class_name StoryFrame
extends RefCounted
## The camera for `[frame Name]` in a dialogue scene: a side-on shot of Aeneas and that node (the
## captain mid-fight), placed wherever they happen to be standing. It tries both sides and leans
## a little behind Aeneas, and keeps clear of walls (pulls in in front of them).

const NAME := "StoryFrameShot"


static func place(level: Node, player: Node3D, target: Node3D) -> Camera3D:
	var shot := level.get_node_or_null(NAME) as Camera3D
	if shot == null:
		shot = Camera3D.new()
		shot.name = NAME
		shot.fov = 50.0
		shot.far = 320.0
		level.add_child(shot)
	var a := player.global_position + Vector3.UP * 1.2
	var b := target.global_position + Vector3.UP * 1.3
	var mid := (a + b) * 0.5
	var across := b - a
	across.y = 0.0
	if across.length() < 0.1:
		across = -player.get_node("Model").global_basis.z
	var gap := across.length()
	across = across.normalized()
	var side := across.cross(Vector3.UP)
	var reach := clampf(gap * 0.9 + 2.6, 3.0, 7.0)
	var space := player.get_world_3d().direct_space_state
	var best := mid + side * 1.5
	var best_clear := -1.0
	for s in [1.0, -1.0]:
		for lean in [0.45, 0.15, 0.8]:
			var dir: Vector3 = (side * s - across * lean).normalized()
			var want := mid + dir * reach + Vector3.UP * 0.5
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(mid, want, 1))
			var clear := reach if hit.is_empty() else mid.distance_to(hit.position) - 0.35
			if clear > best_clear + 0.01:
				best_clear = clear
				best = mid + (want - mid).normalized() * maxf(clear, 1.2)
			if best_clear >= reach:
				break
		if best_clear >= reach:
			break
	shot.global_position = best
	shot.look_at(mid - Vector3.UP * 0.15, Vector3.UP)
	return shot
