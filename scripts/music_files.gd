extends RefCounted
## Helpers for the Music autoload (scripts/music.gd): loading tracks so they always loop, sending
## other sound players to the SFX bus, and making sure the buses exist. Static functions only.

const DIR := "res://audio/music/"

static var _streams := {}  # track -> AudioStream (null for a missing one, so it warns once)


## Loads res://audio/music/<track>.wav (or .ogg / .mp3) once, and makes it loop whatever its
## import settings say. Returns null (with one warning) when there's no such file.
static func load_track(track: String) -> AudioStream:
	if _streams.has(track):
		return _streams[track]
	var stream: AudioStream = null
	for ext in [".wav", ".ogg", ".mp3"]:
		if ResourceLoader.exists(DIR + track + ext):
			stream = load(DIR + track + ext)
			break
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
