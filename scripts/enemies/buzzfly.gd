class_name Buzzfly
extends Enemy

## Buzzfly: Flying enemy that moves in a sine wave pattern. Does NOT chase.

@export var wave_amplitude: float = 3.0   # World units side-to-side
@export var wave_frequency: float = 1.5   # Cycles per second
@export var fly_speed: float = 1.0        # Forward movement speed

var wave_time: float = 0.0
var fly_direction: Vector2 = Vector2(1, 0)  # Movement axis

func _ready() -> void:
	float_height = 20.0
	bob_amplitude = 1.0
	bob_speed = 3.0
	max_hp = 1
	score_value = 100
	chase_range = 0.0  # Does NOT chase
	super._ready()
	wave_time = randf() * TAU
	# Randomize flight direction
	var angle := randf() * TAU
	fly_direction = Vector2(cos(angle), sin(angle))

func _process(delta: float) -> void:
	_update_timers(delta)

	# Sine wave movement
	wave_time += delta * wave_frequency * TAU
	var forward := fly_direction * fly_speed * delta
	var lateral := Vector2(-fly_direction.y, fly_direction.x) * sin(wave_time) * wave_amplitude * delta

	var new_x := world_pos.x + forward.x + lateral.x
	var new_y := world_pos.y + forward.y + lateral.y

	# Bounce off patrol bounds
	var dist_from_origin := Vector2(new_x - patrol_origin.x, new_y - patrol_origin.y).length()
	if dist_from_origin > patrol_distance:
		fly_direction = -fly_direction
		new_x = world_pos.x
		new_y = world_pos.y

	world_pos.x = new_x
	world_pos.y = new_y

	# Vertical bob (use flying-safe ground sampling so PIT tiles do not pull fliers down)
	var ground_height := _flying_ground_height_at(world_pos.x, world_pos.y)
	base_z = ground_height + float_height
	bob_time += delta * bob_speed
	world_pos.z = base_z + sin(bob_time) * bob_amplitude

	# Contact damage (flying enemy - only hits airborne players)
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if is_instance_valid(p):
			_try_contact_damage(p)

	_update_screen_position()
	_update_depth_sort()

func _setup_placeholder_sprites() -> void:
	# Yellow/black insect sprite
	if sprite and sprite.texture == null:
		var img := Image.create(12, 10, false, Image.FORMAT_RGBA8)
		var center := Vector2(6, 5)
		for y in range(10):
			for x in range(12):
				var pos := Vector2(x, y)
				var dist := pos.distance_to(center)
				# Body (oval)
				if dist <= 4.0:
					# Striped yellow/black pattern
					var stripe := int(y) % 3
					if stripe == 0:
						img.set_pixel(x, y, Color(0.1, 0.1, 0.1))
					else:
						img.set_pixel(x, y, Color(0.9, 0.8, 0.1))
				# Wings (left and right)
				elif (x <= 3 or x >= 9) and y >= 2 and y <= 5:
					var wing_dist := Vector2(x, y).distance_to(Vector2(2 if x <= 3 else 10, 3))
					if wing_dist <= 2.5:
						img.set_pixel(x, y, Color(0.8, 0.9, 1.0, 0.6))
		var tex := ImageTexture.create_from_image(img)
		sprite.texture = tex
		sprite.offset = Vector2(0, -5)

	if shadow and shadow.texture == null:
		var img := Image.create(8, 4, false, Image.FORMAT_RGBA8)
		for y in range(4):
			for x in range(8):
				var cx := x - 4
				var cy := y - 2
				if (cx * cx) / 16.0 + (cy * cy) / 4.0 <= 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0.4))
		shadow.texture = ImageTexture.create_from_image(img)
