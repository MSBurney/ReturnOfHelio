# ISOMETRIC PLATFORMER - GAME DESIGN DOCUMENT
## Part 3: Enemy Design and Combat

---

## 3.1 ENEMY DESIGN PHILOSOPHY

### Core Principles

1. **Readable at a Glance** — Enemy behavior should be obvious from appearance
2. **Fair Challenge** — All enemies can be defeated with skill, no cheap deaths
3. **Reward Mastery** — Skilled players can chain through enemy groups efficiently
4. **World Theming** — Each world has 3 unique enemy types that fit its theme

### Enemy Categories

| Category | Behavior | Defeat Method | Examples |
|----------|----------|---------------|----------|
| **Floater** | Stationary, bobs in air | Homing attack, stomp | Basic test enemy |
| **Walker** | Patrols on ground | Stomp, homing attack, melee | Patrol enemies |
| **Flyer** | Moves through air | Homing attack only | Flying enemies |
| **Charger** | Rushes player when spotted | Stomp, homing attack, dodge | Aggressive enemies |
| **Shooter** | Fires projectiles | Stomp, homing attack (dodge projectiles) | Ranged enemies |
| **Shielded** | Blocks frontal attacks | Stomp only, attack from behind | Defensive enemies |
| **Boss** | Multi-phase, unique mechanics | Phase-specific strategies | World bosses |

---

## 3.2 BASE ENEMY CLASS

### Enemy Parameters

```gdscript
class_name Enemy
extends Node2D

# Core properties
@export var max_health: int = 1
@export var damage_to_player: int = 1
@export var score_value: int = 100

# Visual properties
@export var float_height: float = 16.0  # Height above ground
@export var bob_amplitude: float = 2.0  # Vertical bob amount
@export var bob_speed: float = 2.0      # Bob cycle speed

# World position
var world_pos: Vector3 = Vector3.ZERO
var current_health: int = max_health
```

### Required Methods

```gdscript
# Called by level to initialize position
func setup(tile_x: int, tile_y: int, ground_height: float) -> void:
	world_pos = Vector3(tile_x + 0.5, tile_y + 0.5, ground_height + float_height)

# Called by player when hit
func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		_die()
	else:
		_on_hurt()

# Called when player stomps
func stomp() -> void:
	take_damage(1)

# Public getter for targeting
func get_world_pos() -> Vector3:
	return world_pos
```

### Death Handling

```gdscript
func _die() -> void:
	# Spawn death particles
	# Play death sound
	# Award score
	# Remove from scene
	queue_free()

func _on_hurt() -> void:
	# Flash white
	# Play hurt sound
	# Brief invincibility if multi-hit enemy
	pass
```

---

## 3.3 ENEMY TYPES BY WORLD

### World 1: Grasslands
*Theme: Rolling hills, forests, introductory enemies*

| Enemy | Behavior | Health | Sprite Concept |
|-------|----------|--------|----------------|
| **Nibbler** | Floats stationary, bobs gently | 1 | Blue spiky ball (test enemy) |
| **Hopper** | Jumps periodically, moves toward player | 1 | Green frog-like creature |
| **Buzzfly** | Flies in sine wave pattern | 1 | Yellow/black insect |

### World 2: Crystal Caves
*Theme: Underground, crystals, reflective surfaces*

| Enemy | Behavior | Health | Sprite Concept |
|-------|----------|--------|----------------|
| **Gemling** | Walks patrol route, immune to front attack | 1 | Walking crystal |
| **Bat Swarm** | 3 bats fly in formation | 3 (1 each) | Purple bats |
| **Stalactite** | Falls when player passes beneath | 1 | Pointed rock |

### World 3: Seaside Cliffs
*Theme: Ocean, beaches, water hazards*

| Enemy | Behavior | Health | Sprite Concept |
|-------|----------|--------|----------------|
| **Crab Walker** | Moves sideways, charges when spotted | 1 | Red crab |
| **Seagull** | Dive-bombs player location | 1 | White bird |
| **Jellyfish** | Floats up from water, electrified | 1 | Pink translucent blob |

### World 4: Volcanic Ruins
*Theme: Lava, ancient structures, fire hazards*

| Enemy | Behavior | Health | Sprite Concept |
|-------|----------|--------|----------------|
| **Magmite** | Walks through lava, throws fireballs | 2 | Orange molten creature |
| **Fire Serpent** | Emerges from lava, lunges | 1 | Red snake |
| **Stone Guardian** | Slow, tanky, swings club | 3 | Gray golem |

### World 5: Frozen Peaks
*Theme: Ice, snow, slippery surfaces*

| Enemy | Behavior | Health | Sprite Concept |
|-------|----------|--------|----------------|
| **Ice Slime** | Splits into 2 smaller slimes when hit | 1+2 | Cyan blob |
| **Penguin Slider** | Slides on ice toward player | 1 | Black/white bird |
| **Yeti** | Throws snowballs, roars to stun | 3 | White furry beast |

### World 6: Sky Citadel
*Theme: Floating platforms, wind, vertical design*

| Enemy | Behavior | Health | Sprite Concept |
|-------|----------|--------|----------------|
| **Cloud Puff** | Blows wind to push player | 1 | White cloud with face |
| **Sky Knight** | Flies with lance, charges | 2 | Armored bird-person |
| **Thunder Orb** | Teleports, zaps lightning at player | 1 | Yellow electric ball |

### World 7: Haunted Manor
*Theme: Ghosts, darkness, jump scares*

| Enemy | Behavior | Health | Sprite Concept |
|-------|----------|--------|----------------|
| **Phantom** | Invisible until close, chases | 1 | Translucent ghost |
| **Armor Set** | Animated armor, swings sword | 2 | Empty knight armor |
| **Chandelier** | Falls when player underneath | 1 | Ornate chandelier |

### World 8: Factory Complex
*Theme: Machines, conveyor belts, hazards*

| Enemy | Behavior | Health | Sprite Concept |
|-------|----------|--------|----------------|
| **Drone Bot** | Flies patrol route, fires laser | 1 | Floating robot |
| **Crusher** | Slams down periodically | Invincible | Hydraulic press |
| **Assembly Arm** | Swings in pattern, can be ridden | Invincible | Robotic arm |

### World 9: Dark Fortress
*Theme: Final challenge, remixed enemies, all mechanics tested*

| Enemy | Behavior | Health | Sprite Concept |
|-------|----------|--------|----------------|
| **Shadow Nibbler** | Faster Nibbler, fires projectiles | 2 | Dark blue spiky ball |
| **Elite Knight** | Fast, combo attacks, blocks | 3 | Black armored knight |
| **Portal Warper** | Teleports, summons minions | 2 | Purple vortex creature |

---

## 3.4 ENEMY BEHAVIOR IMPLEMENTATIONS

### Floater (Stationary)

```gdscript
class_name EnemyFloater
extends Enemy

var bob_time: float = 0.0
var base_z: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	bob_time = randf() * TAU  # Random starting phase

func _process(delta: float) -> void:
	bob_time += delta * bob_speed
	world_pos.z = base_z + sin(bob_time) * bob_amplitude
	_update_visual()

func setup(tile_x: int, tile_y: int, ground_height: float) -> void:
	base_z = ground_height + float_height
	world_pos = Vector3(tile_x + 0.5, tile_y + 0.5, base_z)
```

### Walker (Patrol)

```gdscript
class_name EnemyWalker
extends Enemy

@export var patrol_distance: float = 3.0  # Tiles
@export var walk_speed: float = 20.0

var patrol_start: Vector2
var patrol_end: Vector2
var patrol_direction: int = 1
var ground_height: float = 0.0

func _ready() -> void:
	add_to_group("enemies")

func setup(tile_x: int, tile_y: int, g_height: float) -> void:
	ground_height = g_height
	world_pos = Vector3(tile_x + 0.5, tile_y + 0.5, ground_height)
	patrol_start = Vector2(world_pos.x, world_pos.y)
	patrol_end = patrol_start + Vector2(patrol_distance, 0)

func _process(delta: float) -> void:
	# Move along patrol route
	world_pos.x += walk_speed * delta * patrol_direction / 100.0
	
	# Reverse at patrol bounds
	if world_pos.x >= patrol_end.x:
		patrol_direction = -1
	elif world_pos.x <= patrol_start.x:
		patrol_direction = 1
	
	_update_visual()
```

### Charger (Aggressive)

```gdscript
class_name EnemyCharger
extends Enemy

enum State { IDLE, ALERT, CHARGING, RECOVERING }

@export var detection_range: float = 48.0  # Screen pixels
@export var charge_speed: float = 80.0
@export var recovery_time: float = 1.0

var state: State = State.IDLE
var charge_direction: Vector3 = Vector3.ZERO
var recovery_timer: float = 0.0
var player_ref: Node2D = null

func _process(delta: float) -> void:
	match state:
		State.IDLE:
			_check_for_player()
		State.ALERT:
			_prepare_charge()
		State.CHARGING:
			_do_charge(delta)
		State.RECOVERING:
			_recover(delta)

func _check_for_player() -> void:
	if player_ref == null:
		player_ref = get_tree().get_first_node_in_group("player")
	if player_ref == null:
		return
	
	var my_screen := IsoUtils.world_to_screen(world_pos)
	var player_screen := IsoUtils.world_to_screen(player_ref.get_world_pos())
	
	if my_screen.distance_to(player_screen) < detection_range:
		state = State.ALERT

func _prepare_charge() -> void:
	# Flash/telegraph for 0.3 seconds
	charge_direction = (player_ref.get_world_pos() - world_pos).normalized()
	state = State.CHARGING

func _do_charge(delta: float) -> void:
	world_pos += charge_direction * charge_speed * delta
	
	# Check if hit wall or traveled too far
	# Then enter recovery
	recovery_timer = recovery_time
	state = State.RECOVERING

func _recover(delta: float) -> void:
	recovery_timer -= delta
	if recovery_timer <= 0:
		state = State.IDLE
```

### Shooter (Ranged)

```gdscript
class_name EnemyShooter
extends Enemy

@export var shoot_interval: float = 2.0
@export var projectile_speed: float = 60.0

var shoot_timer: float = 0.0
var projectile_scene: PackedScene

func _ready() -> void:
	add_to_group("enemies")
	projectile_scene = preload("res://scenes/enemies/projectile.tscn")
	shoot_timer = shoot_interval

func _process(delta: float) -> void:
	shoot_timer -= delta
	if shoot_timer <= 0:
		_shoot()
		shoot_timer = shoot_interval

func _shoot() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	
	var projectile := projectile_scene.instantiate()
	get_parent().add_child(projectile)
	
	var direction := (player.get_world_pos() - world_pos).normalized()
	projectile.setup(world_pos, direction, projectile_speed)
```

---

## 3.5 PROJECTILE SYSTEM

### Projectile Parameters

```gdscript
class_name Projectile
extends Node2D

var world_pos: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.ZERO
var speed: float = 60.0
var damage: int = 1
var lifetime: float = 5.0
```

### Projectile Implementation

```gdscript
func setup(start_pos: Vector3, dir: Vector3, spd: float) -> void:
	world_pos = start_pos
	direction = dir.normalized()
	speed = spd

func _process(delta: float) -> void:
	world_pos += direction * speed * delta
	lifetime -= delta
	
	if lifetime <= 0:
		queue_free()
		return
	
	_update_visual()
	_check_player_collision()

func _check_player_collision() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	
	var dist := world_pos.distance_to(player.get_world_pos())
	if dist < 8.0:  # Hit radius
		player.take_damage(damage)
		queue_free()
```

---

## 3.6 BOSS DESIGN

### Boss Structure

Each world ends with a boss fight featuring:
- **3 Phases** — Escalating difficulty and new attacks
- **Clear Patterns** — Learnable attack sequences
- **Vulnerability Windows** — Telegraphed moments to attack
- **Checkpoint Before Fight** — No repeating level to retry boss

### Boss Base Class

```gdscript
class_name Boss
extends Node2D

enum Phase { ONE, TWO, THREE }

@export var phase_1_health: int = 10
@export var phase_2_health: int = 10
@export var phase_3_health: int = 10

var current_phase: Phase = Phase.ONE
var current_health: int
var is_vulnerable: bool = false
var is_attacking: bool = false

signal phase_changed(new_phase: Phase)
signal defeated

func _ready() -> void:
	current_health = phase_1_health
	_start_phase(Phase.ONE)

func take_damage(amount: int) -> void:
	if not is_vulnerable:
		return
	
	current_health -= amount
	if current_health <= 0:
		_advance_phase()

func _advance_phase() -> void:
	match current_phase:
		Phase.ONE:
			current_phase = Phase.TWO
			current_health = phase_2_health
			_start_phase(Phase.TWO)
		Phase.TWO:
			current_phase = Phase.THREE
			current_health = phase_3_health
			_start_phase(Phase.THREE)
		Phase.THREE:
			defeated.emit()
			_die()

func _start_phase(phase: Phase) -> void:
	phase_changed.emit(phase)
	is_vulnerable = false
	# Override in subclass for phase-specific behavior
```

### Example Boss: World 1 - Giant Frog

```gdscript
class_name BossGiantFrog
extends Boss

enum Attack { TONGUE_LASH, BELLY_FLOP, SPAWN_HOPPERS }

var attack_timer: float = 0.0
var current_attack: Attack

func _start_phase(phase: Phase) -> void:
	super._start_phase(phase)
	
	match phase:
		Phase.ONE:
			# Tongue attack only
			_queue_attack(Attack.TONGUE_LASH)
		Phase.TWO:
			# Add belly flop
			_queue_attack(Attack.BELLY_FLOP)
		Phase.THREE:
			# Add minion spawns
			_queue_attack(Attack.SPAWN_HOPPERS)

func _execute_attack(attack: Attack) -> void:
	match attack:
		Attack.TONGUE_LASH:
			# Extend tongue toward player
			# Vulnerable after tongue retracts
			pass
		Attack.BELLY_FLOP:
			# Jump high, crash down
			# Creates shockwave
			# Vulnerable while stunned
			pass
		Attack.SPAWN_HOPPERS:
			# Spawn 3 Hopper enemies
			# Vulnerable briefly during spawn
			pass
```

---

## 3.7 COMBAT FEEL AND JUICE

### Hit Stop

Freeze game briefly on impactful hits:

```gdscript
func _apply_hitstop(duration: float = 0.05) -> void:
	Engine.time_scale = 0.0
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
```

### Screen Shake

```gdscript
# In camera or game manager
func shake(intensity: float = 4.0, duration: float = 0.2) -> void:
	var tween := create_tween()
	for i in range(int(duration / 0.02)):
		var offset := Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(self, "offset", offset, 0.02)
	tween.tween_property(self, "offset", Vector2.ZERO, 0.02)
```

### Death Particles

```gdscript
func _spawn_death_particles() -> void:
	var particles := preload("res://scenes/effects/enemy_death.tscn").instantiate()
	particles.global_position = global_position
	get_parent().add_child(particles)
	particles.emitting = true
```

### Flash on Hit

```gdscript
func _flash_white() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.0)
	tween.tween_property(sprite, "modulate", Color(2, 2, 2), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
```

---

## IMPLEMENTATION CHECKLIST

- [x] Base enemy class
- [x] Floater enemy (test enemy)
- [x] Enemy death (queue_free)
- [x] Enemy group for targeting
- [ ] Walker enemy (patrol)
- [ ] Charger enemy (aggressive)
- [ ] Shooter enemy (ranged)
- [ ] Projectile system
- [ ] All World 1 enemies
- [ ] Boss base class
- [ ] World 1 boss
- [ ] Hit stop
- [ ] Screen shake
- [ ] Death particles
- [ ] Hit flash

---

*Continue to Part 4: Level Design and World Structure*
