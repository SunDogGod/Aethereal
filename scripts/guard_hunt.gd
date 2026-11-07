extends RefCounted
## An agent with Guard.hunts on (the Massacre's chase): while he is shown and no story scene plays,
## he runs at Aeneas, along the level's navigation mesh when it has one (straight at him when it
## has none), and a grab within CATCH metres is the same restart as being spotted. A four-year-old
## can't fight back: hunters ignore hits, lock-on and takedowns (guard.gd checks `hunts`).

const CATCH := 0.95  ## metres between them (centre to centre) that count as a grab


static func tick(g: Guard, delta: float) -> void:
	var p: Player = g._player
	if p == null or not g.is_visible_in_tree() or p.in_cutscene or not p.controls_enabled or g.state == Guard.State.SPOTTED:
		g._stop()  # a scene, a restart under way, or not on stage yet
		return
	g.suspicion = 1.0  # he knows exactly where the child is
	var to := p.global_position - g.global_position
	to.y = 0.0
	if to.length() < CATCH:
		g._stop()
		g._spot()  # the director fades out and puts everyone back
		return
	var dir := _towards(g, p.global_position)
	if dir == Vector3.ZERO:
		dir = to.normalized()
	g.velocity.x = dir.x * g.hunt_speed
	g.velocity.z = dir.z * g.hunt_speed
	g._turn_to(atan2(-dir.x, -dir.z), delta)


## Which way to run: the first corner of the navigation path, or nothing if there is no mesh.
static func _towards(g: Guard, target: Vector3) -> Vector3:
	var map := g.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return Vector3.ZERO
	var path := NavigationServer3D.map_get_path(map, g.global_position, target, true)
	for point in path:
		var d := point - g.global_position
		d.y = 0.0
		if d.length() > 0.3:
			return d.normalized()
	return Vector3.ZERO
