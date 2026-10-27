@tool
extends "res://scripts/props_black_sand/sand_piece.gd"
## More of the family's things around the shed in Black Sand, picked from Kind: a drag sled of
## salvage, salvage sorted in stacks, a windbreak, boards laid as a path, a cold fire pit. Origin
## on the sand; the windbreak and the board path run `length` metres along +X. The path boards are
## 2 cm high and never solid, so they never make a step. Drift is not used here.
## The drums, fence, garden, tool rack and washing line are sand_yard.gd.

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

@export_enum("Drag sled", "Salvage stacks", "Windbreak", "Board path", "Cold fire pit") var kind := 0:
	set(value):
		kind = value
		_rebuild()


func _build() -> void:
	match kind:
		0: _sled()
		1: _stacks()
		2: _windbreak()
		3: _boards()
		4: _fire_pit()


func _drift_spread() -> float:
	return 0.0


## A sled made of a bent plate, loaded with salvage (pipe lengths, plates, a cable coil), a tow
## rope trailing toward +X.
func _sled() -> void:
	_pm.box(Y.hull, Vector3(2.2, 0.06, 1.0), _at(0, 0.05, 0))
	_pm.box(Y.hull, Vector3(0.06, 0.3, 1.0), Transform3D(Basis(Vector3.FORWARD, -0.6), Vector3(1.15, 0.15, 0)))
	for s in [-1, 1]:
		_pm.box(Y.metal, Vector3(2.0, 0.12, 0.04), _at(0, 0.1, s * 0.5))
	for i in 3:
		_pm.cyl(Y.pipe, 0.08, 0.08, 1.9, Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.RIGHT, 0.05 * i), Vector3(-0.05, 0.17 + i * 0.05, -0.3 + i * 0.16)), 8)
	_pm.box(Y.rust, Vector3(0.9, 0.04, 0.7), _yaw(0.2, -0.3, 0.32, 0.15))
	_pm.ring(Y.rubber, 0.2, 0.3, _at(0.55, 0.22, 0.2), 10, 3)
	_pm.stick(Y.rope, Vector3(1.2, 0.25, 0), Vector3(2.4, 0.03, 0.4), 0.025)
	_pm.stick(Y.rope, Vector3(2.4, 0.03, 0.4), Vector3(3.0, 0.03, 0.2), 0.025)
	_boxes.append([Vector3(2.3, 0.5, 1.0), _at(0, 0.25, 0)])


## What they salvaged, sorted: plates stacked flat, pipes on two trestles, a crate of fittings,
## cable coils, a drum of bolts.
func _stacks() -> void:
	for i in 6:
		_pm.box(Y.rust if i % 2 == 0 else Y.hull, Vector3(1.6, 0.04, 1.1), _yaw(_r.randf_range(-0.12, 0.12), 0, 0.03 + i * 0.045, 0))
	for x in [1.6, 3.0]:
		_pm.box(Y.timber, Vector3(0.1, 0.7, 1.0), _at(x, 0.35, 0))
	for i in 5:
		_pm.cyl(Y.pipe if i % 2 == 0 else Y.metal, 0.09, 0.09, 2.0, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(2.3, 0.78 + (i % 2) * 0.12, -0.36 + i * 0.18)), 8)
	_pm.box(Y.timber, Vector3(0.6, 0.45, 0.5), _yaw(0.3, -0.3, 0.22, 1.05))
	for i in 4:
		_pm.cyl(Y.metal, 0.05, 0.05, 0.1, _at(-0.45 + i * 0.1, 0.47, 1.0 + (i % 2) * 0.12), 6)
	for p in [Vector3(4.2, 0, 0.4), Vector3(4.0, 0.12, 0.45)]:
		_pm.ring(Y.rubber, 0.3, 0.42, _at(p.x, p.y + 0.05, p.z), 12, 3)
	_drum(Vector3(4.1, 0, -0.6), 0.28, 0.8, Y.rust)
	_boxes.append([Vector3(5.0, 0.9, 1.4), _at(1.9, 0.45, 0)])


## Stakes driven in a line along +X with strips of tarp and plate tied between them, all leaning
## a little away from the wind (toward +Z): something to break the sand off the garden.
func _windbreak() -> void:
	var n := maxi(int(length / 1.2), 1)
	for i in n + 1:
		var x := i * length / n
		var lean := Basis(Vector3.RIGHT, 0.12 + _r.randf_range(-0.04, 0.04))
		_pm.box(Y.timber, Vector3(0.07, 1.8, 0.07), Transform3D(lean, Vector3(x, 0.6, 0)))
		if i < n:
			var mid := x + length / n * 0.5
			_pm.box(Y.tarp if (i + variant) % 3 != 0 else Y.rust, Vector3(length / n, _r.randf_range(0.6, 1.0), 0.02), Transform3D(lean, Vector3(mid, 0.9, 0.08)))
	_boxes.append([Vector3(length, 1.4, 0.3), _at(length * 0.5, 0.7, 0.1)])


## Boards laid on the sand in a line `length` long along +X, where they walk most, each a little
## skew. 2 cm high and never solid.
func _boards() -> void:
	var x := 0.0
	while x < length:
		var w := _r.randf_range(0.22, 0.32)
		var l := _r.randf_range(0.9, 1.3)
		_pm.box(Y.timber if _r.randf() < 0.7 else Y.wood, Vector3(w, 0.02, l), _yaw(_r.randf_range(-0.12, 0.12), x + w * 0.5, 0.01, _r.randf_range(-0.12, 0.12)))
		x += w + _r.randf_range(0.04, 0.35)


## A ring of stones round cold ash, a tripod of rods with a blackened pot, a stool of a can.
func _fire_pit() -> void:
	for i in 10:
		var a := TAU * i / 10.0 + _r.randf_range(-0.12, 0.12)
		var s := _r.randf_range(0.12, 0.2)
		_ball(Y.stone, Vector3(s, s * 0.6, s), _at(cos(a) * 0.65, s * 0.3, sin(a) * 0.65), 6, 3)
	_pm.cyl(Y.dead, 0.48, 0.5, 0.04, _at(0, 0.02, 0), 10)
	for i in 3:
		var a := TAU * i / 3.0
		_pm.stick(Y.metal, Vector3(cos(a) * 0.7, -0.1, sin(a) * 0.7), Vector3(0, 1.25, 0), 0.03)
	_pm.stick(Y.metal, Vector3(0, 1.25, 0), Vector3(0, 0.75, 0), 0.015)
	_pm.cyl(Y.rubber, 0.2, 0.16, 0.25, _at(0, 0.6, 0), 8)
	_pm.cyl(Y.rust, 0.18, 0.18, 0.4, _at(1.2, 0.2, 0.3), 8)
	_boxes.append([Vector3(1.5, 1.3, 1.5), _at(0, 0.65, 0)])  # the ring and tripod: walked round, not through
