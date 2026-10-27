extends "C:/Users/ArmandoSanchez/Documents/Aethereal 3D Godot/aethereal-3d/tests/overnight/saving_impl/save_test_base.gd"
# The save file on its own (no scenes): atomic writes with a spare copy, a broken or truncated
# file, a leftover .tmp, a file from a newer version, the old save.cfg, bad entries, and the
# title screen's Continue / New Game with each. Run headless.


func _initialize() -> void:
	_run()


func _save(level: String, x: float) -> Dictionary:
	return {"version": 1, "level": level, "reason": "checkpoint", "stage": 1, "fresh": false,
			"spot": {"pos": [x, 24.0, 33.0], "yaw": 0.5, "cam_yaw": 0.25}, "restart": {"pos": [x, 24.0, 33.0]},
			"story": {"res://data/dialogue/empty_town.txt": ["arrival"]}, "checkpoints": [TOWN + "::Checkpoints/BridgeEnd"],
			"fights_won": [], "guards_down": [{"key": TOWN + "::Guards/AgentEastDeck", "pos": [1, 2, 3], "yaw": 1.0, "killed": true}],
			"looked": [], "flashlight": true}


func _file(name: String) -> String:
	return SaveGame.folder.path_join(name)


func _put_text(name: String, text: String) -> void:
	var f := FileAccess.open(_file(name), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _run() -> void:
	setup("file")
	check("no files: no save", SaveGame.load_save().is_empty() and not SaveGame.exists())
	check("write 1", SaveGame.write(_save(TOWN, 1.0)))
	check("write 2 keeps 1 as the spare", SaveGame.write(_save(TOWN, 2.0)) and FileAccess.file_exists(_file(SaveGame.BAK))
			and not FileAccess.file_exists(_file(SaveGame.TMP)))
	var data := SaveGame.load_save()
	check("reads back: spot, restart, story, guards, flashlight", spot_of(data) == Vector3(2, 24, 33)
			and data.restart.pos[0] == 2.0 and data.story.size() == 1 and data.guards_down.size() == 1
			and data.guards_down[0].killed and data.flashlight and data.stage == 1 and typeof(data.stage) == TYPE_INT)
	check("describe: %s" % SaveGame.describe(data), SaveGame.describe(data) == "0.1  The Empty Town")

	# A broken main file: the spare is used, and the next write keeps the broken one aside.
	_put_text(SaveGame.FILE, "{\"version\": 1, \"level\": \"res://scenes/lev")
	data = SaveGame.load_save()
	check("truncated file: falls back to the spare (x=1)", spot_of(data).x == 1.0)
	check("write after a broken file keeps the spare", SaveGame.write(_save(TOWN, 3.0))
			and FileAccess.file_exists(_file(SaveGame.CORRUPT)) and spot_of(SaveGame.load_save()).x == 3.0)
	data = JSON.parse_string(FileAccess.get_file_as_string(_file(SaveGame.BAK)))
	check("the good spare survived (x=1)", data is Dictionary and float(data.spot.pos[0]) == 1.0)
	_put_text(SaveGame.FILE, "not json at all")
	check("garbage file: spare used", spot_of(SaveGame.load_save()).x == 1.0)

	# Only a .tmp left (a crash between the two renames).
	for f in [SaveGame.FILE, SaveGame.BAK]:
		DirAccess.remove_absolute(_file(f))
	_put_text(SaveGame.TMP, JSON.stringify(_save(BS, 4.0)))
	data = SaveGame.load_save()
	check("only the .tmp: it is used", data.get("level", "") == BS and spot_of(data).x == 4.0)
	DirAccess.remove_absolute(_file(SaveGame.TMP))

	# A file from a newer version is never read, and never overwritten.
	var newer := _save(TOWN, 5.0)
	newer.version = 2
	_put_text(SaveGame.FILE, JSON.stringify(newer))
	check("newer version: no Continue", SaveGame.load_save().is_empty())
	check("writing keeps it as savegame.v2.json", SaveGame.write(_save(TOWN, 6.0))
			and FileAccess.file_exists(_file("savegame.v2.json")) and spot_of(SaveGame.load_save()).x == 6.0)

	# Bad entries are dropped one by one; a bad spot makes it a level-start save; a gone level, no save.
	var bad := _save(TOWN, 7.0)
	bad.guards_down = [{"key": "nope", "pos": [1, 2, 3]}, {"key": TOWN + "::G", "pos": [1, "x", 3]}, {"key": TOWN + "::G", "pos": [1, 2, 3]}]
	bad.checkpoints = ["x", 3, TOWN + "::Checkpoints/Rim"]
	bad.story = {"res://data/dialogue/empty_town.txt": ["arrival", 4], "x": "y"}
	_put_text(SaveGame.FILE, JSON.stringify(bad))
	data = SaveGame.load_save()
	check("bad entries dropped %s %s %s" % [data.guards_down.size(), data.checkpoints, data.story],
			data.guards_down.size() == 1 and data.checkpoints == [TOWN + "::Checkpoints/Rim"]
			and data.story == {"res://data/dialogue/empty_town.txt": ["arrival"]})
	bad.spot = {"pos": [1, 2]}
	_put_text(SaveGame.FILE, JSON.stringify(bad))
	data = SaveGame.load_save()
	check("a bad spot: start of that level", data.get("fresh") == true and data.level == TOWN)
	bad.level = "res://scenes/levels/gone.tscn"
	_put_text(SaveGame.FILE, JSON.stringify(bad))
	DirAccess.remove_absolute(_file(SaveGame.BAK))
	check("a level that no longer exists: no save", SaveGame.load_save().is_empty())

	# The old save.cfg (before saving existed) continues as the start of its level.
	for f in DirAccess.get_files_at(SaveGame.folder):
		DirAccess.remove_absolute(_file(f))
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "level", STATION)
	cfg.save(_file("save.cfg"))
	data = SaveGame.load_save()
	check("old save.cfg: the station's start", data.get("level", "") == STATION and data.get("fresh") == true)
	SaveGame.write({"version": 1, "level": STATION, "fresh": true})
	check("the first new save keeps save.cfg as save.cfg.old", not FileAccess.file_exists(_file("save.cfg"))
			and FileAccess.file_exists(_file("save.cfg.old")) and SaveGame.last_level() == STATION)

	# The title screen with that save: Continue says where; New Game asks first; No keeps it.
	SaveGame.recording = false
	change_scene_to_file(TITLE)
	for i in 10:
		await process_frame
	var cont := current_scene.find_child("Continue", true, false) as MenuItem
	check("title: Continue shows %s" % (cont.detail if cont else "-"), cont != null and cont.detail == "0.4  The Vacuum Station")
	(current_scene.find_child("NewGame", true, false) as MenuItem).pressed.emit()
	await frames(3)
	var confirm := current_scene.get_node("Confirm") as Control
	check("New Game asks first, No has the focus", confirm.visible
			and root.gui_get_focus_owner() == current_scene.find_child("No", true, false))
	(current_scene.find_child("No", true, false) as MenuItem).pressed.emit()
	await frames(3)
	check("No: back to the menu, save kept", not confirm.visible and SaveGame.last_level() == STATION)
	# A fresh save of the first level loses nothing: New Game goes straight in.
	SaveGame.write({"version": 1, "level": TOWN, "fresh": true})
	change_scene_to_file(TITLE)
	for i in 10:
		await process_frame
	var title := current_scene
	(title.find_child("NewGame", true, false) as MenuItem).pressed.emit()
	await frames(3)
	check("nothing to lose: New Game doesn't ask", not (title.get_node("Confirm") as Control).visible)
	# The test yard is never saved, so picking it never asks.
	change_scene_to_file(TITLE)
	for i in 10:
		await process_frame
	story.stop()
	SaveGame.write(_save(TOWN, 8.0))
	change_scene_to_file(TITLE)
	for i in 10:
		await process_frame
	title = current_scene
	(title.find_child("Testyard(movement)", true, false) as MenuItem).pressed.emit()
	await frames(3)
	check("the test yard doesn't ask", not (title.get_node("Confirm") as Control).visible)
	story.stop()
	finish("SAVE FILE TEST")
