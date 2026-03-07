class_name KingRibbit
extends Boss

## World 1 Boss: King Ribbit
## Phase 1: Tongue lash (ranged linear attack)
## Phase 2: Belly flop (jump + crash) + tongue
## Phase 3: Spawn Hopper minions + combined attacks

const HopperScene := preload("res://scenes/enemies/hopper.tscn")

# Tongue attack
@export var tongue_interval: float = 2.0
@export var tongue_telegraph_time: float = 0.4
@export var tongue_range: float = 4.0
@export var tongue_damage: int = 1
@export var tongue_width: float = 0.6
var tongue_timer: float = 0.0
var tongue_telegraph: float = 0.0
var tongue_active: bool = false
var tongue_dir: Vector2 = Vector2.ZERO
var tongue_display_timer: float = 0.0
var tongue_line: Node2D = null

# Belly flop (uses crash system from Boss)
var flop_enabled: bool = false

# Minion spawning
@export var spawn_interval: float = 8.0
@export var max_minions: int = 3
var spawn_timer: float = 0.0
var spawn_enabled: bool = false
var spawned_minions: Array[Node2D] = []

func _ready() -> void:
	max_phases = 3
	max_hp = 6
	float_height = 0.0
	bob_amplitude = 0.0
	chase_speed = 1.2
	chase_range = 8.0
	crash_interval = 4.0
	crash_telegraph_time = 0.5
	crash_speed = 8.0
	crash_damage = 2
	crash_radius = 1.5
	crash_height = 20.0
	crash_start_radius = 6.0
	score_value = 1000
	contact_damage = 1
	super._ready()

func _on_phase_change(phase: int) -> void:
	if phase == 2:
		flop_enabled = true
		crash_interval = 3.5
		tongue_interval = 1.5
		# Flash to indicate phase change
		if sprite:
			sprite.modulate = Color(1.0, 0.6, 0.6, 1.0)
			var tween := create_tween()
			tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.5)
	elif phase == 3:
		spawn_enabled = true
		flop_enabled = true
		crash_interval = 3.0
		tongue_interval = 1.2
		if sprite:
			sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
			var tween := create_tween()
			tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.5)

func _process(delta: float) -> void:
	_update_timers(delta)
	_update_ai(delta)

	var ground_height := _flying_ground_height_at(world_pos.x, world_pos.y)
	base_z = ground_height + float_height

	if crash_state == 2 or crash_state == 3:
		pass
	else:
		bob_time += delta * bob_speed
		world_pos.z = base_z + sin(bob_time) * bob_amplitude

	_update_screen_position()
	_update_depth_sort()

	# Tongue display
	if tongue_display_timer > 0.0:
		tongue_display_timer -= delta
		if tongue_display_timer <= 0.0:
			_clear_tongue_line()

func _update_ai(delta: float) -> void:
	if not active:
		return

	# Tongue attack
	_update_tongue(delta)

	# Belly flop (reuse crash system)
	if flop_enabled:
		_update_crash(delta)

	# Minion spawning
	if spawn_enabled:
		_update_spawning(delta)

	# Chase player (slower, ground-based)
	var player := _find_chase_target()
	if player:
		if crash_state == 0 or crash_state == 1:
			_chase_player(player, delta)

func _update_tongue(delta: float) -> void:
	if tongue_telegraph > 0.0:
		tongue_telegraph -= delta
		if tongue_telegraph <= 0.0:
			_do_tongue_attack()
		return

	tongue_timer += delta
	if tongue_timer >= tongue_interval:
		tongue_timer = 0.0
		var target := _find_chase_target()
		if not target:
			return
		var t_pos: Vector3 = target.get_world_pos()
		var dist := Vector2(t_pos.x - world_pos.x, t_pos.y - world_pos.y).length()
		if dist <= tongue_range:
			tongue_dir = Vector2(t_pos.x - world_pos.x, t_pos.y - world_pos.y).normalized()
			tongue_telegraph = tongue_telegraph_time
			# Telegraph: turn red-ish
			if sprite:
				sprite.modulate = Color(1.0, 0.7, 0.7, 1.0)

func _do_tongue_attack() -> void:
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
	tongue_active = true
	# Show tongue line
	_spawn_tongue_line()
	tongue_display_timer = 0.2
	# Check damage along the tongue line
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if not is_instance_valid(p) or not p.has_method("get_world_pos"):
			continue
		var p_pos: Vector3 = p.get_world_pos()
		var to_player := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y)
		var proj := to_player.dot(tongue_dir)
		if proj < 0.0 or proj > tongue_range:
			continue
		var perp := absf(to_player.cross(tongue_dir))
		if perp <= tongue_width:
			if p.has_method("take_damage"):
				p.take_damage(tongue_damage, tongue_dir, self)
	tongue_active = false

func _spawn_tongue_line() -> void:
	_clear_tongue_line()
	tongue_line = Node2D.new()
	tongue_line.z_index = 150
	get_parent().add_child(tongue_line)
	# Draw tongue as a series of small sprites along the line
	var start_screen := IsoUtils.world_to_screen(world_pos)
	var end_world := Vector3(world_pos.x + tongue_dir.x * tongue_range, world_pos.y + tongue_dir.y * tongue_range, world_pos.z)
	var end_screen := IsoUtils.world_to_screen(end_world)
	var steps := 8
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var pos := start_screen.lerp(end_screen, t)
		var dot := Sprite2D.new()
		var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.9, 0.3, 0.4, 0.9))
		dot.texture = ImageTexture.create_from_image(img)
		dot.position = pos
		tongue_line.add_child(dot)

func _clear_tongue_line() -> void:
	if tongue_line:
		tongue_line.queue_free()
		tongue_line = null

func _update_spawning(delta: float) -> void:
	# Clean dead minions
	spawned_minions = spawned_minions.filter(func(m): return is_instance_valid(m))
	if spawned_minions.size() >= max_minions:
		return
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_hopper()

func _spawn_hopper() -> void:
	var hopper := HopperScene.instantiate()
	# Spawn near boss with offset
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * 2.0
	var ground := _ground_height_at(world_pos.x + offset.x, world_pos.y + offset.y)
	hopper.setup(int(world_pos.x + offset.x), int(world_pos.y + offset.y), ground)
	get_parent().add_child(hopper)
	spawned_minions.append(hopper)

func _try_contact_damage(player: Node2D) -> void:
	# King Ribbit does contact damage when on ground
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
	if dist <= 1.2 and height_diff < 12.0:
		var dir := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y)
		if player.has_method("take_damage"):
			player.take_damage(contact_damage, dir, self)
		contact_timer = contact_cooldown

func _setup_placeholder_sprites() -> void:
	# Large green frog boss sprite (24x24)
	if sprite and sprite.texture == null:
		var size := 24
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center := Vector2(size * 0.5, size * 0.5)
		for y in range(size):
			for x in range(size):
				var pos := Vector2(x, y)
				# Wide frog body (ellipse)
				var ex := (pos.x - center.x) / 11.0
				var ey := (pos.y - center.y) / 9.0
				if ex * ex + ey * ey <= 1.0:
					var shade := 1.0 - (pos.y - center.y) * 0.03
					# Belly (lighter green on bottom half)
					if pos.y > center.y + 2:
						img.set_pixel(x, y, Color(0.3 * shade, 0.75 * shade, 0.2 * shade))
					else:
						img.set_pixel(x, y, Color(0.15 * shade, 0.6 * shade, 0.12 * shade))
				# Crown (golden, on top)
				if y >= 1 and y <= 4:
					if (x >= 7 and x <= 16):
						# Crown base
						if y == 4:
							img.set_pixel(x, y, Color(0.95, 0.8, 0.15))
						# Crown spikes
						elif y <= 3 and (x == 8 or x == 11 or x == 15):
							img.set_pixel(x, y, Color(0.95, 0.8, 0.15))
						elif y <= 2 and (x == 8 or x == 11 or x == 15):
							img.set_pixel(x, y, Color(1.0, 0.85, 0.2))
				# Eyes (big bulging frog eyes)
				var eye_l := Vector2(7, 7)
				var eye_r := Vector2(16, 7)
				if pos.distance_to(eye_l) <= 2.5 or pos.distance_to(eye_r) <= 2.5:
					img.set_pixel(x, y, Color(0.95, 0.95, 0.3))
				if pos.distance_to(eye_l) <= 1.0 or pos.distance_to(eye_r) <= 1.0:
					img.set_pixel(x, y, Color(0.1, 0.1, 0.1))
				# Mouth line
				if y == 15 and x >= 8 and x <= 15:
					img.set_pixel(x, y, Color(0.6, 0.15, 0.15))
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.offset = Vector2(0, -12)
		# Flash overlay
		flash_sprite = Sprite2D.new()
		flash_sprite.texture = _create_flash_texture()
		flash_sprite.offset = Vector2(0, -12)
		flash_sprite.z_index = 1
		flash_sprite.visible = false
		add_child(flash_sprite)

	if shadow and shadow.texture == null:
		var img := Image.create(22, 10, false, Image.FORMAT_RGBA8)
		for y in range(10):
			for x in range(22):
				var cx := x - 11
				var cy := y - 5
				if (cx * cx) / 121.0 + (cy * cy) / 25.0 <= 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0.6))
		shadow.texture = ImageTexture.create_from_image(img)
