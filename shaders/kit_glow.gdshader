// A ball of light, drawn as a small low-poly sphere added onto the scene: bright in the middle,
// soft at the rim (the rim faces away from the camera). Each instance of a MultiMesh carries its
// own fade in its custom data's alpha (0 = invisible, 1 = full), so a ball can swell in and die
// away without a material of its own. Used by scripts/props_kit/drift_lights.gd for the
// wandering lights and by light_shaft.gd for its dust motes (materials/kit_glow.tres).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

global uniform vec2 ps1_snap_resolution;

instance uniform vec3 tint : source_color = vec3(0.8, 0.75, 1.0);
instance uniform float strength = 1.0;
uniform float near_fade = 1.0;   // metres: a ball right at the camera fades out

varying float fade;
varying vec3 world_pos;

void vertex() {
	fade = INSTANCE_CUSTOM.a;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = ps1_snap_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float core = facing * facing * facing;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float reach = clamp((dist - 0.3) / near_fade, 0.0, 1.0);
	ALBEDO = tint * strength * fade * (0.05 + 0.95 * core) * reach;
}
