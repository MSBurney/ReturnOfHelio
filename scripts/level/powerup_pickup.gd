class_name PowerupPickup
extends IsoEntity

## Generic collectible used for power-ups and form switches.
const PickupBurstScene := preload("res://scenes/effects/pickup_collect_burst.tscn")

signal collected(pickup_type: String)

@export var pickup_type: String = "powerup_rock_dust"
@export var duration: float = 8.0
@export var radius: float = 0.65
@export var z_tolerance: float = 8.0

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	super._ready()
	_setup_placeholder_sprite()
	_update_screen_position()
	_update_depth_sort()

func setup(pos: Vector3, entity_type: String, entity_duration: float = 8.0) -> void:
	world_pos = pos
	pickup_type = entity_type
	duration = entity_duration
	_setup_placeholder_sprite()
	_update_screen_position()
	_update_depth_sort()

func _process(_delta: float) -> void:
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
		if dist > radius:
			continue
		_apply_to_player(p)
		_spawn_collect_burst()
		_play_collect_sfx()
		collected.emit(pickup_type)
		queue_free()
		return

func _apply_to_player(player: Node) -> void:
	if pickup_type.begins_with("powerup_"):
		var powerup_id := pickup_type.trim_prefix("powerup_")
		if player.has_method("apply_powerup"):
			player.apply_powerup(powerup_id, duration)
		return
	if pickup_type.begins_with("form_"):
		var form_id := pickup_type.trim_prefix("form_")
		if player.has_method("set_form"):
			player.set_form(form_id)

func _setup_placeholder_sprite() -> void:
	if not sprite:
		return
	if sprite.texture != null:
		return
	var texture_color := _resolve_color_for_type()
	var size := 8
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(3.5, 3.5)
	for y in range(size):
		for x in range(size):
			var dist := Vector2(x, y).distance_to(center)
			if dist <= 3.5:
				var alpha := 1.0 - (dist / 3.5)
				img.set_pixel(x, y, Color(texture_color.r, texture_color.g, texture_color.b, alpha))
	sprite.texture = ImageTexture.create_from_image(img)

func _resolve_color_for_type() -> Color:
	match pickup_type:
		"powerup_rock_dust":
			return Color(1.0, 0.95, 0.95, 1.0)
		"powerup_dash_dust":
			return Color(0.4, 1.0, 0.9, 1.0)
		"powerup_time_stone":
			return Color(0.8, 0.85, 1.0, 1.0)
		"form_serpent":
			return Color(0.55, 1.0, 0.35, 1.0)
		"form_burning_bush":
			return Color(1.0, 0.55, 0.2, 1.0)
		"form_phocid":
			return Color(0.45, 0.85, 1.0, 1.0)
		"form_metalsaur":
			return Color(0.75, 0.75, 0.85, 1.0)
		_:
			return Color(1.0, 0.9, 0.2, 1.0)

func _spawn_collect_burst() -> void:
	if PickupBurstScene == null:
		return
	var burst: Node2D = PickupBurstScene.instantiate()
	burst.position = IsoUtils.world_to_screen(world_pos)
	burst.z_index = 1000
	get_parent().add_child(burst)

func _play_collect_sfx() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("pickup")
