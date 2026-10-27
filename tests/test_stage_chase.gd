extends SceneTree
# Headless: with Aeneas at the back corner of the stage, do the fighters find the stage ramp
# and reach him? Runs the captain fight, then (fresh level) the hall fight. Env CHASE_FIGHT
# picks one ("CaptainFight" or "HallFight"); default runs CaptainFight.

func _initialize() -> void:
	_run()


func _run() -> void:
	var fight_name := OS.get_environment("CHASE_FIGHT")
	if fight_name == "":
		fight_name = "CaptainFight"
	var level: Node = load("res://scenes/levels/empty_town.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player: Player = level.get_node("Player")
	var combat = player.get_node("Combat")
	for i in 20:
		await physics_frame
	var story := root.get_node("Story")
	while story.playing:  # the arrival scene: skip it
		story.call("_finish") if story.has_method("_finish") else null
		Input.action_press("ui_accept")
		await process_frame
		await process_frame
		Input.action_release("ui_accept")
		await process_frame
	var target := Vector3(5, 1.25, -26.8)
	if OS.get_environment("CHASE_AT") != "":
		var p := OS.get_environment("CHASE_AT").split(",")
		target = Vector3(float(p[0]), float(p[1]), float(p[2]))
	var close_samples := 0
	var samples := 0
	var closest := 99.0
	player.respawn_at(target)
	player.controls_enabled = false
	for i in 10:
		await physics_frame
	var fight: Node = level.get_node(fight_name)
	fight.start()
	for i in 400:  # a story trigger here (the courtyard) plays its scene first: skip it
		if not story.playing:
			break
		Input.action_press("ui_accept")
		await process_frame
		await process_frame
		Input.action_release("ui_accept")
		await process_frame
	var reached := {}
	for second in 25:
		for i in 60:
			combat.health = 1000.0  # he stands still and must not die
			await physics_frame
		var gs: Array = []
		for g in fight.get_children():
			if g is Guard and g.state != Guard.State.DOWN:
				gs.append(g)
		var near := 99.0
		for a in gs.size():
			for b in range(a + 1, gs.size()):
				var ga: Node3D = gs[a]
				var gb: Node3D = gs[b]
				near = minf(near, Vector2(ga.global_position.x - gb.global_position.x, ga.global_position.z - gb.global_position.z).length())
		if gs.size() > 1:
			samples += 1
			closest = minf(closest, near)
			if near < 0.6:
				close_samples += 1
		var parts := []
		for g in fight.get_children():
			if not (g is Guard):
				continue
			var d := Vector2(g.global_position.x - player.global_position.x, g.global_position.z - player.global_position.z).length()
			var dy: float = absf(g.global_position.y - player.global_position.y)
			if d < 2.2 and dy < 0.6 and not reached.has(g.name):
				reached[g.name] = second + 1
			parts.append("%s (%.1f, %.1f, %.1f) %.1fm" % [g.name, g.global_position.x, g.global_position.y, g.global_position.z, d])
		if second % 5 == 4:
			print("t=%2ds  %s" % [second + 1, " | ".join(parts)])
	var total := 0
	for g in fight.get_children():
		if g is Guard:
			total += 1
	print("%s: %d of %d reached Aeneas on the stage: %s" % [fight_name, reached.size(), total, reached])
	print("MERGE: agents closer than 0.6 m in %d of %d samples; closest %.2f m" % [close_samples, samples, closest])
	print("STAGE CHASE %s" % ("PASS" if reached.size() == total else "FAIL"))
	quit()
