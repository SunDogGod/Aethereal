@tool
extends Node3D
## Many small things strewn over a patch of floor, drawn as ONE MultiMesh (one draw call per
## material however many pieces): grit and chunks of concrete, shards of floor tile, old paper,
## flakes of rust, tufts of moss. The patch is an ellipse `extent` metres across (x, z) round this
## node, thickest in the middle; this node sits on the floor. Purely visual: no collision, so the
## pieces never make a step. Change Kind, Count or Seed in the Inspector and it scatters again.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	concrete = preload("res://materials/concrete_dark_worn.tres"), light = preload("res://materials/concrete_worn.tres"),
	panel = preload("res://materials/precursor_panel.tres"), paper = preload("res://materials/vacuum_station_paper.tres"),
	rust = preload("res://materials/pipe_rust.tres"), moss = preload("res://materials/vacuum_station_moss.tres"),
	metal = preload("res://materials/metal_worn.tres"),
}

@export_enum("Grit and chunks", "Tile shards", "Paper", "Rust flakes", "Moss tufts") var kind := 0:
	set(value):
		kind = value
		_rebuild()
## The patch: metres across in x and z.
@export var extent := Vector2(4, 4):
	set(value):
		extent = value
		_rebuild()
@export_range(1, 400) var count := 60:
	set(value):
		count = value
		_rebuild()
@export var seed_value := 0:
	set(value):
		seed_value = value
		_rebuild()
## 0 = spread evenly; 1 = heaped in the middle.
@export_range(0.0, 1.0) var clump := 0.5:
	set(value):
		clump = value
		_rebuild()
## Not drawn beyond this many metres (0 = always drawn).
@export var draw_distance := 40.0:
	set(value):
		draw_distance = value
		_mm.visibility_range_end = maxf(value, 0.0)

var _mm := MultiMeshInstance3D.new()
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mm, false, INTERNAL_MODE_FRONT)
	_mm.visibility_range_end = draw_distance
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rebuild()


## Every setting calls this: the patch is built once, when it is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + seed_value * 97 + kind * 13
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _piece(kind)
	multi.instance_count = count
	for i in count:
		multi.set_instance_transform(i, _place(rng))
	_mm.multimesh = multi


## Where one piece lands: inside the ellipse, pulled to the middle by `clump`, turned and sized.
func _place(rng: RandomNumberGenerator) -> Transform3D:
	var a := rng.randf() * TAU
	var r := pow(rng.randf(), 0.5 + clump * 1.5)  # > 0.5: more near the middle
	var p := Vector3(cos(a) * r * extent.x * 0.5, 0.0, sin(a) * r * extent.y * 0.5)
	var s := rng.randf_range(0.6, 1.4) * (1.0 + (1.0 - r) * clump * 0.6)
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	match kind:
		0:  # chunks sit a little sunk and tipped
			b = b * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4))
			p.y = -0.01
		1, 2, 3:  # flat things lie flat, a millimetre apart so they don't flicker into each other
			p.y = 0.004 + rng.randf() * 0.006
			s = clampf(s, 0.7, 1.3)
	return Transform3D(b.scaled(Vector3.ONE * s), p)


## The piece, made of a few shapes so it doesn't look like a plain box (PropMesh remembers the
## shapes, so building one per patch is cheap).
static func _piece(k: int) -> ArrayMesh:
	var pm := PropMesh.new()
	match k:
		0:
			pm.box(M.concrete, Vector3(0.16, 0.1, 0.12), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, 0.05, 0)))
			pm.box(M.light, Vector3(0.07, 0.05, 0.08), Transform3D(Basis(Vector3.UP, 1.1), Vector3(0.13, 0.025, 0.06)))
			pm.box(M.concrete, Vector3(0.05, 0.03, 0.05), Transform3D(Basis(Vector3.UP, 0.2), Vector3(-0.1, 0.015, -0.09)))
		1:
			pm.box(M.panel, Vector3(0.28, 0.02, 0.2), Transform3D(Basis(Vector3.UP, 0.2), Vector3(0, 0.01, 0)))
			pm.box(M.panel, Vector3(0.12, 0.02, 0.1), Transform3D(Basis(Vector3.UP, 0.9), Vector3(0.22, 0.01, 0.1)))
		2:
			pm.box(M.paper, Vector3(0.1, 0.003, 0.15), Transform3D(Basis(Vector3.UP, 0.1), Vector3.ZERO))
			pm.box(M.paper, Vector3(0.08, 0.003, 0.06), Transform3D(Basis(Vector3.UP, 1.2), Vector3(0.14, 0.001, 0.06)))
		3:
			pm.box(M.rust, Vector3(0.09, 0.006, 0.06), Transform3D(Basis(Vector3.UP, 0.3), Vector3.ZERO))
			pm.box(M.metal, Vector3(0.03, 0.03, 0.18), Transform3D(Basis(Vector3.UP, 1.0), Vector3(0.12, 0.012, 0.0)))  # a bolt or a bar end
		4:
			pm.sphere(M.moss, 0.12, 0.08, Transform3D(Basis(), Vector3(0, 0.01, 0)), 6, 2)
			pm.sphere(M.moss, 0.07, 0.05, Transform3D(Basis(), Vector3(0.12, 0.005, 0.05)), 6, 2)
	return pm.commit()
