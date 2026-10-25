@tool
extends StaticBody3D
## The Empty Town's well, which is really a pipe junction, in two parts (pick Kind):
##   Wellhead: the riser coming up out of a worn concrete collar, a cross fitting at 2.9 m where
##     the two mains leave (round pipe_run.gd pipes in the level, east to the hall and west to the
##     tap), a blind flange and valve wheel on top, a rope wound round it at hand height.
##   Tap basin: where people draw water: a tap cut into the west main's standpipe (which stands
##     0.75 m behind this node, at local -Z) over a round concrete basin of water.
## The node's origin sits on the floor. Solid (a round collider), so fighters walk round it:
## rebake the town's navigation mesh after moving it (scratchpad bake_nav.gd, or the editor).

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	concrete = preload("res://materials/concrete_worn.tres"), dark = preload("res://materials/concrete_dark_worn.tres"),
	pipe = preload("res://materials/pipe_rust.tres"), metal = preload("res://materials/metal_worn.tres"),
	rail = preload("res://materials/trim_rail_worn.tres"), rope = preload("res://materials/wood.tres"),
	water = preload("res://materials/empty_town_water.tres"), pool = preload("res://materials/empty_town_water_still.tres"),
	red = preload("res://materials/paint_red.tres"),
}
const RISER_R := 0.3
const CROSS_Y := 2.9  # where the mains (radius 0.2) leave the riser, east and west
const STANDPIPE := Vector3(0, 0, -0.75)  # the west main's standpipe, from a basin's origin
const STANDPIPE_R := 0.2
const BASIN_R := 0.72
const WATER_Y := 0.42
const SPOUT := Vector3(0, 0.95, -0.3)  # where the water leaves the tap

@export_enum("Wellhead", "Tap basin") var kind := 0:
	set(value):
		kind = value
		_rebuild()

var _mesh := MeshInstance3D.new()


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _rebuild() -> void:
	for c in get_children(true):
		if c is CollisionShape3D:
			c.queue_free()
	var pm := PropMesh.new()
	if kind == 0:
		_wellhead(pm)
	else:
		_basin(pm)
	_mesh.mesh = pm.commit()


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


## A cylinder along X (for the cross fitting's arms).
func _along_x(x0: float, x1: float, y: float, z: float) -> Transform3D:
	return PropMesh.along(Vector3(x0, y, z), Vector3(x1, y, z))


func _collider(radius: float, height: float, y: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position = Vector3(0, y, 0)
	add_child(c, false, INTERNAL_MODE_FRONT)


func _wellhead(pm: PropMesh) -> void:
	pm.cyl(M.concrete, 0.8, 0.85, 0.45, _at(0, 0.225, 0), 12)  # the collar, a little splayed
	pm.cyl(M.dark, 0.84, 0.84, 0.06, _at(0, 0.48, 0), 12)  # its worn cap
	pm.cyl(M.rail, 0.42, 0.42, 0.08, _at(0, 0.55, 0), 12)  # base flange
	for i in 8:  # the flange bolts
		var a := TAU * i / 8.0
		pm.cyl(M.metal, 0.03, 0.03, 0.05, _at(cos(a) * 0.37, 0.61, sin(a) * 0.37), 6)
	pm.cyl(M.pipe, RISER_R, RISER_R, 3.5, _at(0, 2.3, 0), 10, 4)  # the riser
	pm.cyl(M.metal, 0.38, 0.38, 0.6, _at(0, CROSS_Y, 0), 10)  # the cross fitting
	pm.cyl(M.metal, 0.27, 0.27, 0.9, _along_x(-0.45, 0.45, CROSS_Y, 0), 10)  # its arms
	for s in [-1.0, 1.0]:
		pm.cyl(M.rail, 0.3, 0.3, 0.06, _along_x(s * 0.42, s * 0.48, CROSS_Y, 0), 10)  # arm flanges
	pm.cyl(M.rail, 0.42, 0.42, 0.08, _at(0, 4.09, 0), 12)  # blind flange on top (the cables tie on here)
	pm.stick(M.metal, Vector3(0, 4.13, 0), Vector3(0, 4.35, 0), 0.05)  # valve stem
	pm.ring(M.metal, 0.17, 0.22, _at(0, 4.35, 0), 12, 4)  # valve wheel
	pm.stick(M.metal, Vector3(-0.19, 4.35, 0), Vector3(0.19, 4.35, 0), 0.025)
	pm.stick(M.metal, Vector3(0, 4.35, -0.19), Vector3(0, 4.35, 0.19), 0.025)
	for k in 3:  # rope wound round at hand height, worn smooth
		pm.ring(M.rope, RISER_R, RISER_R + 0.045, _at(0, 1.18 + k * 0.05, 0), 12, 4)
	pm.stick(M.rope, Vector3(0.31, 1.15, 0.05), Vector3(0.38, 0.62, 0.22), 0.04)  # its loose end
	_collider(0.85, 0.5, 0.25)
	_collider(RISER_R + 0.02, 3.9, 2.35)


func _basin(pm: PropMesh) -> void:
	# The basin: a ring of short concrete staves (a hollow round trough), a lip, a floor.
	var n := 14
	for i in n:
		var a := TAU * (i + 0.5) / n
		var b := Basis(Vector3.UP, -a)
		var p := Vector3(cos(a), 0, sin(a)) * (BASIN_R - 0.06)
		pm.box(M.concrete, Vector3(0.12, 0.55, TAU * BASIN_R / n + 0.03), Transform3D(b, p + Vector3(0, 0.275, 0)))
		pm.box(M.dark, Vector3(0.16, 0.05, TAU * BASIN_R / n + 0.05), Transform3D(b, p + Vector3(0, 0.575, 0)))
	pm.cyl(M.dark, BASIN_R - 0.1, BASIN_R - 0.1, 0.06, _at(0, 0.03, 0), 12)
	pm.cyl(M.pool, BASIN_R - 0.11, BASIN_R - 0.11, 0.02, _at(0, WATER_Y, 0), 12)  # the water
	# The tap cut into the standpipe: a clamp collar, a stub out, the valve and its handle,
	# an elbow, the spout down over the basin.
	var y := SPOUT.y + 0.15
	var sp := STANDPIPE
	pm.cyl(M.rail, STANDPIPE_R + 0.04, STANDPIPE_R + 0.04, 0.2, _at(sp.x, y, sp.z), 10)
	pm.cyl(M.metal, 0.05, 0.05, 0.3, PropMesh.along(Vector3(0, y, sp.z + STANDPIPE_R), Vector3(0, y, SPOUT.z)), 8)
	pm.box(M.metal, Vector3(0.12, 0.12, 0.12), _at(0, y, sp.z + STANDPIPE_R + 0.12))  # valve body
	pm.stick(M.metal, Vector3(0, y + 0.06, sp.z + 0.32), Vector3(0, y + 0.16, sp.z + 0.32), 0.025)
	pm.stick(M.red, Vector3(-0.09, y + 0.17, sp.z + 0.32), Vector3(0.09, y + 0.17, sp.z + 0.32), 0.035)
	pm.sphere(M.metal, 0.065, 0.13, _at(0, y, SPOUT.z), 8, 4)  # the elbow
	pm.cyl(M.metal, 0.05, 0.05, 0.15, _at(0, SPOUT.y + 0.075, SPOUT.z), 8)
	pm.cyl(M.metal, 0.06, 0.06, 0.03, _at(0, SPOUT.y, SPOUT.z), 8)  # spout lip
	# The water: a thin stream into the basin and the ring where it lands.
	pm.box(M.water, Vector3(0.035, SPOUT.y - WATER_Y, 0.035), _at(0, (SPOUT.y + WATER_Y) * 0.5, SPOUT.z))
	pm.ring(M.water, 0.05, 0.1, _at(0, WATER_Y + 0.012, SPOUT.z), 10, 3)
	_collider(BASIN_R, 0.45, 0.225)
