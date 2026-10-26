"""The captain in the hall: his story poses, and the arm Kael cuts off.

Poses (written for a right arm like everything else; captain_anims.py mirrors them onto his left):
    spear_hand     his flat hand driven straight into Isabella's chest (SPEAR_HIT), held there. She
                   stands SPEAR_GAP metres in front of him, facing him, playing "lunge" then
                   "stabbed" (her lunge carries her in). The scene cuts away; story_clear() ends it.
    lift_throat    his hand closes on Aeneas's throat and lifts him off his feet (held); Aeneas
                   plays "lifted_by_throat", THROAT_GAP in front (anims_story.py). Then
    hold_throat    holding him up, the arm shaking a little (loop; Aeneas: "held_by_throat")
    arm_severed    the arm is gone (call set_arm_severed(true) as it starts): he jerks back and
                   folds over the stump (held); then "drop_to_knees"
    throw_one_arm  a body held in his hand (attach() it to "Weapon_L") swung back and hurled
                   forward; let go of it (detach()) at THROW_RELEASE
The arm: split_arm() moves everything of the left arm below the cut (CUT_T of the way from
shoulder to elbow) into its own mesh, "Severable", and adds a "Stump" cap (hidden in the game until
the cut).
"""
from mathutils import Vector
from pose import keyed
from anims_combat import P, torso, _v
import anims_story as st
import mesh

SPEAR_GAP = 1.20
SPEAR_HIT = 0.38
THROW_RELEASE = 0.80
CUT_T = 0.6
ARM_BONES = ("UpperArm_L", "LowerArm_L", "Hand_L")


# ---------------------------------------------------------------- the cut arm
def split_arm(ch, rect):
    """Moves the faces of the Body part that lie past the cut on the left arm into a new part,
    "Severable", and builds the "Stump": a short capped tube closing the sleeve at the cut."""
    J, body = ch.J, ch.part("Body")
    sh = Vector((-J["shoulder"].x, J["shoulder"].y, J["shoulder"].z))
    el = Vector((-J["elbow"].x, J["elbow"].y, J["elbow"].z))
    axis = (el - sh).normalized()
    cut = sh + (el - sh) * CUT_T

    def arm_w(i):
        return sum(v for k, v in body.weights[i].items() if k in ARM_BONES)

    def past(i):
        return arm_w(i) >= 0.5 and (body.verts[i] - cut).dot(axis) > 0.0
    keep, move = [], []
    for f, idx in enumerate(body.faces):
        (move if all(past(i) for i in idx) else keep).append(f)
    arm = ch.part("Severable")
    remap = {}
    for f in move:
        new = []
        for i in body.faces[f]:
            if i not in remap:
                remap[i] = arm.vert(body.verts[i], body.weights[i])
            new.append(remap[i])
        arm.face(new, body.uvs[f], body.smooth[f])
    body.faces = [body.faces[f] for f in keep]
    body.uvs = [body.uvs[f] for f in keep]
    body.smooth = [body.smooth[f] for f in keep]
    # Where the sleeve left on the body now ends, and how thick it is there.
    ends = [body.verts[i] for f in body.faces for i in f if arm_w(i) >= 0.5 and (body.verts[i] - cut).dot(axis) > -0.06]
    reach = max([(v - sh).dot(axis) for v in ends] + [(cut - sh).dot(axis)])
    c = sh + axis * reach
    rad = max([((v - sh) - axis * (v - sh).dot(axis)).length for v in ends if (v - sh).dot(axis) > reach - 0.03] + [0.06])
    x, y = mesh.frame_along(axis, Vector((0, 1, 0)))
    w = {"UpperArm_L": 1.0}
    rings = [{"c": c - axis * 0.03, "x": x, "y": y, "rx": rad * 1.05, "ry": rad * 1.05, "n": 2.0, "w": w},
             {"c": c + axis * 0.004, "x": x, "y": y, "rx": rad * 1.08, "ry": rad * 1.08, "n": 2.0, "w": w},
             {"c": c + axis * 0.012, "x": x, "y": y, "rx": rad * 0.8, "ry": rad * 0.8, "n": 2.0, "w": w,
              "cap_len": 0.006}]
    mesh.loft(ch.part("Stump"), rings, 10, rect.uv, cap1="pole")
    return len(move)


def paint_stump(rect, cloth, wound):
    """Dark cloth round a dark wound: the cap's middle (v near 1) is the wound."""
    rect.fill(cloth)
    rect.box(0, 0.55, 1, 1.0, wound)


# ---------------------------------------------------------------- poses
def braced(s):
    return {"leg_L": {"ankle": _v((-0.17, 0.12, 0.085), s), "pole": (-0.3, 1, 0), "foot": (0, 10)},
            "leg_R": {"ankle": _v((0.17, -0.16, 0.085), s), "pole": (0.3, 1, 0), "foot": (0, -20)}}


def hand_at(x, y, z, pole=(1.0, -0.2, -0.6), hand=(0, 0, 0)):
    return {"arm_R": {"ik": (x, y, z), "pole": pole, "hand": hand}}


def guard_ik(s):
    """captain_fists.guard_fist with the fist placed absolutely (keys of one animation must place
    the arm the same way, or the blend jumps)."""
    import captain_fists as cf
    return P(cf.guard_fist(s), hand_at(0.14, 0.28, 1.40, (0.7, -0.2, -1.0)))


def spear_hand(s):
    chamber = P(torso(-25, 4, 0, (0, -0.04, -0.08), s), braced(s), hand_at(0.26, -0.02, 1.02, (0.6, -1, -0.2)))
    lunge = {"leg_L": {"ankle": _v((-0.16, 0.45, 0.085), s), "pole": (-0.2, 1, 0), "foot": (0, 8)},
             "leg_R": {"ankle": _v((0.16, -0.22, 0.10), s), "pole": (0.3, 1, 0), "foot": (-20, -20)}}
    hit = P(torso(18, -14, 0, (0, 0.20, -0.14), s), lunge, hand_at(0.0, 0.72, 1.05, (1.0, -0.3, -0.4)))
    held = P(torso(16, -12, 0, (0, 0.19, -0.13), s), lunge, hand_at(0.0, 0.71, 1.05, (1.0, -0.3, -0.4)))
    return keyed([(0.0, guard_ik(s), "io"), (0.25, chamber, "in"), (SPEAR_HIT, hit, "out"), (0.9, held)])


def _throat(s, lift, shake=0.0):
    z = 1.385 + lift - 0.025
    return P(torso(8 + shake * 3, -4, 0, (0, 0.02, -0.06), s, hips_share=0.1), braced(s),
             hand_at(0.0, st.THROAT_GAP - 0.12 + shake * 0.01, z + shake * 0.01, (1.0, -0.3, -0.5)),
             {"Neck": (-2, 0, -6), "Head": (2, 0, -8)})


def lift_throat(s):
    return keyed([(0.0, guard_ik(s), "io"), (0.2, _throat(s, 0.0), "io"),
                  (0.35, _throat(s, st.LIFT * 0.35), "io"), (0.9, _throat(s, st.LIFT))])


def hold_throat(s):
    return keyed([(0.0, _throat(s, st.LIFT)), (0.4, _throat(s, st.LIFT, 1.0)), (0.8, _throat(s, st.LIFT, -0.6))],
                 loop_len=1.2)


def arm_severed(s):
    held = _throat(s, st.LIFT)
    jerk = P(torso(-22, 14, 0, (0, -0.08, -0.05), s, look=0.2), braced(s), {"Neck": (12, 0, 4), "Head": (14, 0, 6)},
             {"arm_R": {"ikr": _v((0.10, -0.08, -0.40), s), "pole": (0.6, 1.0, 0.0), "hand": (0, 0, 0)}})
    fold = P(torso(-10, -24, 0, (0, 0.0, -0.10), s, look=0.0), braced(s), {"Neck": (-10, 0, 0), "Head": (-6, 0, 0)},
             {"arm_R": {"ikr": _v((-0.04, 0.12, -0.36), s), "pole": (0.8, 0.0, -0.6), "hand": (0, 0, 0)}})
    return keyed([(0.0, held, "snap"), (0.1, jerk, "io"), (0.55, fold, "io"), (1.0, P(fold, torso(-8, -26, 0, (0, 0.0, -0.11), s, look=0.0)))])


def throw_one_arm(s):
    hold = P(torso(0, -4, 0, (0, 0.0, -0.06), s), braced(s),
             {"arm_R": {"ikr": _v((-0.12, 0.44, -0.14), s), "pole": (1.0, -0.3, -0.5), "hand": (0, 0, 0)}})
    wind = P(torso(-45, 6, 0, (0, -0.05, -0.10), s), braced(s),
             {"arm_R": {"ikr": _v((0.40, -0.18, -0.16), s), "pole": (0.2, -0.4, -1.0), "hand": (0, 0, 0)}})
    hurl = P(torso(40, -16, 0, (0, 0.14, -0.10), s), braced(s),
             {"arm_R": {"ikr": _v((-0.12, 0.52, 0.12), s), "pole": (1.0, -0.2, -0.3), "hand": (0, 0, 0)}})
    after = P(torso(30, -12, 0, (0, 0.12, -0.08), s), braced(s),
              {"arm_R": {"ikr": _v((-0.18, 0.34, -0.20), s), "pole": (1.0, -0.2, -0.3), "hand": (0, 0, 0)}})
    return keyed([(0.0, hold, "io"), (0.45, wind, "in"), (THROW_RELEASE, hurl, "out"), (1.3, after)])


def add_all(rig, make_action):
    s = rig.head("Hips").z / 0.93
    make_action(rig, "spear_hand", spear_hand(s), 0.9)
    make_action(rig, "lift_throat", lift_throat(s), 0.9)
    make_action(rig, "hold_throat", hold_throat(s), 1.2, loop=True)
    make_action(rig, "arm_severed", arm_severed(s), 1.0)
    make_action(rig, "throw_one_arm", throw_one_arm(s), 1.3)
