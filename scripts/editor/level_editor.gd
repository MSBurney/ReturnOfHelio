@tool
class_name LevelEditor
extends Node2D

## Tilemap-based level editor for ReturnOfHelio.
##
## HOW TO USE:
## 1. Open scenes/editor/level_editor.tscn in the Godot editor
## 2. Select the TileMap node to paint tiles using Godot's tile painting tools
## 3. Layer 0 = Tile Types (paint different tile types)
## 4. Layer 1 = Heights (paint height values: 0, 4, 8, 12)
## 5. Layer 2 = Entities (paint enemy/pickup/goal markers)
## 6. Fill in the export settings in the Inspector
## 7. Check "do_export" to generate the JSON file
##
## TILE IDS (Layer 0 - Types):
##   0 = FLOOR, 1 = PIT, 2 = BOUNCE, 3 = CHECKPOINT,
##   4 = DOOR_OPEN, 5 = DOOR_CLOSED, 6 = WATER, 7 = ICE
##
## TILE IDS (Layer 1 - Heights):
##   0 = height 0, 1 = height 4, 2 = height 8, 3 = height 12
##
## TILE IDS (Layer 2 - Entities):
##   0 = pickup, 1 = key, 2 = goal, 3 = checkpoint,
##   4 = enemy (nibbler), 5 = ground_enemy, 6 = enemy_hopper,
##   7 = enemy_buzzfly, 8 = boss, 9 = boss_king_ribbit,
##   10 = player_start

# Export settings
@export_category("Level Settings")
@export var level_id: String = "w1_l01"
@export var world: int = 1
@export var level_number: int = 1
@export var level_name: String = "Unnamed Level"

@export_category("Segment Settings")
@export var segment_id: String = "start"
@export var segment_width: int = 16
@export var segment_height: int = 12

@export_category("Export")
@export var export_path: String = "res://data/levels/world1/"
@export var do_export: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_export_to_json()
		do_export = false

@export_category("Multi-Segment")
@export var segments_to_combine: Array[String] = []
@export var do_export_combined: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_export_combined_level()
		do_export_combined = false

const TYPE_NAMES := {
	0: "FLOOR",
	1: "PIT",
	2: "BOUNCE",
	3: "CHECKPOINT",
	4: "DOOR_OPEN",
	5: "DOOR_CLOSED",
	6: "WATER",
	7: "ICE",
}

const HEIGHT_VALUES := {
	0: 0,
	1: 4,
	2: 8,
	3: 12,
}

const ENTITY_NAMES := {
	0: "pickup",
	1: "key",
	2: "goal",
	3: "checkpoint",
	4: "enemy",
	5: "ground_enemy",
	6: "enemy_hopper",
	7: "enemy_buzzfly",
	8: "boss",
	9: "boss_king_ribbit",
	10: "player_start",
}

func _export_to_json() -> void:
	var tilemap: TileMapLayer = _find_tilemap_layer(0)
	if not tilemap:
		push_error("LevelEditor: No TileMapLayer found for layer 0")
		return

	var height_layer: TileMapLayer = _find_tilemap_layer(1)
	var entity_layer: TileMapLayer = _find_tilemap_layer(2)

	var segment := _build_segment(tilemap, height_layer, entity_layer)

	# Find player start
	var start_pos := Vector2i(2, 5)
	if entity_layer:
		for cell in entity_layer.get_used_cells():
			var atlas := entity_layer.get_cell_atlas_coords(cell)
			if atlas.x == 10:  # player_start
				start_pos = cell

	var level_dict := {
		"level_id": level_id,
		"world": world,
		"level": level_number,
		"name": level_name,
		"start_segment": segment_id,
		"start_position": [start_pos.x, start_pos.y],
		"collectibles": {"keys": 0, "secrets": 0, "coins": 0},
		"segments": [segment]
	}

	var json_str := JSON.stringify(level_dict, "    ")
	var file_path := export_path + level_id + ".json"
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		print("LevelEditor: Exported to " + file_path)
	else:
		push_error("LevelEditor: Failed to write to " + file_path)

func _export_combined_level() -> void:
	# For multi-segment levels, combine multiple saved segment JSONs
	# Each segment should be saved individually first, then this combines them
	push_warning("LevelEditor: Combined export not yet implemented. Export each segment individually and combine the JSON manually, or use a single segment per editor scene.")

func _build_segment(tilemap: TileMapLayer, height_layer: TileMapLayer, entity_layer: TileMapLayer) -> Dictionary:
	var tiles: Array = []
	var entities: Array = []
	var connections: Array = []

	# Process tile cells
	var used_cells := tilemap.get_used_cells()
	for cell in used_cells:
		if cell.x < 0 or cell.x >= segment_width or cell.y < 0 or cell.y >= segment_height:
			continue

		var atlas := tilemap.get_cell_atlas_coords(cell)
		var type_id := atlas.x  # Use atlas x coordinate as type ID
		var type_name: String = TYPE_NAMES.get(type_id, "FLOOR")

		# Get height from height layer
		var height: int = 0
		if height_layer:
			var h_atlas := height_layer.get_cell_atlas_coords(cell)
			if h_atlas != Vector2i(-1, -1):
				height = HEIGHT_VALUES.get(h_atlas.x, 0)

		tiles.append({"x": cell.x, "y": cell.y, "type": type_name, "height": height})

	# Process entity cells
	if entity_layer:
		for cell in entity_layer.get_used_cells():
			var atlas := entity_layer.get_cell_atlas_coords(cell)
			var entity_id := atlas.x
			if entity_id == 10:  # player_start — not an entity
				continue
			var entity_name: String = ENTITY_NAMES.get(entity_id, "pickup")
			entities.append({"type": entity_name, "x": cell.x, "y": cell.y})

	return {
		"id": segment_id,
		"width": segment_width,
		"height": segment_height,
		"tiles": tiles,
		"entities": entities,
		"connections": connections
	}

func _find_tilemap_layer(index: int) -> TileMapLayer:
	# Find TileMapLayer children by order
	var count := 0
	for child in get_children():
		if child is TileMapLayer:
			if count == index:
				return child
			count += 1
	return null

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# Draw grid overlay in editor
	var half_w := 16  # IsoUtils.TILE_WIDTH_HALF
	var half_h := 8   # IsoUtils.TILE_HEIGHT_HALF
	var grid_color := Color(1, 1, 1, 0.1)
	for x in range(segment_width + 1):
		for y in range(segment_height + 1):
			# Draw grid lines
			var screen := Vector2((x - y) * half_w, (x + y) * half_h)
			if x < segment_width:
				var next := Vector2((x + 1 - y) * half_w, (x + 1 + y) * half_h)
				draw_line(screen, next, grid_color, 1.0)
			if y < segment_height:
				var next := Vector2((x - y - 1) * half_w, (x + y + 1) * half_h)
				draw_line(screen, next, grid_color, 1.0)
