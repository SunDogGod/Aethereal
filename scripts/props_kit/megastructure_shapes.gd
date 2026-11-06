extends RefCounted
## The big silhouettes megastructure_kit.gd picks from. Each static function draws into the
## PropMesh and appends [size, Transform3D] pairs to `boxes` for the parts that get collision.
## Conventions: the wall a piece hangs off is the plane z = 0 behind the origin (-Z); pieces
## reach out along +Z; a vertical piece stands on the origin and rises along +Y.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const IRON := preload("res://materials/kitb_iron.tres")
const RUST := preload("res://materials/kitb_rust.tres")
const GRATING := preload("res://materials/grating.tres")


static func _at(p: Vector3) -> Transform3D:
	return Transform3D(Basis(), p)


## A slanted brace from high on the wall down to a foot block `length` out on the floor.
static func buttress(pm: PropMesh, mat: Material, length: float, height: float, radius: float, variant: int, boxes: Array) -> void:
	var w := maxf(radius, 0.6)
	var pier := Vector3(w, height, 1.0)
	pm.box(mat, pier, _at(Vector3(0, height * 0.5, 0.5)))
	boxes.append([pier, _at(Vector3(0, height * 0.5, 0.5))])
	var top := Vector3(0, height - w * 0.5, 0.8)
	var foot := Vector3(0, 0.9, length)
	var brace := Vector3(w, top.distance_to(foot) + w, w * 1.1)
	pm.box(mat, brace, PropMesh.along(top, foot))
	boxes.append([brace, PropMesh.along(top, foot)])
	var block := Vector3(w + 0.8, 1.6, 2.2)
	pm.box(mat, block, _at(Vector3(0, 0.8, length - 0.2)))
	boxes.append([block, _at(Vector3(0, 0.8, length - 0.2))])
	pm.box(mat, Vector3(w + 0.6, 0.6, 1.6), _at(Vector3(0, height + 0.3, 0.8)))  # the cap
	if variant % 2 == 1:  # a strap of iron plating half way down the brace
		pm.box(IRON, Vector3(w + 0.2, 0.5, w * 1.3), PropMesh.along(top.lerp(foot, 0.45), top.lerp(foot, 0.55)))


## Two piers `length` apart with a chain of boxes arching between them.
static func arch(pm: PropMesh, mat: Material, length: float, height: float, radius: float, boxes: Array) -> void:
	var w := maxf(radius, 0.6)
	var rx := length * 0.5
	var ry := minf(length * 0.42, height * 0.6)
	for s in [-1, 1]:
		var pier := Vector3(w, height, w)
		pm.box(mat, pier, _at(Vector3(s * rx, height * 0.5, 0)))
		boxes.append([pier, _at(Vector3(s * rx, height * 0.5, 0))])
		pm.box(mat, Vector3(w + 0.5, 0.6, w + 0.5), _at(Vector3(s * rx, height + 0.3, 0)))  # the springer
	var n := 12
	var prev := Vector3(-rx, height, 0)
	for i in range(1, n + 1):
		var a := PI * (1.0 - float(i) / n)
		var p := Vector3(cos(a) * rx, height + sin(a) * ry, 0)
		pm.box(mat, Vector3(w * 0.9, prev.distance_to(p) + 0.4, w), PropMesh.along(prev, p))
		prev = p
	pm.box(mat, Vector3(w * 1.4, w * 0.8, w * 1.3), _at(Vector3(0, height + ry, 0)))  # the keystone


## A round shaft from just under the floor up `height` metres, banded every 10 m, so its top
## is lost in the fog. Collision is one cylinder (a box would stick out at the corners).
static func shaft(pm: PropMesh, mat: Material, height: float, radius: float, variant: int, boxes: Array) -> void:
	var r := maxf(radius, 0.5)
	pm.cyl(mat, r, r, height + 2.0, _at(Vector3(0, height * 0.5 - 1.0, 0)), 12, clampi(int(height / 6.0), 1, 24))
	pm.cyl(mat, r * 1.25, r * 1.4, 1.2, _at(Vector3(0, 0.6, 0)), 12)  # the plinth
	var y := 10.0 if variant % 2 == 0 else 6.0
	while y < height - 1.0:
		pm.cyl(IRON if variant % 3 == 2 else mat, r * 1.08, r * 1.08, 0.7, _at(Vector3(0, y, 0)), 12)
		y += 10.0
	boxes.append([Vector3(r * 2.0, height + 2.0, r * 2.0), _at(Vector3(0, height * 0.5 - 1.0, 0)), "cyl"])


## A stepped slab: each step `radius` m shallower than the one below, `length` wide.
static func setback(pm: PropMesh, mat: Material, length: float, height: float, radius: float, variant: int, boxes: Array) -> void:
	var steps := 4 + variant % 3
	var run := maxf(radius, 1.0)
	var sh := height / steps
	for i in steps:
		var depth := run * (steps - i)
		var size := Vector3(length, sh, depth)
		var xf := _at(Vector3(0, sh * (i + 0.5), depth * 0.5))
		pm.box(mat, size, xf)
		boxes.append([size, xf])
		pm.box(IRON, Vector3(length + 0.1, 0.25, 0.3), _at(Vector3(0, sh * (i + 1) - 0.12, depth + 0.1)))  # a drip edge


## A cantilevered walkway out of the wall, broken off at its far end: slab, two braces
## underneath, railing posts, torn rebar at the break.
static func walkway(pm: PropMesh, mat: Material, length: float, radius: float, boxes: Array) -> void:
	var w := maxf(radius, 1.0) * 2.0
	var slab := Vector3(w, 0.5, length)
	pm.box(mat, slab, _at(Vector3(0, -0.25, length * 0.5)))
	boxes.append([slab, _at(Vector3(0, -0.25, length * 0.5))])
	for s in [-1, 1]:
		var top := Vector3(s * w * 0.38, -0.5, length * 0.72)
		var bot := Vector3(s * w * 0.38, -minf(length * 0.6, 6.0), 0.3)
		pm.box(mat, Vector3(0.6, top.distance_to(bot) + 0.4, 0.6), PropMesh.along(top, bot))
		var n := maxi(2, int(length / 2.0))
		for k in n:
			var z := (k + 0.5) * length / n
			pm.stick(IRON, Vector3(s * (w * 0.5 - 0.08), 0, z), Vector3(s * (w * 0.5 - 0.08), 1.1, z), 0.07)
		pm.stick(IRON, Vector3(s * (w * 0.5 - 0.08), 1.1, 0), Vector3(s * (w * 0.5 - 0.08), 1.1, length * 0.92), 0.07)
		boxes.append([Vector3(0.12, 1.1, length * 0.92), _at(Vector3(s * (w * 0.5 - 0.08), 0.55, length * 0.46))])
	# The break: staggered stubs past the slab's end, rebar bent down out of them.
	for k in 3:
		var x := (k - 1) * w * 0.33
		var over := 0.3 + 0.5 * absf(sin(k * 2.3 + x))
		pm.box(mat, Vector3(w * 0.3, 0.46, over * 2.0), _at(Vector3(x, -0.27, length)))
		var a := Vector3(x, -0.25, length + over)
		var b := a + Vector3(0.1 * k - 0.1, -0.5 - 0.3 * k, 0.7)
		pm.stick(RUST, a, b, 0.04)
		pm.stick(RUST, b, b + Vector3(0.05, -0.6, 0.1), 0.04)


## Three or more chains hanging from a collar on the ceiling, splayed a little, hooks at the end.
static func chains(pm: PropMesh, height: float, radius: float, variant: int) -> void:
	var count := 3 + variant % 3
	pm.cyl(IRON, 0.5, 0.5, 0.3, _at(Vector3(0, -0.15, 0)), 8)
	for c in count:
		var a := TAU * c / count + variant
		var top := Vector3(cos(a) * 0.3, -0.3, sin(a) * 0.3)
		var bottom := Vector3(cos(a) * radius, -height, sin(a) * radius)
		var axis := PropMesh.along(top, bottom)
		var links := maxi(2, int(top.distance_to(bottom) / 0.52))
		for i in links:
			var p := top.lerp(bottom, (i + 0.5) / links)
			var twist := axis.basis * Basis(Vector3.UP, PI * 0.5 * (i % 2))
			pm.box(IRON, Vector3(0.11, 0.7, 0.38), Transform3D(twist, p))
		pm.ring(RUST, 0.12, 0.3, Transform3D(axis.basis * Basis(Vector3.RIGHT, PI * 0.5), bottom + Vector3(0, -0.25, 0)), 8, 4)


## A lattice gantry `length` long along X, `radius` wide: grating deck, trusses each side.
static func gantry(pm: PropMesh, length: float, radius: float, boxes: Array) -> void:
	var w := maxf(radius, 1.2)
	var h := 2.2
	var deck := Vector3(length, 0.12, w)
	pm.box(GRATING, deck, _at(Vector3(0, 0.06, 0)))
	boxes.append([Vector3(length, 0.12, w), _at(Vector3(0, 0.06, 0))])
	var n := maxi(1, int(length / 2.5))
	for s in [-1, 1]:
		var z: float = s * (w * 0.5 - 0.1)
		pm.box(IRON, Vector3(length, 0.2, 0.2), _at(Vector3(0, 0.1, z)))
		pm.box(IRON, Vector3(length, 0.2, 0.2), _at(Vector3(0, h, z)))
		pm.box(IRON, Vector3(length, 0.08, 0.08), _at(Vector3(0, h * 0.5, z)))
		for k in n + 1:
			var x := -length * 0.5 + length * k / n
			pm.stick(IRON, Vector3(x, 0, z), Vector3(x, h, z), 0.14)
			if k < n:
				var x2 := x + length / n
				if k % 2 == 0:
					pm.stick(IRON, Vector3(x, 0.1, z), Vector3(x2, h - 0.1, z), 0.08)
				else:
					pm.stick(IRON, Vector3(x, h - 0.1, z), Vector3(x2, 0.1, z), 0.08)
		boxes.append([Vector3(length, h, 0.2), _at(Vector3(0, h * 0.5, z))])
	for k in n + 1:  # cross ties over the top
		var x := -length * 0.5 + length * k / n
		pm.box(IRON, Vector3(0.14, 0.14, w), _at(Vector3(x, h + 0.1, 0)))
