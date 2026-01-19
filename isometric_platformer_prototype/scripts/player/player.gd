class_name Player
extends Node2D

# Movement parameters
@export var move_speed: float = 108.0  # World units per second
@export var acceleration: float = 80.0  # How fast we reach move_speed
@export var deceleration: float = 60.0  # How fast we slow down
@export var jump_velocity: float = 135.0
@export var gravity: float = 350.0
@export var homing_attack_speed: float = 200.0
@export var homing_attack_range: float = 64.0  # Screen pixels
@export var stomp_bounce_velocity: float = 100.0  # Bounce after stomping enemy
@export var homing_bounce_velocity: float = 80.0  # Bounce after homing attack
@export var max_step_height: float = 4.0  # Maximum height we can walk up without jumping

# World position (logical coordinates)
var world_pos: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO

# Horizontal velocity for acceleration
var horizontal_velocity: Vector2 = Vector2.ZERO

# State tracking
var is_on_ground: bool = true
var can_double_jump: bool = false  # Restored: tracks if double jump is available
var is_homing: bool = false
var homing_target: Node2D = null
var just_jumped: bool = false
var current_target: Node2D = null  # Currently targeted enemy (for reticle)

# References
@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow
@onready var target_reticle: Node2D = $TargetReticle

# Level reference for collision
var level: Node = null

func _ready() -> void:
	# Find level in parent hierarchy
	level = get_parent()
	while level and not level.has_method("get_tile_height_at"):
		level = level.get_parent()
	
	_setup_placeholder_sprites()
	_update_screen_position()

func _setup_placeholder_sprites() -> void:
	# Create player sprite (simple colored ball)
	if sprite and sprite.texture == null:
		var img := Image.create(12, 14, false, Image.FORMAT_RGBA8)
		for y in range(14):
			for x in range(12):
				var cx := x - 6
				var cy := y - 7
				if (cx * cx) / 25.0 + (cy * cy) / 36.0 <= 1.0:
					var shade := 1.0 - (cx + cy) * 0.05
					img.set_pixel(x, y, Color(0.9 * shade, 0.3 * shade, 0.3 * shade))
		
		var tex := ImageTexture.create_from_image(img)
		sprite.texture = tex
		sprite.offset = Vector2(0, -7)
	
	# Create shadow sprite (ellipse)
	if shadow and shadow.texture == null:
		var img := Image.create(12, 6, false, Image.FORMAT_RGBA8)
		for y in range(6):
			for x in range(12):
				var cx := x - 6
				var cy := y - 3
				if (cx * cx) / 36.0 + (cy * cy) / 9.0 <= 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0.6))
		
		var tex := ImageTexture.create_from_image(img)
		shadow.texture = tex

func _physics_process(delta: float) -> void:
	if is_homing:
		_process_homing_attack(delta)
	else:
		_process_jump()
		_process_movement(delta)
		_process_gravity(delta)
	
	_update_collision()
	_check_enemy_stomp()
	_update_target_reticle()
	_update_screen_position()
	_update_depth_sort()
	
	just_jumped = false

func _process_movement(delta: float) -> void:
	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")
	
	var world_dir := IsoUtils.input_to_world_direction(input)
	var target_velocity := world_dir * move_speed
	
	if world_dir.length() > 0:
		horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(Vector2.ZERO, deceleration * delta)
	
	var new_x: float = world_pos.x + horizontal_velocity.x * delta
	var new_y: float = world_pos.y + horizontal_velocity.y * delta
	
	# Wall collision
	if level and level.has_method("get_tile_height_at"):
		var new_ground_x: float = level.get_tile_height_at(new_x, world_pos.y)
		if new_ground_x > world_pos.z + max_step_height:
			new_x = world_pos.x
			horizontal_velocity.x = 0.0
		
		var new_ground_y: float = level.get_tile_height_at(world_pos.x, new_y)
		if new_ground_y > world_pos.z + max_step_height:
			new_y = world_pos.y
			horizontal_velocity.y = 0.0
		
		var new_ground_xy: float = level.get_tile_height_at(new_x, new_y)
		if new_ground_xy > world_pos.z + max_step_height:
			if new_x != world_pos.x and new_y != world_pos.y:
				var ground_x_only: float = level.get_tile_height_at(new_x, world_pos.y)
				if ground_x_only <= world_pos.z + max_step_height:
					new_y = world_pos.y
					horizontal_velocity.y = 0.0
				else:
					var ground_y_only: float = level.get_tile_height_at(world_pos.x, new_y)
					if ground_y_only <= world_pos.z + max_step_height:
						new_x = world_pos.x
						horizontal_velocity.x = 0.0
					else:
						new_x = world_pos.x
						new_y = world_pos.y
						horizontal_velocity = Vector2.ZERO
	
	world_pos.x = new_x
	world_pos.y = new_y

func _process_gravity(delta: float) -> void:
	if not is_on_ground:
		velocity.z -= gravity * delta
	world_pos.z += velocity.z * delta

func _process_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		if is_on_ground:
			# Ground jump
			velocity.z = jump_velocity
			is_on_ground = false
			can_double_jump = true  # Enable double jump after first jump
			just_jumped = true
		elif not is_on_ground and can_double_jump:
			# Airborne with double jump available
			var target := _find_homing_target()
			if target:
				# Homing attack takes priority when target exists
				_start_homing_attack(target)
				can_double_jump = false
			else:
				# No target - perform double jump
				velocity.z = jump_velocity * 0.8
				can_double_jump = false

func _find_homing_target() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = homing_attack_range
	
	var my_screen_pos := IsoUtils.world_to_screen(world_pos)
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("get_world_pos"):
			var enemy_screen_pos := IsoUtils.world_to_screen(enemy.get_world_pos())
			var dist := my_screen_pos.distance_to(enemy_screen_pos)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = enemy
	
	return nearest

func _update_target_reticle() -> void:
	if not target_reticle:
		return
	
	# Only show reticle when airborne and there's a valid target
	if is_on_ground or is_homing:
		current_target = null
		target_reticle.hide_reticle()
		return
	
	current_target = _find_homing_target()
	
	if current_target and is_instance_valid(current_target):
		var target_screen_pos := IsoUtils.world_to_screen(current_target.get_world_pos())
		target_reticle.show_at(target_screen_pos)
	else:
		target_reticle.hide_reticle()

func _start_homing_attack(target: Node2D) -> void:
	is_homing = true
	homing_target = target
	# Stop horizontal momentum during homing
	horizontal_velocity = Vector2.ZERO
	velocity.z = 0.0

func _process_homing_attack(delta: float) -> void:
	if not is_instance_valid(homing_target):
		_end_homing_attack(false)
		return
	
	var target_world_pos: Vector3 = homing_target.get_world_pos()
	var to_target := target_world_pos - world_pos
	var distance := to_target.length()
	
	# Calculate how far we'd move this frame
	var move_distance: float = homing_attack_speed * delta
	
	# If we would overshoot, clamp to target position and hit
	if move_distance >= distance or distance < 8.0:
		# Snap to target position (or very close) then register hit
		world_pos = target_world_pos
		if homing_target.has_method("take_damage"):
			homing_target.take_damage(1)
		_end_homing_attack(true)
	else:
		# Move toward target without overshooting
		var direction := to_target.normalized()
		world_pos += direction * move_distance

func _end_homing_attack(hit_enemy: bool) -> void:
	is_homing = false
	homing_target = null
	
	if hit_enemy:
		# Bounce upward after hitting enemy
		velocity.z = homing_bounce_velocity
		# Re-enable double jump/homing for chaining attacks
		can_double_jump = true

func _check_enemy_stomp() -> void:
	# Only check when falling
	if is_on_ground or velocity.z >= 0 or is_homing:
		return
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var my_screen_pos := IsoUtils.world_to_screen(world_pos)
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_method("get_world_pos"):
			continue
		
		var enemy_pos: Vector3 = enemy.get_world_pos()
		
		# Check if we're above the enemy and close enough horizontally
		var horizontal_dist := Vector2(world_pos.x - enemy_pos.x, world_pos.y - enemy_pos.y).length()
		var vertical_diff := world_pos.z - enemy_pos.z
		
		# Stomp detection: close horizontally, coming from above
		if horizontal_dist < 1.0 and vertical_diff > 0 and vertical_diff < 12.0:
			# Stomp the enemy
			if enemy.has_method("stomp"):
				enemy.stomp()
			elif enemy.has_method("take_damage"):
				enemy.take_damage(1)
			
			# Bounce and re-enable air action
			velocity.z = stomp_bounce_velocity
			can_double_jump = true
			break

func _update_collision() -> void:
	if just_jumped:
		return
	
	# Don't do ground collision during homing attack
	if is_homing:
		return
	
	var ground_height: float = 0.0
	if level and level.has_method("get_tile_height_at"):
		ground_height = level.get_tile_height_at(world_pos.x, world_pos.y)
	
	if world_pos.z <= ground_height:
		world_pos.z = ground_height
		velocity.z = 0.0
		is_on_ground = true
		can_double_jump = false  # Reset double jump when landing
	else:
		is_on_ground = false

func _update_screen_position() -> void:
	position = IsoUtils.world_to_screen(world_pos)
	
	if shadow:
		var ground_height: float = 0.0
		if level and level.has_method("get_tile_height_at"):
			ground_height = level.get_tile_height_at(world_pos.x, world_pos.y)
		
		var shadow_world_pos := Vector3(world_pos.x, world_pos.y, ground_height)
		var shadow_screen_pos := IsoUtils.world_to_screen(shadow_world_pos)
		shadow.global_position = shadow_screen_pos
		shadow.z_index = z_index - 1
		
		var height_diff: float = world_pos.z - ground_height
		var alpha: float = clampf(1.0 - (height_diff / 64.0), 0.2, 0.6)
		shadow.modulate.a = alpha
		
		var scale_factor: float = clampf(1.0 - (height_diff / 128.0), 0.5, 1.0)
		shadow.scale = Vector2(scale_factor, scale_factor)

func _update_depth_sort() -> void:
	z_index = int(IsoUtils.get_depth_sort(world_pos) * 10)

func get_world_pos() -> Vector3:
	return world_pos

func set_world_pos(pos: Vector3) -> void:
	world_pos = pos
	_update_screen_position()
	_update_depth_sort()
