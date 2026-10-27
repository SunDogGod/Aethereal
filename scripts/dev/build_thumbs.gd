extends Node
## Little pictures for Build Mode's asset tiles. Each thing is built once in a small hidden
## room of its own (a SubViewport with its own world, a lamp and a camera), photographed from
## a three-quarter view and thrown away; the picture goes on its tile and is kept in
## user://build_thumbs/ so the next session shows it at once (a changed scene or script file
## gets a new picture). One thing every few frames, so the game keeps drawing meanwhile.

const LevelEdits := preload("res://scripts/dev/level_edits.gd")
const Gizmo := preload("res://scripts/dev/build_gizmo.gd")
const SIZE := 64
const CACHE := "user://build_thumbs/"

var _queue: Array[Dictionary] = []  # entries still to photograph
var _view: SubViewport
var _cam: Camera3D
var _busy := false
var _ui: Node


## Gives the screen (build_ui.gd) a picture for every entry: from the cache, or taken now.
func fill(entries: Array[Dictionary], ui: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return  # nothing is drawn without a window
	_ui = ui
	_queue.clear()
	for entry: Dictionary in entries:
		if ui.icons.has(ui.key_of(entry)):
			continue
		var cached := _load(entry)
		if cached:
			ui.set_icon(ui.key_of(entry), cached)
		else:
			_queue.append(entry)
	if not _queue.is_empty() and not _busy:
		_work()


func _work() -> void:
	_busy = true
	if _view == null:
		_make_room()
	while not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		var tex := await _shoot(entry)
		if tex and is_instance_valid(_ui):
			_ui.set_icon(_ui.key_of(entry), tex)
	_busy = false


func _shoot(entry: Dictionary) -> Texture2D:
	var node := LevelEdits.make_node(entry.merged({"id": "thumb", "name": "Thumb"}), self)
	if node == null:
		return null
	node.transform = Transform3D.IDENTITY
	_view.add_child(node)
	await get_tree().process_frame  # a building block finishes its fronts in _ready
	var box := Gizmo.bounds_of(node)
	if box == Gizmo.NOTHING:  # a lamp or a sound: nothing to photograph, the tile keeps its frame
		node.queue_free()
		return null
	var centre := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.2)
	var dir := Vector3(0.75, 0.55, 1.0).normalized()
	_cam.global_transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), centre + dir * radius * 2.6)
	_cam.far = radius * 8.0 + 10.0
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _view.get_texture().get_image()
	node.queue_free()
	if img == null or img.is_empty():
		return null
	_save(entry, img)
	return ImageTexture.create_from_image(img)


func _make_room() -> void:
	_view = SubViewport.new()
	_view.size = Vector2i(SIZE, SIZE)
	_view.own_world_3d = true
	_view.transparent_bg = false
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.075, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.65)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	_view.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.1
	_view.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_view.add_child(_cam)
	_cam.current = true


## The cached picture of an entry, or null (none yet, or its file changed since).
func _load(entry: Dictionary) -> Texture2D:
	var path := _cache_path(entry)
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null


func _save(entry: Dictionary, img: Image) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE))
	img.save_png(ProjectSettings.globalize_path(_cache_path(entry)))


## One file per entry and version of its source file (its time stamp is in the name).
func _cache_path(entry: Dictionary) -> String:
	var source := str(entry.get("scene", entry.get("script", "")))
	var stamp := FileAccess.get_modified_time(source) if source != "" else 0
	var key := "%s|%s|%s|%d" % [entry.group + entry.label, source, JSON.stringify(entry.get("props", {})), stamp]
	return CACHE + key.md5_text() + ".png"
