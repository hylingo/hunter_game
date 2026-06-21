extends GutTest

class FakeAnimal:
	var velocity: Vector3 = Vector3.ZERO
	var global_transform: Transform3D = Transform3D.IDENTITY
	var wander_speed: float = 2.0
	var threat: bool = false
	func sees_threat() -> bool: return threat
	func threat_response_state() -> String: return "flee"
	func look_at(_a: Vector3, _b: Vector3) -> void: pass

func test_idle_zeroes_velocity() -> void:
	var s := StateIdle.new()
	var a := FakeAnimal.new()
	a.velocity = Vector3(5, 0, 5)
	s.enter(a)
	s.process(a, 0.01)
	assert_eq(a.velocity.x, 0.0)
	assert_eq(a.velocity.z, 0.0)

func test_idle_transitions_to_wander_after_timeout() -> void:
	var s := StateIdle.new()
	var a := FakeAnimal.new()
	s.enter(a)
	# Force enough ticks to exceed even the longest possible random idle time (6s).
	var result := ""
	for i in 700:  # 7 seconds at 10ms per tick
		result = s.process(a, 0.01)
		if result != "":
			break
	assert_eq(result, "wander")

func test_idle_breaks_to_threat_response_when_threat_seen() -> void:
	var s := StateIdle.new()
	var a := FakeAnimal.new()
	a.threat = true
	s.enter(a)
	assert_eq(s.process(a, 0.01), "flee")

func test_wander_transitions_to_idle_on_arrival() -> void:
	var s := StateWander.new()
	var a := FakeAnimal.new()
	s.enter(a)
	# Force target to current position so we "arrive" instantly.
	s._target = a.global_transform.origin
	assert_eq(s.process(a, 0.01), "idle")
