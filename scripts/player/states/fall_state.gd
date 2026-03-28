class_name FallState
extends PlayerState

## Airborne descent state after upward velocity is spent.

func physics_update(player: Node, delta: float) -> void:
	player._process_jump()
	if player.is_homing:
		return
	player._process_movement(delta)
	player._process_gravity(delta)
