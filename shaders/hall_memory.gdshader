// The passage into a memory (scripts/vfx/memory_fade.gd): over the whole screen, `black` lays
// black on top, and `dream` turns what is behind it soft, pale, warm and washed out (a light
// blur, the colour drained, lifted toward a warm white). The hall's end slides into black with
// the dream rising; the Massacre opens from black into a full dream that settles into the scene.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float black : hint_range(0.0, 1.0) = 0.0;
uniform float dream : hint_range(0.0, 1.0) = 0.0;
uniform vec3 warm : source_color = vec3(1.0, 0.93, 0.8);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * (1.0 + 3.0 * dream);
	vec3 c = texture(screen, SCREEN_UV).rgb * 0.4;
	c += texture(screen, SCREEN_UV + vec2(px.x, 0.0)).rgb * 0.15;
	c += texture(screen, SCREEN_UV - vec2(px.x, 0.0)).rgb * 0.15;
	c += texture(screen, SCREEN_UV + vec2(0.0, px.y)).rgb * 0.15;
	c += texture(screen, SCREEN_UV - vec2(0.0, px.y)).rgb * 0.15;
	float grey = dot(c, vec3(0.3, 0.55, 0.15));
	vec3 washed = mix(vec3(grey), c, 0.35) * 0.75 + warm * 0.35;
	c = mix(c, washed, dream);
	COLOR = vec4(c * (1.0 - black), 1.0);
}
