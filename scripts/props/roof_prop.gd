@tool
extends Node3D
## Rooftop clutter, built from simple shapes and picked from Kind: a water tank on legs, an
## antenna mast, a satellite dish. Origin on the roof; Variant changes colours and sizes.
## Mostly seen as silhouettes against the fog from the bridge. Purely visual: no collision.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	steel = preload("res://materials/pipe_round.tres"), rust = preload("res://materials/pipe_rust.tres"),
	metal = preload("res://materials/metal.tres"), plaster = preload("res://materials/white_plaster.tres"),
	teal = preload("res://materials/paint_teal.tres"), glow = preload("res://materials/neon_pink.tres"),
}

@export_enum("Water tank", "Antenna", "Dish") var kind := 0:
	set(value):
		kind = value
		_rebuild()
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()

var _mesh := MeshInstance3D.new()
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	var pm := PropMesh.new()
	match kind:
		0: _tank(pm)
		1: _antenna(pm)
		2: _dish(pm)
	_mesh.mesh = pm.commit()


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


func _tank(pm: PropMesh) -> void:
	var body: Material = [M.rust, M.steel, M.teal][posmod(variant, 3)]
	var r := 0.9 + 0.2 * posmod(variant, 2)
	var legs := 0.9
	for x in [-1, 1]:
		for z in [-1, 1]:
			pm.stick(M.metal, Vector3(x * r * 0.6, 0, z * r * 0.6), Vector3(x * r * 0.6, legs, z * r * 0.6), 0.1)
	pm.box(M.metal, Vector3(r * 1.5, 0.1, r * 1.5), _at(0, legs, 0))
	pm.cyl(body, r, r, 1.7, _at(0, legs + 0.9, 0), 10, 2)
	pm.cyl(body, 0.15, r, 0.35, _at(0, legs + 1.75 + 0.175, 0), 10)
	pm.cyl(M.metal, 0.06, 0.06, legs + 0.6, _at(r * 0.75, (legs + 0.6) * 0.5, 0), 6)  # outlet pipe


func _antenna(pm: PropMesh) -> void:
	var h := 3.5 + 1.5 * posmod(variant, 3)
	pm.stick(M.metal, Vector3.ZERO, Vector3(0, h, 0), 0.07)
	for i in 3:
		var y := h - 0.4 - i * 0.6
		var w := 1.1 - i * 0.25
		pm.stick(M.metal, Vector3(-w * 0.5, y, 0), Vector3(w * 0.5, y, 0), 0.04)
	for s in [Vector3(1.2, 0, 0.6), Vector3(-1.0, 0, 0.8), Vector3(0.1, 0, -1.2)]:
		pm.stick(M.metal, Vector3(0, h * 0.6, 0), s, 0.02)  # guy wires
	pm.box(M.glow, Vector3(0.12, 0.12, 0.12), _at(0, h + 0.06, 0))  # warning light


func _dish(pm: PropMesh) -> void:
	var r := 0.5 + 0.2 * posmod(variant, 2)
	pm.stick(M.metal, Vector3.ZERO, Vector3(0, 1.0, 0), 0.08)
	var tilt := Basis(Vector3.RIGHT, 0.9)  # faces up and out toward +Z
	var c := Vector3(0, 1.1, 0.05)
	pm.cyl(M.plaster, r, 0.1, 0.22, Transform3D(tilt, c), 12)
	pm.stick(M.metal, c, c + tilt * Vector3(0, 0.55, 0), 0.03)
	pm.box(M.metal, Vector3(0.1, 0.1, 0.1), Transform3D(tilt, c + tilt * Vector3(0, 0.58, 0)))
