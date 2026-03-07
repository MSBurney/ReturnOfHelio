class_name Hopper
extends Enemy

## Hopper: Ground-based frog enemy that periodically jumps toward the player.

@export var jump_velocity: float = 120.0
@export var jump_interval_min: float = 1.5
@export var jump_interval_max: float = 3.0
@export var jump_move_speed: float = 60.0

var velocity_z: float = 0.0
var is_jumping: bool = false
var jump_timer: float = 0.0
var ground_level: float = 0.0

@onready var hurtbox: Node2D = $Hurtbox

func _ready() -> void:
	float_height = 0.0
	bob_amplitude = 0.0
	max_hp = 1
	score_value = 150
	chase_range = 5.0
	super._ready()
	jump_timer = randf_range(jump_interval_min, jump_interval_max)
	if hurtbox and hurtbox.has_method("set"):
		hurtbox.set("z_offset", 6.0)

func _process(delta: float) -> void:
	_update_timers(delta)
	ground_level = _sample_ground_level_for_state()

	if is_jumping:
		# Apply gravity
		velocity_z -= 350.0 * delta
		world_pos.z += velocity_z * delta
		# Land check
		if world_pos.z <= ground_level:
			world_pos.z = ground_level
			velocity_z = 0.0
			is_jumping = false
			jump_timer = randf_range(jump_interval_min, jump_interval_max)
	else:
		world_pos.z = ground_level
		jump_timer -= delta
		if jump_timer <= 0.0:
			_jump()

	# Contact damage while on ground or jumping
	var player := _find_chase_target()
	if player:
		_try_contact_damage(player)

	_update_screen_position()
	_update_depth_sort()

func _sample_ground_level_for_state() -> float:
	var sampled_ground: float = _ground_height_at(world_pos.x, world_pos.y)
	# While airborne, treat PIT tiles as pass-through so jump arcs can clear pits.
	if is_jumping and level and level.has_method("get_tile_type_at"):
		var tile_type: TileTypes.TileType = level.get_tile_type_at(world_pos.x, world_pos.y)
		if tile_type == TileTypes.TileType.PIT and level.has_method("get_raw_tile_height_at"):
			sampled_ground = level.get_raw_tile_height_at(world_pos.x, world_pos.y)
	return sampled_ground

func _jump() -> void:
	is_jumping = true
	velocity_z = jump_velocity

	# Jump toward nearest player if in range
	var player := _find_chase_target()
	if player and player.has_method("get_world_pos"):
		var p_pos: Vector3 = player.get_world_pos()
		var dir := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y)
		if dir.length_squared() > 0.01:
			var move := dir.normalized() * jump_move_speed * 0.02
			world_pos.x += move.x
			world_pos.y += move.y

func _try_contact_damage(player: Node2D) -> void:
	if contact_timer > 0.0:
		return
	if not player or not player.has_method("get_world_pos"):
		return
	if player.has_method("get"):
		var homing: bool = player.get("is_homing") == true
		if homing:
			return
	var p_pos: Vector3 = player.get_world_pos()
	var dist := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y).length()
	var height_diff := absf(p_pos.z - world_pos.z)
	if dist <= 0.8 and height_diff < 12.0:
		var dir := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y)
		if player.has_method("take_damage"):
			player.take_damage(contact_damage, dir, self)
		contact_timer = contact_cooldown

func _setup_placeholder_sprites() -> void:
	# Green frog-like sprite
	if sprite and sprite.texture == null:
		var img := Image.create(12, 10, false, Image.FORMAT_RGBA8)
		var center := Vector2(6, 5)
		for y in range(10):
			for x in range(12):
				var pos := Vector2(x, y)
				var dist := pos.distance_to(center)
				# Frog body (wide ellipse)
				if (float(x - 6) * float(x - 6)) / 30.0 + (float(y - 5) * float(y - 5)) / 20.0 <= 1.0:
					var shade := 1.0 - (pos.y - 5) * 0.05
					img.set_pixel(x, y, Color(0.15 * shade, 0.7 * shade, 0.2 * shade))
				# Eyes (two dots near top)
				if (x == 3 or x == 8) and y == 2:
					img.set_pixel(x, y, Color(0.9, 0.9, 0.1))
		var tex := ImageTexture.create_from_image(img)
		sprite.texture = tex
		sprite.offset = Vector2(0, -5)

	if shadow and shadow.texture == null:
		var img := Image.create(10, 5, false, Image.FORMAT_RGBA8)
		for y in range(5):
			for x in range(10):
				var cx := x - 5
				var cy := y - 2.5
				if (cx * cx) / 25.0 + (cy * cy) / 6.25 <= 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0.5))
		shadow.texture = ImageTexture.create_from_image(img)
