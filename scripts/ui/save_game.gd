class_name SaveGame
extends RefCounted
## The save file: one slot, written by the game itself (never by a menu), read by Continue.
## The game saves on its own (scripts/autosave.gd): at a checkpoint, at the end of a story scene
## and when Aeneas walks into the next zone, plus a "fresh" save each time a level starts. What a
## save holds is built by save_state.gd; Continue puts it back with save_restore.gd.
## The file is user://savegame.json (plain JSON you can open in a text editor). Each write goes to
## savegame.tmp.json first and is then renamed over the old file, so a crash mid-write can never
## leave a half-written save; the previous save is kept as savegame.bak.json. A broken or
## truncated file falls back to the .bak; a file from a newer version of the game is left alone
## (renamed savegame.v<N>.json before anything overwrites it). The old save.cfg (before saving
## existed) is read as a start-of-level save until the first new save, then kept as save.cfg.old.
## Recording starts once the title screen has been shown, so tests and levels run on their own
## (F6) never touch your save.

const VERSION := 1
const FILE := "savegame.json"
const BAK := "savegame.bak.json"
const TMP := "savegame.tmp.json"
const CORRUPT := "savegame.corrupt.json"
const OLD_CFG := "save.cfg"  ## before 2026-10-26: only [progress] level

static var folder := "user://"  ## where the files live (test scripts point this at a scratch folder)
static var recording := false   ## the title screen switches this on
static var pending := {}        ## Continue puts the save here; Story restores it as the level loads

static var _main_bad := false   # the main file was unreadable: the next write keeps it aside, not over the .bak
static var _main_newer := 0     # the main file came from a newer version (its number), or 0


## True when there is a save Continue can use.
static func exists() -> bool:
	return not load_save().is_empty()


## The save to continue from, checked and cleaned, or {} when there is none.
static func load_save() -> Dictionary:
	_main_bad = false
	_main_newer = 0
	var main := _read(FILE)
	if _main_newer > 0:
		return {}  # a newer game wrote it: don't guess at its contents
	if not main.is_empty():
		return main
	_main_bad = FileAccess.file_exists(_path(FILE))
	for spare: String in [BAK, TMP]:
		var data := _read(spare)
		if not data.is_empty():
			return data
	return _read_old()


## The level Continue would start in, or "" (menus and tests read this).
static func last_level() -> String:
	return str(load_save().get("level", ""))


## "0.3  Black Sand": what Continue and the menus show for a save.
static func describe(data: Dictionary) -> String:
	return Chapters.label_of(str(data.get("level", "")))


## A save at the very start of a level (New Game, a chapter, a [level] line). Continue then
## starts that level the normal way, opening scene and all.
static func start_level(path: String) -> void:
	if path == World.SCENE:
		path = World.current_level  # the world itself isn't a chapter: the zone he is in is
	if not recording or not Chapters.is_story_level(path):
		return  # menus and test spaces aren't progress
	write({"version": VERSION, "saved_unix": int(Time.get_unix_time_from_system()), "reason": "level",
			"level": path, "scene": World.SCENE if World.has_level(path) else path, "stage": 0, "fresh": true})


## Writes a save safely (see the top of this file). False if the disk refused.
static func write(data: Dictionary) -> bool:
	if not DirAccess.dir_exists_absolute(_path("")):
		DirAccess.make_dir_recursive_absolute(_path(""))
	var file := FileAccess.open(_path(TMP), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok:
		return false
	if FileAccess.file_exists(_path(FILE)):
		load_save()  # is the file we are about to replace good, broken, or from a newer game?
		var keep := BAK
		if _main_newer > 0:
			keep = "savegame.v%d.json" % _main_newer
		elif _main_bad:
			keep = CORRUPT
		DirAccess.remove_absolute(_path(keep))
		if DirAccess.rename_absolute(_path(FILE), _path(keep)) != OK:
			return false
	if DirAccess.rename_absolute(_path(TMP), _path(FILE)) != OK:
		return false
	_main_bad = false
	_main_newer = 0
	if FileAccess.file_exists(_path(OLD_CFG)):  # the old save is replaced now: keep it, but stop reading it
		DirAccess.remove_absolute(_path(OLD_CFG + ".old"))
		DirAccess.rename_absolute(_path(OLD_CFG), _path(OLD_CFG + ".old"))
	return true


static func _path(file_name: String) -> String:
	return ProjectSettings.globalize_path(folder.path_join(file_name))


## One file, parsed and checked, or {} (missing, broken, or not a save).
static func _read(file_name: String) -> Dictionary:
	if not FileAccess.file_exists(_path(file_name)):
		return {}
	var json := JSON.new()  # not JSON.parse_string: that prints an error for a broken file
	if json.parse(FileAccess.get_file_as_string(_path(file_name))) != OK or not json.data is Dictionary:
		return {}
	var data: Dictionary = json.data
	var version := int(_num(data.get("version"), 0.0))
	if version > VERSION:
		if file_name == FILE:
			_main_newer = version
		return {}
	if version < 1:
		return {}
	return _clean(data)


## The old save.cfg: just a level, so it continues as that level's start.
static func _read_old() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(_path(OLD_CFG)) != OK:
		return {}
	return _clean({"version": 1, "reason": "level", "fresh": true,
			"level": str(cfg.get_value("progress", "level", ""))})


## Keeps only what makes sense: a story level that still exists, finite positions, lists of
## strings. A bad optional entry is dropped on its own; a bad spot makes it a start-of-level save.
## JSON gives every number back as a float, so numbers are cast here.
static func _clean(raw: Dictionary) -> Dictionary:
	var level := str(raw.get("level", ""))
	if not Chapters.is_story_level(level) or not ResourceLoader.exists(level):
		return {}
	var out := {"version": VERSION, "level": level, "scene": World.SCENE if World.has_level(level) else level,
			"reason": str(raw.get("reason", "")), "saved_unix": int(_num(raw.get("saved_unix"), 0.0)),
			"stage": int(_num(raw.get("stage"), 0.0)), "fresh": raw.get("fresh", false) == true}
	var spot: Variant = raw.get("spot")
	if not out.fresh and spot is Dictionary and _vec_ok(spot.get("pos")):
		out.spot = {"pos": spot.pos, "yaw": _num(spot.get("yaw"), 0.0), "cam_yaw": _num(spot.get("cam_yaw"), 0.0)}
	else:
		out.fresh = true
		return out  # nothing else matters for a start-of-level save
	var restart: Variant = raw.get("restart")
	if restart is Dictionary and _vec_ok(restart.get("pos")):
		out.restart = {"pos": restart.pos}
	out.story = {}
	var story: Variant = raw.get("story")
	if story is Dictionary:
		for path: Variant in story:
			if path is String and story[path] is Array:
				out.story[path] = _strings(story[path])
	for list: String in ["checkpoints", "fights_won", "looked"]:
		out[list] = _strings(raw.get(list), true)
	out.guards_down = []
	var guards: Variant = raw.get("guards_down")
	if guards is Array:
		for g: Variant in guards:
			if g is Dictionary and g.get("key") is String and str(g.key).contains("::") and _vec_ok(g.get("pos")):
				out.guards_down.append({"key": g.key, "pos": g.pos, "yaw": _num(g.get("yaw"), 0.0),
						"killed": g.get("killed", false) == true})
	out.flashlight = raw.get("flashlight", false) == true
	var progress: Variant = raw.get("progress")  # older saves have none: no Aether, no skills
	if progress is Dictionary:
		out.progress = {"aether": maxi(0, int(_num(progress.get("aether"), 0.0))),
				"owned": _strings(progress.get("owned")), "tree_open": progress.get("tree_open", false) == true}
	return out


static func _num(v: Variant, fallback: float) -> float:
	return float(v) if (v is float or v is int) and is_finite(float(v)) else fallback


static func _vec_ok(v: Variant) -> bool:
	if not v is Array or v.size() != 3:
		return false
	for n: Variant in v:
		if not (n is float or n is int) or not is_finite(float(n)):
			return false
	return true


static func _strings(v: Variant, keys := false) -> Array:
	var out := []
	if v is Array:
		for s: Variant in v:
			if s is String and (not keys or s.contains("::")):
				out.append(s)
	return out
