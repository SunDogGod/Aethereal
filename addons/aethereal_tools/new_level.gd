extends RefCounted
## Makes a new level from scenes/prefabs/level_template.tscn: a floor, light and fog, the Player,
## the StealthDirector, an opening camera, an arrival scene trigger, the usual group nodes and a
## Navigation node. It also starts the level's dialogue file. Nothing existing is overwritten.

const TEMPLATE := "res://scenes/prefabs/level_template.tscn"

const DIALOGUE_HEADER := """# %s: every spoken scene in the level.
#
# DRAFT. Write the scenes in your own words; the game picks up changes the next time you press F5.
#
# How to write a scene:
#   === scene_name ===          starts a scene. A StoryTrigger in the level plays it by this name.
#   KAEL: Does anyone live here?
#                               a spoken line: the NAME in capitals, a colon, then the words.
#   The wind stops.             a line with no NAME is narration.
#   [camera OpeningShot]        cut to a camera (a Camera3D under the level's Shots node).
#   [camera]                    cut back to the normal camera behind Aeneas.
#   [wait 1.5]                  pause for 1.5 seconds.
#   [hide Kael] / [show Kael]   hide or show something in the level, by its node name.
#   More commands (fights, fades, titles, the next level) are in docs/customizing.md.
# Lines starting with # are notes to yourself; the game ignores them.

=== arrival ===
[camera OpeningShot]
DRAFT: a line of narration as Aeneas arrives.
[camera]
"""


## "The Old Mill" -> "the_old_mill" (letters, digits and underscores only).
static func file_name(display_name: String) -> String:
	var snake := display_name.strip_edges().to_snake_case()
	var clean := ""
	for c in snake:
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
			clean += c
	return clean.trim_prefix("_").trim_suffix("_")


## Makes the level and its dialogue file. Returns {ok, path, message}.
static func create(display_name: String, levels_dir := "res://scenes/levels", dialogue_dir := "res://data/dialogue") -> Dictionary:
	var base := file_name(display_name)
	if base.is_empty():
		return {"ok": false, "message": "Type a name with some letters in it."}
	var path := "%s/%s.tscn" % [levels_dir, base]
	if FileAccess.file_exists(path):
		return {"ok": false, "message": "%s already exists. Pick another name." % path}
	var template := load(TEMPLATE) as PackedScene
	if template == null:
		return {"ok": false, "message": "The template %s is missing." % TEMPLATE}
	var level := template.instantiate()
	level.name = base.to_pascal_case()
	level.scene_file_path = ""  # a level of its own, not a copy that follows the template
	_own_resources(level)
	var dialogue := "%s/%s.txt" % [dialogue_dir, base]
	for trigger in level.find_children("*", "Area3D", true, false):
		if "dialogue_file" in trigger:
			trigger.set("dialogue_file", dialogue)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	level.free()
	if err == OK:
		err = ResourceSaver.save(packed, path)
	if err != OK:
		return {"ok": false, "message": "Couldn't save %s (error %d)." % [path, err]}
	var made_dialogue := false
	if not FileAccess.file_exists(dialogue):
		var f := FileAccess.open(dialogue, FileAccess.WRITE)
		if f:
			f.store_string(DIALOGUE_HEADER % display_name.strip_edges().to_upper())
			f.close()
			made_dialogue = true
	var msg := "Made %s%s. Add it to the chapter list in scripts/ui/chapters.gd (the guide shows how), then bake its navigation once you've built the floor." % [
			path.get_file(), (" and " + dialogue.get_file()) if made_dialogue else ""]
	return {"ok": true, "path": path, "message": msg}


## The template's own sub-resources (zone shapes, fog, navigation mesh) are copied, so the new
## level never edits the template's. The insides of instanced scenes (the Player) are left alone.
static func _own_resources(node: Node, level: Node = null) -> void:
	if level == null:
		level = node
	for prop in ["shape", "environment", "navigation_mesh"]:
		if prop in node:
			var res: Variant = node.get(prop)
			if res is Resource and (res as Resource).resource_path.contains("::"):
				node.set(prop, (res as Resource).duplicate(true))
	for child in node.get_children():
		if child.owner == level:
			_own_resources(child, level)
