@tool
extends "res://scripts/props_black_sand/sand_piece.gd"
## Whole hulks half drowned in Black Sand, picked from Kind: a module like the family's shed lying
## on its side, a dead machine with one lamp still lit, a tank, a balcony fallen from the town
## above. Length: the module's or tank's length along X (the machine and balcony ignore it).
## Burying, drift, collision: sand_piece.gd. Girders, pipes and masts are sand_relic.gd.

@export_enum("Module", "Machine", "Tank", "Fallen balcony") var kind := 0:
	set(value):
		kind = value
		_rebuild()


func _build() -> void:
	match kind:
		0: _module()
		1: _machine()
		2: _tank()
		3: _balcony()


func _drift_spread() -> float:
	return length * 0.45 if kind in [0, 2] else 2.2


## A module like the one the family lives in, `length` long, 4 x 4, lying half drowned: ribbed
## walls, corner posts, a hatch, and one end burst open on a dark inside.
func _module() -> void:
	var l := length
	var hw := 2.0
	var h := 4.0
	_pm.box(M.hole, Vector3(l - 0.4, h - 0.4, hw * 2.0 - 0.4), _at(0, h * 0.5, 0))  # the dark inside
	for s in [-1, 1]:
		_pm.box(M.hull, Vector3(l, h, 0.12), _at(0, h * 0.5, s * hw))
	_pm.box(M.hull, Vector3(l, 0.12, hw * 2.0), _at(0, h, 0))
	_pm.box(M.hull, Vector3(0.12, h, hw * 2.0), _at(-l * 0.5, h * 0.5, 0))
	# The +X end, burst: a lower lip and one bent leaf, the dark inside behind.
	_pm.box(M.rust, Vector3(0.12, 1.1, hw * 2.0), _at(l * 0.5, 0.55, 0))
	_pm.box(M.rust, Vector3(0.12, 2.4, 1.6), Transform3D(Basis(Vector3.UP, 0.9), Vector3(l * 0.5 + 0.55, 2.1, hw - 0.5)))
	for cx in [-1, 1]:  # corner posts and rails
		for cz in [-1, 1]:
			_pm.box(M.metal, Vector3(0.3, h + 0.1, 0.3), _at(cx * (l * 0.5 - 0.1), h * 0.5, cz * (hw - 0.05)))
		_pm.box(M.metal, Vector3(l, 0.25, 0.3), _at(0, h - 0.05, cx * (hw - 0.05)))
	var ribs := int(l / 1.3)
	for i in ribs:  # vertical ribs on the long walls
		var x := -l * 0.5 + 0.65 + i * (l - 1.3) / maxf(ribs - 1, 1)
		for s in [-1, 1]:
			_pm.box(M.rust if (i + variant) % 3 == 0 else M.hull, Vector3(0.14, h - 0.3, 0.1), _at(x, h * 0.5, s * (hw + 0.08)))
	# A hatch on the +Z wall with a wheel, and a stencil band.
	_pm.box(M.metal, Vector3(1.2, 1.9, 0.08), _at(-l * 0.25, 1.4, hw + 0.15))
	_pm.ring(M.rust, 0.18, 0.24, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-l * 0.25, 1.4, hw + 0.24)), 10, 3)
	_pm.box(M.yellow, Vector3(1.6, 0.25, 0.02), _at(l * 0.2, h - 0.6, hw + 0.07))
	_boxes.append([Vector3(l, h, hw * 2.0), _at(0, h * 0.5, 0)])


## A dead machine: a housing with a flywheel standing out of one side, two cylinders with their
## rods, a gearbox, an exhaust stack, a panel of dead gauges with one lamp still faintly lit
## (black_sand_beacon: point a glow_pulse.gd at it to make it blink).
func _machine() -> void:
	_pm.box(M.hull, Vector3(3.6, 2.4, 2.2), _at(0, 1.0, 0))
	_pm.box(M.rust, Vector3(3.8, 0.3, 2.4), _at(0, 2.3, 0))
	# The flywheel on the -Z side: rim, hub, six spokes.
	var fx := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.6, 1.7, -1.45))
	_pm.ring(M.rust, 1.15, 1.45, fx, 16, 4)
	_pm.cyl(M.metal, 0.25, 0.25, 0.5, fx, 8)
	for i in 6:
		var a := TAU * i / 6.0 + 0.2 * variant
		_pm.stick(M.rust, Vector3(-0.6, 1.7, -1.45), Vector3(-0.6 + cos(a) * 1.2, 1.7 + sin(a) * 1.2, -1.45), 0.14)
	# Two cylinders on top and their rods to a crank box.
	for i in 2:
		var x := 0.5 + i * 0.9
		_pm.cyl(M.metal, 0.35, 0.35, 1.1, _at(x, 2.95, 0.3), 10)
		_pm.cyl(M.rust, 0.42, 0.42, 0.12, _at(x, 3.5, 0.3), 10)
		_pm.stick(M.metal, Vector3(x, 3.5, 0.3), Vector3(x + 0.3, 2.6, -0.8), 0.1)
	_pm.box(M.rust, Vector3(1.6, 0.6, 0.6), _at(0.9, 2.6, -0.85))
	_pm.cyl(M.pipe, 0.25, 0.3, 2.6, _at(-1.4, 3.3, 0.6), 8)  # exhaust stack
	_pm.cyl(M.rust, 0.33, 0.33, 0.2, _at(-1.4, 4.55, 0.6), 8)
	# The gauge panel on the +Z face: dead dials and the one live lamp.
	_pm.box(M.metal, Vector3(1.4, 0.8, 0.08), _at(0.8, 1.5, 1.12))
	for i in 3:
		_pm.cyl(M.dead, 0.13, 0.13, 0.05, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.35 + i * 0.4, 1.6, 1.17)), 8)
	_pm.box(M.beacon, Vector3(0.1, 0.1, 0.06), _at(1.35, 1.3, 1.17))
	# Pipes leaving it into the sand.
	_pm.cyl(M.pipe, 0.22, 0.22, 2.2, Transform3D(Basis(Vector3.FORWARD, 1.1), Vector3(2.4, 0.3, 0.4)), 8)
	_pm.cyl(M.pipe, 0.16, 0.16, 1.8, Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3(-0.8, 0.3, 1.5)), 8)
	_boxes.append([Vector3(3.6, 2.6, 2.2), _at(0, 1.0, 0)])
	_boxes.append([Vector3(2.9, 2.9, 0.6), _at(-0.6, 1.7, -1.45)])


## A tank `length` long lying along X, 2.2 m round, half sunk: bands, a manhole and a ladder.
func _tank() -> void:
	var r := 2.2
	var along := Basis(Vector3.FORWARD, PI * 0.5)
	_pm.cyl(M.hull, r, r, length, Transform3D(along, Vector3(0, r * 0.5, 0)), 14)
	for i in 3:
		var x := -length * 0.5 + 0.4 + i * (length - 0.8) * 0.5
		_pm.cyl(M.rust, r + 0.06, r + 0.06, 0.3, Transform3D(along, Vector3(x, r * 0.5, 0)), 14)
	for s in [-1, 1]:  # domed ends
		_pm.sphere(M.hull, r, r * 0.8, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(s * length * 0.5, r * 0.5, 0)), 14, 5)
	_pm.cyl(M.metal, 0.45, 0.45, 0.3, _at(length * 0.2, r * 1.5 + 0.1, 0), 10)
	_pm.cyl(M.rust, 0.5, 0.5, 0.08, _at(length * 0.2, r * 1.5 + 0.28, 0), 10)
	for s in [-0.25, 0.25]:  # a ladder down the +Z side into the sand
		_pm.stick(M.metal, Vector3(length * 0.2 + s, r * 1.45, 0.5), Vector3(length * 0.2 + s, -0.3, r + 0.2), 0.06)
	for i in 5:
		var t := (i + 0.5) / 5.0
		var p := Vector3(length * 0.2, r * 1.45, 0.5).lerp(Vector3(length * 0.2, -0.3, r + 0.2), t)
		_pm.box(M.metal, Vector3(0.5, 0.05, 0.05), _at(p.x, p.y, p.z))
	_boxes.append([Vector3(length + r, r * 1.4, r * 2.0), _at(0, r * 0.5, 0)])


## A balcony that came down from the town: its slab on edge in the sand, the railing bent, an
## air conditioner smashed beside it, a plant pot. Origin on the sand.
func _balcony() -> void:
	var slab := Transform3D(Basis(Vector3.RIGHT, -1.1) * Basis(Vector3.FORWARD, 0.15), Vector3(0, 0.6, 0))
	_pm.box(M.concrete, Vector3(3.6, 0.22, 1.5), slab)
	for i in 5:
		var x := -1.6 + i * 0.8
		_pm.stick(M.metal, slab * Vector3(x, 0.1, 0.7), slab * Vector3(x + 0.1 * (i % 2), 1.0, 0.75 + 0.2 * (i % 3)), 0.04)
	_pm.stick(M.metal, slab * Vector3(-1.6, 1.0, 0.75), slab * Vector3(0.2, 1.05, 1.1), 0.05)
	_pm.stick(M.metal, slab * Vector3(0.2, 1.05, 1.1), slab * Vector3(1.7, 0.6, 1.4), 0.05)
	# The air conditioner, face down, its fan grille and its pipes torn out.
	var ac := Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3.RIGHT, 0.25), Vector3(2.4, 0.2, 1.0))
	_pm.box(M.hull, Vector3(0.9, 0.6, 0.35), ac)
	_pm.cyl(M.hole, 0.22, 0.22, 0.04, ac * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.15, 0, 0.18)), 10)
	_pm.stick(M.metal, ac * Vector3(-0.45, 0.1, 0), ac * Vector3(-1.1, 0.0, 0.4), 0.03)
	_pm.cyl(M.concrete, 0.18, 0.13, 0.3, Transform3D(Basis(Vector3.FORWARD, 1.4), Vector3(-1.4, 0.13, 1.3)), 8)
	_boxes.append([Vector3(3.6, 1.4, 0.8), _at(0, 0.5, 0)])


