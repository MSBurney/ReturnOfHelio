class_name CombatProjectile
extends IsoEntity

## Shared projectile actor used by enemy shooters and player form specials.

@export var team: String = "enemy"  # "enemy" or "player"
@export var speed: float = 10.0
@export var damage: int = 1
@export var hit_radius: float = 0.6
@export var lifetime: float = 1.4
@export var z_tolerance: float = 10.0
@export var explosive_radius: float = 0.0
@export var tint: Color = Color(1, 0.2, 0.2, 1.0)

var direction: Vector2 = Vector2.RIGHT
var owner_node: Node = null
var _hit_ids: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	super._ready()
	_setup_sprite()
	_update_screen_position()
	_update_depth_sort()

func setup(
	start_world_pos: Vector3,
	move_dir: Vector2,
	owner: Node,
	projectile_team: String,
	projectile_damage: int,
	projectile_speed: float,
	projectile_lifetime: float,
	projectile_color: Color,
	projectile_explosive_radius: float = 0.0
) -> void:
	world_pos = start_world_pos
	direction = move_dir.normalized() if move_dir.length_squared() > 0.0 else Vector2.RIGHT
	owner_node = owner
	team = projectile_team
	damage = projectile_damage
	speed = projectile_speed
	lifetime = projectile_lifetime
	tint = projectile_color
	explosive_radius = projectile_explosive_radius
	_setup_sprite()
	_update_screen_position()
	_update_depth_sort()

func _process(delta: float) -> void:
	lifetime = maxf(lifetime - delta, 0.0)
	if lifetime <= 0.0:
		queue_free()
		return
	world_pos.x += direction.x * speed * delta
	world_pos.y += direction.y * speed * delta
	_update_screen_position()
	_update_depth_sort()
	_check_collisions()

func _check_collisions() -> void:
	if team == "enemy":
		_check_hits_on_players()
	else:
		_check_hits_on_enemies()

func _check_hits_on_players() -> void:
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if not is_instance_valid(p):
			continue
		if not p.has_method("get_world_pos"):
			continue
		var key := str(p.get_instance_id())
		if _hit_ids.has(key):
			continue
		var p_pos: Vector3 = p.get_world_pos()
		if absf(p_pos.z - world_pos.z) > z_tolerance:
			continue
		var dist := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y).length()
		if dist > hit_radius:
			continue
		_hit_ids[key] = true
		var dir := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y)
		if p.has_method("take_damage"):
			p.take_damage(damage, dir, owner_node)
		_explode_and_free()
		return

func _check_hits_on_enemies() -> void:
	var targets := get_tree().get_nodes_in_group("hurtboxes")
	if targets.is_empty():
		targets = get_tree().get_nodes_in_group("enemies")
	for target in targets:
		if not is_instance_valid(target):
			continue
		if not target.has_method("get_world_pos"):
			continue
		var owner: Node = target
		if target.has_method("get_owner_body"):
			var body: Node = target.get_owner_body()
			if body:
				owner = body
		if owner == owner_node:
			continue
		var key := str(owner.get_instance_id())
		if _hit_ids.has(key):
			continue
		var t_pos: Vector3 = target.get_world_pos()
		if absf(t_pos.z - world_pos.z) > z_tolerance:
			continue
		var dist := Vector2(t_pos.x - world_pos.x, t_pos.y - world_pos.y).length()
		if dist > hit_radius:
			continue
		_hit_ids[key] = true
		if owner and owner.has_method("take_damage"):
			owner.take_damage(damage, direction)
		elif target.has_method("take_damage"):
			target.take_damage(damage, direction)
		_explode_and_free()
		return

func _explode_and_free() -> void:
	if explosive_radius > 0.0:
		_apply_explosion()
	queue_free()

func _apply_explosion() -> void:
	if team == "enemy":
		var players := get_tree().get_nodes_in_group("players")
		for p in players:
			if not is_instance_valid(p):
				continue
			if not p.has_method("get_world_pos"):
				continue
			var p_pos: Vector3 = p.get_world_pos()
			if absf(p_pos.z - world_pos.z) > z_tolerance:
				continue
			var dist := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y).length()
			if dist > explosive_radius:
				continue
			if p.has_method("take_damage"):
				p.take_damage(damage, Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y), owner_node)
		return
	var targets := get_tree().get_nodes_in_group("hurtboxes")
	if targets.is_empty():
		targets = get_tree().get_nodes_in_group("enemies")
	for target in targets:
		if not is_instance_valid(target):
			continue
		if not target.has_method("get_world_pos"):
			continue
		var owner: Node = target
		if target.has_method("get_owner_body"):
			var body: Node = target.get_owner_body()
			if body:
				owner = body
		if owner == owner_node:
			continue
		var t_pos: Vector3 = target.get_world_pos()
		if absf(t_pos.z - world_pos.z) > z_tolerance:
			continue
		var dist := Vector2(t_pos.x - world_pos.x, t_pos.y - world_pos.y).length()
		if dist > explosive_radius:
			continue
		if owner and owner.has_method("take_damage"):
			owner.take_damage(damage, Vector2(t_pos.x - world_pos.x, t_pos.y - world_pos.y))

func _setup_sprite() -> void:
	if not sprite:
		return
	if sprite.texture != null and sprite.modulate == tint:
		return
	var size := 6
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(2.5, 2.5)
	for y in range(size):
		for x in range(size):
			var dist := Vector2(x, y).distance_to(center)
			if dist <= 2.5:
				var alpha := 1.0 - (dist / 2.5)
				img.set_pixel(x, y, Color(tint.r, tint.g, tint.b, alpha))
	sprite.texture = ImageTexture.create_from_image(img)
