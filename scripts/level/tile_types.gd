class_name TileTypes
extends RefCounted

## Tile type definitions and TileData for the isometric tile system.

enum TileType {
	FLOOR,        # Walkable ground
	WALL,         # Impassable barrier (height-based)
	PIT,          # Instant death
	WATER,        # Slows movement, can drown
	LAVA,         # Damage over time
	ICE,          # Reduced friction
	CONVEYOR,     # Moves player in direction
	BOUNCE,       # Springs player upward
	CRUMBLE,      # Breaks after standing
	SWITCH,       # Activates connected door/platform
	DOOR_CLOSED,  # Requires key
	DOOR_OPEN,    # Passable exit
	CHECKPOINT,   # Respawn point
	COLLECTIBLE,  # Item pickup location
}

## Returns whether a tile type is solid (blocks movement from below)
static func is_type_solid(type: TileType) -> bool:
	match type:
		TileType.PIT, TileType.WATER, TileType.LAVA:
			return false
		_:
			return true

## Returns the contact damage for a tile type
static func get_type_damage(type: TileType) -> int:
	match type:
		TileType.PIT:
			return -1  # Instant death
		TileType.LAVA:
			return 1
		_:
			return 0

## Returns the friction modifier for a tile type (1.0 = normal)
static func get_type_friction(type: TileType) -> float:
	match type:
		TileType.ICE:
			return 0.3
		TileType.WATER:
			return 0.6
		_:
			return 1.0

## Returns the bounce force for bounce tiles (0.0 = no bounce)
static func get_type_bounce(type: TileType) -> float:
	match type:
		TileType.BOUNCE:
			return 250.0
		_:
			return 0.0

## Converts a string name to a TileType enum value (for JSON parsing)
static func from_string(type_name: String) -> TileType:
	match type_name.to_upper():
		"FLOOR": return TileType.FLOOR
		"WALL": return TileType.WALL
		"PIT": return TileType.PIT
		"WATER": return TileType.WATER
		"LAVA": return TileType.LAVA
		"ICE": return TileType.ICE
		"CONVEYOR": return TileType.CONVEYOR
		"BOUNCE": return TileType.BOUNCE
		"CRUMBLE": return TileType.CRUMBLE
		"SWITCH": return TileType.SWITCH
		"DOOR_CLOSED": return TileType.DOOR_CLOSED
		"DOOR_OPEN": return TileType.DOOR_OPEN
		"CHECKPOINT": return TileType.CHECKPOINT
		"COLLECTIBLE": return TileType.COLLECTIBLE
		_: return TileType.FLOOR
