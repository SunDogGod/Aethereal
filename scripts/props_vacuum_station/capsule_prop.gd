@tool
extends "res://scripts/props_vacuum_station/station_prop_base.gd"
## Things inside the capsule, picked from Kind: bedding for a bunk, the table's legs and stools,
## galley fittings, a shelf, a pack and bedroll, boots, a rug, the training dummy, the practice
## sword rack, a bench, a hanging bag, weights, coat pegs, a table lamp. Origin on the floor (or on
## the surface it sits on, or on the wall for wall things), facing +Z.

const M := {
	wood = preload("res://materials/wood.tres"), metal = preload("res://materials/metal.tres"),
	dark = preload("res://materials/rubber.tres"), ceramic = preload("res://materials/ceramic.tres"),
	plaster = preload("res://materials/white_plaster.tres"), teal = preload("res://materials/paint_teal.tres"),
	red = preload("res://materials/paint_red.tres"), yellow = preload("res://materials/paint_yellow.tres"),
	rug = preload("res://materials/awning_red.tres"), concrete = preload("res://materials/concrete.tres"),
	brass = preload("res://materials/brass.tres"), warm = preload("res://materials/window_glow.tres"),
	hull = preload("res://materials/vacuum_station_hull.tres"),
}

@export_enum("Bedding", "Table legs and stools", "Galley fittings", "Wall shelf", "Pack and bedroll",
		"Boots", "Rug", "Training dummy", "Sword rack", "Bench", "Hanging bag", "Weights", "Coat pegs",
		"Table lamp") var kind := 0:
	set(value):
		kind = value
		_rebuild()


func _build() -> void:
	match kind:
		0: _bedding()
		1: _table()
		2: _galley()
		3: _shelf()
		4: _pack()
		5: _boots()
		6: _rug()
		7: _dummy()
		8: _rack()
		9: _bench()
		10: _bag()
		11: _weights()
		12: _pegs()
		13: _lamp()


## On top of a 2 x 5 m bunk (origin on the bunk's top centre): a mattress, a pillow at -Z, a
## blanket thrown back (variant 1: folded square at the foot).
func _bedding() -> void:
	span(M.plaster, Vector3(-0.9, 0, -2.4), Vector3(0.9, 0.14, 2.4))
	pm.box(M.plaster, Vector3(0.9, 0.12, 0.45), at(0, 0.2, -1.95, Basis(Vector3.RIGHT, -0.15)))
	var cloth: Material = M.teal if variant % 2 == 0 else M.red
	if variant % 2 == 0:
		span(cloth, Vector3(-0.92, 0.14, -0.6), Vector3(0.92, 0.2, 2.3))
		pm.box(cloth, Vector3(1.84, 0.1, 0.35), at(0, 0.24, -0.75, Basis(Vector3.RIGHT, 0.3)))
	else:
		span(cloth, Vector3(-0.5, 0.14, 1.4), Vector3(0.5, 0.32, 2.1))
	fp(Vector3.ZERO, Vector3.ZERO)


## Legs for the 2 x 1.3 m table top (origin on the floor under its centre; top 0.73 m up) and
## two stools pulled out on the +X side.
func _table() -> void:
	for x in [-0.9, 0.9]:
		for z in [-0.55, 0.55]:
			span(M.wood, Vector3(x - 0.04, 0, z - 0.04), Vector3(x + 0.04, 0.68, z + 0.04))
	span(M.wood, Vector3(-0.9, 0.55, -0.02), Vector3(0.9, 0.6, 0.02))  # stretcher
	for z in [-0.35, 0.4]:
		var c := Vector3(1.35, 0, z)
		pm.cyl(M.wood, 0.19, 0.19, 0.05, at(c.x, 0.45, c.z), 10)
		for i in 3:
			var a: float = TAU * i / 3.0 + z
			pm.stick(M.metal, c + Vector3(cos(a) * 0.12, 0.43, sin(a) * 0.12), c + Vector3(cos(a) * 0.17, 0, sin(a) * 0.17), 0.025)
	pm.cyl(M.ceramic, 0.04, 0.035, 0.09, at(0.55, 0.825, 0.3), 8)  # a cup left on the table
	fp(Vector3(2.0, 0.68, 1.3), Vector3(0, 0.34, 0))


## On the galley counter (origin on its top, back edge centre, counter 3.4 x 1 m running along X):
## a sink, a tap, a kettle, cups, a board; a cabinet and a utensil rail on the wall above.
func _galley() -> void:
	span(M.dark, Vector3(0.5, -0.12, 0.25), Vector3(1.2, 0.012, 0.75))  # sink basin (dark)
	span(M.metal, Vector3(0.45, 0.0, 0.2), Vector3(1.25, 0.02, 0.25))
	pm.stick(M.metal, Vector3(0.85, 0.0, 0.12), Vector3(0.85, 0.32, 0.12), 0.04)
	pm.stick(M.metal, Vector3(0.85, 0.32, 0.12), Vector3(0.85, 0.3, 0.32), 0.035)
	pm.cyl(M.metal, 0.11, 0.13, 0.22, at(-0.9, 0.11, 0.4), 10)  # kettle
	pm.stick(M.dark, Vector3(-0.97, 0.26, 0.4), Vector3(-0.83, 0.26, 0.4), 0.03)
	for i in 3:
		pm.cyl(M.ceramic, 0.04, 0.035, 0.09, at(-0.4 + i * 0.13, 0.045, 0.62), 8)
	pm.box(M.wood, Vector3(0.45, 0.025, 0.3), at(-1.3, 0.0125, 0.55, Basis(Vector3.UP, 0.15)))
	span(M.hull, Vector3(-1.6, 1.05, 0.0), Vector3(1.6, 1.75, 0.4))  # wall cabinet
	span(M.dark, Vector3(-0.01, 1.08, 0.4), Vector3(0.01, 1.72, 0.42))
	span(M.warm, Vector3(-1.5, 1.03, 0.05), Vector3(1.5, 1.05, 0.35))  # the strip light under it
	span(M.brass, Vector3(-1.4, 0.75, 0.0), Vector3(-0.2, 0.78, 0.06))
	for i in 4:
		pm.stick(M.metal, Vector3(-1.3 + i * 0.3, 0.76, 0.06), Vector3(-1.3 + i * 0.3, 0.5, 0.08), 0.025)
	fp(Vector3.ZERO, Vector3.ZERO)


## A wall shelf with jars and a folded cloth (origin on the wall at shelf height).
func _shelf() -> void:
	span(M.wood, Vector3(-0.8, -0.03, 0), Vector3(0.8, 0.0, 0.28))
	for x in [-0.6, 0.6]:
		pm.box(M.metal, Vector3(0.03, 0.2, 0.2), at(x, -0.13, 0.1))
	for i in 4:
		var mat: Material = [M.ceramic, M.brass, M.ceramic, M.teal][(i + variant) % 4]
		pm.cyl(mat, 0.06, 0.06, 0.14 + 0.03 * (i % 2), at(-0.6 + i * 0.16, 0.08, 0.14), 8)
	span(M.red if variant % 2 == 0 else M.yellow, Vector3(0.15, 0.0, 0.04), Vector3(0.55, 0.1, 0.26))
	fp(Vector3.ZERO, Vector3.ZERO)


## A travel pack leaning on the wall and a rolled bedroll beside it.
func _pack() -> void:
	pm.box(M.yellow if variant % 2 else M.wood, Vector3(0.45, 0.6, 0.28), at(0, 0.31, 0.14, Basis(Vector3.RIGHT, -0.12)))
	pm.box(M.dark, Vector3(0.36, 0.22, 0.08), at(0, 0.3, 0.32, Basis(Vector3.RIGHT, -0.12)))
	pm.cyl(M.teal, 0.13, 0.13, 0.7, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.65, 0.13, 0.22)), 8)
	fp(Vector3.ZERO, Vector3.ZERO)


## Two pairs of boots by a wall.
func _boots() -> void:
	for i in 4:
		var x := -0.33 + i * 0.22 + (0.05 if i >= 2 else 0.0)
		var tilt := 0.15 * ((i % 2) * 2 - 1)
		span(M.dark, Vector3(x - 0.05, 0, 0.0), Vector3(x + 0.05, 0.28, 0.12))
		pm.box(M.dark, Vector3(0.1, 0.08, 0.26), at(x, 0.04, 0.12, Basis(Vector3.UP, tilt)))
	fp(Vector3.ZERO, Vector3.ZERO)


## A striped rug, flush (1 cm).
func _rug() -> void:
	face(M.rug, Vector2(2.2, 1.5), at(0, 0.01, 0, Basis(Vector3.RIGHT, -PI * 0.5)))
	fp(Vector3.ZERO, Vector3.ZERO)


## A wooden training dummy: cross feet, a post, three arms, a head block.
func _dummy() -> void:
	span(M.wood, Vector3(-0.45, 0, -0.07), Vector3(0.45, 0.1, 0.07))
	span(M.wood, Vector3(-0.07, 0, -0.45), Vector3(0.07, 0.1, 0.45))
	pm.cyl(M.wood, 0.14, 0.16, 1.55, at(0, 0.1 + 0.775, 0), 8)
	pm.box(M.wood, Vector3(0.24, 0.28, 0.24), at(0, 1.8, 0, Basis(Vector3.UP, 0.3)))
	pm.stick(M.wood, Vector3(0, 1.4, 0), Vector3(0.45, 1.5, 0.35), 0.06)
	pm.stick(M.wood, Vector3(0, 1.4, 0), Vector3(-0.45, 1.5, 0.35), 0.06)
	pm.stick(M.wood, Vector3(0, 0.95, 0), Vector3(0.05, 0.9, 0.5), 0.06)
	for y in [0.5, 1.2]:
		pm.cyl(M.dark, 0.165, 0.165, 0.06, at(0, y, 0), 8)  # binding
	fp(Vector3(0.5, 1.95, 0.5), Vector3(0, 0.975, 0))


## Practice blades and a staff on pegs (origin on the rack's face at its centre, 2 m up the board).
func _rack() -> void:
	for i in 4:
		var z := -1.3 + i * 0.55
		span(M.metal, Vector3(z - 0.02, 0.5, 0), Vector3(z + 0.02, 0.54, 0.12))
		span(M.metal, Vector3(z - 0.02, -0.3, 0), Vector3(z + 0.02, -0.26, 0.12))
		pm.box(M.wood, Vector3(0.05, 1.0, 0.025), at(z + 0.08, 0.1, 0.1))
		pm.box(M.dark, Vector3(0.16, 0.03, 0.04), at(z + 0.08, -0.32, 0.1))  # guard
		pm.box(M.wood, Vector3(0.035, 0.22, 0.035), at(z + 0.08, -0.46, 0.1))  # grip
	pm.stick(M.wood, Vector3(1.4, -0.95, 0.12), Vector3(1.55, 0.85, 0.12), 0.05)  # staff leaning
	fp(Vector3.ZERO, Vector3.ZERO)


## A low wooden bench, a towel over it and a water jug on it.
func _bench() -> void:
	span(M.wood, Vector3(-0.9, 0.38, -0.2), Vector3(0.9, 0.45, 0.2))
	for x in [-0.75, 0.75]:
		span(M.wood, Vector3(x - 0.05, 0, -0.17), Vector3(x + 0.05, 0.38, 0.17))
	span(M.plaster, Vector3(-0.5, 0.45, -0.21), Vector3(-0.1, 0.47, 0.21))
	span(M.plaster, Vector3(-0.5, 0.25, 0.2), Vector3(-0.1, 0.47, 0.22))
	pm.cyl(M.ceramic, 0.09, 0.1, 0.28, at(0.5, 0.59, 0), 8)
	fp(Vector3(1.8, 0.47, 0.42), Vector3(0, 0.235, 0))


## A heavy bag on a chain from the ceiling, `variant` = ceiling height above the floor in metres
## (0 = 6.7 m, the capsule's).
func _bag() -> void:
	var top := 6.7 if variant <= 0 else float(variant)
	pm.cyl(M.red, 0.26, 0.26, 1.1, at(0, 1.55, 0), 10, 2)
	pm.cyl(M.dark, 0.27, 0.27, 0.06, at(0, 2.1, 0), 10)
	pm.stick(M.metal, Vector3(0, 2.1, 0), Vector3(0, top, 0), 0.03)
	fp(Vector3(0.54, 1.2, 0.54), Vector3(0, 1.5, 0))


## A pair of kettle weights and a short bar by the wall.
func _weights() -> void:
	for x in [-0.25, 0.1]:
		pm.sphere(M.dark, 0.13, 0.24, at(x, 0.12, 0), 8, 4)
		pm.ring(M.dark, 0.05, 0.08, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.27, 0)), 8, 3)
	pm.stick(M.metal, Vector3(0.35, 0.06, -0.3), Vector3(0.45, 0.06, 0.4), 0.04)
	fp(Vector3.ZERO, Vector3.ZERO)


## A peg rail on the wall with a cloak and a scarf hanging (origin on the wall at rail height).
func _pegs() -> void:
	span(M.wood, Vector3(-0.6, -0.05, 0), Vector3(0.6, 0.05, 0.04))
	for x in [-0.4, 0.0, 0.4]:
		pm.stick(M.brass, Vector3(x, 0, 0.04), Vector3(x, 0.05, 0.14), 0.03)
	pm.box(M.teal if variant % 2 == 0 else M.dark, Vector3(0.5, 1.1, 0.08), at(-0.4, -0.5, 0.12))
	pm.box(M.yellow, Vector3(0.14, 0.7, 0.03), at(0.4, -0.33, 0.1))
	fp(Vector3.ZERO, Vector3.ZERO)


## A small lamp with a warm glowing shade (sits on a table or shelf).
func _lamp() -> void:
	pm.cyl(M.brass, 0.08, 0.09, 0.03, at(0, 0.015, 0), 8)
	pm.stick(M.brass, Vector3(0, 0.03, 0), Vector3(0, 0.3, 0), 0.025)
	pm.cyl(M.warm, 0.07, 0.13, 0.16, at(0, 0.36, 0), 8)
	fp(Vector3.ZERO, Vector3.ZERO)
