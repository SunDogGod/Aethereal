// PS1-style surface. Every 3D mesh in the game uses this shader.
// What it fakes, and why the PS1 looked this way:
//  - Vertex wobble: the PS1 had no sub-pixel precision, so corners snapped to
//    whole pixels and shimmered as the camera moved.
//  - Texture warping: the PS1 didn't correct textures for perspective, so they
//    bend and swim on big polygons close to the camera ("affine" mapping).
//  - Crisp texels: no texture smoothing, so every texel is a hard square.
//  - Vertex lighting: light was worked out per corner, not per pixel.
// The wobble grid is shared by every material:
// Project Settings > Shader Globals > ps1_snap_resolution. Lower = more wobble.
shader_type spatial;
render_mode vertex_lighting, specular_disabled, cull_back;

global uniform vec2 ps1_snap_resolution;

uniform vec4 albedo_color : source_color = vec4(1.0);
// Nearest-with-mipmaps: hard texels up close, but far surfaces average out instead of
// shimmering into noise (the one thing the PS1 couldn't do that we want anyway).
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform vec2 uv_scale = vec2(1.0);
// With a trim sheet: pick the strip by offsetting v (e.g. scale (1, 1/8), offset (0, 3/8)).
uniform vec2 uv_offset = vec2(0.0);
// For blockout shapes (CSG boxes) that have no good UVs of their own: project
// the texture from the world instead, one repeat every texture_world_size metres.
uniform bool world_uv = false;
uniform float texture_world_size = 2.0;
// With world_uv on: give floors and ceilings their own texture (no glow), so a
// building can have windows on its walls and plain concrete on its roof.
uniform bool use_top_texture = false;
uniform sampler2D top_texture : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
// 1.0 = full PS1 warping, 0.0 = modern perspective-correct textures.
uniform float affine_amount : hint_range(0.0, 1.0) = 0.0;
// The warping is eased off on surfaces right in front of the camera, between these two
// distances (metres), so walls stop swimming when you brush past them.
uniform float affine_near = 2.0;
uniform float affine_far = 10.0;
// Multiply by the mesh's vertex colors (handy for models painted in Blender).
uniform bool use_vertex_color = false;
// Characters: a finer wobble grid (2 = twice as fine), so animated bodies don't jitter.
uniform float snap_scale = 1.0;
// Glow for neon signs and lit windows. Fog still swallows it in the distance.
// The glow texture adds per-texel glow (lit windows); black means no glow.
uniform vec3 emission_color : source_color = vec3(0.0);
uniform sampler2D emission_texture : source_color, filter_nearest_mipmap, repeat_enable, hint_default_black;
uniform vec3 emission_tint : source_color = vec3(1.0);  // colours the glow texture (a white sign, tinted pink)
uniform float emission_energy = 0.0;

varying vec2 correct_uv;
// xy = uv * w, z = w. Dividing them per pixel cancels the GPU's perspective fix.
varying vec3 affine_uv;
varying float affine_strength;
varying flat float is_top;

vec2 world_projected_uv(vec3 world_pos, vec3 world_normal) {
	vec3 n = abs(world_normal);
	if (n.y >= n.x && n.y >= n.z) {
		return world_pos.xz;
	} else if (n.x >= n.z) {
		return vec2(world_pos.z, -world_pos.y);
	}
	return vec2(world_pos.x, -world_pos.y);
}

void vertex() {
	vec2 uv = UV * uv_scale + uv_offset;
	is_top = 0.0;
	if (world_uv) {
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
		uv = world_projected_uv(world_pos, world_normal) / texture_world_size;
		is_top = step(0.7, abs(world_normal.y));
	}

	// Snap the corner to a coarse screen grid: the wobble.
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = ps1_snap_resolution * 0.5 * snap_scale;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;

	correct_uv = uv;
	affine_uv = vec3(uv * clip.w, clip.w);
	affine_strength = affine_amount * smoothstep(affine_near, affine_far, clip.w);
}

void fragment() {
	vec2 uv = mix(correct_uv, affine_uv.xy / affine_uv.z, affine_strength);
	bool top = use_top_texture && is_top > 0.5;
	vec3 color = (top ? texture(top_texture, uv).rgb : texture(albedo_texture, uv).rgb) * albedo_color.rgb;
	if (use_vertex_color) {
		color *= COLOR.rgb;
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
	vec3 glow = top ? vec3(0.0) : texture(emission_texture, uv).rgb;
	EMISSION = (emission_color + glow * emission_tint) * emission_energy;
}
