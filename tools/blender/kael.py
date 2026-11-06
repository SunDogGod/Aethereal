"""Kael, a wandering swordsman in his twenties: taller and leaner than Aeneas, all in black but for
his white hair, cut in a few big spiky wedges. A long black coat (a high stiff collar, a blood-red
lining that shows at the open front, inside the collar and at the turned-back cuffs, a skirt split
front and back to below the knee, the hem worn and dusty) cinched with a black leather sash, a black
undershirt, dark trousers, tall black boots, black gloves. A black-metal talisman with thin silver
rings hangs on a cord at his throat. Lamento, a long bone-white blade with a faint violet edge, a
ring pommel and a red tassel, rides on his back with the grip over his right shoulder.

Knobs: colours are the C table below; shapes are the profile tables (one row per ring, height
first, then radii); hair is HAIR (one row per wedge); where Lamento hangs is LAMENTO_GRIP /
LAMENTO_DIR. The sword's own shape, the talisman and the clothes paint are in kael_gear.py; his
face is FACE (face.py).
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
import face                   # noqa: E402
import face_paint             # noqa: E402
from paint import rgb, shade  # noqa: E402

C = {k: rgb(v) for k, v in {
    "skin": "#dcab88", "hair": "#e4e6ec", "hair_dark": "#9a9eae", "hair_light": "#f8f8fb",
    "eye": "#25232b", "iris": "#7a7e96", "lash": "#2e262c", "lip": "#a8705f", "brow": "#8b8e9c",
    "coat": "#1b1b21", "coat_line": "#35353f", "coat_edge": "#2f2f38", "lining": "#8e1a25", "red": "#a9212e",
    "dust": "#3a3733", "dust_light": "#4a4641",
    "sash": "#141317", "shirt": "#17161b", "trousers": "#26262d", "boot": "#1a191e", "boot_top": "#2c2b32",
    "sole": "#0e0e11", "glove": "#1c1b20", "strap": "#26201f", "silver": "#c3c7d1", "metal": "#15151a",
    "bone": "#ebe7dd", "bone_edge": "#d4c4f2", "bone_dark": "#c6bfc8", "iron": "#5c5e68",
    "wrap": "#8a1a24", "wrap_dark": "#2e0b10"}.items()}

# Profiles are rows for a 1.72 m body (Character scales them to his 1.82 m).
# The black undershirt (the torso): lean, a narrow waist under broad shoulders.
TORSO = [(0.86, 0.12, 0.075, 0.080, 2.2), (0.92, 0.150, 0.088, 0.094, 2.5), (0.99, 0.138, 0.086, 0.090, 2.5),
         (1.06, 0.128, 0.085, 0.083, 2.5), (1.15, 0.145, 0.098, 0.090, 2.6), (1.24, 0.162, 0.106, 0.096, 2.6),
         (1.31, 0.180, 0.100, 0.097, 2.7), (1.36, 0.196, 0.086, 0.090, 2.8), (1.395, 0.160, 0.070, 0.076, 2.6),
         (1.425, 0.092, 0.058, 0.060, 2.2), (1.44, 0.058, 0.050, 0.052, 2.0)]
# The coat above the sash: (height, half width, front, back, squareness, forward shift, V half-angle).
# The V opens from the chest up, so the red lining shows down his front.
COAT = [(0.94, 0.152, 0.098, 0.102, 2.5, 0.0, 0), (0.99, 0.150, 0.098, 0.100, 2.5, 0.0, 0),
        (1.06, 0.142, 0.098, 0.096, 2.5, 0.0, 2), (1.15, 0.158, 0.110, 0.101, 2.6, 0.0, 10),
        (1.24, 0.177, 0.118, 0.107, 2.7, 0.0, 18), (1.31, 0.200, 0.112, 0.108, 2.8, 0.0, 24),
        (1.36, 0.222, 0.098, 0.103, 2.9, 0.0, 30), (1.395, 0.180, 0.083, 0.090, 2.7, 0.0, 36),
        (1.425, 0.116, 0.072, 0.076, 2.3, 0.0, 42)]
# The high stiff collar: straight walls up past his chin, a little flare at the top, its two front
# corners standing by the jaw (last number: the opening's half-angle), blood-red inside.
COLLAR = [(1.40, 0.118, 0.090, 0.092, 2.2, -0.004, 40), (1.46, 0.106, 0.084, 0.088, 2.0, -0.006, 42),
          (1.52, 0.106, 0.086, 0.090, 2.0, -0.009, 48), (1.56, 0.112, 0.092, 0.094, 2.0, -0.012, 58)]
# The skirt, hem first: (height, half width, front, back, squareness, front split, back slit) in degrees.
SKIRT = [(0.38, 0.262, 0.172, 0.190, 2.2, 18, 8), (0.50, 0.246, 0.160, 0.176, 2.2, 14, 5),
         (0.68, 0.230, 0.146, 0.160, 2.25, 9, 3), (0.82, 0.214, 0.133, 0.143, 2.3, 4, 1),
         (0.92, 0.196, 0.118, 0.126, 2.4, 1, 1), (1.00, 0.160, 0.102, 0.106, 2.5, 1, 1)]
SASH = [(0.928, 0.204, 0.125, 0.132, 2.5), (0.975, 0.186, 0.116, 0.121, 2.5), (1.025, 0.165, 0.107, 0.109, 2.5)]
# The sleeve flares into a turned-back cuff at the wrist.
SLEEVE = [(0.0, 0.064, 0.066), (0.25, 0.060, 0.062), (0.7, 0.053, 0.055), (1.0, 0.050, 0.051), (1.3, 0.051, 0.053),
          (1.70, 0.047, 0.049), (1.76, 0.057, 0.059), (2.0, 0.061, 0.063)]
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
# His face (face.py): lean and sharp, heavy-lidded grey-violet eyes (a lower upper lid, a thick
# lash line, a deep crease) under straight low brows, a long nose, a defined jaw, a half smile.
FACE = face.look(face.MAN, rows=HEAD, scale=1.06, eye_h=0.0042, eye_lo=0.0042, eye_tilt=0.0006, iris_r=0.0062,
                 lash=0.0026, crease=1.0, brow_z0=0.1165, brow_z1=0.1185, brow_arch=0.0010, brow_thick=0.0038,
                 nose=0.020, nose_w=5.0, cheek=0.0042, hollow=0.0028, jaw=0.004, chin_w=12.5, smirk=0.0007,
                 lip_sat=0.3, skin=C["skin"], hair=shade(C["hair"], 0.88), brow=C["brow"], lash_col=C["lash"],
                 iris=C["iris"], lip=C["lip"])
# Hair: a few big spiky wedges. Each row is one wedge: a path of (angle round the head, height,
# lift) from root to tip (90 = the face, 0 = his right, 270 = the back; heights above the crown,
# 0.229, stand up off it) and its widths along the way (the last 0 is the point). The tips lift
# away from the head, so they jut instead of hugging it.
WEDGE = [0.064, 0.070, 0.054, 0.034, 0.0]
W4 = [0.068, 0.058, 0.036, 0.0]
SPIKE = [0.050, 0.042, 0.0]
HAIR = [
    # the fringe: two wedges crossing from the crown down over the brows, each tip out past a
    # temple, and a shorter one between them lying over the middle of his brow
    ([(110, 0.236, 0), (94, 0.212, 0.030), (76, 0.170, 0.044), (64, 0.134, 0.044), (58, 0.108, 0.036)], WEDGE),
    ([(72, 0.238, 0), (88, 0.210, 0.030), (104, 0.168, 0.044), (116, 0.132, 0.042), (124, 0.106, 0.034)], WEDGE),
    ([(90, 0.232, 0), (92, 0.200, 0.040), (94, 0.160, 0.052), (96, 0.128, 0.046)], [0.056, 0.060, 0.044, 0.0]),
    # a spike standing up and forward from the front of the crown
    ([(90, 0.224, 0), (90, 0.252, 0.030), (88, 0.284, 0.070)], SPIKE),
    # the temples: swept back over the ears, tips jutting out behind them
    ([(46, 0.226, 0), (28, 0.204, 0.032), (10, 0.160, 0.052), (358, 0.116, 0.064)], W4),
    ([(134, 0.226, 0), (152, 0.204, 0.032), (170, 0.160, 0.052), (182, 0.116, 0.064)], W4),
    # the sides of the back, jutting out and back
    ([(18, 0.232, 0), (352, 0.206, 0.030), (338, 0.160, 0.052), (330, 0.112, 0.066)], W4),
    ([(162, 0.232, 0), (188, 0.206, 0.030), (202, 0.160, 0.052), (210, 0.112, 0.066)], W4),
    ([(330, 0.232, 0), (322, 0.200, 0.032), (314, 0.150, 0.052), (308, 0.100, 0.070)], W4),
    ([(210, 0.232, 0), (218, 0.200, 0.032), (226, 0.150, 0.052), (232, 0.100, 0.070)], W4),
    # the nape: one wide wedge straight down, its tip off the collar
    ([(270, 0.234, 0), (270, 0.192, 0.030), (270, 0.140, 0.046), (270, 0.095, 0.060)], [0.076, 0.080, 0.060, 0.0]),
    # three spikes rising off the back of the crown
    ([(250, 0.228, 0), (242, 0.256, 0.036), (232, 0.282, 0.076)], SPIKE),
    ([(290, 0.228, 0), (298, 0.256, 0.036), (308, 0.282, 0.076)], SPIKE),
    ([(270, 0.226, 0), (270, 0.258, 0.030), (270, 0.288, 0.066)], SPIKE),
]
# Lamento on his back: grip centre, and the way the blade points (down, a little left and out).
LAMENTO_GRIP = (0.140, -0.150, 1.42)
LAMENTO_DIR = (-0.20, -0.09, -1.0)


def build():
    ch = cb.Character("kael", height=1.82, shoulders=1.06, hips=0.95, atlas_size=512)
    J, A, P = ch.J, ch.atlas, ch.part("Body")
    s = J["height"] / 1.72
    r = {n: A.rect(n, w, h) for n, w, h in (
        ("head", face.HEAD_RECT[0], face.HEAD_RECT[1]), ("coat", 96, 56), ("skirt", 64, 48), ("sleeve", 64, 40),
        ("shirt", 48, 32), ("ear", 16, 16),
        ("trousers", 48, 40), ("boot", 48, 32), ("foot", 40, 24), ("hair", 32, 32), ("collar", 48, 16),
        ("sash", 48, 8), ("sash_tail", 16, 24), ("hand", 24, 16), ("neck", 16, 12),
        ("lining", 8, 8), ("collar_in", 8, 8), ("strap", 8, 32), ("talisman", 24, 12), ("cord", 8, 8))}
    body.trunk(P, J, r["shirt"], TORSO, cap0="pole")
    body.neck(P, J, r["neck"])
    head = face.Head(J, FACE)
    head.build(P, r["head"])
    face.ears(P, head, r["ear"], FACE, C["skin"], shade(C["skin"], 0.8))
    face_paint.paint(head, FACE, gear.hairline)
    gear.fringe_shadow(head, r["head"], FACE)
    for path, widths in HAIR:
        _lock(P, head, r["hair"], path, widths)
    body.trunk(P, J, r["coat"], COAT, segs=18, arc=(90, 450), thickness=0.008, lining=r["lining"])
    body.trunk(P, J, r["collar"], COLLAR, segs=12, arc=(130, 410), thickness=0.008, lining=r["collar_in"])
    bb.mirrored(P, lambda: _skirt_panel(P, J, r["skirt"], r["lining"]))
    body.trunk(P, J, r["sash"], SASH, segs=16)
    _sash_knot(P, J, r["sash_tail"])
    gear.talisman(P, J, r["cord"], r["talisman"], TORSO)
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


def _lock(P, head, r, path, widths, depth=0.55, sides=5):
    """A wedge of hair. Points below the cheekbones hang straight down instead of hugging the jaw;
    points above the crown stand up off it."""
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
