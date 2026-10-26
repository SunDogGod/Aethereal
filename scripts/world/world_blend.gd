class_name WorldBlend
extends RefCounted
## Mixes the zones' own environments (fog, light, background) into the one the world shows.
## Inside one zone the world simply shows that zone's own environment (so a zone that changes its
## own while playing, like Black Sand's dawn, shows the change at no cost). On a link, the
## strongest zone's settings are copied whole (sky or flat colour, which kind of fog) and the
## numbers and colours below are mixed by weight, so walking a link fades one place's air into
## the next.

const MIX := [
	"background_color", "background_energy_multiplier",
	"ambient_light_color", "ambient_light_energy", "ambient_light_sky_contribution",
	"fog_light_color", "fog_light_energy", "fog_sun_scatter", "fog_density",
	"fog_height", "fog_height_density", "fog_aerial_perspective", "fog_sky_affect",
	"fog_depth_curve", "fog_depth_begin", "fog_depth_end",
	"volumetric_fog_density", "volumetric_fog_albedo", "volumetric_fog_emission",
	"volumetric_fog_emission_energy", "volumetric_fog_length", "volumetric_fog_anisotropy",
	"tonemap_exposure", "glow_intensity",
]

var _base: Environment  # on a link: the zone whose copy is on screen (null inside one zone)


## profiles: the zones' environments; weights: how much of each (they add up to 1).
func apply(target: WorldEnvironment, profiles: Array[Environment], weights: Array[float]) -> void:
	var strongest := -1
	for i in profiles.size():
		if profiles[i] and (strongest < 0 or weights[i] > weights[strongest]):
			strongest = i
	if strongest < 0:
		return
	if weights[strongest] >= 0.999:  # inside one zone: its own settings, as they are
		_base = null
		if target.environment != profiles[strongest]:
			target.environment = profiles[strongest]
		return
	if profiles[strongest] != _base:
		_base = profiles[strongest]
		target.environment = _base.duplicate()
	var env := target.environment
	for prop: String in MIX:
		var sum: Variant = null
		for i in profiles.size():
			if profiles[i] == null or weights[i] <= 0.0:
				continue
			var part: Variant = profiles[i].get(prop) * weights[i]
			sum = part if sum == null else sum + part
		if sum != null:
			env.set(prop, sum)
