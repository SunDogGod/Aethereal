"""Kael's animations: the shared set with his right hand empty (Lamento rides on his back), and
the end of the hall, where he draws it.

    draw_lamento   his right hand reaches over his shoulder and closes on the grip (LAMENTO_SWAP:
                   the game moves the blade from his back, "Lamento", to his hand, "LamentoDrawn"),
                   draws it up and over, and settles low and ready
    sever_cut      from high on his right, one cut straight down through the captain's raised arm
                   (SEVER_HIT: the blade passes shoulder height in front of him)
    behead_cut     a level cut from his right to his left at the neck of a kneeling man
                   (BEHEAD_HIT; the scene cuts away)
    bloody_stand   standing over him, the blade held low and out at his side (held). The blood:
                   set_lamento(true, true) shows "LamentoBlood" in place of the clean blade.
Every key places the sword grip ('grip' + 'blade': where the grip is, where the blade points).
"""
from mathutils import Vector
from pose import make_action, keyed, dirs_to_blade
from anims_combat import P, torso, stance, _v
import anims_loco
import anims_combat
import anims_story as st

LAMENTO_SWAP = 0.32     # character_story.gd LAMENTO_SWAP
SEVER_HIT = 0.30
BEHEAD_HIT = 0.32


def mirror_arm(a):
    """The right arm doing what the left does (mirrored): his hands swing free."""
    x, y, z = a["ikr"]
    px, py, pz = a.get("pole", (-0.3, -1.0, -0.2))
    hx, hy, hz = a.get("hand", (0, 0, 0))
    return {"ikr": (-x, y, z), "pole": (-px, py, pz), "hand": (hx, -hy, -hz)}


def loco(rig, s):
    """The shared loops with his right arm swinging free like his left; the idle stands taller."""
    L = anims_loco

    def free(f, half):
        def at(t):
            p = f(t)
            p["arm_R"] = mirror_arm(f((t + 0.5) % 1.0 if half else t)["arm_L"])
            return p
        return at

    for name, f in (("walk", L.walk), ("run", L.run), ("sprint", L.sprint), ("crouch_walk", L.crouch_walk)):
        make_action(rig, name, free(f(rig, s), True), 1.0, loop=True)
    stand = free(L.idle(rig, s), False)

    def idle(t):
        p = stand(t)
        p["Head"] = (p["Head"][0] + 2.5, p["Head"][1], p["Head"][2])     # chin up
        p["Chest"] = (p["Chest"][0] + 1.5, p["Chest"][1], p["Chest"][2])
        return p
    make_action(rig, "idle", idle, 2.4, loop=True)
    make_action(rig, "crouch_idle", free(L.crouch_idle(rig, s), False), 2.0, loop=True)
    make_action(rig, "jump", L.jump(rig, s), 0.5)
    make_action(rig, "fall", L.fall(rig, s), 0.8, loop=True)


def sword(g, blade, pole=(0.4, -1.0, -0.2)):
    return {"arm_R": {"grip": tuple(g), "blade": blade, "pole": pole}}


def free_left(s, x=-0.06, y=0.06, z=-0.48):
    return {"arm_L": {"ikr": _v((x, y, z), s), "pole": (-0.4, -1.0, -0.3), "hand": (5, 0, -10)}}


def at_back(s, grip, direction):
    """Where his hand takes Lamento on his back: the grip, and the blade turned exactly as the
    back copy lies (its width across = the drawn copy's edge axis)."""
    d = Vector(direction).normalized()
    e = (Vector((1, 0, 0)) - d * d.x).normalized()
    return Vector(grip) * s, dirs_to_blade(d, d.cross(e), -170.0)


def draw_lamento(s, grip, direction):
    g, b = at_back(s, grip, direction)
    stand = P(torso(0, -1, 0, (0, 0, -0.02), s), st.feet(s), free_left(s),
              sword(_v((0.20, 0.06, 0.95), s), (-20, -70, 70)))
    reach = P(torso(4, 0, 0, (0, 0, -0.02), s), st.feet(s), free_left(s), sword(g + Vector((0.03, 0.05, -0.06)), b, (0.4, 0.3, 1.0)))
    grab = P(torso(0, 0, 0, (0, 0, 0), s), st.feet(s), free_left(s), sword(g, b, (0.4, 0.3, 1.0)))
    up = P(torso(-6, 2, 0, (0, 0, -0.02), s), st.feet(s), free_left(s),
           sword(_v((0.26, 0.02, 1.80), s), (-170, 60, 70), (0.8, 0.2, 0.6)))
    over = P(torso(-12, -4, 0, (0, 0.02, -0.04), s), stance(s), free_left(s),
             sword(_v((0.16, 0.34, 1.40), s), (-20, 30, 70), (0.6, -0.6, -0.4)))
    ready = low_ready(s)
    return keyed([(0.0, stand, "io"), (0.2, reach, "io"), (LAMENTO_SWAP, grab, "in"), (0.55, up, "io"),
                  (0.75, over, "io"), (1.0, ready)])


def low_ready(s):
    return P(torso(-10, -3, 0, (0, 0, -0.05), s), stance(s), free_left(s),
             sword(_v((0.16, 0.30, 1.00), s), (-18, -22, 70), (0.5, -0.7, -0.4)))


def sever_cut(s):
    high = P(torso(-24, 8, 0, (0, -0.03, -0.04), s), stance(s), free_left(s, -0.12, 0.10, -0.40),
             sword(_v((0.22, 0.06, 1.95), s), (-175, 40, 90), (0.8, 0.0, 0.6)))
    hit = P(torso(4, -14, 0, (0, 0.10, -0.08), s), stance(s), free_left(s, -0.16, 0.0, -0.42),
            sword(_v((0.06, 0.46, 1.48), s), (0, 2, 90), (0.6, -0.6, -0.3)))
    low = P(torso(20, -20, 0, (0, 0.12, -0.12), s), stance(s), free_left(s, -0.18, -0.04, -0.40),
            sword(_v((-0.12, 0.36, 0.92), s), (25, -55, 90), (0.6, -0.8, -0.2)))
    return keyed([(0.0, low_ready(s), "io"), (0.18, high, "in"), (SEVER_HIT, hit, "out"), (0.42, low, "io"),
                  (0.55, P(low, torso(18, -18, 0, (0, 0.11, -0.11), s)))])


def behead_cut(s):
    wind = P(torso(-42, -6, 0, (0, -0.02, -0.10), s), stance(s), free_left(s, -0.10, 0.12, -0.40),
             sword(_v((0.42, -0.02, 1.15), s), (-125, 4, 180), (0.4, -0.6, -0.6)))
    hit = P(torso(0, -10, 0, (0, 0.08, -0.12), s), stance(s), free_left(s, -0.16, 0.0, -0.42),
            sword(_v((0.06, 0.46, 1.08), s), (0, 0, 180), (0.6, -0.6, -0.4)))
    through = P(torso(38, -10, 0, (0, 0.08, -0.12), s), stance(s), free_left(s, -0.20, -0.06, -0.38),
                sword(_v((-0.40, 0.22, 1.04), s), (110, -6, 180), (0.6, -0.4, -0.6)))
    return keyed([(0.0, low_ready(s), "io"), (0.2, wind, "in"), (BEHEAD_HIT, hit, "lin"), (0.45, through, "out"),
                  (0.6, P(through, torso(40, -9, 0, (0, 0.08, -0.12), s)))])


def bloody_stand(s):
    tall = P(torso(-6, 1, 0, (0, 0, -0.01), s), st.feet(s, 0.13, 0.03, 8), free_left(s, -0.05, 0.04, -0.50),
             {"Neck": (-6, 0, 0), "Head": (-8, 0, 0)},
             sword(_v((0.25, 0.10, 0.86), s), (-42, -44, 70), (0.4, -1.0, -0.2)))
    return keyed([(0.0, low_ready(s), "io"), (1.0, tall)])


def add_all(rig, grip, direction):
    s = rig.head("Hips").z / 0.93
    loco(rig, s)
    anims_combat.add_all(rig)
    make_action(rig, "draw_lamento", draw_lamento(s, grip, direction), 1.0)
    make_action(rig, "sever_cut", sever_cut(s), 0.55)
    make_action(rig, "behead_cut", behead_cut(s), 0.6)
    make_action(rig, "bloody_stand", bloody_stand(s), 1.0)
