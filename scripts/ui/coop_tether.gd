class_name CoopTether
extends Control

## Simple dotted tether drawn in screen space between both players.

@export var dot_count: int = 8
@export var dot_radius: float = 2.0
@export var dot_color: Color = Color(1, 1, 1, 0.95)

var player_a: Node2D = null
var player_b: Node2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

func set_players(a: Node2D, b: Node2D) -> void:
	player_a = a
	player_b = b
	visible = is_instance_valid(player_a) and is_instance_valid(player_b)

func _process(_delta: float) -> void:
	visible = is_instance_valid(player_a) and is_instance_valid(player_b)
	if visible:
		queue_redraw()

func _draw() -> void:
	if not visible:
		return
	if dot_count <= 0:
		return
	var from_pos := player_a.global_position
	var to_pos := player_b.global_position
	for i in range(dot_count + 1):
		var t: float = float(i) / float(dot_count)
		draw_circle(from_pos.lerp(to_pos, t), dot_radius, dot_color)
