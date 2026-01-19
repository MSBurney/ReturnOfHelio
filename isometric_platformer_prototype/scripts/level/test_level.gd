class_name TestLevel
extends Node2D

const IsoTileScript := preload("res://scripts/level/iso_tile.gd")
const EnemyScene := preload("res://scenes/enemies/enemy.tscn")

# Level dimensions (in tiles)
@export var level_width: int = 16
@export var level_height: int = 16

# Tile colors (Snake: Rattle n' Roll style green)
@export var grass_color_a: Color = Color(0.18, 0.55, 0.18)
@export var grass_color_b: Color = Color(0.25, 0.65, 0.25)

# Tile height data - stores height at each tile position
var height_map: Dictionary = {}

# Node references
@onready var tile_container: Node2D = $Tiles
@onready var enemy_container: Node2D = $Enemies
@onready var player: Node2D = $Player
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	_generate_height_map()
	_generate_tiles()
	_spawn_enemies()
	_setup_player()

func _generate_height_map() -> void:
	# Create a simple height map with some platforms
	for x in range(level_width):
		for y in range(level_height):
			var height: float = 0.0
			
			# Create some elevated platforms
			# Center raised area
			if x >= 6 and x <= 9 and y >= 6 and y <= 9:
				height = 16.0
			
			# Stepped platforms on the right
			if x >= 12 and x <= 14 and y >= 2 and y <= 5:
				height = 8.0
			if x >= 13 and x <= 14 and y >= 3 and y <= 4:
				height = 16.0
			
			# Lower area (pit/water level simulation)
			if x >= 2 and x <= 4 and y >= 10 and y <= 13:
				height = -8.0
			
			# Ramp-like structure (stepped)
			if x >= 10 and y >= 10 and y <= 12:
				height = (x - 10) * 4.0
			
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

func _spawn_enemies() -> void:
	# Spawn three test enemies at different locations
	var enemy_positions: Array[Vector2i] = [
		Vector2i(6, 4),   # Near the center platform
		Vector2i(8, 8),   # On the center platform
		Vector2i(12, 3),  # Near the stepped platforms
	]
	
	for pos in enemy_positions:
		var ground_height: float = float(height_map.get(pos, 0.0))
		var enemy: Node2D = EnemyScene.instantiate()
		enemy_container.add_child(enemy)
		enemy.setup(pos.x, pos.y, ground_height)

func _process(_delta: float) -> void:
	# Camera follows player
	if camera and player:
		camera.position = player.position

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
