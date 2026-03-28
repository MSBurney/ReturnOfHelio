class_name WorldMapScreen
extends Control

@onready var title_label: Label = $Panel/Title
@onready var menu: VBoxContainer = $Panel/Menu

var index: int = 0

func _ready() -> void:
	_play_music("title")
	title_label.text = "World %d Map" % GameState.current_world
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
		_play_ui_sfx("ui_cancel")
		GameState.go_to_main_menu()

func _update_selection() -> void:
	for i in range(menu.get_child_count()):
		var label := menu.get_child(i) as Label
		if not label:
			continue
		label.modulate = Color(1, 1, 1, 1) if i == index else Color(0.7, 0.7, 0.7, 1)
	var unlocked_level := GameState.get_unlocked_level(GameState.current_world)
	var continue_label := menu.get_node_or_null("Continue") as Label
	if continue_label:
		continue_label.text = "Continue (L%d)" % maxi(GameState.get_continue_level(), 1)
	var level_select_label := menu.get_node_or_null("LevelSelect") as Label
	if level_select_label:
		level_select_label.text = "Level Select (1-%d)" % unlocked_level

func _activate() -> void:
	match index:
		0:
			GameState.load_continue_target()
		1:
			GameState.go_to_level_select()
		2:
			GameState.go_to_main_menu()

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
