// The title screen's background: a still of the Empty Town, darkened and cooled, that
// drifts and breathes very slowly. The PS1Screen filter dithers it like everything else.
// Every number below shows in the Inspector (TitleScreen > Background > Material).
shader_type canvas_item;

uniform float zoom = 1.12;                 // how far into the picture (room for the drift)
uniform float drift = 0.022;               // how far it pans, as a fraction of the picture
uniform float cycle_seconds = 46.0;        // one slow drift there and back
uniform float brightness = 0.5;
uniform float desaturate = 0.35;
uniform vec3 tint : source_color = vec3(0.62, 0.7, 1.0);
uniform float vignette = 1.1;
uniform float left_shade = 0.55;           // extra dark on the left, behind the menu

void fragment() {
	float t = 0.5 - 0.5 * cos(TIME * 6.2831853 / cycle_seconds);  // eases 0 -> 1 -> 0
	float z = zoom + 0.04 * t;
	vec2 pan = vec2(mix(-drift, drift, t), mix(drift * 0.4, -drift * 0.4, t));
	vec2 uv = (UV - 0.5) / z + 0.5 + pan;
	vec3 c = texture(TEXTURE, uv).rgb;
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(grey), desaturate) * tint * brightness;
	vec2 d = UV - 0.5;
	c *= clamp(1.0 - vignette * dot(d, d), 0.0, 1.0);
	c *= 1.0 - left_shade * smoothstep(0.62, 0.0, UV.x);
	COLOR = vec4(c, 1.0);
}
