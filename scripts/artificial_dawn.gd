extends Node3D
## The Construct's artificial dawn. The ceiling light panels under this node switch on
## one row at a time, from far to near, and the "sun" (a DirectionalLight3D named Sun,
## anywhere in the level) rises with them. Starts when the level loads.

@export var delay := 2.0        ## seconds before the first panel lights
@export var wave_time := 18.0   ## seconds from the first panel to the last
@export var on_material: Material
@export var sun_energy := 0.9
@export var sun_color := Color(1.0, 0.95, 0.85)
@export var day_fog := Color(0.42, 0.4, 0.44)  ## the fog and sky color once the panels are on
@export var day_ambient := 0.6

var _panels: Array[MeshInstance3D] = []
var _started := false


func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			_panels.append(child)
	# Far panels light first: sort by z, most negative (far) first.
	_panels.sort_custom(func(a, b): return a.position.z < b.position.z)
	# Its own level's Sun and WorldEnvironment (owner), also when the level is a zone of the big world.
	var level: Node = owner if owner else get_tree().current_scene
	var sun := level.find_child("Sun", true, false) if level else null
	await get_tree().create_timer(delay).timeout
	_started = true
	for i in _panels.size():
		var panel := _panels[i]
		get_tree().create_timer(wave_time * i / maxf(1.0, _panels.size() - 1)).timeout.connect(
				func() -> void: panel.material_override = on_material)
	var tween := create_tween().set_parallel()
	if sun is DirectionalLight3D:
		tween.tween_property(sun, "light_energy", sun_energy, wave_time).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sun, "light_color", sun_color, wave_time)
	var we := level.find_child("WorldEnvironment", true, false) if level else null
	if we is WorldEnvironment:
		var env: Environment = we.environment.duplicate()
		we.environment = env
		tween.tween_property(env, "fog_light_color", day_fog, wave_time)
		tween.tween_property(env, "background_color", day_fog, wave_time)
		tween.tween_property(env, "ambient_light_energy", day_ambient, wave_time)
