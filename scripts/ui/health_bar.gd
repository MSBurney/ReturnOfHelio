class_name HealthBar
extends Node2D

# Simple world-space HP bar
@export var width: float = 20.0
@export var height: float = 3.0
@export var y_offset: float = -18.0
@export var bg_color: Color = Color(0, 0, 0, 0.7)
@export var fg_color: Color = Color(0.2, 0.9, 0.2, 0.9)

var _current: int = 1
var _max: int = 1

func _ready() -> void:
	position.y = y_offset
	queue_redraw()

func set_values(current: int, max_value: int) -> void:
	_current = max(current, 0)
	_max = max(max_value, 1)
	queue_redraw()

func _draw() -> void:
	var ratio := float(_current) / float(_max)
	var w := width
	var h := height
	draw_rect(Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)), bg_color, true)
	draw_rect(Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w * ratio, h)), fg_color, true)
