class_name SaveGame
extends RefCounted
## Remembers the last story level Aeneas entered, in user://save.cfg, so the title screen
## can offer Continue. Story calls record_level() whenever it changes level.
## Recording starts once the title screen has been shown, so test scripts and levels run
## on their own (F6) never move your Continue point.

const PATH := "user://save.cfg"

static var recording := false  ## the title screen switches this on


static func record_level(path: String) -> void:
	if not recording or not Chapters.is_story_level(path):
		return  # menus and test spaces aren't progress
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # keep anything else already in the file
	cfg.set_value("progress", "level", path)
	cfg.save(PATH)


## The level to continue from, or "" when there is no save (or its level is gone).
static func last_level() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return ""
	var path := str(cfg.get_value("progress", "level", ""))
	return path if Chapters.is_story_level(path) and ResourceLoader.exists(path) else ""
