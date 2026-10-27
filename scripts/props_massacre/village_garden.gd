@tool
extends "res://scripts/props_massacre/village_prop_base.gd"
## The village's growing things and water, picked from Kind. Origin on the ground; Length runs
## along local X, Width along Z (centred). Everything is walk-through and at most 15 cm high
## (no step), except trees (their trunk is solid) and hedges (solid).
##   Garden bed: dark soil in a timber edge, rows of vegetables, bean poles.
##   Channel: an irrigation channel, stone-lined, water running in it, plank bridges.
##   Stepping stones; Pond (a stone rim, lilies, koi); Tree (Variant: pine, blossom,
##   persimmon, maple; Length = height); Bamboo; Hedge; Paddy (a flooded plot of rice);
##   Lamp frame (a low grow lamp on two posts over a bed, for the beds the ceiling lamps miss);
##   Path (packed earth, 3 cm, edged with stones now and then; Variant 1 = no stones);
##   Field shed (an open shed on four posts, a tiled roof, tools and sacks; walk-through).

@export_enum("Garden bed", "Channel", "Stepping stones", "Pond", "Tree", "Bamboo", "Hedge", "Paddy",
		"Lamp frame", "Path", "Field shed") var kind := 0:
	set(value):
		kind = value
		_rebuild()
@export var length := 4.0:
	set(value):
		length = value
		_rebuild()
@export var width := 2.0:
	set(value):
		width = value
		_rebuild()


func _build() -> void:
	match kind:
		0: _bed()
		1: _channel()
		2: _stones()
		3: _pond()
		4: _tree()
		5: _bamboo()
		6: _hedge()
		7: _paddy()
		8: _lamp_frame()
		9: _path()
		10: _shed()


func _bed() -> void:
	pm.box(M.soil, Vector3(length, 0.1, width), at(0, 0.05, 0))
	for sz: float in [-1.0, 1.0]:
		pm.box(M.timber, Vector3(length + 0.1, 0.14, 0.06), at(0, 0.07, sz * width * 0.5))
	for sx: float in [-1.0, 1.0]:
		pm.box(M.timber, Vector3(0.06, 0.14, width), at(sx * length * 0.5, 0.07, 0))
	var rows := maxi(1, int(width / 0.45))
	for r in rows:
		var z := -width * 0.5 + (r + 0.5) * width / rows
		var crop := (r + variant) % 3
		var n := int(length / 0.35)
		for i in n:
			var x := -length * 0.5 + (i + 0.5) * length / n
			if crop == 0:  # cabbages
				pm.sphere(M.leaf2, 0.13, 0.15, at(x, 0.15, z), 6, 3)
			elif crop == 1:  # leeks
				pm.cyl(M.leaf2, 0.0, 0.04, 0.35, at(x, 0.27, z), 4)
				pm.cyl(M.leaf, 0.0, 0.03, 0.3, at(x + 0.05, 0.25, z + 0.03), 4)
			else:  # beans up a pole
				if i % 2 == 0:
					pm.stick(M.straw, Vector3(x, 0.08, z), Vector3(x, 1.3, z), 0.025)
					pm.cyl(M.leaf, 0.07, 0.11, 0.9, at(x, 0.6, z), 5)


func _channel() -> void:
	var w := 0.4
	for sz: float in [-1.0, 1.0]:
		pm.box(M.stone, Vector3(length, 0.12, 0.16), at(0, 0.06, sz * (w * 0.5 + 0.08)))
	pm.box(M.soil, Vector3(length, 0.03, w), at(0, 0.015, 0))
	pm.box(M.water, Vector3(length, 0.02, w + 0.02), at(0, 0.075, 0))
	var bridges := int(length / 9.0)
	for i in bridges:
		var x := -length * 0.5 + (i + 0.5) * length / bridges
		pm.box(M.plank, Vector3(0.7, 0.04, w + 0.5), at(x, 0.14, 0))
	for i in int(length / 2.5):  # stones and weed in the water
		var x := -length * 0.5 + (i + rnd(i)) * 2.5
		pm.sphere(M.moss, 0.08, 0.08, at(x, 0.07, (rnd(i + 9) - 0.5) * 0.25), 5, 2)


func _stones() -> void:
	var n := maxi(1, int(length / 0.75))
	for i in n:
		var x := -length * 0.5 + (i + 0.5) * length / n
		var s := 0.42 + rnd(i) * 0.2
		turned(M.stone, Vector3(s, 0.04, s * 0.8), Vector3(x, 0.02, (rnd(i + 30) - 0.5) * 0.2), rnd(i + 50) * 1.2)


func _pond() -> void:
	pm.box(M.water, Vector3(length - 0.3, 0.04, width - 0.3), at(0, 0.03, 0))
	var n := int((length + width) * 2.0 / 0.55)
	for i in n:
		var t := float(i) / n * 2.0 * (length + width)
		var p := Vector3.ZERO
		if t < length:
			p = Vector3(-length * 0.5 + t, 0, -width * 0.5)
		elif t < length + width:
			p = Vector3(length * 0.5, 0, -width * 0.5 + t - length)
		elif t < 2.0 * length + width:
			p = Vector3(length * 0.5 - (t - length - width), 0, width * 0.5)
		else:
			p = Vector3(-length * 0.5, 0, width * 0.5 - (t - 2.0 * length - width))
		var s := 0.35 + rnd(i) * 0.25
		turned(M.stone if i % 4 else M.moss, Vector3(s, 0.12 + rnd(i + 3) * 0.06, s * 0.8), p + Vector3(0, 0.06, 0), rnd(i + 7) * 2.0)
	for i in 4:  # lily pads and koi
		pm.cyl(M.leaf2, 0.14, 0.14, 0.01, at((rnd(i + 11) - 0.5) * (length - 1.0), 0.055, (rnd(i + 13) - 0.5) * (width - 1.0)), 8)
	for i in 3:
		turned(M.fruit if i != 1 else M.linen, Vector3(0.24, 0.02, 0.07), Vector3((rnd(i + 21) - 0.5) * (length - 1.2), 0.045,
				(rnd(i + 23) - 0.5) * (width - 1.2)), rnd(i + 25) * 3.0)


func _tree() -> void:
	var h := maxf(length, 2.0)
	var style := variant % 4
	var bark: Material = M.timber
	var crown: Material = [M.leaf, M.blossom, M.leaf2, M.red][style]
	pm.cyl(bark, 0.16, 0.24, h * 0.55, at(0, h * 0.275, 0), 7)
	pm.stick(bark, Vector3(0, h * 0.5, 0), Vector3(0.5, h * 0.72, 0.2), 0.16)
	pm.stick(bark, Vector3(0, h * 0.45, 0), Vector3(-0.55, h * 0.62, -0.15), 0.14)
	pm.stick(bark, Vector3(0, h * 0.55, 0), Vector3(-0.1, h * 0.85, 0.05), 0.13)
	if style == 0:  # a pine: flat layered pads
		for k in 5:
			var c := Vector3((rnd(k) - 0.5) * 1.6, h * (0.55 + k * 0.1), (rnd(k + 5) - 0.5) * 1.2)
			pm.sphere(crown, 1.0 - k * 0.12, 0.38, at(c.x, c.y, c.z), 8, 3)
	else:
		for k in 7:
			var c := Vector3((rnd(k) - 0.5) * 2.0, h * (0.66 + rnd(k + 3) * 0.3), (rnd(k + 5) - 0.5) * 2.0)
			pm.sphere(crown, 0.8 + rnd(k + 8) * 0.4, 1.0 + rnd(k + 9) * 0.5, at(c.x, c.y, c.z), 7, 4)
		if style == 2:
			for k in 9:
				pm.sphere(M.fruit, 0.07, 0.12, at((rnd(k + 30) - 0.5) * 2.2, h * (0.6 + rnd(k + 31) * 0.3), (rnd(k + 32) - 0.5) * 2.2), 5, 3)
		if style == 1:  # fallen petals round the foot
			for k in 6:
				pm.box(M.blossom, Vector3(0.5, 0.004, 0.4), at((rnd(k + 40) - 0.5) * 2.4, 0.025 + k * 0.006, (rnd(k + 41) - 0.5) * 2.4))
	fp(Vector3(0.4, h * 0.5, 0.4), Vector3(0, h * 0.25, 0))


func _bamboo() -> void:
	for i in 9:
		var p := Vector3((rnd(i) - 0.5) * 1.4, 0, (rnd(i + 9) - 0.5) * 1.4)
		var h := 3.5 + rnd(i + 18) * 2.5
		var tip := p + Vector3((rnd(i + 27) - 0.5) * 0.6, h, (rnd(i + 36) - 0.5) * 0.6)
		pm.stick(M.leaf2, p, tip, 0.07)
		for k in 3:
			var c := p.lerp(tip, 0.75 + k * 0.1)
			pm.sphere(M.leaf2 if k % 2 else M.leaf, 0.35, 0.25, at(c.x + 0.2, c.y, c.z), 6, 3)


func _hedge() -> void:
	var n := maxi(1, int(length / 0.8))
	for i in n:
		var x := -length * 0.5 + (i + 0.5) * length / n
		var hh := 0.8 + rnd(i) * 0.25
		pm.box(M.leaf, Vector3(length / n + 0.12, hh, 0.7), at(x, hh * 0.5, 0))
	fp(Vector3(length, 0.8, 0.7), Vector3(0, 0.4, 0))


func _paddy() -> void:
	for sz: float in [-1.0, 1.0]:
		pm.box(M.soil, Vector3(length + 0.3, 0.14, 0.15), at(0, 0.07, sz * (width * 0.5 + 0.075)))
	for sx: float in [-1.0, 1.0]:
		pm.box(M.soil, Vector3(0.15, 0.14, width), at(sx * (length * 0.5 + 0.075), 0.07, 0))
	pm.box(M.water, Vector3(length, 0.02, width), at(0, 0.06, 0))
	for i in int(length / 0.4):
		for k in int(width / 0.4):
			pm.cyl(M.leaf2, 0.0, 0.035, 0.32, at(-length * 0.5 + (i + 0.5) * 0.4, 0.2, -width * 0.5 + (k + 0.5) * 0.4), 3)


func _lamp_frame() -> void:
	for sx: float in [-1.0, 1.0]:
		pm.box(M.iron, Vector3(0.08, 2.6, 0.08), at(sx * length * 0.5, 1.3, 0))
		pm.box(M.stone, Vector3(0.25, 0.12, 0.25), at(sx * length * 0.5, 0.06, 0))
	pm.box(M.iron, Vector3(length + 0.1, 0.08, 0.1), at(0, 2.56, 0))
	pm.box(M.iron, Vector3(length - 0.4, 0.1, 0.4), at(0, 2.42, 0))
	pm.box(preload("res://materials/grow_lamp.tres"), Vector3(length - 0.5, 0.03, 0.3), at(0, 2.36, 0))
	pm.stick(M.dark, Vector3(length * 0.5, 2.5, 0.05), Vector3(length * 0.5 + 0.3, 0.05, 0.05), 0.025)


func _path() -> void:
	var pieces := maxi(1, ceili(length / 3.0))  # short pieces: a long quad wobbles
	for i in pieces:
		pm.box(preload("res://materials/ground_dirt.tres"), Vector3(length / pieces, 0.03, width), at(-length * 0.5 + (i + 0.5) * length / pieces, 0.015, 0))
	if variant % 2 == 1:
		return
	var n := int(length / 1.1)
	for i in n:
		for sz: float in [-1.0, 1.0]:
			if rnd(i * 2 + int(sz)) < 0.45:
				continue
			var s := 0.22 + rnd(i + 77) * 0.18
			turned(M.stone, Vector3(s, 0.06, s * 0.8), Vector3(-length * 0.5 + (i + 0.5) * length / n, 0.03, sz * (width * 0.5 + 0.1)), rnd(i + 5) * 2.0)


func _shed() -> void:
	var w := 3.2
	var d := 2.4
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pm.box(M.timber, Vector3(0.16, 2.3, 0.16), at(sx * w * 0.5, 1.15, sz * d * 0.5))
			pm.box(M.stone, Vector3(0.3, 0.12, 0.3), at(sx * w * 0.5, 0.06, sz * d * 0.5))
	pm.box(M.timber, Vector3(w + 0.2, 0.14, 0.16), at(0, 2.3, d * 0.5))
	pm.box(M.timber, Vector3(w + 0.2, 0.14, 0.16), at(0, 2.3, -d * 0.5))
	preload("res://scripts/props_massacre/roof_kit.gd").gable(pm, {roof = M.clay, ridge = M.ridge, timber = M.timber}, Transform3D(),
			w, d, 2.37, 30.0, Vector2(0.5, 0.5), 0.3)
	pm.box(M.plank, Vector3(w - 0.3, 0.05, 0.5), at(0, 1.0, -d * 0.5 + 0.3))  # a shelf at the back
	for k in 3:
		pm.cyl(M.plank, 0.13, 0.11, 0.25, at(-1.0 + k * 0.4, 1.15, -d * 0.5 + 0.3), 8)
	for k in 3:  # tools leaning on the back beam
		var x := 0.6 + k * 0.25
		pm.stick(M.timber, Vector3(x, 0.02, -d * 0.5 + 0.35), Vector3(x + 0.05, 1.55, -d * 0.5 + 0.12), 0.04)
	pm.box(M.metal, Vector3(0.22, 0.14, 0.03), at(0.6, 0.09, -d * 0.5 + 0.36))
	for k in 2:
		pm.box(M.straw, Vector3(0.6, 0.36, 0.42), at(-0.8 + k * 0.7, 0.18, 0.2 - k * 0.3, Basis(Vector3.UP, k * 0.4)))
	pm.box(M.straw, Vector3(1.2, 0.08, 0.9), at(-0.4, 0.04, -0.2))
