class_name Checkpoint
extends Node2D

## Visual checkpoint marker. Changes appearance when activated.

@onready var sprite: Sprite2D = $Sprite

var activated: bool = false
var tile_pos: Vector2i = Vector2i.ZERO

func _ready() -> void:
	_setup_sprite()

func setup(pos: Vector2i, screen_pos: Vector2) -> void:
	tile_pos = pos
	position = screen_pos
	z_index = 300

func activate() -> void:
	if activated:
		return
	activated = true
	_setup_sprite()

func _setup_sprite() -> void:
	if not sprite or sprite.texture != null:
		# Only create once or on re-create after activation
		pass
	var size := 10
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(4.5, 4.5)
	var base_color := Color(0.3, 0.7, 1.0) if not activated else Color(0.2, 1.0, 0.4)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x, y).distance_to(center)
			if d <= 4.5:
				var alpha := 1.0 - (d / 4.5) * 0.5
				var shade := 1.0 - (float(y) / size) * 0.3
				img.set_pixel(x, y, Color(base_color.r * shade, base_color.g * shade, base_color.b * shade, alpha))
	var tex := ImageTexture.create_from_image(img)
	if sprite:
		sprite.texture = tex
	sprite.offset = Vector2(0, -5)
