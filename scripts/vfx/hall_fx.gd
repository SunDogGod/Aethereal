extends Node3D
## One-off effects the hall's scenes call by name ([call HallFx burst Player]):
##   burst(who)   Aeneas's aether bursts out of him (hall_burst.gd), then crackles round him while
##                the eruption lasts (hall_crackle.gd). Whatever the cube gave him stops glowing.
##   spray(who)   the beheading, kept restrained: a short spray of dark against the firelight at
##                his neck, no more. (Kael's cut is the pose; the captain drops with [kill].)
##   topple(who)  a kneeling body falls forward, face down, from his knees (the beheaded captain).
##   clear_text() takes the last line off the screen, so a wordless beat plays on a clean frame
##                (a scene otherwise keeps its last line up until the next one).

const HallBurst := preload("res://scripts/vfx/hall_burst.gd")
const HallGlow := preload("res://scripts/vfx/hall_glow.gd")


func burst(who: Node3D, strength := 1.0) -> void:
	HallGlow.off(who)
	HallBurst.burst(who, strength)


## A kneeling body pitches forward onto the floor from where it kneels (a death animation would
## first stand him back up). Story pose and all: only his Model tips, about his knees.
func topple(who: Node3D, seconds := 0.8) -> void:
	var model: Node3D = who.get("model") if who.get("model") is Node3D else who.get_node_or_null("Model")
	if model == null:
		return
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", -1.4, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(model, "rotation:x", -1.32, 0.15).set_trans(Tween.TRANS_SINE)  # the small bounce of landing


func clear_text() -> void:
	var box := get_tree().root.find_child("DialogueBox", true, false)
	if box is DialogueBox:
		box.close()


func spray(who: Node3D) -> void:
	if who == null or not who.is_inside_tree():
		return
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.85
	p.randomness = 0.4
	p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.06
	m.direction = Vector3(0, 1, 0)
	m.spread = 55.0
	m.initial_velocity_min = 2.5
	m.initial_velocity_max = 5.5
	m.gravity = Vector3(0, -9.0, 0)
	m.scale_min = 0.6
	m.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.16, 0.02, 0.02, 1))
	ramp.set_color(1, Color(0.05, 0.0, 0.0, 0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	m.color_ramp = tex
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(0.11, 0.11)
	var mat := StandardMaterial3D.new()  # a particle draw pass (the PS1 shader can't place particles)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	p.draw_pass_1 = quad
	add_child(p)
	p.global_position = who.global_position + Vector3(0, 1.1, 0)
	p.emitting = true
	get_tree().create_timer(2.0, false).timeout.connect(p.queue_free)
