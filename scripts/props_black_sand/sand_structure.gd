@tool
extends Node3D
## The old infrastructure of the megastructure, half swallowed by the dunes, picked from Kind:
## a support column running up into the haze, a lattice pylon, a vent stack, a length of pipeline,
## a road tunnel mouth in the hall wall, a giant curved rib. Origin on the sand; each kind reaches
## a few metres below it, so the sand can bury its foot. With Solid on, it gets box collision
## (built when the game runs, never saved in the scene). Wrecks are sand_wreck.gd.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	metal = preload("res://materials/metal.tres"), hull = preload("res://materials/black_sand_hull.tres"),
	rust = preload("res://materials/black_sand_hull_rust.tres"), mega = preload("res://materials/black_sand_mega.tres"),
	grating = preload("res://materials/grating.tres"), hole = preload("res://materials/black_sand_void.tres"),
	beacon = preload("res://materials/black_sand_beacon.tres"), lens = preload("res://materials/precursor_light.tres"),
	stone = preload("res://materials/black_sand_stone.tres"), rubber = preload("res://materials/rubber.tres"),
}

@export_enum("Column", "Pylon", "Vent stack", "Pipe segment", "Tunnel mouth", "Rib") var kind := 0:
	set(value):
		kind = value
		_rebuild()
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()
## Column and Pylon: height above the sand. Pipe segment: its length (along X).
@export var length := 60.0:
	set(value):
		length = value
		_rebuild()
## Pipe segment: its radius (the camp's pipe is 4 m; a slimmer line is 1.7).
@export var radius := 1.7:
	set(value):
		radius = value
		_rebuild()
## Box collision for the parts you could walk into.
@export var solid := true:
	set(value):
		solid = value
		_rebuild()

var _mesh := MeshInstance3D.new()
var _pm: PropMesh
var _boxes: Array = []  # [size, Transform3D] pairs for the collision
var _body: StaticBody3D


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _ready() -> void:
	_apply_collision()


func _rebuild() -> void:
	_pm = PropMesh.new()
	_boxes.clear()
	match kind:
		0: _column()
		1: _pylon()
		2: _vent()
		3: _pipe()
		4: _tunnel()
		5: _rib()
	_mesh.mesh = _pm.commit()
	if is_inside_tree():
		_apply_collision()


## One StaticBody3D (layer 1, like the Blocks) with a box per solid part.
func _apply_collision() -> void:
	if _body:
		_body.queue_free()
		_body = null
	if not solid or _boxes.is_empty():
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


## A box that is drawn and also solid.
func _solid(mat: Material, size: Vector3, xf: Transform3D) -> void:
	_pm.box(mat, size, xf)
	_boxes.append([size, xf])


## A square support column, 7 m across, from 6 m under the sand up `length` metres: a wide
## buried plinth, recessed bands every 12 m, a ladder cage up one face, beacon housings.
func _column() -> void:
	var w := 7.0 + (variant % 2)
	_solid(M.mega, Vector3(w, length + 6.0, w), _at(0, length * 0.5 - 3.0, 0))
	_pm.box(M.mega, Vector3(w + 2.4, 5.0, w + 2.4), _at(0, -1.5, 0))  # the plinth, mostly buried
	_boxes.append([Vector3(w + 2.4, 5.0, w + 2.4), _at(0, -1.5, 0)])
	var y := 12.0
	while y < length - 2.0:
		_pm.box(M.hull, Vector3(w + 0.5, 0.8, w + 0.5), _at(0, y, 0))  # a band of plating
		y += 12.0
	# The ladder cage on the +Z face: two rails and a hoop every 3 m, from 3 m up.
	for x in [-0.35, 0.35]:
		_pm.box(M.metal, Vector3(0.08, length - 4.0, 0.08), _at(x, length * 0.5 + 1.0, w * 0.5 + 0.35))
	var hy := 4.0
	while hy < length - 2.0:
		_pm.box(M.metal, Vector3(0.9, 0.06, 0.06), _at(0, hy, w * 0.5 + 0.75))
		hy += 3.0
	for k in [0.42, 0.78]:  # beacon housings; the blinking lamps are separate nodes
		_pm.box(M.hull, Vector3(1.0, 0.6, 0.5), _at(w * 0.5 - 1.0, length * k - 0.7, w * 0.5 + 0.25))


## A lattice power pylon `length` m tall: four splayed legs, cross bracing, two cross-arms with
## insulator strings. Its cables are separate (cable_run.gd) nodes.
func _pylon() -> void:
	var h := length
	var base := 2.6
	var top := 0.7
	var legs: Array[Vector3] = []
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			legs.append(Vector3(sx, 0, sz))
	for l in legs:
		var a := Vector3(l.x * base, -1.5, l.z * base)
		var b := Vector3(l.x * top, h, l.z * top)
		_pm.stick(M.metal, a, b, 0.22)
		_boxes.append([Vector3(0.5, 3.0, 0.5), _at(l.x * base * 0.95, 0.0, l.z * base * 0.95)])
	var levels := 6
	for i in levels:  # X bracing on each face, level by level
		var t0 := float(i) / levels
		var t1 := float(i + 1) / levels
		var y0 := lerpf(-1.5, h, t0)
		var y1 := lerpf(-1.5, h, t1)
		var r0 := lerpf(base, top, t0)
		var r1 := lerpf(base, top, t1)
		for f in 4:
			var d0 := Vector3(1, 0, 1) if f == 0 else (Vector3(1, 0, -1) if f == 1 else (Vector3(-1, 0, -1) if f == 2 else Vector3(-1, 0, 1)))
			var d1 := Vector3(-d0.z, 0, d0.x)
			_pm.stick(M.metal, Vector3(d0.x * r0, y0, d0.z * r0), Vector3(d1.x * r1, y1, d1.z * r1), 0.08)
			_pm.stick(M.metal, Vector3(d1.x * r0, y0, d1.z * r0), Vector3(d0.x * r1, y1, d0.z * r1), 0.08)
	for k in [0.82, 0.96]:
		var y: float = h * k
		var span: float = 5.5 if k < 0.9 else 4.0
		_pm.box(M.metal, Vector3(span * 2.0, 0.3, 0.3), _at(0, y, 0))
		for s in [-1, 1]:
			_pm.stick(M.metal, Vector3(s * span, y, 0), Vector3(s * top, y + 1.6, 0), 0.1)
			_pm.cyl(M.stone, 0.12, 0.12, 1.0, _at(s * (span - 0.3), y - 0.6, 0), 6, 2)  # insulators


## A squat vent stack poking out of the sand: a ribbed shaft, a louvred hood, a grille on top.
## Put a steam_vent.gd node just above it for the plume.
func _vent() -> void:
	var r := 1.6 + 0.3 * (variant % 2)
	var h := 5.0 + variant % 3
	_pm.cyl(M.mega, r, r * 1.15, h + 3.0, _at(0, h * 0.5 - 1.5, 0), 12, 2)
	_boxes.append([Vector3(r * 1.6, h + 3.0, r * 1.6), _at(0, h * 0.5 - 1.5, 0)])
	for k in 3:
		_pm.cyl(M.hull, r * 1.08, r * 1.08, 0.35, _at(0, 1.0 + k * 1.6, 0), 12)
	_pm.cyl(M.rust, r * 1.25, r * 1.25, 0.25, _at(0, h, 0), 12)
	_pm.cyl(M.grating, r * 0.95, r * 0.95, 0.06, _at(0, h + 0.1, 0), 12)
	_pm.cyl(M.hole, r * 0.9, r * 0.9, 0.04, _at(0, h + 0.02, 0), 12)


## A pipeline `length` along local X, `radius` round, its flanges, saddles under it. Variant 1
## ends broken open at +X: a dark mouth you can see into.
func _pipe() -> void:
	var r := radius
	var along_x := Basis(Vector3.FORWARD, PI * 0.5)
	_pm.cyl(M.rust if variant % 2 == 1 else M.hull, r, r, length, Transform3D(along_x, Vector3.ZERO), 12, int(length / 4.0))
	_boxes.append([Vector3(length, r * 1.7, r * 1.7), _at(0, 0, 0)])
	var n := int(length / 9.0)
	for i in n + 1:
		var x := -length * 0.5 + length * i / maxf(1.0, n)
		if variant % 2 == 1 and i == n:
			continue
		_pm.cyl(M.metal, r * 1.12, r * 1.12, 0.4, Transform3D(along_x, Vector3(x, 0, 0)), 12)  # flange
	for i in n:
		var x := -length * 0.5 + length * (i + 0.5) / maxf(1.0, n)
		_pm.box(M.metal, Vector3(0.5, r * 1.2, r * 2.4), _at(x, -r * 0.8, 0))  # saddle
	if variant % 2 == 1:
		_pm.cyl(M.hole, r * 0.92, r * 0.92, 0.1, Transform3D(along_x, Vector3(length * 0.5 - 0.6, 0, 0)), 12)
		for k in 3:  # torn plating around the mouth
			var a := TAU * k / 3.0 + 0.5
			_pm.box(M.rust, Vector3(1.4, 0.08, 0.9), Transform3D(Basis(Vector3.RIGHT, a) * Basis(Vector3.FORWARD, 0.3),
					Vector3(length * 0.5 + 0.4, sin(a) * r, cos(a) * r)))


## Where the road runs into the hall wall: two piers and a lintel framing a dark mouth, a
## shutter stuck a third of the way down, lamp housings. Faces +Z; the wall is behind (-Z).
func _tunnel() -> void:
	var w := 14.0
	var h := 10.0
	for s in [-1, 1]:
		_solid(M.mega, Vector3(3.0, h + 6.0, 2.5), _at(s * (w * 0.5 + 1.5), h * 0.5 - 2.0, 1.25))
	_solid(M.mega, Vector3(w + 6.0, 4.0, 2.5), _at(0, h + 2.0, 1.25))
	_pm.box(M.hole, Vector3(w, h + 2.0, 0.2), _at(0, h * 0.5 - 1.0, 0.1))
	_pm.box(M.hull, Vector3(w, h * 0.35, 0.3), _at(0, h - h * 0.175, 0.5))  # the shutter
	for k in 6:
		_pm.box(M.metal, Vector3(w, 0.06, 0.05), _at(0, h - 0.4 - k * 0.55, 0.67))
	for s in [-1, 1]:
		_pm.box(M.hull, Vector3(0.8, 0.5, 0.6), _at(s * (w * 0.5 + 1.5), h + 0.6, 2.75))
		_pm.box(M.beacon, Vector3(0.5, 0.25, 0.1), _at(s * (w * 0.5 + 1.5), h + 0.6, 3.1))


## A giant curved rib of some buried frame, arching out of the sand and back in: a chain of
## girder boxes on a half-ellipse `length` m across and half as tall, plated on its outer face.
func _rib() -> void:
	var n := 14
	var rx := length * 0.5
	var ry := length * 0.42
	var prev := Vector3(-rx, -2.0, 0)
	for i in range(1, n + 1):
		var a := PI * (1.0 - float(i) / n)
		var p := Vector3(cos(a) * rx, sin(a) * ry - 2.0, 0)
		var seg := p - prev
		var xf := PropMesh.along(prev, p)
		_pm.box(M.hull if i % 3 != 0 else M.rust, Vector3(1.4, seg.length() + 0.3, 1.0), xf)
		_pm.box(M.metal, Vector3(0.5, seg.length() * 0.8, 1.3), xf)
		if i <= 2 or i >= n - 1:
			_boxes.append([Vector3(1.4, seg.length(), 1.2), xf])
		prev = p
