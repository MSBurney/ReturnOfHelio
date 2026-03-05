# ISOMETRIC PLATFORMER - GAME DESIGN DOCUMENT
## Part 2: Core Mechanics and Controls

---

## 2.1 CONTROL SCHEME

### Primary Input (NES-Style Two-Button + Combo)

| Input | Action (Ground) | Action (Air) | Action (Near Enemy + Air) |
|-------|-----------------|--------------|---------------------------|
| D-Pad / Left Stick | Move (8-directional) | Air control | Air control |
| Button A (Z/Space) | Jump | Double Jump | Homing Attack |
| Button B (X) | Attack | Attack | Attack |
| Button A + B (Together) | Dash | Air Dash | Air Dash |

### Extended Controls (Optional)

| Input | Action |
|-------|--------|
| Start | Pause Menu |
| Select | Map/Inventory |
| L/R Triggers | Camera zoom (if implemented) |

### Input Mapping (Godot)

```
move_up:      W, Up Arrow, D-Pad Up
move_down:    S, Down Arrow, D-Pad Down
move_left:    A, Left Arrow, D-Pad Left
move_right:   D, Right Arrow, D-Pad Right
jump:         Z, Space, Gamepad A/Cross
attack:       X, Gamepad B/Circle
pause:        Escape, Start
```

---

## 2.2 MOVEMENT SYSTEM

### Isometric Projection

**Coordinate System:**
- World X+ → Screen down-right
- World Y+ → Screen down-left
- World Z+ → Screen up (height)

**Projection Formula:**
```gdscript
# World to Screen
screen_x = (world_x - world_y) * TILE_WIDTH_HALF   # 8 pixels
screen_y = (world_x + world_y) * TILE_HEIGHT_HALF - world_z  # 4 pixels

# Screen to World (at known Z)
world_x = (screen_x / 8 + (screen_y + z) / 4) * 0.5
world_y = ((screen_y + z) / 4 - screen_x / 8) * 0.5
```

**Uniform Screen-Space Speed:**
Input direction is normalized in screen space, then converted to world space. This ensures pressing Up moves the same screen distance as pressing Right.

### Movement Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `move_speed` | 108.0 | World units per second |
| `acceleration` | 80.0 | Units/sec² when accelerating |
| `deceleration` | 60.0 | Units/sec² when decelerating |
| `max_step_height` | 4.0 | Max height difference walkable without jump |

### Movement Implementation

```gdscript
func _process_movement(delta: float) -> void:
    # Get raw input
    var input := Vector2(
        Input.get_axis("move_left", "move_right"),
        Input.get_axis("move_up", "move_down")
    )
    
    # Convert to world direction (screen-space normalized)
    var world_dir := IsoUtils.input_to_world_direction(input)
    var target_velocity := world_dir * move_speed
    
    # Apply acceleration/deceleration
    if world_dir.length() > 0:
        horizontal_velocity = horizontal_velocity.move_toward(
            target_velocity, acceleration * delta
        )
    else:
        horizontal_velocity = horizontal_velocity.move_toward(
            Vector2.ZERO, deceleration * delta
        )
    
    # Wall collision check before applying movement
    # (See Section 2.5 for wall collision details)
    
    world_pos.x += horizontal_velocity.x * delta
    world_pos.y += horizontal_velocity.y * delta
```

---

## 2.3 JUMP SYSTEM

### Jump Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `jump_velocity` | 135.0 | Initial upward velocity |
| `gravity` | 350.0 | Downward acceleration |
| `double_jump_multiplier` | 0.8 | Double jump is 80% of first jump |

### Jump States

```
GROUNDED ──(press jump)──► JUMPING ──(apex)──► FALLING
    ▲                          │                   │
    │                          │ (press jump       │
    │                          │  + no target)     │
    │                          ▼                   │
    │                    DOUBLE_JUMPING ───────────┤
    │                          │                   │
    └──────────────────────────┴───(land)──────────┘
```

### Jump Implementation

```gdscript
var is_on_ground: bool = true
var can_double_jump: bool = false
var just_jumped: bool = false  # Prevents same-frame ground collision

func _process_jump() -> void:
    if Input.is_action_just_pressed("jump"):
        if is_on_ground:
            # First jump
            velocity.z = jump_velocity
            is_on_ground = false
            can_double_jump = true
            just_jumped = true
        elif can_double_jump:
            # Check for homing target first
            var target := _find_homing_target()
            if target:
                _start_homing_attack(target)
                can_double_jump = false
            else:
                # Double jump
                velocity.z = jump_velocity * 0.8
                can_double_jump = false

func _process_gravity(delta: float) -> void:
    if not is_on_ground:
        velocity.z -= gravity * delta
    world_pos.z += velocity.z * delta
```

### Coyote Time (Future Enhancement)

Allow jump for a few frames after leaving a platform edge:

```gdscript
var coyote_timer: float = 0.0
const COYOTE_TIME: float = 0.1  # 100ms

func _physics_process(delta: float) -> void:
    if was_on_ground and not is_on_ground:
        coyote_timer = COYOTE_TIME
    elif is_on_ground:
        coyote_timer = 0.0
    else:
        coyote_timer -= delta
    
    # In jump check:
    if is_on_ground or coyote_timer > 0:
        # Allow jump
```

### Input Buffering (Future Enhancement)

Remember jump input for a few frames before landing:

```gdscript
var jump_buffer_timer: float = 0.0
const JUMP_BUFFER_TIME: float = 0.1

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("jump"):
        jump_buffer_timer = JUMP_BUFFER_TIME

func _physics_process(delta: float) -> void:
    jump_buffer_timer -= delta
    
    if is_on_ground and jump_buffer_timer > 0:
        _do_jump()
        jump_buffer_timer = 0.0
```

---

## 2.4 HOMING ATTACK SYSTEM

### Homing Attack Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `homing_attack_speed` | 200.0 | Speed toward target |
| `homing_attack_range` | 64.0 | Screen pixels detection radius |
| `homing_bounce_velocity` | 80.0 | Upward bounce after hit |

### Target Acquisition

1. Player is airborne (from any source: jump, fall, bounce)
2. Enemy within `homing_attack_range` screen pixels
3. Nearest valid enemy becomes target
4. Target reticle appears on targeted enemy

```gdscript
func _find_homing_target() -> Node2D:
    var enemies := get_tree().get_nodes_in_group("enemies")
    var nearest: Node2D = null
    var nearest_dist: float = homing_attack_range
    var my_screen_pos := IsoUtils.world_to_screen(world_pos)
    
    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        if enemy.has_method("get_world_pos"):
            var enemy_screen_pos := IsoUtils.world_to_screen(enemy.get_world_pos())
            var dist := my_screen_pos.distance_to(enemy_screen_pos)
            if dist < nearest_dist:
                nearest_dist = dist
                nearest = enemy
    
    return nearest
```

### Target Reticle

- Only visible when airborne AND valid target exists
- Rotating yellow crosshair/ring on targeted enemy
- Pulses to draw attention
- Disappears when grounded or no target

### Homing Attack Execution

```gdscript
var is_homing: bool = false
var homing_target: Node2D = null

func _start_homing_attack(target: Node2D) -> void:
    is_homing = true
    homing_target = target
    horizontal_velocity = Vector2.ZERO  # Stop horizontal momentum
    velocity.z = 0.0  # Stop vertical momentum

func _process_homing_attack(delta: float) -> void:
    if not is_instance_valid(homing_target):
        _end_homing_attack(false)
        return
    
    var target_pos: Vector3 = homing_target.get_world_pos()
    var to_target := target_pos - world_pos
    var distance := to_target.length()
    var move_distance: float = homing_attack_speed * delta
    
    # Prevent overshooting
    if move_distance >= distance or distance < 8.0:
        world_pos = target_pos
        homing_target.take_damage(1)
        _end_homing_attack(true)
    else:
        world_pos += to_target.normalized() * move_distance

func _end_homing_attack(hit_enemy: bool) -> void:
    is_homing = false
    homing_target = null
    if hit_enemy:
        velocity.z = homing_bounce_velocity
        can_double_jump = true  # Enable chaining
```

### Chaining Attacks

After a successful homing attack:
1. Player bounces upward
2. `can_double_jump` is re-enabled
3. If another enemy is in range, reticle appears
4. Player can immediately homing attack again
5. Chains continue until no targets or player lands

---

## 2.5 COLLISION SYSTEM

### Ground Collision

```gdscript
func _update_collision() -> void:
    if just_jumped or is_homing:
        return
    
    var ground_height: float = level.get_tile_height_at(world_pos.x, world_pos.y)
    
    if world_pos.z <= ground_height:
        world_pos.z = ground_height
        velocity.z = 0.0
        is_on_ground = true
        can_double_jump = false
    else:
        is_on_ground = false
```

### Wall Collision

Walls are height differences greater than `max_step_height`:

```gdscript
func _check_wall_collision(new_x: float, new_y: float) -> Vector2:
    var result := Vector2(new_x, new_y)
    
    # Check X movement
    var ground_at_new_x: float = level.get_tile_height_at(new_x, world_pos.y)
    if ground_at_new_x > world_pos.z + max_step_height:
        result.x = world_pos.x
        horizontal_velocity.x = 0.0
    
    # Check Y movement
    var ground_at_new_y: float = level.get_tile_height_at(world_pos.x, new_y)
    if ground_at_new_y > world_pos.z + max_step_height:
        result.y = world_pos.y
        horizontal_velocity.y = 0.0
    
    # Check diagonal (corner case)
    var ground_at_new_xy: float = level.get_tile_height_at(result.x, result.y)
    if ground_at_new_xy > world_pos.z + max_step_height:
        # Try sliding along wall
        # (Implementation handles X-only and Y-only fallbacks)
    
    return result
```

### Stomp Detection

Detect when player lands on enemy from above:

```gdscript
func _check_enemy_stomp() -> void:
    if is_on_ground or velocity.z >= 0 or is_homing:
        return  # Only check when falling
    
    for enemy in get_tree().get_nodes_in_group("enemies"):
        var enemy_pos: Vector3 = enemy.get_world_pos()
        var horizontal_dist := Vector2(
            world_pos.x - enemy_pos.x,
            world_pos.y - enemy_pos.y
        ).length()
        var vertical_diff := world_pos.z - enemy_pos.z
        
        if horizontal_dist < 1.0 and vertical_diff > 0 and vertical_diff < 12.0:
            enemy.stomp()
            velocity.z = stomp_bounce_velocity
            can_double_jump = true
            break
```

---

## 2.6 ATTACK SYSTEM (BASIC)

### Ground Attack

Simple melee attack for close-range combat:

| Parameter | Value | Description |
|-----------|-------|-------------|
| `attack_range` | 16.0 | World units |
| `attack_damage` | 1 | Damage dealt |
| `attack_cooldown` | 0.3 | Seconds between attacks |

### Attack Implementation (To Be Implemented)

```gdscript
var attack_timer: float = 0.0

func _process_attack() -> void:
    attack_timer -= delta
    
    if Input.is_action_just_pressed("attack") and attack_timer <= 0:
        attack_timer = attack_cooldown
        _do_attack()

func _do_attack() -> void:
    # Play attack animation
    # Check for enemies in attack_range
    # Deal damage to hit enemies
    pass
```

---

## 2.7 DEPTH VISUALIZATION

### Drop Shadow System

Every entity with height has a shadow:
- Shadow position: directly below entity at ground level
- Shadow alpha: fades with height (1.0 at ground, 0.2 at max height)
- Shadow scale: shrinks with height (1.0 at ground, 0.5 at max height)
- Shadow z-index: always behind the entity

```gdscript
func _update_shadow() -> void:
    var ground_height: float = level.get_tile_height_at(world_pos.x, world_pos.y)
    var shadow_pos := Vector3(world_pos.x, world_pos.y, ground_height)
    shadow.global_position = IsoUtils.world_to_screen(shadow_pos)
    shadow.z_index = z_index - 1
    
    var height_diff: float = world_pos.z - ground_height
    shadow.modulate.a = clampf(1.0 - (height_diff / 64.0), 0.2, 0.6)
    shadow.scale = Vector2.ONE * clampf(1.0 - (height_diff / 128.0), 0.5, 1.0)
```

### Depth Sorting

Z-index based on isometric depth:

```gdscript
func _update_depth_sort() -> void:
    z_index = int((world_pos.x + world_pos.y + world_pos.z * 0.01) * 10)
```

---

## 2.8 DASH MECHANIC

### Dash Overview

The dash is performed by pressing **Jump + Attack simultaneously**. It propels the player forward in their current facing direction at high speed.

### Dash Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `dash_speed` | 250.0 | Speed during dash |
| `dash_duration` | 0.15 | Seconds |
| `dash_cooldown` | 0.5 | Seconds between dashes |
| `dash_damage` | 1 | Damage dealt to enemies |

### Dash Implementation

```gdscript
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

func _process_dash(delta: float) -> void:
    dash_cooldown_timer -= delta
    
    if is_dashing:
        dash_timer -= delta
        if dash_timer <= 0:
            _end_dash()
        else:
            # Move in dash direction
            world_pos.x += dash_direction.x * dash_speed * delta
            world_pos.y += dash_direction.y * dash_speed * delta
            _check_dash_collision()
        return
    
    # Check for dash input (both buttons pressed)
    var jump_pressed := Input.is_action_pressed("jump")
    var attack_pressed := Input.is_action_pressed("attack")
    
    if jump_pressed and attack_pressed and dash_cooldown_timer <= 0:
        _start_dash()

func _start_dash() -> void:
    is_dashing = true
    dash_timer = dash_duration
    dash_cooldown_timer = dash_cooldown
    dash_direction = _get_facing_direction()
    # Dash maintains current height (can dash in air)

func _end_dash() -> void:
    is_dashing = false
    dash_direction = Vector2.ZERO

func _check_dash_collision() -> void:
    var enemies := get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        var dist := Vector2(world_pos.x - enemy.world_pos.x, 
                           world_pos.y - enemy.world_pos.y).length()
        if dist < 1.5:
            _on_dash_hit_enemy(enemy)

func _on_dash_hit_enemy(enemy: Node2D) -> void:
    var damage := dash_damage
    
    # Form-specific bonuses
    match current_form:
        Form.METALSAUR:
            damage = dash_damage * 2
            # Can break metallic/stone enemies
            if enemy.has_method("is_metallic") or enemy.has_method("is_stone"):
                enemy.shatter()
        Form.BURNING_BUSH:
            _spawn_fire_explosion(enemy.world_pos)
        Form.PHOCID:
            _spawn_ice_explosion(enemy.world_pos)
    
    enemy.take_damage(damage)
```

### Dash + Form Interactions

| Form | Dash Effect |
|------|-------------|
| Default | Standard dash, 1 damage |
| Serpent | Standard dash, 1 damage (can dash in air more effectively) |
| Burning Bush | Dash causes fire explosion on hit |
| Phocid | Dash causes ice explosion on hit, freezes enemies |
| Metalsaur | Double damage (2), breaks metallic/stone objects |

---

## 2.9 POWER-UP / FORM SYSTEM

### Overview

Players can transform into different forms by collecting power-ups found within levels. Forms persist until a different power-up is collected or a Time Stone reverts the player to default.

### Form Types

| Form | Visual Change | Abilities | Notes |
|------|---------------|-----------|-------|
| **Default** | Normal Helio/Anigi | Standard moveset | Starting form |
| **Serpent** | Wings appear | Higher jump, floaty descent | Best for platforming |
| **Burning Bush** | Player becomes fireball | Fireball attack, fire explosion on dash | Offensive form |
| **Phocid** | Player becomes snowball | Iceball attack, freeze explosion on dash, ice cubes float on water | Utility + offense |
| **Metalsaur** | Knight helmet | Invulnerable to attacks, 2x dash damage, breaks metal/stone, sinks in water | Tank form, water weakness |

### Form Parameters

```gdscript
enum Form {
    DEFAULT,
    SERPENT,
    BURNING_BUSH,
    PHOCID,
    METALSAUR
}

var current_form: Form = Form.DEFAULT

# Serpent parameters
const SERPENT_JUMP_MULTIPLIER: float = 1.4
const SERPENT_GRAVITY_MULTIPLIER: float = 0.6  # Floaty

# Burning Bush parameters
const FIRE_EXPLOSION_RADIUS: float = 24.0
const FIRE_EXPLOSION_DAMAGE: int = 2

# Phocid parameters
const ICE_EXPLOSION_RADIUS: float = 20.0
const ICE_FREEZE_DURATION: float = 5.0

# Metalsaur parameters
const METALSAUR_DASH_MULTIPLIER: int = 2
const METALSAUR_SINK_SPEED: float = 30.0
```

### Form Implementation

```gdscript
func set_form(new_form: Form) -> void:
    current_form = new_form
    _update_visual_for_form()
    form_changed.emit(current_form)

func _update_visual_for_form() -> void:
    match current_form:
        Form.DEFAULT:
            sprite.texture = default_texture
        Form.SERPENT:
            sprite.texture = serpent_texture  # Wings
        Form.BURNING_BUSH:
            sprite.texture = fireball_texture
        Form.PHOCID:
            sprite.texture = snowball_texture
        Form.METALSAUR:
            sprite.texture = knight_texture

func _get_jump_velocity() -> float:
    var base := jump_velocity
    if current_form == Form.SERPENT:
        base *= SERPENT_JUMP_MULTIPLIER
    return base

func _get_gravity() -> float:
    var base := gravity
    if current_form == Form.SERPENT:
        base *= SERPENT_GRAVITY_MULTIPLIER
    return base

func take_damage(amount: int) -> void:
    if current_form == Form.METALSAUR:
        return  # Invulnerable
    if is_invincible:
        return  # Rock Dust active
    
    current_health -= amount
    # ... rest of damage handling
```

### Form-Specific Attacks

#### Burning Bush - Fireball Attack

```gdscript
func _attack_burning_bush() -> void:
    var fireball := fireball_scene.instantiate()
    fireball.setup(world_pos, _get_facing_direction_3d(), fireball_speed)
    fireball.explosion_radius = FIRE_EXPLOSION_RADIUS
    fireball.explosion_damage = FIRE_EXPLOSION_DAMAGE
    get_parent().add_child(fireball)
```

#### Phocid - Iceball Attack

```gdscript
func _attack_phocid() -> void:
    var iceball := iceball_scene.instantiate()
    iceball.setup(world_pos, _get_facing_direction_3d(), iceball_speed)
    iceball.freeze_duration = ICE_FREEZE_DURATION
    get_parent().add_child(iceball)

func _spawn_ice_explosion(pos: Vector3) -> void:
    var enemies := get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        var dist := pos.distance_to(enemy.world_pos)
        if dist < ICE_EXPLOSION_RADIUS:
            enemy.freeze(ICE_FREEZE_DURATION)
            # Frozen enemies become ice cubes that can be pushed
```

#### Metalsaur - Water Interaction

```gdscript
func _process_water_interaction(delta: float) -> void:
    var tile_type := level.get_tile_type_at(world_pos.x, world_pos.y)
    
    if tile_type == TileType.WATER:
        if current_form == Form.METALSAUR:
            # Sink in water
            world_pos.z -= METALSAUR_SINK_SPEED * delta
            if world_pos.z < -32:  # Death depth
                _die()
        elif current_form == Form.PHOCID:
            # Ice cubes float - Phocid walks on frozen enemies in water
            pass
```

---

## 2.10 TEMPORARY POWER-UPS

### Rock Dust (Invincibility)

| Property | Value |
|----------|-------|
| Duration | 20 seconds |
| Effect | Invulnerable + contact damage |
| Visual | Sparkly dust emanating from player |
| Stacking | Collecting another resets timer |

```gdscript
var is_invincible: bool = false
var invincibility_timer: float = 0.0
const ROCK_DUST_DURATION: float = 20.0

func collect_rock_dust() -> void:
    is_invincible = true
    invincibility_timer = ROCK_DUST_DURATION
    _start_sparkle_effect()

func _process_invincibility(delta: float) -> void:
    if is_invincible:
        invincibility_timer -= delta
        if invincibility_timer <= 0:
            is_invincible = false
            _stop_sparkle_effect()
        else:
            # Contact damage to enemies
            _check_contact_damage()

func _check_contact_damage() -> void:
    var enemies := get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        var dist := world_pos.distance_to(enemy.world_pos)
        if dist < 8.0:
            enemy.take_damage(1)
```

### Dash Dust (Speed Boost)

| Property | Value |
|----------|-------|
| Duration | 20 seconds |
| Effect | 2x movement speed |
| Visual | None (just faster movement) |
| Stacking | Collecting another resets timer |

```gdscript
var has_speed_boost: bool = false
var speed_boost_timer: float = 0.0
const DASH_DUST_DURATION: float = 20.0
const SPEED_BOOST_MULTIPLIER: float = 2.0

func collect_dash_dust() -> void:
    has_speed_boost = true
    speed_boost_timer = DASH_DUST_DURATION

func _get_move_speed() -> float:
    var base := move_speed
    if has_speed_boost:
        base *= SPEED_BOOST_MULTIPLIER
    return base

func _process_speed_boost(delta: float) -> void:
    if has_speed_boost:
        speed_boost_timer -= delta
        if speed_boost_timer <= 0:
            has_speed_boost = false
```

### Time Stone (Form Reset)

```gdscript
func collect_time_stone() -> void:
    set_form(Form.DEFAULT)
    # Visual/audio feedback for reverting
```

---

## 2.11 POWER-UP COLLECTIBLES

### Power-Up Spawn Locations

Power-ups are placed within levels (not on world map). They appear as distinct collectible items.

### Power-Up Visual Design

| Power-Up | Visual |
|----------|--------|
| Serpent Gem | Green gem with wing icon |
| Burning Bush Gem | Red/orange gem with flame icon |
| Phocid Gem | Cyan gem with snowflake icon |
| Metalsaur Gem | Gray gem with helmet icon |
| Rock Dust | Golden sparkly dust cloud |
| Dash Dust | Blue sparkly dust cloud |
| Time Stone | White/gray stone with clock icon |

### Collectible Implementation

```gdscript
class_name PowerUpCollectible
extends Collectible

enum PowerUpType {
    SERPENT,
    BURNING_BUSH,
    PHOCID,
    METALSAUR,
    ROCK_DUST,
    DASH_DUST,
    TIME_STONE
}

@export var power_up_type: PowerUpType = PowerUpType.SERPENT

func collect(player: Player) -> void:
    match power_up_type:
        PowerUpType.SERPENT:
            player.set_form(Player.Form.SERPENT)
        PowerUpType.BURNING_BUSH:
            player.set_form(Player.Form.BURNING_BUSH)
        PowerUpType.PHOCID:
            player.set_form(Player.Form.PHOCID)
        PowerUpType.METALSAUR:
            player.set_form(Player.Form.METALSAUR)
        PowerUpType.ROCK_DUST:
            player.collect_rock_dust()
        PowerUpType.DASH_DUST:
            player.collect_dash_dust()
        PowerUpType.TIME_STONE:
            player.collect_time_stone()
    
    _play_collect_effect()
    queue_free()
```

---

## IMPLEMENTATION CHECKLIST

- [x] Movement with acceleration/deceleration
- [x] Uniform screen-space speed
- [x] Jump and double jump
- [x] Gravity
- [x] Ground collision
- [x] Wall collision
- [x] Homing attack targeting
- [x] Homing attack execution
- [x] Attack chaining via bounce
- [x] Enemy stomp
- [x] Drop shadow
- [x] Depth sorting
- [x] Target reticle
- [ ] Basic attack (melee)
- [ ] Coyote time
- [ ] Input buffering
- [ ] Attack animations
- [ ] Movement animations
- [ ] **Dash mechanic**
- [ ] **Form system (Serpent, Burning Bush, Phocid, Metalsaur)**
- [ ] **Form-specific attacks**
- [ ] **Rock Dust (invincibility)**
- [ ] **Dash Dust (speed boost)**
- [ ] **Time Stone (form reset)**
- [ ] **Power-up collectibles**
- [ ] **Frozen enemy ice cube physics**
- [ ] **Metalsaur water sinking**

---

*Continue to Part 2.5: Tactical RPG Battle Mode*
