@tool
extends Node3D
## Small clutter strewn over a patch of Black Sand, drawn as ONE MultiMesh (one draw call per
## material however many pieces): stones, shards of plate, bolts and rods, bits of cable.
## `points` are where the pieces lie (local to this node, each already on the sand); every piece
## gets its own turn, tilt and size from `seed_value`, sunk a little so it sits in the sand.
## Keep one node per patch (~30 m), so the whole patch can drop out beyond `draw_distance`.
## Purely visual: no collision, so nothing here ever makes a step.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	stone = preload("res://materials/black_sand_stone.tres"), hull = preload("res://materials/black_sand_hull_worn.tres"),
	rust = preload("res://materials/black_sand_hull_rust_worn.tres"), metal = preload("res://materials/metal_worn.tres"),
	rubber = preload("res://materials/rubber.tres"), pipe = preload("res://materials/pipe_rust.tres"),
}

@export_enum("Stones", "Plate shards", "Bolts and rods", "Cable bits") var kind := 0:
	set(value):
		kind = value
		_rebuild()
@export var points := PackedVector3Array():
	set(value):
		points = value
		_rebuild()
@export var seed_value := 1:
	set(value):
		seed_value = value
		_rebuild()
## Pieces are scaled between 0.7 and 1.3 times this.
@export var size := 1.0:
	set(value):
		size = value
		_rebuild()
@export var draw_distance := 55.0:
	set(value):
		draw_distance = value
		_mm.visibility_range_end = maxf(value, 0.0)

static var _pieces := {}  # kind -> ArrayMesh, shared by every scatter of that kind
var _mm := MultiMeshInstance3D.new()
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mm, false, INTERNAL_MODE_FRONT)
	_mm.visibility_range_end = draw_distance
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rebuild()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _piece()
	mm.instance_count = points.size()
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 7919 + kind
	for i in points.size():
		var s := size * r.randf_range(0.7, 1.3)
		var b := Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(-0.35, 0.35))
		mm.set_instance_transform(i, Transform3D(b.scaled(Vector3(s, s, s)), points[i] + Vector3(0, -0.04 * s, 0)))
	_mm.multimesh = mm


## The one piece every instance draws: a little group, so a patch doesn't look stamped.
func _piece() -> ArrayMesh:
	if _pieces.has(kind) and not Engine.is_editor_hint():
		return _pieces[kind]
	var pm := PropMesh.new()
	match kind:
		0:
			pm.sphere(M.stone, 0.2, 0.22, Transform3D(Basis().scaled(Vector3(1.3, 1.0, 1.0)), Vector3(0, 0.06, 0)), 6, 3)
			pm.sphere(M.stone, 0.11, 0.14, Transform3D(Basis(), Vector3(0.32, 0.03, 0.12)), 5, 3)
		1:
			pm.box(M.rust, Vector3(0.7, 0.03, 0.45), Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.06, 0)))
			pm.box(M.hull, Vector3(0.35, 0.03, 0.3), Transform3D(Basis(Vector3.UP, 0.8) * Basis(Vector3.FORWARD, 0.4), Vector3(0.45, 0.06, 0.25)))
		2:
			pm.stick(M.metal, Vector3(-0.4, 0.02, 0), Vector3(0.45, 0.25, 0.1), 0.04)
			pm.cyl(M.metal, 0.05, 0.05, 0.06, Transform3D(Basis(), Vector3(0.2, 0.03, 0.25)), 6)
			pm.cyl(M.pipe, 0.06, 0.06, 0.5, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.1, 0.05, -0.3)), 6)
		3:
			pm.stick(M.rubber, Vector3(-0.6, 0.03, 0), Vector3(0.0, 0.05, 0.2), 0.05)
			pm.stick(M.rubber, Vector3(0.0, 0.05, 0.2), Vector3(0.5, 0.03, -0.1), 0.05)
	var mesh := pm.commit()
	if not Engine.is_editor_hint():
		_pieces[kind] = mesh
	return mesh
