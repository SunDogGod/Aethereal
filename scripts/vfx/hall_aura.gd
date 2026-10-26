@tool
extends Node3D
## The Black Cube's aura while it accepts the sacrifices: a dark shimmering halo round the cube
## (materials/hall_aura.tres), motes of fire drawn up out of the bonfire and spiralling into it,
## and the cube's red light breathing with it. Put this node at the cube's centre.
##   pulse(strength)   one body taken: the halo swells, the light flares, a burst of motes.
##   surge(seconds)    a story beat (Isabella's sacrifice, Valentina's): the halo opens wide,
##                     the light floods the hall, motes stream in fast; then it settles.
##   set_active(on)    off: no halo, no motes, the light back to its own level.
## While the fire burns it also pulses by itself now and then (`auto_pulse_every`), weaker.

const HALO := preload("res://materials/hall_aura.tres")
const MOTE := preload("res://materials/hall_mote.tres")

## The bonfire the motes rise out of (any Node3D: its position is used).
@export var source: NodePath
## The cube's light (an OmniLight3D): it swells with each pulse.
@export var light: NodePath
## Width of the halo in metres, at rest.
@export var halo_size := 3.0
## Seconds between the aura's own small pulses while the fire burns (0 = never).
@export var auto_pulse_every := 7.0
## Motes drifting in per second at rest.
@export var mote_rate := 5.0
@export var active := true:
	set(value):
		active = value
		if is_node_ready():
			_apply_active()

const MOTES := 48

var _halos: Array[MeshInstance3D] = []
var _halo_mat: ShaderMaterial
var _multi := MultiMesh.new()
var _light: OmniLight3D
var _light_base := 0.0
var _pulse := 0.0
var _surge := 0.0
var _surge_hold := 0.0
var _spawn := 0.0
var _next_auto := 4.0
var _rng := RandomNumberGenerator.new()
# Per mote: progress (-1 = idle), speed, start point, bend (sideways), size.
var _t := PackedFloat32Array()
var _speed := PackedFloat32Array()
var _from: Array[Vector3] = []
var _bend: Array[Vector3] = []
var _size := PackedFloat32Array()


func _ready() -> void:
	if not _halos.is_empty():
		return
	_halo_mat = HALO.duplicate()
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	for i in 2:
		var q := MeshInstance3D.new()
		q.mesh = quad
		q.material_override = _halo_mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.extra_cull_margin = 4.0
		q.set_instance_shader_parameter("seed", 3.0 + i * 11.0)
		q.set_instance_shader_parameter("fade", 1.0 if i == 0 else 0.4)
		add_child(q, false, INTERNAL_MODE_FRONT)
		_halos.append(q)
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_colors = true
	_multi.mesh = quad
	_multi.instance_count = MOTES
	_multi.custom_aabb = AABB(Vector3(-6, -4, -6), Vector3(12, 10, 20))
	var mm := MultiMeshInstance3D.new()
	mm.multimesh = _multi
	mm.material_override = MOTE
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm, false, INTERNAL_MODE_FRONT)
	_t.resize(MOTES)
	_speed.resize(MOTES)
	_size.resize(MOTES)
	_from.resize(MOTES)
	_bend.resize(MOTES)
	for i in MOTES:
		_t[i] = -1.0
		_multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	_apply_halo()
	if Engine.is_editor_hint():
		return
	_rng.randomize()
	_light = get_node_or_null(light) as OmniLight3D
	if _light:
		_light_base = _light.light_energy
	_apply_active()


## One body taken. 1 = a full pulse; the aura's own rhythm uses about half.
func pulse(strength := 1.0) -> void:
	_pulse = maxf(_pulse, clampf(strength, 0.0, 1.5))
	_spawn += 8.0 * strength


## The big beat: wide open for `seconds`, then settling over about two seconds.
func surge(seconds := 3.0) -> void:
	_surge_hold = maxf(_surge_hold, seconds)
	_spawn += 20.0


func set_active(on: bool) -> void:
	active = on  # the setter applies it


func _apply_active() -> void:
	var on := active
	for q in _halos:
		q.visible = on
	if not on:
		_pulse = 0.0
		_surge = 0.0
		_surge_hold = 0.0
		for i in MOTES:
			_t[i] = -1.0
			_multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	if _light:
		_light.light_energy = _light_base


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not active:
		return
	_pulse = maxf(_pulse - delta * 0.8, 0.0)
	if _surge_hold > 0.0:
		_surge_hold -= delta
		_surge = minf(_surge + delta * 2.5, 1.0)
	else:
		_surge = maxf(_surge - delta * 0.5, 0.0)
	if auto_pulse_every > 0.0:
		_next_auto -= delta
		if _next_auto <= 0.0:
			_next_auto = auto_pulse_every * _rng.randf_range(0.7, 1.3)
			pulse(0.5)
	_apply_halo()
	if _light:
		var breathe := 0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.0021)
		_light.light_energy = _light_base * (breathe + 1.2 * _pulse + 2.2 * _surge)
	_motes(delta)


func _apply_halo() -> void:
	_halo_mat.set_shader_parameter("pulse", _pulse)
	_halo_mat.set_shader_parameter("surge", _surge)
	for i in _halos.size():
		var s := halo_size * (1.0 if i == 0 else 1.9) * (1.0 + 0.2 * _pulse + 1.0 * _surge)
		_halos[i].scale = Vector3(s, s, 1.0)


## Motes leave from just above the fire, rise in an arc and spiral into the cube.
func _motes(delta: float) -> void:
	var src := get_node_or_null(source) as Node3D
	if src == null:
		return
	_spawn += delta * (mote_rate + 10.0 * _pulse + 40.0 * _surge)
	var fire := to_local(src.global_position)
	for i in MOTES:
		if _t[i] < 0.0:
			if _spawn < 1.0:
				_multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
				continue
			_spawn -= 1.0
			var a := _rng.randf_range(0.0, TAU)
			_from[i] = fire + Vector3(cos(a) * _rng.randf_range(0.2, 0.9), _rng.randf_range(1.0, 2.6), sin(a) * _rng.randf_range(0.2, 0.9))
			_bend[i] = Vector3(_rng.randf_range(-2.5, 2.5), _rng.randf_range(1.5, 3.5), _rng.randf_range(-1.0, 1.0))
			_speed[i] = _rng.randf_range(0.22, 0.4)
			_size[i] = _rng.randf_range(0.05, 0.08)
			_t[i] = 0.0
		_t[i] += delta * _speed[i] * (1.0 + 1.5 * _surge + 0.5 * _pulse)
		var t: float = _t[i]
		if t >= 1.0:
			_t[i] = -1.0
			_multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		var p0: Vector3 = _from[i]
		var p1: Vector3 = (p0 * 0.5) + _bend[i]
		var p := p0.lerp(p1, t).lerp(p1.lerp(Vector3.ZERO, t), t)  # a curve that ends at the cube
		# The last stretch spirals in.
		var spin := t * 9.0 + i
		p += Vector3(cos(spin), 0.4 * sin(spin * 0.7), sin(spin)) * 0.35 * (1.0 - t) * t
		var s: float = _size[i] * (1.0 + 0.3 * _surge) * minf(1.0, (1.0 - t) * 4.0)
		_multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), p))
		var c := Color(1.0, 0.55, 0.2).lerp(Color(0.85, 0.1, 0.3), smoothstep(0.3, 0.95, t))
		c.a = minf(1.0, t * 8.0)
		_multi.set_instance_color(i, c)
