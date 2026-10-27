extends RefCounted
## Build Mode's mouse picking: what a ray from the camera hits, worked out from the meshes
## themselves (not physics), so it finds things with no collision too (lamps, decals, trims)
## and works while the game is paused. Things you can't see (lights, sounds, zones, particles)
## get a small box at their origin, drawn as a marker by build_gizmo.gd.
##   cast(root, from, dir)  -> {node, position, normal, distance} of the nearest hit, or {}

const PROXY := 0.35        ## half size of the box an invisible thing is picked by
const PROXY_RANGE := 90.0  ## invisible things further than this aren't offered
const REACH := 600.0


## The nearest thing along the ray under `root` (skipping hidden nodes and `skip` subtrees).
static func cast(root: Node, from: Vector3, dir: Vector3, skip: Array = [], with_proxies := true) -> Dictionary:
	var best := {}
	var stack: Array[Node] = [root]
	dir = dir.normalized()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n in skip:
			continue
		if n is Node3D and not (n as Node3D).visible:
			continue
		if n is CanvasItem or n is Viewport:
			continue
		var hit := {}
		if n is MeshInstance3D:
			hit = _mesh_hit(n, from, dir)
		elif n is MultiMeshInstance3D or n is CSGShape3D:
			hit = _box_hit(n, (n as VisualInstance3D).get_aabb(), from, dir)
		elif with_proxies and is_proxy(n) and (n as Node3D).global_position.distance_to(from) < PROXY_RANGE:
			hit = _box_hit(n, AABB(Vector3.ONE * -PROXY, Vector3.ONE * PROXY * 2.0), from, dir, true)
		if not hit.is_empty() and (best.is_empty() or hit.distance < best.distance):
			best = hit
		for child in n.get_children(true):
			stack.append(child)
	return best


## An invisible thing that gets a picking box and a marker.
static func is_proxy(n: Node) -> bool:
	return n is Light3D or n is Decal or n is AudioStreamPlayer3D or n is Area3D \
			or n is GPUParticles3D or n is CPUParticles3D or (n is Camera3D and n.get_parent() and n.get_parent().name == &"Shots")


static func _mesh_hit(mi: MeshInstance3D, from: Vector3, dir: Vector3) -> Dictionary:
	var mesh := mi.mesh
	if mesh == null or not _in_range(mi, from):
		return {}
	var xf := mi.global_transform
	var inv := xf.affine_inverse()
	var o := inv * from
	var d := inv.basis * dir
	if mesh.get_aabb().grow(0.01).intersects_ray(o, d) == null:
		return {}
	var tri := mesh.generate_triangle_mesh()
	if tri == null:
		return {}
	# Only the sides you can see count: surfaces are drawn one-sided (cull_back), so a ray
	# that meets the back of a face (from inside a box, a hidden wall) goes on past it.
	var two_sided := _two_sided(mi)
	var start := o
	var normal := Vector3.ZERO
	var at := Vector3.ZERO
	var found := false
	for i in 12:
		var r := tri.intersect_ray(start, d)
		if r.is_empty():
			return {}
		at = xf * (r.position as Vector3)
		normal = (xf.basis.inverse().transposed() * _front(tri, int(r.face_index), r.normal)).normalized()
		if normal.dot(dir) < 0.0:
			found = true
			break
		if two_sided:
			normal = -normal
			found = true
			break
		start = (r.position as Vector3) + d.normalized() * 0.001
	if not found:
		return {}
	var dist := from.distance_to(at)
	return {} if dist > REACH else {"node": mi, "position": at, "normal": normal, "distance": dist}


static func _box_hit(n: Node3D, box: AABB, from: Vector3, dir: Vector3, proxy := false) -> Dictionary:
	if box.size == Vector3.ZERO:
		return {}
	var xf := n.global_transform if not proxy else Transform3D(Basis(), n.global_position)
	var inv := xf.affine_inverse()
	var local: Variant = box.intersects_ray(inv * from, inv.basis * dir)
	if local == null:
		return {}
	var at: Vector3 = xf * (local as Vector3)
	var dist := from.distance_to(at)
	return {} if dist > REACH else {"node": n, "position": at, "normal": -dir, "distance": dist, "proxy": proxy}


static var _faces := {}  # TriangleMesh id -> [weakref, its faces] (get_faces() copies each call)


## The face's front side (Godot: clockwise seen from the front). TriangleMesh's own normal
## just points back at the ray, so it can't tell the front from the back.
static func _front(tri: TriangleMesh, face: int, fallback: Vector3) -> Vector3:
	var id := tri.get_instance_id()
	if not _faces.has(id) or (_faces[id][0] as WeakRef).get_ref() != tri:
		_faces[id] = [weakref(tri), tri.get_faces()]
	var f: PackedVector3Array = _faces[id][1]
	if face < 0 or face * 3 + 2 >= f.size():
		return fallback
	return Plane(f[face * 3], f[face * 3 + 1], f[face * 3 + 2]).normal


## True when the mesh is drawn from both sides (a shader with cull_disabled).
static func _two_sided(mi: MeshInstance3D) -> bool:
	var mat := mi.material_override
	if mat == null and mi.mesh.get_surface_count() > 0:
		mat = mi.get_active_material(0)
	var shader := (mat as ShaderMaterial).shader if mat is ShaderMaterial else null
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED
	return shader != null and shader.code.contains("cull_disabled")


## False when the mesh has faded out at this distance (props with a draw distance).
static func _in_range(g: GeometryInstance3D, from: Vector3) -> bool:
	return g.visibility_range_end <= 0.0 or g.global_position.distance_to(from) <= g.visibility_range_end
