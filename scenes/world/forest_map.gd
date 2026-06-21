extends Node3D

const DeerScene: PackedScene = preload("res://scenes/animals/deer.tscn")
const WolfScene: PackedScene = preload("res://scenes/animals/wolf.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player/player.tscn")

@export var deer_count: int = 4
@export var wolf_count: int = 2

func _ready() -> void:
	_spawn_player()
	_spawn_animals()

func _spawn_player() -> void:
	var p: CharacterBody3D = PlayerScene.instantiate()
	p.global_transform.origin = Vector3(0, 1, 0)
	add_child(p)

func _spawn_animals() -> void:
	for i in deer_count:
		var d: CharacterBody3D = DeerScene.instantiate()
		d.global_transform.origin = _random_ground_position()
		add_child(d)
	for i in wolf_count:
		var w: CharacterBody3D = WolfScene.instantiate()
		w.global_transform.origin = _random_ground_position()
		add_child(w)

func _random_ground_position() -> Vector3:
	return Vector3(randf_range(-40, 40), 0.5, randf_range(-40, 40))
