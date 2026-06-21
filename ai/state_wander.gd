class_name StateWander
extends AnimalState

var _target: Vector3
var _timer: float = 0.0

func enter(animal) -> void:
	_timer = 0.0
	_pick_new_target(animal)

func _pick_new_target(animal) -> void:
	var offset := Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
	_target = animal.global_transform.origin + offset

func process(animal, delta: float) -> String:
	_timer += delta
	var to_target: Vector3 = _target - animal.global_transform.origin
	to_target.y = 0
	if to_target.length() < 0.5 or _timer > 10.0:
		return "idle"
	var direction: Vector3 = to_target.normalized()
	var speed: float = animal.wander_speed
	animal.velocity.x = direction.x * speed
	animal.velocity.z = direction.z * speed
	animal.look_at(animal.global_transform.origin + direction, Vector3.UP)
	if animal.has_method("sees_threat") and animal.sees_threat():
		return animal.threat_response_state()
	return ""
