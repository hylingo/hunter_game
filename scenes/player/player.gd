extends CharacterBody3D
class_name Player

## Third-person character controller. Owns movement, sneak state,
## bow charge/release, and arrow spawning.

const ArrowScene: PackedScene = preload("res://scenes/projectiles/arrow.tscn")

enum Stance { STANDING, SNEAKING, RUNNING }

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var anim_player: AnimationPlayer = _find_animation_player()

var stance: Stance = Stance.STANDING
var is_drawing_bow: bool = false
var bow_charge: float = 0.0  # 0.0..1.0

func _find_animation_player() -> AnimationPlayer:
	var model: Node = get_node_or_null("Model")
	if model == null:
		return null
	for child in model.get_children():
		if child is AnimationPlayer:
			return child
	for child in model.get_children():
		for grandchild in child.get_children():
			if grandchild is AnimationPlayer:
				return grandchild
	return null

func _play_anim(name: String) -> void:
	if anim_player == null:
		return
	if anim_player.current_animation == name:
		return
	if anim_player.has_animation(name):
		anim_player.play(name)

## Returns the noise radius the player is currently producing.
## Read by animal hearing checks.
func noise_radius() -> float:
	if velocity.length() < 0.1:
		return 0.0
	match stance:
		Stance.SNEAKING: return Config.NOISE_SNEAK
		Stance.RUNNING:  return Config.NOISE_RUN
		_:               return Config.NOISE_WALK

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		# Yaw rotates the whole player body so the model faces forward
		rotate_y(-motion.relative.x * 0.003)
		# Pitch only tilts the camera arm
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
	_update_anim()

func _update_anim() -> void:
	if anim_player == null:
		return
	var horizontal: float = Vector2(velocity.x, velocity.z).length()
	if horizontal < 0.1:
		_play_anim("Idle")
	elif stance == Stance.RUNNING:
		_play_anim("Run")
	else:
		_play_anim("Walk")  # walking or sneaking both use Walk anim

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= Config.PLAYER_GRAVITY * delta

func _handle_jump() -> void:
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = Config.PLAYER_JUMP_VELOCITY

func _update_stance() -> void:
	var prev := stance
	if Input.is_action_pressed("sneak"):
		stance = Stance.SNEAKING
	elif Input.is_action_pressed("run"):
		stance = Stance.RUNNING
	else:
		stance = Stance.STANDING
	if stance != prev:
		print("[stance] ", stance, " sneak=", Input.is_action_pressed("sneak"), " run=", Input.is_action_pressed("run"))

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
	var speed: float = Config.PLAYER_WALK_SPEED
	if stance == Stance.SNEAKING:
		speed = Config.PLAYER_SNEAK_SPEED
	elif stance == Stance.RUNNING:
		speed = Config.PLAYER_RUN_SPEED
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
	# Aim along the CAMERA's look direction so mouse pitch (up/down) actually aims the bow.
	var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
	var direction: Vector3 = -camera.global_transform.basis.z.normalized()
	# Spawn in front of the camera; arrow has gravity for a natural arc.
	var spawn_pos: Vector3 = camera.global_transform.origin + direction * 1.5
	arrow.global_transform.origin = spawn_pos
	arrow.look_at(spawn_pos + direction, Vector3.UP)
	var speed: float = lerp(Config.ARROW_SPEED_MIN, Config.ARROW_SPEED_MAX, charge)
	arrow.linear_velocity = direction * speed
	EventBus.player_shot_arrow.emit(spawn_pos, direction)
