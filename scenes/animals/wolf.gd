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

func _ready() -> void:
	hp = max_hp
	_transition("idle")

func _physics_process(delta: float) -> void:
	if current_state == null:
		return
	_apply_gravity(delta)
	var next := current_state.process(self, delta)
	move_and_slide()
	# Soft world boundary: keep wolf inside ±45m
	var p := global_transform.origin
	if absf(p.x) > 45 or absf(p.z) > 45:
		var t := global_transform
		t.origin.x = clampf(t.origin.x, -45, 45)
		t.origin.z = clampf(t.origin.z, -45, 45)
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

func take_damage(amount: float) -> void:
	if hp <= 0:
		return  # already dying
	hp -= amount
	if hp <= 0:
		_die()

func _die() -> void:
	EventBus.animal_killed.emit("wolf", global_transform.origin)
	set_physics_process(false)
	rotation.x = deg_to_rad(-90)
	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh and mesh.get_surface_override_material(0):
		var mat: StandardMaterial3D = mesh.get_surface_override_material(0).duplicate()
		mat.albedo_color = mat.albedo_color * 0.4
		mesh.set_surface_override_material(0, mat)
	await get_tree().create_timer(2.0).timeout
	queue_free()

func sees_threat() -> bool:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var dist: float = global_transform.origin.distance_to(player.global_transform.origin)
	return dist <= Config.WOLF_AGGRO_RANGE

func threat_response_state() -> String:
	return "chase"
