# ISOMETRIC PLATFORMER - GAME DESIGN DOCUMENT
## Part 5: Progression, Collectibles, and UI

---

## 5.1 PROGRESSION SYSTEM

### World Unlock Flow

```
World 1 ──(beat boss)──► World 2 ──(beat boss)──► World 3
                                                      │
World 6 ◄──(beat boss)── World 5 ◄──(beat boss)── World 4
    │
World 7 ──(beat boss)──► World 8 ──(beat boss)──► World 9
                                                      │
                                              FINAL BOSS
```

### Level Unlock Within World

- Levels unlock **sequentially** (beat 1 to unlock 2)
- Boss unlocks after completing all 13 levels
- **Secret levels** unlock via hidden exits (optional)

### Save System

```gdscript
class_name SaveData
extends Resource

@export var current_world: int = 1
@export var current_level: int = 1
@export var completed_levels: Dictionary = {}  # {"w1_l01": true, ...}
@export var collected_secrets: Dictionary = {}
@export var total_coins: int = 0
@export var total_playtime: float = 0.0
@export var deaths: int = 0
@export var settings: Dictionary = {}
```

### Save/Load Implementation

```gdscript
const SAVE_PATH := "user://save.tres"

func save_game() -> void:
    var save := SaveData.new()
    save.current_world = current_world
    save.current_level = current_level
    save.completed_levels = completed_levels
    # ... populate all fields
    ResourceSaver.save(save, SAVE_PATH)

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var save: SaveData = load(SAVE_PATH)
    current_world = save.current_world
    current_level = save.current_level
    # ... restore all fields
    return true
```

---

## 5.2 COLLECTIBLES

### Key Items

| Item | Purpose | Visual |
|------|---------|--------|
| **Door Key** | Opens locked doors within level | Gold key, sparkle effect |
| **Boss Key** | Opens boss room (World 9 only) | Large ornate key |
| **Secret Key** | Opens secret areas | Silver key, glow |

### Currency

| Item | Value | Visual |
|------|-------|--------|
| **Coin** | 1 | Small gold circle |
| **Silver Coin** | 5 | Larger silver circle |
| **Gem** | 10 | Colored crystal |

### Power-Ups (Future Enhancement)

| Item | Effect | Duration |
|------|--------|----------|
| **Speed Boost** | 1.5x movement speed | 10 seconds |
| **Shield** | Blocks one hit | Until hit |
| **Magnet** | Attracts nearby coins | 15 seconds |
| **Double Coins** | 2x coin value | 30 seconds |

### Collectible Implementation

```gdscript
class_name Collectible
extends Node2D

enum CollectibleType { KEY, COIN, GEM, SECRET, POWERUP }

@export var type: CollectibleType = CollectibleType.COIN
@export var value: int = 1
@export var bob_amplitude: float = 2.0
@export var bob_speed: float = 3.0
@export var rotation_speed: float = 2.0

var world_pos: Vector3 = Vector3.ZERO
var bob_time: float = 0.0
var base_z: float = 0.0

func _ready() -> void:
    add_to_group("collectibles")
    bob_time = randf() * TAU

func _process(delta: float) -> void:
    bob_time += delta * bob_speed
    world_pos.z = base_z + sin(bob_time) * bob_amplitude
    rotation += rotation_speed * delta
    _update_visual()

func collect(player: Player) -> void:
    match type:
        CollectibleType.KEY:
            player.add_key()
        CollectibleType.COIN, CollectibleType.GEM:
            player.add_coins(value)
        CollectibleType.SECRET:
            player.add_secret()
        CollectibleType.POWERUP:
            player.apply_powerup(_get_powerup_type())
    
    _play_collect_effect()
    queue_free()
```

---

## 5.3 SCORING SYSTEM

### Score Sources

| Action | Points |
|--------|--------|
| Defeat enemy (stomp) | 100 |
| Defeat enemy (homing) | 150 |
| Defeat enemy (chain 2+) | 200 per enemy |
| Collect coin | 10 |
| Collect gem | 50 |
| Find secret | 1000 |
| Complete level | 5000 |
| Complete level (no deaths) | +2500 bonus |
| Speed bonus (under par time) | Variable |
| Beat boss | 10000 |

### Chain Bonus

```gdscript
var chain_count: int = 0
var chain_timer: float = 0.0
const CHAIN_TIMEOUT: float = 2.0

func _on_enemy_defeated() -> void:
    chain_count += 1
    chain_timer = CHAIN_TIMEOUT
    
    var points: int
    if chain_count >= 2:
        points = 200 * chain_count  # Escalating bonus
    else:
        points = 150
    
    add_score(points)
    _show_chain_popup(chain_count)

func _process(delta: float) -> void:
    if chain_count > 0:
        chain_timer -= delta
        if chain_timer <= 0:
            chain_count = 0
```

### Leaderboards (Future Enhancement)

- Per-level leaderboards
- Global score leaderboards
- Speedrun leaderboards (time-based)

---

## 5.4 LIVES AND GAME OVER

### Health System

- **3 Hearts** — Player starts with 3 health
- **Lose 1 Heart** — Hit by enemy or hazard
- **Lose All Hearts** — Return to checkpoint, lose 1 life
- **Instant Death** — Pits, crushing, some hazards

### Lives System

- **Start with 5 Lives**
- **Gain Life** — Every 100 coins, find 1-Up item
- **Lose Life** — Lose all hearts
- **Game Over** — 0 lives, return to world map (keep progress)

```gdscript
var current_health: int = 3
var max_health: int = 3
var lives: int = 5

func take_damage(amount: int) -> void:
    current_health -= amount
    if current_health <= 0:
        _die()

func _die() -> void:
    lives -= 1
    if lives <= 0:
        _game_over()
    else:
        _respawn_at_checkpoint()
        current_health = max_health

func _game_over() -> void:
    # Show game over screen
    # Return to world map
    # Lives reset to 5, level progress retained
    pass
```

### Checkpoints

- Placed every 1-2 segments
- Activated by touching
- Visual indicator (flag raises, light activates)
- Restore full health on respawn

---

## 5.5 USER INTERFACE

### HUD Elements

```
┌─────────────────────────────────────────────────────┐
│ [❤️][❤️][❤️]                    [🔑] x2    [💰] 0047 │
│                                                     │
│                                                     │
│                     GAME AREA                       │
│                                                     │
│                                                     │
│                                                     │
│                                         [LIVES] x5  │
└─────────────────────────────────────────────────────┘
```

### HUD Implementation

```gdscript
class_name HUD
extends CanvasLayer

@onready var hearts_container: HBoxContainer = $HeartsContainer
@onready var key_count: Label = $KeyCount
@onready var coin_count: Label = $CoinCount
@onready var lives_count: Label = $LivesCount

func update_health(current: int, max_health: int) -> void:
    for i in range(hearts_container.get_child_count()):
        var heart: TextureRect = hearts_container.get_child(i)
        heart.visible = i < max_health
        heart.modulate = Color.WHITE if i < current else Color(0.3, 0.3, 0.3)

func update_keys(count: int) -> void:
    key_count.text = "x%d" % count

func update_coins(count: int) -> void:
    coin_count.text = "%04d" % count

func update_lives(count: int) -> void:
    lives_count.text = "x%d" % count
```

### Pause Menu

```
┌─────────────────────────────┐
│         PAUSED              │
│                             │
│    ► RESUME                 │
│      OPTIONS                │
│      RESTART LEVEL          │
│      QUIT TO MAP            │
│                             │
└─────────────────────────────┘
```

### Options Menu

```
┌─────────────────────────────┐
│         OPTIONS             │
│                             │
│  Music Volume    [████░░] 70%│
│  SFX Volume      [█████░] 90%│
│  Screen Shake    [ON] OFF   │
│  Colorblind Mode OFF [ON]   │
│                             │
│    ► BACK                   │
└─────────────────────────────┘
```

### World Map

```
┌─────────────────────────────────────────────────────┐
│  WORLD SELECT                         [💰] 12,345   │
│                                                     │
│    [1]━━━[2]━━━[3]                                 │
│              ┃                                     │
│    [6]━━━[5]━━━[4]                                 │
│     ┃                                               │
│    [7]━━━[8]━━━[9]                                 │
│                                                     │
│  World 1: Grasslands      13/13 ⭐⭐⭐              │
│  Press A to enter                                   │
└─────────────────────────────────────────────────────┘
```

### Level Select (Within World)

```
┌─────────────────────────────────────────────────────┐
│  WORLD 1: GRASSLANDS                                │
│                                                     │
│  [01]⭐ [02]⭐ [03]⭐ [04]⭐ [05]⭐                  │
│  [06]⭐ [07]⭐ [08]⭐ [09]⭐ [10]⭐                  │
│  [11]⭐ [12]⭐ [13]⭐                                │
│                                                     │
│  [BOSS] 🔒                                          │
│                                                     │
│  Level 1: Green Hills                               │
│  Best Time: 1:23.45    Secrets: 3/3                │
└─────────────────────────────────────────────────────┘
```

---

## 5.6 NES-STYLE UI AESTHETICS

### Typography

- **Primary Font**: Pixel font, 8x8 characters
- **Numbers**: Monospace for consistent alignment
- **Colors**: White text, dark backgrounds

### UI Color Palette

```gdscript
const UI_COLORS := {
    "background": Color(0.1, 0.1, 0.15),
    "panel": Color(0.15, 0.15, 0.2),
    "border": Color(0.8, 0.8, 0.9),
    "text": Color(1.0, 1.0, 1.0),
    "text_disabled": Color(0.5, 0.5, 0.5),
    "highlight": Color(1.0, 0.8, 0.2),
    "health": Color(1.0, 0.2, 0.2),
    "coins": Color(1.0, 0.85, 0.0),
}
```

### UI Animation

- **Menu Selection**: Bounce/pulse on hover
- **Health Loss**: Flash and shake
- **Coin Pickup**: Pop-up number, fly to counter
- **Level Complete**: Fanfare, score tally animation

```gdscript
func _animate_coin_pickup(amount: int, world_position: Vector2) -> void:
    var popup := coin_popup_scene.instantiate()
    popup.position = world_position
    popup.text = "+%d" % amount
    add_child(popup)
    
    var tween := create_tween()
    tween.tween_property(popup, "position:y", popup.position.y - 20, 0.5)
    tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.5)
    tween.tween_callback(popup.queue_free)
```

---

## 5.7 SCREEN TRANSITIONS

### Level Transitions

```gdscript
func _transition_to_level(world: int, level: int) -> void:
    # Fade out
    var tween := create_tween()
    tween.tween_property(transition_rect, "color:a", 1.0, 0.3)
    await tween.finished
    
    # Load level
    _load_level(world, level)
    
    # Fade in
    tween = create_tween()
    tween.tween_property(transition_rect, "color:a", 0.0, 0.3)
```

### Door Transitions (Within Level)

```gdscript
func _transition_through_door(door: Door) -> void:
    # Brief fade or iris wipe
    # Move player to connected segment
    # Camera pan to new area
    pass
```

### World Map Transitions

- Smooth camera pan between selected worlds
- World preview thumbnail on selection
- Boss icon shows completion status

---

## 5.8 ACCESSIBILITY OPTIONS

### Visual Accessibility

| Option | Description |
|--------|-------------|
| Colorblind Mode | Alternate color palettes (deuteranopia, protanopia, tritanopia) |
| High Contrast | Increased contrast for visibility |
| Screen Shake | Toggle on/off |
| Flash Reduction | Reduce intense visual effects |
| UI Scale | Adjust HUD size |

### Audio Accessibility

| Option | Description |
|--------|-------------|
| Music Volume | 0-100% |
| SFX Volume | 0-100% |
| Mono Audio | Combine stereo to mono |
| Subtitles | For any voiced content |

### Control Accessibility

| Option | Description |
|--------|-------------|
| Remappable Controls | All buttons remappable |
| Auto-Run | Toggle vs hold to run |
| Aim Assist | Larger homing attack range |
| Invincibility Mode | For story/exploration only |

### Difficulty Options

| Mode | Description |
|------|-------------|
| Normal | Default experience |
| Easy | More health, fewer enemies, more checkpoints |
| Hard | Less health, more enemies, limited checkpoints |
| Speedrun | Timer visible, no deaths required |

---

## IMPLEMENTATION CHECKLIST

- [ ] Save/load system
- [ ] Key collectible
- [ ] Coin collectible
- [ ] Gem collectible
- [ ] Score system
- [ ] Chain bonus
- [ ] Health system
- [ ] Lives system
- [ ] Checkpoint system
- [ ] HUD (hearts, keys, coins, lives)
- [ ] Pause menu
- [ ] Options menu
- [ ] World map
- [ ] Level select
- [ ] Screen transitions
- [ ] Coin pickup animation
- [ ] Accessibility options

---

*Continue to Part 6: Story, Characters, and World Lore*
