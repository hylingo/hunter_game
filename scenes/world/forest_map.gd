extends Node3D

const DeerScene: PackedScene = preload("res://scenes/animals/deer.tscn")
const WolfScene: PackedScene = preload("res://scenes/animals/wolf.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player/player.tscn")

const TREE_SCENES: Array[PackedScene] = [
	preload("res://assets/models/environment/CommonTree_1.gltf"),
	preload("res://assets/models/environment/CommonTree_2.gltf"),
	preload("res://assets/models/environment/CommonTree_3.gltf"),
	preload("res://assets/models/environment/CommonTree_4.gltf"),
	preload("res://assets/models/environment/CommonTree_5.gltf"),
]

# Map is 250x250 centered on origin. Keep spawns inside ±120 so nothing
# touches the boundary walls at ±125.
const MAP_HALF := 120.0
const PLAYER_CLEAR_RADIUS := 8.0  # no trees right on top of the player spawn

@export var deer_count: int = 8
@export var wolf_count: int = 4
@export var scattered_tree_count: int = 60
@export var grove_count: int = 5            # dense clusters
@export var trees_per_grove: int = 12

var _rng := RandomNumberGenerator.new()
var _trees_root: Node3D

func _ready() -> void:
	_rng.randomize()
	_trees_root = Node3D.new()
	_trees_root.name = "Trees"
	add_child(_trees_root)
	_scatter_trees()
	_spawn_groves()
	_spawn_player()
	_spawn_animals()

func _spawn_player() -> void:
	var p: CharacterBody3D = PlayerScene.instantiate()
	add_child(p)
	p.global_transform.origin = Vector3(0, 1, 0)

func _spawn_animals() -> void:
	for i in deer_count:
		var d: CharacterBody3D = DeerScene.instantiate()
		add_child(d)
		d.global_transform.origin = _random_ground_position()
	for i in wolf_count:
		var w: CharacterBody3D = WolfScene.instantiate()
		add_child(w)
		w.global_transform.origin = _random_ground_position()

## Even sparse coverage across the whole map.
func _scatter_trees() -> void:
	for i in scattered_tree_count:
		var pos := _random_ground_position()
		if Vector2(pos.x, pos.z).length() < PLAYER_CLEAR_RADIUS:
			continue
		_place_tree(pos)

## A few dense groves so some areas feel like thick forest.
func _spawn_groves() -> void:
	for g in grove_count:
		var center := Vector2(
			_rng.randf_range(-MAP_HALF + 20, MAP_HALF - 20),
			_rng.randf_range(-MAP_HALF + 20, MAP_HALF - 20)
		)
		for t in trees_per_grove:
			var offset := Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12))
			var p := center + offset
			if p.length() < PLAYER_CLEAR_RADIUS:
				continue
			_place_tree(Vector3(p.x, 0, p.y))

func _place_tree(pos: Vector3) -> void:
	var body := StaticBody3D.new()

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 8.0
	col.shape = shape
	col.position = Vector3(0, 4, 0)
	body.add_child(col)

	var model := TREE_SCENES[_rng.randi() % TREE_SCENES.size()].instantiate()
	var s := _rng.randf_range(1.3, 1.9)
	model.scale = Vector3(s, s, s)
	model.rotate_y(_rng.randf_range(0, TAU))
	body.add_child(model)

	# Distance cull the visual so far trees stop rendering (collision stays).
	for child in model.get_children():
		if child is GeometryInstance3D:
			child.visibility_range_end = 180.0
			child.visibility_range_end_margin = 20.0

	_trees_root.add_child(body)
	# Set the world position only after the node is in the tree.
	body.global_transform.origin = pos

func _random_ground_position() -> Vector3:
	return Vector3(
		_rng.randf_range(-MAP_HALF, MAP_HALF),
		0.5,
		_rng.randf_range(-MAP_HALF, MAP_HALF)
	)
