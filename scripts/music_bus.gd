class_name MusicBus
extends RefCounted
## The door gameplay code knocks on for music, like SfxBus for sounds. The Music autoload
## (scripts/music.gd) signs itself up here in its _ready; until then (headless tests, a scene
## run on its own) every call is a no-op. Gameplay scripts call MusicBus.fight(true), never
## the Music autoload by name (naming an autoload breaks the headless tests, see CLAUDE.md).

static var player: Node


## A fight started (true) or ended (false). Pass the Fight node as `source` so two fights
## can overlap; the fight track plays while any is on, and lingers a moment after the last.
static func fight(on: bool, source: Object = null) -> void:
	if player:
		player.fight(on, source)


## Plays res://audio/music/<track>.wav (or .ogg / .mp3) instead of the level's own bed,
## crossfading over `fade` seconds, until the level changes.
static func play(track: String, fade := 1.5) -> void:
	if player:
		player.play(track, fade)


## Silence instead of the level's bed, until the level changes or play() is called.
static func stop(fade := 1.5) -> void:
	if player:
		player.stop(fade)


## The track playing now ("" for silence or no Music autoload).
static func current() -> String:
	return player.current_track() if player else ""
