@tool
extends Node3D
## Broken things for an old town, picked from Kind: rubble, debris, a fallen sign, rebar out of a
## broken ledge, a tarp over a hole, a welded repair, a bent railing, a collapsed awning, a burst
## pipe, a dead cable. Same rules as street_prop.gd: origin on the floor (or on the wall plane for
## wall things), the wall behind at -Z, the prop facing +Z. Purely visual: no collision, so a
## piece of rubble on a walked floor never makes a step. Change Kind, Variant or Length in the
## Inspector and it rebuilds.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	concrete = preload("res://materials/concrete_worn.tres"), dark = preload("res://materials/concrete_dark_worn.tres"),
	metal = preload("res://materials/metal_worn.tres"), rust = preload("res://materials/pipe_rust.tres"),
	rail = preload("res://materials/trim_rail_worn.tres"), rubber = preload("res://materials/rubber.tres"),
	paper = preload("res://materials/white_plaster.tres"), hole = preload("res://materials/black_cube.tres"),
	tarp = preload("res://materials/tarp.tres"), sign = preload("res://materials/sign_dead.tres"),
	awning = preload("res://materials/awning_red.tres"), copper = preload("res://materials/brass.tres"),
	wood = preload("res://materials/wood.tres"),
}

@export_enum("Rubble pile", "Debris (flat)", "Fallen sign", "Rebar (broken ledge)", "Tarp over a hole",
		"Welded patch", "Bent railing", "Collapsed awning", "Burst pipe", "Dead cable") var kind := 0:
	set(value):
		kind = value
		_rebuild()
## Changes the scatter and small details, so two of the same Kind don't look identical.
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()
## Metres: how far the rebar sticks out, the awning's mount height, the pipe's or cable's length.
@export var length := 1.0:
	set(value):
		length = value
		_rebuild()
## Not drawn beyond this many metres (0 = always drawn).
@export var draw_distance := 50.0:
	set(value):
		draw_distance = value
		_mesh.visibility_range_end = maxf(value, 0.0)

var _mesh := MeshInstance3D.new()
var _pm: PropMesh
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_mesh.visibility_range_end = draw_distance
	_rebuild()


func _rebuild() -> void:
	_pm = PropMesh.new()
	_rng.seed = 7919 * (variant + 1) + kind
	match kind:
		0: _rubble()
		1: _debris()
		2: _fallen_sign()
		3: _rebar()
		4: _tarp()
		5: _patch()
		6: _bent_rail()
		7: _awning()
		8: _burst_pipe()
		9: _cable()
	_mesh.mesh = _pm.commit()


func _rot(x: float, y: float, z: float) -> Basis:
	return Basis.from_euler(Vector3(x, y, z))


func _r(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


## Chunks of concrete heaped against the wall (highest at the back), a bent bar poking out.
func _rubble() -> void:
	for i in 14:
		var s := Vector3(_r(0.2, 0.55), _r(0.14, 0.32), _r(0.18, 0.45)) * (1.0 - i * 0.04)
		var back := 1.0 - float(i) / 14.0  # the big ones at the back
		var p := Vector3(_r(-0.75, 0.75) * (1.2 - back * 0.5), 0.0, lerpf(0.9, 0.25, back) + _r(-0.1, 0.1))
		p.y = s.y * 0.35 + back * 0.3
		_pm.box(M.concrete if i % 3 else M.dark, s, Transform3D(_rot(_r(-0.4, 0.4), _r(0, TAU), _r(-0.4, 0.4)), p))
	for i in 6:
		var s := _r(0.05, 0.1)
		_pm.box(M.concrete, Vector3(s, s * 0.6, s), Transform3D(_rot(0, _r(0, TAU), 0.3), Vector3(_r(-0.8, 0.8), s * 0.3, _r(0.7, 1.15))))
	_pm.stick(M.rust, Vector3(-0.1, 0.25, 0.3), Vector3(0.25, 0.62, 0.55), 0.02)
	_pm.stick(M.rust, Vector3(0.25, 0.62, 0.55), Vector3(0.42, 0.55, 0.7), 0.02)


## Flat bits a few centimetres high spread across the floor, and a couple of sheets of paper.
func _debris() -> void:
	for i in 14:
		var s := Vector3(_r(0.04, 0.16), _r(0.015, 0.05), _r(0.04, 0.14))
		_pm.box(M.concrete if i % 2 else M.dark, s, Transform3D(_rot(0, _r(0, TAU), 0), Vector3(_r(-0.8, 0.8), s.y * 0.5, _r(-0.6, 0.6))))
	for i in 2:
		_pm.box(M.paper, Vector3(0.21, 0.004, 0.3), Transform3D(_rot(0, _r(0, TAU), 0), Vector3(_r(-0.6, 0.6), 0.003, _r(-0.5, 0.5))))
	_pm.stick(M.rust, Vector3(-0.5, 0.012, -0.3), Vector3(0.1, 0.012, 0.25), 0.015)


## A blade sign come down: the plate face-up on the floor, one end propped on its own bracket,
## the arms torn off and bent.
func _fallen_sign() -> void:
	var tilt := _rot(0.22, 0.35, 0.0)
	var c := Vector3(0, 0.14, 0.45)
	_pm.box(M.sign, Vector3(0.7, 0.05, 0.55), Transform3D(tilt, c))
	_pm.box(M.metal, Vector3(0.74, 0.06, 0.04), Transform3D(tilt, c + tilt * Vector3(0, 0, -0.29)))
	_pm.box(M.metal, Vector3(0.74, 0.06, 0.04), Transform3D(tilt, c + tilt * Vector3(0, 0, 0.29)))
	_pm.box(M.metal, Vector3(0.1, 0.9, 0.04), Transform3D(_rot(0, 0.3, 1.45), Vector3(0.1, 0.11, -0.05)))  # the wall bracket
	_pm.stick(M.metal, Vector3(0.38, 0.2, 0.3), Vector3(0.62, 0.3, 0.75), 0.04)
	_pm.stick(M.metal, Vector3(0.62, 0.3, 0.75), Vector3(0.8, 0.05, 0.95), 0.04)
	_pm.box(M.concrete, Vector3(0.18, 0.1, 0.14), Transform3D(_rot(0, 0.5, 0), Vector3(-0.6, 0.05, 0.85)))


## Bars sticking out of a broken slab edge, bent down at the tips, with jagged lips of concrete.
func _rebar() -> void:
	var n := 5 + posmod(variant, 2)
	for i in n:
		var x := -0.6 + 1.2 * i / float(n - 1) + _r(-0.05, 0.05)
		var y := _r(-0.08, 0.08)
		var out := length * _r(0.45, 1.0)
		var mid := Vector3(x, y, out * 0.7)
		_pm.stick(M.rust, Vector3(x, y, -0.05), mid, 0.025)
		_pm.stick(M.rust, mid, mid + Vector3(_r(-0.15, 0.15), -out * _r(0.2, 0.6), out * 0.3), 0.025)
	for i in 4:
		var s := Vector3(_r(0.2, 0.4), _r(0.1, 0.2), _r(0.08, 0.18))
		_pm.box(M.concrete, s, Transform3D(_rot(_r(-0.3, 0.3), 0, _r(-0.3, 0.3)), Vector3(-0.55 + i * 0.37, _r(-0.12, 0.08), s.z * 0.4)))


## A faded tarp tied over a hole in the wall: the dark hole, the sheet sagging, cords, a brick
## weighing the bottom corner.
func _tarp() -> void:
	_pm.box(M.hole, Vector3(1.2, 1.0, 0.01), Transform3D(Basis(), Vector3(0, 1.4, 0.005)))
	var top := Transform3D(_rot(-0.05, 0, 0.03), Vector3(0, 1.75, 0.04))
	_pm.box(M.tarp, Vector3(1.6, 0.75, 0.015), top)
	_pm.box(M.tarp, Vector3(1.55, 0.75, 0.015), Transform3D(_rot(0.12, 0, -0.04), Vector3(0.03, 1.06, 0.07)))
	for p in [Vector3(-0.8, 2.12, 0.02), Vector3(0.8, 2.12, 0.02), Vector3(-0.76, 0.7, 0.05)]:
		_pm.stick(M.rubber, p, p + Vector3(0, 0, 0.06), 0.02)
	_pm.box(M.concrete, Vector3(0.22, 0.1, 0.11), Transform3D(Basis(), Vector3(0.62, 0.72, 0.13)))
	_pm.stick(M.rubber, Vector3(0.62, 0.77, 0.12), Vector3(0.74, 0.68, 0.08), 0.015)


## A plate welded over a rusted-through spot: the plate, a weld bead round it, four bolts.
func _patch() -> void:
	var b := _rot(0, 0, _r(-0.08, 0.08))
	var c := Vector3(0, 0, 0.012)
	var s := Vector2(0.9 + 0.2 * posmod(variant, 2), 0.7)
	_pm.box(M.metal, Vector3(s.x, s.y, 0.02), Transform3D(b, c))
	for e in [[Vector3(0, s.y * 0.5, 0), Vector3(s.x + 0.03, 0.025, 0.025)], [Vector3(0, -s.y * 0.5, 0), Vector3(s.x + 0.03, 0.025, 0.025)],
			[Vector3(s.x * 0.5, 0, 0), Vector3(0.025, s.y, 0.025)], [Vector3(-s.x * 0.5, 0, 0), Vector3(0.025, s.y, 0.025)]]:
		_pm.box(M.rust, e[1], Transform3D(b, c + b * e[0]))
	for k in [Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(-1, 1, 0), Vector3(1, 1, 0)]:
		_pm.cyl(M.rust, 0.025, 0.025, 0.03, Transform3D(b * _rot(PI * 0.5, 0, 0), c + b * (k * Vector3(s.x * 0.4, s.y * 0.38, 0) + Vector3(0, 0, 0.02))), 6)


## A length of railing torn off and dropped: two pieces bent at the break, lying on the floor.
func _bent_rail() -> void:
	var a := Vector3(-1.1, 0.06, 0.1)
	var k := Vector3(0.0, 0.06, 0.35)
	var e := Vector3(0.8, 0.22, 0.05)
	_pm.box(M.rail, Vector3(a.distance_to(k), 0.1, 0.06), Transform3D(_rot(0, -atan2(k.z - a.z, k.x - a.x), 0), (a + k) * 0.5))
	_pm.stick(M.rail, k, e, 0.07)
	for p in [Vector3(-0.8, 0.03, 0.18), Vector3(-0.3, 0.03, 0.28)]:
		_pm.stick(M.rail, p, p + Vector3(0.05, 0.02, 0.55), 0.035)  # posts snapped off, lying flat


## An awning torn off its wall on one side: the canopy hangs from the far bracket to the floor,
## the near strut bent down, the hem lying on the ground. `length` is the mount height.
func _awning() -> void:
	var h := maxf(length, 1.5)
	var hold := Vector3(0.95, h, 0.0)  # the bracket that held
	var down := Vector3(-0.95, 0.6, 0.0)  # the end that fell
	var x := (hold - down).normalized()
	var z := (Vector3(0, -0.5, 0.85) - x * x.dot(Vector3(0, -0.5, 0.85))).normalized()
	var basis := Basis(x, z.cross(x), z)
	_pm.box(M.awning, Vector3(hold.distance_to(down), 0.03, 1.0), Transform3D(basis, (hold + down) * 0.5 + z * 0.52))
	var foot := Vector3(-0.85, 0.0, 0.6)
	_pm.box(M.awning, Vector3(0.9, 0.03, 0.22), Transform3D(_rot(0, 0.4, 0), foot + Vector3(-0.1, 0.02, 0.25)))  # the hem
	_pm.box(M.metal, Vector3(0.1, 0.12, 0.08), Transform3D(Basis(), Vector3(0.9, h, 0.04)))
	_pm.box(M.metal, Vector3(0.1, 0.12, 0.08), Transform3D(Basis(), Vector3(-0.9, h, 0.04)))  # the bare bracket
	_pm.stick(M.metal, Vector3(0.9, h, 0.06), Vector3(0.85, h - 0.35, 0.9), 0.03)
	_pm.stick(M.metal, Vector3(-0.9, h, 0.06), Vector3(-0.85, h - 0.5, 0.25), 0.03)
	_pm.stick(M.metal, Vector3(-0.85, h - 0.5, 0.25), Vector3(-0.7, h - 1.1, 0.3), 0.03)


## A downpipe split open: two lengths with flared lips, a bent tongue of metal, clamps.
func _burst_pipe() -> void:
	var r := 0.08
	var gap := length * 0.45
	_pm.cyl(M.rust, r, r, gap - 0.1, Transform3D(Basis(), Vector3(0, (gap - 0.1) * 0.5, r + 0.02)), 8)
	_pm.cyl(M.rust, r * 1.4, r, 0.08, Transform3D(Basis(), Vector3(0, gap - 0.06, r + 0.02)), 8)  # flared lip
	_pm.cyl(M.rust, r, r * 1.4, 0.08, Transform3D(Basis(), Vector3(0, gap + 0.2, r + 0.02)), 8)
	_pm.cyl(M.rust, r, r, length - gap - 0.24, Transform3D(Basis(), Vector3(0, (length + gap + 0.24) * 0.5, r + 0.02)), 8)
	_pm.box(M.rust, Vector3(0.1, 0.25, 0.01), Transform3D(_rot(0.7, 0, 0.2), Vector3(0.02, gap - 0.05, r * 2 + 0.1)))  # the torn tongue
	for y in [0.2, length - 0.3]:
		_pm.box(M.metal, Vector3(0.24, 0.04, 0.2), Transform3D(Basis(), Vector3(0, y, 0.1)))


## A dead cable hanging from where it was cut: a slow curve down, the frayed end showing copper.
func _cable() -> void:
	var p := Vector3.ZERO
	var steps := 6
	for i in steps:
		var t := float(i + 1) / steps
		var q := Vector3(sin(t * 2.2 + variant) * 0.12, -length * t, 0.06 + t * 0.12)
		_pm.stick(M.rubber, p, q, 0.03)
		p = q
	for k in 3:
		_pm.stick(M.copper, p, p + Vector3(_r(-0.04, 0.04), -0.07, _r(-0.03, 0.03)), 0.008)
