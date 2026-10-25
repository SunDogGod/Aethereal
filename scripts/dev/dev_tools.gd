extends Node
## The developer menu's front door (autoload "DevTools"), for testing the game.
## In a debug run (the editor's F5 / F6, or an export made with "Export With Debug") it sets
## up the dev menu, the overlay and the cheats. In a release export it removes itself at once
## and never even loads them, so players can't open it.
##   F1, or hold the gamepad's Back / View button for a second: open or close the dev menu.
## Nothing in the game calls this; the dev menu reaches into the game, never the other way.

const CHEATS := "res://scripts/dev/dev_cheats.gd"
const PLACES := "res://scripts/dev/dev_places.gd"
const OVERLAY := "res://scripts/dev/dev_overlay.gd"
const MENU := "res://scenes/dev/dev_menu.tscn"

var cheats: Node         ## god mode, noclip, blind guards, time scale, skip (dev_cheats.gd)
var places: Node         ## teleports, checkpoint, restarts, reloads, chapters (dev_places.gd)
var overlay: CanvasLayer ## FPS, position, checkpoint and guard states (dev_overlay.gd)
var menu: CanvasLayer    ## the menu itself (scenes/dev/dev_menu.tscn)


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()  # a release build: no dev menu, ever
		return
	# load(), not preload(): a release build never touches these files.
	cheats = _add(load(CHEATS).new(), "Cheats")
	places = _add(load(PLACES).new(), "Places")
	cheats.places = places
	places.cheats = cheats
	overlay = _add(load(OVERLAY).new(), "Overlay")
	overlay.cheats = cheats
	overlay.places = places
	menu = load(MENU).instantiate()
	menu.cheats = cheats
	menu.places = places
	menu.overlay = overlay
	_add(menu, "Menu")


func _add(node: Node, node_name: String) -> Node:
	node.name = node_name
	add_child(node)
	return node
