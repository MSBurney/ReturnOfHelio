class_name GateMarker
extends Node2D

@export var active: bool = false

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	_setup_sprite()
	_update_color()

func set_active(is_active: bool) -> void:
	active = is_active
	_update_color()

func _update_color() -> void:
	if sprite:
		sprite.modulate = Color(1.0, 0.6, 0.2, 1.0) if active else Color(0.3, 0.3, 0.3, 1.0)

func _setup_sprite() -> void:
	if sprite and sprite.texture == null:
		var size := 12
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center := Vector2(5.5, 5.5)
		for y in range(size):
			for x in range(size):
				var d := Vector2(x, y).distance_to(center)
				if d <= 5.5:
					var alpha := 1.0 - (d / 5.5)
					img.set_pixel(x, y, Color(1.0, 0.6, 0.2, alpha))
		sprite.texture = ImageTexture.create_from_image(img)
