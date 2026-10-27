extends Node
## The developer menu's front door (autoload "DevTools"), for testing the game.
## In a debug run (the editor's F5 / F6, or an export made with "Export With Debug") it sets
## up the dev menu, the overlay, the cheats and Build Mode. In a release export it keeps only
## the edits applier (the author's in-game Build Mode edits, data/edits/*.json, must ship with
## the game until they are baked into the scenes) and never even loads the rest, so players
## can't open any of it.
##   F1, or hold the gamepad's Back / View button for a second: open or close the dev menu.
##   F2: Build Mode (change the level from inside the game; build_mode.gd).
## Nothing in the game calls this; the dev menu reaches into the game, never the other way.

const CHEATS := "res://scripts/dev/dev_cheats.gd"
const PLACES := "res://scripts/dev/dev_places.gd"
const OVERLAY := "res://scripts/dev/dev_overlay.gd"
const BUILD := "res://scripts/dev/build_mode.gd"
const MENU := "res://scenes/dev/dev_menu.tscn"
const EDITS := preload("res://scripts/dev/edits_applier.gd")

var edits: Node          ## puts in-game edits back as scenes load, in every build (edits_applier.gd)
var cheats: Node         ## god mode, noclip, blind guards, time scale, skip (dev_cheats.gd)
var places: Node         ## teleports, checkpoint, restarts, reloads, chapters (dev_places.gd)
var overlay: CanvasLayer ## FPS, position, checkpoint and guard states (dev_overlay.gd)
var build: Node          ## Build Mode: select, move, delete, add things in game (build_mode.gd)
var menu: CanvasLayer    ## the menu itself (scenes/dev/dev_menu.tscn)


func _ready() -> void:
	edits = _add(EDITS.new(), "Edits")
	if not OS.is_debug_build():
		return  # a release build: the edits applier only, no dev menu, ever
	# load(), not preload(): a release build never touches these files.
	cheats = _add(load(CHEATS).new(), "Cheats")
	places = _add(load(PLACES).new(), "Places")
	cheats.places = places
	places.cheats = cheats
	overlay = _add(load(OVERLAY).new(), "Overlay")
	overlay.cheats = cheats
	overlay.places = places
	build = load(BUILD).new()
	build.cheats = cheats
	build.applier = edits
	menu = load(MENU).instantiate()
	menu.cheats = cheats
	menu.places = places
	menu.overlay = overlay
	menu.build = build
	_add(menu, "Menu")
	_add(build, "Build")  # after the menu: it hears F1 first while it is open


func _add(node: Node, node_name: String) -> Node:
	node.name = node_name
	add_child(node)
	return node
