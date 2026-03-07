class_name LevelData
extends RefCounted

## Parses and holds level data loaded from JSON files.

# Level metadata
var level_id: String = ""
var world: int = 1
var level: int = 1
var level_name: String = ""

# Segments
var segments: Dictionary = {}  # segment_id -> SegmentData
var start_segment: String = "start"
var start_position: Vector2i = Vector2i(3, 3)

# Collectible counts (for validation/display)
var total_keys: int = 0
var total_secrets: int = 0
var total_coins: int = 0

## Segment data container
class SegmentData:
	var id: String = ""
	var width: int = 16
	var height: int = 16
	var tiles: Array[TileEntry] = []
	var entities: Array[EntityEntry] = []
	var connections: Array[ConnectionEntry] = []

## Individual tile entry
class TileEntry:
	var x: int = 0
	var y: int = 0
	var type: TileTypes.TileType = TileTypes.TileType.FLOOR
	var height: float = 0.0
	var properties: Dictionary = {}

## Entity spawn entry
class EntityEntry:
	var type: String = ""
	var x: int = 0
	var y: int = 0
	var properties: Dictionary = {}

## Door/connection between segments
class ConnectionEntry:
	var door_pos: Vector2i = Vector2i.ZERO
	var target_segment: String = ""
	var target_pos: Vector2i = Vector2i.ZERO
	var requires_key: bool = false

## Load level data from a JSON file path (res:// path)
static func load_from_file(path: String) -> LevelData:
	if not FileAccess.file_exists(path):
		push_error("LevelData: File not found: " + path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("LevelData: Cannot open file: " + path)
		return null

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		push_error("LevelData: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return null

	var data: Dictionary = json.data
	return _parse_level(data)

## Parse a level dictionary into LevelData
static func _parse_level(data: Dictionary) -> LevelData:
	var level_data := LevelData.new()

	level_data.level_id = data.get("level_id", "")
	level_data.world = data.get("world", 1)
	level_data.level = data.get("level", 1)
	level_data.level_name = data.get("name", "Unnamed")
	level_data.start_segment = data.get("start_segment", "start")

	var start_pos: Array = data.get("start_position", [3, 3])
	level_data.start_position = Vector2i(int(start_pos[0]), int(start_pos[1]))

	var collectibles: Dictionary = data.get("collectibles", {})
	level_data.total_keys = collectibles.get("keys", 0)
	level_data.total_secrets = collectibles.get("secrets", 0)
	level_data.total_coins = collectibles.get("coins", 0)

	# Parse segments
	var segments_array: Array = data.get("segments", [])
	for seg_dict: Dictionary in segments_array:
		var segment := _parse_segment(seg_dict)
		level_data.segments[segment.id] = segment

	return level_data

## Parse a single segment dictionary
static func _parse_segment(data: Dictionary) -> SegmentData:
	var segment := SegmentData.new()
	segment.id = data.get("id", "")
	segment.width = data.get("width", 16)
	segment.height = data.get("height", 16)

	# Parse tiles
	var tiles_array: Array = data.get("tiles", [])
	for tile_dict: Dictionary in tiles_array:
		var tile := TileEntry.new()
		tile.x = tile_dict.get("x", 0)
		tile.y = tile_dict.get("y", 0)
		tile.type = TileTypes.from_string(tile_dict.get("type", "FLOOR"))
		tile.height = tile_dict.get("height", 0.0)
		tile.properties = tile_dict.get("properties", {})
		segment.tiles.append(tile)

	# Parse entities
	var entities_array: Array = data.get("entities", [])
	for ent_dict: Dictionary in entities_array:
		var entity := EntityEntry.new()
		entity.type = ent_dict.get("type", "")
		entity.x = ent_dict.get("x", 0)
		entity.y = ent_dict.get("y", 0)
		entity.properties = ent_dict.get("properties", {})
		segment.entities.append(entity)

	# Parse connections
	var connections_array: Array = data.get("connections", [])
	for conn_dict: Dictionary in connections_array:
		var conn := ConnectionEntry.new()
		var door_pos: Array = conn_dict.get("door_pos", [0, 0])
		conn.door_pos = Vector2i(int(door_pos[0]), int(door_pos[1]))
		conn.target_segment = conn_dict.get("target_segment", "")
		var target_pos: Array = conn_dict.get("target_pos", [0, 0])
		conn.target_pos = Vector2i(int(target_pos[0]), int(target_pos[1]))
		conn.requires_key = conn_dict.get("requires_key", false)
		segment.connections.append(conn)

	return segment

## Build a height map dictionary from a segment's tile data
func get_segment_height_map(segment_id: String) -> Dictionary:
	var height_map: Dictionary = {}
	if not segments.has(segment_id):
		return height_map

	var segment: SegmentData = segments[segment_id]

	# Fill with default floor at height 0
	for x in range(segment.width):
		for y in range(segment.height):
			height_map[Vector2i(x, y)] = 0.0

	# Override with actual tile data
	for tile in segment.tiles:
		height_map[Vector2i(tile.x, tile.y)] = tile.height

	return height_map

## Build a tile type map from a segment's tile data
func get_segment_type_map(segment_id: String) -> Dictionary:
	var type_map: Dictionary = {}
	if not segments.has(segment_id):
		return type_map

	var segment: SegmentData = segments[segment_id]

	# Fill with default FLOOR
	for x in range(segment.width):
		for y in range(segment.height):
			type_map[Vector2i(x, y)] = TileTypes.TileType.FLOOR

	# Override with actual tile data
	for tile in segment.tiles:
		type_map[Vector2i(tile.x, tile.y)] = tile.type

	return type_map

## Get the path for a level JSON file
static func get_level_path(world_num: int, level_num: int) -> String:
	return "res://data/levels/world%d/w%d_l%02d.json" % [world_num, world_num, level_num]

## Get the path for a boss level JSON file
static func get_boss_level_path(world_num: int) -> String:
	return "res://data/levels/world%d/w%d_boss.json" % [world_num, world_num]
