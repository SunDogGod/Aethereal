extends Node
## Sound effects (autoload: "Sfx"). Plays the WAVs in res://audio/ (synthesized by the
## scratchpad script make_sfx.gd) through a small pool of 3D players, with a little random
## pitch so repeated sounds don't machine-gun. Gameplay code reaches it through SfxBus, which
## this node signs up to in _ready, so scripts never name the autoload.
##   Sfx.play("parry_clang", position)            one-shot in the world
##   Sfx.play("ui_blip")                          one-shot with no position (menus)
##   Sfx.loop_at("neon_hum", position, -6.0)      an ambient loop; returns the player

const POOL_SIZE := 8
const AUDIO_DIR := "res://audio/"
const UNIT_SIZE := 8.0      ## metres at which a 3D sound is at full volume; it fades beyond
const MAX_DISTANCE := 40.0  ## metres beyond which a one-shot is silent
const BUS := "SFX"           ## every player here goes to this bus (Settings > Effects volume)

var _streams := {}  # name -> AudioStreamWAV (loaded once)
var _missing := {}  # names we already warned about
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _next := 0      # round-robin when every player is busy


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.name = "Voice%d" % i
		p.unit_size = UNIT_SIZE
		p.max_distance = MAX_DISTANCE
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.bus = BUS
		add_child(p)
		_pool_3d.append(p)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "Flat%d" % i
		p.bus = BUS
		p.process_mode = Node.PROCESS_MODE_ALWAYS  # menu sounds still play while the game is paused
		add_child(p)
		_pool_2d.append(p)
	SfxBus.player = self


## Plays a one-shot. `at` = Vector3.INF (the default) means "no position": a flat 2D sound.
func play(name: String, at: Vector3 = Vector3.INF, volume_db := 0.0, pitch_variance := 0.08) -> void:
	var stream := _stream(name)
	if stream == null:
		return
	var pitch := 1.0 + randf_range(-pitch_variance, pitch_variance)
	if at.is_finite():
		var p := _free_3d()
		p.stream = stream
		p.global_position = at
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.play()
	else:
		var p2 := _free_2d()
		p2.stream = stream
		p2.volume_db = volume_db
		p2.pitch_scale = pitch
		p2.play()


## An ambient loop at a point. Its own player (not from the pool), under `parent` if given
## (so it goes away with the level) or under this node. Loops even if the WAV wasn't imported
## as a loop: the stream is copied and set to loop forward over its whole length.
func loop_at(name: String, at: Vector3, volume_db := 0.0, parent: Node = null) -> AudioStreamPlayer3D:
	var stream := _stream(name)
	if stream == null:
		return null
	var looped: AudioStreamWAV = stream
	if stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		looped = stream.duplicate()
		looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looped.loop_begin = 0
		looped.loop_end = int(stream.get_length() * stream.mix_rate)
	var p := AudioStreamPlayer3D.new()
	p.name = "Loop_" + name
	p.bus = BUS
	p.stream = looped
	p.volume_db = volume_db
	p.unit_size = 3.0
	p.max_distance = 20.0
	p.autoplay = true
	var owner_node := parent if parent else self
	owner_node.add_child(p)
	if p.is_inside_tree():
		p.global_position = at
	else:
		p.position = at  # the parent is not in the tree yet: place it relative to the parent
	if p.is_inside_tree() and not p.playing:
		p.play()
	return p


func _stream(name: String) -> AudioStreamWAV:
	if _streams.has(name):
		return _streams[name]
	var path := AUDIO_DIR + name + ".wav"
	if not ResourceLoader.exists(path):
		if not _missing.has(name):
			_missing[name] = true
			push_warning("Sfx: no sound file " + path)
		return null
	var stream: AudioStreamWAV = load(path)
	_streams[name] = stream
	return stream


## A player that isn't busy; if all are, the next in line (the oldest sound is cut off).
func _free_3d() -> AudioStreamPlayer3D:
	for p in _pool_3d:
		if not p.playing:
			return p
	var p: AudioStreamPlayer3D = _pool_3d[_next % POOL_SIZE]
	_next += 1
	return p


func _free_2d() -> AudioStreamPlayer:
	for p in _pool_2d:
		if not p.playing:
			return p
	return _pool_2d[0]
