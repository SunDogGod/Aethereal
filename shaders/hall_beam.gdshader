// A beam of soul light between the Black Cube and someone it gives to (hall_stream.gd): a thin
// cylinder whose middle burns white and whose sides carry the colour, with chunky bands of
// light running along it toward the receiver. Added onto the scene like the fire (blend_add).
// `head` is how far it has reached (0 at the cube, 1 at the receiver), `tail` where it starts
// (it lets go of the cube at the end), `fade` dims all of it. The mesh's local Y runs from
// -0.5 (the giver) to 0.5 (the receiver); hall_stream.gd lays it along the two.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec2 ps1_snap_resolution;

uniform vec3 core_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 edge_color : source_color = vec3(0.45, 0.8, 1.0);
uniform float head = 1.0;
uniform float tail = 0.0;
uniform float fade = 1.0;
uniform float speed = 2.5;
// Chunky texels round the beam and along it.
uniform vec2 pixels = vec2(6.0, 40.0);

varying float along;

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
	along = VERTEX.y + 0.5;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = ps1_snap_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	float a = (floor(along * pixels.y) + 0.5) / pixels.y;
	if (a > head || a < tail) {
		discard;
	}
	float facing = abs(dot(NORMAL, VIEW));
	float n = noise(vec2(floor(UV.x * pixels.x), a * pixels.y * 0.35 - TIME * speed * 6.0));
	// The leading end burns brightest; both ends taper.
	float tip = 1.0 + 1.5 * smoothstep(head - 0.08, head, a);
	float ends = smoothstep(tail, tail + 0.04, a);
	float heat = (0.35 + 0.65 * facing * facing) * (0.55 + 0.6 * n) * tip * ends;
	vec3 c = mix(edge_color, core_color, smoothstep(0.55, 0.95, facing));
	ALBEDO = c * heat * fade;
}
