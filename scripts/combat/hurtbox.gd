class_name Hurtbox
extends Node2D

# Visual/logic radius for targeting
@export var radius: float = 8.0
@export var z_offset: float = 0.0

func _ready() -> void:
	# Allow quick lookup of targetable entities
	add_to_group("hurtboxes")

func get_owner_body() -> Node:
	# Parent is expected to be the entity with combat methods
	return get_parent()

func get_world_pos() -> Vector3:
	# Proxy world position to the owner if possible
	var owner_body := get_owner_body()
	if owner_body and owner_body.has_method("get_world_pos"):
		var pos: Vector3 = owner_body.get_world_pos()
		pos.z += z_offset
		return pos
	return IsoUtils.screen_to_world(global_position)
