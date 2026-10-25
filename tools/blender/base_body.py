"""A complete plain body (and the face painter) that character scripts start from.

    import base_body as bb
    parts = bb.base_body(ch, bb.GREY)          # torso, neck, head, arms, fists, legs, feet + face
    # or call the pieces yourself (see aeneas.py) to swap in a jacket, boots, hair...
Profiles below are for a 1.72 m body; Character scales them. Change a number, rerun, look.
"""
import math
import numpy as np
import body
import mesh
from paint import rgb, shade

# (z, half width, front depth, back depth, squareness[, forward offset])
TORSO = [(0.86, 0.12, 0.075, 0.080, 2.2), (0.92, 0.160, 0.092, 0.098, 2.5), (0.99, 0.150, 0.090, 0.094, 2.5),
         (1.06, 0.136, 0.088, 0.086, 2.5), (1.15, 0.148, 0.100, 0.090, 2.6), (1.24, 0.162, 0.108, 0.097, 2.6),
         (1.31, 0.176, 0.100, 0.097, 2.7), (1.36, 0.188, 0.086, 0.090, 2.8), (1.395, 0.155, 0.070, 0.076, 2.6),
         (1.425, 0.090, 0.058, 0.060, 2.2), (1.44, 0.058, 0.050, 0.052, 2.0)]
# (t along the arm: 0..1 upper arm, 1..2 forearm; radius across; radius front[, back])
ARM = [(0.0, 0.052, 0.054), (0.25, 0.048, 0.050), (0.7, 0.042, 0.044), (1.0, 0.038, 0.040), (1.3, 0.040, 0.042),
       (1.7, 0.034, 0.036), (2.0, 0.030, 0.031)]
LEG = [(-0.15, 0.082, 0.088), (0.0, 0.085, 0.090), (0.3, 0.077, 0.082), (0.7, 0.062, 0.066), (1.0, 0.053, 0.056),
       (1.25, 0.054, 0.058, 0.066), (1.6, 0.046, 0.050), (2.0, 0.038, 0.040)]

GREY = {"skin": "#b9b4ad", "top": "#8d8f93", "legs": "#5d6066", "shoes": "#3f4146", "hair": "#4a4a4e",
        "eye": "#2a2a2e", "lip": "#9a8f88"}


def mirrored(part, build):
    """Runs build() (which adds right-side geometry) and adds its mirror for the left side."""
    v0, f0 = mesh.mark(part)
    build()
    v1, f1 = mesh.mark(part)
    mesh.mirror_part(part, (v0, v1, f0, f1))


def hair_line(theta):
    """Height (above the head joint) where the hair starts, around the head (90 = the face)."""
    c = math.cos(math.radians(theta - 90))      # 1 front, -1 back
    side = abs(math.sin(math.radians(theta - 90)))
    return 0.13 + 0.045 * max(0.0, c) - 0.08 * max(0.0, -c) * (1 - 0.3 * side) + 0.0 * side


def paint_head(head, rect, skin, hair, eye, lip, brow=None, hairline=hair_line, iris=None, face=True):
    """Skin, hair cap, and a simple appealing face: almond eyes with a lash line, brows, mouth.
    face=False leaves a blank head (a helmet or mask)."""
    img = rect.atlas.img
    rect.fill(skin)
    brow = brow if brow is not None else hair
    for col in range(rect.w):
        u = (col + 0.5) / rect.w
        # invert the head's u warp to find the angle of this column
        f = u / 0.6 if u < 0.2 else ((u - 0.2) / 1.8 + 1 / 3 if u < 0.8 else (u - 0.8) / 0.6 + 2 / 3)
        th = f * 360.0 - 90.0
        z_line = hairline(th)
        for row in range(rect.h):
            v = 1 - (row + 0.5) / rect.h
            z = _z_of_v(head, v)
            if z > z_line:
                img[rect.y + row, rect.x + col] = hair
            elif z > z_line - 0.006:
                img[rect.y + row, rect.x + col] = shade(hair, 1.35) * 0.5 + np.asarray(skin) * 0.5
    def at(th, z):
        return rect.px(*head.uv(th, z))
    if not face:
        return
    for side in (1, -1):
        th = 90 + 21 * side
        # eye white, iris, lash line above, a lighter lid crease
        x0, y0 = at(th - 7.5 * side, 0.100)
        x1, y1 = at(th + 7.5 * side, 0.100)
        lo, hi = min(x0, x1), max(x0, x1)
        img[y0 - 2:y0 + 2, lo + 1:hi] = rgb("#f2ede6")   # the white, 4 rows: open, awake eyes
        img[y0 - 1:y0 + 1, lo:hi + 1] = rgb("#f2ede6")
        ix, iy = at(th - 1.0 * side, 0.100)
        img[iy - 2:iy + 2, ix - 1:ix + 2] = iris if iris is not None else eye
        img[iy - 1:iy + 2, ix:ix + 1] = shade(eye, 0.4)
        img[iy - 2, ix - 1] = rgb("#f8f5ee")  # a glint
        img[y0 - 3, lo:hi + 2] = shade(eye, 0.5)   # lash line
        img[y0 + 2, lo + 2:hi - 1] = shade(rgb("#f2ede6"), 0.8)
        ox = hi + 1 if side == 1 else lo - 1
        img[y0 - 1, ox] = shade(eye, 0.55)  # a flick at the outer corner
        # brow: a tapered stroke, thicker toward the nose
        bx0, by0 = at(90 + 12 * side, 0.124)
        bx1, by1 = at(90 + 33 * side, 0.121)
        for k in range(abs(bx1 - bx0) + 1):
            t = k / max(1, abs(bx1 - bx0))
            x = bx0 + (k if bx1 > bx0 else -k)
            y = round(by0 + (by1 - by0) * t - 1.5 * math.sin(math.pi * t))
            img[y:y + (2 if t < 0.6 else 1), x] = brow
    # mouth: a short line with a lighter lower lip, and a shadow under the nose
    mx0, my = at(90 - 7, 0.042)
    mx1, _ = at(90 + 7, 0.042)
    img[my, min(mx0, mx1):max(mx0, mx1) + 1] = lip
    img[my + 1, min(mx0, mx1) + 1:max(mx0, mx1)] = shade(skin, 1.06)
    nx0, ny = at(90 - 4, 0.063)
    nx1, _ = at(90 + 4, 0.063)
    img[ny, min(nx0, nx1):max(nx0, nx1) + 1] = shade(skin, 0.86)


def _z_of_v(head, v):
    target = v * head.lens[-1]
    zs = [r[0] for r in head.rows]
    for i in range(len(zs) - 1):
        if head.lens[i] <= target <= head.lens[i + 1]:
            t = (target - head.lens[i]) / max(1e-6, head.lens[i + 1] - head.lens[i])
            return zs[i] + (zs[i + 1] - zs[i]) * t
    return zs[-1]


def base_body(ch, colors=GREY, torso=TORSO, arm=ARM, leg=LEG, hair=True, top_obj="Body", face=True):
    """Builds a whole plain body into ch.part('Body'). Returns the Head (for hair and face).
    top_obj: put the torso and sleeves in their own object (guards recolour their "Coat")."""
    J, A, P = ch.J, ch.atlas, ch.part("Body")
    T = ch.part(top_obj)
    c = {k: rgb(v) for k, v in colors.items()}
    r_head = A.rect("head", 128, 72)
    r_torso = A.rect("torso", 96, 48)
    r_arm = A.rect("arm", 64, 40)
    r_leg = A.rect("leg", 64, 48)
    r_foot = A.rect("foot", 48, 24)
    r_hand = A.rect("hand", 24, 16)
    r_neck = A.rect("neck", 24, 16)
    r_hair = A.rect("hair", 32, 24)
    body.trunk(T, J, r_torso, torso, cap0="pole")
    r_torso.fill(c["top"])
    r_torso.hline(0.02, shade(c["top"], 0.75), 2)
    body.neck(P, J, r_neck)
    r_neck.fill(c["skin"])
    head = body.Head(J)
    head.build(P, r_head)
    body.nose(P, head, r_head)
    body.ear(P, head, r_head, 1)
    body.ear(P, head, r_head, -1)
    paint_head(head, r_head, c["skin"], c["hair"], c["eye"], c["lip"], face=face)
    mirrored(T, lambda: body.limb(T, J, body.arm_joints(J), ("UpperArm_R", "LowerArm_R"), r_arm, arm,
                                  hand_bone="Hand_R", cap0="pole"))
    r_arm.fill(c["top"])
    r_arm.hline(0.97, shade(c["top"], 0.75), 2)
    mirrored(P, lambda: body.fist(P, J, r_hand))
    r_hand.fill(c["skin"])
    r_hand.hline(0.55, shade(c["skin"], 0.85))
    mirrored(P, lambda: body.limb(P, J, body.leg_joints(J), ("UpperLeg_R", "LowerLeg_R"), r_leg, leg))
    r_leg.fill(c["legs"])
    mirrored(P, lambda: body.foot(P, J, r_foot))
    r_foot.fill(c["shoes"])
    r_foot.box(0, 0.0, 1, 0.12, shade(c["shoes"], 0.6))
    if hair:
        r_hair.fill(c["hair"])
        for th in range(0, 360, 40):
            body.lock(P, head, r_hair, [(th, 0.235, 0.0), (th, 0.20, 0.012), (th + 10, 0.15, 0.010)],
                      [0.035, 0.030, 0.0])
    return head
