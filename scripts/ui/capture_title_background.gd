extends SceneTree
## Retakes the title screen's background (scenes/ui/title_town.png): the Empty Town seen down
## the bridge, with no characters and no HUD, from an off-screen 1280x720 camera.
## It is a tool, not part of the game. Run it from a terminal (with a window, not --headless):
##   Godot_v4.7.2-stable_win64_console.exe --path "<project folder>" -s res://scripts/ui/capture_title_background.gd
## Then run Godot once with --import (or open the editor) so the new picture is picked up.
## To try another angle, change FROM / LOOK_AT / FOV below. The darkening and the slow drift are
## not in the picture: they are the Background material's settings on the title screen.

const LEVEL := "res://scenes/levels/empty_town.tscn"
const OUT := "res://scenes/ui/title_town.png"
const FROM := Vector3(0.0, 25.4, 92.0)   ## the camera: on the bridge, near the ledge end
const LOOK_AT := Vector3(0.0, 32.0, 10.0)  ## towards the gate towers, a little upward
const FOV := 65.0


func _initialize() -> void:
	_run()


func _run() -> void:
	var level: Node = load(LEVEL).instantiate()
	root.add_child(level)
	current_scene = level
	for n in ["Player", "Isabella", "Figures"]:
		var node := level.get_node_or_null(n)
		if node is Node3D:
			node.visible = false
	var view := SubViewport.new()  # shares the level's world, so fog and lights match
	view.size = Vector2i(1280, 720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var cam := Camera3D.new()
	view.add_child(cam)
	cam.current = true
	cam.fov = FOV
	await process_frame
	cam.look_at_from_position(FROM, LOOK_AT, Vector3.UP)
	for i in 40:  # let flickers, steam and the wobble settle
		await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT))
	print("saved ", OUT)
	quit()
