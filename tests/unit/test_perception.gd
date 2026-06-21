extends GutTest

const Perception := preload("res://scenes/animals/deer.gd")

func test_player_inside_view_cone_is_seen() -> void:
	var deer_pos := Vector3.ZERO
	var deer_forward := Vector3.FORWARD
	var player_pos := Vector3(0, 0, -5)
	assert_true(Perception.in_view_cone(deer_pos, deer_forward, player_pos,
		Config.DEER_VIEW_RANGE, Config.DEER_VIEW_CONE_DEG))

func test_player_outside_range_not_seen() -> void:
	var deer_pos := Vector3.ZERO
	var deer_forward := Vector3.FORWARD
	var player_pos := Vector3(0, 0, -50)
	assert_false(Perception.in_view_cone(deer_pos, deer_forward, player_pos,
		Config.DEER_VIEW_RANGE, Config.DEER_VIEW_CONE_DEG))

func test_player_behind_not_seen() -> void:
	var deer_pos := Vector3.ZERO
	var deer_forward := Vector3.FORWARD
	var player_pos := Vector3(0, 0, 5)
	assert_false(Perception.in_view_cone(deer_pos, deer_forward, player_pos,
		Config.DEER_VIEW_RANGE, Config.DEER_VIEW_CONE_DEG))

func test_player_within_hearing_with_loud_noise_heard() -> void:
	var deer_pos := Vector3.ZERO
	var player_pos := Vector3(5, 0, 0)
	var player_noise: float = Config.NOISE_WALK
	assert_true(Perception.heard(deer_pos, player_pos, player_noise,
		Config.DEER_HEARING_RANGE))

func test_sneaking_player_at_3m_not_heard() -> void:
	var deer_pos := Vector3.ZERO
	var player_pos := Vector3(3, 0, 0)
	var player_noise: float = Config.NOISE_SNEAK
	assert_false(Perception.heard(deer_pos, player_pos, player_noise,
		Config.DEER_HEARING_RANGE))
