class_name WorldZone
extends Node3D
## One place in the big world (scenes/world/world.tscn): a level scene instanced as this node's
## child, plus the facts the world needs about it. Move this node to move the whole level.
## The level scene itself stays untouched and runnable on its own (F6): everything that only
## matters in the world (removing its own Player, who follows Aeneas, what is gone once the
## story has moved on) is listed here instead. Paths are relative to the level's root node.

@export var order := 1  ## story order, the chapter's number after the dot (0.1 town, 0.3 Black Sand, 0.4 station)
@export var box := AABB(Vector3(-50, -15, -50), Vector3(100, 100, 100))  ## the zone's space, in this node's coordinates. Its bottom is the fall limit.
## Nodes of the level that the world replaces with its own (its Player, its StealthDirector).
@export var remove_in_world := PackedStringArray(["Player", "StealthDirector"])
## Companions (and gear) that travel with Aeneas once the story has reached this zone. They move
## out of the level into the world's Carry node, so they keep going when the zone is switched off.
@export var followers := PackedStringArray()
## Removed once the story is past this zone (a chapter started further on, or he walked on):
## its story triggers, the agents who left, the companion who died.
@export var gone_after := PackedStringArray()
@export var hidden_after := PackedStringArray()  ## hidden once the story is past this zone
@export var shown_after := PackedStringArray()   ## shown once the story is past this zone

var level: Node3D  ## the level instance (this node's first child)


## The level's file, e.g. res://scenes/levels/black_sand.tscn.
func level_path() -> String:
	return level.scene_file_path if level else ""


## Where Aeneas starts when a chapter or a [level] line sends him here (the Start marker).
func start_transform(world: Node3D) -> Transform3D:
	var mark := get_node_or_null("Start") as Node3D
	return World.xf_in(world, mark if mark else self)


## True when a point (world coordinates) is inside the zone's box.
func has_point(world_point: Vector3) -> bool:
	return box.has_point(transform.affine_inverse() * world_point)


## The height under which he has fallen out of this zone (world metres).
func fall_limit() -> float:
	return (transform * box.position).y


## The level's own WorldEnvironment settings: the world blends these as he walks between zones.
## Read live, so a level that changes its own (Black Sand's dawn) shows the change.
func profile() -> Environment:
	var we := level.get_node_or_null("WorldEnvironment") as WorldEnvironment if level else null
	return we.environment if we else null


## Called once, before the level enters the tree: drop what the world replaces.
func prepare() -> void:
	level = get_child(0) as Node3D
	for path in remove_in_world:
		World.drop(level.get_node_or_null(path))
	for path in followers:  # nobody follows the level's own (removed) Player any more
		var n := level.get_node_or_null(path)
		if n and "leader" in n:
			n.set("leader", null)


## Applies the story's progress: `stage` is the furthest zone order reached.
func apply_stage(world: World, stage: int) -> void:
	var past := stage > order
	if past:
		for path in gone_after:
			World.drop(level.get_node_or_null(path))
		for path in hidden_after:
			var n := level.get_node_or_null(path) as Node3D
			if n:
				n.visible = false
		for path in shown_after:
			var n := level.get_node_or_null(path) as Node3D
			if n:
				n.visible = true
	if stage >= order:
		for path in followers:
			var n := level.get_node_or_null(path) as Node3D
			if n:
				world.carry(n)
