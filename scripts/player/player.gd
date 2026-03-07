class_name Player
extends IsoEntity

const GroundedStateScript := preload("res://scripts/player/states/grounded_state.gd")
const AirborneStateScript := preload("res://scripts/player/states/airborne_state.gd")
const HomingStateScript := preload("res://scripts/player/states/homing_state.gd")
const HurtStateScript := preload("res://scripts/player/states/hurt_state.gd")
const DeadStateScript := preload("res://scripts/player/states/dead_state.gd")
const DashSmokeBurstScene := preload("res://scenes/effects/dash_smoke_burst.tscn")
const LandDustBurstScene := preload("res://scenes/effects/land_dust_burst.tscn")
const JumpDustBurstScene := preload("res://scenes/effects/jump_dust_burst.tscn")

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
enum ActionState { GROUNDED, AIRBORNE, HOMING, HURT, DEAD }
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
@export var dash_distance: float = 18.0  # World units traveled per dash
@export var dash_duration: float = 0.18  # Seconds (fast burst)
@export var dash_recovery: float = 0.1
@export var dash_damage: int = 2
@export var dash_hit_radius: float = 0.9
@export var dash_input_window: float = 0.12  # Max gap between jump+attack presses

# Health/feedback
@export var max_hp: int = 3
@export var invuln_time: float = 0.5
@export var hit_flash_time: float = 0.12
@export var knockback_strength: float = 2.0  # World units per second
@export var homing_post_hit_invuln_time: float = 0.5  # Extra invulnerability after homing collision
@export var hurt_state_time: float = 0.12

var velocity: Vector3 = Vector3.ZERO

# Horizontal velocity for acceleration
var horizontal_velocity: Vector2 = Vector2.ZERO
var last_move_dir: Vector2 = Vector2.DOWN

# State tracking
var is_on_ground: bool = true
var is_dead: bool = false
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
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_remaining_distance: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var dash_hit_ids: Dictionary = {}
var dash_jump_buffer: float = 0.0
var dash_attack_buffer: float = 0.0
var dash_elapsed: float = 0.0
var dash_smoke_timer: float = 0.0
var dash_flash_sprite: Sprite2D = null

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
var homing_invuln_timer: float = 0.0
var hurt_state_timer: float = 0.0

var _state_map: Dictionary = {}
var _current_state: PlayerState = null
var _was_on_ground: bool = true
var _squash_stretch: Vector2 = Vector2.ONE
var _squash_timer: float = 0.0

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
	_setup_states()
	_setup_placeholder_sprites()
	_update_screen_position()
	hp = max_hp
	_update_health_bar()
	_set_action_state(ActionState.GROUNDED)

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

func _setup_states() -> void:
	_state_map = {
		ActionState.GROUNDED: GroundedStateScript.new(),
		ActionState.AIRBORNE: AirborneStateScript.new(),
		ActionState.HOMING: HomingStateScript.new(),
		ActionState.HURT: HurtStateScript.new(),
		ActionState.DEAD: DeadStateScript.new(),
	}

func _play_sfx(event_id: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(event_id)

func _emit_hit_feedback(shake_strength: float = 1.0) -> void:
	GameState.request_hit_stop(0.04, 0.12)
	GameState.request_camera_shake(1.4 * shake_strength, 0.12)
	_play_sfx("hit")

func _on_land() -> void:
	_spawn_effect(LandDustBurstScene)
	_apply_squash(Vector2(1.3, 0.7), 0.1)

func _on_jump_effect() -> void:
	_spawn_effect(JumpDustBurstScene)
	_apply_squash(Vector2(0.7, 1.3), 0.1)

func _spawn_effect(scene: PackedScene) -> void:
	if not scene:
		return
	var burst := scene.instantiate()
	burst.position = IsoUtils.world_to_screen(world_pos)
	burst.z_index = 900
	get_parent().add_child(burst)

func _apply_squash(scale: Vector2, duration: float) -> void:
	_squash_stretch = scale
	_squash_timer = duration

func _update_squash_stretch(delta: float) -> void:
	if _squash_timer > 0.0:
		_squash_timer = maxf(_squash_timer - delta, 0.0)
		if _squash_timer <= 0.0:
			_squash_stretch = Vector2.ONE
	if sprite:
		sprite.scale = _squash_stretch

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
		_setup_dash_flash_sprite(img)
	
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

func _setup_dash_flash_sprite(source_img: Image) -> void:
	# White additive overlay used to make dash state visually obvious.
	var flash_img := Image.create(source_img.get_width(), source_img.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(source_img.get_height()):
		for x in range(source_img.get_width()):
			var a := source_img.get_pixel(x, y).a
			if a > 0.0:
				flash_img.set_pixel(x, y, Color(1, 1, 1, a))
	var flash_tex := ImageTexture.create_from_image(flash_img)
	dash_flash_sprite = Sprite2D.new()
	dash_flash_sprite.texture = flash_tex
	dash_flash_sprite.offset = Vector2(0, -7)
	dash_flash_sprite.z_index = 25
	dash_flash_sprite.visible = false
	var flash_material := CanvasItemMaterial.new()
	flash_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	dash_flash_sprite.material = flash_material
	add_child(dash_flash_sprite)

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
	if is_dead:
		return
	_update_timers(delta)
	_try_start_dash()
	_process_attack(delta)
	_update_hands(delta)
	if is_dashing:
		_process_dash(delta)
	elif _current_state:
		_current_state.physics_update(self, delta)
	
	_update_collision()
	_check_enemy_stomp()
	_update_target_reticle()
	_update_screen_position()
	_update_depth_sort()
	_update_explosions(delta)
	_update_squash_stretch(delta)

	_was_on_ground = is_on_ground
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

func _try_start_dash() -> void:
	if is_dashing or is_homing or is_dead:
		return
	if not is_on_ground:
		return
	if action_state == ActionState.HURT or action_state == ActionState.DEAD:
		return
	if dash_jump_buffer <= 0.0 or dash_attack_buffer <= 0.0:
		return
	var dash_dir := _get_dash_direction()
	if dash_dir.length_squared() == 0.0:
		return
	_start_dash(dash_dir)

func _get_dash_direction() -> Vector2:
	var input := Vector2.ZERO
	input.x = Input.get_axis(_move_left_action, _move_right_action)
	input.y = Input.get_axis(_move_up_action, _move_down_action)
	var world_dir := IsoUtils.input_to_world_direction(input)
	if world_dir.length_squared() > 0.0:
		last_move_dir = world_dir.normalized()
		return world_dir.normalized()
	if last_move_dir.length_squared() > 0.0:
		return last_move_dir.normalized()
	return Vector2.ZERO

func _start_dash(dir: Vector2) -> void:
	is_dashing = true
	dash_direction = dir.normalized()
	dash_timer = dash_duration
	dash_elapsed = 0.0
	dash_remaining_distance = dash_distance
	dash_hit_ids.clear()
	dash_smoke_timer = 0.0
	dash_jump_buffer = 0.0
	dash_attack_buffer = 0.0
	horizontal_velocity = Vector2.ZERO
	velocity.z = 0.0
	charging = false
	charge_timer = 0.0
	charge_fired = false
	combo_step = 0
	combo_timer = 0.0
	attack_cooldown = maxf(attack_cooldown, dash_recovery)
	_play_sfx("attack")
	_update_dash_visual(0.0)
	_spawn_dash_smoke()

func _process_dash(delta: float) -> void:
	if not is_dashing:
		return
	if dash_timer <= 0.0 or dash_remaining_distance <= 0.0:
		_end_dash()
		return
	dash_elapsed += delta
	var progress := clampf(dash_elapsed / maxf(dash_duration, 0.001), 0.0, 1.0)
	# Smooth accel/decel profile (0 at start/end, peak at midpoint).
	var profile: float = maxf(sin(progress * PI), 0.0)
	var average_profile := 2.0 / PI
	var dash_speed := (dash_distance / maxf(dash_duration, 0.001)) * (profile / maxf(average_profile, 0.001))
	var desired_step := minf(dash_speed * delta, dash_remaining_distance)
	var start_pos := Vector2(world_pos.x, world_pos.y)
	var target_pos := start_pos + dash_direction * desired_step
	var final_pos := _resolve_dash_step_collision(target_pos)
	world_pos.x = final_pos.x
	world_pos.y = final_pos.y
	var moved_distance := start_pos.distance_to(final_pos)
	_apply_dash_damage_segment(start_pos, final_pos)
	dash_remaining_distance = maxf(dash_remaining_distance - moved_distance, 0.0)
	dash_timer = maxf(dash_timer - delta, 0.0)
	dash_smoke_timer = maxf(dash_smoke_timer - delta, 0.0)
	if dash_smoke_timer <= 0.0:
		_spawn_dash_smoke()
		dash_smoke_timer = 0.02
	_update_dash_visual(progress)
	if moved_distance <= 0.001 or dash_timer <= 0.0 or dash_remaining_distance <= 0.0:
		_end_dash()

func _resolve_dash_step_collision(target_pos: Vector2) -> Vector2:
	var new_x := target_pos.x
	var new_y := target_pos.y
	if level and level.has_method("is_step_blocked"):
		if level.is_step_blocked(new_x, world_pos.y, world_pos.z, max_step_height):
			new_x = world_pos.x
		if level.is_step_blocked(world_pos.x, new_y, world_pos.z, max_step_height):
			new_y = world_pos.y
		if level.is_step_blocked(new_x, new_y, world_pos.z, max_step_height):
			new_x = world_pos.x
			new_y = world_pos.y
	return Vector2(new_x, new_y)

func _apply_dash_damage_segment(start_pos: Vector2, end_pos: Vector2) -> void:
	var targets := get_tree().get_nodes_in_group("hurtboxes")
	if targets.is_empty():
		targets = get_tree().get_nodes_in_group("enemies")
	var hit_any: bool = false
	for target in targets:
		if not is_instance_valid(target):
			continue
		if not target.has_method("get_world_pos"):
			continue
		var target_pos3: Vector3 = target.get_world_pos()
		var target_pos := Vector2(target_pos3.x, target_pos3.y)
		if _distance_to_segment(target_pos, start_pos, end_pos) > dash_hit_radius:
			continue
		var owner: Node = target
		if target.has_method("get_owner_body"):
			var owner_body: Node = target.get_owner_body()
			if owner_body:
				owner = owner_body
		var key := str(owner.get_instance_id())
		if dash_hit_ids.has(key):
			continue
		dash_hit_ids[key] = true
		if _is_node_hazardous(owner):
			take_damage(1, dash_direction, owner)
		if owner and owner.has_method("take_damage"):
			owner.take_damage(dash_damage, dash_direction)
			hit_any = true
	if hit_any:
		_emit_hit_feedback(1.1)

func _distance_to_segment(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
	var ab := seg_b - seg_a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq <= 0.000001:
		return point.distance_to(seg_a)
	var t := clampf((point - seg_a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest := seg_a + ab * t
	return point.distance_to(closest)

func _end_dash() -> void:
	is_dashing = false
	dash_timer = 0.0
	dash_elapsed = 0.0
	dash_remaining_distance = 0.0
	dash_smoke_timer = 0.0
	dash_hit_ids.clear()
	if dash_flash_sprite:
		dash_flash_sprite.visible = false

func _update_dash_visual(progress: float) -> void:
	if not dash_flash_sprite:
		return
	dash_flash_sprite.visible = true
	var pulse: float = 0.55 + 0.45 * sin(progress * PI * 6.0)
	dash_flash_sprite.modulate = Color(1, 1, 1, clampf(pulse, 0.2, 1.0))

func _spawn_dash_smoke() -> void:
	if not DashSmokeBurstScene:
		return
	if not get_parent():
		return
	var burst := DashSmokeBurstScene.instantiate()
	burst.position = IsoUtils.world_to_screen(world_pos)
	burst.z_index = 900
	get_parent().add_child(burst)

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
			_play_sfx("jump")
			_on_jump_effect()
			jump_buffer_timer = 0.0
		elif not is_on_ground:
			# In air: homing is allowed whenever a target is valid.
			var target: Node2D = _find_homing_target()
			if target:
				_start_homing_attack(target)
				can_double_jump = false
				jump_buffer_timer = 0.0
			elif can_double_jump:
				# No target - perform double jump (once per airtime)
				velocity.z = jump_velocity * 0.8
				can_double_jump = false
				_play_sfx("jump")
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
	_play_sfx("attack")

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
		var hazard_dir := Vector2(to_target.x, to_target.y)
		# Snap to target position (or very close) then register hit
		world_pos = target_world_pos
		var target_owner: Node = null
		if homing_target.has_method("get_owner_body"):
			target_owner = homing_target.get_owner_body()
		if _is_node_hazardous(homing_target):
			var hazard_source: Node = target_owner if target_owner else homing_target
			take_damage(1, hazard_dir, hazard_source)
			# Hazardous targets do not take homing damage.
			_end_homing_attack(false)
			return
		if target_owner and target_owner.has_method("take_damage"):
			target_owner.take_damage(1)
		elif homing_target.has_method("take_damage"):
			homing_target.take_damage(1)
		_emit_hit_feedback(1.0)
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
		homing_invuln_timer = maxf(homing_invuln_timer, homing_post_hit_invuln_time)
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
			_emit_hit_feedback(0.8)
			_apply_squash(Vector2(0.7, 1.3), 0.08)
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
		if not _was_on_ground:
			_on_land()
		velocity.z = 0.0
		is_on_ground = true
		_set_action_state(ActionState.GROUNDED)
		can_double_jump = false  # Reset double jump when landing
		coyote_timer = coyote_time
		_check_tile_interaction()
	else:
		is_on_ground = false
		if not is_homing and action_state != ActionState.HURT:
			_set_action_state(ActionState.AIRBORNE)

func _check_tile_interaction() -> void:
	if not level:
		return
	# Check tile type at current position
	if not level.has_method("get_tile_type_at"):
		return
	var tile_type: int = level.get_tile_type_at(world_pos.x, world_pos.y)

	match tile_type:
		TileTypes.TileType.PIT:
			# Fall into pit — take damage and respawn at checkpoint
			if is_on_ground:
				take_damage(1, Vector2.ZERO, self)
				if level and level.has_method("_respawn_player"):
					level._respawn_player(self)
		TileTypes.TileType.BOUNCE:
			velocity.z = TileTypes.get_type_bounce(TileTypes.TileType.BOUNCE)
			is_on_ground = false
			_set_action_state(ActionState.AIRBORNE)
			can_double_jump = true
		TileTypes.TileType.DOOR_OPEN:
			_try_door_transition()
		TileTypes.TileType.DOOR_CLOSED:
			if GameState.keys > 0 and GameState.use_key():
				# Unlock the door in the level's type map
				if level.has_method("unlock_door_at"):
					level.unlock_door_at(world_pos.x, world_pos.y)
				_try_door_transition()
		TileTypes.TileType.CHECKPOINT:
			if level.has_method("activate_checkpoint"):
				level.activate_checkpoint(world_pos)
		TileTypes.TileType.CRUMBLE:
			# Find the tile node and start crumbling
			if level.has_node("Tiles"):
				var tile_pos := Vector2i(int(floor(world_pos.x)), int(floor(world_pos.y)))
				for tile in level.get_node("Tiles").get_children():
					if tile is IsoTile and tile.tile_x == tile_pos.x and tile.tile_y == tile_pos.y:
						tile.start_crumble()
						break

var _door_cooldown: float = 0.0

func _try_door_transition() -> void:
	if _door_cooldown > 0.0:
		return
	if not level or not level.has_method("transition_to_segment"):
		return
	if not level is LevelLoader:
		return
	var loader: LevelLoader = level as LevelLoader
	if not loader.level_data:
		return
	var segment_id := loader.current_segment_id
	if not loader.level_data.segments.has(segment_id):
		return
	var segment: LevelData.SegmentData = loader.level_data.segments[segment_id]
	var tile_pos := Vector2i(int(floor(world_pos.x)), int(floor(world_pos.y)))
	for conn in segment.connections:
		if conn.door_pos == tile_pos:
			_door_cooldown = 0.5
			loader.transition_to_segment(conn.target_segment, conn.target_pos)
			return

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
	if action_state == new_state and _current_state != null:
		return
	if _current_state:
		_current_state.exit(self)
	action_state = new_state
	_current_state = _state_map.get(new_state, null)
	if _current_state:
		_current_state.enter(self)

func take_damage(amount: int, source_dir: Vector2 = Vector2.ZERO, source: Node = null) -> void:
	if (_is_homing_protected() or _is_dash_protected()) and not _is_homing_damage_hazardous(source):
		return
	if invuln_timer > 0.0 or is_dead:
		return
	if is_dashing:
		_end_dash()
	_play_sfx("player_hit")
	GameState.request_camera_shake(2.2, 0.14)
	_apply_squash(Vector2(1.4, 0.6), 0.12)
	hp -= amount
	invuln_timer = invuln_time
	hit_flash_timer = hit_flash_time
	hurt_state_timer = hurt_state_time
	_set_action_state(ActionState.HURT)
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
	if source_dir.length_squared() > 0.0:
		var knock := source_dir.normalized() * knockback_strength
		world_pos.x += knock.x
		world_pos.y += knock.y
	if hp <= 0:
		_die()
		return
	_update_health_bar()

func _is_homing_protected() -> bool:
	return is_homing or homing_invuln_timer > 0.0

func _is_dash_protected() -> bool:
	return is_dashing

func _is_homing_damage_hazardous(source: Node) -> bool:
	if source and _is_node_hazardous(source):
		return true
	if source == null and is_instance_valid(homing_target):
		return _is_node_hazardous(homing_target)
	return false

func _is_node_hazardous(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	if node.is_in_group("hazardous"):
		return true
	if node.has_method("is_hazardous"):
		return node.is_hazardous()
	if node.has_method("get"):
		var hazard_flag: Variant = node.get("hazardous")
		if hazard_flag is bool and hazard_flag:
			return true
	if node.has_method("get_owner_body"):
		var owner_body: Node = node.get_owner_body()
		if owner_body and owner_body != node:
			return _is_node_hazardous(owner_body)
	return false

func _die() -> void:
	is_dead = true
	_end_dash()
	_set_action_state(ActionState.DEAD)
	hp = 0
	_update_health_bar()
	velocity = Vector3.ZERO
	horizontal_velocity = Vector2.ZERO
	_play_sfx("player_die")

	# Brief death visual (flash)
	if sprite:
		sprite.modulate = Color(1, 0.3, 0.3, 0.5)

	# Use a timer to delay respawn
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(_on_death_respawn)

func _on_death_respawn() -> void:
	if not GameState.lose_life():
		# Game over
		if level and level.has_method("show_game_over"):
			level.show_game_over()
		else:
			GameState.go_to_main_menu()
		return

	# Respawn at checkpoint
	is_dead = false
	_end_dash()
	hp = max_hp
	_update_health_bar()
	invuln_timer = invuln_time * 2.0
	hurt_state_timer = 0.0
	velocity = Vector3.ZERO
	horizontal_velocity = Vector2.ZERO
	is_on_ground = true
	_set_action_state(ActionState.GROUNDED)
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)

	# Respawn at level checkpoint
	if level and level.has_method("activate_checkpoint"):
		var loader := level as LevelLoader
		if loader:
			# If checkpoint is in a different segment, transition there
			if loader.last_checkpoint_segment != loader.current_segment_id:
				var cp_tile := Vector2i(int(floor(loader.last_checkpoint_pos.x)), int(floor(loader.last_checkpoint_pos.y)))
				loader.transition_to_segment(loader.last_checkpoint_segment, cp_tile)
			else:
				set_world_pos(loader.last_checkpoint_pos)

func _update_timers(delta: float) -> void:
	if Input.is_action_just_pressed(_jump_action):
		dash_jump_buffer = dash_input_window
	if Input.is_action_just_pressed(_attack_action):
		dash_attack_buffer = dash_input_window
	if dash_jump_buffer > 0.0:
		dash_jump_buffer = maxf(dash_jump_buffer - delta, 0.0)
	if dash_attack_buffer > 0.0:
		dash_attack_buffer = maxf(dash_attack_buffer - delta, 0.0)
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
	if _door_cooldown > 0.0:
		_door_cooldown = maxf(_door_cooldown - delta, 0.0)
	if homing_invuln_timer > 0.0:
		homing_invuln_timer = maxf(homing_invuln_timer - delta, 0.0)
	if hurt_state_timer > 0.0:
		hurt_state_timer = maxf(hurt_state_timer - delta, 0.0)
		if hurt_state_timer == 0.0 and action_state == ActionState.HURT:
			_set_action_state(ActionState.GROUNDED if is_on_ground else ActionState.AIRBORNE)

func _update_health_bar() -> void:
	if health_bar and health_bar.has_method("set_values"):
		health_bar.set_values(hp, max_hp)

func _process_attack(delta: float) -> void:
	if is_dashing:
		return
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
	
	_play_sfx("attack")
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
	_play_sfx("attack_charge")
	
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
		_emit_hit_feedback(0.9)

func _apply_explosive_damage(damage: int, radius: float) -> void:
	_apply_explosive_damage_at(Vector2(world_pos.x, world_pos.y), damage, radius)

func _apply_explosive_damage_at(center: Vector2, damage: int, radius: float) -> void:
	var targets := get_tree().get_nodes_in_group("hurtboxes")
	if targets.is_empty():
		targets = get_tree().get_nodes_in_group("enemies")
	var hit_any: bool = false
	
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
					hit_any = true
			elif target.has_method("take_damage"):
				var dir := Vector2(target_pos.x - center.x, target_pos.y - center.y)
				target.take_damage(damage, dir)
				hit_any = true
	if hit_any:
		_emit_hit_feedback(1.2)

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
