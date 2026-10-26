class_name SceneLoader
extends Node
## Changes scenes without freezing the window. Story owns one, and it works behind Story's black
## fade (go_to_level, and [level] lines in dialogue):
##   1. The scene file loads on a background thread, so the window keeps drawing.
##   2. The scene is instanced and its code-built meshes (mesh_build.gd) are built a slice of
##      each frame, so the window still keeps drawing.
##   3. Story swaps it in and fades back.
## If that takes more than a moment, a small "Loading" line with a bar shows in the bottom-right
## corner of the black screen. The title screen starts step 1 for the world as soon as it shows
## (fetch), so New Game and Continue find it ready; after every change the scenes the new one's
## dialogue can lead to ([level] lines) start loading the same way. Its music is fetched too
## (music_files.gd), so the first bars of a track never stall the game.

const MusicFiles := preload("res://scripts/music_files.gd")
const SLICE_MS := 12.0    ## building time per frame while the screen is black (60 fps = 16.7 ms)
const SHOW_AFTER := 0.3   ## seconds before the Loading line shows (quick changes never show it)

static var busy := false  ## a scene change is under way (the pause menu stays shut meanwhile)
static var _fetched: Array[String] = []  # requested on a thread and not picked up yet

var _gen := 0             # each change (and cancel) bumps this; an older change still running gives up
var _started := 0         # msec when the current change began
var _ui: Control
var _fill: ColorRect
var _tween: Tween


## Starts loading a scene file on a background thread, if it isn't loaded or loading already.
## prepare() picks it up later. Safe to call any time, from anywhere.
static func fetch(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path, "", false)
		if not path in _fetched:
			_fetched.append(path)


## Picks up a fetched scene (waits for it if it is still loading). Null if it wasn't fetched.
static func _take(path: String) -> PackedScene:
	_fetched.erase(path)
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return null
	return ResourceLoader.load_threaded_get(path) as PackedScene


## The game is closing: let go of scenes fetched but never used, so nothing is left loaded at exit.
func _exit_tree() -> void:
	for path: String in _fetched.duplicate():
		_take(path)


## Fetches every scene the dialogue of `scene_path` can lead to ([level] lines), so the next
## change finds it loaded. The big world's levels share one scene (world.tscn).
static func fetch_after(scene_path: String) -> void:
	var levels: Array = World.LEVELS if scene_path == World.SCENE else [scene_path]
	for level: String in levels:
		var file := "res://data/dialogue/%s.txt" % level.get_file().get_basename()
		if not FileAccess.file_exists(file):
			continue
		var scenes := DialogueFile.parse(FileAccess.get_file_as_string(file))
		for steps: Array in scenes.values():
			for step: Dictionary in steps:
				if step.type == "level":
					var target: String = World.SCENE if World.has_level(step.path) else step.path
					if target != scene_path:
						fetch(target)


## Puts the Loading line on `layer` (Story's dialogue box layer, above its fade).
func attach(layer: CanvasLayer) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = Control.new()
	_ui.name = "Loading"
	_ui.theme = preload("res://scenes/ui/menu_theme.tres")
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ui.offset_left = -132.0
	_ui.offset_top = -44.0
	_ui.offset_right = -24.0
	_ui.offset_bottom = -22.0
	_ui.visible = false
	var label := Label.new()
	label.text = "LOADING"
	label.theme_type_variation = "HintLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_bottom = 14.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(label)
	var track := ColorRect.new()
	track.color = MenuFx.LINE
	track.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	track.offset_top = -2.0
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(track)
	_fill = ColorRect.new()
	_fill.color = MenuFx.ACCENT
	_fill.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fill.offset_top = -2.0
	_fill.offset_right = 0.0
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fill)
	layer.add_child(_ui)


## Loads and instances `path` and builds its meshes, a slice per frame, then returns the new
## scene (not yet in the tree: the caller swaps it in with change_scene_to_node). Returns null if
## cancel() was called meanwhile. Call it with the screen already black.
func prepare(path: String) -> Node:
	busy = true
	_gen += 1
	var gen := _gen
	_started = Time.get_ticks_msec()
	fetch(path)
	var progress := []
	while ResourceLoader.load_threaded_get_status(path, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_show(0.5 * float(progress[0]) if not progress.is_empty() else 0.0)
		await get_tree().process_frame
		if gen != _gen:
			return null
	var scene := _take(path)
	if scene == null:
		scene = load(path) as PackedScene  # the thread failed: load it the plain way (reports why)
	if scene == null:
		busy = false
		return null
	MusicFiles.fetch(MusicFiles.tracks_for(path))  # its music too, so the first play never stalls
	_show(0.5)
	await get_tree().process_frame  # let the bar show before instancing (a short pause)
	if gen != _gen:
		return null
	var level := scene.instantiate()
	var todo := MeshBuild.waiting_under(level)
	var done := 0
	while done < todo.size():
		var t0 := Time.get_ticks_usec()
		while done < todo.size() and Time.get_ticks_usec() - t0 < SLICE_MS * 1000.0:
			MeshBuild.build_early(todo[done])
			done += 1
		_show(0.55 + 0.4 * done / todo.size())
		await get_tree().process_frame
		if gen != _gen:
			level.free()
			return null
	_show(1.0)
	return level


## The new scene is in and has drawn: hide the Loading line and start fetching what comes next.
func finish(scene_path: String) -> void:
	busy = false
	_hide()
	MeshBuild.forget_unused()
	fetch_after(scene_path)


## Story.stop(): give up on the change under way.
func cancel() -> void:
	_gen += 1
	busy = false
	_hide()


func _show(amount: float) -> void:
	if _ui == null:
		return
	_fill.offset_right = (_ui.size.x if _ui.size.x > 0.0 else 108.0) * clampf(amount, 0.0, 1.0)
	if not _ui.visible and Time.get_ticks_msec() - _started > SHOW_AFTER * 1000.0:
		_ui.visible = true
		_ui.modulate.a = 0.0
		_fade_ui(1.0, 0.2)


func _hide() -> void:
	if _ui and _ui.visible:
		_fade_ui(0.0, 0.15)


func _fade_ui(to: float, seconds: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_ui, "modulate:a", to, seconds)
	if to == 0.0:
		_tween.tween_callback(func() -> void: _ui.visible = false)
