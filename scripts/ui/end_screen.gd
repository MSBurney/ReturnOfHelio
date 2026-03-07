class_name EndScreen
extends Control

@onready var menu: VBoxContainer = $Panel/Menu

var index: int = 0

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_selection()

func show_menu() -> void:
	visible = true
	index = 0
	_update_selection()

func hide_menu() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
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
	elif event.is_action_pressed("ui_cancel"):
		# Cancel is mapped (X/K/ESC), no-op on end screen by design.
		pass

func _update_selection() -> void:
	for i in range(menu.get_child_count()):
		var label := menu.get_child(i) as Label
		if label:
			label.modulate = Color(1, 1, 1, 1) if i == index else Color(0.7, 0.7, 0.7, 1)

func _activate() -> void:
	match index:
		0:
			# Next Level
			get_tree().paused = false
			_load_next_level()
		1:
			get_tree().paused = false
			GameState.restart_game()
		2:
			get_tree().paused = false
			GameState.go_to_main_menu()

func _load_next_level() -> void:
	if GameState.current_level == 0:
		# Boss level completed — world complete
		GameState.go_to_main_menu()
	elif GameState.current_level >= 13:
		# Last regular level — load boss
		GameState.load_boss_level(GameState.current_world)
	else:
		GameState.load_level(GameState.current_world, GameState.current_level + 1)

func _play_ui_sfx(event_id: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(event_id)
