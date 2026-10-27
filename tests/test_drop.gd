extends SceneTree
# Headless: jump off the overlook balcony into the light well (a 24 m drop to the courtyard).
# It should count as a fall: the FELL card, and Aeneas back at his last checkpoint, not in the
# courtyard. Isabella should come back beside him, standing on the floor.

func _initialize() -> void:
	_run()


func _run() -> void:
	var level: Node = load("res://scenes/levels/empty_town.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player: Player = level.get_node("Player")
	var story := root.get_node("Story")
	for i in 20:
		await physics_frame
	while story.playing:
		Input.action_press("ui_accept")
		await process_frame
		await process_frame
		Input.action_release("ui_accept")
		await process_frame
	# Env DROP_CP: the checkpoint to touch first; DROP_FROM, DROP_YAW: where to jump from, facing.
	var cp := _vec(OS.get_environment("DROP_CP"), Vector3(0, 24, 12))
	var from := _vec(OS.get_environment("DROP_FROM"), Vector3(0, 24, 7.0))
	var yaw := float(OS.get_environment("DROP_YAW")) if OS.get_environment("DROP_YAW") != "" else 0.0
	player.respawn_at(cp)
	for i in 30:
		await physics_frame
	while story.playing:  # the round-up plays on the rim now
		Input.action_press("ui_accept")
		await process_frame
		await process_frame
		Input.action_release("ui_accept")
		await process_frame
	player.respawn_at(from)
	var pivot: Node3D = player.get_node("CameraPivot")
	pivot.rotation.y = yaw
	for i in 10:
		await physics_frame
	var msg: Label = level.get_node("StealthDirector/Screen/Message")
	var saw_card := ""
	var lowest := 99.0
	Input.action_press("move_forward")
	Input.action_press("jump")
	for i in 400:
		await physics_frame
		if i == 20:
			Input.action_release("jump")
		lowest = minf(lowest, player.global_position.y)
		if msg.visible and saw_card == "":
			saw_card = msg.text
		if saw_card != "" and i > 120 and player.controls_enabled:
			break
	Input.action_release("move_forward")
	for i in 30:
		await physics_frame
	var isa: Node3D = level.get_node("Isabella")
	var q := PhysicsRayQueryParameters3D.create(isa.global_position + Vector3.UP * 0.5, isa.global_position + Vector3.DOWN * 3.0, 1)
	var hit := level.get_viewport().world_3d.direct_space_state.intersect_ray(q)
	var gap: float = isa.global_position.y - (hit.position.y if not hit.is_empty() else -99.0)
	print("DROP: lowest y %.1f, card '%s', Aeneas now at (%.1f, %.1f, %.1f), Isabella %.2f m above the floor" % [lowest, saw_card, player.global_position.x, player.global_position.y, player.global_position.z, gap])
	var back: bool = player.global_position.distance_to(cp) < 1.5
	print("DROP %s" % ("PASS" if saw_card == "FELL" and back and absf(gap) < 0.1 else "FAIL"))
	quit()


func _vec(s: String, fallback: Vector3) -> Vector3:
	if s == "":
		return fallback
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
