"""Kael, a wandering swordsman in his twenties: taller and leaner than Aeneas. A long white coat
(tall collar, red lining and trim, a skirt split front and back down to the knee) cinched with a
red sash, a red scarf, a black undershirt, dark trousers, tall black boots, black gloves, and
silver-white hair to the jaw. Lamento, a long bone-white blade with a ring pommel and a red
tassel, rides on his back with the grip over his right shoulder, on a black strap.

Knobs: colours are the C table below; shapes are the profile tables (one row per ring, height
first, then radii); hair is HAIR; where Lamento hangs is LAMENTO_GRIP / LAMENTO_DIR. The sword's
own shape and the face / clothes paint are in kael_gear.py.
Rebuild:  .\\tools\\blender\\rebuild.ps1 kael     (see tools/blender/README.md)
"""
import math
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Matrix, Vector  # noqa: E402
import character_base as cb   # noqa: E402
import base_body as bb        # noqa: E402
import body                   # noqa: E402
import mesh                   # noqa: E402
import kael_anims             # noqa: E402
import kael_gear as gear      # noqa: E402
from paint import rgb         # noqa: E402

C = {k: rgb(v) for k, v in {
    "skin": "#dfae8c", "hair": "#d9dbe2", "hair_dark": "#a3a7b6", "hair_light": "#f3f4f8",
    "eye": "#25232b", "iris": "#7a8a9c", "lash": "#3a2f35", "lip": "#a8705f", "brow": "#8b8e9c",
    "coat": "#e4e1d9", "coat_line": "#bdb8ae", "red": "#a9212e", "lining": "#741520",
    "shirt": "#1d1c22", "trousers": "#2a2a31", "boot": "#1b1a1f", "boot_top": "#302f36", "sole": "#0e0e11",
    "glove": "#232228", "strap": "#26201f", "silver": "#b8bcc6",
    "bone": "#e6dcc3", "bone_edge": "#f7f2e6", "bone_dark": "#bfb291", "iron": "#5c5e68",
    "wrap": "#8a1a24", "wrap_dark": "#2e0b10"}.items()}

# Profiles are rows for a 1.72 m body (Character scales them to his 1.82 m).
# The black undershirt (the torso): lean, a narrow waist under broad shoulders.
TORSO = [(0.86, 0.12, 0.075, 0.080, 2.2), (0.92, 0.150, 0.088, 0.094, 2.5), (0.99, 0.138, 0.086, 0.090, 2.5),
         (1.06, 0.128, 0.085, 0.083, 2.5), (1.15, 0.145, 0.098, 0.090, 2.6), (1.24, 0.162, 0.106, 0.096, 2.6),
         (1.31, 0.180, 0.100, 0.097, 2.7), (1.36, 0.196, 0.086, 0.090, 2.8), (1.395, 0.160, 0.070, 0.076, 2.6),
         (1.425, 0.092, 0.058, 0.060, 2.2), (1.44, 0.058, 0.050, 0.052, 2.0)]
# The coat above the sash: (height, half width, front, back, squareness, forward shift, V half-angle).
COAT = [(0.94, 0.152, 0.098, 0.102, 2.5, 0.0, 0), (0.99, 0.150, 0.098, 0.100, 2.5, 0.0, 0),
        (1.06, 0.142, 0.098, 0.096, 2.5, 0.0, 1), (1.15, 0.158, 0.110, 0.101, 2.6, 0.0, 9),
        (1.24, 0.175, 0.118, 0.107, 2.7, 0.0, 17), (1.31, 0.193, 0.112, 0.108, 2.8, 0.0, 23),
        (1.36, 0.212, 0.098, 0.103, 2.9, 0.0, 28), (1.395, 0.176, 0.083, 0.090, 2.7, 0.0, 33),
        (1.425, 0.112, 0.071, 0.075, 2.3, 0.0, 40)]
# Tall stand collar, open at the front (last number), white inside and out with a red edge.
COLLAR = [(1.40, 0.114, 0.084, 0.088, 2.2, -0.004, 46), (1.45, 0.092, 0.074, 0.079, 2.0, -0.006, 48),
          (1.495, 0.092, 0.078, 0.083, 2.0, -0.009, 52), (1.525, 0.097, 0.085, 0.089, 2.0, -0.011, 56)]
# The skirt, hem first: (height, half width, front, back, squareness, front split, back slit) in degrees.
SKIRT = [(0.47, 0.236, 0.156, 0.172, 2.2, 9, 4), (0.58, 0.230, 0.150, 0.165, 2.2, 7, 3),
         (0.70, 0.222, 0.142, 0.155, 2.25, 5, 2), (0.82, 0.212, 0.132, 0.142, 2.3, 3, 1),
         (0.92, 0.196, 0.118, 0.126, 2.4, 1, 1), (1.00, 0.160, 0.102, 0.106, 2.5, 1, 1)]
SASH = [(0.928, 0.204, 0.125, 0.132, 2.5), (0.975, 0.186, 0.116, 0.121, 2.5), (1.025, 0.165, 0.107, 0.109, 2.5)]
SCARF = [(1.375, 0.100, 0.095, 0.080, 2.2, 0.012), (1.405, 0.090, 0.091, 0.072, 2.1, 0.012),
         (1.435, 0.078, 0.083, 0.066, 2.0, 0.008), (1.462, 0.068, 0.073, 0.060, 2.0, 0.004)]
SLEEVE = [(0.0, 0.064, 0.066), (0.25, 0.060, 0.062), (0.7, 0.053, 0.055), (1.0, 0.050, 0.051), (1.3, 0.051, 0.053),
          (1.72, 0.047, 0.049), (1.80, 0.054, 0.056), (2.0, 0.056, 0.058)]
TROUSERS = [(-0.15, 0.080, 0.086), (0.0, 0.082, 0.088), (0.3, 0.074, 0.079), (0.7, 0.062, 0.066),
            (1.0, 0.054, 0.057), (1.2, 0.054, 0.058, 0.062), (1.6, 0.047, 0.050), (2.0, 0.043, 0.045)]
BOOT = [(1.16, 0.065, 0.067, 0.071), (1.20, 0.066, 0.068, 0.072), (1.23, 0.060, 0.063, 0.067),
        (1.45, 0.058, 0.061, 0.065), (1.7, 0.053, 0.056, 0.057), (1.88, 0.051, 0.055, 0.052), (2.02, 0.051, 0.056, 0.051)]
FOOT = [(-0.09, 0.034, 0.038, -0.034), (-0.065, 0.045, 0.056, -0.024), (0.0, 0.049, 0.062, -0.018),
        (0.075, 0.051, 0.042, -0.040), (0.14, 0.050, 0.031, -0.052), (0.20, 0.042, 0.024, -0.06)]
# A slightly longer, squarer-jawed face than Aeneas's (rows as body.HEAD_ROWS).
HEAD = [(0.000, 0.046, 0.033, 0.030, 0.028, 2.4), (0.016, 0.030, 0.055, 0.062, 0.050, 2.5),
        (0.044, 0.016, 0.066, 0.078, 0.072, 2.5), (0.074, 0.008, 0.072, 0.087, 0.088, 2.4),
        (0.103, 0.004, 0.076, 0.089, 0.097, 2.4), (0.135, 0.0, 0.077, 0.090, 0.101, 2.4),
        (0.170, -0.005, 0.074, 0.084, 0.100, 2.3), (0.203, -0.010, 0.063, 0.067, 0.084, 2.2),
        (0.229, -0.015, 0.039, 0.041, 0.050, 2.0)]
W5 = [0.042, 0.048, 0.042, 0.028, 0.0]
W4 = [0.042, 0.046, 0.034, 0.0]
# Hair locks: (angle round the head, height, lift) from root to tip; 90 = the face, 0 = his right.
HAIR = [
    ([(60, 0.228, 0), (80, 0.212, 0.024), (102, 0.170, 0.026), (117, 0.128, 0.018), (124, 0.100, 0.010)], W5),
    ([(90, 0.234, 0), (106, 0.212, 0.026), (126, 0.168, 0.026), (139, 0.128, 0.018), (146, 0.098, 0.010)], W5),
    ([(42, 0.224, 0), (55, 0.204, 0.022), (68, 0.166, 0.020), (75, 0.130, 0.010)], W4),
    ([(26, 0.214, 0), (20, 0.170, 0.018), (17, 0.110, 0.020), (19, 0.060, 0.020), (23, 0.030, 0.012)], W5),
    ([(154, 0.214, 0), (160, 0.170, 0.018), (163, 0.110, 0.022), (161, 0.060, 0.022), (157, 0.025, 0.012)], W5),
    ([(4, 0.222, 0), (-4, 0.180, 0.020), (-8, 0.120, 0.022), (-8, 0.070, 0.018)], W4),
    ([(176, 0.222, 0), (184, 0.180, 0.020), (188, 0.120, 0.022), (188, 0.070, 0.018)], W4),
    ([(300, 0.228, 0), (305, 0.180, 0.022), (310, 0.110, 0.022), (314, 0.050, 0.024), (317, 0.025, 0.022)], W5),
    ([(270, 0.226, 0), (270, 0.170, 0.022), (271, 0.100, 0.022), (270, 0.040, 0.024), (270, 0.015, 0.022)], W5),
    ([(240, 0.228, 0), (235, 0.180, 0.022), (230, 0.110, 0.022), (226, 0.050, 0.024), (223, 0.025, 0.022)], W5),
    ([(332, 0.222, 0), (338, 0.170, 0.020), (342, 0.100, 0.022), (344, 0.050, 0.020)], W4),
    ([(208, 0.222, 0), (202, 0.170, 0.020), (198, 0.100, 0.022), (196, 0.050, 0.020)], W4),
    ([(250, 0.236, 0), (262, 0.232, 0.022), (280, 0.205, 0.028), (290, 0.170, 0.022)], W4),
    ([(130, 0.236, 0), (150, 0.226, 0.024), (170, 0.196, 0.024), (180, 0.165, 0.014)], W4),
    ([(20, 0.232, 0), (6, 0.222, 0.022), (352, 0.196, 0.022), (346, 0.165, 0.012)], W4),
    ([(200, 0.238, 0), (214, 0.244, 0.030), (230, 0.228, 0.045)], [0.040, 0.034, 0.0]),
]
# Lamento on his back: grip centre, and the way the blade points (down, a little left and out).
LAMENTO_GRIP = (0.140, -0.150, 1.42)
LAMENTO_DIR = (-0.20, -0.09, -1.0)


def build():
    ch = cb.Character("kael", height=1.82, shoulders=1.06, hips=0.95)
    J, A, P = ch.J, ch.atlas, ch.part("Body")
    s = J["height"] / 1.72
    r = {n: A.rect(n, w, h) for n, w, h in (
        ("head", 128, 72), ("coat", 96, 56), ("skirt", 64, 48), ("sleeve", 64, 40), ("shirt", 48, 32),
        ("trousers", 48, 40), ("boot", 48, 32), ("foot", 40, 24), ("hair", 32, 32), ("collar", 48, 16),
        ("scarf", 48, 16), ("sash", 48, 8), ("sash_tail", 16, 24), ("hand", 24, 16), ("neck", 16, 12),
        ("lining", 8, 8), ("collar_in", 8, 8), ("strap", 8, 32))}
    body.trunk(P, J, r["shirt"], TORSO, cap0="pole")
    body.neck(P, J, r["neck"])
    head = body.Head(J, rows=HEAD, brow=0.005, scale=1.06)
    head.build(P, r["head"])
    body.nose(P, head, r["head"], length=0.024)
    gear.paint_face(head, r["head"], C)
    for path, widths in HAIR:
        _lock(P, head, r["hair"], path, widths)
    body.trunk(P, J, r["coat"], COAT, segs=18, arc=(90, 450), thickness=0.008, lining=r["lining"])
    body.trunk(P, J, r["collar"], COLLAR, segs=12, arc=(142, 398), thickness=0.007, lining=r["collar_in"])
    bb.mirrored(P, lambda: _skirt_panel(P, J, r["skirt"], r["lining"]))
    body.trunk(P, J, r["sash"], SASH, segs=16)
    _sash_knot(P, J, r["sash_tail"])
    _scarf(P, J, r["scarf"])
    bb.mirrored(P, lambda: body.limb(P, J, body.arm_joints(J), ("UpperArm_R", "LowerArm_R"), r["sleeve"],
                                     SLEEVE, hand_bone="Hand_R", cap0="pole", cap1="pole"))
    bb.mirrored(P, lambda: body.fist(P, J, r["hand"]))
    bb.mirrored(P, lambda: body.limb(P, J, body.leg_joints(J), ("UpperLeg_R", "LowerLeg_R"), r["trousers"], TROUSERS))
    bb.mirrored(P, lambda: body.limb(P, J, body.leg_joints(J), ("UpperLeg_R", "LowerLeg_R"), r["boot"], BOOT))
    bb.mirrored(P, lambda: body.foot(P, J, r["foot"], rows=FOOT))
    _strap(P, J, r["strap"])
    gear.paint_clothes(r, C)
    lam = ch.prop("LamentoMesh", "Back", "Lamento")
    gear.lamento(lam, A, C)
    # Hang it on his back: build it grip-at-origin, then turn it into place in the Back bone's frame.
    d = Vector(LAMENTO_DIR).normalized()
    e = (Vector((1, 0, 0)) - d * d.x).normalized()       # the edge faces his right; a flat faces the camera
    rot = Matrix((d.cross(e), d, e)).transposed().to_4x4()
    rot.translation = Vector(LAMENTO_GRIP) * s
    mesh.transform_part(lam, ch.arm.data.bones["Back"].matrix_local.inverted() @ rot)
    # In his hand (drawn in the hall): the same sword on Weapon_R, turned so its width lies along the
    # grip's edge axis, clean and bloody (the game shows one; character_story.gd set_lamento).
    for name, bloody in (("LamentoHand", False), ("LamentoBlood", True)):
        held = ch.prop(name, "Weapon_R", "LamentoDrawn")
        gear.lamento(held, A, C, bloody=bloody)
        mesh.transform_part(held, Matrix.Rotation(math.radians(-90), 4, "Y"))
    return ch


def _lock(P, head, r, path, widths, depth=0.52, sides=5):
    """A clump of hair. Points below the cheekbones hang straight down instead of hugging the jaw."""
    pts = []
    for th, z, lift in path:
        p = head.surface(th, max(z, 0.10), lift)
        p.z = head.z0 + z * head.s * head.k
        pts.append(p)
    root_out = pts[0] - Vector((0, 0, head.z0 + 0.12 * head.s))
    body.strand(P, pts, [w * head.s for w in widths], depth, r.uv, {"Head": 1.0}, up=root_out, sides=sides)


def _skirt_panel(P, J, r, lining):
    """His right half of the coat skirt, from the back slit round to the front split: an open shell
    with a red inside. It follows the right thigh, more at the front than the back and more toward
    the hem, so the coat parts as he walks and lifts when he crouches."""
    s = J["height"] / 1.72
    top, hem = SKIRT[-1][0], SKIRT[0][0]
    rings = []
    for z, rx, ryf, ryb, n, front, back in SKIRT:
        f = ((top - z) / (top - hem)) ** 0.8

        def wf(th, f=f):
            c = math.sin(math.radians(th))       # 1 at the front, -1 at the back
            k = f * (0.62 + 0.28 * max(0.0, c) - 0.17 * max(0.0, -c))
            return {"Hips": 1.0 - k, "UpperLeg_R": k}
        rings.append({"c": Vector((0, 0, z * s)), "x": Vector((1, 0, 0)), "y": body.FWD, "rx": rx * s,
                      "ry": ryf * s, "ryb": ryb * s, "n": n, "arc": (-90.0 + back, 90.0 - front), "wf": wf, "w": wf(0)})
    v0, segs = len(P.verts), 12
    grid = mesh.loft(P, rings, segs, r.uv, arc=rings[0]["arc"], thickness=0.008 * s, lining=lining.uv)
    # loft gives the inside the ring's plain weight: copy each outside point's weight to its twin.
    inner = v0 + len(rings) * (segs + 1)
    for i in range(len(rings)):
        for j in range(segs + 1):
            P.weights[inner + i * (segs + 1) + j] = dict(P.weights[grid[i][j]])


def _left_skirt_w(z, theta):
    """The left panel's weight at a height and angle (for things hanging on it, like the sash ends)."""
    top, hem = SKIRT[-1][0], SKIRT[0][0]
    f = (min(1.0, max(0.0, (top - z) / (top - hem)))) ** 0.8
    k = f * (0.62 + 0.28 * max(0.0, math.sin(math.radians(theta))))
    return {"Hips": 1.0 - k, "UpperLeg_L": k}


def _sash_knot(P, J, r):
    """The sash is knotted at his left hip; two ends hang down the coat."""
    s = J["height"] / 1.72
    sk = [row[:5] for row in SKIRT]
    knot = [body.trunk_point(J, SASH, th, z, lift) for th, z, lift in ((143, 0.990, 0.004), (149, 0.975, 0.022), (155, 0.958, 0.006))]
    body.strand(P, knot, [0.026 * s, 0.032 * s, 0.0], 0.8, r.uv, {"Hips": 1.0}, up=Vector((0, 1, 0)), sides=5)
    for path, wid in (([(147, 0.962, 0.016), (150, 0.86, 0.016), (153, 0.75, 0.014), (155, 0.64, 0.012)], 0.034),
                      ([(152, 0.962, 0.016), (157, 0.88, 0.018), (160, 0.79, 0.016)], 0.030)):
        pts = [body.trunk_point(J, sk if z < 0.93 else SASH, th, z, lift) for th, z, lift in path]
        zs = [z for _, z, _ in path]
        body.strand(P, pts, [wid * s] * (len(pts) - 1) + [0.0], 0.22, r.uv,
                    lambda k, zs=zs, th=path[0][0]: _left_skirt_w(zs[0] + (zs[-1] - zs[0]) * k, th),
                    up=Vector((-0.5, 0.86, 0)), sides=4)


def _scarf(P, J, r):
    """A red scarf wrapped round his neck inside the collar, the knot's ends down his left chest."""
    s = J["height"] / 1.72
    rings = []
    for z, rx, ryf, ryb, n, dy in SCARF:
        rings.append({"c": Vector((0, dy * s, z * s)), "x": Vector((1, 0, 0)), "y": body.FWD, "rx": rx * s,
                      "ry": ryf * s, "ryb": ryb * s, "n": n, "w": body.spine_w(J, z * s)})
    mesh.loft(P, rings, 14, r.uv)
    for path, wid in (([(-0.045, 1.41, 0.016), (-0.062, 1.34, 0.012), (-0.068, 1.27, 0.012), (-0.07, 1.20, 0.010)],
                       (0.026, 0.030, 0.032)),
                      ([(-0.07, 1.405, 0.012), (-0.082, 1.345, 0.010), (-0.086, 1.29, 0.008)], (0.022, 0.026))):
        pts = [_front(J, SCARF if z > 1.40 else COAT, x, z, lift) for x, z, lift in path]
        zs = [p[1] for p in path]
        body.strand(P, pts, [x * s for x in wid] + [0.0], 0.18, r.uv,
                    lambda k, zs=zs: body.spine_w(J, (zs[0] + (zs[-1] - zs[0]) * k) * s), up=Vector((0, 1, 0)), sides=4)


def _front(J, profile, x, z, lift):
    """The point on the front of a trunk profile at sideways offset x and height z, pushed out by lift."""
    s = J["height"] / 1.72
    zs = [row[0] for row in profile]
    i = max([k for k in range(len(zs) - 1) if zs[k] <= z] or [0])
    t = min(1.0, max(0.0, (z - zs[i]) / (zs[i + 1] - zs[i])))
    a, b = profile[i], profile[i + 1]
    rx, ry, n = (a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[4] + (b[4] - a[4]) * t)
    dy = (a[5] + (b[5] - a[5]) * t) if profile is SCARF else 0.0
    y = dy + ry * max(0.0, 1.0 - min(1.0, abs(x) / rx) ** (n / 2)) ** (2 / n)
    return Vector((x * s, (y + lift) * s, z * s))


def _strap(P, J, r):
    """Lamento's strap: from the left hip, up across his chest, over the right shoulder, down his back."""
    path = [(162, 0.995, 0.012), (140, 1.07, 0.014), (112, 1.17, 0.016), (82, 1.27, 0.018), (50, 1.36, 0.014),
            (18, 1.415, 0.010), (-12, 1.415, 0.010), (-40, 1.36, 0.014), (-75, 1.24, 0.012), (-110, 1.12, 0.010),
            (-150, 1.02, 0.010)]
    pts = [body.trunk_point(J, COAT, th, z, lift) for th, z, lift in path]
    zs = [z for _, z, _ in path]
    s = J["height"] / 1.72

    def w(k):
        i = min(len(zs) - 2, int(k * (len(zs) - 1)))
        t = k * (len(zs) - 1) - i
        return body.spine_w(J, (zs[i] + (zs[i + 1] - zs[i]) * t) * s)
    body.strand(P, pts, [0.021] * (len(pts) - 1) + [0.019], 0.28, r.uv, w, up=Vector((0, 1, 0.2)), sides=4)


def animations(rig):
    """The shared set with his right hand swinging free, and his story cuts (kael_anims.py)."""
    kael_anims.add_all(rig, LAMENTO_GRIP, LAMENTO_DIR)


if __name__ == "__main__":
    build().finish(animations=animations)
