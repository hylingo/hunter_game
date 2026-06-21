class_name StateFlee
extends AnimalState

var _timer: float = 0.0
const FLEE_DURATION := 15.0

func enter(_animal) -> void:
	_timer = 0.0

func process(animal, delta: float) -> String:
	_timer += delta
	if _timer >= FLEE_DURATION:
		return "wander"
	var player := animal.get_tree().get_first_node_in_group("player")
	if player == null:
		return "wander"
	var away: Vector3 = animal.global_transform.origin - player.global_transform.origin
	away.y = 0
	away = away.normalized()
	var speed: float = Config.DEER_FLEE_SPEED
	animal.velocity.x = away.x * speed
	animal.velocity.z = away.z * speed
	animal.look_at(animal.global_transform.origin + away, Vector3.UP)
	return ""
