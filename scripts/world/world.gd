class_name World
extends Node3D
## The one big world (scenes/world/world.tscn): the Empty Town, Black Sand and the Vacuum Station
## as one connected place, joined by walkways you can actually walk (WorldLinks: the service stair
## behind the hall's stage, the road tunnel). The Massacre stays its own scene: it is a memory.
## Each place is still its own level scene, instanced under Zones (one WorldZone each), so you can
## open and run it alone (F6) as before. When the world starts it removes each level's own Player
## and StealthDirector and uses its single ones; companions join Aeneas from the zone where the
## story picks them up. Only the zone he is in is shown and running (both zones while he walks a
## link), and its fog, light and music fade into the next as he crosses.
## The story finds it through Story: a [level] line or a chapter that names a level in LEVELS comes
## here and starts at that zone's Start marker; inside the world such a line just lets him walk on.

signal stage_changed(stage: int)

const SCENE := "res://scenes/world/world.tscn"
## The levels that live inside the world. Add a level here when you add its WorldZone.
const LEVELS := [
	"res://scenes/levels/empty_town.tscn",
	"res://scenes/levels/black_sand.tscn",
	"res://scenes/levels/vacuum_station.tscn",
]

static var pending_level := ""  ## set before loading the world: start at this level's zone
static var current_level := ""  ## the level of the zone Aeneas is in (pause menu, music)

var stage := 0                  ## the furthest zone order the story has reached in this run
var zones: Array[WorldZone] = []
var links: Array[WorldLink] = []
var player: Player

var _here: Node3D               # the zone or link he is in (null: nowhere yet)
var _blend := WorldBlend.new()


## Does this level live inside the world?
static func has_level(path: String) -> bool:
	return path in LEVELS


## The World a node belongs to, or null (a level running on its own).
static func of(node: Node) -> World:
	var n := node
	while n:
		if n is World:
			return n
		n = n.get_parent()
	return null


## A node's transform relative to the world's root, also before anything is in the tree.
static func xf_in(world: Node, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n and n != world:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Clears the scene ownership of a node and everything under it, before it moves to another
## part of the world (ownership only matters for saving scenes, which the world never does).
## Nodes owned inside the moved piece (the insides of an instanced character) keep their owner.
static func unown(node: Node) -> void:
	for n in [node] + node.find_children("*", "", true, false):
		var o: Node = n.owner
		if o and o != node and not node.is_ancestor_of(o):
			n.owner = null


## Removes a node for good (works before and after it is in the tree).
static func drop(node: Node) -> void:
	if node == null:
		return
	if node.is_inside_tree():
		node.queue_free()
	else:
		node.get_parent().remove_child(node)
		node.free()


func _enter_tree() -> void:
	# Runs before any child is in the tree, so removed nodes never start.
	process_physics_priority = -10  # sort the zones out before Aeneas moves
	player = get_node("Player")
	for z in get_node("Zones").get_children():
		if z is WorldZone:
			zones.append(z)
			z.prepare()
	for l in get_node("Links").get_children():
		if l is WorldLink:
			links.append(l)
			l.prepare(self)
	var start := _start_zone()
	stage = start.order if start else 0
	for z in zones:
		z.apply_stage(self, stage)
	_update(true)


func _ready() -> void:
	player.respawned.connect(func() -> void: _update(false))
	var director := get_node_or_null("StealthDirector")
	if director and director.has_method("move_checkpoint"):
		director.move_checkpoint(player.global_position)


func _physics_process(_delta: float) -> void:
	_update(false)


## A companion or gear joins Aeneas: it moves into Carry (keeping its place) and follows him.
func carry(node: Node3D) -> void:
	var carry_node := get_node("Carry")
	if node.get_parent() == carry_node:
		return
	unown(node)
	if node.is_inside_tree():
		node.reparent(carry_node)
	else:
		var at := xf_in(self, node)
		node.get_parent().remove_child(node)
		carry_node.add_child(node)
		node.transform = at
	if "leader" in node and node.get("leader") == null:
		node.set("leader", player)


## The level a dialogue file belongs to (black_sand.txt -> the Black Sand level), so a scene's
## [camera TownShot] finds Black Sand's TownShot, not the town's.
func level_for_dialogue(path: String) -> Node:
	var name := path.get_file().get_basename()
	for z in zones:
		if z.level and z.level_path().get_file().get_basename() == name:
			return z.level
	return self


## The level Aeneas is in now.
func level_here() -> Node3D:
	var z := _dominant()
	return z.level if z else null


## A level of the world -> its zone.
func zone_of(level_path: String) -> WorldZone:
	for z in zones:
		if z.level_path() == level_path:
			return z
	return null


func _start_zone() -> WorldZone:
	var wanted := zone_of(pending_level) if pending_level != "" else null
	pending_level = ""
	if wanted:
		player.transform = wanted.start_transform(self)
		return wanted
	# Opened directly (F6) or reloaded at a spot: start wherever the Player stands.
	for z in zones:
		if z.has_point(player.position):
			return z
	return zones[0] if not zones.is_empty() else null


func _dominant() -> WorldZone:
	if _here is WorldZone:
		return _here
	if _here is WorldLink:
		var link := _here as WorldLink
		return link.b if link.progress(player.global_position) >= 0.5 else link.a
	return null


func _update(initial: bool) -> void:
	var at := player.global_position if player.is_inside_tree() else player.position
	var found: Node3D = null
	for z in zones:
		if z.has_point(at):
			found = z
	if found == null:
		for l in links:
			if l.has_point(at):
				found = l
	if found:
		_here = found
	elif _here == null:
		_here = zones[0]
	var shown: Array[WorldZone] = []
	var weights: Array[float] = []
	if _here is WorldLink:
		var link := _here as WorldLink
		var t := link.progress(at)
		shown = [link.a, link.b]
		weights = [1.0 - t, t]
	else:
		shown = [_here as WorldZone]
		weights = [1.0]
	for z in zones:
		var on := z in shown
		if initial or z.visible != on:
			z.visible = on
			z.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	for l in links:
		var on := l == _here or ((l.a in shown or l.b in shown) and l.is_near(at))
		if initial or l.visible != on:
			l.visible = on
			l.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	var limit := INF
	for z in shown:
		limit = minf(limit, z.fall_limit())
	player.fall_limit = limit
	var profiles: Array[Environment] = []
	for z in shown:
		profiles.append(z.profile())
	_blend.apply(get_node("WorldEnvironment"), profiles, weights)
	var main := _dominant()
	if main:
		current_level = main.level_path()
		if main.order > stage:
			_reach(main)


## He walked into a zone further on in the story: Continue starts there from now on, and the
## zones behind him move on (their story triggers go, and so on).
func _reach(zone: WorldZone) -> void:
	stage = zone.order
	SaveGame.record_level(zone.level_path())
	for z in zones:
		z.apply_stage(self, stage)
	stage_changed.emit(stage)
