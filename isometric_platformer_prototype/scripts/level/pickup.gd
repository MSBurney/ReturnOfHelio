class_name Pickup
extends IsoEntity

signal collected(value: int)

@export var value: int = 1
@export var radius: float = 0.6

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
		var dist := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y).length()
		if dist <= radius:
			emit_signal("collected", value)
			queue_free()
			return

func setup(pos: Vector3) -> void:
	world_pos = pos
	_update_screen_position()
	_update_depth_sort()
