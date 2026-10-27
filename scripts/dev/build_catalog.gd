extends RefCounted
## Everything Build Mode can place, found fresh each time (new prefabs and prop scripts keep
## being written): the prefabs in scenes/prefabs/ (story pieces left out: triggers, shots,
## checkpoints, guards and fights need the Inspector), the prop scenes in scenes/prefabs/props/,
## and the prop scripts that build themselves (scripts/props*/, the same list as the editor
## dock), one entry per Kind when the script has one (Street prop: Bin, Street prop: Bicycle...).
## An entry: {label, group, name, parent, and scene, or script + class (+ props)}.

const Builders := preload("res://addons/aethereal_tools/builders.gd")

const PREFABS := "res://scenes/prefabs/"
## Prefabs that only make sense set up in the editor (story pieces, a whole level).
const LEAVE_OUT := ["agency_guard", "camera_shot", "checkpoint", "fight", "level_template",
		"look_at_spot", "patrol_point", "story_trigger"]
## Prefabs that are life signs: they go under the level's Life node, like the dock puts them.
const LIFE := ["drip", "flickering_light", "steam_grate", "steam_vent", "tv_window"]


## Every placeable thing, grouped (Prefabs, Prop scenes, Props, Props: Black Sand...).
static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for file in _scenes_in(PREFABS, false):
		var base := file.get_file().get_basename()
		if base in LEAVE_OUT:
			continue
		out.append(_scene_entry(file, "Prefabs", "Life" if base in LIFE else "Dressing"))
	for file in _scenes_in(PREFABS + "props/", true):
		out.append(_scene_entry(file, "Prop scenes", "Dressing"))
	var props := Builders.list_props()
	var shared := _shared_bases(props)
	for prop: Array in props:
		var path: String = prop[1]
		var cls := Builders.native_base(path)
		if cls == "" or path in shared:
			continue
		var group := "Props" if prop[2] == "" else "Props: " + str(prop[2])
		var base := {"group": group, "script": path, "class": cls, "parent": "Dressing",
				"name": path.get_file().get_basename().to_pascal_case()}
		var kinds := kinds_of(path)
		if kinds.is_empty():
			var one := base.duplicate()
			one.label = str(prop[0])
			out.append(one)
		for k: Array in kinds:
			var entry := base.duplicate()
			entry.label = "%s: %s" % [prop[0], k[0]]
			entry.props = {"kind": var_to_str(k[1])}
			out.append(entry)
	return out


## Prop scripts that other prop scripts extend (sand_piece.gd under sand_relic.gd): a shared
## base, not a thing of its own.
static func _shared_bases(props: Array) -> Array[String]:
	var out: Array[String] = []
	for prop: Array in props:
		var script := load(prop[1]) as Script
		var base := script.get_base_script() if script else null
		while base:
			out.append(base.resource_path)
			base = base.get_base_script()
	return out


## The choices of a script's `kind` enum, as [label, value]; empty when it has none.
static func kinds_of(script_path: String) -> Array:
	var script := load(script_path) as Script
	if script == null:
		return []
	for p: Dictionary in script.get_script_property_list():
		if p.name != "kind" or p.hint != PROPERTY_HINT_ENUM:
			continue
		var out := []
		var next := 0
		for part: String in str(p.hint_string).split(","):
			var label := part
			var value := next
			if part.contains(":"):
				label = part.get_slice(":", 0)
				value = part.get_slice(":", 1).to_int()
			out.append([label.strip_edges(), value])
			next = value + 1
		return out
	return []


static func _scene_entry(file: String, group: String, parent: String) -> Dictionary:
	var base := file.get_file().get_basename()
	return {"label": base.capitalize(), "group": group, "scene": file, "parent": parent,
			"name": base.to_pascal_case()}


## Scene files in a folder (and its subfolders when `deep`), sorted.
static func _scenes_in(dir: String, deep: bool) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for file in DirAccess.get_files_at(dir):
		var f := file.trim_suffix(".remap")  # an exported game lists scenes as .tscn.remap
		if f.ends_with(".tscn") or f.ends_with(".scn"):
			out.append(dir + f)
	if deep:
		for sub in DirAccess.get_directories_at(dir):
			out.append_array(_scenes_in(dir + sub + "/", true))
	out.sort()
	return out
