# ISOMETRIC PLATFORMER - GAME DESIGN DOCUMENT
## Part 8: Multiplayer, Co-op Systems, and Technical Specifications

---

## 8.1 CO-OP OVERVIEW

### Same-Screen Co-op

- **2 Players** on same screen
- **Local only** — No online multiplayer (scope limitation)
- **Drop-in/Drop-out** — Player 2 can join/leave anytime
- **Shared progression** — Both players share lives, keys, score
- **Elastic Tether** — Players connected by visible elastic band

### Player Identification

| Player | Color | Name | Controls |
|--------|-------|------|----------|
| Player 1 | Red/Orange | Pip | Keyboard/Gamepad 1 |
| Player 2 | Blue | Pax | Gamepad 2 |

---

## 8.2 ELASTIC TETHER SYSTEM

### Tether Mechanics (Knuckles Chaotix-Inspired)

When two players are connected:
- **Visible elastic band** between players
- **Maximum distance** — 64 pixels screen space
- **Pulling force** — Beyond max distance, players pulled toward each other
- **Slingshot launch** — Run away, then release toward partner

### Tether Parameters

```gdscript
const TETHER_REST_LENGTH: float = 32.0  # Pixels, no force
const TETHER_MAX_LENGTH: float = 64.0   # Pixels, max stretch
const TETHER_STIFFNESS: float = 100.0   # Pull force multiplier
const SLINGSHOT_CHARGE_TIME: float = 0.5
const SLINGSHOT_MAX_SPEED: float = 200.0
```

### Tether Implementation

```gdscript
class_name TetherSystem
extends Node2D

var player1: Player
var player2: Player
var tether_length: float = 0.0
var is_stretched: bool = false
var slingshot_charge: float = 0.0

func _physics_process(delta: float) -> void:
    if not player1 or not player2:
        return
    
    var p1_screen := player1.global_position
    var p2_screen := player2.global_position
    tether_length = p1_screen.distance_to(p2_screen)
    
    if tether_length > TETHER_MAX_LENGTH:
        _apply_tether_force(delta)
    
    _update_visual()

func _apply_tether_force(delta: float) -> void:
    var direction := (player2.global_position - player1.global_position).normalized()
    var stretch := tether_length - TETHER_REST_LENGTH
    var force := direction * stretch * TETHER_STIFFNESS * delta
    
    # Apply equal and opposite forces
    player1.apply_external_force(force)
    player2.apply_external_force(-force)

func _update_visual() -> void:
    queue_redraw()

func _draw() -> void:
    if not player1 or not player2:
        return
    
    var p1_local := to_local(player1.global_position)
    var p2_local := to_local(player2.global_position)
    
    # Color based on stretch
    var color := Color.WHITE
    if tether_length > TETHER_REST_LENGTH:
        var stretch_ratio := (tether_length - TETHER_REST_LENGTH) / (TETHER_MAX_LENGTH - TETHER_REST_LENGTH)
        color = Color.WHITE.lerp(Color.RED, stretch_ratio)
    
    draw_line(p1_local, p2_local, color, 2.0)
```

### Slingshot Mechanic

```gdscript
var is_charging_slingshot: bool = false
var slingshot_direction: Vector2 = Vector2.ZERO

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("slingshot") and tether_length > TETHER_REST_LENGTH:
        is_charging_slingshot = true
        slingshot_charge = 0.0
    elif event.is_action_released("slingshot") and is_charging_slingshot:
        _launch_slingshot()

func _physics_process(delta: float) -> void:
    if is_charging_slingshot:
        slingshot_charge = min(slingshot_charge + delta, SLINGSHOT_CHARGE_TIME)

func _launch_slingshot() -> void:
    is_charging_slingshot = false
    var charge_ratio := slingshot_charge / SLINGSHOT_CHARGE_TIME
    var launch_speed := SLINGSHOT_MAX_SPEED * charge_ratio
    var direction := (player2.global_position - player1.global_position).normalized()
    player1.launch(direction * launch_speed)
```

---

## 8.3 CO-OP CAMERA SYSTEM

### Camera Behavior

- **Center on midpoint** between both players
- **Zoom out** when players are far apart
- **Zoom in** when players are close
- **Boundaries** — Don't zoom out beyond level bounds

### Camera Implementation

```gdscript
class_name CoopCamera
extends Camera2D

@export var min_zoom: float = 1.0
@export var max_zoom: float = 2.0
@export var zoom_margin: float = 32.0
@export var smooth_speed: float = 5.0

var player1: Player
var player2: Player

func _process(delta: float) -> void:
    if not player1:
        return
    
    var target_position: Vector2
    var target_zoom: float
    
    if player2 and player2.is_active:
        target_position = (player1.global_position + player2.global_position) / 2.0
        var distance := player1.global_position.distance_to(player2.global_position)
        var required_size := distance + zoom_margin * 2
        var screen_size := get_viewport_rect().size
        var required_zoom := max(required_size / screen_size.x, required_size / screen_size.y)
        target_zoom = clamp(required_zoom, min_zoom, max_zoom)
    else:
        target_position = player1.global_position
        target_zoom = min_zoom
    
    global_position = global_position.lerp(target_position, smooth_speed * delta)
    zoom = zoom.lerp(Vector2.ONE / target_zoom, smooth_speed * delta)
```

---

## 8.4 CO-OP GAME STATE

### Shared Resources

| Resource | Behavior |
|----------|----------|
| Lives | Shared pool, either player dying costs 1 life |
| Keys | Shared, either player can collect |
| Coins | Shared total |
| Score | Combined score |
| Checkpoints | Both respawn at same checkpoint |

### Respawn Behavior

```gdscript
func _on_player_died(player: Player) -> void:
    lives -= 1
    
    if lives <= 0:
        _game_over()
        return
    
    player.respawn(checkpoint_position)
    player.set_invincible(2.0)
```

### Drop-in/Drop-out

```gdscript
func _spawn_player2() -> void:
    player2 = player_scene.instantiate()
    player2.player_id = 2
    player2.global_position = player1.global_position + Vector2(16, 0)
    add_child(player2)
    player2_active = true
    tether_system.player2 = player2

func _remove_player2() -> void:
    player2.queue_free()
    player2 = null
    player2_active = false
    tether_system.player2 = null
```

---

## 8.5 TECHNICAL ARCHITECTURE

### Scene Structure

```
Main
├── GameManager (autoload)
├── AudioManager (autoload)
├── InputManager (autoload)
└── CurrentScene
    └── Level
        ├── ParallaxBackground
        ├── TileContainer
        ├── EntityContainer
        │   ├── Player1
        │   ├── Player2 (if co-op)
        │   ├── Enemies
        │   └── Collectibles
        ├── TetherSystem (if co-op)
        ├── Camera2D
        └── CanvasLayer (HUD)
```

### Autoload Singletons

```gdscript
# GameManager - Global game state
class_name GameManager
extends Node

var current_world: int = 1
var current_level: int = 1
var lives: int = 5
var coins: int = 0
var keys: int = 0
var score: int = 0
var is_coop: bool = false

signal lives_changed(new_value: int)
signal coins_changed(new_value: int)
signal keys_changed(new_value: int)
signal score_changed(new_value: int)
```

```gdscript
# AudioManager - Sound playback
class_name AudioManager
extends Node

var music_player: AudioStreamPlayer
var sfx_pools: Dictionary = {}

func play_music(track: String) -> void
func play_sfx(sound: String) -> void
func set_music_volume(volume: float) -> void
func set_sfx_volume(volume: float) -> void
```

```gdscript
# InputManager - Input handling for multiple players
class_name InputManager
extends Node

var player_devices: Dictionary = {1: -1, 2: -1}  # -1 = keyboard

func get_movement_vector(player_id: int) -> Vector2
func is_action_pressed(player_id: int, action: String) -> bool
func is_action_just_pressed(player_id: int, action: String) -> bool
```

---

## 8.6 PERFORMANCE TARGETS

### Frame Rate

| Platform | Target | Minimum |
|----------|--------|---------|
| PC | 60 FPS | 60 FPS |
| Switch | 60 FPS | 30 FPS |
| PS4/Xbox One | 60 FPS | 60 FPS |
| PS5/Series X | 60 FPS | 60 FPS |

### Memory Budget

| Category | Budget |
|----------|--------|
| Textures | 64 MB |
| Audio | 32 MB |
| Level Data | 16 MB |
| Code/Scripts | 8 MB |
| **Total** | **~120 MB** |

### Optimization Strategies

```gdscript
# Object pooling for frequently spawned objects
class_name ObjectPool
extends Node

var pool: Array[Node] = []
var scene: PackedScene

func get_object() -> Node:
    for obj in pool:
        if not obj.visible:
            obj.visible = true
            obj.set_process(true)
            return obj
    var new_obj := scene.instantiate()
    pool.append(new_obj)
    add_child(new_obj)
    return new_obj

func return_object(obj: Node) -> void:
    obj.visible = false
    obj.set_process(false)
```

```gdscript
# Hybrid culling - skip processing off-screen entities
func _physics_process(delta: float) -> void:
    var camera_rect := _get_camera_rect()
    for enemy in enemies:
        var on_screen := camera_rect.has_point(enemy.global_position)
        enemy.set_physics_process(on_screen)
        enemy.visible = on_screen
```

---

## 8.7 SAVE SYSTEM ARCHITECTURE

### Save Data Structure

```gdscript
class_name SaveData
extends Resource

# Progress
@export var completed_levels: Dictionary = {}  # "w1_l01": {time, secrets, coins}
@export var unlocked_worlds: Array[int] = [1]
@export var collected_lore: Array[String] = []

# Statistics
@export var total_playtime: float = 0.0
@export var total_deaths: int = 0
@export var total_coins: int = 0
@export var enemies_defeated: int = 0

# Settings
@export var music_volume: float = 1.0
@export var sfx_volume: float = 1.0
@export var screen_shake: bool = true
@export var colorblind_mode: int = 0

# Current session (not persisted between plays)
var session_lives: int = 5
var session_coins: int = 0
var session_keys: int = 0
```

### Save/Load Implementation

```gdscript
const SAVE_PATH := "user://save.tres"
const BACKUP_PATH := "user://save_backup.tres"

func save_game() -> bool:
    # Create backup first
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
    
    var result := ResourceSaver.save(save_data, SAVE_PATH)
    return result == OK

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    
    var loaded: SaveData = load(SAVE_PATH)
    if loaded:
        save_data = loaded
        return true
    
    # Try backup
    if FileAccess.file_exists(BACKUP_PATH):
        loaded = load(BACKUP_PATH)
        if loaded:
            save_data = loaded
            return true
    
    return false

func delete_save() -> void:
    DirAccess.remove_absolute(SAVE_PATH)
    DirAccess.remove_absolute(BACKUP_PATH)
    save_data = SaveData.new()
```

---

## 8.8 INPUT HANDLING

### Input Actions

```
# project.godot input map
move_up_p1, move_down_p1, move_left_p1, move_right_p1
jump_p1, attack_p1, pause_p1
move_up_p2, move_down_p2, move_left_p2, move_right_p2
jump_p2, attack_p2, slingshot_p2
```

### Controller Support

```gdscript
func _ready() -> void:
    Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
    if connected:
        print("Controller %d connected" % device)
        if device == 0:
            InputManager.player_devices[1] = device
        elif device == 1:
            InputManager.player_devices[2] = device
    else:
        print("Controller %d disconnected" % device)
        for player_id in InputManager.player_devices:
            if InputManager.player_devices[player_id] == device:
                InputManager.player_devices[player_id] = -1
```

---

## 8.9 PLATFORM CONSIDERATIONS

### PC (Steam)

- Keyboard + mouse support (mouse optional)
- Full controller support
- Steam achievements
- Steam cloud saves
- Resolution options (windowed, fullscreen, borderless)

### Nintendo Switch

- Joy-Con support (single and dual)
- Pro Controller support
- Handheld mode optimization
- Sleep/resume handling
- Nintendo Online achievements (if applicable)

### PlayStation

- DualShock/DualSense support
- Trophy integration
- Activity cards (PS5)
- Platform-specific button prompts

### Xbox

- Xbox controller support
- Achievement integration
- Quick Resume support
- Platform-specific button prompts

### Cross-Platform Considerations

```gdscript
func get_platform() -> String:
    match OS.get_name():
        "Windows", "Linux", "macOS":
            return "pc"
        "Switch":
            return "switch"
        "PlayStation":
            return "playstation"
        "Xbox":
            return "xbox"
    return "unknown"

func get_button_icon(action: String) -> Texture2D:
    var platform := get_platform()
    var path := "res://assets/ui/buttons/%s/%s.png" % [platform, action]
    return load(path)
```

---

## 8.10 DEBUG AND DEVELOPMENT TOOLS

### Debug Menu (Development Only)

```gdscript
func _input(event: InputEvent) -> void:
    if not OS.is_debug_build():
        return
    
    if event.is_action_pressed("debug_menu"):
        _toggle_debug_menu()

func _toggle_debug_menu() -> void:
    debug_menu.visible = not debug_menu.visible
    get_tree().paused = debug_menu.visible
```

### Debug Commands

| Command | Effect |
|---------|--------|
| F1 | Toggle debug overlay (FPS, position, state) |
| F2 | Toggle collision visualization |
| F3 | Toggle invincibility |
| F4 | Skip to next level |
| F5 | Spawn test enemy |
| F6 | Give 99 lives |
| F7 | Toggle slow motion |
| F8 | Reload current level |

### Debug Overlay

```gdscript
func _process(_delta: float) -> void:
    if not debug_overlay.visible:
        return
    
    var text := ""
    text += "FPS: %d\n" % Engine.get_frames_per_second()
    text += "World Pos: %s\n" % str(player.world_pos)
    text += "Screen Pos: %s\n" % str(player.global_position)
    text += "Velocity: %s\n" % str(player.velocity)
    text += "State: %s\n" % player.current_state
    text += "On Ground: %s\n" % str(player.is_on_ground)
    text += "Enemies: %d\n" % get_tree().get_nodes_in_group("enemies").size()
    
    debug_label.text = text
```

---

## IMPLEMENTATION CHECKLIST

- [ ] Player 2 character
- [ ] Drop-in/drop-out system
- [ ] Tether visual
- [ ] Tether physics
- [ ] Slingshot mechanic
- [ ] Co-op camera
- [ ] Shared resources
- [ ] Autoload singletons
- [ ] Object pooling
- [ ] Off-screen culling
- [ ] Save/load system
- [ ] Multi-controller input
- [ ] Platform-specific code
- [ ] Debug tools

---

*Continue to Part 9: Development Roadmap and Implementation Guide*
