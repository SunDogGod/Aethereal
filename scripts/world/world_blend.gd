class_name WorldBlend
extends RefCounted
## Mixes the zones' own environments (fog, light, background) into the one the world shows.
## Inside one zone the world simply shows that zone's own environment (so a zone that changes its
## own while playing, like Black Sand's dawn, shows the change at no cost). On a link, the
## strongest zone's settings are copied whole (sky or flat colour, which kind of fog) and the
## numbers and colours below are mixed by weight, so walking a link fades one place's air into
## the next.
## Volumetric fog is the exception to "copied whole": it is on along the whole link if either
## side uses it, and a side without it counts as no fog at all (VOLUMETRIC_OFF), so Black Sand's
## ground fog (FogVolumes lit through ambient_inject) fades in across the link instead of
## switching on halfway.

const MIX := [
	"background_color", "background_energy_multiplier",
	"ambient_light_color", "ambient_light_energy", "ambient_light_sky_contribution",
	"fog_light_color", "fog_light_energy", "fog_sun_scatter", "fog_density",
	"fog_height", "fog_height_density", "fog_aerial_perspective", "fog_sky_affect",
	"fog_depth_curve", "fog_depth_begin", "fog_depth_end",
	"tonemap_exposure", "glow_intensity",
]
## Mixed only between the zones that use volumetric fog; a zone without it adds these values.
const VOLUMETRIC_OFF := {
	"volumetric_fog_density": 0.0, "volumetric_fog_emission_energy": 0.0,
	"volumetric_fog_ambient_inject": 0.0,
}
## The look of the volumetric fog: taken from the zones that use it (re-weighted among them).
const VOLUMETRIC_LOOK := [
	"volumetric_fog_albedo", "volumetric_fog_emission", "volumetric_fog_length",
	"volumetric_fog_anisotropy",
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
		_mix(env, prop, profiles, weights, false)
	var foggy := 0.0  # how much of the mix comes from zones with volumetric fog
	for i in profiles.size():
		if profiles[i] and weights[i] > 0.0 and profiles[i].volumetric_fog_enabled:
			foggy += weights[i]
	env.volumetric_fog_enabled = foggy > 0.0
	if foggy <= 0.0:
		return
	for prop: String in VOLUMETRIC_OFF:
		_mix(env, prop, profiles, weights, true)
	for prop: String in VOLUMETRIC_LOOK:
		_mix(env, prop, profiles, weights, true, foggy)


## Sets `prop` to the weighted sum. With `volumetric`, a zone without volumetric fog adds its
## VOLUMETRIC_OFF value (or nothing, for the look, which is then divided by `share`).
static func _mix(env: Environment, prop: String, profiles: Array[Environment], weights: Array[float],
		volumetric: bool, share := 1.0) -> void:
	var sum: Variant = null
	for i in profiles.size():
		if profiles[i] == null or weights[i] <= 0.0:
			continue
		var value: Variant = profiles[i].get(prop)
		if volumetric and not profiles[i].volumetric_fog_enabled:
			if not VOLUMETRIC_OFF.has(prop):
				continue
			value = VOLUMETRIC_OFF[prop]
		var part: Variant = value * (weights[i] / share)
		sum = part if sum == null else sum + part
	if sum != null:
		env.set(prop, sum)
