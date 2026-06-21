class_name AnimalState
extends RefCounted

## Abstract base for FSM states. Each concrete state implements process()
## and may return a different state name to request a transition.

## Override. Called every physics frame by the animal.
## Return:
##   "" to stay in the current state
##   "<state_name>" to request a transition (handled by the animal)
func process(_animal, _delta: float) -> String:
	return ""

## Override. Called once when the state becomes active.
func enter(_animal) -> void:
	pass

## Override. Called once when the state is being left.
func exit(_animal) -> void:
	pass
