extends SceneTree
# Headless: the station's Flashlight starts off, the "flashlight" action (L / D-pad down) turns it
# on and off, the beam sits at his chest and points where the camera looks, it ignores presses
# during a story scene, and a level without the node has no torch. Prints FLASHLIGHT PASS.

var ok := true


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	ok = ok and cond


func _press() -> void:
	Input.action_press("flashlight")
	await process_frame
	await process_frame
	Input.action_release("flashlight")
	await process_frame


func _run() -> void:
	var level: Node = load("res://scenes/levels/vacuum_station.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for i in 10:
		await physics_frame
	var torch = level.get_node_or_null("Flashlight")
	_check(torch != null and torch.light != null, "the station has a Flashlight with a beam")
	if torch == null or torch.light == null:
		quit()
		return
	var player: Node3D = level.get_node("Player")
	player.in_cutscene = false
	_check(not torch.is_on(), "off when the level starts")
	_check(InputMap.has_action("flashlight"), "the flashlight action is registered")
	var keys := InputMap.action_get_events("flashlight").map(func(e: InputEvent) -> String: return e.as_text())
	print("     bound to: ", keys)
	await _press()
	_check(torch.is_on(), "L / D-pad down turns it on")
	for i in 30:
		await process_frame
	var cam: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	var beam: SpotLight3D = torch.light
	var chest: Vector3 = player.global_position + Vector3.UP * torch.chest_height
	_check(beam.global_position.distance_to(chest) < 0.6, "the beam sits at his chest (%.2f m off)" % beam.global_position.distance_to(chest))
	var fwd := -beam.global_basis.z
	var aim := -cam.global_basis.z
	_check(fwd.dot(aim) > 0.95, "it points where the camera looks (dot %.3f)" % fwd.dot(aim))
	await _press()
	_check(not torch.is_on(), "a second press turns it off")
	player.in_cutscene = true
	await _press()
	_check(not torch.is_on(), "ignored during a story scene")
	player.in_cutscene = false
	root.remove_child(level)
	level.free()
	var other: Node = load("res://scenes/levels/black_sand.tscn").instantiate()
	root.add_child(other)
	await process_frame
	_check(other.find_children("*", "SpotLight3D", true, false).filter(func(n: Node) -> bool: return n.name == "FlashlightBeam").is_empty(), "a level without the node has no torch")
	print("FLASHLIGHT PASS" if ok else "FLASHLIGHT FAIL")
	quit()
