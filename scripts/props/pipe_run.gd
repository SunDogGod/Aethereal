@tool
extends Node3D
## A pipe that follows walls and corners: a straight run between each pair of Points, a fat
## collar at every bend, and a bracket every `bracket_every` metres. The Points are local to
## this node: select it, open Points in the Inspector, change a number, and the pipe rebuilds.
## Round by default; Square makes it a box duct (Radius is then half its width) with a cube
## elbow at every bend and a strap at every bracket. Wall Side (a direction, local) is where the
## wall is: each bracket then reaches back to the wall on an arm with a plate, Wall Gap metres
## behind the pipe. End a run inside a wall (or the ground) and it reads as going in.
## Purely visual unless Solid is on: keep collision off for pipes up a front out of reach, on
## for one the player can walk into.
## The town's older square ducts are the `_duct` Blocks under its Ducts node.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")

@export var points := PackedVector3Array([Vector3.ZERO, Vector3(0, 3, 0)]):
	set(value):
		points = value
		_rebuild()
@export var radius := 0.1:
	set(value):
		radius = value
		_rebuild()
@export var square := false:  ## a box duct instead of a round pipe
	set(value):
		square = value
		_rebuild()
@export var material: Material = preload("res://materials/pipe_round.tres"):
	set(value):
		material = value
		_rebuild()
## The collars, straps and brackets.
@export var fitting_material: Material = preload("res://materials/trim_rail.tres"):
	set(value):
		fitting_material = value
		_rebuild()
@export var bracket_every := 3.0:
	set(value):
		bracket_every = value
		_rebuild()
## Where the wall is (local direction, e.g. 0, 0, -1). Zero = no arms, just collars.
@export var wall_side := Vector3.ZERO:
	set(value):
		wall_side = value
		_rebuild()
@export var wall_gap := 0.12:  ## metres between the pipe's surface and the wall
	set(value):
		wall_gap = value
		_rebuild()
@export var solid := false:  ## collision along the runs
	set(value):
		solid = value
		_rebuild()
## Not drawn beyond this many metres (0 = always drawn).
@export var draw_distance := 0.0:
	set(value):
		draw_distance = value
		_mesh.visibility_range_end = maxf(value, 0.0)

var _mesh := MeshInstance3D.new()
var _body: StaticBody3D
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	_mesh.visibility_range_end = maxf(draw_distance, 0.0)
	if material == null or points.size() < 2:
		_mesh.mesh = null
		_collide()
		return
	var pm := PropMesh.new()
	var fit: Material = fitting_material if fitting_material else material
	var wall := wall_side.normalized()
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		# Rings along the run so lamps light it per vertex, not just at its ends.
		if square:
			pm.box(material, Vector3(radius * 2.0, length, radius * 2.0), PropMesh.along(a, b))
		else:
			pm.cyl(material, radius, radius, length, PropMesh.along(a, b), 8, clampi(int(length / 2.0), 0, 12))
		if bracket_every > 0.0:
			var dir := (b - a) / length
			var n := int(length / bracket_every)
			for k in n:
				var at: Vector3 = a + dir * (bracket_every * (k + 0.5))
				_bracket(pm, fit, at, dir, wall)
	for i in range(1, points.size() - 1):
		if square:
			pm.box(fit, Vector3.ONE * radius * 2.3, Transform3D(Basis(), points[i]))
		else:
			pm.sphere(fit, radius * 1.3, radius * 2.6, Transform3D(Basis(), points[i]), 8, 4)
	# End caps: a short wider flange where the pipe meets a wall or the ground.
	for e in [[points[0], points[1]], [points[points.size() - 1], points[points.size() - 2]]]:
		var p: Vector3 = e[0]
		var d: Vector3 = (e[1] - e[0]).normalized()
		if square:
			pm.box(fit, Vector3(radius * 2.5, 0.06, radius * 2.5), PropMesh.along(p, p + d * 0.06))
		else:
			pm.cyl(fit, radius * 1.5, radius * 1.5, 0.05, PropMesh.along(p, p + d * 0.05), 8)
	_mesh.mesh = pm.commit()
	_collide()


## A collar or strap round the pipe at `at`, and an arm back to the wall when Wall Side is set.
func _bracket(pm: PropMesh, fit: Material, at: Vector3, dir: Vector3, wall: Vector3) -> void:
	if square:
		pm.box(fit, Vector3(radius * 2.2, 0.07, radius * 2.2), PropMesh.along(at - dir * 0.035, at + dir * 0.035))
	else:
		pm.cyl(fit, radius * 1.35, radius * 1.35, 0.06, PropMesh.along(at - dir * 0.03, at + dir * 0.03), 8)
	if wall == Vector3.ZERO or absf(wall.dot(dir)) > 0.9:
		return
	var back := at + wall * (radius + wall_gap)
	pm.stick(fit, at + wall * radius * 0.8, back, maxf(0.04, radius * 0.3))
	var plate := maxf(0.12, radius * 1.2)
	pm.box(fit, Vector3(plate, 0.03, plate), PropMesh.along(back - wall * 0.03, back))


## Boxes (square) or cylinders (round) along the runs, when Solid is on.
func _collide() -> void:
	if _body:
		_body.free()
		_body = null
	if not solid or points.size() < 2:
		return
	_body = StaticBody3D.new()
	add_child(_body, false, INTERNAL_MODE_FRONT)
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var c := CollisionShape3D.new()
		if square:
			var box := BoxShape3D.new()
			box.size = Vector3(radius * 2.0, length + radius * 2.0, radius * 2.0)
			c.shape = box
		else:
			var cyl := CylinderShape3D.new()
			cyl.radius = radius
			cyl.height = length + radius * 2.0
			c.shape = cyl
		c.transform = PropMesh.along(a, b)
		_body.add_child(c)
