class_name Pickup
extends IsoEntity

const PickupBurstScene := preload("res://scenes/effects/pickup_collect_burst.tscn")

signal collected(value: int)

@export var value: int = 1
@export var radius: float = 0.6
@export var z_tolerance: float = 6.0

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	super._ready()
	_setup_placeholder_sprite()
	_update_screen_position()

func _setup_placeholder_sprite() -> void:
	if sprite and sprite.texture == null:
		var size := 8
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center := Vector2(3.5, 3.5)
		for y in range(size):
			for x in range(size):
				var d := Vector2(x, y).distance_to(center)
				if d <= 3.5:
					var alpha := 1.0 - (d / 3.5)
					img.set_pixel(x, y, Color(1.0, 0.9, 0.2, alpha))
		sprite.texture = ImageTexture.create_from_image(img)

func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if not is_instance_valid(p):
			continue
		if not p.has_method("get_world_pos"):
			continue
		var p_pos: Vector3 = p.get_world_pos()
		var height_diff := absf(p_pos.z - world_pos.z)
		if height_diff > z_tolerance:
			continue
		var dist := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y).length()
		if dist <= radius:
			_spawn_collect_burst()
			var audio := get_node_or_null("/root/AudioManager")
			if audio and audio.has_method("play_sfx"):
				audio.play_sfx("pickup")
			emit_signal("collected", value)
			queue_free()
			return

var is_key: bool = false

func set_as_key() -> void:
	is_key = true
	if sprite:
		var size := 8
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		# Key shape: magenta diamond with teeth
		var center := Vector2(3.5, 3.5)
		for y in range(size):
			for x in range(size):
				var dx := absf(x - center.x)
				var dy := absf(y - center.y)
				if dx + dy <= 3.5:
					img.set_pixel(x, y, Color(1.0, 0.3, 0.5, 1.0))
				if y >= 5 and x >= 2 and x <= 5 and (x % 2 == 0):
					img.set_pixel(x, y, Color(0.9, 0.2, 0.4, 1.0))
		sprite.texture = ImageTexture.create_from_image(img)

func setup(pos: Vector3) -> void:
	world_pos = pos
	_update_screen_position()
	_update_depth_sort()

func _spawn_collect_burst() -> void:
	if not PickupBurstScene:
		return
	var burst := PickupBurstScene.instantiate()
	burst.position = IsoUtils.world_to_screen(world_pos)
	burst.z_index = 1000
	get_parent().add_child(burst)
