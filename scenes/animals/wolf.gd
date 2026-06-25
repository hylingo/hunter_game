extends CharacterBody3D
class_name Wolf

const STATES := {
	"idle":    preload("res://ai/state_idle.gd"),
	"wander":  preload("res://ai/state_wander.gd"),
	"chase":   preload("res://ai/state_chase.gd"),
	"attack":  preload("res://ai/state_attack.gd"),
	"retreat": preload("res://ai/state_retreat.gd"),
}

@export var max_hp: float = Config.WOLF_HP
@export var wander_speed: float = Config.WOLF_WANDER_SPEED

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
	_sync_locomotion_anim_speed()
	# Soft world boundary: keep wolf inside ±120m
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

# Reference speeds = the actual movement speeds these clips play at, so playback
# tracks ground travel and the legs keep pace (no foot sliding). Calibrated to
# Config: Walk while wandering (2 m/s), Gallop while chasing (6 m/s).
const WALK_ANIM_REF_SPEED := Config.WOLF_WANDER_SPEED   # 2.0
const GALLOP_ANIM_REF_SPEED := Config.WOLF_CHASE_SPEED  # 6.0

func _sync_locomotion_anim_speed() -> void:
	if anim_player == null:
		return
	# Use the REAL post-collision velocity, not the intended one: when blocked by a
	# tree/wall/other animal, move_and_slide keeps `velocity` high but it actually
	# travels slower — that mismatch is what looks like sliding against obstacles.
	var rv := get_real_velocity()
	var ground_speed := Vector2(rv.x, rv.z).length()
	match anim_player.current_animation:
		"Walk":
			anim_player.speed_scale = clampf(ground_speed / WALK_ANIM_REF_SPEED, 0.5, 2.5)
		"Gallop":
			anim_player.speed_scale = clampf(ground_speed / GALLOP_ANIM_REF_SPEED, 0.5, 2.5)
		_:
			anim_player.speed_scale = 1.0

func _transition(state_name: String) -> void:
	if current_state:
		current_state.exit(self)
	current_state_name = state_name
	current_state = STATES[state_name].new()
	current_state.enter(self)
	match state_name:
		"idle":    _play_anim("Idle")
		"wander":  _play_anim("Walk")
		"chase":   _play_anim("Gallop")
		"attack":  _play_anim("Attack")
		"retreat": _play_anim("Gallop")

func take_damage(amount: float) -> void:
	if hp <= 0:
		return
	hp -= amount
	if hp <= 0:
		_die()

func _die() -> void:
	EventBus.animal_killed.emit("wolf", global_transform.origin)
	set_physics_process(false)
	_play_anim("Death")
	# Leave the carcass (with any embedded arrows) in the world — no despawn.

func sees_threat() -> bool:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var dist: float = global_transform.origin.distance_to(player.global_transform.origin)
	return dist <= Config.WOLF_AGGRO_RANGE

func threat_response_state() -> String:
	return "chase"
