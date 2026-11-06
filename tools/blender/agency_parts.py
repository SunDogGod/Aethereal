"""Pieces the Agency's people share (agent.py, captain.py): the shell and plate builders, the
helmet with its glowing visor slit, the blade, and the weathering paint (dust at a hem, chips on
armour edges). Shapes are for a 1.72 m body and scale with the character's height.
"""
import math
import numpy as np
from mathutils import Vector
import body
import mesh
import props
from paint import rgb, shade

# The palette of the uniform (everything not tinted in the game).
C = {k: rgb(v) for k, v in {
    "helm": "#17181c", "helm_hi": "#30333a", "helm_edge": "#4c5058", "slot": "#050506",
    "plate": "#2b2e35", "plate_hi": "#555a63", "plate_dk": "#141519", "rivet": "#8a8f97", "mark": "#8e1a14",
    "suit": "#1c1d22", "leather": "#18181c", "leather_hi": "#2e2f35", "boot": "#131316", "sole": "#08080a",
    "buckle": "#7d828a", "steel": "#5b616a", "edge": "#d2d6dc", "grip": "#121214",
    "dust": "#8c8272", "scuff": "#3d3a36"}.items()}

# The helmet: (z above the head joint, forward offset, half width, front depth, back depth, squareness).
# Rows 5-6 are the recessed visor slit; row 7 the brow lip over it.
HELM = [(-0.040, -0.010, 0.064, 0.074, 0.100, 2.6), (-0.022, 0.000, 0.068, 0.088, 0.098, 2.8),
        (0.010, 0.008, 0.078, 0.104, 0.098, 3.0), (0.055, 0.010, 0.085, 0.108, 0.102, 3.0),
        (0.086, 0.010, 0.088, 0.108, 0.106, 2.9), (0.094, 0.004, 0.088, 0.098, 0.106, 2.9),
        (0.111, 0.004, 0.089, 0.098, 0.107, 2.9), (0.119, 0.010, 0.090, 0.111, 0.108, 2.8),
        (0.150, 0.004, 0.089, 0.104, 0.110, 2.6), (0.190, -0.004, 0.083, 0.090, 0.106, 2.4),
        (0.222, -0.010, 0.066, 0.068, 0.086, 2.2), (0.246, -0.016, 0.038, 0.040, 0.050, 2.0)]
SLIT_Z, SLIT_ARC = 0.1025, 54          # the visor bar: height on the helmet and half its sweep (degrees)


def at_z(profile, z):
    """A torso profile's (half width, front, back, squareness) at height z."""
    for a, b in zip(profile, profile[1:]):
        if a[0] <= z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return [a[i] + (b[i] - a[i]) * t for i in range(1, 5)]
    row = profile[0] if z < profile[0][0] else profile[-1]
    return list(row[1:5])


def shoulder_wf(w):
    """Like body.trunk: the outer shoulders of a garment follow the collarbones a little."""
    def wf(th):
        c = math.cos(math.radians(th))
        k = max(0.0, abs(c) - 0.55) / 0.45 * 0.6
        out = {b: v * (1 - k) for b, v in w.items()}
        out["Shoulder_R" if c > 0 else "Shoulder_L"] = k
        return out
    return wf


def lining_follows(part, grid):
    """An open shell's inside (made by mesh.loft right after the outside) takes the same bone
    weights as the outside, so a hem that rides on a thigh or an arm doesn't leave its lining behind."""
    n = sum(len(row) for row in grid)
    start = len(part.verts) - n
    k = 0
    for row in grid:
        for v in row:
            part.weights[start + k] = dict(part.weights[v])
            k += 1


def shell(part, J, rect, rows, segs=16, thickness=0.0, lining=None, cap0=None, r=None, weights=None, arcs=None, wf=None,
          rz=None):
    """A trunk-shaped loft (body.trunk with extras): rows (z, rx, ry front, ry back, n[, dy]);
    r(theta) shapes the ring (or rz(z) gives each ring its own r: folds that deepen toward a hem),
    weights(z) overrides the spine weights, arcs[i] makes an open shell, wf(z, w) gives a per-angle
    weight function for the ring at height z (w: its spine weights)."""
    s = J["height"] / 1.72
    rings = []
    for i, row in enumerate(rows):
        z = row[0] * s
        w = weights(row[0]) if weights else body.spine_w(J, z)
        g = {"c": Vector((0, (row[5] if len(row) > 5 else 0.0) * s, z)), "x": Vector((1, 0, 0)), "y": body.FWD,
             "rx": row[1] * s, "ry": row[2] * s, "ryb": row[3] * s, "n": row[4], "w": w}
        if r:
            g["r"] = r
        if rz:
            g["r"] = rz(row[0])
        if arcs:
            g["arc"] = arcs[i]
        if wf:
            g["wf"] = wf(row[0], w)
        elif weights is None and z > J["shoulder"].z - 0.07 * s:
            g["wf"] = shoulder_wf(w)
        rings.append(g)
    grid = mesh.loft(part, rings, segs, rect.uv, arc=arcs[0] if arcs else None, thickness=thickness,
                     lining=lining.uv if lining else None, cap0=cap0)
    if arcs and thickness > 0:
        lining_follows(part, grid)
    return grid


def limb_shell(part, J, joints, bones, rect, rows, arc, segs=8, thickness=0.006, lining=None):
    """An armour plate wrapped part way round an arm or leg (rows like body.limb, arc in degrees:
    90 = the front of a leg / the thumb side of an arm, 180 = the outside of a right arm)."""
    s = J["height"] / 1.72
    rings = []
    for t, rx, ry in rows:
        p, d = body._chain(J, *joints, t)
        x, y = mesh.frame_along(d, body.FWD)
        k = min(1.0, max(0.0, (t - 0.85) / 0.3))
        rings.append({"c": p, "x": x, "y": y, "rx": rx * s, "ry": ry * s, "n": 2.0,
                      "w": {bones[0]: 1 - k, bones[1]: k} if 0 < k < 1 else {bones[0 if k == 0 else 1]: 1.0}})
    mesh.loft(part, rings, segs, rect.uv, arc=arc, thickness=thickness * s, lining=(lining or rect).uv)


def box(part, centre, half, rect, w, axes=(Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))):
    """A small box (buckle, pouch, guard) with outward faces; axes turn it."""
    ax, ay, az = axes
    v = [part.vert(centre + ax * (half[0] * sx) + ay * (half[1] * sy) + az * (half[2] * sz), w)
         for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]   # 0..3 bottom, 4..7 top (x fastest)
    u0, v0, u1, v1 = rect.uv
    uv = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
    for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (3, 2, 6, 7), (2, 0, 4, 6), (1, 3, 7, 5)):
        part.face([v[i] for i in f], uv, False)


def left_only(part, build):
    """Runs build() (which adds right-side geometry) and keeps only its mirror on the left: the
    captain's one arm."""
    v0, f0 = mesh.mark(part)
    build()
    v1, f1 = mesh.mark(part)
    mesh.mirror_part(part, (v0, v1, f0, f1))
    del part.faces[f0:f1], part.uvs[f0:f1], part.smooth[f0:f1]   # the right side's verts are left unused


def pauldron(P, J, rect, lining, shoulders, size):
    """A shoulder dome: rings along an axis from beside the neck out over the right shoulder,
    covering the top, front and back (open underneath)."""
    s = J["height"] / 1.72
    base = Vector((0.10 * shoulders, -0.005, 1.43)) * s
    a = Vector((1.0, 0.0, -0.62)).normalized()
    x, y = mesh.frame_along(a, Vector((0, 0, 1)))   # x: forward, y: up and out
    rings = []
    for d, rx, ry in ((0.0, 0.070, 0.030), (0.035, 0.094, 0.062), (0.08, 0.106, 0.084), (0.13, 0.108, 0.090),
                      (0.17, 0.094, 0.080), (0.195, 0.05, 0.045)):
        w = ({"Chest": 0.5, "Shoulder_R": 0.5} if d < 0.06 else
             ({"Shoulder_R": 0.7, "UpperArm_R": 0.3} if d < 0.1 else {"Shoulder_R": 0.45, "UpperArm_R": 0.55}))
        rings.append({"c": base + a * d * s * size, "x": x, "y": y, "rx": rx * s * size, "ry": ry * s * size,
                      "n": 2.2, "w": w})
    mesh.loft(P, rings, 10, rect.uv, arc=(-28, 208), thickness=0.007 * s, lining=lining.uv)


def crest(P, head, rect, tall=1.0):
    """A ridge from the brow over the crown to the nape, sitting half into the helmet
    (tall > 1 raises it into a fin: the captain's)."""
    pts = [head.surface(th, z, 0.0) for th, z in ((90, 0.182), (90, 0.205), (90, 0.228), (270, 0.236), (270, 0.20),
                                                  (270, 0.14))]   # starts above the brow: the cult's eye sits there
    widths = [0.4, 0.85, 1.0, 1.0, 0.85, 0.4]
    rings = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, 5)] - pts[max(i - 1, 0)]).normalized()
        x = Vector((1, 0, 0))
        y = d.cross(x).normalized()
        rings.append({"c": p, "x": x, "y": y, "rx": 0.010 * head.s * widths[i],
                      "ry": 0.008 * head.s * widths[i] * tall, "ryb": 0.004 * head.s, "n": 2.0, "w": {"Head": 1.0},
                      "cap_len": 0.004 * head.s})
    mesh.loft(P, rings, 6, rect.uv, cap0="pole", cap1="pole")


def disc(P, head, rect):
    """A round plate on the right side of the helmet (a comm unit)."""
    c = head.surface(0.0, 0.07, -0.004)
    out = Vector((1, -0.1, 0)).normalized()
    x, y = mesh.frame_along(out, Vector((0, 0, 1)))
    r = 0.024 * head.s
    rings = [{"c": c + out * o * head.s, "x": x, "y": y, "rx": rr * head.s, "ry": rr * head.s, "n": 2.0,
              "w": {"Head": 1.0}, "cap_len": 0.0} for o, rr in ((0.0, r / head.s * 1.05), (0.012, r / head.s))]
    mesh.loft(P, rings, 8, rect.uv, cap1="pole")


def visor(ch, head, rect):
    """The glowing slit: a thin bar set into the helmet's groove, on the Head bone (guard.gd finds
    the mesh called Visor and sets its colour and glow)."""
    part = ch.prop("Visor", "Head", "HeadGear")
    to_bone = ch.arm.data.bones["Head"].matrix_local.inverted()
    n = 9
    ths = [90 - SLIT_ARC + 2 * SLIT_ARC * i / (n - 1) for i in range(n)]
    pts = [to_bone @ head.surface(th, SLIT_Z, 0.002) for th in ths]
    outs = [to_bone.to_3x3() @ (head.surface(th, SLIT_Z, 0.02) - head.surface(th, SLIT_Z, 0.0)) for th in ths]
    rings = []
    for i, p in enumerate(pts):
        d = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        x, y = mesh.frame_along(d, outs[i])
        taper = 0.75 if i in (0, n - 1) else 1.0
        rings.append({"c": p, "x": x, "y": y, "rx": 0.0085 * head.s * taper, "ry": 0.0032 * head.s, "n": 2.6,
                      "w": {}, "cap_len": 0.003 * head.s})
    mesh.loft(part, rings, 6, rect.uv, cap0="pole", cap1="pole")
    rect.fill(rgb("#ffffff"))   # white: guard.gd tints it with GuardData.visor_color


def blade(p, atlas, length=0.78, grip=None, wrap=None, prefix="blade"):
    """The Agency blade: long, single-edged, widening toward a clipped point; square guard, long
    black grip, block pommel. Grip at the origin, blade along +Y, edge along +Z."""
    r_blade, r_hilt = atlas.rect(prefix, 48, 12), atlas.rect(prefix + "_hilt", 16, 12)
    r_guard = atlas.rect(prefix + "_guard", 8, 8)
    L = length
    props.rod(p, [(0.09, 0.024, 0.0075), (0.16, 0.027, 0.0070), (0.09 + L * 0.6, 0.031, 0.0062),
                  (0.09 + L * 0.86, 0.034, 0.0054), (0.09 + L * 0.95, 0.022, 0.0042, (0, 0, -0.011)),
                  (0.09 + L, 0.0, 0.0, (0, 0, -0.025))], r_blade.uv, sides=4, start=0.0, smooth=False)
    props.rod(p, [(-0.11, 0.0155, 0.0155), (0.0, 0.0165, 0.0165), (0.075, 0.0155, 0.0155)], r_hilt.uv, sides=6)
    box(p, Vector((0, 0.083, 0)), (0.013, 0.008, 0.055), r_guard, {})
    box(p, Vector((0, -0.122, 0)), (0.017, 0.014, 0.017), r_guard, {})
    st = C["steel"]
    r_blade.fill(st)
    r_blade.box(0.0, 0, 0.09, 1, C["edge"])     # the bright bevel along the edge (both flats)
    r_blade.box(0.91, 0, 1.0, 1, C["edge"])
    r_blade.vline(0.5, shade(st, 0.6), 1)        # the spine
    r_blade.box(0, 0, 1, 0.05, shade(st, 0.7))
    for u, v in ((0.3, 0.2), (0.62, 0.55), (0.4, 0.8)):  # a few nicks in the old steel
        r_blade.dot(u, v, shade(st, 0.75))
    r_hilt.fill(grip if grip is not None else C["grip"])
    for k in range(5):
        r_hilt.hline(0.12 + k * 0.18, wrap if wrap is not None else C["leather_hi"])
    r_guard.fill(shade(C["plate"], 1.2))
    r_guard.hline(0.5, C["plate_hi"])


def paint_helm(R, head, crest_col=None):
    """The helmet: black with a dark slot for the visor, a brow-lip highlight, a breathing grille,
    cheek-plate seams and rivets, and a few scratches."""
    def hbox(th0, th1, z0, z1, col):
        u0, v0 = head.uv(th0, z0)
        u1, v1 = head.uv(th1, z1)
        R["helm"].box(min(u0, u1), min(v0, v1), max(u0, u1), max(v0, v1), col)
    R["helm"].fill(C["helm"])
    hbox(-89, 269, -0.040, -0.031, C["helm_edge"])                # bottom rim trim
    hbox(-89, 269, -0.030, -0.027, C["plate_dk"])
    hbox(34, 146, 0.088, 0.116, C["slot"])                         # the visor slot
    hbox(36, 144, 0.117, 0.121, C["helm_edge"])                     # light on the brow lip
    hbox(160, 200, 0.150, 0.172, shade(C["helm_hi"], 0.85))      # a sheen on each side of the dome
    hbox(-20, 20, 0.150, 0.172, shade(C["helm_hi"], 0.85))
    for th in (82, 90, 98):                                         # breathing grille under the slit
        hbox(th - 1.2, th + 1.2, 0.014, 0.060, C["helm_hi"])
    for side in (1, -1):                                            # cheek plate seams and rivets
        for k in range(8):
            z = 0.082 - k * 0.013
            th = 90 + side * (40 + k * 2.2)
            hbox(th - 0.8, th + 0.8, z - 0.006, z + 0.006, C["helm_edge"])
        hbox(90 + side * 30 - 1, 90 + side * 30 + 1, 0.0, 0.006, C["rivet"])
    for th, z in ((128, 0.17), (232, 0.13), (300, 0.19), (20, 0.05)):   # old scratches
        hbox(th - 2.5, th + 2.5, z, z + 0.004, C["helm_edge"])
    hbox(56, 124, 0.126, 0.129, C["helm_edge"])                    # the brow plate's lower seam
    hbox(60, 120, 0.176, 0.179, C["helm_edge"])                    # and its upper seam
    for th in (62, 118):
        hbox(th - 1, th + 1, 0.150, 0.156, C["rivet"])
    # The cult's eye on the brow plate, between the visor lip and the crest.
    import agency_marks
    u, v = head.uv(90, 0.152)
    u1, v1 = head.uv(104, 0.178)
    agency_marks.eye_mark(R["helm"], u, v, max(5, round((u1 - u) * R["helm"].w)), max(4, round((v1 - v) * R["helm"].h)),
                          C["mark"], C["mark"], C["helm"])
    R["crest"].fill(crest_col if crest_col is not None else C["helm_hi"])


# ---------------------------------------------------------------- weathering
def weather(rect, top, dust, grime=None, seed=1, waves=3, strength=0.6, flip=False):
    """Dust climbing a hem: a soft, ragged band up to about v = top (0..1 of the block), in two flat
    steps so it stays crisp, mixed over what's painted (seams still show through), with a darker
    line of grime at the very edge. Low contrast on purpose: worn, not noisy. flip: the hem is at
    the block's top (v = 1), e.g. a sleeve's cuff or a boot's foot end."""
    rng = np.random.RandomState(seed)
    img = rect.atlas.img
    ph = rng.uniform(0, math.tau, 3)
    dust, grime = np.asarray(dust), np.asarray(grime if grime is not None else shade(dust, 0.7))
    chunk = max(2, rect.w // 16)
    jit = rng.uniform(-0.12, 0.12, rect.w // chunk + 1)
    for col in range(rect.w):
        f = col / rect.w
        t = top * (1 + 0.13 * math.sin(math.tau * f * waves + ph[0]) + 0.07 * math.sin(math.tau * f * waves * 2.3 + ph[1])
                   + 0.5 * jit[col // chunk])
        g = top * 0.22 * (1 + 0.4 * math.sin(math.tau * f * 5 + ph[2]))
        for row in range(rect.h):
            v = (row + 0.5) / rect.h if flip else 1 - (row + 0.5) / rect.h
            if v > t:
                continue
            a = strength if v < t * 0.55 else strength * 0.5
            c = grime if v < g else dust
            px = img[rect.y + row, rect.x + col]
            img[rect.y + row, rect.x + col] = px * (1 - a) + c * a


def chips(rect, color, count=8, seed=2, v_range=(0.0, 1.0)):
    """A few bright chips knocked into painted metal (armour edges, old plate)."""
    rng = np.random.RandomState(seed)
    for _ in range(count):
        rect.dot(rng.uniform(0.02, 0.98), rng.uniform(*v_range), color)
