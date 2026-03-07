class_name TitleScreen
extends Control

@onready var menu: VBoxContainer = $Menu

var index: int = 0

func _ready() -> void:
	_play_music("title")
	if not GameState.has_save_data():
		index = 1
	_update_selection()

func _unhandled_input(event: InputEvent) -> void:
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
	elif event.is_action_pressed("ui_cancel"):
		# Cancel is mapped (X/K/ESC), no-op on title screen.
		pass

func _update_selection() -> void:
	for i in range(menu.get_child_count()):
		var label := menu.get_child(i) as Label
		if label:
			var enabled: bool = i != 0 or GameState.has_save_data()
			var selected := i == index
			if not enabled:
				label.modulate = Color(0.35, 0.35, 0.35, 1.0)
			else:
				label.modulate = Color(1, 1, 1, 1) if selected else Color(0.7, 0.7, 0.7, 1)

func _activate() -> void:
	match index:
		0:
			GameState.continue_game()
		1:
			GameState.start_game(1)
		2:
			GameState.start_game(2)
		3:
			get_tree().quit()

func _play_ui_sfx(event_id: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(event_id)

func _play_music(track_id: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_music"):
		audio.play_music(track_id, 0.2)
