@tool
extends Node3D
## A cable strung between anchor Points (local to this node), hanging `sag` metres low in the
## middle of each span, like power and phone lines between buildings. Edit the Points in the
## Inspector; the cable rebuilds. Purely visual (no collision). Keep the lowest point of a span
## at least 2.6 m above any floor people walk on.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")

@export var points := PackedVector3Array([Vector3.ZERO, Vector3(6, 0, 0)]):
	set(value):
		points = value
		_rebuild()
@export var sag := 0.5:
	set(value):
		sag = value
		_rebuild()
@export var thickness := 0.04:
	set(value):
		thickness = value
		_rebuild()
@export var material: Material = preload("res://materials/rubber.tres"):
	set(value):
		material = value
		_rebuild()
## Straight pieces per span: more = a smoother curve.
@export_range(2, 16) var pieces := 8:
	set(value):
		pieces = value
		_rebuild()
## Paper lanterns hanging from the cable every this many metres (0 = none). They glow but cast
## no light, so a string of them costs nothing.
@export var lantern_every := 0.0:
	set(value):
		lantern_every = value
		_rebuild()
@export var lantern_material: Material = preload("res://materials/candle.tres"):
	set(value):
		lantern_material = value
		_rebuild()

var _mesh := MeshInstance3D.new()


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _rebuild() -> void:
	if material == null or points.size() < 2:
		_mesh.mesh = null
		return
	var pm := PropMesh.new()
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var prev := a
		for k in range(1, pieces + 1):
			var t := float(k) / pieces
			var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
			pm.stick(material, prev, p, thickness)
			prev = p
		if lantern_every > 0.0 and lantern_material:
			var n := int(a.distance_to(b) / lantern_every)
			for k in n:
				var t := (k + 0.5) / n
				var top := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
				pm.stick(material, top, top + Vector3.DOWN * 0.12, 0.015)
				pm.cyl(lantern_material, 0.08, 0.1, 0.2, Transform3D(Basis(), top + Vector3.DOWN * 0.22), 6)
	_mesh.mesh = pm.commit()


## The lowest point of every span, in this node's space (for checks).
func lowest_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in points.size() - 1:
		out.append(points[i].lerp(points[i + 1], 0.5) + Vector3.DOWN * sag)
	return out
