extends RefCounted
## Makes each ready-made thing as a small tree of new nodes, set up exactly the way the levels
## already do it (same scripts, collision layers, zone sizes, materials). Nothing is added to a
## scene here: placer.gd decides where things go and adds them with undo. The prefab maker
## (tools/make_prefabs.gd) uses the same functions, so a button and a prefab always match.

const GUARD_SCENE := "res://scenes/guard.tscn"
const AGENT_DATA := "res://data/enemies/agency_agent.tres"
const BLOCK := "res://scripts/block.gd"
const CHECKPOINT := "res://scripts/checkpoint.gd"
const STORY_TRIGGER := "res://scripts/story_trigger.gd"
const INTERACTABLE := "res://scripts/interactable.gd"
const FIGHT := "res://scripts/fight.gd"
const FLICKER := "res://scripts/flicker_light.gd"
const STEAM := "res://scripts/steam_vent.gd"
const DRIP := "res://scripts/drip.gd"
const TV := "res://scripts/tv_window.gd"

## Physics layers (CLAUDE.md): 1 world, 2 player, 3 enemies. Zones listen for the player only.
const ZONE_LAYER := 0
const ZONE_MASK := 2


## An Agency agent (an instance of guard.tscn). With `route_end` (in his own space: -Z is the
## way he faces) he gets a Route with two points, A where he stands and B there.
static func guard(route_end: Variant = null, fights := false, dormant := false) -> Node3D:
	var scene := load(GUARD_SCENE) as PackedScene
	var agent := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	agent.name = "Agent"
	agent.set("data", load(AGENT_DATA))
	if fights:
		agent.set("fights", true)
	if dormant:
		agent.set("dormant", true)
	if route_end is Vector3:
		var route := Node3D.new()
		route.name = "Route"
		agent.add_child(route)
		route.add_child(patrol_point("A", Vector3.ZERO))
		route.add_child(patrol_point("B", route_end))
	return agent


## One point of a guard's walk: a Marker3D under his Route. He visits the points from the top
## of the list down, then walks back to the first.
static func patrol_point(point_name: String, at: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = point_name
	m.position = at
	return m


## A save spot: walk in and a restart (spotted, slain, fell) comes back here.
static func checkpoint() -> Area3D:
	return _zone_area("Checkpoint", CHECKPOINT, Vector3(4, 3, 3), 1.5)


## Plays a dialogue scene when Aeneas walks in. `dialogue_file` is pre-filled with the level's file.
static func story_trigger(dialogue_file: String) -> Area3D:
	var area := _zone_area("StoryTrigger", STORY_TRIGGER, Vector3(4, 3, 2), 1.5)
	area.set("dialogue_file", dialogue_file)
	area.set("scene", "")
	return area


## Something to look at ("E / Up: Look"). It starts with placeholder words in Text so it works
## at once; write your own there, or empty Text and use the level's inspect file instead.
static func look_spot(inspect_file: String) -> Area3D:
	var area := _zone_area("LookSpot", INTERACTABLE, Vector3(3, 2.5, 3), 1.25)
	area.set("label", "Look")
	area.set("text", "DRAFT: what Aeneas notices here.|Write the words in Text (lines split by a bar).")
	area.set("file", inspect_file)
	return area


## A story fight: the agents under it attack when a scene says [fight <its name>].
static func fight(dialogue_file: String) -> Node3D:
	var node := Node3D.new()
	node.name = "Fight"
	node.set_script(load(FIGHT))
	node.set("dialogue_file", dialogue_file)
	var agent := guard(null, true, true)
	agent.rotation.y = PI  # faces back the way you looked: toward Aeneas coming in
	node.add_child(agent)
	return node


## A camera for story scenes ([camera <its name>]); same lens as the town's shots.
static func camera_shot() -> Camera3D:
	var cam := Camera3D.new()
	cam.name = "Shot"
	cam.fov = 55.0
	cam.far = 320.0
	return cam


## A lamp that blinks and buzzes now and then (Personality in the Inspector).
static func flicker_light() -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "FlickerLight"
	light.light_color = Color(1, 0.78, 0.5)
	light.omni_range = 8.0
	light.set_script(load(FLICKER))
	return light


## Steam from a wall grille. The node's +X points out of the wall; `on_floor` makes a floor
## grate instead (steam straight up, a flat grate with no collision so nobody trips on it).
static func steam_vent(on_floor := false) -> Node3D:
	var vent := Node3D.new()
	vent.name = "SteamVent"
	vent.set_script(load(STEAM))
	var grille := block(Vector3(0.1, 0.5, 0.5), "res://materials/trim_vent.tres")
	grille.name = "Grille"
	grille.set("grime", 0.0)
	grille.set("trim", true)
	if on_floor:
		vent.set("direction", Vector3(0, 1, 0))
		grille.set("size", Vector3(0.6, 0.04, 0.6))
		grille.position = Vector3(0, -0.03, 0)
		grille.collision_layer = 0
	else:
		vent.set("direction", Vector3(0.5, 1, 0))
		grille.position = Vector3(-0.1, 0, 0)
	vent.add_child(grille)
	return vent


## Water dripping from here to the floor below every few seconds.
static func drip() -> Node3D:
	var node := Node3D.new()
	node.name = "Drip"
	node.set_script(load(DRIP))
	return node


## A thin glowing pane whose light cuts like a TV behind a window. Its thin side (X) faces out.
static func tv_window() -> StaticBody3D:
	var tv := StaticBody3D.new()
	tv.name = "TvWindow"
	tv.set_script(load(TV))
	tv.set("size", Vector3(0.06, 1, 1.4))
	tv.set("material", load("res://materials/window_glow.tres"))
	tv.set("grime", 0.0)
	return tv


## A plain Block (a box you can see and stand on).
static func block(size := Vector3(2, 2, 2), material := "res://materials/concrete.tres") -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "Block"
	b.set_script(load(BLOCK))
	b.set("size", size)
	b.set("material", load(material))
	return b


## A building: a Block with Style = Building (doors, shopfronts, window bays, parapet, roof).
## 12.8 m tall = the 3.2 m ground floor, three 3 m storeys and the 0.6 m parapet.
static func building() -> StaticBody3D:
	var b := block(Vector3(11, 12.8, 9), "res://materials/building.tres")
	b.name = "Building"
	b.set("style", 1)  # Block.Style.BUILDING
	return b


## A prop: a node of the script's own kind (Node3D, StaticBody3D, a light...) carrying the
## script, which builds its own mesh. Null if the script can't be loaded right now.
static func prop(script_path: String) -> Node3D:
	var native := native_base(script_path)
	var script := load(script_path) as Script
	if native == "" or script == null:
		return null
	var node := ClassDB.instantiate(native) as Node3D
	node.name = script_path.get_file().get_basename().to_pascal_case()
	node.set_script(script)
	return node


## Prop scripts in scripts/props/ and any scripts/props_*/ folder, as [label, path, group]
## (group "" for scripts/props, else the folder's level name). Read from the files' text, not
## loaded, so a prop script someone is halfway through writing can't break the list. Only
## scripts that make a 3D node count (prop_mesh.gd, a helper, and *_base.gd files are skipped).
static func list_props() -> Array:
	var found: Array = []
	var dirs: Array[String] = ["res://scripts/props"]
	for sub in DirAccess.get_directories_at("res://scripts"):
		if sub.begins_with("props_"):
			dirs.append("res://scripts/" + sub)
	for dir in dirs:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd") or file.get_basename().ends_with("_base"):
				continue
			var path := dir + "/" + file
			var native := native_base(path)
			if native == "" or not ClassDB.is_parent_class(native, "Node3D"):
				continue
			var group := "" if dir == "res://scripts/props" else dir.get_file().trim_prefix("props_").capitalize()
			found.append([file.get_basename().capitalize(), path, group])
	return found


## The engine class a script's node must be: follows "extends" through script paths and
## class_names (e.g. extends Block -> StaticBody3D). "" if it can't tell.
static func native_base(path: String, depth := 0) -> String:
	if depth > 8 or not FileAccess.file_exists(path):
		return ""
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.get_slice("#", 0).strip_edges()  # no comment
		if line.begins_with("class_name ") and line.contains(" extends "):
			line = line.substr(line.find(" extends ") + 1)  # "class_name X extends Y"
		if not line.begins_with("extends "):
			continue
		var base := line.trim_prefix("extends ").strip_edges()
		if base.begins_with("\"") or base.begins_with("'"):
			return native_base(base.substr(1, base.length() - 2), depth + 1)
		if ClassDB.class_exists(base):
			return base
		for entry: Dictionary in ProjectSettings.get_global_class_list():
			if entry["class"] == base:
				return native_base(entry["path"], depth + 1)
		return ""
	return ""


## An Area3D with a script and a box Zone, the way every trigger in the levels is made:
## origin on the floor, zone lifted so it stands on the floor, listening for the player only.
static func _zone_area(area_name: String, script_path: String, size: Vector3, lift: float) -> Area3D:
	var area := Area3D.new()
	area.name = area_name
	area.collision_layer = ZONE_LAYER
	area.collision_mask = ZONE_MASK
	area.monitorable = false
	area.set_script(load(script_path))
	var zone := CollisionShape3D.new()
	zone.name = "Zone"
	zone.position = Vector3(0, lift, 0)
	var shape := BoxShape3D.new()
	shape.size = size
	shape.resource_local_to_scene = true  # each copy gets its own box, even from a prefab
	zone.shape = shape
	area.add_child(zone)
	return area
