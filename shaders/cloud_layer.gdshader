// A soft cloud deck: a few stacked see-through sheets of drifting noise (scripts/cloud_layer.gd
// builds them; each sheet's number is in the vertex colour's red). Seen from below, the sheets
// slide past each other a little, so the deck reads as thick instead of a flat lid.
// PS1 rules kept: the corners snap to the global wobble grid, the cloud is drawn in chunky
// world texels (`texel` metres each) that slide with the wind, and the 15-bit dither comes from
// PS1Screen like everything else. The fog fades distant cloud into the level's haze.
// Where a building pokes through, the cloud thins out against its walls (`soft_contact`) instead
// of cutting a hard line across them. Used by materials/clouds_*.tres.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

global uniform vec2 ps1_snap_resolution;

uniform vec3 light_color : source_color = vec3(0.30, 0.31, 0.35);   // thin, lit cloud
uniform vec3 shade_color : source_color = vec3(0.13, 0.14, 0.17);   // the thick middle, seen from below
uniform float opacity : hint_range(0.0, 1.0) = 0.8;    // how solid the thickest cloud is
uniform float cover : hint_range(0.0, 1.0) = 0.55;     // how much of the sky is cloud
uniform float softness : hint_range(0.01, 1.0) = 0.35; // how gently a cloud's edge fades
uniform float cloud_size = 70.0;    // metres across a typical cloud
uniform float texel = 0.3;          // metres per cloud pixel: chunky, like the textures
uniform vec2 wind = vec2(1.2, 0.4); // metres per second the clouds drift
uniform float soft_contact = 6.0;   // metres: the cloud thins out this close to a wall behind it
uniform float near_fade = 10.0;     // metres: a sheet the camera is close to fades away
uniform float edge_fade = 60.0;     // metres: the deck's outer border fades out
instance uniform vec2 half_size = vec2(300.0, 300.0);  // set by cloud_layer.gd

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying vec3 world_pos;
varying vec2 local_xz;
varying float sheet;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v / 0.9375;
}

void vertex() {
	sheet = COLOR.r * 255.0;
	local_xz = VERTEX.xz;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = ps1_snap_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	// Each sheet drifts a little faster than the one below it and has its own pattern.
	vec2 drift = wind * TIME * (1.0 + 0.15 * sheet);
	// Chunky texels up close; far off, where a texel shrinks under two screen pixels, plain smooth
	// cloud instead (like the textures' mipmaps), or the drifting texels would shimmer.
	vec2 raw = world_pos.xz + drift;
	float pixel = length(fwidth(world_pos.xz));
	vec2 p = mix(floor(raw / texel) * texel + texel * 0.5, raw, smoothstep(texel * 0.3, texel * 0.6, pixel));
	float n = fbm(p / cloud_size + vec2(sheet * 3.7, sheet * 1.9));
	float density = smoothstep(1.0 - cover, 1.0 - cover + softness, n);

	vec3 color = mix(light_color, shade_color, smoothstep(0.3, 1.0, density));
	float a = density * opacity;

	// Fade out at the deck's border (a rounded border, each sheet a little smaller than the one
	// below, so the deck never shows a rectangle from underneath), close to the camera, and
	// against the walls it meets.
	vec2 shrink = half_size * (1.0 - 0.12 * sheet);
	vec2 edge = max(shrink - abs(local_xz), vec2(0.0));
	float corner = length(vec2(edge_fade) - min(edge, vec2(edge_fade)));
	a *= clamp(1.0 - corner / edge_fade, 0.0, 1.0);
	float distance_to_camera = length(world_pos - CAMERA_POSITION_WORLD);
	a *= clamp((distance_to_camera - 2.0) / near_fade, 0.0, 1.0);
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float gap = -behind.z / behind.w + VERTEX.z;  // metres from this sheet to whatever is behind it
	a *= clamp(gap / soft_contact, 0.0, 1.0);

	ALBEDO = color;
	ALPHA = a;
}
