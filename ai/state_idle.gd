class_name StateIdle
extends AnimalState

var _timer: float = 0.0
var _idle_duration: float = 0.0

func enter(_animal) -> void:
	_timer = 0.0
	_idle_duration = randf_range(3.0, 6.0)

func process(animal, delta: float) -> String:
	_timer += delta
	animal.velocity.x = 0
	animal.velocity.z = 0
	if _timer >= _idle_duration:
		return "wander"
	if animal.has_method("sees_threat") and animal.sees_threat():
		return animal.threat_response_state()
	return ""
