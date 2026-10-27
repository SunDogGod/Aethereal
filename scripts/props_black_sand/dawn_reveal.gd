extends Node
## Black Sand's dawn, the parts black_sand_dawn.gd (the ArtificialDawn node) doesn't do: while the
## ceiling lights come on, the fog draws back (you wake seeing only the nearest dunes; by day the columns, the arch and the
## town stand out of the haze) and the "sun" climbs from low over the far end to its morning angle.
## It also owns one ceiling panel that comes on late, stutters, and blinks now and then.
## It follows the timing of the ArtificialDawn node (its delay and wave time), so retime that one.
## The level's Environment keeps fog_density at 0.98, not 1: past fog_end a dark wall still vanishes,
## but bright lights (the town's windows far overhead, lit ceiling panels) show faintly through the
## haze, so the waking scene's look back at the town reads before the fog has drawn back.

@export var dawn: NodePath  ## the ArtificialDawn node
@export var fog_end_dark := 55.0    ## metres you can see before the dawn
@export var fog_end_day := 150.0    ## ...and once the lights are on
@export var fog_begin_dark := 2.0
@export var fog_begin_day := 8.0
@export var sun_pitch_dark := -6.0   ## degrees: the sun starts just over the horizon...
@export var sun_pitch_day := -32.0   ## ...and climbs to here
@export var sun_yaw := 150.0         ## degrees: which way the light travels (180 = toward the start, south)
@export var late_panel: NodePath     ## a ceiling panel (MeshInstance3D) that is NOT under ArtificialDawn
@export var late_material: Material  ## what it shows when lit (grow_lamp.tres)
@export_range(0.0, 1.5) var late_at := 1.15  ## when it comes on, as a share of the wave time

var _late: MeshInstance3D
var _off: Material
var _rng := RandomNumberGenerator.new()
var _we: WorldEnvironment
var _sun: DirectionalLight3D
var _t := 0.0
var _start_at := 2.1    # when the tween starts (ArtificialDawn's delay, plus a moment)
var _wave := 18.0
var _started := false
var _next_flip := -1.0  # the late panel's next on/off change, in seconds since load
var _flips_left := 0    # stutters still to come before it holds


func _ready() -> void:
	_rng.randomize()
	var level: Node = owner if owner else get_tree().current_scene
	if level == null:
		return
	var dawn_node := get_node_or_null(dawn)
	if dawn_node:
		_start_at = float(dawn_node.get("delay")) + 0.1
		_wave = float(dawn_node.get("wave_time"))
	_sun = level.find_child("Sun", true, false) as DirectionalLight3D
	if _sun:
		_sun.rotation = Vector3(deg_to_rad(sun_pitch_dark), deg_to_rad(sun_yaw), 0.0)
	_we = level.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if _we and _we.environment:
		_we.environment.fog_depth_end = fog_end_dark
		_we.environment.fog_depth_begin = fog_begin_dark
	_late = get_node_or_null(late_panel) as MeshInstance3D
	if _late and late_material:
		_off = _late.material_override
		_next_flip = _start_at + _wave * late_at
		_flips_left = 9


# Timed in _process rather than with awaits, so nothing is left waiting when the level is freed.
func _process(delta: float) -> void:
	_t += delta
	if not _started and _t >= _start_at:
		_started = true
		_begin()
	if _next_flip >= 0.0 and _t >= _next_flip:
		_flip()


## ArtificialDawn has swapped in its own copy of the Environment by now: tween that one.
func _begin() -> void:
	var tween := create_tween().set_parallel()
	if _we and _we.environment:
		tween.tween_property(_we.environment, "fog_depth_end", fog_end_day, _wave).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_we.environment, "fog_depth_begin", fog_begin_day, _wave)
	if _sun:
		tween.tween_property(_sun, "rotation:x", deg_to_rad(sun_pitch_day), _wave).set_trans(Tween.TRANS_SINE)


## The late panel comes on like a tired tube: a few tries, then it holds; later it drops out
## for a moment every 5 to 14 seconds.
func _flip() -> void:
	var lit := _late.material_override == late_material
	_late.material_override = _off if lit else late_material
	if _flips_left > 0:
		_flips_left -= 1
		_next_flip = _t + (_rng.randf_range(0.05, 0.2) if not lit else _rng.randf_range(0.1, 0.5))
	elif lit:
		_next_flip = _t + _rng.randf_range(0.06, 0.25)  # a short dropout
	else:
		_next_flip = _t + _rng.randf_range(5.0, 14.0)  # back on: hold for a while
