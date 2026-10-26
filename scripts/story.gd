extends Node
## Plays the story's dialogue scenes and simple cutscenes (autoload: "Story").
## Anything can call Story.play("res://data/dialogue/empty_town.txt", "kael_meeting").
## While a scene plays, Aeneas can't move and guards don't look for him.
## The words live in plain-text files in data/dialogue/, so writing a scene
## never means touching code. It also handles fades, title cards and moving
## to the next level (loaded behind the black screen by scene_loader.gd, so the window never freezes).
## The town, Black Sand and the station live together in one big world (scenes/world/world.tscn).
## Going to one of those levels loads the world at that zone's start; inside the world a [level]
## line for one of them just lets Aeneas walk on. A scene looks up cameras, markers and characters
## in its own level first (black_sand.txt looks in Black Sand), then anywhere in the world.
## Saving: each level start is saved (SaveGame.start_level), Autosave (added to each story level
## loaded here) saves when a scene ends, and Continue's save is put back as the level loads.

signal scene_finished(scene: String)
## A dialogue file's scene played to its normal end (not a look-at, not a scene that left the level).
signal scene_done(path: String, scene: String)

const DIALOGUE_BOX := preload("res://scenes/dialogue_box.tscn")

var playing := false
var last_started_fights: Array = []  ## the fights the playing (or last) scene started with [fight]

var _run_id := 0  # stop() bumps this; a scene or level change still waiting then gives up
var _fade_tween: Tween

var _box: DialogueBox
var _fade: ColorRect
var _title: Label
var _files := {}  # path -> parsed scenes, read once
var _scope: Node  # the level the playing scene belongs to (in the world: its zone's level)
var _loader := SceneLoader.new()  # changes scenes behind the fade without freezing the window


func _ready() -> void:
	_box = DIALOGUE_BOX.instantiate()
	add_child(_box)
	_fade = _box.get_node("Fade")
	_title = _box.get_node("Title")
	add_child(_loader)
	_loader.attach(_box)


## Starts a scene. Returns false if it can't (another scene is playing, or no such scene).
func play(path: String, scene: String) -> bool:
	if playing:
		return false
	var steps: Array = _scenes_in(path).get(scene, [])
	if steps.is_empty():
		push_warning("Story: no scene '%s' in %s" % [scene, path])
		return false
	var root := _root()
	_scope = root.level_for_dialogue(path) if root.has_method("level_for_dialogue") else root
	_run(steps, scene, path)
	return true


## Shows a few lines of narration (no speaker), one after another, the way an Interactable
## does when Aeneas looks at something. Same rules as a scene: he can't move meanwhile,
## and it does nothing while another scene is playing.
func narrate(lines: Array) -> void:
	if playing or lines.is_empty():
		return
	var steps: Array = []
	for line: String in lines:
		steps.append({"type": "line", "speaker": "", "text": line})
	_scope = null
	_run(steps, "narrate")


## Goes to another level with a fade to black. Used by the title screen and the chapter lists.
## A level that lives in the big world loads the world, starting at that level's zone.
## `fresh` saves the start of that level (New Game, a chapter); Continue passes false.
func go_to_level(path: String, fresh := true) -> void:
	var run_id := _run_id
	await fade("out")
	if run_id != _run_id:
		return  # stop() was called during the fade
	if not await _change_scene(path, run_id):
		return
	if fresh:
		SaveGame.start_level(path)  # Continue on the title screen starts here, until the next save
	await get_tree().process_frame
	await get_tree().process_frame
	_loader.finish(get_tree().current_scene.scene_file_path if get_tree().current_scene else "")
	await fade("in")


## "out" = to black, "white" = to white, "in" = back to the game.
func fade(how: String) -> void:
	var color := Color(1, 1, 1, 1) if how == "white" else Color(0, 0, 0, 1)
	if how == "in":
		color = Color(_fade.color.r, _fade.color.g, _fade.color.b, 0.0)
	else:
		_fade.color = Color(color.r, color.g, color.b, _fade.color.a)
	var tween := create_tween()
	_fade_tween = tween
	tween.tween_property(_fade, "color", color, 0.6)
	await tween.finished


## Ends whatever is playing at once and clears the screen (the pause menu's Return to Title).
func stop() -> void:
	_run_id += 1
	playing = false
	SaveGame.pending = {}  # a Continue still loading is called off too
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_loader.cancel()
	_fade.color.a = 0.0
	_title.visible = false
	_box.close()
	_box.letterbox(false)


func _run(steps: Array, scene: String, path := "") -> void:
	playing = true
	last_started_fights = []
	var player: Player = get_tree().get_first_node_in_group("player")
	if player:
		player.controls_enabled = false
		player.in_cutscene = true
		player.velocity = Vector3.ZERO
	var gameplay_camera := get_viewport().get_camera_3d()
	var run_id := _run_id
	for step: Dictionary in steps:
		if run_id != _run_id:
			return  # stop() ended this scene (Return to Title)
		match step.type:
			"line":
				await _box.say(step.speaker, step.text)
			"camera":
				_cut_to(step.name, gameplay_camera)
			"wait":
				await get_tree().create_timer(step.seconds, false).timeout  # false: stops while paused
			"hide", "show":
				var node := _find(step.name)
				if node is Node3D:
					node.visible = step.type == "show"
			"fade":
				_box.close()
				await fade(step.how)
			"title":
				_box.close()  # the last line shouldn't sit under the title card
				await _show_title(step.text)
			"frame":
				var framed := _find(step.name)
				if framed is Node3D and player:
					var shot := StoryFrame.place(_level(), player, framed)
					shot.make_current()
					_box.letterbox(true)
			"teleport":
				var mark := _find(step.name)
				if mark is Node3D and player:
					player.respawn_at(mark.global_position)
					player.get_node("CameraPivot").rotation.y = mark.global_rotation.y
					# Restarts (spotted, slain, fell) now happen here, not at the last checkpoint behind.
					var director := _root().find_child("StealthDirector", true, false)
					if director and director.has_method("move_checkpoint"):
						director.move_checkpoint(mark.global_position)
			"fight":
				var fight := _find(step.name)
				if fight and fight.has_method("start"):
					fight.call_deferred("start")  # after this scene gives control back
					last_started_fights.append(fight)
			"erupt":
				if player:
					player.get_node("Combat").set_erupting(step.on)
			"empower":
				var guard := _find(step.name)
				if guard is Guard:
					guard.empower()
			"collapse":
				var body := _find(step.name)
				if body:
					for n in [body] + body.find_children("*", "", true, false):
						if n.has_method("die") and not n is Guard:
							n.die()  # its animator plays the death and holds the last pose
							break
			"kill":
				var victim := _find(step.name)
				if victim is Guard:
					victim.sacrifice()
			"heal":
				if player:
					player.get_node("Combat").heal_full()
			"level":
				_box.close()
				if World.has_level(step.path) and _root() is World:
					# Already in the big world, where that place is just ahead: he walks on.
					if _fade.color.a > 0.01:
						await fade("in")
				else:
					if _fade.color.a < 0.99:  # not already faded (e.g. after [fade white])
						await fade("out")
					if run_id != _run_id:
						return
					if not await _change_scene(step.path, run_id):
						return
					SaveGame.start_level(step.path)
					# This scene is over: the next level's opening trigger (Aeneas starts inside it)
					# may start its own scene while the screen fades back in.
					playing = false
					scene_finished.emit(scene)
					await get_tree().process_frame
					await get_tree().process_frame
					_loader.finish(get_tree().current_scene.scene_file_path if get_tree().current_scene else "")
					await fade("in")
					return
	if run_id != _run_id:
		return
	_box.close()
	_cut_to("", gameplay_camera)
	# Two physics ticks before handing control back, so the press that closed the box is
	# not also read as a swing, a jump or a new look.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if run_id != _run_id:
		return
	if is_instance_valid(player):
		player.controls_enabled = true
		player.in_cutscene = false
	playing = false
	scene_finished.emit(scene)
	if path != "":
		scene_done.emit(path, scene)  # Autosave saves here


## A title card over the fade: "ACT 0 - BLACK SAND". Lines split on " / ".
func _show_title(text: String) -> void:
	_title.text = text.replace(" / ", "\n")
	_title.modulate.a = 0.0
	_title.visible = true
	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 1.0, 0.6)
	tween.tween_interval(2.0)
	tween.tween_property(_title, "modulate:a", 0.0, 0.6)
	await tween.finished
	_title.visible = false


## Cuts to a Camera3D in the level by name, or back to the gameplay camera if name is "".
func _cut_to(camera_name: String, gameplay_camera: Camera3D) -> void:
	if camera_name.is_empty():
		if is_instance_valid(gameplay_camera):
			gameplay_camera.make_current()
		_box.letterbox(false)
		return
	var shot := _find(camera_name)
	if shot is Camera3D:
		shot.make_current()
		_box.letterbox(true)
	else:
		push_warning("Story: no camera called '%s' in the level" % camera_name)


func _scenes_in(path: String) -> Dictionary:
	if not _files.has(path):
		_files[path] = DialogueFile.parse(FileAccess.get_file_as_string(path))
	return _files[path]


## The level the playing scene belongs to.
func _level() -> Node:
	return _scope if is_instance_valid(_scope) and _scope.is_inside_tree() else _root()


## The current scene (the big world, or a level running on its own).
func _root() -> Node:
	return get_tree().current_scene if get_tree().current_scene else get_tree().root


## A node by name: in the scene's own level first, then anywhere (a companion who joined Aeneas
## lives in the world's Carry node, not in his old level).
func _find(node_name: String) -> Node:
	var found := _level().find_child(node_name, true, false)
	if found == null and _level() != _root():
		found = _root().find_child(node_name, true, false)
	return found


## Loads a level, or the big world at that level's zone, behind the black screen and without
## freezing the window (scene_loader.gd), then swaps it in. False if stop() came meanwhile.
## A story level gets an Autosave; Continue's save (SaveGame.pending) is put back as it starts.
func _change_scene(path: String, run_id: int) -> bool:
	var next: Node = await _loader.prepare(World.SCENE if World.has_level(path) else path)
	if next == null or run_id != _run_id:
		if next:
			next.free()
		return false
	var restore: Dictionary = SaveGame.pending if SaveGame.pending.get("level", "") == path else {}
	SaveGame.pending = {}
	if World.has_level(path):
		World.pending_level = path
	SaveRestore.prepare(next, restore)
	if Chapters.is_story_level(path):
		Autosave.attach(next, restore)
	get_tree().change_scene_to_node(next)
	return true
