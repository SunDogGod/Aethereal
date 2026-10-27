@tool
extends Node3D
## Dust hanging in the air: tiny flecks drifting slowly inside a box `extent` metres big (centred
## on this node). They are lit like anything else, so in the dark they are almost nothing, and in
## the flashlight's beam or under a lamp they show. One MultiMesh, moved a little each frame,
## only while the camera is within `awake_range` (asleep, it costs nothing).

const DUST := preload("res://materials/vacuum_station_dust.tres")
const PropMesh := preload("res://scripts/props/prop_mesh.gd")

@export var extent := Vector3(8, 4, 8):
	set(value):
		extent = value
		_rebuild()
@export_range(1, 300) var count := 90:
	set(value):
		count = value
		_rebuild()
## Metres per second, roughly.
@export var drift := 0.08
@export var awake_range := 30.0
@export var seed_value := 0:
	set(value):
		seed_value = value
		_rebuild()

var _mm := MultiMeshInstance3D.new()
var _home := PackedVector3Array()  # each fleck's resting place
var _phase := PackedFloat32Array()
var _time := 0.0
var _wait := 0.0
var _buf := PackedFloat32Array()  # the MultiMesh buffer, rewritten as the flecks drift
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mm, false, INTERNAL_MODE_FRONT)
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rebuild()


func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + seed_value
	var pm := PropMesh.new()  # PropMesh reads the box once a game, not once per node
	pm.box(DUST, Vector3.ONE * 0.035, Transform3D())
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = pm.commit()
	multi.instance_count = count
	_home.resize(count)
	_phase.resize(count)
	for i in count:
		_home[i] = Vector3(rng.randf_range(-0.5, 0.5) * extent.x, rng.randf_range(-0.5, 0.5) * extent.y,
				rng.randf_range(-0.5, 0.5) * extent.z)
		_phase[i] = rng.randf() * TAU
	_buf = PackedFloat32Array()
	_buf.resize(count * 12)
	for i in count:  # no turn (a plain basis), at home
		var h := _home[i]
		var row := [1.0, 0.0, 0.0, h.x, 0.0, 1.0, 0.0, h.y, 0.0, 0.0, 1.0, h.z]
		for k in 12:
			_buf[i * 12 + k] = row[k]
	multi.buffer = _buf
	_mm.multimesh = multi
	_mm.custom_aabb = AABB(-extent * 0.5 - Vector3.ONE, extent + Vector3.ONE * 2.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _mm.multimesh == null or not is_visible_in_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(global_position) > awake_range + extent.length() * 0.5:
		return
	_time += delta
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 1.0 / 20.0  # 20 moves a second is plenty for dust this slow
	# All the flecks in one call: 12 floats each (the basis rows and the position).
	var r := drift * 6.0
	var buf := _buf
	for i in _home.size():
		var ph := _phase[i]
		var p := _home[i] + Vector3(sin(_time * 0.11 + ph) * r, sin(_time * 0.07 + ph * 1.7) * r * 0.6, cos(_time * 0.09 + ph * 0.6) * r)
		buf[i * 12 + 3] = p.x
		buf[i * 12 + 7] = p.y
		buf[i * 12 + 11] = p.z
	_buf = buf
	_mm.multimesh.buffer = buf
