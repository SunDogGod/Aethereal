@tool
extends Node3D
## Isabella and Aeneas's house in Black Sand: a one-room farmhouse in their village's style
## (white plaster walls on a dark stone footing, timber posts and beams, a terracotta gable roof,
## a covered wooden veranda, lattice windows) and the low walled yard around it. Picked from Kind.
## Origin on the ground at the middle of the house floor; the front (door, veranda) faces +Z.
## The floors are drawn 3-5 cm above the ground but have no collision (you walk on the sand under
## them, so there is no step). Walls, posts and the yard wall get box collision when the game runs.
## Things inside and around it (the bier, furniture, lanterns) are sand_home.gd.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	plaster = preload("res://materials/black_sand_plaster.tres"), roof = preload("res://materials/terracotta.tres"),
	wood = preload("res://materials/wood.tres"), stone = preload("res://materials/black_sand_stone.tres"),
	paper = preload("res://materials/black_sand_shoji.tres"), dark = preload("res://materials/black_sand_void.tres"),
	timber = preload("res://materials/black_sand_timber.tres"), tatami = preload("res://materials/black_sand_tatami.tres"),
}
const W := 8.0    # house width (x), wall centre to wall centre
const D := 6.0    # house depth (z)
const H := 2.9    # wall height
const T := 0.24   # wall thickness
const PITCH := 24.0  # roof pitch, degrees
const DOOR_X := -1.2  # the door's centre along the front wall (the yard gate lines up with it)

@export_enum("House", "Yard wall") var kind := 0:
	set(value):
		kind = value
		_rebuild()
## Box collision for walls and posts (built when the game runs, never saved in the scene).
@export var solid := true:
	set(value):
		solid = value
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
	if kind == 0:
		_house()
	else:
		_yard_wall()
	_mesh.mesh = _pm.commit()
	if is_inside_tree():
		_apply_collision()


func _apply_collision() -> void:
	if _body:
		_body.queue_free()
		_body = null
	if not solid or _boxes.is_empty() or Engine.is_editor_hint():
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


func _solid(mat: Material, size: Vector3, xf: Transform3D) -> void:
	_pm.box(mat, size, xf)
	_boxes.append([size, xf])


## A wall `length` long and `height` tall, in its own frame `xf` (along local X, centred, from the
## ground up, `thick` deep). openings: [centre, width, bottom, top] along the wall, left to right.
func _wall(xf: Transform3D, length: float, height: float, thick: float, openings: Array, mat: Material) -> void:
	var u := -length * 0.5
	for o in openings:
		var a: float = o[0] - o[1] * 0.5
		var b: float = o[0] + o[1] * 0.5
		if a > u:
			_solid(mat, Vector3(a - u, height, thick), xf * _at((u + a) * 0.5, height * 0.5, 0))
		if o[2] > 0.0:
			_solid(mat, Vector3(b - a, o[2], thick), xf * _at(o[0], o[2] * 0.5, 0))
		if height - o[3] > 0.001:
			_solid(mat, Vector3(b - a, height - o[3], thick), xf * _at(o[0], (height + o[3]) * 0.5, 0))
		u = b
	if u < length * 0.5:
		_solid(mat, Vector3(length * 0.5 - u, height, thick), xf * _at((u + length * 0.5) * 0.5, height * 0.5, 0))


## A timber frame round an opening (lapping 1 cm into it, so its faces never sit on the wall's), and for a window, a lattice of upright bars with paper behind
## it (inside), lit warm from within.
func _frame(xf: Transform3D, o: Array, window: bool) -> void:
	var w: float = o[1]
	var d := T + 0.06
	_pm.box(M.timber, Vector3(0.1, o[3] - o[2], d), xf * _at(o[0] - w * 0.5 - 0.04, (o[2] + o[3]) * 0.5, 0))
	_pm.box(M.timber, Vector3(0.1, o[3] - o[2], d), xf * _at(o[0] + w * 0.5 + 0.04, (o[2] + o[3]) * 0.5, 0))
	_pm.box(M.timber, Vector3(w + 0.3, 0.12, d), xf * _at(o[0], o[3] + 0.05, 0))
	if not window:
		return
	_pm.box(M.timber, Vector3(w + 0.3, 0.1, d + 0.04), xf * _at(o[0], o[2] - 0.04, 0))  # the sill
	var n := int(w / 0.13)
	for i in n:
		var x: float = o[0] - w * 0.5 + (i + 0.5) * w / n
		_pm.box(M.wood, Vector3(0.035, o[3] - o[2], 0.05), xf * _at(x, (o[2] + o[3]) * 0.5, 0.03))
	_pm.box(M.paper, Vector3(w, o[3] - o[2], 0.02), xf * _at(o[0], (o[2] + o[3]) * 0.5, -T * 0.5 + 0.03))


func _house() -> void:
	var front := [[DOOR_X, 1.2, 0.0, 2.1], [2.1, 1.5, 0.9, 1.75]]
	var side := [[0.0, 1.0, 1.0, 1.7]]
	var fxf := _at(0, 0, D * 0.5)
	_wall(fxf, W - T, H, T, front, M.plaster)
	_frame(fxf, front[0], false)
	_frame(fxf, front[1], true)
	_wall(_at(0, 0, -D * 0.5), W - T, H, T, [], M.plaster)
	var exf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(W * 0.5, 0, 0))  # east wall, faces +X
	_wall(exf, D - T, H, T, side, M.plaster)
	_frame(exf, side[0], true)
	_wall(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-W * 0.5, 0, 0)), D - T, H, T, [], M.plaster)
	# Corner posts, the footing and the beam band (each a little proud of the one inside it).
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_solid(M.timber, Vector3(0.36, H, 0.36), _at(sx * W * 0.5, H * 0.5, sz * D * 0.5))
	for sz in [-1, 1]:
		_pm.box(M.stone, Vector3(W + 0.4, 0.4, T + 0.16), _at(0, 0.1, sz * D * 0.5))
		_pm.box(M.timber, Vector3(W + 0.4, 0.18, T + 0.18), _at(0, H - 0.16, sz * D * 0.5))
	for sx in [-1, 1]:
		_pm.box(M.stone, Vector3(T + 0.16, 0.39, D + 0.4), _at(sx * W * 0.5, 0.095, 0))
	# Floors: wood, with tatami in the west half; a stone step-down inside the door (genkan).
	_pm.box(M.wood, Vector3(W - T, 0.1, D - T), _at(0, -0.02, 0))
	for i in 3:
		_pm.box(M.tatami, Vector3(0.9, 0.02, 1.8), _at(-3.3 + i * 0.95, 0.04, -1.6))
	_pm.box(M.stone, Vector3(1.2, 0.02, 0.9), _at(DOOR_X, 0.04, D * 0.5 - 0.6))
	_pm.box(M.wood, Vector3(W - T, 0.06, D - T), _at(0, H - 0.03, 0))  # the ceiling
	# The sliding door, pushed open to the right (inside the wall line).
	_pm.box(M.timber, Vector3(1.2, 2.06, 0.05), _at(DOOR_X + 1.2, 1.06, D * 0.5 - T * 0.5 - 0.04))
	_pm.box(M.paper, Vector3(1.0, 1.4, 0.02), _at(DOOR_X + 1.2, 1.2, D * 0.5 - T * 0.5 - 0.09))
	_roof()
	_veranda()


## A gable roof: a plaster gable under two tiled slabs, a ridge with end tiles. The front slab
## reaches out over the veranda; its lowest edge is 2.2 m up.
func _roof() -> void:
	var a := deg_to_rad(PITCH)
	var half := D * 0.5 + T * 0.5
	var h := half * tan(a)
	var gable := PrismMesh.new()
	gable.size = Vector3(D + T, h, W + T)
	# PrismMesh is a primitive like the others, so PropMesh can take it (through its _add).
	_pm._add(M.plaster, gable, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, H + h * 0.5, 0)))
	var ridge := Vector3(0, H + h, 0)
	var thick := 0.16
	var length := W + T + 0.9
	for side in [[1.0, 1.55], [-1.0, 0.75]]:
		var s: float = side[0]
		var run: float = half + side[1]
		var slope := run / cos(a) + 0.12
		var down := Vector3(0, -sin(a), s * cos(a))
		var out := Vector3(0, cos(a), s * sin(a))
		var centre := ridge + down * (slope * 0.5 - 0.12) + out * (thick * 0.5 + 0.02)
		_pm.box(M.roof, Vector3(length, thick, slope), Transform3D(Basis(Vector3.RIGHT, s * a), centre))
		var edge := ridge + down * (slope - 0.12) + out * (thick * 0.5)
		_pm.box(M.timber, Vector3(length, 0.14, 0.08), _at(0, edge.y - 0.04, edge.z + s * 0.02))  # fascia
	_pm.box(M.stone, Vector3(length + 0.1, 0.2, 0.34), _at(0, ridge.y + 0.2, 0))
	for sx in [-1, 1]:
		_pm.box(M.stone, Vector3(0.3, 0.42, 0.42), _at(sx * (length * 0.5 + 0.1), ridge.y + 0.28, 0))


## The veranda along the front: a plank deck at ground level, two posts and a beam under the eave.
func _veranda() -> void:
	var z0 := D * 0.5 + 0.2
	var z1 := D * 0.5 + 1.4
	_pm.box(M.wood, Vector3(W + 0.4, 0.08, z1 - z0), _at(0, 0.01, (z0 + z1) * 0.5))
	for i in 9:  # plank lines
		_pm.box(M.timber, Vector3(0.02, 0.02, z1 - z0), _at(-W * 0.5 + i * (W / 8.0), 0.055, (z0 + z1) * 0.5))
	for sx in [-1, 1]:
		_solid(M.timber, Vector3(0.16, 2.3, 0.16), _at(sx * (W * 0.5 + 0.05), 1.15, z1 - 0.1))
	_pm.box(M.timber, Vector3(W + 0.5, 0.14, 0.16), _at(0, 2.27, z1 - 0.1))


## The yard: a low plastered wall with a tiled cap round the house and a small garden in front,
## a timber gate (no doors) in line with the house door. Origin = the house's origin.
func _yard_wall() -> void:
	var x0 := -6.5
	var x1 := 6.5
	var zb := -4.2
	var zf := 9.0
	var h := 1.3
	var t := 0.3
	var gate := [[DOOR_X, 1.8, 0.0, h + 0.4]]
	_yard_run(_at(0, -0.4, zf), x1 - x0 + t, h + 0.4, t, gate)
	_yard_run(_at(0, -0.4, zb), x1 - x0 + t, h + 0.4, t, [])
	for sx in [-1, 1]:
		_yard_run(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(sx * x1, -0.4, (zf + zb) * 0.5)), zf - zb - t, h + 0.4, t, [], 0.06)
	# The gate: two posts, a tie beam at 2.3 m, a little tiled roof.
	for s in [-1, 1]:
		_solid(M.timber, Vector3(0.24, 2.5, 0.24), _at(DOOR_X + s * 1.01, 1.25, zf))
	_pm.box(M.timber, Vector3(2.6, 0.16, 0.2), _at(DOOR_X, 2.38, zf))
	for s in [-1, 1]:
		_pm.box(M.roof, Vector3(2.9, 0.08, 0.6), Transform3D(Basis(Vector3.RIGHT, s * 0.45), Vector3(DOOR_X, 2.62, zf + s * 0.24)))
	_pm.box(M.stone, Vector3(3.0, 0.1, 0.12), _at(DOOR_X, 2.76, zf))


## One run of yard wall with its tiled cap (`cap_trim`: shortens the cap so caps never overlap
## at the corners).
func _yard_run(xf: Transform3D, length: float, height: float, thick: float, openings: Array, cap_trim := 0.0) -> void:
	_wall(xf, length, height, thick, openings, M.plaster)
	var caps := [[-length * 0.5 + cap_trim, length * 0.5 - cap_trim]]
	var feet := [[-length * 0.5, length * 0.5]]
	if not openings.is_empty():
		var o: Array = openings[0]
		caps = [[-length * 0.5, o[0] - o[1] * 0.5], [o[0] + o[1] * 0.5, length * 0.5]]
		feet = caps
	for c in caps:  # the tiled cap
		_pm.box(M.roof, Vector3(c[1] - c[0], 0.1, thick + 0.12), xf * _at((c[0] + c[1]) * 0.5, height + 0.05, 0))
	var foot_h := 0.62 if cap_trim == 0.0 else 0.61  # side runs a hair lower, so the corners never z-fight
	for c in feet:  # a dark footing just above the sand
		_pm.box(M.stone, Vector3(c[1] - c[0], foot_h, thick + 0.04), xf * _at((c[0] + c[1]) * 0.5, foot_h * 0.5, 0))
