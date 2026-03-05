extends Node

var player_count: int = 2
var last_scene_path: String = "res://scenes/level/test_level.tscn"

func start_game(count: int) -> void:
	player_count = clamp(count, 1, 2)
	last_scene_path = "res://scenes/level/test_level.tscn"
	get_tree().change_scene_to_file(last_scene_path)

func restart_game() -> void:
	if last_scene_path == "":
		last_scene_path = "res://scenes/level/test_level.tscn"
	get_tree().change_scene_to_file(last_scene_path)

func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
