@tool
extends Node3D
## Broken concrete, seeded. Kind Pile: a heap of chunks and leaning slabs at the foot of a wall,
## rebar poking out, a drift of grit spreading onto the floor. Kind Collapsed walkway: a slab
## that has torn off a wall and tilts down toward its broken far end, rebar bent out of the
## break, and (with Drop set) the heap that fell to the floor under it. Origin at the foot of the
## wall on the floor (Pile) or where the walkway met the wall at its floor level (Collapsed
## walkway); the wall is behind (-Z) and the rubble spreads out along +Z, Length wide along X.
## Solid gives the pile a low box and the walkway slab its tilted box, so he bumps instead of
## wading through. Change Random Seed for another heap.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const RUST := preload("res://materials/kitb_rust.tres")
const GRIT := preload("res://materials/kitb_grit.tres")

@export_enum("Pile", "Collapsed walkway") var kind := 0:
	set(value):
		kind = value
		_rebuild()
@export var random_seed := 1:
	set(value):
		random_seed = value
		_rebuild()
## Pile: how wide along the wall. Walkway: its width along the wall.
@export var length := 6.0:
	set(value):
		length = maxf(value, 1.0)
		_rebuild()
## Pile: how far it spreads from the wall. Walkway: how far the slab reaches out.
@export var depth := 2.2:
	set(value):
		depth = maxf(value, 0.5)
		_rebuild()
## Pile: how tall at the wall. Walkway: how far its broken end has sagged below the start.
@export var height := 1.3:
	set(value):
		height = maxf(value, 0.2)
		_rebuild()
@export_range(4, 60) var chunks := 24:
	set(value):
		chunks = value
		_rebuild()
## Walkway only: the floor is this far below; 0 = no heap under the break.
@export var drop := 0.0:
	set(value):
		drop = maxf(value, 0.0)
		_rebuild()
@export var rebar := true:
	set(value):
		rebar = value
		_rebuild()
@export var grit := true:
	set(value):
		grit = value
		_rebuild()
@export var material: Material = preload("res://materials/kitb_concrete.tres"):
	set(value):
		material = value
		_rebuild()
@export var solid := true:
	set(value):
		solid = value
		_rebuild()

var _mesh := MeshInstance3D.new()
var _body: StaticBody3D
var _boxes: Array = []  # [size, Transform3D] pairs for the collision
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _ready() -> void:
	_collide()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	_boxes.clear()
	if material == null:
		_mesh.mesh = null
		return
	var pm := PropMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	if kind == 0:
		_heap(pm, rng, Vector3.ZERO, length, depth, height, chunks)
		_boxes.append([Vector3(length, height * 0.6, depth * 0.6), _at(Vector3(0, height * 0.3, depth * 0.3))])
		_boxes.append([Vector3(length + 0.4, height * 0.25, depth * 0.95), _at(Vector3(0, height * 0.12, depth * 0.48))])
	else:
		_walkway(pm, rng)
	_mesh.mesh = pm.commit()
	if is_inside_tree():
		_collide()


func _at(p: Vector3) -> Transform3D:
	return Transform3D(Basis(), p)


## A heap against the wall at `foot`: chunks thicker near the wall, a few slabs leaning on it,
## rebar out of the top, a drift of grit on the floor round it.
func _heap(pm: PropMesh, rng: RandomNumberGenerator, foot: Vector3, w: float, d: float, h: float, n: int) -> void:
	for i in n:
		var z := d * pow(rng.randf(), 1.4)
		var top := h * pow(1.0 - z / d, 1.2)
		var size := Vector3(rng.randf_range(0.25, 0.9), rng.randf_range(0.18, 0.5), rng.randf_range(0.25, 0.8))
		var p := foot + Vector3(rng.randf_range(-w * 0.5 + 0.3, w * 0.5 - 0.3), rng.randf_range(0.0, maxf(top - size.y * 0.3, 0.0)) + size.y * 0.3, z + 0.2)
		var turn := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0, TAU), rng.randf_range(-0.5, 0.5)))
		pm.box(material, size, Transform3D(turn, p))
	for k in maxi(1, int(w / 2.5)):  # slabs leaning on the wall
		var x := foot.x + (k + 0.5) * w / maxi(1, int(w / 2.5)) - w * 0.5 + rng.randf_range(-0.4, 0.4)
		var lean := rng.randf_range(0.35, 0.7)
		var len := rng.randf_range(1.0, 1.8)
		var base := foot + Vector3(x, 0.1, sin(lean) * len)
		var tip := foot + Vector3(x, cos(lean) * len, 0.15)
		pm.box(material, Vector3(rng.randf_range(0.7, 1.3), base.distance_to(tip), 0.22), PropMesh.along(base, tip))
	if rebar:
		for k in maxi(2, int(w * 1.2)):
			var a := foot + Vector3(rng.randf_range(-w * 0.45, w * 0.45), rng.randf_range(0.2, h * 0.7), rng.randf_range(0.2, d * 0.6))
			var dir := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.3, 1.0), rng.randf_range(0.0, 0.9)).normalized()
			var b := a + dir * rng.randf_range(0.5, 1.2)
			pm.stick(RUST, a, b, 0.035)
			pm.stick(RUST, b, b + Vector3(dir.z * 0.4, -0.2, -dir.x * 0.4), 0.035)
	if grit:
		# A drift of grit: overlapping flat patches turned a little, each at its own height
		# (2 cm proud at most, so it is no step), so the edge is ragged, not a rectangle.
		for k in 6:
			var x := foot.x + rng.randf_range(-w * 0.4, w * 0.4)
			var reach := rng.randf_range(0.8, 2.0)
			var patch := Vector3(rng.randf_range(w * 0.3, w * 0.6), 0.03, reach)
			var p := foot + Vector3(x, -0.006 + 0.0025 * k, d * 0.5 + reach * 0.4)
			pm.box(GRIT, patch, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.35, 0.35)), p))


## The torn-off walkway: the slab from the wall tilting down `height` over `depth`, its rails
## hanging on, three staggered stubs and bent rebar at the break, a heap on the floor below.
func _walkway(pm: PropMesh, rng: RandomNumberGenerator) -> void:
	var w := length
	var start := Vector3(0, 0, 0)
	var end := Vector3(0, -height, depth)
	var xf := PropMesh.along(start, end)
	var slab := Vector3(w, depth + 0.3, 0.45)
	pm.box(material, slab, Transform3D(xf.basis, (start + end) * 0.5 - xf.basis.z * 0.22))
	_boxes.append([slab, Transform3D(xf.basis, (start + end) * 0.5 - xf.basis.z * 0.22)])
	pm.box(material, Vector3(w + 0.6, 0.8, 0.5), _at(Vector3(0, -0.2, 0.0)))  # the stump at the wall
	for s in [-1, 1]:
		var n := maxi(2, int(depth / 2.0))
		for k in n:
			var t := (k + 0.5) / n
			var p := start.lerp(end, t) + Vector3(s * (w * 0.5 - 0.1), 0, 0)
			var lean: float = 0.0 if k < n - 1 else rng.randf_range(0.3, 0.8) * s
			pm.stick(RUST, p, p + Vector3(sin(lean), cos(lean) * 1.1, 0), 0.07)
	for k in 3:
		var x := (k - 1) * w * 0.33 + rng.randf_range(-0.2, 0.2)
		var over := rng.randf_range(0.2, 0.9)
		pm.box(material, Vector3(w * 0.3, over * 2.0, 0.42), Transform3D(xf.basis, end + Vector3(x, 0, 0) - xf.basis.z * 0.22))
		var a := end + Vector3(x, 0, 0) + xf.basis.y * over
		var b := a + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.9, -0.4), rng.randf_range(0.3, 0.8))
		pm.stick(RUST, a, b, 0.04)
		pm.stick(RUST, b, b + Vector3(0.1, -0.5, 0.05), 0.04)
	if drop > 0.0:
		_heap(pm, rng, Vector3(0, -drop, depth + 0.4), w, 2.4, 1.0, chunks)
		_boxes.append([Vector3(w, 0.6, 1.6), _at(Vector3(0, -drop + 0.3, depth + 1.2))])


## One StaticBody3D (layer 1, like the Blocks) with a box per solid part.
func _collide() -> void:
	if _body:
		_body.queue_free()
		_body = null
	if not solid or _boxes.is_empty():
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
