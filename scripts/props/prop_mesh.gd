extends RefCounted
## Builds ONE mesh out of simple shapes (boxes, cylinders, spheres, rings), with one surface per
## material, for the prop scripts in this folder (pipe_run.gd, cable_run.gd, street_prop.gd).
## One mesh per prop means one draw call per material instead of one per piece.
## Not a node: a prop script makes one, adds shapes, then calls commit().
## Godot's own primitive meshes are wound correctly (clockwise front faces), and the transforms
## used here never mirror, so the result is never inside out.

var _tools := {}  # Material -> SurfaceTool


func box(mat: Material, size: Vector3, xf: Transform3D) -> void:
	var m := BoxMesh.new()
	m.size = size
	_add(mat, m, xf)


## A cylinder (or a cone, if the radii differ) standing along its local Y axis.
func cyl(mat: Material, r_top: float, r_bottom: float, height: float, xf: Transform3D, sides := 8, rings := 0) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = height
	m.radial_segments = sides
	m.rings = rings
	_add(mat, m, xf)


## A sphere, or a squashed one when height != radius * 2.
func sphere(mat: Material, radius: float, height: float, xf: Transform3D, sides := 8, rings := 4) -> void:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = sides
	m.rings = rings
	_add(mat, m, xf)


## A ring lying flat (around local Y): wheels, collars.
func ring(mat: Material, inner: float, outer: float, xf: Transform3D, sides := 12, ring_sides := 4) -> void:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = sides
	m.ring_segments = ring_sides
	_add(mat, m, xf)


## A thin box from a to b (a stick, a strut, a cable piece), `thick` metres across.
func stick(mat: Material, a: Vector3, b: Vector3, thick: float) -> void:
	var length := a.distance_to(b)
	if length < 0.001:
		return
	box(mat, Vector3(thick, length + thick * 0.5, thick), along(a, b))


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for mat in _tools:
		var st: SurfaceTool = _tools[mat]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	return mesh


## A transform whose Y axis runs from a to b, centred between them (for cylinders and sticks).
static func along(a: Vector3, b: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var ref := Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y, z), (a + b) * 0.5)


func _add(mat: Material, m: PrimitiveMesh, xf: Transform3D) -> void:
	if not _tools.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat] = st
	var tool: SurfaceTool = _tools[mat]
	tool.append_from(m, 0, xf)
