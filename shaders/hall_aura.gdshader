// The Black Cube's halo while it takes the sacrifices: a dark corona round the cube that
// shimmers at its edge, with a thin crimson rim. A quad that always faces the camera, drawn
// at a coarse pixel grid; the cube itself hides the middle (it is drawn first, and solid).
// `pulse` (one body taken) and `surge` (a story beat) are tweened by scripts/vfx/hall_aura.gd.
// Used by materials/hall_aura.tres.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec2 ps1_snap_resolution;

uniform vec3 dark_color : source_color = vec3(0.03, 0.0, 0.035);
uniform vec3 rim_color : source_color = vec3(0.78, 0.1, 0.2);
uniform float darkness = 0.92;      // how much of the room the corona blots out
uniform float pulse = 0.0;          // 0..1: a body taken (brief swell)
uniform float surge = 0.0;          // 0..1: the big beat (wide, bright, fast)
uniform float speed = 0.7;
uniform float pixels = 36.0;

instance uniform float seed = 0.0;
instance uniform float fade = 1.0;   // the faint outer halo uses less

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
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec2 size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	vec3 world = origin + INV_VIEW_MATRIX[0].xyz * VERTEX.x * size.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y * size.y;
	vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	vec2 grid = ps1_snap_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	vec2 px = (floor(UV * pixels) + 0.5) / pixels - 0.5;
	px.y = -px.y;                                // up is +y
	float r = length(px) * 2.0;                 // 0 centre .. 1 quad edge
	float ang = atan(px.y, px.x) / 6.2831853 + 0.5;
	float up = max(px.y * 2.0 / max(r, 0.001), 0.0);  // 1 straight above the cube
	float t = TIME * speed * (1.0 + surge * 2.5) + seed * 9.0;
	// The edge of the corona wavers in slow tongues that lean upward, like dark flame.
	float slow = noise(vec2(ang * 11.0 + seed * 3.0, t * 0.6 - r * 2.0));
	float fast = noise(vec2(ang * 29.0 - t * 1.7, r * 7.0 - t * 2.6));
	float edge = 0.34 + 0.22 * slow * (0.6 + 0.6 * up) + 0.06 * fast + 0.12 * pulse + 0.1 * surge;
	if (r > edge + 0.06) {
		discard;
	}
	float inside = 1.0 - smoothstep(edge - 0.07, edge, r);
	// The rim only catches in broken flickering pixels, not a drawn circle.
	float rim = 1.0 - clamp(abs(r - edge) / 0.05, 0.0, 1.0);
	float sparks = step(0.7 - 0.12 * pulse - 0.12 * surge, fast);
	float rim_on = (rim > 0.4 ? 1.0 : 0.0) * sparks * fade;
	vec3 c = mix(dark_color, rim_color * (1.0 + pulse * 0.8 + surge * 1.6), rim_on);
	float a = max(inside * darkness * (0.8 + 0.2 * fast), rim_on * (0.75 + 0.25 * pulse));
	if (a < 0.04) {
		discard;
	}
	ALBEDO = c;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
