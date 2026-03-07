class_name GroundedState
extends PlayerState

## Standard grounded locomotion state.

func physics_update(player: Node, delta: float) -> void:
	player._process_jump()
	if player.is_homing:
		return
	player._process_movement(delta)
	player._process_gravity(delta)
