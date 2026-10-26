@tool
extends Node3D
## The station AI's projection: three rings of light turning slowly round a small core, high over
## the emitter, with a faint widening beam down to it. It is the landmark you see from across the
## hall. Built in code (nothing extra saved in the scene); see-through (GeometryInstance3D
## transparency) and flickering a little, like the figure (hologram.gd). Put this node where the
## rings' centre should be; the beam runs `beam_length` metres straight down.

@export var material: Material = preload("res://materials/hologram.tres"):
	set(value):
		material = value
		_rebuild()
## The beam down to the emitter: a dimmer material, so it reads as light, not as a pole.
@export var beam_material: Material = preload("res://materials/vacuum_station_holo_beam.tres"):
	set(value):
		beam_material = value
		_rebuild()
@export var radius := 2.0:
	set(value):
		radius = value
		_rebuild()
@export var beam_length := 7.0:
	set(value):
		beam_length = value
		_rebuild()
## Radians per second for the outer ring (the others turn at other speeds).
@export var spin := 0.3
## 0 = steady; higher = more flicker.
@export var flicker := 0.25

var _rings: Array[MeshInstance3D] = []
var _parts: Array[MeshInstance3D] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	_rebuild()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	for p in _parts:
		remove_child(p)
		p.free()
	_parts.clear()
	_rings.clear()
	var tilts := [Vector3(1.25, 0, 0), Vector3(1.25, 0, 1.0), Vector3(0, 0, 0.35)]
	for i in 3:
		var t := TorusMesh.new()
		var r := radius * (1.0 - i * 0.18)
		t.inner_radius = r - 0.11
		t.outer_radius = r
		t.rings = 24
		t.ring_segments = 3
		var holder := _part(t, 0.35)
		holder.rotation = tilts[i]
		_rings.append(holder)
	var core := SphereMesh.new()  # a diamond: 4 sides, 2 rings
	core.radius = 0.32
	core.height = 0.8
	core.radial_segments = 4
	core.rings = 2
	_part(core, 0.15)
	var beam := CylinderMesh.new()
	beam.top_radius = 0.3
	beam.bottom_radius = 0.05
	beam.height = beam_length
	beam.radial_segments = 8
	beam.rings = 0
	beam.cap_top = false
	beam.cap_bottom = false
	var b := _part(beam, 0.55, beam_material)
	b.position = Vector3(0, -beam_length * 0.5, 0)


func _part(mesh: Mesh, see_through: float, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat if mat else material
	mi.transparency = see_through
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("base", see_through)
	add_child(mi, false, INTERNAL_MODE_FRONT)
	_parts.append(mi)
	return mi


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	for i in _rings.size():
		_rings[i].rotate_object_local(Vector3.UP, spin * delta * [1.0, -0.7, 0.45][i])
	_parts[3].rotate_y(delta * 0.8)  # the core
	var on := 1.0 - flicker * (0.5 + 0.5 * sin(_t * 19.0) * sin(_t * 5.3))
	if _rng.randf() < 0.015 * flicker:
		on = 0.3
	for p in _parts:
		var base: float = p.get_meta("base")
		p.transparency = clampf(1.0 - (1.0 - base) * on, 0.0, 0.95)
