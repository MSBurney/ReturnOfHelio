class_name IsoUtils
extends RefCounted

# Tile dimensions for 2:1 isometric projection (NES-style)
const TILE_WIDTH: int = 16
const TILE_HEIGHT: int = 8
const TILE_WIDTH_HALF: int = 8
const TILE_HEIGHT_HALF: int = 4

# Convert world coordinates (x, y, z) to screen coordinates
static func world_to_screen(world_pos: Vector3) -> Vector2:
	var screen_x: float = (world_pos.x - world_pos.y) * TILE_WIDTH_HALF
	var screen_y: float = (world_pos.x + world_pos.y) * TILE_HEIGHT_HALF - world_pos.z
	return Vector2(screen_x, screen_y)

# Convert screen coordinates to world coordinates at a given z height
static func screen_to_world(screen_pos: Vector2, z: float = 0.0) -> Vector3:
	var adjusted_screen_y: float = screen_pos.y + z
	var world_x: float = (screen_pos.x / TILE_WIDTH_HALF + adjusted_screen_y / TILE_HEIGHT_HALF) * 0.5
	var world_y: float = (adjusted_screen_y / TILE_HEIGHT_HALF - screen_pos.x / TILE_WIDTH_HALF) * 0.5
	return Vector3(world_x, world_y, z)

# Calculate depth sort value for z-index ordering
# Higher values should render on top (in front)
static func get_depth_sort(world_pos: Vector3) -> float:
	return world_pos.x + world_pos.y + world_pos.z * 0.01

# Convert input direction to world movement direction
# Input is in screen-space (up/down/left/right), output is world-space
# Compensates for isometric projection so screen-space speed is uniform
static func input_to_world_direction(input: Vector2) -> Vector2:
	if input.length_squared() == 0:
		return Vector2.ZERO
	
	var world_x: float = input.x + input.y   # right + down
	var world_y: float = -input.x + input.y  # -right + down
	
	var screen_dx: float = (world_x - world_y) * TILE_WIDTH_HALF
	var screen_dy: float = (world_x + world_y) * TILE_HEIGHT_HALF
	var screen_dir := Vector2(screen_dx, screen_dy)
	
	if screen_dir.length_squared() == 0:
		return Vector2.ZERO
	
	screen_dir = screen_dir.normalized()
	
	var result_world_x: float = screen_dir.x / 16.0 + screen_dir.y / 8.0
	var result_world_y: float = screen_dir.y / 8.0 - screen_dir.x / 16.0
	
	return Vector2(result_world_x, result_world_y)

# Snap a world position to the tile grid
static func snap_to_grid(world_pos: Vector3) -> Vector3:
	return Vector3(
		round(world_pos.x),
		round(world_pos.y),
		world_pos.z
	)

# Get tile coordinates from world position
static func world_to_tile(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x)),
		int(floor(world_pos.y))
	)

# Get world position from tile coordinates (center of tile at given height)
static func tile_to_world(tile_pos: Vector2i, z: float = 0.0) -> Vector3:
	return Vector3(tile_pos.x + 0.5, tile_pos.y + 0.5, z)
