extends Node
## Runtime player stats. Read by HUD, written by player.gd and combat code.

signal hp_changed(new_hp: float)
signal arrows_changed(new_count: int)

const HP_MAX := 100.0
const ARROWS_MAX := 9999
const ARROWS_START := 1000

var hp: float = HP_MAX:
	set(value):
		hp = clamp(value, 0.0, HP_MAX)
		hp_changed.emit(hp)

var arrows: int = ARROWS_START:
	set(value):
		arrows = clamp(value, 0, ARROWS_MAX)
		arrows_changed.emit(arrows)

func reset() -> void:
	hp = HP_MAX
	arrows = ARROWS_START
