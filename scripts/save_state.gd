class_name SaveState
extends RefCounted
## What a save holds, read from the running game (Autosave calls capture()). Put back by
## save_restore.gd. Everything that changes for good is in it:
##   where he stands (and the way he and the camera face), the restart point,
##   the zone and how far the story has come (the big world's stage),
##   the story scenes finished, in order (Continue marks their triggers done and replays what
##   they changed: who is hidden or shown, who collapsed, the eruption, the fight they started),
##   the checkpoints reached, the fights won, the agents down for good (where, which way, knifed
##   or not), the look-at spots that can only be read once, and the flashlight.
## Health is not saved: Continue starts at full health, like every restart.
## Nodes are saved as keys, "<level file>::<path inside that level>", and positions relative to
## their level, so moving a whole zone in world.tscn doesn't break a save.


## The save of the game as it is now. `root` is the big world or a level running alone; the spot
## (where Continue puts him) is a global transform; `level` is the level it belongs to.
static func capture(root: Node, story_log: Dictionary, reason: String, spot: Transform3D, level: Node3D) -> Dictionary:
	var tree := root.get_tree()
	var player := tree.get_first_node_in_group("player") as Player
	var to_level := level.global_transform.affine_inverse()
	var level_yaw := level.global_rotation.y
	var data := {
		"version": SaveGame.VERSION, "saved_unix": int(Time.get_unix_time_from_system()), "reason": reason,
		"level": level.scene_file_path, "scene": root.scene_file_path, "fresh": false,
		"stage": root.stage if root is World else 0,
		"spot": {"pos": _arr(to_level * spot.origin), "yaw": spot.basis.get_euler().y - level_yaw,
				"cam_yaw": player.camera_pivot.rotation.y if player else 0.0},
		"story": story_log.duplicate(true),
		"checkpoints": [], "fights_won": [], "guards_down": [], "looked": [],
		"flashlight": false,
	}
	var director := root.get_node_or_null("StealthDirector")
	if director and director.has_method("checkpoint_position"):
		data.restart = {"pos": _arr(to_level * director.checkpoint_position())}
	for cp in tree.get_nodes_in_group("checkpoints"):
		if cp.get("reached_once") == true:
			_add_key(data.checkpoints, cp)
	for fight in tree.get_nodes_in_group("fights"):
		if fight.get("won") == true:
			_add_key(data.fights_won, fight)
	for spot_node in tree.get_nodes_in_group("interactables"):
		if spot_node.has_method("is_read") and spot_node.is_read():
			_add_key(data.looked, spot_node)
	for g: Guard in tree.get_nodes_in_group("guards"):
		var key := key_of(g)
		if g.state == Guard.State.DOWN and g.down_for_good and key != "":
			var own := level_of(g)
			data.guards_down.append({"key": key, "pos": _arr(own.global_transform.affine_inverse() * g.global_position),
					"yaw": g.model.rotation.y - own.global_rotation.y, "killed": g.killed})
	for light in tree.get_nodes_in_group("flashlights"):
		if light.has_method("is_on") and light.is_on():
			data.flashlight = true
	if player and player.skills:
		data.progress = player.skills.to_save()  # Aether, skills bought, the skill tree
	return data


## The level a node lives in: its nearest ancestor that is a story level's scene (in the big
## world, the zone's level instance), or null (the world's own nodes, companions in Carry).
static func level_of(node: Node) -> Node3D:
	var n := node
	while n:
		var file := n.scene_file_path
		if n is Node3D and file != "" and file != World.SCENE and Chapters.is_story_level(file):
			return n
		n = n.get_parent()
	return null


## "res://scenes/levels/empty_town.tscn::Guards/AgentEastDeck", or "" for a node in no level.
static func key_of(node: Node) -> String:
	var level := level_of(node)
	if level == null or level == node:
		return ""
	return "%s::%s" % [level.scene_file_path, level.get_path_to(node)]


## The node a key names, in the big world or a level running alone; null if it is gone.
static func node_of(root: Node, key: String) -> Node:
	var cut := key.find("::")
	if cut < 0:
		return null
	var level := level_node(root, key.substr(0, cut))
	return level.get_node_or_null(NodePath(key.substr(cut + 2))) if level else null


## A level of the running game by its file: a zone's level in the big world, or the level itself.
static func level_node(root: Node, path: String) -> Node3D:
	if root is World:
		var zone: WorldZone = (root as World).zone_of(path)
		return zone.level if zone else null
	return root as Node3D if root.scene_file_path == path else null


static func _add_key(list: Array, node: Node) -> void:
	var key := key_of(node)
	if key != "":
		list.append(key)


static func _arr(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
