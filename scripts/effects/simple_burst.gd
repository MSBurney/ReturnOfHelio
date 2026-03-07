class_name SimpleBurst
extends Node2D

## Lightweight scripted burst used for temporary placeholder particles.

@export var particle_count: int = 6
@export var speed: float = 36.0
@export var lifetime: float = 0.25
@export var size_px: int = 3
@export var burst_color: Color = Color(1.0, 0.85, 0.2, 1.0)

var _time_left: float = 0.0
var _particles: Array[Dictionary] = []

func _ready() -> void:
	_time_left = lifetime
	var tex := _make_pixel_texture(maxi(size_px, 1), burst_color)
	for _i in range(particle_count):
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = true
		add_child(sprite)
		var angle := randf() * TAU
		var velocity := Vector2(cos(angle), sin(angle)) * speed * randf_range(0.65, 1.2)
		_particles.append({
			"sprite": sprite,
			"velocity": velocity,
		})

func _process(delta: float) -> void:
	if _time_left <= 0.0:
		queue_free()
		return
	_time_left = maxf(_time_left - delta, 0.0)
	var t: float = _time_left / maxf(lifetime, 0.001)
	for entry in _particles:
		var sprite: Sprite2D = entry["sprite"]
		var velocity: Vector2 = entry["velocity"]
		sprite.position += velocity * delta
		entry["velocity"] = velocity * 0.9
		sprite.modulate.a = t

func _make_pixel_texture(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
