extends RefCounted
## Rebakes the open level's navigation mesh (the floor fighters path over) and keeps a copy of
## the old one, so the dock can undo a bake. The mesh's own settings decide what counts (agent
## size, which nodes, the area): select the Navigation node and look at its NavigationMesh.

## The level's NavigationRegion3D: the node called Navigation, or the first one found.
static func find_region(root: Node) -> NavigationRegion3D:
	var named := root.get_node_or_null("Navigation") as NavigationRegion3D
	if named:
		return named
	var all := root.find_children("*", "NavigationRegion3D", true, false)
	return all[0] as NavigationRegion3D if not all.is_empty() else null


## The mesh's polygons as plain data, to put back later.
static func snapshot(nm: NavigationMesh) -> Dictionary:
	var polygons: Array = []
	for i in nm.get_polygon_count():
		polygons.append(nm.get_polygon(i))
	return {"vertices": nm.get_vertices(), "polygons": polygons}


## Puts a snapshot back into the mesh and, if the mesh is its own file, saves that file.
static func restore(region: NavigationRegion3D, snap: Dictionary) -> void:
	var nm := region.navigation_mesh
	nm.clear_polygons()
	nm.set_vertices(snap.vertices)
	for polygon: PackedInt32Array in snap.polygons:
		nm.add_polygon(polygon)
	nm.emit_changed()
	save_if_file(nm)


## A mesh kept in data/nav/*.tres is saved straight away; one stored inside the level saves
## with the level (Ctrl+S).
static func save_if_file(nm: NavigationMesh) -> bool:
	if nm.resource_path.begins_with("res://") and not nm.resource_path.contains("::"):
		return ResourceSaver.save(nm, nm.resource_path) == OK
	return false


## Bakes now (the editor pauses for a moment). Returns {ok, before, after, message}.
static func bake(region: NavigationRegion3D) -> Dictionary:
	if region.navigation_mesh == null:
		region.navigation_mesh = NavigationMesh.new()
	var nm := region.navigation_mesh
	var before := snapshot(nm)
	region.bake_navigation_mesh(false)
	var after := snapshot(nm)
	var saved := save_if_file(nm)
	var msg := "Navigation baked: %d polygons (was %d)." % [after.polygons.size(), before.polygons.size()]
	if saved:
		msg += " Saved to " + nm.resource_path.get_file() + "."
	else:
		msg += " Save the level (Ctrl+S) to keep it."
	if after.polygons.is_empty():
		msg = "The bake found no floor. Check the NavigationMesh settings on the Navigation node (Geometry > Source Group Name, and the level root's group)."
	return {"ok": not after.polygons.is_empty(), "before": before, "after": after, "message": msg}
