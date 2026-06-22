extends CharacterBody3D
class_name Player

## Third-person character controller. Owns movement, sneak state,
## bow charge/release, and arrow spawning.

const ArrowScene: PackedScene = preload("res://scenes/projectiles/arrow.tscn")

enum Stance { STANDING, SNEAKING, RUNNING }

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var anim_player: AnimationPlayer = _find_animation_player()
@onready var model: Node3D = $Model

const SNEAK_CROUCH_SCALE := 0.6  # vertical squash when sneaking

# Camera: scroll wheel adjusts distance; bow draw pulls in closer still.
const CAMERA_DIST_MIN := 1.5    # closest the wheel can zoom in
const CAMERA_DIST_MAX := 10.0   # farthest the wheel can zoom out
const CAMERA_DIST_DEFAULT := 4.0
const CAMERA_AIM_PULL_IN := 2.0  # how much closer the camera gets while aiming
const CAMERA_ZOOM_STEP := 0.5    # distance change per wheel notch
const CAMERA_ZOOM_SPEED := 10.0  # smoothing speed toward the target distance

# How fast the camera eases back behind the character after free-look (left mouse) ends.
const CAMERA_RECENTER_SPEED := 6.0

# Wheel-controlled base distance; aiming subtracts CAMERA_AIM_PULL_IN from it.
var camera_distance: float = CAMERA_DIST_DEFAULT
var _orbiting: bool = false  # true while the camera has been freely orbited off-center

var stance: Stance = Stance.STANDING
var is_drawing_bow: bool = false
var bow_charge: float = 0.0  # 0.0..1.0
var _shoot_anim_timer: float = 0.0  # counts down while the one-shot shoot anim plays

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

# Mouse-look lives in _input (not _unhandled_input) so the camera always turns,
# even while another button (e.g. right-click to draw the bow) is held.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var yaw := -motion.relative.x * 0.003
		if Input.is_action_pressed("look_front"):
			# Hold left mouse: orbit the camera around the character (body stays put)
			# so you can look from any angle, including the front.
			camera_pivot.rotate_y(yaw)
			_orbiting = true
		else:
			# Default: yaw turns the whole body, camera follows behind.
			rotate_y(yaw)
		# Pitch only tilts the camera arm.
		spring_arm.rotate_x(-motion.relative.y * 0.003)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -1.2, 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var btn := event as InputEventMouseButton
		if btn.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = clamp(camera_distance - CAMERA_ZOOM_STEP, CAMERA_DIST_MIN, CAMERA_DIST_MAX)
		elif btn.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = clamp(camera_distance + CAMERA_ZOOM_STEP, CAMERA_DIST_MIN, CAMERA_DIST_MAX)
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
	_update_anim(delta)
	_update_crouch(delta)
	_update_camera_zoom(delta)
	_update_camera_recenter(delta)

## Smoothly move the camera toward the wheel-set distance, pulling in while aiming.
func _update_camera_zoom(delta: float) -> void:
	var target: float = camera_distance
	if is_drawing_bow:
		target = maxf(CAMERA_DIST_MIN, camera_distance - CAMERA_AIM_PULL_IN)
	spring_arm.spring_length = lerp(
		spring_arm.spring_length, target, clampf(delta * CAMERA_ZOOM_SPEED, 0.0, 1.0)
	)

## After free-look (left mouse) ends, ease the camera back behind the character.
func _update_camera_recenter(delta: float) -> void:
	if Input.is_action_pressed("look_front"):
		return  # actively orbiting; leave the camera where the player put it
	if not _orbiting:
		return  # already centered, nothing to do
	camera_pivot.rotation.y = lerp_angle(
		camera_pivot.rotation.y, 0.0, clampf(delta * CAMERA_RECENTER_SPEED, 0.0, 1.0)
	)
	if absf(wrapf(camera_pivot.rotation.y, -PI, PI)) < 0.01:
		camera_pivot.rotation.y = 0.0
		_orbiting = false

func _update_anim(delta: float = 0.0) -> void:
	if anim_player == null:
		return
	# One-shot shoot pose plays out before anything else.
	if _shoot_anim_timer > 0.0:
		_shoot_anim_timer -= delta
		return
	# Drawing the bow: hold an aiming pose (pack has no bow anim, reuse gun aim).
	if is_drawing_bow:
		_play_anim("Idle_Gun_Pointing")
		return
	var horizontal: float = Vector2(velocity.x, velocity.z).length()
	if horizontal < 0.1:
		_play_anim("Idle")
	elif stance == Stance.RUNNING:
		_play_anim("Run")
	else:
		_play_anim("Walk")  # walking or sneaking both use Walk anim

## Visual crouch: squash the model vertically while sneaking (no sneak anim exists).
func _update_crouch(delta: float) -> void:
	if model == null:
		return
	var target_y: float = SNEAK_CROUCH_SCALE if stance == Stance.SNEAKING else 1.0
	var s := model.scale
	# Model X/Z are flipped (-1); preserve their sign, animate magnitude of Y.
	var new_y: float = lerp(absf(s.y), target_y, clampf(delta * 10.0, 0.0, 1.0))
	model.scale = Vector3(s.x, new_y, s.z)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= Config.PLAYER_GRAVITY * delta

func _handle_jump() -> void:
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = Config.PLAYER_JUMP_VELOCITY

func _update_stance() -> void:
	if Input.is_action_pressed("sneak"):
		stance = Stance.SNEAKING
	elif Input.is_action_pressed("run"):
		stance = Stance.RUNNING
	else:
		stance = Stance.STANDING

func _apply_horizontal_movement(_delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)
	# Use the body's facing while free-looking (so WASD stays consistent no matter
	# where the camera is orbited); otherwise the camera and body face the same way.
	var basis_source: Node3D = self if _orbiting else camera_pivot
	var forward := -basis_source.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := basis_source.global_transform.basis.x
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

	var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
	var bow_mount: Node3D = $BowMount
	# Spawn the arrow at the bow on the character's body so it's visible leaving the player.
	var spawn_pos: Vector3 = bow_mount.global_transform.origin

	# Aim at whatever the screen center is pointing at (raycast from the camera),
	# then fire from the bow toward that target. Spawn point is the body, aim is the crosshair.
	var aim_point: Vector3 = _screen_center_aim_point(camera)
	var direction: Vector3 = (aim_point - spawn_pos).normalized()

	arrow.global_transform.origin = spawn_pos
	arrow.look_at(spawn_pos + direction, Vector3.UP)
	var speed: float = lerp(Config.ARROW_SPEED_MIN, Config.ARROW_SPEED_MAX, charge)
	arrow.linear_velocity = direction * speed
	EventBus.player_shot_arrow.emit(spawn_pos, direction)
	# Play a one-shot shoot pose so the release reads as "loosing an arrow".
	if anim_player and anim_player.has_animation("Gun_Shoot"):
		anim_player.play("Gun_Shoot")
		_shoot_anim_timer = 0.4

## Raycast from the camera through the screen center to find the aim target.
## Falls back to a far point along the camera's look direction if nothing is hit.
func _screen_center_aim_point(camera: Camera3D) -> Vector3:
	var cam_origin: Vector3 = camera.global_transform.origin
	var cam_forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var far_point: Vector3 = cam_origin + cam_forward * 1000.0

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(cam_origin, far_point)
	query.exclude = [get_rid()]  # don't aim at ourselves
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return far_point
	return hit.position
