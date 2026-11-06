extends SceneTree
## Builds the Horus arc's rough-cut level, scenes/levels/horus_road.tscn, from the geography in
## docs/act1_horus.md: the capsule's platform in the south, the pipe, three days of dunes, the
## farmer's shack, the Obelisk on the ridge, Temek's lake in the north. Run it once (Godot closed):
##   godot --headless --path PROJ -s res://tools/generators/build_horus.gd
## After that the scene file is the source of truth: edit it, don't regenerate (unless you mean to
## start over). Props come from scripts/props_horus/ and scripts/props_kit/; a prop whose script
## is missing is skipped with a note, so the level builds even while those are being written.

const OUT := "res://scenes/levels/horus_road.tscn"
const SAND := "res://materials/horus_sand.tres"
const GROUND_Y := 6.0  # the desert floor where the terrain is flat (the road's height in the south)

var _root: Node3D
var _terrain: Node
var _notes: PackedStringArray = []


func _initialize() -> void:
	_root = Node3D.new()
	_root.name = "HorusRoad"
	root.add_child(_root)
	_environment()
	_terrain_and_ground()
	_platform()
	_pipe()
	_desert()
	_shack()
	_obelisk()
	_temek()
	_people()
	_story()
	_life()
	for n in _notes:
		print("NOTE: ", n)
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("BUILD HORUS ", "ok" if err == OK else "failed %d" % err, " -> ", OUT)
	quit()


# ---------------------------------------------------------------- helpers
func _own(n: Node) -> void:
	n.owner = _root
	for c in n.get_children():
		if c.owner == null and not c.name.begins_with("@"):
			_own(c)


func _add(parent: Node, n: Node, name: String, at := Vector3.ZERO, yaw_deg := 0.0) -> Node:
	n.name = name
	parent.add_child(n)
	if n is Node3D:
		(n as Node3D).position = at
		(n as Node3D).rotation.y = deg_to_rad(yaw_deg)
	_own(n)
	return n


func _group(parent: Node, name: String) -> Node3D:
	return _add(parent, Node3D.new(), name) as Node3D


## A node with a script from scripts/, with the exports it has set from `props`.
func _prop(parent: Node, script_path: String, name: String, at: Vector3, props := {}, yaw_deg := 0.0) -> Node:
	if not ResourceLoader.exists(script_path):
		_notes.append("missing %s (for %s)" % [script_path, name])
		return null
	var scr: Script = load(script_path)
	var n: Node = scr.new()
	for key: String in props:
		if key in n:
			n.set(key, props[key])
		else:
			_notes.append("%s has no export '%s'" % [script_path.get_file(), key])
	return _add(parent, n, name, at, yaw_deg)


func _block(parent: Node, name: String, at: Vector3, size: Vector3, mat_path: String, yaw_deg := 0.0, extra := {}) -> Node:
	var b := Block.new()
	b.size = size
	b.material = load(mat_path)
	for key: String in extra:
		b.set(key, extra[key])
	return _add(parent, b, name, at, yaw_deg)


func _ground(x: float, z: float) -> float:
	if _terrain and _terrain.has_method("height_at"):
		return _terrain.height_at(x, z)
	return GROUND_Y


func _marker(parent: Node, name: String, at: Vector3, yaw_deg := 0.0) -> Marker3D:
	return _add(parent, Marker3D.new(), name, at, yaw_deg) as Marker3D


func _shot(parent: Node, name: String, from: Vector3, to: Vector3, fov := 60.0) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = fov
	cam.far = 400.0
	_add(parent, cam, name, from)
	cam.look_at_from_position(from, to, Vector3.UP)
	return cam


func _area(parent: Node, name: String, at: Vector3, size: Vector3, script_path: String, props := {}) -> Area3D:
	var a := Area3D.new()
	a.set_script(load(script_path))
	a.collision_layer = 0
	a.collision_mask = 2
	a.monitorable = false
	for key: String in props:
		a.set(key, props[key])
	_add(parent, a, name, at)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	_add(a, shape, "Zone", Vector3(0, size.y * 0.5, 0))
	return a


func _light(parent: Node, name: String, at: Vector3, color: Color, energy: float, range_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.shadow_enabled = false
	return _add(parent, l, name, at) as OmniLight3D


# ---------------------------------------------------------------- the level
func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.19, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.48, 0.32)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.36, 0.23, 0.10)
	env.fog_density = 1.0
	env.fog_depth_begin = 6.0
	env.fog_depth_end = 190.0
	env.fog_depth_curve = 1.3
	we.environment = env
	_add(_root, we, "WorldEnvironment")
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.9, 0.7, 0.45)
	sun.light_energy = 0.35
	sun.shadow_enabled = false
	_add(_root, sun, "Sun")
	sun.rotation_degrees = Vector3(-62, 35, 0)


func _terrain_and_ground() -> void:
	# The road: south platform top, winding north, up the ridge, down to the lake.
	var road := PackedVector3Array([
		Vector3(0, GROUND_Y, 283), Vector3(0, GROUND_Y, 250), Vector3(18, GROUND_Y + 1.5, 200),
		Vector3(-8, GROUND_Y + 2, 130), Vector3(24, GROUND_Y + 4, 60), Vector3(-18, GROUND_Y + 3, -20),
		Vector3(8, GROUND_Y + 5, -100), Vector3(-30, GROUND_Y + 6, -140), Vector3(-10, GROUND_Y + 10, -200),
		Vector3(0, GROUND_Y + 18, -255), Vector3(0, GROUND_Y + 10, -290), Vector3(0, 0.5, -330), Vector3(0, 0.5, -360),
	])
	var pads := PackedVector3Array([Vector3(-30, GROUND_Y + 6, -140), Vector3(0, GROUND_Y + 18, -258), Vector3(44, GROUND_Y + 1, 262)])
	_terrain = _prop(_root, "res://scripts/props_horus/desert_terrain.gd", "Desert", Vector3(0, 0, -69.5),  # its edge just north of z 283, the ramp top: the cutting is south of it
			{"size": Vector2(360, 703), "seed": 1101, "amplitude": 9.0, "road": road, "road_width": 14.0,
			"pads": pads, "pad_radius": 16.0, "rim": 14.0, "material": load(SAND) if ResourceLoader.exists(SAND) else null})
	if _terrain == null:
		# No terrain builder yet: a flat sand floor so the level is walkable.
		_block(_root, "SandFloor", Vector3(0, GROUND_Y - 0.5, -58.5), Vector3(360, 1, 683), "res://materials/black_sand_dunes.tres")
	else:
		for i in 3:
			if _terrain.has_method("_rebuild_now"):
				break


func _platform() -> void:
	var g := _group(_root, "Platform")
	# A concrete cutting at the south end: the tube mouth, the platform at y = 0, a ramp up to the sand.
	_block(g, "Floor", Vector3(0, -0.5, 318), Vector3(24, 1, 30), "res://materials/vacuum_station_floor_worn.tres")
	_block(g, "WallW", Vector3(-12.5, GROUND_Y * 0.5 + 1, 318), Vector3(1, GROUND_Y + 2, 30), "res://materials/concrete_dark_worn.tres")
	_block(g, "WallE", Vector3(12.5, GROUND_Y * 0.5 + 1, 318), Vector3(1, GROUND_Y + 2, 30), "res://materials/concrete_dark_worn.tres")
	_block(g, "TubeMouth", Vector3(0, 5, 336), Vector3(24, 12, 6), "res://materials/vacuum_station_capsule_wall.tres")
	_block(g, "TubeHole", Vector3(0, 3.5, 333.5), Vector3(8, 7, 1), "res://materials/black_cube.tres")
	# The capsule, stopped at the platform (a house-sized car).
	_block(g, "Capsule", Vector3(0, 3, 324), Vector3(8, 6, 14), "res://materials/vacuum_station_capsule_wall.tres", 0.0, {"grime": 0.5})
	_block(g, "CapsuleDoor", Vector3(-4.05, 1.5, 320), Vector3(0.1, 2.6, 2.0), "res://materials/black_cube.tres")
	# The ramp out: 2 m up... the sand is GROUND_Y high, so a long ramp (no steps).
	# Its top face runs from (y 0, z 309) to (y GROUND_Y, z 283) exactly, so neither end has a lip.
	var slope := atan2(GROUND_Y, 26.0)
	var centre := Vector3(0, GROUND_Y * 0.5, 296) - Vector3(0, cos(slope), sin(slope)) * 0.3
	var ramp := _block(g, "Ramp", centre, Vector3(10, 0.6, sqrt(26.0 * 26.0 + GROUND_Y * GROUND_Y)), "res://materials/concrete_worn.tres") as Node3D
	ramp.rotation.x = slope
	_light(g, "PlatformLamp", Vector3(0, 7, 318), Color(1.0, 0.75, 0.45), 1.6, 18.0)
	_light(g, "TubeLamp", Vector3(0, 6, 331), Color(0.55, 0.75, 0.9), 1.2, 12.0)


func _pipe() -> void:
	var g := _group(_root, "Pipe")
	var y := GROUND_Y + 5.0
	var points := PackedVector3Array([Vector3(44, y, 262), Vector3(42, y, 180), Vector3(36, y + 2, 60),
			Vector3(40, y + 5, -80), Vector3(32, y + 12, -220), Vector3(26, y + 8, -300), Vector3(22, y - 2, -400)])
	_prop(g, "res://scripts/props_horus/pump_house.gd", "PumpHouse", Vector3(44, _ground(44, 262), 268))
	var whole := _prop(g, "res://scripts/props_horus/construct_pipe.gd", "PipeWhole", Vector3.ZERO, {"points": points, "broken": false})
	var broken := _prop(g, "res://scripts/props_horus/construct_pipe.gd", "PipeBroken", Vector3.ZERO,
			{"points": points, "broken": true, "break_at": 1.0})
	if broken:
		(broken as Node3D).visible = false
		var spray := broken.get_node_or_null("Spray")
		if spray:
			(spray as Node3D).visible = false
	if whole == null:
		# No pipe builder yet: a long box on legs so the line reads.
		for i in points.size() - 1:
			var a := points[i]
			var b := points[i + 1]
			var mid := (a + b) * 0.5
			var seg := _block(g, "PipeSeg%d" % i, mid, Vector3(4, 4, a.distance_to(b)), "res://materials/pipe_rust.tres") as Node3D
			seg.look_at_from_position(mid, b, Vector3.UP)


func _desert() -> void:
	var g := _group(_root, "Dunes")
	# Half-buried old infrastructure, the same relics as Black Sand, warmer.
	var relics := [
		["res://scripts/props_black_sand/sand_structure.gd", "Column1", Vector3(-70, 0, 160), {"kind": 0, "length": 80.0}],
		["res://scripts/props_black_sand/sand_structure.gd", "Pylon1", Vector3(90, 0, 40), {"kind": 1, "length": 40.0}],
		["res://scripts/props_black_sand/sand_structure.gd", "Rib1", Vector3(-90, 0, -40), {"kind": 5, "length": 60.0}],
		["res://scripts/props_black_sand/sand_relic.gd", "Relic1", Vector3(60, 0, 120), {"kind": 1}],
		["res://scripts/props_black_sand/sand_relic.gd", "Relic2", Vector3(-50, 0, 20), {"kind": 3}],
		["res://scripts/props_black_sand/sand_hulk.gd", "Hulk1", Vector3(70, 0, -60), {"kind": 1}],
		["res://scripts/props_black_sand/sand_structure.gd", "Vent1", Vector3(-60, 0, -100), {"kind": 2, "length": 30.0}],
	]
	for r in relics:
		var at: Vector3 = r[2]
		at.y = _ground(at.x, at.z) - 1.0
		_prop(g, r[0], r[1], at, r[3])
	# A dead derrick, leaning, off the road on the second day.
	_prop(g, "res://scripts/props_horus/derrick.gd", "DeadDerrick", Vector3(60, _ground(60, 100), 100), {"lit": false, "lean": 12.0}, 20.0)
	# Mirages: sheets of "water" lying between dunes; the scene hides them as he nears.
	var mirages := _group(_root, "Mirages")
	for i in 3:
		var at: Vector3 = [Vector3(-40, 0, 90), Vector3(50, 0, -10), Vector3(-60, 0, -70)][i]
		at.y = _ground(at.x, at.z) + 0.3
		var m := _prop(mirages, "res://scripts/props_horus/lake.gd", "Mirage%d" % (i + 1), at, {"size": Vector2(40, 24)})
		if m == null:
			_block(mirages, "Mirage%d" % (i + 1), at, Vector3(40, 0.2, 24), "res://materials/empty_town_water_still.tres")


func _shack() -> void:
	var g := _group(_root, "Farm")
	var at := Vector3(-30, _ground(-30, -140), -140)
	var shack := _prop(g, "res://scripts/props_horus/desert_shack.gd", "Shack", at, {}, 90.0)
	if shack == null:
		_block(g, "ShackBox", at + Vector3(0, 1.6, 0), Vector3(6, 3.2, 8), "res://materials/black_sand_hull_rust_worn.tres")
	for i in 4:
		_prop(g, "res://scripts/props_horus/condenser_frame.gd", "Frames%d" % (i + 1),
				Vector3(-30 + 12 + i * 5, _ground(-18 + i * 5, -150), -150), {"rows": 1, "per_row": 4}, 10.0 * i)
	_light(g, "ShackLamp", at + Vector3(3, 2.6, 0), Color(1.0, 0.72, 0.4), 1.4, 12.0)


func _obelisk() -> void:
	var g := _group(_root, "Obelisk")
	var at := Vector3(0, _ground(0, -258), -258)
	var ob := _prop(g, "res://scripts/props_horus/obelisk.gd", "Obelisk", at + Vector3(14, 0, 0), {"height": 40.0, "lit": true})
	if ob == null:
		_block(g, "ObeliskBox", at + Vector3(14, 20, 0), Vector3(5, 40, 5), "res://materials/black_cube.tres")
	_light(g, "ObeliskGlow", at + Vector3(10, 6, 0), Color(0.6, 0.8, 1.0), 1.0, 24.0)


func _temek() -> void:
	var g := _group(_root, "Temek")
	var lake := _prop(g, "res://scripts/props_horus/lake.gd", "Lake", Vector3(0, -2.0, -520), {"size": Vector2(700, 380)})
	if lake == null:
		_block(g, "LakeBox", Vector3(0, -2.5, -520), Vector3(700, 1, 380), "res://materials/empty_town_water_still.tres")
	# The causeway out over the water, and its first gate: the rough cut ends there.
	_block(g, "Causeway", Vector3(0, -0.5, -400), Vector3(10, 1, 140), "res://materials/massacre_stone.tres")
	_block(g, "CausewayFoot", Vector3(0, -0.5, -345), Vector3(30, 1, 30), "res://materials/massacre_stone.tres")
	var gate := _prop(g, "res://scripts/props_horus/causeway_gate.gd", "Gate", Vector3(0, 0, -360), {})
	if gate == null:
		_block(g, "GateW", Vector3(-4, 4, -360), Vector3(2, 8, 2), "res://materials/massacre_stone.tres")
		_block(g, "GateE", Vector3(4, 4, -360), Vector3(2, 8, 2), "res://materials/massacre_stone.tres")
		_block(g, "GateLintel", Vector3(0, 8.5, -360), Vector3(10, 1, 2), "res://materials/massacre_stone.tres")
	# Pyramids over the water and derricks burning along the shore.
	var pyr := [[Vector3(-110, -2, -470), 60.0], [Vector3(10, -2, -540), 90.0], [Vector3(120, -2, -480), 50.0]]
	for i in pyr.size():
		var p := _prop(g, "res://scripts/props_horus/pyramid.gd", "Pyramid%d" % (i + 1), pyr[i][0], {"base": pyr[i][1], "steps": 7})
		if p == null:
			_block(g, "Pyramid%d" % (i + 1), pyr[i][0] + Vector3(0, pyr[i][1] * 0.35, 0), Vector3(pyr[i][1], pyr[i][1] * 0.7, pyr[i][1]), "res://materials/black_cube.tres", 45.0)
	var shore := [Vector3(-130, 0, -345), Vector3(-75, 0, -335), Vector3(70, 0, -338), Vector3(120, 0, -350), Vector3(-40, -1, -420), Vector3(60, -1, -440)]
	for i in shore.size():
		var d := _prop(g, "res://scripts/props_horus/derrick.gd", "Derrick%d" % (i + 1), shore[i], {"lit": true, "lean": 0.0}, 30.0 * i)
		if d == null:
			_block(g, "Derrick%dBox" % (i + 1), shore[i] + Vector3(0, 14, 0), Vector3(4, 28, 4), "res://materials/pipe_rust.tres")
			_light(g, "Flare%d" % (i + 1), shore[i] + Vector3(0, 30, 0), Color(1.0, 0.55, 0.2), 3.0, 60.0)
	# Nothing past the gate: a wall of haze and an invisible stop.
	var stop := StaticBody3D.new()
	_add(g, stop, "CausewayStop", Vector3(0, 2, -372))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(14, 6, 1)
	shape.shape = box
	_add(stop, shape, "Shape")


func _people() -> void:
	var player: Node3D = load("res://scenes/player.tscn").instantiate()
	_add(_root, player, "Player", Vector3(0, 0.6, 316))  # unrotated: the camera pivot turns inside it
	var kael: Node3D = load("res://scenes/kael.tscn").instantiate()
	_add(_root, kael, "Kael", Vector3(2.5, 0.6, 314))
	kael.set("leader", player)  # packed as a node path with node_paths=...
	var director: Node = load("res://scenes/stealth_director.tscn").instantiate()
	_add(_root, director, "StealthDirector")
	director.set("player", player)
	var figures := _group(_root, "Figures")
	_prop(figures, "res://scripts/props_massacre/crowd_figure.gd", "Farmer", Vector3(-18, _ground(-18, -146), -146), {"kind": 2, "variant": 3}, 200.0)
	for i in 4:
		var at := Vector3(-6 + i * 4, 0.0, -352 + (i % 2) * 3)
		_prop(figures, "res://scripts/props_massacre/crowd_figure.gd", "Beggar%d" % (i + 1), at, {"kind": [0, 2, 1, 0][i], "variant": i}, 160.0 + i * 20)
	_prop(figures, "res://scripts/props_massacre/crowd_figure.gd", "NoblesMan", Vector3(3, 0.0, -358), {"kind": 0, "variant": 5}, 180.0)


func _story() -> void:
	var shots := _group(_root, "Shots")
	_shot(shots, "PlatformShot", Vector3(-9, 4, 306), Vector3(0, 2.5, 322), 55.0)
	_shot(shots, "KaelPlatformShot", Vector3(-3, 2.2, 312), Vector3(2.5, 1.5, 318), 45.0)
	_shot(shots, "PipeShot", Vector3(12, GROUND_Y + 3, 240), Vector3(42, GROUND_Y + 8, 120), 60.0)
	_shot(shots, "PumpShot", Vector3(20, GROUND_Y + 6, 200), Vector3(44, GROUND_Y + 5, 185), 55.0)
	_shot(shots, "SwordShot", Vector3(24, GROUND_Y + 2.2, 186), Vector3(32, GROUND_Y + 1.2, 180), 50.0)
	_shot(shots, "MirageShot", Vector3(10, GROUND_Y + 9, 20), Vector3(50, GROUND_Y + 3, -10), 55.0)
	_shot(shots, "ShackShot", Vector3(-10, _ground(-10, -118) + 3, -118), Vector3(-30, _ground(-30, -140) + 2, -140), 55.0)
	_shot(shots, "FarmerShot", Vector3(-22, _ground(-22, -142) + 1.8, -142), Vector3(-18, _ground(-18, -146) + 1.4, -146), 45.0)
	_shot(shots, "ObeliskShot", Vector3(-20, _ground(-20, -230) + 4, -230), Vector3(14, _ground(14, -258) + 22, -258), 60.0)
	_shot(shots, "ObeliskFootShot", Vector3(-6, _ground(-6, -262) + 2, -262), Vector3(14, _ground(14, -258) + 3, -258), 55.0)
	_shot(shots, "LakeShot", Vector3(-8, _ground(-8, -268) + 4, -268), Vector3(10, 10, -480), 60.0)
	_shot(shots, "CausewayShot", Vector3(-9, 3, -340), Vector3(0, 1.4, -356), 50.0)
	var marks := _group(_root, "StoryMarks")
	_marker(marks, "PlatformTop", Vector3(0, GROUND_Y + 0.1, 282), 180.0)
	var triggers := _group(_root, "StoryTriggers")
	var dlg := "res://data/dialogue/horus.txt"
	var S := "res://scripts/story_trigger.gd"
	_area(triggers, "Arrival", Vector3(0, 0, 312), Vector3(20, 4, 8), S, {"dialogue_file": dlg, "scene": "arrival"})
	_area(triggers, "ThePipe", Vector3(14, GROUND_Y - 1, 206), Vector3(40, 8, 10), S, {"dialogue_file": dlg, "scene": "the_pipe"})
	_area(triggers, "DayTwo", Vector3(4, GROUND_Y, 100), Vector3(80, 12, 10), S, {"dialogue_file": dlg, "scene": "day_two"})
	_area(triggers, "Mirage", Vector3(10, GROUND_Y + 2, 30), Vector3(80, 12, 10), S, {"dialogue_file": dlg, "scene": "mirage"})
	_area(triggers, "DayThree", Vector3(-10, GROUND_Y + 3, -50), Vector3(80, 12, 10), S, {"dialogue_file": dlg, "scene": "day_three"})
	_area(triggers, "TheFarmer", Vector3(-24, _ground(-24, -128), -128), Vector3(30, 8, 10), S, {"dialogue_file": dlg, "scene": "the_farmer"})
	_area(triggers, "TheObelisk", Vector3(-4, _ground(-4, -236), -236), Vector3(50, 14, 10), S, {"dialogue_file": dlg, "scene": "the_obelisk"})
	_area(triggers, "TheGate", Vector3(0, -1, -340), Vector3(26, 6, 8), S, {"dialogue_file": dlg, "scene": "the_gate"})
	var checkpoints := _group(_root, "Checkpoints")
	var C := "res://scripts/checkpoint.gd"
	_area(checkpoints, "PlatformTop", Vector3(0, GROUND_Y - 1, 280), Vector3(16, 6, 4), C)
	_area(checkpoints, "PastThePipe", Vector3(8, GROUND_Y, 150), Vector3(60, 10, 4), C)
	_area(checkpoints, "TheShack", Vector3(-24, _ground(-24, -132), -132), Vector3(40, 10, 4), C)
	_area(checkpoints, "TheRidge", Vector3(0, _ground(0, -270), -270), Vector3(50, 12, 4), C)
	var inspect := _group(_root, "Inspect")
	var bed := Area3D.new()
	bed.set_script(load("res://scripts/rest_bed.gd"))
	bed.set("dialogue_file", dlg)
	bed.set("label", "Rest")
	bed.set("reach", 2.5)
	_add(inspect, bed, "RestBed", Vector3(-30, _ground(-30, -140) + 0.4, -140))
	var bshape := CollisionShape3D.new()
	var bbox := BoxShape3D.new()
	bbox.size = Vector3(3, 2, 3)
	bshape.shape = bbox
	_add(bed, bshape, "Zone", Vector3(0, 1, 0))
	var quake := Node.new()
	quake.set_script(load("res://scripts/vfx/quake.gd"))
	_add(_root, quake, "Quake")


func _life() -> void:
	var life := _group(_root, "Life")
	# The amber smog deck, far up (CloudLayer with a brown material).
	var smog_mat := "res://materials/clouds_horus.tres"
	if ResourceLoader.exists(smog_mat):
		var clouds := CloudLayer.new()
		clouds.size = Vector2(900, 1100)
		clouds.sheets = 3
		clouds.spacing = 8.0
		clouds.material = load(smog_mat)
		_add(life, clouds, "Smog", Vector3(0, 75, -120))
	_prop(life, "res://scripts/props_kit/drift_lights.gd", "DriftLights", Vector3(20, 40, -60), {"count": 4})
	var sound := _group(_root, "Sound")
	var wind := AudioStreamPlayer3D.new()
	wind.stream = load("res://audio/black_sand_wind.wav")
	wind.autoplay = true
	wind.volume_db = -14.0
	wind.max_distance = 400.0
	wind.unit_size = 60.0
	_add(sound, wind, "Wind", Vector3(0, GROUND_Y + 10, 40))
