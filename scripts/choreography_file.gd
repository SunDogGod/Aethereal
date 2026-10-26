class_name ChoreographyFile
extends RefCounted
## Reads a fight's choreography (data/fights/*.txt): the beats a guard plays, phase by phase.
## The format is explained at the top of data/fights/captain.txt.

const MOVES := ["approach", "step_in", "back", "circle", "guard", "feint", "swing", "combo",
		"heavy", "finish", "scene"]


## Returns { guard name: { phase number: {"beats": [beat, ...], "loop": index} } }.
## A section with no guard name ("=== phase 1 ===") is stored under "" (the Fight's boss).
## Each beat is {"move": String, "args": PackedStringArray, "line": int}.
static func parse(source: String) -> Dictionary:
	var result := {}
	var phase: Dictionary = {}
	var line_no := 0
	for raw in source.split("\n"):
		line_no += 1
		var line := raw.strip_edges()
		var note_at := line.find("#")
		if note_at >= 0:
			line = line.substr(0, note_at).strip_edges()  # a note after the beat
		if line.is_empty():
			continue
		if line.begins_with("===") and line.ends_with("==="):
			var words := line.trim_prefix("===").trim_suffix("===").strip_edges().split(" ", false)
			var phase_no := 1
			var who := ""
			if words.size() >= 2 and words[words.size() - 2].to_lower() == "phase":
				phase_no = words[words.size() - 1].to_int()
				who = " ".join(words.slice(0, words.size() - 2))
			else:
				who = " ".join(words)
			if not result.has(who):
				result[who] = {}
			phase = {"beats": [], "loop": 0}
			result[who][phase_no] = phase
			continue
		if phase.is_empty():
			push_warning("Choreography line %d: a beat before any === phase === heading" % line_no)
			continue
		var parts := line.split(" ", false)
		var move := parts[0].to_lower()
		if move == "loop":
			phase.loop = phase.beats.size()
			continue
		if not move in MOVES:
			push_warning("Choreography line %d: unknown beat '%s'" % [line_no, move])
			continue
		phase.beats.append({"move": move, "args": parts.slice(1), "line": line_no})
	return result


## A beat's number argument, or `fallback` if it has none there.
static func number(beat: Dictionary, index: int, fallback: float) -> float:
	var args: PackedStringArray = beat.args
	if index < args.size() and args[index].is_valid_float():
		return args[index].to_float()
	return fallback
