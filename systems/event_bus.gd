extends Node
## Global signal bus. Holds no state. Nodes emit/listen via EventBus.* to avoid
## tight coupling between scenes.

signal animal_killed(animal_type: String, position: Vector3)
signal animal_alerted(animal: Node3D)
signal player_shot_arrow(from: Vector3, direction: Vector3)
signal player_hit_by(damage: float, source: Node3D)
