@tool
extends StaticBody3D
## The waystation train's body (the house): seen from the side it is a trapezoid. The ends stand
## upright for a low band (where the buffers and lamps are), then lean back to a shorter roof.
## Seen from the front the roof corners are chamfered so the car sits snugly in the round tube.
## Two shells: the worn steel skin outside and the clean padded lining inside, `wall` metres
## apart, with a door cut through both on the +X side. The floor is a separate Block.
## Origin: centred under the car at track level (y = 0); the front faces +Z.
## Collision is made from the same faces, so Aeneas bumps into exactly what he sees.
## Godot's front faces are clockwise seen from outside; _poly() orders each triangle by the
## direction the face should look, so nothing comes out inside out.

@export var skin: Material = preload("res://materials/vacuum_station_hull_worn.tres"):
	set(v):
		skin = v
		_rebuild()
@export var lining: Material = preload("res://materials/vacuum_station_capsule_wall.tres"):
	set(v):
		lining = v
		_rebuild()
@export var glass: Material = preload("res://materials/vacuum_station_glass.tres"):
	set(v):
		glass = v
		_rebuild()
## Floor to floor, front to back, along the bottom.
@export var length := 17.75:
	set(v):
		length = v
		_rebuild()
@export var width := 9.98:
	set(v):
		width = v
		_rebuild()
@export var bottom := 0.92:
	set(v):
		bottom = v
		_rebuild()
## Top of the floor Block: the lining starts here, and so does the door.
@export var floor_top := 1.25:
	set(v):
		floor_top = v
		_rebuild()
@export var roof := 8.15:
	set(v):
		roof = v
		_rebuild()
## The ends stand upright up to this height, then lean back.
@export var band := 2.0:
	set(v):
		band = v
		_rebuild()
## How far each end leans back between the band and the roof (the trapezoid's slant).
@export var slope := 2.2:
	set(v):
		slope = v
		_rebuild()
@export var chamfer := 0.8:
	set(v):
		chamfer = v
		_rebuild()
@export var wall := 0.3:
	set(v):
		wall = v
		_rebuild()
## The side door (+X side): its centre along Z (local), width and height above the floor.
@export var door_z := 6.575:
	set(v):
		door_z = v
		_rebuild()
@export var door_width := 1.6:
	set(v):
		door_width = v
		_rebuild()
@export var door_height := 2.65:
	set(v):
		door_height = v
		_rebuild()

var _mesh := MeshInstance3D.new()
var _shape := CollisionShape3D.new()
var _tools := {}
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	add_child(_shape, false, INTERNAL_MODE_FRONT)
	_rebuild()


## Z of the front (end = 1) or back (end = -1) face at height y, `inset` metres inside the skin.
func _end_z(y: float, end: float, inset: float) -> float:
	var lean := slope * clampf((y - band) / (roof - band), 0.0, 1.0)
	return end * (length * 0.5 - inset - lean)


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	_tools = {}
	_shell(skin, width * 0.5, bottom, roof, 0.0, 1.0)
	_shell(lining, width * 0.5 - wall, floor_top, roof - wall, wall, -1.0)
	_door_reveal()
	_cab_window()
	var mesh := ArrayMesh.new()
	for mat in _tools:
		var st: SurfaceTool = _tools[mat]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	_mesh.mesh = mesh
	var shape := mesh.create_trimesh_shape() if mesh.get_surface_count() > 0 else null
	if shape:
		shape.backface_collision = true
	_shape.shape = shape


## One shell: sides, chamfers, roof and both ends. face = 1 looks outward, -1 inward.
func _shell(mat: Material, hw: float, y0: float, top: float, inset: float, face: float) -> void:
	var ch := chamfer
	var yc := top - ch  # where the side wall meets the chamfer
	for sx in [-1.0, 1.0]:
		var side := PackedVector2Array([Vector2(_end_z(y0, 1, inset), y0), Vector2(_end_z(band, 1, inset), band),
				Vector2(_end_z(yc, 1, inset), yc), Vector2(_end_z(yc, -1, inset), yc),
				Vector2(_end_z(band, -1, inset), band), Vector2(_end_z(y0, -1, inset), y0)])
		var pieces := [side] if sx < 0.0 else _cut_door(side, y0)
		for piece in pieces:
			var pts := PackedVector3Array()
			for p in piece:
				pts.append(Vector3(sx * hw, p.y, p.x))
			_poly(mat, pts, Vector3(sx * face, 0, 0))
		# The chamfer strip between the side and the roof.
		_poly(mat, PackedVector3Array([Vector3(sx * hw, yc, _end_z(yc, 1, inset)), Vector3(sx * hw, yc, _end_z(yc, -1, inset)),
				Vector3(sx * (hw - ch), top, _end_z(top, -1, inset)), Vector3(sx * (hw - ch), top, _end_z(top, 1, inset))]),
				Vector3(sx, 1, 0) * face)
	_poly(mat, PackedVector3Array([Vector3(-hw + ch, top, _end_z(top, 1, inset)), Vector3(hw - ch, top, _end_z(top, 1, inset)),
			Vector3(hw - ch, top, _end_z(top, -1, inset)), Vector3(-hw + ch, top, _end_z(top, -1, inset))]), Vector3.UP * face)
	for end in [1.0, -1.0]:
		var zb := _end_z(y0, end, inset)
		_poly(mat, PackedVector3Array([Vector3(-hw, y0, zb), Vector3(hw, y0, zb), Vector3(hw, band, zb), Vector3(-hw, band, zb)]),
				Vector3(0, 0, end * face))
		var lean := PackedVector3Array()
		for p in [Vector2(-hw, band), Vector2(hw, band), Vector2(hw, yc), Vector2(hw - ch, top), Vector2(-hw + ch, top), Vector2(-hw, yc)]:
			lean.append(Vector3(p.x, p.y, _end_z(p.y, end, inset)))
		_poly(mat, lean, Vector3(0, slope, end * (roof - band)).normalized() * face)


## The +X side minus the door: convex pieces in front of, behind, above and below the opening.
func _cut_door(side: PackedVector2Array, y0: float) -> Array:
	var z0 := door_z - door_width * 0.5
	var z1 := door_z + door_width * 0.5
	var top := floor_top + door_height
	var mid := _clip(_clip(side, Vector2(1, 0), z0), Vector2(-1, 0), -z1)
	var out := [_clip(side, Vector2(1, 0), z1), _clip(side, Vector2(-1, 0), -z0), _clip(mid, Vector2(0, 1), top)]
	if y0 < floor_top - 0.001:
		out.append(_clip(mid, Vector2(0, -1), -floor_top))
	return out.filter(func(p: PackedVector2Array) -> bool: return p.size() >= 3)


## Keeps the part of a convex polygon where dot(p, n) >= d (Sutherland-Hodgman, one edge).
func _clip(poly: PackedVector2Array, n: Vector2, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var da := a.dot(n) - d
		var db := b.dot(n) - d
		if da >= 0.0:
			out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


## The door opening's sides: jambs, head and sill joining the skin to the lining.
func _door_reveal() -> void:
	var xo := width * 0.5
	var xi := xo - wall
	var z0 := door_z - door_width * 0.5
	var z1 := door_z + door_width * 0.5
	var y1 := floor_top + door_height
	_poly(skin, PackedVector3Array([Vector3(xi, floor_top, z1), Vector3(xo, floor_top, z1), Vector3(xo, y1, z1), Vector3(xi, y1, z1)]), Vector3.FORWARD)
	_poly(skin, PackedVector3Array([Vector3(xi, floor_top, z0), Vector3(xo, floor_top, z0), Vector3(xo, y1, z0), Vector3(xi, y1, z0)]), Vector3.BACK)
	_poly(skin, PackedVector3Array([Vector3(xi, y1, z0), Vector3(xo, y1, z0), Vector3(xo, y1, z1), Vector3(xi, y1, z1)]), Vector3.DOWN)


## A dark windscreen on the front's slant, just proud of the skin.
func _cab_window() -> void:
	var n := Vector3(0, slope, roof - band).normalized()
	var pts := PackedVector3Array()
	for p in [Vector2(-3.0, 4.6), Vector2(3.0, 4.6), Vector2(3.0, 6.3), Vector2(-3.0, 6.3)]:
		pts.append(Vector3(p.x, p.y, _end_z(p.y, 1, 0.0)) + n * 0.03)
	_poly(glass, pts, n)


## A convex polygon as a triangle fan, each triangle wound to face `outward`.
func _poly(mat: Material, pts: PackedVector3Array, outward: Vector3) -> void:
	if pts.size() < 3 or mat == null:
		return
	if not _tools.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat] = st
	var tool: SurfaceTool = _tools[mat]
	var n := outward.normalized()
	for i in range(1, pts.size() - 1):
		var a := pts[0]
		var b := pts[i]
		var c := pts[i + 1]
		if (b - a).cross(c - a).dot(n) > 0.0:  # counter-clockwise from outside: swap to clockwise
			var t := b
			b = c
			c = t
		for v in [a, b, c]:
			tool.set_normal(n)
			tool.set_uv(Vector2(v.z + v.x, v.y) * 0.5)
			tool.add_vertex(v)
