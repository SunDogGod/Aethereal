@tool
extends EditorNode3DGizmoPlugin
## Draws each guard's patrol in the 3D view (editor only): an amber loop through the points
## under his Route, in the order he walks them, back to the first.

const Query := preload("res://addons/aethereal_tools/scene_query.gd")


func _init() -> void:
	create_material("route", Color(1.0, 0.76, 0.4), false, true)


func _get_gizmo_name() -> String:
	return "Aethereal patrol route"


func _has_gizmo(node: Node3D) -> bool:
	return Query.is_guard(node)


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var points := route_points(gizmo.get_node_3d())
	if points.size() < 2:
		return
	var lines := PackedVector3Array()
	for i in points.size():
		lines.append(points[i])
		lines.append(points[(i + 1) % points.size()])
		# A post and a small cross at each point, so the points read from any angle.
		lines.append_array([points[i], points[i] + Vector3(0, 0.9, 0)])
		lines.append_array([points[i] + Vector3(-0.25, 0, 0), points[i] + Vector3(0.25, 0, 0)])
		lines.append_array([points[i] + Vector3(0, 0, -0.25), points[i] + Vector3(0, 0, 0.25)])
	gizmo.add_lines(lines, get_material("route", gizmo))


## The guard's patrol points in his own space, lifted a little off the floor.
static func route_points(guard: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	var route := guard.get_node_or_null("Route")
	if route == null or not guard.is_inside_tree():
		return points
	var to_local := guard.global_transform.affine_inverse()
	for m in route.get_children():
		if m is Node3D:
			points.append(to_local * (m as Node3D).global_position + Vector3(0, 0.15, 0))
	return points
