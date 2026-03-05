# ISOMETRIC PLATFORMER - GAME DESIGN DOCUMENT
## Part 7: Audio Design and Visual Style

---

## 7.1 VISUAL STYLE OVERVIEW

### Core Aesthetic

- **NES-Era Isometric** — Inspired by Snake: Rattle n' Roll, Solstice
- **2:1 Isometric Projection** — 16x8 pixel tile diamonds
- **Limited Color Palette** — Per-world palettes, NES-style restrictions
- **Pixel Art** — Clean, readable sprites with clear silhouettes
- **Modern Enhancements** — Parallax scrolling, widescreen, particle effects

### Technical Specifications

| Aspect | Specification |
|--------|---------------|
| Native Resolution | 426 x 240 pixels |
| Aspect Ratio | 16:9 (widescreen NES) |
| Tile Size | 16 x 8 pixels (diamond) |
| Character Size | ~12 x 14 pixels (player) |
| Color Depth | 8-bit per channel |
| Frame Rate | 60 FPS target |
| Scaling | Integer scaling, pixel-perfect |

### Visual Hierarchy

1. **Background** — Parallax layers, static scenery (z-index: -100)
2. **Tiles** — Ground, platforms, walls (z-index: depth-sorted)
3. **Shadows** — Entity shadows at ground level (z-index: entity - 1)
4. **Entities** — Player, enemies, collectibles (z-index: depth-sorted)
5. **Effects** — Particles, flashes (z-index: 100+)
6. **UI** — HUD, menus (CanvasLayer)

---

## 7.2 COLOR PALETTES

### Global UI Palette

```gdscript
const PALETTE_UI := {
    "black": Color("0f0f1a"),
    "dark_gray": Color("2a2a3a"),
    "gray": Color("5a5a6a"),
    "light_gray": Color("9a9aaa"),
    "white": Color("eaeafa"),
    "red": Color("e04040"),
    "yellow": Color("f0c020"),
    "green": Color("40c040"),
    "blue": Color("4080e0"),
}
```

### World 1: Grasslands

```gdscript
const PALETTE_GRASSLANDS := {
    "grass_dark": Color("2d5a2d"),
    "grass_light": Color("4a8a4a"),
    "dirt": Color("6a4a30"),
    "wood": Color("8a6040"),
    "sky": Color("80c0f0"),
    "cloud": Color("f0f0ff"),
    "water": Color("4080c0"),
    "flower_red": Color("e04040"),
    "flower_yellow": Color("f0c020"),
}
```

### World 2: Crystal Caves

```gdscript
const PALETTE_CAVES := {
    "rock_dark": Color("2a2040"),
    "rock_light": Color("4a3060"),
    "crystal_purple": Color("a040c0"),
    "crystal_cyan": Color("40c0c0"),
    "crystal_pink": Color("e060a0"),
    "glow": Color("c080ff"),
    "shadow": Color("101020"),
}
```

### World 3: Seaside Cliffs

```gdscript
const PALETTE_SEASIDE := {
    "sand": Color("e0c090"),
    "rock": Color("8a7060"),
    "water_shallow": Color("60b0d0"),
    "water_deep": Color("2060a0"),
    "foam": Color("f0f0ff"),
    "sky": Color("80d0f0"),
    "seaweed": Color("408040"),
}
```

### World 4: Volcanic Ruins

```gdscript
const PALETTE_VOLCANIC := {
    "stone_dark": Color("302020"),
    "stone_light": Color("504040"),
    "lava_dark": Color("c02000"),
    "lava_light": Color("ff6020"),
    "ember": Color("ffc040"),
    "ash": Color("404040"),
    "sky": Color("602000"),
}
```

### World 5: Frozen Peaks

```gdscript
const PALETTE_FROZEN := {
    "snow": Color("e0f0ff"),
    "ice_dark": Color("80c0e0"),
    "ice_light": Color("c0e0ff"),
    "rock": Color("6080a0"),
    "sky": Color("a0d0ff"),
    "pine": Color("204040"),
}
```

### World 6: Sky Citadel

```gdscript
const PALETTE_SKY := {
    "cloud_dark": Color("c0d0e0"),
    "cloud_light": Color("f0f8ff"),
    "gold": Color("d0a020"),
    "marble": Color("e0e0f0"),
    "sky_top": Color("4080c0"),
    "sky_bottom": Color("80c0ff"),
}
```

### World 7: Haunted Manor

```gdscript
const PALETTE_HAUNTED := {
    "wood_dark": Color("302830"),
    "wood_light": Color("504850"),
    "stone": Color("404050"),
    "purple": Color("604080"),
    "green_glow": Color("40c060"),
    "candle": Color("f0c060"),
    "shadow": Color("101018"),
}
```

### World 8: Factory Complex

```gdscript
const PALETTE_FACTORY := {
    "metal_dark": Color("404050"),
    "metal_light": Color("808090"),
    "rust": Color("a06040"),
    "warning": Color("f0c000"),
    "danger": Color("e02020"),
    "steam": Color("c0c0d0"),
    "glow": Color("60ff60"),
}
```

### World 9: Dark Fortress

```gdscript
const PALETTE_FORTRESS := {
    "void": Color("080010"),
    "stone_dark": Color("201830"),
    "stone_light": Color("403050"),
    "purple": Color("8040a0"),
    "red_glow": Color("c02040"),
    "corruption": Color("400060"),
}
```

---

## 7.3 SPRITE DESIGN GUIDELINES

### Player Character (Pip)

```
Frame Size: 12 x 14 pixels
Animation Frames:
- Idle: 2 frames (subtle bounce)
- Walk: 4 frames (squash/stretch)
- Jump: 2 frames (anticipation, airborne)
- Fall: 1 frame
- Homing: 2 frames (spin)
- Hurt: 1 frame (flash)
- Death: 4 frames (pop effect)

Color Breakdown:
- Body: Primary color (red/blue)
- Highlight: Lighter shade
- Shadow: Darker shade
- Eyes: White with black pupil
```

### Enemy Sprites

```
Small Enemies: 12-16 pixels
- Clear silhouette
- Distinct from player
- Animation: 2-4 frames idle

Large Enemies: 20-24 pixels
- More detail allowed
- Animation: 4-6 frames

Bosses: 24-32+ pixels
- Most detailed sprites
- Multiple animation sets
- Phase-specific variants
```

### Collectible Sprites

```
Coins: 8 x 8 pixels
- Simple circle with highlight
- 4-frame rotation animation

Keys: 8 x 10 pixels
- Distinct key shape
- Glowing effect

Gems: 10 x 10 pixels
- Crystal shape
- 4-frame sparkle animation
```

---

## 7.4 ANIMATION PRINCIPLES

### Squash and Stretch

Apply to all character movement:

```gdscript
func _animate_jump() -> void:
    # Anticipation (squash)
    var tween := create_tween()
    tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.05)
    # Launch (stretch)
    tween.tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.1)
    # Normalize
    tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)
```

### Landing Impact

```gdscript
func _animate_land() -> void:
    var tween := create_tween()
    # Squash on impact
    tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.05)
    # Bounce back
    tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.1)
    # Settle
    tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
```

### Homing Attack Spin

```gdscript
func _animate_homing() -> void:
    var tween := create_tween().set_loops()
    tween.tween_property(sprite, "rotation", TAU, 0.2)
```

---

## 7.5 PARTICLE EFFECTS

### Death Particles

```gdscript
# particles/enemy_death.tscn
[GPUParticles2D]
amount = 8
lifetime = 0.5
one_shot = true
explosiveness = 1.0

# Particle material settings:
direction = Vector2(0, -1)
spread = 180
initial_velocity_min = 40
initial_velocity_max = 80
gravity = Vector2(0, 200)
scale_amount_min = 2
scale_amount_max = 4
color = world_palette.primary
```

### Coin Collect Sparkle

```gdscript
# particles/coin_sparkle.tscn
[GPUParticles2D]
amount = 6
lifetime = 0.3
one_shot = true
explosiveness = 0.8

# Small stars that burst outward
```

### Jump Dust

```gdscript
# particles/jump_dust.tscn
[GPUParticles2D]
amount = 4
lifetime = 0.4
one_shot = true

# Puff of dust at feet when jumping
```

---

## 7.6 PARALLAX BACKGROUNDS

### Layer Structure

```
Layer -3: Sky/distant (move at 10% of camera)
Layer -2: Far background (move at 30% of camera)
Layer -1: Near background (move at 60% of camera)
Layer 0:  Game layer (move at 100% of camera)
```

### Implementation

```gdscript
class_name ParallaxManager
extends ParallaxBackground

func _ready() -> void:
    # Configure layers based on world
    for layer in get_children():
        if layer is ParallaxLayer:
            match layer.name:
                "Sky":
                    layer.motion_scale = Vector2(0.1, 0.05)
                "Far":
                    layer.motion_scale = Vector2(0.3, 0.15)
                "Near":
                    layer.motion_scale = Vector2(0.6, 0.3)
```

### World-Specific Backgrounds

| World | Layer -3 | Layer -2 | Layer -1 |
|-------|----------|----------|----------|
| Grasslands | Sky + clouds | Distant hills | Trees |
| Caves | Void | Far crystals | Stalactites |
| Seaside | Sky + sun | Ocean horizon | Waves |
| Volcanic | Smoke sky | Distant lava | Ash particles |
| Frozen | Blizzard sky | Mountains | Snowfall |
| Sky | Gradient sky | Distant clouds | Near clouds |
| Haunted | Moon + sky | Dead trees | Fog |
| Factory | Smog | Distant machinery | Pipes |
| Fortress | Void | Floating debris | Purple flames |

---

## 7.7 AUDIO DESIGN OVERVIEW

### Audio Categories

| Category | Format | Count Estimate |
|----------|--------|----------------|
| Music | OGG | 15-20 tracks |
| SFX | WAV | 50-80 effects |
| Ambience | OGG | 10 loops |
| Jingles | OGG | 10-15 short |

### Music Style

- **Chiptune-inspired** — Modern compositions with 8-bit influences
- **Melodic and memorable** — Catchy themes for each world
- **Dynamic** — Intensity changes during boss fights
- **Loopable** — Seamless loops for gameplay

### Audio Bus Structure

```
Master
├── Music (0 dB default)
├── SFX (0 dB default)
│   ├── Player
│   ├── Enemies
│   ├── Environment
│   └── UI
└── Ambience (-6 dB default)
```

---

## 7.8 MUSIC TRACKS

### Track List

| Track | Usage | Duration | Tempo |
|-------|-------|----------|-------|
| `title_theme` | Title screen | 2:00 | 120 BPM |
| `world_map` | World select | 1:30 | 100 BPM |
| `grasslands` | World 1 levels | 2:30 | 130 BPM |
| `grasslands_boss` | King Ribbit | 2:00 | 150 BPM |
| `caves` | World 2 levels | 2:30 | 110 BPM |
| `caves_boss` | Crystal Golem | 2:00 | 140 BPM |
| `seaside` | World 3 levels | 2:30 | 125 BPM |
| `seaside_boss` | Admiral Tentacle | 2:00 | 145 BPM |
| `volcanic` | World 4 levels | 2:30 | 135 BPM |
| `volcanic_boss` | Magmus | 2:00 | 155 BPM |
| `frozen` | World 5 levels | 2:30 | 100 BPM |
| `frozen_boss` | Frost Wyrm | 2:00 | 140 BPM |
| `sky` | World 6 levels | 2:30 | 120 BPM |
| `sky_boss` | Storm Harpy | 2:00 | 150 BPM |
| `haunted` | World 7 levels | 2:30 | 90 BPM |
| `haunted_boss` | Count Spectra | 2:00 | 130 BPM |
| `factory` | World 8 levels | 2:30 | 140 BPM |
| `factory_boss` | Mecha Magnus | 2:00 | 160 BPM |
| `fortress` | World 9 levels | 3:00 | 130 BPM |
| `final_boss` | Shadow King | 3:00 | 165 BPM |
| `victory` | Level complete | 0:15 | — |
| `game_over` | Game over screen | 0:10 | — |
| `ending` | Credits | 3:00 | 90 BPM |

### Music Implementation

```gdscript
class_name MusicManager
extends Node

var current_track: AudioStreamPlayer
var next_track: AudioStreamPlayer
var crossfade_duration: float = 1.0

func play_track(track_name: String, crossfade: bool = true) -> void:
    var path := "res://assets/audio/music/%s.ogg" % track_name
    var stream: AudioStream = load(path)
    
    if crossfade and current_track.playing:
        next_track.stream = stream
        _crossfade()
    else:
        current_track.stream = stream
        current_track.play()

func _crossfade() -> void:
    next_track.volume_db = -80
    next_track.play()
    
    var tween := create_tween()
    tween.tween_property(current_track, "volume_db", -80, crossfade_duration)
    tween.parallel().tween_property(next_track, "volume_db", 0, crossfade_duration)
    tween.tween_callback(_swap_tracks)

func _swap_tracks() -> void:
    current_track.stop()
    var temp := current_track
    current_track = next_track
    next_track = temp
```

---

## 7.9 SOUND EFFECTS

### Player SFX

| Sound | Trigger | Description |
|-------|---------|-------------|
| `player_jump` | Jump | Short "boing" |
| `player_double_jump` | Double jump | Higher-pitched "boing" |
| `player_land` | Land on ground | Soft thud |
| `player_homing_start` | Begin homing | Whoosh wind-up |
| `player_homing_hit` | Hit enemy | Impact + sparkle |
| `player_hurt` | Take damage | Oof + flash |
| `player_death` | Lose all health | Pop + sad jingle |
| `player_attack` | Melee attack | Swoosh |

### Enemy SFX

| Sound | Trigger | Description |
|-------|---------|-------------|
| `enemy_hurt` | Take damage | Impact |
| `enemy_death` | Defeated | Pop + particles |
| `enemy_alert` | Spot player | Alarm/notice |
| `enemy_attack` | Attack | Varies by enemy |

### Collectible SFX

| Sound | Trigger | Description |
|-------|---------|-------------|
| `coin_collect` | Collect coin | Pling |
| `gem_collect` | Collect gem | Higher pling |
| `key_collect` | Collect key | Triumphant ding |
| `secret_found` | Find secret | Discovery jingle |

### UI SFX

| Sound | Trigger | Description |
|-------|---------|-------------|
| `menu_move` | Navigate menu | Blip |
| `menu_select` | Confirm selection | Confirm ding |
| `menu_back` | Cancel/back | Low blip |
| `pause` | Pause game | Pause sound |

### Environment SFX

| Sound | Trigger | Description |
|-------|---------|-------------|
| `door_open` | Door unlocks | Creak + click |
| `checkpoint` | Activate checkpoint | Activation chime |
| `bounce` | Hit bounce pad | Spring boing |
| `splash` | Enter water | Splash |
| `conveyor` | On conveyor belt | Mechanical hum |

### SFX Implementation

```gdscript
class_name SFXManager
extends Node

var pools: Dictionary = {}
const POOL_SIZE := 8

func _ready() -> void:
    _create_pools()

func _create_pools() -> void:
    for sfx_name in ["player_jump", "coin_collect", "enemy_death"]:
        var pool: Array[AudioStreamPlayer] = []
        for i in POOL_SIZE:
            var player := AudioStreamPlayer.new()
            player.bus = "SFX"
            player.stream = load("res://assets/audio/sfx/%s.wav" % sfx_name)
            add_child(player)
            pool.append(player)
        pools[sfx_name] = pool

func play(sfx_name: String, pitch_variance: float = 0.0) -> void:
    if not pools.has(sfx_name):
        push_warning("Unknown SFX: %s" % sfx_name)
        return
    
    for player in pools[sfx_name]:
        if not player.playing:
            if pitch_variance > 0:
                player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
            player.play()
            return
    
    # All players busy, force oldest
    pools[sfx_name][0].play()
```

---

## 7.10 AMBIENCE

### World Ambience

| World | Ambience | Description |
|-------|----------|-------------|
| Grasslands | Birds, wind | Peaceful nature |
| Caves | Dripping, echoes | Underground |
| Seaside | Waves, gulls | Ocean atmosphere |
| Volcanic | Rumbling, hissing | Dangerous heat |
| Frozen | Wind, ice cracking | Cold isolation |
| Sky | Wind, chimes | High altitude |
| Haunted | Creaks, whispers | Spooky |
| Factory | Machinery, steam | Industrial |
| Fortress | Low drones, void | Ominous |

---

## IMPLEMENTATION CHECKLIST

- [ ] World color palettes
- [ ] Player sprite (all animations)
- [ ] Enemy sprites (World 1)
- [ ] Collectible sprites
- [ ] Tile graphics (all worlds)
- [ ] Parallax backgrounds
- [ ] Particle effects
- [ ] Music tracks (all worlds)
- [ ] Player SFX
- [ ] Enemy SFX
- [ ] Collectible SFX
- [ ] UI SFX
- [ ] Ambience loops
- [ ] Audio manager
- [ ] SFX pooling system

---

*Continue to Part 8: Multiplayer and Co-op Systems*
