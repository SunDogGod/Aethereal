"""The Agency agents' story poses (agent.py adds them; the lieutenant wears the agent model).

    captor_knife       from behind, the knife (prop "Knife", drawn into his left hand while the pose
                       plays) laid across Aeneas's throat; his sword hangs low in his right hand.
                       He stands anims_story.HOSTAGE_GAP behind the hostage, facing the same way (loop).
    captor_knife_low   the same for Isabella (her throat sits lower)
    captor_grab(_low)  the grab that ends in captor_knife(_low) (anims_story.GRAB_LEN seconds; the
                       hostage plays "hostage_grabbed" alongside): a fist on the shoulder, a yank
                       back, the knife from the small of his back over the shoulder to the throat
    drag_by_arm        walking ahead, his left hand behind him hauling her by the wrist (loop, upper
                       body). Valentina ("dragged") follows: his root is DRAG_OFFSET from hers.
    heave_body         a two-handed heave of a body onto the fire: bend, lift, swing, throw (the
                       body leaves his hands at HEAVE_RELEASE). His sword is hidden meanwhile.
Contact points are real metres.
"""
import math
from pose import keyed
from anims_combat import P, torso, _v
import anims_story as st

KNIFE_BLADE = (-90, 0, 180)   # the knife laid flat across the throat, pointing at the hostage's right
HEAVE_RELEASE = 1.05          # seconds into heave_body when the body leaves his hands (character_story.gd)
GRAB_DRAW = 0.30              # seconds into captor_grab when the knife leaves its sheath for his hand (character_story.gd)
LOW_THROAT = st.THROAT_Z * 1.66 / 1.72   # Isabella's throat (she is 1.66 m)


def sword_low(s, b=0.0):
    """His sword hanging point-down at his right side."""
    return {"arm_R": {"ikr": _v((0.085, 0.07, -0.47 + 0.004 * b), s), "pole": (0.4, -1, -0.3), "blade": (-12, -64, 70)}}


def captor_key(s, throat_z=st.THROAT_Z, b=0.0, tw=0.0):
    """A key of the captor_knife loop: his left arm comes over the hostage's left shoulder, the
    knife in a reverse grip lying across the throat, knuckles forward; chest close behind the
    hostage's back, chin over his shoulder; the sword hangs low in his right hand."""
    gap = st.HOSTAGE_GAP
    return P(torso(-14 + tw, -7, 0, (0.01, 0.02, -0.04), s, hips_share=0.2, look=0.6),
             {"Neck": (-4, 0, 5), "Head": (-6, 0, 8)},
             {"leg_L": {"ankle": (-0.17 * s, 0.10, 0.085 * s), "pole": (-0.3, 1, 0), "foot": (0, 12)},
              "leg_R": {"ankle": (0.16 * s, -0.16, 0.085 * s), "pole": (0.3, 1, 0), "foot": (0, -24)}},
             {"arm_L": {"grip": (-0.075, gap + 0.075 + 0.004 * b, throat_z - 0.005), "blade": KNIFE_BLADE,
                        "pole": (-1.0, 0.5, -0.4)}},
             sword_low(s, b))


def captor_knife(s, throat_z=st.THROAT_Z):
    """The held loop (it starts on captor_key(), where captor_grab ends)."""
    return keyed([(0.0, captor_key(s, throat_z)), (0.7, captor_key(s, throat_z, 1, -2)),
                  (1.4, captor_key(s, throat_z, -1, 2))], loop_len=2.1)


def _knife_held(rig, p):
    """Pose p with his left hand round the knife's handle at the small of his back (the Knife
    bone), written as a free grip so it blends with the keys that carry the knife."""
    p = dict(p)
    p["arm_L"] = {"hold": ("Knife", 0.0, 0.0), "pole": (-1.0, -0.4, 0.1)}
    p = rig.hold_as_grip(p, "L", ref_yaw=-90.0)
    arm = p["arm_L"]
    ang, rad, z = arm.pop("gripc")
    t = math.radians(ang)
    arm["grip"] = (-rad * math.sin(t), rad * math.cos(t), z)
    return p


def captor_grab(rig, s, throat_z=st.THROAT_Z):
    """The grab from behind (GRAB_LEN seconds; the hostage's "hostage_grabbed" plays alongside):
    his right fist, sword and all, clamps down on the hostage's right shoulder and yanks him back
    while his left hand finds the knife at the small of his back (it leaves the sheath at
    GRAB_DRAW); the knife comes up past his hip, over the hostage's left shoulder and down across
    the throat (st.GRAB_KNIFE_AT); the right hand lets go and drops the sword low. Ends on
    captor_key(), the first frame of captor_knife."""
    gap, hs = st.HOSTAGE_GAP, throat_z / st.THROAT_Z      # hs: the hostage's size (Isabella's smaller)
    end = captor_key(s, throat_z)
    feet0 = {"leg_L": {"ankle": (-0.13 * s, 0.03, 0.085 * s), "pole": (-0.3, 1, 0), "foot": (0, 9)},
             "leg_R": {"ankle": (0.12 * s, -0.04, 0.085 * s), "pole": (0.3, 1, 0), "foot": (0, -8)}}
    step_l = {"leg_L": {"ankle": (-0.15 * s, 0.07, 0.14 * s), "pole": (-0.3, 1, 0), "foot": (-10, 10)},
              "leg_R": feet0["leg_R"]}
    feet1 = {"leg_L": end["leg_L"], "leg_R": feet0["leg_R"]}
    step_r = {"leg_L": end["leg_L"], "leg_R": {"ankle": (0.15 * s, -0.11, 0.13 * s), "pole": (0.3, 1, 0), "foot": (-14, -16)}}
    feet2 = {"leg_L": end["leg_L"], "leg_R": end["leg_R"]}

    def right(x, y, z, blade, pole=(0.8, -0.5, -0.2)):
        return {"arm_R": {"ikr": (x, y, z), "pole": pole, "blade": blade}}
    clamp = (-165, -50, 90)                  # the blade out of the back of his fist, behind him
    sx, sz = 0.165 * hs - 0.19, 1.43 * hs - 1.40     # his fist on the hostage's shoulder, from his own
    on = right(sx, 0.14, sz, clamp)
    yank = right(sx, 0.09, sz - 0.01, clamp)

    def left(x, y, z, blade):
        return {"arm_L": {"grip": (x, y, z), "blade": blade, "pole": (-1.0, 0.2, -0.4)}}
    body0 = P(torso(0, -3, 0, (0, 0, -0.02), s), feet0, sword_low(s))
    k0 = _knife_held(rig, body0)                          # his hand on its way to the knife
    k0["arm_L"] = dict(k0["arm_L"], grip=tuple(a + d for a, d in zip(k0["arm_L"]["grip"], (-0.06, 0.08, -0.06))))
    reach = P(torso(-4, -6, 0, (0, 0.02, -0.035), s), step_l, right(0.02, 0.16, -0.20, (-120, -30, 80)))
    lunge = P(torso(-6, -10, 0, (0, 0.05, -0.05), s, look=0.8), feet1, on)
    pulled = P(torso(-10, -3, 0, (0, -0.01, -0.05), s, look=0.7), step_r, yank)
    drawing = P(torso(-4, -6, 0, (0, 0.0, -0.05), s, look=0.7), feet2, right(sx, 0.11, sz - 0.01, clamp),
                left(-0.33, 0.04, 1.08, (-20, -30, 135)))
    over = P(torso(-12, -8, 0, (0.01, 0.02, -0.045), s, look=0.6), feet2, right(sx, 0.12, sz - 0.01, clamp),
             left(-0.25, gap - 0.02, throat_z + 0.10, (-60, 35, 180)))
    cut = P(end, right(sx, 0.12, sz - 0.02, clamp))
    let_go = P(end, right(0.07, 0.14, -0.16, (-80, -60, 80)))
    return keyed([(0.0, k0, "io"),
                  (0.10, P(reach, {"arm_L": _knife_held(rig, reach)["arm_L"]}), "io"),
                  (0.20, P(lunge, {"arm_L": _knife_held(rig, lunge)["arm_L"]}), "io"),
                  (GRAB_DRAW, P(pulled, {"arm_L": _knife_held(rig, pulled)["arm_L"]}), "io"),
                  (0.52, drawing, "io"), (0.74, over, "snap"), (st.GRAB_KNIFE_AT, cut, "io"),
                  (1.15, let_go, "io"), (st.GRAB_LEN, end)])


def drag_by_arm(s):
    """Leaning into the pull, his left hand behind him at her wrist, the sword carried low (loop)."""
    def key(pull, look):
        return P({"Spine": (-7 - 2 * pull, 0, 8), "Chest": (-5 - pull, 0, 6), "Neck": (4, 0, -8 + look),
                  "Head": (5, 0, -6 + look * 2), "Shoulder_L": (0, 0, -6 * pull)},
                 {"arm_L": {"ik": (-0.20, -0.40 - 0.03 * pull, 1.02), "pole": (-0.7, 0.4, -0.7), "hand": (-30, 0, 10)},
                  "arm_R": {"ikr": _v((0.04, 0.16, -0.44), s), "pole": (0.4, -1, -0.3), "blade": (-6, -50, 70)}})
    return keyed([(0.0, key(0, 0)), (0.35, key(1, 10)), (0.7, key(0.4, 4))], loop_len=1.0)


def heave_body(s):
    """Hands under a body at his feet; up to the chest; a swing back; heaved forward and up."""
    def hands(y, z, x=0.17):
        return {"arm_L": {"ik": _v((-x, y, z), s), "pole": (-1.0, -0.3, -0.6), "hand": (-40, 0, 30)},
                "arm_R": {"ik": _v((x, y, z), s), "pole": (1.0, -0.3, -0.6), "hand": (-40, 0, -30)}}

    def legs(lf, rb, bend=0.0):
        return {"leg_L": {"ankle": _v((-0.16, lf, 0.085), s), "pole": (-0.3, 1, 0), "foot": (0, 10)},
                "leg_R": {"ankle": _v((0.16, rb, 0.085 + bend), s), "pole": (0.3, 1, 0), "foot": (-bend * 300, -14)}}
    bent = P(torso(0, -34, 0, (0, -0.06, -0.30), s, look=0.6), legs(0.06, -0.12), hands(0.42, 0.60))
    lifted = P(torso(0, -2, 0, (0, -0.01, -0.07), s), legs(0.06, -0.12), hands(0.30, 1.16))
    wind = P(torso(0, 10, 0, (0, -0.07, -0.10), s), legs(0.06, -0.16), hands(0.20, 1.30))
    throw = P(torso(0, -20, 0, (0, 0.15, -0.07), s, look=0.5), legs(0.34, -0.14, 0.05), hands(0.64, 1.50, 0.15))
    after = P(torso(0, -10, 0, (0, 0.13, -0.05), s), legs(0.34, -0.12), hands(0.42, 1.06, 0.14))
    return keyed([(0.0, bent, "io"), (0.45, lifted, "io"), (0.8, wind, "in"), (HEAVE_RELEASE, throw, "out"),
                  (1.5, after)])


def add_all(rig, make_action):
    s = rig.head("Hips").z / 0.93
    make_action(rig, "captor_knife", captor_knife(s), 2.1, loop=True)
    make_action(rig, "captor_knife_low", captor_knife(s, LOW_THROAT), 2.1, loop=True)
    make_action(rig, "captor_grab", captor_grab(rig, s), st.GRAB_LEN)
    make_action(rig, "captor_grab_low", captor_grab(rig, s, LOW_THROAT), st.GRAB_LEN)
    make_action(rig, "drag_by_arm", drag_by_arm(s), 1.0, loop=True)
    make_action(rig, "heave_body", heave_body(s), 1.5)
