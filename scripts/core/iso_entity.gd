class_name IsoEntity
extends Node2D

# World position (logical coordinates)
var world_pos: Vector3 = Vector3.ZERO

# Level reference for collision/height queries
var level: Node = null

func _ready() -> void:
	# Find level in parent hierarchy
	level = _find_level()

func _find_level() -> Node:
	var node := get_parent()
	while node and not node.has_method("get_tile_height_at"):
		node = node.get_parent()
	return node

func _ground_height_at(x: float, y: float) -> float:
	if level and level.has_method("get_tile_height_at"):
		return level.get_tile_height_at(x, y)
	return 0.0

func _update_screen_position() -> void:
	# Convert world position to screen coordinates
	position = IsoUtils.world_to_screen(world_pos)

func _update_depth_sort() -> void:
	# Higher values render on top (in front)
	z_index = int(IsoUtils.get_depth_sort(world_pos) * 10)

func _update_shadow(shadow: Sprite2D, max_height: float, min_alpha: float, max_alpha: float, min_scale: float, max_scale: float) -> void:
	# Update shadow position, fade, and scale based on height above ground
	if not shadow:
		return
	
	var ground_height: float = _ground_height_at(world_pos.x, world_pos.y)
	var shadow_world_pos := Vector3(world_pos.x, world_pos.y, ground_height)
	var shadow_screen_pos := IsoUtils.world_to_screen(shadow_world_pos)
	shadow.global_position = shadow_screen_pos
	shadow.z_index = z_index - 1
	
	var height_diff: float = world_pos.z - ground_height
	var alpha: float = clampf(1.0 - (height_diff / max_height), min_alpha, max_alpha)
	shadow.modulate.a = alpha
	
	var scale_factor: float = clampf(1.0 - (height_diff / (max_height * 2.0)), min_scale, max_scale)
	shadow.scale = Vector2(scale_factor, scale_factor)

func get_world_pos() -> Vector3:
	# Public getter for homing/targeting
	return world_pos

func set_world_pos(pos: Vector3) -> void:
	# Set world position and refresh screen/depth state
	world_pos = pos
	_update_screen_position()
	_update_depth_sort()
