@tool
extends Node3D
## A gantry crane that crawls along the ceiling of the hall, far overhead: a girder spanning the
## hall, a trolley, a hook on a long cable, two red lamps blinking at its ends. In the game it
## drifts back and forth along Z between Z From and Z To, slowing at each end, so something up in
## the haze is always moving. Purely visual (no collision). The origin is the middle of the girder.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const HULL := preload("res://materials/black_sand_hull_worn.tres")
const METAL := preload("res://materials/metal_worn.tres")
const RUBBER := preload("res://materials/rubber.tres")
const BEACON := preload("res://materials/black_sand_beacon.tres")

@export var span := 176.0:  ## girder length along X
	set(value):
		span = value
		_rebuild()
@export var hook_drop := 18.0:  ## how far the hook hangs below the girder
	set(value):
		hook_drop = value
		_rebuild()
@export var z_from := -60.0
@export var z_to := 60.0
@export var seconds_per_pass := 140.0
@export var blink_period := 1.6

var _mesh := MeshInstance3D.new()
var _lamp: ShaderMaterial
var _t := 0.0
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	var pm := PropMesh.new()
	pm.box(HULL, Vector3(span, 2.4, 3.0), Transform3D())
	pm.box(METAL, Vector3(span, 0.4, 0.4), Transform3D(Basis(), Vector3(0, -1.6, 1.2)))
	pm.box(METAL, Vector3(span, 0.4, 0.4), Transform3D(Basis(), Vector3(0, -1.6, -1.2)))
	for s in [-1, 1]:  # end carriages riding the wall rails
		pm.box(HULL, Vector3(3.0, 3.2, 8.0), Transform3D(Basis(), Vector3(s * (span * 0.5 - 1.5), 0.4, 0)))
	var trolley := Vector3(span * 0.12, -2.6, 0)
	pm.box(HULL, Vector3(5.0, 2.2, 4.4), Transform3D(Basis(), trolley))
	pm.stick(RUBBER, trolley + Vector3(-0.4, -1.1, 0), trolley + Vector3(-0.4, -hook_drop, 0), 0.12)
	pm.stick(RUBBER, trolley + Vector3(0.4, -1.1, 0), trolley + Vector3(0.4, -hook_drop, 0), 0.12)
	pm.box(METAL, Vector3(1.6, 1.2, 1.0), Transform3D(Basis(), trolley + Vector3(0, -hook_drop - 0.4, 0)))
	_lamp = BEACON.duplicate()
	for s in [-1, 1]:
		pm.box(_lamp, Vector3(0.8, 0.8, 0.8), Transform3D(Basis(), Vector3(s * (span * 0.5 - 1.5), -1.6, 4.1)))
	_mesh.mesh = pm.commit()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	# Ping-pong with an eased turn at each end: 0..1..0 over two passes.
	var phase := fposmod(_t / seconds_per_pass, 2.0)
	var k := phase if phase < 1.0 else 2.0 - phase
	position.z = lerpf(z_from, z_to, smoothstep(0.0, 1.0, k))
	_lamp.set_shader_parameter("emission_energy", 2.5 if fposmod(_t, blink_period) < blink_period * 0.3 else 0.1)
