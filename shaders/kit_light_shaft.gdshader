// A shaft of light (scripts/props_kit/light_shaft.gd): a see-through cone added onto the scene,
// bright where the light enters (the top), fading along its length and at its silhouette, with
// slow bands of haze drifting down it. Drawn in chunky bands like the hall beam; the corners
// snap to the global wobble grid. The tint and strength are per shaft (instance uniforms), so
// every shaft shares materials/kit_light_shaft.tres.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec2 ps1_snap_resolution;

uniform float pixels = 24.0;      // chunky bands along the shaft
uniform float speed = 0.04;       // how fast the haze drifts down (bands per second)
uniform float near_fade = 2.0;    // metres: the shaft fades when the camera is inside or close
uniform float far_fade = 90.0;    // metres: it is gone this far away (fog would have taken it)
instance uniform vec3 tint : source_color = vec3(0.75, 0.7, 0.95);
instance uniform float strength = 0.25;
instance uniform float seed = 0.0;

varying float along;      // 0 at the top, 1 at the foot
varying vec3 world_pos;

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
	along = UV.y;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = ps1_snap_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	float a = (floor(along * pixels) + 0.5) / pixels;
	// Brightest at the top, gone at the foot; soft at the silhouette (the cone's edge faces away).
	float body = (1.0 - a) * (1.0 - a);
	float facing = abs(dot(NORMAL, VIEW));
	float edge = facing * facing * facing;
	// Slow bands of haze sliding down, in coarse texels round the cone.
	float haze = 0.7 + 0.3 * noise(vec2(floor(UV.x * 10.0) + seed * 7.0, a * pixels * 0.5 - TIME * speed * pixels));
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float reach = clamp((dist - 0.6) / near_fade, 0.0, 1.0) * (1.0 - clamp((dist - far_fade * 0.6) / (far_fade * 0.4), 0.0, 1.0));
	// Both sides of the cone are drawn and add up, so each gives half.
	ALBEDO = tint * strength * 0.5 * body * edge * haze * reach;
}
