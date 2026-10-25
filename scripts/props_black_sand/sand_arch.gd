@tool
extends Node3D
## The buried arch: the upper half of a giant Precursor ring standing in the sand, its lower half
## underground. Built from stone segments with glowing joints between them, a lit line along the
## underside and a crown on top. The node's origin is the CENTRE of the ring (put it near sand
## level); the ring stands in the node's XY plane, so you walk through it along Z.
## Each segment gets box collision when the game runs (never saved in the scene).

const PropMesh := preload("res://scripts/props/prop_mesh.gd")

@export var inner_radius := 16.0:
	set(value):
		inner_radius = value
		_rebuild()
@export var outer_radius := 21.0:
	set(value):
		outer_radius = value
		_rebuild()
@export var depth := 6.0:  ## thickness of the ring along Z
	set(value):
		depth = value
		_rebuild()
@export_range(5, 31) var segments := 15:
	set(value):
		segments = value
		_rebuild()
## How far (degrees) the ring carries on below the horizontal at each end, into the sand.
@export var sink_degrees := 12.0:
	set(value):
		sink_degrees = value
		_rebuild()
@export var stone: Material = preload("res://materials/black_sand_arch_worn.tres"):
	set(value):
		stone = value
		_rebuild()
@export var glow: Material = preload("res://materials/precursor_light.tres"):
	set(value):
		glow = value
		_rebuild()

var _mesh := MeshInstance3D.new()
var _boxes: Array = []
var _body: StaticBody3D


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _ready() -> void:
	_apply_collision()


func _rebuild() -> void:
	if stone == null or glow == null:
		return
	var pm := PropMesh.new()
	_boxes.clear()
	var a_start := deg_to_rad(-sink_degrees)
	var a_end := PI + deg_to_rad(sink_degrees)
	var step := (a_end - a_start) / segments
	var t := outer_radius - inner_radius
	var mid_r := (inner_radius + outer_radius) * 0.5
	var seg_len := 2.0 * outer_radius * sin(step * 0.5) - 0.3  # outer faces almost meet
	for i in segments:
		var am := a_start + step * (i + 0.5)
		var xf := _frame(am, mid_r)
		pm.box(stone, Vector3(seg_len, t, depth), xf)
		_boxes.append([Vector3(seg_len, t, depth), xf])
		# The lit line along the underside, inset into each segment's inner face.
		pm.box(glow, Vector3(seg_len * 0.86, 0.1, 0.5), xf * Transform3D(Basis(), Vector3(0, -t * 0.5 - 0.03, 0)))
		# A shallow raised band on both faces, like a frame cut round the ring.
		for side in [-1, 1]:
			pm.box(stone, Vector3(seg_len * 0.98, 0.5, 0.2), xf * Transform3D(Basis(), Vector3(0, t * 0.5 - 0.6, side * (depth * 0.5 + 0.1))))
	# Glowing joints between the segments, standing a little proud of both faces.
	for i in range(1, segments):
		var ab := a_start + step * i
		pm.box(glow, Vector3(0.28, t + 0.3, depth + 0.24), _frame(ab, mid_r))
	# The crown: a raised block on top, with a lit slot.
	var top := _frame(PI * 0.5, outer_radius + 1.1)
	pm.box(stone, Vector3(4.2, 2.2, depth - 1.2), top)
	_boxes.append([Vector3(4.2, 2.2, depth - 1.2), top])
	pm.box(glow, Vector3(0.5, 1.4, depth - 1.0), top)
	_mesh.mesh = pm.commit()
	if is_inside_tree():
		_apply_collision()


## A frame on the ring at angle `a` (radians from +X, counter-clockwise seen from +Z) and radius
## `r`: local X runs along the ring (clockwise), local Y points out from the centre. The basis is
## right-handed (X cross Y = Z): a mirrored one would turn the boxes inside out.
func _frame(a: float, r: float) -> Transform3D:
	var out := Vector3(cos(a), sin(a), 0)
	var along := Vector3(sin(a), -cos(a), 0)
	return Transform3D(Basis(along, out, Vector3(0, 0, 1)), out * r)


func _apply_collision() -> void:
	if _body:
		_body.queue_free()
		_body = null
	if _boxes.is_empty():
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
