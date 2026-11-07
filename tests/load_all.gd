extends SceneTree
# Loads every level for a second each and reports Block counts, so a Block/shader change
# that breaks a scene shows up here.

func _initialize() -> void:
	_run()


func _run() -> void:
	for path in ["res://scenes/levels/empty_town.tscn", "res://scenes/levels/massacre.tscn",
			"res://scenes/levels/black_sand.tscn", "res://scenes/levels/vacuum_station.tscn", "res://scenes/levels/horus_road.tscn",
			"res://scenes/levels/temek.tscn", "res://scenes/test_yard.tscn",
			"res://scenes/world/world.tscn"]:
		var level: Node = load(path).instantiate()
		root.add_child(level)
		current_scene = level
		for i in 40:
			await physics_frame
		var blocks := 0
		var trims := 0
		for b in level.find_children("*", "StaticBody3D", true, false):
			if b is Block:
				blocks += 1
				if b.trim:
					trims += 1
		var player = level.get_node_or_null("Player")
		print("%-45s blocks %3d (trim %2d)  player on floor: %s" % [path.get_file(), blocks, trims, player.is_on_floor() if player else "n/a"])
		root.remove_child(level)
		level.free()
	quit()
