extends "res://tools/generators/build_horus.gd"
## Builds Temek's rough-cut level, scenes/levels/temek.tscn (docs/act1_temek.md): a ring of stone
## streets standing in the lake, the black pyramid hanging point-down from the roof over the inner
## water, and a bridge across that water with a platform under the pyramid where people touch it.
## South to north: the causeway gate, the market street (the nobleman's house, the beggars), the
## plaza, the bridge and the platform, the palace forecourt (the Pharaoh, the smith). Run it once
## (Godot closed):  godot --headless --path PROJ -s res://tools/generators/build_temek.gd
## After that the scene file is the source of truth. Reuses build_horus.gd's helpers.

const TEMEK_OUT := "res://scenes/levels/temek.tscn"
const STONE := "res://materials/horus_stone.tres"
const STONE_DARK := "res://materials/horus_stone_dark.tres"
const PLASTER := "res://materials/tex_horus_plaster.tres"
const CLOTH := "res://materials/horus_cloth.tres"
const IRON := "res://materials/horus_iron.tres"
const WATER_Y := -1.2
const PYRAMID_AT := Vector3(0, 0, -40)  # the inner lake's middle, under the pyramid
const TOUCH_Y := 2.6                     # the pyramid's underside over the platform


func _initialize() -> void:
	_root = Node3D.new()
	_root.name = "Temek"
	root.add_child(_root)
	_temek_environment()
	_ring()
	_bridge()
	_hanging_pyramid()
	_market()
	_palace()
	_outskirts()
	_temek_people()
	_temek_story()
	_temek_life()
	for n in _notes:
		print("NOTE: ", n)
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err == OK:
		err = ResourceSaver.save(packed, TEMEK_OUT)
	print("BUILD TEMEK ", "ok" if err == OK else "failed %d" % err, " -> ", TEMEK_OUT)
	quit()


## A low stone lip along an edge (1.1 m, solid), so he can't walk into the water by accident.
func _lip(parent: Node, name: String, at: Vector3, length: float, along_x: bool) -> void:
	var size := Vector3(length, 1.1, 0.4) if along_x else Vector3(0.4, 1.1, length)
	_block(parent, name, at + Vector3(0, 0.55, 0), size, STONE_DARK)


## A house: a plaster box standing on the street, a darker band of stone at its foot, a flat roof.
func _house(parent: Node, name: String, at: Vector3, size: Vector3, yaw := 0.0) -> Node3D:
	var h := _block(parent, name, at + Vector3(0, size.y * 0.5, 0), size, PLASTER, yaw, {"grime": 0.6}) as Node3D
	_block(parent, name + "Foot", at + Vector3(0, 0.45, 0), Vector3(size.x + 0.3, 0.9, size.z + 0.3), STONE_DARK, yaw)
	return h


## A cloth awning over a shopfront: a sloped sheet on two iron poles, facing +Z of the yaw.
func _awning(parent: Node, name: String, at: Vector3, width: float, yaw := 0.0) -> void:
	var g := _add(parent, Node3D.new(), name, at, yaw) as Node3D
	var sheet := _block(g, "Sheet", Vector3(0, 2.9, 1.2), Vector3(width, 0.06, 2.6), CLOTH, 0.0, {"collision_layer": 0}) as Node3D
	sheet.rotation.x = deg_to_rad(14)
	for s in [-1.0, 1.0]:
		_block(g, "Pole%s" % ("L" if s < 0 else "R"), Vector3(s * (width * 0.5 - 0.1), 1.3, 2.4), Vector3(0.1, 2.6, 0.1), IRON, 0.0, {"collision_layer": 0})


# ---------------------------------------------------------------- the level
func _temek_environment() -> void:
	# A bright desert city under the megastructure's roof: warm daylight, a pale amber haze that
	# hides the roof and the far shores (the pyramid's top goes up into it).
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.78, 0.6, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.7, 0.52)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.76, 0.58, 0.36)
	env.fog_density = 1.0
	env.fog_depth_begin = 25.0
	env.fog_depth_end = 300.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.0
	we.environment = env
	_add(_root, we, "WorldEnvironment")
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 0.9
	sun.shadow_enabled = false
	_add(_root, sun, "Sun")
	sun.rotation_degrees = Vector3(-58, 28, 0)


func _ring() -> void:
	# The city stands in the lake: one water sheet under everything, and a square ring of stone
	# terraces (streets at y 0) round the inner water, x -60..60, z 20..-100.
	var g := _group(_root, "Ring")
	_prop(g, "res://scripts/props_horus/lake.gd", "Lake", Vector3(0, WATER_Y, -40), {"size": Vector2(700, 700), "shore": 2.0})
	_block(g, "South", Vector3(0, -2, 45), Vector3(220, 4, 50), STONE)
	_block(g, "North", Vector3(0, -2, -135), Vector3(220, 4, 70), STONE)
	_block(g, "West", Vector3(-85, -2, -40), Vector3(50, 4, 120), STONE)
	_block(g, "East", Vector3(85, -2, -40), Vector3(50, 4, 120), STONE)
	# Lips round the inner water (the bridge's two ends left open) and round the outer edge
	# (the causeway's mouth left open).
	_lip(g, "LipInnerS_W", Vector3(-32, 0, 20.2), 56, true)
	_lip(g, "LipInnerS_E", Vector3(32, 0, 20.2), 56, true)
	_lip(g, "LipInnerN_W", Vector3(-32, 0, -100.2), 56, true)
	_lip(g, "LipInnerN_E", Vector3(32, 0, -100.2), 56, true)
	_lip(g, "LipInnerW", Vector3(-60.2, 0, -40), 120, false)
	_lip(g, "LipInnerE", Vector3(60.2, 0, -40), 120, false)
	_lip(g, "LipOuterS_W", Vector3(-57, 0, 69.8), 106, true)
	_lip(g, "LipOuterS_E", Vector3(57, 0, 69.8), 106, true)
	_lip(g, "LipOuterN", Vector3(0, 0, -169.8), 220, true)
	_lip(g, "LipOuterW", Vector3(-109.8, 0, -50), 240, false)
	_lip(g, "LipOuterE", Vector3(109.8, 0, -50), 240, false)
	# The causeway in from the desert, its gate halfway (the deck is the gate prop's own).
	_prop(g, "res://scripts/props_horus/causeway_gate.gd", "Gate", Vector3(0, 0, 115), {"length": 90.0, "width": 10.0})
	var stop := StaticBody3D.new()
	_add(g, stop, "CausewayStop", Vector3(0, 2, 160.5))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(14, 6, 1)
	shape.shape = box
	_add(stop, shape, "Shape")
	for side in [-1.0, 1.0]:  # either side of the deck, stopping short of the gatehouse
		var s := "W" if side < 0 else "E"
		_lip(g, "CausewayLipS" + s, Vector3(side * 5.2, 0, 88.5), 37, false)
		_lip(g, "CausewayLipN" + s, Vector3(side * 5.2, 0, 141.5), 37, false)


func _bridge() -> void:
	# South shore -> the platform under the pyramid -> the north shore. Deck top at y 0.
	var g := _group(_root, "Bridge")
	var c := PYRAMID_AT
	_block(g, "DeckSouth", Vector3(0, -0.4, (20 + c.z + 14) * 0.5), Vector3(6, 0.8, 20 - (c.z + 14)), STONE)
	_block(g, "DeckNorth", Vector3(0, -0.4, (c.z - 14 - 100) * 0.5), Vector3(6, 0.8, (c.z - 14) + 100), STONE)
	_block(g, "Platform", Vector3(c.x, -0.5, c.z), Vector3(28, 1, 28), STONE_DARK)
	for side in [-1.0, 1.0]:
		var s := "W" if side < 0 else "E"
		_lip(g, "LipSouth" + s, Vector3(side * 3.2, 0, (20 + c.z + 14) * 0.5), 20 - (c.z + 14), false)
		_lip(g, "LipNorth" + s, Vector3(side * 3.2, 0, (c.z - 14 - 100) * 0.5), (c.z - 14) + 100, false)
		_lip(g, "LipPlatform" + s, Vector3(side * 13.8, 0, c.z), 28, false)
		_lip(g, "LipPlatformS" + s, Vector3(side * 8.5, 0, c.z + 13.8), 10.6, true)
		_lip(g, "LipPlatformN" + s, Vector3(side * 8.5, 0, c.z - 13.8), 10.6, true)
	# Piers down into the water.
	var z := 14.0
	while z > -96.0:
		if absf(z - c.z) > 16.0:
			_block(g, "Pier%d" % int(z), Vector3(0, -2.6, z), Vector3(7, 3.6, 2.4), STONE_DARK)
		z -= 12.0
	# Braziers at the platform's corners: the only fire on the water.
	for i in 4:
		var at := c + Vector3([-11, 11, -11, 11][i], 0, [-11, -11, 11, 11][i])
		_block(g, "Brazier%d" % i, at + Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.0), IRON)
		_block(g, "Coals%d" % i, at + Vector3(0, 1.05, 0), Vector3(0.8, 0.1, 0.8), "res://materials/horus_flame.tres", 0.0, {"collision_layer": 0})
		_light(g, "BrazierLight%d" % i, at + Vector3(0, 1.8, 0), Color(1.0, 0.6, 0.28), 1.4, 9.0)


func _hanging_pyramid() -> void:
	# The black pyramid, point down from the roof over the inner water. Inverted pyramid.gd: its
	# shrine end (the "tip") hangs TOUCH_Y over the platform. It lowers with every sacrifice.
	var g := _group(_root, "Pyramid")
	var base := 110.0
	var tier_top := base * 0.62
	var depth := tier_top + 5.0 * 0.9 + 0.4  # tiers + shrine + its lintel (pyramid.gd)
	var p := _prop(g, "res://scripts/props_horus/pyramid.gd", "BlackPyramid", PYRAMID_AT + Vector3(0, TOUCH_Y + depth, 0), {"base": base, "steps": 9, "lit": true})
	if p:
		(p as Node3D).rotation.x = PI
	_light(g, "UnderGlow", PYRAMID_AT + Vector3(0, TOUCH_Y - 0.6, 0), Color(0.6, 0.75, 1.0), 0.8, 10.0)
	_marker(g, "TouchMark", PYRAMID_AT + Vector3(0, 0.05, 2.0), 0.0)


func _market() -> void:
	# The south ring: the main street from the causeway to the plaza (x -8..8), houses both sides,
	# the nobleman's courtyard house on the west, and the plaza at the bridge's foot.
	var g := _group(_root, "Market")
	var rows := [  # x, z, size
		[-16, 62, Vector3(14, 8, 12)], [-14, 47, Vector3(10, 11, 10)], [-46, 60, Vector3(16, 7, 14)],
		[16, 61, Vector3(14, 9, 14)], [17, 45, Vector3(12, 7, 10)], [40, 58, Vector3(18, 12, 16)],
		[-80, 52, Vector3(30, 10, 22)], [72, 50, Vector3(20, 14, 18)], [96, 54, Vector3(16, 9, 20)],
	]
	for i in rows.size():
		var r: Array = rows[i]
		var at := Vector3(r[0], 0, r[1])
		var size: Vector3 = r[2]
		_house(g, "House%d" % i, at, size)
		if absf(at.x) < 30:
			var face := at.x - signf(at.x) * size.x * 0.5
			_awning(g, "Awning%d" % i, Vector3(face, 0, at.z), size.z * 0.6, -90.0 * signf(at.x))
		_prop(g, "res://scripts/props_kit/rooftop_kit.gd", "Roof%d" % i, at + Vector3(0, size.y, 0), {"size": Vector2(size.x - 1, size.z - 1), "random_seed": 40 + i, "density": 0.5})
	# The nobleman's house: walls round a courtyard (x -44..-24, z 32..48), its door on the street
	# side; a dry pool in the middle (the water has gone from here too).
	var n := _group(g, "NobleHouse")
	_house(n, "WallN", Vector3(-34, 0, 48.5), Vector3(21, 6, 1))
	_house(n, "WallS", Vector3(-34, 0, 31.5), Vector3(21, 6, 1))
	_house(n, "WallW", Vector3(-44, 0, 40), Vector3(1, 6, 16))
	_house(n, "WallE_N", Vector3(-24, 0, 44.5), Vector3(1, 6, 7))
	_house(n, "WallE_S", Vector3(-24, 0, 35.5), Vector3(1, 6, 7))
	_block(n, "Lintel", Vector3(-24, 5.0, 40), Vector3(1.4, 1.0, 2.0), STONE_DARK)
	_block(n, "Hall", Vector3(-39, 3.5, 40), Vector3(8, 7, 14), PLASTER)  # the roofed rooms at the back
	_block(n, "Porch", Vector3(-34.2, 3.8, 40), Vector3(1.6, 0.4, 12), STONE_DARK, 0.0, {"collision_layer": 0})
	_block(n, "PoolRim", Vector3(-30, 0.15, 40), Vector3(6, 0.3, 4), STONE_DARK)
	_block(n, "PoolDry", Vector3(-30, 0.31, 40), Vector3(5.2, 0.02, 3.2), "res://materials/horus_mud.tres", 0.0, {"collision_layer": 0})
	_light(n, "CourtLamp", Vector3(-33, 4.0, 40), Color(1.0, 0.72, 0.42), 1.3, 12.0)
	# The plaza at the bridge's foot: two communal screens on iron frames, facing the street.
	var p := _group(g, "Plaza")
	for side in [-1.0, 1.0]:
		var s := "W" if side < 0 else "E"
		var at := Vector3(side * 14, 0, 26)
		_block(p, "ScreenFrame" + s, at + Vector3(0, 4.5, 0), Vector3(7.4, 4.4, 0.4), IRON)
		_prop(p, "res://scripts/tv_window.gd", "Screen" + s, at + Vector3(0, 4.5, 0.23),
				{"size": Vector3(6.6, 3.6, 0.05), "material": load("res://materials/window_glow.tres"), "collision_layer": 0, "random_seed": 7 + int(side)})
		for leg in [-1.0, 1.0]:
			_block(p, "ScreenLeg%s%d" % [s, int(leg)], at + Vector3(leg * 3.2, 1.25, 0), Vector3(0.3, 2.5, 0.3), IRON)


func _palace() -> void:
	# The north ring: the forecourt where the bridge lands, the Pharaoh's pyramid behind it with a
	# columned porch on its face, and the smith's forge on the east of the court.
	var g := _group(_root, "Palace")
	_prop(g, "res://scripts/props_horus/pyramid.gd", "PalacePyramid", Vector3(0, 0, -142), {"base": 46.0, "steps": 6, "lit": false})
	var porch := Vector3(0, 0, -116)
	for i in 6:
		var x := -10.0 + i * 4.0
		_block(g, "Column%d" % i, porch + Vector3(x, 3.5, 0), Vector3(1.2, 7, 1.2), STONE)
	_block(g, "PorchRoof", porch + Vector3(0, 7.5, -1.0), Vector3(24, 1.0, 4), STONE_DARK)
	_block(g, "Doorway", porch + Vector3(0, 2.5, -2.95), Vector3(4, 5, 0.1), "res://materials/black_cube.tres", 0.0, {"collision_layer": 0})
	_light(g, "PorchLamp", porch + Vector3(0, 6, 1), Color(1.0, 0.7, 0.4), 1.6, 16.0)
	# The forge: an open shed, the hearth glowing, the anvil.
	var f := _group(g, "Forge")
	var at := Vector3(32, 0, -112)
	_block(f, "Back", at + Vector3(0, 2.5, -3.5), Vector3(9, 5, 0.6), STONE_DARK)
	_block(f, "SideW", at + Vector3(-4.2, 2.5, 0), Vector3(0.6, 5, 7), STONE_DARK)
	_block(f, "SideE", at + Vector3(4.2, 2.5, 0), Vector3(0.6, 5, 7), STONE_DARK)
	_block(f, "Roof", at + Vector3(0, 5.2, -0.3), Vector3(9.4, 0.4, 7.6), IRON)
	_block(f, "Hearth", at + Vector3(-2, 0.6, -2.4), Vector3(2.6, 1.2, 1.6), STONE)
	_block(f, "Embers", at + Vector3(-2, 1.22, -2.4), Vector3(2.0, 0.06, 1.0), "res://materials/horus_flame.tres", 0.0, {"collision_layer": 0})
	_block(f, "Anvil", at + Vector3(1.2, 0.45, -0.6), Vector3(0.8, 0.9, 0.5), IRON)
	_block(f, "Chimney", at + Vector3(-2, 7, -3.2), Vector3(1.2, 5, 1.2), STONE_DARK)
	_light(f, "ForgeGlow", at + Vector3(-2, 2.0, -1.6), Color(1.0, 0.45, 0.15), 2.4, 10.0)
	# Houses on the north ring either side of the palace, and on the west and east rings.
	var rows := [[-48, -130, Vector3(20, 12, 24)], [48, -134, Vector3(22, 10, 26)], [-86, -140, Vector3(24, 9, 30)],
			[86, -128, Vector3(24, 13, 22)], [-88, -70, Vector3(26, 11, 30)], [-86, -12, Vector3(22, 8, 26)],
			[88, -80, Vector3(24, 10, 34)], [86, -16, Vector3(26, 12, 24)]]
	for i in rows.size():
		var r: Array = rows[i]
		var hat := Vector3(r[0], 0, r[1])
		var size: Vector3 = r[2]
		_house(g, "House%d" % i, hat, size)
		_prop(g, "res://scripts/props_kit/rooftop_kit.gd", "Roof%d" % i, hat + Vector3(0, size.y, 0), {"size": Vector2(size.x - 1, size.z - 1), "random_seed": 60 + i, "density": 0.5})


func _outskirts() -> void:
	# Derricks burning against pyramids: the city's foundations stand in the outer lake.
	var g := _group(_root, "Outskirts")
	var pyr := [[Vector3(-190, -2, -110), 70.0], [Vector3(200, -2, -20), 60.0], [Vector3(-170, -2, 120), 50.0], [Vector3(150, -2, -220), 80.0]]
	for i in pyr.size():
		_prop(g, "res://scripts/props_horus/pyramid.gd", "Pyramid%d" % (i + 1), pyr[i][0], {"base": pyr[i][1], "steps": 7, "lit": i % 2 == 0})
	var derricks := [Vector3(-100, 0, 30), Vector3(100, 0, 28), Vector3(-100, 0, -104), Vector3(100, 0, -162), Vector3(-140, -1, 30), Vector3(150, -1, 90), Vector3(-60, -1, -210)]
	for i in derricks.size():
		_prop(g, "res://scripts/props_horus/derrick.gd", "Derrick%d" % (i + 1), derricks[i], {"lit": true, "lean": 0.0, "height": 18.0 + (i % 3) * 4.0}, 35.0 * i)


func _temek_people() -> void:
	var player: Node3D = load("res://scenes/player.tscn").instantiate()
	_add(_root, player, "Player", Vector3(0, 0.6, 152))
	var kael: Node3D = load("res://scenes/kael.tscn").instantiate()
	_add(_root, kael, "Kael", Vector3(2.5, 0.6, 154))
	kael.set("leader", player)
	var director: Node = load("res://scenes/stealth_director.tscn").instantiate()
	_add(_root, director, "StealthDirector")
	director.set("player", player)
	var F := "res://scripts/props_massacre/crowd_figure.gd"
	var g := _group(_root, "Figures")
	for i in 6:  # beggars along the market street and at the gate
		var at := Vector3([-6.0, 6.0, -5.5, 6.5, -6.5, 5.0][i], 0, [76.0, 74.0, 56.0, 50.0, 38.0, 34.0][i])
		_prop(g, F, "Beggar%d" % (i + 1), at, {"kind": [2, 0, 1, 2, 0, 1][i], "variant": i}, [90.0, -90.0, 90.0, -90.0, 80.0, -100.0][i])
	for i in 8:  # townsfolk in the plaza and on the bridge
		var at := Vector3([-10.0, 9.0, -4.0, 4.0, -2.3, 2.0, -9.0, 8.0][i], 0, [28.0, 30.0, 22.0, 24.0, 2.0, -30.0, -36.0, -46.0][i])
		_prop(g, F, "Townsman%d" % (i + 1), at, {"kind": 0, "variant": 8 + i}, 180.0 + i * 37.0)
	_prop(g, F, "Nobleman", Vector3(-31, 0, 43), {"kind": 2, "variant": 5}, 90.0)
	_prop(g, F, "Pharaoh", Vector3(0, 0, -118), {"kind": 2, "variant": 7}, 0.0)
	_prop(g, F, "Kira", Vector3(-4, 0, -118), {"kind": 0, "variant": 6}, 20.0)
	for i in 4:  # the elite guard at the porch
		_prop(g, F, "Guard%d" % (i + 1), Vector3(-9 + i * 6, 0, -113), {"kind": 3, "variant": i}, 0.0)
	_prop(g, F, "Smith", Vector3(33, 0, -110), {"kind": 2, "variant": 2}, 200.0)


func _temek_story() -> void:
	var shots := _group(_root, "Shots")
	_shot(shots, "CausewayShot", Vector3(-6, 3, 150), Vector3(0, 30, -40), 62.0)
	_shot(shots, "MarketShot", Vector3(5, 2.5, 80), Vector3(-6, 1.4, 70), 50.0)
	_shot(shots, "CourtShot", Vector3(-26, 2.2, 36), Vector3(-31, 1.6, 43), 50.0)
	_shot(shots, "PoolShot", Vector3(-27, 3.4, 38), Vector3(-30, 0.3, 40), 50.0)
	_shot(shots, "BridgeShot", Vector3(-4, 1.6, 14), Vector3(0, 12, -40), 60.0)
	_shot(shots, "UnderShot", Vector3(-6, 1.0, -33), Vector3(0, 4, -40), 60.0)
	_shot(shots, "UpShot", Vector3(0, 1.2, -36), Vector3(0, 60, -42), 70.0)
	_shot(shots, "PorchShot", Vector3(5, 2.2, -106), Vector3(-1, 1.6, -117), 50.0)
	_shot(shots, "KiraShot", Vector3(-1, 1.8, -113), Vector3(-3, 1.5, -117), 40.0)
	_shot(shots, "ForgeShot", Vector3(29, 2.0, -105), Vector3(31, 1.0, -113), 50.0)
	var triggers := _group(_root, "StoryTriggers")
	var dlg := "res://data/dialogue/temek.txt"
	var S := "res://scripts/story_trigger.gd"
	_area(triggers, "Arrival", Vector3(0, 0, 144), Vector3(10, 4, 6), S, {"dialogue_file": dlg, "scene": "arrival"})
	_area(triggers, "TheMarket", Vector3(0, 0, 72), Vector3(16, 4, 4), S, {"dialogue_file": dlg, "scene": "the_market"})
	_area(triggers, "TheNobleman", Vector3(-28, 0, 40), Vector3(6, 4, 14), S, {"dialogue_file": dlg, "scene": "the_nobleman"})
	_area(triggers, "ThePyramid", PYRAMID_AT + Vector3(0, 0, 4), Vector3(12, 4, 6), S, {"dialogue_file": dlg, "scene": "the_pyramid"})
	_area(triggers, "ThePharaoh", Vector3(0, 0, -108), Vector3(20, 4, 4), S, {"dialogue_file": dlg, "scene": "the_pharaoh"})
	_area(triggers, "TheSmith", Vector3(32, 0, -106), Vector3(9, 4, 4), S, {"dialogue_file": dlg, "scene": "the_smith"})
	var checkpoints := _group(_root, "Checkpoints")
	var C := "res://scripts/checkpoint.gd"
	_area(checkpoints, "Gate", Vector3(0, 0, 100), Vector3(10, 4, 4), C)
	_area(checkpoints, "Plaza", Vector3(0, 0, 24), Vector3(24, 4, 4), C)
	_area(checkpoints, "Platform", PYRAMID_AT + Vector3(0, 0, 10), Vector3(10, 4, 4), C)
	_area(checkpoints, "Forecourt", Vector3(0, 0, -104), Vector3(20, 4, 4), C)
	var quake := Node.new()
	quake.set_script(load("res://scripts/vfx/quake.gd"))
	_add(_root, quake, "Quake")


func _temek_life() -> void:
	var life := _group(_root, "Life")
	var smog := "res://materials/clouds_horus.tres"
	if ResourceLoader.exists(smog):
		var clouds := CloudLayer.new()
		clouds.size = Vector2(700, 700)
		clouds.sheets = 3
		clouds.spacing = 7.0
		clouds.material = load(smog)
		_add(life, clouds, "Smog", Vector3(0, 58, -40))
	_prop(life, "res://scripts/props_kit/drift_lights.gd", "PyramidLights", PYRAMID_AT + Vector3(0, 16, 0), {"count": 5, "box_size": Vector3(30, 14, 30)})
	var sound := _group(_root, "Sound")
	var wind := AudioStreamPlayer3D.new()
	wind.stream = load("res://audio/black_sand_wind.wav")
	wind.autoplay = true
	wind.volume_db = -18.0
	wind.max_distance = 400.0
	wind.unit_size = 60.0
	_add(sound, wind, "Wind", Vector3(0, 20, 0))
