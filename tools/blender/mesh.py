"""Geometry helpers: everything is built as 'lofts' (rings of points joined into a tube), which
gives smooth, readable limbs with exactly as many polygons as we ask for.

A Part collects vertices, faces, UVs and bone weights; to_object() turns it into a mesh.
Ring dicts used by loft():
    c   centre (Vector)          x, y  the ring's own right / front axes (x cross y = loft direction)
    rx, ry  radii along x / y    ryb   radius toward -y (the back), default ry
    n   squareness: 2 = ellipse, 3-4 = rounded box
    w   bone weights {bone: weight}    r(theta) optional radius multiplier (theta in degrees:
        0 = +x, 90 = +y, 180 = -x, 270 = -y)    arc (a, b) optional, for open shells
"""
import math
import bpy
import bmesh
from mathutils import Vector


class Part:
    def __init__(self):
        self.verts, self.weights, self.faces, self.uvs, self.smooth = [], [], [], [], []

    def vert(self, co, w):
        self.verts.append(Vector(co))
        self.weights.append(dict(w))
        return len(self.verts) - 1

    def face(self, idx, uvs, smooth=True):
        self.faces.append(list(idx))
        self.uvs.append([tuple(u) for u in uvs])
        self.smooth.append(smooth)

    def tris(self):
        return sum(len(f) - 2 for f in self.faces)


def _sp(c, n):
    """Superellipse helper: sign(c) * |c|^(2/n)."""
    return math.copysign(abs(c) ** (2.0 / n), c)


def ring_point(r, theta):
    t = math.radians(theta)
    ct, st = math.cos(t), math.sin(t)
    n = r.get("n", 2.0)
    m = r["r"](theta) if "r" in r else 1.0
    ry = r["ry"] if st >= 0 else r.get("ryb", r["ry"])
    return r["c"] + r["x"] * (r["rx"] * m * _sp(ct, n)) + r["y"] * (ry * m * _sp(st, n))


def loft(part, rings, segs, uv, start=-90.0, arc=None, cap0=None, cap1=None, thickness=0.0,
         lining=None, smooth=True, u_map=None):
    """Joins rings into a tube. uv = (u0, v0, u1, v1) in 0..1 texture space: u runs around the
    ring (from `start`, default the back), v from the first ring (v0) to the last (v1).
    arc = (a, b): only that part of the ring (an open shell, e.g. a jacket open at the front);
    then `thickness` gives it an inside (mapped to `lining` uv) so it isn't see-through.
    cap0 / cap1: 'pole' closes that end with a fan, or None. u_map(fraction) warps u."""
    u0, v0, u1, v1 = uv
    closed = arc is None
    cols = segs if closed else segs + 1
    lens = [0.0]
    for a, b in zip(rings, rings[1:]):
        lens.append(lens[-1] + (b["c"] - a["c"]).length)
    total = lens[-1] or 1.0
    grid = []
    thetas = []
    for j in range(cols):
        frac = j / segs
        thetas.append((start + 360.0 * frac) if closed else (arc[0] + (arc[1] - arc[0]) * frac))
    for i, r in enumerate(rings):
        row = []
        for j in range(cols):
            th = thetas[j]
            if not closed and "arc" in r:
                th = r["arc"][0] + (r["arc"][1] - r["arc"][0]) * j / segs
            row.append(part.vert(ring_point(r, th), r["wf"](th) if "wf" in r else r["w"]))
        grid.append(row)
    um = u_map or (lambda f: f)
    U = [u0 + (u1 - u0) * um(j / segs) for j in range(segs + 1)]
    V = [v0 + (v1 - v0) * (l / total) for l in lens]
    for i in range(len(rings) - 1):
        for j in range(segs):
            a, b = grid[i][j], grid[i][(j + 1) % cols]
            c, d = grid[i + 1][(j + 1) % cols], grid[i + 1][j]
            part.face((a, b, c, d), [(U[j], V[i]), (U[j + 1], V[i]), (U[j + 1], V[i + 1]), (U[j], V[i + 1])], smooth)
    for end, cap in ((0, cap0), (len(rings) - 1, cap1)):
        if cap != "pole":
            continue
        r = rings[end]
        sign = -1.0 if end == 0 else 1.0
        axis = r["x"].cross(r["y"]).normalized()
        tip = part.vert(r["c"] + axis * sign * r.get("cap_len", 0.0), r["w"])
        vv = V[end]
        for j in range(segs):
            p, q = grid[end][j], grid[end][(j + 1) % cols]
            uv_t = ((U[j] + U[j + 1]) / 2, vv)
            if end == 0:
                part.face((q, p, tip), [(U[j + 1], vv), (U[j], vv), uv_t], smooth)
            else:
                part.face((p, q, tip), [(U[j], vv), (U[j + 1], vv), uv_t], smooth)
    if not closed and thickness > 0:
        _shell_inside(part, rings, grid, thetas, segs, thickness, lining or uv, smooth)
    return grid


def _shell_inside(part, rings, grid, thetas, segs, t, uv, smooth):
    """The inside of an open shell, plus the rims that join it to the outside."""
    u0, v0, u1, v1 = uv
    inner = []
    for i, r in enumerate(rings):
        row = []
        for j in range(segs + 1):
            o = part.verts[grid[i][j]]
            radial = (o - r["c"])
            radial = radial - r["x"].cross(r["y"]).normalized() * radial.dot(r["x"].cross(r["y"]).normalized())
            row.append(part.vert(o - radial.normalized() * t, r["w"]))
        inner.append(row)
    n = len(rings)
    U = [u0 + (u1 - u0) * j / segs for j in range(segs + 1)]
    V = [v0 + (v1 - v0) * i / max(1, n - 1) for i in range(n)]
    for i in range(n - 1):
        for j in range(segs):
            a, b, c, d = inner[i][j], inner[i][j + 1], inner[i + 1][j + 1], inner[i + 1][j]
            part.face((d, c, b, a), [(U[j], V[i + 1]), (U[j + 1], V[i + 1]), (U[j + 1], V[i]), (U[j], V[i])], smooth)
    rim = (u0, v0)
    # Front edges (the two ends of the arc) and the bottom / top hems.
    for i in range(n - 1):
        o0, o1, i0, i1 = grid[i][0], grid[i + 1][0], inner[i][0], inner[i + 1][0]
        part.face((o1, o0, i0, i1), [rim] * 4, False)
        o0, o1, i0, i1 = grid[i][segs], grid[i + 1][segs], inner[i][segs], inner[i + 1][segs]
        part.face((o0, o1, i1, i0), [rim] * 4, False)
    for j in range(segs):
        o0, o1, i0, i1 = grid[0][j], grid[0][j + 1], inner[0][j], inner[0][j + 1]
        part.face((o0, i0, i1, o1), [rim] * 4, False)
        o0, o1, i0, i1 = grid[-1][j], grid[-1][j + 1], inner[-1][j], inner[-1][j + 1]
        part.face((o1, i1, i0, o0), [rim] * 4, False)


def frame_along(direction, up_hint):
    """Ring axes (x, y) for a loft heading along `direction`, with y as close to up_hint as possible."""
    a = Vector(direction).normalized()
    y = Vector(up_hint) - a * Vector(up_hint).dot(a)
    if y.length < 1e-5:
        y = a.orthogonal()
    y.normalize()
    x = y.cross(a)
    return x, y


def strand(part, points, widths, depth, uv, w, up=(0, 0, 1), sides=4, start=-90.0, smooth=True):
    """A tapering lock of hair (or strap, or blade): a loft along `points`, flat-ish
    (`widths` across, `depth` times that through), closing to a point at the end."""
    rings = []
    pts = [Vector(p) for p in points]
    for k, p in enumerate(pts):
        d = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)])
        x, y = frame_along(d, up)
        wk = widths[k]
        rings.append({"c": p, "x": x, "y": y, "rx": wk, "ry": max(wk * depth, 0.002), "n": 2.0,
                      "w": w if isinstance(w, dict) else w(k / max(1, len(pts) - 1))})
    if widths[-1] <= 1e-4:
        tip = rings.pop()  # the last point is the tip: the end cap reaches out to it
        rings[-1] = dict(rings[-1], cap_len=(tip["c"] - rings[-1]["c"]).length)
    return loft(part, rings, sides, uv, start=start, cap0="pole", cap1="pole", smooth=smooth)


def mirror_part(part, src_range):
    """Adds a left/right mirror copy of the faces built in `src_range` (vertex count before/after),
    swapping _L/_R weights."""
    v_start, v_end, f_start, f_end = src_range
    remap = {}
    for i in range(v_start, v_end):
        co = part.verts[i]
        w = {(k[:-1] + ("L" if k.endswith("R") else "R")) if k[-2:] in ("_L", "_R") else k: v
             for k, v in part.weights[i].items()}
        remap[i] = part.vert((-co.x, co.y, co.z), w)
    for f in range(f_start, f_end):
        idx = [remap[i] for i in reversed(part.faces[f])]
        part.face(idx, list(reversed(part.uvs[f])), part.smooth[f])


def mark(part):
    return (len(part.verts), len(part.faces))


def to_object(part, name, arm, material):
    """Builds the mesh object, skinned to `arm` with the weights gathered on the way."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in part.verts], [], part.faces)
    me.update()
    uvl = me.uv_layers.new(name="UVMap")
    k = 0
    for poly, uvs in zip(me.polygons, part.uvs):
        for li, uvc in zip(poly.loop_indices, uvs):
            uvl.data[li].uv = uvc
        k += 1
    for poly, sm in zip(me.polygons, part.smooth):
        poly.use_smooth = sm
    me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if arm is not None:
        ob.parent = arm
        mod = ob.modifiers.new("Armature", 'ARMATURE')
        mod.object = arm
        groups = {}
        for vi, w in enumerate(part.weights):
            items = sorted(w.items(), key=lambda kv: -kv[1])[:4]
            total = sum(v for _, v in items) or 1.0
            for bone, val in items:
                if bone not in groups:
                    groups[bone] = ob.vertex_groups.new(name=bone)
                groups[bone].add([vi], val / total, 'REPLACE')
    return ob


def transform_part(part, matrix, since=0):
    """Moves/turns the vertices added since vertex index `since` (e.g. to hang a sword grip-up
    on the back: build it grip-at-origin, then turn and shift it here)."""
    for i in range(since, len(part.verts)):
        part.verts[i] = matrix @ part.verts[i]
