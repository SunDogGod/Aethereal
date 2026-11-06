extends SceneTree
# Renders the Empty Town's far city ONCE into textures/backdrop_city.png: six cube faces side by
# side (+X, -X, +Y, -Y, +Z, -Z, 1024 px each). The level shows it as its sky
# (shaders/sky_backdrop.gdshader), so thousands of megastructure pieces cost one texture read.
# The city is built here (Blame!-scale: 70-400 m wide, kilometres tall, 0.7-7.5 km away) from
# boxes, cylinders, spires, buttresses, floating slabs, gantries and sagging cables, and coloured
# by the CITY shader below: dotted windows with dark storeys and dark runs, two hot sodium clusters
# low down, towers that vanish upward into the haze. The sky behind is the SKY shader: the fog
# colour at and below the horizon (Environment fog_sky_affect stays 0: the haze is painted in),
# a thin magenta-violet dusk band just above it, black-green overhead.
# Each face renders at 2048 px and is halved on the GPU keeping the brightest pixel where a light
# sits (so 1 px lights survive) and the average elsewhere.
# The geometry lives in render_backdrop_city.gd.
# Run WINDOWED (it waits for frames to draw): godot --path PROJ -s this.gd, then --headless --import.

const OUT := "res://textures/backdrop_city.png"
const FACE := 1024
# Must match the Empty Town's fog colour so fogged geometry melts into the backdrop.
const HAZE := Color(0.055, 0.062, 0.092)
const WALL := Color(0.085, 0.09, 0.112)
const SODIUM := Color(1.0, 0.52, 0.16)
# The two hot clusters: centre (x, y, z) and radius. One ahead of the bridge (-Z), one east.
const CLUSTERS := [[Vector3(-320.0, -60.0, -1150.0), 430.0], [Vector3(1500.0, -140.0, 560.0), 520.0]]
# Cube faces: [forward, up]; right = forward x up. sky_backdrop.gdshader uses the same table.
const FACES := [[Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(0, 0, 1)], [Vector3(0, -1, 0), Vector3(0, 0, -1)],
	[Vector3(0, 0, 1), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(0, 1, 0)]]
# Shared by both shaders: the sky colour in a direction (all colours are sRGB uniforms).
const SKY_FN := """
uniform vec3 haze : source_color;
uniform vec3 sky_mid : source_color;
uniform vec3 sky_top : source_color;
uniform vec3 dusk : source_color;
uniform vec3 sodium : source_color;
uniform vec4 clusters[2];
vec3 sky_col(vec3 d) {
	float e = d.y;
	if (e <= 0.0) { return haze; }
	vec3 c = mix(haze, sky_mid, smoothstep(0.0, 0.2, e));
	c = mix(c, sky_top, smoothstep(0.16, 0.65, e));
	float az = atan(d.x, d.z);
	float band = exp(-pow((e - 0.05) / 0.045, 2.0)) * smoothstep(0.0, 0.05, e);
	c += dusk * band * (0.55 + 0.45 * cos(az - 2.6));
	for (int i = 0; i < 2; i++) {
		float da = az - atan(clusters[i].x, clusters[i].z);
		da = abs(mod(da + 3.14159, 6.28318) - 3.14159);
		c += sodium * 0.08 * exp(-pow(da / 0.28, 2.0)) * exp(-e / 0.05) * smoothstep(0.0, 0.03, e);
	}
	return c;
}
"""
const SKY := "shader_type sky;\n" + SKY_FN + "\nvoid sky() { COLOR = sky_col(normalize(EYEDIR)); }\n"
# Vertex colour: r tone, g window density, b building id, a kind (0 wall, 0.5 cool beacon, 1 lamp).
const CITY := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 wall : source_color;
uniform vec3 cool : source_color;
varying vec3 wp;
varying vec3 wn;
varying vec4 vc;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
""" + SKY_FN + """
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vc = COLOR;
}
void fragment() {
	float dist = length(wp);
	float id = floor(vc.b * 255.0) * 7.3;
	vec3 col = wall * (0.8 + 0.4 * vc.r + 0.25 * wn.y + 0.08 * wn.x);
	float cw = 0.0;  // how deep inside a sodium cluster
	for (int i = 0; i < 2; i++) {
		vec3 dc = wp - vec3(clusters[i].x, clusters[i].y, clusters[i].z);
		float horiz = 1.0 - smoothstep(clusters[i].w * 0.35, clusters[i].w, length(dc.xz));
		cw = max(cw, horiz * (1.0 - smoothstep(120.0, 420.0, abs(dc.y))));
	}
	if (abs(wn.y) < 0.5) {
		vec3 t = normalize(vec3(wn.z, 0.0, -wn.x));
		vec2 g = vec2(dot(wp, t) / 5.0, wp.y / 4.0);
		vec2 cell = floor(g);
		vec2 f = fract(g);
		float alive = step(0.45, h21(vec2(cell.y, id))) * step(0.35, h21(vec2(floor(cell.x / 5.0), cell.y + id)));
		alive *= step(0.17, fract(cell.y / 12.0));  // a dark mechanical floor band every 12 storeys
		float inside = step(0.3, f.x) * step(f.x, 0.7) * step(0.35, f.y) * step(f.y, 0.75);
		float lit = alive * inside * step(h21(cell + id), vc.g * (1.0 + 4.0 * cw));
		float br = 0.3 + 0.7 * h21(cell * 1.7 + id);
		vec3 wc = h21(cell * 2.3 + id) < 0.6 ? vec3(1.0, 0.8, 0.5) : vec3(0.6, 0.8, 1.0);
		col += lit * br * mix(wc, sodium, cw);
	}
	col += sodium * cw * 0.06;
	if (vc.a > 0.75) { col = sodium * 1.6; } else if (vc.a > 0.25) { col = cool * 1.3; }
	float fog = 1.0 - exp(-dist / 2200.0);
	float up = smoothstep(900.0, 2300.0, wp.y);
	ALBEDO = mix(col, sky_col(wp / dist), max(fog, up));
}
"""
const DOWNSAMPLE := """
shader_type canvas_item;
uniform sampler2D src : filter_nearest;
float lum(vec3 c) { return dot(c, vec3(0.3, 0.5, 0.2)); }
void fragment() {
	vec2 p = floor(UV * 1024.0) * 2.0 + 0.5;
	vec3 a = texture(src, p / 2048.0).rgb;
	vec3 b = texture(src, (p + vec2(1.0, 0.0)) / 2048.0).rgb;
	vec3 c = texture(src, (p + vec2(0.0, 1.0)) / 2048.0).rgb;
	vec3 d = texture(src, (p + vec2(1.0, 1.0)) / 2048.0).rgb;
	vec3 avg = (a + b + c + d) * 0.25;
	vec3 mx = a;
	if (lum(b) > lum(mx)) mx = b;
	if (lum(c) > lum(mx)) mx = c;
	if (lum(d) > lum(mx)) mx = d;
	COLOR = vec4(lum(mx) > lum(avg) * 1.5 + 0.03 ? mx : avg, 1.0);
}
"""

const City := preload("res://tools/generators/render_backdrop_city.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var builder := City.new()
	var big := SubViewport.new()
	big.size = Vector2i(FACE * 2, FACE * 2)
	big.own_world_3d = true
	big.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(big)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky.sky_material = _material(SKY)
	var we := WorldEnvironment.new()
	we.environment = env
	big.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 90.0
	cam.near = 2.0
	cam.far = 30000.0
	big.add_child(cam)
	var city := MeshInstance3D.new()
	city.mesh = builder.build(20261105, CLUSTERS)
	city.material_override = _material(CITY)
	city.extra_cull_margin = 16384.0
	big.add_child(city)
	# The halving pass.
	var small := SubViewport.new()
	small.size = Vector2i(FACE, FACE)
	small.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(small)
	var rect := ColorRect.new()
	rect.size = Vector2(FACE, FACE)
	rect.material = _material(DOWNSAMPLE)
	rect.material.set_shader_parameter("src", big.get_texture())
	small.add_child(rect)
	var strip := Image.create(FACE * 6, FACE, false, Image.FORMAT_RGB8)
	for i in 6:
		var f: Vector3 = FACES[i][0]
		var u: Vector3 = FACES[i][1]
		cam.transform = Transform3D(Basis(f.cross(u), u, -f), Vector3.ZERO)
		for k in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := small.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		strip.blit_rect(img, Rect2i(0, 0, FACE, FACE), Vector2i(i * FACE, 0))
		print("face ", i)
	strip.save_png(OUT)
	print("backdrop written: %d pieces, down-face pixel %s (fog colour %s)" % [builder.pieces, strip.get_pixel(FACE * 3 + 512, 512), HAZE])
	quit()


func _material(code: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = code
	for p in [["haze", HAZE], ["sky_mid", Color(0.03, 0.045, 0.046)], ["sky_top", Color(0.01, 0.02, 0.018)],
			["dusk", Color(0.17, 0.05, 0.15)], ["sodium", SODIUM], ["wall", WALL], ["cool", Color(0.75, 0.9, 1.0)]]:
		mat.set_shader_parameter(p[0], p[1])
	var cl: Array[Vector4] = []
	for c in CLUSTERS:
		cl.append(Vector4(c[0].x, c[0].y, c[0].z, c[1]))
	mat.set_shader_parameter("clusters", cl)
	return mat


