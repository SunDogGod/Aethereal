@tool
extends StaticBody3D
## The shared part of the Vacuum Station prop scripts (station_prop.gd, station_fixture.gd,
## capsule_prop.gd): ONE mesh built from simple shapes (scripts/props/prop_mesh.gd), plus, with
## Solid on, a box collision around the prop's footprint so Aeneas bumps into it like a wall.
## A solid prop is never a step: it is taller than a step, or it is left walk-through.
## Origin on the floor; a prop that stands against a wall has the wall behind it (-Z), facing +Z.
## The mesh and collision are made in code, so the Scene panel only shows the prop itself.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")

## Changes colours and small details, so two of the same Kind don't look identical.
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()
## Off = walk-through (purely visual).
@export var solid := true:
	set(value):
		solid = value
		_rebuild()
## Not drawn beyond this many metres (0 = always drawn).
@export var draw_distance := 0.0:
	set(value):
		draw_distance = value
		_mesh.visibility_range_end = maxf(value, 0.0)

## The prop's collision box in its own space (set by each Kind; read by the audit scripts).
var footprint := AABB()
var pm: PropMesh
var _mesh := MeshInstance3D.new()
var _shape := CollisionShape3D.new()
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	add_child(_shape, false, INTERNAL_MODE_FRONT)
	_rebuild()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	pm = PropMesh.new()
	footprint = AABB()
	_build()
	_mesh.mesh = pm.commit()
	var box := BoxShape3D.new()
	box.size = footprint.size if footprint.size != Vector3.ZERO else Vector3.ONE * 0.01
	_shape.shape = box
	_shape.position = footprint.get_center()
	_shape.disabled = not solid or footprint.size == Vector3.ZERO


## Each script fills `pm` with shapes here and sets `footprint` with fp().
func _build() -> void:
	pass


func fp(size: Vector3, center: Vector3) -> void:
	footprint = AABB(center - size * 0.5, size)


static func at(x: float, y: float, z: float, b := Basis()) -> Transform3D:
	return Transform3D(b, Vector3(x, y, z))


## A box between two corners (axis-aligned in the prop's space).
func span(mat: Material, a: Vector3, b: Vector3) -> void:
	pm.box(mat, (b - a).abs(), Transform3D(Basis(), (a + b) * 0.5))


## One flat face with the whole texture on it (a QuadMesh, its front toward +Z of `xf`), for
## textured faces: signs, boards, grilles. PropMesh boxes use BoxMesh's UVs, a 3 x 2 atlas of
## faces, so a texture on a box shows only a piece of itself.
func face(mat: Material, size: Vector2, xf: Transform3D) -> void:
	var q := QuadMesh.new()
	q.size = size
	pm._add(mat, q, xf)
