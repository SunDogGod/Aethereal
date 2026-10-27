extends SceneTree
# Edge cases: menu sounds while paused, skip during a look-at, Return to Title mid-skip,
# a tap (no skip), a hold that began before the scene, pause during a hold.

const ME := "C:/Users/ArmandoSanchez/Documents/Aethereal 3D Godot/aethereal-3d/tests/batch9/sound-skip"
const FILE := "res://data/dialogue/empty_town.txt"
var story: Node


func _initialize() -> void:
	create_timer(200.0, true, false, true).timeout.connect(func() -> void:
		print("WATCHDOG")
		quit(1))
	_run()


func _run() -> void:
	await process_frame
	story = root.get_node("Story")
	SaveGame.folder = ME + "/saves"
	# 1. Menu sounds while paused go through the pause menu's player, with the right sound.
	var p := AudioStreamPlayer.new()
	root.add_child(p)
	MenuFx.paused_player = p
	var probe := Node.new()
	root.add_child(probe)
	paused = true
	await process_frame
	await process_frame
	MenuFx.blip(probe, true)
	print("PAUSED CHOOSE: %s at %.0f dB" % [p.stream.resource_path.get_file() if p.stream else "none", p.volume_db])
	await process_frame
	MenuFx.blip(probe, false)
	print("PAUSED MOVE: %s at %.0f dB" % [p.stream.resource_path.get_file() if p.stream else "none", p.volume_db])
	paused = false
	MenuFx.paused_player = null

	var level: Node = load("res://scenes/levels/empty_town.tscn").instantiate()
	var triggers := level.get_node_or_null("StoryTriggers")
	if triggers:
		level.remove_child(triggers)
		triggers.free()
	root.add_child(level)
	current_scene = level
	await _frames(10)
	var skipper: Node = story.get("_skipper")
	var hint: Control = skipper.get("hint")

	# 2. A look-at can't be skipped.
	story.narrate(["A first thought.", "A second one."])
	await _press_and_hold(1.0)
	print("LOOK-AT: skip active %s, still playing %s, hint alpha %.2f" % [skipper.active, story.playing, hint.modulate.a])
	story.stop()
	await _frames(3)

	# 3. A tap shows the hint but doesn't skip.
	story.play(FILE, "arrival")
	await _seconds(0.3)
	await process_frame
	Input.action_press("skip_cutscene")
	await _seconds(0.15)
	Input.action_release("skip_cutscene")
	await _seconds(0.2)
	print("TAP: skip active %s, playing %s, hint alpha %.2f" % [skipper.active, story.playing, hint.modulate.a])
	await _seconds(2.5)
	print("TAP LATER: hint alpha %.2f (fades after 2 s)" % hint.modulate.a)

	# 4. Pause during a hold: no skip while paused, the hint hides.
	await process_frame
	Input.action_press("skip_cutscene")
	await _seconds(0.3)
	paused = true
	await _real(1.0)
	print("PAUSED HOLD: skip active %s, hint alpha %.2f" % [skipper.active, hint.modulate.a])
	Input.action_release("skip_cutscene")
	paused = false
	await _seconds(0.2)
	print("AFTER PAUSE: skip active %s, playing %s" % [skipper.active, story.playing])
	story.stop()
	await _frames(3)

	# 5. A hold that started before the scene doesn't skip it.
	await process_frame
	Input.action_press("skip_cutscene")
	await _seconds(0.2)
	story.play(FILE, "kael_meeting")
	await _seconds(1.2)
	print("HELD FROM BEFORE: skip active %s, playing %s" % [skipper.active, story.playing])
	Input.action_release("skip_cutscene")
	await _seconds(0.1)

	# 6. Return to Title in the middle of a skip: sound back on, screen clear, nothing left over.
	await process_frame
	Input.action_press("skip_cutscene")
	while not skipper.active:
		await process_frame
	Input.action_release("skip_cutscene")
	await _seconds(0.15)  # mid-dip
	var bus := AudioServer.get_bus_index("SFX")
	story.stop()
	await _seconds(0.5)
	print("STOP MID-SKIP: active %s, playing %s, fade %.2f, sfx muted %s" % [skipper.active, story.playing,
			story.get("_fade").color.a, AudioServer.is_bus_mute(bus)])

	# 7. A skip with Effects at 0 (bus muted by Settings) leaves it muted.
	AudioServer.set_bus_mute(bus, true)
	story.play(FILE, "round_up")
	await _seconds(0.3)
	await process_frame
	Input.action_press("skip_cutscene")
	while story.playing:
		await process_frame
	Input.action_release("skip_cutscene")
	await _seconds(0.6)
	print("SETTINGS MUTE KEPT: %s" % AudioServer.is_bus_mute(bus))
	AudioServer.set_bus_mute(bus, false)
	print("EDGES DONE")
	quit()


func _press_and_hold(seconds: float) -> void:
	await process_frame
	Input.action_press("skip_cutscene")
	await _seconds(seconds)
	Input.action_release("skip_cutscene")


func _seconds(s: float) -> void:
	await create_timer(s).timeout


func _real(s: float) -> void:
	await create_timer(s, true).timeout


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
