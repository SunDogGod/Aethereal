extends SceneTree
# Headless check of the capsule bed (rest_bed.gd) in the Vacuum Station:
# prompt offered / not in a fight, rest heals and saves, beats in order (training gates them),
# the dream shows and hides, Continue restores the bed's progress.

const LEVEL := "res://scenes/levels/vacuum_station.tscn"
const FILE := "res://data/dialogue/vacuum_station.txt"
const SCRATCH := "user://bed_test_saves/"

var story: Node
var level: Node3D
var player: Player
var bed: Node
var fails := 0


func _initialize() -> void:
	_run()


func check(what: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _run() -> void:
	story = root.get_node("Story")
	SaveGame.folder = SCRATCH
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))
	for f in DirAccess.get_files_at(SCRATCH):
		DirAccess.remove_absolute(SCRATCH.path_join(f))
	SaveGame.recording = true
	await _load({})
	bed = level.find_child("RestBed", true, false)
	check("RestBed exists", bed != null)
	check("EndOfAct walk-in trigger is gone", level.find_child("EndOfAct", true, false) == null)
	check("Dream set hidden at start", not level.find_child("Dream", true, false).visible)
	check("before training the bed plays rest (got %s)" % bed.next_scene(), bed.next_scene() == "rest")
	check("no double jump before training", not player.double_jump_unlocked)

	# Prompt at the bunk.
	await _stand_at_bed()
	var hud := player.get_node("Hud")
	check("prompt shown: '%s'" % hud.prompt.text, hud.prompt.visible and hud.prompt.text == "E / Up: Rest")
	# Not offered in a fight (locked on).
	var combat := player.get_node("Combat")
	var foe_script := GDScript.new()
	foe_script.source_code = "extends Node3D\nfunc can_be_locked() -> bool:\n\treturn true\n"
	foe_script.reload()
	var foe := Node3D.new()  # a stand-in enemy to lock onto
	foe.set_script(foe_script)
	level.add_child(foe)
	foe.global_position = player.global_position + Vector3(0, 0, 3)
	combat.lock_target = foe
	await _frames(3)
	check("no prompt while locked on", not hud.prompt.visible)
	combat.lock_target = null
	foe.queue_free()
	await _frames(3)

	# Rest: heals and saves.
	combat.health = 30.0
	await _use_bed("rest")
	check("rest healed him (%.0f)" % combat.health, combat.health >= combat.max_health)
	await _frames(90)
	var data := SaveGame.load_save()
	check("rest saved (reason %s, log %s)" % [data.get("reason"), data.get("story", {}).get(FILE, [])],
			data.get("reason", "") == "story" and data.get("story", {}).get(FILE, []).has("rest"))

	# Training (a trigger plays it), then the bed moves the story on.
	story.play(FILE, "training")
	await _read_all("training")
	check("after training the bed plays first_sleep (got %s)" % bed.next_scene(), bed.next_scene() == "first_sleep")
	check("training taught the double jump", player.double_jump_unlocked)
	await _stand_at_bed()
	combat.health = 40.0
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	check("first_sleep started", story.playing)
	var dream := level.find_child("Dream", true, false) as Node3D
	var orb := level.find_child("Orb0", true, false) as Node3D
	var saw_dream := false
	var saw_camera := false
	var orb_start := orb.position
	var orb_moved := false
	var presses := 0
	while story.playing and presses < 60:
		await _frames(20)
		if dream.visible:
			saw_dream = true
			if orb.position.distance_to(orb_start) > 0.01:
				orb_moved = true
		var cam := root.get_viewport().get_camera_3d()
		if cam and cam.name == "DreamShot":
			saw_camera = true
		await _press()
		print("   | %s" % story.get("_box").words.text)
		await _press()
		presses += 2
	check("the dream set showed", saw_dream)
	check("the camera cut to DreamShot", saw_camera)
	check("the orbs drift", orb_moved)
	check("dream hidden after waking", not dream.visible)
	check("orbs hidden after waking", not orb.get_parent().visible)
	check("camera back on Aeneas", root.get_viewport().get_camera_3d() == player.get_node("CameraPivot/SpringArm3D/Camera3D"))
	check("first_sleep healed him", combat.health >= combat.max_health)
	check("next is month_passes (got %s)" % bed.next_scene(), bed.next_scene() == "month_passes")
	await _frames(90)
	data = SaveGame.load_save()
	print("   save after first_sleep: %s" % data.get("story", {}))

	# Continue from that save: a fresh station, the bed remembers.
	await _load(data)
	bed = level.find_child("RestBed", true, false)
	check("Continue: bed's next is month_passes (got %s)" % bed.next_scene(), bed.next_scene() == "month_passes")
	check("Continue: Dream hidden", not level.find_child("Dream", true, false).visible)
	check("Continue: he still has the double jump", player.double_jump_unlocked)

	# month_passes, then end_of_act.
	await _use_bed("month_passes")
	check("next is end_of_act (got %s)" % bed.next_scene(), bed.next_scene() == "end_of_act")
	await _stand_at_bed()
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	var t := 0
	while t < 1200 and current_scene == level:
		await _frames(10)
		t += 10
		if story.playing:
			await _press()
	check("end_of_act went to the title screen (%s)" % (current_scene.scene_file_path if current_scene else "none"),
			current_scene != null and current_scene.scene_file_path.ends_with("title_screen.tscn"))
	print("BED TEST %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()


func _load(save: Dictionary) -> void:
	if current_scene:
		var old := current_scene
		current_scene = null
		old.queue_free()
		await _frames(2)
	level = load(LEVEL).instantiate()
	if not save.is_empty():
		SaveRestore.prepare(level, save)
	Autosave.attach(level, save)
	# Only the scenes under test play: the walk-in triggers stay quiet.
	for trig in level.get_node("StoryTriggers").get_children():
		trig.set("once", true)
		trig.call("mark_done")
	root.add_child(level)
	current_scene = level
	player = level.get_node("Player")
	await _frames(5)


func _stand_at_bed() -> void:
	player.respawn_at(Vector3(-2.1, 1.3, -52.5))
	player.model.rotation.y = PI / 2.0  # facing west, at the bunk
	await _frames(10)


func _use_bed(expect: String) -> void:
	await _stand_at_bed()
	check("bed offers %s" % expect, bed.next_scene() == expect)
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	check("%s started" % expect, story.playing)
	await _read_all(expect)


func _read_all(scene: String) -> void:
	var box = story.get("_box")
	var presses := 0
	while story.playing and presses < 60:
		await _frames(20)
		await _press()
		print("   %s | %s" % [scene, box.words.text])
		await _press()
		presses += 2
	await _frames(5)


func _press() -> void:
	Input.action_press("ui_accept")
	await process_frame
	await process_frame
	Input.action_release("ui_accept")
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
