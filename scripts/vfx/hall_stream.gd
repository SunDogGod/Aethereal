class_name HallStream
extends Node3D
## A stream of soul light from one place to another, for the Black Cube (hall_aura.gd): motes
## leave the giver for `emit_time` seconds, each flies an arc to the receiver in `travel`
## seconds, spiralling round it, coloured from `color_from` to `color_to`. With `beam` > 0 a beam
## of light (shaders/hall_beam.gdshader) that wide also reaches out ahead of the first mote and
## lets go behind the last. `arrived` fires when the first mote gets there (the next beat starts
## then); the stream frees itself when the last is in. Ends follow nodes as they move.
## Made in code by make(); nothing is saved in a scene.

signal arrived

const FLAME := preload("res://shaders/hall_flame.gdshader")
const BEAM := preload("res://shaders/hall_beam.gdshader")
const MOST := 280

var travel := 1.2
var emit_time := 0.9
var rate := 40.0
var size := 0.09
var spin := 0.35            ## how wide the motes spiral round the arc (metres)
var arc := 1.4              ## how high the arc bows above the straight line (metres)
var beam := 0.0             ## > 0: a beam this wide (metres) along the stream
var color_from := Color.WHITE
var color_to := Color.WHITE

var _from: Variant          # a Node3D (followed) or a Vector3
var _to: Variant
var _from_lift := Vector3.ZERO
var _to_lift := Vector3.ZERO
var _ends := [Vector3.ZERO, Vector3.ZERO]  # where each end was last seen
var _t := 0.0
var _count := 0
var _sent := false
var _multi := MultiMesh.new()
var _beam_mesh: MeshInstance3D
var _beam_mat: ShaderMaterial
static var _mote_mat: ShaderMaterial


## A stream under `parent` from `from` to `to` (each a Node3D or a Vector3; `*_lift` is added
## to a node's position: its chest, the cube's centre). `look` sets any of the vars above
## (travel, rate, beam, color_from...) before it starts.
static func make(parent: Node, from: Variant, to: Variant, from_lift := Vector3.ZERO, to_lift := Vector3.ZERO,
		look := {}) -> HallStream:
	var s := HallStream.new()
	for k: String in look:
		s.set(k, look[k])
	s.set("_from", from)
	s.set("_to", to)
	s.set("_from_lift", from_lift)
	s.set("_to_lift", to_lift)
	parent.add_child(s)
	return s


## The motes' look: round, chunky, white-hot in the middle; each mote's colour tints it.
static func mote_material() -> ShaderMaterial:
	if _mote_mat == null:
		_mote_mat = ShaderMaterial.new()
		_mote_mat.shader = FLAME
		_mote_mat.render_priority = 2
		_mote_mat.set_shader_parameter("shape", 1)
		_mote_mat.set_shader_parameter("pixels", Vector2(6, 6))
		_mote_mat.set_shader_parameter("core_color", Color(1, 1, 1))
		_mote_mat.set_shader_parameter("mid_color", Color(0.85, 0.85, 0.85))
		_mote_mat.set_shader_parameter("edge_color", Color(0.5, 0.5, 0.5))
		_mote_mat.set_shader_parameter("brightness", 1.3)
	return _mote_mat


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_colors = true
	_multi.mesh = quad
	_count = clampi(int(ceil(rate * emit_time)), 1, MOST)
	_multi.instance_count = _count
	var start := _end(0)
	_end(1)
	_multi.custom_aabb = AABB(start - Vector3(60, 30, 60), Vector3(120, 60, 120))
	for i in _count:
		_multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), start))
	var mm := MultiMeshInstance3D.new()
	mm.multimesh = _multi
	mm.material_override = mote_material()
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm)
	if beam > 0.0:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.5
		cyl.height = 1.0
		cyl.radial_segments = 8
		cyl.rings = 1
		cyl.cap_top = false
		cyl.cap_bottom = false
		_beam_mat = ShaderMaterial.new()
		_beam_mat.shader = BEAM
		_beam_mat.render_priority = 2
		_beam_mat.set_shader_parameter("core_color", color_to.lerp(Color.WHITE, 0.6))
		_beam_mat.set_shader_parameter("edge_color", color_from)
		_beam_mat.set_shader_parameter("head", 0.0)
		_beam_mesh = MeshInstance3D.new()
		_beam_mesh.mesh = cyl
		_beam_mesh.material_override = _beam_mat
		_beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beam_mesh.extra_cull_margin = 8.0
		add_child(_beam_mesh)


func _process(delta: float) -> void:
	_t += delta
	var a := _end(0)
	var b := _end(1)
	var mid := (a + b) * 0.5 + Vector3.UP * arc
	var along := (b - a).normalized() if a.distance_to(b) > 0.01 else Vector3.UP
	var side := along.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var up := side.cross(along).normalized()
	for i in _count:
		var k := (_t - float(i) / rate) / travel
		if k < 0.0 or k > 1.0:
			_multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), a))
			continue
		var e := k * k * (3.0 - 2.0 * k)
		var p := a.lerp(mid, e).lerp(mid.lerp(b, e), e)
		var turn := k * TAU * 1.6 + i * 2.39
		p += (side * cos(turn) + up * sin(turn)) * spin * sin(k * PI) * (0.6 + 0.4 * fmod(i * 0.618, 1.0))
		var s := size * (0.55 + 0.6 * sin(k * PI)) * (0.8 + 0.4 * fmod(i * 0.37, 1.0))
		_multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), p))
		var c := color_from.lerp(color_to, k)
		c.a = minf(1.0, k * 6.0)
		_multi.set_instance_color(i, c)
	if not _sent and _t >= travel:
		_sent = true
		arrived.emit()
	var last := (float(_count - 1) / rate) + travel
	if _beam_mesh:
		_lay_beam(a, b, last)
	if _t > last + 0.5:
		queue_free()


## The beam along the chord: it reaches out with the first mote and lets go after the last.
func _lay_beam(a: Vector3, b: Vector3, last: float) -> void:
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var y := (b - a) / length
	var x := y.cross(Vector3.UP)
	x = x.normalized() if x.length() > 0.01 else Vector3.RIGHT
	var z := x.cross(y)
	_beam_mesh.global_transform = Transform3D(Basis(x * beam, y * length, z * beam), (a + b) * 0.5)
	_beam_mat.set_shader_parameter("head", clampf(_t / travel, 0.0, 1.0))
	_beam_mat.set_shader_parameter("tail", clampf((_t - (last - travel)) / travel, 0.0, 1.0))
	_beam_mat.set_shader_parameter("fade", clampf((last + 0.4 - _t) / 0.6, 0.0, 1.0) * minf(1.0, _t * 4.0))


## Where an end is now (0 = the giver, 1 = the receiver). A node that is gone, or out of the
## tree, leaves the end where it last was.
func _end(which: int) -> Vector3:
	var p: Variant = _from if which == 0 else _to
	var lift: Vector3 = _from_lift if which == 0 else _to_lift
	if p is Vector3:
		return p + lift
	if is_instance_valid(p) and (p as Node3D).is_inside_tree():
		_ends[which] = (p as Node3D).global_position
	return _ends[which] + lift
