extends SceneTree
# Generic walkthrough: WALK_LEVEL = scene path, WALK_ROUTE = JSON [[label, x, y, z], ...].
# Holds forward toward each waypoint, auto-advances any story scene, reports stuck/wrong
# height, and notices when a [level] command moves to another scene.

var story: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	story = root.get_node("Story")
	var level_path := OS.get_environment("WALK_LEVEL")
	var route: Array = JSON.parse_string(OS.get_environment("WALK_ROUTE"))
	var level: Node = load(level_path).instantiate()
	root.add_child(level)
	current_scene = level
	var player = level.get_node("Player")
	var pivot: Node3D = player.get_node("CameraPivot")
	await _frames(10)
	await _skip_story()
	if OS.get_environment("WALK_PEACEFUL") == "1":  # guards look away: tests the geometry only
		for guard in get_nodes_in_group("guards"):
			guard.dormant = true
	var start_at := OS.get_environment("WALK_START")  # optional "x,y,z" to begin elsewhere
	if start_at != "":
		var parts := start_at.split(",")
		player.respawn_at(Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float()))
		await _frames(10)
	print("start ", _fmt(player.global_position), " floor=", player.is_on_floor())
	var ok := true
	for step in route:
		var target := Vector3(step[1], step[2], step[3])
		var reached := false
		var frames := 0
		Input.action_press("move_forward")
		while frames < 1500:
			if not is_instance_valid(player):
				break
			if story.playing:
				Input.action_release("move_forward")
				await _skip_story()
				if not is_instance_valid(player) or current_scene != level:
					break
				Input.action_press("move_forward")
			var to: Vector3 = target - player.global_position
			to.y = 0.0
			if to.length() < 0.6:
				reached = true
				break
			pivot.rotation.y = atan2(-to.x, -to.z)
			await physics_frame
			frames += 1
		Input.action_release("move_forward")
		if not is_instance_valid(player) or current_scene != level:
			print("%-40s LEVEL CHANGED -> %s" % [step[0], current_scene.name if current_scene else "?"])
			break
		await _frames(10)
		var pos: Vector3 = player.global_position
		var dy: float = pos.y - target.y
		var verdict := "OK"
		if not reached:
			verdict = "STUCK"
		elif absf(dy) > 0.8 and target.y > -50.0:  # y = -99 means "any height"
			verdict = "WRONG HEIGHT"
		print("%-40s %-12s at %s (%.1fs, dy %.2f)" % [step[0], verdict, _fmt(pos), frames / 60.0, dy])
		if verdict != "OK":
			ok = false
			break
	print("ROUTE ", "COMPLETE" if ok else "FAILED")
	quit()


func _skip_story() -> void:
	var box = story.get("_box")
	var presses := 0
	while story.playing and presses < 60:
		await _frames(8)
		if box.panel.visible:
			print("   > %s%s" % [(box.speaker.text + ": ") if box.speaker.visible else "", box.words.text])
		Input.action_press("ui_accept")
		await process_frame
		await process_frame
		Input.action_release("ui_accept")
		await process_frame
		presses += 1
	if presses > 0:
		await _frames(5)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _fmt(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]
