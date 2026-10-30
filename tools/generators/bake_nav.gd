extends SceneTree
# Bakes the navigation mesh fighters path over in the Empty Town's courtyard and hall, and saves it
# to res://data/nav/empty_town_navmesh.tres (the level's Navigation node uses it). Re-run, or
# press "Bake NavigationMesh" on the Navigation node in the editor, after moving walls, columns,
# ramps or the stage there. Only physics layer 1 counts; props with collision off are ignored.

const SCENE := "res://scenes/levels/empty_town.tscn"
const OUT := "res://data/nav/empty_town_navmesh.tres"


func _initialize() -> void:
	_run()


func _run() -> void:
	var level: Node = load(SCENE).instantiate()
	root.add_child(level)
	await process_frame
	for i in 60:
		await physics_frame
	var b5 := level.get_node("Hall/Story/Bodies/Body5")
	for c in b5.get_children(true):
		if c is CollisionShape3D:
			print("Body5 shape ", c.shape, " disabled ", c.disabled)
	var nm := make_navmesh()
	if not level.is_in_group("navmesh_source"):
		level.add_to_group("navmesh_source")
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, level)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	print("navmesh: %d polygons, %d vertices" % [nm.get_polygon_count(), nm.get_vertices().size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/nav"))
	print("saved: ", ResourceSaver.save(nm, OUT) == OK)
	quit()


static func make_navmesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.25         # one cell, under the 0.35 capsule: a guard can never stand off the mesh
	nm.agent_height = 1.75         # whole cells too
	nm.agent_max_climb = 0.25      # no steps: they walk ramps, like the player
	nm.agent_max_slope = 45.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "navmesh_source"
	nm.filter_baking_aabb = AABB(Vector3(-10, -1, -30), Vector3(20, 6, 40))  # courtyard + hall only
	return nm
