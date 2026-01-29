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
	# For 2:1 isometric projection:
	# - Screen X movement: 8 pixels per world unit (TILE_WIDTH_HALF)
	# - Screen Y movement: 4 pixels per world unit (TILE_HEIGHT_HALF)
	# 
	# To make screen movement feel uniform, we need to scale world movement
	# so that 1 second of input produces equal screen displacement in all directions.
	#
	# Screen UP/DOWN moves along world diagonal (x+y or x-y), affecting screen Y
	# Screen LEFT/RIGHT moves along world diagonal, affecting screen X
	#
	# Raw world directions:
	# UP (input.y = -1):    world (-1, -1) -> screen (0, -8) via projection
	# DOWN (input.y = +1):  world (+1, +1) -> screen (0, +8)
	# LEFT (input.x = -1):  world (-1, +1) -> screen (-16, 0)
	# RIGHT (input.x = +1): world (+1, -1) -> screen (+16, 0)
	#
	# Horizontal screen movement is 2x faster than vertical for same world speed.
	# To equalize: scale horizontal input by 0.5, or scale vertical input by 2.
	# We'll scale the world direction components to achieve uniform screen speed.
	if input.length_squared() == 0:
		return Vector2.ZERO
	
	var world_x: float = input.x + input.y   # right + down
	var world_y: float = -input.x + input.y  # -right + down
	
	# The projection formula:
	# screen_x = (world_x - world_y) * 8
	# screen_y = (world_x + world_y) * 4
	#
	# For pure horizontal input (1, 0): world = (1, -1)
	#   screen_x = (1 - (-1)) * 8 = 16
	#   screen_y = (1 + (-1)) * 4 = 0
	#   screen magnitude = 16
	#
	# For pure vertical input (0, -1): world = (-1, -1)
	#   screen_x = (-1 - (-1)) * 8 = 0
	#   screen_y = (-1 + (-1)) * 4 = -8
	#   screen magnitude = 8
	#
	# To equalize, we want both to produce the same screen magnitude.
	# Scale factor for vertical: 16/8 = 2
	# But we want uniform feel, so let's normalize to screen-space.
	var screen_dx: float = (world_x - world_y) * TILE_WIDTH_HALF
	var screen_dy: float = (world_x + world_y) * TILE_HEIGHT_HALF
	var screen_dir := Vector2(screen_dx, screen_dy)
	
	if screen_dir.length_squared() == 0:
		return Vector2.ZERO
	
	# Normalize in screen space, then convert back to world space
	screen_dir = screen_dir.normalized()
	
	# Inverse projection: screen -> world
	# screen_x = (world_x - world_y) * 8  =>  world_x - world_y = screen_x / 8
	# screen_y = (world_x + world_y) * 4  =>  world_x + world_y = screen_y / 4
	# Adding: 2 * world_x = screen_x/8 + screen_y/4
	# world_x = screen_x/16 + screen_y/8
	# world_y = screen_y/8 - screen_x/16
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
