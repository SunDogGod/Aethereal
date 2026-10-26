extends Node3D
## A story cue for the hall's fire and the cube, for dialogue scenes: [show CubeSurge] calls
## the aura's surge(), [show CubePulse] its pulse(), [show FireFlare] the bonfire's flare().
## Showing the cue runs the call once and hides the cue again (it draws nothing). A saved game
## that replays the [show] as the level loads does nothing (the first second is ignored).

## The node to call (the CubeAura or the Bonfire).
@export var target: NodePath
## The method to call on it.
@export var method := "pulse"

var _settled := false


func _ready() -> void:
	visible = false
	visibility_changed.connect(_on_visibility_changed)
	get_tree().create_timer(1.0, false).timeout.connect(func() -> void: _settled = true)


func _on_visibility_changed() -> void:
	if not visible:
		return
	set_deferred("visible", false)
	if not _settled:
		return
	var node := get_node_or_null(target)
	if node and node.has_method(method):
		node.call(method)
