extends CharacterBody3D
class_name Player

## Third-person character controller. Owns movement, sneak state,
## bow charge/release, and arrow spawning.

const ArrowScene: PackedScene = preload("res://scenes/projectiles/arrow.tscn")

enum Stance { STANDING, SNEAKING }

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D

var stance: Stance = Stance.STANDING
var is_drawing_bow: bool = false
var bow_charge: float = 0.0  # 0.0..1.0

## Returns the noise radius the player is currently producing.
## Read by animal hearing checks.
func noise_radius() -> float:
	if velocity.length() < 0.1:
		return 0.0
	match stance:
		Stance.SNEAKING: return Config.NOISE_SNEAK
		_:               return Config.NOISE_WALK

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		camera_pivot.rotate_y(-motion.relative.x * 0.003)
		spring_arm.rotate_x(-motion.relative.y * 0.003)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -1.2, 0.5)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("fire"):
		is_drawing_bow = true
	elif event.is_action_released("fire"):
		var charge := release_bow()
		_fire_arrow(charge)

func _physics_process(delta: float) -> void:
	tick_bow(delta)
	_apply_gravity(delta)
	_handle_jump()
	_update_stance()
	_apply_horizontal_movement(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= Config.PLAYER_GRAVITY * delta

func _handle_jump() -> void:
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = Config.PLAYER_JUMP_VELOCITY

func _update_stance() -> void:
	stance = Stance.SNEAKING if Input.is_action_pressed("sneak") else Stance.STANDING

func _apply_horizontal_movement(_delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)
	var forward := -camera_pivot.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := camera_pivot.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var move_dir := (right * input.x + forward * input.y).normalized() if input.length() > 0 else Vector3.ZERO
	var speed := Config.PLAYER_SNEAK_SPEED if stance == Stance.SNEAKING else Config.PLAYER_WALK_SPEED
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

## Advance bow charge for one tick. Pure logic, no node calls — testable.
func tick_bow(delta: float) -> void:
	if is_drawing_bow:
		bow_charge = clamp(bow_charge + delta / Config.BOW_CHARGE_TIME, 0.0, 1.0)

## Release the bow. Returns the charge level [0..1] and resets state.
func release_bow() -> float:
	var charge := bow_charge
	bow_charge = 0.0
	is_drawing_bow = false
	return charge

func take_damage(amount: float) -> void:
	GameState.hp -= amount
	EventBus.player_hit_by.emit(amount, self)
	if GameState.hp <= 0:
		_die()

func _die() -> void:
	# Milestone 1: reload scene on death.
	GameState.reset()
	get_tree().reload_current_scene()

func _fire_arrow(charge: float) -> void:
	if GameState.arrows <= 0:
		return
	GameState.arrows -= 1
	var arrow: Arrow = ArrowScene.instantiate()
	get_tree().current_scene.add_child(arrow)
	# Fire along the camera pivot's -Z (horizontal forward, matches the green indicator),
	# NOT the camera's own -Z (which tilts up/down with mouse pitch).
	var direction: Vector3 = -camera_pivot.global_transform.basis.z.normalized()
	# Spawn slightly below eye height so arrows hit chest-level targets, not over their heads
	var spawn_pos: Vector3 = camera_pivot.global_transform.origin + direction * 1.0 + Vector3(0, -0.6, 0)
	arrow.global_transform.origin = spawn_pos
	arrow.look_at(spawn_pos + direction, Vector3.UP)
	var speed: float = lerp(Config.ARROW_SPEED_MIN, Config.ARROW_SPEED_MAX, charge)
	arrow.linear_velocity = direction * speed
	EventBus.player_shot_arrow.emit(spawn_pos, direction)
