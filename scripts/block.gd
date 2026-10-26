@tool
class_name Block
extends StaticBody3D
## A building block: one box you can see and stand on.
## Change Size and Material in the Inspector; the box and its collision follow.
## Big faces are split into ~2 m squares so the PS1 texture warping stays tame.
## The mesh carries vertex colours: the bottom of every side face darkens (grime,
## like dirt kicked up against a wall), which painted materials multiply in.
## Trim: for rails, pipes and cables, map the texture along each face instead
## (u = metres along the face, v = 0..1 across it), so a trim-sheet strip fits.
## Style BUILDING: the faces become real building fronts (doors and shopfronts at the bottom,
## window bays with plain corners, floor slabs, a parapet, a plain roof) mapped into the
## building atlas; see building_faces.gd. Use it with materials/building*.tres (world_uv off).
## The box is built once it is in a scene (see mesh_build.gd); identical plain blocks share
## one mesh while the game runs.

const SUBDIVIDE_EVERY := 2.0

enum Style { PLAIN, BUILDING }

@export var size := Vector3(2.0, 2.0, 2.0):
	set(value):
		size = value
		_rebuild()
@export var material: Material:  # only the look changes: the box itself stays as it is
	set(value):
		material = value
		_mesh_instance.material_override = _runtime_material if _runtime_material else material
@export var style: Style = Style.PLAIN:
	set(value):
		style = value
		_rebuild()
@export_group("Building")
@export var ground_floor := true:  ## doors and shopfronts along the bottom (off for a block that floats above the street)
	set(value):
		ground_floor = value
		_rebuild()
@export_group("Shading")
@export_range(0.0, 1.0) var grime := 0.35:  ## how dark the bottom of the walls gets
	set(value):
		grime = value
		_rebuild()
@export var grime_height := 1.4:  ## metres up the wall the grime reaches
	set(value):
		grime_height = value
		_rebuild()
@export var trim := false:  ## map the texture along the faces (trim sheets)
	set(value):
		trim = value
		_rebuild()

# Made in code and kept out of the scene file, so the Scene panel only shows the Block.
var _mesh_instance := MeshInstance3D.new()
var _collision := CollisionShape3D.new()
var _runtime_material: Material  # set by life-sign scripts; never saved into the scene
var _build_pending := false  # waiting to be built (it builds once it is in a scene)


func _init() -> void:
	add_child(_mesh_instance, false, INTERNAL_MODE_FRONT)
	add_child(_collision, false, INTERNAL_MODE_FRONT)
	set_notify_local_transform(true)
	_rebuild()


## A plain block builds as it enters the tree (unless the loading screen built it already).
## A building picks its doors and lit windows from where it stands, so dragging one in the
## editor rebuilds its fronts (otherwise the game would show a different front than the editor).
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE and _build_pending and style != Style.BUILDING:
		_rebuild_now()
	elif what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and style == Style.BUILDING and is_inside_tree():
		_rebuild()


## A building's fronts look at what stands around it (building_context.gd), so it is built in
## _ready, once the whole scene is in the tree.
func _ready() -> void:
	if style == Style.BUILDING:
		_rebuild()


## Every setting calls this. Outside a scene (while a scene file is being instanced) it only
## remembers to build: each setting would otherwise rebuild the whole box again.
func _rebuild() -> void:
	if is_inside_tree():
		_rebuild_now()
	else:
		_build_pending = true


func _rebuild_now() -> void:
	_build_pending = false
	_mesh_instance.material_override = _runtime_material if _runtime_material else material
	var shape := BoxShape3D.new()
	shape.size = size
	_collision.shape = shape
	_mesh_instance.mesh = _build_mesh()


## Shows a different material while the game runs (a TV's own animated copy, a flickering
## sign's glow) without touching the exported `material`, so a scene saved afterwards still
## points at the shared file in materials/. Pass null to go back to `material`.
func set_runtime_material(m: Material) -> void:
	_runtime_material = m
	_mesh_instance.material_override = m if m else material


func _build_mesh() -> ArrayMesh:
	if style == Style.BUILDING:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		BuildingFaces.new(st, self).build()
		return st.commit()
	var key := [size, grime, grime_height, trim]
	var mesh: ArrayMesh = MeshBuild.shared(key)  # another block just like this one, already built?
	if mesh:
		return mesh
	var out := [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedColorArray()]
	var h := size * 0.5
	# Each face: its outward normal, the axis that runs "along" it (u) and "across" it (v).
	_face(out, Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0), h)    # front
	_face(out, Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0), h)  # back
	_face(out, Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0), h)   # right
	_face(out, Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), h)   # left
	_face(out, Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), h)   # top
	_face(out, Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), h)   # bottom
	mesh = ArrayMesh.new()
	if not (out[0] as PackedVector3Array).is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = out[0]
		arrays[Mesh.ARRAY_NORMAL] = out[1]
		arrays[Mesh.ARRAY_TEX_UV] = out[2]
		arrays[Mesh.ARRAY_COLOR] = out[3]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	MeshBuild.share(key, mesh)
	return mesh


## One face split into a grid of squares, two triangles each, added to `out`
## (positions, normals, uvs, colours).
func _face(out: Array, n: Vector3, u_axis: Vector3, v_axis: Vector3, h: Vector3) -> void:
	var u_len: float = (h * u_axis.abs()).length() * 2.0
	var v_len: float = (h * v_axis.abs()).length() * 2.0
	if u_len <= 0.0 or v_len <= 0.0:
		return
	# For trim, u runs along the longer side and v across the shorter one.
	if trim and v_len > u_len:
		var swap_axis := u_axis
		u_axis = v_axis
		v_axis = swap_axis
		var swap_len := u_len
		u_len = v_len
		v_len = swap_len
	# Capped: a 200 m foundation doesn't need 10,000 quads a face; warping only matters up close.
	var nu := clampi(ceili(u_len / SUBDIVIDE_EVERY), 1, 16)
	var nv := clampi(ceili(v_len / SUBDIVIDE_EVERY), 1, 16)
	var origin: Vector3 = n * (h * n.abs()).length() - u_axis * u_len * 0.5 - v_axis * v_len * 0.5
	var side := absf(n.y) < 0.5
	# The grid's corners, each worked out once (a corner is shared by up to four squares).
	var pos := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for j in nv + 1:
		var dv: float = v_len * j / nv
		for i in nu + 1:
			var du: float = u_len * i / nu
			var p: Vector3 = origin + u_axis * du + v_axis * dv
			pos.append(p)
			if trim:
				uvs.append(Vector2(du, 1.0 - dv / v_len))  # metres along, 0..1 across
			else:
				uvs.append(Vector2(du / u_len, 1.0 - dv / v_len))  # one texture per face (props)
			cols.append(_shade(p, side, n))
	var verts: PackedVector3Array = out[0]
	var norms: PackedVector3Array = out[1]
	var tex: PackedVector2Array = out[2]
	var shade: PackedColorArray = out[3]
	var row := nu + 1
	for j in nv:
		for i in nu:
			# The square's corners, counter-clockwise in (u, v): (i,j) (i+1,j) (i+1,j+1) (i,j+1).
			var c := [j * row + i, j * row + i + 1, (j + 1) * row + i + 1, (j + 1) * row + i]
			# Two triangles, wound so they face outward. Godot's front faces are CLOCKWISE seen
			# from outside, so when the right-hand (counter-clockwise) normal points out, flip.
			var tri_normal: Vector3 = (pos[c[1]] - pos[c[0]]).cross(pos[c[2]] - pos[c[0]])
			var order := [0, 2, 1, 0, 3, 2] if tri_normal.dot(n) > 0.0 else [0, 1, 2, 0, 2, 3]
			for k: int in order:
				var at: int = c[k]
				verts.append(pos[at])
				norms.append(n)
				tex.append(uvs[at])
				shade.append(cols[at])
	out[0] = verts
	out[1] = norms
	out[2] = tex
	out[3] = shade


## Vertex colour: grime at the foot of side faces, a hair of random variation everywhere.
func _shade(pos: Vector3, side: bool, n: Vector3) -> Color:
	var v := 1.0
	if side:
		var up: float = clampf((pos.y + size.y * 0.5) / maxf(0.05, grime_height), 0.0, 1.0)
		v = lerpf(1.0 - grime, 1.0, smoothstep(0.0, 1.0, up))
	elif n.y < 0.0:
		v = 1.0 - grime
	var wobble: float = fmod(absf(sin(pos.x * 12.9898 + pos.y * 78.233 + pos.z * 37.719) * 43758.5453), 1.0)
	v *= 0.96 + 0.04 * wobble
	return Color(v, v, v, 1.0)
