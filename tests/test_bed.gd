extends SceneTree
# Headless check of the capsule bed (rest_bed.gd) in the Vacuum Station:
# prompt offered / not in a fight, rest heals and saves, beats in order (the launch gates them),
# the Grey night, the cube (Aether, the skill tree), buying the double jump in the pause menu,
# and Continue restoring all of it.

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
	check("Grey hidden at start", level.find_child("Grey", true, false) != null and not level.find_child("Grey", true, false).visible)
	check("before the launch the bed plays rest (got %s)" % bed.next_scene(), bed.next_scene() == "rest")
	check("no skill tree yet", not player.skills.tree_open)

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

	# The launch (a trigger plays it), then the bed moves the story on.
	story.play(FILE, "launch")
	await _read_all("launch")
	check("after the launch the bed plays first_night (got %s)" % bed.next_scene(), bed.next_scene() == "first_night")
	await _stand_at_bed()
	combat.health = 40.0
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	check("first_night started", story.playing)
	var grey := level.find_child("Grey", true, false) as Node3D
	var saw_grey := false
	var saw_camera := false
	var saw_cube := false
	var presses := 0
	while story.playing and presses < 400:
		await _frames(20)
		if grey and grey.visible:
			saw_grey = true
		if level.find_child("TrainingCube", true, false).visible:
			saw_cube = true
		var cam := root.get_viewport().get_camera_3d()
		if cam and cam.name == "GreyShot":
			saw_camera = true
		await _press()
		await _press()
		presses += 2
	check("the Grey showed", saw_grey)
	check("the camera was his eyes (GreyShot)", saw_camera)
	check("Grey hidden after", grey != null and not grey.visible)
	check("Aeneas and Kael shown again", player.visible and level.find_child("Kael", true, false).visible)
	check("the cube showed at the training", saw_cube)
	check("cube hidden after", not level.find_child("TrainingCube", true, false).visible)
	check("camera back on Aeneas", root.get_viewport().get_camera_3d() == player.get_node("CameraPivot/SpringArm3D/Camera3D"))
	check("first_night healed him", combat.health >= combat.max_health)
	check("the sacrifice gave 3 Aether (got %d)" % player.skills.aether, player.skills.aether == 3)
	check("the skill tree is open", player.skills.tree_open)
	check("no double jump until bought", not player.double_jump_unlocked)
	check("next is end_of_act (got %s)" % bed.next_scene(), bed.next_scene() == "end_of_act")

	# The pause menu's Skills page buys the double jump.
	var pause := root.get_node("PauseMenu")
	pause.open()
	await process_frame
	check("pause menu offers Skills", pause._skills_item.visible)
	pause._open_skills()
	await _frames(3)
	var page: SkillsPanel = pause._skills_page
	check("Skills page shows %s" % page._aether.text, page.visible and page._aether.text == "Aether  3")
	page._rows[0].emit_signal("pressed")
	await process_frame
	check("bought: double jump on, 0 Aether left", player.double_jump_unlocked and player.skills.aether == 0)
	check("row says owned", page._rows[0].detail == "owned")
	pause.resume()
	await _frames(3)

	# A save now keeps all of it.
	var save := SaveState.capture(level, {FILE: ["arrival", "the_ai", "launch", "first_night"]}, "story",
			player.global_transform, level)
	check("save has the progress %s" % save.get("progress"), save.get("progress", {}).get("owned", []).has("double_jump"))
	data = SaveGame._clean(JSON.parse_string(JSON.stringify(save)))

	# Continue from that save: a fresh station, everything remembered.
	await _load(data)
	bed = level.find_child("RestBed", true, false)
	check("Continue: bed's next is end_of_act (got %s)" % bed.next_scene(), bed.next_scene() == "end_of_act")
	check("Continue: Grey hidden", not level.find_child("Grey", true, false).visible)
	check("Continue: double jump, tree open, 0 Aether", player.double_jump_unlocked and player.skills.tree_open \
			and player.skills.aether == 0)

	# end_of_act.
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
