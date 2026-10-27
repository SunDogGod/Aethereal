extends Node
## Puts the author's in-game edits (data/edits/*.json, written by Build Mode) back into a scene
## each time it loads: alone (F6, a chapter) or inside the big world. It runs in EVERY build,
## release exports too (DevTools keeps just this node there), so the edits ship until they are
## baked into the scene file with the editor dock's "Bake in-game edits" button.
## It listens for nodes entering the tree; when a scene that has an edits file enters, the
## edits are applied before any of its children are ready (nothing has run, built or saved yet).

const LevelEdits := preload("res://scripts/dev/level_edits.gd")
const DONE := &"build_edits_applied"

var _files := {}  ## scene path -> its edits file, for the scenes that have one
var applied := {} ## scene path -> the last report (Build Mode shows it)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rescan()
	get_tree().node_added.connect(_on_node_added)


## Looks again for edits files (Build Mode calls it after saving one).
func rescan() -> void:
	_files.clear()
	if not DirAccess.dir_exists_absolute(LevelEdits.FOLDER):
		return
	for file in DirAccess.get_files_at(LevelEdits.FOLDER):
		if not file.ends_with(".json"):
			continue
		var path := LevelEdits.FOLDER + file
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("scene") is String:
			_files[parsed.scene] = path


func _on_node_added(node: Node) -> void:
	var scene := node.scene_file_path
	if scene == "" or not _files.has(scene) or node.has_meta(DONE):
		return
	node.set_meta(DONE, true)  # a scene taken out and put back must not get them twice
	var data := LevelEdits.read(scene, _files[scene])
	if LevelEdits.is_empty(data):
		return
	var report := LevelEdits.apply(node, data)
	applied[scene] = report
	if not report.missing.is_empty():
		push_warning("In-game edits for %s: %d not found (renamed or removed in the editor?): %s"
				% [scene.get_file(), report.missing.size(), ", ".join(report.missing)])
