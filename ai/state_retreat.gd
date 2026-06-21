class_name StateRetreat
extends AnimalState

var _timer: float = 0.0
const RETREAT_DURATION := 10.0

func process(animal, delta: float) -> String:
	_timer += delta
	if _timer >= RETREAT_DURATION:
		return "wander"
	var player := animal.get_tree().get_first_node_in_group("player")
	if player == null:
		return "wander"
	var away: Vector3 = animal.global_transform.origin - player.global_transform.origin
	away.y = 0
	away = away.normalized()
	animal.velocity.x = away.x * Config.WOLF_CHASE_SPEED
	animal.velocity.z = away.z * Config.WOLF_CHASE_SPEED
	animal.look_at(animal.global_transform.origin + away, Vector3.UP)
	return ""
