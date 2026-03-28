extends CanvasLayer

## Global fade transitions for scene/segment/menu flow.

var _fade_rect: ColorRect = null
var _busy: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.anchor_left = 0.0
	_fade_rect.anchor_top = 0.0
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.offset_left = 0.0
	_fade_rect.offset_top = 0.0
	_fade_rect.offset_right = 0.0
	_fade_rect.offset_bottom = 0.0
	add_child(_fade_rect)

func is_busy() -> bool:
	return _busy

func transition_to_scene(scene_path: String, fade_out_sec: float = 0.16, fade_in_sec: float = 0.16) -> void:
	if scene_path == "":
		return
	if _busy:
		return
	_run_scene_transition(scene_path, fade_out_sec, fade_in_sec)

func flash(fade_out_sec: float = 0.08, fade_in_sec: float = 0.08) -> void:
	if _busy:
		return
	_run_flash(fade_out_sec, fade_in_sec)

func _run_scene_transition(scene_path: String, fade_out_sec: float, fade_in_sec: float) -> void:
	_busy = true
	await _fade_to(1.0, fade_out_sec)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await _fade_to(0.0, fade_in_sec)
	_busy = false

func _run_flash(fade_out_sec: float, fade_in_sec: float) -> void:
	_busy = true
	await _fade_to(0.65, fade_out_sec)
	await _fade_to(0.0, fade_in_sec)
	_busy = false

func _fade_to(alpha: float, duration: float) -> void:
	if _fade_rect == null:
		return
	if duration <= 0.0:
		_fade_rect.color.a = alpha
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade_rect, "color:a", alpha, duration)
	await tween.finished
