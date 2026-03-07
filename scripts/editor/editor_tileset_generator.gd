@tool
class_name EditorTilesetGenerator
extends Node

## Run this in the editor to generate the tileset for the level editor.
## Attach to any node, check "generate" in Inspector.

@export var generate: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_generate_tileset()
		generate = false

func _generate_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 16)  # Isometric tile size

	# --- Source 0: Tile Types (8 types) ---
	var type_source := TileSetAtlasSource.new()
	var type_img := Image.create(256, 16, false, Image.FORMAT_RGBA8)
	var type_colors := {
		0: Color(0.3, 0.7, 0.3),   # FLOOR - green
		1: Color(0.1, 0.0, 0.15),  # PIT - dark
		2: Color(1.0, 0.8, 0.2),   # BOUNCE - yellow
		3: Color(0.2, 0.5, 0.9),   # CHECKPOINT - blue
		4: Color(0.3, 0.8, 0.3),   # DOOR_OPEN - bright green
		5: Color(0.6, 0.3, 0.15),  # DOOR_CLOSED - brown
		6: Color(0.1, 0.3, 0.8),   # WATER - blue
		7: Color(0.8, 0.9, 1.0),   # ICE - white-blue
	}
	for i in range(8):
		var color: Color = type_colors.get(i, Color.WHITE)
		for y in range(16):
			for x in range(32):
				# Diamond shape
				var cx := x - 16
				var cy := y - 8
				if absf(cx) / 16.0 + absf(cy) / 8.0 <= 1.0:
					type_img.set_pixel(i * 32 + x, y, color)
	type_source.texture = ImageTexture.create_from_image(type_img)
	type_source.texture_region_size = Vector2i(32, 16)
	for i in range(8):
		type_source.create_tile(Vector2i(i, 0))
	ts.add_source(type_source, 0)

	# --- Source 1: Heights (4 values) ---
	var height_source := TileSetAtlasSource.new()
	var height_img := Image.create(128, 16, false, Image.FORMAT_RGBA8)
	var height_colors := {
		0: Color(0.5, 0.5, 0.5, 0.5),  # h=0
		1: Color(0.6, 0.6, 0.4, 0.5),  # h=4
		2: Color(0.7, 0.5, 0.3, 0.5),  # h=8
		3: Color(0.8, 0.4, 0.2, 0.5),  # h=12
	}
	for i in range(4):
		var color: Color = height_colors.get(i, Color.GRAY)
		for y in range(16):
			for x in range(32):
				var cx := x - 16
				var cy := y - 8
				if absf(cx) / 16.0 + absf(cy) / 8.0 <= 1.0:
					height_img.set_pixel(i * 32 + x, y, color)
	height_source.texture = ImageTexture.create_from_image(height_img)
	height_source.texture_region_size = Vector2i(32, 16)
	for i in range(4):
		height_source.create_tile(Vector2i(i, 0))
	ts.add_source(height_source, 1)

	# --- Source 2: Entities (11 types) ---
	var ent_source := TileSetAtlasSource.new()
	var ent_img := Image.create(352, 16, false, Image.FORMAT_RGBA8)
	var ent_colors := {
		0: Color(1.0, 0.9, 0.2),   # pickup - gold
		1: Color(1.0, 0.3, 0.5),   # key - magenta
		2: Color(0.0, 1.0, 0.5),   # goal - green
		3: Color(0.2, 0.6, 1.0),   # checkpoint - blue
		4: Color(0.2, 0.5, 0.9),   # enemy (nibbler) - blue
		5: Color(0.9, 0.8, 0.2),   # ground_enemy - yellow
		6: Color(0.2, 0.8, 0.3),   # hopper - green
		7: Color(0.9, 0.9, 0.1),   # buzzfly - yellow-black
		8: Color(0.8, 0.2, 0.2),   # boss - red
		9: Color(0.1, 0.7, 0.2),   # king_ribbit - dark green
		10: Color(0.3, 0.7, 1.0),  # player_start - cyan
	}
	for i in range(11):
		var color: Color = ent_colors.get(i, Color.WHITE)
		var cx := i * 32 + 16
		var cy := 8
		for y in range(16):
			for x in range(32):
				var d := Vector2(i * 32 + x, y).distance_to(Vector2(cx, cy))
				if d <= 5:
					ent_img.set_pixel(i * 32 + x, y, color)
	ent_source.texture = ImageTexture.create_from_image(ent_img)
	ent_source.texture_region_size = Vector2i(32, 16)
	for i in range(11):
		ent_source.create_tile(Vector2i(i, 0))
	ts.add_source(ent_source, 2)

	# Save
	var err := ResourceSaver.save(ts, "res://resources/editor_tileset.tres")
	if err == OK:
		print("EditorTilesetGenerator: Saved tileset to res://resources/editor_tileset.tres")
	else:
		push_error("EditorTilesetGenerator: Failed to save tileset, error: " + str(err))
