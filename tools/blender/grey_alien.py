"""The Grey: the alien in Aeneas's first dream (he wakes in the night and it is looking at him).
A classic Grey, stylised: about 1.31 m, a big bulbous cranium over a small pointed chin, huge black
almond eyes (their own little lens meshes, glossy with a painted glint), two nose slits and a slit
of a mouth, a thin neck, narrow shoulders, faint ribs, thin limbs and long three-fingered hands
with a thumb. Smooth cool-grey skin. One 128 px texture. Its clips: grey_alien_anims.py.

Its proportions are not human, so it has its own joint layout (LAYOUT below) on the shared bone
names (rig.py). Rebuild:  .\\tools\\blender\\rebuild.ps1 grey_alien    (Godot closed)
"""
import json
import math
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Vector  # noqa: E402
import rig as rigmod          # noqa: E402
import character_base as cb   # noqa: E402
import base_body as bb        # noqa: E402
import body                   # noqa: E402
import mesh                   # noqa: E402
import grey_alien_anims       # noqa: E402
from paint import rgb, shade  # noqa: E402

HEIGHT = 1.31
S = HEIGHT / 1.72           # body.* helpers take shapes for a 1.72 m body; ours are in real metres
GLOW = 0.14                 # faint self-light (the eyes' glint shows in a dark room); 0 = none
C = {k: rgb(v) for k, v in {"skin": "#9ba2a6", "skin_dk": "#7d8489", "skin_hi": "#aeb5b8",
                            "eye": "#07080b", "eye_lo": "#141a26", "glint": "#d4dcea", "glint2": "#4c586c"}.items()}

# Joints (real metres; x = its right, y = forward, z = up). Short legs, a long thin trunk, long arms.
ARM_ANGLE = 62.0


def layout(height=HEIGHT, shoulders=1.0, hips=1.0):
    V = Vector
    J = {"height": HEIGHT, "hips": V((0, 0, 0.58)), "spine": V((0, 0, 0.67)), "chest": V((0, 0, 0.78)),
         "neck": V((0, -0.012, 0.93)), "head": V((0, -0.01, 1.0)), "head_top": V((0, -0.02, 1.31)),
         "clavicle": V((0.02, 0, 0.905)), "shoulder": V((0.112, -0.005, 0.905)),
         "hip_joint": V((0.058, 0, 0.555)), "knee": V((0.064, 0.012, 0.305)), "ankle": V((0.066, -0.012, 0.062)),
         "toe": V((0.066, 0.10, 0.018))}
    a = math.radians(ARM_ANGLE)
    J["elbow"] = J["shoulder"] + V((math.cos(a), -0.03, -math.sin(a))).normalized() * 0.27
    J["wrist"] = J["elbow"] + V((math.cos(a), 0.06, -math.sin(a))).normalized() * 0.26
    J["hand_tip"] = J["wrist"] + V((math.cos(a) * 0.95, 0.06, -math.sin(a))).normalized() * 0.21
    return J


# The skull, chin first: (z above the head joint, forward offset, half width, front, back, squareness).
SKULL = [(-0.015, 0.075, 0.012, 0.010, 0.010, 2.0), (0.000, 0.066, 0.030, 0.022, 0.030, 2.2),
         (0.026, 0.050, 0.046, 0.040, 0.046, 2.2), (0.055, 0.036, 0.063, 0.057, 0.061, 2.3),
         (0.085, 0.025, 0.080, 0.071, 0.076, 2.4), (0.115, 0.018, 0.096, 0.081, 0.091, 2.4),
         (0.150, 0.010, 0.110, 0.087, 0.111, 2.4), (0.190, 0.000, 0.118, 0.089, 0.128, 2.3),
         (0.230, -0.010, 0.114, 0.082, 0.132, 2.2), (0.265, -0.020, 0.095, 0.064, 0.115, 2.1),
         (0.292, -0.028, 0.062, 0.040, 0.078, 2.0), (0.308, -0.032, 0.020, 0.014, 0.025, 2.0)]
# The eyes: centre (angle, height on the skull), half length, half height, tilt (outer corner up).
EYE = {"th": 33.0, "z": 0.112, "len": 0.046, "h": 0.026, "tilt": 26.0, "bulge": 0.011}
TORSO = [(0.50, 0.050, 0.040, 0.045, 2.2), (0.54, 0.085, 0.055, 0.060, 2.3), (0.60, 0.090, 0.058, 0.060, 2.4),
         (0.66, 0.077, 0.060, 0.054, 2.4), (0.72, 0.081, 0.057, 0.055, 2.4), (0.79, 0.095, 0.058, 0.058, 2.5),
         (0.86, 0.106, 0.054, 0.057, 2.5), (0.905, 0.110, 0.046, 0.050, 2.4), (0.935, 0.084, 0.036, 0.040, 2.2),
         (0.955, 0.030, 0.025, 0.028, 2.0)]
ARM = [(-0.03, 0.024, 0.025), (0.08, 0.026, 0.028), (0.4, 0.023, 0.024), (0.85, 0.018, 0.019), (1.0, 0.019, 0.020),
       (1.12, 0.020, 0.021), (1.5, 0.016, 0.017), (1.95, 0.013, 0.011)]
LEG = [(-0.15, 0.046, 0.046), (0.0, 0.046, 0.048), (0.4, 0.036, 0.038), (0.88, 0.027, 0.028), (1.0, 0.029, 0.031),
       (1.3, 0.030, 0.032, 0.036), (1.7, 0.022, 0.024), (2.0, 0.018, 0.019)]
FOOT = [(-0.04, 0.020, 0.022, -0.020), (0.0, 0.026, 0.030, -0.018), (0.05, 0.030, 0.020, -0.031),
        (0.10, 0.027, 0.013, -0.041), (0.13, 0.017, 0.008, -0.046)]
# Fingers: (offset across the palm toward the thumb, length, spread); then the thumb.
FINGERS = [(0.014, 0.112, 0.010), (0.0, 0.124, 0.0), (-0.014, 0.106, -0.012)]


def scaled(rows, n_len):
    """Real-metre rows -> the 1.72 m units body.* helpers expect (the first n_len numbers)."""
    return [tuple(v / S if i < n_len else v for i, v in enumerate(r)) for r in rows]


def neck(P, J, rect):
    rings = []
    for z, r, w in ((0.89, 0.032, {"Chest": 1.0}), (0.935, 0.024, {"Neck": 1.0}), (1.0, 0.023, {"Neck": 0.5, "Head": 0.5}),
                    (1.06, 0.022, {"Head": 1.0}), (1.09, 0.020, {"Head": 1.0})):
        rings.append({"c": Vector((0, -0.012 + (z - 0.89) * 0.05, z)), "x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)),
                      "rx": r, "ry": r * 0.95, "n": 2.0, "w": w})
    mesh.loft(P, rings, 10, rect.uv)


def eye_point(head, side, s, t, lift_scale=1.0):
    """A point on the right (side 1) or left (-1) eye: s -1..1 inner to outer corner, t -1..1 across."""
    e = EYE
    a = math.radians(e["tilt"])
    h = e["h"] * max(0.0, 1 - s * s) ** 0.55 * (0.86 + 0.18 * s)
    along, across = s * e["len"], t * h
    dx, dz = along * math.cos(a) - across * math.sin(a), along * math.sin(a) + across * math.cos(a)
    th_c = 90.0 - side * e["th"]
    rad = (head.surface(th_c, e["z"]) - Vector((0, 0, head.surface(th_c, e["z"]).z))).length * 0.9
    th = th_c - side * math.degrees(dx / rad)
    bulge = e["bulge"] * math.sqrt(max(0.0, 1 - s * s)) * math.sqrt(max(0.0, 1 - t * t)) * lift_scale
    return head.surface(th, e["z"] + dz, -0.0015 + bulge)


def eyes(P, head, rect):
    """Two black almond lenses, a little proud of the face; the glint sits the same way on both."""
    w = {"Head": 1.0}
    NS, NT = 8, 4
    for side in (1, -1):
        grid = [[eye_point(head, side, -1 + 2 * i / NS, -1 + 2 * j / NT) for j in range(NT + 1)] for i in range(NS + 1)]
        xs = [p.x for row in grid for p in row]
        zs = [p.z for row in grid for p in row]
        x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
        ids = [[P.vert(p, w) for p in row] for row in grid]
        centre = sum((p for row in grid for p in row), Vector()) / ((NS + 1) * (NT + 1))
        out = (centre - Vector((0, -0.01, 1.0 + EYE["z"]))).normalized()

        def uv(p):
            u = (p.x - x0) / (x1 - x0)
            v = (p.z - z0) / (z1 - z0)
            return (rect.uv[0] + (rect.uv[2] - rect.uv[0]) * u, rect.uv[1] + (rect.uv[3] - rect.uv[1]) * v)
        for i in range(NS):
            for j in range(NT):
                q = [ids[i][j], ids[i + 1][j], ids[i + 1][j + 1], ids[i][j + 1]]
                pts = [P.verts[k] for k in q]
                if (pts[1] - pts[0]).cross(pts[3] - pts[0]).dot(out) < 0:
                    q.reverse()
                P.face(q, [uv(P.verts[k]) for k in q])


def hand(P, J, rect):
    """The right hand, open and relaxed: a slim palm, three long fingers with round pads, a thumb."""
    wrist, tip = J["wrist"], J["hand_tip"]
    d = (tip - wrist).normalized()
    y = Vector((0, 1, 0)) - d * d.y
    y.normalize()                       # the thumb side
    palm = y.cross(d)                   # toward the palm (the back of the hand faces away)
    rings = []
    for t, th, wd in ((-0.012, 0.010, 0.015), (0.015, 0.011, 0.019), (0.05, 0.010, 0.023), (0.078, 0.009, 0.022),
                      (0.088, 0.006, 0.016)):
        w = {"Hand_R": 1.0} if t > 0.01 else {"Hand_R": 0.6, "LowerArm_R": 0.4}
        rings.append({"c": wrist + d * t, "x": palm, "y": y, "rx": th, "ry": wd, "n": 2.4, "w": w})
    mesh.loft(P, rings, 8, rect.uv, cap1="pole")
    hw = {"Hand_R": 1.0}
    for off, length, spread in FINGERS:
        root = wrist + d * 0.072 + y * off
        fr = (0.0, 0.4, 0.78, 0.92, 1.0)
        pts = [root + d * length * f + palm * 0.022 * f * f + y * spread * f for f in fr]
        mesh.strand(P, pts, [0.0062, 0.0052, 0.0052, 0.0074, 0.0], 0.85, rect.uv, hw, up=palm, sides=5)
    base = wrist + d * 0.02 + y * 0.02
    pts = [base + (d * 0.55 + y * 0.8).normalized() * k + palm * 0.01 * k / 0.07 for k in (0.0, 0.035, 0.06, 0.07)]
    mesh.strand(P, pts, [0.0068, 0.0058, 0.0072, 0.0], 0.85, rect.uv, hw, up=palm, sides=5)


def paint_head(head, r):
    img = r.atlas.img
    r.vgrad(C["skin_dk"] * 0.5 + C["skin"] * 0.5, C["skin_hi"])
    e = EYE
    a = math.radians(e["tilt"])
    for col in range(r.w):
        u = (col + 0.5) / r.w
        f = u / 0.6 if u < 0.2 else ((u - 0.2) / 1.8 + 1 / 3 if u < 0.8 else (u - 0.8) / 0.6 + 2 / 3)
        th = f * 360.0 - 90.0
        for row in range(r.h):
            z = bb._z_of_v(head, 1 - (row + 0.5) / r.h)
            for side in (1, -1):
                # where this texel sits in the eye's own frame (the socket shadow round the lens)
                dx = -side * math.radians(th - (90.0 - side * e["th"])) * 0.085
                dz = z - e["z"]
                along = (dx * math.cos(a) + dz * math.sin(a)) / (e["len"] * 1.3)
                across = (-dx * math.sin(a) + dz * math.cos(a)) / (e["h"] * 1.55)
                k = along * along + across * across
                if k < 1.0:
                    img[r.y + row, r.x + col] = img[r.y + row, r.x + col] * (0.87 + 0.13 * k)
    for side in (1, -1):    # nose slits and the thin mouth
        x, y = r.px(*head.uv(90 - side * 4.5, 0.060))
        img[y, x] = C["skin_dk"] * 0.55
        x0, my = r.px(*head.uv(90 - side * 8, 0.031))
        x1, _ = r.px(*head.uv(90, 0.031))
        img[my, min(x0, x1):max(x0, x1) + 1] = C["skin_dk"] * 0.7


def paint_eye(r):
    r.vgrad(C["eye_lo"], C["eye"])
    r.box(0.40, 0.60, 0.48, 0.70, C["glint"])     # the glint (top middle, the same on both eyes)
    r.dot(0.58, 0.36, C["glint2"])                 # a faint second reflection


def paint_torso(r, rows):
    r.fill(C["skin"])
    zs = [z for z, *_ in rows]
    lens = [0.0]
    for a, b in zip(zs, zs[1:]):
        lens.append(lens[-1] + (b - a))

    def v_of(z):
        for i in range(len(zs) - 1):
            if zs[i] <= z <= zs[i + 1]:
                return (lens[i] + (z - zs[i])) / lens[-1]
        return 1.0
    for z in (0.75, 0.79, 0.83):            # faint ribs on the flanks, sloping down toward the front
        for u0, u1 in ((0.29, 0.41), (0.71, 0.59)):
            n = 8
            for k in range(n + 1):
                u = u0 + (u1 - u0) * k / n
                r.dot(u, v_of(z - 0.02 * k / n), C["skin"] * 0.93)


def build():
    rigmod.layout = layout              # this body's own joints, on the shared bone names
    ch = cb.Character("grey_alien", height=HEIGHT, atlas_size=128)
    J, A, P = ch.J, ch.atlas, ch.part("Body")
    r_head, r_torso = A.rect("head", 64, 48), A.rect("torso", 32, 32)
    r_arm, r_leg, r_eye = A.rect("arm", 24, 16), A.rect("leg", 24, 16), A.rect("eye", 24, 12)
    r_hand, r_foot, r_neck = A.rect("hand", 16, 8), A.rect("foot", 16, 8), A.rect("neck", 16, 8)
    head = body.Head(J, rows=SKULL, brow=0.0, scale=1.0)
    head.s = 1.0                        # SKULL is in real metres
    head.build(P, r_head, segs=24)
    eyes(P, head, r_eye)
    neck(P, J, r_neck)
    body.trunk(P, J, r_torso, scaled(TORSO, 4), segs=14, cap0="pole")
    bb.mirrored(P, lambda: body.limb(P, J, body.arm_joints(J), ("UpperArm_R", "LowerArm_R"), r_arm,
                                     [(t, a / S, b / S) for t, a, b in ARM], segs=8,
                                     hand_bone="Hand_R", cap0="pole"))
    bb.mirrored(P, lambda: hand(P, J, r_hand))
    bb.mirrored(P, lambda: body.limb(P, J, body.leg_joints(J), ("UpperLeg_R", "LowerLeg_R"), r_leg,
                                     [tuple([r[0]] + [v / S for v in r[1:]]) for r in LEG], segs=8))
    bb.mirrored(P, lambda: body.foot(P, J, r_foot, rows=[(y / S, w / S, h / S, z / S) for y, w, h, z in FOOT], segs=8))
    paint_head(head, r_head)
    paint_eye(r_eye)
    paint_torso(r_torso, TORSO)
    for r in (r_arm, r_leg, r_neck):
        r.fill(C["skin"])
    r_hand.fill(C["skin"])
    r_foot.fill(C["skin"] * 0.92)
    return ch


def finish_files(ch):
    """Our touches on what finish() wrote: a tidy root name, and the faint glow in the material."""
    out = cb.OUT_DIR
    spec_path = os.path.join(out, "grey_alien.json")
    spec = json.load(open(spec_path))
    spec["root"] = "GreyAlienModel"
    with open(spec_path, "w", newline="\n") as f:
        json.dump(spec, f, indent=1)
    mat = os.path.join(out, "grey_alien_mat.tres")
    text = open(mat).read()
    if GLOW > 0:
        text += ('shader_parameter/emission_texture = ExtResource("2_atlas")\n'
                 'shader_parameter/emission_tint = Color(0.8, 0.88, 1, 1)\n'
                 'shader_parameter/emission_energy = %.3f\n' % GLOW)
    with open(mat, "w", newline="\n") as f:
        f.write(text)


if __name__ == "__main__":
    c = build()
    c.finish(animations=grey_alien_anims.add_all)
    finish_files(c)
