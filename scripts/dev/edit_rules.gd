extends RefCounted
## The rules of in-game Build Mode: which scene an edit belongs to, which node a click means,
## and which nodes the story needs (they can't be deleted, and say why).
##
## Edit roots: the running scene's root, and every instance of a level or world scene inside it
## (res://scenes/levels/*, res://scenes/world/*). In the big world a crate in the town belongs to
## empty_town.tscn, so the edit is written to data/edits/empty_town.json and shows up wherever
## the town is loaded (alone with F6, or inside the world).

const EDIT_FOLDERS := ["res://scenes/levels/", "res://scenes/world/"]

## Script files whose nodes the story leans on: [file name, why it can't be deleted].
const STORY_SCRIPTS := [
	["story_trigger.gd", "a story trigger: it starts a scene"],
	["story_cue_takedown.gd", "a story trigger: it starts a scene"],
	["checkpoint.gd", "a checkpoint: restarts and saves come back here"],
	["fight.gd", "a story fight: a scene starts it"],
	["stealth_director.gd", "the stealth director: it runs the restarts"],
	["world_zone.gd", "a zone of the big world"],
	["world_link.gd", "a walkway of the big world"],
	["world_gate.gd", "a gate of the big world: the story opens it"],
	["autosave.gd", "the autosave"],
	["companion.gd", "a character: the story moves them"],
]
const CHARACTER_SCENES := ["res://scenes/player.tscn", "res://scenes/isabella.tscn",
		"res://scenes/kael.tscn", "res://scenes/valentina.tscn", "res://scenes/guard.tscn"]


## The scene an edit of `node` belongs to (see the top of this file), or null.
static func edit_root_of(node: Node, scene_root: Node) -> Node:
	var p := node.get_parent() if node else null
	while p:
		if p == scene_root or is_edit_scene(p.scene_file_path):
			return p
		p = p.get_parent()
	return null


static func is_edit_scene(path: String) -> bool:
	for folder: String in EDIT_FOLDERS:
		if path.begins_with(folder):
			return true
	return false


## The node a click on `hit` means: the prop, block, light, decal or prefab instance, never a
## mesh a script built inside it or a part inside a prefab. Null if it is nothing editable.
static func target_of(hit: Node, scene_root: Node) -> Node3D:
	var root := edit_root_of(hit, scene_root)
	if root == null:
		return null
	var n := hit
	while n and n != root and n.owner != root:  # climb out of built parts and prefab insides
		n = n.get_parent()
	if n == null or n == root:
		return null
	# A bare mesh, shape or light inside a scripted thing (or a body) means that thing.
	while _is_part(n) and n.get_parent() != root and n.get_parent().owner == root and _is_unit(n.get_parent()):
		n = n.get_parent()
	return n as Node3D


## Why this node can't be deleted ("" when it can): the node itself or anything inside it.
static func protected_reason(node: Node) -> String:
	var own := _own_reason(node)
	if own != "":
		return own
	for child in node.get_children():
		var inner := protected_reason(child)
		if inner != "":
			return "it holds " + inner.get_slice(":", 0)
	return ""


## Why this node can't be moved ("" when it can). Most story things may move; these may not.
static func locked_reason(node: Node) -> String:
	if node.is_in_group("player"):
		return "Aeneas moves himself"
	if node is NavigationRegion3D:
		return "the navigation floor: rebake it in the editor instead"
	if node is WorldEnvironment:
		return "the level's light and fog"
	var s := node.get_script() as Script
	if s and s.resource_path.get_file() in ["world_zone.gd", "world_link.gd"]:
		return "part of the big world's layout: move it in the editor"
	return ""


static func _own_reason(n: Node) -> String:
	if n.is_in_group("player"):
		return "Aeneas"
	if n.is_in_group("guards"):
		return "a guard: patrols, fights and saves count on him"
	if n is CharacterBody3D or n.scene_file_path in CHARACTER_SCENES:
		return "a character: the story moves them"
	if n is NavigationRegion3D:
		return "the navigation floor fighters walk on"
	if n is WorldEnvironment:
		return "the level's light and fog"
	if n.is_in_group("checkpoints"):
		return "a checkpoint: restarts and saves come back here"
	var s := n.get_script() as Script
	if s:
		var file := s.resource_path.get_file()
		for entry: Array in STORY_SCRIPTS:
			if file == entry[0]:
				return entry[1]
	if n is Camera3D and n.get_parent() and n.get_parent().name == &"Shots":
		return "a story camera: a scene cuts to it with [camera %s]" % n.name
	if n.name == &"Shots" or n.name == &"StoryTriggers" or n.name == &"Checkpoints":
		return "the level's %s list" % n.name
	return ""


## A piece something else is made of (a mesh, a shape, a light, a sound).
static func _is_part(n: Node) -> bool:
	return n is GeometryInstance3D or n is CollisionShape3D or n is Light3D or n is Decal \
			or n is AudioStreamPlayer3D or n is Marker3D or n is GPUParticles3D


## Something whole: a script, a prefab instance, a body or a zone (not a plain group node).
static func _is_unit(n: Node) -> bool:
	return n.get_script() != null or n.scene_file_path != "" or n is PhysicsBody3D or n is Area3D
