class_name LevelLoader
extends Node2D

## Data-driven level loader that replaces the monolithic test_level.gd.
## Loads level geometry and entities from JSON via LevelData.

const IsoTileScript := preload("res://scripts/level/iso_tile.gd")
const EnemyScene := preload("res://scenes/enemies/enemy.tscn")
const PlayerScene := preload("res://scenes/player/player.tscn")
const PickupScene := preload("res://scenes/level/pickup.tscn")
const PowerupPickupScene := preload("res://scenes/level/powerup_pickup.tscn")
const BossScene := preload("res://scenes/enemies/boss.tscn")
const KingRibbitScene := preload("res://scenes/enemies/king_ribbit.tscn")
const GroundEnemyScene := preload("res://scenes/enemies/ground_enemy.tscn")
const HopperScene := preload("res://scenes/enemies/hopper.tscn")
const BuzzflyScene := preload("res://scenes/enemies/buzzfly.tscn")
const HazardEnemyScene := preload("res://scenes/enemies/hazard_enemy.tscn")
const ShooterEnemyScene := preload("res://scenes/enemies/shooter.tscn")
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
@onready var coop_tether: Control = $UI/CoopTether
@onready var player: Node2D = $Player
@onready var camera: Camera2D = $Camera2D
var player2: Node2D = null
var boss_ref: Node2D = null
var start_marker: Node2D = null
var gate_marker: Node2D = null
var goal_world_pos: Vector3 = Vector3.ZERO  # Stored directly for reliable distance checks
var has_goal: bool = false
var level_state_id: String = ""

# Game state
var collected_pickups: int = 0
var total_pickups: int = 0
var level_complete: bool = false
var collected_keys: int = 0
var checkpoint_nodes: Array[Node2D] = []
var activated_checkpoints: Dictionary = {}  # "segment_id:x,y" -> true
var removed_entities: Dictionary = {}  # "segment_id:type:x,y" -> true
var door_state_overrides: Dictionary = {}  # "segment_id:x,y" -> TileTypes.TileType (door + crumble overrides)
var _resume_segment_id: String = ""
var _resume_start_tile: Vector2i = Vector2i.ZERO
var _has_resume_tile: bool = false

# Co-op tether / camera
@export var max_player_separation: float = 12.0
@export var tether_rest_length: float = 8.0
@export var tether_stiffness: float = 10.0
@export var slingshot_threshold: float = 15.0
@export var slingshot_impulse: float = 16.0
@export var camera_zoom_near: float = 1.0
@export var camera_zoom_far: float = 1.35
@export var camera_zoom_separation: float = 16.0

# Checkpoint
var last_checkpoint_pos: Vector3 = Vector3.ZERO
var last_checkpoint_segment: String = ""

var _camera_shake_time: float = 0.0
var _camera_shake_intensity: float = 0.0
var level_elapsed_time: float = 0.0
var level_deaths: int = 0
var _slingshot_armed: bool = false

# Level path (set before _ready or via load_level)
@export var level_json_path: String = ""

func _ready() -> void:
	if not GameState.camera_shake_requested.is_connected(_on_camera_shake_requested):
		GameState.camera_shake_requested.connect(_on_camera_shake_requested)
	if not GameState.chain_changed.is_connected(_on_chain_changed):
		GameState.chain_changed.connect(_on_chain_changed)
	var music_track := "world%d_boss" % GameState.current_world if GameState.current_level == 0 else "world%d_level" % GameState.current_world
	_play_music(music_track)
	_play_ambience("ambience_wind")
	if level_json_path != "":
		load_level_from_path(level_json_path)
	else:
		var path: String
		if GameState.current_level == 0:
			path = LevelData.get_boss_level_path(GameState.current_world)
		else:
			path = LevelData.get_level_path(GameState.current_world, GameState.current_level)
		load_level_from_path(path)

func load_level_from_path(path: String) -> void:
	level_data = LevelData.load_from_file(path)
	if not level_data:
		push_error("LevelLoader: Failed to load level from: " + path)
		return

	# Reset level-wide state before optional restore.
	_reset_runtime_state_defaults()
	level_elapsed_time = 0.0
	level_deaths = 0

	# Count total pickups across ALL segments
	for seg_id in level_data.segments:
		var seg: LevelData.SegmentData = level_data.segments[seg_id]
		for ent in seg.entities:
			if ent.type == "pickup":
				total_pickups += 1

	level_state_id = _resolve_level_state_id()
	_restore_runtime_state()

	# Load the starting segment (restored segment/tile when available).
	var start_segment: String = level_data.start_segment
	var start_position: Vector2i = level_data.start_position
	if _resume_segment_id != "" and level_data.segments.has(_resume_segment_id):
		start_segment = _resume_segment_id
	if _has_resume_tile:
		start_position = _resume_start_tile
	_load_segment(start_segment, start_position)
	_save_runtime_state()

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
	_apply_persistent_tile_states(segment_id)

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
		if tile_type == TileTypes.TileType.CRUMBLE and tile.has_signal("crumbled"):
			tile.crumbled.connect(_on_crumble_tile_crumbled)

func _spawn_entities(segment: LevelData.SegmentData) -> void:
	for entity_entry in segment.entities:
		var pos := Vector2i(entity_entry.x, entity_entry.y)
		var ground_height: float = float(height_map.get(pos, 0.0))

		# Skip entities that were already removed (collected/killed)
		var entity_key := "%s:%s:%d,%d" % [current_segment_id, entity_entry.type, pos.x, pos.y]
		if removed_entities.has(entity_key):
			continue

		match entity_entry.type:
			"enemy", "enemy_nibbler":
				var enemy: Node2D = EnemyScene.instantiate()
				enemy_container.add_child(enemy)
				enemy.setup(pos.x, pos.y, ground_height)
				_apply_entity_properties(enemy, entity_entry.properties)
				if enemy.has_signal("died"):
					enemy.died.connect(_on_enemy_died.bind(entity_key))
			"ground_enemy":
				var ground_enemy: Node2D = GroundEnemyScene.instantiate()
				enemy_container.add_child(ground_enemy)
				ground_enemy.setup(pos.x, pos.y, ground_height)
				_apply_entity_properties(ground_enemy, entity_entry.properties)
				if ground_enemy.has_signal("died"):
					ground_enemy.died.connect(_on_enemy_died.bind(entity_key))
			"enemy_hopper":
				var hopper: Node2D = HopperScene.instantiate()
				enemy_container.add_child(hopper)
				hopper.setup(pos.x, pos.y, ground_height)
				_apply_entity_properties(hopper, entity_entry.properties)
				if hopper.has_signal("died"):
					hopper.died.connect(_on_enemy_died.bind(entity_key))
			"enemy_buzzfly":
				var buzzfly: Node2D = BuzzflyScene.instantiate()
				enemy_container.add_child(buzzfly)
				buzzfly.setup(pos.x, pos.y, ground_height)
				_apply_entity_properties(buzzfly, entity_entry.properties)
				if buzzfly.has_signal("died"):
					buzzfly.died.connect(_on_enemy_died.bind(entity_key))
			"enemy_hazard":
				var hazard_enemy: Node2D = HazardEnemyScene.instantiate()
				enemy_container.add_child(hazard_enemy)
				hazard_enemy.setup(pos.x, pos.y, ground_height)
				_apply_entity_properties(hazard_enemy, entity_entry.properties)
				if hazard_enemy.has_signal("died"):
					hazard_enemy.died.connect(_on_enemy_died.bind(entity_key))
			"enemy_shooter":
				var shooter: Node2D = ShooterEnemyScene.instantiate()
				enemy_container.add_child(shooter)
				shooter.setup(pos.x, pos.y, ground_height)
				_apply_entity_properties(shooter, entity_entry.properties)
				if shooter.has_signal("died"):
					shooter.died.connect(_on_enemy_died.bind(entity_key))
			"boss":
				var boss: Node2D = BossScene.instantiate()
				boss_container.add_child(boss)
				boss.setup(pos.x, pos.y, ground_height)
				_apply_entity_properties(boss, entity_entry.properties)
				boss.set("active", false)
				boss_ref = boss
			"boss_king_ribbit":
				var boss: Node2D = KingRibbitScene.instantiate()
				boss_container.add_child(boss)
				boss.setup(pos.x, pos.y, ground_height)
				_apply_entity_properties(boss, entity_entry.properties)
				boss.set("active", false)
				boss_ref = boss
			"pickup":
				var pickup: Node2D = PickupScene.instantiate()
				pickup_container.add_child(pickup)
				if pickup.has_method("setup"):
					pickup.setup(Vector3(pos.x + 0.5, pos.y + 0.5, ground_height + 6.0))
				if pickup.has_signal("collected"):
					pickup.collected.connect(_on_pickup_collected.bind(entity_key))
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
			"key":
				var key_pickup: Node2D = PickupScene.instantiate()
				pickup_container.add_child(key_pickup)
				if key_pickup.has_method("setup"):
					key_pickup.setup(Vector3(pos.x + 0.5, pos.y + 0.5, ground_height + 6.0))
				if key_pickup.has_method("set_as_key"):
					key_pickup.set_as_key()
				if key_pickup.has_signal("collected"):
					key_pickup.collected.connect(_on_key_collected.bind(entity_key))
			"powerup_rock_dust", "powerup_dash_dust", "powerup_time_stone", "form_serpent", "form_burning_bush", "form_phocid", "form_metalsaur":
				var utility_pickup: Node2D = PowerupPickupScene.instantiate()
				pickup_container.add_child(utility_pickup)
				var duration: float = 8.0
				if entity_entry.properties.has("duration"):
					duration = float(entity_entry.properties["duration"])
				if utility_pickup.has_method("setup"):
					utility_pickup.setup(Vector3(pos.x + 0.5, pos.y + 0.5, ground_height + 6.0), entity_entry.type, duration)
				if utility_pickup.has_signal("collected"):
					utility_pickup.collected.connect(_on_utility_pickup_collected.bind(entity_key))

func _setup_player(start_tile: Vector2i) -> void:
	_cleanup_duplicate_secondary_players()
	if player:
		var start_height: float = float(height_map.get(start_tile, 0.0))
		player.set_world_pos(Vector3(start_tile.x + 0.5, start_tile.y + 0.5, start_height))
		if player.has_method("set"):
			player.set("player_id", 1)
		if InputManager and InputManager.has_method("assign_device"):
			InputManager.assign_device(1, -1)

	# Set initial checkpoint
	var start_height: float = float(height_map.get(start_tile, 0.0))
	last_checkpoint_pos = Vector3(start_tile.x + 0.5, start_tile.y + 0.5, start_height)
	last_checkpoint_segment = current_segment_id

	var player_count: int = GameState.player_count
	if player_count >= 2:
		var p2_tile := Vector2i(start_tile.x + 1, start_tile.y)
		var p2_height: float = float(height_map.get(p2_tile, 0.0))
		if (not player2 or not is_instance_valid(player2)):
			player2 = _find_existing_secondary_player()
		if not player2 or not is_instance_valid(player2):
			player2 = PlayerScene.instantiate()
			if player2.has_method("set"):
				player2.set("player_id", 2)
			add_child(player2)
		player2.set_world_pos(Vector3(p2_tile.x + 0.5, p2_tile.y + 0.5, p2_height))
		if InputManager and InputManager.has_method("assign_device"):
			InputManager.assign_device(2, -1)
		_cleanup_duplicate_secondary_players()
	else:
		_remove_all_secondary_players()
	_refresh_coop_tether()

func _spawn_markers(start_tile: Vector2i) -> void:
	var start_height: float = float(height_map.get(start_tile, 0.0))
	start_marker = StartMarkerScene.instantiate()
	marker_container.add_child(start_marker)
	start_marker.position = IsoUtils.world_to_screen(Vector3(start_tile.x + 0.5, start_tile.y + 0.5, start_height + 6.0))
	start_marker.z_index = 200

func _on_pickup_collected(value: int, entity_key: String = "") -> void:
	collected_pickups += value
	if entity_key != "":
		removed_entities[entity_key] = true
	_update_pickup_label()
	_save_runtime_state()

func _on_key_collected(_value: int, entity_key: String = "") -> void:
	GameState.add_keys(1)
	if entity_key != "":
		removed_entities[entity_key] = true
	_save_runtime_state()

func _on_utility_pickup_collected(_pickup_type: String, entity_key: String = "") -> void:
	if entity_key != "":
		removed_entities[entity_key] = true
	_save_runtime_state()

func _on_enemy_died(entity_key: String) -> void:
	removed_entities[entity_key] = true
	_save_runtime_state()

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
	if level_complete:
		return
	# Boss level: goal activates when boss is dead
	if total_pickups == 0 and has_goal and (boss_ref == null or not is_instance_valid(boss_ref)):
		_update_gate_active(true)
		_check_player_at_goal()
		return
	if total_pickups == 0:
		return
	if collected_pickups < total_pickups:
		_update_gate_active(false)
		return
	_update_gate_active(true)
	_check_player_at_goal()

func _check_player_at_goal() -> void:
	if not has_goal or not gate_marker:
		return
	var goal_2d := Vector2(goal_world_pos.x, goal_world_pos.y)
	var p1_pos: Vector3 = player.get_world_pos()
	var p2_pos: Vector3 = player2.get_world_pos() if player2 else p1_pos
	if Vector2(p1_pos.x, p1_pos.y).distance_to(goal_2d) <= 1.75 or Vector2(p2_pos.x, p2_pos.y).distance_to(goal_2d) <= 1.75:
		level_complete = true
		GameState.record_level_clear(level_state_id, level_elapsed_time, level_deaths)
		GameState.complete_current_level()
		if end_screen and end_screen.has_method("show_menu"):
			get_tree().paused = true
			end_screen.show_menu()

func _update_boss_trigger() -> void:
	if not boss_ref or not is_instance_valid(boss_ref) or not player:
		return
	if boss_ref.has_method("activate") and boss_ref.has_method("get_world_pos"):
		var boss_pos: Vector3 = boss_ref.get_world_pos()
		var p_pos: Vector3 = player.get_world_pos()
		var dist := Vector2(p_pos.x - boss_pos.x, p_pos.y - boss_pos.y).length()
		if dist <= 6.0:
			boss_ref.activate()

func _update_coop_separation(delta: float) -> void:
	if not player or not player2:
		_slingshot_armed = false
		return
	var p1: Vector3 = player.get_world_pos()
	var p2: Vector3 = player2.get_world_pos()
	var to_p2 := Vector2(p2.x - p1.x, p2.y - p1.y)
	var dist := to_p2.length()
	if dist <= 0.001:
		return
	var dir := to_p2 / dist

	# Elastic pull once players exceed the rest length.
	if dist > tether_rest_length:
		var excess := dist - tether_rest_length
		var pull := dir * excess * tether_stiffness * delta
		var p1_new := Vector2(p1.x, p1.y) + pull * 0.5
		var p2_new := Vector2(p2.x, p2.y) - pull * 0.5
		player.set_world_pos(Vector3(p1_new.x, p1_new.y, p1.z))
		player2.set_world_pos(Vector3(p2_new.x, p2_new.y, p2.z))

	# Hard clamp to avoid runaway separation.
	if dist > max_player_separation:
		var midpoint := Vector2((p1.x + p2.x) * 0.5, (p1.y + p2.y) * 0.5)
		var half := dir * (max_player_separation * 0.5)
		var clamped_p1 := midpoint - half
		var clamped_p2 := midpoint + half
		player.set_world_pos(Vector3(clamped_p1.x, clamped_p1.y, p1.z))
		player2.set_world_pos(Vector3(clamped_p2.x, clamped_p2.y, p2.z))

	# Slingshot trigger: arm on high tension, then launch when tension releases.
	if dist >= slingshot_threshold:
		_slingshot_armed = true
	elif _slingshot_armed and dist <= tether_rest_length * 0.9:
		_slingshot_armed = false
		var midpoint := Vector2((p1.x + p2.x) * 0.5, (p1.y + p2.y) * 0.5)
		var p1_dir := Vector2(p1.x, p1.y) - midpoint
		var p2_dir := Vector2(p2.x, p2.y) - midpoint
		if player.has_method("add_external_impulse"):
			player.add_external_impulse(p1_dir, slingshot_impulse)
		if player2.has_method("add_external_impulse"):
			player2.add_external_impulse(p2_dir, slingshot_impulse)

func _check_player_fall(p: Node2D) -> void:
	if not p or not p.has_method("get_world_pos"):
		return
	var pos: Vector3 = p.get_world_pos()
	if get_tile_height_at(pos.x, pos.y) < -500.0 or pos.z < -200.0:
		_respawn_player(p)

func _respawn_player(p: Node2D) -> void:
	if p.has_method("respawn_at"):
		p.respawn_at(last_checkpoint_pos)
	elif p.has_method("set_world_pos"):
		p.set_world_pos(last_checkpoint_pos)

func _process(delta: float) -> void:
	if not level_complete and not get_tree().paused:
		level_elapsed_time += delta
	# Camera follows player(s)
	if camera and player:
		var target_zoom := camera_zoom_near
		if player2:
			camera.position = (player.position + player2.position) * 0.5
			if player.has_method("get_world_pos") and player2.has_method("get_world_pos"):
				var p1_pos: Vector3 = player.get_world_pos()
				var p2_pos: Vector3 = player2.get_world_pos()
				var dist := Vector2(p1_pos.x - p2_pos.x, p1_pos.y - p2_pos.y).length()
				var t := clampf(dist / maxf(camera_zoom_separation, 0.01), 0.0, 1.0)
				target_zoom = lerpf(camera_zoom_near, camera_zoom_far, t)
		else:
			camera.position = player.position
		camera.zoom = camera.zoom.lerp(Vector2(target_zoom, target_zoom), clampf(delta * 6.0, 0.0, 1.0))
		_apply_camera_shake(delta)

	_update_coop_separation(delta)
	_check_goal()
	_update_boss_trigger()
	_check_player_fall(player)
	if player2:
		_check_player_fall(player2)
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("coop_toggle") and not get_tree().paused:
		_toggle_secondary_player()
		return
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

func _toggle_secondary_player() -> void:
	if not player:
		return
	if player2 and is_instance_valid(player2):
		player2.queue_free()
		player2 = null
		if InputManager and InputManager.has_method("assign_device"):
			InputManager.assign_device(2, -1)
		GameState.player_count = 1
		GameState.save_progress()
		_refresh_coop_tether()
		return
	var p1_pos: Vector3 = player.get_world_pos()
	var p2_tile: Vector2i = Vector2i(int(floor(p1_pos.x + 1.0)), int(floor(p1_pos.y)))
	var p2_height: float = float(height_map.get(p2_tile, p1_pos.z))
	player2 = PlayerScene.instantiate()
	player2.set("player_id", 2)
	add_child(player2)
	player2.set_world_pos(Vector3(p2_tile.x + 0.5, p2_tile.y + 0.5, p2_height))
	if InputManager and InputManager.has_method("assign_device"):
		InputManager.assign_device(2, -1)
	GameState.player_count = 2
	GameState.save_progress()
	_refresh_coop_tether()

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

func _play_music(track_id: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_music"):
		audio.play_music(track_id, 0.25)

func _play_ambience(track_id: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_ambience"):
		audio.play_ambience(track_id, 0.25)

## Show game over screen
func show_game_over() -> void:
	if game_over_screen and game_over_screen.has_method("show_menu"):
		game_over_screen.show_menu()

## Transition to a different segment via door
func transition_to_segment(segment_id: String, target_pos: Vector2i) -> void:
	if not level_data or not level_data.segments.has(segment_id):
		return
	var transition := get_node_or_null("/root/TransitionManager")
	if transition and transition.has_method("flash"):
		transition.flash(0.06, 0.06)
	_load_segment(segment_id, target_pos)
	_save_runtime_state()

func register_level_death() -> void:
	level_deaths += 1

## Activate checkpoint at a position
func activate_checkpoint(pos: Vector3) -> void:
	var tile_pos := Vector2i(int(floor(pos.x)), int(floor(pos.y)))
	var cp_key := "%s:%d,%d" % [current_segment_id, tile_pos.x, tile_pos.y]
	if activated_checkpoints.has(cp_key):
		return  # Already activated
	activated_checkpoints[cp_key] = true
	last_checkpoint_pos = pos
	last_checkpoint_segment = current_segment_id
	_save_runtime_state()
	GameState.save_progress()
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
	# PIT tiles act as holes — return very low height
	var tile_type: TileTypes.TileType = type_map.get(tile_pos, TileTypes.TileType.FLOOR)
	if tile_type == TileTypes.TileType.PIT:
		return -100.0
	return float(height_map.get(tile_pos, 0.0))

func get_raw_tile_height_at(world_x: float, world_y: float) -> float:
	var tile_pos := Vector2i(int(floor(world_x)), int(floor(world_y)))
	if tile_pos.x < 0 or tile_pos.x >= segment_width:
		return -1000.0
	if tile_pos.y < 0 or tile_pos.y >= segment_height:
		return -1000.0
	if not height_map.has(tile_pos):
		return -1000.0
	return float(height_map.get(tile_pos, 0.0))

func get_tile_type_at(world_x: float, world_y: float) -> TileTypes.TileType:
	var tile_pos := Vector2i(int(floor(world_x)), int(floor(world_y)))
	return type_map.get(tile_pos, TileTypes.TileType.FLOOR)

func unlock_door_at(world_x: float, world_y: float) -> void:
	var tile_pos := Vector2i(int(floor(world_x)), int(floor(world_y)))
	type_map[tile_pos] = TileTypes.TileType.DOOR_OPEN
	door_state_overrides[_tile_state_key(current_segment_id, tile_pos)] = TileTypes.TileType.DOOR_OPEN
	_save_runtime_state()
	# Update the visual tile
	for tile in tile_container.get_children():
		if tile.has_method("get") and tile.get("tile_x") == tile_pos.x and tile.get("tile_y") == tile_pos.y:
			if tile.has_method("set"):
				tile.set("tile_type", TileTypes.TileType.DOOR_OPEN)
			tile.queue_redraw()
			break

func _on_crumble_tile_crumbled(tile_x: int, tile_y: int) -> void:
	var tile_pos := Vector2i(tile_x, tile_y)
	type_map[tile_pos] = TileTypes.TileType.PIT
	door_state_overrides[_tile_state_key(current_segment_id, tile_pos)] = TileTypes.TileType.PIT
	_save_runtime_state()

func is_solid_at(world_pos: Vector3) -> bool:
	var ground_height := get_tile_height_at(world_pos.x, world_pos.y)
	return world_pos.z <= ground_height

func is_step_blocked(world_x: float, world_y: float, current_z: float, max_step: float) -> bool:
	var ground_height := get_tile_height_at(world_x, world_y)
	return ground_height > current_z + max_step

func _tile_state_key(segment_id: String, tile_pos: Vector2i) -> String:
	return "%s:%d,%d" % [segment_id, tile_pos.x, tile_pos.y]

func _apply_persistent_tile_states(segment_id: String) -> void:
	for key in door_state_overrides.keys():
		var key_text: String = str(key)
		if not key_text.begins_with(segment_id + ":"):
			continue
		var tile_data := key_text.split(":")
		if tile_data.size() != 2:
			continue
		var coords := tile_data[1].split(",")
		if coords.size() != 2:
			continue
		var tile_pos := Vector2i(int(coords[0]), int(coords[1]))
		var state_value: Variant = door_state_overrides[key]
		if state_value is int:
			type_map[tile_pos] = int(state_value)

func _on_camera_shake_requested(intensity: float, duration: float) -> void:
	_camera_shake_intensity = maxf(_camera_shake_intensity, intensity)
	_camera_shake_time = maxf(_camera_shake_time, duration)

func _apply_camera_shake(delta: float) -> void:
	if _camera_shake_time <= 0.0:
		return
	_camera_shake_time = maxf(_camera_shake_time - delta, 0.0)
	var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _camera_shake_intensity
	camera.position += offset
	_camera_shake_intensity = maxf(_camera_shake_intensity - (delta * 18.0), 0.0)

func _find_existing_secondary_player() -> Node2D:
	for node in get_tree().get_nodes_in_group("players"):
		if node == player:
			continue
		if not is_instance_valid(node):
			continue
		if node.get_parent() != self:
			continue
		if node is Node2D:
			return node as Node2D
	return null

func _cleanup_duplicate_secondary_players() -> void:
	var secondary_players: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("players"):
		if node == player:
			continue
		if not is_instance_valid(node):
			continue
		if node.get_parent() != self:
			continue
		if node is Node2D:
			secondary_players.append(node as Node2D)
	if secondary_players.is_empty():
		player2 = null
		_refresh_coop_tether()
		return
	if not player2 or not is_instance_valid(player2):
		player2 = secondary_players[0]
	for candidate in secondary_players:
		if candidate == player2:
			continue
		candidate.queue_free()
	_refresh_coop_tether()

func _remove_all_secondary_players() -> void:
	for node in get_tree().get_nodes_in_group("players"):
		if node == player:
			continue
		if not is_instance_valid(node):
			continue
		if node.get_parent() != self:
			continue
		node.queue_free()
	player2 = null
	_refresh_coop_tether()

func _refresh_coop_tether() -> void:
	if coop_tether and coop_tether.has_method("set_players"):
		coop_tether.set_players(player, player2)

func _resolve_level_state_id() -> String:
	if level_data and level_data.level_id != "":
		return level_data.level_id
	if GameState.current_level == 0:
		return "w%d_boss" % GameState.current_world
	return "w%d_l%02d" % [GameState.current_world, GameState.current_level]

func _reset_runtime_state_defaults() -> void:
	collected_pickups = 0
	total_pickups = 0
	level_complete = false
	activated_checkpoints.clear()
	removed_entities.clear()
	door_state_overrides.clear()
	_resume_segment_id = ""
	_resume_start_tile = Vector2i.ZERO
	_has_resume_tile = false

func _restore_runtime_state() -> void:
	if level_state_id == "":
		return
	var state: Dictionary = GameState.get_level_runtime_state(level_state_id)
	if state.is_empty():
		return
	collected_pickups = clampi(int(state.get("collected_pickups", 0)), 0, total_pickups)
	var saved_checkpoints: Variant = state.get("activated_checkpoints", {})
	if saved_checkpoints is Dictionary:
		activated_checkpoints = saved_checkpoints.duplicate(true)
	var saved_removed: Variant = state.get("removed_entities", {})
	if saved_removed is Dictionary:
		removed_entities = saved_removed.duplicate(true)
	var saved_doors: Variant = state.get("door_state_overrides", {})
	if saved_doors is Dictionary:
		door_state_overrides = saved_doors.duplicate(true)
	last_checkpoint_segment = str(state.get("last_checkpoint_segment", ""))
	var saved_checkpoint_pos: Variant = state.get("last_checkpoint_pos", [])
	if saved_checkpoint_pos is Array and saved_checkpoint_pos.size() >= 3:
		last_checkpoint_pos = Vector3(
			float(saved_checkpoint_pos[0]),
			float(saved_checkpoint_pos[1]),
			float(saved_checkpoint_pos[2])
		)
	var saved_segment: String = str(state.get("current_segment", ""))
	if saved_segment != "":
		_resume_segment_id = saved_segment
	var saved_resume_tile: Variant = state.get("resume_tile", [])
	if saved_resume_tile is Array and saved_resume_tile.size() >= 2:
		_resume_start_tile = Vector2i(int(saved_resume_tile[0]), int(saved_resume_tile[1]))
		_has_resume_tile = true

func _save_runtime_state() -> void:
	if level_state_id == "":
		return
	var resume_tile := _get_resume_tile()
	var payload := {
		"collected_pickups": collected_pickups,
		"activated_checkpoints": activated_checkpoints.duplicate(true),
		"removed_entities": removed_entities.duplicate(true),
		"door_state_overrides": door_state_overrides.duplicate(true),
		"last_checkpoint_segment": last_checkpoint_segment,
		"last_checkpoint_pos": [last_checkpoint_pos.x, last_checkpoint_pos.y, last_checkpoint_pos.z],
		"current_segment": current_segment_id,
		"resume_tile": [resume_tile.x, resume_tile.y],
	}
	GameState.set_level_runtime_state(level_state_id, payload)

func _get_resume_tile() -> Vector2i:
	if player and player.has_method("get_world_pos"):
		var player_pos: Vector3 = player.get_world_pos()
		return Vector2i(int(floor(player_pos.x)), int(floor(player_pos.y)))
	return level_data.start_position if level_data else Vector2i.ZERO

func _apply_entity_properties(node: Node, properties: Dictionary) -> void:
	if node == null or properties.is_empty():
		return
	for raw_key in properties.keys():
		var prop_name: String = str(raw_key)
		if not _node_has_property(node, prop_name):
			continue
		node.set(prop_name, properties[raw_key])

func _node_has_property(node: Object, property_name: String) -> bool:
	for entry in node.get_property_list():
		var item: Variant = entry
		if item is Dictionary and str(item.get("name", "")) == property_name:
			return true
	return false

func _on_chain_changed(count: int, _timer: float) -> void:
	if count <= 1:
		return
	var anchor: Node2D = player
	if (anchor == null or not is_instance_valid(anchor)) and player2 and is_instance_valid(player2):
		anchor = player2
	if anchor == null or not is_instance_valid(anchor):
		return
	ScorePopup.spawn_text(self, anchor.position + Vector2(0, -24), "CHAIN x%d" % count, Color(1.0, 0.85, 0.25, 1.0))
