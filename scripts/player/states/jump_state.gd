class_name JumpState
extends PlayerState

## Airborne ascent state after jump launch.

func physics_update(player: Node, delta: float) -> void:
	player._process_jump()
	if player.is_homing:
		return
	player._process_movement(delta)
	player._process_gravity(delta)
