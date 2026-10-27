extends RefCounted
## In-game edits to a scene, kept beside it in data/edits/<scene name>.json until they are
## baked into the scene file (the editor dock's "Bake in-game edits" button). Build Mode writes
## them; the EditsApplier puts them back every time the scene loads, in every build, so what the
## author changed in game ships even before it is baked.
##
## The file:
##   "scene":   the scene file it belongs to (res://scenes/levels/empty_town.tscn)
##   "deleted": node paths (relative to the scene's root) taken out
##   "moved":   node path -> transform (relative to its parent; edit_codec.gd)
##   "added":   new things: {id, name, parent, transform, and one of
##              scene (a prefab), script + class + props (a prop that builds itself),
##              duplicate_of (a copy of a node already in the scene, at its own transform)}
## Applied in that order: added, moved, deleted (a copy outlives the original it was made from).

const Codec := preload("res://scripts/dev/edit_codec.gd")
const FOLDER := "res://data/edits/"
const VERSION := 1
const ADDED_META := &"build_added"  ## an added node keeps its entry id in this meta


## The edits file of a scene ("res://data/edits/empty_town.json").
static func file_for(scene_path: String) -> String:
	return FOLDER + scene_path.get_file().get_basename() + ".json"


## A fresh, empty set of edits for a scene.
static func empty(scene_path: String) -> Dictionary:
	return {"version": VERSION, "scene": scene_path, "deleted": [], "moved": {}, "added": []}


static func is_empty(data: Dictionary) -> bool:
	return data.deleted.is_empty() and data.moved.is_empty() and data.added.is_empty()


## The edits saved for a scene (empty when there are none, or the file can't be read).
static func read(scene_path: String, path := "") -> Dictionary:
	if path == "":
		path = file_for(scene_path)
	var data := empty(scene_path)
	if not FileAccess.file_exists(path):
		return data
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("Build Mode: %s isn't readable JSON; ignoring it." % path)
		return data
	if parsed.get("scene", scene_path) != scene_path:
		return data  # another scene with the same file name
	if parsed.get("deleted") is Array:
		for p: Variant in parsed.deleted:
			if p is String:
				data.deleted.append(p)
	if parsed.get("moved") is Dictionary:
		for p: Variant in parsed.moved:
			if parsed.moved[p] is Dictionary:
				data.moved[str(p)] = parsed.moved[p]
	if parsed.get("added") is Array:
		for e: Variant in parsed.added:
			if e is Dictionary and e.get("id") is String and e.get("name") is String:
				data.added.append(e)
	return data


## Writes the edits safely (a temporary file, then a rename). No edits left: the file goes.
static func write(data: Dictionary, path := "") -> Error:
	if path == "":
		path = file_for(data.scene)
	if is_empty(data):
		if FileAccess.file_exists(path):
			return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return OK
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t", false))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


## Applies edits to a scene's root (in the game as it loads, or in the editor when baking).
## With `for_editor`, new nodes are owned by the root so the editor saves them with the scene.
## Returns {"done": n, "missing": [paths that weren't found]}.
static func apply(root: Node, data: Dictionary, for_editor := false) -> Dictionary:
	var report := {"done": 0, "missing": []}
	for entry: Dictionary in data.added:
		var parent := parent_for(root, str(entry.get("parent", "")), for_editor)
		var node := make_node(entry, root, for_editor)
		if node == null:
			report.missing.append(str(entry.get("duplicate_of", entry.get("scene", entry.get("script", entry.name)))))
			continue
		if for_editor:
			node.remove_meta(ADDED_META)  # baked: an ordinary part of the scene now
		parent.add_child(node, true)
		var source_path := str(entry.get("duplicate_of", ""))
		own(node, root, root.get_node_or_null(NodePath(source_path)) if source_path != "" else null)
		report.done += 1
	for p: String in data.moved:
		var n := root.get_node_or_null(NodePath(p)) as Node3D
		if n == null:
			report.missing.append(p)
			continue
		n.transform = Codec.xf_from_json(data.moved[p])
		report.done += 1
	for p: String in data.deleted:
		var n := root.get_node_or_null(NodePath(p))
		if n == null or n == root:
			report.missing.append(p)
			continue
		n.get_parent().remove_child(n)
		n.queue_free()
		report.done += 1
	return report


## Makes the node an "added" entry describes, at its transform (not yet in the tree).
static func make_node(entry: Dictionary, root: Node, for_editor := false) -> Node3D:
	var node: Node3D = null
	var source_path := str(entry.get("duplicate_of", ""))
	if source_path != "":
		var source := root.get_node_or_null(NodePath(source_path)) as Node3D
		if source == null:
			return null
		node = copy_of(source)
	elif str(entry.get("scene", "")) != "":
		var scene := load(entry.scene) as PackedScene if ResourceLoader.exists(entry.scene) else null
		if scene == null:
			return null
		var mode := PackedScene.GEN_EDIT_STATE_INSTANCE if for_editor else PackedScene.GEN_EDIT_STATE_DISABLED
		node = scene.instantiate(mode) as Node3D
	elif str(entry.get("script", "")) != "":
		var script := load(entry.script) as Script if ResourceLoader.exists(entry.script) else null
		var cls := str(entry.get("class", "Node3D"))
		if script == null or not ClassDB.can_instantiate(cls) or not ClassDB.is_parent_class(cls, "Node3D"):
			return null
		node = ClassDB.instantiate(cls) as Node3D
		node.set_script(script)
	if node == null:
		return null
	Codec.set_props(node, entry.get("props", {}))
	node.name = str(entry.name)
	node.transform = Codec.xf_from_json(entry.get("transform"))
	node.set_meta(ADDED_META, entry.id)
	return node


## A copy of a node already in the scene: everything the scene file holds of it, not the meshes
## its script built (the copy builds its own as it enters the tree).
static func copy_of(source: Node3D) -> Node3D:
	var copy := source.duplicate() as Node3D
	_drop_built(source, copy)
	copy.remove_meta(ADDED_META)
	return copy


static func _drop_built(source: Node, copy: Node) -> void:
	for child in source.get_children():
		var twin := copy.get_node_or_null(NodePath(child.name))
		if twin == null:
			continue
		if child.owner == null:  # made by a script while the game ran
			copy.remove_child(twin)
			twin.free()
		else:
			_drop_built(child, twin)


## Gives a new node to the scene's root, so Build Mode can pick it later (and the editor saves
## it). A copy's inside keeps the owners its original had.
static func own(node: Node, root: Node, source: Node = null) -> void:
	node.owner = root
	if source:
		_own_like(source, node, root)


static func _own_like(source: Node, copy: Node, root: Node) -> void:
	for child in source.get_children():
		var twin := copy.get_node_or_null(NodePath(child.name))
		if twin == null:
			continue
		if child.owner == root:
			twin.owner = root
		_own_like(child, twin, root)


## The node an added entry goes under; a missing group (Dressing, Life) is made.
static func parent_for(root: Node, path: String, for_editor: bool) -> Node:
	if path == "" or path == ".":
		return root
	var parent := root.get_node_or_null(NodePath(path))
	if parent:
		return parent
	var group := Node3D.new()
	group.name = path.get_file()
	var above := parent_for(root, path.get_base_dir(), for_editor) if path.contains("/") else root
	above.add_child(group, true)
	group.owner = root
	return group
