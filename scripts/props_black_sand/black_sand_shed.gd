@tool
extends Node3D
## Isabella and Aeneas's home in Black Sand: nobody built them a house. It is a giant steel module
## (a block of the megastructure, ribbed and cornered like a container) half drowned in the sand,
## that they cut into and made a shed of: a torch-cut doorway with a tarp hung over it and a
## sheet-metal panel to drag across at night, two rough window holes with bars, patches of scrap
## plate over the rust-throughs, a lamp over the door and a guide lamp on a pole on the roof.
## The things inside and in front (beds, stove and stovepipe, belongings) are black_sand_shed_home.gd.
## Origin: the middle of the floor at sand level; the front (door) faces +Z. The walls run `SINK`
## metres down into the sand. Walls get box collision when the game runs (never saved).

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	hull = preload("res://materials/black_sand_hull_worn.tres"), rust = preload("res://materials/black_sand_hull_rust_worn.tres"),
	metal = preload("res://materials/metal_worn.tres"), tarp = preload("res://materials/black_sand_tarp.tres"),
	dark = preload("res://materials/black_sand_void.tres"), warm = preload("res://materials/black_sand_lamp_warm.tres"),
	beacon = preload("res://materials/black_sand_beacon.tres"), rope = preload("res://materials/black_sand_rope.tres"),
	plates = preload("res://materials/metal_plates_worn.tres"), blue = preload("res://materials/tarp.tres"),
}
const L := 16.0    # length along x, outside to outside
const D := 6.3     # depth along z
const H := 6.0     # height of the roof's top above the sand
const T := 0.25    # wall thickness
const SINK := 0.8  # how far the walls go on under the sand
const DOOR := [-1.2, 1.7, 0.0, 2.4]  # [centre x, width, bottom, top] (keep DOOR_X in step in the home script)
const WINDOWS := [[3.8, 1.2, 1.3, 2.2], [-5.4, 1.0, 1.4, 2.1]]

## Box collision for the walls (built when the game runs, never saved in the scene).
@export var solid := true:
	set(value):
		solid = value
		_rebuild()

var _mesh := MeshInstance3D.new()
var _pm: PropMesh
var _boxes: Array = []
var _body: StaticBody3D
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _ready() -> void:
	_apply_collision()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	_pm = PropMesh.new()
	_boxes.clear()
	_shell()
	_ribs()
	_patches()
	_door()
	_roof_things()
	_mesh.mesh = _pm.commit()
	if is_inside_tree():
		_apply_collision()


func _apply_collision() -> void:
	if _body:
		_body.queue_free()
		_body = null
	if not solid or Engine.is_editor_hint():
		return
	_body = StaticBody3D.new()
	add_child(_body, false, INTERNAL_MODE_FRONT)
	for pair in _boxes:
		var shape := BoxShape3D.new()
		shape.size = pair[0]
		var col := CollisionShape3D.new()
		col.shape = shape
		col.transform = pair[1]
		_body.add_child(col)


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


## A box split into ~1 m squares, so the vertex lighting picks up the lamps on big faces.
func _plate(mat: Material, size: Vector3, xf: Transform3D, solid_box := false) -> void:
	var m := BoxMesh.new()
	m.size = size
	m.subdivide_width = int(size.x)
	m.subdivide_height = int(size.y)
	m.subdivide_depth = int(size.z)
	_pm._add(mat, m, xf)
	if solid_box:
		_boxes.append([size, xf])


## The four walls and the roof. The front wall is cut around the door and the window holes.
func _shell() -> void:
	var y0 := -SINK
	var top := H - T
	var fz := D * 0.5 - T * 0.5
	var cuts := [DOOR] + WINDOWS
	cuts.sort_custom(func(a, b): return a[0] < b[0])
	var x := -L * 0.5
	for c in cuts:
		var left: float = c[0] - c[1] * 0.5
		var right: float = c[0] + c[1] * 0.5
		_plate(M.hull, Vector3(left - x, top - y0, T), _at((x + left) * 0.5, (y0 + top) * 0.5, fz), true)
		if c[2] > 0.0:
			_plate(M.hull, Vector3(c[1], c[2] - y0, T), _at(c[0], (y0 + c[2]) * 0.5, fz), true)
		else:
			_boxes.append([Vector3(c[1], 0.3, T), _at(c[0], -0.3, fz)])  # under the doorway's sand
		_plate(M.hull, Vector3(c[1], top - c[3], T), _at(c[0], (c[3] + top) * 0.5, fz), true)
		x = right
	_plate(M.hull, Vector3(L * 0.5 - x, top - y0, T), _at((x + L * 0.5) * 0.5, (y0 + top) * 0.5, fz), true)
	_plate(M.hull, Vector3(L, top - y0, T), _at(0, (y0 + top) * 0.5, -fz), true)  # back
	for sx in [-1, 1]:
		_plate(M.hull, Vector3(T, top - y0, D - 2.0 * T), _at(sx * (L * 0.5 - T * 0.5), (y0 + top) * 0.5, 0), true)
	_plate(M.hull, Vector3(L, T, D), _at(0, H - T * 0.5, 0))  # roof
	# Torch-cut edges: uneven tabs of steel left hanging into the openings, so the holes read as
	# cut by hand, not built.
	for c in cuts:
		var w: float = c[1]
		var tabs := [[-0.32, 0.22, 0.1], [0.05, 0.36, 0.17], [0.36, 0.2, 0.07]]
		for t in tabs:
			_pm.box(M.hull, Vector3(w * t[1], t[2], T * 0.9), _at(c[0] + w * t[0], c[3] - t[2] * 0.5, fz))
		for s in [-1, 1]:
			_pm.box(M.hull, Vector3(0.06 + 0.04 * (s + 1), 0.3 + 0.25 * (s + 1), T * 0.9), _at(c[0] + s * (w * 0.5 - 0.04), c[2] + (c[3] - c[2]) * (0.55 + 0.12 * s), fz))


## What makes it read as a module of the megastructure: corner posts, top and foot rails, ribs.
func _ribs() -> void:
	var post := 0.45
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_pm.box(M.hull, Vector3(post, H + SINK + 0.12, post), _at(sx * (L * 0.5 - post * 0.4), (H - SINK + 0.12) * 0.5, sz * (D * 0.5 - post * 0.4)))
	for sz in [-1, 1]:
		var z: float = sz * (D * 0.5 + 0.06)
		_plate(M.hull, Vector3(L - 0.3, 0.32, 0.14), _at(0, H - 0.2, z))
		for i in range(-3, 4):
			var x: float = i * 2.0 + 1.0 * sz
			if sz > 0 and _in_cut(x, 0.35):
				continue
			_pm.box(M.hull, Vector3(0.2, H - 0.7, 0.1), _at(x, (H - 0.7) * 0.5 + 0.2, sz * (D * 0.5 + 0.05)))
	for sx in [-1, 1]:
		_plate(M.hull, Vector3(0.14, 0.32, D - 0.3), _at(sx * (L * 0.5 + 0.06), H - 0.2, 0))
		for z in [-1.2, 1.2]:
			_pm.box(M.hull, Vector3(0.1, H - 0.7, 0.2), _at(sx * (L * 0.5 + 0.05), (H - 0.7) * 0.5 + 0.2, z))


func _in_cut(x: float, margin: float) -> bool:
	for c in [DOOR] + WINDOWS:
		if absf(x - c[0]) < c[1] * 0.5 + margin:
			return true
	return false


## Scrap plates over the worst rust, each a little skew; bars over the window holes.
func _patches() -> void:
	var fz := D * 0.5 + 0.03
	# [x, y, w, h, tilt (deg), material] on the front, then the back, then the ends.
	for p in [[2.0, 1.0, 1.3, 0.9, 3.0, M.rust], [-4.0, 4.1, 1.5, 1.2, -4.0, M.metal], [6.0, 0.75, 1.4, 1.0, 2.0, M.plates],
			[0.0, 4.6, 1.2, 0.7, 6.0, M.rust], [-6.6, 3.6, 0.9, 1.0, -2.0, M.metal]]:
		_pm.box(p[5], Vector3(p[2], p[3], 0.04), Transform3D(Basis(Vector3.BACK, deg_to_rad(p[4])), Vector3(p[0], p[1], fz)))
	for p in [[-2.0, 1.6, 1.5, 1.2, -3.0, M.metal], [4.0, 3.4, 1.2, 1.5, 4.0, M.rust]]:
		_pm.box(p[5], Vector3(p[2], p[3], 0.04), Transform3D(Basis(Vector3.BACK, deg_to_rad(p[4])), Vector3(p[0], p[1], -fz)))
	for sx in [-1, 1]:
		_pm.box(M.metal if sx < 0 else M.rust, Vector3(0.04, 1.3, 1.6), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(3.0 * sx)), Vector3(sx * (L * 0.5 + 0.03), 1.4 + sx * 0.6, 0.3 * sx)))
	for wdw in WINDOWS:
		var n := 3
		for i in n:
			var x: float = wdw[0] - wdw[1] * 0.5 + wdw[1] * (i + 1) / (n + 1)
			_pm.box(M.metal, Vector3(0.05, wdw[3] - wdw[2] + 0.1, 0.05), _at(x, (wdw[2] + wdw[3]) * 0.5, D * 0.5 - T * 0.5))


## The doorway: a tarp on a pole hung over most of it, the rest tied back in a roll; the steel
## panel they drag across at night leans by the opening; a lamp on a bracket above.
func _door() -> void:
	var x: float = DOOR[0]
	var w: float = DOOR[1]
	var z := D * 0.5 + 0.1
	var top: float = DOOR[3]
	_pm.stick(M.metal, Vector3(x - w * 0.5 - 0.15, top + 0.1, z), Vector3(x + w * 0.5 + 0.15, top + 0.1, z), 0.05)
	var hang := w * 0.35
	_pm.box(M.blue, Vector3(hang, top - 0.05, 0.03), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-2.0)), Vector3(x - w * 0.5 + hang * 0.5, top * 0.5 + 0.08, z + 0.03)))
	_pm.cyl(M.blue, 0.11, 0.09, top - 0.4, _at(x + w * 0.5 - 0.1, top * 0.5 + 0.25, z + 0.06), 6)
	_pm.box(M.rope, Vector3(0.24, 0.04, 0.24), _at(x + w * 0.5 - 0.1, top * 0.55, z + 0.06))
	# The night door: a sheet of plate with two welded handles, leaning on the wall.
	var lean := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-7.0)), Vector3(x + w * 0.5 + 0.85, 1.12, D * 0.5 + 0.27))
	_pm.box(M.rust, Vector3(1.3, 2.25, 0.05), lean)
	for hy in [-0.4, 0.4]:
		_pm.box(M.metal, Vector3(0.06, 0.25, 0.08), lean * _at(-0.45, hy, 0.05))
	# The lamp over the door.
	var lamp := Vector3(x, top + 0.55, D * 0.5 + 0.45)
	_pm.stick(M.metal, Vector3(x, top + 0.75, D * 0.5 + 0.05), lamp + Vector3(0, 0.2, 0), 0.05)
	_pm.cyl(M.metal, 0.06, 0.2, 0.16, _at(lamp.x, lamp.y + 0.08, lamp.z), 8)
	_pm.sphere(M.warm, 0.07, 0.12, _at(lamp.x, lamp.y - 0.02, lamp.z), 6, 3)


## On the roof: the stovepipe's collar, a tarp weighed down by plate offcuts, the guide lamp
## on its pole (red, so it can be told from the town's windows), a cable down the side.
func _roof_things() -> void:
	_pm.box(M.tarp, Vector3(3.2, 0.03, 2.4), Transform3D(Basis(Vector3.UP, 0.08), Vector3(-3.2, H + 0.02, -0.8)))
	for p in [Vector3(-4.6, 0, -1.7), Vector3(-1.8, 0, 0.2), Vector3(-4.4, 0, 0.3)]:
		_pm.box(M.metal, Vector3(0.5, 0.08, 0.4), Transform3D(Basis(Vector3.UP, p.x), Vector3(p.x, H + 0.08, p.z)))
	var pole := Vector3(-7.1, H, 2.5)
	_pm.box(M.metal, Vector3(0.35, 0.06, 0.35), _at(pole.x, H + 0.03, pole.z))
	_pm.stick(M.metal, pole, pole + Vector3(0, 1.8, 0), 0.07)
	_pm.cyl(M.metal, 0.09, 0.12, 0.08, _at(pole.x, H + 1.84, pole.z), 6)
	_pm.sphere(M.beacon, 0.1, 0.16, _at(pole.x, H + 1.94, pole.z), 6, 3)
	_pm.stick(M.rope, pole + Vector3(0, 1.6, 0), Vector3(-L * 0.5 - 0.05, H - 0.3, 2.9), 0.025)
	_pm.stick(M.rope, Vector3(-L * 0.5 - 0.05, H - 0.3, 2.9), Vector3(-L * 0.5 - 0.05, 0.4, 2.7), 0.025)
