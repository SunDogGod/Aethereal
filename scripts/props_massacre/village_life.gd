@tool
extends "res://scripts/props_massacre/village_prop_base.gd"
## The small living things and hanging things of the village, picked from Kind: cats, birds,
## hens, a bird cage, a wind chime, a hanging paper lantern, an iron window grille with a flower
## box (on a wall), strings of drying persimmons (on a wall). Walk-through; small, so give them a
## Draw distance. Origin: on the floor or ledge for animals (facing +Z); at the hook for hanging
## things; on the wall plane for wall things (the wall behind, -Z).
## idle_motion.gd on a parent node makes a bird peck or a lantern sway.

@export_enum("Cat sitting", "Cat curled", "Cat walking", "Bird", "Birds on a ledge", "Bird cage", "Wind chime",
		"Hanging lantern", "Window grille", "Persimmon strings", "Hens") var kind := 0:
	set(value):
		kind = value
		_rebuild()


func _build() -> void:
	match kind:
		0: _cat_sitting()
		1: _cat_curled()
		2: _cat_walking()
		3: _bird(Vector3.ZERO, 0.0)
		4:
			for i in 3:
				_bird(Vector3(-0.5 + i * 0.45 + rnd(i) * 0.15, 0, rnd(i + 3) * 0.06), (rnd(i + 7) - 0.5) * 2.4)
		5: _cage()
		6: _chime()
		7: _lantern()
		8: _grille()
		9: _persimmons()
		10:
			_hen(Vector3(0, 0, 0), 0.3)
			_hen(Vector3(0.6, 0, -0.35), -1.2)


func _fur() -> Array:
	match variant % 4:
		0: return [M.ginger, M.white]
		1: return [M.black, M.black]
		2: return [M.white, M.ginger]
		_: return [M.bird, M.white]


func _head(c: Vector3, yaw: float, fur: Material, belly: Material) -> void:
	var b := Basis(Vector3.UP, yaw)
	pm.sphere(fur, 0.075, 0.13, Transform3D(b, c), 8, 4)
	pm.sphere(belly, 0.035, 0.05, Transform3D(b, c + b * Vector3(0, -0.025, 0.06)), 6, 3)
	for sx: float in [-1.0, 1.0]:
		pm.cyl(fur, 0.0, 0.03, 0.06, Transform3D(b, c + b * Vector3(sx * 0.04, 0.075, -0.005)), 4)
		pm.box(M.dark, Vector3(0.018, 0.012, 0.01), Transform3D(b, c + b * Vector3(sx * 0.03, 0.01, 0.07)))


func _cat_sitting() -> void:
	var f := _fur()
	pm.sphere(f[0], 0.11, 0.2, at(0, 0.1, -0.03), 8, 4)
	pm.sphere(f[1], 0.075, 0.2, at(0, 0.17, 0.05), 8, 4)
	for sx: float in [-1.0, 1.0]:
		pm.cyl(f[0], 0.025, 0.025, 0.14, at(sx * 0.04, 0.07, 0.08), 5)
	_head(Vector3(0, 0.3, 0.05), (rnd(1) - 0.5) * 0.9, f[0], f[1])
	var prev := Vector3(0, 0.03, -0.12)
	for k in range(1, 6):  # the tail curled round the feet
		var a := k * 0.55
		var p := Vector3(sin(a) * 0.14, 0.025, -0.12 + (1.0 - cos(a)) * 0.12)
		pm.stick(f[0], prev, p, 0.035)
		prev = p


func _cat_curled() -> void:
	var f := _fur()
	pm.sphere(f[0], 0.16, 0.13, at(0, 0.065, 0), 10, 4)
	_head(Vector3(0.1, 0.08, 0.1), 0.9, f[0], f[1])
	var prev := Vector3(-0.12, 0.03, 0.05)
	for k in range(1, 6):
		var a := PI * 0.6 + k * 0.4
		var p := Vector3(cos(a) * 0.17, 0.03, sin(a) * 0.17 + 0.03)
		pm.stick(f[0], prev, p, 0.04)
		prev = p


func _cat_walking() -> void:
	var f := _fur()
	pm.sphere(f[0], 0.08, 0.3, at(0, 0.22, 0, Basis(Vector3.RIGHT, PI * 0.5)), 8, 4)
	for p: Vector3 in [Vector3(-0.045, 0, 0.1), Vector3(0.045, 0, 0.06), Vector3(-0.045, 0, -0.1), Vector3(0.045, 0, -0.07)]:
		pm.cyl(f[1] if p.z > 0 else f[0], 0.022, 0.02, 0.2, at(p.x, 0.1, p.z), 5)
	_head(Vector3(0, 0.3, 0.17), (rnd(2) - 0.5) * 0.6, f[0], f[1])
	pm.stick(f[0], Vector3(0, 0.25, -0.15), Vector3(0, 0.42, -0.24), 0.035)
	pm.stick(f[0], Vector3(0, 0.42, -0.24), Vector3(0.03, 0.5, -0.2), 0.035)


func _bird(c: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var body: Material = M.bird if variant % 3 else M.dark
	pm.sphere(body, 0.045, 0.07, Transform3D(b, c + Vector3(0, 0.045, 0)), 6, 3)
	pm.sphere(M.white if variant % 3 == 1 else body, 0.03, 0.05, Transform3D(b, c + b * Vector3(0, 0.085, 0.03)), 6, 3)
	pm.cyl(M.ochre, 0.0, 0.01, 0.025, Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), c + b * Vector3(0, 0.085, 0.065)), 4)
	pm.box(body, Vector3(0.03, 0.01, 0.07), Transform3D(b * Basis(Vector3.RIGHT, -0.3), c + b * Vector3(0, 0.045, -0.06)))


func _hen(c: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var body: Material = M.linen if variant % 2 == 0 else M.ochre
	pm.sphere(body, 0.13, 0.2, Transform3D(b, c + Vector3(0, 0.2, 0)), 8, 4)
	pm.sphere(body, 0.06, 0.11, Transform3D(b, c + b * Vector3(0, 0.33, 0.1)), 6, 3)
	pm.box(M.red, Vector3(0.02, 0.05, 0.06), Transform3D(b, c + b * Vector3(0, 0.4, 0.1)))
	pm.cyl(M.ochre, 0.0, 0.02, 0.04, Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), c + b * Vector3(0, 0.33, 0.17)), 4)
	pm.box(body, Vector3(0.08, 0.12, 0.08), Transform3D(b * Basis(Vector3.RIGHT, 0.6), c + b * Vector3(0, 0.3, -0.13)))
	for sx: float in [-1.0, 1.0]:
		pm.stick(M.ochre, c + b * Vector3(sx * 0.04, 0.1, 0), c + b * Vector3(sx * 0.04, 0, 0.02), 0.015)


func _cage() -> void:
	pm.stick(M.rope, Vector3.ZERO, Vector3(0, -0.25, 0), 0.015)
	pm.cyl(M.straw, 0.02, 0.17, 0.12, at(0, -0.31, 0), 8)
	for i in 10:
		var a := TAU * i / 10.0
		pm.stick(M.straw, Vector3(cos(a) * 0.17, -0.37, sin(a) * 0.17), Vector3(cos(a) * 0.17, -0.72, sin(a) * 0.17), 0.012)
	pm.cyl(M.plank, 0.19, 0.19, 0.04, at(0, -0.74, 0), 10)
	pm.cyl(M.straw, 0.008, 0.008, 0.3, at(0, -0.55, 0, Basis(Vector3.FORWARD, PI * 0.5)), 4)
	_bird(Vector3(0, -0.545, 0), rnd(5) * 3.0)


func _chime() -> void:
	pm.stick(M.rope, Vector3.ZERO, Vector3(0, -0.06, 0), 0.01)
	pm.sphere(M.ceramic, 0.07, 0.11, at(0, -0.1, 0), 8, 3)
	pm.stick(M.rope, Vector3(0, -0.12, 0), Vector3(0, -0.3, 0), 0.006)
	pm.box(M.paper, Vector3(0.07, 0.2, 0.005), at(0, -0.4, 0))


func _lantern() -> void:
	pm.stick(M.timber, Vector3.ZERO, Vector3(0, -0.2, 0), 0.02)
	var paper: Material = M.red_paper if variant % 2 == 0 else M.lit
	pm.cyl(M.timber, 0.13, 0.13, 0.05, at(0, -0.22, 0), 8)
	pm.sphere(paper, 0.2, 0.46, at(0, -0.46, 0), 8, 4)
	pm.cyl(M.timber, 0.13, 0.13, 0.05, at(0, -0.7, 0), 8)
	pm.box(M.red, Vector3(0.03, 0.18, 0.03), at(0, -0.81, 0))


func _grille() -> void:
	pm.box(M.dark, Vector3(0.9, 1.0, 0.02), at(0, 0, 0.01))
	pm.box(M.lit if variant % 2 == 0 else M.dark, Vector3(0.8, 0.9, 0.02), at(0, 0, 0.02))
	for k in 6:
		pm.box(M.iron, Vector3(0.03, 1.1, 0.03), at(-0.375 + k * 0.15, 0, 0.12))
	for y: float in [-0.45, 0.0, 0.45]:
		pm.box(M.iron, Vector3(0.95, 0.03, 0.03), at(0, y, 0.12))
	pm.box(M.iron, Vector3(0.95, 0.03, 0.2), at(0, 0.56, 0.08))
	# The flower box on the sill, geraniums spilling over.
	pm.box(M.clay, Vector3(0.9, 0.18, 0.24), at(0, -0.62, 0.16))
	for i in 5:
		pm.sphere(M.leaf, 0.12, 0.14, at(-0.34 + i * 0.17, -0.48, 0.18), 6, 3)
		pm.sphere(M.red if (i + variant) % 3 else M.blossom, 0.05, 0.06, at(-0.34 + i * 0.17, -0.4, 0.24), 4, 2)


func _persimmons() -> void:
	pm.box(M.timber, Vector3(1.4, 0.05, 0.05), at(0, 0, 0.12))
	for i in 5:
		var x := -0.56 + i * 0.28
		pm.stick(M.rope, Vector3(x, 0, 0.12), Vector3(x, -0.85 - rnd(i) * 0.2, 0.12), 0.01)
		for k in 6:
			pm.sphere(M.fruit, 0.04, 0.07, at(x, -0.1 - k * 0.13, 0.12), 5, 3)
