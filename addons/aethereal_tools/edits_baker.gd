@tool
extends RefCounted
## "Bake in-game edits": moves what was changed in the game's Build Mode (data/edits/*.json) into
## the scene files themselves, so the .tscn stays the one true copy, then clears the edits file
## (it is kept as <name>.json.bak beside it, just in case).
## In the editor each scene is opened, changed and saved by the editor itself (bake_open_scene).
## bake_into_file() does the same without the editor, into any file (tests bake into a copy).

const LevelEdits := preload("res://scripts/dev/level_edits.gd")


## Every edits file waiting, as [scene path, edits file].
static func waiting() -> Array:
	var out := []
	if not DirAccess.dir_exists_absolute(LevelEdits.FOLDER):
		return out
	for file in DirAccess.get_files_at(LevelEdits.FOLDER):
		if not file.ends_with(".json"):
			continue
		var path := LevelEdits.FOLDER + file
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("scene") is String and ResourceLoader.exists(parsed.scene):
			out.append([parsed.scene, path])
	return out


## Editor only: bakes every waiting edits file into its scene. Returns what it did, in words.
static func bake_all() -> String:
	var jobs := waiting()
	if jobs.is_empty():
		return "No in-game edits waiting (data/edits/ is empty). Make some with F2 in the running game."
	var lines: Array[String] = []
	for job: Array in jobs:
		lines.append(bake_open_scene(job[0], job[1]))
	return "\n".join(lines)


## Editor only: opens the scene (or switches to its tab), applies the edits, saves it with the
## editor and retires the edits file.
static func bake_open_scene(scene_path: String, edits_path: String) -> String:
	var data := LevelEdits.read(scene_path, edits_path)
	var file_name := scene_path.get_file()
	if LevelEdits.is_empty(data):
		_retire(edits_path)
		return "%s: nothing to bake." % file_name
	EditorInterface.open_scene_from_path(scene_path)
	var root := EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != scene_path:
		return "%s: couldn't open it, so its edits are still waiting." % file_name
	var report := LevelEdits.apply(root, data, true)
	EditorInterface.mark_scene_as_unsaved()
	var err := EditorInterface.save_scene()
	if err != OK:
		return "%s: applied but not saved (%s). Save it with Ctrl+S; the edits file is kept." % [file_name, error_string(err)]
	_retire(edits_path)
	var note := "%s: %d edits baked and saved." % [file_name, report.done]
	if not report.missing.is_empty():
		note += " Not found (renamed or removed since): " + ", ".join(report.missing)
	return note


## Applies edits to a scene and saves the result to `out_path` (the scene file itself, or a copy).
static func bake_into_file(scene_path: String, data: Dictionary, out_path: String) -> Dictionary:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return {"ok": false, "message": "can't load " + scene_path}
	var root := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var report := LevelEdits.apply(root, data, true)
	var out := PackedScene.new()
	var err := out.pack(root)
	if err == OK:
		err = ResourceSaver.save(out, out_path)
	root.free()
	return {"ok": err == OK, "message": error_string(err), "report": report}


## The edits are in the scene now: keep the file as .bak (overwriting an older one) and remove it.
static func _retire(edits_path: String) -> void:
	var from := ProjectSettings.globalize_path(edits_path)
	var to := from + ".bak"
	if FileAccess.file_exists(edits_path + ".bak"):
		DirAccess.remove_absolute(to)
	DirAccess.rename_absolute(from, to)
