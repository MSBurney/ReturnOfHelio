class_name TargetReticle
extends Node2D

# Visual properties
@export var rotation_speed: float = 3.0
@export var pulse_speed: float = 4.0
@export var pulse_min: float = 0.8
@export var pulse_max: float = 1.2

var pulse_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	visible = false
	_setup_placeholder_sprite()

func _setup_placeholder_sprite() -> void:
	if sprite and sprite.texture == null:
		var size: int = 18
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center: float = size / 2.0
		
		for y in range(size):
			for x in range(size):
				var dx: float = x - center + 0.5
				var dy: float = y - center + 0.5
				var dist: float = sqrt(dx * dx + dy * dy)
				
				# Outer ring
				if dist >= 6.0 and dist <= 8.0:
					img.set_pixel(x, y, Color(1.0, 0.8, 0.0, 0.9))
				# Inner crosshair
				elif dist <= 7.0:
					if (x == int(center) or y == int(center)) and dist >= 2.0:
						img.set_pixel(x, y, Color(1.0, 0.8, 0.0, 0.9))
				# Corner brackets
				if (x <= 3 or x >= size - 4) and (y <= 3 or y >= size - 4):
					if x <= 3 and y <= 1:
						img.set_pixel(x, y, Color(1.0, 0.8, 0.0, 0.9))
					elif x <= 1 and y <= 3:
						img.set_pixel(x, y, Color(1.0, 0.8, 0.0, 0.9))
					elif x >= size - 4 and y <= 1:
						img.set_pixel(x, y, Color(1.0, 0.8, 0.0, 0.9))
					elif x >= size - 2 and y <= 3:
						img.set_pixel(x, y, Color(1.0, 0.8, 0.0, 0.9))
					elif x <= 3 and y >= size - 2:
						img.set_pixel(x, y, Color(1.0, 0.8, 0.0, 0.9))
					elif x <= 1 and y >= size - 4:
						img.set_pixel(x, y, Color(1.0, 0.8, 0.0, 0.9))
					elif x >= size - 4 and y >= size - 2:
						img.set_pixel(x, y, Color(1.0, 0.8, 0.0, 0.9))
					elif x >= size - 2 and y >= size - 4:
						img.set_pixel(x, y, Color(1.0, 0.8, 0.0, 0.9))
		
		var tex := ImageTexture.create_from_image(img)
		sprite.texture = tex

func _process(delta: float) -> void:
	if visible:
		# Rotate
		rotation += rotation_speed * delta
		
		# Pulse scale
		pulse_time += delta * pulse_speed
		var pulse_scale: float = lerp(pulse_min, pulse_max, (sin(pulse_time) + 1.0) / 2.0)
		scale = Vector2(pulse_scale, pulse_scale)

func show_at(screen_pos: Vector2) -> void:
	global_position = screen_pos
	visible = true

func hide_reticle() -> void:
	visible = false
