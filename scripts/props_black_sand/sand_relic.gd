@tool
extends "res://scripts/props_black_sand/sand_piece.gd"
## The bones of the megastructure sticking out of Black Sand, picked from Kind: a girder stabbing
## out of the sand, a girder frame, a big pipe that rises and dives back in, a leaning mast, a
## bundle of conduits along a hall wall. Length: the girder's, frame's or mast's height above
## the sand, how high the pipe rises before it turns, or how long the conduits run (along X).
## Burying, drift, collision: sand_piece.gd. Whole hulks (a module, a machine) are sand_hulk.gd.

@export_enum("Girder", "Girder frame", "Pipe bend", "Mast", "Wall conduits") var kind := 0:
	set(value):
		kind = value
		_rebuild()


func _build() -> void:
	match kind:
		0: _girder()
		1: _frame()
		2: _pipe_bend()
		3: _mast()
		4: _conduits()


func _drift_spread() -> float:
	return length * 0.45 if kind == 4 else 2.0


## An I-beam from a to b: two flanges and a web, `w` wide; its web faces local X of the frame.
func _beam(mat: Material, a: Vector3, b: Vector3, w: float) -> void:
	var xf := PropMesh.along(a, b)
	var l := a.distance_to(b)
	_pm.box(mat, Vector3(w, l, 0.09), xf * _at(0, 0, w * 0.6))
	_pm.box(mat, Vector3(w, l, 0.09), xf * _at(0, 0, -w * 0.6))
	_pm.box(mat, Vector3(0.1, l, w * 1.2), xf)


## A girder stabbing up out of the sand, its top torn off ragged. Variant 1 bends halfway,
## variant 2 has a splice plate and a stub of crossbeam, variant 3 lies low like a fallen one.
func _girder() -> void:
	var w := 0.6
	var top := Vector3(0, length, 0)
	if variant % 4 == 1:
		var knee := Vector3(0, length * 0.55, 0)
		top = knee + Basis(Vector3.RIGHT, 0.7) * Vector3(0, length * 0.45, 0)
		_beam(M.rust, Vector3(0, -2.5, 0), knee, w)
		_beam(M.rust, knee, top, w)
		_pm.box(M.metal, Vector3(0.9, 0.5, 0.9), _at(0, knee.y, 0.1))  # the crumpled knee
	else:
		_beam(M.rust if variant % 2 == 0 else M.hull, Vector3(0, -2.5, 0), top, w)
	# The torn end: one flange longer than the other, a curl of web.
	var dir := (top - Vector3(0, length * 0.5, 0)).normalized()
	_pm.box(M.rust, Vector3(w, 0.7, 0.09), Transform3D(Basis(Vector3.RIGHT, 0.5), top + dir * 0.3 + Vector3(0, 0, w * 0.6)))
	_pm.box(M.metal, Vector3(0.1, 0.4, 0.5), Transform3D(Basis(Vector3.FORWARD, 0.6), top + dir * 0.15))
	if variant % 4 == 2:
		_pm.box(M.hull, Vector3(0.8, 0.9, 0.04), _at(0, length * 0.35, w * 0.66))
		_beam(M.rust, Vector3(0, length * 0.62, 0), Vector3(2.2, length * 0.62 - 0.6, 0), 0.4)
	# Lightening holes down the web: dark plates a hair proud of it on both sides.
	for i in int(length / 2.0):
		var p := Vector3(0, 0.9 + i * 2.0, 0)
		if p.y < length - 1.0 and variant % 4 != 1:
			_pm.box(M.hole, Vector3(0.12, 0.45, 0.4), _at(0, p.y, 0))
	_boxes.append([Vector3(1.0, 3.0, 1.0), _at(0, 1.0, 0)])


## Two girders standing `length` tall 5 m apart, a beam across, a brace: part of a frame whose
## other half is under the sand. Variant 1: the crossbeam has come down at one end.
func _frame() -> void:
	var w := 0.55
	for x in [-2.5, 2.5]:
		var h := length if x < 0 or variant % 2 == 0 else length * 0.7
		_beam(M.rust, Vector3(x, -2.5, 0), Vector3(x, h, 0), w)
		_boxes.append([Vector3(0.9, 3.0, 0.9), _at(x, 1.0, 0)])
	if variant % 2 == 0:
		_beam(M.hull, Vector3(-2.9, length - 0.4, 0), Vector3(2.9, length - 0.4, 0), w)
	else:
		_beam(M.hull, Vector3(-2.6, length - 0.4, 0), Vector3(2.8, -0.3, 0.3), w)
	_beam(M.metal, Vector3(-2.4, 0.6, 0), Vector3(2.4, length * 0.6, 0), 0.25)
	for x in [-2.5, 2.5]:  # gusset plates where the beams meet
		_pm.box(M.hull, Vector3(1.0, 1.0, 0.04), _at(x * 0.88, length - 0.8, w * 0.7))


## A big pipe (0.9 m round) rising `length` out of the sand, turning, running 6 m and diving back
## in. Flanges at the joints, rust bands. Variant 1: the far end is broken off, a dark mouth.
func _pipe_bend() -> void:
	var r := 0.9
	var h := length
	_pm.cyl(M.pipe, r, r, h + 2.0 - r, _at(0, (h - r - 2.0) * 0.5, 0), 12)
	_bend(Vector3(0, h - r, 0), r, 1.0)
	var run := 6.0
	_pm.cyl(M.pipe, r, r, run - 2.0 * r, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(run * 0.5, h, 0)), 12)
	if variant % 2 == 0:
		_bend(Vector3(run, h - r, 0), r, -1.0)
		_pm.cyl(M.pipe, r, r, h + 2.0 - r, _at(run, (h - r - 2.0) * 0.5, 0), 12)
		_boxes.append([Vector3(r * 2, h + r, r * 2), _at(run, (h + r) * 0.5 - 0.5, 0)])
	else:
		_pm.cyl(M.rust, r * 1.15, r * 1.15, 0.2, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(run - r, h, 0)), 12)
		_pm.cyl(M.hole, r * 0.85, r * 0.85, 0.05, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(run - r + 0.11, h, 0)), 12)
	for y in [0.4, h * 0.5]:  # flanges and a rust band
		_pm.cyl(M.rust, r * 1.12, r * 1.12, 0.22, _at(0, y, 0), 12)
	_pm.cyl(M.rust, r * 1.12, r * 1.12, 0.22, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(run * 0.5, h, 0)), 12)
	_boxes.append([Vector3(r * 2, h + r, r * 2), _at(0, (h + r) * 0.5 - 0.5, 0)])
	_boxes.append([Vector3(run, r * 2, r * 2), _at(run * 0.5, h, 0)])


## A quarter bend from straight up to along +X (dir 1) or from along X to straight down (dir -1),
## as three short cylinders: `c` is where the straight upright part ends.
func _bend(c: Vector3, r: float, dir: float) -> void:
	for i in 3:
		var a := (i + 0.5) / 3.0 * PI * 0.5
		var p := c + Vector3(dir * (r - r * cos(a)), r * sin(a), 0)
		_pm.cyl(M.pipe, r, r, r * 0.62, Transform3D(Basis(Vector3.FORWARD, -dir * a), p), 12)


## A mast `length` tall leaning out of the sand: two cross-arms, a dish, insulators, and guy
## wires running down to stakes, a red warning lamp on top (black_sand_beacon: a glow_pulse.gd
## in Blink mode makes it blink). Thin, so never solid.
func _mast() -> void:
	_pm.cyl(M.metal, 0.14, 0.2, length + 2.0, _at(0, length * 0.5 - 1.0, 0), 8)
	_pm.box(M.beacon, Vector3(0.22, 0.22, 0.22), _at(0, length + 0.1, 0))
	for y in [length * 0.75, length * 0.92]:
		_pm.box(M.rust, Vector3(2.4, 0.12, 0.12), _at(0, y, 0))
		for x in [-1.1, 1.1]:
			_pm.cyl(M.dead, 0.06, 0.06, 0.3, _at(x, y - 0.2, 0), 6)
	_pm.cyl(M.hull, 0.9, 0.2, 0.35, Transform3D(Basis(Vector3.RIGHT, 1.1), Vector3(0, length * 0.6, 0.45)), 10)
	_pm.stick(M.metal, Vector3(0, length * 0.6, 0.2), Vector3(0, length * 0.6 + 0.3, 1.0), 0.04)
	var r := _rng(5)
	for i in 3:
		var a := TAU * i / 3.0 + r.randf_range(-0.3, 0.3)
		var foot := Vector3(cos(a), 0, sin(a)) * length * 0.55
		_pm.stick(M.rubber, Vector3(0, length * 0.85, 0), foot, 0.025)
		_pm.stick(M.metal, foot + Vector3(0, -0.3, 0), foot + Vector3(0, 0.4, 0), 0.08)


## Three conduits `length` long along X against a wall at -Z, on brackets, the lowest half buried.
func _conduits() -> void:
	var rows := [[0.2, 0.55, M.pipe], [1.5, 0.35, M.hull], [2.4, 0.25, M.rust]]
	for row in rows:
		_pm.cyl(row[2], row[1], row[1], length, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, row[0], 0.8)), 10)
	var n := int(length / 4.0) + 1
	for i in n:
		var x := -length * 0.5 + 0.5 + i * (length - 1.0) / maxf(n - 1, 1)
		_pm.box(M.metal, Vector3(0.16, 3.0, 0.16), _at(x, 1.3, 1.25))
		for row in rows:
			_pm.box(M.metal, Vector3(0.12, 0.12, 1.3), _at(x, row[0] + row[1] + 0.06, 0.65))
		_pm.box(M.hull, Vector3(0.5, 0.6, 0.06), _at(x, 2.4, 0.03))  # the plate on the wall
	_boxes.append([Vector3(length, 2.8, 1.8), _at(0, 1.1, 0.8)])


