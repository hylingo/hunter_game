extends Node3D
## The Adventurer.glb is the full Quaternius modular pack: every outfit
## (King, Suit, Swat, ...) plus Backpack/Sword/Pistol are all stacked on one
## skeleton. This shows only the chosen outfit parts and hides everything else,
## so the character wears exactly one set instead of all of them overlapping.

## Prefixes/names of the mesh parts to KEEP visible. Everything else is hidden.
## Change this list to swap outfits (e.g. ["Swat", "Backpack"]).
@export var visible_parts: Array[String] = ["King"]

func _ready() -> void:
	var skeleton := _find_skeleton(self)
	if skeleton == null:
		push_warning("Outfit: no Skeleton3D found under model")
		return
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			child.visible = _should_show(child.name)

func _should_show(part_name: String) -> bool:
	for keep in visible_parts:
		if part_name.begins_with(keep):
			return true
	return false

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
