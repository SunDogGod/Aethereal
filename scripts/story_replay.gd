class_name StoryReplay
extends RefCounted
## Continue's fast-forward: replays a finished story scene without playing it. Only the commands
## that change the level for good run: [hide] [show] [collapse] [kill] [empower] [erupt], and the
## stage directions' end states ([place] [stand] [move] [face] [pose] [ink], story_stage.gd).
## Lines, cameras, waits, fades, titles, teleports, [heal], [call] and [level] are skipped, and a
## [fight] is handed back (unless already won) so Continue can start it once the screen is up.
## If you add a dialogue command that changes the level, handle it here too, or Continue
## will forget it.

const SKIPPED := ["line", "camera", "wait", "fade", "title", "frame", "teleport", "heal", "level", "call"]
const STAGE := ["place", "stand", "move", "face", "pose", "ink"]


## Replays one scene of a dialogue file. Returns the fights its [fight] lines start that are not in
## `won`. Names are looked up the way Story does: in the scene's own level first, then anywhere.
static func run(root: Node, path: String, scene: String, won: Array) -> Array:
	var fights := []
	var steps: Array = DialogueFile.parse(FileAccess.get_file_as_string(path)).get(scene, [])
	var player := root.get_tree().get_first_node_in_group("player") as Player
	for step: Dictionary in steps:
		if step.type in SKIPPED:
			continue
		if step.type in STAGE:
			StoryStage.replay(step, func(n: String) -> Node: return _find(root, path, n), player)
			continue
		var node := _find(root, path, str(step.get("name", ""))) if step.has("name") else null
		match step.type:
			"hide", "show":
				if node is Node3D:
					node.visible = step.type == "show"
			"collapse":
				if node:
					for n in [node] + node.find_children("*", "", true, false):
						if n.has_method("die") and not n is Guard:
							n.call("die", true)  # straight into the last pose, under the black screen
							break
			"kill":
				if node is Guard:
					node.sacrifice()
					if node.animator:
						node.animator.die(true)
			"empower":
				if node is Guard:
					node.empower()
			"erupt":
				if player:
					player.get_node("Combat").set_erupting(step.on)
			"fight":
				if node and node.has_method("start") and not node in won and not node in fights:
					fights.append(node)
	return fights


static func _find(root: Node, path: String, node_name: String) -> Node:
	if node_name == "":
		return null
	var level: Node = root.level_for_dialogue(path) if root.has_method("level_for_dialogue") else root
	var found := level.find_child(node_name, true, false)
	if found == null and level != root:
		found = root.find_child(node_name, true, false)
	return found
