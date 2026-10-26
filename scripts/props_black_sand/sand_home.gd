@tool
extends Node3D
## The things in and around the family house (sand_house.gd), picked from Kind:
##  Bier: Isabella's body, wrapped in white linen and bound with cord, on a low wooden bier, her
##    bell and her brush by her head, two candles and an incense bowl on the floor. Origin on the
##    floor under the bier's middle; the bier runs along X, her head toward -X, its back to -Z.
##  Room: the everyday things of the one room (low table, cushions, rolled bedding, a chest, a
##    shelf, a house shrine, a hanging scroll, a hearth). Origin = the house's origin.
##  Yard: stepping stones, a stone lantern, a water jar, firewood, a bench, pots, a garden bed,
##    a washing line, sandals, a broom, paper lanterns at the gate. Origin = the house's origin.
## Purely visual except the bier, the chest, the hearth and the stone lantern (box collision when
## the game runs), so nothing on the way in makes a step. The lights are separate OmniLight3D nodes.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	wood = preload("res://materials/wood.tres"), timber = preload("res://materials/black_sand_timber.tres"),
	linen = preload("res://materials/black_sand_linen.tres"), indigo = preload("res://materials/black_sand_indigo.tres"),
	rope = preload("res://materials/black_sand_rope.tres"), soil = preload("res://materials/black_sand_soil.tres"),
	brass = preload("res://materials/brass.tres"), candle = preload("res://materials/candle.tres"),
	ceramic = preload("res://materials/ceramic.tres"), leaf = preload("res://materials/leaf.tres"),
	stone = preload("res://materials/black_sand_stone.tres"), paper = preload("res://materials/black_sand_shoji.tres"),
	lantern = preload("res://materials/lantern.tres"), dark = preload("res://materials/black_sand_void.tres"),
	red = preload("res://materials/paint_red.tres"), metal = preload("res://materials/metal.tres"),
	tatami = preload("res://materials/black_sand_tatami.tres"),
}
const DOOR_X := -1.2  # keep in step with sand_house.gd

@export_enum("Bier", "Room", "Yard") var kind := 0:
	set(value):
		kind = value
		_rebuild()

var _mesh := MeshInstance3D.new()
var _pm: PropMesh
var _boxes: Array = []
var _body: StaticBody3D
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _ready() -> void:
	_apply_collision()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	_pm = PropMesh.new()
	_boxes.clear()
	match kind:
		0: _bier()
		1: _room()
		2: _yard()
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


## A transform lying along X (for cylinders: logs, the rolled bedding, the body).
func _along_x(x: float, y: float, z: float, squash := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(Vector3.FORWARD, PI * 0.5).scaled(squash), Vector3(x, y, z))


func _bier() -> void:
	var top := 0.45
	_pm.box(M.wood, Vector3(2.1, 0.08, 0.84), _at(0, top - 0.04, 0))
	for sx in [-0.95, 0.95]:
		for sz in [-0.35, 0.35]:
			_pm.box(M.timber, Vector3(0.1, top - 0.08, 0.1), _at(sx, (top - 0.08) * 0.5, sz))
	_pm.box(M.timber, Vector3(1.8, 0.06, 0.06), _at(0, 0.12, -0.35))
	_pm.box(M.timber, Vector3(1.8, 0.06, 0.06), _at(0, 0.12, 0.35))
	_boxes.append([Vector3(2.1, top, 0.84), _at(0, top * 0.5, 0)])
	_pm.box(M.linen, Vector3(2.0, 0.03, 0.9), _at(0, top + 0.015, 0))  # the sheet under her
	# Her body in the shroud, head to -X: the head and neck, the shoulders and chest, her hands
	# folded on it, the legs narrowing to the feet (the toes lift the cloth), cords at neck, waist
	# and ankles. Squashed cylinders, so the shape lies low like a body, not a roll of cloth.
	var b := top + 0.03
	var flat := Vector3(1.0, 0.6, 1.0)
	_pm.sphere(M.linen, 0.115, 0.2, Transform3D(Basis().scaled(Vector3(1.2, 1.0, 1.0)), Vector3(-0.78, b + 0.1, 0)), 10, 5)
	_pm.cyl(M.linen, 0.07, 0.07, 0.12, _along_x(-0.64, b + 0.08, 0), 8)
	_pm.cyl(M.linen, 0.2, 0.23, 0.5, _along_x(-0.33, b + 0.12, 0, flat), 10)  # shoulders to waist
	_pm.cyl(M.linen, 0.13, 0.2, 0.75, _along_x(0.28, b + 0.1, 0, flat), 10)  # hips to ankles
	_pm.sphere(M.linen, 0.11, 0.2, _at(0.72, b + 0.12, 0), 8, 4)  # the feet
	_pm.sphere(M.linen, 0.1, 0.09, _at(-0.2, b + 0.25, 0), 8, 3)  # the folded hands
	for c in [[-0.62, 0.16, 0.16, 0.08], [-0.08, 0.44, 0.27, 0.12], [0.6, 0.29, 0.18, 0.1]]:  # x, width, height, centre
		_pm.box(M.rope, Vector3(0.03, c[2], c[1]), _at(c[0], b + c[3], 0))
	# An indigo cloth folded over her legs, its edges hanging down either side.
	_pm.box(M.indigo, Vector3(0.46, 0.025, 0.5), _at(0.3, b + 0.2, 0))
	for sz in [-1, 1]:
		_pm.box(M.indigo, Vector3(0.46, 0.17, 0.02), _at(0.3, b + 0.115, sz * 0.25))
	for i in 3:  # flowers laid by her hands
		_pm.sphere(M.linen if i != 1 else M.candle, 0.04, 0.05, _at(-0.33 + i * 0.07, b + 0.27, -0.06 + i * 0.05), 6, 3)
		_pm.stick(M.leaf, Vector3(-0.33 + i * 0.07, b + 0.26, -0.06 + i * 0.05), Vector3(-0.12 + i * 0.05, b + 0.25, 0.02), 0.012)
	# Her bell and her brush, by her head.
	_pm.cyl(M.brass, 0.03, 0.065, 0.1, _at(-0.9, top + 0.08, 0.27), 8)
	_pm.sphere(M.brass, 0.022, 0.04, _at(-0.9, top + 0.15, 0.27), 6, 3)
	_pm.stick(M.wood, Vector3(-0.98, top + 0.045, -0.3), Vector3(-0.7, top + 0.045, -0.24), 0.018)
	_pm.cyl(M.dark, 0.0, 0.016, 0.05, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-1.01, top + 0.045, -0.305)), 6)
	# On the floor at her head: two candles in brass holders, an incense bowl with one stick.
	for sz in [-0.3, 0.3]:
		_pm.cyl(M.brass, 0.06, 0.07, 0.05, _at(-1.35, 0.025, sz), 8)
		_pm.cyl(M.candle, 0.025, 0.025, 0.24, _at(-1.35, 0.17, sz), 6)
	_pm.cyl(M.ceramic, 0.09, 0.06, 0.08, _at(-1.38, 0.04, 0), 8)
	_pm.stick(M.red, Vector3(-1.38, 0.06, 0), Vector3(-1.38, 0.3, 0.02), 0.008)


func _room() -> void:
	# Low table with two cups and a teapot, cushions either side.
	_pm.box(M.wood, Vector3(0.9, 0.05, 0.7), _at(-2.2, 0.33, 0.6))
	for sx in [-0.38, 0.38]:
		for sz in [-0.28, 0.28]:
			_pm.box(M.timber, Vector3(0.06, 0.3, 0.06), _at(-2.2 + sx, 0.16, 0.6 + sz))
	for c in [Vector3(-2.4, 0.39, 0.5), Vector3(-2.0, 0.39, 0.75)]:
		_pm.cyl(M.ceramic, 0.04, 0.035, 0.07, _at(c.x, c.y, c.z), 6)
	_pm.sphere(M.ceramic, 0.09, 0.14, _at(-2.15, 0.43, 0.45), 8, 4)
	_pm.stick(M.ceramic, Vector3(-2.07, 0.43, 0.45), Vector3(-1.98, 0.48, 0.45), 0.025)
	for z in [-0.05, 1.25]:
		_pm.box(M.indigo, Vector3(0.55, 0.07, 0.55), _at(-2.2, 0.065, z))
	# Rolled bedding in the corner, tied with cord.
	_pm.cyl(M.linen, 0.19, 0.19, 1.0, _along_x(-3.3, 0.22, 2.45), 10)
	_pm.cyl(M.indigo, 0.2, 0.2, 0.9, _along_x(-3.3, 0.22, 2.45, Vector3(1.0, 1.0, 1.0)), 10)
	for x in [-3.6, -3.0]:
		_pm.cyl(M.rope, 0.205, 0.205, 0.04, _along_x(x, 0.22, 2.45), 10)
	# A chest of drawers against the west wall (facing +X), brass pulls.
	_pm.box(M.wood, Vector3(0.45, 1.1, 1.0), _at(-3.62, 0.58, 0.0))
	_boxes.append([Vector3(0.45, 1.1, 1.0), _at(-3.62, 0.58, 0.0)])
	for i in 4:
		var y := 0.2 + i * 0.26
		_pm.box(M.timber, Vector3(0.02, 0.02, 0.96), _at(-3.39, y + 0.12, 0.0))
		_pm.box(M.brass, Vector3(0.03, 0.04, 0.12), _at(-3.38, y, 0.0))
	# A shelf on the back wall with jars and a basket.
	_pm.box(M.wood, Vector3(1.4, 0.04, 0.26), _at(-2.3, 1.45, -2.74))
	for b in [[-2.8, 0.09, 0.22], [-2.5, 0.07, 0.16], [-2.2, 0.1, 0.26]]:
		_pm.cyl(M.ceramic, b[1] * 0.8, b[1], b[2], _at(b[0], 1.47 + b[2] * 0.5, -2.74), 8)
	_pm.cyl(M.rope, 0.16, 0.12, 0.16, _at(-1.8, 1.55, -2.72), 8)
	# The house shrine over the bier: a shelf, a little gabled box, two plates of offerings.
	_pm.box(M.wood, Vector3(0.9, 0.04, 0.3), _at(1.3, 1.95, -2.72))
	_pm.box(M.wood, Vector3(0.36, 0.3, 0.2), _at(1.3, 2.12, -2.76))
	_pm.box(M.timber, Vector3(0.44, 0.04, 0.26), _at(1.3, 2.29, -2.76))
	for sx in [-0.32, 0.32]:
		_pm.cyl(M.ceramic, 0.07, 0.06, 0.02, _at(1.3 + sx, 1.98, -2.68), 8)
	# A hanging scroll beside it.
	_pm.box(M.linen, Vector3(0.5, 1.0, 0.015), _at(2.9, 1.55, -2.865))
	_pm.box(M.indigo, Vector3(0.12, 0.5, 0.005), _at(2.9, 1.6, -2.85))
	for y in [1.04, 2.06]:
		_pm.cyl(M.timber, 0.02, 0.02, 0.6, _along_x(2.9, y, -2.86), 6)
	# The hearth: a plastered stove with an iron pot.
	_pm.box(M.stone, Vector3(0.9, 0.62, 0.65), _at(3.35, 0.31, 2.4))
	_boxes.append([Vector3(0.9, 0.62, 0.65), _at(3.35, 0.31, 2.4)])
	_pm.cyl(M.metal, 0.2, 0.16, 0.22, _at(3.35, 0.73, 2.4), 8)
	_pm.box(M.dark, Vector3(0.3, 0.2, 0.02), _at(3.35, 0.2, 2.07))
	# Sandals at the step inside the door.
	for i in 2:
		for s in [-0.08, 0.08]:
			var x: float = DOOR_X - 0.25 + i * 0.5 + s
			_pm.box(M.wood, Vector3(0.1, 0.03, 0.25), _at(x, 0.065, 2.6))
			_pm.box(M.indigo, Vector3(0.1, 0.02, 0.03), _at(x, 0.09, 2.53))


func _yard() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 2105
	for z in [8.3, 7.45, 6.6, 5.75, 4.95]:  # stepping stones, gate to veranda
		_pm.box(M.stone, Vector3(0.62, 0.05, 0.5), Transform3D(Basis(Vector3.UP, r.randf_range(-0.2, 0.2)), Vector3(DOOR_X + r.randf_range(-0.1, 0.1), 0.01, z)))
	_toro(Vector3(3.3, 0, 7.0))
	# The water jar by the veranda, its lid and ladle.
	_pm.cyl(M.ceramic, 0.27, 0.24, 0.7, _at(-3.4, 0.35, 4.9), 10)
	_pm.cyl(M.wood, 0.3, 0.3, 0.04, _at(-3.4, 0.72, 4.9), 10)
	_pm.stick(M.wood, Vector3(-3.5, 0.75, 4.75), Vector3(-3.1, 0.76, 5.1), 0.03)
	_boxes.append([Vector3(0.55, 0.74, 0.55), _at(-3.4, 0.37, 4.9)])
	# Firewood stacked against the west wall, log ends out.
	for row in 3:
		for i in 7 - row:
			_pm.cyl(M.wood, 0.1, 0.1, 0.5, _along_x(-4.55, 0.11 + row * 0.18, -1.4 + i * 0.21 + row * 0.1), 6)
	# A bench on the veranda, pots inside the gate, a garden bed.
	_pm.box(M.wood, Vector3(1.4, 0.05, 0.36), _at(2.4, 0.43, 3.85))
	for sx in [-0.6, 0.6]:
		_pm.box(M.timber, Vector3(0.06, 0.38, 0.3), _at(2.4 + sx, 0.22, 3.85))
	for x in [DOOR_X - 1.5, DOOR_X + 1.5]:
		_pm.cyl(M.ceramic, 0.2, 0.15, 0.32, _at(x, 0.16, 8.25), 8)
		_pm.sphere(M.leaf, 0.26, 0.36, _at(x, 0.46, 8.25), 7, 4)
	_pm.box(M.timber, Vector3(1.7, 0.22, 3.1), _at(4.7, 0.1, 6.4))
	_pm.box(M.soil, Vector3(1.5, 0.04, 2.9), _at(4.7, 0.21, 6.4))
	for i in 12:
		_pm.box(M.leaf, Vector3(0.12, 0.14, 0.12), Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(4.3 + (i % 3) * 0.4, 0.29, 5.3 + (i / 3) * 0.7)))
	# A washing line in the side yard (east), off the path: two poles, a sheet, a cloth, a shirt.
	for z in [-2.4, 2.4]:
		_pm.box(M.timber, Vector3(0.08, 2.0, 0.08), _at(5.4, 1.0, z))
	_pm.box(M.rope, Vector3(0.015, 0.015, 4.8), _at(5.4, 1.95, 0))
	_pm.box(M.linen, Vector3(0.02, 0.9, 1.3), _at(5.4, 1.5, -1.2))
	_pm.box(M.indigo, Vector3(0.02, 0.6, 0.7), _at(5.4, 1.65, 0.4))
	_pm.box(M.tatami, Vector3(0.02, 0.55, 0.6), _at(5.4, 1.67, 1.5))
	# A broom leaning by the door.
	_pm.stick(M.wood, Vector3(-0.35, 0.3, 3.3), Vector3(-0.3, 1.45, 3.24), 0.03)
	_pm.box(M.rope, Vector3(0.28, 0.32, 0.06), Transform3D(Basis(Vector3.FORWARD, -0.04), Vector3(-0.355, 0.16, 3.31)))
	# Paper lanterns on brackets on the outer face of the gate posts.
	for s in [-1, 1]:
		var p := Vector3(DOOR_X + s * 1.14, 1.95, 9.3)
		_pm.stick(M.timber, p + Vector3(0, 0.3, -0.18), p + Vector3(0, 0.3, 0.02), 0.03)
		_pm.cyl(M.lantern, 0.15, 0.15, 0.34, _at(p.x, p.y, p.z + 0.05), 8)
		_pm.cyl(M.timber, 0.1, 0.1, 0.04, _at(p.x, p.y + 0.19, p.z + 0.05), 8)
		_pm.cyl(M.timber, 0.1, 0.1, 0.04, _at(p.x, p.y - 0.19, p.z + 0.05), 8)


## A stone lantern: footing, post, a fire box with paper sides, a four-sided cap and a finial.
func _toro(p: Vector3) -> void:
	_pm.box(M.stone, Vector3(0.6, 0.2, 0.6), _at(p.x, 0.08, p.z))
	_pm.cyl(M.stone, 0.11, 0.13, 0.6, _at(p.x, 0.48, p.z), 6)
	_pm.box(M.stone, Vector3(0.5, 0.08, 0.5), _at(p.x, 0.82, p.z))
	for sx in [-0.17, 0.17]:
		for sz in [-0.17, 0.17]:
			_pm.box(M.stone, Vector3(0.08, 0.32, 0.08), _at(p.x + sx, 1.02, p.z + sz))
	_pm.box(M.paper, Vector3(0.3, 0.28, 0.3), _at(p.x, 1.02, p.z))
	_pm.cyl(M.stone, 0.06, 0.42, 0.26, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(p.x, 1.31, p.z)), 4)
	_pm.sphere(M.stone, 0.07, 0.14, _at(p.x, 1.5, p.z), 6, 3)
	_boxes.append([Vector3(0.6, 1.5, 0.6), _at(p.x, 0.75, p.z)])
