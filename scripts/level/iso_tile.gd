class_name IsoTile
extends Node2D

# Tile properties
@export var tile_x: int = 0
@export var tile_y: int = 0
@export var tile_height: float = 0.0  # Height in pixels (z offset)
@export var tile_type: TileTypes.TileType = TileTypes.TileType.FLOOR

# Visual properties
@export var color_a: Color = Color(0.2, 0.6, 0.2)  # Primary checkerboard color
@export var color_b: Color = Color(0.3, 0.7, 0.3)  # Secondary checkerboard color
@export var side_color: Color = Color(0.15, 0.4, 0.15)  # Side face color

# Conveyor direction (for CONVEYOR tiles)
var conveyor_direction: Vector2 = Vector2.RIGHT

# Crumble state (for CRUMBLE tiles)
var crumble_timer: float = 0.0
var is_crumbling: bool = false
var is_crumbled: bool = false
const CRUMBLE_TIME: float = 0.8

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

func _process(delta: float) -> void:
	if tile_type == TileTypes.TileType.CRUMBLE and is_crumbling and not is_crumbled:
		crumble_timer += delta
		if crumble_timer >= CRUMBLE_TIME:
			is_crumbled = true
			visible = false

func _draw() -> void:
	if is_crumbled:
		return

	# Determine checkerboard color
	var is_checker := (tile_x + tile_y) % 2 == 0
	var top_color := _get_top_color(is_checker)

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
		var s_color := _get_side_color()
		var left_side := PackedVector2Array([
			Vector2(-half_w, 0),
			Vector2(0, half_h),
			Vector2(0, half_h + side_h),
			Vector2(-half_w, side_h)
		])
		draw_colored_polygon(left_side, s_color)

		var right_side := PackedVector2Array([
			Vector2(0, half_h),
			Vector2(half_w, 0),
			Vector2(half_w, side_h),
			Vector2(0, half_h + side_h)
		])
		draw_colored_polygon(right_side, s_color.darkened(0.2))

	# Draw top face
	draw_colored_polygon(top_points, top_color)

	# Draw type-specific decorations on top
	_draw_type_decoration(top_points, half_w, half_h)

	# Draw outline
	var outline_color := Color(0, 0, 0, 0.3)
	if tile_type == TileTypes.TileType.CRUMBLE and is_crumbling:
		outline_color = Color(1, 0.3, 0, 0.6)
	draw_polyline(top_points + PackedVector2Array([top_points[0]]), outline_color, 1.0)

func _get_top_color(is_checker: bool) -> Color:
	match tile_type:
		TileTypes.TileType.PIT:
			return Color(0.05, 0.02, 0.1) if is_checker else Color(0.08, 0.03, 0.12)
		TileTypes.TileType.WATER:
			return Color(0.1, 0.3, 0.7, 0.8) if is_checker else Color(0.15, 0.35, 0.75, 0.8)
		TileTypes.TileType.LAVA:
			return Color(0.9, 0.3, 0.0) if is_checker else Color(1.0, 0.5, 0.1)
		TileTypes.TileType.ICE:
			return Color(0.7, 0.85, 0.95) if is_checker else Color(0.8, 0.9, 1.0)
		TileTypes.TileType.CONVEYOR:
			return Color(0.4, 0.4, 0.45) if is_checker else Color(0.5, 0.5, 0.55)
		TileTypes.TileType.BOUNCE:
			return Color(0.9, 0.7, 0.1) if is_checker else Color(1.0, 0.8, 0.2)
		TileTypes.TileType.CRUMBLE:
			var base := color_a if is_checker else color_b
			return base.lightened(0.1) if not is_crumbling else Color(0.6, 0.3, 0.1)
		TileTypes.TileType.SWITCH:
			return Color(0.6, 0.2, 0.6) if is_checker else Color(0.7, 0.3, 0.7)
		TileTypes.TileType.DOOR_CLOSED:
			return Color(0.5, 0.3, 0.15) if is_checker else Color(0.6, 0.35, 0.2)
		TileTypes.TileType.DOOR_OPEN:
			return Color(0.3, 0.6, 0.3) if is_checker else Color(0.4, 0.7, 0.4)
		TileTypes.TileType.CHECKPOINT:
			return Color(0.2, 0.5, 0.8) if is_checker else Color(0.3, 0.6, 0.9)
		TileTypes.TileType.COLLECTIBLE:
			return Color(0.8, 0.7, 0.1) if is_checker else Color(0.9, 0.8, 0.2)
		_:
			return color_a if is_checker else color_b

func _get_side_color() -> Color:
	match tile_type:
		TileTypes.TileType.WATER:
			return Color(0.05, 0.15, 0.5, 0.9)
		TileTypes.TileType.LAVA:
			return Color(0.6, 0.1, 0.0)
		TileTypes.TileType.ICE:
			return Color(0.5, 0.7, 0.85)
		TileTypes.TileType.BOUNCE:
			return Color(0.6, 0.5, 0.05)
		TileTypes.TileType.FLOOR, TileTypes.TileType.CHECKPOINT, TileTypes.TileType.COLLECTIBLE:
			# Dirt/earth side for natural tiles
			return Color("4a3420")
		_:
			return side_color

func _draw_type_decoration(top_points: PackedVector2Array, half_w: float, half_h: float) -> void:
	match tile_type:
		TileTypes.TileType.BOUNCE:
			# Draw a small upward arrow
			draw_line(Vector2(0, 1), Vector2(0, -1), Color(1, 1, 1, 0.6), 1.0)
			draw_line(Vector2(-1, 0), Vector2(0, -1), Color(1, 1, 1, 0.6), 1.0)
			draw_line(Vector2(1, 0), Vector2(0, -1), Color(1, 1, 1, 0.6), 1.0)
		TileTypes.TileType.CHECKPOINT:
			# Draw a small dot in the center
			draw_circle(Vector2.ZERO, 1.5, Color(1, 1, 1, 0.7))
		TileTypes.TileType.DOOR_CLOSED:
			# Draw an X mark
			draw_line(Vector2(-2, -1), Vector2(2, 1), Color(0.8, 0.2, 0.2, 0.7), 1.0)
			draw_line(Vector2(2, -1), Vector2(-2, 1), Color(0.8, 0.2, 0.2, 0.7), 1.0)
		TileTypes.TileType.DOOR_OPEN:
			# Draw a circle
			draw_circle(Vector2.ZERO, 1.5, Color(1, 1, 1, 0.5))
		TileTypes.TileType.CONVEYOR:
			# Draw arrow in conveyor direction
			var dir_screen := Vector2(conveyor_direction.x - conveyor_direction.y, (conveyor_direction.x + conveyor_direction.y) * 0.5).normalized() * 2.0
			draw_line(-dir_screen, dir_screen, Color(0.8, 0.8, 0.2, 0.6), 1.0)
		TileTypes.TileType.SWITCH:
			# Draw a small diamond
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -1.5), Vector2(1.5, 0), Vector2(0, 1.5), Vector2(-1.5, 0)
			]), Color(1.0, 0.9, 0.3, 0.7))

func start_crumble() -> void:
	if tile_type == TileTypes.TileType.CRUMBLE and not is_crumbling:
		is_crumbling = true
		crumble_timer = 0.0
		queue_redraw()

func reset_crumble() -> void:
	is_crumbling = false
	is_crumbled = false
	crumble_timer = 0.0
	visible = true
	queue_redraw()

func setup(x: int, y: int, height: float = 0.0, col_a: Color = Color.WHITE, col_b: Color = Color.WHITE, type: TileTypes.TileType = TileTypes.TileType.FLOOR) -> void:
	tile_x = x
	tile_y = y
	tile_height = height
	tile_type = type
	if col_a != Color.WHITE:
		color_a = col_a
	if col_b != Color.WHITE:
		color_b = col_b
	side_color = color_a.darkened(0.4)
	_update_position()
	_update_depth_sort()
	queue_redraw()
