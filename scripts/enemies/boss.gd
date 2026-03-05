class_name Boss
extends Enemy

# Boss behavior
@export var active: bool = false
@export var enable_slam: bool = false
@export var slam_interval: float = 2.5
@export var slam_radius: float = 2.5
@export var slam_damage: int = 2
@export var slam_telegraph_time: float = 0.3
var slam_timer: float = 0.0
var telegraph_timer: float = 0.0
var crash_timer: float = 0.0

# Crash attack
@export var crash_interval: float = 3.0
@export var crash_telegraph_time: float = 0.3
@export var crash_speed: float = 10.0
@export var crash_damage: int = 2
@export var crash_radius: float = 1.0
@export var crash_height: float = 18.0
@export var crash_start_radius: float = 3.0
var crash_active: bool = false
var crash_target: Vector2 = Vector2.ZERO
var crash_state: int = 0 # 0 idle, 1 telegraph, 2 drop, 3 rise

var target_marker: Node2D = null
var flash_sprite: Sprite2D = null

@onready var hurtbox: Node2D = $Hurtbox

func _ready() -> void:
	super._ready()
	# Ensure boss is a flying enemy
	float_height = 24.0
	bob_amplitude = 3.0
	max_hp = max_hp * 4
	hp = max_hp
	_update_health_bar()
	if hurtbox and hurtbox.has_method("set"):
		# Raise target point toward center of sprite
		hurtbox.set("z_offset", 8.0)

func _setup_placeholder_sprites() -> void:
	if sprite and sprite.texture == null:
		var size := 24
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center := Vector2(size * 0.5, size * 0.5)
		for y in range(size):
			for x in range(size):
				var pos := Vector2(x, y)
				var dist := pos.distance_to(center)
				if dist <= 9.0:
					var shade: float = 1.0 - (pos.x + pos.y - center.x) * 0.02
					img.set_pixel(x, y, Color(0.8 * shade, 0.2 * shade, 0.2 * shade))
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
		var img := Image.create(18, 8, false, Image.FORMAT_RGBA8)
		for y in range(8):
			for x in range(18):
				var cx := x - 9
				var cy := y - 4
				if (cx * cx) / 81.0 + (cy * cy) / 16.0 <= 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0.6))
		shadow.texture = ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	# Override Enemy._process to control crash movement/height
	_update_timers(delta)
	_update_ai(delta)
	
	var ground_height := _ground_height_at(world_pos.x, world_pos.y)
	base_z = ground_height + float_height
	
	if crash_state == 2 or crash_state == 3:
		# Crash handles Z movement
		pass
	else:
		bob_time += delta * bob_speed
		world_pos.z = base_z + sin(bob_time) * bob_amplitude
	
	_update_screen_position()
	_update_depth_sort()

func _update_ai(delta: float) -> void:
	if not active:
		return
	
	if enable_slam:
		slam_timer += delta
		if slam_timer >= slam_interval:
			slam_timer = 0.0
			telegraph_timer = slam_telegraph_time
			if sprite:
				sprite.modulate = Color(1.0, 0.9, 0.4, 1.0)
	
	if enable_slam and telegraph_timer > 0.0:
		telegraph_timer = maxf(telegraph_timer - delta, 0.0)
		if telegraph_timer == 0.0:
			_do_slam()
			if sprite:
				sprite.modulate = Color(1, 1, 1, 1)
	
	_update_crash(delta)
	
	var player := _find_chase_target()
	if player:
		if crash_state == 0 or crash_state == 1:
			_chase_player(player, delta)

func activate() -> void:
	active = true

func _do_slam() -> void:
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if not is_instance_valid(p):
			continue
		if not p.has_method("get_world_pos"):
			continue
		var p_pos: Vector3 = p.get_world_pos()
		var dist := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y).length()
		if dist <= slam_radius:
			var dir := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y)
			if p.has_method("take_damage"):
				p.take_damage(slam_damage, dir)

func _update_crash(delta: float) -> void:
	if crash_state == 0:
		crash_timer += delta
		if crash_timer >= crash_interval:
			crash_timer = 0.0
			var target := _find_chase_target()
			if not target:
				return
			var t_pos: Vector3 = target.get_world_pos()
			crash_target = Vector2(t_pos.x, t_pos.y)
			var dist := Vector2(world_pos.x - crash_target.x, world_pos.y - crash_target.y).length()
			if dist <= crash_start_radius:
				crash_state = 1
				crash_active = true
				telegraph_timer = crash_telegraph_time
				_spawn_target_marker()
				_show_flash(true)
			return
	
	if crash_state == 1:
		# Track player during telegraph
		var target := _find_chase_target()
		if target:
			var t_pos: Vector3 = target.get_world_pos()
			crash_target = Vector2(t_pos.x, t_pos.y)
			_update_target_marker()
			var to_target := crash_target - Vector2(world_pos.x, world_pos.y)
			if to_target.length_squared() > 0.01:
				var dir := to_target.normalized()
				world_pos.x += dir.x * crash_speed * delta
				world_pos.y += dir.y * crash_speed * delta
				_update_screen_position()
				_update_depth_sort()
		telegraph_timer = maxf(telegraph_timer - delta, 0.0)
		if telegraph_timer <= 0.0:
			_show_flash(false)
			crash_state = 2
		return
	
	if crash_state == 2:
		# Drop down to ground
		var to_target := crash_target - Vector2(world_pos.x, world_pos.y)
		if to_target.length_squared() > 0.01:
			var dir := to_target.normalized()
			world_pos.x += dir.x * crash_speed * delta
			world_pos.y += dir.y * crash_speed * delta
		var ground := _ground_height_at(world_pos.x, world_pos.y)
		world_pos.z = maxf(world_pos.z - crash_speed * 20.0 * delta, ground)
		_update_screen_position()
		_update_depth_sort()
		if world_pos.z <= ground:
			_do_crash_damage()
			crash_state = 3
		return
	
	if crash_state == 3:
		# Rise back up
		var ground := _ground_height_at(world_pos.x, world_pos.y)
		world_pos.z = minf(world_pos.z + crash_speed * 12.0 * delta, ground + crash_height)
		_update_screen_position()
		_update_depth_sort()
		if world_pos.z >= ground + crash_height:
			crash_state = 0
			crash_active = false
			if sprite:
				sprite.modulate = Color(1, 1, 1, 1)
			_clear_target_marker()

func _do_crash_damage() -> void:
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if not is_instance_valid(p):
			continue
		if not p.has_method("get_world_pos"):
			continue
		var p_pos: Vector3 = p.get_world_pos()
		var dist := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y).length()
		if dist <= crash_radius:
			var dir := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y)
			if p.has_method("take_damage"):
				p.take_damage(crash_damage, dir)

func _try_contact_damage(_player: Node2D) -> void:
	# Boss only damages via slam/crash, not passive contact
	return

func _spawn_target_marker() -> void:
	_clear_target_marker()
	var marker := Node2D.new()
	var sprite_node := Sprite2D.new()
	sprite_node.texture = _create_target_texture()
	sprite_node.z_index = 200
	marker.add_child(sprite_node)
	get_parent().add_child(marker)
	var ground := _ground_height_at(crash_target.x, crash_target.y)
	marker.position = IsoUtils.world_to_screen(Vector3(crash_target.x, crash_target.y, ground + 2.0))
	target_marker = marker

func _update_target_marker() -> void:
	if not target_marker:
		return
	var ground := _ground_height_at(crash_target.x, crash_target.y)
	target_marker.position = IsoUtils.world_to_screen(Vector3(crash_target.x, crash_target.y, ground + 2.0))

func _clear_target_marker() -> void:
	if target_marker:
		target_marker.queue_free()
		target_marker = null

func _create_target_texture() -> ImageTexture:
	var size := 14
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(6.5, 6.5)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x, y).distance_to(center)
			if d >= 4.5 and d <= 6.5:
				img.set_pixel(x, y, Color(1.0, 0.4, 0.4, 0.9))
	return ImageTexture.create_from_image(img)

func _create_flash_texture() -> ImageTexture:
	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	for y in range(size):
		for x in range(size):
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)
			if dist <= 9.0:
				img.set_pixel(x, y, Color(1, 1, 1, 0.9))
	return ImageTexture.create_from_image(img)

func _show_flash(visible: bool) -> void:
	if flash_sprite:
		flash_sprite.visible = visible
