class_name Hitbox
extends Node2D

# Visual/logic radius for attacks
@export var radius: float = 8.0

func _ready() -> void:
	# Allow quick lookup of active attack areas
	add_to_group("hitboxes")
