class_name ScorePopup
extends Node2D

## Floating score text that drifts up and fades out.

var text: String = ""
var lifetime: float = 0.6
var _timer: float = 0.0
var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 2)
	_label.position = Vector2(-20, -8)
	add_child(_label)

func _process(delta: float) -> void:
	_timer += delta
	var t := _timer / lifetime
	position.y -= 30.0 * delta
	if _label:
		_label.modulate.a = 1.0 - t
	if t >= 1.0:
		queue_free()

static func spawn(parent: Node, screen_pos: Vector2, value: int) -> void:
	var popup := ScorePopup.new()
	popup.text = str(value)
	popup.position = screen_pos + Vector2(0, -12)
	popup.z_index = 1100
	parent.add_child(popup)
