@tool
extends Node3D
## Water stains and rust tails under a ledge: thin dark vertical strips down a wall, placed by
## rule from a seed, each a wide smudge at the top and a narrowing tail. Very thin boxes a
## centimetre proud of the wall (each part at its own distance so they never fight). Origin on
## the wall's face, on the line where the ledge's underside meets it; the wall faces +Z and the
## strips hang down from the origin, spread Length metres along X. A share of them are rust
## tails (from a bolt or a bracket) instead of water. Purely visual, no collision.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")

@export var length := 6.0:
	set(value):
		length = maxf(value, 0.3)
		_rebuild()
@export var random_seed := 1:
	set(value):
		random_seed = value
		_rebuild()
## Average gap between strips.
@export var spacing := 0.8:
	set(value):
		spacing = maxf(value, 0.15)
		_rebuild()
## The longest a strip hangs (each one is 35..100 % of this).
@export var drop := 1.8:
	set(value):
		drop = maxf(value, 0.1)
		_rebuild()
@export var width := 0.18:
	set(value):
		width = maxf(value, 0.03)
		_rebuild()
@export_range(0.0, 1.0) var rust_share := 0.3:
	set(value):
		rust_share = value
		_rebuild()
@export var stain_material: Material = preload("res://materials/kitb_stain.tres"):
	set(value):
		stain_material = value
		_rebuild()
@export var rust_material: Material = preload("res://materials/kitb_rust_tail.tres"):
	set(value):
		rust_material = value
		_rebuild()

var _mesh := MeshInstance3D.new()
var strip_count := 0  # how many strips were placed (for checks)
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	strip_count = 0
	if stain_material == null and rust_material == null:
		_mesh.mesh = null
		return
	var pm := PropMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var x := -length * 0.5 + rng.randf_range(0.1, spacing)
	while x < length * 0.5 - width:
		var rust := rng.randf() < rust_share
		var mat: Material = rust_material if rust and rust_material else stain_material
		if mat == null:
			mat = rust_material
		var len := drop * rng.randf_range(0.35, 1.0)
		var w := width * rng.randf_range(0.7, 1.5)
		# Each strip is two or three overlapping boxes of different widths, so no two strips
		# have the same outline: a head where it starts, a tail, sometimes a thin thread.
		var head := w * rng.randf_range(1.4, 2.6)
		var head_len := len * rng.randf_range(0.15, 0.4)
		var tail := w * rng.randf_range(0.5, 1.0)
		var tail_len := len * rng.randf_range(0.5, 1.0)
		var lean := rng.randf_range(-0.03, 0.03)
		if rust:
			# A rust tail starts at a bolt or a bracket foot: a squat head, then a tail that
			# fans out a little before it fades.
			pm.box(mat, Vector3(head * 0.7, head * 0.7, 0.012), Transform3D(Basis(), Vector3(x, -head * 0.35, 0.006)))
			pm.box(mat, Vector3(tail, tail_len, 0.012), Transform3D(Basis(), Vector3(x + lean, -tail_len * 0.5 - head * 0.3, 0.01)))
			if rng.randf() < 0.6:
				pm.box(mat, Vector3(tail * 1.6, tail_len * 0.3, 0.012), Transform3D(Basis(), Vector3(x + lean, -tail_len * 0.85, 0.008)))
		else:
			# Water: a wide smudge under the ledge, a tail, sometimes a thread at the very end.
			pm.box(mat, Vector3(head, head_len, 0.012), Transform3D(Basis(), Vector3(x, -head_len * 0.5, 0.006)))
			pm.box(mat, Vector3(tail, tail_len, 0.012), Transform3D(Basis(), Vector3(x + lean, -tail_len * 0.5, 0.01)))
			if rng.randf() < 0.5:
				pm.box(mat, Vector3(tail * 0.5, len * 0.5, 0.012), Transform3D(Basis(), Vector3(x + lean * 2.0, -len * 0.75, 0.008)))
		strip_count += 1
		x += maxf(w * 2.2, spacing * rng.randf_range(0.5, 1.6))
	_mesh.mesh = pm.commit()
