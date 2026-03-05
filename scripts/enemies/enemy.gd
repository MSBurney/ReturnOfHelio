class_name Enemy
extends IsoEntity

# Enemy properties
@export var float_height: float = 16.0  # Height above ground
@export var bob_amplitude: float = 2.0  # Vertical bob amount
@export var bob_speed: float = 2.0  # Bob cycle speed
@export var max_hp: int = 3
@export var invuln_time: float = 0.25
@export var hit_flash_time: float = 0.1
@export var knockback_strength: float = 1.5

# AI properties
@export var patrol_distance: float = 4.0  # Tiles/world units
@export var patrol_speed: float = 1.5
@export var chase_range: float = 3.0
@export var chase_speed: float = 2.0
@export var contact_damage: int = 1
@export var contact_cooldown: float = 0.6

var base_z: float = 0.0  # Ground level + float_height
var bob_time: float = 0.0
var hp: int = 0
var patrol_origin: Vector2 = Vector2.ZERO
var patrol_forward: bool = true
var invuln_timer: float = 0.0
var hit_flash_timer: float = 0.0
var contact_timer: float = 0.0

# References
@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow
@onready var health_bar: Node2D = $HealthBar

func _ready() -> void:
	super._ready()
	add_to_group("enemies")
	
	_setup_placeholder_sprites()
	_update_screen_position()
	hp = max_hp
	_update_health_bar()

func _setup_placeholder_sprites() -> void:
	# Create enemy sprite (spiky ball)
	if sprite and sprite.texture == null:
		var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
		var center := Vector2(7, 7)
		
		for y in range(14):
			for x in range(14):
				var pos := Vector2(x, y)
				var dist := pos.distance_to(center)
				
				# Main body (circle)
				if dist <= 5.0:
					var shade: float = 1.0 - (pos.x + pos.y - 7) * 0.04
					img.set_pixel(x, y, Color(0.2 * shade, 0.5 * shade, 0.9 * shade))
				# Spikes (simple cross pattern)
				elif (x == 7 and (y <= 2 or y >= 12)) or (y == 7 and (x <= 2 or x >= 12)):
					img.set_pixel(x, y, Color(0.8, 0.3, 0.3))
				# Diagonal spikes
				elif abs(x - 7) == abs(y - 7) and dist >= 5.0 and dist <= 8.0:
					img.set_pixel(x, y, Color(0.8, 0.3, 0.3))
		
		var tex := ImageTexture.create_from_image(img)
		sprite.texture = tex
		sprite.offset = Vector2(0, -7)
	
	# Create shadow sprite
	if shadow and shadow.texture == null:
		var img := Image.create(10, 5, false, Image.FORMAT_RGBA8)
		for y in range(5):
			for x in range(10):
				var cx := x - 5
				var cy := y - 2.5
				if (cx * cx) / 25.0 + (cy * cy) / 6.25 <= 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0.5))
		
		var tex := ImageTexture.create_from_image(img)
		shadow.texture = tex

func _process(delta: float) -> void:
	# Bob up and down
	_update_timers(delta)
	_update_ai(delta)
	var ground_height := _ground_height_at(world_pos.x, world_pos.y)
	base_z = ground_height + float_height
	bob_time += delta * bob_speed
	world_pos.z = base_z + sin(bob_time) * bob_amplitude
	
	_update_screen_position()
	_update_depth_sort()

func _update_screen_position() -> void:
	super._update_screen_position()
	# Update shadow
	_update_shadow(shadow, 48.0, 0.2, 0.5, 1.0, 1.0)

func _update_depth_sort() -> void:
	super._update_depth_sort()

func setup(tile_x: int, tile_y: int, ground_height: float) -> void:
	# Called by level to set initial position
	base_z = ground_height + float_height
	world_pos = Vector3(tile_x + 0.5, tile_y + 0.5, base_z)
	patrol_origin = Vector2(world_pos.x, world_pos.y)
	bob_time = randf() * TAU  # Random starting phase
	_update_screen_position()
	_update_depth_sort()

func take_damage(amount: int, source_dir: Vector2 = Vector2.ZERO) -> void:
	# Called when hit by player
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
	_update_health_bar()
	if hp <= 0:
		queue_free()

func stomp() -> void:
	# Called when player jumps on enemy
	take_damage(1)

func _update_ai(delta: float) -> void:
	var player := _find_chase_target()
	if player:
		_chase_player(player, delta)
		_try_contact_damage(player)
	else:
		_patrol(delta)

func _find_chase_target() -> Node2D:
	var players := get_tree().get_nodes_in_group("players")
	var nearest: Node2D = null
	var nearest_dist := chase_range
	var my_ground := _ground_height_at(world_pos.x, world_pos.y)
	
	for p in players:
		if not is_instance_valid(p):
			continue
		if not p.has_method("get_world_pos"):
			continue
		var p_pos: Vector3 = p.get_world_pos()
		var p_ground := _ground_height_at(p_pos.x, p_pos.y)
		if absf(p_ground - my_ground) > 0.1:
			continue
		var dist := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y).length()
		if dist <= nearest_dist:
			nearest_dist = dist
			nearest = p
	
	return nearest

func _chase_player(player: Node2D, delta: float) -> void:
	var p_pos: Vector3 = player.get_world_pos()
	var to_player := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y)
	if to_player.length_squared() == 0.0:
		return
	var dir := to_player.normalized()
	var move := dir * chase_speed * delta
	world_pos.x += move.x
	world_pos.y += move.y

func _patrol(delta: float) -> void:
	var patrol_min := patrol_origin.x - patrol_distance
	var patrol_max := patrol_origin.x + patrol_distance
	var dir := 1.0 if patrol_forward else -1.0
	world_pos.x += dir * patrol_speed * delta
	
	if world_pos.x >= patrol_max:
		world_pos.x = patrol_max
		patrol_forward = false
	elif world_pos.x <= patrol_min:
		world_pos.x = patrol_min
		patrol_forward = true

func _try_contact_damage(player: Node2D) -> void:
	if contact_timer > 0.0:
		return
	if not player or not player.has_method("get_world_pos"):
		return
	# Flying enemies only damage airborne players
	if player.has_method("get"):
		var grounded: bool = player.get("is_on_ground") == true
		if grounded:
			return
		var homing: bool = player.get("is_homing") == true
		if homing:
			return
	var p_pos: Vector3 = player.get_world_pos()
	var dist := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y).length()
	if dist <= 0.8:
		var dir := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y)
		if player.has_method("take_damage"):
			player.take_damage(contact_damage, dir)
		contact_timer = contact_cooldown

func _update_timers(delta: float) -> void:
	if invuln_timer > 0.0:
		invuln_timer = maxf(invuln_timer - delta, 0.0)
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)
		if hit_flash_timer == 0.0 and sprite:
			sprite.modulate = Color(1, 1, 1, 1)
	if contact_timer > 0.0:
		contact_timer = maxf(contact_timer - delta, 0.0)

func _update_health_bar() -> void:
	if health_bar and health_bar.has_method("set_values"):
		health_bar.set_values(hp, max_hp)
