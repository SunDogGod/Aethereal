extends Node
## Music and ambience (autoload "Music"). One looping track at a time, crossfading when it
## changes, plus the sneaking "tension" layer on top. What plays, strongest first:
##   1. a fight: fight.gd calls MusicBus.fight(true / false)
##   2. a story cue: [music name] / [music off] in a dialogue file call play() / stop()
##   3. a zone inside a level (ZONES: the Empty Town's hall plays "hall")
##   4. the scene's own bed (SCENE_BEDS). In the big world (scenes/world/world.tscn) that is the
##      bed of the level Aeneas is walking in, crossfading as he walks from one into the next.
## Tracks are res://audio/music/<name>.wav (synthesized by the scratchpad script make_music.py);
## drop in a .ogg or .mp3 of the same name to replace one. It keeps running while the game is
## paused, a little quieter and muffled. It also sends every other sound player still on the
## Master bus (level hums, the tap, Sfx) to the "SFX" bus, so Settings > Effects volume reaches them.
## Gameplay scripts reach it through MusicBus, never by its autoload name.

const Files := preload("res://scripts/music_files.gd")  ## loading tracks, routing, buses
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

## How loud each track sits in the mix, in dB. Set from measurements: a running step stays
## 6 dB or more above a bed's loud moments, a crouched one just above its average (see the
## scratchpad's mix_report.py). Judge them by ear and change them here.
const TRACK_DB := {
	"title": -6.0, "empty_town": -13.0, "massacre": -7.0, "black_sand": -10.0,
	"vacuum_station": -14.0, "tension": -16.0, "fight": -8.0, "hall": -12.0,
}
## The bed each scene plays. A scene that isn't listed is silent.
const SCENE_BEDS := {
	"res://scenes/ui/title_screen.tscn": "title",
	"res://scenes/location_menu.tscn": "title",
	"res://scenes/levels/empty_town.tscn": "empty_town",
	"res://scenes/levels/massacre.tscn": "massacre",
	"res://scenes/levels/black_sand.tscn": "black_sand",
	"res://scenes/levels/vacuum_station.tscn": "vacuum_station",
}
## Places inside a level with their own bed: [scene, track, box]. Aeneas's position decides.
const ZONES := [
	["res://scenes/levels/empty_town.tscn", "hall", AABB(Vector3(-10.5, -1.0, -28.5), Vector3(21.0, 12.0, 18.0))],
]
const FIGHT_TRACK := "fight"
const TENSION_TRACK := "tension"
const FADE_SCENE := 2.5      ## crossfade when the level changes
const FADE_ZONE := 4.0       ## walking into or out of a zone
const FADE_FIGHT_IN := 0.8
const FADE_FIGHT_OUT := 4.0
const FIGHT_LINGER := 3.0    ## seconds the fight track holds after a fight ends (a death restart keeps it going)
const PAUSE_DUCK_DB := -8.0  ## quieter while the pause menu is up
const TENSION_NEAR := 20.0   ## metres: a guard closer than this raises the tension layer
const TENSION_RISE := 0.5    ## tension fade-in per second (0..1)
const TENSION_FALL := 0.12   ## and fade-out: slow, so it ebbs away
const GUARD_DOWN := 3        ## Guard.State.DOWN (a number, so this file never depends on guard.gd)


## One playing track: its player and where its fade is (0 = silent, 1 = full).
class Voice:
	var player: AudioStreamPlayer
	var track := ""
	var level := 0.0
	var target := 0.0
	var rate := 1.0


var _voices: Array[Voice] = []   # the main line (one fading in, others fading out)
var _tension: Voice               # the sneaking layer (null when silent)
var _current := ""                # the main track we want now ("" = silence)
var _resume := {}                 # bed -> playback position, so a bed comes back where it left off
var _override := ""               # story cue; "-" = [music off]
var _override_scene: Node         # the cue lasts while this scene is current
var _override_fade := 1.5
var _fights := {}                 # instance id of each running Fight -> true
var _fight_ended_at := -100.0
var _scene: Node
var _in_zone := ""
var _duck_db := 0.0
var _tick := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps playing (ducked) under the pause menu
	Files.ensure_bus(MUSIC_BUS)
	Files.ensure_bus(SFX_BUS)
	GameSettings.apply_volumes()
	get_tree().node_added.connect(_route)
	Files.route_tree(get_tree().root, SFX_BUS)
	MusicBus.player = self


## Story cue: play a track (file name without extension) instead of the level's bed.
func play(track_name: String, fade := 1.5) -> void:
	if Files.load_track(track_name) == null:
		return
	_override = track_name
	_override_scene = get_tree().current_scene
	_override_fade = fade
	_update(fade)


## Story cue: silence until the level changes or play() is called.
func stop(fade := 1.5) -> void:
	_override = "-"
	_override_scene = get_tree().current_scene
	_override_fade = fade
	_update(fade)


func fight(on: bool, source: Object = null) -> void:
	var id := source.get_instance_id() if source else 0
	if on:
		_fights[id] = true
	elif _fights.has(id):
		_fights.erase(id)
		if _fights.is_empty():
			_fight_ended_at = _now()
	_update(FADE_FIGHT_IN if on else FADE_FIGHT_OUT)


func current_track() -> String:
	return _current


func tension_level() -> float:
	return _tension.level if _tension else 0.0


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _scene:
		_scene = scene
		_resume.clear()
		_in_zone = ""
		_update(FADE_SCENE)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.2
		_update(FADE_ZONE)
		_update_tension()
	var paused := get_tree().paused
	_duck_db = move_toward(_duck_db, PAUSE_DUCK_DB if paused else 0.0, 30.0 * delta)
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if bus >= 0 and AudioServer.get_bus_effect_count(bus) > 0 and AudioServer.get_bus_effect(bus, 0) is AudioEffectLowPassFilter:
		AudioServer.set_bus_effect_enabled(bus, 0, paused)
	for v: Voice in _voices.duplicate():
		_fade(v, delta)
		if v.level <= 0.0 and v.target <= 0.0:
			if v.track != FIGHT_TRACK:
				_resume[v.track] = v.player.get_playback_position()
			v.player.queue_free()
			_voices.erase(v)
	if _tension:
		_fade(_tension, delta)
		if _tension.level <= 0.0 and _tension.target <= 0.0:
			_tension.player.queue_free()
			_tension = null


## Works out which track should play and crossfades to it if that changed.
func _update(fade: float) -> void:
	var want := _wanted()
	if want == _current:
		return
	if want == FIGHT_TRACK or _current == FIGHT_TRACK:
		fade = FADE_FIGHT_IN if want == FIGHT_TRACK else FADE_FIGHT_OUT
	elif _override_active():
		fade = _override_fade
	_current = want
	for v: Voice in _voices:
		if v.track != want:
			v.target = 0.0
			v.rate = 1.0 / maxf(fade, 0.05)
	if want == "":
		return
	var voice: Voice = null
	for v: Voice in _voices:
		if v.track == want:
			voice = v
	if voice == null:
		voice = _start(want, 0.0 if want == FIGHT_TRACK else float(_resume.get(want, 0.0)))
		if voice == null:
			return
		_voices.append(voice)
	voice.target = 1.0
	voice.rate = 1.0 / maxf(fade, 0.05)


func _wanted() -> String:
	if _fight_active():
		return FIGHT_TRACK
	if _override_active():
		return "" if _override == "-" else _override
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	var path := scene.scene_file_path
	var level := scene as Node3D
	if scene.has_method("level_here"):  # the big world: the zone Aeneas is in picks the bed
		level = scene.level_here()
		path = level.scene_file_path if level else ""
	var zone := _zone(path, level)
	if zone != "":
		return zone
	return str(SCENE_BEDS.get(path, ""))


func _override_active() -> bool:
	return _override != "" and is_instance_valid(_override_scene) and _override_scene == get_tree().current_scene


func _fight_active() -> bool:
	for id: int in _fights.keys():
		if id != 0 and not is_instance_id_valid(id):
			_fights.erase(id)  # its level was unloaded
	return not _fights.is_empty() or _now() - _fight_ended_at < FIGHT_LINGER


## The zone track Aeneas stands in ("" for none). Leaving needs a step past the box's edge,
## so standing in the doorway doesn't flip back and forth. The boxes are in the level's own
## coordinates (in the big world a level can sit anywhere).
func _zone(path: String, level: Node3D) -> String:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return ""
	var at := player.global_position
	if level and level.is_inside_tree():
		at = level.to_local(at)
	for z: Array in ZONES:
		if z[0] != path:
			continue
		var box: AABB = z[2]
		if _in_zone == z[1]:
			box = box.grow(1.0)
		if box.has_point(at):
			_in_zone = z[1]
			return _in_zone
	_in_zone = ""
	return ""


## The tension layer follows the nearest danger: a guard close by (closer, and crouched,
## means more) or one who has started to notice Aeneas (his "?" filling).
func _update_tension() -> void:
	var target := 0.0
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var level_bed := _current != "" and _current != FIGHT_TRACK and not _override_active()
	if player and level_bed and player.get("in_cutscene") != true:
		var crouched: bool = player.get("is_crouched") == true
		for g: Node in get_tree().get_nodes_in_group("guards"):
			var guard := g as Node3D
			if guard == null or guard.get("dormant") == true or guard.get("state") == GUARD_DOWN or not guard.is_visible_in_tree():
				continue
			var d := guard.global_position.distance_to(player.global_position)
			var near := (0.55 if crouched else 0.4) * clampf(1.2 - d / TENSION_NEAR, 0.0, 1.0)
			var seen: Variant = guard.get("suspicion")
			var noticed: float = seen if seen is float else 0.0
			var alert := 0.6 + 0.4 * noticed if noticed > 0.01 else 0.0
			target = maxf(target, maxf(near, alert))
	if target > 0.0 and _tension == null:
		_tension = _start(TENSION_TRACK, 0.0)
	if _tension:
		_tension.target = target
		_tension.rate = TENSION_RISE if target > _tension.level else TENSION_FALL


func _fade(v: Voice, delta: float) -> void:
	v.level = move_toward(v.level, v.target, v.rate * delta)
	var gain := sin(v.level * PI * 0.5)  # equal-power crossfade
	v.player.volume_db = float(TRACK_DB.get(v.track, 0.0)) + linear_to_db(maxf(gain, 0.0001)) + _duck_db


func _start(track: String, from: float) -> Voice:
	var stream := Files.load_track(track)
	if stream == null:
		return null
	var v := Voice.new()
	v.track = track
	v.player = AudioStreamPlayer.new()
	v.player.name = "Track_" + track
	v.player.stream = stream
	v.player.bus = MUSIC_BUS
	v.player.volume_db = -80.0
	add_child(v.player)
	v.player.play(fmod(from, maxf(stream.get_length(), 0.01)))
	return v


## The game is closing: stop and let go of the tracks, so nothing still holds them at exit.
func _exit_tree() -> void:
	for p in find_children("*", "AudioStreamPlayer", false, false):
		(p as AudioStreamPlayer).stop()
		(p as AudioStreamPlayer).stream = null
	_voices.clear()
	_tension = null
	Files.forget()


func _route(node: Node) -> void:
	Files.route(node, SFX_BUS)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
