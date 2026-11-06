@tool
extends Node3D
## "Moving balls of light": a few small glowing spheres that wander slowly inside a box centred
## on this node, swelling in and dying away, never explained (the Notion foreshadowing). One
## OmniLight rides with the first ball, so the nearest wall takes its colour. They are drawn
## added onto the scene (shaders/kit_glow.gdshader), so they read as light, not as objects.
## Purely visual: no collision. Put the node mid-air in the space they should haunt.

const GLOW_MATERIAL := preload("res://materials/kit_glow.tres")
const FADE := 2.5  # seconds to swell in or die away

@export_range(1, 24) var count := 5:
	set(value):
		count = value
		_rebuild()
## The box they stay inside, in metres, centred on this node.
@export var box_size := Vector3(8, 4, 8):
	set(value):
		box_size = value
		_rebuild()
@export var color := Color(0.72, 0.66, 1.0):
	set(value):
		color = value
		_rebuild()
## Metres per second, roughly: 0.4 is a slow drift, 1.5 is restless.
@export var speed := 0.4
@export var size := 0.14:
	set(value):
		size = maxf(value, 0.01)
		_rebuild()
@export_range(0.0, 3.0) var brightness := 0.8:
	set(value):
		brightness = value
		_rebuild()
## One OmniLight follows the first ball and brightens with it.
@export var cast_light := true:
	set(value):
		cast_light = value
		_rebuild()
@export var light_energy := 0.8
@export var light_range := 6.0
## 0 = a different wander every run; any other number repeats the same one.
@export var random_seed := 0

var _balls := MultiMeshInstance3D.new()
var _multi := MultiMesh.new()
var _light := OmniLight3D.new()
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _goal := PackedVector3Array()
var _life := PackedFloat32Array()   # seconds into this showing
var _hold := PackedFloat32Array()   # how long this showing lasts
var _rng := RandomNumberGenerator.new()
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_balls, false, INTERNAL_MODE_FRONT)
	add_child(_light, false, INTERNAL_MODE_FRONT)
	_balls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_custom_data = true
	_balls.multimesh = _multi
	_light.shadow_enabled = false
	_rebuild()


## Every setting calls this: the balls are laid out once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	var ball := SphereMesh.new()
	ball.radius = size
	ball.height = size * 2.0
	ball.radial_segments = 8
	ball.rings = 4
	_multi.instance_count = 0
	_multi.mesh = ball
	_multi.instance_count = count
	_balls.material_override = GLOW_MATERIAL
	_balls.set_instance_shader_parameter("tint", Vector3(color.r, color.g, color.b))
	_balls.set_instance_shader_parameter("strength", brightness)
	_balls.custom_aabb = AABB(-box_size * 0.5 - Vector3.ONE * size, box_size + Vector3.ONE * size * 2.0)
	_pos.resize(count)
	_vel.resize(count)
	_goal.resize(count)
	_life.resize(count)
	_hold.resize(count)
	for i in count:
		_pos[i] = _spot()
		_goal[i] = _spot()
		_vel[i] = Vector3.ZERO
		_hold[i] = _rng.randf_range(6.0, 14.0)
		_life[i] = _rng.randf() * _hold[i]  # not all at the same point of their cycle
	_light.visible = cast_light
	_light.light_color = color
	_light.omni_range = light_range
	_light.light_energy = light_energy
	_show()


## A random point inside the box.
func _spot() -> Vector3:
	return Vector3(_rng.randf_range(-0.5, 0.5) * box_size.x, _rng.randf_range(-0.5, 0.5) * box_size.y,
			_rng.randf_range(-0.5, 0.5) * box_size.z)


func _fade(i: int) -> float:
	if Engine.is_editor_hint():
		return 1.0
	var up := smoothstep(0.0, FADE, _life[i])
	var down := 1.0 - smoothstep(_hold[i] - FADE, _hold[i], _life[i])
	return minf(up, down)


func _show() -> void:
	for i in count:
		_multi.set_instance_transform(i, Transform3D(Basis(), _pos[i]))
		_multi.set_instance_custom_data(i, Color(0, 0, 0, _fade(i)))
	if count > 0:
		_light.position = _pos[0]
		_light.light_energy = light_energy * _fade(0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _pos.size() != count:
		return
	for i in count:
		_life[i] += delta
		if _life[i] >= _hold[i]:  # gone: come back somewhere else
			_life[i] = 0.0
			_hold[i] = _rng.randf_range(6.0, 14.0)
			_pos[i] = _spot()
			_goal[i] = _spot()
			_vel[i] = Vector3.ZERO
		# Steer gently toward a goal; pick a new one when close, or now and then.
		var to_goal := _goal[i] - _pos[i]
		if to_goal.length() < 0.3 or _rng.randf() < 0.05 * delta:
			_goal[i] = _spot()
		_vel[i] = _vel[i].lerp(to_goal.normalized() * speed, minf(delta * 0.8, 1.0))
		_pos[i] += _vel[i] * delta
		_pos[i] = _pos[i].clamp(-box_size * 0.5, box_size * 0.5)
	_show()
