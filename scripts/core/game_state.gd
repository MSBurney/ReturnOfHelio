extends Node

const SAVE_PATH := "user://savegame.json"
const SAVE_TMP_PATH := "user://savegame.tmp.json"
const SAVE_VERSION := 3
const LEVEL_SCENE_PATH := "res://scenes/level/level.tscn"
const TITLE_SCENE_PATH := "res://scenes/ui/title_screen.tscn"
const WORLD_MAP_SCENE_PATH := "res://scenes/ui/world_map.tscn"
const LEVEL_SELECT_SCENE_PATH := "res://scenes/ui/level_select.tscn"

const DEFAULT_SETTINGS := {
	"audio": {
		"master_db": 0.0,
		"music_db": 0.0,
		"sfx_db": 0.0,
	},
	"accessibility": {
		"screen_shake_enabled": true,
		"hit_stop_enabled": true,
		"reduced_flashes": false,
		"high_contrast_hud": false,
	},
	"controls": {},
}

var player_count: int = 2
var last_scene_path: String = "res://scenes/level/test_level.tscn"

# Level tracking
var current_world: int = 1
var current_level: int = 1

# Progression
var lives: int = 5
var coins: int = 0
var score: int = 0
var keys: int = 0
var unlocks: Dictionary = {"world_1_max_level": 1}
var level_runtime_state: Dictionary = {}  # "level_id" -> Dictionary payload
var continue_level_override: int = 0
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var level_stats: Dictionary = {}  # "level_id" -> {"cleared", "best_score", "best_time", "deaths"}

# Signals for HUD updates
signal lives_changed(new_lives: int)
signal coins_changed(new_coins: int)
signal score_changed(new_score: int)
signal keys_changed(new_keys: int)
signal camera_shake_requested(intensity: float, duration: float)
signal settings_changed(payload: Dictionary)
signal chain_changed(count: int, timer: float)

var _hit_stop_active: bool = false
var _hit_stop_end_time_ms: int = 0
var score_chain_count: int = 0
var score_chain_timer: float = 0.0
var score_chain_window: float = 2.0

func _ready() -> void:
	set_process(true)
	if has_save_data():
		load_progress()
	_apply_runtime_settings.call_deferred()

func _process(_delta: float) -> void:
	if _hit_stop_active and Time.get_ticks_msec() >= _hit_stop_end_time_ms:
		_hit_stop_active = false
		Engine.time_scale = 1.0
	if score_chain_timer > 0.0:
		score_chain_timer = maxf(score_chain_timer - _delta, 0.0)
		if score_chain_timer == 0.0 and score_chain_count != 0:
			score_chain_count = 0
			chain_changed.emit(score_chain_count, score_chain_timer)

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func start_game(count: int) -> void:
	player_count = clamp(count, 1, 2)
	_reset_progression()
	_unlock_level(1, 1)
	save_progress()
	go_to_world_map()

func continue_game() -> void:
	if not load_progress():
		start_game(1)
		return
	go_to_world_map()

func load_continue_target() -> void:
	if continue_level_override > 0:
		var target_level: int = continue_level_override
		continue_level_override = 0
		load_level(current_world, target_level)
		return
	if current_level == 0:
		load_boss_level(current_world)
		return
	load_level(current_world, current_level)

func load_level(world: int, level: int) -> void:
	var unlocked_level: int = int(unlocks.get(_world_unlock_key(world), 1))
	if level > unlocked_level:
		level = unlocked_level
	current_world = world
	current_level = level
	continue_level_override = 0
	last_scene_path = LEVEL_SCENE_PATH
	_change_scene(last_scene_path)
	save_progress()

func load_boss_level(world: int) -> void:
	current_world = world
	current_level = 0  # 0 indicates boss level
	continue_level_override = 0
	last_scene_path = LEVEL_SCENE_PATH
	_change_scene(last_scene_path)
	save_progress()

func load_test_level() -> void:
	last_scene_path = "res://scenes/level/test_level.tscn"
	_change_scene(last_scene_path)

func restart_game() -> void:
	if last_scene_path == "":
		last_scene_path = LEVEL_SCENE_PATH
	_change_scene(last_scene_path)

func go_to_main_menu() -> void:
	save_progress()
	_change_scene(TITLE_SCENE_PATH)

func go_to_world_map() -> void:
	save_progress()
	_change_scene(WORLD_MAP_SCENE_PATH)

func go_to_level_select() -> void:
	save_progress()
	_change_scene(LEVEL_SELECT_SCENE_PATH)

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)
	# Extra life every 100 coins
	while coins >= 100:
		coins -= 100
		add_lives(1)
		coins_changed.emit(coins)
	save_progress()

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)
	save_progress()

func add_score_with_chain(base_amount: int) -> int:
	if base_amount <= 0:
		return 0
	if score_chain_timer > 0.0:
		score_chain_count += 1
	else:
		score_chain_count = 1
	score_chain_timer = score_chain_window
	var multiplier: float = 1.0 + float(score_chain_count - 1) * 0.2
	var total_award: int = maxi(int(round(float(base_amount) * multiplier)), base_amount)
	add_score(total_award)
	chain_changed.emit(score_chain_count, score_chain_timer)
	return total_award

func add_keys(amount: int) -> void:
	keys += amount
	keys_changed.emit(keys)
	save_progress()

func use_key() -> bool:
	if keys > 0:
		keys -= 1
		keys_changed.emit(keys)
		save_progress()
		return true
	return false

func add_lives(amount: int) -> void:
	lives += amount
	lives_changed.emit(lives)
	save_progress()

func lose_life() -> bool:
	lives -= 1
	lives_changed.emit(lives)
	save_progress()
	return lives >= 0

func complete_current_level() -> void:
	if current_level <= 0:
		save_progress()
		return
	var next_level := mini(current_level + 1, 13)
	_unlock_level(current_world, next_level)
	continue_level_override = next_level
	save_progress()

func get_continue_level() -> int:
	if continue_level_override > 0:
		return continue_level_override
	if current_level <= 0:
		return 13
	return maxi(current_level, 1)

func get_unlocked_level(world: int) -> int:
	return maxi(int(unlocks.get(_world_unlock_key(world), 1)), 1)

func request_camera_shake(intensity: float, duration: float) -> void:
	if not is_screen_shake_enabled():
		return
	camera_shake_requested.emit(intensity, duration)

func request_hit_stop(duration: float = 0.04, time_scale: float = 0.12) -> void:
	if not is_hit_stop_enabled():
		return
	if duration <= 0.0:
		return
	var now_ms: int = Time.get_ticks_msec()
	var end_ms: int = now_ms + int(duration * 1000.0)
	if not _hit_stop_active:
		Engine.time_scale = clampf(time_scale, 0.01, 1.0)
		_hit_stop_active = true
		_hit_stop_end_time_ms = end_ms
		return
	_hit_stop_end_time_ms = maxi(_hit_stop_end_time_ms, end_ms)
	Engine.time_scale = minf(Engine.time_scale, clampf(time_scale, 0.01, 1.0))

func has_save_data() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_progress() -> bool:
	var file := FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_build_save_data(), "\t"))
	file.close()
	var save_abs := ProjectSettings.globalize_path(SAVE_PATH)
	var temp_abs := ProjectSettings.globalize_path(SAVE_TMP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(save_abs)
	var move_err: int = DirAccess.rename_absolute(temp_abs, save_abs)
	if move_err == OK:
		return true
	# Fallback: direct write if rename is unavailable on platform.
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_build_save_data(), "\t"))
	file.close()
	return true

func load_progress() -> bool:
	if not has_save_data():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var raw_text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var err: int = parser.parse(raw_text)
	if err != OK:
		return false
	var payload: Dictionary = parser.data if parser.data is Dictionary else {}
	if payload.is_empty():
		return false
	_apply_save_data(payload)
	return true

func clear_save_data() -> void:
	if has_save_data():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if FileAccess.file_exists(SAVE_TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TMP_PATH))

func get_setting(section: String, key: String, fallback: Variant = null) -> Variant:
	var section_data: Variant = settings.get(section, {})
	if section_data is Dictionary:
		return section_data.get(key, fallback)
	return fallback

func set_setting(section: String, key: String, value: Variant, persist: bool = true) -> void:
	var section_data: Variant = settings.get(section, {})
	if not (section_data is Dictionary):
		section_data = {}
	var dict_section: Dictionary = section_data
	dict_section[key] = value
	settings[section] = dict_section
	_apply_runtime_settings()
	settings_changed.emit(settings.duplicate(true))
	if persist:
		save_progress()

func is_screen_shake_enabled() -> bool:
	return bool(get_setting("accessibility", "screen_shake_enabled", true))

func is_hit_stop_enabled() -> bool:
	return bool(get_setting("accessibility", "hit_stop_enabled", true))

func is_reduced_flashes_enabled() -> bool:
	return bool(get_setting("accessibility", "reduced_flashes", false))

func is_high_contrast_hud_enabled() -> bool:
	return bool(get_setting("accessibility", "high_contrast_hud", false))

func update_control_bindings(bindings: Dictionary) -> void:
	set_setting("controls", "bindings", bindings.duplicate(true), false)
	save_progress()

func get_control_bindings() -> Dictionary:
	var controls: Variant = settings.get("controls", {})
	if controls is Dictionary:
		var bindings: Variant = controls.get("bindings", {})
		if bindings is Dictionary:
			return bindings.duplicate(true)
	return {}

func record_level_clear(level_id: String, clear_time: float, deaths: int) -> void:
	if level_id == "":
		return
	var current_entry: Variant = level_stats.get(level_id, {})
	var entry: Dictionary = current_entry.duplicate(true) if current_entry is Dictionary else {}
	entry["cleared"] = true
	var best_score: int = int(entry.get("best_score", 0))
	entry["best_score"] = maxi(best_score, score)
	var best_time: float = float(entry.get("best_time", 0.0))
	if best_time <= 0.0:
		entry["best_time"] = clear_time
	else:
		entry["best_time"] = minf(best_time, clear_time)
	entry["deaths"] = mini(int(entry.get("deaths", deaths)), deaths) if entry.has("deaths") else deaths
	level_stats[level_id] = entry
	save_progress()

func record_level_death(level_id: String) -> void:
	if level_id == "":
		return
	var current_entry: Variant = level_stats.get(level_id, {})
	var entry: Dictionary = current_entry.duplicate(true) if current_entry is Dictionary else {}
	var deaths: int = int(entry.get("deaths", 0))
	entry["deaths"] = deaths + 1
	level_stats[level_id] = entry
	save_progress()

func _reset_progression() -> void:
	current_world = 1
	current_level = 1
	lives = 5
	coins = 0
	score = 0
	keys = 0
	unlocks = {"world_1_max_level": 1}
	level_runtime_state.clear()
	level_stats.clear()
	continue_level_override = 0
	score_chain_count = 0
	score_chain_timer = 0.0
	lives_changed.emit(lives)
	coins_changed.emit(coins)
	score_changed.emit(score)
	keys_changed.emit(keys)

func set_level_runtime_state(level_id: String, state: Dictionary) -> void:
	if level_id == "":
		return
	level_runtime_state[level_id] = state.duplicate(true)
	save_progress()

func get_level_runtime_state(level_id: String) -> Dictionary:
	if level_id == "":
		return {}
	var payload: Variant = level_runtime_state.get(level_id, {})
	if payload is Dictionary:
		return payload.duplicate(true)
	return {}

func clear_level_runtime_state(level_id: String = "") -> void:
	if level_id == "":
		level_runtime_state.clear()
	else:
		level_runtime_state.erase(level_id)
	save_progress()

func _world_unlock_key(world: int) -> String:
	return "world_%d_max_level" % world

func _unlock_level(world: int, level: int) -> void:
	var key := _world_unlock_key(world)
	var current_unlocked: int = int(unlocks.get(key, 1))
	if level > current_unlocked:
		unlocks[key] = level

func _build_save_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"world": current_world,
		"level": current_level,
		"lives": lives,
		"score": score,
		"keys": keys,
		"coins": coins,
		"player_count": player_count,
		"unlocks": unlocks.duplicate(true),
		"runtime": level_runtime_state.duplicate(true),
		"continue_level_override": continue_level_override,
		"settings": settings.duplicate(true),
		"level_stats": level_stats.duplicate(true),
	}

func _apply_save_data(data: Dictionary) -> void:
	var save_version: int = int(data.get("save_version", 1))
	current_world = int(data.get("world", 1))
	current_level = int(data.get("level", 1))
	lives = int(data.get("lives", 5))
	score = int(data.get("score", 0))
	keys = int(data.get("keys", 0))
	coins = int(data.get("coins", 0))
	player_count = clampi(int(data.get("player_count", 1)), 1, 2)
	var loaded_unlocks: Variant = data.get("unlocks", {"world_1_max_level": 1})
	if loaded_unlocks is Dictionary:
		unlocks = loaded_unlocks.duplicate(true)
	else:
		unlocks = {"world_1_max_level": 1}
	if save_version >= 2:
		var runtime_state: Variant = data.get("runtime", {})
		if runtime_state is Dictionary:
			level_runtime_state = runtime_state.duplicate(true)
		else:
			level_runtime_state = {}
		continue_level_override = int(data.get("continue_level_override", 0))
	else:
		level_runtime_state = {}
		continue_level_override = 0
	if save_version >= 3:
		var loaded_settings: Variant = data.get("settings", DEFAULT_SETTINGS)
		if loaded_settings is Dictionary:
			settings = _merge_settings(DEFAULT_SETTINGS, loaded_settings)
		else:
			settings = DEFAULT_SETTINGS.duplicate(true)
		var loaded_level_stats: Variant = data.get("level_stats", {})
		if loaded_level_stats is Dictionary:
			level_stats = loaded_level_stats.duplicate(true)
		else:
			level_stats = {}
	else:
		settings = DEFAULT_SETTINGS.duplicate(true)
		level_stats = {}
	lives_changed.emit(lives)
	coins_changed.emit(coins)
	score_changed.emit(score)
	keys_changed.emit(keys)
	_apply_runtime_settings()

func _merge_settings(base: Dictionary, incoming: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	for key in incoming.keys():
		var incoming_value: Variant = incoming[key]
		if merged.has(key) and merged[key] is Dictionary and incoming_value is Dictionary:
			merged[key] = _merge_settings(merged[key], incoming_value)
		else:
			merged[key] = incoming_value
	return merged

func _apply_runtime_settings() -> void:
	var controls := get_control_bindings()
	var input_manager := get_node_or_null("/root/InputManager")
	if input_manager and input_manager.has_method("apply_bindings"):
		if controls.is_empty():
			input_manager.apply_bindings({})
		else:
			input_manager.apply_bindings(controls)
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("set_bus_volume"):
		audio.set_bus_volume("Master", float(get_setting("audio", "master_db", 0.0)))
		audio.set_bus_volume("Music", float(get_setting("audio", "music_db", 0.0)))
		audio.set_bus_volume("SFX", float(get_setting("audio", "sfx_db", 0.0)))

func _change_scene(path: String) -> void:
	var transition := get_node_or_null("/root/TransitionManager")
	if transition and transition.has_method("transition_to_scene"):
		transition.transition_to_scene(path)
		return
	get_tree().change_scene_to_file(path)
