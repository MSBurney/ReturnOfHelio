class_name PauseMenu
extends Control

@onready var menu: VBoxContainer = $Panel/Menu
@onready var options_menu: OptionsMenu = $OptionsMenu

var index: int = 0

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_selection()

func show_menu() -> void:
	visible = true
	_update_selection()

func hide_menu() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if options_menu and options_menu.visible:
		return
	if event.is_action_pressed("ui_up"):
		index = (index - 1 + menu.get_child_count()) % menu.get_child_count()
		_play_ui_sfx("ui_move")
		_update_selection()
	elif event.is_action_pressed("ui_down"):
		index = (index + 1) % menu.get_child_count()
		_play_ui_sfx("ui_move")
		_update_selection()
	elif event.is_action_pressed("ui_accept"):
		_play_ui_sfx("ui_accept")
		_activate()
	elif event.is_action_pressed("ui_cancel") or _is_escape_pressed(event):
		_play_ui_sfx("ui_cancel")
		_resume()

func _update_selection() -> void:
	for i in range(menu.get_child_count()):
		var label := menu.get_child(i) as Label
		if label:
			label.modulate = Color(1, 1, 1, 1) if i == index else Color(0.7, 0.7, 0.7, 1)

func _activate() -> void:
	match index:
		0:
			_resume()
		1:
			if options_menu:
				options_menu.show_menu()
		2:
			get_tree().paused = false
			GameState.restart_game()
		3:
			get_tree().paused = false
			GameState.go_to_main_menu()

func _resume() -> void:
	get_tree().paused = false
	if options_menu:
		options_menu.hide_menu()
	hide_menu()

func _is_escape_pressed(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == 4194305 or key_event.physical_keycode == 4194305

func _play_ui_sfx(event_id: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(event_id)
