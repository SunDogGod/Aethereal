@tool
class_name CloudLayer
extends Node3D
## A cloud deck over a level, so the sky has weather instead of being a lid: a few see-through
## sheets stacked `spacing` metres apart, `size` metres across, centred on this node (put the node
## at the height the clouds should hang, e.g. the town's rooftops). The look (colour, how cloudy,
## how big the clouds are, the wind) lives in the material (materials/clouds_*.tres), so it can be
## tuned in the Inspector. Purely visual: no collision, no light.

@export var size := Vector2(600, 600):
	set(value):
		size = value
		_rebuild()
@export_range(1, 6) var sheets := 3:
	set(value):
		sheets = value
		_rebuild()
@export var spacing := 5.0:  ## metres between the sheets
	set(value):
		spacing = value
		_rebuild()
@export var material: ShaderMaterial:
	set(value):
		material = value
		_rebuild()

const CELLS := 24  # squares per side of a sheet: enough that the corner wobble stays small

var _mesh := MeshInstance3D.new()
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rebuild()


## Every setting calls this: the mesh is built once, when the node is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	if material == null:
		_mesh.mesh = null
		return
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var half := size * 0.5
	for s in sheets:
		var y := (s - (sheets - 1) * 0.5) * spacing
		var tag := Color(s / 255.0, 0, 0)  # the shader reads the sheet's number from here
		for i in CELLS:
			for j in CELLS:
				var x0 := lerpf(-half.x, half.x, float(i) / CELLS)
				var x1 := lerpf(-half.x, half.x, float(i + 1) / CELLS)
				var z0 := lerpf(-half.y, half.y, float(j) / CELLS)
				var z1 := lerpf(-half.y, half.y, float(j + 1) / CELLS)
				# Clockwise seen from below (the side people look at); the material draws both sides.
				for v in [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1),
						Vector3(x0, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]:
					verts.append(v)
					colors.append(tag)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-half.x, -sheets * spacing, -half.y), Vector3(size.x, sheets * spacing * 2.0, size.y))
	_mesh.mesh = mesh
	_mesh.material_override = material
	_mesh.set_instance_shader_parameter("half_size", half)
