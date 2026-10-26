class_name SaveGame
extends RefCounted
## Remembers the furthest story level Aeneas has entered, in user://save.cfg, so the title screen
## can offer Continue. Story calls record_level() whenever it changes level, and the big world
## calls it when he walks on into a zone further along the story (Black Sand -> the station).
## Continue only moves forward: replaying an earlier chapter (from the Chapters page) keeps the
## furthest one. New Game asks first, then clear()s it.
## Recording starts once the title screen has been shown, so test scripts and levels run
## on their own (F6) never move your Continue point.

const PATH := "user://save.cfg"

static var recording := false  ## the title screen switches this on


static func record_level(path: String) -> void:
	if path == World.SCENE:
		path = World.current_level  # the world itself isn't a chapter: the zone he is in is
	if not recording or not Chapters.is_story_level(path):
		return  # menus and test spaces aren't progress
	if Chapters.index_of(path) <= Chapters.index_of(last_level()):
		return  # not further on than the saved chapter
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # keep anything else already in the file
	cfg.set_value("progress", "level", path)
	cfg.save(PATH)


## Forgets the Continue point (New Game, once the player said yes).
static func clear() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK or not cfg.has_section("progress"):
		return
	cfg.erase_section("progress")
	cfg.save(PATH)


## The level to continue from, or "" when there is no save (or its level is gone).
static func last_level() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return ""
	var path := str(cfg.get_value("progress", "level", ""))
	return path if Chapters.is_story_level(path) and ResourceLoader.exists(path) else ""
