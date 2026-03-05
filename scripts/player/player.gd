class_name Player
extends IsoEntity

# Movement parameters
@export var move_speed: float = 108.0  # World units per second
@export var acceleration: float = 80.0  # How fast we reach move_speed
@export var deceleration: float = 60.0  # How fast we slow down
@export var jump_velocity: float = 135.0
@export var gravity: float = 350.0
@export var homing_attack_speed: float = 200.0
@export var homing_attack_range: float = 64.0  # Screen pixels
@export var stomp_bounce_velocity: float = 150.0  # Bounce after stomping enemy
@export var homing_bounce_velocity: float = 150.0  # Bounce after homing attack
@export var max_step_height: float = 4.0  # Maximum height we can walk up without jumping

# Combat / movement state
enum ActionState { GROUNDED, AIRBORNE, HOMING }
var action_state: ActionState = ActionState.GROUNDED

# Player identity / input mapping
@export var player_id: int = 1

# Attack tuning
@export var attack_range: float = 6.0  # World units
@export var attack_cone_degrees: float = 90.0  # Total cone angle
@export var combo_window: float = 0.5
@export var combo_recovery: float = 0.2
@export var attack_damage: int = 1
@export var combo_third_multiplier: int = 3
@export var charge_time: float = 1.0
@export var charge_damage: int = 3
@export var charge_radius: float = 3.0  # World units
@export var charge_recovery: float = 0.2
@export var attack_visual_distance: float = 48.0  # Screen pixels
@export var attack_visual_time: float = 0.18

# Health/feedback
@export var max_hp: int = 5
@export var invuln_time: float = 0.5
@export var hit_flash_time: float = 0.12
@export var knockback_strength: float = 2.0  # World units per second

var velocity: Vector3 = Vector3.ZERO

# Horizontal velocity for acceleration
var horizontal_velocity: Vector2 = Vector2.ZERO
var last_move_dir: Vector2 = Vector2.DOWN

# State tracking
var is_on_ground: bool = true
var can_double_jump: bool = false  # Restored: tracks if double jump is available
var is_homing: bool = false
var homing_target: Node2D = null
var just_jumped: bool = false
var current_target: Node2D = null  # Currently targeted enemy (for reticle)

# Attack state
var combo_step: int = 0
var combo_timer: float = 0.0
var attack_cooldown: float = 0.0
var charging: bool = false
var charge_timer: float = 0.0
var charge_fired: bool = false
var flash_timer: float = 0.0
var combo_hand_index: int = 0

var hand_attack_time: Array[float] = [0.0, 0.0]
var hand_attack_active: Array[bool] = [false, false]
var hand_attack_explosion: Array[bool] = [false, false]

var explosions: Array[Dictionary] = []

# Movement feel
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var air_accel_multiplier: float = 0.7
@export var air_decel_multiplier: float = 0.8

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# Health state
var hp: int = 0
var invuln_timer: float = 0.0
var hit_flash_timer: float = 0.0

# References
@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow
@onready var target_reticle: Node2D = $TargetReticle
@onready var hand_left: Sprite2D = $HandLeft
@onready var hand_right: Sprite2D = $HandRight
@onready var health_bar: Node2D = $HealthBar

var _move_left_action: StringName
var _move_right_action: StringName
var _move_up_action: StringName
var _move_down_action: StringName
var _jump_action: StringName
var _attack_action: StringName

func _ready() -> void:
	super._ready()
	add_to_group("players")
	_setup_input_actions()
	_setup_placeholder_sprites()
	_update_screen_position()
	hp = max_hp
	_update_health_bar()

func _setup_input_actions() -> void:
	# Map actions per player
	if player_id <= 1:
		_move_left_action = &"p1_move_left"
		_move_right_action = &"p1_move_right"
		_move_up_action = &"p1_move_up"
		_move_down_action = &"p1_move_down"
		_jump_action = &"p1_jump"
		_attack_action = &"p1_attack"
	else:
		_move_left_action = &"p2_move_left"
		_move_right_action = &"p2_move_right"
		_move_up_action = &"p2_move_up"
		_move_down_action = &"p2_move_down"
		_jump_action = &"p2_jump"
		_attack_action = &"p2_attack"

func _setup_placeholder_sprites() -> void:
	# Create player sprite (simple colored ball)
	if sprite and sprite.texture == null:
		var base_color := Color(0.2, 0.4, 0.9) if player_id == 1 else Color(0.6, 0.2, 0.9)
		var img := Image.create(12, 14, false, Image.FORMAT_RGBA8)
		for y in range(14):
			for x in range(12):
				var cx := x - 6
				var cy := y - 7
				if (cx * cx) / 25.0 + (cy * cy) / 36.0 <= 1.0:
					var shade := 1.0 - (cx + cy) * 0.05
					img.set_pixel(x, y, base_color * shade)
		
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
	
	# Create hand sprites (small white circles)
	var hand_tex := _create_hand_texture()
	if hand_left and hand_left.texture == null:
		hand_left.texture = hand_tex
		hand_left.z_index = 20
	if hand_right and hand_right.texture == null:
		hand_right.texture = hand_tex
		hand_right.z_index = 20

func _create_hand_texture() -> ImageTexture:
	var size := 6
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(2.5, 2.5)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x, y).distance_to(center)
			if d <= 2.5:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_process_attack(delta)
	_update_hands(delta)
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
	_update_explosions(delta)
	
	just_jumped = false

func _process_movement(delta: float) -> void:
	var input := Vector2.ZERO
	input.x = Input.get_axis(_move_left_action, _move_right_action)
	input.y = Input.get_axis(_move_up_action, _move_down_action)
	
	var world_dir := IsoUtils.input_to_world_direction(input)
	var target_velocity := world_dir * move_speed
	
	if world_dir.length_squared() > 0.0:
		last_move_dir = world_dir.normalized()
	
	var accel := acceleration
	var decel := deceleration
	if not is_on_ground:
		accel *= air_accel_multiplier
		decel *= air_decel_multiplier
	
	if world_dir.length() > 0:
		horizontal_velocity = horizontal_velocity.move_toward(target_velocity, accel * delta)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(Vector2.ZERO, decel * delta)
	
	var new_x: float = world_pos.x + horizontal_velocity.x * delta
	var new_y: float = world_pos.y + horizontal_velocity.y * delta
	
	# Wall collision
	if level and level.has_method("get_tile_height_at"):
		if level.is_step_blocked(new_x, world_pos.y, world_pos.z, max_step_height):
			new_x = world_pos.x
			horizontal_velocity.x = 0.0
		
		if level.is_step_blocked(world_pos.x, new_y, world_pos.z, max_step_height):
			new_y = world_pos.y
			horizontal_velocity.y = 0.0
		
		if level.is_step_blocked(new_x, new_y, world_pos.z, max_step_height):
			if new_x != world_pos.x and new_y != world_pos.y:
				if not level.is_step_blocked(new_x, world_pos.y, world_pos.z, max_step_height):
					new_y = world_pos.y
					horizontal_velocity.y = 0.0
				else:
					if not level.is_step_blocked(world_pos.x, new_y, world_pos.z, max_step_height):
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
	if Input.is_action_just_pressed(_jump_action):
		jump_buffer_timer = jump_buffer_time
	
	if jump_buffer_timer > 0.0:
		if is_on_ground or coyote_timer > 0.0:
			# Ground jump (with coyote time)
			velocity.z = jump_velocity
			is_on_ground = false
			_set_action_state(ActionState.AIRBORNE)
			can_double_jump = true  # Enable double jump after first jump
			just_jumped = true
			jump_buffer_timer = 0.0
		elif not is_on_ground and can_double_jump:
			# Airborne with double jump available
			var target := _find_homing_target()
			if target:
				# Homing attack takes priority when target exists
				_start_homing_attack(target)
				can_double_jump = false
				jump_buffer_timer = 0.0
			else:
				# No target - perform double jump
				velocity.z = jump_velocity * 0.8
				can_double_jump = false
				jump_buffer_timer = 0.0

func _find_homing_target() -> Node2D:
	var hurtboxes := get_tree().get_nodes_in_group("hurtboxes")
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = homing_attack_range
	
	var my_screen_pos := IsoUtils.world_to_screen(world_pos)
	
	for hurtbox in hurtboxes:
		if not is_instance_valid(hurtbox):
			continue
		if hurtbox.has_method("get_world_pos"):
			var hb_screen_pos := IsoUtils.world_to_screen(hurtbox.get_world_pos())
			var dist_hb := my_screen_pos.distance_to(hb_screen_pos)
			if dist_hb < nearest_dist:
				nearest_dist = dist_hb
				nearest = hurtbox
	
	if nearest == null:
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
	
	if current_target and is_instance_valid(current_target) and current_target.has_method("get_world_pos"):
		var target_screen_pos := IsoUtils.world_to_screen(current_target.get_world_pos())
		target_reticle.show_at(target_screen_pos)
	else:
		target_reticle.hide_reticle()

func _start_homing_attack(target: Node2D) -> void:
	is_homing = true
	_set_action_state(ActionState.HOMING)
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
		if homing_target.has_method("get_owner_body"):
			var owner_body: Node = homing_target.get_owner_body()
			if owner_body and owner_body.has_method("take_damage"):
				owner_body.take_damage(1)
		elif homing_target.has_method("take_damage"):
			homing_target.take_damage(1)
		_end_homing_attack(true)
	else:
		# Move toward target without overshooting
		var direction := to_target.normalized()
		world_pos += direction * move_distance

func _end_homing_attack(hit_enemy: bool) -> void:
	is_homing = false
	_set_action_state(ActionState.AIRBORNE)
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
	
	var targets := get_tree().get_nodes_in_group("hurtboxes")
	if targets.is_empty():
		targets = get_tree().get_nodes_in_group("enemies")
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		if not target.has_method("get_world_pos"):
			continue
		
		var enemy_pos: Vector3 = target.get_world_pos()
		
		# Check if we're above the enemy and close enough horizontally
		var horizontal_dist := Vector2(world_pos.x - enemy_pos.x, world_pos.y - enemy_pos.y).length()
		var vertical_diff := world_pos.z - enemy_pos.z
		var stomp_dist := 1.0
		var stomp_height := 12.0
		if target is GroundEnemy:
			stomp_dist = 1.5
			stomp_height = 18.0
		
		# Stomp detection: close horizontally, coming from above
		if horizontal_dist < stomp_dist and vertical_diff > 0 and vertical_diff < stomp_height:
			# Stomp the enemy
			if target.has_method("get_owner_body"):
				var owner_body: Node = target.get_owner_body()
				if owner_body and owner_body.has_method("stomp"):
					owner_body.stomp()
				elif owner_body and owner_body.has_method("take_damage"):
					owner_body.take_damage(1)
			elif target.has_method("stomp"):
				target.stomp()
			elif target.has_method("take_damage"):
				target.take_damage(1)
			
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
	
	var ground_height: float = _ground_height_at(world_pos.x, world_pos.y)
	
	if world_pos.z <= ground_height:
		world_pos.z = ground_height
		velocity.z = 0.0
		is_on_ground = true
		_set_action_state(ActionState.GROUNDED)
		can_double_jump = false  # Reset double jump when landing
		coyote_timer = coyote_time
	else:
		is_on_ground = false
		if not is_homing:
			_set_action_state(ActionState.AIRBORNE)

func _update_screen_position() -> void:
	# Update sprite and shadow positions from world coordinates
	super._update_screen_position()
	_update_shadow(shadow, 64.0, 0.2, 0.6, 0.5, 1.0)

func _update_depth_sort() -> void:
	super._update_depth_sort()

func set_world_pos(pos: Vector3) -> void:
	super.set_world_pos(pos)

func _set_action_state(new_state: ActionState) -> void:
	# Centralized state change for future combat logic
	if action_state == new_state:
		return
	action_state = new_state

func take_damage(amount: int, source_dir: Vector2 = Vector2.ZERO) -> void:
	if invuln_timer > 0.0:
		return
	hp -= amount
	invuln_timer = invuln_time
	hit_flash_timer = hit_flash_time
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
	if source_dir.length_squared() > 0.0:
		var knock := source_dir.normalized() * knockback_strength
		world_pos.x += knock.x
		world_pos.y += knock.y
	if hp <= 0:
		hp = max_hp
		_update_health_bar()
		return
	_update_health_bar()

func _update_timers(delta: float) -> void:
	if invuln_timer > 0.0:
		invuln_timer = maxf(invuln_timer - delta, 0.0)
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)
		if hit_flash_timer == 0.0 and sprite:
			sprite.modulate = Color(1, 1, 1, 1)
	if not is_on_ground and coyote_timer > 0.0:
		coyote_timer = maxf(coyote_timer - delta, 0.0)
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

func _update_health_bar() -> void:
	if health_bar and health_bar.has_method("set_values"):
		health_bar.set_values(hp, max_hp)

func _process_attack(delta: float) -> void:
	# Timers
	if combo_timer > 0.0:
		combo_timer = maxf(combo_timer - delta, 0.0)
		if combo_timer == 0.0:
			combo_step = 0
	if attack_cooldown > 0.0:
		attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	
	if flash_timer > 0.0:
		flash_timer = maxf(flash_timer - delta, 0.0)
		if flash_timer == 0.0 and sprite:
			sprite.modulate = Color(1, 1, 1, 1)
	
	# Charging logic
	if Input.is_action_just_pressed(_attack_action) and attack_cooldown == 0.0:
		charging = true
		charge_timer = 0.0
		charge_fired = false
	
	if charging:
		charge_timer += delta
		if charge_timer >= charge_time and not charge_fired:
			# Charge attack triggers once
			charge_fired = true
			combo_step = 0
			combo_timer = 0.0
			_perform_charge_attack()
			attack_cooldown = charge_recovery
		
		if Input.is_action_just_released(_attack_action):
			charging = false
			if not charge_fired and attack_cooldown == 0.0:
				_perform_combo_attack()
	
	if not Input.is_action_pressed(_attack_action) and charge_fired:
		charging = false

func _perform_combo_attack() -> void:
	if attack_cooldown > 0.0:
		return
	
	combo_step += 1
	if combo_step >= 3:
		var damage := attack_damage * combo_third_multiplier
		_apply_cone_damage(damage)
		_start_hand_attack(0, true)
		combo_step = 0
		attack_cooldown = combo_recovery
	else:
		_apply_cone_damage(attack_damage)
		_start_hand_attack(combo_hand_index, false)
		combo_hand_index = 1 - combo_hand_index
		combo_timer = combo_window

func _perform_charge_attack() -> void:
	# White flash when charge completes
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
		flash_timer = 0.1
	
	var target := _find_attack_target(attack_range * 1.5, 90.0)
	if target and target.has_method("get_world_pos"):
		var target_pos: Vector3 = target.get_world_pos()
		_apply_explosive_damage_at(Vector2(target_pos.x, target_pos.y), charge_damage, charge_radius)
	else:
		_apply_explosive_damage(charge_damage, charge_radius)
	_start_hand_attack(0, true)

func _apply_cone_damage(damage: int) -> void:
	var targets := get_tree().get_nodes_in_group("hurtboxes")
	if targets.is_empty():
		targets = get_tree().get_nodes_in_group("enemies")
	
	var best_target: Node2D = null
	var best_dist := attack_range
	var forward := last_move_dir
	if forward.length_squared() == 0.0:
		forward = Vector2.DOWN
	var cos_half := cos(deg_to_rad(attack_cone_degrees * 0.5))
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		if not target.has_method("get_world_pos"):
			continue
		
		var target_pos: Vector3 = target.get_world_pos()
		var to_target := Vector2(target_pos.x - world_pos.x, target_pos.y - world_pos.y)
		var dist := to_target.length()
		if dist > attack_range or dist == 0.0:
			continue
		var dir := to_target / dist
		if dir.dot(forward) < cos_half:
			continue
		if dist < best_dist:
			best_dist = dist
			best_target = target
	
	if best_target:
		if best_target.has_method("get_owner_body"):
			var owner_body: Node = best_target.get_owner_body()
			if owner_body and owner_body.has_method("take_damage"):
				var target_pos: Vector3 = best_target.get_world_pos()
				var dir := Vector2(target_pos.x - world_pos.x, target_pos.y - world_pos.y)
				owner_body.take_damage(damage, dir)
		elif best_target.has_method("take_damage"):
			var target_pos: Vector3 = best_target.get_world_pos()
			var dir := Vector2(target_pos.x - world_pos.x, target_pos.y - world_pos.y)
			best_target.take_damage(damage, dir)

func _apply_explosive_damage(damage: int, radius: float) -> void:
	_apply_explosive_damage_at(Vector2(world_pos.x, world_pos.y), damage, radius)

func _apply_explosive_damage_at(center: Vector2, damage: int, radius: float) -> void:
	var targets := get_tree().get_nodes_in_group("hurtboxes")
	if targets.is_empty():
		targets = get_tree().get_nodes_in_group("enemies")
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		if not target.has_method("get_world_pos"):
			continue
		
		var target_pos: Vector3 = target.get_world_pos()
		var dist := Vector2(target_pos.x - center.x, target_pos.y - center.y).length()
		if dist <= radius:
			if target.has_method("get_owner_body"):
				var owner_body: Node = target.get_owner_body()
				if owner_body and owner_body.has_method("take_damage"):
					var dir := Vector2(target_pos.x - center.x, target_pos.y - center.y)
					owner_body.take_damage(damage, dir)
			elif target.has_method("take_damage"):
				var dir := Vector2(target_pos.x - center.x, target_pos.y - center.y)
				target.take_damage(damage, dir)

func _start_hand_attack(hand_index: int, trigger_explosion: bool) -> void:
	if hand_index < 0 or hand_index >= hand_attack_time.size():
		return
	hand_attack_active[hand_index] = true
	hand_attack_time[hand_index] = 0.0
	hand_attack_explosion[hand_index] = trigger_explosion

func _update_hands(delta: float) -> void:
	if not hand_left or not hand_right:
		return
	
	var dir := last_move_dir
	if dir.length_squared() == 0.0:
		dir = Vector2.DOWN
	var facing_lr := absf(dir.x) > absf(dir.y)
	
	var left_visible := true
	var right_visible := true
	var left_offset := Vector2(-4, 0)
	var right_offset := Vector2(4, 0)
	
	if facing_lr:
		# Side-facing: show only one hand centered
		if dir.x > 0.0:
			left_visible = false
			right_offset = Vector2(0, 0)
		else:
			right_visible = false
			left_offset = Vector2(0, 0)
	else:
		# Forward/back: both hands visible on sides
		left_offset = Vector2(-4, 2 if dir.y > 0.0 else -2)
		right_offset = Vector2(4, 2 if dir.y > 0.0 else -2)
	
	hand_left.visible = left_visible or hand_attack_active[0]
	hand_right.visible = right_visible or hand_attack_active[1]
	
	var screen_dir := _get_attack_screen_dir(dir)
	if screen_dir.length_squared() == 0.0:
		screen_dir = Vector2(0, 1)
	
	hand_left.position = left_offset + _hand_attack_offset(0, screen_dir, delta)
	hand_right.position = right_offset + _hand_attack_offset(1, screen_dir, delta)

func _hand_attack_offset(hand_index: int, screen_dir: Vector2, delta: float) -> Vector2:
	if not hand_attack_active[hand_index]:
		return Vector2.ZERO
	hand_attack_time[hand_index] += delta
	var t := hand_attack_time[hand_index] / attack_visual_time
	if t >= 1.0:
		hand_attack_active[hand_index] = false
		hand_attack_time[hand_index] = 0.0
		return Vector2.ZERO
	
	var progress := t / 0.5 if t <= 0.5 else (1.0 - t) / 0.5
	if hand_attack_explosion[hand_index] and t >= 0.5:
		hand_attack_explosion[hand_index] = false
		_spawn_explosion(screen_dir * attack_visual_distance)
	return screen_dir * attack_visual_distance * progress

func _world_dir_to_screen(dir: Vector2) -> Vector2:
	var screen_x := (dir.x - dir.y) * IsoUtils.TILE_WIDTH_HALF
	var screen_y := (dir.x + dir.y) * IsoUtils.TILE_HEIGHT_HALF
	return Vector2(screen_x, screen_y)

func _get_attack_screen_dir(fallback_dir: Vector2) -> Vector2:
	var target := _find_attack_target(attack_range * 1.5, 90.0)
	if target and target.has_method("get_world_pos"):
		var target_pos: Vector3 = target.get_world_pos()
		var to_target := Vector2(target_pos.x - world_pos.x, target_pos.y - world_pos.y)
		if to_target.length_squared() > 0.0:
			return _world_dir_to_screen(to_target.normalized()).normalized()
	return _world_dir_to_screen(fallback_dir).normalized()

func _find_attack_target(range: float, cone_degrees: float) -> Node2D:
	var targets := get_tree().get_nodes_in_group("hurtboxes")
	if targets.is_empty():
		targets = get_tree().get_nodes_in_group("enemies")
	
	var best_target: Node2D = null
	var best_dist := range
	var forward := last_move_dir
	if forward.length_squared() == 0.0:
		forward = Vector2.DOWN
	var cos_half := cos(deg_to_rad(cone_degrees * 0.5))
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		if not target.has_method("get_world_pos"):
			continue
		
		var target_pos: Vector3 = target.get_world_pos()
		var to_target := Vector2(target_pos.x - world_pos.x, target_pos.y - world_pos.y)
		var dist := to_target.length()
		if dist > range or dist == 0.0:
			continue
		var dir := to_target / dist
		if dir.dot(forward) < cos_half:
			continue
		if dist < best_dist:
			best_dist = dist
			best_target = target
	
	return best_target

func _spawn_explosion(offset: Vector2) -> void:
	var node := Sprite2D.new()
	node.texture = _create_explosion_texture()
	node.z_index = 30
	node.position = offset
	add_child(node)
	explosions.append({
		"node": node,
		"time": 0.15
	})

func _create_explosion_texture() -> ImageTexture:
	var size := 12
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(5.5, 5.5)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x, y).distance_to(center)
			if d <= 5.5:
				var alpha := 1.0 - (d / 5.5)
				img.set_pixel(x, y, Color(1.0, 0.9, 0.4, alpha))
	return ImageTexture.create_from_image(img)

func _update_explosions(delta: float) -> void:
	for i in range(explosions.size() - 1, -1, -1):
		var entry := explosions[i]
		entry.time -= delta
		var node: Sprite2D = entry.node
		if entry.time <= 0.0:
			if node:
				node.queue_free()
			explosions.remove_at(i)
		else:
			if node:
				var t: float = entry.time / 0.15
				node.scale = Vector2(1.0 + (1.0 - t), 1.0 + (1.0 - t))
				node.modulate.a = t
