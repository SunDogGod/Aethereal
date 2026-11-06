// The Barrier Obelisk's wall of light: a faint see-through sheet across the ridge, made of fat
// glyph bands that crawl slowly upward. Additive, unshaded, drawn in chunky cells so it reads
// like the rest of the PS1 look; the corners snap to the global wobble grid like every other
// mesh. `fade` is per instance so a scene can dim the wall away (tween it to 0 and hide it).
// Used by materials/horus_barrier.tres on obelisk.gd's BarrierWall quad.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec2 ps1_snap_resolution;

uniform vec3 color : source_color = vec3(0.3, 0.55, 1.0);
uniform float strength = 0.5;        // how bright the glyphs are
uniform float band_height = 2.5;     // metres per glyph band
uniform float glyph_width = 1.6;     // metres per glyph cell across the wall
uniform float speed = 0.35;          // bands per second the glyphs crawl upward
uniform float edge_fade = 0.15;      // fraction of the height that fades at the top and bottom
uniform float near_fade = 4.0;       // metres: the wall fades when the camera is this close
uniform float far_fade = 140.0;      // metres: seen from further off it is only a faint band
instance uniform float fade = 1.0;
instance uniform vec2 wall_size = vec2(120.0, 20.0);  // metres, set by obelisk.gd

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = ps1_snap_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	// Metres across (x) and up (y) the wall, the bands sliding upward.
	vec2 m = vec2(UV.x * wall_size.x, (1.0 - UV.y) * wall_size.y);
	float band = floor((m.y - TIME * speed * band_height) / band_height);
	float cell = floor(m.x / glyph_width);
	// Each band is its own row of fat glyphs: a cell is lit or dark, and a lit cell carries one
	// dark notch (a 3 x 3 block pattern), so it reads as writing, not as a checkerboard.
	float lit = step(0.45, hash(vec2(cell, band)));
	vec2 sub = floor(fract(vec2(m.x / glyph_width, (m.y - TIME * speed * band_height) / band_height)) * 3.0);
	float notch = hash(vec2(cell * 7.0 + sub.x, band * 3.0 + sub.y));
	float ink = lit * step(0.35, notch);
	// A thin gap between bands, a faint glow everywhere, and the glyphs on top.
	float gap = step(0.12, fract((m.y - TIME * speed * band_height) / band_height));
	float a = 0.03 + 0.5 * ink * gap;
	// Soft at the top and bottom, soft against the camera.
	float v = UV.y;
	a *= smoothstep(0.0, edge_fade, v) * smoothstep(0.0, edge_fade, 1.0 - v);
	float d = length(world_pos - CAMERA_POSITION_WORLD);
	a *= clamp((d - 0.5) / near_fade, 0.0, 1.0);
	a *= 1.0 - 0.8 * smoothstep(far_fade * 0.4, far_fade, d);
	ALBEDO = color * strength * a * fade;
}
