class_name OptionsMenu
extends Control

## Production options menu: audio, accessibility toggles, and keyboard remapping.

const REBIND_ACTIONS: Array[Dictionary] = [
	{"id": "p1_move_up", "label": "P1 Up"},
	{"id": "p1_move_down", "label": "P1 Down"},
	{"id": "p1_move_left", "label": "P1 Left"},
	{"id": "p1_move_right", "label": "P1 Right"},
	{"id": "p1_jump", "label": "P1 Jump"},
	{"id": "p1_attack", "label": "P1 Attack"},
	{"id": "p2_move_up", "label": "P2 Up"},
	{"id": "p2_move_down", "label": "P2 Down"},
	{"id": "p2_move_left", "label": "P2 Left"},
	{"id": "p2_move_right", "label": "P2 Right"},
	{"id": "p2_jump", "label": "P2 Jump"},
	{"id": "p2_attack", "label": "P2 Attack"},
	{"id": "ui_up", "label": "Menu Up"},
	{"id": "ui_down", "label": "Menu Down"},
	{"id": "ui_accept", "label": "Menu Accept"},
	{"id": "ui_cancel", "label": "Menu Cancel"},
]

@onready var menu: VBoxContainer = $Panel/Menu

var index: int = 0
var master_db: float = 0.0
var music_db: float = 0.0
var sfx_db: float = 0.0
var waiting_for_key_action: String = ""
var entries: Array[Dictionary] = []

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_entries()
	_refresh_from_state()
	_update_labels()
	_update_selection()

func show_menu() -> void:
	visible = true
	index = 0
	waiting_for_key_action = ""
	_refresh_from_state()
	_update_labels()
	_update_selection()

func hide_menu() -> void:
	waiting_for_key_action = ""
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if waiting_for_key_action != "":
		_handle_rebind_input(event)
		return

	if event.is_action_pressed("ui_up"):
		index = (index - 1 + entries.size()) % entries.size()
		_play_ui_sfx("ui_move")
		_update_selection()
	elif event.is_action_pressed("ui_down"):
		index = (index + 1) % entries.size()
		_play_ui_sfx("ui_move")
		_update_selection()
	elif event.is_action_pressed("ui_left"):
		_adjust_current(-2.0)
	elif event.is_action_pressed("ui_right"):
		_adjust_current(2.0)
	elif event.is_action_pressed("ui_accept"):
		_activate_current()
	elif event.is_action_pressed("ui_cancel"):
		_play_ui_sfx("ui_cancel")
		hide_menu()

func _build_entries() -> void:
	entries.clear()
	entries.append({"type": "volume", "id": "master", "label": "Master"})
	entries.append({"type": "volume", "id": "music", "label": "Music"})
	entries.append({"type": "volume", "id": "sfx", "label": "SFX"})
	entries.append({"type": "toggle", "section": "accessibility", "id": "screen_shake_enabled", "label": "Screen Shake"})
	entries.append({"type": "toggle", "section": "accessibility", "id": "hit_stop_enabled", "label": "Hit Stop"})
	entries.append({"type": "toggle", "section": "accessibility", "id": "reduced_flashes", "label": "Reduced Flashes"})
	entries.append({"type": "toggle", "section": "accessibility", "id": "high_contrast_hud", "label": "High Contrast HUD"})
	for item in REBIND_ACTIONS:
		entries.append({"type": "rebind", "id": str(item["id"]), "label": str(item["label"])})
	entries.append({"type": "back", "label": "Back"})

	while menu.get_child_count() < entries.size():
		menu.add_child(Label.new())
	while menu.get_child_count() > entries.size():
		menu.get_child(menu.get_child_count() - 1).queue_free()

func _refresh_from_state() -> void:
	master_db = float(GameState.get_setting("audio", "master_db", 0.0))
	music_db = float(GameState.get_setting("audio", "music_db", 0.0))
	sfx_db = float(GameState.get_setting("audio", "sfx_db", 0.0))

func _update_labels() -> void:
	for i in range(entries.size()):
		var label := menu.get_child(i) as Label
		if not label:
			continue
		var entry := entries[i]
		match str(entry["type"]):
			"volume":
				var value_db := 0.0
				match str(entry["id"]):
					"master":
						value_db = master_db
					"music":
						value_db = music_db
					"sfx":
						value_db = sfx_db
				label.text = "%s: %ddB" % [entry["label"], int(round(value_db))]
			"toggle":
				var enabled: bool = bool(GameState.get_setting(str(entry["section"]), str(entry["id"]), false))
				label.text = "%s: %s" % [entry["label"], "ON" if enabled else "OFF"]
			"rebind":
				var binding_text := "-"
				if InputManager and InputManager.has_method("get_binding_display"):
					binding_text = InputManager.get_binding_display(str(entry["id"]))
				label.text = "%s: %s" % [entry["label"], binding_text]
			"back":
				label.text = "Back"

	if waiting_for_key_action != "":
		for i in range(entries.size()):
			if str(entries[i].get("id", "")) == waiting_for_key_action:
				var selected := menu.get_child(i) as Label
				if selected:
					selected.text = "%s: Press Key..." % entries[i]["label"]

func _update_selection() -> void:
	for i in range(entries.size()):
		var label := menu.get_child(i) as Label
		if not label:
			continue
		label.modulate = Color(1, 1, 1, 1) if i == index else Color(0.7, 0.7, 0.7, 1)

func _activate_current() -> void:
	var entry := entries[index]
	match str(entry["type"]):
		"rebind":
			waiting_for_key_action = str(entry["id"])
			_play_ui_sfx("ui_accept")
			_update_labels()
			_update_selection()
		"toggle":
			_toggle_current()
		"back":
			_play_ui_sfx("ui_accept")
			hide_menu()
		_:
			# Volume items are adjusted with left/right.
			pass

func _adjust_current(step_db: float) -> void:
	var entry := entries[index]
	if str(entry["type"]) != "volume":
		if str(entry["type"]) == "toggle":
			_toggle_current()
		return
	match str(entry["id"]):
		"master":
			master_db = clampf(master_db + step_db, -40.0, 6.0)
			_apply_bus("Master", master_db)
			GameState.set_setting("audio", "master_db", master_db, false)
		"music":
			music_db = clampf(music_db + step_db, -40.0, 6.0)
			_apply_bus("Music", music_db)
			GameState.set_setting("audio", "music_db", music_db, false)
		"sfx":
			sfx_db = clampf(sfx_db + step_db, -40.0, 6.0)
			_apply_bus("SFX", sfx_db)
			GameState.set_setting("audio", "sfx_db", sfx_db, false)
		_:
			return
	GameState.save_progress()
	_play_ui_sfx("ui_move")
	_update_labels()

func _toggle_current() -> void:
	var entry := entries[index]
	if str(entry["type"]) != "toggle":
		return
	var section := str(entry["section"])
	var key := str(entry["id"])
	var enabled: bool = bool(GameState.get_setting(section, key, false))
	GameState.set_setting(section, key, not enabled)
	_play_ui_sfx("ui_move")
	_update_labels()

func _handle_rebind_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		waiting_for_key_action = ""
		_play_ui_sfx("ui_cancel")
		_update_labels()
		_update_selection()
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var code: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	if code == 0:
		return
	if InputManager and InputManager.has_method("rebind_action"):
		InputManager.rebind_action(waiting_for_key_action, code)
	if InputManager and InputManager.has_method("get_bindings") and GameState.has_method("update_control_bindings"):
		GameState.update_control_bindings(InputManager.get_bindings())
	waiting_for_key_action = ""
	_play_ui_sfx("ui_accept")
	_update_labels()
	_update_selection()

func _apply_bus(bus_name: String, value_db: float) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("set_bus_volume"):
		audio.set_bus_volume(bus_name, value_db)

func _play_ui_sfx(event_id: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(event_id)
