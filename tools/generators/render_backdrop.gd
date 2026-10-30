extends SceneTree
# Renders the Empty Town's far city ONCE into textures/backdrop_city.png: six cube faces side by
# side (+X, -X, +Y, -Y, +Z, -Z, 1024 px each). The level shows it as its sky
# (shaders/sky_backdrop.gdshader), so thousands of megastructure blocks cost one texture read.
# The city is built here from boxes (Blame!-scale: 70-400 m wide, kilometres tall, 0.7-7 km away),
# coloured by backdrop_city.gdshader. Each face renders at 2048 px and is halved on the GPU keeping
# the brightest pixel where a light sits (so 1 px lights survive) and the average elsewhere.
# Run WINDOWED (it waits for frames to draw): godot --path PROJ -s this.gd, then --import.

const DIR := "C:/Users/ArmandoSanchez/Documents/Aethereal 3D Godot/aethereal-3d/tools/generators/out/"
const OUT := "res://textures/backdrop_city.png"
const FACE := 1024
# Must match the Empty Town's fog colour so fogged geometry melts into the backdrop.
const HAZE := Color(0.055, 0.062, 0.092)
const WALL := Color(0.15, 0.16, 0.2)
# Cube faces: [forward, up]; right = forward x up. sky_backdrop.gdshader uses the same table.
const FACES := [[Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(0, 0, 1)], [Vector3(0, -1, 0), Vector3(0, 0, -1)],
	[Vector3(0, 0, 1), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(0, 1, 0)]]
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

var rng := RandomNumberGenerator.new()
var st := SurfaceTool.new()
var boxes := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	rng.seed = 20261025
	var big := SubViewport.new()
	big.size = Vector2i(FACE * 2, FACE * 2)
	big.own_world_3d = true
	big.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(big)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = HAZE
	var we := WorldEnvironment.new()
	we.environment = env
	big.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 90.0
	cam.near = 2.0
	cam.far = 30000.0
	big.add_child(cam)
	var city := MeshInstance3D.new()
	city.mesh = _build_city()
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FileAccess.get_file_as_string(DIR + "backdrop_city.gdshader")
	mat.shader = sh
	mat.set_shader_parameter("haze", HAZE)
	mat.set_shader_parameter("wall", WALL)
	mat.set_shader_parameter("light_warm", Color(1.0, 0.78, 0.45))
	mat.set_shader_parameter("light_cool", Color(0.7, 0.85, 1.0))
	city.material_override = mat
	city.extra_cull_margin = 16384.0
	big.add_child(city)
	# The halving pass.
	var small := SubViewport.new()
	small.size = Vector2i(FACE, FACE)
	small.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(small)
	var rect := ColorRect.new()
	rect.size = Vector2(FACE, FACE)
	var dmat := ShaderMaterial.new()
	var dsh := Shader.new()
	dsh.code = DOWNSAMPLE
	dmat.shader = dsh
	dmat.set_shader_parameter("src", big.get_texture())
	rect.material = dmat
	small.add_child(rect)
	var strip := Image.create(FACE * 6, FACE, false, Image.FORMAT_RGB8)
	for i in 6:
		var f: Vector3 = FACES[i][0]
		var u: Vector3 = FACES[i][1]
		var r := f.cross(u)
		cam.transform = Transform3D(Basis(r, u, -f), Vector3.ZERO)
		for k in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := small.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		strip.blit_rect(img, Rect2i(0, 0, FACE, FACE), Vector2i(i * FACE, 0))
		print("face ", i)
	strip.save_png(OUT)
	print("backdrop written: %d boxes, haze pixel %s" % [boxes, strip.get_pixel(FACE * 4 + 512, 40)])
	quit()


# ------------------------------------------------------------------ the city

func _build_city() -> ArrayMesh:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var towers: Array = []  # [centre x, centre z, half width, top] for the bridges
	# Rings: [inner, outer, count]. Nearer rings get the widest masses.
	for ring in [[700.0, 1300.0, 16], [1300.0, 2400.0, 28], [2400.0, 4200.0, 44], [4200.0, 7500.0, 64]]:
		for k in int(ring[2]):
			var ang := rng.randf() * TAU
			var dist := rng.randf_range(ring[0], ring[1])
			var c := Vector2(cos(ang), sin(ang)) * dist
			var hw := clampf(dist * rng.randf_range(0.03, 0.08), 35.0, 380.0)
			var hd := hw * rng.randf_range(0.6, 1.4)
			var top := rng.randf_range(-150.0, 1900.0)
			var dens := rng.randf_range(0.004, 0.03)
			_tower(c, hw, hd, top, dens)
			towers.append([c.x, c.y, hw, top])
	# Spans between neighbours: bridges, conduits and slabs hanging in the haze.
	for k in 36:
		var a: Array = towers[rng.randi() % towers.size()]
		var best: Array = []
		var best_d := INF
		for b in towers:
			var dd := Vector2(a[0] - b[0], a[1] - b[1]).length()
			if dd > a[2] * 2.5 and dd < best_d and rng.randf() < 0.5:
				best_d = dd
				best = b
		if best.is_empty():
			continue
		var y := rng.randf_range(-600.0, minf(a[3], best[3]) - 40.0)
		var thick := rng.randf_range(12.0, 60.0)
		_span(Vector2(a[0], a[1]), Vector2(best[0], best[1]), y, thick, rng.randf_range(15.0, 70.0))
	# A ceiling far overhead, in pieces: the megastructure closes over everything.
	for k in 26:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(1500.0, 6000.0)
		var c := Vector2(cos(ang), sin(ang)) * dist
		var hw := rng.randf_range(300.0, 1200.0)
		_box(Vector3(c.x - hw, 2300.0 + rng.randf() * 900.0, c.y - hw * 0.6), Vector3(c.x + hw, 2600.0 + rng.randf() * 900.0, c.y + hw * 0.6), rng.randf(), 0.006)
	return st.commit()


## A tower: a main shaft from the abyss, then 1-3 setbacks, sometimes a buttress at its side.
func _tower(c: Vector2, hw: float, hd: float, top: float, dens: float) -> void:
	var tone := rng.randf()
	var bottom := -2600.0
	var steps := rng.randi_range(1, 3)
	var y := bottom
	var shaft_top := top - (top - bottom) * rng.randf_range(0.0, 0.25) * steps
	_box(Vector3(c.x - hw, y, c.y - hd), Vector3(c.x + hw, shaft_top, c.y + hd), tone, dens)
	y = shaft_top
	var w := hw
	var d := hd
	for s in steps:
		w *= rng.randf_range(0.45, 0.8)
		d *= rng.randf_range(0.45, 0.8)
		var off := Vector2(rng.randf_range(-0.3, 0.3) * hw, rng.randf_range(-0.3, 0.3) * hd)
		var y1 := y + (top - shaft_top) / steps + rng.randf_range(20.0, 120.0)
		_box(Vector3(c.x + off.x - w, y, c.y + off.y - d), Vector3(c.x + off.x + w, y1, c.y + off.y + d), tone, dens * 1.4)
		y = y1
	if rng.randf() < 0.4:
		var side := Vector2(hw * 1.1, 0.0).rotated(rng.randi_range(0, 3) * PI * 0.5)
		var bw := hw * rng.randf_range(0.25, 0.5)
		_box(Vector3(c.x + side.x - bw, bottom, c.y + side.y - bw), Vector3(c.x + side.x + bw, shaft_top * rng.randf_range(0.3, 0.8), c.y + side.y + bw), tone * 0.8, dens * 0.6)


## A long box from a to b at height y.
func _span(a: Vector2, b: Vector2, y: float, thick: float, width: float) -> void:
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x) * width * 0.5
	var pts := [a + n, b + n, b - n, a - n]
	var tone := rng.randf()
	_quad_prism(pts, y, y + thick, tone, 0.02)


func _box(lo: Vector3, hi: Vector3, tone: float, dens: float) -> void:
	_quad_prism([Vector2(lo.x, lo.z), Vector2(hi.x, lo.z), Vector2(hi.x, hi.z), Vector2(lo.x, hi.z)], lo.y, hi.y, tone, dens)


## A prism over a 4-point footprint, y0..y1. Faces are cut into 300 m tall strips so the
## vertex positions stay precise. The shader draws both sides, so winding doesn't matter.
func _quad_prism(pts: Array, y0: float, y1: float, tone: float, dens: float) -> void:
	boxes += 1
	var col := Color(tone, dens, float(boxes % 1024) / 1024.0)
	var mid: Vector2 = (pts[0] + pts[1] + pts[2] + pts[3]) * 0.25
	for i in 4:
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % 4]
		var e := (q - p).normalized()
		var out := Vector2(-e.y, e.x)
		if out.dot((p + q) * 0.5 - mid) < 0.0:
			out = -out
		var n := Vector3(out.x, 0.0, out.y)
		var y := y0
		while y < y1 - 0.01:
			var ya := minf(y + 300.0, y1)
			_tri(Vector3(p.x, y, p.y), Vector3(q.x, y, q.y), Vector3(q.x, ya, q.y), col, n)
			_tri(Vector3(p.x, y, p.y), Vector3(q.x, ya, q.y), Vector3(p.x, ya, p.y), col, n)
			y = ya
	var top: Array = []
	var bot: Array = []
	for p in pts:
		top.append(Vector3(p.x, y1, p.y))
		bot.append(Vector3(p.x, y0, p.y))
	_tri(top[0], top[2], top[1], col, Vector3.UP)
	_tri(top[0], top[3], top[2], col, Vector3.UP)
	_tri(bot[0], bot[1], bot[2], col, Vector3.DOWN)
	_tri(bot[0], bot[2], bot[3], col, Vector3.DOWN)


func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color, n: Vector3) -> void:
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)
