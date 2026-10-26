extends RefCounted
## Helpers for the Music autoload (scripts/music.gd): loading tracks so they always loop, sending
## other sound players to the SFX bus, and making sure the buses exist. Static functions only.

const DIR := "res://audio/music/"

static var _streams := {}  # track -> AudioStream (null for a missing one, so it warns once)
static var _fetching := {}  # track -> file being loaded on a background thread (fetch)


## The file of a track: res://audio/music/<track>.wav (or .ogg / .mp3), "" if there is none.
static func path_of(track: String) -> String:
	for ext in [".wav", ".ogg", ".mp3"]:
		if ResourceLoader.exists(DIR + track + ext):
			return DIR + track + ext
	return ""


## Starts loading tracks on a background thread (the loading screen asks for the next scene's),
## so playing one later doesn't stop the game while its file loads.
static func fetch(tracks: Array) -> void:
	for track: String in tracks:
		var path := path_of(track)
		if _streams.has(track) or _fetching.has(track) or path == "":
			continue
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(path)
			_fetching[track] = path


## The tracks a scene can play: its bed (each zone's in the big world), the hall's, the fight
## and the sneaking layer. Read from the lists at the top of music.gd.
static func tracks_for(scene_path: String) -> Array:
	var lists := (load("res://scripts/music.gd") as Script).get_script_constant_map()
	var scenes: Array = World.LEVELS if scene_path == World.SCENE else [scene_path]
	var out := []
	for s: String in scenes:
		if lists.SCENE_BEDS.has(s):
			out.append(lists.SCENE_BEDS[s])
		for zone: Array in lists.ZONES:
			if zone[0] == s:
				out.append(zone[1])
	if not out.is_empty() and not scene_path.begins_with("res://scenes/ui/"):
		out.append_array([lists.FIGHT_TRACK, lists.TENSION_TRACK])
	return out


## Loads res://audio/music/<track>.wav (or .ogg / .mp3) once, and makes it loop whatever its
## import settings say. Returns null (with one warning) when there's no such file.
static func load_track(track: String) -> AudioStream:
	if _streams.has(track):
		return _streams[track]
	var stream: AudioStream = null
	if _fetching.has(track):
		stream = ResourceLoader.load_threaded_get(_fetching[track])  # ready, or waits for the rest
		_fetching.erase(track)
	var path := path_of(track)
	if stream == null and path != "":
		stream = load(path)
	if stream == null:
		push_warning("Music: no track " + DIR + track + ".wav")
	elif stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	elif "loop" in stream:
		stream.loop = true  # Ogg Vorbis and MP3
	_streams[track] = stream
	return stream


## A sound player still on the Master bus goes to `bus` instead (level hums, the tap, menu blips).
static func route(node: Node, bus: StringName) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D:
		if node.bus == &"Master":
			node.bus = bus


static func route_tree(node: Node, bus: StringName) -> void:
	route(node, bus)
	for child in node.get_children():
		route_tree(child, bus)


## The buses normally come from res://default_bus_layout.tres; this adds one if it's missing.
static func ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, &"Master")


## Lets go of every loaded track (the Music autoload calls this as the game closes, so nothing is
## left holding them at exit).
static func forget() -> void:
	for track: String in _fetching:
		ResourceLoader.load_threaded_get(_fetching[track])  # picks up tracks fetched but never played
	_fetching.clear()
	_streams.clear()
