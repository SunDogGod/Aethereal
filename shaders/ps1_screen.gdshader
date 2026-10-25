// Full-screen PS1 color: 15-bit color (32 shades per channel), plus the 4x4
// ordered dither the PS1 used to hide the banding that causes.
// Lives on the PS1Screen autoload, so it covers every scene.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float color_levels = 32.0;
uniform bool dither = true;

const float BAYER[16] = {
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
};

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	if (dither) {
		ivec2 cell = ivec2(mod(FRAGCOORD.xy, 4.0));
		float threshold = BAYER[cell.y * 4 + cell.x] / 16.0 - 0.5;
		color += threshold / color_levels;
	}
	color = round(color * (color_levels - 1.0)) / (color_levels - 1.0);
	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
