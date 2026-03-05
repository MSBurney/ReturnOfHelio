class_name IsoTile
extends Node2D

# Tile properties
@export var tile_x: int = 0
@export var tile_y: int = 0
@export var tile_height: float = 0.0  # Height in pixels (z offset)

# Visual properties
@export var color_a: Color = Color(0.2, 0.6, 0.2)  # Primary checkerboard color
@export var color_b: Color = Color(0.3, 0.7, 0.3)  # Secondary checkerboard color
@export var side_color: Color = Color(0.15, 0.4, 0.15)  # Side face color

var world_pos: Vector3:
	get:
		return Vector3(tile_x + 0.5, tile_y + 0.5, tile_height)

func _ready() -> void:
	queue_redraw()
	_update_position()
	_update_depth_sort()

func _update_position() -> void:
	# Position at the tile's world coordinates
	var world := Vector3(tile_x, tile_y, tile_height)
	position = IsoUtils.world_to_screen(world)

func _update_depth_sort() -> void:
	z_index = int(IsoUtils.get_depth_sort(Vector3(tile_x, tile_y, tile_height)) * 10)

func _draw() -> void:
	# Determine checkerboard color
	var is_checker := (tile_x + tile_y) % 2 == 0
	var top_color := color_a if is_checker else color_b
	
	# Draw tile top (diamond shape)
	var half_w := IsoUtils.TILE_WIDTH_HALF
	var half_h := IsoUtils.TILE_HEIGHT_HALF
	
	var top_points := PackedVector2Array([
		Vector2(0, -half_h),       # Top
		Vector2(half_w, 0),        # Right
		Vector2(0, half_h),        # Bottom
		Vector2(-half_w, 0)        # Left
	])
	
	# Draw side faces if tile has height
	if tile_height > 0:
		var side_h := tile_height
		var left_side := PackedVector2Array([
			Vector2(-half_w, 0),
			Vector2(0, half_h),
			Vector2(0, half_h + side_h),
			Vector2(-half_w, side_h)
		])
		draw_colored_polygon(left_side, side_color)
		
		var right_side := PackedVector2Array([
			Vector2(0, half_h),
			Vector2(half_w, 0),
			Vector2(half_w, side_h),
			Vector2(0, half_h + side_h)
		])
		draw_colored_polygon(right_side, side_color.darkened(0.2))
	
	# Draw top face
	draw_colored_polygon(top_points, top_color)
	
	# Draw outline
	draw_polyline(top_points + PackedVector2Array([top_points[0]]), Color(0, 0, 0, 0.3), 1.0)

func setup(x: int, y: int, height: float = 0.0, col_a: Color = Color.WHITE, col_b: Color = Color.WHITE) -> void:
	tile_x = x
	tile_y = y
	tile_height = height
	if col_a != Color.WHITE:
		color_a = col_a
	if col_b != Color.WHITE:
		color_b = col_b
	side_color = color_a.darkened(0.4)
	_update_position()
	_update_depth_sort()
	queue_redraw()
