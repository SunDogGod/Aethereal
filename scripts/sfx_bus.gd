class_name SfxBus
extends RefCounted
## The door gameplay code knocks on to make a sound. The Sfx autoload signs itself up here
## in its _ready; until then (headless tests, a scene run on its own) every call is a no-op.
## Gameplay scripts call SfxBus.play(...), never the Sfx autoload by name: naming an autoload
## in a gameplay script breaks the headless test scripts that preload it (see CLAUDE.md).

static var player: Node


## Plays res://audio/<name>.wav once, at a point in the world (or flat, with no position).
static func play(name: String, at: Vector3 = Vector3.INF, volume_db := 0.0, pitch_variance := 0.08) -> void:
	if player:
		player.play(name, at, volume_db, pitch_variance)


## Starts an ambient loop at a point. Returns the player so the caller can stop or move it,
## or null when no Sfx autoload is running. `parent` (a level node) owns it; default: Sfx.
static func loop_at(name: String, at: Vector3, volume_db := 0.0, parent: Node = null) -> AudioStreamPlayer3D:
	if player == null:
		return null
	return player.loop_at(name, at, volume_db, parent)
