extends CanvasLayer
class_name HUD

@onready var hp_bar: ProgressBar = $root/HPBar
@onready var hp_label: Label = $root/HPBar/HPLabel
@onready var arrows_label: Label = $root/ArrowsLabel
@onready var kills_label: Label = $root/KillsLabel
@onready var crosshair: Control = $root/Crosshair

var kills: int = 0

func _ready() -> void:
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.arrows_changed.connect(_on_arrows_changed)
	EventBus.animal_killed.connect(_on_animal_killed)
	crosshair.visible = false
	_refresh()

func _process(_delta: float) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and "is_drawing_bow" in player:
		crosshair.visible = player.is_drawing_bow

func _refresh() -> void:
	_on_hp_changed(GameState.hp)
	_on_arrows_changed(GameState.arrows)

func _on_hp_changed(new_hp: float) -> void:
	hp_bar.max_value = GameState.HP_MAX
	hp_bar.value = new_hp
	hp_label.text = "HP %d / %d" % [int(new_hp), int(GameState.HP_MAX)]

func _on_arrows_changed(new_count: int) -> void:
	arrows_label.text = "Arrows: %d" % new_count

func _on_animal_killed(_type: String, _pos: Vector3) -> void:
	kills += 1
	kills_label.text = "Kills: %d" % kills
