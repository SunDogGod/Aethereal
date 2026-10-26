class_name MeshBuild
extends RefCounted
## When code-built meshes get built: ONCE, when the node is in a scene.
## Blocks (block.gd) and the prop scripts (scripts/props*/) make their mesh in code from their
## Inspector settings. While a scene file is being instanced, Godot sets those settings one by
## one, and each set used to rebuild the whole mesh again (in the big world that froze New Game
## for half a minute). Now a set only marks the node as waiting; it builds when it enters the
## tree (in the editor, with F6, in tests), or earlier, a few at a time while the loading screen
## is up (scene_loader.gd), so a level arrives already built and the window keeps drawing.
## In the editor nothing changes for you: a node in an open scene rebuilds at once when you edit it.
##
## Identical plain Blocks share one mesh while the game runs (same size and shading = the same
## mesh): less building and less video memory. The editor never shares.
##
## For a new mesh-building script: keep `var _build_pending := false`, put the building in
## `_rebuild_now()`, and write `func _rebuild() -> void: MeshBuild.request(self)`; every setter
## calls _rebuild(). Build props with PropMesh (scripts/props/prop_mesh.gd), never by passing a
## PrimitiveMesh to SurfaceTool.append_from while the game runs (each one is a slow round trip to
## the graphics card).

static var _shared := {}  # [size, grime, grime_height, trim] -> WeakRef to the ArrayMesh


## Called from a builder's _rebuild(): builds now if the node is in the tree, else once it enters.
static func request(node: Node) -> void:
	if node.is_inside_tree():
		node._build_pending = false
		node._rebuild_now()
	elif not node._build_pending:
		node._build_pending = true
		node.tree_entered.connect(node._rebuild, CONNECT_ONE_SHOT)


## Can the loading screen build this node before it enters the tree? (A BUILDING block can't:
## its doors and windows look at its neighbours in the scene, so it builds in its _ready.)
static func can_build_early(node: Node) -> bool:
	if not ("_build_pending" in node) or not node._build_pending or node.is_inside_tree():
		return false
	return not (node is Block and node.style == Block.Style.BUILDING)


## Builds a waiting node now, before it enters the tree (the loading screen).
static func build_early(node: Node) -> void:
	if not can_build_early(node):
		return
	node._build_pending = false
	if node.tree_entered.is_connected(node._rebuild):
		node.tree_entered.disconnect(node._rebuild)
	node._rebuild_now()


## Every node under `root` the loading screen can build early, in tree order.
static func waiting_under(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	for n in root.find_children("*", "", true, false):
		if can_build_early(n):
			out.append(n)
	return out


## A mesh another Block with exactly these settings already built (null if none, or in the editor).
static func shared(key: Array) -> ArrayMesh:
	if Engine.is_editor_hint() or not _shared.has(key):
		return null
	return (_shared[key] as WeakRef).get_ref() as ArrayMesh


static func share(key: Array, mesh: ArrayMesh) -> void:
	if not Engine.is_editor_hint():
		_shared[key] = weakref(mesh)


## Forgets meshes nothing shows any more (the loading screen calls this after a level change).
static func forget_unused() -> void:
	for key: Array in _shared.keys():
		if (_shared[key] as WeakRef).get_ref() == null:
			_shared.erase(key)
