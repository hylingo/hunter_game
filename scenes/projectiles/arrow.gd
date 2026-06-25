extends RigidBody3D
class_name Arrow

## Arrow that flies on its own (manual ballistics + raycast hit detection, so it
## never gets bounced around by the physics engine) and STICKS into the first
## thing it hits — tree, ground, or animal. It then stays embedded and rides
## along if the target moves. Nothing despawns on hit.
## (Pass-through / penetration is intentionally left out for now — that's planned
## for future higher-tier arrows or a stamina/power system.)

const LIFETIME_SECONDS := 30.0   # cull arrows that never hit anything
const GRAVITY := 6.0             # arc drop (m/s^2); lower than world gravity = flatter
const EMBED_DEPTH := 0.25        # how far the tip sinks into what stops it

var damage: float = Config.ARROW_DAMAGE

var _velocity: Vector3 = Vector3.ZERO
var _exclude: Array = []          # RIDs to ignore (the shooter)
var _stuck: bool = false
var _age: float = 0.0

@onready var hit_area: Area3D = $HitArea

## Current flight velocity (the arrow drives its own motion, not the physics body).
func current_velocity() -> Vector3:
	return _velocity

func is_stuck() -> bool:
	return _stuck

func _ready() -> void:
	# We drive motion ourselves; disable the physics body's own simulation.
	freeze = true
	if hit_area:
		hit_area.monitoring = false

## Called by the player right after spawning. velocity is direction*speed;
## exclude holds RIDs to ignore (the shooter). charge is unused for now.
func launch(velocity: Vector3, _charge: float, exclude: Array) -> void:
	_velocity = velocity
	_exclude = exclude.duplicate()
	if not is_inside_tree():
		await ready
	look_at(global_position + _velocity.normalized(), Vector3.UP)

func _physics_process(delta: float) -> void:
	if _stuck:
		return
	_age += delta
	if _age >= LIFETIME_SECONDS:
		queue_free()
		return

	_velocity.y -= GRAVITY * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + _velocity * delta

	# Sweep the segment we're about to travel for a hit.
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = _exclude
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)

	if hit.is_empty():
		# No hit this step — keep flying and face the travel direction.
		global_position = to
		if _velocity.length() > 0.01:
			look_at(to + _velocity.normalized(), Vector3.UP)
		return

	_resolve_hit(hit)

func _resolve_hit(hit: Dictionary) -> void:
	var body: Object = hit.get("collider")
	var point: Vector3 = hit.get("position", global_position)
	# Damage anything that can take it.
	if body and body.has_method("take_damage"):
		body.take_damage(damage)
	_embed(body, point)

func _embed(body: Object, point: Vector3) -> void:
	_stuck = true
	var forward: Vector3 = _velocity.normalized()
	global_position = point + forward * EMBED_DEPTH
	if forward.length() > 0.01:
		look_at(global_position + forward, Vector3.UP)
	# Parent under the hit body so the arrow rides along if it moves (deferred —
	# scene-tree edits can't happen inside a physics query step).
	if body is Node:
		_attach_to.call_deferred(body)

func _attach_to(body: Node) -> void:
	if not is_instance_valid(body):
		return
	var keep := global_transform
	# If the target has a skeleton (an animal), attach to a torso bone so the arrow
	# follows the body as it animates (e.g. falls over when it dies) instead of
	# hanging in mid-air where the body used to stand.
	var skel := _find_skeleton(body)
	var new_parent: Node = body
	if skel != null:
		var bone := _pick_torso_bone(skel)
		var ba := BoneAttachment3D.new()
		ba.bone_idx = bone
		skel.add_child(ba)
		new_parent = ba
	# Reparent KEEPING the world transform (true). Passing false was the bug: it
	# kept the arrow's LOCAL transform, so under a scaled tree (scale 1.3-1.9) the
	# arrow got displaced/resized and vanished.
	reparent(new_parent, true)
	# Re-pin the exact world pose, then cancel out any inherited parent scale so
	# the arrow keeps its real size (trees are scaled up; bones may scale too).
	global_transform = keep
	_normalize_world_scale()

## Force the arrow's effective world scale back to 1 regardless of parent scaling.
func _normalize_world_scale() -> void:
	var parent_scale: Vector3 = get_parent().global_transform.basis.get_scale()
	if parent_scale.x == 0.0 or parent_scale.y == 0.0 or parent_scale.z == 0.0:
		return
	scale = Vector3(1.0 / parent_scale.x, 1.0 / parent_scale.y, 1.0 / parent_scale.z)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null

## Prefer a central torso/body bone; fall back to bone 0.
func _pick_torso_bone(skel: Skeleton3D) -> int:
	for want in ["Torso", "Body", "Spine", "Chest", "Hips"]:
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).begins_with(want):
				return i
	return 0
