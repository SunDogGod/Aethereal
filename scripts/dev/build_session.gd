extends RefCounted
## What Build Mode does to a level, and the record of it: delete, move, add, duplicate, undo.
## Every change happens in the running level at once and is written straight to the scene's
## edits file (data/edits/<scene>.json, see level_edits.gd), so nothing is lost if the game
## closes. Undo (Ctrl+Z) steps back through this session's changes, file included.
## No input, camera or drawing here (build_mode.gd does those), so tests can drive it directly.

signal saved(path: String)

const LevelEdits := preload("res://scripts/dev/level_edits.gd")
const Rules := preload("res://scripts/dev/edit_rules.gd")
const Codec := preload("res://scripts/dev/edit_codec.gd")
const MERGE_SECONDS := 1.5  ## nudges of the same thing closer together than this undo as one

var scene_root: Node        ## the running scene (get_tree().current_scene)
var message := ""           ## what the last call did, or why it didn't (the corner panel shows it)
var write_files := true     ## tests can switch the file writing off
var files := {}             ## scene path -> edits file, for tests (default: LevelEdits.file_for)

var _data := {}             # scene path -> its edits (level_edits.gd format)
var _undo: Array[Dictionary] = []
var _held: Array[Node] = [] # deleted nodes kept for undo; freed by clear()


func _init(root: Node) -> void:
	scene_root = root


## The editable thing a click on `hit` means, or null.
func target_of(hit: Node) -> Node3D:
	return Rules.target_of(hit, scene_root) if hit else null


func edit_root_of(node: Node) -> Node:
	return Rules.edit_root_of(node, scene_root)


## How many changes Ctrl+Z can take back.
func undo_count() -> int:
	return _undo.size()


## Forgets the undo steps and frees what they held (the level is closing or changing).
func clear() -> void:
	_undo.clear()
	for n in _held:
		if is_instance_valid(n) and not n.is_inside_tree():
			n.free()
	_held.clear()


# --- Changes ------------------------------------------------------------------------------

## Takes a node out of the level. Story nodes are refused (message says why). True if done.
func delete(node: Node3D) -> bool:
	var root := _root_or_say(node)
	if root == null:
		return false
	var why := Rules.protected_reason(node)
	if why != "":
		message = "Can't delete %s: %s." % [node.name, why]
		return false
	var snap := _snapshot(root)
	var data := _edits(root)
	var entry := _entry_of(node, data)
	if entry.is_empty():
		var path := str(root.get_path_to(node))
		for moved: String in data.moved.keys():
			if moved == path or moved.begins_with(path + "/"):
				data.moved.erase(moved)
		data.deleted.append(path)
	else:
		data.added.erase(entry)
	var parent := node.get_parent()
	var index := node.get_index()
	var owners := _owners(node)
	parent.remove_child(node)
	_held.append(node)
	_push(snap, func() -> void:
		parent.add_child(node)
		parent.move_child(node, mini(index, parent.get_child_count() - 1))
		for pair: Array in owners:
			if is_instance_valid(pair[0]) and is_instance_valid(pair[1]):
				(pair[0] as Node).owner = pair[1]
		_held.erase(node))
	_save(root)
	message = "Deleted %s." % node.name
	return true


## Moves a node to `xf` (relative to its parent). `before` is where it was (a drag has already
## moved it); `merge` folds quick repeats (arrow-key nudges) into one undo step.
func move(node: Node3D, xf: Transform3D, before: Variant = null, merge := false) -> bool:
	var root := _root_or_say(node)
	if root == null:
		return false
	var why := Rules.locked_reason(node)
	if why != "":
		message = "Can't move %s: %s." % [node.name, why]
		if before is Transform3D:
			node.transform = before
		return false
	var old: Transform3D = before if before is Transform3D else node.transform
	var key := "move:%d" % node.get_instance_id()
	var now := Time.get_ticks_msec()
	var top: Dictionary = _undo.back() if not _undo.is_empty() else {}
	var merging: bool = merge and top.get("key", "") == key and now - int(top.get("at", 0)) < MERGE_SECONDS * 1000
	if not merging:
		var put_back := func() -> void:
			if is_instance_valid(node):
				node.transform = old
		_push(_snapshot(root), put_back, key)
	else:
		top.at = now
	node.transform = xf
	var data := _edits(root)
	var entry := _entry_of(node, data)
	if entry.is_empty():
		data.moved[str(root.get_path_to(node))] = Codec.xf_to_json(xf)
	else:
		entry.transform = Codec.xf_to_json(xf)
	_save(root)
	message = "Moved %s." % node.name
	return true


## Adds a catalog thing (build_catalog.gd) at a world transform. `near` is a node the new
## one belongs with (what the crosshair hit): its level gets the edit. Returns the node or null.
func add(asset: Dictionary, world_xf: Transform3D, near: Node = null) -> Node3D:
	var root := _root_for_new(near)
	if root == null:
		message = "Nothing here to add to."
		return null
	if root.scene_file_path == "":
		message = "This scene has no file, so its edits can't be saved."
		return null
	var snap := _snapshot(root)
	var data := _edits(root)
	var group := str(asset.get("parent", "Dressing"))
	var parent := LevelEdits.parent_for(root, group, false)
	var entry := {"id": _new_id(data), "name": str(asset.get("name", "Thing")), "parent": group,
			"transform": Codec.xf_to_json(Codec.local_xf(parent, world_xf))}
	for key: String in ["scene", "script", "class", "props"]:
		if asset.has(key):
			entry[key] = asset[key]
	var node := LevelEdits.make_node(entry, root)
	if node == null:
		message = "Couldn't make %s." % asset.get("label", entry.name)
		return null
	return _finish_add(root, parent, node, entry, data, snap, null)


## A copy of a node beside it (`offset` in world metres). Story nodes are refused.
func duplicate(node: Node3D, offset: Vector3) -> Node3D:
	var root := _root_or_say(node)
	if root == null:
		return null
	var why := Rules.protected_reason(node)
	if why != "":
		message = "Can't copy %s: %s." % [node.name, why]
		return null
	var snap := _snapshot(root)
	var data := _edits(root)
	var parent := node.get_parent() as Node
	var xf := node.transform
	xf.origin += Codec.local_dir(parent, offset)
	var source := _entry_of(node, data)
	var entry: Dictionary
	if source.is_empty():
		entry = {"id": "", "name": str(node.name), "parent": str(root.get_path_to(parent)),
				"duplicate_of": str(root.get_path_to(node))}
	else:
		entry = source.duplicate(true)
	entry.id = _new_id(data)
	entry.transform = Codec.xf_to_json(xf)
	var copy := LevelEdits.make_node(entry, root)
	if copy == null:
		message = "Couldn't copy %s." % node.name
		return null
	var original := root.get_node_or_null(NodePath(str(entry.get("duplicate_of", ""))))
	return _finish_add(root, parent, copy, entry, data, snap, original)


## Takes back the last change (and its line in the edits file).
func undo() -> bool:
	if _undo.is_empty():
		message = "Nothing to undo."
		return false
	var step: Dictionary = _undo.pop_back()
	(step.undo as Callable).call()
	for scene: String in step.snap:
		_data[scene] = step.snap[scene]
		_save_scene(scene)
	message = "Undone (%d left)." % _undo.size()
	return true


## The edits recorded so far for a scene (a copy).
func edits_for(scene_path: String) -> Dictionary:
	return (_data[scene_path] as Dictionary).duplicate(true) if _data.has(scene_path) \
			else LevelEdits.read(scene_path, files.get(scene_path, ""))


# --- Helpers ------------------------------------------------------------------------------

func _finish_add(root: Node, parent: Node, node: Node3D, entry: Dictionary, data: Dictionary,
		snap: Dictionary, original: Node) -> Node3D:
	parent.add_child(node, true)
	LevelEdits.own(node, root, original)
	entry.name = str(node.name)  # the name it really got (a sibling may have had it)
	data.added.append(entry)
	_push(snap, func() -> void:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free())
	_save(root)
	message = "Added %s." % node.name
	return node


func _root_or_say(node: Node) -> Node:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		message = "Nothing selected."
		return null
	var root := edit_root_of(node)
	if root == null:
		message = "%s isn't part of a level." % node.name
	elif root.scene_file_path == "":
		message = "This scene has no file, so its edits can't be saved."
		return null
	return root


## The level a new thing goes into: the one the crosshair hit, else the running scene.
func _root_for_new(near: Node) -> Node:
	if near and is_instance_valid(near):
		if near == scene_root or Rules.is_edit_scene(near.scene_file_path):
			return near
		var r := edit_root_of(near)
		if r:
			return r
	return scene_root


func _edits(root: Node) -> Dictionary:
	var scene := root.scene_file_path
	if not _data.has(scene):
		_data[scene] = LevelEdits.read(scene, files.get(scene, ""))
	return _data[scene]


func _snapshot(root: Node) -> Dictionary:
	return {root.scene_file_path: _edits(root).duplicate(true)}


func _entry_of(node: Node, data: Dictionary) -> Dictionary:
	if not node.has_meta(LevelEdits.ADDED_META):
		return {}
	var id := str(node.get_meta(LevelEdits.ADDED_META))
	for e: Dictionary in data.added:
		if e.id == id:
			return e
	return {}


func _new_id(data: Dictionary) -> String:
	var top := 0
	for e: Dictionary in data.added:
		top = maxi(top, str(e.id).trim_prefix("a").to_int())
	return "a%d" % (top + 1)


func _push(snap: Dictionary, undo_call: Callable, key := "") -> void:
	_undo.append({"snap": snap, "undo": undo_call, "key": key, "at": Time.get_ticks_msec()})
	if _undo.size() > 200:
		_undo.pop_front()


func _save(root: Node) -> void:
	_save_scene(root.scene_file_path)


func _save_scene(scene: String) -> void:
	if not write_files:
		return
	var err := LevelEdits.write(_data[scene], files.get(scene, ""))
	if err != OK:
		message = "Couldn't save %s (%s)." % [LevelEdits.file_for(scene), error_string(err)]
		return
	saved.emit(LevelEdits.file_for(scene))


## Every node in a subtree with its owner (taking a node out of the tree clears them).
func _owners(node: Node) -> Array:
	var out := [[node, node.owner]]
	for child in node.get_children():
		out.append_array(_owners(child))
	return out
