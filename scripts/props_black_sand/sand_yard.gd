@tool
extends "res://scripts/props_black_sand/sand_piece.gd"
## The family's life around their shed in Black Sand, made from what the dunes gave up, picked
## from Kind: water drums (variant 1 catches a downpipe off the roof), a hand-made fence, a garden
## that is trying, a tool rack, a long washing line. Origin on the sand; the fence, line and garden
## run `length` metres along +X; the tool rack has its wall at -Z. Water drums variant 1: `length`
## is the height of the roof edge the downpipe comes from. Drift is not used here.
## With Solid on, what you could walk into gets box collision when the game runs (never saved).
## More of their things (sled, stacks, windbreak, board path, fire pit): sand_salvage.gd.

const Y := {
	wood = preload("res://materials/wood.tres"), timber = preload("res://materials/black_sand_timber.tres"),
	linen = preload("res://materials/black_sand_linen.tres"), indigo = preload("res://materials/black_sand_indigo.tres"),
	tarp = preload("res://materials/black_sand_tarp.tres"), blue = preload("res://materials/tarp.tres"),
	rope = preload("res://materials/black_sand_rope.tres"), metal = preload("res://materials/metal_worn.tres"),
	rust = preload("res://materials/black_sand_hull_rust_worn.tres"), hull = preload("res://materials/black_sand_hull_worn.tres"),
	warm = preload("res://materials/black_sand_lamp_warm.tres"), soil = preload("res://materials/black_sand_soil.tres"),
	leaf = preload("res://materials/leaf.tres"), rubber = preload("res://materials/rubber.tres"),
	stone = preload("res://materials/black_sand_stone.tres"), ceramic = preload("res://materials/ceramic.tres"),
	pipe = preload("res://materials/pipe_rust.tres"), dead = preload("res://materials/ceiling_panel_off.tres"),
	red = preload("res://materials/paint_red.tres"),
}

@export_enum("Water drums", "Fence", "Garden", "Tool rack", "Washing line") var kind := 0:
	set(value):
		kind = value
		_rebuild()


func _build() -> void:
	match kind:
		0: _drums()
		1: _fence()
		2: _garden()
		3: _tool_rack()
		4: _washing_line()


func _drift_spread() -> float:
	return 0.0


## Three drums of water, one with a plate weighed down by a stone, one tipped over and empty,
## a jerrycan and a dipper. Variant 1: a downpipe from the roof edge (`length` up, at -Z) runs
## into the first drum through a funnel cut from a can: put a drip.gd at the funnel.
func _drums() -> void:
	_drum(Vector3(0, 0, 0), 0.32, 0.95, Y.rust)
	_drum(Vector3(0.75, 0, 0.1), 0.3, 0.9, Y.hull)
	_pm.box(Y.metal, Vector3(0.7, 0.03, 0.7), _yaw(0.4, 0.75, 0.88, 0.1))
	_pm.sphere(Y.stone, 0.12, 0.14, _at(0.8, 0.95, 0.12), 6, 3)
	_pm.cyl(Y.rust, 0.3, 0.3, 0.85, Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.3, 0.27, 0.95)), 10)
	_pm.box(Y.red, Vector3(0.18, 0.42, 0.32), _yaw(0.3, 1.25, 0.21, 0.55))  # jerrycan
	_pm.box(Y.metal, Vector3(0.12, 0.05, 0.04), _yaw(0.3, 1.25, 0.45, 0.55))
	_boxes.append([Vector3(1.4, 0.95, 0.75), _at(0.37, 0.47, 0.05)])
	if variant == 1:
		var top := Vector3(0, length, -0.45)
		_pm.cyl(Y.pipe, 0.08, 0.08, length - 1.35, _at(0, 1.35 + (length - 1.35) * 0.5, -0.45), 6)
		_pm.box(Y.metal, Vector3(0.3, 0.12, 0.5), _at(0, top.y, -0.3))  # the gutter lip it hangs from
		_pm.stick(Y.pipe, Vector3(0, 1.4, -0.45), Vector3(0, 1.2, -0.1), 0.14)
		_pm.cyl(Y.metal, 0.22, 0.06, 0.25, _at(0, 1.08, 0), 8)  # funnel
		for y in [length * 0.4, length * 0.75]:  # straps to the wall
			_pm.box(Y.metal, Vector3(0.24, 0.05, 0.12), _at(0, y, -0.5))


## A fence the family put up from whatever they found: posts of pipe offcut and rebar every
## 1.5 m, two strands of wire, and some bays filled with scrap plate, a door panel, a tarp strip.
func _fence() -> void:
	var n := maxi(int(length / 1.5), 1)
	var step := length / n
	for i in n + 1:
		var x := i * step
		var h := _r.randf_range(1.05, 1.45)
		var lean := Basis(Vector3.FORWARD, _r.randf_range(-0.08, 0.08)) * Basis(Vector3.RIGHT, _r.randf_range(-0.06, 0.06))
		var mat: Material = Y.pipe if i % 3 == 0 else (Y.metal if i % 3 == 1 else Y.timber)
		_pm.box(mat, Vector3(0.09, h + 0.4, 0.09), Transform3D(lean, Vector3(x, (h - 0.4) * 0.5, 0)))
		if i == n:
			break
		var fill := (i + variant) % 4
		var mid := x + step * 0.5
		if fill == 0:
			_pm.box(Y.rust, Vector3(step * 0.95, 0.9, 0.03), _yaw(_r.randf_range(-0.05, 0.05), mid, 0.48, 0.06))
		elif fill == 1:
			_pm.box(Y.hull, Vector3(step * 0.7, 1.0, 0.04), Transform3D(Basis(Vector3.FORWARD, 0.06), Vector3(mid, 0.5, -0.06)))
			_pm.box(Y.metal, Vector3(0.08, 0.2, 0.03), _at(mid + step * 0.25, 0.55, -0.1))  # a handle: it was a door
		elif fill == 2:
			_pm.box(Y.tarp, Vector3(step * 0.9, 0.35, 0.02), _at(mid, 0.85, 0.07))
	for y in [0.55, 1.0]:  # the wire, a little slack
		_pm.stick(Y.rubber, Vector3(0, y, 0), Vector3(length * 0.5, y - 0.04, 0), 0.015)
		_pm.stick(Y.rubber, Vector3(length * 0.5, y - 0.04, 0), Vector3(length, y, 0), 0.015)
	_boxes.append([Vector3(length, 1.3, 0.3), _at(length * 0.5, 0.65, 0)])


## A raised bed `length` x 1.4 m walled with plate, filled with darker soil they carried in, rows
## of sprouts (some made it, most are pale and thin), a lamp on a bent pole over it (the light is
## a separate OmniLight3D), a watering can, a covered bucket of water.
func _garden() -> void:
	var w := 1.4
	for s in [-1, 1]:
		_pm.box(Y.rust, Vector3(length, 0.45, 0.05), _at(length * 0.5, 0.15, s * w * 0.5))
	for x in [0.0, length]:
		_pm.box(Y.hull, Vector3(0.05, 0.45, w), _at(x, 0.15, 0))
	_pm.box(Y.soil, Vector3(length - 0.06, 0.05, w - 0.06), _at(length * 0.5, 0.33, 0))
	for row in 3:
		var z := -0.45 + row * 0.45
		var count := int(length / 0.35)
		for i in count:
			var x := 0.25 + i * (length - 0.5) / maxf(count - 1, 1)
			var h := _r.randf_range(0.08, 0.3) if _r.randf() < 0.65 else _r.randf_range(0.3, 0.5)
			var tip := Vector3(x + _r.randf_range(-0.05, 0.05), 0.35 + h, z + _r.randf_range(-0.05, 0.05))
			_pm.stick(Y.leaf, Vector3(x, 0.34, z), tip, 0.02)
			if h > 0.2:
				_pm.box(Y.leaf, Vector3(0.12, 0.015, 0.06), _yaw(_r.randf() * TAU, tip.x, tip.y - 0.04, tip.z))
		_pm.stick(Y.rope, Vector3(0.1, 0.42, z + 0.2), Vector3(length - 0.1, 0.42, z + 0.2), 0.01)  # string to sow by
	# The lamp: a pole at the far end, bent over the bed, a hooded bulb.
	var top := Vector3(length + 0.25, 2.3, 0)
	_pm.stick(Y.metal, Vector3(length + 0.25, -0.3, 0), top, 0.06)
	_pm.stick(Y.metal, top, Vector3(length * 0.5, 2.1, 0), 0.04)
	_pm.cyl(Y.metal, 0.05, 0.2, 0.15, _at(length * 0.5, 2.03, 0), 8)
	_pm.sphere(Y.warm, 0.07, 0.1, _at(length * 0.5, 1.94, 0), 6, 3)
	_pm.stick(Y.rubber, top, Vector3(length + 0.7, -0.1, 0.6), 0.03)
	# A watering can and a covered bucket at the near end.
	_pm.cyl(Y.metal, 0.13, 0.15, 0.3, _at(-0.35, 0.15, 0.55), 8)
	_pm.stick(Y.metal, Vector3(-0.25, 0.2, 0.55), Vector3(-0.05, 0.38, 0.6), 0.03)
	_pm.cyl(Y.rust, 0.2, 0.17, 0.4, _at(-0.4, 0.2, -0.3), 8)
	_pm.box(Y.tarp, Vector3(0.45, 0.03, 0.45), _yaw(0.3, -0.4, 0.41, -0.3))
	_boxes.append([Vector3(length + 0.2, 0.5, w), _at(length * 0.5, 0.2, 0)])


## Two posts against a wall at -Z with a bar across: a shovel, a pick, a saw, a sieve and a coil
## of rope hang on it; a barrow beside it with a broken handle.
func _tool_rack() -> void:
	for x in [-0.9, 0.9]:
		_pm.box(Y.timber, Vector3(0.1, 1.9, 0.1), _at(x, 0.85, 0.1))
	_pm.box(Y.timber, Vector3(2.0, 0.08, 0.08), _at(0, 1.6, 0.12))
	_pm.stick(Y.wood, Vector3(-0.6, 1.62, 0.2), Vector3(-0.62, 0.35, 0.22), 0.04)  # shovel
	_pm.box(Y.metal, Vector3(0.24, 0.3, 0.02), _yaw(0.0, -0.62, 0.22, 0.23))
	_pm.stick(Y.wood, Vector3(-0.15, 1.62, 0.2), Vector3(-0.18, 0.75, 0.24), 0.04)  # pick
	_pm.stick(Y.metal, Vector3(-0.42, 0.78, 0.24), Vector3(0.12, 0.72, 0.24), 0.05)
	_pm.box(Y.metal, Vector3(0.55, 0.13, 0.01), _at(0.35, 1.38, 0.18))  # saw
	_pm.box(Y.wood, Vector3(0.12, 0.1, 0.03), _at(0.66, 1.4, 0.18))
	_pm.ring(Y.timber, 0.2, 0.24, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.65, 1.15, 0.2)), 10, 3)  # sieve rim
	_pm.box(Y.metal, Vector3(0.36, 0.36, 0.005), _at(0.65, 1.15, 0.2))
	for i in 3:
		_pm.ring(Y.rope, 0.14, 0.17, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.35 + i * 0.02, 0.9, 0.22 + i * 0.015)), 10, 3)
	# The barrow: a tub, a wheel, one handle snapped.
	var b := _yaw(0.5, 1.6, 0, 0.7)
	_pm.box(Y.rust, Vector3(0.9, 0.35, 0.6), b * _at(0, 0.5, 0))
	_pm.ring(Y.rubber, 0.12, 0.2, b * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.55, 0.2, 0)), 10, 3)
	_pm.stick(Y.wood, b * Vector3(-0.3, 0.4, 0.25), b * Vector3(-1.1, 0.5, 0.25), 0.05)
	_pm.stick(Y.wood, b * Vector3(-0.3, 0.4, -0.25), b * Vector3(-0.7, 0.1, -0.3), 0.05)
	_boxes.append([Vector3(2.0, 1.8, 0.4), _at(0, 0.9, 0.15)])
	_boxes.append([Vector3(1.0, 0.7, 0.8), b * _at(0, 0.35, 0)])


## Two poles `length` apart, a line sagging between them, cloths pegged on it.
func _washing_line() -> void:
	for x in [0.0, length]:
		_pm.stick(Y.pipe, Vector3(x, -0.3, 0), Vector3(x, 2.1, 0), 0.07)
		_pm.stick(Y.metal, Vector3(x, 1.9, 0), Vector3(x + (0.3 if x == 0.0 else -0.3), -0.3, 0.6), 0.03)  # a stay
	var sag := 0.25
	var pieces := 6
	for i in pieces:
		var a := _line_at(i / float(pieces), sag)
		var b := _line_at((i + 1) / float(pieces), sag)
		_pm.stick(Y.rope, a, b, 0.03)
	var cloths := [Y.linen, Y.indigo, Y.tarp, Y.linen, Y.blue]
	var x := 0.5
	var k := 0
	while x < length - 0.6:
		var w := _r.randf_range(0.35, 0.8)
		var h := _r.randf_range(0.4, 0.85)
		var p := _line_at((x + w * 0.5) / length, sag)
		_pm.box(cloths[(k + variant) % cloths.size()], Vector3(w, h, 0.02), _yaw(_r.randf_range(-0.06, 0.06), p.x, p.y - h * 0.5, 0))
		x += w + _r.randf_range(0.15, 0.5)
		k += 1


func _line_at(t: float, sag: float) -> Vector3:
	return Vector3(length * t, 2.0 - sag * 4.0 * t * (1.0 - t), 0)


