extends SceneTree
# Prop audit, part 4 (read-only): CLIP = a prop and a block of ANOTHER group pass through each
# other: the intersection is at least 4 cm deep on every axis of the overlap and holds more than
# 0.002 m3 (sampled on a 4 cm grid inside the smaller of the two). Same-group pairs (a duct and
# its own straps) are skipped. Barrels count as boxes.
const SCENE := "res://scenes/levels/empty_town.tscn"
const PROP_ROOTS := ["Dressing", "Dressing2", "Ducts", "Life", "Inspect"]


class Box:
	var path: String
	var group: String
	var is_prop: bool
	var xf: Transform3D  # orthonormal
	var half: Vector3
	var aabb: AABB
	var vol: float


var level: Node
var boxes: Array[Box] = []


func _initialize() -> void:
	level = load(SCENE).instantiate()
	root.add_child(level)
	for i in 3:
		await physics_frame
	for n in _all(level, []):
		if n is StaticBody3D and n.is_visible_in_tree():
			var b := _make(n)
			if b:
				boxes.append(b)
	var reported := 0
	for p in boxes:
		if not p.is_prop:
			continue
		for o in boxes:
			if o == p or o.group == p.group or (o.is_prop and o.path < p.path):
				continue
			var lap := p.aabb.intersection(o.aabb)
			if lap.size.x < 0.04 or lap.size.y < 0.04 or lap.size.z < 0.04:
				continue
			# Sample the smaller box on a 4 cm grid, count points inside the other.
			var small: Box = p if p.vol <= o.vol else o
			var big: Box = o if small == p else p
			var cnt := 0
			var tot := 0
			var nx := clampi(ceili(small.half.x * 2.0 / 0.04), 1, 40)
			var ny := clampi(ceili(small.half.y * 2.0 / 0.04), 1, 40)
			var nz := clampi(ceili(small.half.z * 2.0 / 0.04), 1, 40)
			var cell := small.vol / (nx * ny * nz)
			for i in nx:
				for j in ny:
					for k in nz:
						var l := Vector3((i + 0.5) / nx * 2.0 - 1.0, (j + 0.5) / ny * 2.0 - 1.0, (k + 0.5) / nz * 2.0 - 1.0) * small.half
						var w: Vector3 = small.xf * l
						tot += 1
						var lb: Vector3 = big.xf.affine_inverse() * w
						if absf(lb.x) < big.half.x and absf(lb.y) < big.half.y and absf(lb.z) < big.half.z:
							cnt += 1
			var v := cnt * cell
			if v > 0.002:
				reported += 1
				print("CLIP %-34s x %-34s %.3f m3 (%3.0f%% of %s), overlap %s..%s" % [p.path, o.path, v, 100.0 * cnt / tot, small.path.get_file(), _v(lap.position), _v(lap.end)])
	print("CLIP pairs: ", reported)
	quit()


func _make(body: StaticBody3D) -> Box:
	var b := Box.new()
	b.path = str(level.get_path_to(body))
	var xf: Transform3D
	var size := Vector3.ZERO
	if body is Block:
		xf = body.global_transform
		size = body.size
	else:
		for c in body.get_children():
			if c is CollisionShape3D and c.shape:
				xf = c.global_transform
				if c.shape is BoxShape3D:
					size = c.shape.size
				elif c.shape is CylinderShape3D:
					size = Vector3(c.shape.radius * 2.0, c.shape.height, c.shape.radius * 2.0)
	if size == Vector3.ZERO:
		return null
	b.half = size * 0.5 * xf.basis.get_scale().abs()
	b.xf = xf.orthonormalized()
	b.vol = b.half.x * b.half.y * b.half.z * 8.0
	b.aabb = AABB(b.xf.origin, Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				b.aabb = b.aabb.expand(b.xf * (Vector3(sx, sy, sz) * b.half))
	var w: Node = body
	while w.get_parent() != level:
		if w.get_parent().get_parent() == level and PROP_ROOTS.has(w.get_parent().name):
			b.group = str(level.get_path_to(w))
			b.is_prop = true
		w = w.get_parent()
	if PROP_ROOTS.has(w.name) and not b.is_prop:
		b.is_prop = true
		b.group = b.path
	if not b.is_prop:
		b.group = b.path
	return b


func _all(n: Node, out: Array) -> Array:
	for c in n.get_children():
		out.append(c)
		_all(c, out)
	return out


func _v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]
