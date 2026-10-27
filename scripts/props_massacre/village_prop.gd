@tool
extends "res://scripts/props_massacre/village_prop_base.gd"
## The village's everyday things, picked from Kind. Origin on the ground; things that stand
## against a wall have it behind them (-Z) and face +Z. Solid ones get a box collision around
## their footprint (turn Solid off to walk through). Length is used by the washing line.

@export_enum("Stone lantern", "Water jar", "Bench", "Firewood", "Buckets", "Produce baskets", "Barrels",
		"Bonsai", "Flower pots", "Hand cart", "Rice sacks", "Parasol", "Lantern post", "Washing line",
		"Well", "Drying rack", "Drum", "Banner") var kind := 0:
	set(value):
		kind = value
		_rebuild()
@export var length := 4.0:
	set(value):
		length = value
		_rebuild()


func _build() -> void:
	match kind:
		0: _toro()
		1: _jar()
		2: _bench()
		3: _firewood()
		4: _buckets()
		5: _baskets()
		6: _barrels()
		7: _bonsai()
		8: _pots()
		9: _cart()
		10: _sacks()
		11: _parasol()
		12: _lantern_post()
		13: _washing()
		14: _well()
		15: _rack()
		16: _drum()
		17: _banner()


func _toro() -> void:
	var stone: Material = M.moss if variant % 3 == 2 else M.stone
	pm.box(stone, Vector3(0.62, 0.16, 0.62), at(0, 0.08, 0))
	pm.cyl(stone, 0.13, 0.16, 0.6, at(0, 0.46, 0), 6)
	pm.box(stone, Vector3(0.5, 0.1, 0.5), at(0, 0.81, 0))
	pm.box(M.lit, Vector3(0.3, 0.26, 0.3), at(0, 0.99, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pm.box(stone, Vector3(0.07, 0.26, 0.07), at(sx * 0.15, 0.99, sz * 0.15))
	pm.cyl(stone, 0.0, 0.46, 0.26, at(0, 1.25, 0, Basis(Vector3.UP, PI * 0.25)), 4)
	pm.sphere(stone, 0.07, 0.14, at(0, 1.42, 0), 6, 3)
	fp(Vector3(0.62, 1.4, 0.62), Vector3(0, 0.7, 0))


func _jar() -> void:
	var r := 0.34 + rnd(1) * 0.1
	pm.cyl(M.clay, r * 0.7, r * 0.6, 0.1, at(0, 0.05, 0), 10)
	pm.cyl(M.clay, r, r * 0.72, 0.42, at(0, 0.31, 0), 10)
	pm.cyl(M.clay, r * 0.72, r, 0.3, at(0, 0.67, 0), 10)
	pm.cyl(M.clay, r * 0.62, r * 0.62, 0.06, at(0, 0.85, 0), 10)
	pm.cyl(M.plank, r * 0.66, r * 0.66, 0.04, at(0, 0.89, 0), 10)
	pm.stick(M.timber, Vector3(0, 0.92, 0), Vector3(r * 0.9, 1.1, 0.05), 0.03)
	pm.cyl(M.timber, 0.06, 0.05, 0.08, at(r * 0.95, 1.08, 0.05), 6)
	fp(Vector3(r * 2, 0.9, r * 2), Vector3(0, 0.45, 0))


func _bench() -> void:
	var l := 1.6 + rnd(2) * 0.6
	pm.box(M.plank, Vector3(l, 0.07, 0.42), at(0, 0.43, 0))
	for sx: float in [-1.0, 1.0]:
		pm.box(M.timber, Vector3(0.08, 0.4, 0.36), at(sx * (l * 0.5 - 0.15), 0.2, 0))
	pm.box(M.timber, Vector3(l - 0.3, 0.06, 0.05), at(0, 0.15, 0))
	if variant % 2 == 0:  # a folded cloth and a cup left on it
		pm.box(M.indigo, Vector3(0.36, 0.04, 0.3), at(-l * 0.25, 0.485, 0))
		pm.cyl(M.ceramic, 0.04, 0.035, 0.08, at(l * 0.3, 0.505, 0.05), 6)
	fp(Vector3(l, 0.47, 0.42), Vector3(0, 0.235, 0))


func _firewood() -> void:
	var l := 1.8
	for row in 4:
		var n := 6 - row
		for i in n:
			var x := -0.55 + i * 0.22 + row * 0.11
			var r := 0.09 + rnd(row * 10 + i) * 0.025
			pm.cyl(M.plank if (i + row) % 3 else M.timber, r, r, 0.5, at(x, 0.1 + row * 0.18, 0.1, Basis(Vector3.RIGHT, PI * 0.5)), 6)
	pm.box(M.timber, Vector3(l, 0.06, 0.8), at(0, 0.98, 0.1))
	for sx: float in [-1.0, 1.0]:
		pm.box(M.timber, Vector3(0.06, 0.95, 0.06), at(sx * (l * 0.5 - 0.1), 0.48, 0.45))
	pm.cyl(M.timber, 0.2, 0.22, 0.4, at(0.6, 0.2, 0.75), 8)  # chopping block, an axe in it
	pm.stick(M.timber, Vector3(0.6, 0.42, 0.75), Vector3(0.75, 0.75, 0.95), 0.04)
	pm.box(M.metal, Vector3(0.04, 0.12, 0.16), at(0.6, 0.44, 0.76))
	fp(Vector3(l, 1.0, 0.8), Vector3(0, 0.5, 0.1))


func _buckets() -> void:
	for i in 3:
		var x := -0.45 + i * 0.42
		var r := 0.15 + rnd(i) * 0.05
		pm.cyl(M.plank, r, r * 0.85, 0.3, at(x, 0.15, rnd(i + 4) * 0.2), 8)
		pm.ring(M.iron, r * 0.98, r * 1.04, at(x, 0.24, rnd(i + 4) * 0.2), 8, 3)
	pm.cyl(M.plank, 0.42, 0.38, 0.18, at(0.15, 0.09, 0.55), 10)  # a washing tub with cloth in it
	pm.cyl(M.water, 0.38, 0.38, 0.02, at(0.15, 0.15, 0.55), 10)
	pm.box(M.linen, Vector3(0.4, 0.05, 0.3), at(0.05, 0.165, 0.5, Basis(Vector3.UP, 0.4)))


func _baskets() -> void:
	var goods: Array = [M.fruit, M.leaf2, M.ochre, M.red]
	for i in 3:
		var x := -0.5 + i * 0.5
		pm.cyl(M.straw, 0.22, 0.17, 0.22, at(x, 0.11, 0), 8)
		var g: Material = goods[(i + variant) % goods.size()]
		for k in 5:
			pm.sphere(g, 0.07, 0.12, at(x - 0.08 + (k % 3) * 0.08, 0.24 + (k / 3) * 0.05, -0.05 + (k % 2) * 0.1), 6, 3)


func _barrels() -> void:
	for p: Vector3 in [Vector3(-0.38, 0, 0), Vector3(0.38, 0, 0), Vector3(0, 0.62, 0)]:
		pm.cyl(M.straw, 0.32, 0.32, 0.6, at(p.x, p.y + 0.3, p.z, Basis(Vector3.RIGHT, PI * 0.5)), 10)
		pm.box(M.red if variant % 2 == 0 else M.indigo, Vector3(0.66, 0.36, 0.06), at(p.x, p.y + 0.31, 0.29))
		for z: float in [-0.18, 0.18]:
			pm.ring(M.rope, 0.31, 0.34, at(p.x, p.y + 0.31, z, Basis(Vector3.RIGHT, PI * 0.5)), 10, 3)
	fp(Vector3(1.4, 1.0, 0.7), Vector3(0, 0.5, 0))


func _bonsai() -> void:
	pm.box(M.timber, Vector3(0.7, 0.04, 0.4), at(0, 0.5, 0))
	for sx: float in [-1.0, 1.0]:
		pm.box(M.timber, Vector3(0.05, 0.5, 0.36), at(sx * 0.3, 0.25, 0))
	pm.box(M.ceramic, Vector3(0.5, 0.1, 0.3), at(0, 0.57, 0))
	pm.box(M.soil, Vector3(0.44, 0.02, 0.24), at(0, 0.62, 0))
	pm.stick(M.timber, Vector3(0, 0.62, 0), Vector3(0.08, 0.8, 0.02), 0.05)
	pm.stick(M.timber, Vector3(0.08, 0.8, 0.02), Vector3(-0.1, 0.95, 0), 0.04)
	for c: Vector3 in [Vector3(-0.14, 0.97, 0), Vector3(0.12, 0.84, 0.04), Vector3(0.0, 1.06, -0.03)]:
		pm.sphere(M.leaf, 0.14, 0.1, at(c.x, c.y, c.z), 6, 3)
	fp(Vector3(0.7, 0.6, 0.4), Vector3(0, 0.3, 0))


func _pots() -> void:
	var n := maxi(2, int(length / 0.5))
	for i in n:
		var x := -length * 0.5 + (i + 0.5) * length / n
		var r := 0.13 + rnd(i) * 0.06
		pm.cyl(M.clay, r, r * 0.75, r * 1.6, at(x, r * 0.8, 0), 8)
		pm.sphere(M.leaf, r * 1.1, r * 1.1, at(x, r * 1.75, 0), 6, 3)
		for k in 3:
			pm.sphere(M.red if (i + variant) % 3 else M.blossom, 0.04, 0.05, at(x - r * 0.5 + k * r * 0.5, r * 2.1, 0.03 * k), 4, 2)


func _cart() -> void:
	pm.box(M.plank, Vector3(1.0, 0.06, 1.5), at(0, 0.62, 0))
	for sx: float in [-1.0, 1.0]:
		pm.box(M.timber, Vector3(0.06, 0.25, 1.5), at(sx * 0.48, 0.75, 0))
		pm.cyl(M.timber, 0.42, 0.42, 0.07, at(sx * 0.6, 0.42, 0.1, Basis(Vector3.FORWARD, PI * 0.5)), 10)
		pm.stick(M.timber, Vector3(sx * 0.4, 0.6, 0.75), Vector3(sx * 0.35, 0.08, 2.0), 0.07)
	pm.cyl(M.iron, 0.04, 0.04, 1.3, at(0, 0.42, 0.1, Basis(Vector3.FORWARD, PI * 0.5)), 6)
	for k in 3:
		pm.box(M.straw, Vector3(0.4, 0.28, 0.55), at(-0.22 + k * 0.22, 0.79 + (k % 2) * 0.15, -0.3 + k * 0.25, Basis(Vector3.UP, k * 0.3)))
	fp(Vector3(1.3, 1.0, 1.6), Vector3(0, 0.5, 0))


func _sacks() -> void:
	for p: Vector3 in [Vector3(-0.35, 0.18, 0), Vector3(0.35, 0.18, 0.05), Vector3(0, 0.52, 0.02), Vector3(0.8, 0.18, 0.3)]:
		pm.box(M.straw, Vector3(0.62, 0.36, 0.42), at(p.x, p.y, p.z, Basis(Vector3.UP, p.x * 0.4)))
		pm.ring(M.rope, 0.2, 0.23, at(p.x, p.y, p.z, Basis(Vector3.FORWARD, PI * 0.5)), 8, 3)
	fp(Vector3(1.6, 0.7, 0.7), Vector3(0.2, 0.35, 0.1))


func _parasol() -> void:
	pm.cyl(M.timber, 0.03, 0.03, 2.4, at(0, 1.2, 0), 6)
	var cloth: Material = M.red if variant % 2 == 0 else M.ochre
	pm.cyl(cloth, 0.08, 1.3, 0.45, at(0, 2.35, 0), 12)
	pm.cyl(M.timber, 0.0, 0.08, 0.12, at(0, 2.63, 0), 6)
	for i in 12:
		var a := TAU * i / 12.0
		pm.stick(M.timber, Vector3(0, 2.0, 0), Vector3(cos(a) * 0.6, 2.25, sin(a) * 0.6), 0.015)
	pm.box(M.stone, Vector3(0.3, 0.12, 0.3), at(0, 0.06, 0))


func _lantern_post() -> void:
	pm.box(M.stone, Vector3(0.35, 0.2, 0.35), at(0, 0.1, 0))
	pm.box(M.timber, Vector3(0.14, 2.9, 0.14), at(0, 1.45, 0))
	pm.box(M.timber, Vector3(0.08, 0.08, 0.7), at(0, 2.8, 0.3))
	pm.box(M.timber, Vector3(0.02, 0.25, 0.02), at(0, 2.65, 0.6))
	pm.cyl(M.lit if variant % 2 == 0 else M.red_paper, 0.2, 0.2, 0.5, at(0, 2.27, 0.6), 8)
	pm.cyl(M.timber, 0.14, 0.14, 0.05, at(0, 2.54, 0.6), 8)
	pm.cyl(M.timber, 0.14, 0.14, 0.05, at(0, 2.0, 0.6), 8)
	fp(Vector3(0.35, 2.9, 0.35), Vector3(0, 1.45, 0))


func _washing() -> void:
	for sx: float in [-1.0, 1.0]:
		pm.box(M.timber, Vector3(0.1, 2.3, 0.1), at(sx * length * 0.5, 1.15, 0))
		pm.box(M.timber, Vector3(0.06, 0.06, 0.5), at(sx * length * 0.5, 2.2, 0))
	var sag := 0.15
	var prev := Vector3(-length * 0.5, 2.18, 0)
	for k in range(1, 9):
		var t := k / 8.0
		var p := Vector3(-length * 0.5 + length * t, 2.18 - sag * 4.0 * t * (1.0 - t), 0)
		pm.stick(M.rope, prev, p, 0.015)
		prev = p
	var cloths: Array = [M.linen, M.indigo, M.linen, M.red, M.ochre, M.linen]
	var x := -length * 0.5 + 0.3
	var i := 0
	while x < length * 0.5 - 0.5:
		var w := 0.35 + rnd(i) * 0.6
		var hgt := 0.4 + rnd(i + 20) * 0.7
		var t := (x + w * 0.5 + length * 0.5) / length
		var y := 2.18 - sag * 4.0 * t * (1.0 - t)
		pm.box(cloths[(i + variant) % cloths.size()], Vector3(w, hgt, 0.02), at(x + w * 0.5, y - hgt * 0.5, 0, Basis(Vector3.UP, (rnd(i + 40) - 0.5) * 0.2)))
		x += w + 0.12 + rnd(i + 60) * 0.3
		i += 1


func _well() -> void:
	pm.cyl(M.stone, 0.75, 0.8, 0.75, at(0, 0.375, 0), 12)
	pm.cyl(M.dark, 0.6, 0.6, 0.02, at(0, 0.74, 0), 12)
	pm.cyl(M.moss, 0.8, 0.8, 0.08, at(0, 0.04, 0), 12)
	for sx: float in [-1.0, 1.0]:
		pm.box(M.timber, Vector3(0.12, 2.0, 0.12), at(sx * 0.85, 1.0, 0))
	pm.box(M.timber, Vector3(1.9, 0.1, 0.1), at(0, 1.95, 0))
	pm.cyl(M.timber, 0.08, 0.08, 0.06, at(0, 1.82, 0, Basis(Vector3.FORWARD, PI * 0.5)), 8)
	pm.stick(M.rope, Vector3(0, 1.8, 0), Vector3(0, 0.95, 0), 0.015)
	pm.cyl(M.plank, 0.12, 0.1, 0.22, at(0, 0.85, 0), 8)
	var mats := {roof = M.clay, ridge = M.ridge, timber = M.timber}
	preload("res://scripts/props_massacre/roof_kit.gd").gable(pm, mats, Transform3D(), 1.9, 0.3, 2.0, 35.0, Vector2(0.6, 0.6), 0.15, false)
	fp(Vector3(1.6, 0.75, 1.6), Vector3(0, 0.375, 0))


func _rack() -> void:
	for sx: float in [-1.0, 1.0]:
		pm.stick(M.straw, Vector3(sx * length * 0.5, 0, -0.3), Vector3(sx * length * 0.5, 1.9, 0), 0.06)
		pm.stick(M.straw, Vector3(sx * length * 0.5, 0, 0.3), Vector3(sx * length * 0.5, 1.9, 0), 0.06)
	pm.cyl(M.straw, 0.035, 0.035, length + 0.2, at(0, 1.85, 0, Basis(Vector3.FORWARD, PI * 0.5)), 6)
	var n := int(length / 0.3)
	for i in n:
		var x := -length * 0.5 + (i + 0.5) * length / n
		pm.stick(M.rope, Vector3(x, 1.84, 0), Vector3(x, 0.9 + rnd(i) * 0.3, 0), 0.012)
		for k in 5:
			var y := 1.75 - k * 0.15
			if y > 0.95 + rnd(i) * 0.3:
				pm.sphere(M.fruit if (i + variant) % 4 else M.ochre, 0.05, 0.08, at(x, y, 0), 5, 3)


## A festival drum (taiko) tilted on its wooden stand, the sticks resting on top.
func _drum() -> void:
	var tilt := Basis(Vector3.RIGHT, PI * 0.5 - 0.35)
	pm.cyl(M.timber, 0.42, 0.42, 0.62, at(0, 0.95, 0, tilt), 12)
	pm.cyl(M.linen, 0.4, 0.4, 0.66, at(0, 0.95, 0, tilt), 12)
	pm.cyl(M.timber, 0.45, 0.45, 0.4, at(0, 0.95, 0, tilt), 12)
	for sx: float in [-1.0, 1.0]:
		pm.box(M.timber, Vector3(0.1, 0.9, 0.1), at(sx * 0.48, 0.45, -0.1))
		pm.box(M.timber, Vector3(0.1, 0.1, 0.8), at(sx * 0.48, 0.05, 0))
	pm.box(M.timber, Vector3(1.06, 0.1, 0.1), at(0, 0.62, -0.1))
	for k in 2:
		pm.stick(M.plank, Vector3(-0.15 + k * 0.25, 1.38, -0.1), Vector3(-0.05 + k * 0.25, 1.36, 0.3), 0.035)
	pm.box(M.red, Vector3(0.9, 0.18, 0.02), at(0, 0.3, 0.32))
	fp(Vector3(1.06, 1.3, 0.9), Vector3(0, 0.65, 0))


## A festival banner (nobori): a tall pole with a long cloth hung from a crossbar, a stone foot.
func _banner() -> void:
	pm.box(M.stone, Vector3(0.3, 0.25, 0.3), at(0, 0.125, 0))
	pm.cyl(M.timber, 0.04, 0.045, 4.6, at(0, 2.3, 0), 6)
	pm.box(M.timber, Vector3(0.7, 0.04, 0.04), at(0.35, 4.4, 0))
	var cloth: Material = [M.indigo, M.red, M.linen, M.ochre][variant % 4]
	pm.box(cloth, Vector3(0.62, 3.0, 0.02), at(0.37, 2.85, 0))
	pm.box(M.linen if cloth != M.linen else M.red, Vector3(0.62, 0.18, 0.025), at(0.37, 4.24, 0))
	for k in 3:
		pm.box(M.rope, Vector3(0.04, 0.04, 0.03), at(0.06, 1.6 + k * 1.2, 0))
