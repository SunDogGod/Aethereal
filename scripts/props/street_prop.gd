@tool
extends Node3D
## A small street prop built from simple shapes, picked from Kind: plants, bicycles, bins, the
## things people left behind. The node's origin sits on the floor; for things that stand against
## a wall, the wall is behind (-Z) and the prop faces +Z. Change Kind or Variant in the Inspector
## and it rebuilds. Purely visual: no collision, so it never makes a step on a walked floor.
## Rooftop things (tanks, antennas, dishes) are roof_prop.gd.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	pot = preload("res://materials/terracotta.tres"), leaf = preload("res://materials/leaf.tres"),
	soil = preload("res://materials/rubber.tres"), red = preload("res://materials/paint_red.tres"),
	teal = preload("res://materials/paint_teal.tres"), yellow = preload("res://materials/paint_yellow.tres"),
	rubber = preload("res://materials/rubber.tres"), metal = preload("res://materials/metal.tres"),
	ceramic = preload("res://materials/ceramic.tres"), wood = preload("res://materials/wood.tres"),
	plaster = preload("res://materials/white_plaster.tres"), rail = preload("res://materials/trim_rail.tres"),
}

@export_enum("Potted plant", "Tall plant", "Bicycle", "Trash bags", "Bin", "Stool", "Stool (knocked over)",
		"Shoe", "Spilled groceries", "Meal", "Bucket") var kind := 0:
	set(value):
		kind = value
		_rebuild()
## Changes colours and small details, so two of the same Kind don't look identical.
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()
## Not drawn beyond this many metres (0 = always drawn). Small things far off are a pixel or two
## inside the fog anyway, and skipping them keeps the view from the bridge cheap.
@export var draw_distance := 50.0:
	set(value):
		draw_distance = value
		_mesh.visibility_range_end = maxf(value, 0.0)

var _mesh := MeshInstance3D.new()
var _pm: PropMesh


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_mesh.visibility_range_end = draw_distance
	_rebuild()


func _rebuild() -> void:
	_pm = PropMesh.new()
	match kind:
		0: _potted(false)
		1: _potted(true)
		2: _bicycle()
		3: _bags()
		4: _bin()
		5: _stool(false)
		6: _stool(true)
		7: _shoe()
		8: _groceries()
		9: _meal()
		10: _bucket()
	_mesh.mesh = _pm.commit()


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


func _paint() -> Material:
	return [M.red, M.teal, M.yellow][posmod(variant, 3)]


func _potted(tall: bool) -> void:
	var r := 0.2 if not tall else 0.16
	var h := 0.36 if not tall else 0.42
	_pm.cyl(M.pot, r, r * 0.75, h, _at(0, h * 0.5, 0), 8)
	_pm.cyl(M.soil, r * 0.9, r * 0.9, 0.02, _at(0, h - 0.02, 0), 8)
	if tall:
		_pm.stick(M.wood, Vector3(0, h, 0), Vector3(0.02, 1.15, 0), 0.03)
		for i in 4:
			var a := TAU * i / 4.0 + variant
			_pm.sphere(M.leaf, 0.17, 0.26, _at(cos(a) * 0.12, 0.62 + i * 0.15, sin(a) * 0.12), 6, 3)
	else:
		for i in 3:
			var a := TAU * i / 3.0 + variant * 0.7
			_pm.sphere(M.leaf, 0.2, 0.3, _at(cos(a) * 0.1, h + 0.18 + i * 0.05, sin(a) * 0.1), 6, 3)


## Length along X, wheels in the XY plane, leaning a little back toward a wall at -Z.
func _bicycle() -> void:
	var lean := Basis(Vector3.RIGHT, -0.12)
	var w_r := 0.3
	var wheel_xf := Basis(Vector3.RIGHT, PI * 0.5)
	for x in [-0.52, 0.52]:
		_pm.ring(M.rubber, w_r - 0.04, w_r, Transform3D(lean * wheel_xf, lean * Vector3(x, w_r, 0)), 12, 4)
		_pm.stick(M.metal, lean * Vector3(x, w_r, -0.03), lean * Vector3(x, w_r, 0.03), 0.05)  # hub
	var frame: Material = _paint()
	var rear := Vector3(-0.52, w_r, 0)
	var front := Vector3(0.52, w_r, 0)
	var seat := Vector3(-0.2, 0.78, 0)
	var head := Vector3(0.38, 0.8, 0)
	var crank := Vector3(-0.05, 0.32, 0)
	for s in [[rear, seat], [rear, crank], [crank, seat], [seat, head], [crank, head], [head, front]]:
		_pm.stick(frame, lean * s[0], lean * s[1], 0.035)
	_pm.box(M.rubber, Vector3(0.22, 0.05, 0.1), Transform3D(lean, lean * (seat + Vector3(-0.02, 0.06, 0))))
	_pm.stick(M.metal, lean * (head + Vector3(0, 0.12, -0.24)), lean * (head + Vector3(0, 0.12, 0.24)), 0.03)
	_pm.stick(M.metal, lean * head, lean * (head + Vector3(0, 0.12, 0)), 0.03)


func _bags() -> void:
	var n := 2 + posmod(variant, 2)
	for i in n:
		var r := 0.26 - i * 0.03
		var x := -0.25 + i * 0.32
		var z := (i % 2) * 0.12
		_pm.sphere(M.rubber, r, r * 1.5, _at(x, r * 0.75, z), 7, 4)
		_pm.stick(M.rubber, Vector3(x, r * 1.4, z), Vector3(x, r * 1.65, z), 0.05)  # the knot


func _bin() -> void:
	_pm.cyl(M.teal if variant % 2 == 0 else M.metal, 0.26, 0.22, 0.8, _at(0, 0.4, 0), 10, 1)
	_pm.cyl(M.rail, 0.29, 0.29, 0.06, _at(0, 0.83, 0), 10)
	_pm.sphere(M.rubber, 0.2, 0.18, _at(0.05, 0.88, 0.02), 6, 3)  # a bag poking out


func _stool(knocked: bool) -> void:
	var rest := Transform3D()
	if knocked:
		# On its side: the seat's edge and two leg ends on the floor.
		rest = Transform3D(Basis(Vector3.UP, 0.4 + variant) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.17, 0))
	var seat_y := 0.45
	_pm.cyl(M.wood if variant % 2 == 0 else M.red, 0.17, 0.17, 0.05, rest * _at(0, seat_y - 0.025, 0), 10)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var top := Vector3(cos(a) * 0.11, seat_y - 0.05, sin(a) * 0.11)
		var foot := Vector3(cos(a) * 0.15, 0.0, sin(a) * 0.15)
		_pm.stick(M.metal, rest * top, rest * foot, 0.025)


## One small shoe on its side: a child's, by default.
func _shoe() -> void:
	var mat: Material = [M.red, M.yellow, M.teal][posmod(variant, 3)]
	var tilt := Basis(Vector3.RIGHT, 1.25)
	var c := Vector3(0, 0.04, 0)
	_pm.box(mat, Vector3(0.18, 0.06, 0.07), Transform3D(tilt, c))
	_pm.sphere(mat, 0.045, 0.07, Transform3D(tilt, c + Vector3(0.07, 0.005, 0)), 6, 3)
	_pm.box(M.plaster, Vector3(0.185, 0.02, 0.075), Transform3D(tilt, c + tilt * Vector3(0, -0.035, 0)))


## A paper bag on its side and what rolled out of it.
func _groceries() -> void:
	_pm.box(M.wood, Vector3(0.3, 0.22, 0.38), Transform3D(Basis(Vector3.UP, 0.3), Vector3(0, 0.11, 0)))
	_pm.box(M.plaster, Vector3(0.09, 0.16, 0.09), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.28, 0.045, 0.2)))
	var spots := [Vector3(0.45, 0, 0.05), Vector3(0.62, 0, 0.3), Vector3(0.9, 0, 0.18), Vector3(0.35, 0, 0.45), Vector3(1.2, 0, 0.42)]
	for i in spots.size():
		var r := 0.045 + 0.01 * (i % 2)
		var mat: Material = [M.pot, M.leaf, M.yellow, M.red][(i + variant) % 4]
		var p: Vector3 = spots[i]
		_pm.sphere(mat, r, r * 2.0, _at(p.x, r, p.z), 6, 3)


## A bowl half eaten, chopsticks dropped across it, a cup: set it on a ledge or table.
func _meal() -> void:
	_pm.cyl(M.ceramic, 0.09, 0.05, 0.07, _at(0, 0.035, 0), 10)
	_pm.cyl(M.yellow, 0.075, 0.075, 0.01, _at(0, 0.05, 0), 10)
	_pm.stick(M.wood, Vector3(-0.1, 0.075, -0.06), Vector3(0.14, 0.072, 0.05), 0.012)
	_pm.stick(M.wood, Vector3(-0.09, 0.075, -0.03), Vector3(0.15, 0.072, 0.07), 0.012)
	_pm.cyl(M.ceramic, 0.035, 0.03, 0.07, _at(0.2, 0.035, -0.06), 8)


func _bucket() -> void:
	var mat: Material = [M.teal, M.red, M.metal][posmod(variant, 3)]
	_pm.cyl(mat, 0.15, 0.12, 0.28, _at(0, 0.14, 0), 10)
	_pm.ring(M.metal, 0.14, 0.16, _at(0, 0.28, 0), 10, 3)
