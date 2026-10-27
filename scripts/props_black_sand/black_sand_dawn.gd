extends Node3D
## Black Sand's artificial dawn. The ceiling light panels under this node switch on one at a time,
## from far to near, and the "sun" (a DirectionalLight3D named Sun, anywhere in the level) rises
## with them. Starts when the level loads. dawn_reveal.gd does the fog and the sun's angle, and
## follows this node's delay and wave time.
## Timed in _process (not with SceneTree timers), so in the big world the whole dawn waits while
## Black Sand's zone is frozen, and the panels, sun and fog stay in step.

@export var delay := 2.0        ## seconds before the first panel lights
@export var wave_time := 18.0   ## seconds from the first panel to the last
@export var on_material: Material
@export var sun_energy := 0.9
@export var sun_color := Color(1.0, 0.95, 0.85)
@export var day_fog := Color(0.42, 0.4, 0.44)  ## the fog and sky color once the panels are on
@export var day_ambient := 0.6

var _panels: Array[MeshInstance3D] = []
var _started := false
var _t := 0.0     # seconds since the level loaded (only counted while this node processes)
var _lit := 0     # panels switched on so far, in _panels order


func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			_panels.append(child)
	# Far panels light first: sort by z, most negative (far) first.
	_panels.sort_custom(func(a, b): return a.position.z < b.position.z)


func _process(delta: float) -> void:
	_t += delta
	if not _started:
		if _t < delay:
			return
		_started = true
		_begin()
	var since := _t - delay
	var step := wave_time / maxf(1.0, _panels.size() - 1)
	while _lit < _panels.size() and since >= step * _lit:
		_panels[_lit].material_override = on_material
		_lit += 1
	if _lit >= _panels.size():
		set_process(false)  # every panel is on; the tween finishes the sun and fog by itself


## Its own level's Sun and WorldEnvironment (owner), also when the level is a zone of the big world.
## The Environment is swapped for a copy first, so the shared resource is never changed.
func _begin() -> void:
	var level: Node = owner if owner else get_tree().current_scene
	if level == null:
		return
	var tween := create_tween().set_parallel()
	var sun := level.find_child("Sun", true, false)
	if sun is DirectionalLight3D:
		tween.tween_property(sun, "light_energy", sun_energy, wave_time).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sun, "light_color", sun_color, wave_time)
	var we := level.find_child("WorldEnvironment", true, false)
	if we is WorldEnvironment:
		var env: Environment = we.environment.duplicate()
		we.environment = env
		tween.tween_property(env, "fog_light_color", day_fog, wave_time)
		tween.tween_property(env, "background_color", day_fog, wave_time)
		tween.tween_property(env, "ambient_light_energy", day_ambient, wave_time)
