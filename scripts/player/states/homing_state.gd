class_name HomingState
extends PlayerState

## Dedicated homing movement state.

func physics_update(player: Node, delta: float) -> void:
	player._process_homing_attack(delta)
