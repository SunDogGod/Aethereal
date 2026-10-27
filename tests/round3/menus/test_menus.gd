extends SceneTree
# Headless test of the menus (works windowed too): title -> New Game -> Empty Town; pause and
# resume during the arrival scene (tree paused, dialogue frozen, mouse mode); the settings page;
# Return to Title through the question; Continue; pausing during the death fade; the camera
# reading invert Y; settings persisting across a reload. Restores your settings.cfg; saves go to a
# scratch folder (SaveGame.folder), never to your real save.

const TOWN := "res://scenes/levels/empty_town.tscn"
const FILES := ["user://settings.cfg"]
const SAVES := "C:/Users/ArmandoSanchez/Documents/Aethereal 3D Godot/aethereal-3d/tests/round3/menus/saves"

var fails := 0
var story: Node
var pause: Node
var _saved := {}


func _initialize() -> void:
	_run()


func _run() -> void:
	for f: String in FILES:
		_saved[f] = FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else null
	SaveGame.folder = SAVES  # start with no save, and never touch the real one
	DirAccess.make_dir_recursive_absolute(SAVES)
	for f in DirAccess.get_files_at(SAVES):
		DirAccess.remove_absolute(SAVES.path_join(f))
	story = root.get_node("Story")
	pause = root.get_node("PauseMenu")

	# 1. The title screen.
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await _frames(5)
	_check("title screen is up", current_scene != null and current_scene.is_in_group("title_screen"))
	var names := _names(current_scene.get_node("Main"))
	_check("no save: no Continue %s" % [names], names == ["NewGame", "Chapters", "Settings", "Quit"])
	_check("New Game has the focus", root.gui_get_focus_owner() == current_scene.find_child("NewGame", true, false))
	await _press("pause")
	_check("pause stays shut on the title", not paused and not pause.is_open)
	_choose(current_scene, "Chapters")
	await _frames(3)
	var chapters: Control = current_scene.get_node("Chapters")
	_check("chapters page shows %d chapters + Back" % Chapters.LIST.size(),
			chapters.visible and _names(chapters.get_node("List")).size() == Chapters.LIST.size() + 1)
	await _press("ui_cancel")
	_check("Esc closes the chapters page, Chapters has the focus", not chapters.visible
			and root.gui_get_focus_owner() == current_scene.find_child("Chapters", true, false))
	_choose(current_scene, "Settings")
	await _frames(3)
	_check("settings page opens on the title", current_scene.get_node("Settings").visible)
	await _press("ui_cancel")
	_check("Esc closes it again", not current_scene.get_node("Settings").visible)

	# 2. New Game.
	_item(current_scene, "NewGame").pressed.emit()
	await _until(func() -> bool: return current_scene != null and (current_scene.scene_file_path in [TOWN, "res://scenes/world/world.tscn"]), 900)
	_check("New Game loads the Empty Town", (current_scene.scene_file_path in [TOWN, "res://scenes/world/world.tscn"]))
	_check("Continue now points at the Empty Town", SaveGame.last_level() == TOWN)

	# 3. Pause during the arrival scene.
	await _until(func() -> bool: return story.playing, 120)
	_check("the arrival scene is playing", story.playing)
	var box = story.get("_box")
	await _frames(5)
	await _press("pause")
	_check("pause opens and pauses the tree", paused and pause.is_open)
	_check("mouse freed (asked %d, actual %d)" % [pause.mouse_wanted, Input.mouse_mode],
			pause.mouse_wanted == Input.MOUSE_MODE_VISIBLE and _mouse_ok(Input.MOUSE_MODE_VISIBLE))
	_check("Resume has the focus", root.gui_get_focus_owner() == pause.find_child("Resume", true, false))
	var shown: int = box.words.visible_characters
	Input.action_press("ui_accept")
	await _frames(30)
	Input.action_release("ui_accept")
	_check("dialogue frozen while paused (%d -> %d chars)" % [shown, box.words.visible_characters],
			box.words.visible_characters == shown and story.playing)
	await _press("pause")
	_check("pause again resumes", not paused and not pause.is_open)
	_check("mouse captured again (asked %d)" % pause.mouse_wanted,
			pause.mouse_wanted == Input.MOUSE_MODE_CAPTURED and _mouse_ok(Input.MOUSE_MODE_CAPTURED))
	await _frames(20)
	_check("dialogue goes on after resume", box.words.visible_characters != shown or box.next_mark.visible)

	# 4. The settings page inside the pause menu.
	await _press("pause")
	_choose(pause, "Settings")
	await _frames(3)
	var settings: Control = pause.get_node("Root/Settings")
	_check("settings page opens in the pause menu", settings.visible and paused)
	await _press("ui_cancel")
	_check("Esc goes back to the pause list", not settings.visible and pause.is_open
			and root.gui_get_focus_owner() == pause.find_child("Settings", true, false))

	# 5. Return to Title, through the question.
	_choose(pause, "ReturntoTitle")
	await _frames(3)
	var confirm: Control = pause.get_node("Root/Confirm")
	_check("Return to Title asks first, No has the focus", confirm.visible
			and root.gui_get_focus_owner() == pause.find_child("No", true, false))
	await _press("ui_cancel")
	_check("Esc on the question means No", not confirm.visible and pause.is_open and paused)
	_choose(pause, "ReturntoTitle")
	await _frames(2)
	_item(pause, "Yes").pressed.emit()
	await _until(func() -> bool: return current_scene != null and current_scene.is_in_group("title_screen"), 200)
	await _frames(3)
	_check("back on the title screen", current_scene.is_in_group("title_screen"))
	_check("unpaused, menu shut, black overlay gone", not paused and not pause.is_open
			and pause.get_node("Black").color.a == 0.0)
	_check("story stopped and its screen cleared", not story.playing
			and story.get("_fade").color.a == 0.0 and not box.panel.visible)
	_check("Continue is offered: %s" % [_names(current_scene.get_node("Main"))],
			_names(current_scene.get_node("Main"))[0] == "Continue")

	# 6. Continue: the arrival scene plays again and reads to the end (the stopped one stays dead).
	_item(current_scene, "Continue").pressed.emit()
	await _until(func() -> bool: return current_scene != null and (current_scene.scene_file_path in [TOWN, "res://scenes/world/world.tscn"]), 900)
	await _until(func() -> bool: return story.playing, 120)
	_check("Continue loads the town and the scene plays", (current_scene.scene_file_path in [TOWN, "res://scenes/world/world.tscn"]) and story.playing)
	var presses := 0
	while story.playing and presses < 60:
		await _press("ui_accept")
		await _frames(4)
		presses += 1
	await _frames(5)
	var player: Node = current_scene.get_node("Player")
	_check("scene read to the end, controls back (%d presses)" % presses, not story.playing and player.controls_enabled)

	# 7. Pausing during the death fade.
	var director: Node = current_scene.get_node("StealthDirector")
	var fade: ColorRect = director.get_node("Screen/Fade")
	director.restart("FELL")
	await _until(func() -> bool: return fade.color.a > 0.2, 600)
	await _press("pause")
	var alpha := fade.color.a
	await create_timer(0.5).timeout  # a timer that runs while paused
	_check("death fade frozen while paused (alpha %.2f -> %.2f)" % [alpha, fade.color.a], paused and fade.color.a == alpha)
	await _press("pause")
	await _until(func() -> bool: return fade.color.a == 0.0 and player.controls_enabled, 600)
	_check("death fade finishes after resume", fade.color.a == 0.0 and player.controls_enabled and not paused)

	# 8. The camera reads invert Y from GameSettings.
	var cam: Node3D = player.get_node("CameraPivot")
	var arm: Node3D = cam.get_node("SpringArm3D")
	var turns := []
	for invert in [false, true]:
		GameSettings.invert_y = invert
		arm.rotation.x = deg_to_rad(-20.0)
		Input.action_press("camera_up")
		await _frames(4)
		Input.action_release("camera_up")
		turns.append(arm.rotation.x - deg_to_rad(-20.0))
	_check("invert Y flips the stick's pitch (%.3f vs %.3f)" % [turns[0], turns[1]],
			signf(turns[0]) == -signf(turns[1]) and turns[0] != 0.0)

	# 9. Settings persist across a reload.
	GameSettings.master_volume = 0.35
	GameSettings.mouse_sensitivity = 1.7
	GameSettings.stick_sensitivity = 0.6
	GameSettings.invert_y = true
	GameSettings.fullscreen = false
	GameSettings.save_file()
	GameSettings.reset()
	GameSettings.load_file()
	_check("settings persist (%.2f %.2f %.2f %s)" % [GameSettings.master_volume, GameSettings.mouse_sensitivity,
			GameSettings.stick_sensitivity, GameSettings.invert_y], is_equal_approx(GameSettings.master_volume, 0.35)
			and is_equal_approx(GameSettings.mouse_sensitivity, 1.7) and is_equal_approx(GameSettings.stick_sensitivity, 0.6)
			and GameSettings.invert_y and not GameSettings.fullscreen)
	GameSettings.apply()
	var db := AudioServer.get_bus_volume_db(0)
	_check("master volume applied to the bus (%.1f dB)" % db, is_equal_approx(db, linear_to_db(0.35)))

	# 11. Level changes: pausing mid-fade holds the change; Return to Title mid-fade cancels it.
	var massacre := "res://scenes/levels/massacre.tscn"
	story.go_to_level(massacre)
	await create_timer(0.2).timeout
	await _press("pause")
	_check("pause opens during a level-change fade", paused and pause.is_open)
	await create_timer(1.0).timeout
	_check("the level doesn't change while paused", (current_scene.scene_file_path in [TOWN, "res://scenes/world/world.tscn"]))
	await _press("pause")
	await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == massacre, 600)
	_check("after resume the level change goes through", current_scene.scene_file_path == massacre)
	await create_timer(0.8).timeout
	story.go_to_level("res://scenes/levels/black_sand.tscn")
	await create_timer(0.2).timeout
	await _press("pause")
	_check("pause opens in the next level too", pause.is_open)
	_choose(pause, "ReturntoTitle")
	await _frames(2)
	_item(pause, "Yes").pressed.emit()
	await _until(func() -> bool: return current_scene != null and current_scene.is_in_group("title_screen"), 300)
	await create_timer(1.5).timeout
	_check("Return to Title mid-fade lands on the title and stays (%s)" % current_scene.scene_file_path,
			current_scene.is_in_group("title_screen") and story.get("_fade").color.a == 0.0 and not paused)

	# 10. The old location menu path (the end of Act 0 goes there) now shows the title.
	change_scene_to_file("res://scenes/location_menu.tscn")
	await _frames(5)
	_check("location_menu.tscn opens the title screen", current_scene.is_in_group("title_screen")
			and _names(current_scene.get_node("Main")).size() >= 4)

	for f: String in FILES:
		if _saved[f] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		else:
			var file := FileAccess.open(f, FileAccess.WRITE)
			file.store_buffer(_saved[f])
			file.close()
	print("MENU TEST %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


## Headless Godot has no mouse: there only the menu's request can be checked.
func _mouse_ok(mode: int) -> bool:
	return DisplayServer.get_name() == "headless" or Input.mouse_mode == mode


func _press(action: String) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		await _frames(2)


func _choose(under: Node, item_name: String) -> void:
	var item := _item(under, item_name)
	item.grab_focus()  # as if highlighted, then pressed
	item.pressed.emit()


func _item(under: Node, item_name: String) -> MenuItem:
	return under.find_child(item_name, true, false) as MenuItem


func _names(list: Node) -> Array:
	var out := []
	for child in list.get_children():
		if child is MenuItem:
			out.append(String(child.name))
	return out


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Waits for cond. Gives up only after max_frames frames AND three times their 60 fps time in real
## time: headless frames run uncapped, and a threaded load on a busy machine takes seconds.
func _until(cond: Callable, max_frames: int) -> void:
	var deadline := Time.get_ticks_msec() + max_frames * 50
	var i := 0
	while i < max_frames or Time.get_ticks_msec() < deadline:
		if cond.call():
			return
		await process_frame
		i += 1
