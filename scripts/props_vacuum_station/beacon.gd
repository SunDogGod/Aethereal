extends OmniLight3D
## A status light on its own clock: Pulse breathes slowly, Blink flashes once per period, Rare
## blink flashes once in a long while (the dead drone's eye). Only the light's energy changes,
## and, if you name one, the glow of a Block (its material is duplicated at runtime, like
## flicker_light.gd does), so the scene keeps the shared material file.

@export_enum("Pulse", "Blink", "Rare blink") var pattern := 0
## Seconds per cycle.
@export var period := 2.0
## Optional: a Block whose glow follows the light.
@export var emissive_block: NodePath
## Where in the cycle it starts (0..1), so neighbours are not in step.
@export_range(0.0, 1.0) var phase := 0.0
## The level it never goes below (0 = fully off between flashes).
@export_range(0.0, 1.0) var floor_level := 0.0

var _base_energy := 1.0
var _base_glow := 0.0
var _glow_mat: ShaderMaterial
var _t := 0.0


func _ready() -> void:
	_base_energy = light_energy
	_t = phase * period
	if emissive_block != NodePath():
		var blk := get_node_or_null(emissive_block)
		if blk and blk.get("material") is ShaderMaterial:
			_glow_mat = blk.material.duplicate()
			if blk.has_method("set_runtime_material"):
				blk.set_runtime_material(_glow_mat)
			else:
				blk.material = _glow_mat
			var glow: Variant = _glow_mat.get_shader_parameter("emission_energy")
			_base_glow = float(glow) if glow != null else 0.0


func _process(delta: float) -> void:
	_t = fmod(_t + delta, maxf(period, 0.05))
	var x := _t / maxf(period, 0.05)
	var level := 1.0
	match pattern:
		0:
			level = 0.5 + 0.5 * sin(x * TAU)
		1:
			level = 1.0 if x < 0.18 else 0.0
		2:
			level = 1.0 - clampf(absf(x - 0.5) * 12.0, 0.0, 1.0)  # a short soft flash mid-cycle
	level = lerpf(floor_level, 1.0, level)
	light_energy = _base_energy * level
	if _glow_mat:
		_glow_mat.set_shader_parameter("emission_energy", _base_glow * level)
