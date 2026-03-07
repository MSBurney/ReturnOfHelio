class_name OptionsMenu
extends Control

## Minimal options menu: volume controls + control mapping reference.

@onready var menu: VBoxContainer = $Panel/Menu
@onready var master_label: Label = $Panel/Menu/Master
@onready var music_label: Label = $Panel/Menu/Music
@onready var sfx_label: Label = $Panel/Menu/SFX

var index: int = 0
var master_db: float = 0.0
var music_db: float = 0.0
var sfx_db: float = 0.0

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_from_audio()
	_update_labels()
	_update_selection()

func show_menu() -> void:
	visible = true
	index = 0
	_refresh_from_audio()
	_update_labels()
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
	elif event.is_action_pressed("move_left"):
		_adjust_volume(-2.0)
	elif event.is_action_pressed("move_right"):
		_adjust_volume(2.0)
	elif event.is_action_pressed("ui_accept"):
		if index >= 4:
			_play_ui_sfx("ui_accept")
			hide_menu()
	elif event.is_action_pressed("ui_cancel"):
		_play_ui_sfx("ui_cancel")
		hide_menu()

func _adjust_volume(step_db: float) -> void:
	match index:
		0:
			master_db = clampf(master_db + step_db, -40.0, 6.0)
			_apply_bus("Master", master_db)
		1:
			music_db = clampf(music_db + step_db, -40.0, 6.0)
			_apply_bus("Music", music_db)
		2:
			sfx_db = clampf(sfx_db + step_db, -40.0, 6.0)
			_apply_bus("SFX", sfx_db)
		_:
			return
	_play_ui_sfx("ui_move")
	_update_labels()

func _apply_bus(bus_name: String, value_db: float) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("set_bus_volume"):
		audio.set_bus_volume(bus_name, value_db)

func _refresh_from_audio() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("get_bus_volume"):
		master_db = audio.get_bus_volume("Master")
		music_db = audio.get_bus_volume("Music")
		sfx_db = audio.get_bus_volume("SFX")

func _update_labels() -> void:
	master_label.text = "Master: %ddB" % int(round(master_db))
	music_label.text = "Music: %ddB" % int(round(music_db))
	sfx_label.text = "SFX: %ddB" % int(round(sfx_db))

func _update_selection() -> void:
	for i in range(menu.get_child_count()):
		var label := menu.get_child(i) as Label
		if not label:
			continue
		label.modulate = Color(1, 1, 1, 1) if i == index else Color(0.7, 0.7, 0.7, 1)

func _play_ui_sfx(event_id: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(event_id)
