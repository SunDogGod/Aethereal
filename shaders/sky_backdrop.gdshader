// The Empty Town's backdrop: a far megastructure city rendered once (scratchpad
// r8_sky/render_backdrop.gd) into six cube faces side by side in one texture, shown as the
// level's sky. It sits at "infinity", so it never clips (shot cameras have far = 120) and looks the
// same from the bridge, the streets and every story shot, and costs one texture read per pixel.
// Its haze is the level's fog colour, so geometry fading into the fog melts into it
// (the Environment keeps fog_sky_affect at 0: the haze is painted in).
shader_type sky;

uniform sampler2D faces : source_color, filter_nearest, repeat_disable;
// What reflections and the radiance map see: the old flat background colour, so the PS1 materials
// light exactly as before.
uniform vec3 radiance_color : source_color = vec3(0.035, 0.042, 0.068);

void sky() {
	if (AT_CUBEMAP_PASS) {
		COLOR = radiance_color;
	} else {
		vec3 d = normalize(EYEDIR);
		vec3 a = abs(d);
		// Face order and axes match render_backdrop.gd: [forward, up], right = forward x up.
		float face;
		vec3 f;
		vec3 u;
		if (a.x >= a.y && a.x >= a.z) {
			face = d.x > 0.0 ? 0.0 : 1.0;
			f = vec3(sign(d.x), 0.0, 0.0);
			u = vec3(0.0, 1.0, 0.0);
		} else if (a.y >= a.z) {
			face = d.y > 0.0 ? 2.0 : 3.0;
			f = vec3(0.0, sign(d.y), 0.0);
			u = vec3(0.0, 0.0, sign(d.y));
		} else {
			face = d.z > 0.0 ? 4.0 : 5.0;
			f = vec3(0.0, 0.0, sign(d.z));
			u = vec3(0.0, 1.0, 0.0);
		}
		vec3 r = cross(f, u);
		float k = dot(d, f);
		vec2 st = vec2(dot(d, r), dot(d, u)) / k;          // -1..1 across the face
		vec2 uv = vec2(0.5 + 0.5 * st.x, 0.5 - 0.5 * st.y);
		uv = clamp(uv, vec2(0.5 / 1024.0), vec2(1.0 - 0.5 / 1024.0));  // no bleed from the next face
		COLOR = texture(faces, vec2((uv.x + face) / 6.0, uv.y)).rgb;
	}
}
