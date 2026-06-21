class_name StateChase
extends AnimalState

func process(animal, _delta: float) -> String:
	var player: Node = animal.get_tree().get_first_node_in_group("player")
	if player == null:
		return "wander"
	var to_player: Vector3 = player.global_transform.origin - animal.global_transform.origin
	to_player.y = 0
	var dist := to_player.length()
	if dist <= Config.WOLF_ATTACK_RANGE:
		return "attack"
	if dist > Config.WOLF_AGGRO_RANGE * 1.5:
		return "wander"  # lost interest
	if animal.hp < animal.max_hp * Config.WOLF_RETREAT_HP_FRACTION:
		return "retreat"
	var dir: Vector3 = to_player.normalized()
	animal.velocity.x = dir.x * Config.WOLF_CHASE_SPEED
	animal.velocity.z = dir.z * Config.WOLF_CHASE_SPEED
	animal.look_at(animal.global_transform.origin + dir, Vector3.UP)
	return ""
