extends SceneTree
## Rebuilds the prefab scenes in scenes/prefabs/ (and the new-level template) from the same
## functions the dock's buttons use, so the two always match. Run it after changing builders.gd
## or adding a prop script, with Godot closed, from the project folder:
##   godot --headless --path . -s res://addons/aethereal_tools/tools/make_prefabs.gd

const Builders := preload("res://addons/aethereal_tools/builders.gd")
const OUT := "res://scenes/prefabs"


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/props"))
	var made := _save_guard()
	made += _save(Builders.patrol_point("PatrolPoint", Vector3.ZERO), "patrol_point")
	made += _save(Builders.checkpoint(), "checkpoint")
	made += _save(Builders.story_trigger(""), "story_trigger")
	made += _save(Builders.look_spot(""), "look_at_spot")
	made += _save(Builders.fight(""), "fight")
	made += _save(Builders.camera_shot(), "camera_shot")
	made += _save(Builders.flicker_light(), "flickering_light")
	made += _save(Builders.steam_vent(false), "steam_vent")
	made += _save(Builders.steam_vent(true), "steam_grate")
	made += _save(Builders.drip(), "drip")
	made += _save(Builders.tv_window(), "tv_window")
	made += _save(Builders.block(), "block")
	made += _save(Builders.building(), "building")
	for entry: Array in Builders.list_props():
		var path: String = entry[1]
		var node := Builders.prop(path) if entry[2] == "" else null  # the town's props (scripts/props/)
		if node:
			made += _save(node, "props/" + path.get_file().get_basename())
	await process_frame
	made += await _save_template()
	print("PREFABS: %d saved" % made)
	quit()


## Owns every new node to the prefab's root (not the insides of an instanced guard), packs, saves.
func _save(node: Node, file: String) -> int:
	_own(node, node)
	var packed := PackedScene.new()
	var err := packed.pack(node)
	if err == OK:
		err = ResourceSaver.save(packed, "%s/%s.tscn" % [OUT, file])
	print("%-28s %s" % [file, "ok" if err == OK else "ERROR %d" % err])
	node.free()
	return 1 if err == OK else 0


## The guard prefab is a scene that INHERITS guard.tscn and adds a two-point Route, so it
## follows every change to guard.tscn (his model, his numbers). Packing from a script can't
## make an inherited scene, so this one is written out as text.
func _save_guard() -> int:
	var text := """[gd_scene format=3]

[ext_resource type="PackedScene" path="%s" id="1_guard"]

[node name="Agent" instance=ExtResource("1_guard")]

[node name="Route" type="Node3D" parent="."]

[node name="A" type="Marker3D" parent="Route"]

[node name="B" type="Marker3D" parent="Route"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -4)
""" % Builders.GUARD_SCENE
	var f := FileAccess.open(OUT + "/agency_guard.tscn", FileAccess.WRITE)
	if f == null:
		print("agency_guard                 ERROR")
		return 0
	f.store_string(text)
	f.close()
	print("agency_guard                 ok")
	return 1


func _own(node: Node, root: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = root
		if child.owner == root:
			_own(child, root)


## The new-level template: floor, sky and fog, the Player, the StealthDirector, an opening shot,
## the arrival trigger, the usual group nodes, and a Navigation node already baked for the floor.
func _save_template() -> int:
	var level := Node3D.new()
	level.name = "LevelTemplate"
	level.add_to_group("navmesh_source", true)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.65)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.05, 0.06, 0.1)
	env.fog_depth_begin = 10.0
	env.fog_depth_end = 80.0
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = env
	level.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_color = Color(0.75, 0.8, 1.0)
	sun.light_energy = 0.5
	level.add_child(sun)
	var layout := _group(level, "Layout")
	var ground := Builders.block(Vector3(40, 1, 40), "res://materials/pavement.tres")
	ground.name = "Ground"
	ground.position = Vector3(0, -0.5, 0)
	layout.add_child(ground)
	var house := Builders.building()
	house.position = Vector3(-12, 6.4, -12)
	layout.add_child(house)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector3(0, 0, 12)
	level.add_child(player)
	for g in ["Guards", "Checkpoints", "Inspect", "Life", "Dressing"]:
		_group(level, g)
	var shot := Builders.camera_shot()
	shot.name = "OpeningShot"
	var eye := Vector3(3.5, 2.2, 17.5)
	shot.transform = Transform3D(Basis.looking_at(Vector3(0, 1.2, 12) - eye, Vector3.UP), eye)
	_group(level, "Shots").add_child(shot)
	var arrival := Builders.story_trigger("")
	arrival.name = "Arrival"
	arrival.set("scene", "arrival")
	arrival.position = Vector3(0, 0, 12)
	_group(level, "StoryTriggers").add_child(arrival)
	var director := (load("res://scenes/stealth_director.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	director.name = "StealthDirector"
	level.add_child(director)
	director.set("player", player)
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	region.navigation_mesh = _navmesh()
	level.add_child(region)
	await _bake(region.navigation_mesh, layout)
	return _save(level, "level_template")


func _group(parent: Node, group_name: String) -> Node3D:
	var existing := parent.get_node_or_null(group_name) as Node3D
	if existing:
		return existing
	var g := Node3D.new()
	g.name = group_name
	parent.add_child(g)
	return g


## The same settings as the Empty Town's mesh (scratch bake_nav.gd), for the whole level.
func _navmesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.25
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 45.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "navmesh_source"
	return nm


## Bakes from a throwaway copy of the floor and buildings (so no Player or director starts up).
func _bake(nm: NavigationMesh, layout: Node3D) -> void:
	var temp := Node3D.new()
	temp.add_to_group("navmesh_source")  # the mesh reads nodes in this group (like the level root)
	temp.add_child(layout.duplicate())
	root.add_child(temp)
	await physics_frame
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, temp)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	print("template navmesh: %d polygons" % nm.get_polygon_count())
	temp.queue_free()
