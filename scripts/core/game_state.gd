extends Node

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

# Signals for HUD updates
signal lives_changed(new_lives: int)
signal coins_changed(new_coins: int)
signal score_changed(new_score: int)
signal keys_changed(new_keys: int)

func start_game(count: int) -> void:
	player_count = clamp(count, 1, 2)
	_reset_progression()
	load_level(1, 1)

func load_level(world: int, level: int) -> void:
	current_world = world
	current_level = level
	last_scene_path = "res://scenes/level/level.tscn"
	get_tree().change_scene_to_file(last_scene_path)

func load_test_level() -> void:
	last_scene_path = "res://scenes/level/test_level.tscn"
	get_tree().change_scene_to_file(last_scene_path)

func restart_game() -> void:
	if last_scene_path == "":
		last_scene_path = "res://scenes/level/level.tscn"
	get_tree().change_scene_to_file(last_scene_path)

func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)
	# Extra life every 100 coins
	while coins >= 100:
		coins -= 100
		add_lives(1)
		coins_changed.emit(coins)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func add_keys(amount: int) -> void:
	keys += amount
	keys_changed.emit(keys)

func use_key() -> bool:
	if keys > 0:
		keys -= 1
		keys_changed.emit(keys)
		return true
	return false

func add_lives(amount: int) -> void:
	lives += amount
	lives_changed.emit(lives)

func lose_life() -> bool:
	lives -= 1
	lives_changed.emit(lives)
	return lives >= 0

func _reset_progression() -> void:
	lives = 5
	coins = 0
	score = 0
	keys = 0
