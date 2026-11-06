@tool
extends Node3D
## A shaft of light falling from a skylight or a lamp: a soft see-through cone (its own shader,
## shaders/kit_light_shaft.gdshader) that fades along its length and at its edge, with a few
## dust motes drifting slowly down inside it. Put the node where the light ENTERS (the skylight,
## the lamp); the shaft hangs straight down from there, `length` metres. Tilt the node to slant
## it. Purely visual: no light of its own (pair it with an OmniLight or a SpotLight if the floor
## should be lit) and no collision. For Black Sand's skylights and the hall.

const SHAFT_MATERIAL := preload("res://materials/kit_light_shaft.tres")
const GLOW_MATERIAL := preload("res://materials/kit_glow.tres")
const SIDES := 12
const RINGS := 6

@export var length := 8.0:
	set(value):
		length = maxf(value, 0.1)
		_rebuild()
@export var radius_top := 0.8:
	set(value):
		radius_top = maxf(value, 0.05)
		_rebuild()
@export var radius_bottom := 2.4:
	set(value):
		radius_bottom = maxf(value, 0.05)
		_rebuild()
@export var color := Color(0.75, 0.7, 0.95):
	set(value):
		color = value
		_rebuild()
## How bright the shaft is (it adds onto what is behind it; 0.1 is faint, 0.6 is a searchlight).
@export_range(0.0, 2.0) var strength := 0.25:
	set(value):
		strength = value
		_rebuild()
@export_range(0, 60) var mote_count := 14:
	set(value):
		mote_count = value
		_rebuild()
@export var mote_size := 0.05:
	set(value):
		mote_size = maxf(value, 0.005)
		_rebuild()
## Metres per second the motes sink (they also sway sideways).
@export var mote_speed := 0.12

var _mesh := MeshInstance3D.new()
var _motes := MultiMeshInstance3D.new()
var _multi := MultiMesh.new()
var _mote_data: Array[Vector4] = []  # x = angle, y = radius share 0..1, z = how far down 0..1, w = phase
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	add_child(_motes, false, INTERNAL_MODE_FRONT)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_custom_data = true
	_motes.multimesh = _multi
	_rebuild()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	_mesh.mesh = _cone()
	_mesh.material_override = SHAFT_MATERIAL
	_mesh.set_instance_shader_parameter("tint", Vector3(color.r, color.g, color.b))
	_mesh.set_instance_shader_parameter("strength", strength)
	_mesh.set_instance_shader_parameter("seed", float(hash(name) % 97))
	_mesh.custom_aabb = _bounds()
	_build_motes()


## The cone: `RINGS` bands from the top (v = 0) to the foot (v = 1). The shader draws both sides.
func _cone() -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var index := PackedInt32Array()
	var slope := (radius_bottom - radius_top) / length
	for r in RINGS + 1:
		var t := float(r) / RINGS
		var rad := lerpf(radius_top, radius_bottom, t)
		for s in SIDES + 1:
			var ang := TAU * s / SIDES
			var dir := Vector3(cos(ang), 0, sin(ang))
			verts.append(dir * rad + Vector3.DOWN * length * t)
			norms.append((dir + Vector3.UP * slope).normalized())
			uvs.append(Vector2(float(s) / SIDES, t))
	for r in RINGS:
		for s in SIDES:
			var a := r * (SIDES + 1) + s
			var b := a + SIDES + 1
			index.append_array([a, a + 1, b, a + 1, b + 1, b])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _bounds() -> AABB:
	var r := maxf(radius_top, radius_bottom)
	return AABB(Vector3(-r, -length, -r), Vector3(r * 2.0, length, r * 2.0))


func _build_motes() -> void:
	_rng.seed = hash(name) + 11
	var ball := SphereMesh.new()
	ball.radius = mote_size
	ball.height = mote_size * 2.0
	ball.radial_segments = 4
	ball.rings = 2
	_multi.instance_count = 0
	_multi.mesh = ball
	_multi.instance_count = mote_count
	_mote_data.clear()
	for i in mote_count:
		_mote_data.append(Vector4(_rng.randf() * TAU, _rng.randf(), _rng.randf(), _rng.randf() * TAU))
	_motes.material_override = GLOW_MATERIAL
	_motes.set_instance_shader_parameter("tint", Vector3(color.r, color.g, color.b))
	_motes.set_instance_shader_parameter("strength", 0.8 + strength)
	_motes.custom_aabb = _bounds()
	_place_motes()


func _place_motes() -> void:
	for i in _mote_data.size():
		var m := _mote_data[i]
		var rad := lerpf(radius_top, radius_bottom, m.z) * (0.15 + 0.8 * m.y)
		var sway := Vector2(sin(_time * 0.37 + m.w), cos(_time * 0.29 + m.w * 1.7)) * 0.15
		var p := Vector3(cos(m.x) * rad + sway.x, -length * m.z, sin(m.x) * rad + sway.y)
		# Brighter near the top (where the light is), twinkling slowly, gone at the foot.
		var twinkle := 0.55 + 0.45 * sin(_time * 1.3 + m.w * 3.0)
		var fade := (1.0 - m.z) * twinkle * smoothstep(0.0, 0.08, m.z)
		_multi.set_instance_transform(i, Transform3D(Basis(), p))
		_multi.set_instance_custom_data(i, Color(0, 0, 0, fade))


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _mote_data.is_empty():
		return
	_time += delta
	for i in _mote_data.size():
		var m := _mote_data[i]
		m.z += delta * mote_speed * (0.6 + 0.6 * fmod(m.w, 1.0)) / length
		m.x += delta * 0.15
		if m.z > 1.0:
			m.z -= 1.0
			m.y = _rng.randf()
		_mote_data[i] = m
	_place_motes()
