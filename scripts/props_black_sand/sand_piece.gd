@tool
extends Node3D
## What sand_relic.gd and sand_hulk.gd share: big old things of the megastructure the dunes are
## swallowing. Origin on the sand; every kind reaches a little below it, so tilt and sink the
## node itself to bury it. Drift heaps sand against its foot (the dunes' own world-mapped sand,
## so it melts into them). With Solid on, the big parts get box collision, built when the game
## runs (never saved in the scene). Identical pieces share one mesh while the game runs.
## Not used on its own: a script that extends it adds `kind` and `_build()`.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	hull = preload("res://materials/black_sand_hull_worn.tres"), rust = preload("res://materials/black_sand_hull_rust_worn.tres"),
	metal = preload("res://materials/metal_worn.tres"), hole = preload("res://materials/black_sand_void.tres"),
	sand = preload("res://materials/black_sand_dunes.tres"), pipe = preload("res://materials/pipe_rust.tres"),
	beacon = preload("res://materials/black_sand_beacon.tres"), dead = preload("res://materials/ceiling_panel_off.tres"),
	yellow = preload("res://materials/paint_yellow.tres"), rubber = preload("res://materials/rubber.tres"),
	concrete = preload("res://materials/concrete_dark_worn.tres"), grating = preload("res://materials/grating.tres"),
}

## Changes breaks, bends and small details, so two of the same Kind don't look identical.
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()
## Metres: what it means depends on the Kind (see its notes).
@export var length := 8.0:
	set(value):
		length = value
		_rebuild()
## How much sand is heaped against its foot (0 = none, 1 = a drift, 2 = a big one).
@export_range(0.0, 2.0) var drift := 1.0:
	set(value):
		drift = value
		_rebuild()
## Box collision for the big parts (anything the player could walk into).
@export var solid := true:
	set(value):
		solid = value
		_rebuild()
## Not drawn beyond this many metres (0 = always drawn).
@export var draw_distance := 0.0:
	set(value):
		draw_distance = value
		_mesh.visibility_range_end = maxf(value, 0.0)

static var _cache := {}  # settings -> [ArrayMesh, boxes]
var _mesh := MeshInstance3D.new()
var _pm: PropMesh
var _boxes: Array = []  # [size, Transform3D] pairs for the collision
var _body: StaticBody3D
var _r := RandomNumberGenerator.new()  # seeded from Kind and Variant before each build
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _ready() -> void:
	_apply_collision()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	var key := [get_script().resource_path, get("kind"), variant, length, drift]
	var shared: Array = [] if Engine.is_editor_hint() else _cache.get(key, [])
	if shared.is_empty():
		_pm = PropMesh.new()
		_boxes = []
		_r.seed = 500 + int(get("kind")) * 37 + variant
		_build()
		_drift()
		shared = [_pm.commit(), _boxes]
		if not Engine.is_editor_hint():
			_cache[key] = shared
	_mesh.mesh = shared[0]
	_boxes = shared[1]
	_mesh.visibility_range_end = maxf(draw_distance, 0.0)
	if is_inside_tree():
		_apply_collision()


## The shapes of this Kind (the scripts that extend this one fill it in).
func _build() -> void:
	pass


## How far (in X) the drift spreads either side of the origin.
func _drift_spread() -> float:
	return 2.0


## One StaticBody3D (layer 1, like the Blocks) with a box per solid part.
func _apply_collision() -> void:
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


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


func _yaw(a: float, x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, a), Vector3(x, y, z))


## A drum standing at p (on the sand), r round, h tall, two hoops.
func _drum(p: Vector3, r: float, h: float, mat: Material) -> void:
	_pm.cyl(mat, r, r, h, _at(p.x, p.y + h * 0.5 - 0.05, p.z), 10)
	for y in [0.2, h - 0.2]:
		_pm.cyl(M.metal, r + 0.02, r + 0.02, 0.05, _at(p.x, p.y + y, p.z), 10)


func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(get("kind")) * 1000 + variant * 31 + salt
	return r


## A sphere squashed to `half` (half-sizes along x, y, z), placed at xf. Built from ONE unit sphere per
## sides/rings, stretched: every new sphere size would otherwise be read from the graphics card again.
func _ball(mat: Material, half: Vector3, xf: Transform3D, sides := 8, rings := 4) -> void:
	_pm.sphere(mat, 1.0, 2.0, Transform3D(xf.basis * Basis.from_scale(half), xf.origin), sides, rings)


## Sand heaped against the foot: low squashed mounds of the dune material around the origin.
func _drift() -> void:
	if drift <= 0.01:
		return
	var r := _rng(9)
	var spread := _drift_spread()
	if spread <= 0.0:
		return
	for i in 3:
		var rad := r.randf_range(1.6, 2.6) * drift
		var p := Vector3(r.randf_range(-spread, spread), -rad * 0.35, r.randf_range(-1.2, 1.6))
		_ball(M.sand, Vector3(rad * 1.4, rad * 0.55, rad * 1.1), Transform3D(Basis(), p), 10, 5)
