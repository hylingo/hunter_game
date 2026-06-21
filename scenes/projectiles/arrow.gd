extends RigidBody3D
class_name Arrow

const LIFETIME_SECONDS := 3.0

var damage: float = Config.ARROW_DAMAGE
var _age: float = 0.0

@onready var hit_area: Area3D = $HitArea

func _ready() -> void:
	hit_area.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME_SECONDS:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# Ignore other arrows and the player who fired us.
	if body is Arrow:
		return
	if body is Player:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
