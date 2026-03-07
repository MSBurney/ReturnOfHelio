class_name PlayerState
extends RefCounted

## Base player state interface.

func enter(_player: Node) -> void:
	pass

func physics_update(_player: Node, _delta: float) -> void:
	pass

func exit(_player: Node) -> void:
	pass
