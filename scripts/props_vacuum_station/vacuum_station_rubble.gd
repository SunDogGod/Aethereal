@tool
extends StaticBody3D
## The collapsed half of the waystation, picked from Kind:
##   Mound: a heap of broken concrete `extent` across (x, height, z), chunks tumbled at random
##     (the same `seed_value` always gives the same heap), a few bent bars poking out. Its
##     collision is one box round the heap's core, so Aeneas walks into it like a wall.
##   Slab: a fallen piece of the roof `extent` big: the slab, the ribs that were on its underside,
##     a torn +X edge with bars sticking out. Tilt the node to lean it. Collision: the slab.
##   Bent beam: a steel I-beam `extent.x` long running along +X from the origin, buckled down
##     `bend_degrees` at `bend_at` (0..1 of its length). Purely visual.
## Origin on the floor (Mound), at the slab's centre (Slab), or at the beam's root (Bent beam).

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	concrete = preload("res://materials/concrete_dark_worn.tres"), wall = preload("res://materials/vacuum_station_wall_worn.tres"),
	metal = preload("res://materials/metal_worn.tres"), rust = preload("res://materials/pipe_rust.tres"),
}

@export_enum("Mound", "Slab", "Bent beam") var kind := 0:
	set(v):
		kind = v
		_rebuild()
@export var extent := Vector3(6, 2.5, 6):
	set(v):
		extent = v
		_rebuild()
@export var seed_value := 1:
	set(v):
		seed_value = v
		_rebuild()
@export var bend_at := 0.55:
	set(v):
		bend_at = v
		_rebuild()
@export var bend_degrees := 35.0:
	set(v):
		bend_degrees = v
		_rebuild()
## Off = walk-through (purely visual).
@export var solid := true:
	set(v):
		solid = v
		_rebuild()

var pm: PropMesh
var _rng := RandomNumberGenerator.new()
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
	_rng.seed = seed_value * 7919 + kind
	var box := AABB()
	match kind:
		0: box = _mound()
		1: box = _slab()
		2: _beam()
	_mesh.mesh = pm.commit()
	var shape := BoxShape3D.new()
	shape.size = box.size if box.size != Vector3.ZERO else Vector3.ONE * 0.01
	_shape.shape = shape
	_shape.position = box.get_center()
	_shape.disabled = not solid or box.size == Vector3.ZERO


func _r(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


func _tumbled() -> Basis:
	return Basis.from_euler(Vector3(_r(-0.7, 0.7), _r(0, TAU), _r(-0.7, 0.7)))


## Chunks scattered over an ellipse, piled highest in the middle (a dome), big ones first.
func _mound() -> AABB:
	var count := clampi(int(extent.x * extent.z * 0.9), 12, 70)
	for i in count:
		var ang := _r(0, TAU)
		var r := sqrt(_r(0, 1))  # even spread over the area
		var lift := extent.y * (1.0 - r * r)
		var s := lerpf(1.8, 0.4, float(i) / count) * _r(0.7, 1.2)
		var p := Vector3(cos(ang) * r * extent.x * 0.5, _r(0.3, 1.0) * lift + s * 0.2, sin(ang) * r * extent.z * 0.5)
		var mat: Material = M.concrete if i % 3 != 0 else M.wall
		pm.box(mat, Vector3(s, s * _r(0.3, 0.7), s * _r(0.6, 1.1)), Transform3D(_tumbled(), p))
	for i in 5:  # bent bars
		var a := Vector3(_r(-0.3, 0.3) * extent.x, _r(0.3, 0.8) * extent.y, _r(-0.3, 0.3) * extent.z)
		var b := a + Vector3(_r(-1, 1), _r(0.4, 1.3), _r(-1, 1))
		pm.stick(M.rust, a, b, 0.05)
		pm.stick(M.rust, b, b + Vector3(_r(-0.6, 0.6), _r(-0.5, 0.1), _r(-0.6, 0.6)), 0.05)
	return AABB(Vector3(-extent.x * 0.32, 0, -extent.z * 0.32), Vector3(extent.x * 0.64, extent.y * 0.8, extent.z * 0.64))


## A broken roof slab: the slab, two ribs under it, the torn +X edge, bars out of it.
func _slab() -> AABB:
	pm.box(M.concrete, extent, Transform3D())
	for zf in [-0.28, 0.28]:
		pm.box(M.concrete, Vector3(extent.x * 0.92, extent.y * 1.4, 0.9), Transform3D(Basis(), Vector3(-extent.x * 0.04, -extent.y * 1.2, zf * extent.z)))
	var edge := extent.x * 0.5
	var n := maxi(int(extent.z / 1.4), 3)
	for i in n:  # jagged lip: chunks half-attached along the torn edge
		var z := lerpf(-extent.z * 0.45, extent.z * 0.45, (i + 0.5) / n)
		var s := _r(0.6, 1.3)
		pm.box(M.concrete, Vector3(s, extent.y * _r(0.6, 1.0), s * _r(0.8, 1.4)),
				Transform3D(Basis.from_euler(Vector3(_r(-0.3, 0.3), _r(-0.4, 0.4), _r(-0.3, 0.3))), Vector3(edge + _r(-0.2, 0.3), 0, z)))
	for i in n * 2:  # bars out of the break, bent down at the tips
		var z := lerpf(-extent.z * 0.48, extent.z * 0.48, (i + 0.5) / (n * 2))
		var a := Vector3(edge, _r(-0.2, 0.2) * extent.y, z)
		var b := a + Vector3(_r(0.4, 1.2), _r(-0.1, 0.2), _r(-0.2, 0.2))
		pm.stick(M.rust, a, b, 0.05)
		pm.stick(M.rust, b, b + Vector3(_r(0.1, 0.4), _r(-0.7, -0.2), _r(-0.2, 0.2)), 0.05)
	return AABB(-extent * 0.5, extent)


## An I-beam (two flanges and a web) in two runs with a buckle between them.
func _beam() -> void:
	var h := maxf(extent.y, 0.4)
	var w := maxf(extent.z, 0.3)
	var l1 := extent.x * bend_at
	var l2 := extent.x - l1
	var bend := Basis(Vector3.BACK, -deg_to_rad(bend_degrees))
	var knee := Vector3(l1, 0, 0)
	for run in [[Basis(), Vector3(l1 * 0.5, 0, 0), l1], [bend, knee + bend * Vector3(l2 * 0.5, 0, 0), l2]]:
		var b: Basis = run[0]
		var c: Vector3 = run[1]
		var l: float = run[2]
		pm.box(M.metal, Vector3(l, h * 0.12, w), Transform3D(b, c + b * Vector3(0, h * 0.44, 0)))
		pm.box(M.metal, Vector3(l, h * 0.12, w), Transform3D(b, c - b * Vector3(0, h * 0.44, 0)))
		pm.box(M.rust, Vector3(l, h * 0.8, w * 0.18), Transform3D(b, c))
	pm.box(M.rust, Vector3(h * 0.9, h * 0.9, w * 1.1), Transform3D(Basis(Vector3.BACK, -deg_to_rad(bend_degrees) * 0.5), knee))
