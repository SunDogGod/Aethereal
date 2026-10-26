extends Node3D
## The raw aether still crackling round Aeneas after the burst (hall_burst.gd): little jagged
## arcs of light that jump off his body and re-strike many times a second, motes streaming up
## round him, and a cold flickering light. It rides along as his child and lasts while his
## eruption does (his Combat's `erupting`), at least `seconds`, then crackles out over a second.
## on(who) starts it (or keeps the one he has). Made in code; nothing is saved.

const NAME := "HallCrackle"
const ARCS := 4
const PER_ARC := 7
const RISING := 18

var seconds := 5.0
var _t := 0.0
var _out := 0.0         # counts up once it is ending
var _restrike := 0.0
var _multi := MultiMesh.new()
var _light := OmniLight3D.new()
var _rng := RandomNumberGenerator.new()


static func on(who: Node3D, seconds := 5.0) -> Node3D:
	if who == null:
		return null
	var c: Node3D = who.get_node_or_null(NAME)
	if c == null:
		c = load("res://scripts/vfx/hall_crackle.gd").new()
		c.name = NAME
		c.set("seconds", seconds)
		who.add_child(c)
	return c


func _ready() -> void:
	_rng.randomize()
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_colors = true
	_multi.mesh = quad
	_multi.instance_count = ARCS * PER_ARC + RISING
	_multi.custom_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 5, 6))
	var mm := MultiMeshInstance3D.new()
	mm.multimesh = _multi
	mm.material_override = HallStream.mote_material()
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm)
	_light.light_color = Color(0.55, 0.85, 1.0)
	_light.omni_range = 5.0
	_light.position = Vector3(0, 1.1, 0)
	add_child(_light)
	_strike()


func _process(delta: float) -> void:
	_t += delta
	var combat := get_parent().get_node_or_null("Combat")
	var going: bool = _t < seconds or (combat != null and bool(combat.get("erupting")))
	if not going:
		_out += delta
		if _out >= 1.0:
			queue_free()
			return
	var level := 1.0 - _out
	_restrike -= delta
	if _restrike <= 0.0:
		_restrike = _rng.randf_range(0.05, 0.11)
		_strike(level)
	_light.light_energy = (1.4 + _rng.randf_range(0.0, 1.6)) * level
	for i in RISING:
		var k := fmod(_t * (0.7 + 0.4 * fmod(i * 0.37, 1.0)) + i * 0.618, 1.0)
		var a := i * 2.39 + k * TAU
		var r := 0.42 + 0.25 * k
		var s := 0.06 * sin(k * PI) * level
		_multi.set_instance_transform(ARCS * PER_ARC + i, Transform3D(Basis.from_scale(Vector3(s, s, s)), Vector3(cos(a) * r, 0.1 + k * 2.3, sin(a) * r)))
		_multi.set_instance_color(ARCS * PER_ARC + i, Color(0.6, 0.9, 1.0) if i % 3 else Color(0.7, 0.5, 1.0))


## New arcs: each starts on his body and jags outward a little way, then they hold until the next.
func _strike(level := 1.0) -> void:
	for a in ARCS:
		var h := _rng.randf_range(0.3, 1.7)
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.4, 0.6), _rng.randf_range(-1, 1)).normalized()
		var p := Vector3(0, h, 0) + Vector3(dir.x, 0, dir.z).normalized() * 0.25
		for j in PER_ARC:
			p += dir * 0.11 + Vector3(_rng.randf_range(-0.07, 0.07), _rng.randf_range(-0.07, 0.07), _rng.randf_range(-0.07, 0.07))
			var s := 0.07 * (1.0 - float(j) / PER_ARC * 0.6) * level
			_multi.set_instance_transform(a * PER_ARC + j, Transform3D(Basis.from_scale(Vector3(s, s, s)), p))
			_multi.set_instance_color(a * PER_ARC + j, Color(0.85, 0.97, 1.0) if j < 3 else Color(0.5, 0.8, 1.0))
