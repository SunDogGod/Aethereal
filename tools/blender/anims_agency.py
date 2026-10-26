"""The Agency agents' story poses (agent.py adds them; the lieutenant wears the agent model).

    captor_knife       from behind, the knife (prop "Knife", drawn into his left hand while the pose
                       plays) laid across Aeneas's throat; his sword hangs low in his right hand.
                       He stands anims_story.HOSTAGE_GAP behind the hostage, facing the same way (loop).
    captor_knife_low   the same for Isabella (her throat sits lower)
    drag_by_arm        walking ahead, his left hand behind him hauling her by the wrist (loop, upper
                       body). Valentina ("dragged") follows: his root is DRAG_OFFSET from hers.
    heave_body         a two-handed heave of a body onto the fire: bend, lift, swing, throw (the
                       body leaves his hands at HEAVE_RELEASE). His sword is hidden meanwhile.
Contact points are real metres.
"""
from pose import keyed
from anims_combat import P, torso, _v
import anims_story as st

KNIFE_BLADE = (-90, 0, 180)   # the knife laid flat across the throat, pointing at the hostage's right
HEAVE_RELEASE = 1.05          # seconds into heave_body when the body leaves his hands (character_story.gd)


def sword_low(s, b=0.0):
    """His sword hanging point-down at his right side."""
    return {"arm_R": {"ikr": _v((0.085, 0.07, -0.47 + 0.004 * b), s), "pole": (0.4, -1, -0.3), "blade": (-12, -64, 70)}}


def captor_knife(s, throat_z=st.THROAT_Z):
    """His left arm comes over the hostage's left shoulder, the knife in a reverse grip lying across
    the throat, knuckles forward; chest close behind the hostage's back, chin over his shoulder."""
    gap = st.HOSTAGE_GAP

    def key(b, tw):
        return P(torso(-14 + tw, -7, 0, (0.01, 0.02, -0.04), s, hips_share=0.2, look=0.6),
                 {"Neck": (-4, 0, 5), "Head": (-6, 0, 8)},
                 {"leg_L": {"ankle": (-0.17 * s, 0.10, 0.085 * s), "pole": (-0.3, 1, 0), "foot": (0, 12)},
                  "leg_R": {"ankle": (0.16 * s, -0.16, 0.085 * s), "pole": (0.3, 1, 0), "foot": (0, -24)}},
                 {"arm_L": {"grip": (-0.075, gap + 0.075 + 0.004 * b, throat_z - 0.005), "blade": KNIFE_BLADE,
                            "pole": (-1.0, 0.5, -0.4)}},
                 sword_low(s, b))
    return keyed([(0.0, key(0, 0)), (0.7, key(1, -2)), (1.4, key(-1, 2))], loop_len=2.1)


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
    make_action(rig, "captor_knife_low", captor_knife(s, st.THROAT_Z * 1.66 / 1.72), 2.1, loop=True)
    make_action(rig, "drag_by_arm", drag_by_arm(s), 1.0, loop=True)
    make_action(rig, "heave_body", heave_body(s), 1.5)
