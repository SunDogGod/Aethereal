@tool
extends Node3D
## The family's things in and around the shed (black_sand_shed.gd), picked from Kind:
##  Inside: their two beds (pallets with thin mattresses, hers made up and empty), a crate by the
##    beds with an oil lamp, a cloth hung on a wire to screen the beds, blankets nailed on the steel
##    for warmth, sheet plates laid over the sand, a barrel stove with its pipe up through the roof,
##    a cable-drum table and bucket stools, crates for shelves, a water drum, a hanging lamp and a
##    string of small bulbs. Isabella's bier is sand_home.gd (kind Bier). Origin = the shed's origin.
##  Outside: a water barrel by the door, a plank bench on buckets, a washing line, a scrap pile
##    (fuel). Origin = the shed's origin.
##  Guide lamp: a stake with a hooded lamp, one of the lamps they staked out to find home in the
##    fog. Origin on the sand. (The light itself is a separate OmniLight3D.)
## Furniture gets box collision when the game runs (never saved), nothing low on the way in.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	wood = preload("res://materials/wood.tres"), timber = preload("res://materials/black_sand_timber.tres"),
	linen = preload("res://materials/black_sand_linen.tres"), indigo = preload("res://materials/black_sand_indigo.tres"),
	tarp = preload("res://materials/black_sand_tarp.tres"), rope = preload("res://materials/black_sand_rope.tres"),
	metal = preload("res://materials/metal_worn.tres"), rust = preload("res://materials/black_sand_hull_rust_worn.tres"),
	hull = preload("res://materials/black_sand_hull_worn.tres"), warm = preload("res://materials/black_sand_lamp_warm.tres"),
	fire = preload("res://materials/fire.tres"), dark = preload("res://materials/black_sand_void.tres"),
	ceramic = preload("res://materials/ceramic.tres"), brass = preload("res://materials/brass.tres"),
	red = preload("res://materials/paint_red.tres"), rubber = preload("res://materials/rubber.tres"),
}
const IN_Z := 2.9     # the inner face of the front and back walls (keep in step with black_sand_shed.gd)
const IN_X := 7.75    # the inner face of the end walls
const ROOF := 5.75    # underside of the roof
const DOOR_X := -1.2
const STOVE := Vector3(5.9, 0, -2.3)

@export_enum("Inside", "Outside", "Guide lamp") var kind := 0:
	set(value):
		kind = value
		_rebuild()

var _mesh := MeshInstance3D.new()
var _pm: PropMesh
var _boxes: Array = []
var _body: StaticBody3D


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _ready() -> void:
	_apply_collision()


func _rebuild() -> void:
	_pm = PropMesh.new()
	_boxes.clear()
	match kind:
		0: _inside()
		1: _outside()
		2: _guide_lamp()
	_mesh.mesh = _pm.commit()
	if is_inside_tree():
		_apply_collision()


func _apply_collision() -> void:
	if _body:
		_body.queue_free()
		_body = null
	if _boxes.is_empty() or Engine.is_editor_hint():
		return
	_body = StaticBody3D.new()
	add_child(_body, false, INTERNAL_MODE_FRONT)
	for pair in _boxes:
		var shape := BoxShape3D.new()
		shape.size = pair[0]
		var col := CollisionShape3D.new()
		col.shape = shape
		col.transform = pair[1]
		_body.add_child(col)


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


func _turn(yaw: float, p: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


func _inside() -> void:
	# Sheet plates over the sand (each at its own height, so none flicker where they overlap).
	for p in [[-5.6, -1.0, 4.2, 3.6, 0.04, 0.012], [-0.6, 0.4, 3.6, 3.4, -0.06, 0.02], [4.9, -0.8, 4.4, 3.8, 0.05, 0.028]]:
		_pm.box(M.metal, Vector3(p[2], 0.02, p[3]), _turn(p[4], Vector3(p[0], p[5], p[1])))
	_pm.box(M.red, Vector3(1.6, 0.012, 1.1), _turn(0.1, Vector3(-5.4, 0.045, 0.6)))  # a rug between the beds
	# His bed along the back wall, hers along the end wall, both pallets on the floor.
	_bed(Transform3D(Basis(), Vector3(-5.5, 0, -IN_Z + 0.5)), M.tarp, false)
	_bed(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-IN_X + 0.5, 0, 0.7)), M.indigo, true)
	# The crate between them with the oil lamp, a cup and a folded cloth.
	_crate(Vector3(-7.15, 0, -2.35), 0.55, 0.2)
	_pm.cyl(M.brass, 0.07, 0.09, 0.05, _at(-7.1, 0.58, -2.35), 8)
	_pm.cyl(M.warm, 0.03, 0.04, 0.12, _at(-7.1, 0.67, -2.35), 6)
	_pm.cyl(M.ceramic, 0.04, 0.035, 0.08, _at(-7.3, 0.59, -2.2), 6)
	# The screen: a wire across, a cloth half drawn.
	_pm.stick(M.rope, Vector3(-3.4, 2.1, -IN_Z), Vector3(-3.4, 2.1, 0.8), 0.02)
	_pm.box(M.tarp, Vector3(0.03, 1.9, 1.1), Transform3D(Basis(Vector3.UP, 0.12), Vector3(-3.4, 1.12, -IN_Z + 0.65)))
	_pm.box(M.tarp, Vector3(0.14, 1.9, 0.3), _at(-3.4, 1.12, -IN_Z + 1.4))
	# Blankets nailed on the steel behind the beds, a coat and a bag on hooks, a plank shelf.
	_pm.box(M.indigo, Vector3(2.2, 1.4, 0.03), _at(-5.6, 1.15, -IN_Z + 0.02))
	_pm.box(M.tarp, Vector3(0.03, 1.5, 2.2), _at(-IN_X + 0.02, 1.2, 0.7))
	_pm.box(M.tarp, Vector3(0.3, 0.75, 0.08), _at(-4.3, 1.75, -IN_Z + 0.09))
	_pm.sphere(M.tarp, 0.2, 0.35, _at(-6.5, 1.55, -IN_Z + 0.16), 6, 3)
	_pm.box(M.wood, Vector3(1.6, 0.04, 0.26), _at(-5.4, 2.3, -IN_Z + 0.15))
	for x in [-5.9, -5.6, -5.0]:
		_pm.cyl(M.ceramic, 0.06, 0.06, 0.14, _at(x, 2.39, -IN_Z + 0.15), 6)
	_pm.box(M.linen, Vector3(0.3, 0.08, 0.2), _at(-4.8, 2.36, -IN_Z + 0.15))
	# A line of washing over his bed; crates stacked inside the door.
	_pm.stick(M.rope, Vector3(-IN_X, 2.5, -1.3), Vector3(-3.4, 2.4, -1.3), 0.015)
	for c in [[-6.9, 0.5, 0.6, M.linen], [-5.9, 0.45, 0.7, M.indigo], [-4.6, 0.4, 0.5, M.tarp]]:
		_pm.box(c[3], Vector3(c[1], c[2], 0.02), _at(c[0], 2.45 - c[2] * 0.5, -1.3))
	_crate(Vector3(-2.9, 0, IN_Z - 0.45), 0.55, 0.15)
	_crate(Vector3(-2.95, 0.55, IN_Z - 0.45), 0.4, -0.2)
	_kitchen()
	_ceiling_lights()


## A pallet on the floor, a thin mattress, a pillow, a blanket. `xf`: origin under the bed's
## middle, the bed running along local X with the head at -X. `made`: blanket folded square.
func _bed(xf: Transform3D, blanket: Material, made: bool) -> void:
	_pm.box(M.wood, Vector3(2.0, 0.13, 0.95), xf * _at(0, 0.065, 0))
	for z in [-0.42, 0.0, 0.42]:
		_pm.box(M.timber, Vector3(2.0, 0.05, 0.1), xf * _at(0, 0.025, z))
	_pm.box(M.linen, Vector3(1.9, 0.12, 0.82), xf * _at(0, 0.19, 0))
	_pm.box(M.linen, Vector3(0.38, 0.1, 0.6), xf * _at(-0.72, 0.3, 0))
	if made:
		_pm.box(blanket, Vector3(1.3, 0.05, 0.84), xf * _at(0.28, 0.275, 0))
		_pm.box(blanket, Vector3(0.36, 0.1, 0.5), xf * _at(0.7, 0.35, 0))
	else:
		_pm.box(blanket, Vector3(1.25, 0.06, 0.86), Transform3D(xf.basis * Basis(Vector3.UP, 0.12), xf * Vector3(0.25, 0.28, 0.04)))
		_pm.box(blanket, Vector3(0.3, 0.12, 0.86), xf * _at(-0.28, 0.3, 0.02))
	_boxes.append([Vector3(2.0, 0.34, 0.95), xf * _at(0, 0.17, 0)])


func _crate(p: Vector3, s: float, yaw := 0.0) -> void:
	var xf := _turn(yaw, p + Vector3(0, s * 0.5, 0))
	_pm.box(M.wood, Vector3(s, s, s), xf)
	_pm.box(M.timber, Vector3(s + 0.02, 0.06, s + 0.02), xf * _at(0, s * 0.3, 0))
	_boxes.append([Vector3(s, s, s), xf])


func _kitchen() -> void:
	# The barrel stove on short legs, its door glowing, the pipe up through the roof.
	var s := STOVE
	for a in [0.0, 2.1, 4.2]:
		_pm.box(M.metal, Vector3(0.06, 0.18, 0.06), _at(s.x + 0.28 * cos(a), 0.09, s.z + 0.28 * sin(a)))
	_pm.cyl(M.rust, 0.36, 0.36, 0.8, _at(s.x, 0.58, s.z), 10)
	_pm.box(M.dark, Vector3(0.3, 0.24, 0.04), _at(s.x, 0.55, s.z + 0.35))
	_pm.box(M.fire, Vector3(0.22, 0.08, 0.03), _at(s.x, 0.48, s.z + 0.36))
	_pm.cyl(M.metal, 0.13, 0.13, 0.1, _at(s.x, 1.02, s.z), 8)
	_pm.cyl(M.metal, 0.11, 0.11, ROOF + 1.9 - 1.0, _at(s.x, (1.0 + ROOF + 1.9) * 0.5, s.z), 8)
	_pm.cyl(M.metal, 0.2, 0.2, 0.06, _at(s.x, ROOF + 0.3, s.z), 8)  # the collar on the roof
	_pm.cyl(M.metal, 0.0, 0.26, 0.2, _at(s.x, ROOF + 2.05, s.z), 8)  # rain cap
	for a in [0.5, 2.6, 4.7]:
		_pm.stick(M.metal, Vector3(s.x + 0.11 * cos(a), ROOF + 1.92, s.z + 0.11 * sin(a)), Vector3(s.x + 0.11 * cos(a), ROOF + 2.0, s.z + 0.11 * sin(a)), 0.02)
	_pm.cyl(M.metal, 0.1, 0.12, 0.12, _at(s.x + 0.12, 1.04, s.z + 0.15), 8)  # a pot on the stove
	_boxes.append([Vector3(0.8, 1.0, 0.8), _at(s.x, 0.5, s.z)])
	# A shelf between her bier and the stove: two crates and a plank, pots and jars, a plank above.
	_crate(Vector3(3.45, 0, -IN_Z + 0.32), 0.55)
	_crate(Vector3(4.45, 0, -IN_Z + 0.32), 0.55, 0.1)
	_pm.box(M.wood, Vector3(1.6, 0.05, 0.4), _at(3.95, 0.575, -IN_Z + 0.3))
	_pm.box(M.wood, Vector3(1.5, 0.04, 0.26), _at(3.95, 1.55, -IN_Z + 0.15))
	for p in [[3.4, 0.6, M.metal, 0.11], [3.8, 0.6, M.ceramic, 0.07], [4.5, 0.6, M.ceramic, 0.06], [3.6, 1.57, M.ceramic, 0.06], [4.1, 1.57, M.metal, 0.08], [4.45, 1.57, M.ceramic, 0.05]]:
		_pm.cyl(p[2], p[3], p[3] * 0.85, 0.16, _at(p[0], p[1] + 0.08, -IN_Z + 0.25), 6)
	# The water drum, crates stacked for shelves along the end wall, pots and tins on them.
	_pm.cyl(M.hull, 0.3, 0.3, 0.9, _at(7.3, 0.45, -2.5), 10)
	_pm.cyl(M.metal, 0.31, 0.31, 0.04, _at(7.3, 0.9, -2.5), 10)
	_boxes.append([Vector3(0.6, 0.9, 0.6), _at(7.3, 0.45, -2.5)])
	for c in [[7.35, 0.0, 0.4], [7.35, 0.0, 1.1], [7.35, 0.6, 0.75]]:
		_crate(Vector3(c[0], c[1], c[2]), 0.6)
	for p in [[7.3, 1.2, 0.6, M.metal], [7.4, 1.2, 0.9, M.ceramic], [7.3, 0.6, 1.25, M.metal]]:
		_pm.cyl(p[3], 0.08, 0.07, 0.14, _at(p[0], p[1] + 0.07, p[2]), 6)
	# The table: a cable drum stood on end, a cup and a bowl on it; upturned buckets for stools.
	_pm.cyl(M.wood, 0.55, 0.55, 0.06, _at(4.6, 0.67, 0.6), 10)
	_pm.cyl(M.timber, 0.22, 0.22, 0.6, _at(4.6, 0.34, 0.6), 8)
	_pm.cyl(M.wood, 0.5, 0.5, 0.06, _at(4.6, 0.03, 0.6), 10)
	_pm.cyl(M.ceramic, 0.05, 0.04, 0.08, _at(4.45, 0.74, 0.5), 6)
	_pm.cyl(M.ceramic, 0.12, 0.08, 0.07, _at(4.75, 0.735, 0.72), 8)
	_boxes.append([Vector3(1.0, 0.7, 1.0), _at(4.6, 0.35, 0.6)])
	for b in [Vector3(3.75, 0, 0.9), Vector3(5.4, 0, 0.2)]:
		_pm.cyl(M.metal, 0.17, 0.2, 0.42, _at(b.x, 0.21, b.z), 8)


## A lamp hung over the table, and a string of small bulbs along the ceiling: wire, then bulbs.
func _ceiling_lights() -> void:
	_pm.stick(M.rubber, Vector3(4.6, ROOF, 0.6), Vector3(4.6, 2.35, 0.6), 0.02)
	_pm.cyl(M.metal, 0.07, 0.28, 0.2, _at(4.6, 2.25, 0.6), 8)
	_pm.sphere(M.warm, 0.08, 0.13, _at(4.6, 2.13, 0.6), 6, 3)
	var pts := [Vector3(-IN_X, 3.3, -2.9), Vector3(-2.2, 3.0, 2.9), Vector3(2.6, 3.3, -2.9), Vector3(IN_X, 3.1, 2.9)]
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var mid := (a + b) * 0.5 + Vector3(0, -0.45, 0)
		_pm.stick(M.rubber, a, mid, 0.015)
		_pm.stick(M.rubber, mid, b, 0.015)
		for k in range(1, 6):
			var t := k / 6.0
			var p := a.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(b, t * 2.0 - 1.0)
			_pm.sphere(M.warm, 0.035, 0.06, _at(p.x, p.y - 0.04, p.z), 5, 3)


func _outside() -> void:
	var fz := IN_Z + 0.25  # the outer face of the front wall
	# The water barrel by the door with a plate for a lid and a dipper.
	_pm.cyl(M.rust, 0.32, 0.32, 0.95, _at(-3.3, 0.475, fz + 0.5), 10)
	_pm.box(M.metal, Vector3(0.75, 0.03, 0.75), _turn(0.3, Vector3(-3.3, 0.965, fz + 0.5)))
	_pm.stick(M.metal, Vector3(-3.15, 0.99, fz + 0.4), Vector3(-2.9, 1.25, fz + 0.65), 0.03)
	_boxes.append([Vector3(0.64, 0.95, 0.64), _at(-3.3, 0.475, fz + 0.5)])
	# A bench: a plank on two buckets, against the wall right of the night door.
	for x in [2.0, 3.3]:
		_pm.cyl(M.metal, 0.16, 0.19, 0.4, _at(x, 0.2, fz + 0.4), 8)
	_pm.box(M.wood, Vector3(1.9, 0.05, 0.32), _at(2.65, 0.425, fz + 0.4))
	_boxes.append([Vector3(1.9, 0.45, 0.4), _at(2.65, 0.225, fz + 0.4)])
	# The washing line: two poles stuck in the sand, a line, two cloths.
	for x in [4.6, 7.6]:
		_pm.stick(M.metal, Vector3(x, -0.3, fz + 2.6), Vector3(x, 1.9, fz + 2.6), 0.06)
	_pm.stick(M.rope, Vector3(4.6, 1.85, fz + 2.6), Vector3(6.1, 1.72, fz + 2.6), 0.015)
	_pm.stick(M.rope, Vector3(6.1, 1.72, fz + 2.6), Vector3(7.6, 1.85, fz + 2.6), 0.015)
	_pm.box(M.linen, Vector3(0.7, 0.8, 0.02), _at(5.3, 1.36, fz + 2.6))
	_pm.box(M.indigo, Vector3(0.5, 0.6, 0.02), _at(6.75, 1.46, fz + 2.6))
	# Scrap for the stove, piled by the far corner: plates leaning, pipe offcuts, a crate.
	for p in [[6.6, 0.0, 1.0, 0.7, 0.35], [7.1, 0.3, 1.2, 0.9, -0.2], [6.2, -0.4, 0.8, 0.6, 0.9]]:
		_pm.box(M.rust if p[4] > 0 else M.metal, Vector3(p[2], p[3], 0.04), Transform3D(Basis(Vector3.UP, p[4]) * Basis(Vector3.RIGHT, -0.35), Vector3(p[0], p[3] * 0.45, fz + 0.4 + p[1] * 0.3)))
	for p in [[5.6, 0.7, 0.3], [5.9, 0.9, -0.5]]:
		_pm.cyl(M.metal, 0.1, 0.1, 1.1, Transform3D(Basis(Vector3.UP, p[2]) * Basis(Vector3.FORWARD, PI * 0.5), Vector3(p[0], 0.1, fz + p[1])), 8)
	_crate(Vector3(7.4, 0, fz + 1.2), 0.55, 0.4)


func _guide_lamp() -> void:
	_pm.stick(M.metal, Vector3(0, -0.3, 0), Vector3(0.05, 1.5, 0), 0.06)
	_pm.stick(M.metal, Vector3(0.05, 1.45, 0), Vector3(0.05, 1.45, 0.3), 0.04)
	_pm.cyl(M.metal, 0.05, 0.14, 0.12, _at(0.05, 1.42, 0.3), 6)
	_pm.sphere(M.warm, 0.05, 0.08, _at(0.05, 1.35, 0.3), 5, 3)
	_pm.box(M.red, Vector3(0.03, 0.22, 0.1), _at(0.06, 1.05, -0.02))  # a rag tied on
