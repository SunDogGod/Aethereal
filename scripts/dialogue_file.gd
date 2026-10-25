class_name DialogueFile
extends RefCounted
## Reads a dialogue text file (data/dialogue/*.txt) into scenes of steps.
## The format is explained at the top of each dialogue file.


## Returns { scene name: [steps] }. Each step is a Dictionary with a "type":
## "line" (speaker, text), "camera" (name; "" = back to the player), "wait" (seconds),
## "hide" / "show" (name).
static func parse(source: String) -> Dictionary:
	var scenes := {}
	var steps: Array = []
	var speaker_line := RegEx.create_from_string("^([A-Z][A-Z .'-]*):\\s*(.+)$")
	var command := RegEx.create_from_string("^\\[(\\w+)\\s*(.*)\\]$")
	for raw in source.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("===") and line.ends_with("==="):
			steps = []
			scenes[line.trim_prefix("===").trim_suffix("===").strip_edges()] = steps
			continue
		var cmd := command.search(line)
		if cmd:
			var word := cmd.get_string(1).to_lower()
			var arg := cmd.get_string(2).strip_edges()
			match word:
				"camera":
					steps.append({"type": "camera", "name": arg})
				"wait":
					steps.append({"type": "wait", "seconds": arg.to_float()})
				"hide", "show":
					steps.append({"type": word, "name": arg})
				"fade":
					steps.append({"type": "fade", "how": arg.to_lower()})  # out, in, white
				"level":
					steps.append({"type": "level", "path": arg})
				"title":
					steps.append({"type": "title", "text": arg})
				"teleport":
					steps.append({"type": "teleport", "name": arg})  # a Marker3D in the level
				"fight":
					steps.append({"type": "fight", "name": arg})     # a Fight node: its guards attack
				"erupt":
					steps.append({"type": "erupt", "on": arg.to_lower() == "on"})  # Aeneas's gravity power
				"empower":
					steps.append({"type": "empower", "name": arg})   # a Guard becomes unbeatable
				"kill":
					steps.append({"type": "kill", "name": arg})      # a Guard drops (sacrificed), no blood
				"heal":
					steps.append({"type": "heal"})
				_:
					push_warning("Dialogue: unknown command [%s]" % word)
			continue
		var spoken := speaker_line.search(line)
		if spoken:
			steps.append({"type": "line", "speaker": spoken.get_string(1).capitalize(), "text": spoken.get_string(2)})
		else:
			steps.append({"type": "line", "speaker": "", "text": line})  # narration
	return scenes
