extends CharacterBody3D
class_name Deer

const STATES := {
	"idle":   preload("res://ai/state_idle.gd"),
	"wander": preload("res://ai/state_wander.gd"),
	"alert":  preload("res://ai/state_alert.gd"),
	"flee":   preload("res://ai/state_flee.gd"),
}

@export var max_hp: float = Config.DEER_HP
@export var wander_speed: float = Config.DEER_WANDER_SPEED

var hp: float
var current_state: AnimalState
var current_state_name: String = ""

@onready var anim_player: AnimationPlayer = _find_animation_player()

func _find_animation_player() -> AnimationPlayer:
	var model: Node = get_node_or_null("Model")
	if model == null:
		return null
	for child in model.get_children():
		if child is AnimationPlayer:
			return child
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

func _ready() -> void:
	hp = max_hp
	_transition("idle")

func _physics_process(delta: float) -> void:
	if current_state == null:
		return
	_apply_gravity(delta)
	var next := current_state.process(self, delta)
	move_and_slide()
	# Soft world boundary: keep deer inside ±120m
	var p := global_transform.origin
	if absf(p.x) > 120 or absf(p.z) > 120:
		var t := global_transform
		t.origin.x = clampf(t.origin.x, -120, 120)
		t.origin.z = clampf(t.origin.z, -120, 120)
		global_transform = t
	if next != "" and next != current_state_name:
		_transition(next)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= Config.PLAYER_GRAVITY * delta
	else:
		velocity.y = max(velocity.y, 0)

func _transition(state_name: String) -> void:
	if current_state:
		current_state.exit(self)
	current_state_name = state_name
	current_state = STATES[state_name].new()
	current_state.enter(self)
	match state_name:
		"idle":   _play_anim("Idle")
		"wander": _play_anim("Walk")
		"alert":  _play_anim("Idle_2")
		"flee":   _play_anim("Gallop")

func take_damage(amount: float) -> void:
	if hp <= 0:
		return  # already dying
	hp -= amount
	if hp <= 0:
		_die()

func _die() -> void:
	EventBus.animal_killed.emit("deer", global_transform.origin)
	set_physics_process(false)
	_play_anim("Death")
	await get_tree().create_timer(2.5).timeout
	queue_free()

func sees_threat() -> bool:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var forward: Vector3 = -global_transform.basis.z
	var seen := Deer.in_view_cone(global_transform.origin, forward,
		player.global_transform.origin,
		Config.DEER_VIEW_RANGE, Config.DEER_VIEW_CONE_DEG)
	var heard := Deer.heard(global_transform.origin,
		player.global_transform.origin,
		player.noise_radius(), Config.DEER_HEARING_RANGE)
	return seen or heard

func threat_response_state() -> String:
	return "alert"

# --- static perception helpers (testable without nodes) ---

static func in_view_cone(observer_pos: Vector3, observer_forward: Vector3,
		target_pos: Vector3, max_range: float, cone_deg: float) -> bool:
	var to_target: Vector3 = target_pos - observer_pos
	to_target.y = 0
	var dist := to_target.length()
	if dist > max_range or dist < 0.001:
		return false
	var fwd := observer_forward
	fwd.y = 0
	fwd = fwd.normalized()
	var angle := rad_to_deg(fwd.angle_to(to_target.normalized()))
	return angle <= cone_deg * 0.5

static func heard(observer_pos: Vector3, target_pos: Vector3,
		target_noise_radius: float, observer_hearing_range: float) -> bool:
	var dist := observer_pos.distance_to(target_pos)
	if dist > observer_hearing_range:
		return false
	return target_noise_radius >= dist
