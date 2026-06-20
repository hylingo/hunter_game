extends GutTest
## GameState is an autoload, accessible as the global identifier `GameState`.

func before_each() -> void:
	GameState.reset()

func test_initial_hp_is_max() -> void:
	assert_eq(GameState.hp, GameState.HP_MAX)

func test_hp_setter_clamps_to_max() -> void:
	GameState.hp = 9999.0
	assert_eq(GameState.hp, GameState.HP_MAX)

func test_hp_setter_clamps_to_zero() -> void:
	GameState.hp = -50.0
	assert_eq(GameState.hp, 0.0)

func test_arrows_setter_clamps_to_max() -> void:
	GameState.arrows = 500
	assert_eq(GameState.arrows, GameState.ARROWS_MAX)

func test_hp_changed_signal_emits() -> void:
	watch_signals(GameState)
	GameState.hp = 50.0
	assert_signal_emitted_with_parameters(GameState, "hp_changed", [50.0])

func test_reset_restores_defaults() -> void:
	GameState.hp = 10.0
	GameState.arrows = 0
	GameState.reset()
	assert_eq(GameState.hp, GameState.HP_MAX)
	assert_eq(GameState.arrows, 10)
