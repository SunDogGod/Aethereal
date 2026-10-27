extends SceneTree
# Loads a level (OVERLAP_SCENE env, default the town) and reports every CharacterBody3D whose
# collision shape overlaps world geometry (physics layer 1), plus every patrol Marker3D whose
# standing capsule would. Headless: physics runs for a few frames first so bodies settle.

var scene_path: String = OS.get_environment("OVERLAP_SCENE") if OS.get_environment("OVERLAP_SCENE") != "" else "res://scenes/levels/empty_town.tscn"


func _initialize() -> void:
	_run()


func _run() -> void:
	var level: Node = load(scene_path).instantiate()
	root.add_child(level)
	current_scene = level
	await _frames(3)
	var space := level.get_viewport().world_3d.direct_space_state
	var bodies: Array[Node] = []
	_collect(level, bodies)
	print("bodies: ", bodies.size())
	var bad := 0
	for b in bodies:
		var body := b as CharacterBody3D
		var shape_node: CollisionShape3D = null
		for c in body.get_children():
			if c is CollisionShape3D and not c.disabled:
				shape_node = c
				break
		if shape_node == null or shape_node.shape == null:
			print("  ", level.get_path_to(body), ": no collision shape")
			continue
		var hits := _overlaps(space, shape_node.shape, shape_node.global_transform, body)
		var where := body.global_position
		if hits.is_empty():
			print("ok   ", level.get_path_to(body), "  at ", _v(where))
		else:
			bad += 1
			print("STUCK ", level.get_path_to(body), "  at ", _v(where), "  inside: ", ", ".join(hits))
		# Patrol points: would he fit standing there?
		var route := body.get_node_or_null("Route")
		if route:
			for m in route.get_children():
				if m is Marker3D:
					var cap := CapsuleShape3D.new()
					cap.radius = 0.35
					cap.height = 1.7
					var t := Transform3D(Basis(), m.global_position + Vector3(0, 0.95, 0))
					var mh := _overlaps(space, cap, t, body)
					if not mh.is_empty():
						bad += 1
						print("  ROUTE POINT ", m.name, " of ", body.name, " at ", _v(m.global_position), " inside: ", ", ".join(mh))
	print("OVERLAP CHECK DONE: %d problems" % bad)
	quit()


func _overlaps(space: PhysicsDirectSpaceState3D, shape: Shape3D, xform: Transform3D, me: Node) -> Array[String]:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = xform
	q.collision_mask = 1
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var out: Array[String] = []
	for r in space.intersect_shape(q, 16):
		var col: Node = r["collider"]
		if col == me:
			continue
		var p := str(current_scene.get_path_to(col))
		if not out.has(p):
			out.append(p)
	return out


func _collect(n: Node, into: Array[Node]) -> void:
	if n is CharacterBody3D:
		into.append(n)
	for c in n.get_children():
		_collect(c, into)


func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
