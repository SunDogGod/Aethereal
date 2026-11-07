extends "res://tools/generators/build_horus.gd"
## The Massacre's buildings, for build_massacre.gd (which adds the people and the story): the
## megastructure hall the village stands in, the one corridor in, the village packed close round
## a big walled courtyard (the clan's), the Great House on its north side, and Aeneas's family's
## own house in its east corner, with a ramp down to the cellar where the escape capsule waits
## on its line (the same capsule found wrecked at the Vacuum Station, years later).
## Layout (metres, north = -Z): hall x -46..46, z -44..56; courtyard x -28..28, z -24..18, its
## gate in the south wall at x 0; family house x 19..27, z -9..6, its door on the west wall at
## z 4.6; cellar x 13..33, z -16..-5, its floor at y -4.5.

const GRASS := "res://materials/grass.tres"
const CONCRETE := "res://materials/concrete_dark.tres"
const CONCRETE_WORN := "res://materials/concrete_dark_worn.tres"
const FLOOR_WORN := "res://materials/concrete_worn.tres"
const METAL := "res://materials/metal.tres"
const METAL_WORN := "res://materials/metal_worn.tres"
const PLASTER := "res://materials/massacre_plaster.tres"
const STONE := "res://materials/massacre_stone.tres"
const SOIL := "res://materials/massacre_soil.tres"
const TIMBER := "res://materials/massacre_timber.tres"
const PLANK := "res://materials/massacre_timber_light.tres"
const IRON := "res://materials/massacre_iron.tres"
const LANTERN := "res://materials/massacre_lantern.tres"
const LAMP_ON := "res://materials/massacre_grow_lamp.tres"
const LAMP_OFF := "res://materials/ceiling_panel_off.tres"
const P := "res://scripts/props_massacre/"
const WARM := Color(1, 0.6, 0.27)
const CEILING_Y := 24.0
const CELLAR_Y := -4.5
const DOOR_Z := 4.6     # the family house's door (west wall, x 19)
const RAMP := Rect2(23, -5, 3, 9)  # the hole in the house floor the ramp goes down (x, z, w, d)

var _lit_panels: Array[Vector3] = []


func _hall() -> void:
	var g := _group(_root, "Hall")
	# The floor: grass, 1 m thick, with the ramp's hole cut out of it (it is the cellar's ceiling).
	var r := RAMP
	_block(g, "FloorSouth", Vector3(0, -0.5, (r.end.y + 56) * 0.5), Vector3(92, 1, 56 - r.end.y), GRASS)
	_block(g, "FloorNorth", Vector3(0, -0.5, (r.position.y - 44) * 0.5), Vector3(92, 1, r.position.y + 44), GRASS)
	_block(g, "FloorWest", Vector3((r.position.x - 46) * 0.5, -0.5, r.get_center().y), Vector3(r.position.x + 46, 1, r.size.y), GRASS)
	_block(g, "FloorEast", Vector3((r.end.x + 46) * 0.5, -0.5, r.get_center().y), Vector3(46 - r.end.x, 1, r.size.y), GRASS)
	_block(g, "Ceiling", Vector3(0, CEILING_Y + 1, 6), Vector3(96, 2, 104), CONCRETE)
	_block(g, "WallWest", Vector3(-47, 12, 6), Vector3(2, 24, 104), CONCRETE)
	_block(g, "WallEast", Vector3(47, 12, 6), Vector3(2, 24, 104), CONCRETE)
	_block(g, "WallNorth", Vector3(0, 12, -45), Vector3(92, 24, 2), CONCRETE)
	_block(g, "WallSouthWest", Vector3(-25, 12, 57), Vector3(44, 24, 2), CONCRETE)
	_block(g, "WallSouthEast", Vector3(25, 12, 57), Vector3(44, 24, 2), CONCRETE)
	_block(g, "WallSouthTop", Vector3(0, 15, 57), Vector3(6, 18, 2), CONCRETE)
	for x in [-24.0, 0.0, 24.0]:
		_block(g, "CeilingPipe%d" % int(x), Vector3(x, CEILING_Y - 0.7, 6), Vector3(1.2, 1.2, 100), METAL)
	var m := _group(_root, "Megastructure")
	for i in 9:  # pilasters every 12 m: the hall reads as one bay of something enormous
		var z := -40.0 + i * 12.0
		for s in [-1.0, 1.0]:
			_block(m, "Pilaster%s%d" % ["W" if s < 0 else "E", i], Vector3(s * 45.4, 12, z), Vector3(1.2, 24, 2), CONCRETE_WORN, 0.0, {"grime": 0.5})
	for i in 7:
		var x := -36.0 + i * 12.0
		_block(m, "PilasterN%d" % i, Vector3(x, 12, -43.4), Vector3(2, 24, 1.2), CONCRETE_WORN, 0.0, {"grime": 0.5})
	# The one corridor in, from the south.
	var c := _group(_root, "Corridor")
	_block(c, "Floor", Vector3(0, -0.5, 72), Vector3(6, 1, 28), FLOOR_WORN)
	_block(c, "WallWest", Vector3(-3.5, 3, 72), Vector3(1, 6, 28), CONCRETE_WORN)
	_block(c, "WallEast", Vector3(3.5, 3, 72), Vector3(1, 6, 28), CONCRETE_WORN)
	_block(c, "Roof", Vector3(0, 6.5, 72), Vector3(8, 1, 28), CONCRETE)
	_block(c, "FarDoor", Vector3(0, 3, 86.25), Vector3(6, 6, 0.5), METAL_WORN)
	_light(c, "GateLight", Vector3(0, 4, 62), Color(1, 0.75, 0.45), 1.2, 12.0)


## The grow lamps: a panel every 12 m, one in three lit, each on its steel rig.
func _grow_lamps() -> void:
	var g := _group(_root, "GrowLamps")
	var panels := PackedVector3Array()
	var i := 0
	for ix in 7:
		for iz in 8:
			var at := Vector3(-36 + ix * 12, CEILING_Y - 2.25, -36 + iz * 12)
			var lit := i % 3 == 0
			_block(g, "Lamp%d" % i, at, Vector3(6, 0.5, 6), LAMP_ON if lit else LAMP_OFF)
			if lit:
				var l := _light(g, "LampLight%d" % i, at - Vector3(0, 1.35, 0), Color(0.7, 0.78, 1), 0.4, 28.0)
				l.light_specular = 0.0
				_lit_panels.append(at)
			panels.append(at)
			i += 1
	_prop(g, P + "grow_rigs.gd", "Rigs", Vector3.ZERO, {"panels": panels, "ceiling_y": CEILING_Y})


## A village house: the plaster Block and its dressing (village_house.gd), front facing +Z of yaw.
func _vhouse(parent: Node, name: String, at: Vector3, size: Vector3, yaw := 0.0, great := false) -> void:
	_block(parent, name, at + Vector3(0, size.y * 0.5, 0), size, PLASTER, yaw, {"grime": 0.5})
	_prop(parent, P + "village_house.gd", name + "Dressing", at, {"house_size": size, "great": great}, yaw)


## A string of paper lanterns between two points, with two breathing lights along it.
func _lantern_string(parent: Node, name: String, a: Vector3, b: Vector3, count: int) -> void:
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var yaw := rad_to_deg(atan2(-(b - a).z, (b - a).x))
	_block(parent, name, mid, Vector3(length, 0.04, 0.04), METAL, yaw, {"collision_layer": 0})
	for k in count:
		var t := (k + 0.5) / count
		_block(parent, "%s_%d" % [name, k], a.lerp(b, t) - Vector3(0, 0.3, 0), Vector3(0.45, 0.5, 0.45), LANTERN, yaw, {"collision_layer": 0})
	for t in [0.25, 0.75]:
		var l := _light(parent, "%sLight%d" % [name, int(t * 4)], a.lerp(b, t) - Vector3(0, 0.4, 0), WARM, 1.5, 9.0)
		l.set_script(load(P + "lantern_glow.gd"))
		l.set("waver", 0.1)


## The village round the courtyard: rows of houses close together along narrow lanes, the
## street from the corridor up to the courtyard gate, back gardens to the north. All of it is
## seen over the courtyard walls; only the courtyard is walked.
func _village() -> void:
	var v := _group(_root, "Village")
	var size := Vector3(8, 3.8, 6)
	_block(v, "Street", Vector3(0, 0.01, 37.25), Vector3(7, 0.02, 37.5), SOIL)
	var n := 0
	for z in [50.0, 40.0, 30.0]:  # the street up from the corridor, and two rows behind each side
		for row in [[-8.0, 90.0], [8.0, -90.0], [-18.0, -90.0], [18.0, 90.0], [-31.0, 90.0], [31.0, -90.0]]:
			_vhouse(v, "House%d" % n, Vector3(row[0], 0, z), size, row[1])
			n += 1
	for z in [-20.0, -10.0, 0.0, 10.0]:  # the rows outside the courtyard's west and east walls
		_vhouse(v, "House%d" % n, Vector3(-38, 0, z), size, 90.0)
		_vhouse(v, "House%d" % (n + 1), Vector3(38, 0, z), size, -90.0)
		n += 2
	for x in [-30.0, -14.0, 14.0, 30.0]:  # north, behind the Great House, facing the courtyard wall
		_vhouse(v, "House%d" % n, Vector3(x, 0, -33), Vector3(10, 3.8, 6), 0.0)
		n += 1
	var G := P + "village_garden.gd"
	_prop(v, G, "Paddy", Vector3(0, 0, -36), {"kind": 7, "length": 12, "width": 6})
	_prop(v, G, "BedN", Vector3(-22, 0, -40), {"kind": 0, "length": 6, "width": 2})
	_prop(v, G, "BambooN", Vector3(22, 0, -40), {"kind": 5, "length": 8, "width": 1.5})
	_prop(v, G, "PineS", Vector3(-12, 0, 21), {"kind": 4, "length": 6, "variant": 0})
	_prop(v, G, "MapleS", Vector3(12, 0, 21), {"kind": 4, "length": 5, "variant": 3})
	var areas: Array[Rect2] = [Rect2(-46, -44, 92, 100)]
	var holes: Array[Rect2] = [Rect2(-28.5, -24.5, 57, 43), Rect2(-3.5, 18, 7, 38)]
	_prop(v, P + "grass_tufts.gd", "Tufts", Vector3.ZERO, {"areas": areas, "holes": holes, "density": 0.5, "random_seed": 26})


## The clan's courtyard: plaster walls, the gate (shut until the Agency breaks it), the Great
## House on the north side, flagstones, and the festival.
func _courtyard() -> void:
	var c := _group(_root, "Courtyard")
	var h := 2.6
	_block(c, "WallWest", Vector3(-28, h * 0.5, -3), Vector3(0.5, h, 42.5), PLASTER, 0.0, {"grime": 0.6})
	_block(c, "WallEast", Vector3(28, h * 0.5, -3), Vector3(0.5, h, 42.5), PLASTER, 0.0, {"grime": 0.6})
	_block(c, "WallNorth", Vector3(0, h * 0.5, -24), Vector3(55.5, h, 0.5), PLASTER, 0.0, {"grime": 0.6})
	_block(c, "WallSouthW", Vector3(-15.375, h * 0.5, 18), Vector3(24.75, h, 0.5), PLASTER, 0.0, {"grime": 0.6})
	_block(c, "WallSouthE", Vector3(15.375, h * 0.5, 18), Vector3(24.75, h, 0.5), PLASTER, 0.0, {"grime": 0.6})
	# The gate: two posts, a lintel, its own little roof.
	for s in [-1.0, 1.0]:
		_block(c, "GatePost%s" % ("W" if s < 0 else "E"), Vector3(s * 2.75, 1.8, 18), Vector3(0.5, 3.6, 0.7), TIMBER)
	_block(c, "GateLintel", Vector3(0, 3.775, 18), Vector3(6.6, 0.35, 0.8), TIMBER)
	_prop(c, P + "village_roof.gd", "GateRoof", Vector3(0, 3.95, 18), {"length": 7.2, "depth": 1.6, "pitch": 32.0})
	var shut := _group(c, "GateShut")
	for s in [-1.0, 1.0]:
		_block(shut, "Leaf%s" % ("W" if s < 0 else "E"), Vector3(s * 1.26, 1.5, 18), Vector3(2.48, 3.0, 0.14), PLANK)
	var broken := _group(c, "GateBroken")
	broken.visible = false
	broken.set_script(load(P + "hidden_solids.gd"))
	var pieces := [[-1.6, 15.6, 18.0, 2.4], [1.1, 14.9, -30.0, 2.2], [0.2, 16.6, 70.0, 1.2], [-0.7, 13.8, 12.0, 0.9]]
	for i in pieces.size():  # the leaves smashed in, lying on the flagstones (walk-through)
		var pc: Array = pieces[i]
		_block(broken, "Piece%d" % i, Vector3(pc[0], 0.06, pc[1]), Vector3(pc[3], 0.1, 0.9 if i < 2 else 0.25), PLANK, pc[2], {"collision_layer": 0})
	# Flagstones over the open yard (the family house keeps its own floor).
	_block(c, "Paving", Vector3(-4.425, 0.01, 1.3), Vector3(46.65, 0.02, 32.6), STONE)
	_block(c, "PavingSE", Vector3(23.325, 0.01, 11.85), Vector3(8.85, 0.02, 11.5), STONE)
	_block(c, "PavingNE", Vector3(23.325, 0.01, -12.05), Vector3(8.85, 0.02, 5.9), STONE)
	_vhouse(c, "GreatHouse", Vector3(0, 0, -19.25), Vector3(30, 4.4, 8.5), 0.0, true)
	_festival(c)


func _festival(c: Node3D) -> void:
	var f := _group(c, "Festival")
	var V := P + "village_prop.gd"
	for z in [-11.0, -3.0, 5.0, 12.5]:
		_lantern_string(f, "String%d" % int(z + 20), Vector3(-27.6, 3.3, z), Vector3(27.6 if z > 6.0 or z < -10.0 else 18.6, 3.3, z), 8)
	_prop(f, V, "DrumW", Vector3(-6, 0, -11), {"kind": 16}, 20.0)
	_prop(f, V, "DrumE", Vector3(6, 0, -11), {"kind": 16}, -20.0)
	for i in 4:
		_prop(f, V, "Banner%d" % i, Vector3([-12.0, -8.0, 8.0, 12.0][i], 0, -12.6), {"kind": 17, "variant": i})
	for s in [-1.0, 1.0]:
		_prop(f, V, "GateLantern%s" % ("W" if s < 0 else "E"), Vector3(s * 4.6, 0, 16.6), {"kind": 0})
	var S := P + "market_stall.gd"
	_prop(f, S, "StallFood", Vector3(-24.4, 0, 0), {"kind": 3}, 90.0)
	_prop(f, S, "StallLanterns", Vector3(-24.4, 0, 6.5), {"kind": 4, "variant": 1}, 90.0)
	_prop(f, S, "StallFruit", Vector3(-24.4, 0, 13), {"kind": 0, "variant": 2}, 90.0)
	_prop(f, S, "StallCloth", Vector3(24.4, 0, 10.5), {"kind": 1, "variant": 3}, -90.0)
	_prop(f, S, "StallPottery", Vector3(24.4, 0, 15.5), {"kind": 2, "variant": 4}, -90.0)
	_light(f, "FoodGlow", Vector3(-23.8, 1.4, 0), Color(1, 0.5, 0.2), 0.8, 5.0)
	var H := P + "village_shrine.gd"
	_prop(f, H, "Shrine", Vector3(-23, 0, -20.5), {"kind": 0})
	_prop(f, H, "Torii", Vector3(-23, 0, -16.8), {"kind": 1, "width": 2.6})
	_prop(f, H, "Jizo", Vector3(-19.5, 0, -21.5), {"kind": 2, "width": 2.0})
	var G := P + "village_garden.gd"
	_prop(f, G, "Blossom", Vector3(-24.5, 0, -8), {"kind": 4, "length": 5, "variant": 1})
	_prop(f, G, "Persimmon", Vector3(24, 0, -19.5), {"kind": 4, "length": 5, "variant": 2})


## The family's own house in the courtyard's east corner: walls you can walk into, a door on the
## courtyard, a plank floor, a ramp down through a hole in it (rails round the hole), and the
## cellar under it with the capsule at the mouth of its tube.
func _family_house() -> void:
	var fh := _group(_root, "FamilyHouse")
	var h := 3.2
	var t := 0.3
	_block(fh, "WallWestA", Vector3(19.15, h * 0.5, (-9 + 3.7) * 0.5), Vector3(t, h, 12.7), PLASTER, 0.0, {"grime": 0.6})
	_block(fh, "WallWestB", Vector3(19.15, h * 0.5, 5.75), Vector3(t, h, 0.5), PLASTER, 0.0, {"grime": 0.6})
	_block(fh, "DoorHead", Vector3(19.15, 2.75, DOOR_Z), Vector3(t, 0.9, 1.8), PLASTER)
	_block(fh, "WallEast", Vector3(26.85, h * 0.5, -1.5), Vector3(t, h, 15), PLASTER, 0.0, {"grime": 0.6})
	_block(fh, "WallNorth", Vector3(23, h * 0.5, -8.85), Vector3(7.4, h, t), PLASTER, 0.0, {"grime": 0.6})
	_block(fh, "WallSouth", Vector3(23, h * 0.5, 5.85), Vector3(7.4, h, t), PLASTER, 0.0, {"grime": 0.6})
	for z in [DOOR_Z - 0.95, DOOR_Z + 0.95]:
		_block(fh, "DoorPost%d" % int(z * 10), Vector3(18.92, 1.15, z), Vector3(0.14, 2.3, 0.14), TIMBER)
	_prop(fh, P + "village_roof.gd", "Roof", Vector3(23, h, -1.5), {"length": 15.0, "depth": 8.0}, 90.0)
	# Plank floor round the ramp's hole (2 cm: no lip to trip on).
	var r := RAMP
	_block(fh, "FloorW", Vector3((19.3 + r.position.x) * 0.5, 0.01, -1.5), Vector3(r.position.x - 19.3, 0.02, 14.4), PLANK)
	_block(fh, "FloorE", Vector3((r.end.x + 26.7) * 0.5, 0.01, -1.5), Vector3(26.7 - r.end.x, 0.02, 14.4), PLANK)
	_block(fh, "FloorLanding", Vector3(r.get_center().x, 0.01, (r.end.y + 5.7) * 0.5), Vector3(r.size.x, 0.02, 5.7 - r.end.y), PLANK)
	_block(fh, "FloorBack", Vector3(r.get_center().x, 0.01, (-8.7 + r.position.y) * 0.5), Vector3(r.size.x, 0.02, r.position.y + 8.7), PLANK)
	# Rails round the hole: 1 m, too high for a four-year-old to climb (the ramp's own end is open).
	_block(fh, "RailW", Vector3(r.position.x - 0.15, 0.52, -0.7), Vector3(0.3, 1.0, 8.6), TIMBER)
	_block(fh, "RailE", Vector3(r.end.x + 0.15, 0.52, -0.7), Vector3(0.3, 1.0, 8.6), TIMBER)
	_block(fh, "RailEnd", Vector3(r.get_center().x, 0.52, r.position.y - 0.15), Vector3(r.size.x + 0.6, 1.0, 0.3), TIMBER)
	var V := P + "village_prop.gd"
	_prop(fh, V, "Sacks", Vector3(20.4, 0, -7.6), {"kind": 10})
	_prop(fh, V, "Jar", Vector3(21.6, 0, -7.9), {"kind": 1})
	_prop(fh, V, "Bench", Vector3(20.0, 0, -3.0), {"kind": 2}, 90.0)
	_light(fh, "HouseLight", Vector3(21.5, 2.5, 0.5), WARM, 1.2, 8.0)
	for z in [DOOR_Z - 1.4, DOOR_Z + 1.4]:  # paper lanterns either side of the door
		_prop(fh, P + "village_life.gd", "DoorLantern%d" % int(z * 10), Vector3(18.7, 2.6, z), {"kind": 7})
	_light(fh, "DoorGlow", Vector3(18.2, 2.3, DOOR_Z), WARM, 1.0, 6.0)
	_ramp_and_cellar(fh)


func _ramp_and_cellar(fh: Node3D) -> void:
	var r := RAMP
	var drop := -CELLAR_Y
	var run := r.size.y
	var a := atan2(drop, run)
	var length := sqrt(drop * drop + run * run) + 0.4  # 0.4 m more, tucked under the cellar floor
	var thick := 0.4
	var normal := Vector3(0, cos(a), -sin(a))
	var down := Vector3(0, -sin(a), -cos(a))  # along the ramp, downhill
	var top_mid := Vector3(r.get_center().x, CELLAR_Y * 0.5, r.get_center().y) + down * 0.2
	var ramp := _block(fh, "Ramp", top_mid - normal * thick * 0.5, Vector3(r.size.x, thick, length), FLOOR_WORN) as Node3D
	ramp.rotation.x = -a
	var y := CELLAR_Y
	var wh := -1.0 - y  # the cellar's walls run up to the floor slab's underside
	var wy := y + wh * 0.5
	for s in [[r.position.x - 0.15, "SideW"], [r.end.x + 0.15, "SideE"]]:
		_block(fh, "Ramp" + s[1], Vector3(s[0], wy, (r.position.y - 0.2 + r.end.y) * 0.5), Vector3(0.3, wh, r.size.y + 0.2), STONE)
	var cel := _group(fh, "Cellar")
	_block(cel, "Floor", Vector3(23, y - 0.25, -10.5), Vector3(20.8, 0.5, 11.8), FLOOR_WORN)
	_block(cel, "WallNorth", Vector3(23, wy, -16.2), Vector3(20.8, wh, 0.4), STONE)
	_block(cel, "Ceiling", Vector3(23, -1.05, -10.5), Vector3(20, 0.1, 11), PLANK)  # the house floor's planks, from below
	_block(cel, "WallEast", Vector3(33.2, wy, -10.5), Vector3(0.4, wh, 11.0), STONE)
	_block(cel, "WallSouthW", Vector3((13.0 + r.position.x - 0.3) * 0.5, wy, -4.8), Vector3(r.position.x - 0.3 - 13.0, wh, 0.4), STONE)
	_block(cel, "WallSouthE", Vector3((r.end.x + 0.3 + 33.0) * 0.5, wy, -4.8), Vector3(33.0 - r.end.x - 0.3, wh, 0.4), STONE)
	# The west wall, round the tube's mouth (3.6 m wide, up to 3.1 m).
	_block(cel, "WallWestN", Vector3(12.8, wy, -14.4), Vector3(0.4, wh, 3.2), STONE)
	_block(cel, "WallWestS", Vector3(12.8, wy, -7.1), Vector3(0.4, wh, 4.2), STONE)
	_block(cel, "WallWestTop", Vector3(12.8, -1.2, -11.0), Vector3(0.4, 0.4, 3.6), STONE)
	_prop(cel, "res://scripts/props_vacuum_station/tube_tunnel.gd", "Tube", Vector3(12.6, y + 1.31, -11.0),
			{"radius": 1.75, "end_radius": 1.1, "length": 30.0, "end_cap": true}, 90.0)
	for zz in [-11.6, -10.4]:  # its line: two rails from the capsule to the tube
		_block(cel, "Rail%d" % int(zz * 10), Vector3(16.0, y + 0.04, zz), Vector3(6.4, 0.08, 0.1), IRON, 0.0, {"collision_layer": 0})
	_prop(cel, "res://scripts/props_vacuum_station/old_pod.gd", "Pod", Vector3(21, y, -11), {"wrecked": false}, -90.0)
	var l := _light(cel, "CellarLight", Vector3(21, -2.0, -8.0), Color(0.72, 0.85, 1.0), 0.9, 10.0)
	l.light_specular = 0.1
	_light(cel, "RampLight", Vector3(24.5, -2.2, -6.0), WARM, 0.8, 6.0)
