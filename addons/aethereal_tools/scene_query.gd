extends RefCounted
## Small questions about the open level that the dock asks before adding something: is this
## node a guard, which fight or guard is selected, which name is still free. Nothing changes here.

const GUARD_SCENE := "res://scenes/guard.tscn"
const FIGHT_SCRIPT := "res://scripts/fight.gd"


## A guard: guard.tscn, a scene inheriting it (the prefab), or anything carrying guard.gd.
static func is_guard(n: Node) -> bool:
	if not n is CharacterBody3D:
		return false
	if n.scene_file_path == GUARD_SCENE:
		return true
	var script := n.get_script() as Script
	return script != null and script.resource_path.get_file() == "guard.gd"


## The guard a node belongs to: itself, or the guard of a selected patrol point / Route.
static func guard_of(n: Node, level: Node) -> Node3D:
	while n != null and n != level:
		if is_guard(n):
			return n
		n = n.get_parent()
	return null


## The Fight a node is (or the Fight of a selected guard inside one), or null.
static func fight_of(n: Node) -> Node3D:
	if n is CharacterBody3D:
		n = n.get_parent()  # a guard inside a fight: add next to him
	if n is Node3D and n.get_script() and (n.get_script() as Script).resource_path == FIGHT_SCRIPT:
		return n
	return null


## `base`, or base2, base3... whichever is free under `parent` (also counting names that
## `steps` are about to add there).
static func unique(parent: Node, base: String, steps: Array) -> String:
	if not _taken(parent, base, steps):
		return base
	var i := 2
	while _taken(parent, "%s%d" % [base, i], steps):
		i += 1
	return "%s%d" % [base, i]


## The next free letter for a patrol point: A, B, C...
static func unique_letter(route: Node, steps: Array) -> String:
	for code in range(65, 91):  # A..Z
		var letter := String.chr(code)
		if not _taken(route, letter, steps):
			return letter
	return unique(route, "P", steps)


## Every node in a new subtree that no scene owns yet (not the insides of an instanced guard).
static func collect_unowned(node: Node, into: Array[Node]) -> void:
	if node.owner == null:
		into.append(node)
	for child in node.get_children():
		collect_unowned(child, into)


static func _taken(parent: Node, n: String, steps: Array) -> bool:
	if parent.has_node(NodePath(n)):
		return true
	for step: Dictionary in steps:
		if step.parent == parent and step.node.name == n:
			return true
	return false
