extends SceneTree
# Details for the prop audit (read-only): world AABBs of named blocks, every wall-mounted unit
# group's distance to the wall behind it (ray along the group's -Z from in front of the unit,
# ignoring the group's own bodies), and the bodies around a few suspicious points.
const SCENE := "res://scenes/levels/empty_town.tscn"
const NAMES := ["SouthDistrict/Tower2", "SouthDistrict/Tower3", "SouthDistrict/Tower4", "SouthDistrict/GateArch",
	"EastDistrict/Tower5", "EastDistrict/Tower6", "EastDistrict/Tower6b", "WestDistrict/Tower7", "WestDistrict/Tower8",
	"WestDistrict/Tower9", "WestDistrict/Tower10", "WestDistrict/AlleyCrate2", "WestDistrict/SignTower7",
	"SouthDistrict/SignRimAmber", "Courtyard/RampDown", "NorthDistrict/HallRoof", "WestDistrict/Foundation",
	"EastDistrict/Foundation", "SouthDistrict/Foundation"]  # the old Rim and Deck blocks are gone
const PROBES := [["AlleyAC2 centre", Vector3(-20.15, 13.0, 0.5)], ["RimSign", Vector3(10, 28, 13.9)],
	["RimPhone", Vector3(23.4, 25, 14.15)], ["DeckBarrels", Vector3(13.3, 16.5, 7.2)]]

var level: Node


func _initialize() -> void:
	level = load(SCENE).instantiate()
	root.add_child(level)
	for i in 5:
		await physics_frame
	for n in NAMES:
		var b: Node = level.get_node_or_null(n)
		if b == null:
			print("no ", n)
			continue
		print("BLOCK %-28s %s" % [n, _aabb(b)])
	var space: PhysicsDirectSpaceState3D = level.get_viewport().world_3d.direct_space_state
	# Every Node3D group with a "Unit" child (the AC units).
	for g in _all(level, []):
		if not (g is Node3D) or g.get_node_or_null("Unit") == null or not (g.get_node("Unit") is Block):
			continue
		var excl: Array[RID] = []
		for c in g.get_children():
			if c is CollisionObject3D:
				excl.append(c.get_rid())
		var gx: Transform3D = g.global_transform
		var out_dir: Vector3 = gx.basis.z.normalized()
		var from: Vector3 = gx.origin + out_dir * 0.45
		var q := PhysicsRayQueryParameters3D.create(from, from - out_dir * 3.0, 1)
		q.exclude = excl
		var r := space.intersect_ray(q)
		var txt := "no wall within 2.55 m behind"
		if not r.is_empty():
			var t: float = (r["position"] - from).length()
			var wall: float = 0.45 - t  # wall plane along out_dir relative to the unit's back
			var hit: Node = r["collider"]
			if wall < -0.005:
				txt = "AIR GAP %.2f m between the unit's back and %s" % [-wall, level.get_path_to(hit)]
			elif wall > 0.005:
				txt = "SUNK %.2f m of its 0.40 m depth into %s" % [wall, level.get_path_to(hit)]
			else:
				txt = "flush on %s" % level.get_path_to(hit)
		print("UNIT %-18s origin %s faces %s: %s" % [level.get_path_to(g), _v(gx.origin), _v(out_dir), txt])
	for p in PROBES:
		var pq := PhysicsShapeQueryParameters3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 1.6
		pq.shape = sh
		pq.transform = Transform3D(Basis(), p[1])
		var names: Array[String] = []
		for r in space.intersect_shape(pq, 32):
			var col: Node = r["collider"]
			names.append("%s %s" % [level.get_path_to(col), _aabb(col)])
		print("NEAR %s %s:" % [p[0], _v(p[1])])
		for s in names:
			print("     ", s)
	quit()


func _aabb(n: Node) -> String:
	if n is Block:
		var xf: Transform3D = n.global_transform
		var a := AABB(xf.origin, Vector3.ZERO)
		var h: Vector3 = n.size * 0.5
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					a = a.expand(xf * Vector3(h.x * sx, h.y * sy, h.z * sz))
		return "%s..%s" % [_v(a.position), _v(a.end)]
	return "(%s at %s)" % [n.get_class(), _v(n.global_position)]


func _all(n: Node, out: Array) -> Array:
	for c in n.get_children():
		out.append(c)
		_all(c, out)
	return out


func _v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]
