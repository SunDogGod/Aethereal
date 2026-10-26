"""The Agency agent: the rank and file (the lieutenant is this body bare-headed, lieutenant.py, in
his GuardData colours; the captain has his own model, captain.py). A faceless enforcer in a white
long coat: a black helmet with a glowing visor slit (agency_heads.py), a dark breastplate and
shoulder domes, black gauntlets, tall boots with knee plates, a heavy single-edged blade in his
right hand and a knife across the small of his back (drawn for the hostage poses,
anims_agency.py). The coat is old and dusty at the hem, the armour chipped: this world is
thousands of years old.

Rebuild:  .\\tools\\blender\\rebuild.ps1 agent   (or blender -b --factory-startup -P tools/blender/agent.py)

What the game recolours (scripts/guard_look.gd): every mesh named "Coat..." takes
GuardData.coat_color, every mesh named "Trim..." (collar, cuffs, armband) GuardData.trim_color, and
the "Visor" glows in GuardData.visor_color. Coat and trim are painted near-white here (the dust is
painted in) so any colour works. Everything in "Body" (helmet, armour, gloves, boots) keeps its own.
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
import pose                   # noqa: E402
import anims_loco             # noqa: E402
import anims_combat           # noqa: E402
import agency_parts as ap     # noqa: E402
import agency_heads as ah     # noqa: E402
import anims_agency           # noqa: E402
import props                  # noqa: E402
from agency_parts import C, at_z, shell, limb_shell, box  # noqa: E402
from paint import rgb, shade  # noqa: E402

HEIGHT, SHOULDERS = 1.80, 1.10
HELM_SCALE, PAULDRON = 1.13, 0.92   # helmet size (1.08 = Aeneas's head), shoulder dome size
# The coat and trim: near-white, multiplied by GuardData.coat_color / trim_color in the game.
K = {k: rgb(v) for k, v in {"cloth": "#efefec", "fold": "#cfcfcb", "seam": "#9d9d98", "pipe": "#ffffff",
                            "lining": "#8f8f8b", "dust": "#a89c87", "grime": "#7d7365"}.items()}

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
SLEEVE = [(0.0, 0.066, 0.068), (0.25, 0.062, 0.064), (0.7, 0.056, 0.058), (1.0, 0.052, 0.054), (1.3, 0.052, 0.054),
          (1.75, 0.047, 0.049)]
CUFF = [(1.34, 0.057, 0.059), (1.50, 0.058, 0.060)]          # trim ring just above the gauntlet
ARMBAND = [(0.40, 0.064, 0.066), (0.56, 0.062, 0.064)]       # trim ring round the left upper arm
GAUNTLET = [(1.50, 0.060, 0.062), (1.56, 0.062, 0.064), (1.70, 0.052, 0.054), (1.86, 0.044, 0.046),
            (1.97, 0.040, 0.041)]
TROUSERS = [(-0.15, 0.084, 0.090), (0.0, 0.087, 0.092), (0.3, 0.079, 0.084), (0.7, 0.064, 0.068),
            (1.0, 0.056, 0.058), (1.1, 0.055, 0.058)]
BOOT = [(0.90, 0.067, 0.072, 0.070), (0.95, 0.068, 0.073, 0.072), (1.04, 0.061, 0.065, 0.067),
        (1.3, 0.060, 0.063, 0.069), (1.6, 0.053, 0.056, 0.058), (1.85, 0.049, 0.052, 0.051), (2.02, 0.048, 0.053, 0.049)]
FOOT = [(-0.095, 0.036, 0.040, -0.034), (-0.07, 0.048, 0.058, -0.024), (0.0, 0.053, 0.066, -0.018),
        (0.075, 0.056, 0.047, -0.040), (0.14, 0.056, 0.035, -0.052), (0.20, 0.048, 0.027, -0.06)]
KNEE = [(0.84, 0.068, 0.074), (0.97, 0.074, 0.084), (1.10, 0.066, 0.074)]


def build(name="agent", officer=None):
    """officer: (face look, hair style, hairline) for a bare-headed officer (lieutenant.py) in
    place of the helmet (agency_heads.py)."""
    ch = cb.Character(name, height=HEIGHT, shoulders=SHOULDERS, atlas_size=512 if officer else 256)
    J, A = ch.J, ch.atlas
    P, T, M = ch.part("Body"), ch.part("Coat"), ch.part("Trim")
    s = J["height"] / 1.72
    R = {n: A.rect(n, w, h) for n, w, h in (() if officer else (("helm", 128, 72),)) + (
        ("cuirass", 96, 48), ("skirt", 64, 56), ("sleeve", 48, 40), ("ctorso", 32, 32),
        ("boot", 48, 40), ("trousers", 40, 32), ("foot", 40, 24), ("pauldron", 48, 24), ("lame", 32, 12),
        ("gauntlet", 32, 24), ("collar", 48, 16), ("hand", 24, 16), ("belt", 64, 8), ("knee", 16, 16),
        ("pouch", 16, 12), ("neck", 16, 12), ("lining", 8, 8), ("plate_in", 8, 8), ("buckle", 8, 8),
        ("trim", 16, 8)) + (() if officer else (("visor", 16, 8), ("crest", 16, 8), ("disc", 8, 8)))}
    arm = (body.arm_joints(J), ("UpperArm_R", "LowerArm_R"))

    # --- The coat (tinted in game): torso, skirt halves that follow the thighs, sleeves.
    shell(T, J, R["ctorso"], COAT_TORSO, segs=14, cap0="pole")

    def skirt_half():
        def w(z):
            k = 0.9 * max(0.0, min(1.0, (0.95 - z) / 0.40)) ** 0.6   # 0 at the belt, 0.9 at the knee
            return {"Hips": 1 - k, "UpperLeg_R": k} if k > 0 else {"Hips": 1.0}
        arcs = [(-90 + row[6], 90 - row[5]) for row in SKIRT]
        shell(T, J, R["skirt"], [r[:5] for r in SKIRT], segs=10, thickness=0.007 * s, lining=R["lining"],
              weights=w, arcs=arcs)
    bb.mirrored(T, skirt_half)
    bb.mirrored(T, lambda: body.limb(T, J, *arm, R["sleeve"], SLEEVE, cap0="pole"))
    # --- The trim (tinted in game): high collar, cuffs, an armband on the left arm.
    shell(M, J, R["collar"], [r[:6] for r in COLLAR], segs=14, thickness=0.007 * s, lining=R["lining"],
          arcs=[(90 + r[6], 450 - r[6]) for r in COLLAR])
    bb.mirrored(M, lambda: body.limb(M, J, *arm, R["trim"], CUFF, segs=10))
    ap.left_only(M, lambda: body.limb(M, J, *arm, R["trim"], ARMBAND, segs=10))
    # --- Armour: breastplate with a keel, fauld flare, shoulder domes and lames.
    rows = []
    for z in CUIRASS_Z:
        rx, ryf, ryb, n = at_z(COAT_TORSO, z)
        flare = 0.026 if z < 1.02 else 0.0
        rows.append((z, rx + 0.014 + flare, ryf + 0.018 + flare, ryb + 0.012 + flare, min(2.9, n + 0.15)))
    shell(P, J, R["cuirass"], rows, segs=18, r=lambda th: 1.0 + 0.05 * max(0.0, math.sin(math.radians(th))) ** 14)
    bb.mirrored(P, lambda: ap.pauldron(P, J, R["pauldron"], R["plate_in"], SHOULDERS, PAULDRON))
    for t0 in (0.17, 0.29):
        bb.mirrored(P, lambda t0=t0: limb_shell(P, J, *arm, R["lame"], [(t0, 0.071, 0.072), (t0 + 0.15, 0.078, 0.079)],
                                                (55, 305), lining=R["plate_in"]))
    belt(P, J, R, COAT_TORSO, SKIRT)
    # --- The helmet with its visor slit, or an officer's bare head and eyepiece; neck under the collar.
    if officer:
        ah.officer_head(ch, P, *officer)
    else:
        ah.helmet(ch, P, R, HELM_SCALE)
    # --- Gauntlets, gloves, trousers, boots with knee plates, feet.
    bb.mirrored(P, lambda: body.limb(P, J, *arm, R["gauntlet"], GAUNTLET, hand_bone="Hand_R"))
    bb.mirrored(P, lambda: body.fist(P, J, R["hand"], size=1.1))
    lower(P, J, R)
    paint(R)
    ap.blade(ch.prop("BladeMesh", "Weapon_R", "Blade"), A)
    props.knife(ch.prop("KnifeMesh", "Knife", "Knife"), A)
    return ch


def belt(P, J, R, torso, skirt, pouches=(32, 148, 222)):
    """The belt over coat and skirt, with a buckle plate and pouches (angles round him, 90 = front)."""
    s = J["height"] / 1.72
    brows = []
    for z in (0.94, 0.998):
        a, b = at_z(torso, z), at_z([r[:5] for r in skirt], z)
        brows.append((z, max(a[0], b[0]) + 0.009, max(a[1], b[1]) + 0.009, max(a[2], b[2]) + 0.009, 2.5))
    shell(P, J, R["belt"], brows, segs=18)
    zb = 0.969 * s
    box(P, Vector((0, (brows[0][2] + 0.006) * s, zb)), (0.026 * s, 0.006 * s, 0.022 * s), R["buckle"], {"Hips": 1.0})
    for th in pouches:
        c, d = math.cos(math.radians(th)), math.sin(math.radians(th))
        rr = brows[0][1] * abs(c) + (brows[0][2] if d > 0 else brows[0][3]) * abs(d)
        box(P, Vector((c * (rr + 0.016) * s, d * (rr + 0.016) * s, zb - 0.012 * s)), (0.032 * s, 0.017 * s, 0.03 * s),
            R["pouch"], {"Hips": 1.0}, (Vector((d, -c, 0)), Vector((c, d, 0)), Vector((0, 0, 1))))


def lower(P, J, R):
    """Trousers, boots with knee plates, and feet."""
    legs = (body.leg_joints(J), ("UpperLeg_R", "LowerLeg_R"))
    bb.mirrored(P, lambda: body.limb(P, J, *legs, R["trousers"], TROUSERS))
    bb.mirrored(P, lambda: body.limb(P, J, *legs, R["boot"], BOOT))
    bb.mirrored(P, lambda: limb_shell(P, J, *legs, R["knee"], KNEE, (25, 155), lining=R["plate_in"]))
    bb.mirrored(P, lambda: body.foot(P, J, R["foot"], rows=FOOT))


def paint_armour(R, chipped=True):
    """Breastplate, shoulders, lames, knee plates: dark steel with a lit lower bevel, the keel,
    abdomen lames, side straps, rivets, the red Agency mark, and old chips along the edges."""
    plate = [R[n] for n in ("cuirass", "pauldron", "lame", "knee") if n in R]
    for r in plate:
        r.fill(C["plate"])
        r.box(0, 0.0, 1, 0.12, C["plate_hi"])        # light bevel along the lower edge
        r.hline(0.13, C["plate_dk"])
        if chipped:
            ap.chips(r, shade(C["plate_hi"], 1.15), count=max(3, r.w // 10), seed=r.w + r.h, v_range=(0.0, 0.2))
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
    c.box(0.30, 0.58, 0.36, 0.60, C["scuff"])         # old dents
    c.box(0.70, 0.36, 0.74, 0.38, C["scuff"])
    if "pauldron" in R:
        R["pauldron"].box(0, 0.9, 1, 1.0, C["plate_dk"])
        for k in range(6):
            R["pauldron"].dot(0.1 + k * 0.16, 0.2, C["rivet"])
    R["plate_in"].fill(C["plate_dk"])


def paint_lower(R):
    """Gauntlets, gloves, trousers, boots (dusty at the foot), feet, belt and pouches."""
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
    ap.weather(b, 0.30, C["dust"], seed=7, strength=0.45, flip=True)   # road dust at the foot
    f = R["foot"]
    f.fill(shade(C["boot"], 1.0) * 0.6 + C["dust"] * 0.4)
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


def paint(R):
    """The coat and trim, the armour, the lower body (the helmet paints itself: agency_heads.py)."""
    paint_armour(R)
    # The coat, near-white (guard_look.gd multiplies it by the coat colour), dusty at the hem.
    for n in ("ctorso", "skirt", "sleeve"):
        R[n].fill(K["cloth"])
    sk = R["skirt"]
    sk.box(0, 0, 1, 0.07, K["fold"])                  # hem band
    sk.hline(0.075, K["seam"])
    sk.box(0.95, 0, 1.0, 1, K["pipe"])                # front edge piping
    sk.vline(0.94, K["seam"])
    sk.vline(0.02, K["seam"])                         # back vent edge
    for u in (0.3, 0.62):                             # long folds
        sk.vline(u, K["fold"], 1, 0.08, 0.85)
    ap.weather(sk, 0.36, K["dust"], K["grime"], seed=3)
    sk.box(0.44, 0.10, 0.47, 0.16, K["seam"])        # a mended tear
    sk.hline(0.13, K["fold"])
    sv = R["sleeve"]
    sv.seam(0.5, K["seam"], K["pipe"], 0.0, 0.85)
    sv.hline(0.45, K["fold"])
    ap.weather(sv, 0.16, K["dust"], seed=5, strength=0.35, flip=True)   # grimy at the wrist
    R["ctorso"].vline(0.5, K["seam"])
    R["lining"].fill(K["lining"])
    # The trim, near-white too (tinted by the trim colour): collar edge, cuffs, armband.
    R["collar"].fill(K["cloth"])
    R["collar"].box(0, 0.8, 1, 1.0, K["pipe"])
    R["collar"].hline(0.78, K["seam"])
    R["trim"].fill(K["cloth"])
    R["trim"].hline(0.15, K["seam"])
    R["trim"].hline(0.85, K["seam"])
    paint_lower(R)


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
    anims_agency.add_all(rig, pose.make_action)   # captor_knife, drag_by_arm, heave_body

if __name__ == "__main__":
    ch = build()
    for name, part in ch.parts.items():
        print("CHARACTER part %s: %d triangles" % (name, part.tris()))
    ch.finish(animations=animations)
