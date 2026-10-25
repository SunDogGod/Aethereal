extends Node
## Going places from the dev menu (DevTools/Places): teleports, the last checkpoint, restarts,
## reloads and chapter jumps. It keeps track of the last checkpoint Aeneas reached by listening
## to the checkpoints' `reached` signal, the same signal the StealthDirector listens to.
## Like the cheats, it only uses the public side of the game's nodes.

var cheats: Node                  ## DevTools/Cheats: finds the player, the story, the floor
var checkpoint_name := "start"    ## the last checkpoint reached in this level ("start" = none yet)
var checkpoint_at := Vector3.ZERO ## where it is

var _checkpoint_path := NodePath()  # its path in the level, to find it again after a reload
var _scene: Node


func _process(_delta: float) -> void:
	_watch_scene()


func _physics_process(_delta: float) -> void:
	_watch_scene()


## Every place in the level worth jumping to, as [group, label, node].
func targets() -> Array:
	var out := []
	var lv: Node = cheats.level()
	if lv == null:
		return out
	for cp in get_tree().get_nodes_in_group("checkpoints"):
		if lv.is_ancestor_of(cp):
			out.append(["CHECKPOINTS", str(cp.name), cp])
	for area in lv.find_children("*", "Area3D", true, false):
		if "dialogue_file" in area and "scene" in area:
			out.append(["STORY TRIGGERS", "%s  (%s)" % [area.name, area.get("scene")], area])
	var shots := lv.get_node_or_null("Shots")
	if shots:
		for cam in shots.find_children("*", "Camera3D", true, false):
			out.append(["CAMERA SHOTS", str(cam.name), cam])
	for mark in lv.find_children("*", "Marker3D", true, false):
		var path := str(lv.get_path_to(mark))
		if not path.contains("Model/"):  # skip the eye points inside the agents' models
			var parts := path.split("/")
			out.append(["MARKERS", " / ".join(parts.slice(maxi(0, parts.size() - 3))), mark])
	return out


## Puts Aeneas on the floor at (or under) a node: a checkpoint, a trigger, a shot, a marker.
## A scene that is playing is skipped first. Returns false if there was nowhere to stand.
func teleport_to(target: Node3D) -> bool:
	if cheats.story_playing():
		await cheats.skip_scene()
	var p = cheats.player()
	if p == null or not is_instance_valid(target) or not target.is_inside_tree():
		return false  # the skipped scene took him to another level
	var spot := target.global_position
	if not cheats.noclip.on:
		var ground: Variant = cheats.find_floor(spot)
		if ground == null:
			return false
		spot = ground
	p.respawn_at(spot)
	var pivot := p.get_node_or_null("CameraPivot") as Node3D
	if pivot:  # look the way the node looks (a shot: the way its camera points)
		pivot.rotation.y = target.global_rotation.y
	return true


## The game's own restart (what being spotted does), back to the last checkpoint.
func restart_at_checkpoint() -> void:
	if cheats.story_playing():
		await cheats.skip_scene()
	cheats.noclip.set_on(false)
	var d = cheats.director()
	var p = cheats.player()
	if d and d.has_method("restart"):
		d.restart("RESTART")
	elif p:
		p.respawn_at(checkpoint_at)


## A fresh copy of this level, from its start or with Aeneas at the last checkpoint.
func reload_level(at_checkpoint: bool) -> void:
	var lv: Node = cheats.level()
	if lv == null or lv.scene_file_path == "":
		return
	var keep_name := checkpoint_name
	var keep_path := _checkpoint_path
	var spot: Variant = checkpoint_at if at_checkpoint and keep_name != "start" else null
	await _change_level(lv.scene_file_path, spot)
	var p = cheats.player()
	if spot == null or p == null:
		return
	p.respawn_at(spot)  # Isabella (and anyone else listening) catches up with him
	var d = cheats.director()
	if d and d.has_method("move_checkpoint"):
		d.move_checkpoint(spot)
	checkpoint_name = keep_name
	checkpoint_at = spot
	_checkpoint_path = keep_path
	cheats.emit_signal("changed")


## Jumps to a chapter (a level path from Chapters.LIST), with the Story's fade.
func go_to_chapter(path: String) -> void:
	cheats.noclip.forget()
	var s = cheats.story()
	if s and s.has_method("stop"):
		s.stop()  # end any scene at once (the level is going away)
	if s and s.has_method("go_to_level"):
		s.go_to_level(path)
	else:
		get_tree().change_scene_to_file(path)


## Swaps in a new copy of a level. With a spot, Aeneas is moved there BEFORE the level
## enters the tree, so the level starts with him there: the trigger around his usual start
## (the opening scene) never sees him, and the StealthDirector takes the spot as its checkpoint.
func _change_level(path: String, spot: Variant = null) -> void:
	cheats.noclip.forget()
	var s = cheats.story()
	if s and s.has_method("stop"):
		s.stop()
	var old: Node = cheats.level()
	var fresh: Node = (load(path) as PackedScene).instantiate()
	var p := fresh.get_node_or_null("Player") as Node3D
	var base := fresh as Node3D
	if spot != null and p:
		p.position = base.transform.affine_inverse() * (spot as Vector3) if base else (spot as Vector3)
	get_tree().change_scene_to_node(fresh)
	for i in 120:
		await get_tree().process_frame
		if cheats.level() != null and cheats.level() != old:
			break
	_watch_scene()


## A new level: the checkpoint goes back to its start, and we listen to its checkpoints.
func _watch_scene() -> void:
	var lv: Node = cheats.level()
	if lv == _scene:
		return
	_scene = lv
	var p = cheats.player()
	checkpoint_name = "start"
	checkpoint_at = p.global_position if p else Vector3.ZERO
	_checkpoint_path = NodePath()
	for cp in get_tree().get_nodes_in_group("checkpoints"):
		if cp.has_signal("reached") and not cp.is_connected("reached", _on_checkpoint):
			cp.connect("reached", _on_checkpoint)
	if p and p.has_signal("respawned") and not p.is_connected("respawned", _on_respawned):
		p.connect("respawned", _on_respawned)
	cheats.emit_signal("changed")


func _on_checkpoint(cp: Node3D) -> void:
	checkpoint_name = str(cp.name)
	checkpoint_at = cp.global_position
	_checkpoint_path = cheats.level().get_path_to(cp) if cheats.level() else NodePath()
	cheats.emit_signal("changed")


## A story scene's [teleport] moves the restart point to where it put him.
func _on_respawned() -> void:
	var p = cheats.player()
	if cheats.story_playing() and p:
		checkpoint_name = "story teleport"
		checkpoint_at = p.global_position
		_checkpoint_path = NodePath()
		cheats.emit_signal("changed")
