extends "res://tools/generators/massacre_layout.gd"
## Rebuilds the Massacre (scenes/levels/massacre.tscn), the author's layout of 2026-11-07: the
## village packed close round a big courtyard; the Agency breaks the courtyard gate during the
## festival while the clan's men fight them; Aeneas runs home across the courtyard (agents hunt
## him: a grab restarts), his father holds the door, his brother takes him and Isabella down to
## the cellar and holds the ramp while the capsule leaves on its line.
## Keeps the scene's Player (the four-year-old's setup), WorldEnvironment, Sun and MemoryFade;
## everything else is built here (massacre_layout.gd has the buildings). Run once, Godot closed:
##   godot --headless --path PROJ -s res://tools/generators/build_massacre.gd
## After that the scene file is the source of truth. It also bakes data/nav/massacre_navmesh.tres.

const MASSACRE_OUT := "res://scenes/levels/massacre.tscn"
const NAV_OUT := "res://data/nav/massacre_navmesh.tres"
const DLG := "res://data/dialogue/massacre.txt"
const KEEP := ["WorldEnvironment", "Sun", "MemoryFade", "Player"]
const F := "res://scripts/props_massacre/crowd_figure.gd"
const AGENT := "res://data/enemies/agency_agent.tres"

var _player: Node3D


func _initialize() -> void:
	_run()


## Built out of the tree, so nothing runs before it is saved (a running Player would save his
## HUD's and camera's runtime state into the scene). The navmesh is baked from a running copy.
func _run() -> void:
	_root = _load_edit()
	for child in _root.get_children():
		if not child.name in KEEP:
			_root.remove_child(child)
			child.free()
	_player = _root.get_node("Player")
	_root.set_editable_instance(_player, true)  # keeps the four-year-old's model, camera and capsule
	_root.set_editable_instance(_player.get_node("Model"), true)  # and no sword, knife or rifle on him
	_player.position = Vector3(0, 0.5, -7)
	_root.add_to_group("navmesh_source", true)
	_hall()
	_grow_lamps()
	_village()
	_courtyard()
	_family_house()
	_people()
	_agency()
	_story()
	_life()
	for n in _notes:
		print("NOTE: ", n)
	_save(_root)
	var live: Node = (ResourceLoader.load(MASSACRE_OUT, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	root.add_child(live)
	for i in 90:  # let every Block and prop build its mesh and collision before the bake
		await physics_frame
	var nav := _bake_navigation(live)
	live.queue_free()
	await process_frame
	var again := _load_edit()
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nav
	_root = again
	_add(again, region, "Navigation")
	_save(again)
	quit()


func _load_edit() -> Node:
	var packed := ResourceLoader.load(MASSACRE_OUT, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	return packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)


func _save(scene: Node) -> void:
	var out := PackedScene.new()
	var err := out.pack(scene)
	if err == OK:
		err = ResourceSaver.save(out, MASSACRE_OUT)
	print("BUILD MASSACRE ", "ok" if err == OK else "failed %d" % err, " -> ", MASSACRE_OUT)


## Out of the tree a camera can't look_at; aim it by its basis instead.
func _shot(parent: Node, name: String, from: Vector3, to: Vector3, fov := 60.0) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = fov
	cam.far = 120.0
	_add(parent, cam, name, from)
	cam.basis = Basis.looking_at(to - from, Vector3.UP)
	return cam


## A group the story shows or hides; hidden, nothing inside it is solid (hidden_solids.gd).
func _stage_group(parent: Node, name: String, shown := false) -> Node3D:
	var g := _group(parent, name)
	g.set_script(load(P + "hidden_solids.gd"))
	g.visible = shown
	return g


func _figure(parent: Node, name: String, at: Vector3, yaw: float, props := {}) -> void:
	_prop(parent, F, name, at, props, yaw)


## An Agency agent (scenes/guard.tscn). yaw 0 faces -Z. Hunters run at Aeneas while shown;
## the others stand where the story poses them (dormant: no sight, no fighting).
func _agent(parent: Node, name: String, at: Vector3, yaw: float, hunt_speed := 0.0) -> Node:
	var g: Node3D = load("res://scenes/guard.tscn").instantiate()
	g.set("data", load(AGENT))
	g.set("dormant", hunt_speed <= 0.0)
	g.set("hunts", hunt_speed > 0.0)
	if hunt_speed > 0.0:
		g.set("hunt_speed", hunt_speed)
	return _add(parent, g, name, at, yaw)


func _people() -> void:
	var isabella: Node3D = load("res://scenes/isabella.tscn").instantiate()
	_add(_root, isabella, "Isabella", Vector3(-1.3, 0.6, -5.6))
	isabella.set("leader", _player)
	var director: Node = load("res://scenes/stealth_director.tscn").instantiate()
	_add(_root, director, "StealthDirector")
	director.set("player", _player)
	var figs := _group(_root, "Figures")
	# The festival: the courtyard full of people (gone when the gate breaks).
	var crowd := _stage_group(figs, "Crowd", true)
	var spots := [[-5.0, -4.0], [-3.0, 0.5], [4.5, -3.5], [6.5, 1.0], [-9.0, 3.0], [9.5, -6.0], [-11.0, -7.5],
			[2.0, 4.5], [-6.5, 7.5], [5.0, 8.5], [12.0, 3.5], [-14.0, 0.0], [-2.0, 10.0], [14.0, -9.0],
			[-17.0, -10.5], [1.0, -12.0]]
	for i in spots.size():
		var s: Array = spots[i]
		_figure(crowd, "Villager%d" % i, Vector3(s[0], 0, s[1]), 37.0 * i + 200.0, {"kind": 1 if i % 5 == 3 else 0, "variant": i})
	_figure(crowd, "Elder", Vector3(-0.5, 0, -12.6), 0.0, {"kind": 2})
	_figure(crowd, "AnchisesFest", Vector3(-1.8, 0, -9.4), 180.0, {"kind": 0, "variant": 5, "height": 1.9})
	_figure(crowd, "BrotherFest", Vector3(1.9, 0, -9.2), 160.0, {"kind": 0, "variant": 9, "height": 1.6})
	# The clan's men, fighting the Agency in the courtyard (shown at the breach).
	var defenders := _stage_group(figs, "Defenders")
	for d in [["Defender1", -15.4, 9.0, 90.0], ["Defender2", -19.0, 0.6, 0.0], ["Defender3", 10.4, 13.0, -90.0], ["Defender4", -7.0, 12.1, 0.0]]:
		_figure(defenders, d[0], Vector3(d[1], 0, d[2]), d[3], {"kind": 3, "variant": int(d[1])})
	# The family, where each scene leaves them. Black coats, blades: the clan's fighters.
	var dad := {"kind": 3, "variant": 5, "height": 1.9}
	var bro := {"kind": 3, "variant": 9, "height": 1.6}
	var at_door := _stage_group(figs, "DoorFamily")  # ahead of him, at home, while he runs
	_figure(at_door, "Anchises", Vector3(17.6, 0, 3.9), -90.0, dad)
	_figure(at_door, "Brother", Vector3(19.7, 0, 4.6), -90.0, bro)
	var stand := _stage_group(figs, "HouseStand")  # his father in the doorway
	_figure(stand, "AnchisesDoor", Vector3(19.0, 0, DOOR_Z), -90.0, dad)
	var bro_house := _stage_group(figs, "BrotherHouse")  # his brother at the top of the ramp
	_figure(bro_house, "BrotherRamp", Vector3(24.6, 0, 5.0), -90.0, bro)
	var cellar := _stage_group(figs, "CellarStand")  # his brother at the foot of the ramp
	_figure(cellar, "BrotherCellar", Vector3(24.5, CELLAR_Y, -5.7), 0.0, bro)


func _agency() -> void:
	var ag := _group(_root, "Agency")
	var hunters := _stage_group(ag, "Hunters")
	var h := [[-2.5, 15.5, 3.0], [2.5, 15.8, 3.1], [0.0, 14.2, 3.25], [-6.8, 15.0, 2.9], [6.8, 15.2, 3.05]]
	for i in h.size():
		_agent(hunters, "Hunter%d" % (i + 1), Vector3(h[i][0], 0.05, h[i][1]), 0.0, h[i][2])
	var court := _stage_group(ag, "CourtFight")
	for a in [["CourtAgent1", -14.0, 9.0, 90.0], ["CourtAgent2", -19.0, 2.0, 0.0], ["CourtAgent3", 9.0, 13.0, -90.0], ["CourtAgent4", -7.0, 13.5, 0.0]]:
		_agent(court, a[0], Vector3(a[1], 0.05, a[2]), a[3])
	var door := _stage_group(ag, "DoorFight")
	_agent(door, "DoorAgent1", Vector3(17.4, 0.05, 4.0), -90.0)
	_agent(door, "DoorAgent2", Vector3(17.1, 0.05, 5.3), -90.0)
	var inside := _stage_group(ag, "HouseHunter")
	_agent(inside, "HouseHunter1", Vector3(16.4, 0.05, DOOR_Z), -90.0, 2.9)
	var ramp := _stage_group(ag, "CellarAgents")
	_agent(ramp, "CellarAgent1", Vector3(24.0, -2.95, -2.0), 0.0)
	_agent(ramp, "CellarAgent2", Vector3(25.1, -1.7, 0.6), 0.0)


func _story() -> void:
	var shots := _group(_root, "Shots")
	_shot(shots, "CourtyardShot", Vector3(-9, 5.5, 1), Vector3(1, 1.4, -11), 55.0)
	_shot(shots, "GateShot", Vector3(0.5, 2.0, 5), Vector3(0, 2.0, 18), 55.0)
	_shot(shots, "FightShot", Vector3(-13, 3.2, 1), Vector3(-8, 1.0, 11), 55.0)
	_shot(shots, "HomeShot", Vector3(8, 2.2, 0), Vector3(19, 1.2, DOOR_Z), 50.0)
	_shot(shots, "DoorShot", Vector3(24.2, 1.6, 3.6), Vector3(17.5, 1.2, DOOR_Z), 55.0)
	_shot(shots, "StandShot", Vector3(14.2, 1.7, 2.4), Vector3(19.0, 1.3, DOOR_Z), 50.0)
	_shot(shots, "PodShot", Vector3(25.4, -2.7, -6.6), Vector3(20.6, -3.6, -11), 55.0)
	_shot(shots, "StairShot", Vector3(22.2, -3.3, -9.2), Vector3(24.8, -2.6, -1.5), 55.0)
	_shot(shots, "LaunchShot", Vector3(16.5, -3.2, -7.3), Vector3(12.8, -3.2, -11), 55.0)
	var tr := _group(_root, "StoryTriggers")
	var S := "res://scripts/story_trigger.gd"
	_area(tr, "Memory", Vector3(0, 0, -7), Vector3(6, 3, 6), S, {"dialogue_file": DLG, "scene": "memory"})
	# The gate breaks as soon as he walks a few steps from where the memory opens, any way but
	# north (the Great House's veranda): three boxes round a pocket at the start.
	var men := _area(tr, "TheMen", Vector3(0, 0, 7.75), Vector3(55, 3, 19.5), S, {"dialogue_file": DLG, "scene": "the_men"})
	for z in [["West", -17.25, 20.5], ["East", 12.75, 11.5]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(z[2], 3, 11)
		shape.shape = box
		_add(men, shape, "Zone" + z[0], Vector3(z[1], 1.5, -15.25))
	_area(tr, "TheHouse", Vector3(20.6, 0, DOOR_Z), Vector3(1.4, 3, 1.8), S, {"dialogue_file": DLG, "scene": "the_house"})
	_area(tr, "ThePod", Vector3(21, CELLAR_Y, -8.6), Vector3(3, 3, 1.6), S, {"dialogue_file": DLG, "scene": "the_pod"})
	var cps := _group(_root, "Checkpoints")  # in route order: restarts only move forward
	_area(cps, "HouseDoor", Vector3(20.6, 0, DOOR_Z), Vector3(1.4, 3, 1.8), "res://scripts/checkpoint.gd")
	_area(cps, "CellarFoot", Vector3(24.5, CELLAR_Y, -6.4), Vector3(3, 3, 1.2), "res://scripts/checkpoint.gd")
	var q := _add(_root, Node3D.new(), "Quake")
	q.set_script(load("res://scripts/vfx/quake.gd"))
	var ins := _group(_root, "Inspect")
	var I := "res://scripts/interactable.gd"
	var file := "res://data/inspect/massacre.txt"
	_area(ins, "Drum", Vector3(-6, 0, -11), Vector3(3, 2.5, 3), I, {"label": "Look at the drum", "file": file, "reach": 2.4})
	_area(ins, "Shrine", Vector3(-23, 0, -19), Vector3(3, 2.5, 3), I, {"label": "Look at the shrine", "file": file, "reach": 2.6})
	_area(ins, "FoodStall", Vector3(-22.6, 0, 0), Vector3(3, 2.5, 3), I, {"label": "Look at the stall", "file": file, "reach": 2.4})


func _life() -> void:
	var look := _group(_root, "LookDressing")
	_prop(look, "res://scripts/cloud_layer.gd", "Smoke", Vector3(0, 13, 6), {"size": Vector2(100, 110), "sheets": 2,
			"spacing": 4.0, "material": load("res://materials/clouds_massacre.tres")})
	_prop(look, "res://scripts/props_kit/drift_lights.gd", "Embers", Vector3(0, 4, -2), {"count": 10,
			"box_size": Vector3(40, 6, 26), "color": Color(1, 0.6, 0.28), "speed": 0.25, "size": 0.08,
			"brightness": 1.2, "cast_light": false, "random_seed": 7})
	var picks := [Vector3(-6, 0, 0), Vector3(-24, 0, 30)]
	for k in picks.size():
		var best := _lit_panels[0]
		for p in _lit_panels:
			if Vector2(p.x, p.z).distance_to(Vector2(picks[k].x, picks[k].z)) < Vector2(best.x, best.z).distance_to(Vector2(picks[k].x, picks[k].z)):
				best = p
		_prop(look, "res://scripts/props_kit/light_shaft.gd", "Shaft%d" % k, best - Vector3(0, 0.35, 0), {"length": best.y - 0.35,
				"radius_top": 2.6, "radius_bottom": 6.0, "color": Color(0.6, 0.68, 0.95), "strength": 0.2 - 0.02 * k, "mote_count": 16})
	var snd := _group(_root, "Sounds")
	var water := AudioStreamPlayer3D.new()
	water.stream = load("res://audio/running_water.wav")
	water.volume_db = -18.0
	water.unit_size = 3.0
	water.max_distance = 14.0
	water.autoplay = true
	water.bus = &"SFX"
	_add(snd, water, "Water", Vector3(0, 0.3, -30))


## The navigation mesh the hunters run over: the courtyard, the family house, the ramp and the
## cellar (everything solid on layer 1; the gate is shut and the stage groups hidden while it bakes).
func _bake_navigation(level: Node) -> NavigationMesh:
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
	nm.filter_baking_aabb = AABB(Vector3(-29, -6, -25), Vector3(63, 11, 44))
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, level)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	print("navmesh: %d polygons" % nm.get_polygon_count())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/nav"))
	ResourceSaver.save(nm, NAV_OUT)
	nm.take_over_path(NAV_OUT)
	return nm
