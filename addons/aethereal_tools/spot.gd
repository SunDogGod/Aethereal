extends RefCounted
## Finds WHERE a new thing goes: the floor in front of the editor camera, or under a node.
## It casts rays against the level's own geometry (Blocks, box shapes and terrain triangles on
## physics layer 1) in plain math, so it works the same in the editor, where physics doesn't
## run, and in headless tests. Nothing here changes the scene.

const UP := Vector3.UP
const BACK_OFF := 0.5  ## metres a thing stands out from the wall you pointed at

var _boxes: Array = []      # [Transform3D (global, inverse), Vector3 half size, the body]
var _triangles := PackedVector3Array()  # every 3 = one terrain triangle, global


## Reads the collision geometry under `root` once; the casts below reuse it.
func _init(root: Node) -> void:
	for body: Node in root.find_children("*", "StaticBody3D", true, false):
		var sb := body as StaticBody3D
		if not sb.is_inside_tree() or (sb.collision_layer & 1) == 0:
			continue
		if "size" in sb and sb.get("size") is Vector3:  # a Block: its box is its size
			_boxes.append([sb.global_transform.affine_inverse(), (sb.get("size") as Vector3) * 0.5, sb])
			continue
		for child: Node in sb.get_children():
			var cs := child as CollisionShape3D
			if cs == null or cs.disabled or cs.shape == null:
				continue
			if cs.shape is BoxShape3D:
				_boxes.append([cs.global_transform.affine_inverse(), (cs.shape as BoxShape3D).size * 0.5, sb])
			elif cs.shape is ConcavePolygonShape3D:
				var xf := cs.global_transform
				for p: Vector3 in (cs.shape as ConcavePolygonShape3D).get_faces():
					_triangles.append(xf * p)


## The nearest surface between two points: {position, normal} or {} for none.
## A box the ray starts inside is skipped (so a ray from inside a selected Block still works).
func cast(from: Vector3, to: Vector3) -> Dictionary:
	var best_t := INF
	var best := {}
	for box: Array in _boxes:
		var inv: Transform3D = box[0]
		var half: Vector3 = box[1]
		var hit := _segment_box(inv * from, inv * to, half)
		if not hit.is_empty() and hit.t < best_t:
			best_t = hit.t
			var normal: Vector3 = (inv.basis.transposed() * (hit.normal as Vector3)).normalized()
			best = {"position": from.lerp(to, hit.t), "normal": normal, "collider": box[2]}
	for i in range(0, _triangles.size() - 2, 3):
		var p: Variant = Geometry3D.segment_intersects_triangle(from, to, _triangles[i], _triangles[i + 1], _triangles[i + 2])
		if p == null:
			continue
		var t: float = from.distance_to(p) / maxf(from.distance_to(to), 0.0001)
		if t < best_t:
			best_t = t
			var n := (_triangles[i + 1] - _triangles[i]).cross(_triangles[i + 2] - _triangles[i]).normalized()
			if n.dot(from - to) < 0.0:
				n = -n  # face the ray, whichever way the triangle was wound
			best = {"position": p, "normal": n}
	return best


## The floor under a point (searching `depth` metres down), or null.
func floor_below(point: Vector3, depth := 60.0) -> Variant:
	var hit := cast(point + UP * 0.05, point - UP * depth)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.3:
		return null
	return hit.position


## Where the editor camera is looking. Returns:
##   floor   a point on the floor (near what you looked at)
##   surface the point you looked at (a wall, a floor, or 8 m ahead when nothing is there)
##   normal  that surface's outward direction (UP for a floor)
##   wall    true if you looked at a wall
##   facing  the camera's direction, flattened (things placed "face away from you" along it)
func from_view(cam: Transform3D) -> Dictionary:
	var from := cam.origin
	var dir := -cam.basis.z.normalized()
	var facing := _flat(dir, Vector3.FORWARD)
	var hit := cast(from, from + dir * 80.0)
	if hit.is_empty():
		var ahead := from + dir * 8.0
		var below: Variant = floor_below(ahead + UP * 0.5)
		var spot: Vector3 = below if below != null else ahead
		return {"floor": spot, "surface": spot, "normal": UP, "wall": false, "facing": facing}
	var n: Vector3 = hit.normal
	var p: Vector3 = hit.position
	if n.y > 0.6:
		return {"floor": p, "surface": p, "normal": n, "wall": false, "facing": facing}
	# A wall (or a ceiling): stand a little way out from it and find the floor there.
	var out := _flat(n, -facing) if absf(n.y) < 0.9 else -facing
	var stand := p + out * BACK_OFF
	var ground: Variant = floor_below(stand + UP * 0.2)
	return {"floor": ground if ground != null else stand, "surface": p, "normal": n,
			"wall": absf(n.y) < 0.5, "facing": facing}


## At a node: on top of a selected Block, otherwise on the floor under the node.
func from_node(node: Node3D) -> Dictionary:
	var p := node.global_position
	var facing := _flat(-node.global_basis.z, Vector3.FORWARD)
	var spot := p
	if "size" in node and node.get("size") is Vector3:
		spot = p + node.global_basis.y * (node.get("size") as Vector3).y * 0.5  # its top
	else:
		var below: Variant = floor_below(p + UP * 0.5)
		if below != null:
			spot = below
	return {"floor": spot, "surface": spot, "normal": UP, "wall": false, "facing": facing,
			"from_selection": true}


## The ceiling over a point (up to `height` metres), or null.
func ceiling_above(point: Vector3, height := 8.0) -> Variant:
	var hit := cast(point + UP * 0.2, point + UP * height)
	if hit.is_empty() or (hit.normal as Vector3).y > -0.3:
		return null
	return hit.position


static func _flat(v: Vector3, fallback: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length() > 0.01 else fallback


## Segment against a box centred on the origin (slab test). {t, normal} or {}.
static func _segment_box(a: Vector3, b: Vector3, half: Vector3) -> Dictionary:
	if absf(a.x) < half.x and absf(a.y) < half.y and absf(a.z) < half.z:
		return {}  # starts inside this box
	var d := b - a
	var t_in := 0.0
	var t_out := 1.0
	var normal := Vector3.ZERO
	for axis in 3:
		if absf(d[axis]) < 0.000001:
			if absf(a[axis]) > half[axis]:
				return {}
			continue
		var t1 := (-half[axis] - a[axis]) / d[axis]
		var t2 := (half[axis] - a[axis]) / d[axis]
		var sign_in := -1.0
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
			sign_in = 1.0
		if t1 > t_in:
			t_in = t1
			normal = Vector3.ZERO
			normal[axis] = sign_in
		t_out = minf(t_out, t2)
		if t_in > t_out:
			return {}
	if normal == Vector3.ZERO:
		return {}
	return {"t": t_in, "normal": normal}
