extends Node3D
## Water dripping from a pipe: a droplet falls from this node to the floor below every
## 1-4 s and lands with a small ring that spreads and vanishes. Finds the floor with one
## raycast when the level starts, so just put the node where the drop begins.

@export var min_wait := 1.0
@export var max_wait := 4.0
@export var color := Color(0.7, 0.82, 0.95)

const PS1 := preload("res://shaders/ps1_surface.gdshader")

var _drop: MeshInstance3D
var _ring: MeshInstance3D
var _floor_y := 0.0
var _found_floor := false
var _wait := 0.5
var _vel := 0.0
var _falling := false
var _splash := -1.0     # seconds into the splash, -1 = none


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = PS1
	mat.set_shader_parameter("albedo_color", color)
	mat.set_shader_parameter("emission_color", color)
	mat.set_shader_parameter("emission_energy", 0.25)
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.09, 0.05)
	_drop = MeshInstance3D.new()
	_drop.name = "Drop"
	_drop.mesh = box
	_drop.material_override = mat
	_drop.visible = false
	add_child(_drop)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.09
	torus.outer_radius = 0.14
	torus.rings = 8
	torus.ring_segments = 3
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.mesh = torus
	_ring.material_override = mat
	_ring.visible = false
	add_child(_ring)
	_wait = randf_range(min_wait, max_wait)


func _physics_process(delta: float) -> void:
	if not _found_floor:
		_find_floor()
		return
	if _splash >= 0.0:
		_splash += delta
		var t := _splash / 0.35
		if t >= 1.0:
			_splash = -1.0
			_ring.visible = false
		else:
			var s := 0.3 + 1.2 * t
			_ring.scale = Vector3(s, 0.25 * (1.0 - t) + 0.05, s)
	if _falling:
		_vel += 9.8 * delta
		_drop.position.y -= _vel * delta
		if global_position.y + _drop.position.y <= _floor_y + 0.03:
			_land()
		return
	_wait -= delta
	if _wait <= 0.0:
		_falling = true
		_vel = 0.0
		_drop.position = Vector3.ZERO
		_drop.visible = true


func _find_floor() -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0, -80, 0), 1)
	var hit := space.intersect_ray(query)
	_found_floor = true
	if hit.is_empty():
		_floor_y = global_position.y - 2.0   # nothing below: drip into the dark 2 m down
		return
	_floor_y = hit.position.y
	_ring.position = to_local(hit.position) + Vector3(0, 0.01, 0)


func _land() -> void:
	_falling = false
	_drop.visible = false
	_wait = randf_range(min_wait, max_wait)
	if _ring.position != Vector3.ZERO:
		_splash = 0.0
		_ring.visible = true
