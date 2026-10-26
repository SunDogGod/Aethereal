// Aeneas's aether bursting out of him (hall_burst.gd): a sphere of raw light. With `fill` 1 it
// is the flash itself, white at its heart and coloured at its edge; with `fill` 0 only the edge
// shows: the shockwave shell racing out through the hall. Ragged at a chunky pixel grid, added
// onto the scene (blend_add). `fade` takes it away.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec2 ps1_snap_resolution;

uniform vec3 core_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 rim_color : source_color = vec3(0.35, 0.85, 1.0);
uniform vec3 fringe_color : source_color = vec3(0.55, 0.25, 1.0);
uniform float fill = 1.0;
uniform float fade = 1.0;
uniform float pixels = 20.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = ps1_snap_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	vec2 px = floor(UV * vec2(pixels * 2.0, pixels));
	float n = noise(px * 0.5 + vec2(TIME * 9.0, -TIME * 6.0));
	float facing = abs(dot(NORMAL, VIEW));
	float rim = 1.0 - facing;
	// The shell: a bright ragged edge. The flash: bright through, whitest in the middle.
	float shell = pow(rim, 2.2) * (0.5 + 0.8 * n);
	float flash = (0.45 + 0.55 * facing) * (0.7 + 0.4 * n);
	float heat = mix(shell, flash, fill);
	if (heat < 0.04) {
		discard;
	}
	vec3 edge = mix(rim_color, fringe_color, smoothstep(0.55, 0.95, rim) * (0.5 + 0.5 * n));
	vec3 c = mix(edge, core_color, smoothstep(0.35, 0.9, facing) * fill);
	ALBEDO = c * heat * fade;
}
