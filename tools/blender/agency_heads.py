"""The Agency's heads. The rank and file wear the black helmet with its glowing visor slit
(helmet()); the officers, the captain and the lieutenant, go bare-headed (officer_head()): a face
(face.py), short hair (a close shell, slicked back or cropped), ears, and an eyepiece over the left
eye. The eyepiece's lens is the officer's "Visor": guard.gd needs a mesh called Visor on the Head
bone, glowing in GuardData.visor_color to show where he looks and flaring before a blow.
"""
import math
from mathutils import Vector
import base_body as bb
import body
import face
import face_paint
import mesh
import agency_parts as ap
from agency_parts import C
from paint import rgb, shade

# Hair styles for officer_head: lift = how far the hair stands off the skin at the sides / on top,
# comb = "back" (slicked back, strands combed from the brow to the nape) or "crop" (short strokes).
SLICKED = dict(side=0.0045, top=0.0085, comb="back")
CROPPED = dict(side=0.0035, top=0.0060, comb="crop")


def helmet(ch, P, R, scale):
    """The agent's helmet (on the Head bone: no face), crest and side discs, and the visor slit."""
    J = ch.J
    body.neck(P, J, R["neck"], r=0.052)
    head = body.Head(J, rows=ap.HELM, brow=0.0, scale=scale)
    head.build(P, R["helm"], segs=20)
    ap.crest(P, head, R["crest"])
    bb.mirrored(P, lambda: ap.disc(P, head, R["disc"]))
    ap.paint_helm(R, head)
    R["disc"].fill(C["plate"])
    R["disc"].box(0.3, 0.3, 0.7, 0.7, C["plate_hi"])
    ap.visor(ch, head, R["visor"])
    return head


def officer_head(ch, P, look, style, hairline):
    """A bare head: face, ears, short hair, the eyepiece (its lens the Visor). Reserves its own
    blocks in the atlas (use a 512 px one: the face block is big). Returns the Head."""
    A, J = ch.atlas, ch.J
    r_neck = A.rect("officer_neck", 16, 12)
    body.neck(P, J, r_neck, r=0.050)
    r_neck.fill(look["skin"])
    head = face.Head(J, look)
    head.build(P, A.rect("officer_head", *face.HEAD_RECT))
    face.ears(P, head, A.rect("ear", 16, 16), look, look["skin"], shade(look["skin"], 0.8))
    face_paint.paint(head, look, hairline)
    v_of = shell(P, head, A.rect("hair_cap", 64, 32), hairline, style)
    paint_shell(A.rects["hair_cap"], v_of, hairline, look["hair"], style)
    eyepiece(ch, head, look, A.rect("visor", 16, 8), A.rect("eyepiece", 16, 8))
    return head


def receding(base, depth=0.012, at=36.0):
    """A hairline (theta -> height) with the temples worn back (an M at the brow), from `base`."""
    def line(theta):
        a = abs(((theta - 90.0) + 180.0) % 360.0 - 180.0)
        return base(theta) + depth * math.exp(-((a - at) / 13.0) ** 2)
    return line


def _lift(style, theta, z):
    top = min(1.0, max(0.0, (z - 0.15) / 0.05))
    return style["side"] + (style["top"] - style["side"]) * top


def shell(P, head, rect, hairline, style, cols=28):
    """The short hair: rows from just under the skin at the hairline up to the crown, standing off
    the skull by the style's lift. v in the texture is height (for the paint)."""
    fr = [0.0, 0.0, 0.18, 0.38, 0.58, 0.76, 0.9]
    z_top = head.rows[-1][0]
    z_lo = min(hairline(th) for th in range(0, 360, 10))
    pole_c = head.ring(len(head.rows) - 1)["c"] + Vector((0, 0, (0.004 + style["top"]) * head.s))

    def v_of(z):
        return (z - z_lo) / (z_top + 0.01 - z_lo)
    grid, vs = [], []
    for i, f in enumerate(fr):
        row, vrow = [], []
        for j in range(cols):
            th = -90.0 + 360.0 * j / cols
            z0 = hairline(th)
            z = z0 + (z_top - z0) * f
            row.append(P.vert(head.surface(th, z, -0.002 if i == 0 else _lift(style, th, z)), {"Head": 1.0}))
            vrow.append(v_of(z))
        grid.append(row)
        vs.append(vrow)
    pole = P.vert(pole_c, {"Head": 1.0})
    u0, v0, u1, v1 = rect.uv

    def uv(j, v):
        return (u0 + (u1 - u0) * j / cols, v0 + (v1 - v0) * min(1.0, max(0.0, v)))
    for i in range(len(fr) - 1):
        for j in range(cols):
            k = (j + 1) % cols
            P.face((grid[i][j], grid[i][k], grid[i + 1][k], grid[i + 1][j]),
                   [uv(j, vs[i][j]), uv(j + 1, vs[i][k]), uv(j + 1, vs[i + 1][k]), uv(j, vs[i + 1][j])])
    for j in range(cols):
        k = (j + 1) % cols
        P.face((grid[-1][j], grid[-1][k], pole), [uv(j, vs[-1][j]), uv(j + 1, vs[-1][k]), uv(j + 0.5, 1.0)])
    return v_of


def paint_shell(rect, v_of, hairline, hair, style):
    """Slicked back: comb lines running from the brow over the top and back along the sides, a
    sheen on top. Cropped: fine short strokes, lighter on top."""
    img = rect.atlas.img
    for col in range(rect.w):
        u = (col + 0.5) / rect.w
        th = -90.0 + 360.0 * u
        sn, cs = abs(math.sin(math.radians(th))), abs(math.cos(math.radians(th)))
        for row in range(rect.h):
            v = 1 - (row + 0.5) / rect.h
            c = hair
            if style["comb"] == "back":
                if sn > 0.6 and col % 4 == 0 and v > 0.2:
                    c = shade(hair, 0.87)                      # combed straight back over the top
                elif cs > 0.75 and row % 5 == 0:
                    c = shade(hair, 0.87)                      # and back along the sides
                elif 0.6 < v < 0.8 and sn > 0.5:
                    c = shade(hair, 1.12)                      # the sheen of the oil
            else:
                if (col * 3 + row) % 7 == 0:
                    c = shade(hair, 0.92)                      # short strokes
                if v > 0.6:
                    c = shade(c, 1.12)                         # lighter on top, where the light falls
            img[rect.y + row, rect.x + col] = c


def eyepiece(ch, head, look, r_lens, r_frame):
    """A round lens before his left eye in a dark rim, a thin arm back to the ear. The lens is the
    prop Visor (node HeadGear, Head bone); the rim and arm are skinned to the head."""
    P = ch.part("Body")
    hs = head.s * head.k
    th = 90.0 + look["eye_a"]
    n = Vector((math.cos(math.radians(th)), math.sin(math.radians(th)), 0.0))
    c = head.surface(th, look["eye_z"], 0.0) + n * 0.0075 * hs
    x = Vector((0, 0, 1)).cross(n).normalized()
    y = n.cross(x).normalized()

    def disc(part, d0, d1, r, w, uv):
        rings = [{"c": c + n * d * hs, "x": x, "y": y, "rx": r * hs, "ry": r * hs, "n": 2.0, "w": w,
                  "cap_len": 0.0} for d in (d0, d1)]
        rings[-1]["cap_len"] = 0.0012 * hs
        mesh.loft(part, rings, 10, uv, cap0="pole", cap1="pole")
    disc(P, -0.004, 0.0015, 0.0128, {"Head": 1.0}, r_frame.uv)
    lens = ch.prop("Visor", "Head", "HeadGear")
    disc(lens, 0.0012, 0.0026, 0.0104, {}, r_lens.uv)
    mesh.transform_part(lens, ch.arm.data.bones["Head"].matrix_local.inverted())
    ear = head.surface(180.0 - look["ear_a"], look["ear_z"] + 0.022, 0.004)
    side = c + x * 0.0115 * hs
    pts = [side, side.lerp(ear, 0.5) + n * 0.002 * hs, ear]
    body.strand(P, pts, [0.0022 * hs, 0.002 * hs, 0.0015 * hs], 0.8, r_frame.uv, {"Head": 1.0},
                up=Vector((0, 0, 1)), sides=4)
    r_lens.fill(rgb("#ffffff"))   # white: guard_look.gd tints it with GuardData.visor_color
    r_frame.fill(C["plate"])
    r_frame.hline(0.5, C["plate_hi"])
