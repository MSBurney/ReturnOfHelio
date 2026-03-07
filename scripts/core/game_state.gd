extends Node

const SAVE_PATH := "user://savegame.json"

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

# Signals for HUD updates
signal lives_changed(new_lives: int)
signal coins_changed(new_coins: int)
signal score_changed(new_score: int)
signal keys_changed(new_keys: int)
signal camera_shake_requested(intensity: float, duration: float)

var _hit_stop_active: bool = false
var _hit_stop_end_time_ms: int = 0

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	if _hit_stop_active and Time.get_ticks_msec() >= _hit_stop_end_time_ms:
		_hit_stop_active = false
		Engine.time_scale = 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func start_game(count: int) -> void:
	player_count = clamp(count, 1, 2)
	_reset_progression()
	_unlock_level(1, 1)
	save_progress()
	load_level(1, 1)

func continue_game() -> void:
	if not load_progress():
		start_game(1)
		return
	if current_level == 0:
		load_boss_level(current_world)
	else:
		load_level(current_world, current_level)

func load_level(world: int, level: int) -> void:
	var unlocked_level: int = int(unlocks.get(_world_unlock_key(world), 1))
	if level > unlocked_level:
		level = unlocked_level
	current_world = world
	current_level = level
	last_scene_path = "res://scenes/level/level.tscn"
	get_tree().change_scene_to_file(last_scene_path)
	save_progress()

func load_boss_level(world: int) -> void:
	current_world = world
	current_level = 0  # 0 indicates boss level
	last_scene_path = "res://scenes/level/level.tscn"
	get_tree().change_scene_to_file(last_scene_path)
	save_progress()

func load_test_level() -> void:
	last_scene_path = "res://scenes/level/test_level.tscn"
	get_tree().change_scene_to_file(last_scene_path)

func restart_game() -> void:
	if last_scene_path == "":
		last_scene_path = "res://scenes/level/level.tscn"
	get_tree().change_scene_to_file(last_scene_path)

func go_to_main_menu() -> void:
	save_progress()
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

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
	save_progress()

func request_camera_shake(intensity: float, duration: float) -> void:
	camera_shake_requested.emit(intensity, duration)

func request_hit_stop(duration: float = 0.04, time_scale: float = 0.12) -> void:
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
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
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
	if not has_save_data():
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _reset_progression() -> void:
	current_world = 1
	current_level = 1
	lives = 5
	coins = 0
	score = 0
	keys = 0
	unlocks = {"world_1_max_level": 1}
	lives_changed.emit(lives)
	coins_changed.emit(coins)
	score_changed.emit(score)
	keys_changed.emit(keys)

func _world_unlock_key(world: int) -> String:
	return "world_%d_max_level" % world

func _unlock_level(world: int, level: int) -> void:
	var key := _world_unlock_key(world)
	var current_unlocked: int = int(unlocks.get(key, 1))
	if level > current_unlocked:
		unlocks[key] = level

func _build_save_data() -> Dictionary:
	return {
		"save_version": 1,
		"world": current_world,
		"level": current_level,
		"lives": lives,
		"score": score,
		"keys": keys,
		"coins": coins,
		"player_count": player_count,
		"unlocks": unlocks.duplicate(true),
	}

func _apply_save_data(data: Dictionary) -> void:
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
	lives_changed.emit(lives)
	coins_changed.emit(coins)
	score_changed.emit(score)
	keys_changed.emit(keys)
