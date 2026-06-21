class_name StateAttack
extends AnimalState

var _cooldown: float = 0.0
const ATTACK_INTERVAL := 1.2

func enter(_animal) -> void:
	_cooldown = 0.0

func process(animal, delta: float) -> String:
	animal.velocity.x = 0
	animal.velocity.z = 0
	var player: Node = animal.get_tree().get_first_node_in_group("player")
	if player == null:
		return "wander"
	var dist: float = animal.global_transform.origin.distance_to(player.global_transform.origin)
	if dist > Config.WOLF_ATTACK_RANGE * 1.2:
		return "chase"
	_cooldown -= delta
	if _cooldown <= 0:
		if player.has_method("take_damage"):
			player.take_damage(Config.WOLF_ATTACK_DAMAGE)
		_cooldown = ATTACK_INTERVAL
	if animal.hp < animal.max_hp * Config.WOLF_RETREAT_HP_FRACTION:
		return "retreat"
	return ""
