@tool
extends "res://scripts/props_massacre/village_prop_base.gd"
## A festival market stall: a plank counter on a timber frame, four posts, a cloth awning or a
## little tiled roof, a shelf behind with more goods, a stool for the seller (who is at the
## festival). Picked from Kind by what it sells. The counter faces +Z (the customer's side);
## origin on the ground under the counter's middle. Solid: the counter and the space behind it.
## Food: a pot on glowing coals (put a steam_vent.gd node over it at (0.5, 1.25, -0.05)).

const Roof := preload("res://scripts/props_massacre/roof_kit.gd")
const W := 2.4
const D := 1.6

@export_enum("Fruit and greens", "Cloth", "Pottery", "Food", "Lanterns") var kind := 0:
	set(value):
		kind = value
		_rebuild()


func _build() -> void:
	# The counter at the front, the back shelf, the posts.
	pm.box(M.plank, Vector3(W, 0.06, 0.7), at(0, 0.9, 0))
	pm.box(M.timber, Vector3(W - 0.1, 0.84, 0.06), at(0, 0.44, 0.3))
	for sx: float in [-1.0, 1.0]:
		pm.box(M.timber, Vector3(0.06, 0.84, 0.6), at(sx * (W * 0.5 - 0.05), 0.44, 0))
		pm.box(M.timber, Vector3(0.1, 2.28, 0.1), at(sx * W * 0.5, 1.14, 0.35))
		pm.box(M.timber, Vector3(0.1, 2.7, 0.1), at(sx * W * 0.5, 1.35, -D + 0.1))
	pm.box(M.plank, Vector3(W - 0.2, 0.05, 0.4), at(0, 1.2, -D + 0.3))
	pm.box(M.plank, Vector3(W - 0.2, 0.05, 0.4), at(0, 0.6, -D + 0.3))
	pm.cyl(M.timber, 0.16, 0.16, 0.45, at(0.6, 0.225, -0.75), 8)  # the seller's stool
	# The roof: a striped cloth awning or tiled.
	if variant % 2 == 0:
		var cloth: Material = [M.red, M.indigo, M.ochre][(variant / 2) % 3]
		var a := atan2(0.4, D + 0.3)
		pm.box(cloth, Vector3(W + 0.4, 0.04, D + 0.5), at(0, 2.52, -D * 0.5 + 0.25, Basis(Vector3.RIGHT, a)))
		for i in 6:
			pm.box(M.linen if i % 2 else cloth, Vector3((W + 0.4) / 6.0, 0.25, 0.03), at(-W * 0.5 - 0.2 + (i + 0.5) * (W + 0.4) / 6.0, 2.2, 0.62))
	else:
		Roof.pent(pm, {roof = M.clay, ridge = M.ridge, timber = M.timber}, at(0, 0, -D + 0.05), W + 0.5, D + 0.6, 2.75, 0.45)
	match kind:
		0: _greens()
		1: _cloth()
		2: _pottery()
		3: _food()
		4: _lanterns()
	fp(Vector3(W + 0.1, 0.95, D + 0.15), Vector3(0, 0.475, -D * 0.5 + 0.35))


func _greens() -> void:
	var goods: Array = [M.fruit, M.leaf2, M.red, M.ochre]
	for i in 4:
		var x := -0.85 + i * 0.57
		pm.cyl(M.straw, 0.24, 0.2, 0.16, at(x, 1.01, 0.02), 8)
		for k in 6:
			pm.sphere(goods[(i + k / 4) % 4], 0.065, 0.11, at(x - 0.1 + (k % 3) * 0.1, 1.1 + (k / 3) * 0.05, -0.05 + (k % 2) * 0.1), 5, 3)
	for i in 3:
		pm.box(M.straw, Vector3(0.5, 0.3, 0.35), at(-0.7 + i * 0.7, 1.38, -D + 0.3))
		pm.box(M.leaf2, Vector3(0.44, 0.06, 0.3), at(-0.7 + i * 0.7, 1.55, -D + 0.3))


func _cloth() -> void:
	var cloths: Array = [M.indigo, M.red, M.linen, M.ochre]
	for i in 5:
		pm.box(cloths[i % 4], Vector3(0.38, 0.06 + i % 2 * 0.06, 0.5), at(-0.9 + i * 0.45, 0.96 + (i % 2) * 0.03, 0))
	for i in 4:  # bolts on the shelf, and lengths hung from the awning rail
		pm.cyl(cloths[(i + 1) % 4], 0.1, 0.1, 0.38, at(-0.75 + i * 0.5, 1.33, -D + 0.3, Basis(Vector3.RIGHT, PI * 0.5)), 8)
		pm.box(cloths[(i + 2) % 4], Vector3(0.45, 1.0, 0.02), at(-0.75 + i * 0.5, 1.75, -D + 0.12))


func _pottery() -> void:
	for i in 6:
		var x := -0.95 + i * 0.38
		var r := 0.08 + rnd(i) * 0.06
		pm.cyl(M.ceramic if i % 2 else M.clay, r, r * 0.7, r * 2.2, at(x, 0.93 + r * 1.1, 0), 8)
	for i in 5:
		pm.cyl(M.ceramic, 0.1, 0.06, 0.06, at(-0.8 + i * 0.4, 1.26, -D + 0.3), 8)
		pm.cyl(M.clay, 0.12, 0.09, 0.3, at(-0.8 + i * 0.4, 0.78, -D + 0.3), 8)


func _food() -> void:
	pm.box(M.stone, Vector3(0.6, 0.2, 0.5), at(0.5, 1.03, -0.05))
	pm.box(M.coal, Vector3(0.4, 0.05, 0.35), at(0.5, 1.15, -0.05))
	pm.cyl(M.iron, 0.26, 0.2, 0.26, at(0.5, 1.3, -0.05), 10)
	pm.cyl(M.water, 0.24, 0.24, 0.02, at(0.5, 1.42, -0.05), 10)
	pm.stick(M.timber, Vector3(0.45, 1.4, -0.05), Vector3(0.2, 1.8, -0.1), 0.03)
	for i in 6:  # skewers and bowls along the counter
		pm.stick(M.straw, Vector3(-1.0 + i * 0.13, 0.95, 0.1), Vector3(-1.0 + i * 0.13, 0.95, -0.15), 0.01)
		pm.sphere(M.fruit, 0.03, 0.04, at(-1.0 + i * 0.13, 0.96, -0.05), 4, 2)
	for i in 4:
		pm.cyl(M.ceramic, 0.07, 0.045, 0.06, at(-0.3 + i * 0.16, 0.96, 0.18), 8)
	pm.box(M.red, Vector3(0.8, 0.6, 0.02), at(-0.5, 1.95, 0.5))  # a cloth sign, no words


func _lanterns() -> void:
	for i in 5:
		var x := -0.9 + i * 0.45
		pm.stick(M.rope, Vector3(x, 2.25, 0.3), Vector3(x, 1.95, 0.3), 0.01)
		pm.sphere(M.lit if i % 2 else M.red_paper, 0.15, 0.32, at(x, 1.8, 0.3), 8, 4)
	for i in 4:
		pm.cyl(M.paper, 0.12, 0.12, 0.3, at(-0.7 + i * 0.45, 1.08, 0), 8)
	for i in 3:
		pm.box(M.paper, Vector3(0.3, 0.3, 0.3), at(-0.6 + i * 0.6, 1.37, -D + 0.3))
