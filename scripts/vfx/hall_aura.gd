@tool
extends Node3D
## The Black Cube's aura: a dark shimmering halo round the cube (materials/hall_aura.tres) and
## the cube's red light breathing with it. Put this node at the cube's centre.
## The cube takes sacrifices and gives their power on (hall_stream.gd draws the streams):
##   take(from, strength, give_to)  soul light rises from `from` (the fire, Isabella) into the cube
##                     and the cube flares; with `give_to`, a moment later it sends the power on
##                     into him (give), then settles back to neutral, waiting for the next one.
##   give(to, strength) the cube sends what it holds into someone, who glows with it (hall_glow.gd).
## A body on the fire is worth 1: a modest stream, a short flare, the captain glows briefly.
## Isabella's soul is GREAT: the cube blazes, the whole hall lights up, the fire bends toward the
## cube, the drone swells, and it waits to give it to Aeneas ([call CubeAura give Player 3]) as a
## long beam.
##   pulse(strength) / surge(seconds)  the halo swells / opens wide ([show CubePulse] / CubeSurge).
##   set_active(on)    off: no halo, the light back to its own level.
## At rest it only breathes: a small swell now and then (`auto_pulse_every`).

const HALO := preload("res://materials/hall_aura.tres")
const HallGlow := preload("res://scripts/vfx/hall_glow.gd")
const GREAT := 3.0        ## Isabella's sacrifice
const FIRE_GLOW := Color(1.0, 0.55, 0.2)
const CRIMSON := Color(0.95, 0.12, 0.22)
const SOUL := Color(0.85, 0.75, 1.0)
const AETHER := Color(0.55, 0.9, 1.0)

## The bonfire (hall_bonfire.gd): a body's soul rises from it, and it bends toward a great one.
@export var source: NodePath
## The cube's light (an OmniLight3D): it swells with each pulse.
@export var light: NodePath
## Who the cube gives the burnt bodies' power to (the captain).
@export var receiver: NodePath
## The cube's hum (an AudioStreamPlayer3D): it swells with a great sacrifice.
@export var drone: NodePath
## Width of the halo in metres, at rest.
@export var halo_size := 3.0
## Seconds between the aura's own small swells while it waits (0 = never).
@export var auto_pulse_every := 7.0
@export var active := true:
	set(value):
		active = value
		if is_node_ready():
			_apply_active()

var _halos: Array[MeshInstance3D] = []
var _halo_mat: ShaderMaterial
var _light: OmniLight3D
var _light_base := 0.0
var _hall_light: OmniLight3D   # the whole hall lit by a great sacrifice
var _pulse := 0.0
var _surge := 0.0
var _surge_hold := 0.0
var _blaze := 0.0              # 0..1: a great sacrifice held in the cube
var _blaze_hold := 0.0
var _next_auto := 4.0
var _rng := RandomNumberGenerator.new()


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
	_apply_halo()
	if Engine.is_editor_hint():
		return
	_rng.randomize()
	_light = get_node_or_null(light) as OmniLight3D
	if _light:
		_light_base = _light.light_energy
	_hall_light = OmniLight3D.new()
	_hall_light.light_color = SOUL
	_hall_light.omni_range = 30.0
	_hall_light.omni_attenuation = 0.6
	_hall_light.light_energy = 0.0
	_hall_light.position = Vector3(0, 2.0, 4.0)
	add_child(_hall_light, false, INTERNAL_MODE_FRONT)
	_apply_active()


## A sacrifice: its soul rises from `from` into the cube. 1 = a body; GREAT = Isabella.
func take(from: Node3D, strength := 1.0, give_to: Node3D = null) -> void:
	if not active or from == null:
		return
	var great := strength >= GREAT
	var lift := Vector3(0, 1.4, 0) if from.has_method("throw_in") else Vector3(0, 0.9, 0)
	var stream := HallStream.make(get_parent(), from, self, lift, Vector3.ZERO, {
		travel = 2.2 if great else 1.4, emit_time = 2.2 if great else 1.1, rate = 100.0 if great else 90.0,
		size = 0.2 if great else 0.15, spin = 0.6 if great else 0.32, arc = 2.0 if great else 1.6,
		color_from = SOUL if great else FIRE_GLOW, color_to = Color.WHITE if great else CRIMSON})
	if great:
		var fire := get_node_or_null(source)
		if fire and fire.has_method("bend"):
			fire.bend(global_position, 6.0)
		_swell_drone(7.0)
	stream.arrived.connect(func() -> void:
		pulse(minf(strength, 1.5))
		if great:
			_blaze_hold = 12.0  # until give() sends it on (or it gives up waiting)
			surge(3.0)
		elif give_to:
			get_tree().create_timer(0.45, false).timeout.connect(give.bind(give_to, strength)))


## The cube sends what it holds into `to`, who glows with it.
func give(to: Node3D, strength := 1.0) -> void:
	if not active or to == null or not is_instance_valid(to) or not to.is_visible_in_tree():
		return
	var great := strength >= GREAT
	var stream := HallStream.make(get_parent(), self, to, Vector3.ZERO, Vector3(0, 1.1, 0), {
		travel = 1.3 if great else 1.0, emit_time = 2.6 if great else 0.9, rate = 100.0 if great else 50.0,
		size = 0.18 if great else 0.14, spin = 0.4 if great else 0.25, arc = 0.5 if great else 0.9,
		beam = 0.16 if great else 0.0,
		color_from = Color.WHITE if great else CRIMSON, color_to = AETHER if great else CRIMSON})
	pulse(0.6)
	stream.arrived.connect(func() -> void:
		HallGlow.on(to, AETHER if great else CRIMSON, strength, 7.0 if great else 1.6)
		if great:
			_blaze_hold = 2.4)  # the cube lets go as the beam does


## The receiver of the burnt bodies' power (the captain), if he's still there to take it.
func receiver_node() -> Node3D:
	return get_node_or_null(receiver) as Node3D


## One body taken. 1 = a full pulse; the aura's own rhythm uses less.
func pulse(strength := 1.0) -> void:
	_pulse = maxf(_pulse, clampf(strength, 0.0, 1.5))


## The halo opens wide for `seconds`, then settles over about two seconds.
func surge(seconds := 3.0) -> void:
	_surge_hold = maxf(_surge_hold, seconds)


func set_active(on: bool) -> void:
	active = on  # the setter applies it


func _apply_active() -> void:
	for q in _halos:
		q.visible = active
	if not active:
		_pulse = 0.0
		_surge = 0.0
		_surge_hold = 0.0
		_blaze = 0.0
		_blaze_hold = 0.0
	if _light:
		_light.light_energy = _light_base
	if _hall_light:
		_hall_light.light_energy = 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not active:
		return
	_pulse = maxf(_pulse - delta * 0.8, 0.0)
	if _surge_hold > 0.0:
		_surge_hold -= delta
		_surge = minf(_surge + delta * 2.5, 1.0)
	else:
		_surge = maxf(_surge - delta * 0.5, 0.0)
	if _blaze_hold > 0.0:
		_blaze_hold -= delta
		_blaze = minf(_blaze + delta * 1.5, 1.0)
		_surge_hold = maxf(_surge_hold, 0.2)
	else:
		_blaze = maxf(_blaze - delta * 0.6, 0.0)
	if auto_pulse_every > 0.0:
		_next_auto -= delta
		if _next_auto <= 0.0:
			_next_auto = auto_pulse_every * _rng.randf_range(0.7, 1.3)
			pulse(0.4)
	_apply_halo()
	if _light:
		var breathe := 0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.0021)
		_light.light_energy = _light_base * (breathe + 1.2 * _pulse + 2.2 * _surge + 3.0 * _blaze)
	if _hall_light:
		var flicker := 0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.013)
		_hall_light.light_energy = 4.5 * _blaze * flicker


func _apply_halo() -> void:
	_halo_mat.set_shader_parameter("pulse", _pulse)
	_halo_mat.set_shader_parameter("surge", minf(_surge + _blaze * 0.5, 1.5))
	for i in _halos.size():
		var s := halo_size * (1.0 if i == 0 else 1.9) * (1.0 + 0.2 * _pulse + 1.0 * _surge + 0.8 * _blaze)
		_halos[i].scale = Vector3(s, s, 1.0)


## A great sacrifice: the cube's hum rises and climbs in pitch, then sinks back.
func _swell_drone(seconds: float) -> void:
	var hum := get_node_or_null(drone)
	if not (hum is AudioStreamPlayer3D):
		return
	var vol: float = hum.volume_db
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(hum, "volume_db", vol + 9.0, 2.0)
	tw.tween_property(hum, "pitch_scale", 1.35, 2.5)
	tw.chain().tween_interval(seconds - 4.0)
	tw.chain().set_parallel(true)
	tw.tween_property(hum, "volume_db", vol, 2.0)
	tw.tween_property(hum, "pitch_scale", 1.0, 2.0)
