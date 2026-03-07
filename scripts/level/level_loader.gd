class_name LevelLoader
extends Node2D

## Data-driven level loader that replaces the monolithic test_level.gd.
## Loads level geometry and entities from JSON via LevelData.

const IsoTileScript := preload("res://scripts/level/iso_tile.gd")
const EnemyScene := preload("res://scenes/enemies/enemy.tscn")
const PlayerScene := preload("res://scenes/player/player.tscn")
const PickupScene := preload("res://scenes/level/pickup.tscn")
const BossScene := preload("res://scenes/enemies/boss.tscn")
const GroundEnemyScene := preload("res://scenes/enemies/ground_enemy.tscn")
const StartMarkerScene := preload("res://scenes/level/start_marker.tscn")
const GateMarkerScene := preload("res://scenes/level/gate_marker.tscn")
const CheckpointScene := preload("res://scenes/level/checkpoint.tscn")

# Level data
var level_data: LevelData = null
var current_segment_id: String = ""

# Tile colors (Grasslands palette from GDD Part 7)
@export var grass_color_a: Color = Color("2d5a2d")  # Dark grass
@export var grass_color_b: Color = Color("4a8a4a")  # Light grass

# Current segment state
var height_map: Dictionary = {}
var type_map: Dictionary = {}
var segment_width: int = 16
var segment_height: int = 16

# Node references
@onready var tile_container: Node2D = $Tiles
@onready var enemy_container: Node2D = $Enemies
@onready var pickup_container: Node2D = $Pickups
@onready var boss_container: Node2D = $Bosses
@onready var marker_container: Node2D = $Markers
@onready var pickup_label: Label = $UI/PickupLabel
@onready var pause_menu: Control = $UI/PauseMenu
@onready var end_screen: Control = $UI/EndScreen
@onready var game_over_screen: CanvasLayer = $UI/GameOverScreen
@onready var hud: Control = $UI/HUD
@onready var player: Node2D = $Player
@onready var camera: Camera2D = $Camera2D
var player2: Node2D = null
var boss_ref: Node2D = null
var start_marker: Node2D = null
var gate_marker: Node2D = null
var goal_world_pos: Vector3 = Vector3.ZERO  # Stored directly for reliable distance checks
var has_goal: bool = false

# Game state
var separation_timer: float = 0.0
var separation_active: bool = false
var collected_pickups: int = 0
var total_pickups: int = 0
var level_complete: bool = false
var collected_keys: int = 0
var checkpoint_nodes: Array[Node2D] = []
var activated_checkpoints: Dictionary = {}  # "segment_id:x,y" -> true

# Co-op tether
@export var max_player_separation: float = 12.0
@export var separation_delay: float = 0.8

# Checkpoint
var last_checkpoint_pos: Vector3 = Vector3.ZERO
var last_checkpoint_segment: String = ""

# Level path (set before _ready or via load_level)
@export var level_json_path: String = ""

func _ready() -> void:
	if level_json_path != "":
		load_level_from_path(level_json_path)
	else:
		# Default: load world 1 level 1
		var path := LevelData.get_level_path(GameState.current_world, GameState.current_level)
		load_level_from_path(path)

func load_level_from_path(path: String) -> void:
	level_data = LevelData.load_from_file(path)
	if not level_data:
		push_error("LevelLoader: Failed to load level from: " + path)
		return

	# Reset level-wide state
	collected_pickups = 0
	total_pickups = 0
	level_complete = false
	activated_checkpoints.clear()

	# Count total pickups across ALL segments
	for seg_id in level_data.segments:
		var seg: LevelData.SegmentData = level_data.segments[seg_id]
		for ent in seg.entities:
			if ent.type == "pickup":
				total_pickups += 1

	# Load the starting segment
	_load_segment(level_data.start_segment, level_data.start_position)

func _load_segment(segment_id: String, player_start: Vector2i) -> void:
	if not level_data or not level_data.segments.has(segment_id):
		push_error("LevelLoader: Segment not found: " + segment_id)
		return

	current_segment_id = segment_id
	var segment: LevelData.SegmentData = level_data.segments[segment_id]
	segment_width = segment.width
	segment_height = segment.height

	# Build maps
	height_map = level_data.get_segment_height_map(segment_id)
	type_map = level_data.get_segment_type_map(segment_id)

	# Clear existing content
	_clear_segment()

	# Generate visuals and entities
	_generate_tiles(segment)
	_spawn_entities(segment)
	_setup_player(player_start)
	_spawn_markers(player_start)
	_update_pickup_label()

func _clear_segment() -> void:
	for child in tile_container.get_children():
		child.queue_free()
	for child in enemy_container.get_children():
		child.queue_free()
	for child in pickup_container.get_children():
		child.queue_free()
	for child in boss_container.get_children():
		child.queue_free()
	for child in marker_container.get_children():
		child.queue_free()
	boss_ref = null
	start_marker = null
	gate_marker = null
	has_goal = false
	checkpoint_nodes.clear()

func _generate_tiles(segment: LevelData.SegmentData) -> void:
	# Build tile positions sorted by depth
	var tile_positions: Array[Vector2i] = []
	for x in range(segment.width):
		for y in range(segment.height):
			if height_map.has(Vector2i(x, y)):
				tile_positions.append(Vector2i(x, y))

	tile_positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a.x + a.y) < (b.x + b.y)
	)

	for tile_pos in tile_positions:
		var height: float = float(height_map.get(tile_pos, 0.0))
		var tile_type: TileTypes.TileType = type_map.get(tile_pos, TileTypes.TileType.FLOOR)

		if height < -16.0:
			continue

		var tile := Node2D.new()
		tile.set_script(IsoTileScript)
		tile_container.add_child(tile)
		tile.setup(tile_pos.x, tile_pos.y, height, grass_color_a, grass_color_b, tile_type)

func _spawn_entities(segment: LevelData.SegmentData) -> void:
	for entity_entry in segment.entities:
		var pos := Vector2i(entity_entry.x, entity_entry.y)
		var ground_height: float = float(height_map.get(pos, 0.0))

		match entity_entry.type:
			"enemy", "enemy_nibbler":
				var enemy: Node2D = EnemyScene.instantiate()
				enemy_container.add_child(enemy)
				enemy.setup(pos.x, pos.y, ground_height)
			"ground_enemy":
				var ground_enemy: Node2D = GroundEnemyScene.instantiate()
				enemy_container.add_child(ground_enemy)
				ground_enemy.setup(pos.x, pos.y, ground_height)
			"boss":
				var boss: Node2D = BossScene.instantiate()
				boss_container.add_child(boss)
				boss.setup(pos.x, pos.y, ground_height)
				boss.set("active", false)
				boss_ref = boss
			"pickup":
				var pickup: Node2D = PickupScene.instantiate()
				pickup_container.add_child(pickup)
				if pickup.has_method("setup"):
					pickup.setup(Vector3(pos.x + 0.5, pos.y + 0.5, ground_height + 6.0))
				if pickup.has_signal("collected"):
					pickup.collected.connect(_on_pickup_collected)
			"goal":
				# Spawn gate marker at this position
				var goal_height: float = float(height_map.get(pos, 0.0))
				goal_world_pos = Vector3(pos.x + 0.5, pos.y + 0.5, goal_height)
				has_goal = true
				gate_marker = GateMarkerScene.instantiate()
				marker_container.add_child(gate_marker)
				gate_marker.position = IsoUtils.world_to_screen(Vector3(pos.x + 0.5, pos.y + 0.5, goal_height + 12.0))
				gate_marker.z_index = 600
				_update_gate_active(false)
			"checkpoint":
				var cp: Node2D = CheckpointScene.instantiate()
				marker_container.add_child(cp)
				var cp_screen := IsoUtils.world_to_screen(Vector3(pos.x + 0.5, pos.y + 0.5, ground_height + 6.0))
				cp.setup(pos, cp_screen)
				var cp_key := "%s:%d,%d" % [current_segment_id, pos.x, pos.y]
				if activated_checkpoints.has(cp_key):
					cp.activate()
				checkpoint_nodes.append(cp)

func _setup_player(start_tile: Vector2i) -> void:
	if player:
		var start_height: float = float(height_map.get(start_tile, 0.0))
		player.set_world_pos(Vector3(start_tile.x + 0.5, start_tile.y + 0.5, start_height))
		if player.has_method("set"):
			player.set("player_id", 1)

	# Set initial checkpoint
	var start_height: float = float(height_map.get(start_tile, 0.0))
	last_checkpoint_pos = Vector3(start_tile.x + 0.5, start_tile.y + 0.5, start_height)
	last_checkpoint_segment = current_segment_id

	var player_count: int = GameState.player_count
	if player_count >= 2:
		var p2_tile := Vector2i(start_tile.x + 1, start_tile.y)
		var p2_height: float = float(height_map.get(p2_tile, 0.0))
		player2 = PlayerScene.instantiate()
		if player2.has_method("set"):
			player2.set("player_id", 2)
		add_child(player2)
		player2.set_world_pos(Vector3(p2_tile.x + 0.5, p2_tile.y + 0.5, p2_height))

func _spawn_markers(start_tile: Vector2i) -> void:
	var start_height: float = float(height_map.get(start_tile, 0.0))
	start_marker = StartMarkerScene.instantiate()
	marker_container.add_child(start_marker)
	start_marker.position = IsoUtils.world_to_screen(Vector3(start_tile.x + 0.5, start_tile.y + 0.5, start_height + 6.0))
	start_marker.z_index = 200

func _on_pickup_collected(value: int) -> void:
	collected_pickups += value
	_update_pickup_label()

func _update_pickup_label() -> void:
	if pickup_label:
		pickup_label.text = "Pickups: %d / %d" % [collected_pickups, total_pickups]
	if hud and hud.has_method("update_pickups"):
		hud.update_pickups(collected_pickups, total_pickups)

func _update_gate_active(active: bool) -> void:
	if gate_marker and gate_marker.has_method("set_active"):
		gate_marker.set_active(active)
		gate_marker.visible = active

func _check_goal() -> void:
	if level_complete or total_pickups == 0:
		return
	if collected_pickups < total_pickups:
		_update_gate_active(false)
		return
	_update_gate_active(true)

	# Goal must be in the current segment and visible
	if not has_goal or not gate_marker:
		return

	# Check if players are near the gate using stored world position
	var goal_2d := Vector2(goal_world_pos.x, goal_world_pos.y)
	var p1_pos: Vector3 = player.get_world_pos()
	var p2_pos: Vector3 = player2.get_world_pos() if player2 else p1_pos
	if Vector2(p1_pos.x, p1_pos.y).distance_to(goal_2d) <= 1.75 or Vector2(p2_pos.x, p2_pos.y).distance_to(goal_2d) <= 1.75:
		level_complete = true
		if end_screen and end_screen.has_method("show_menu"):
			get_tree().paused = true
			end_screen.show_menu()

func _update_boss_trigger() -> void:
	if not boss_ref or not player:
		return
	if boss_ref.has_method("activate") and boss_ref.has_method("get_world_pos"):
		var boss_pos: Vector3 = boss_ref.get_world_pos()
		var p_pos: Vector3 = player.get_world_pos()
		var dist := Vector2(p_pos.x - boss_pos.x, p_pos.y - boss_pos.y).length()
		if dist <= 6.0:
			boss_ref.activate()

func _update_coop_separation(delta: float) -> void:
	if not player or not player2:
		return
	var p1: Vector3 = player.get_world_pos()
	var p2: Vector3 = player2.get_world_pos()
	var dist := Vector2(p1.x - p2.x, p1.y - p2.y).length()
	if dist > max_player_separation:
		separation_timer += delta
		if separation_timer >= separation_delay:
			separation_active = true
			separation_timer = 0.0
	else:
		separation_timer = 0.0
		separation_active = false

	if separation_active:
		var dir := Vector2(p1.x - p2.x, p1.y - p2.y)
		if dir.length_squared() > 0.01:
			var step := dir.normalized() * (max_player_separation * 3.0) * delta
			var new_pos := Vector2(p2.x, p2.y) + step
			player2.set_world_pos(Vector3(new_pos.x, new_pos.y, p2.z))
			if Vector2(p1.x - new_pos.x, p1.y - new_pos.y).length() <= max_player_separation * 0.6:
				separation_active = false

func _check_player_fall(p: Node2D) -> void:
	if not p or not p.has_method("get_world_pos"):
		return
	var pos: Vector3 = p.get_world_pos()
	if get_tile_height_at(pos.x, pos.y) < -500.0 or pos.z < -200.0:
		_respawn_player(p)

func _respawn_player(p: Node2D) -> void:
	if p.has_method("set_world_pos"):
		p.set_world_pos(last_checkpoint_pos)

func _process(delta: float) -> void:
	# Camera follows player(s)
	if camera and player:
		if player2:
			camera.position = (player.position + player2.position) * 0.5
		else:
			camera.position = player.position

	_update_coop_separation(delta)
	_check_goal()
	_update_boss_trigger()
	_check_player_fall(player)
	if player2:
		_check_player_fall(player2)
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_escape_pressed(event):
		return
	
	# Toggle pause menu with ESC (or ui_cancel keys).
	if get_tree().paused:
		if pause_menu and pause_menu.visible and pause_menu.has_method("hide_menu"):
			get_tree().paused = false
			pause_menu.hide_menu()
		return
	
	if pause_menu and pause_menu.has_method("show_menu"):
		get_tree().paused = true
		pause_menu.show_menu()

func _is_escape_pressed(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == 4194305 or key_event.physical_keycode == 4194305

func _update_hud() -> void:
	if hud and hud.has_method("update_hearts") and player:
		hud.update_hearts(player.hp, player.max_hp)

## Show game over screen
func show_game_over() -> void:
	if game_over_screen and game_over_screen.has_method("show_menu"):
		game_over_screen.show_menu()

## Transition to a different segment via door
func transition_to_segment(segment_id: String, target_pos: Vector2i) -> void:
	if not level_data or not level_data.segments.has(segment_id):
		return
	_load_segment(segment_id, target_pos)

## Activate checkpoint at a position
func activate_checkpoint(pos: Vector3) -> void:
	var tile_pos := Vector2i(int(floor(pos.x)), int(floor(pos.y)))
	var cp_key := "%s:%d,%d" % [current_segment_id, tile_pos.x, tile_pos.y]
	if activated_checkpoints.has(cp_key):
		return  # Already activated
	activated_checkpoints[cp_key] = true
	last_checkpoint_pos = pos
	last_checkpoint_segment = current_segment_id
	# Activate visual checkpoint node
	for cp in checkpoint_nodes:
		if cp is Checkpoint and cp.tile_pos == tile_pos:
			cp.activate()
			break

# --- Tile query methods (used by IsoEntity._find_level()) ---

func get_tile_height_at(world_x: float, world_y: float) -> float:
	var tile_pos := Vector2i(int(floor(world_x)), int(floor(world_y)))
	if tile_pos.x < 0 or tile_pos.x >= segment_width:
		return -1000.0
	if tile_pos.y < 0 or tile_pos.y >= segment_height:
		return -1000.0
	if not height_map.has(tile_pos):
		return -1000.0  # No tile = void
	return float(height_map.get(tile_pos, 0.0))

func get_tile_type_at(world_x: float, world_y: float) -> TileTypes.TileType:
	var tile_pos := Vector2i(int(floor(world_x)), int(floor(world_y)))
	return type_map.get(tile_pos, TileTypes.TileType.FLOOR)

func is_solid_at(world_pos: Vector3) -> bool:
	var ground_height := get_tile_height_at(world_pos.x, world_pos.y)
	return world_pos.z <= ground_height

func is_step_blocked(world_x: float, world_y: float, current_z: float, max_step: float) -> bool:
	var ground_height := get_tile_height_at(world_x, world_y)
	return ground_height > current_z + max_step
