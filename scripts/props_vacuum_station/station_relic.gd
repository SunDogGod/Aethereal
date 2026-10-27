@tool
extends "res://scripts/props_vacuum_station/station_prop_base.gd"
## What the travellers and the ages left in the waystation, picked from Kind: a suitcase, a trunk,
## a heap of luggage, a ticket booth, a broken bench, a dead hologram emitter, a sign in the old
## script hanging on chains, the same sign fallen, roots out of a crack, a ceiling lamp come down,
## and for the train: a locker, a stack of training mats, a water drum.
## Origin on the floor (hanging things: at the anchor, hanging `drop` metres down), facing +Z,
## a wall (if any) behind at -Z. Small things are walk-through whatever Solid says (they have no
## footprint); see each Kind.

const M := {
	metal = preload("res://materials/metal_worn.tres"), clean = preload("res://materials/metal.tres"),
	dark = preload("res://materials/rubber.tres"), rust = preload("res://materials/pipe_rust.tres"),
	hull = preload("res://materials/vacuum_station_hull_worn.tres"), glass = preload("res://materials/vacuum_station_screen_dead.tres"),
	leather = preload("res://materials/vacuum_station_leather.tres"), cloth = preload("res://materials/vacuum_station_cloth.tres"),
	paper = preload("res://materials/vacuum_station_paper.tres"), brass = preload("res://materials/brass.tres"),
	wood = preload("res://materials/wood.tres"), off = preload("res://materials/ceiling_panel_off.tres"),
	sign_a = preload("res://materials/vacuum_station_old_sign_a.tres"), sign_b = preload("res://materials/vacuum_station_old_sign_b.tres"),
	root = preload("res://materials/vacuum_station_root.tres"), moss = preload("res://materials/vacuum_station_moss.tres"),
	concrete = preload("res://materials/concrete_dark_worn.tres"), teal = preload("res://materials/paint_teal.tres"),
	red = preload("res://materials/paint_red.tres"), mat = preload("res://materials/vacuum_station_mat.tres"),
	yellow = preload("res://materials/paint_yellow.tres"),
}

@export_enum("Suitcase", "Trunk", "Luggage heap", "Ticket booth", "Broken bench", "Dead emitter",
		"Hanging sign", "Fallen sign", "Roots", "Fallen lamp", "Train locker", "Mat stack",
		"Water drum") var kind := 0:
	set(value):
		kind = value
		_rebuild()
## Hanging sign: chain length. Fallen lamp: how far up its cable goes. Metres.
@export var drop := 3.0:
	set(value):
		drop = value
		_rebuild()
## Hanging and fallen signs: the plate's width in metres (its height is a quarter of it).
@export var width := 4.0:
	set(value):
		width = value
		_rebuild()

var _rng := RandomNumberGenerator.new()


func _build() -> void:
	_rng.seed = 5300 + variant * 31 + kind
	match kind:
		0: _suitcase(Vector3.ZERO, 0.0, variant)
		1: _trunk()
		2: _heap()
		3: _booth()
		4: _broken_bench()
		5: _emitter()
		6: _hanging_sign()
		7: _fallen_sign()
		8: _roots()
		9: _fallen_lamp()
		10: _locker()
		11: _mats()
		12: _drum()


func _r(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


## A hard case at `p`, turned `yaw`: style 0 upright on its end, 1 lying flat, 2 lying open with
## clothes spilling out. Walk-through (no footprint).
func _suitcase(p: Vector3, yaw: float, style: int) -> void:
	var skin: Material = [M.leather, M.cloth, M.teal, M.red][posmod(variant + int(p.x * 3.0), 4)]
	var turn := Basis(Vector3.UP, yaw)
	if posmod(style, 3) == 0:
		pm.box(skin, Vector3(0.48, 0.66, 0.22), Transform3D(turn, p + turn * Vector3(0, 0.33, 0)))
		pm.box(M.dark, Vector3(0.5, 0.04, 0.24), Transform3D(turn, p + turn * Vector3(0, 0.36, 0)))  # the seam
		pm.box(M.dark, Vector3(0.16, 0.05, 0.04), Transform3D(turn, p + turn * Vector3(0, 0.69, 0)))  # handle
	else:
		pm.box(skin, Vector3(0.66, 0.2, 0.46), Transform3D(turn, p + turn * Vector3(0, 0.1, 0)))
		pm.box(M.dark, Vector3(0.68, 0.03, 0.48), Transform3D(turn, p + turn * Vector3(0, 0.12, 0)))
		for x in [-0.22, 0.22]:
			pm.box(M.brass, Vector3(0.06, 0.04, 0.03), Transform3D(turn, p + turn * Vector3(x, 0.12, 0.24)))
		if posmod(style, 3) == 2:  # the lid thrown back, clothes on the floor
			var lid := turn * Basis(Vector3.RIGHT, -1.9)
			pm.box(skin, Vector3(0.66, 0.08, 0.46), Transform3D(lid, p + turn * Vector3(0, 0.2, -0.27)))
			for i in 3:
				var q := p + turn * Vector3(_r(-0.3, 0.3), 0.012 + i * 0.006, _r(0.35, 0.75))
				pm.box([M.cloth, M.paper, M.red][i], Vector3(_r(0.25, 0.45), 0.02, _r(0.2, 0.35)), Transform3D(Basis(Vector3.UP, _r(0, TAU)), q))


## An old travel trunk: boards, leather straps, brass corners.
func _trunk() -> void:
	span(M.wood, Vector3(-0.5, 0, -0.3), Vector3(0.5, 0.5, 0.3))
	pm.box(M.wood, Vector3(1.0, 0.1, 0.6), at(0, 0.55, 0))
	for x in [-0.3, 0.3]:
		span(M.leather, Vector3(x - 0.05, -0.005, -0.31), Vector3(x + 0.05, 0.61, 0.31))
	for x in [-0.49, 0.49]:
		for z in [-0.29, 0.29]:
			pm.box(M.brass, Vector3(0.06, 0.06, 0.06), at(x, 0.57, z))
	pm.box(M.brass, Vector3(0.1, 0.1, 0.03), at(0, 0.45, 0.31))
	fp(Vector3(1.0, 0.6, 0.6), Vector3(0, 0.3, 0))


## Cases and bags dropped in a pile and left: one upright, two flat, one burst open, a duffel,
## a trunk under it all.
func _heap() -> void:
	span(M.wood, Vector3(-0.5, 0, -0.3), Vector3(0.5, 0.5, 0.3))
	for x in [-0.3, 0.3]:
		span(M.leather, Vector3(x - 0.05, -0.005, -0.31), Vector3(x + 0.05, 0.51, 0.31))
	_suitcase(Vector3(0.05, 0.5, 0.0), 0.3, 1)
	_suitcase(Vector3(0.75, 0, 0.1), -0.4, 0)
	_suitcase(Vector3(-0.8, 0, 0.35), 0.9, 2)
	_suitcase(Vector3(0.0, 0.7, -0.05), -0.2, 1)
	pm.cyl(M.cloth, 0.2, 0.2, 0.75, Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.35, 0.2, -0.55)), 8)
	pm.stick(M.dark, Vector3(-0.6, 0.38, -0.4), Vector3(-0.1, 0.4, -0.7), 0.03)
	fp(Vector3(1.0, 0.95, 0.6), Vector3(0, 0.47, 0))


## A ticket booth: a small steel cabin, a window of dead glass over a counter with a slot, an
## overhanging roof with a sign in the old script, the door at the back ajar on darkness.
func _booth() -> void:
	var w := 2.6
	var d := 2.0
	span(M.hull, Vector3(-w * 0.5, 0, -d * 0.5), Vector3(w * 0.5, 1.0, d * 0.5))  # the lower walls
	span(M.hull, Vector3(-w * 0.5, 1.0, -d * 0.5), Vector3(w * 0.5, 2.6, -d * 0.5 + 0.12))  # back
	for x in [-w * 0.5, w * 0.5 - 0.12]:
		span(M.hull, Vector3(x, 1.0, -d * 0.5), Vector3(x + 0.12, 2.6, d * 0.5))  # sides
	span(M.hull, Vector3(-w * 0.5, 2.2, d * 0.5 - 0.12), Vector3(w * 0.5, 2.6, d * 0.5))  # over the window
	span(M.metal, Vector3(-w * 0.5 - 0.02, 1.0, d * 0.5 - 0.06), Vector3(w * 0.5 + 0.02, 1.06, d * 0.5 + 0.3))  # counter
	span(M.dark, Vector3(-0.3, 1.0, d * 0.5 - 0.02), Vector3(0.3, 1.08, d * 0.5 + 0.02))  # the slot
	# The glass: one pane whole, one cracked out (a jagged stub), mullion between.
	span(M.glass, Vector3(-w * 0.5 + 0.12, 1.06, d * 0.5 - 0.08), Vector3(-0.03, 2.2, d * 0.5 - 0.06))
	span(M.metal, Vector3(-0.04, 1.06, d * 0.5 - 0.1), Vector3(0.04, 2.2, d * 0.5 - 0.04))
	pm.box(M.glass, Vector3(0.5, 0.35, 0.02), at(0.4, 1.25, d * 0.5 - 0.07, Basis(Vector3.BACK, 0.4)))
	span(M.dark, Vector3(-w * 0.5 + 0.12, 1.06, -d * 0.5 + 0.12), Vector3(w * 0.5 - 0.12, 2.2, -d * 0.5 + 0.14))  # dark inside
	pm.box(M.hull, Vector3(w + 0.5, 0.14, d + 0.6), at(0, 2.67, 0.15))  # roof
	span(M.metal, Vector3(-w * 0.5, 2.74, d * 0.5 + 0.1), Vector3(w * 0.5, 3.36, d * 0.5 + 0.16))
	face(M.sign_a if variant % 2 == 0 else M.sign_b, Vector2(w - 0.1, 0.56), at(0, 3.05, d * 0.5 + 0.17))
	pm.box(M.hull, Vector3(0.75, 1.9, 0.04), at(0.95, 0.98, -d * 0.5 - 0.3, Basis(Vector3.UP, -0.7)))  # door ajar
	span(M.dark, Vector3(0.6, 0.02, -d * 0.5 - 0.01), Vector3(1.2, 1.9, -d * 0.5 + 0.01))
	fp(Vector3(w, 2.6, d), Vector3(0, 1.3, 0))


## A rusted waiting bench with one plinth rotted through: the seat slab has dropped to the floor
## at that end.
func _broken_bench() -> void:
	span(M.rust, Vector3(0.7, 0, -0.2), Vector3(1.0, 0.42, 0.2))
	pm.box(M.rust, Vector3(0.3, 0.12, 0.4), at(-0.85, 0.06, 0.02, Basis(Vector3.UP, 0.2)))  # the stump
	var tilt := Basis(Vector3.BACK, 0.2)
	pm.box(M.hull, Vector3(2.2, 0.08, 0.5), Transform3D(tilt, Vector3(0, 0.25, 0)))
	pm.box(M.hull, Vector3(2.2, 0.42, 0.06), Transform3D(tilt, Vector3(0.02, 0.5, -0.22)))
	pm.box(M.rust, Vector3(2.24, 0.04, 0.1), Transform3D(tilt, Vector3(0.05, 0.72, -0.22)))
	fp(Vector3(2.2, 0.6, 0.52), Vector3(0, 0.3, 0))


## A hologram emitter that died long ago: a pedestal, a lens gone grey and cracked, the ring that
## carried the image fallen askew, cables out of a torn panel.
func _emitter() -> void:
	pm.cyl(M.metal, 0.55, 0.65, 0.2, at(0, 0.1, 0), 8)
	pm.cyl(M.hull, 0.32, 0.4, 0.95, at(0, 0.67, 0), 8)
	pm.cyl(M.metal, 0.42, 0.34, 0.12, at(0, 1.2, 0), 8)
	pm.sphere(M.glass, 0.26, 0.26, at(0, 1.26, 0), 8, 3)
	pm.box(M.dark, Vector3(0.3, 0.015, 0.02), at(0.05, 1.35, 0.05, Basis(Vector3.UP, 0.5)))  # the crack
	pm.ring(M.rust, 0.42, 0.48, Transform3D(Basis(Vector3.RIGHT, 0.5) * Basis(Vector3.FORWARD, 0.25), Vector3(0.1, 0.4, 0.25)), 12, 3)
	span(M.dark, Vector3(-0.2, 0.3, 0.33), Vector3(0.2, 0.7, 0.38))  # the torn panel's hole
	pm.box(M.hull, Vector3(0.4, 0.4, 0.03), at(0.3, 0.02, 0.75, Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, 0.4)))
	pm.stick(M.red, Vector3(-0.08, 0.45, 0.36), Vector3(-0.2, 0.02, 0.7), 0.025)
	pm.stick(M.dark, Vector3(0.05, 0.5, 0.36), Vector3(0.35, 0.02, 0.6), 0.03)
	fp(Vector3(1.0, 1.3, 1.0), Vector3(0, 0.65, 0))


## A sign plate in the old script on two chains, `drop` metres below the anchor (this node).
## Variant 0/1: hanging level (plate a / b). 2/3: one chain has snapped and the plate hangs
## steeply from the other, the broken chain dangling. No collision: it hangs out of reach.
func _hanging_sign() -> void:
	var mat: Material = M.sign_a if variant % 2 == 0 else M.sign_b
	var w := width
	var h := width * 0.25
	var snapped := variant >= 2
	var held := Vector3(w * 0.4, 0, 0)
	if not snapped:
		for x in [-w * 0.4, w * 0.4]:
			_chain(Vector3(x, 0, 0), Vector3(x, -drop, 0))
		_plate(mat, Transform3D(Basis(), Vector3(0, -drop - h * 0.5, 0)), w, h)
	else:
		var tilt := Basis(Vector3.BACK, 0.55)
		var hang := Vector3(w * 0.4, -drop, 0)
		_chain(held, hang)
		var centre := hang + tilt * Vector3(-w * 0.4, -h * 0.5 + 0.04, 0)
		_plate(mat, Transform3D(tilt, centre), w, h)
		_chain(Vector3(-w * 0.4, 0, 0), Vector3(-w * 0.4 - 0.1, -drop * 0.35, 0.05))  # the snapped end
	fp(Vector3.ZERO, Vector3.ZERO)


## A double-sided plate in a frame. The faces are split into 1 m squares so a lamp or the
## flashlight lights them evenly (lighting is worked out at the corners).
func _plate(mat: Material, xf: Transform3D, w: float, h: float) -> void:
	pm.box(M.metal, Vector3(w + 0.08, h + 0.08, 0.06), xf)
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	q.subdivide_width = maxi(0, int(w) - 1)
	pm._add(mat, q, xf * at(0, 0, 0.035))
	pm._add(mat, q, xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -0.035)))


func _chain(a: Vector3, b: Vector3) -> void:
	pm.stick(M.metal, a, b, 0.035)
	var links := int(a.distance_to(b) / 0.5)
	for i in links:
		pm.box(M.rust, Vector3(0.06, 0.08, 0.06), Transform3D(Basis(), a.lerp(b, (i + 0.5) / maxf(1.0, links))))


## A hanging sign that came down: the plate face up, one corner propped on a chunk of concrete,
## its chains in a heap.
func _fallen_sign() -> void:
	var mat: Material = M.sign_a if variant % 2 == 0 else M.sign_b
	pm.box(M.concrete, Vector3(0.4, 0.22, 0.35), at(width * 0.38, 0.11, -0.1, Basis(Vector3.UP, 0.4)))
	var lie := Basis(Vector3.BACK, 0.25 / width) * Basis(Vector3.RIGHT, -PI * 0.5)  # one end on the floor, one on the chunk
	_plate(mat, Transform3D(lie, Vector3(0, 0.155, 0)), width, width * 0.25)
	for i in 6:
		pm.box(M.rust, Vector3(0.07, 0.04, 0.09), at(-width * 0.5 + _r(-0.3, 0.3), 0.02, 0.8 + _r(-0.15, 0.15), Basis(Vector3.UP, _r(0, TAU))))
	pm.stick(M.metal, Vector3(-1.2, 0.03, 0.4), Vector3(-0.4, 0.03, 0.75), 0.035)
	fp(Vector3.ZERO, Vector3.ZERO)


## Roots that found their way in: out of a crack at the foot of a wall (-Z), up it and across the
## floor, with moss in the wet. Walk-through.
func _roots() -> void:
	var start := Vector3(0, 0, -0.05)
	for i in 5:
		var a := _r(-1.2, 1.2)
		var p := start + Vector3(_r(-0.3, 0.3), 0.02, 0)
		var up := i % 2 == 0
		var thick := _r(0.05, 0.09)
		for s in 6:
			var q: Vector3
			if up:
				q = p + Vector3(_r(-0.25, 0.25), _r(0.25, 0.45), -0.0)
				q.z = -0.04
			else:
				q = p + Vector3(sin(a) * _r(0.25, 0.4), 0.0, cos(a) * _r(0.25, 0.4))
				q.y = 0.03
				a += _r(-0.5, 0.5)
			pm.stick(M.root, p, q, thick)
			p = q
			thick = maxf(0.025, thick * 0.85)
	for i in 7:
		var c := Vector3(_r(-0.8, 0.8), 0.0, _r(0.0, 0.7))
		pm.sphere(M.moss, _r(0.12, 0.28), _r(0.06, 0.12), at(c.x, 0.02, c.z), 6, 2)
	fp(Vector3.ZERO, Vector3.ZERO)


## A ceiling lamp that came down: the housing on its side, the diffuser smashed round it, the
## cable going back up `drop` metres to where it hung. Walk-through.
func _fallen_lamp() -> void:
	var lie := Basis(Vector3.UP, 0.4) * Basis(Vector3.BACK, 0.3)
	pm.box(M.metal, Vector3(1.2, 0.18, 0.45), Transform3D(lie, Vector3(0, 0.18, 0)))
	pm.box(M.off, Vector3(1.1, 0.03, 0.38), Transform3D(lie, Vector3(0, 0.18, 0) + lie * Vector3(0, -0.1, 0)))
	for i in 9:
		pm.box(M.off, Vector3(_r(0.06, 0.2), 0.012, _r(0.05, 0.15)), at(_r(-0.9, 0.9), 0.006, _r(-0.6, 0.8), Basis(Vector3.UP, _r(0, TAU))))
	pm.stick(M.dark, Vector3(0.5, 0.25, 0.1), Vector3(0.7, 0.05, 0.6), 0.03)
	pm.stick(M.dark, Vector3(0.7, 0.05, 0.6), Vector3(0.9, drop * 0.5, 0.75), 0.03)
	pm.stick(M.dark, Vector3(0.9, drop * 0.5, 0.75), Vector3(0.95, drop, 0.8), 0.03)
	fp(Vector3.ZERO, Vector3.ZERO)


## A tall double locker for the train, cleaner than the station's: one door open on a coat and a
## spare blade.
func _locker() -> void:
	span(M.clean, Vector3(-0.6, 0.0, -0.25), Vector3(0.6, 1.95, 0.25))
	span(M.dark, Vector3(-0.01, 0.05, 0.25), Vector3(0.01, 1.9, 0.26))
	for x in [-0.3, 0.3]:
		for y in [1.7, 1.78]:
			span(M.dark, Vector3(x - 0.18, y, 0.25), Vector3(x + 0.18, y + 0.03, 0.26))  # vent slots
	span(M.dark, Vector3(0.02, 0.05, -0.2), Vector3(0.58, 1.9, 0.255))  # the open one's inside
	pm.box(M.clean, Vector3(0.56, 1.85, 0.03), at(0.75, 0.98, 0.45, Basis(Vector3.UP, 1.1)))  # its door
	pm.box(M.teal if variant % 2 == 0 else M.red, Vector3(0.36, 0.9, 0.14), at(0.3, 1.25, 0.0))  # a coat
	pm.box(M.wood, Vector3(0.04, 0.9, 0.04), at(0.5, 0.55, 0.1, Basis(Vector3.BACK, 0.1)))
	span(M.clean, Vector3(-0.3, 0.95, 0.25), Vector3(-0.26, 1.1, 0.29))
	fp(Vector3(1.2, 1.95, 0.5), Vector3(0, 0.975, 0))


## Training mats folded in a stack, one rolled against it. Walk-through.
func _mats() -> void:
	for i in 4:
		pm.box(M.mat, Vector3(1.0, 0.1, 0.7), at(_r(-0.04, 0.04), 0.05 + i * 0.1, _r(-0.03, 0.03), Basis(Vector3.UP, _r(-0.08, 0.08))))
	pm.cyl(M.mat, 0.18, 0.18, 0.7, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.75, 0.18, 0.0)), 8)
	pm.box(M.dark, Vector3(0.04, 0.37, 0.04), at(0.75, 0.18, 0.2))
	fp(Vector3.ZERO, Vector3.ZERO)


## A water drum with a lid and a ladle hung on its rim.
func _drum() -> void:
	pm.cyl(M.clean, 0.32, 0.32, 0.86, at(0, 0.43, 0), 10)
	for y in [0.2, 0.66]:
		pm.cyl(M.dark, 0.335, 0.335, 0.04, at(0, y, 0), 10)
	pm.cyl(M.clean, 0.3, 0.3, 0.03, at(0.05, 0.88, 0.02), 10)
	pm.stick(M.wood, Vector3(0.28, 0.95, 0.0), Vector3(0.36, 0.55, 0.05), 0.03)
	pm.sphere(M.clean, 0.07, 0.07, at(0.37, 0.52, 0.05), 6, 3)
	fp(Vector3(0.66, 0.9, 0.66), Vector3(0, 0.45, 0))
