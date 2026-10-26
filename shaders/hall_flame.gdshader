// Fire for the hall's bonfire: flame tongues and the motes the Black Cube draws out of it.
// A quad that turns to face the camera, filled in by hand-made noise at a coarse pixel grid,
// coloured in three hard bands (white-gold core, orange, deep red edge), added onto the
// scene (blend_add: no sorting, no dark edges). The corners snap to the same wobble grid as
// ps1_surface.gdshader, so the fire sits in the world like everything else.
// This is the one other non-ps1_surface shader besides the particle puffs: a flame can't be an
// opaque surface. Used by materials/hall_flame.tres (tongues) and hall_mote.tres (motes).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec2 ps1_snap_resolution;

uniform vec3 core_color : source_color = vec3(1.0, 0.9, 0.55);
uniform vec3 mid_color : source_color = vec3(1.0, 0.46, 0.1);
uniform vec3 edge_color : source_color = vec3(0.62, 0.1, 0.03);
// The bonfire script raises this for a flare (a body thrown on): taller, brighter.
uniform float intensity = 1.0;
uniform float brightness = 1.0;
uniform float speed = 1.5;
// Chunky texels across the quad (x, y): the flame's "pixels".
uniform vec2 pixels = vec2(10.0, 20.0);
// 0 = an upright tongue that turns only around Y; 1 = a round mote that always faces the camera.
uniform int shape = 0;
// Tongues only: how far (metres, world x and z) the top of a tongue is pulled sideways, as if
// the flames were drawn toward something (the Black Cube taking Isabella's soul). The foot stays.
uniform vec2 lean = vec2(0.0);

// Per quad (MeshInstance3D: set_instance_shader_parameter): its own flicker and brightness.
instance uniform float seed = 0.0;
instance uniform float strength = 1.0;

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
	vec3 world;
	if (shape == 0) {
		vec3 to_cam = INV_VIEW_MATRIX[3].xyz - origin;
		to_cam.y = 0.0;
		to_cam = length(to_cam) > 0.001 ? normalize(to_cam) : vec3(0.0, 0.0, 1.0);
		vec3 right = vec3(to_cam.z, 0.0, -to_cam.x);
		world = origin + right * VERTEX.x * size.x + vec3(0.0, VERTEX.y * size.y, 0.0);
		world += vec3(lean.x, 0.0, lean.y) * VERTEX.y * VERTEX.y;  // VERTEX.y: 0 at the foot, 1 at the top
	} else {
		world = origin + INV_VIEW_MATRIX[0].xyz * VERTEX.x * size.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y * size.y;
	}
	vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	vec2 grid = ps1_snap_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

vec3 band(float heat) {
	if (heat > 0.62) {
		return core_color;
	} else if (heat > 0.32) {
		return mid_color;
	}
	return edge_color;
}

void fragment() {
	vec2 px = (floor(UV * pixels) + 0.5) / pixels;
	float t = TIME * speed + seed * 13.0;
	float heat;
	if (shape == 0) {
		float h = 1.0 - px.y;  // 0 at the foot, 1 at the top of the quad
		float n = noise(vec2(px.x * 3.0 + seed * 5.0, h * 2.6 - t));
		float n2 = noise(vec2(px.x * 7.0 - seed, h * 5.5 - t * 1.8));
		// How far up this tongue reaches right now: it licks up and falls back.
		float reach = clamp(0.5 + 0.35 * noise(vec2(seed * 3.0, t * 0.8)) + 0.3 * (intensity - 1.0), 0.15, 1.0);
		float hh = h / reach;
		if (hh >= 1.0) {
			discard;
		}
		float sway = (n - 0.5) * 0.45 * hh;
		float width = 0.46 * pow(1.0 - hh, 0.75) * (0.7 + 0.5 * n2);
		float d = abs(px.x - 0.5 + sway) / max(width, 0.001);
		heat = (1.0 - d) * (1.15 - hh * 0.85) - n2 * 0.3 * hh;
	} else {
		float d = length(px - 0.5) * 2.0;
		heat = (1.0 - d) * (0.8 + 0.4 * noise(vec2(seed * 7.0, t * 4.0)));
	}
	if (heat <= 0.02) {
		discard;
	}
	vec3 c = band(heat) * COLOR.rgb;
	float a = heat > 0.32 ? 1.0 : 0.65;
	ALBEDO = c * brightness * strength * (0.85 + 0.25 * intensity);
	ALPHA = a * COLOR.a;
}
