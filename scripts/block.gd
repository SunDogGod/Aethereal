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

const SUBDIVIDE_EVERY := 2.0

enum Style { PLAIN, BUILDING }

@export var size := Vector3(2.0, 2.0, 2.0):
	set(value):
		size = value
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		_rebuild()
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


func _init() -> void:
	add_child(_mesh_instance, false, INTERNAL_MODE_FRONT)
	add_child(_collision, false, INTERNAL_MODE_FRONT)
	set_notify_local_transform(true)
	_rebuild()


## A building picks its doors and lit windows from where it stands, so dragging one in the
## editor rebuilds its fronts (otherwise the game would show a different front than the editor).
func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and style == Style.BUILDING and is_inside_tree():
		_rebuild()


## A building's doors and lit windows are picked from its position, so it is built once it is
## in the tree (every property set before that would rebuild it for nothing).
func _ready() -> void:
	if style == Style.BUILDING:
		_rebuild()


func _rebuild() -> void:
	_mesh_instance.material_override = _runtime_material if _runtime_material else material
	var shape := BoxShape3D.new()
	shape.size = size
	_collision.shape = shape
	if style == Style.BUILDING and not is_inside_tree():
		return
	_mesh_instance.mesh = _build_mesh()



## Shows a different material while the game runs (a TV's own animated copy, a flickering
## sign's glow) without touching the exported `material`, so a scene saved afterwards still
## points at the shared file in materials/. Pass null to go back to `material`.
func set_runtime_material(m: Material) -> void:
	_runtime_material = m
	_mesh_instance.material_override = m if m else material

func _build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if style == Style.BUILDING:
		BuildingFaces.new(st, self).build()
		return st.commit()
	var h := size * 0.5
	# Each face: its outward normal, the axis that runs "along" it (u) and "across" it (v).
	_face(st, Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0), h)    # front
	_face(st, Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0), h)  # back
	_face(st, Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0), h)   # right
	_face(st, Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), h)   # left
	_face(st, Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), h)   # top
	_face(st, Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), h)   # bottom
	return st.commit()


func _face(st: SurfaceTool, n: Vector3, u_axis: Vector3, v_axis: Vector3, h: Vector3) -> void:
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
	for j in nv:
		for i in nu:
			var p := []
			var uv := []
			var col := []
			for corner in [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]:
				var du: float = u_len * corner.x / nu
				var dv: float = v_len * corner.y / nv
				var pos: Vector3 = origin + u_axis * du + v_axis * dv
				p.append(pos)
				if trim:
					uv.append(Vector2(du, 1.0 - dv / v_len))  # metres along, 0..1 across
				else:
					uv.append(Vector2(du / u_len, 1.0 - dv / v_len))  # one texture per face (props)
				col.append(_shade(pos, side, n))
			# Two triangles, wound so they face outward. Godot's front faces are CLOCKWISE seen
			# from outside, so when the right-hand (counter-clockwise) normal points out, flip.
			var tri_normal: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
			var order := [0, 2, 1, 0, 3, 2] if tri_normal.dot(n) > 0.0 else [0, 1, 2, 0, 2, 3]
			for k in order:
				st.set_normal(n)
				st.set_uv(uv[k])
				st.set_color(col[k])
				st.add_vertex(p[k])


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
