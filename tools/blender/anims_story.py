"""Story poses every character has (the cutscenes call them by name; scripts/character_story.gd).

    hostage            held from behind with a knife at the throat: chin up, both hands on the
                       captor's forearm, a small struggle (loop). The captor ("captor_knife",
                       anims_agency.py) stands HOSTAGE_GAP metres behind, facing the same way.
    drop_to_knees      the legs give and he drops onto both knees, slumped (held)
    captive            wrists bound behind the back, head bowed (loop)
    dragged            pulled along by the right wrist, leaning back (loop, upper body: the legs
                       keep walking while the scene moves her). The agent's "drag_by_arm" leads
                       DRAG_OFFSET ahead of her.
    limp               the body goes slack: head back, arms and legs loose (held), for a body
                       thrown or carried (the scene moves the node)
    lifted_by_throat   lifted off his feet by the throat, hands on the lifting arm (held); then
    held_by_throat     dangling and struggling, legs kicking (loop). The captain ("lift_throat",
                       captain_anims.py) stands THROAT_GAP metres in front, facing him.
Contact points are real metres (not scaled by height), so pairs meet whoever plays them.
"""
import math
from pose import keyed
from anims_combat import P, torso, _v

HOSTAGE_GAP = 0.30          # the captor's feet this far behind the hostage's
THROAT_Z = 1.385            # where the captor's knife sits on Aeneas (1.72 m); Isabella's is lower
LIFT = 0.40                 # how far the captain lifts Aeneas off the floor
THROAT_GAP = 0.62           # the captain's root this far in front of Aeneas's, facing him
DRAG_OFFSET = (0.26, 0.78)  # the agent's root from hers: metres to her right, metres ahead


def feet(s, w=0.12, front=0.02, turn=7):
    return {"leg_L": {"ankle": _v((-w, front, 0.085), s), "pole": (-0.2, 1, 0), "foot": (0, turn)},
            "leg_R": {"ankle": _v((w, -front, 0.085), s), "pole": (0.2, 1, 0), "foot": (0, -turn)}}


def hang(s, dx=0.0, dy=0.0, dz=0.0):
    """Both arms hanging loose at the sides."""
    return {"arm_L": {"ikr": _v((-0.03 - dx, 0.05 + dy, -0.52 + dz), s), "pole": (-0.3, -1, -0.2), "hand": (6, 0, -8)},
            "arm_R": {"ikr": _v((0.03 + dx, 0.05 + dy, -0.52 + dz), s), "pole": (0.3, -1, -0.2), "hand": (6, 0, 8)}}


def hostage(s):
    """Stiff and on his toes, leaning back from the blade, chin up; his hands claw at the forearm
    across his throat (it comes round his left shoulder)."""
    def key(tw, tug, lift):
        z = THROAT_Z * s / 1.0
        return P(torso(tw, 7, 0, (0, -0.035, -0.008 + lift), s, hips_share=0.3),
                 {"Neck": (12, 0, -tw * 0.5), "Head": (14, 0, -4 - tw)},
                 {"leg_L": {"ankle": _v((-0.12, 0.03, 0.085 + lift), s), "pole": (-0.2, 1, 0), "foot": (-8 - lift * 120, 6)},
                  "leg_R": {"ankle": _v((0.12, -0.03, 0.085 + lift), s), "pole": (0.2, 1, 0), "foot": (-8 - lift * 120, -6)}},
                 {"arm_L": {"ik": (-0.10 * s, (0.15 + tug) * s, z - 0.02 * s), "pole": (-0.9, -0.1, -0.5),
                            "hand": (-30, 0, 20)},
                  "arm_R": {"ik": (0.02 * s, (0.18 + tug) * s, z - 0.035 * s), "pole": (0.9, -0.2, -0.5),
                            "hand": (-20, 0, -40)}})
    return keyed([(0.0, key(0, 0.0, 0.0)), (0.7, key(-4, 0.02, 0.012)), (1.4, key(3, -0.01, 0.006))], loop_len=2.1)


def drop_to_knees(s):
    """The knees give; he lands on both and slumps there, arms hanging (held)."""
    stand = P(torso(0, -2, 0, (0, 0, -0.02), s), feet(s), hang(s))
    buckle = P(torso(0, -16, 0, (0, 0.03, -0.24), s, look=0.3),
               {"leg_L": {"ankle": _v((-0.12, -0.02, 0.085), s), "pole": (-0.1, 1, 0), "foot": (0, 6)},
                "leg_R": {"ankle": _v((0.12, -0.06, 0.085), s), "pole": (0.1, 1, 0), "foot": (-10, -6)}},
               hang(s, 0.04, 0.06, 0.04))
    knees = {"leg_L": {"ankle": _v((-0.13, -0.33, 0.075), s), "pole": (-0.1, 1, -0.3), "foot": (-62, 4)},
             "leg_R": {"ankle": _v((0.13, -0.35, 0.075), s), "pole": (0.1, 1, -0.3), "foot": (-62, -4)}}
    down = P(torso(0, -14, 0, (0, 0.05, -0.475), s, look=0.0), knees, hang(s, 0.02, 0.10, 0.06),
             {"Neck": (-8, 0, 0), "Head": (-12, 0, 0)})
    bounce = P(down, {"hips": {"loc": _v((0, 0.05, -0.46), s), "rot": (-6, 0, 0)}})
    slump = P(torso(2, -20, 0, (0, 0.04, -0.49), s, look=0.0), knees, hang(s, 0.0, 0.14, 0.10),
              {"Neck": (-14, 0, 2), "Head": (-16, 0, 4)})
    return keyed([(0.0, stand, "in"), (0.22, buckle, "in"), (0.42, down, "out"), (0.52, bounce, "io"),
                   (0.95, slump)])


def captive(s):
    """Wrists bound behind her back, shoulders drawn in, head bowed; a slow sway (loop)."""
    def key(sway, look):
        return P(torso(sway, -4, 0, (0, 0, -0.015), s, hips_share=0.4, look=0.0), feet(s, 0.10, 0.0, 5),
                 {"Neck": (-10, 0, look), "Head": (-14, 0, look * 1.5), "Shoulder_L": (0, 0, 6), "Shoulder_R": (0, 0, -6)},
                 {"arm_L": {"ik": _v((-0.035, -0.13, 0.95), s), "pole": (-1.0, -0.7, 0.0), "hand": (0, 0, 40)},
                  "arm_R": {"ik": _v((0.035, -0.13, 0.95), s), "pole": (1.0, -0.7, 0.0), "hand": (0, 0, -40)}})
    return keyed([(0.0, key(0, 0)), (1.5, key(3, 6)), (3.0, key(-2, -4))], loop_len=4.5)


def dragged(s):
    """Hauled along by her right wrist: her arm stretched ahead and up, her body leaning back
    against the pull, her left arm out behind for balance (loop; upper body)."""
    def key(jerk, look):
        return P({"Spine": (8 + jerk * 4, 3, 8), "Chest": (6 + jerk * 3, 2, 6), "Neck": (-6, 0, -10 + look),
                  "Head": (-10, 4, -14 + look)},
                 {"arm_R": {"ik": _v((0.06, 0.40 + 0.04 * jerk, 1.10 + 0.02 * jerk), s), "pole": (0.7, -0.4, -0.6),
                            "hand": (10, 0, 0)},
                  "arm_L": {"ikr": _v((-0.20, -0.16, -0.36), s), "pole": (-0.6, -0.2, -1.0), "hand": (0, 0, -20)}})
    return keyed([(0.0, key(0.0, 0)), (0.35, key(1.0, 6)), (0.7, key(0.3, -4))], loop_len=1.0)


def limp(s):
    """Slack: the head falls back, arms and legs hang loose (held)."""
    slack = {"hips": {"loc": (0, 0, 0), "rot": (6, 0, 4)}, "Spine": (10, 0, 2), "Chest": (8, 0, 0),
             "Neck": (18, 0, 6), "Head": (16, 0, 12),
             "arm_L": {"ikr": _v((-0.30, -0.06, -0.38), s), "pole": (-0.4, -0.6, 0.6), "hand": (20, 0, -20)},
             "arm_R": {"ikr": _v((0.32, 0.02, -0.34), s), "pole": (0.4, -0.6, 0.6), "hand": (20, 0, 20)},
             "leg_L": {"fk": [(28, -6, 0), (-48, 0, 0), (-30, 0, 0)]},
             "leg_R": {"fk": [(12, 8, 0), (-30, 0, 0), (-30, 0, 0)]}}
    start = P(torso(0, -2, 0, (0, 0, -0.02), s), hang(s),
              {"leg_L": {"fk": [(0, 0, 0), (0, 0, 0), (0, 0, 0)]}, "leg_R": {"fk": [(0, 0, 0), (0, 0, 0), (0, 0, 0)]}})
    return keyed([(0.0, start, "out"), (0.35, slack)])


def throat_hold(s, kick=0.0, tug=0.0, lift=LIFT):
    """Off the floor by `lift` metres, the captain's fist round his throat; both hands on the
    captain's forearm (it comes straight at him), legs hanging, `kick` swings them."""
    z = 1.385 * s + lift
    return P({"hips": {"loc": (0, 0, lift - 0.01), "rot": (4 + 4 * kick, 0, 0)},
              "Spine": (-2, 0, 2 * kick), "Chest": (-3, 0, -2 * kick), "Neck": (10, 0, 0), "Head": (10, 0, 3 * kick)},
             {"arm_L": {"ik": (-0.06, 0.20 + tug, z - 0.05), "pole": (-1.0, -0.2, -0.4), "hand": (-20, 0, 30)},
              "arm_R": {"ik": (0.07, 0.19 - tug, z - 0.06), "pole": (1.0, -0.2, -0.4), "hand": (-20, 0, -30)},
              "leg_L": {"fk": [(14 + 22 * kick, -4, 0), (-18 - 26 * max(0.0, kick), 0, 0), (-38, 0, 0)]},
              "leg_R": {"fk": [(10 - 22 * kick, 4, 0), (-14 - 26 * max(0.0, -kick), 0, 0), (-42, 0, 0)]}})


def lifted_by_throat(s):
    stand = P(torso(0, 4, 0, (0, -0.02, -0.01), s), feet(s, 0.11, 0.0),
              {"arm_L": {"ik": (-0.06, 0.20, 1.385 * s - 0.08), "pole": (-1.0, -0.2, -0.4), "hand": (-20, 0, 30)},
               "arm_R": {"ik": (0.07, 0.19, 1.385 * s - 0.09), "pole": (1.0, -0.2, -0.4), "hand": (-20, 0, -30)}})
    toes = P(throat_hold(s, 0.0, 0.0, LIFT * 0.35),
             {"leg_L": {"ankle": _v((-0.11, 0.0, 0.085 + LIFT * 0.3), s), "pole": (-0.1, 1, 0), "foot": (-55, 4)},
              "leg_R": {"ankle": _v((0.11, 0.0, 0.085 + LIFT * 0.3), s), "pole": (0.1, 1, 0), "foot": (-55, -4)}})
    return keyed([(0.0, stand, "in"), (0.35, toes, "io"), (0.9, throat_hold(s, 0.3, 0.0))])


def held_by_throat(s):
    return keyed([(0.0, throat_hold(s, 0.3, 0.0)), (0.4, throat_hold(s, -0.5, 0.02)),
                  (0.8, throat_hold(s, 0.6, -0.01))], loop_len=1.2)


def add_all(rig, make_action):
    s = rig.head("Hips").z / 0.93
    make_action(rig, "hostage", hostage(s), 2.1, loop=True)
    make_action(rig, "drop_to_knees", drop_to_knees(s), 0.95)
    make_action(rig, "captive", captive(s), 4.5, loop=True)
    make_action(rig, "dragged", dragged(s), 1.0, loop=True)
    make_action(rig, "limp", limp(s), 0.35)
    make_action(rig, "lifted_by_throat", lifted_by_throat(s), 0.9)
    make_action(rig, "held_by_throat", held_by_throat(s), 1.2, loop=True)
