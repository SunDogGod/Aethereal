"""The Agency captain: the boss of the Empty Town. Taller and broader than his agents, with only his
LEFT arm (the right is gone at the shoulder: the uniform's sleeve is folded and pinned over the
stump). He wears his white Agency coat draped around his shoulders like a cape, sleeves hanging
empty, over a dark uniform and a breastplate more battered than his men's (a crack, old dents,
three rank bars). The coat has a ribbed standing collar, gold epaulettes with a fringe, a gold cord
across his chest that keeps it on, and the cult's eye big on its back (captain_gear.py,
agency_marks.py). Bare-headed (agency_heads.py): an older, hard face, grey
hair slicked back, and the officers' eyepiece over his left eye, its lens glowing like a visor.
He fights with his one fist (captain_fists.py, mirrored onto his left by captain_anims.py); in
the hall Kael cuts that arm off above the elbow: the arm below the cut is its own mesh,
"Severable", over a hidden "Stump" cap (captain_story.py).

Rebuild:  .\\tools\\blender\\rebuild.ps1 captain   (or blender -b --factory-startup -P tools/blender/captain.py)

What the game recolours (scripts/guard_look.gd): "Coat" (the draped coat, its collar and empty
sleeves) takes GuardData.coat_color, "Trim" (the epaulettes and the cuffs of the empty sleeves)
GuardData.trim_color, the "Visor" glows in GuardData.visor_color. The coat's crimson lining and hem
band are painted in, so they stay crimson under a white coat colour.
"""
import math
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy                    # noqa: E402
import character_base as cb   # noqa: E402
import base_body as bb        # noqa: E402
import body                   # noqa: E402
import pose                   # noqa: E402
import rig as rigmod          # noqa: E402
import agency_parts as ap     # noqa: E402
import agent                  # noqa: E402
import agency_heads as ah     # noqa: E402
import agency_marks as am     # noqa: E402
import face                   # noqa: E402
import captain_gear as gear   # noqa: E402
import captain_anims          # noqa: E402
import captain_story          # noqa: E402
from agency_parts import C, at_z, shell, limb_shell  # noqa: E402
from paint import rgb, shade  # noqa: E402

HEIGHT, SHOULDERS = 1.95, 1.16
# His face (face.py): past fifty, weathered and hard: a long, strong nose, deep-set pale eyes under
# heavy brows drawn down, hollow cheeks, a square jaw, a thin mouth turned down, grey stubble.
FACE_C = {k: rgb(v) for k, v in {"skin": "#c49271", "hair": "#8e8c88", "brow": "#6f6c68", "iris": "#6e7f88",
                                 "lip": "#9a6658", "lash": "#2a2321"}.items()}
HEAD = [(0.000, 0.046, 0.036, 0.030, 0.030, 2.5), (0.016, 0.030, 0.058, 0.062, 0.052, 2.6),
        (0.044, 0.016, 0.068, 0.079, 0.074, 2.6)] + body.HEAD_ROWS[3:]
FACE = face.look(face.MAN, rows=HEAD, scale=1.06, eye_h=0.0050, eye_lo=0.0036, iris_r=0.0056, eye_tilt=-0.0002,
                 brow_z0=0.1165, brow_z1=0.1225, brow_arch=0.0006, brow_thick=0.0046, brow_ridge=0.0058,
                 socket=0.0070, nose=0.022, nose_bridge=0.0065, nose_w=5.6, cheek=0.0045, hollow=0.0045,
                 jaw=0.0065, chin=0.0072, chin_w=15.0, lip_h_up=0.0016, lip_h_lo=0.0024, smile=-0.0008,
                 lip_sat=0.2, age=0.85, stubble=0.45, skin=FACE_C["skin"], hair=FACE_C["hair"],
                 brow=FACE_C["brow"], lash_col=FACE_C["lash"], iris=FACE_C["iris"], lip=FACE_C["lip"])
HAIRLINE = ah.receding(lambda th: bb.hair_line(th) - 0.004)
K = {k: rgb(v) for k, v in {           # the coat: near-white (tinted in game) with crimson painted in
    "cloth": "#f2f2ef", "fold": "#d2d2ce", "seam": "#a0a09b", "lining": "#6e1414", "lining_dk": "#4a0d0d",
    "band": "#7a1616", "dust": "#ab9f8a", "grime": "#80766a", "gold": "#e8e4dc"}.items()}
U = {k: rgb(v) for k, v in {           # the dark uniform under it
    "cloth": "#1d1f26", "fold": "#2a2d36", "seam": "#101116", "pin": "#9a8a5c", "wrap": "#5a1210"}.items()}
# The uniform tunic: the agent's coat torso, and a shorter skirt (to mid-thigh).
TUNIC = agent.COAT_TORSO
TUNIC_SKIRT = [r for r in agent.SKIRT if r[0] >= 0.62]
SLEEVE = [(0.0, 0.066, 0.068), (0.25, 0.064, 0.066), (0.7, 0.058, 0.060), (1.0, 0.054, 0.056),
          (1.3, 0.054, 0.056), (1.75, 0.048, 0.050)]


def forward_grip_left(ch):
    """His fist's grip point Weapon_L (where a body he carries hangs: character_story.gd attach)
    turned into the exact mirror of Weapon_R (a forward grip) instead of the shared rig's reverse
    grip, so his mirrored poses land the right way round; the rest pose is read again."""
    arm = ch.arm
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.data.edit_bones
    r, l = eb["Weapon_R"], eb["Weapon_L"]
    l.head, l.tail = rigmod.mirror(r.head), rigmod.mirror(r.tail)
    l.align_roll(rigmod.mirror(r.z_axis))
    bpy.ops.object.mode_set(mode='OBJECT')
    ch.rig = pose.Rig(arm)


def build():
    ch = cb.Character("captain", height=HEIGHT, shoulders=SHOULDERS, atlas_size=512)
    forward_grip_left(ch)
    J, A = ch.J, ch.atlas
    P, T, M = ch.part("Body"), ch.part("Coat"), ch.part("Trim")
    s = J["height"] / 1.72
    R = {n: A.rect(n, w, h) for n, w, h in (
        ("cape", 128, 96), ("cuirass", 96, 64), ("tskirt", 64, 32), ("sleeve", 48, 40), ("cord", 8, 8),
        ("boot", 48, 40), ("tunic", 32, 32), ("trousers", 40, 32), ("foot", 40, 24), ("csleeve", 32, 40),
        ("gauntlet", 32, 24), ("collar", 48, 16), ("lame", 32, 12), ("hand", 24, 16), ("belt", 64, 8),
        ("stump", 24, 16), ("knee", 16, 16), ("pouch", 16, 12), ("neck", 16, 12), ("lining", 8, 8),
        ("tlining", 8, 8), ("plate_in", 8, 8), ("buckle", 8, 8), ("trim", 16, 8), ("board", 16, 8),
        ("fringe", 16, 8), ("cut", 8, 8))}
    arm = (body.arm_joints(J), ("UpperArm_R", "LowerArm_R"))

    # --- The dark uniform: tunic, its skirt, the left sleeve, the pinned stump on the right.
    shell(P, J, R["tunic"], TUNIC, segs=14, cap0="pole")

    def skirt_half():
        def w(z):
            k = 0.9 * max(0.0, min(1.0, (0.95 - z) / 0.40)) ** 0.6
            return {"Hips": 1 - k, "UpperLeg_R": k} if k > 0 else {"Hips": 1.0}
        shell(P, J, R["tskirt"], [r[:5] for r in TUNIC_SKIRT], segs=10, thickness=0.007 * s, lining=R["tlining"],
              weights=w, arcs=[(-90 + r[6], 90 - r[5]) for r in TUNIC_SKIRT])
    bb.mirrored(P, skirt_half)
    ap.left_only(P, lambda: body.limb(P, J, *arm, R["sleeve"], SLEEVE, cap0="pole"))
    gear.stump(P, J, R["stump"])
    # --- Armour: the breastplate, plates down his sword arm, the belt.
    rows = []
    for z in agent.CUIRASS_Z:
        rx, ryf, ryb, n = at_z(TUNIC, z)
        flare = 0.026 if z < 1.02 else 0.0
        rows.append((z, rx + 0.014 + flare, ryf + 0.018 + flare, ryb + 0.012 + flare, min(2.9, n + 0.15)))
    shell(P, J, R["cuirass"], rows, segs=18, r=lambda th: 1.0 + 0.05 * max(0.0, math.sin(math.radians(th))) ** 14)
    for t0 in (0.20, 0.33):
        ap.left_only(P, lambda t0=t0: limb_shell(P, J, *arm, R["lame"], [(t0, 0.073, 0.074), (t0 + 0.15, 0.080, 0.081)],
                                                 (55, 305), lining=R["plate_in"]))
    agent.belt(P, J, R, TUNIC, TUNIC_SKIRT, pouches=(148,))   # the others would push through the coat
    # --- Bare-headed: face, slicked grey hair, the eyepiece (agency_heads.py); neck under the collar.
    ah.officer_head(ch, P, FACE, ah.SLICKED, HAIRLINE)
    # --- His one gauntlet and fist, legs and boots.
    ap.left_only(P, lambda: body.limb(P, J, *arm, R["gauntlet"], agent.GAUNTLET, hand_bone="Hand_R"))
    ap.left_only(P, lambda: body.fist(P, J, R["hand"], size=1.12))
    agent.lower(P, J, R)
    # --- The white coat over his shoulders, its collar and empty sleeves; trim on it.
    gear.cape(T, J, R["cape"], R["lining"])
    gear.collar(T, J, R["collar"], R["lining"])
    gear.empty_sleeves(T, M, J, R["csleeve"], R["trim"])
    gear.epaulettes(M, J, R["board"], R["fringe"])
    gear.TUNIC = TUNIC
    gear.cord(M, J, R["cord"])
    paint(R)
    captain_story.split_arm(ch, R["cut"])   # the arm below the cut: its own mesh, and the stump cap
    captain_story.paint_stump(R["cut"], U["cloth"], K["lining_dk"])
    return ch


def paint(R):
    agent.paint_armour(R, rank=3, worn=1.8)   # his plate has seen more: a crack, big dents
    agent.paint_lower(R)
    # The uniform.
    for n in ("tunic", "tskirt", "sleeve", "stump"):
        R[n].fill(U["cloth"])
    R["tlining"].fill(U["seam"])
    ts = R["tskirt"]
    ts.box(0, 0, 1, 0.1, U["fold"])
    ts.hline(0.11, U["seam"])
    ts.vline(0.94, U["seam"])
    R["sleeve"].seam(0.5, U["seam"], U["fold"], 0.0, 0.85)
    st = R["stump"]
    st.hline(0.55, U["seam"], 2)                       # the fold
    st.box(0.40, 0.62, 0.52, 0.80, U["pin"])          # the pin holding it
    st.box(0.0, 0.85, 1.0, 1.0, U["fold"])
    # The coat (near-white: the game tints it with the coat colour), crimson inside.
    for n in ("cape", "collar", "csleeve"):
        R[n].fill(K["cloth"])
    c = R["cape"]
    c.box(0, 0.0, 1, 0.035, K["fold"])                 # turned hem
    c.box(0, 0.05, 1, 0.075, K["band"])               # a crimson band above it
    c.hline(0.085, K["seam"])
    for u in (0.12, 0.3, 0.5, 0.7, 0.88):              # long folds hanging from the shoulders
        c.vline(u, K["fold"], 1, 0.1, 0.86)
    c.box(0.0, 0.0, 0.025, 1.0, K["lining"])          # the crimson lining shows at both front edges
    c.box(0.975, 0.0, 1.0, 1.0, K["lining"])
    c.hline(0.93, K["seam"])                           # yoke seam across the shoulders
    am.stitches(c, 0.0, 0.915, 1.0, 0.915, K["seam"])
    am.stitches(c, 0.0, 0.09, 1.0, 0.09, K["seam"])
    # The cult's eye, big on the back of the coat (the back is at angle 270: u = (270 - 226) / 212).
    u_back = (270.0 - gear.CAPE[0][5]) / (gear.CAPE[0][6] - gear.CAPE[0][5])
    am.eye_mark(c, u_back, 0.60, 13, 9, K["lining"], K["lining"], K["lining_dk"], stroke=3)
    ap.weather(c, 0.30, K["dust"], K["grime"], seed=11, waves=4)
    am.ragged_hem(c, K["grime"], seed=12, notches=7)
    R["lining"].fill(K["lining"])
    R["lining"].hline(0.5, K["lining_dk"])
    co = R["collar"]
    for k in range(gear.RIBS[0]):                     # the ribs: a lit roll and a shadow beside each
        co.vline(k / gear.RIBS[0], K["fold"], 1, 0.0, 0.8)
        co.vline(k / gear.RIBS[0] + 0.03, shade(K["cloth"], 1.04), 1, 0.0, 0.8)
    co.box(0, 0.82, 1, 1.0, K["fold"])
    co.hline(0.80, K["seam"])
    R["cord"].fill(K["gold"])
    R["cord"].hline(0.3, K["seam"])
    R["cord"].hline(0.7, K["seam"])
    cs = R["csleeve"]
    cs.vline(0.5, K["seam"])
    cs.hline(0.5, K["fold"])
    ap.weather(cs, 0.14, K["dust"], seed=13, strength=0.3, flip=True)
    # Trim (near-white: tinted with the trim colour): cuffs, epaulette boards and fringe.
    for n in ("trim", "board"):
        R[n].fill(K["gold"])
        R[n].hline(0.15, K["seam"])
        R[n].hline(0.85, K["seam"])
    R["board"].dot(0.5, 0.5, K["seam"], 2)
    f = R["fringe"]
    f.fill(K["gold"])
    for k in range(8):
        f.vline(0.06 + k * 0.125, K["seam"])


animations = captain_anims.animations


if __name__ == "__main__":
    ch = build()
    for name, part in ch.parts.items():
        print("CHARACTER part %s: %d triangles" % (name, part.tris()))
    ch.finish(animations=animations)
