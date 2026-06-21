extends CharacterBody3D
class_name Player

## Third-person character controller. Owns movement, sneak state, and
## (later) bow charge/release.

enum Stance { STANDING, SNEAKING }

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D

var stance: Stance = Stance.STANDING

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

func _physics_process(delta: float) -> void:
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
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
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
