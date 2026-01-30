class_name TitleScreen
extends Control

@onready var menu: VBoxContainer = $Menu

var index: int = 0

func _ready() -> void:
	_update_selection()

func _unhandled_input(event: InputEvent) -> void:
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
			GameState.start_game(1)
		1:
			GameState.start_game(2)
		2:
			get_tree().quit()
