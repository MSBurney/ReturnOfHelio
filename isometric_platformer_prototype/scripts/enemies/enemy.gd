class_name Enemy
extends Node2D

# Enemy properties
@export var float_height: float = 16.0  # Height above ground
@export var bob_amplitude: float = 2.0  # Vertical bob amount
@export var bob_speed: float = 2.0  # Bob cycle speed

# World position
var world_pos: Vector3 = Vector3.ZERO
var base_z: float = 0.0  # Ground level + float_height
var bob_time: float = 0.0

# References
@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow

# Level reference
var level: Node = null

func _ready() -> void:
	add_to_group("enemies")
	
	# Find level in parent hierarchy
	level = get_parent()
	while level and not level.has_method("get_tile_height_at"):
		level = level.get_parent()
	
	_setup_placeholder_sprites()
	_update_screen_position()

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
	bob_time += delta * bob_speed
	world_pos.z = base_z + sin(bob_time) * bob_amplitude
	
	_update_screen_position()
	_update_depth_sort()

func _update_screen_position() -> void:
	position = IsoUtils.world_to_screen(world_pos)
	
	# Update shadow
	if shadow:
		var ground_height: float = 0.0
		if level and level.has_method("get_tile_height_at"):
			ground_height = level.get_tile_height_at(world_pos.x, world_pos.y)
		
		var shadow_world_pos := Vector3(world_pos.x, world_pos.y, ground_height)
		shadow.global_position = IsoUtils.world_to_screen(shadow_world_pos)
		shadow.z_index = z_index - 1
		
		# Fade based on height
		var height_diff: float = world_pos.z - ground_height
		shadow.modulate.a = clampf(1.0 - (height_diff / 48.0), 0.2, 0.5)

func _update_depth_sort() -> void:
	z_index = int(IsoUtils.get_depth_sort(world_pos) * 10)

# Called by level to set initial position
func setup(tile_x: int, tile_y: int, ground_height: float) -> void:
	base_z = ground_height + float_height
	world_pos = Vector3(tile_x + 0.5, tile_y + 0.5, base_z)
	bob_time = randf() * TAU  # Random starting phase
	_update_screen_position()
	_update_depth_sort()

# Public getter for homing attack targeting
func get_world_pos() -> Vector3:
	return world_pos

# Called when hit by player
func take_damage(_amount: int) -> void:
	# Simple death - just remove
	queue_free()

# Called when player jumps on enemy
func stomp() -> void:
	queue_free()
