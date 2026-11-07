class_name Chapters
extends RefCounted
## The list of levels, in story order. The title screen's Chapters page is built from it,
## and Continue only remembers levels that are on it. Add a level here when you build one:
## [number, name, scene]. An entry with no number is a test space (listed, never "continued").
## The town, Black Sand and the station are zones of one big world (scenes/world/world.tscn):
## their entries still name the level, and Story starts the world at that zone's Start marker.

const LIST := [
	["0.1", "The Empty Town", "res://scenes/levels/empty_town.tscn"],
	["0.2", "The Massacre (a memory)", "res://scenes/levels/massacre.tscn"],
	["0.3", "Black Sand", "res://scenes/levels/black_sand.tscn"],
	["0.4", "The Vacuum Station", "res://scenes/levels/vacuum_station.tscn"],
	["1.1", "Horus: the road to Temek", "res://scenes/levels/horus_road.tscn"],
	["1.2", "Temek: the city on the lake", "res://scenes/levels/temek.tscn"],
	["", "Test yard (movement)", "res://scenes/test_yard.tscn"],
]

const FIRST_LEVEL := "res://scenes/levels/empty_town.tscn"  ## where New Game starts


## The entry for a scene path, or [] when it isn't a listed level. In the big world it is the
## entry of the zone Aeneas is in.
static func find(path: String) -> Array:
	if path == World.SCENE:
		path = World.current_level
	for entry: Array in LIST:
		if entry[2] == path:
			return entry
	return []


## "0.3  Black Sand" for a level's path ("" for a scene that isn't listed).
static func label_of(path: String) -> String:
	var entry := find(path)
	if entry.is_empty():
		return ""
	return ("%s  %s" % [entry[0], entry[1]]) if entry[0] != "" else str(entry[1])


## True for story levels (the ones Continue remembers).
static func is_story_level(path: String) -> bool:
	var entry := find(path)
	return not entry.is_empty() and entry[0] != ""


## How far on in the story a level is (its line in LIST, from 0), or -1 if it isn't listed.
static func index_of(path: String) -> int:
	var entry := find(path)
	return -1 if entry.is_empty() else LIST.find(entry)
