extends RefCounted
## The flicker of a lamp nobody has fixed, for the light kit (halo_lamp.gd, neon_sign.gd,
## wall_lamp_sodium.gd): the same three personalities as flicker_light.gd, but as a helper a
## prop can own, so the prop's light AND its glowing parts dim together.
## Make one with new(personality, seed), call level(delta) every frame: 1.0 is the lamp at full.
## Personalities: 0 none (always 1.0), 1 steady (a rare blink), 2 failing tube (buzz and
## stutter bursts), 3 dying bulb (sags, goes dark for a moment, flares back).

const NONE := 0
const STEADY := 1
const TUBE := 2
const BULB := 3

var personality := NONE
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _drop_left := 0.0      # seconds left in the current dropout
var _drop_level := 0.0     # how dark the dropout is (fraction of full)
var _stutters := 0         # dropouts still to come in a stutter burst
var _buzz_phase := 0.0
var _last_drop_end := -10.0


func _init(kind := NONE, seed := 0) -> void:
	personality = kind
	if seed == 0:
		_rng.randomize()
	else:
		_rng.seed = seed
	_buzz_phase = _rng.randf() * 100.0


## The lamp's brightness this frame, as a share of full (a little over 1 in a flare).
func level(delta: float) -> float:
	_time += delta
	match personality:
		STEADY:
			return _steady(delta)
		TUBE:
			return _tube(delta)
		BULB:
			return _bulb(delta)
	return 1.0


## Drives a light and a glowing material from one level (null for either is fine).
static func drive(light: Light3D, base_energy: float, mat: ShaderMaterial, base_glow: float, lvl: float) -> void:
	if light:
		light.light_energy = base_energy * lvl
	if mat:
		mat.set_shader_parameter("emission_energy", base_glow * clampf(lvl, 0.0, 1.2))


func _dropout(delta: float, chance: float, min_len: float, max_len: float, dark: float) -> float:
	if _drop_left > 0.0:
		_drop_left -= delta
		return _drop_level
	if _stutters > 0 or _rng.randf() < chance * delta:
		_stutters = maxi(_stutters - 1, 0)
		_drop_left = _rng.randf_range(min_len, max_len)
		_drop_level = dark * _rng.randf_range(0.5, 1.0)
		_last_drop_end = _time + _drop_left
		return _drop_level
	return 1.0


func _steady(delta: float) -> float:
	var d := _dropout(delta, 0.05, 0.04, 0.12, 0.3)
	if d < 1.0:
		return d
	return 1.0 + 0.02 * sin(_time * 2.3 + _buzz_phase)


func _tube(delta: float) -> float:
	var d := _dropout(delta, 0.25, 0.03, 0.09, 0.15)
	if d < 1.0:
		if _stutters == 0 and _rng.randf() < 0.3:
			_stutters = _rng.randi_range(2, 5)
		return d
	var buzz := 0.08 * sin(_time * 47.0 + _buzz_phase) * sin(_time * 13.0)
	return 0.95 + buzz


func _bulb(delta: float) -> float:
	var d := _dropout(delta, 0.12, 0.3, 1.1, 0.05)
	if d < 1.0:
		return d
	var sag := 0.6 + 0.4 * (0.5 + 0.5 * sin(_time * 0.9 + _buzz_phase))
	var since := maxf(_time - _last_drop_end, 0.0)
	var flare := 1.0 + 0.5 * clampf(1.0 - since * 2.0, 0.0, 1.0)
	return sag * flare
