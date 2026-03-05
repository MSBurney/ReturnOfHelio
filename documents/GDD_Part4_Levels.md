# ISOMETRIC PLATFORMER - GAME DESIGN DOCUMENT
## Part 4: Level Design and World Structure

---

## 4.1 WORLD OVERVIEW

### World Progression (Story-Driven)

| World | Name | Theme | Story Focus | Godai |
|-------|------|-------|-------------|-------|
| 1 | Higueran Rainforest | Tutorial/Jungle | Rescue Lien, begin journey | — |
| 2 | Crystal Caves | Underground/Mines | Discover Gem mining operation | — |
| 3 | Caxine Bay | Beach/Ocean | Reunite with Máximo, learn Godai locations | — |
| 4 | Volcanic Ruins | Fire/Lava | Free Ka-Hi (Fire Godai) | 🔥 Fire |
| 5 | Frozen Peaks | Ice/Snow | Free Hyōri (Ice Godai) | ❄️ Ice |
| 6 | Sky Citadel | Floating islands | Free Fūze (Wind Godai) | 💨 Wind |
| 7 | Lalibos Highlands | Mountains/Caves | Free Chi-Tsu (Stone Godai) | 🪨 Stone |
| 8 | Factory Complex | Industrial | Sabotage Tempura's war machines | — |
| 9 | Tempura's Fortress | Dark castle | Final confrontation | — |

### World Gimmicks and Palettes

| World | Gimmick | Color Palette |
|-------|---------|---------------|
| 1 | Basic platforming, vine swinging | Green, brown, blue sky |
| 2 | Bouncy crystals, darkness, mine carts | Purple, cyan, magenta |
| 3 | Water currents, tide timing, ships | Blue, tan, white |
| 4 | Sinking platforms, lava geysers | Red, orange, black |
| 5 | Slippery surfaces, ice puzzles | White, cyan, blue |
| 6 | Wind gusts, cloud platforms | White, gold, light blue |
| 7 | Earthquake hazards, falling rocks | Brown, gray, gold |
| 8 | Conveyor belts, crushers, lasers | Gray, orange, yellow |
| 9 | All gimmicks combined | Black, red, purple |

### Per-World Structure

Each world contains:
- **13 Standard Levels** — Progressively harder
- **1 Boss Level** — After level 13
- **3-5 Secret Areas** — Hidden throughout levels
- **World-Specific Power-ups** — Form gems placed strategically
- **Tactical Battle Encounters** — On world map (see Part 2.5)

---

## 4.2 LEVEL STRUCTURE

### Level Composition

Each level consists of **multiple segments** connected by doors:

```
[SEGMENT A] ──door──► [SEGMENT B] ──door──► [SEGMENT C] ──door──► [EXIT]
     │                      │
     └──secret door──► [SECRET SEGMENT]
```

### Segment Sizes

| Segment Type | Size (Tiles) | Purpose |
|--------------|--------------|---------|
| Small | 12x12 | Transition, item rooms |
| Medium | 16x16 | Standard gameplay |
| Large | 24x24 | Major challenges, hubs |
| Boss Arena | 20x20 | Boss fights |

### Segment Types

1. **Start Segment** — Player spawn, tutorial prompts
2. **Platform Segment** — Jumping challenges
3. **Combat Segment** — Enemy encounters
4. **Puzzle Segment** — Key finding, switch activation
5. **Gimmick Segment** — World-specific mechanics
6. **Hub Segment** — Multiple exits, exploration choice
7. **Boss Segment** — Boss arena
8. **Secret Segment** — Hidden rewards

---

## 4.3 TILE SYSTEM

### Tile Types

```gdscript
enum TileType {
    FLOOR,          # Walkable ground
    WALL,           # Impassable barrier (height-based)
    PIT,            # Instant death
    WATER,          # Slows movement, can drown
    LAVA,           # Damage over time, instant death without protection
    ICE,            # Reduced friction
    CONVEYOR,       # Moves player in direction
    BOUNCE,         # Springs player upward
    CRUMBLE,        # Breaks after standing
    SWITCH,         # Activates connected door/platform
    DOOR_CLOSED,    # Requires key
    DOOR_OPEN,      # Passable exit
    CHECKPOINT,     # Respawn point
    COLLECTIBLE,    # Item pickup location
}
```

### Tile Heights

Tiles can have different heights (in pixels):

| Height | Purpose |
|--------|---------|
| -16 | Pit/water level |
| -8 | Shallow water |
| 0 | Ground level |
| 8 | Low platform |
| 16 | Medium platform |
| 24 | High platform |
| 32 | Tall structure |

### Tile Data Structure

```gdscript
class_name TileData
extends Resource

@export var type: TileType = TileType.FLOOR
@export var height: float = 0.0
@export var color_primary: Color = Color.WHITE
@export var color_secondary: Color = Color.WHITE
@export var is_solid: bool = true
@export var damage: int = 0
@export var properties: Dictionary = {}
```

---

## 4.4 LEVEL DATA FORMAT

### Level File Structure (JSON)

```json
{
    "level_id": "w1_l01",
    "world": 1,
    "level": 1,
    "name": "Green Hills",
    "segments": [
        {
            "id": "start",
            "width": 16,
            "height": 16,
            "tiles": [...],
            "entities": [...],
            "connections": [
                {"door_pos": [15, 8], "target_segment": "main", "target_pos": [0, 8]}
            ]
        },
        {
            "id": "main",
            "width": 24,
            "height": 24,
            "tiles": [...],
            "entities": [...],
            "connections": [...]
        }
    ],
    "start_segment": "start",
    "start_position": [3, 3],
    "collectibles": {
        "keys": 2,
        "secrets": 3,
        "coins": 50
    }
}
```

### Tile Array Format

```json
"tiles": [
    {"x": 0, "y": 0, "type": "FLOOR", "height": 0},
    {"x": 1, "y": 0, "type": "FLOOR", "height": 0},
    {"x": 2, "y": 0, "type": "WALL", "height": 16},
    ...
]
```

### Entity Array Format

```json
"entities": [
    {"type": "enemy_nibbler", "x": 5, "y": 5},
    {"type": "enemy_hopper", "x": 8, "y": 3},
    {"type": "key", "x": 12, "y": 10},
    {"type": "checkpoint", "x": 14, "y": 8},
    ...
]
```

---

## 4.5 WORLD-SPECIFIC GIMMICKS

### World 1: Grasslands (Tutorial)
- **No special gimmicks** — Pure platforming fundamentals
- Introduces: jumping, double jump, homing attack, keys

### World 2: Crystal Caves
- **Bouncy Crystals** — Launch player high when touched
- **Darkness** — Limited visibility, light sources reveal paths
- **Reflective Walls** — Projectiles bounce off

```gdscript
# Bouncy crystal implementation
func _on_player_contact(player: Player) -> void:
    player.velocity.z = bounce_force  # Higher than normal jump
    player.can_double_jump = true
```

### World 3: Seaside Cliffs
- **Water Currents** — Push player in direction
- **Tides** — Water level rises/falls on timer
- **Slippery Seaweed** — Reduced friction

```gdscript
# Water current implementation
func _physics_process(delta: float) -> void:
    for body in get_overlapping_bodies():
        if body is Player:
            body.world_pos.x += current_direction.x * current_strength * delta
            body.world_pos.y += current_direction.y * current_strength * delta
```

### World 4: Volcanic Ruins
- **Sinking Platforms** — Sink when stood on, rise when empty
- **Lava Geysers** — Periodic eruptions blocking paths
- **Heat Shimmer** — Visual effect, no gameplay impact

```gdscript
# Sinking platform implementation
var sink_speed: float = 8.0
var rise_speed: float = 4.0
var min_height: float = -8.0
var max_height: float = 16.0
var is_sinking: bool = false

func _process(delta: float) -> void:
    if is_sinking:
        tile_height = max(min_height, tile_height - sink_speed * delta)
    else:
        tile_height = min(max_height, tile_height + rise_speed * delta)
```

### World 5: Frozen Peaks
- **Ice Friction** — Reduced deceleration on ice tiles
- **Snowball Rolling** — Push snowballs to create platforms
- **Icicle Hazards** — Fall when player passes underneath

```gdscript
# Ice friction modification
func _process_movement(delta: float) -> void:
    var current_tile: TileType = level.get_tile_type_at(world_pos.x, world_pos.y)
    var decel := deceleration
    if current_tile == TileType.ICE:
        decel *= 0.3  # Much less friction
    horizontal_velocity = horizontal_velocity.move_toward(Vector2.ZERO, decel * delta)
```

### World 6: Sky Citadel
- **Wind Gusts** — Push player during jumps
- **Cloud Platforms** — Temporary, disappear after standing
- **Updrafts** — Boost jump height in certain areas

```gdscript
# Wind gust implementation
func _process_gravity(delta: float) -> void:
    if not is_on_ground:
        velocity.z -= gravity * delta
        # Apply wind
        var wind := _get_wind_at_position(world_pos)
        world_pos.x += wind.x * delta
        world_pos.y += wind.y * delta
```

### World 7: Haunted Manor
- **Ghost Walls** — Solid until player looks away
- **Darkness Zones** — Player only visible near light sources
- **Moving Platforms** — Chandeliers, floating furniture

```gdscript
# Ghost wall implementation
func _process(delta: float) -> void:
    var player := get_tree().get_first_node_in_group("player")
    var player_facing := player.get_facing_direction()
    var to_wall := (world_pos - player.world_pos).normalized()
    
    # Wall is solid if player is facing toward it
    is_solid = player_facing.dot(Vector2(to_wall.x, to_wall.y)) > 0.5
```

### World 8: Factory Complex
- **Conveyor Belts** — Move player/enemies in direction
- **Crushers** — Periodic hazards, timing-based
- **Laser Grids** — Activated/deactivated by switches

```gdscript
# Conveyor belt implementation
func _physics_process(delta: float) -> void:
    for body in get_overlapping_bodies():
        if body.has_method("apply_conveyor"):
            body.apply_conveyor(conveyor_direction * conveyor_speed * delta)
```

### World 9: Dark Fortress
- **Combination of all gimmicks**
- **Gravity Zones** — Altered gravity strength
- **Warp Tiles** — Teleport to linked tile

---

## 4.6 LEVEL PROGRESSION

### Difficulty Curve Per World

```
Level 1-3:  Introduction to world theme, easy
Level 4-6:  Standard difficulty, gimmick combinations
Level 7-9:  Challenging, requires mastery
Level 10-12: Hard, multiple mechanics combined
Level 13:   Finale, leads to boss
Boss:       Culmination of world mechanics
```

### Global Difficulty Curve

```
World 1: Tutorial, forgiving
World 2-3: Easy-Medium
World 4-5: Medium
World 6-7: Medium-Hard
World 8: Hard
World 9: Very Hard
```

### Pacing Structure

Each level follows this flow:
1. **Opening** — Safe area, checkpoint
2. **Challenge A** — First test
3. **Respite** — Collectible, safe area
4. **Challenge B** — Escalation
5. **Climax** — Hardest section
6. **Exit** — Reward, door to next level

---

## 4.7 LEVEL EDITOR CONSIDERATIONS

### Runtime Level Loading

```gdscript
class_name LevelLoader
extends Node

func load_level(level_id: String) -> void:
    var path := "res://data/levels/%s.json" % level_id
    var file := FileAccess.open(path, FileAccess.READ)
    var data := JSON.parse_string(file.get_as_text())
    file.close()
    
    _build_level(data)

func _build_level(data: Dictionary) -> void:
    for segment_data in data.segments:
        var segment := _create_segment(segment_data)
        add_child(segment)
    
    _setup_connections(data.segments)
    _spawn_player(data.start_segment, data.start_position)
```

### Level Validation

```gdscript
func validate_level(data: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    
    # Check required fields
    if not data.has("start_segment"):
        errors.append("Missing start_segment")
    
    # Check all connections are valid
    for segment in data.segments:
        for conn in segment.connections:
            if not _segment_exists(data, conn.target_segment):
                errors.append("Invalid connection target: %s" % conn.target_segment)
    
    # Check player can reach exit
    if not _path_exists_to_exit(data):
        errors.append("No path from start to exit")
    
    return errors
```

---

## 4.8 SEGMENT TEMPLATES

### Platform Challenge Template

```
[C] = Checkpoint
[E] = Enemy
[P] = Platform (elevated)
[ ] = Floor
[X] = Pit

[ ][ ][ ][ ][ ][ ][ ][ ]
[ ][C][ ][ ][P][P][ ][ ]
[ ][ ][ ][X][X][X][ ][ ]
[ ][ ][P][X][E][X][P][ ]
[ ][ ][P][X][X][X][P][ ]
[ ][ ][ ][X][X][X][ ][ ]
[ ][ ][ ][ ][P][P][ ][ ]
[ ][ ][ ][ ][ ][ ][D][ ]  (D = Door)
```

### Combat Arena Template

```
[W] = Wall
[E] = Enemy spawn
[C] = Checkpoint
[K] = Key

[W][W][W][W][W][W][W][W]
[W][ ][ ][ ][ ][ ][ ][W]
[W][ ][E][ ][ ][E][ ][W]
[W][ ][ ][ ][K][ ][ ][W]
[W][ ][ ][ ][ ][ ][ ][W]
[W][ ][E][ ][ ][E][ ][W]
[W][C][ ][ ][ ][ ][D][W]
[W][W][W][W][W][W][W][W]
```

### Hub Template

```
[D1], [D2], [D3] = Doors to different paths

[ ][ ][ ][ ][ ][ ][ ][ ]
[ ][ ][ ][D1][ ][ ][ ][ ]
[ ][ ][ ][ ][ ][ ][ ][ ]
[D2][ ][ ][C][ ][ ][D3][ ]
[ ][ ][ ][ ][ ][ ][ ][ ]
[ ][ ][ ][ ][ ][ ][ ][ ]
[ ][ ][ ][ ][ ][ ][ ][ ]
[ ][ ][ ][ ][ ][ ][ ][ ]
```

---

## 4.9 COLLECTIBLE PLACEMENT

### Keys

- **2-3 per level** — Required to open exit door
- Placed behind challenges or minor exploration
- Visible from a distance (glowing, elevated)

### Secrets

- **3-5 per level** — Hidden areas, off the beaten path
- Rewards: extra lives, currency, lore items
- Some require advanced techniques to reach

### Currency (Coins/Gems)

- **50-100 per level** — Scattered throughout
- Encourage exploration and full level traversal
- Can be used for unlocks in hub world

---

## IMPLEMENTATION CHECKLIST

- [x] Basic tile generation (IsoTile)
- [x] Height map system
- [x] Tile rendering with checkerboard
- [ ] Tile type enumeration
- [ ] Level data format (JSON)
- [ ] Level loader
- [ ] Segment connection system
- [ ] Door/key system
- [ ] Checkpoint system
- [ ] World 1 all levels
- [ ] World-specific gimmicks
- [ ] Level editor (optional)
- [ ] Level validation

---

*Continue to Part 5: Progression, Collectibles, and UI*
