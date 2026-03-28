extends Node

## Input rebinding manager.
## Owns keyboard bindings for gameplay/menu actions and exposes runtime remap APIs.

const CONTROL_ACTIONS: PackedStringArray = [
	"ui_up",
	"ui_down",
	"ui_left",
	"ui_right",
	"ui_accept",
	"ui_cancel",
	"p1_move_up",
	"p1_move_down",
	"p1_move_left",
	"p1_move_right",
	"p1_jump",
	"p1_attack",
	"p2_move_up",
	"p2_move_down",
	"p2_move_left",
	"p2_move_right",
	"p2_jump",
	"p2_attack",
	"coop_toggle",
]

const DEFAULT_BINDINGS: Dictionary = {
	"ui_up": [KEY_W, KEY_UP],
	"ui_down": [KEY_S, KEY_DOWN],
	"ui_left": [KEY_A, KEY_LEFT],
	"ui_right": [KEY_D, KEY_RIGHT],
	"ui_accept": [KEY_J, KEY_Z],
	"ui_cancel": [KEY_ESCAPE, KEY_K, KEY_X],
	"p1_move_up": [KEY_W],
	"p1_move_down": [KEY_S],
	"p1_move_left": [KEY_A],
	"p1_move_right": [KEY_D],
	"p1_jump": [KEY_J],
	"p1_attack": [KEY_K],
	"p2_move_up": [KEY_UP],
	"p2_move_down": [KEY_DOWN],
	"p2_move_left": [KEY_LEFT],
	"p2_move_right": [KEY_RIGHT],
	"p2_jump": [KEY_Z],
	"p2_attack": [KEY_X],
	"coop_toggle": [KEY_F2],
}

var _player_device_owner: Dictionary = {1: -1, 2: -1}

func _ready() -> void:
	_apply_default_bindings()

func assign_device(player_id: int, device_id: int) -> void:
	_player_device_owner[player_id] = device_id

func get_device_for_player(player_id: int) -> int:
	return int(_player_device_owner.get(player_id, -1))

func get_bindable_actions() -> PackedStringArray:
	return CONTROL_ACTIONS

func get_bindings() -> Dictionary:
	var out: Dictionary = {}
	for action_name in CONTROL_ACTIONS:
		var keycodes: Array[int] = []
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				var key_event := event as InputEventKey
				var code: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
				if code != 0:
					keycodes.append(code)
		out[action_name] = keycodes
	return out

func apply_bindings(bindings: Dictionary) -> void:
	for action_name in CONTROL_ACTIONS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)
		var keycodes: Variant = bindings.get(action_name, DEFAULT_BINDINGS.get(action_name, []))
		if keycodes is Array:
			for code_variant in keycodes:
				var code: int = int(code_variant)
				if code != 0:
					InputMap.action_add_event(action_name, _make_key_event(code))
	# Mirror old aggregate movement actions used by some existing systems.
	_sync_legacy_actions()

func rebind_action(action_name: String, keycode: int) -> void:
	if action_name == "" or keycode == 0:
		return
	if not CONTROL_ACTIONS.has(action_name):
		return
	# Remove duplicate mappings from other actions for deterministic keyboard ownership.
	for other_action in CONTROL_ACTIONS:
		var removed: bool = false
		for event in InputMap.action_get_events(other_action):
			if not (event is InputEventKey):
				continue
			var key_event := event as InputEventKey
			var code: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
			if code != keycode:
				continue
			InputMap.action_erase_event(other_action, event)
			removed = true
		if removed and InputMap.action_get_events(other_action).is_empty():
			var defaults: Variant = DEFAULT_BINDINGS.get(other_action, [])
			if defaults is Array and not defaults.is_empty():
				InputMap.action_add_event(other_action, _make_key_event(int(defaults[0])))
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, _make_key_event(keycode))
	_sync_legacy_actions()
	_notify_binding_changed()

func get_binding_display(action_name: String) -> String:
	var names: PackedStringArray = []
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			var code: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
			if code != 0:
				names.append(OS.get_keycode_string(code))
	if names.is_empty():
		return "-"
	return "/".join(names)

func _apply_default_bindings() -> void:
	apply_bindings(DEFAULT_BINDINGS)

func _make_key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = 0
	return event

func _sync_legacy_actions() -> void:
	_copy_actions("move_up", ["p1_move_up", "p2_move_up"])
	_copy_actions("move_down", ["p1_move_down", "p2_move_down"])
	_copy_actions("move_left", ["p1_move_left", "p2_move_left"])
	_copy_actions("move_right", ["p1_move_right", "p2_move_right"])
	_copy_actions("jump", ["p1_jump", "p2_jump"])
	_copy_actions("attack", ["p1_attack", "p2_attack"])

func _copy_actions(target_action: String, source_actions: Array[String]) -> void:
	if not InputMap.has_action(target_action):
		InputMap.add_action(target_action)
	InputMap.action_erase_events(target_action)
	for source_action in source_actions:
		for event in InputMap.action_get_events(source_action):
			InputMap.action_add_event(target_action, event)

func _notify_binding_changed() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("update_control_bindings"):
		game_state.update_control_bindings(get_bindings())
