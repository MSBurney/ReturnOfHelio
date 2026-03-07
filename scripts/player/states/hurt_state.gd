class_name HurtState
extends PlayerState

## Brief knockback/recovery state after damage.

func physics_update(player: Node, delta: float) -> void:
	if player.is_homing:
		player._process_homing_attack(delta)
		return
	player._process_movement(delta)
	player._process_gravity(delta)
