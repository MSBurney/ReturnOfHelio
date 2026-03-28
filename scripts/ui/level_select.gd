class_name LevelSelectScreen
extends Control

@onready var title_label: Label = $Panel/Title
@onready var menu: VBoxContainer = $Panel/Menu

var entries: Array[Dictionary] = []
var index: int = 0

func _ready() -> void:
	_rebuild_menu()
	_update_selection()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		index = (index - 1 + entries.size()) % entries.size()
		_play_ui_sfx("ui_move")
		_update_selection()
	elif event.is_action_pressed("ui_down"):
		index = (index + 1) % entries.size()
		_play_ui_sfx("ui_move")
		_update_selection()
	elif event.is_action_pressed("ui_accept"):
		_play_ui_sfx("ui_accept")
		_activate()
	elif event.is_action_pressed("ui_cancel"):
		_play_ui_sfx("ui_cancel")
		GameState.go_to_world_map()

func _rebuild_menu() -> void:
	for child in menu.get_children():
		child.queue_free()
	entries.clear()

	var world := GameState.current_world
	var unlocked_level := GameState.get_unlocked_level(world)
	title_label.text = "World %d - Level Select" % world

	for level_num in range(1, 14):
		var unlocked := level_num <= unlocked_level
		var entry := {
			"type": "level",
			"level": level_num,
			"unlocked": unlocked,
			"text": "Level %02d%s" % [level_num, "" if unlocked else " (Locked)"],
		}
		entries.append(entry)
		var label := Label.new()
		label.text = entry.text
		menu.add_child(label)

	var boss_unlocked := unlocked_level >= 13
	var boss_entry := {
		"type": "boss",
		"unlocked": boss_unlocked,
		"text": "Boss%s" % ("" if boss_unlocked else " (Locked)"),
	}
	entries.append(boss_entry)
	var boss_label := Label.new()
	boss_label.text = str(boss_entry.text)
	menu.add_child(boss_label)

	entries.append({"type": "back", "unlocked": true, "text": "Back"})
	var back_label := Label.new()
	back_label.text = "Back"
	menu.add_child(back_label)

	if entries.is_empty():
		entries.append({"type": "back", "unlocked": true, "text": "Back"})
		var fallback := Label.new()
		fallback.text = "Back"
		menu.add_child(fallback)
	index = clampi(index, 0, entries.size() - 1)

func _update_selection() -> void:
	for i in range(menu.get_child_count()):
		var label := menu.get_child(i) as Label
		if not label:
			continue
		var entry: Dictionary = entries[i]
		var unlocked: bool = bool(entry.get("unlocked", true))
		if i == index:
			label.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.8, 0.35, 0.35, 1)
		else:
			label.modulate = Color(0.7, 0.7, 0.7, 1) if unlocked else Color(0.35, 0.35, 0.35, 1)

func _activate() -> void:
	if entries.is_empty():
		GameState.go_to_world_map()
		return
	var entry: Dictionary = entries[index]
	if not bool(entry.get("unlocked", true)):
		_play_ui_sfx("ui_cancel")
		return
	match str(entry.get("type", "back")):
		"level":
			GameState.load_level(GameState.current_world, int(entry.get("level", 1)))
		"boss":
			GameState.load_boss_level(GameState.current_world)
		_:
			GameState.go_to_world_map()

func _play_ui_sfx(event_id: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(event_id)
