# ISOMETRIC PLATFORMER - GAME DESIGN DOCUMENT
## Part 2.5: Tactical RPG Battle Mode

---

## 2.5.1 OVERVIEW

### Concept

Between platforming levels, players navigate a **Super Mario Bros. 3-style world map**. Enemy units (angels and demons) roam this map. When the player contacts an enemy unit, a **simplified Tactical RPG battle** is triggered.

### Design Goals

- **Short and snappy** — Average battle: 2-3 minutes, maximum: 5 minutes
- **Optional encounters** — Enemies can be avoided on the world map
- **Strategic depth without complexity** — Fire Emblem NES-inspired, but dramatically compressed
- **Rewards progression** — Defeating enemies unlocks levels on the world map

### Core Reference

- **Fire Emblem (NES/Famicom)** — Turn-based tactical combat on grid
- **Super Mario Bros. 3** — World map with roaming enemies

---

## 2.5.2 WORLD MAP SYSTEM

### Map Structure

Each world has a connected map with:
- **Level nodes** — Platforming stages (locked/unlocked)
- **Path connections** — Routes between nodes
- **Roaming enemies** — Angel/Demon units that patrol paths
- **Safe zones** — Areas enemies cannot enter (near save points)

### Player Movement on World Map

```gdscript
# Player moves along paths between nodes
# Movement is free-form on paths, not node-to-node
var map_position: Vector2 = Vector2.ZERO
var map_speed: float = 60.0

func _process_world_map(delta: float) -> void:
    var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    
    # Constrain to path
    var new_pos := map_position + input * map_speed * delta
    new_pos = _constrain_to_path(new_pos)
    
    map_position = new_pos
    _check_level_node_overlap()
    _check_enemy_collision()
```

### Roaming Enemies

Enemy units patrol predetermined routes on the world map:

```gdscript
class_name WorldMapEnemy
extends Node2D

enum Faction { ANGEL, DEMON }

@export var faction: Faction = Faction.DEMON
@export var patrol_path: Path2D
@export var patrol_speed: float = 30.0
@export var army_composition: Array[String] = ["soldier", "soldier", "archer"]

var path_progress: float = 0.0
var patrol_direction: int = 1

func _process(delta: float) -> void:
    path_progress += patrol_speed * delta * patrol_direction
    
    if path_progress >= patrol_path.curve.get_baked_length():
        patrol_direction = -1
    elif path_progress <= 0:
        patrol_direction = 1
    
    position = patrol_path.curve.sample_baked(path_progress)
```

### Collision Triggers Battle

```gdscript
func _check_enemy_collision() -> void:
    for enemy in world_map_enemies:
        if map_position.distance_to(enemy.position) < 16.0:
            _start_tactical_battle(enemy)
            return
```

---

## 2.5.3 TACTICAL BATTLE SYSTEM

### Battle Overview

- **Grid-based** — Small maps (8x8 to 12x12 tiles)
- **Turn-based** — Player phase, then enemy phase
- **Unit control** — Anigi commands dragon army
- **Objective** — Defeat all enemy units OR defeat enemy commander

### Battle Parameters

| Parameter | Value |
|-----------|-------|
| Grid size | 8x8 to 12x12 |
| Max player units | 4-6 |
| Max enemy units | 4-8 |
| Turn time limit | None (but designed for quick resolution) |
| Average battle duration | 2-3 minutes |

### Unit Types

#### Player Units (Dragons)

| Unit | Move | Attack | Range | HP | Special |
|------|------|--------|-------|----|---------| 
| **Balloon Dragon** | 4 | 3 | 1 | 8 | Can float over gaps |
| **Fire Dragon** | 3 | 5 | 1-2 | 6 | Fire breath (ranged) |
| **Ice Dragon** | 3 | 4 | 1 | 7 | Freezes enemy (skip turn) |
| **Stone Dragon** | 2 | 4 | 1 | 12 | High defense |
| **Wind Dragon** | 5 | 3 | 1 | 5 | Can push enemies back |
| **Wyvern** | 4 | 4 | 1 | 6 | Flying |

#### Enemy Units (Angels)

| Unit | Move | Attack | Range | HP | Special |
|------|------|--------|-------|----|---------| 
| **Guardian Angel** | 3 | 3 | 1 | 6 | Basic melee |
| **Archangel** | 4 | 5 | 1-2 | 8 | Commander unit |
| **Cherub** | 5 | 2 | 2 | 4 | Healer |
| **Seraph** | 3 | 6 | 1 | 10 | Elite unit |
| **Throne** | 2 | 4 | 1 | 12 | Defensive |

#### Enemy Units (Demons)

| Unit | Move | Attack | Range | HP | Special |
|------|------|--------|-------|----|---------| 
| **Pride Demon** | 3 | 4 | 1 | 7 | Counter-attacks |
| **Wrath Demon** | 4 | 5 | 1 | 6 | Berserk (more damage when hurt) |
| **Greed Demon** | 3 | 3 | 1 | 8 | Steals items |
| **Sloth Demon** | 2 | 3 | 1 | 10 | Puts units to sleep |
| **Envy Demon** | 4 | 4 | 1 | 5 | Copies abilities |
| **Gluttony Demon** | 2 | 6 | 1 | 12 | Devours weakened units |
| **Lust Demon** | 5 | 2 | 1 | 5 | Charms enemies |

---

## 2.5.4 BATTLE FLOW

### Phase Structure

```
┌─────────────────────────────────────────┐
│  PLAYER PHASE                           │
│  - Select unit                          │
│  - Move unit (highlight movement range) │
│  - Attack (if enemy in range)           │
│  - End unit's turn                      │
│  - Repeat for all units                 │
│  - End player phase                     │
├─────────────────────────────────────────┤
│  ENEMY PHASE                            │
│  - AI moves and attacks                 │
│  - Quick animation for each action      │
│  - End enemy phase                      │
├─────────────────────────────────────────┤
│  VICTORY CHECK                          │
│  - All enemies defeated? → VICTORY      │
│  - All player units defeated? → DEFEAT  │
│  - Otherwise → Next turn                │
└─────────────────────────────────────────┘
```

### Combat Calculation

Simple formula for quick resolution:

```gdscript
func calculate_damage(attacker: TacticalUnit, defender: TacticalUnit) -> int:
    var base_damage: int = attacker.attack - defender.defense
    base_damage = max(1, base_damage)  # Minimum 1 damage
    
    # Type advantages (simplified rock-paper-scissors)
    var multiplier: float = _get_type_multiplier(attacker.type, defender.type)
    
    return int(base_damage * multiplier)

func _get_type_multiplier(attacker_type: String, defender_type: String) -> float:
    # Fire > Ice > Wind > Fire (triangular)
    # Stone is neutral
    match [attacker_type, defender_type]:
        ["fire", "ice"]: return 1.5
        ["ice", "wind"]: return 1.5
        ["wind", "fire"]: return 1.5
        ["ice", "fire"]: return 0.75
        ["wind", "ice"]: return 0.75
        ["fire", "wind"]: return 0.75
    return 1.0
```

### Simplified Counter-Attack

If defender survives and attacker is in defender's range, defender counter-attacks for 50% damage.

---

## 2.5.5 USER INTERFACE

### Battle Screen Layout

```
┌─────────────────────────────────────────────────┐
│  TURN 3 - PLAYER PHASE              [HP] [ATK] │
├─────────────────────────────────────────────────┤
│                                                 │
│     ┌───┬───┬───┬───┬───┬───┬───┬───┐         │
│     │   │ D │   │   │ E │   │   │   │         │
│     ├───┼───┼───┼───┼───┼───┼───┼───┤         │
│     │   │   │   │   │   │   │ E │   │         │
│     ├───┼───┼───┼───┼───┼───┼───┼───┤         │
│     │ P │   │   │   │   │   │   │   │         │
│     ├───┼───┼───┼───┼───┼───┼───┼───┤         │
│     │   │ P │   │   │   │   │   │   │         │
│     └───┴───┴───┴───┴───┴───┴───┴───┘         │
│                                                 │
│  P = Player unit   D = Dragon   E = Enemy      │
├─────────────────────────────────────────────────┤
│  [A] Select  [B] Cancel  [START] End Phase     │
└─────────────────────────────────────────────────┘
```

### Unit Selection

```gdscript
func _on_unit_selected(unit: TacticalUnit) -> void:
    if unit.has_acted:
        return
    
    selected_unit = unit
    _highlight_movement_range(unit)
    _highlight_attack_range(unit)
    battle_state = BattleState.UNIT_SELECTED
```

### Movement Range Visualization

```gdscript
func _highlight_movement_range(unit: TacticalUnit) -> void:
    movement_tiles.clear()
    var start := unit.grid_position
    
    # BFS to find all reachable tiles
    var frontier: Array[Vector2i] = [start]
    var distances: Dictionary = {start: 0}
    
    while not frontier.is_empty():
        var current := frontier.pop_front()
        var current_dist: int = distances[current]
        
        if current_dist >= unit.move_range:
            continue
        
        for neighbor in _get_neighbors(current):
            if not distances.has(neighbor) and _is_walkable(neighbor):
                distances[neighbor] = current_dist + 1
                frontier.append(neighbor)
                movement_tiles.append(neighbor)
```

---

## 2.5.6 AI BEHAVIOR

### Simple Aggressive AI

Enemy AI prioritizes:
1. Attack weakest player unit in range
2. Move toward nearest player unit
3. If healer, prioritize healing wounded allies

```gdscript
func _execute_enemy_turn(unit: TacticalUnit) -> void:
    # Find targets in attack range
    var targets := _get_attackable_targets(unit)
    
    if not targets.is_empty():
        # Attack weakest target
        var weakest := _find_weakest(targets)
        _perform_attack(unit, weakest)
        return
    
    # No targets - move toward nearest player unit
    var nearest := _find_nearest_player_unit(unit)
    if nearest:
        var path := _calculate_path(unit.grid_position, nearest.grid_position)
        var move_target := path[min(unit.move_range, path.size() - 1)]
        _move_unit(unit, move_target)
        
        # Check if can attack after moving
        targets = _get_attackable_targets(unit)
        if not targets.is_empty():
            var weakest := _find_weakest(targets)
            _perform_attack(unit, weakest)
```

---

## 2.5.7 REWARDS AND CONSEQUENCES

### Victory Rewards

| Reward Type | Effect |
|-------------|--------|
| **Unlock Level** | Opens a locked level node on world map |
| **Bonus Coins** | Currency for upgrades/unlocks |
| **Unit Experience** | Dragons gain strength over time (optional) |

### Defeat Consequences

| Consequence | Effect |
|-------------|--------|
| **No unlock** | Level remains locked |
| **Enemy respawns** | After a short time, enemy returns to patrol |
| **No penalty** | No lives lost, can retry |

### Implementation

```gdscript
func _on_battle_victory(enemy: WorldMapEnemy) -> void:
    # Remove enemy from world map
    enemy.queue_free()
    
    # Unlock associated level
    if enemy.unlocks_level != "":
        GameManager.unlock_level(enemy.unlocks_level)
    
    # Award coins
    GameManager.add_coins(enemy.coin_reward)
    
    # Return to world map
    _transition_to_world_map()

func _on_battle_defeat() -> void:
    # Return to world map, enemy still exists
    _transition_to_world_map()
```

---

## 2.5.8 BATTLE MAP DESIGN

### Map Templates

**Open Field (Beginner)**
```
████████
█      █
█  P   █
█ P    █
█    E █
█   E  █
█      █
████████
```

**Choke Point (Intermediate)**
```
████████
█P    E█
█P ██ E█
█  ██  █
█  ██  █
█P ██ E█
█P    E█
████████
```

**Multi-Path (Advanced)**
```
████████
█P  █ E█
█P  █ E█
█   █  █
█  ███ █
█      █
█P    E█
████████
```

### Terrain Types

| Terrain | Effect |
|---------|--------|
| **Plain** | Normal movement |
| **Forest** | +1 defense, +1 move cost |
| **Mountain** | Impassable (flying units can cross) |
| **Water** | Impassable (except flying) |
| **Fortress** | +2 defense, heals 10% HP per turn |

---

## 2.5.9 INTEGRATION WITH MAIN GAME

### Narrative Connection

- **Anigi leads the dragons** — She commands the dragon army as the Dragon Priestess
- **Helio is not present** — These battles happen while Helio is in platforming levels
- **Enemy factions** — Same angels and demons from the story

### World Map Flow

```
[World 1 Start]
     │
     ▼
[Level 1-1] ─────► [Level 1-2] ─────► [Level 1-3]
                        │
                   [Enemy Unit] ← Contact triggers battle
                        │
                   [Locked Level 1-4]
                        │
                   (Defeat enemy to unlock)
```

### When Battles Occur

- **Blocking paths** — Some enemies block the only path forward
- **Optional shortcuts** — Defeating enemies opens faster routes
- **Bonus content** — Some enemies guard secret areas

---

## IMPLEMENTATION CHECKLIST

- [ ] World map system
- [ ] World map player movement
- [ ] Roaming enemy units
- [ ] Enemy patrol paths
- [ ] Battle trigger on collision
- [ ] Tactical battle grid
- [ ] Turn phase system
- [ ] Unit selection and movement
- [ ] Attack calculation
- [ ] Counter-attack system
- [ ] Type advantages
- [ ] Enemy AI (aggressive)
- [ ] Battle UI
- [ ] Victory/defeat conditions
- [ ] Reward system (unlock levels)
- [ ] Transition back to world map
- [ ] Dragon unit roster
- [ ] Angel enemy units
- [ ] Demon enemy units
- [ ] Terrain effects
- [ ] Battle maps (5-10 templates)

---

*Continue to Part 3: Enemy Design and Combat*
