extends Node
## Tuning constants. Never mutate at runtime.

# Player movement
const PLAYER_WALK_SPEED := 4.0
const PLAYER_SNEAK_SPEED := 1.5
const PLAYER_RUN_SPEED := 8.0
const PLAYER_JUMP_VELOCITY := 5.0
const PLAYER_GRAVITY := 20.0

# Noise radii (meters) — used by animal hearing checks
const NOISE_WALK := 6.0
const NOISE_SNEAK := 1.0
const NOISE_RUN := 12.0

# Bow
const ARROW_DAMAGE := 50.0
const ARROW_SPEED_MIN := 25.0
const ARROW_SPEED_MAX := 45.0
const BOW_CHARGE_TIME := 1.0  # seconds to reach full charge

# Deer perception
const DEER_VIEW_RANGE := 15.0
const DEER_VIEW_CONE_DEG := 90.0
const DEER_HEARING_RANGE := 8.0
const DEER_HP := 40.0
const DEER_FLEE_SPEED := 8.0
const DEER_WANDER_SPEED := 1.5

# Wolf
const WOLF_AGGRO_RANGE := 12.0
const WOLF_ATTACK_RANGE := 2.0
const WOLF_HP := 60.0
const WOLF_CHASE_SPEED := 6.0
const WOLF_WANDER_SPEED := 2.0
const WOLF_ATTACK_DAMAGE := 20.0
const WOLF_RETREAT_HP_FRACTION := 0.3
