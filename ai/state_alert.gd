class_name StateAlert
extends AnimalState

var _timer: float = 0.0
const ALERT_HOLD := 2.0

func enter(_animal) -> void:
	_timer = 0.0

func process(animal, delta: float) -> String:
	_timer += delta
	animal.velocity.x = 0
	animal.velocity.z = 0
	if _timer >= ALERT_HOLD:
		if animal.sees_threat():
			return "flee"
		return "idle"
	return ""
