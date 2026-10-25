@tool
extends Node3D
## A round pipe that follows walls and corners: a straight run between each pair of Points, a
## fat collar at every bend, and a bracket ring every `bracket_every` metres. The Points are
## local to this node: select it, open Points in the Inspector, change a number, and the pipe
## rebuilds. Purely visual (no collision), so keep it off the walked floor or tight to a wall.
## Square ducts are the `_duct` Blocks under the town's Ducts node; this is the round kind.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")

@export var points := PackedVector3Array([Vector3.ZERO, Vector3(0, 3, 0)]):
	set(value):
		points = value
		_rebuild()
@export var radius := 0.1:
	set(value):
		radius = value
		_rebuild()
@export var material: Material = preload("res://materials/pipe_round.tres"):
	set(value):
		material = value
		_rebuild()
## The collars and brackets.
@export var fitting_material: Material = preload("res://materials/trim_rail.tres"):
	set(value):
		fitting_material = value
		_rebuild()
@export var bracket_every := 3.0:
	set(value):
		bracket_every = value
		_rebuild()

var _mesh := MeshInstance3D.new()


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _rebuild() -> void:
	if material == null or points.size() < 2:
		_mesh.mesh = null
		return
	var pm := PropMesh.new()
	var fit: Material = fitting_material if fitting_material else material
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		# Rings along the run so lamps light it per vertex, not just at its ends.
		pm.cyl(material, radius, radius, length, PropMesh.along(a, b), 8, clampi(int(length / 2.0), 0, 12))
		if bracket_every > 0.0:
			var dir := (b - a) / length
			var n := int(length / bracket_every)
			for k in n:
				var at: Vector3 = a + dir * (bracket_every * (k + 0.5))
				pm.cyl(fit, radius * 1.35, radius * 1.35, 0.06, PropMesh.along(at - dir * 0.03, at + dir * 0.03), 8)
	for i in range(1, points.size() - 1):
		pm.sphere(fit, radius * 1.3, radius * 2.6, Transform3D(Basis(), points[i]), 8, 4)
	# End caps: a short wider flange where the pipe meets a wall or the ground.
	for e in [[points[0], points[1]], [points[points.size() - 1], points[points.size() - 2]]]:
		var p: Vector3 = e[0]
		var d: Vector3 = (e[1] - e[0]).normalized()
		pm.cyl(fit, radius * 1.5, radius * 1.5, 0.05, PropMesh.along(p, p + d * 0.05), 8)
	_mesh.mesh = pm.commit()
