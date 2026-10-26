@tool
extends Node3D
## A balcony on a building front: a concrete slab with two brackets under it, a railing (steel
## bars or a solid concrete lip) and what people keep out there, picked from Clutter. The origin
## sits on the wall at the balcony's floor, in the middle; the wall is behind (-Z) and the
## balcony sticks out toward +Z (the same frame as street_prop.gd's wall things). One window bay
## is 3 m wide: put the origin on a slab line under a window. Variant changes colours and details.
## Purely visual unless Solid is on: leave it off for balconies nobody can reach (high on a
## front), turn it on for one the player can walk under or onto.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	slab = preload("res://materials/concrete_worn.tres"), lip = preload("res://materials/concrete_dark_worn.tres"),
	metal = preload("res://materials/metal.tres"), rust = preload("res://materials/pipe_rust.tres"),
	teal = preload("res://materials/paint_teal.tres"), red = preload("res://materials/paint_red.tres"),
	yellow = preload("res://materials/paint_yellow.tres"), cloth = preload("res://materials/white_plaster.tres"),
	wood = preload("res://materials/wood.tres"), pot = preload("res://materials/terracotta.tres"),
	leaf = preload("res://materials/leaf.tres"), dark = preload("res://materials/black_cube.tres"),
	rubber = preload("res://materials/rubber.tres"), awning = preload("res://materials/awning_teal.tres"),
}
const SLAB_T := 0.22  # slab thickness
const RAIL_H := 1.0

@export var width := 2.8:
	set(value):
		width = maxf(value, 0.8)
		_rebuild()
@export var depth := 1.4:
	set(value):
		depth = maxf(value, 0.4)
		_rebuild()
@export_enum("Bars", "Solid lip") var railing := 0:
	set(value):
		railing = value
		_rebuild()
@export_enum("Nothing", "Laundry", "Crates", "Plants", "AC unit", "A bit of everything") var clutter := 0:
	set(value):
		clutter = value
		_rebuild()
## Changes colours and small details, so two balconies don't look identical.
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()
## Collision on the slab and railing. Off for balconies out of reach (most of them).
@export var solid := false:
	set(value):
		solid = value
		_rebuild()
## Not drawn beyond this many metres (0 = always drawn).
@export var draw_distance := 160.0:
	set(value):
		draw_distance = value
		_mesh.visibility_range_end = maxf(value, 0.0)

var _mesh := MeshInstance3D.new()
var _body: StaticBody3D
var _pm: PropMesh
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_mesh.visibility_range_end = draw_distance
	_rebuild()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


func _rebuild_now() -> void:
	_pm = PropMesh.new()
	var hw := width * 0.5
	_pm.box(M.slab, Vector3(width, SLAB_T, depth), _at(0, -SLAB_T * 0.5, depth * 0.5))
	_pm.box(M.lip, Vector3(width, 0.06, 0.06), _at(0, -SLAB_T - 0.03, depth - 0.05))  # drip edge
	for x in [-hw + 0.3, hw - 0.3]:  # two brackets into the wall
		_pm.stick(M.lip, Vector3(x, -SLAB_T, depth * 0.7), Vector3(x, -SLAB_T - 0.5, 0.02), 0.12)
	if railing == 1:
		_lip(hw)
	else:
		_bars(hw)
	match clutter:
		1: _laundry(hw)
		2: _crates(hw)
		3: _plants(hw)
		4: _ac(hw)
		5:  # two of them, by Variant
			var pair: Array = [[_laundry, _plants], [_crates, _ac], [_plants, _ac], [_laundry, _crates]][posmod(variant, 4)]
			for f: Callable in pair:
				f.call(hw)
	_mesh.mesh = _pm.commit()
	_collide()


## Steel posts, a top rail and a mid rail along the front and both sides.
func _bars(hw: float) -> void:
	var mat: Material = [M.cloth, M.rust, M.teal, M.metal][posmod(variant, 4)]
	var d := depth - 0.06
	var corners := [Vector3(-hw + 0.04, 0, 0.02), Vector3(-hw + 0.04, 0, d), Vector3(hw - 0.04, 0, d), Vector3(hw - 0.04, 0, 0.02)]
	for i in 3:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[i + 1]
		var n := maxi(1, ceili(a.distance_to(b) / 0.7))
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			_pm.stick(mat, p, p + Vector3(0, RAIL_H, 0), 0.05)
		for h in [RAIL_H, RAIL_H * 0.5]:
			_pm.stick(mat, a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.07 if h == RAIL_H else 0.04)


## A solid concrete parapet round the front and sides, with a cap.
func _lip(hw: float) -> void:
	var h := RAIL_H * 0.9
	_pm.box(M.slab, Vector3(width, h, 0.1), _at(0, h * 0.5, depth - 0.05))
	for x in [-hw + 0.05, hw - 0.05]:
		_pm.box(M.slab, Vector3(0.1, h, depth - 0.1), _at(x, h * 0.5, (depth - 0.1) * 0.5))
	_pm.box(M.lip, Vector3(width + 0.04, 0.05, 0.14), _at(0, h + 0.025, depth - 0.05))


## Two arms out of the wall, a line between them and washing on it, out past the railing.
func _laundry(hw: float) -> void:
	var y := RAIL_H + 0.7
	var z := depth + 0.25
	for x in [-hw + 0.1, hw - 0.1]:
		_pm.stick(M.metal, Vector3(x, y, 0.0), Vector3(x, y, z), 0.035)
	_pm.stick(M.metal, Vector3(-hw + 0.1, y, z), Vector3(hw - 0.1, y, z), 0.012)
	var cloths: Array = [M.cloth, M.red, M.teal, M.yellow, M.awning]
	var x := -hw + 0.35
	var i := 0
	while x < hw - 0.35:
		var w := 0.35 + 0.15 * posmod(i + variant, 3)
		var h := 0.45 + 0.2 * posmod(i * 2 + variant, 3)
		var mat: Material = cloths[posmod(i + variant, cloths.size())]
		_pm.box(mat, Vector3(w, h, 0.02), Transform3D(Basis(Vector3.UP, 0.08 * (i % 3 - 1)), Vector3(x + w * 0.5, y - h * 0.5, z)))
		x += w + 0.12
		i += 1


func _crates(hw: float) -> void:
	var x := hw - 0.45
	_pm.box(M.wood, Vector3(0.6, 0.45, 0.5), _at(x, 0.225, 0.35))
	_pm.box(M.wood, Vector3(0.5, 0.4, 0.45), Transform3D(Basis(Vector3.UP, 0.25), Vector3(x - 0.05, 0.65, 0.33)))
	_pm.box([M.teal, M.red, M.yellow][posmod(variant, 3)], Vector3(0.45, 0.35, 0.4), _at(x - 0.6, 0.175, 0.3))


func _plants(hw: float) -> void:
	var n := 2 + posmod(variant, 2)
	for i in n:
		var x := -hw * 0.6 + i * 0.45
		var z := depth - 0.3
		_pm.cyl(M.pot, 0.16, 0.12, 0.3, _at(x, 0.15, z), 8)
		for k in 3:
			var a := TAU * k / 3.0 + i + variant
			_pm.sphere(M.leaf, 0.17, 0.26, _at(x + cos(a) * 0.09, 0.45 + k * 0.06, z + sin(a) * 0.09), 6, 3)


## An AC unit standing on the slab against the wall, its fan facing out.
func _ac(hw: float) -> void:
	var x := -hw + 0.6
	_pm.box([M.cloth, M.metal][posmod(variant, 2)], Vector3(0.8, 0.55, 0.32), _at(x, 0.3, 0.2))
	_pm.cyl(M.dark, 0.18, 0.18, 0.01, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x - 0.1, 0.3, 0.365)), 10)
	_pm.stick(M.rubber, Vector3(x + 0.4, 0.4, 0.15), Vector3(x + 0.55, 0.4, 0.15), 0.03)
	_pm.stick(M.rubber, Vector3(x + 0.55, 0.4, 0.15), Vector3(x + 0.55, 0.4, 0.0), 0.03)


## The slab and railing as boxes, when Solid is on.
func _collide() -> void:
	if _body:
		_body.free()
		_body = null
	if not solid:
		return
	_body = StaticBody3D.new()
	add_child(_body, false, INTERNAL_MODE_FRONT)
	var boxes := [[Vector3(width, SLAB_T, depth), Vector3(0, -SLAB_T * 0.5, depth * 0.5)],
		[Vector3(width, RAIL_H, 0.1), Vector3(0, RAIL_H * 0.5, depth - 0.05)],
		[Vector3(0.1, RAIL_H, depth), Vector3(-width * 0.5 + 0.05, RAIL_H * 0.5, depth * 0.5)],
		[Vector3(0.1, RAIL_H, depth), Vector3(width * 0.5 - 0.05, RAIL_H * 0.5, depth * 0.5)]]
	for b in boxes:
		var shape := BoxShape3D.new()
		shape.size = b[0]
		var c := CollisionShape3D.new()
		c.shape = shape
		c.position = b[1]
		_body.add_child(c)
