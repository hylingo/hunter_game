extends CharacterBody3D
class_name Player

## Third-person character controller. Owns movement, sneak state,
## bow charge/release, and arrow spawning.

const ArrowScene: PackedScene = preload("res://scenes/projectiles/arrow.tscn")

enum Stance { STANDING, SNEAKING, RUNNING }

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var main_camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var arrow_camera: Camera3D = $ArrowCamera  # top_level cam for the arrow-cam
@onready var nocked_arrow: Node3D = $NockedArrow  # the arrow shown on the bow while drawing
@onready var anim_player: AnimationPlayer = _find_animation_player()
@onready var model: Node3D = $Model

const SNEAK_CROUCH_SCALE := 0.6  # vertical squash when sneaking

# Camera: scroll wheel adjusts distance; bow draw pulls in closer still.
const CAMERA_DIST_MIN := 1.5    # closest the wheel can zoom in
const CAMERA_DIST_MAX := 10.0   # farthest the wheel can zoom out
const CAMERA_DIST_DEFAULT := 4.0
const CAMERA_AIM_PULL_IN := 3.2  # how much closer the camera gets while aiming
const CAMERA_AIM_MIN_DIST := 0.8 # closest the camera may get while aiming (tighter
								 # than the normal zoom-in floor for a close aim shot)
const CAMERA_ZOOM_STEP := 0.5    # distance change per wheel notch
const CAMERA_ZOOM_SPEED := 10.0  # smoothing speed toward the target distance

# How fast the camera eases back behind the character after free-look (left mouse) ends.
const CAMERA_RECENTER_SPEED := 6.0

# Over-the-shoulder aim: while drawing the bow, the camera slides to the right
# shoulder so the head doesn't block the view of the target.
const CAMERA_AIM_SHOULDER_X := 0.7   # how far right the camera shifts when aiming
const CAMERA_AIM_SHOULDER_Y := 0.35  # raise the camera while aiming so it looks
									 # over the shoulder, not at the back of the head
const CAMERA_AIM_BLEND_SPEED := 10.0 # how fast it slides in/out

# Arrow-cam: after firing, the camera follows the arrow until it lands/despawns.
const ARROW_CAM_BACK := 2.0    # how far behind the arrow the camera sits (closer)
const ARROW_CAM_UP := 0.5      # how far above the arrow's flight line
const ARROW_CAM_SIDE := 0.8    # offset to the side so the arrow isn't dead-center
const ARROW_CAM_SPEED := 12.0  # how fast the camera chases the arrow

# Wheel-controlled base distance; aiming subtracts CAMERA_AIM_PULL_IN from it.
var camera_distance: float = CAMERA_DIST_DEFAULT
var _orbiting: bool = false  # true while the camera has been freely orbited off-center
var _aim_blend: float = 0.0  # 0 = centered behind, 1 = over the right shoulder
var _followed_arrow: Arrow = null  # the arrow being tracked (may be freed mid-flight)
var _arrow_cam_active: bool = false  # true while tracking — does NOT rely on the arrow
									 # reference, which goes null the instant the arrow
									 # is freed (e.g. on hitting a tree/animal/ground)
var _arrow_cam_time: float = 0.0   # how long the arrow-cam has been running
var _arrow_cam_returning: bool = false  # gliding the cam back to the player after a shot
var _arrow_cam_return_t: float = 0.0    # 0..1 progress of the glide-back
const ARROW_CAM_MAX_TIME := 2.5    # hand control back after this even if the arrow lives on
const ARROW_CAM_STILL_SPEED := 1.5 # arrow this slow counts as "landed" -> return
const ARROW_CAM_RETURN_DURATION := 0.35 # seconds to glide the cam back to the player
const CAMERA_RETURN_PITCH := -0.15      # look pitch after a shot (slightly raised view)

# Nocked-arrow placement relative to the bow mount.
const NOCK_RAISE := 0.15      # raise the arrow up a bit
const NOCK_PULL_IN := 0.15    # pull it in closer to the body (+Z is behind the player)
const NOCK_DRAW_BACK := 0.35  # how far the arrow slides back at full charge (draw the string)

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
	if _arrow_cam_active:
		# Any deliberate input (key, mouse button, or a real mouse move) cuts the
		# arrow-cam short and hands control straight back to the player (instant,
		# no glide — a glide from a far/high arrow looks like flying up and down).
		if _is_skip_arrow_cam_input(event):
			_end_arrow_cam(true)
		return
	if _arrow_cam_returning:
		return  # gliding back; let it finish (it's brief)
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
		# Pitch tilts the camera arm. Allow a good upward range so the player can
		# aim at high/distant targets (arc shots), while the lowered camera pivot
		# keeps the back-of-head view acceptable.
		spring_arm.rotate_x(-motion.relative.y * 0.003)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -1.2, 0.7)

## True for any deliberate input that should cut the arrow-cam short.
func _is_skip_arrow_cam_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true  # any mouse button press (incl. wheel) skips
	if event is InputEventMouseMotion:
		# Only a real move, not tiny jitter, so it doesn't end instantly.
		return (event as InputEventMouseMotion).relative.length() > 8.0
	return false

func _unhandled_input(event: InputEvent) -> void:
	# Esc always works (so the player can free the mouse even mid-arrow-cam).
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if _arrow_cam_active or _arrow_cam_returning:
		return  # other input locked while the arrow-cam is tracking / gliding back
	if event is InputEventMouseButton and event.pressed:
		var btn := event as InputEventMouseButton
		# If the mouse was freed (Esc), the first click just recaptures it for
		# mouse-look; don't let that click also draw the bow.
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if btn.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = clamp(camera_distance - CAMERA_ZOOM_STEP, CAMERA_DIST_MIN, CAMERA_DIST_MAX)
		elif btn.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = clamp(camera_distance + CAMERA_ZOOM_STEP, CAMERA_DIST_MIN, CAMERA_DIST_MAX)
	if event.is_action_pressed("fire"):
		is_drawing_bow = true
	elif event.is_action_released("fire"):
		var charge := release_bow()
		_fire_arrow(charge)

func _physics_process(delta: float) -> void:
	# While the arrow-cam is active (tracking OR gliding back), the player is locked.
	if _arrow_cam_active or _arrow_cam_returning:
		_apply_gravity(delta)
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		_update_anim(delta)
		if _arrow_cam_returning:
			_update_arrow_cam_return(delta)
		else:
			_update_arrow_cam(delta)
		return
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
	_update_nocked_arrow()

## Show an arrow nocked on the bow while drawing, pointing at the screen-center
## crosshair (same aim point the shot will use). Hidden when not drawing.
func _update_nocked_arrow() -> void:
	if not is_drawing_bow:
		if nocked_arrow.visible:
			nocked_arrow.visible = false
		return
	# Base nock point: at the bow, nudged up and pulled in closer to the body.
	var base: Vector3 = $BowMount.global_transform.origin \
		+ global_transform.basis.y * NOCK_RAISE \
		+ global_transform.basis.z * NOCK_PULL_IN
	var aim_point: Vector3 = _screen_center_aim_point(main_camera)
	var direction: Vector3 = (aim_point - base).normalized()
	# Draw-back: as the bow charges, slide the arrow backwards along the aim line
	# (toward the archer) to mimic pulling the string.
	var spawn_pos: Vector3 = base - direction * (NOCK_DRAW_BACK * bow_charge)
	nocked_arrow.visible = true
	nocked_arrow.global_position = spawn_pos
	nocked_arrow.look_at(spawn_pos + direction, Vector3.UP)

## Chase the fired arrow with the camera until it lands/despawns, then hand control
## back to the player. The player body is frozen while this runs.
func _update_arrow_cam(delta: float) -> void:
	_arrow_cam_time += delta
	# End the arrow-cam if: the arrow is gone (hit/despawned), it has effectively
	# landed (slowed to a stop), or we've watched it long enough.
	var arrow_gone := not is_instance_valid(_followed_arrow)
	var landed := false
	if not arrow_gone:
		landed = _followed_arrow.is_stuck()
	if arrow_gone or landed or _arrow_cam_time >= ARROW_CAM_MAX_TIME:
		_end_arrow_cam()
		return
	var arrow_pos: Vector3 = _followed_arrow.global_transform.origin
	var vel: Vector3 = _followed_arrow.current_velocity()
	var flight_dir: Vector3 = vel.normalized() if vel.length() > 0.1 else -global_transform.basis.z
	# Sideways direction (right of the flight path) so the camera sits off to one
	# side and the arrow is visible rather than hidden dead-center.
	var side_dir: Vector3 = flight_dir.cross(Vector3.UP).normalized()
	# Sit behind, slightly above, and to the side of the arrow, looking at it.
	var desired: Vector3 = arrow_pos \
		- flight_dir * ARROW_CAM_BACK \
		+ Vector3.UP * ARROW_CAM_UP \
		+ side_dir * ARROW_CAM_SIDE
	var t: float = clampf(delta * ARROW_CAM_SPEED, 0.0, 1.0)
	arrow_camera.global_position = arrow_camera.global_position.lerp(desired, t)
	arrow_camera.look_at(arrow_pos, Vector3.UP)

## End the arrow-cam. When `instant` (the player pressed a key/clicked to skip),
## cut straight back to the player — no glide, since gliding from a far-away arrow
## (e.g. one shot into the sky) looks like the view flies up and falls back down.
## Otherwise (arrow landed / timed out) glide smoothly back.
func _end_arrow_cam(instant: bool = false) -> void:
	_followed_arrow = null
	_arrow_cam_active = false
	_aim_blend = 0.0
	spring_arm.position = Vector3.ZERO
	# Reset the look pitch to a comfortable slightly-raised angle.
	spring_arm.rotation.x = CAMERA_RETURN_PITCH
	if instant:
		_arrow_cam_returning = false
		main_camera.make_current()
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	_arrow_cam_returning = true
	_arrow_cam_return_t = 0.0
	# Clean up any float drift from repeated look_at so the interpolation is safe.
	arrow_camera.global_transform = arrow_camera.global_transform.orthonormalized()

## Glide the arrow camera to the player camera over a FIXED time, then hand control
## back. Time-based (not distance-based) so it can never get stuck if the arrow
## ended up far away — it always completes within ARROW_CAM_RETURN_DURATION.
func _update_arrow_cam_return(delta: float) -> void:
	_arrow_cam_return_t += delta / ARROW_CAM_RETURN_DURATION
	var t: float = clampf(_arrow_cam_return_t, 0.0, 1.0)
	# Ease the whole transform toward the main camera's pose. interpolate_with is
	# safe for any orthonormal transforms (unlike Basis.slerp, which can error on
	# slightly non-orthogonal bases produced by repeated look_at and freeze us).
	var target: Transform3D = main_camera.global_transform
	arrow_camera.global_transform = arrow_camera.global_transform.interpolate_with(target, t)
	if t >= 1.0:
		# Done — hand the view back to the third-person camera and unlock the player.
		_arrow_cam_returning = false
		main_camera.make_current()
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Smoothly move the camera toward the wheel-set distance, pulling in while aiming,
## and slide it over the right shoulder so the head doesn't block the aim.
func _update_camera_zoom(delta: float) -> void:
	var target: float = camera_distance
	if is_drawing_bow:
		target = maxf(CAMERA_AIM_MIN_DIST, camera_distance - CAMERA_AIM_PULL_IN)
	spring_arm.spring_length = lerp(
		spring_arm.spring_length, target, clampf(delta * CAMERA_ZOOM_SPEED, 0.0, 1.0)
	)
	# Blend the over-the-shoulder offset in while aiming, out when not.
	var aim_target: float = 1.0 if is_drawing_bow else 0.0
	_aim_blend = lerp(_aim_blend, aim_target, clampf(delta * CAMERA_AIM_BLEND_SPEED, 0.0, 1.0))
	spring_arm.position.x = CAMERA_AIM_SHOULDER_X * _aim_blend
	spring_arm.position.y = CAMERA_AIM_SHOULDER_Y * _aim_blend

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
	var horizontal: float = Vector2(velocity.x, velocity.z).length()
	# Drawing the bow: hold the aiming pose only while standing still. If the
	# player is also moving, play the locomotion anim so the legs move instead of
	# the body sliding under a static aim pose (the pack has no aim+move clip).
	if is_drawing_bow and horizontal < 0.1:
		_play_anim("Idle_Gun_Pointing")
		return
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
	# Launch with kinetic energy scaled by draw charge — drives how much it can
	# punch through (a full draw can pierce several targets).
	arrow.launch(direction * speed, charge, [get_rid()])
	EventBus.player_shot_arrow.emit(spawn_pos, direction)
	# Play a one-shot shoot pose so the release reads as "loosing an arrow".
	if anim_player and anim_player.has_animation("Gun_Shoot"):
		anim_player.play("Gun_Shoot")
		_shoot_anim_timer = 0.4
	# Follow the arrow with the camera until it lands or despawns. Switch to the
	# dedicated top-level arrow camera so the SpringArm doesn't fight us.
	nocked_arrow.visible = false  # the drawn arrow has now been loosed
	_followed_arrow = arrow
	_arrow_cam_active = true
	_arrow_cam_time = 0.0
	_arrow_cam_returning = false  # start a fresh follow, clear any leftover return state
	arrow_camera.global_transform = main_camera.global_transform
	arrow_camera.make_current()

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
