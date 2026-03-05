class_name EndScreen
extends CanvasLayer

@onready var menu: VBoxContainer = $Panel/Menu

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
	if event.is_action_pressed("ui_up"):
		index = (index - 1 + menu.get_child_count()) % menu.get_child_count()
		_update_selection()
	elif event.is_action_pressed("ui_down"):
		index = (index + 1) % menu.get_child_count()
		_update_selection()
	elif event.is_action_pressed("ui_accept"):
		_activate()

func _update_selection() -> void:
	for i in range(menu.get_child_count()):
		var label := menu.get_child(i) as Label
		if label:
			label.modulate = Color(1, 1, 1, 1) if i == index else Color(0.7, 0.7, 0.7, 1)

func _activate() -> void:
	match index:
		0:
			get_tree().paused = false
			GameState.restart_game()
		1:
			get_tree().paused = false
			GameState.go_to_main_menu()
