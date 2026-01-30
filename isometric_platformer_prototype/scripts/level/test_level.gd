class_name TestLevel
extends Node2D

const IsoTileScript := preload("res://scripts/level/iso_tile.gd")
const EnemyScene := preload("res://scenes/enemies/enemy.tscn")
const PlayerScene := preload("res://scenes/player/player.tscn")
const PickupScene := preload("res://scenes/level/pickup.tscn")
const BossScene := preload("res://scenes/enemies/boss.tscn")
const GroundEnemyScene := preload("res://scenes/enemies/ground_enemy.tscn")
const StartMarkerScene := preload("res://scenes/level/start_marker.tscn")
const GateMarkerScene := preload("res://scenes/level/gate_marker.tscn")

# Level dimensions (in tiles)
@export var level_width: int = 48
@export var level_height: int = 48

# Tile colors (Snake: Rattle n' Roll style green)
@export var grass_color_a: Color = Color(0.18, 0.55, 0.18)
@export var grass_color_b: Color = Color(0.25, 0.65, 0.25)

# Tile height data - stores height at each tile position
var height_map: Dictionary = {}

# Node references
@onready var tile_container: Node2D = $Tiles
@onready var enemy_container: Node2D = $Enemies
@onready var pickup_container: Node2D = $Pickups
@onready var boss_container: Node2D = $Bosses
@onready var marker_container: Node2D = $Markers
@onready var pickup_label: Label = $UI/PickupLabel
@onready var pause_menu: CanvasLayer = $UI/PauseMenu
@onready var end_screen: CanvasLayer = $UI/EndScreen
@onready var player: Node2D = $Player
@onready var camera: Camera2D = $Camera2D
var player2: Node2D = null
var boss_ref: Node2D = null
var start_marker: Node2D = null
var gate_marker: Node2D = null
var separation_timer: float = 0.0
var separation_active: bool = false
var collected_pickups: int = 0
var total_pickups: int = 0
var level_complete: bool = false

# Goal/loop tuning
@export var goal_tile: Vector2i = Vector2i(12, 12)
@export var required_pickups: int = 3

# Co-op tether
@export var max_player_separation: float = 12.0
@export var separation_delay: float = 0.8

func _ready() -> void:
	_generate_height_map()
	_generate_tiles()
	_spawn_enemies()
	_setup_player()
	_spawn_pickups()
	_spawn_boss()
	_spawn_markers()
	_update_pickup_label()
	_update_pickup_label()

func _generate_height_map() -> void:
	# Create a simple height map with some platforms
	for x in range(level_width):
		for y in range(level_height):
			var height: float = 0.0
			
			# Create some elevated platforms
			# Center raised area
			if x >= 6 and x <= 9 and y >= 6 and y <= 9:
				height = 16.0
			if x >= 18 and x <= 24 and y >= 18 and y <= 24:
				height = 16.0
			if x >= 28 and x <= 36 and y >= 6 and y <= 10:
				height = 12.0
			if x >= 6 and x <= 12 and y >= 28 and y <= 34:
				height = 12.0
			
			# Stepped platforms on the right
			if x >= 12 and x <= 14 and y >= 2 and y <= 5:
				height = 8.0
			if x >= 13 and x <= 14 and y >= 3 and y <= 4:
				height = 16.0
			if x >= 38 and x <= 42 and y >= 8 and y <= 12:
				height = 8.0
			if x >= 40 and x <= 42 and y >= 9 and y <= 11:
				height = 16.0
			
			# Lower area (pit/water level simulation)
			if x >= 2 and x <= 4 and y >= 10 and y <= 13:
				height = -8.0
			if x >= 20 and x <= 24 and y >= 34 and y <= 38:
				height = -8.0
			if x >= 32 and x <= 36 and y >= 30 and y <= 36:
				height = -8.0
			
			# Ramp-like structure (stepped)
			# (Removed) Tall ramp at lower left
			# Removed tall staircase; replaced with small platforms
			if x >= 24 and x <= 26 and y >= 12 and y <= 14:
				height = 8.0
			if x >= 28 and x <= 30 and y >= 14 and y <= 16:
				height = 12.0
			if x >= 32 and x <= 34 and y >= 12 and y <= 14:
				height = 8.0
			# (Removed) Tall staircase near center-left
			
			height_map[Vector2i(x, y)] = height

func _generate_tiles() -> void:
	# Generate tiles in correct order for depth sorting
	# Back to front: start from high X+Y and go to low X+Y
	var tile_positions: Array[Vector2i] = []
	
	for x in range(level_width):
		for y in range(level_height):
			tile_positions.append(Vector2i(x, y))
	
	# Sort by depth (low to high so we add back tiles first)
	tile_positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a.x + a.y) < (b.x + b.y)
	)
	
	for tile_pos in tile_positions:
		var height: float = float(height_map.get(tile_pos, 0.0))
		
		# Skip tiles that would be "pits" below the view
		if height < -16.0:
			continue
		
		var tile := Node2D.new()
		tile.set_script(IsoTileScript)
		tile_container.add_child(tile)
		tile.setup(tile_pos.x, tile_pos.y, height, grass_color_a, grass_color_b)

func _setup_player() -> void:
	if player:
		# Start player at a specific tile
		var start_tile := Vector2i(3, 3)
		var start_height: float = float(height_map.get(start_tile, 0.0))
		player.set_world_pos(Vector3(start_tile.x + 0.5, start_tile.y + 0.5, start_height))
		if player.has_method("set"):
			player.set("player_id", 1)
	
	var player_count: int = GameState.player_count
	if player_count >= 2:
		# Spawn player 2 nearby
		var p2_tile := Vector2i(4, 3)
		var p2_height: float = float(height_map.get(p2_tile, 0.0))
		player2 = PlayerScene.instantiate()
		if player2.has_method("set"):
			player2.set("player_id", 2)
		add_child(player2)
		player2.set_world_pos(Vector3(p2_tile.x + 0.5, p2_tile.y + 0.5, p2_height))

func _spawn_enemies() -> void:
	# Spawn three test enemies at different locations
	var enemy_positions: Array[Vector2i] = [
		Vector2i(6, 4),   # Near the center platform
		Vector2i(8, 8),   # On the center platform
		Vector2i(12, 3),  # Near the stepped platforms
		Vector2i(22, 22), # Large center platform
		Vector2i(30, 8),  # Right platform
		Vector2i(10, 30), # Upper left platform
		Vector2i(40, 10), # Far right stepped area
	]
	
	for pos in enemy_positions:
		var ground_height: float = float(height_map.get(pos, 0.0))
		var enemy: Node2D = EnemyScene.instantiate()
		enemy_container.add_child(enemy)
		enemy.setup(pos.x, pos.y, ground_height)
	
	# Spawn ground enemy variants
	var ground_positions: Array[Vector2i] = [
		Vector2i(6, 6),
		Vector2i(14, 4),
		Vector2i(24, 18),
		Vector2i(34, 30),
	]
	for pos in ground_positions:
		var ground_height: float = float(height_map.get(pos, 0.0))
		var ground_enemy: Node2D = GroundEnemyScene.instantiate()
		enemy_container.add_child(ground_enemy)
		ground_enemy.setup(pos.x, pos.y, ground_height)

func _spawn_pickups() -> void:
	if not pickup_container:
		return
	# Clear existing pickups
	for child in pickup_container.get_children():
		child.queue_free()
	collected_pickups = 0
	total_pickups = 0
	
	var pickup_positions: Array[Vector2i] = [
		Vector2i(10, 8),
		Vector2i(20, 20),
		Vector2i(30, 18),
		Vector2i(38, 24),
	]
	
	for pos in pickup_positions:
		var ground_height: float = float(height_map.get(pos, 0.0))
		var pickup: Node2D = PickupScene.instantiate()
		pickup_container.add_child(pickup)
		if pickup.has_method("setup"):
			pickup.setup(Vector3(pos.x + 0.5, pos.y + 0.5, ground_height + 6.0))
		if pickup.has_signal("collected"):
			pickup.collected.connect(_on_pickup_collected)
		total_pickups += 1
	required_pickups = total_pickups
	_update_pickup_label()

func _on_pickup_collected(value: int) -> void:
	collected_pickups += value
	_update_pickup_label()

func _spawn_boss() -> void:
	if not boss_container:
		return
	var boss_tile := Vector2i(28, 28)
	var ground_height: float = float(height_map.get(boss_tile, 0.0))
	boss_ref = BossScene.instantiate()
	boss_container.add_child(boss_ref)
	if boss_ref.has_method("setup"):
		boss_ref.setup(boss_tile.x, boss_tile.y, ground_height)
	if boss_ref.has_method("set"):
		boss_ref.set("active", false)

func _update_boss_trigger() -> void:
	if not boss_ref or not player:
		return
	if boss_ref.has_method("activate") and boss_ref.has_method("get_world_pos"):
		var boss_pos: Vector3 = boss_ref.get_world_pos()
		var p_pos: Vector3 = player.get_world_pos()
		var dist := Vector2(p_pos.x - boss_pos.x, p_pos.y - boss_pos.y).length()
		if dist <= 6.0:
			boss_ref.activate()

func _check_goal() -> void:
	if level_complete:
		return
	if collected_pickups < required_pickups:
		_update_gate_active(false)
		return
	_update_gate_active(true)
	var goal_pos := Vector2(goal_tile.x + 0.5, goal_tile.y + 0.5)
	var p1_pos: Vector3 = player.get_world_pos()
	var p2_pos: Vector3 = player2.get_world_pos() if player2 else p1_pos
	if Vector2(p1_pos.x, p1_pos.y).distance_to(goal_pos) <= 1.0 and Vector2(p2_pos.x, p2_pos.y).distance_to(goal_pos) <= 1.5:
		level_complete = true
		if end_screen and end_screen.has_method("show_menu"):
			get_tree().paused = true
			end_screen.show_menu()

func _spawn_markers() -> void:
	if not marker_container:
		return
	for child in marker_container.get_children():
		child.queue_free()
	
	var start_tile := Vector2i(3, 3)
	var start_height: float = float(height_map.get(start_tile, 0.0))
	start_marker = StartMarkerScene.instantiate()
	marker_container.add_child(start_marker)
	start_marker.position = IsoUtils.world_to_screen(Vector3(start_tile.x + 0.5, start_tile.y + 0.5, start_height + 6.0))
	start_marker.z_index = 200
	
	var goal_height: float = float(height_map.get(goal_tile, 0.0))
	gate_marker = GateMarkerScene.instantiate()
	marker_container.add_child(gate_marker)
	gate_marker.position = IsoUtils.world_to_screen(Vector3(goal_tile.x + 0.5, goal_tile.y + 0.5, goal_height + 12.0))
	gate_marker.z_index = 600
	_update_gate_active(false)

func _update_gate_active(active: bool) -> void:
	if gate_marker and gate_marker.has_method("set_active"):
		gate_marker.set_active(active)
		gate_marker.visible = active

func _update_pickup_label() -> void:
	if pickup_label:
		pickup_label.text = "Pickups: %d / %d" % [collected_pickups, required_pickups]

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
		# Smoothly pull player 2 toward player 1
		var dir := Vector2(p1.x - p2.x, p1.y - p2.y)
		if dir.length_squared() > 0.01:
			var step := dir.normalized() * (max_player_separation * 3.0) * delta
			var new_pos := Vector2(p2.x, p2.y) + step
			player2.set_world_pos(Vector3(new_pos.x, new_pos.y, p2.z))
			# Stop once close enough
			if Vector2(p1.x - new_pos.x, p1.y - new_pos.y).length() <= max_player_separation * 0.6:
				separation_active = false

func _check_player_fall(p: Node2D, start_tile: Vector2i) -> void:
	if not p or not p.has_method("get_world_pos"):
		return
	var pos: Vector3 = p.get_world_pos()
	if get_tile_height_at(pos.x, pos.y) < -500.0 or pos.z < -200.0:
		_respawn_player(p, start_tile)

func _respawn_player(p: Node2D, tile: Vector2i) -> void:
	var start_height: float = float(height_map.get(tile, 0.0))
	if p.has_method("set_world_pos"):
		p.set_world_pos(Vector3(tile.x + 0.5, tile.y + 0.5, start_height))

func _process(_delta: float) -> void:
	# Camera follows player
	if camera and player:
		if player2:
			camera.position = (player.position + player2.position) * 0.5
		else:
			camera.position = player.position
	
	_update_coop_separation(_delta)
	_check_goal()
	_update_boss_trigger()
	_check_player_fall(player, Vector2i(3, 3))
	if player2:
		_check_player_fall(player2, Vector2i(4, 3))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		if pause_menu and pause_menu.has_method("show_menu"):
			get_tree().paused = true
			pause_menu.show_menu()

# Returns the tile height at a given world x, y position
func get_tile_height_at(world_x: float, world_y: float) -> float:
	var tile_pos := Vector2i(int(floor(world_x)), int(floor(world_y)))
	
	# Check bounds
	if tile_pos.x < 0 or tile_pos.x >= level_width:
		return -1000.0  # Fall into void
	if tile_pos.y < 0 or tile_pos.y >= level_height:
		return -1000.0
	
	return float(height_map.get(tile_pos, 0.0))

# Check if a world position is within a solid tile
func is_solid_at(world_pos: Vector3) -> bool:
	var ground_height := get_tile_height_at(world_pos.x, world_pos.y)
	return world_pos.z <= ground_height

# Helper for player movement: returns true if the step is too high to climb
func is_step_blocked(world_x: float, world_y: float, current_z: float, max_step: float) -> bool:
	var ground_height := get_tile_height_at(world_x, world_y)
	return ground_height > current_z + max_step
