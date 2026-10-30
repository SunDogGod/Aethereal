"""The Grey's clips (grey_alien.py builds the body):
    idle       (loop, 6 s) very still: slow shallow breaths, the head tilting slowly to one side and back
    lean_look  (3.4 s, holds its last frame) bends over a bed from the waist, the forearms coming up with
               the long hands drooping from the wrists, the head tipping down and sideways to look at the
               sleeper (its face aims about 0.5 m ahead of its feet, 0.5 m off the floor)
    reach      (3.0 s, holds) from the end of lean_look: the right hand comes up, turns its palm to the
               sleeper and reaches slowly for his face, long fingers first (stops ~0.15 m short). Play it
               after lean_look.
Keys are (time in seconds, pose); poses are pose.py dicts. Times and angles are the numbers to tune.
"""
from mathutils import Vector
from pose import make_action, keyed

FWD = (0.0, 1.0, 0.0)
HANG_R = (0.045, 0.03, -0.50)       # a hanging wrist, from the shoulder (the arm is 0.53 m)
HANG_DIR = (0.0, 0.12, -1.0)        # the hand hangs fingers down, palm to the thigh
RAISED = (0.0, 0.17, -0.24)         # lean_look: wrist ahead of the shoulder, elbow bent out and back
DROOP = (0.0, 0.35, -1.0)           # ...the hand drooping from it
# reach: from the right shoulder (after the lean) toward the sleeper's eyes, which lean_look's gaze
# lands on: about 0.6 m ahead of its feet and 0.5 m off the floor. The wrist stops REACH_LEN along it
# (aimed at his chin, so its face stays in view over the hand), the fingers reaching on toward his eyes.
TO_VIEWER = (-0.16, 0.50, -0.43)
REACH_LEN = 0.30


def _norm(v):
    return tuple(Vector(v).normalized())


def _arm(side, rel, aim=HANG_DIR, thumb=FWD, pole=None):
    k = 1 if side == "R" else -1
    return {"ikr": (rel[0] * k, rel[1], rel[2]), "pole": (pole[0] * k, pole[1], pole[2]) if pole else (0.4 * k, -1.0, -0.2),
            "hand_aim": (_norm((aim[0] * k, aim[1], aim[2])), _norm((thumb[0] * k, thumb[1], thumb[2])))}


def _pose(rig, hips=(0, 0, 0), hips_rot=(0, 0, 0), spine=(0, 0, 0), chest=(0, 0, 0), neck=(-4, 0, 0),
          head=(0, 0, 0), arm_r=None, arm_l=None, sh_r=(0, 0, 0)):
    return {"hips": {"loc": hips, "rot": hips_rot}, "Spine": spine, "Chest": chest, "Neck": neck, "Head": head,
            "Shoulder_R": sh_r, "Shoulder_L": (0, 0, 0),
            "arm_R": arm_r or _arm("R", HANG_R), "arm_L": arm_l or _arm("L", HANG_R),
            "leg_R": {"ankle": tuple(rig.head("Foot_R")), "pole": FWD, "foot": (0.0, 0.0)},
            "leg_L": {"ankle": tuple(rig.head("Foot_L")), "pole": FWD, "foot": (0.0, 0.0)}}


def idle(rig):
    """Two slow breaths per loop; the head leans over to its right and comes back."""
    def p(breath, tilt, turn):
        return _pose(rig, hips=(0, 0, -0.002 * breath), spine=(0.4 * breath, 0, 0), chest=(1.2 * breath, 0, 0),
                     neck=(-4 - 0.6 * breath, 0, 0), head=(-1.0 + 0.5 * breath, tilt, turn))
    return keyed([(0.0, p(0, 0, 0)), (1.5, p(1, 4, 1)), (3.0, p(0, 9, 2)), (4.5, p(1, 4, 1))], loop_len=6.0)


def _bent(rig, head, neck=(-4, 0, 2), arms=RAISED, lean=1.0, chest_z=0.0, arm_r=None, sh_r=(0, 0, 0)):
    raised = lambda side: _arm(side, arms, aim=DROOP, pole=(0.7, -0.6, -0.3))
    return _pose(rig, hips=(0, -0.05 * lean, -0.012 * lean), hips_rot=(-8 * lean, 0, 0), spine=(-20 * lean, 0, 0),
                 chest=(-18 * lean, 0, chest_z), neck=neck, head=head,
                 arm_r=arm_r or raised("R"), arm_l=raised("L"), sh_r=sh_r)


def lean_end(rig, tilt=16.0):
    return _bent(rig, head=(-10, tilt, 6))


def lean_look(rig):
    start = idle(rig)(0.0)
    mid = _bent(rig, head=(-6, 4, 3), neck=(-4, 0, 0), arms=(0.02, 0.12, -0.34), lean=0.9)
    return keyed([(0.0, start), (2.2, mid), (3.4, lean_end(rig))])


def _palm(fingers, back):
    """hand_aim for a right hand whose fingers point along `fingers` with the back of the hand facing
    `back` (the bone's Z, the thumb side, is back x fingers)."""
    f, b = Vector(fingers).normalized(), Vector(back).normalized()
    return tuple(f), tuple(b.cross(f).normalized())


def reach(rig):
    """The right hand comes up palm down, then turns its palm to the sleeper and stretches toward his
    face, the long fingers first; it stops a hand short of him."""
    start = lean_end(rig)
    pole = (0.6, -0.3, -1.0)
    u = Vector(TO_VIEWER).normalized()
    up = Vector((0, 0, 1)) - u * u.z
    fingers = (up.normalized() * 0.6 + u * 0.8 + Vector((-0.3, 0, 0))).normalized()   # on toward his eyes, a little inward
    aim_l, thumb_l = _palm((-0.1, 0.9, -0.2), (0, 0, 1))
    aim_o, thumb_o = _palm(fingers, -u)
    lift = _bent(rig, head=(-10, 13, 5), arm_r=_arm("R", (-0.04, 0.20, -0.22), aim=aim_l, thumb=thumb_l, pole=pole),
                 sh_r=(0, 0, 5))
    out = _bent(rig, head=(-12, 10, 4), chest_z=4.0, arm_r=_arm("R", tuple(u * REACH_LEN), aim=aim_o, thumb=thumb_o,
                                                                pole=pole), sh_r=(0, 0, 12))
    return keyed([(0.0, start), (1.0, lift), (3.0, out)])


def add_all(rig):
    make_action(rig, "idle", idle(rig), 6.0, loop=True)
    make_action(rig, "lean_look", lean_look(rig), 3.4)
    make_action(rig, "reach", reach(rig), 3.0)
