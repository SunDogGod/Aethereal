extends OmniLight3D
## A light that is mostly steady but drops out and buzzes now and then, like a lamp nobody
## has fixed. Put it on an OmniLight3D. Only the light's energy changes (and, if you name
## one, the glow of the Block it lights, e.g. a sign plate): no new nodes.

## Steady: a good lamp with a rare blink.  Failing tube: a fluorescent that buzzes and
## stutters.  Dying bulb: sags slowly, goes dark for a moment, then flares back.
@export_enum("Steady", "Failing tube", "Dying bulb") var personality := 0
## Optional: a Block whose material glows (ShaderMaterial with emission_energy). It dims
## with the light. The material is duplicated so only this one Block changes.
@export var emissive_block: NodePath
## 0 = a different pattern every run; any other number repeats the same pattern.
@export var random_seed := 0

var _base_energy := 1.0
var _base_glow := 0.0
var _glow_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _drop_left := 0.0      # seconds left in the current dropout
var _drop_level := 0.0     # how dark the dropout is (fraction of base)
var _stutters := 0         # dropouts still to come in a stutter burst
var _buzz_phase := 0.0
var _last_drop_end := -10.0  # when the last dropout ended (for the bulb's flare)


func _ready() -> void:
	_base_energy = light_energy
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	_buzz_phase = _rng.randf() * 100.0
	if emissive_block != NodePath():
		var blk := get_node_or_null(emissive_block)
		if blk and blk.get("material") is ShaderMaterial:
			_glow_mat = blk.material.duplicate()
			if blk.has_method("set_runtime_material"):
				blk.set_runtime_material(_glow_mat)  # runtime only: the scene keeps the shared file
			else:
				blk.material = _glow_mat
			# Unset uniforms read back as null (the shader default is not reported), so default to 0.
			var glow: Variant = _glow_mat.get_shader_parameter("emission_energy")
			_base_glow = float(glow) if glow != null else 0.0


func _process(delta: float) -> void:
	_time += delta
	var level := 1.0
	match personality:
		0:
			level = _steady(delta)
		1:
			level = _tube(delta)
		2:
			level = _bulb(delta)
	light_energy = _base_energy * level
	if _glow_mat:
		_glow_mat.set_shader_parameter("emission_energy", _base_glow * clampf(level, 0.0, 1.2))


## Runs the current dropout, or maybe starts one. Returns the dropout's level, or 1.0.
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
	# Faint breathing, a blink about once every 20 s.
	var d := _dropout(delta, 0.05, 0.04, 0.12, 0.3)
	if d < 1.0:
		return d
	return 1.0 + 0.02 * sin(_time * 2.3 + _buzz_phase)


func _tube(delta: float) -> float:
	# A 50 Hz-ish buzz you half see, and stutter bursts of three to six quick drops.
	var d := _dropout(delta, 0.25, 0.03, 0.09, 0.15)
	if d < 1.0:
		if _stutters == 0 and _rng.randf() < 0.3:
			_stutters = _rng.randi_range(2, 5)
		return d
	var buzz := 0.08 * sin(_time * 47.0 + _buzz_phase) * sin(_time * 13.0)
	return 0.95 + buzz


func _bulb(delta: float) -> float:
	# Sags over a few seconds, goes almost dark for up to a second, then flares back.
	var d := _dropout(delta, 0.12, 0.3, 1.1, 0.05)
	if d < 1.0:
		return d
	var sag := 0.6 + 0.4 * (0.5 + 0.5 * sin(_time * 0.9 + _buzz_phase))
	var since := maxf(_time - _last_drop_end, 0.0)
	var flare := 1.0 + 0.5 * clampf(1.0 - since * 2.0, 0.0, 1.0)
	return sag * flare
