"""The Agency agent: every guard in the game (the captain and lieutenant are the same model in
another coat colour, from their GuardData file). A faceless enforcer: a black helmet with a glowing
visor slit, a long coat split front and back, an armoured breastplate and shoulders, gauntlets,
tall boots with knee plates, and a heavy single-edged blade in his right hand.

Rebuild:  .\\tools\\blender\\rebuild.ps1 agent   (or blender -b --factory-startup -P tools/blender/agent.py)

What the game recolours (scripts/guard.gd): every mesh named "Coat..." takes GuardData.coat_color
(the coat is painted in light greys here so any colour works), and the "Visor" glows in
GuardData.visor_color. Everything in "Body" (helmet, armour, gloves, boots) keeps its own colour.
"""
import math
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy                    # noqa: E402
from mathutils import Vector  # noqa: E402
import character_base as cb   # noqa: E402
import base_body as bb        # noqa: E402
import body                   # noqa: E402
import mesh                   # noqa: E402
import pose                   # noqa: E402
import props                  # noqa: E402
import anims_loco             # noqa: E402
import anims_combat           # noqa: E402
from paint import rgb, shade  # noqa: E402

HEIGHT, SHOULDERS = 1.80, 1.10
HELM_SCALE, PAULDRON = 1.13, 0.92   # helmet size (1.08 = Aeneas's head), shoulder dome size
C = {k: rgb(v) for k, v in {
    "helm": "#17181c", "helm_hi": "#30333a", "helm_edge": "#4c5058", "slot": "#050506",
    "plate": "#2b2e35", "plate_hi": "#555a63", "plate_dk": "#141519", "rivet": "#8a8f97", "mark": "#8e1a14",
    "suit": "#1c1d22", "leather": "#18181c", "leather_hi": "#2e2f35", "boot": "#131316", "sole": "#08080a",
    "buckle": "#7d828a", "steel": "#5b616a", "edge": "#d2d6dc", "grip": "#121214"}.items()}
# The coat: light greys, multiplied by GuardData.coat_color in the game.
K = {k: rgb(v) for k, v in {"cloth": "#e4e4e4", "fold": "#b4b4b4", "seam": "#7c7c7c", "pipe": "#ffffff",
                            "lining": "#727272"}.items()}

# Rows: (z, half width, front depth, back depth, squareness) for a 1.72 m body (scaled by height).
COAT_TORSO = [(0.90, 0.165, 0.098, 0.104, 2.5), (0.99, 0.158, 0.096, 0.100, 2.5), (1.06, 0.146, 0.094, 0.094, 2.5),
              (1.15, 0.158, 0.106, 0.098, 2.6), (1.24, 0.172, 0.112, 0.104, 2.6), (1.31, 0.192, 0.106, 0.104, 2.7),
              (1.36, 0.206, 0.094, 0.098, 2.8), (1.395, 0.170, 0.080, 0.086, 2.6), (1.425, 0.104, 0.068, 0.072, 2.3),
              (1.45, 0.070, 0.060, 0.064, 2.0)]
# The skirt of the coat, hem up: ... plus the front and back gaps (degrees) between its two halves.
SKIRT = [(0.42, 0.230, 0.156, 0.170, 2.0, 16, 5), (0.52, 0.220, 0.148, 0.160, 2.0, 13, 4),
         (0.64, 0.208, 0.136, 0.148, 2.1, 10, 3), (0.78, 0.198, 0.126, 0.134, 2.2, 6, 2),
         (0.90, 0.188, 0.114, 0.120, 2.3, 3, 1), (0.99, 0.170, 0.106, 0.110, 2.4, 2, 1)]
# High collar, open in a V at the front (last number: the opening's half-angle).
COLLAR = [(1.395, 0.128, 0.090, 0.092, 2.4, -0.004, 36), (1.43, 0.102, 0.084, 0.100, 2.2, -0.008, 36),
          (1.48, 0.100, 0.092, 0.120, 2.1, -0.012, 40), (1.535, 0.108, 0.102, 0.130, 2.1, -0.016, 46)]
CUIRASS_Z = [1.00, 1.04, 1.11, 1.19, 1.27, 1.33, 1.37, 1.405]
# The helmet: (z above the head joint, forward offset, half width, front depth, back depth, squareness).
# Rows 5-6 are the recessed visor slit; row 7 the brow lip over it.
HELM = [(-0.040, -0.010, 0.064, 0.074, 0.100, 2.6), (-0.022, 0.000, 0.068, 0.088, 0.098, 2.8),
        (0.010, 0.008, 0.078, 0.104, 0.098, 3.0), (0.055, 0.010, 0.085, 0.108, 0.102, 3.0),
        (0.086, 0.010, 0.088, 0.108, 0.106, 2.9), (0.094, 0.004, 0.088, 0.098, 0.106, 2.9),
        (0.111, 0.004, 0.089, 0.098, 0.107, 2.9), (0.119, 0.010, 0.090, 0.111, 0.108, 2.8),
        (0.150, 0.004, 0.089, 0.104, 0.110, 2.6), (0.190, -0.004, 0.083, 0.090, 0.106, 2.4),
        (0.222, -0.010, 0.066, 0.068, 0.086, 2.2), (0.246, -0.016, 0.038, 0.040, 0.050, 2.0)]
SLIT_Z, SLIT_ARC = 0.1025, 54          # the visor bar: height on the helmet and half its sweep (degrees)
SLEEVE = [(0.0, 0.066, 0.068), (0.25, 0.062, 0.064), (0.7, 0.056, 0.058), (1.0, 0.052, 0.054), (1.3, 0.052, 0.054),
          (1.75, 0.047, 0.049)]
GAUNTLET = [(1.50, 0.060, 0.062), (1.56, 0.062, 0.064), (1.70, 0.052, 0.054), (1.86, 0.044, 0.046),
            (1.97, 0.040, 0.041)]
TROUSERS = [(-0.15, 0.084, 0.090), (0.0, 0.087, 0.092), (0.3, 0.079, 0.084), (0.7, 0.064, 0.068),
            (1.0, 0.056, 0.058), (1.1, 0.055, 0.058)]
BOOT = [(0.90, 0.067, 0.072, 0.070), (0.95, 0.068, 0.073, 0.072), (1.04, 0.061, 0.065, 0.067),
        (1.3, 0.060, 0.063, 0.069), (1.6, 0.053, 0.056, 0.058), (1.85, 0.049, 0.052, 0.051), (2.02, 0.048, 0.053, 0.049)]
FOOT = [(-0.095, 0.036, 0.040, -0.034), (-0.07, 0.048, 0.058, -0.024), (0.0, 0.053, 0.066, -0.018),
        (0.075, 0.056, 0.047, -0.040), (0.14, 0.056, 0.035, -0.052), (0.20, 0.048, 0.027, -0.06)]


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


def shell(part, J, rect, rows, segs=16, thickness=0.0, lining=None, cap0=None, r=None, weights=None, arcs=None):
    """A trunk-shaped loft (body.trunk with extras): rows (z, rx, ry front, ry back, n[, dy]);
    r(theta) shapes the ring, weights(z) overrides the spine weights, arcs[i] makes an open shell."""
    s = J["height"] / 1.72
    rings = []
    for i, row in enumerate(rows):
        z = row[0] * s
        w = weights(row[0]) if weights else body.spine_w(J, z)
        g = {"c": Vector((0, (row[5] if len(row) > 5 else 0.0) * s, z)), "x": Vector((1, 0, 0)), "y": body.FWD,
             "rx": row[1] * s, "ry": row[2] * s, "ryb": row[3] * s, "n": row[4], "w": w}
        if r:
            g["r"] = r
        if arcs:
            g["arc"] = arcs[i]
        if weights is None and z > J["shoulder"].z - 0.07 * s:
            g["wf"] = shoulder_wf(w)
        rings.append(g)
    return mesh.loft(part, rings, segs, rect.uv, arc=arcs[0] if arcs else None, thickness=thickness,
                     lining=lining.uv if lining else None, cap0=cap0)


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


def build():
    ch = cb.Character("agent", height=HEIGHT, shoulders=SHOULDERS)
    J, A, P, T = ch.J, ch.atlas, ch.part("Body"), ch.part("Coat")
    s = J["height"] / 1.72
    R = {n: A.rect(n, w, h) for n, w, h in (
        ("helm", 128, 72), ("cuirass", 96, 48), ("skirt", 64, 56), ("sleeve", 48, 40), ("ctorso", 32, 32),
        ("boot", 48, 40), ("trousers", 40, 32), ("foot", 40, 24), ("pauldron", 48, 24), ("lame", 32, 12),
        ("gauntlet", 32, 24), ("collar", 48, 16), ("hand", 24, 16), ("belt", 64, 8), ("knee", 16, 16),
        ("pouch", 16, 12), ("neck", 16, 12), ("lining", 8, 8), ("plate_in", 8, 8), ("buckle", 8, 8),
        ("visor", 16, 8), ("crest", 16, 8), ("disc", 8, 8))}

    # --- The coat (tinted in game): torso, skirt halves that follow the thighs, sleeves, collar.
    shell(T, J, R["ctorso"], COAT_TORSO, segs=14, cap0="pole")

    def skirt_half():
        def w(z):
            k = 0.9 * max(0.0, min(1.0, (0.95 - z) / 0.40)) ** 0.6   # 0 at the belt, 0.9 at the knee
            return {"Hips": 1 - k, "UpperLeg_R": k} if k > 0 else {"Hips": 1.0}
        arcs = [(-90 + row[6], 90 - row[5]) for row in SKIRT]
        shell(T, J, R["skirt"], [r[:5] for r in SKIRT], segs=10, thickness=0.007 * s, lining=R["lining"],
              weights=w, arcs=arcs)
    bb.mirrored(T, skirt_half)
    bb.mirrored(T, lambda: body.limb(T, J, body.arm_joints(J), ("UpperArm_R", "LowerArm_R"), R["sleeve"], SLEEVE,
                                     cap0="pole"))
    shell(T, J, R["collar"], [r[:6] for r in COLLAR], segs=14, thickness=0.007 * s, lining=R["lining"],
          arcs=[(90 + r[6], 450 - r[6]) for r in COLLAR])
    # --- Armour: breastplate with a keel, fauld flare, shoulder domes and lames.
    rows = []
    for z in CUIRASS_Z:
        rx, ryf, ryb, n = at_z(COAT_TORSO, z)
        flare = 0.026 if z < 1.02 else 0.0
        rows.append((z, rx + 0.014 + flare, ryf + 0.018 + flare, ryb + 0.012 + flare, min(2.9, n + 0.15)))
    shell(P, J, R["cuirass"], rows, segs=18, r=lambda th: 1.0 + 0.05 * max(0.0, math.sin(math.radians(th))) ** 14)
    bb.mirrored(P, lambda: _pauldron(P, J, R["pauldron"], R["plate_in"]))
    for t0 in (0.17, 0.29):
        bb.mirrored(P, lambda t0=t0: limb_shell(P, J, body.arm_joints(J), ("UpperArm_R", "LowerArm_R"), R["lame"],
                                                [(t0, 0.071, 0.072), (t0 + 0.15, 0.078, 0.079)], (55, 305),
                                                lining=R["plate_in"]))
    # --- Belt with a buckle plate and pouches.
    brows = []
    for z in (0.94, 0.998):
        a, b = at_z(COAT_TORSO, z), at_z([r[:5] for r in SKIRT], z)
        brows.append((z, max(a[0], b[0]) + 0.009, max(a[1], b[1]) + 0.009, max(a[2], b[2]) + 0.009, 2.5))
    shell(P, J, R["belt"], brows, segs=18)
    zb = 0.969 * s
    box(P, Vector((0, (brows[0][2] + 0.006) * s, zb)), (0.026 * s, 0.006 * s, 0.022 * s), R["buckle"], {"Hips": 1.0})
    for th in (32, 148, 222):
        c, d = math.cos(math.radians(th)), math.sin(math.radians(th))
        out = Vector((c, d, 0))
        rr = brows[0][1] * abs(c) + (brows[0][2] if d > 0 else brows[0][3]) * abs(d)
        box(P, Vector((c * (rr + 0.016) * s, d * (rr + 0.016) * s, zb - 0.012 * s)), (0.032 * s, 0.017 * s, 0.03 * s),
            R["pouch"], {"Hips": 1.0}, (Vector((d, -c, 0)), out, Vector((0, 0, 1))))
    # --- Helmet (on the head bone: no face), crest, side discs; neck under the collar.
    body.neck(P, J, R["neck"], r=0.052)
    head = body.Head(J, rows=HELM, brow=0.0, scale=HELM_SCALE)
    head.build(P, R["helm"], segs=20)
    _crest(P, head, R["crest"])
    bb.mirrored(P, lambda: _disc(P, head, R["disc"]))
    # --- Gauntlets, gloves, trousers, boots with knee plates, feet.
    bb.mirrored(P, lambda: body.limb(P, J, body.arm_joints(J), ("UpperArm_R", "LowerArm_R"), R["gauntlet"],
                                     GAUNTLET, hand_bone="Hand_R"))
    bb.mirrored(P, lambda: body.fist(P, J, R["hand"], size=1.1))
    legs = (body.leg_joints(J), ("UpperLeg_R", "LowerLeg_R"))
    bb.mirrored(P, lambda: body.limb(P, J, *legs, R["trousers"], TROUSERS))
    bb.mirrored(P, lambda: body.limb(P, J, *legs, R["boot"], BOOT))
    bb.mirrored(P, lambda: limb_shell(P, J, *legs, R["knee"], [(0.84, 0.068, 0.074), (0.97, 0.074, 0.084),
                                                               (1.10, 0.066, 0.074)], (25, 155), lining=R["plate_in"]))
    bb.mirrored(P, lambda: body.foot(P, J, R["foot"], rows=FOOT))
    _paint(R, head)
    _visor(ch, head, R["visor"])
    _blade(ch.prop("BladeMesh", "Weapon_R", "Blade"), A)
    return ch


def _pauldron(P, J, rect, lining):
    """A shoulder dome: rings along an axis from beside the neck out over the right shoulder,
    covering the top, front and back (open underneath)."""
    s = J["height"] / 1.72
    base = Vector((0.10 * SHOULDERS, -0.005, 1.43)) * s
    a = Vector((1.0, 0.0, -0.62)).normalized()
    x, y = mesh.frame_along(a, Vector((0, 0, 1)))   # x: forward, y: up and out
    rings = []
    for d, rx, ry in ((0.0, 0.070, 0.030), (0.035, 0.094, 0.062), (0.08, 0.106, 0.084), (0.13, 0.108, 0.090),
                      (0.17, 0.094, 0.080), (0.195, 0.05, 0.045)):
        w = ({"Chest": 0.5, "Shoulder_R": 0.5} if d < 0.06 else
             ({"Shoulder_R": 0.7, "UpperArm_R": 0.3} if d < 0.1 else {"Shoulder_R": 0.45, "UpperArm_R": 0.55}))
        rings.append({"c": base + a * d * s * PAULDRON, "x": x, "y": y, "rx": rx * s * PAULDRON, "ry": ry * s * PAULDRON,
                      "n": 2.2, "w": w})
    mesh.loft(P, rings, 10, rect.uv, arc=(-28, 208), thickness=0.007 * s, lining=lining.uv)


def _crest(P, head, rect):
    """A low ridge from the brow over the crown to the nape, sitting half into the helmet."""
    pts = [head.surface(th, z, 0.0) for th, z in ((90, 0.13), (90, 0.185), (90, 0.228), (270, 0.236), (270, 0.20),
                                                  (270, 0.14))]
    widths = [0.4, 0.85, 1.0, 1.0, 0.85, 0.4]
    rings = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, 5)] - pts[max(i - 1, 0)]).normalized()
        x = Vector((1, 0, 0))
        y = d.cross(x).normalized()
        rings.append({"c": p, "x": x, "y": y, "rx": 0.010 * head.s * widths[i], "ry": 0.008 * head.s * widths[i],
                      "ryb": 0.004 * head.s, "n": 2.0, "w": {"Head": 1.0}, "cap_len": 0.004 * head.s})
    mesh.loft(P, rings, 6, rect.uv, cap0="pole", cap1="pole")


def _disc(P, head, rect):
    """A round plate on the right side of the helmet (a comm unit)."""
    c = head.surface(0.0, 0.07, -0.004)
    out = Vector((1, -0.1, 0)).normalized()
    x, y = mesh.frame_along(out, Vector((0, 0, 1)))
    r = 0.024 * head.s
    rings = [{"c": c + out * o * head.s, "x": x, "y": y, "rx": rr * head.s, "ry": rr * head.s, "n": 2.0,
              "w": {"Head": 1.0}, "cap_len": 0.0} for o, rr in ((0.0, r / head.s * 1.05), (0.012, r / head.s))]
    mesh.loft(P, rings, 8, rect.uv, cap1="pole")


def _visor(ch, head, rect):
    """The glowing slit: a thin bar set into the helmet's groove, on the Head bone (guard.gd finds
    the mesh called Visor and sets its colour and glow)."""
    part = ch.prop("Visor", "Head", "HeadGear")
    to_bone = ch.arm.data.bones["Head"].matrix_local.inverted()
    n = 9
    pts = [to_bone @ head.surface(90 - SLIT_ARC + 2 * SLIT_ARC * i / (n - 1), SLIT_Z, 0.002) for i in range(n)]
    outs = [to_bone.to_3x3() @ (head.surface(90 - SLIT_ARC + 2 * SLIT_ARC * i / (n - 1), SLIT_Z, 0.02) -
                                head.surface(90 - SLIT_ARC + 2 * SLIT_ARC * i / (n - 1), SLIT_Z, 0.0)) for i in range(n)]
    rings = []
    for i, p in enumerate(pts):
        d = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        x, y = mesh.frame_along(d, outs[i])
        taper = 0.75 if i in (0, n - 1) else 1.0
        rings.append({"c": p, "x": x, "y": y, "rx": 0.0085 * head.s * taper, "ry": 0.0032 * head.s, "n": 2.6,
                      "w": {}, "cap_len": 0.003 * head.s})
    mesh.loft(part, rings, 6, rect.uv, cap0="pole", cap1="pole")
    rect.fill(rgb("#ffffff"))   # white: guard.gd tints it with GuardData.visor_color


def _blade(p, atlas):
    """The Agency blade: long, single-edged, widening toward a clipped point; square guard, long
    black grip, block pommel. Grip at the origin, blade along +Y, edge along +Z."""
    r_blade, r_hilt, r_guard = atlas.rect("blade", 48, 12), atlas.rect("blade_hilt", 16, 12), atlas.rect("blade_guard", 8, 8)
    L = 0.78
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
    r_hilt.fill(C["grip"])
    for k in range(5):
        r_hilt.hline(0.12 + k * 0.18, C["leather_hi"])
    r_guard.fill(shade(C["plate"], 1.2))
    r_guard.hline(0.5, C["plate_hi"])


def _paint(R, head):
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
    plate = [R[n] for n in ("cuirass", "pauldron", "lame", "knee")]
    for r in plate:
        r.fill(C["plate"])
        r.box(0, 0.0, 1, 0.12, C["plate_hi"])        # light bevel along the lower edge
        r.hline(0.13, C["plate_dk"])
    c = R["cuirass"]
    c.box(0, 0.93, 1, 1.0, C["plate_hi"])            # neck edge
    c.hline(0.92, C["plate_dk"])
    c.vline(0.5, C["plate_hi"], 1, 0.13, 0.92)      # the keel
    c.vline(0.51, C["plate_dk"], 1, 0.13, 0.92)
    for v in (0.30, 0.45):                            # abdomen lames
        c.hline(v, C["plate_dk"])
        c.hline(v - 0.03, shade(C["plate"], 1.25))
    for u in (0.25, 0.75):                            # side straps with buckles
        c.box(u - 0.02, 0.15, u + 0.02, 0.9, C["leather"])
        c.box(u - 0.025, 0.55, u + 0.025, 0.62, C["buckle"])
    for k in range(12):                               # rivets along the neck edge
        c.dot(0.04 + k * 0.083, 0.88, C["rivet"])
    c.box(0.585, 0.70, 0.66, 0.74, C["mark"])         # the Agency mark on the left breast
    R["pauldron"].box(0, 0.9, 1, 1.0, C["plate_dk"])
    for k in range(6):
        R["pauldron"].dot(0.1 + k * 0.16, 0.2, C["rivet"])
    R["plate_in"].fill(C["plate_dk"])
    # The coat, in light greys (guard.gd multiplies them by the coat colour).
    for n in ("ctorso", "skirt", "sleeve", "collar"):
        R[n].fill(K["cloth"])
    sk = R["skirt"]
    sk.box(0, 0, 1, 0.07, K["fold"])                  # hem band
    sk.hline(0.075, K["seam"])
    sk.box(0.95, 0, 1.0, 1, K["pipe"])                # front edge piping
    sk.vline(0.94, K["seam"])
    sk.vline(0.02, K["seam"])                         # back vent edge
    for u in (0.3, 0.62):                             # long folds
        sk.vline(u, K["fold"], 1, 0.08, 0.85)
    sv = R["sleeve"]
    sv.box(0, 0.86, 1, 1.0, K["fold"])                # turned-back cuff
    sv.hline(0.86, K["seam"])
    sv.seam(0.5, K["seam"], K["pipe"], 0.0, 0.85)
    sv.hline(0.45, K["fold"])
    R["collar"].box(0, 0.8, 1, 1.0, K["pipe"])
    R["collar"].hline(0.78, K["seam"])
    R["ctorso"].vline(0.5, K["seam"])
    R["lining"].fill(K["lining"])
    # Leather, cloth and metal of the body.
    g = R["gauntlet"]
    g.fill(C["leather"])
    g.box(0.56, 0.22, 0.94, 0.8, C["plate"])        # the steel plate on the back of the forearm
    g.hline(0.8, C["plate_hi"])
    g.hline(0.22, C["plate_dk"])
    g.box(0, 0.86, 1, 1.0, C["leather_hi"])           # flared cuff edge
    R["hand"].fill(C["leather"])
    R["hand"].hline(0.62, C["leather_hi"], 2)        # knuckle ridge
    R["neck"].fill(C["suit"])
    R["trousers"].fill(C["suit"])
    R["trousers"].seam(0.0, shade(C["suit"], 0.7), shade(C["suit"], 1.4))
    R["trousers"].seam(0.5, shade(C["suit"], 0.7), shade(C["suit"], 1.4))
    b = R["boot"]
    b.fill(C["boot"])
    b.box(0, 0.88, 1, 1.0, C["leather_hi"])           # boot top
    for v in (0.35, 0.6):                             # straps with buckles
        b.hline(v, C["leather_hi"], 2)
        b.box(0.70, v - 0.02, 0.78, v + 0.05, C["buckle"])
    b.seam(0.5, shade(C["boot"], 0.6), shade(C["boot"], 1.8), 0.0, 0.86)
    f = R["foot"]
    f.fill(C["boot"])
    f.box(0.0, 0.0, 0.2, 1.0, C["sole"])
    f.box(0.8, 0.0, 1.0, 1.0, C["sole"])
    f.box(0.0, 0.0, 1.0, 0.1, C["sole"])
    R["belt"].fill(C["leather"])
    R["belt"].hline(0.15, C["leather_hi"])
    R["belt"].hline(0.8, C["leather_hi"])
    R["buckle"].fill(C["buckle"])
    R["buckle"].box(0.25, 0.25, 0.75, 0.75, C["plate_dk"])
    R["pouch"].fill(C["leather_hi"])
    R["pouch"].hline(0.7, C["leather"])
    R["crest"].fill(C["helm_hi"])
    R["disc"].fill(C["plate"])
    R["disc"].box(0.3, 0.3, 0.7, 0.7, C["plate_hi"])


# ---------------------------------------------------------------- his own idle and walk
def agent_idle(s):
    """Feet planted wide, chest out, chin down; the blade hangs point-down at his right side and
    his left hand rests at the small of his back."""
    def at(t):
        b = math.sin(math.tau * t / 3.0)
        look = math.sin(math.tau * t / 6.0)
        return {
            "hips": {"loc": (0.0, 0.0, (-0.016 + 0.002 * b) * s), "rot": (0, 0, 0)},
            "Spine": (1.0, 0, 0), "Chest": (2.5 + 0.6 * b, 0, 0), "Neck": (-4, 0, 3 * look), "Head": (-6, 0, 6 * look),
            "leg_L": {"ankle": (-0.165 * s, 0.01 * s, 0.085 * s), "pole": (-0.3, 1, 0), "foot": (0, 9)},
            "leg_R": {"ankle": (0.165 * s, -0.01 * s, 0.085 * s), "pole": (0.3, 1, 0), "foot": (0, -9)},
            "arm_L": {"ikr": (0.15 * s, -0.20 * s, -0.41 * s), "pole": (-1.0, -0.8, 0.0)},
            "arm_R": {"ikr": (0.075 * s, 0.07 * s, (-0.48 + 0.004 * b) * s), "pole": (0.4, -1, -0.3),
                      "blade": (-10, -60 + 0.6 * b, 70)},
        }
    return at


def agent_walk(s):
    """A measured patrol walk: upright, small arm swing, the blade carried low and forward."""
    return lambda t: anims_loco._cycle_pose(t, s, anims_loco.WALK, -0.02, 0.012, (0, 1, 2, -3, -4), 5, 2, 0.014,
                                            (0.07, 0.03), 0.49, (0.02, 0.01, -6, -58))


def animations(rig):
    """The shared set, then his own idle and walk in place of the shared ones."""
    anims_loco.add_all(rig)
    anims_combat.add_all(rig)
    s = rig.head("Hips").z / 0.93
    for name, fn, length in (("idle", agent_idle(s), 6.0), ("walk", agent_walk(s), 1.0)):
        old = bpy.data.actions.get(name + "_loop")
        if old:
            bpy.data.actions.remove(old)
        pose.make_action(rig, name, fn, length, loop=True)


if __name__ == "__main__":
    ch = build()
    for name, part in ch.parts.items():
        print("CHARACTER part %s: %d triangles" % (name, part.tris()))
    ch.finish(animations=animations)
