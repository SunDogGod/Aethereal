extends RefCounted
## Builds ONE mesh out of simple shapes (boxes, cylinders, spheres, rings), with one surface per
## material, for the prop scripts in this folder (pipe_run.gd, cable_run.gd, street_prop.gd).
## One mesh per prop means one draw call per material instead of one per piece.
## Not a node: a prop script makes one, adds shapes, then calls commit().
## Godot's own primitive meshes are wound correctly (clockwise front faces), and the transforms
## used here never mirror, so the result is never inside out.
## Each kind of shape is read from Godot's primitive meshes only once and remembered (boxes once
## at 1 m, then stretched): reading a primitive mesh is a round trip to the graphics card, about
## 0.7 ms each on a laptop, and the world's props are made of thousands of pieces.

static var _shapes := {}  # shape key -> [positions, normals, uvs, indices], read once per game
var _surfaces := {}  # Material -> [positions, normals, uvs, indices] gathered so far


func box(mat: Material, size: Vector3, xf: Transform3D) -> void:
	var unit: Array = _shapes.get(&"box", [])
	if unit.is_empty():
		var m := BoxMesh.new()
		m.size = Vector3.ONE
		unit = _read(&"box", m)
	# A box is the 1 m box stretched: its corners are linear in its size, its UVs don't change.
	_put(mat, unit, Transform3D(xf.basis * Basis.from_scale(size), xf.origin), xf.basis)


## A cylinder (or a cone, if the radii differ) standing along its local Y axis.
func cyl(mat: Material, r_top: float, r_bottom: float, height: float, xf: Transform3D, sides := 8, rings := 0) -> void:
	var key := [&"cyl", r_top, r_bottom, height, sides, rings]
	var shape: Array = _shapes.get(key, [])
	if shape.is_empty():
		var m := CylinderMesh.new()
		m.top_radius = r_top
		m.bottom_radius = r_bottom
		m.height = height
		m.radial_segments = sides
		m.rings = rings
		shape = _read(key, m)
	_put(mat, shape, xf, xf.basis)


## A sphere, or a squashed one when height != radius * 2.
func sphere(mat: Material, radius: float, height: float, xf: Transform3D, sides := 8, rings := 4) -> void:
	var key := [&"sphere", radius, height, sides, rings]
	var shape: Array = _shapes.get(key, [])
	if shape.is_empty():
		var m := SphereMesh.new()
		m.radius = radius
		m.height = height
		m.radial_segments = sides
		m.rings = rings
		shape = _read(key, m)
	_put(mat, shape, xf, xf.basis)


## A ring lying flat (around local Y): wheels, collars.
func ring(mat: Material, inner: float, outer: float, xf: Transform3D, sides := 12, ring_sides := 4) -> void:
	var key := [&"ring", inner, outer, sides, ring_sides]
	var shape: Array = _shapes.get(key, [])
	if shape.is_empty():
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = sides
		m.ring_segments = ring_sides
		shape = _read(key, m)
	_put(mat, shape, xf, xf.basis)


## A thin box from a to b (a stick, a strut, a cable piece), `thick` metres across.
func stick(mat: Material, a: Vector3, b: Vector3, thick: float) -> void:
	var length := a.distance_to(b)
	if length < 0.001:
		return
	box(mat, Vector3(thick, length + thick * 0.5, thick), along(a, b))


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for mat in _surfaces:
		var s: Array = _surfaces[mat]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s[0]
		arrays[Mesh.ARRAY_NORMAL] = s[1]
		arrays[Mesh.ARRAY_TEX_UV] = s[2]
		arrays[Mesh.ARRAY_INDEX] = s[3]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	return mesh


## A transform whose Y axis runs from a to b, centred between them (for cylinders and sticks).
static func along(a: Vector3, b: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var ref := Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y, z), (a + b) * 0.5)


## Any primitive mesh (a subdivided BoxMesh, a PrismMesh, a QuadMesh...), placed at xf.
func _add(mat: Material, m: PrimitiveMesh, xf: Transform3D) -> void:
	var key := [m.get_class()]
	for p: Dictionary in m.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_STORAGE:
			key.append(m.get(p.name))
	var shape: Array = _shapes.get(key, [])
	if shape.is_empty():
		shape = _read(key, m)
	_put(mat, shape, xf, xf.basis)


## Reads a primitive's vertices once (the slow part) and remembers them under `key`.
static func _read(key: Variant, m: PrimitiveMesh) -> Array:
	var arrays := m.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		index = arrays[Mesh.ARRAY_INDEX]
	if index.is_empty():
		for i in verts.size():
			index.append(i)
	var shape := [verts, arrays[Mesh.ARRAY_NORMAL], arrays[Mesh.ARRAY_TEX_UV], index]
	_shapes[key] = shape
	return shape


## Adds one shape to its material's surface: corners moved by `xf`, normals turned by `turn`.
func _put(mat: Material, shape: Array, xf: Transform3D, turn: Basis) -> void:
	if not _surfaces.has(mat):
		_surfaces[mat] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedInt32Array()]
	var s: Array = _surfaces[mat]
	var verts: PackedVector3Array = s[0]
	var norms: PackedVector3Array = s[1]
	var uvs: PackedVector2Array = s[2]
	var index: PackedInt32Array = s[3]
	var base := verts.size()
	verts.append_array(xf * (shape[0] as PackedVector3Array))
	norms.append_array(Transform3D(turn, Vector3.ZERO) * (shape[1] as PackedVector3Array))
	uvs.append_array(shape[2])
	for k: int in shape[3]:
		index.append(base + k)
	s[0] = verts
	s[1] = norms
	s[2] = uvs
	s[3] = index
