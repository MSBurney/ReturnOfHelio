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
	if not sprite:
		return
	# Flag/pole checkpoint sprite
	var w := 10
	var h := 16
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var flag_color := Color(0.3, 0.7, 1.0) if not activated else Color(0.2, 1.0, 0.4)
	var pole_color := Color(0.6, 0.5, 0.4)
	for y in range(h):
		for x in range(w):
			# Pole (center column, full height)
			if x >= 4 and x <= 5 and y >= 2:
				img.set_pixel(x, y, pole_color)
			# Flag (triangle at top)
			if y >= 0 and y <= 6 and x >= 5 and x < 5 + (7 - y):
				img.set_pixel(x, y, flag_color)
			# Base (small platform)
			if y >= 13 and x >= 2 and x <= 7:
				img.set_pixel(x, y, pole_color.darkened(0.2))
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.offset = Vector2(0, -12)
