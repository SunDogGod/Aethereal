"""The captain fights with his fist: three blows, each a wind-up held while his visor flashes
("telegraph*", upper body) and the blow itself ("strike*", whole body). The fight picks which
(scripts/enemy_fighter.gd next_blow): a single swing is a hook, a combo jabs and hooks, a heavy or
the finishing blow is the overhand.
    telegraph / strike              the jab: fist drawn back to the chin, then straight out
    telegraph_hook / strike_hook    the hook: elbow up and out, the fist swings round to his front
    telegraph_heavy / strike_heavy  the overhand: fist cocked high behind his head, a step in and a
                                    blow driven down through the target
The hit lands as strike* starts (the game deals it on the same frame), so each blow reaches its
target in under a tenth of a second.
Written for a RIGHT fist, like everything else: captain_anims.py mirrors it onto his left arm.
"""
from pose import keyed
from anims_combat import P, torso, stance, _v

TELEGRAPH_LEN = 0.6     # character_animator.gd scales the wind-up to the fight's wind-up time
STRIKE_LEN = 0.5


def fist(s, x, y, z, pole=(0.7, -0.2, -1.0), hand=(0, 0, 0)):
    """His fist at (x, y, z) from his shoulder."""
    return {"arm_R": {"ikr": _v((x, y, z), s), "pole": pole, "hand": hand}}


def guard_fist(s):
    """On guard: chin down, the fist up by his jaw, the stump side turned away."""
    return P(torso(-12, -5, 0, (0, 0, -0.06), s, hips_share=0.1), stance(s), fist(s, -0.07, 0.24, -0.10),
             {"Neck": (-4, 0, 6), "Head": (-6, 0, 8)})


def telegraph(s):
    back = P(torso(-30, 6, 0, (0, -0.03, -0.07), s, hips_share=0.0), stance(s), fist(s, 0.0, 0.06, -0.06))
    return keyed([(0.0, guard_fist(s), "out"), (0.35, back, "io"), (TELEGRAPH_LEN, P(back, torso(-34, 7, 0, (0, -0.03, -0.07), s, hips_share=0.0)))])


def strike(s):
    back = P(torso(-30, 6, 0, (0, -0.03, -0.07), s), stance(s), fist(s, 0.0, 0.06, -0.06))
    out = P(torso(16, -10, 0, (0, 0.08, -0.08), s), stance(s), fist(s, -0.10, 0.60, -0.02, (0.9, -0.1, -0.4)))
    return keyed([(0.0, back, "snap"), (0.07, out, "io"), (0.2, out, "io"), (STRIKE_LEN, guard_fist(s))])


def telegraph_hook(s):
    wide = P(torso(-38, 3, 0, (0, -0.02, -0.08), s, hips_share=0.0), stance(s),
             fist(s, 0.30, -0.04, -0.06, (0.4, -0.6, 0.7)))
    return keyed([(0.0, guard_fist(s), "out"), (0.35, wide, "io"),
                  (TELEGRAPH_LEN, P(wide, torso(-42, 4, 0, (0, -0.02, -0.08), s, hips_share=0.0)))])


def strike_hook(s):
    wide = P(torso(-38, 3, 0, (0, -0.02, -0.08), s), stance(s), fist(s, 0.30, -0.04, -0.06, (0.4, -0.6, 0.7)))
    mid = P(torso(-5, -6, 0, (0, 0.04, -0.09), s), stance(s), fist(s, 0.16, 0.44, 0.0, (1.0, -0.2, 0.4)))
    hit = P(torso(30, -8, 0, (0, 0.06, -0.09), s), stance(s), fist(s, -0.26, 0.44, 0.0, (1.0, 0.2, 0.4)))
    through = P(torso(42, -10, 0, (0, 0.06, -0.09), s), stance(s), fist(s, -0.40, 0.22, -0.08, (1.0, 0.3, 0.2)))
    return keyed([(0.0, wide, "in"), (0.05, mid, "lin"), (0.09, hit, "out"), (0.2, through, "io"),
                  (STRIKE_LEN, guard_fist(s))])


def _cocked(s):
    return P(torso(-30, 14, 0, (0, -0.06, -0.08), s, hips_share=0.0), stance(s),
             fist(s, 0.10, -0.12, 0.30, (0.8, 0.2, 0.4)))


def telegraph_heavy(s):
    return keyed([(0.0, guard_fist(s), "out"), (0.4, _cocked(s), "io"),
                  (TELEGRAPH_LEN, P(_cocked(s), torso(-33, 16, 0, (0, -0.07, -0.09), s, hips_share=0.0)))])


def strike_heavy(s):
    lunge = {"leg_L": {"ankle": _v((-0.15, 0.52, 0.085), s), "pole": (-0.2, 1, 0), "foot": (0, 8)},
             "leg_R": {"ankle": _v((0.15, -0.20, 0.10), s), "pole": (0.3, 1, 0), "foot": (-24, -24)}}
    rise = P(torso(-10, 4, 0, (0, 0.10, -0.08), s), lunge, fist(s, 0.06, 0.28, 0.28, (0.9, 0.0, 0.4)))
    hit = P(torso(20, -26, 0, (0, 0.24, -0.18), s), lunge, fist(s, -0.06, 0.56, -0.26, (0.9, -0.2, 0.2)))
    low = P(torso(26, -32, 0, (0, 0.24, -0.20), s), lunge, fist(s, -0.14, 0.38, -0.50, (0.9, -0.4, 0.2)))
    return keyed([(0.0, _cocked(s), "in"), (0.05, rise, "lin"), (0.10, hit, "out"), (0.32, low, "io"),
                  (0.7, guard_fist(s))])


def add_all(rig, make_action):
    s = rig.head("Hips").z / 0.93
    make_action(rig, "telegraph", telegraph(s), TELEGRAPH_LEN)
    make_action(rig, "strike", strike(s), STRIKE_LEN)
    make_action(rig, "telegraph_hook", telegraph_hook(s), TELEGRAPH_LEN)
    make_action(rig, "strike_hook", strike_hook(s), STRIKE_LEN)
    make_action(rig, "telegraph_heavy", telegraph_heavy(s), TELEGRAPH_LEN)
    make_action(rig, "strike_heavy", strike_heavy(s), 0.7)
