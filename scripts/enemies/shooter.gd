class_name ShooterEnemy
extends Enemy

## Ranged archetype that patrols/chases and periodically fires projectiles.

const ProjectileScene := preload("res://scenes/combat/projectile.tscn")

@export var shot_interval: float = 1.2
@export var shot_speed: float = 9.0
@export var shot_damage: int = 1
@export var shot_range: float = 8.0
@export var shot_color: Color = Color(1.0, 0.3, 0.2, 1.0)

var shot_timer: float = 0.0

func _ready() -> void:
	float_height = 0.0
	bob_amplitude = 0.0
	max_hp = 2
	score_value = 180
	super._ready()

func _process(delta: float) -> void:
	_update_timers(delta)
	_update_ai(delta)
	_update_shooting(delta)
	var ground_height := _ground_height_at(world_pos.x, world_pos.y)
	base_z = ground_height + float_height
	world_pos.z = base_z
	_update_screen_position()
	_update_depth_sort()

func _update_shooting(delta: float) -> void:
	shot_timer += delta
	if shot_timer < shot_interval:
		return
	var target := _find_chase_target()
	if not target:
		return
	if not target.has_method("get_world_pos"):
		return
	var t_pos: Vector3 = target.get_world_pos()
	var to_target := Vector2(t_pos.x - world_pos.x, t_pos.y - world_pos.y)
	if to_target.length() > shot_range or to_target.length_squared() <= 0.0001:
		return
	shot_timer = 0.0
	_fire_projectile(to_target.normalized())

func _fire_projectile(dir: Vector2) -> void:
	if ProjectileScene == null:
		return
	if get_parent() == null:
		return
	var projectile: Node2D = ProjectileScene.instantiate()
	get_parent().add_child(projectile)
	if projectile.has_method("setup"):
		projectile.setup(
			Vector3(world_pos.x, world_pos.y, world_pos.z + 6.0),
			dir,
			self,
			"enemy",
			shot_damage,
			shot_speed,
			1.6,
			shot_color,
			0.0
		)

func _setup_placeholder_sprites() -> void:
	if sprite and sprite.texture == null:
		var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
		var center := Vector2(7, 7)
		for y in range(14):
			for x in range(14):
				var pos := Vector2(x, y)
				var dist := pos.distance_to(center)
				if dist <= 5.0:
					var shade := 1.0 - (pos.x + pos.y - 7.0) * 0.035
					img.set_pixel(x, y, Color(0.85 * shade, 0.35 * shade, 0.2 * shade))
				elif abs(x - 7) <= 1 and y <= 2:
					img.set_pixel(x, y, Color(1.0, 0.8, 0.3))
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.offset = Vector2(0, -7)
	if shadow and shadow.texture == null:
		var simg := Image.create(10, 5, false, Image.FORMAT_RGBA8)
		for y in range(5):
			for x in range(10):
				var cx := x - 5
				var cy := y - 2.5
				if (cx * cx) / 25.0 + (cy * cy) / 6.25 <= 1.0:
					simg.set_pixel(x, y, Color(0, 0, 0, 0.5))
		shadow.texture = ImageTexture.create_from_image(simg)
