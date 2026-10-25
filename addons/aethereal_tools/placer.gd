extends RefCounted
## Decides where each new thing goes and under which parent, as a "plan" that apply() carries
## out and revert() takes back (the dock wraps both in the editor's undo/redo). A plan is
## { steps: [{parent, node, owned}], select: Node, message: String }.
## No editor-only calls here, so headless tests can drive it exactly like the dock does.

const Builders := preload("res://addons/aethereal_tools/builders.gd")
const Spot := preload("res://addons/aethereal_tools/spot.gd")
const Query := preload("res://addons/aethereal_tools/scene_query.gd")

const UP := Vector3.UP

var root: Node3D       ## the open level
var spot: Dictionary   ## from Spot.from_view() / from_node(): floor, surface, normal, wall, facing
var finder: Spot       ## for extra casts (route length, ceilings)
var selected: Node     ## the node selected in the editor, or null
var cam: Variant = null  ## the editor camera's Transform3D, when there is one

var _plan: Dictionary


func _init(level: Node3D, where: Dictionary, spot_finder: Spot, selection: Node = null) -> void:
	root = level
	spot = where
	finder = spot_finder
	selected = selection


## The thing named by `kind` ("guard", "checkpoint", ... or "prop:res://...gd"), as a plan.
func plan(kind: String) -> Dictionary:
	_plan = {"steps": [], "select": null, "message": "", "owner": root}
	match kind:
		"guard": _guard()
		"patrol_point": _patrol_point()
		"checkpoint": _on_floor(Builders.checkpoint(), _group("Checkpoints"))
		"story_trigger": _on_floor(Builders.story_trigger(level_file("dialogue")), _group("StoryTriggers"))
		"look_spot": _on_floor(Builders.look_spot(level_file("inspect")), _group("Inspect"))
		"fight": _on_floor(Builders.fight(level_file("dialogue")), root)
		"camera_shot": _camera_shot()
		"flicker_light": _flicker_light()
		"steam_vent": _steam_vent()
		"drip": _drip()
		"tv_window": _tv_window()
		"block": _block(Builders.block())
		"building": _block(Builders.building())
		_:
			if kind.begins_with("prop:"):
				_prop(kind.trim_prefix("prop:"))
			else:
				_plan.message = "Unknown thing: " + kind
	return _plan


## Adds the plan's nodes (the do half of undo/redo).
func apply(p: Dictionary) -> void:
	for step: Dictionary in p.steps:
		var parent: Node = step.parent
		parent.add_child(step.node, true)
		# Owner = the level, so the nodes save with it. Only the nodes listed at plan time:
		# not the inside of an instanced guard, and not anything a script made in _ready.
		for n: Node in step.owned:
			n.owner = p.owner


## Takes the plan's nodes out again (the undo half), newest first.
func revert(p: Dictionary) -> void:
	var steps: Array = p.steps
	for i in range(steps.size() - 1, -1, -1):
		var step: Dictionary = steps[i]
		var parent: Node = step.parent
		if step.node.get_parent() == parent:
			parent.remove_child(step.node)


## "res://data/dialogue/<level>.txt" (kind = "dialogue" or "inspect") if that file exists, else "".
func level_file(kind: String) -> String:
	var path := "res://data/%s/%s.txt" % [kind, root.scene_file_path.get_file().get_basename()]
	return path if root.scene_file_path != "" and FileAccess.file_exists(path) else ""


# --- the things -------------------------------------------------------------------------

func _guard() -> void:
	var fight := Query.fight_of(selected)
	if fight:  # a guard added while a Fight is selected joins that fight
		var fighter := Builders.guard(null, true, true)
		_add(fighter, fight, _ground_xf(-_facing()))
		_plan.message = "Added a fighting agent to %s (dormant until [fight %s])." % [fight.name, fight.name]
		return
	var start: Vector3 = spot.floor
	var dir := _facing()
	var end_local: Variant = null
	for length: float in [4.0, 3.0, 2.0]:
		var end := start + dir * length
		var wall := finder.cast(start + UP, end + UP)  # a wall in the way at waist height?
		if not wall.is_empty():
			continue
		var ground: Variant = finder.floor_below(end + UP * 0.6, 2.0)
		if ground != null and absf((ground as Vector3).y - start.y) < 0.3:
			end_local = Vector3(0, (ground as Vector3).y - start.y, -length)
			break
	var agent := Builders.guard(end_local)
	_add(agent, _group("Guards"), _ground_xf(dir))
	if end_local == null:
		_plan.message = "No room to walk here, so he stands his post. Add a walk with Patrol point."
	else:
		_plan.message = "Agent added with a two-point Route. Select a point (Route > B) and move it."


func _patrol_point() -> void:
	var agent := Query.guard_of(selected, root)
	if agent == null:
		_plan.message = "Select a guard (or one of his patrol points) first."
		return
	var route := agent.get_node_or_null("Route") as Node3D
	var points: Array[Vector3] = []
	if route:
		for m in route.get_children():
			if m is Node3D:
				points.append((m as Node3D).global_position)
	else:
		route = Node3D.new()
		route.name = "Route"
		_add(route, agent, Transform3D.IDENTITY, false)
		_add(Builders.patrol_point("A", Vector3.ZERO), route, Transform3D.IDENTITY, false)
		points.append(agent.global_position)
	var target: Vector3 = spot.floor
	if target.distance_to(points[-1]) > 40.0 or _spot_is_selection():
		var dir := _facing() if points.size() < 2 else (points[-1] - points[-2]).normalized()
		var ahead: Vector3 = points[-1] + Vector3(dir.x, 0, dir.z).normalized() * 3.0
		var ground: Variant = finder.floor_below(ahead + UP * 0.6, 3.0)
		target = ground if ground != null else ahead
	var route_xf := agent.global_transform * route.transform if not route.is_inside_tree() else route.global_transform
	var point := Builders.patrol_point(Query.unique_letter(route, _plan.steps), route_xf.affine_inverse() * target)
	_add(point, route, Transform3D(Basis(), point.position), false)
	_plan.message = "Patrol point %s added to %s. He walks the points in order, then back to A." % [point.name, agent.name]


func _camera_shot() -> void:
	var shot := Builders.camera_shot()
	var xf: Transform3D
	if cam is Transform3D:
		xf = cam  # exactly what the editor view shows: frame it first, then press the button
	else:
		var target: Vector3 = spot.floor + UP * 1.2
		var eye: Vector3 = spot.floor + UP * 1.7 - _facing() * 4.0
		xf = Transform3D(Basis.looking_at(target - eye, UP), eye)
	_add(shot, _group("Shots"), xf)
	_plan.message = "Shot added where the view is. Use it in a scene with [camera %s]." % shot.name


func _flicker_light() -> void:
	var light := Builders.flicker_light()
	var at: Vector3 = spot.floor + UP * 3.0
	var ceiling: Variant = finder.ceiling_above(spot.floor, 3.3)
	if ceiling != null:
		at = (ceiling as Vector3) - UP * 0.3
	_add(light, _group("Life"), Transform3D(Basis(), at))


func _steam_vent() -> void:
	if spot.wall:
		var vent := Builders.steam_vent(false)
		_add(vent, _group("Life"), _wall_xf(spot.surface + spot.normal * 0.15))
	else:
		var grate := Builders.steam_vent(true)
		_add(grate, _group("Life"), Transform3D(Basis(), spot.floor + UP * 0.05))
		_plan.message = "On a floor it makes a grate; point at a wall for a wall vent."


func _drip() -> void:
	var at: Vector3 = spot.floor + UP * 2.8
	var ceiling: Variant = finder.ceiling_above(spot.floor, 8.0)
	if ceiling != null:
		at = (ceiling as Vector3) - UP * 0.05
	_add(Builders.drip(), _group("Life"), Transform3D(Basis(), at))


func _tv_window() -> void:
	var tv := Builders.tv_window()
	if spot.wall:
		_add(tv, _group("Life"), _wall_xf(spot.surface + spot.normal * 0.03))
	else:
		_add(tv, _group("Life"), Transform3D(_face_basis_x(-_facing()), spot.floor + UP * 1.6))
		_plan.message = "Point at a wall to put the TV window on it."


func _block(b: StaticBody3D) -> void:
	var size: Vector3 = b.get("size")
	var at: Vector3 = spot.floor + UP * size.y * 0.5
	if spot.wall:  # stand it against the wall you pointed at instead of half inside it
		var n: Vector3 = spot.normal
		var flat := Vector3(n.x, 0, n.z).normalized()
		var wall_at: Vector3 = spot.surface
		var half := absf(flat.x) * size.x * 0.5 + absf(flat.z) * size.z * 0.5
		at = Vector3(wall_at.x, at.y, wall_at.z) + flat * half
	var parent := _group("Dressing")
	if selected is StaticBody3D and "size" in selected and selected != root and selected.get_parent() is Node3D:
		parent = selected.get_parent()  # next to the selected Block, like Ctrl+D would
	_add(b, parent, Transform3D(Basis(), at))


func _prop(path: String) -> void:
	var node := Builders.prop(path)
	if node == null:
		_plan.message = "Couldn't load %s right now (see the Output panel)." % path.get_file()
		return
	# Props face +Z, with a wall behind them: against a wall they face out of it, else toward you.
	var face: Vector3 = Vector3(spot.normal.x, 0, spot.normal.z).normalized() if spot.wall else -_facing()
	_add(node, _group("Dressing"), Transform3D(Basis.looking_at(-face, UP), spot.floor))


# --- helpers ------------------------------------------------------------------------------

## Puts `node` on the floor spot, turned the way you look.
func _on_floor(node: Node3D, parent: Node) -> void:
	_add(node, parent, _ground_xf(_facing()))


## Records a step. `xf` is where the node should end up in the world (converted to its parent).
## With global = false it is already local to the parent.
func _add(node: Node3D, parent: Node, xf: Transform3D, global := true) -> void:
	node.name = Query.unique(parent, node.name, _plan.steps)
	if global:
		var parent_xf := root.global_transform
		if parent is Node3D and (parent as Node3D).is_inside_tree():
			parent_xf = (parent as Node3D).global_transform
		node.transform = parent_xf.affine_inverse() * xf
	else:
		node.transform = xf
	var owned: Array[Node] = []
	Query.collect_unowned(node, owned)
	_plan.steps.append({"parent": parent, "node": node, "owned": owned})
	_plan.select = node


## The level's group node with this name (Guards, Checkpoints...); made if it doesn't exist.
func _group(group_name: String) -> Node3D:
	var existing := root.get_node_or_null(group_name) as Node3D
	if existing:
		return existing
	for step: Dictionary in _plan.steps:  # made earlier in this same plan
		if step.parent == root and step.node.name == group_name:
			return step.node
	var g := Node3D.new()
	g.name = group_name
	_add(g, root, Transform3D.IDENTITY, false)
	return g


func _facing() -> Vector3:
	return spot.get("facing", Vector3.FORWARD)


func _spot_is_selection() -> bool:
	return spot.get("from_selection", false)


## On the floor spot, -Z (the way guards and zones face) along `dir`.
func _ground_xf(dir: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(dir, UP), spot.floor)


## On a wall: +X out of the wall along its normal, Y up.
func _wall_xf(at: Vector3) -> Transform3D:
	var n: Vector3 = spot.normal
	return Transform3D(_face_basis_x(Vector3(n.x, 0, n.z).normalized()), at)


static func _face_basis_x(x: Vector3) -> Basis:
	return Basis(x, UP, x.cross(UP))
