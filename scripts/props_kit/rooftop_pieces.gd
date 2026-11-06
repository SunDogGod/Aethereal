extends RefCounted
## The shapes the rooftop kit (rooftop_kit.gd) scatters: a water tank on legs, an antenna mast
## with guy lines, a bank of AC units, a stair head box, a vent hood, the parapet railing.
## Each takes the PropMesh to draw into, a seeded RNG for its small variations, and the list of
## [size, Transform3D] collision boxes to add to when the piece is something you could bump into.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const CONCRETE := preload("res://materials/kitb_concrete.tres")
const IRON := preload("res://materials/kitb_iron.tres")
const RUST := preload("res://materials/kitb_rust.tres")
const GRATING := preload("res://materials/grating.tres")
const BEACON := preload("res://materials/black_sand_beacon.tres")


static func _at(p: Vector3, turn := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, turn), p)


## A round tank on four legs with a cone lid, an outlet pipe down one side, a hoop or two.
static func tank(pm: PropMesh, rng: RandomNumberGenerator, at: Vector3, boxes: Array) -> void:
	var r := rng.randf_range(0.8, 1.2)
	var legs := rng.randf_range(0.8, 1.4)
	var body: Material = RUST if rng.randf() < 0.6 else IRON
	for x in [-1, 1]:
		for z in [-1, 1]:
			var foot := at + Vector3(x * r * 0.62, 0, z * r * 0.62)
			pm.stick(IRON, foot, foot + Vector3(0, legs, 0), 0.11)
		pm.stick(IRON, at + Vector3(x * r * 0.62, 0.1, -r * 0.62), at + Vector3(x * r * 0.62, legs * 0.6, r * 0.62), 0.05)
	pm.box(IRON, Vector3(r * 1.5, 0.12, r * 1.5), _at(at + Vector3(0, legs, 0)))
	pm.cyl(body, r, r, 1.8, _at(at + Vector3(0, legs + 0.96, 0)), 10, 2)
	pm.cyl(IRON, r * 1.04, r * 1.04, 0.14, _at(at + Vector3(0, legs + 0.5, 0)), 10)
	pm.cyl(IRON, r * 1.04, r * 1.04, 0.14, _at(at + Vector3(0, legs + 1.5, 0)), 10)
	pm.cyl(body, 0.12, r, 0.4, _at(at + Vector3(0, legs + 2.06, 0)), 10)
	pm.cyl(IRON, 0.06, 0.06, legs + 0.7, _at(at + Vector3(r * 0.8, (legs + 0.7) * 0.5, 0)), 6)
	boxes.append([Vector3(r * 2.0, legs + 2.0, r * 2.0), _at(at + Vector3(0, (legs + 2.0) * 0.5, 0))])


## A mast with cross bars near the top, three guy lines down to the roof, a red lamp on top.
static func mast(pm: PropMesh, rng: RandomNumberGenerator, at: Vector3, roof: Vector2) -> void:
	var h := rng.randf_range(4.0, 8.0)
	pm.stick(IRON, at, at + Vector3(0, h, 0), 0.1)
	pm.box(CONCRETE, Vector3(0.7, 0.3, 0.7), _at(at + Vector3(0, 0.15, 0)))
	for i in 3:
		var y := h - 0.5 - i * 0.7
		var w := 1.4 - i * 0.3
		pm.stick(IRON, at + Vector3(-w * 0.5, y, 0), at + Vector3(w * 0.5, y, 0), 0.05)
	for k in 3:
		var a := TAU * k / 3.0 + rng.randf_range(-0.3, 0.3)
		var reach := minf(h * 0.45, 2.6)
		var foot := at + Vector3(cos(a) * reach, 0, sin(a) * reach)
		foot.x = clampf(foot.x, -roof.x * 0.5 + 0.4, roof.x * 0.5 - 0.4)
		foot.z = clampf(foot.z, -roof.y * 0.5 + 0.4, roof.y * 0.5 - 0.4)
		pm.stick(IRON, at + Vector3(0, h * 0.72, 0), foot, 0.025)
		pm.box(IRON, Vector3(0.2, 0.15, 0.2), _at(foot + Vector3(0, 0.07, 0)))
	pm.box(BEACON, Vector3(0.16, 0.16, 0.16), _at(at + Vector3(0, h + 0.08, 0)))


## Two to four AC units in a row on a low frame, each with a round fan grille on top.
static func ac_bank(pm: PropMesh, rng: RandomNumberGenerator, at: Vector3, turn: float, boxes: Array) -> void:
	var n := rng.randi_range(2, 4)
	var w := 1.1
	var basis := Basis(Vector3.UP, turn)
	var total := n * w + 0.2
	pm.box(IRON, Vector3(total, 0.25, 1.1), Transform3D(basis, at + Vector3(0, 0.12, 0)))
	for i in n:
		var c := at + basis * Vector3((i - (n - 1) * 0.5) * w, 0.25 + 0.5, 0)
		var dead := rng.randf() < 0.25
		pm.box(RUST if dead else IRON, Vector3(w - 0.1, 1.0, 1.0), Transform3D(basis, c))
		pm.cyl(GRATING, 0.38, 0.38, 0.05, Transform3D(basis, c + Vector3(0, 0.52, 0)), 10)
		pm.box(IRON, Vector3(w - 0.3, 0.06, 0.08), Transform3D(basis, c + Vector3(0, -0.2, 0.5)))
	boxes.append([Vector3(total, 1.3, 1.1), Transform3D(basis, at + Vector3(0, 0.65, 0))])


## The box where the stairs come out: a slab-roofed block with a door recess and a lamp hood.
static func stair_head(pm: PropMesh, at: Vector3, turn: float, boxes: Array) -> void:
	var basis := Basis(Vector3.UP, turn)
	var size := Vector3(2.8, 2.4, 2.6)
	pm.box(CONCRETE, size, Transform3D(basis, at + Vector3(0, size.y * 0.5, 0)))
	pm.box(CONCRETE, Vector3(size.x + 0.4, 0.25, size.z + 0.4), Transform3D(basis, at + Vector3(0, size.y + 0.12, 0)))
	# The door: a dark recess with an iron leaf, on the +Z face (turned by `turn`).
	pm.box(IRON, Vector3(1.0, 2.0, 0.06), Transform3D(basis, at + Vector3(0.4, 1.0, size.z * 0.5 + 0.03)))
	pm.box(IRON, Vector3(0.5, 0.2, 0.3), Transform3D(basis, at + Vector3(0.4, 2.15, size.z * 0.5 + 0.15)))
	boxes.append([size, Transform3D(basis, at + Vector3(0, size.y * 0.5, 0))])


## A squat vent hood: a short duct with a sloped cap.
static func vent(pm: PropMesh, rng: RandomNumberGenerator, at: Vector3, boxes: Array) -> void:
	var r := rng.randf_range(0.3, 0.5)
	var h := rng.randf_range(0.8, 1.5)
	pm.cyl(IRON, r, r, h, _at(at + Vector3(0, h * 0.5, 0)), 8)
	pm.cyl(RUST, r * 1.3, r * 0.6, 0.3, _at(at + Vector3(0, h + 0.15, 0)), 8)
	boxes.append([Vector3(r * 2.0, h, r * 2.0), _at(at + Vector3(0, h * 0.5, 0))])


## A parapet railing round the roof: posts every ~2 m, two rails. 1.1 m tall.
static func railing(pm: PropMesh, size: Vector2, boxes: Array) -> void:
	var hx := size.x * 0.5 - 0.15
	var hz := size.y * 0.5 - 0.15
	var corners := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var n := maxi(1, int(a.distance_to(b) / 2.0))
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			pm.stick(IRON, p, p + Vector3(0, 1.1, 0), 0.07)
		pm.stick(IRON, a + Vector3(0, 1.1, 0), b + Vector3(0, 1.1, 0), 0.07)
		pm.stick(IRON, a + Vector3(0, 0.55, 0), b + Vector3(0, 0.55, 0), 0.045)
		var mid := (a + b) * 0.5 + Vector3(0, 0.55, 0)
		boxes.append([Vector3(a.distance_to(b) + 0.1, 1.1, 0.1) if absf(b.x - a.x) > absf(b.z - a.z) else Vector3(0.1, 1.1, a.distance_to(b) + 0.1), Transform3D(Basis(), mid)])
