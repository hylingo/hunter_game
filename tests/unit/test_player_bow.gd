extends GutTest

const PlayerScript := preload("res://scenes/player/player.gd")

func test_charge_starts_zero() -> void:
	var p: CharacterBody3D = PlayerScript.new()
	assert_eq(p.bow_charge, 0.0)
	p.free()

func test_charge_increases_while_drawing() -> void:
	var p: CharacterBody3D = PlayerScript.new()
	p.is_drawing_bow = true
	p.tick_bow(0.5)
	assert_almost_eq(p.bow_charge, 0.5, 0.001)
	p.free()

func test_charge_clamped_at_one() -> void:
	var p: CharacterBody3D = PlayerScript.new()
	p.is_drawing_bow = true
	p.tick_bow(5.0)
	assert_eq(p.bow_charge, 1.0)
	p.free()

func test_release_returns_charge_and_resets() -> void:
	var p: CharacterBody3D = PlayerScript.new()
	p.is_drawing_bow = true
	p.tick_bow(0.5)
	var released: float = p.release_bow()
	assert_almost_eq(released, 0.5, 0.001)
	assert_eq(p.bow_charge, 0.0)
	assert_false(p.is_drawing_bow)
	p.free()
