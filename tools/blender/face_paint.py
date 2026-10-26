"""Paints a face.Head's texture block from its look (face.py): skin with soft painted shading from
the features (darker in the eye sockets and under the nose, lips and chin), the scalp's hair
colour above the hairline, then the eyes (whites, iris with pupil and glint, lash line, lid
crease), the brows, the lips and nostrils, and per character a blush, age lines or stubble.

Painted three times finer than the block and averaged down, so edges are soft, not jagged.
Colours in the look: skin, hair, brow, lash, iris, pupil, sclera, lip (rgb arrays, paint.rgb).
"""
import numpy as np
import face
from paint import rgb

SS = 3   # samples per texel each way


def _mix(img, mask, color, amount=1.0):
    k = np.clip(mask * amount, 0.0, 1.0)[..., None]
    img *= (1.0 - k)
    img += k * np.asarray(color, dtype=np.float32)


def _band(x, half, soft):
    """1 inside |x| < half, fading to 0 over `soft` (all in metres)."""
    return np.clip((half + soft - np.abs(x)) / max(soft, 1e-6), 0.0, 1.0)


def _inv(pts, values):
    xs, ys = zip(*pts)
    return np.interp(values, ys, xs)


def paint(head, L, hairline):
    r = head.rect
    W, H = r.w * SS, r.h * SS
    u = (np.arange(W) + 0.5) / W
    v = 1.0 - (np.arange(H) + 0.5) / H
    lo, hi = 0.5 - face.FACE_U / 360.0, 0.5 + face.FACE_U / 360.0
    f = np.interp(u, [0.0, (1 - face.U_FACE) / 2, (1 + face.U_FACE) / 2, 1.0], [0.0, lo, hi, 1.0])
    theta = f * 360.0 - 90.0
    a1 = ((theta - 90.0 + 180.0) % 360.0) - 180.0           # + = toward his left
    z1 = _inv(face.V_PTS, v)
    A, Z = np.meshgrid(a1, z1)
    img = np.empty((H, W, 3), dtype=np.float32)
    img[:] = L["skin"]
    _skin_shading(img, L, A, Z)
    hl = np.array([hairline(t) for t in theta])[None, :]
    _mix(img, np.clip((Z - hl + 0.004) / 0.004, 0.0, 1.0), L["hair"], 1.0)
    for sd in (1.0, -1.0):
        _eye(img, L, (A * sd - L["eye_a"]) * face.MDEG, Z - L["eye_z"], sd)
        _brow(img, L, A * sd, Z)
    _mouth(img, L, A * face.MDEG, Z - L["mouth_z"])
    for sd in (1.0, -1.0):                                       # nostrils
        x = (A * sd - L["nose_w"] * 1.05) * face.MDEG
        y = Z - (L["nose_tip_z"] - 0.0068)
        _mix(img, ((x / 0.0019) ** 2 + (y / 0.0009) ** 2 < 1.0).astype(np.float32), L["skin"] * 0.42, 0.85)
    if L["age"] > 0:
        _age(img, L, A, Z)
    out = img.reshape(r.h, SS, r.w, SS, 3).mean(axis=(1, 3))
    r.atlas.img[r.y:r.y + r.h, r.x:r.x + r.w] = out


def _skin_shading(img, L, A, Z):
    """Form painted in, from the relief: dents darker, ridges a touch lighter, surfaces that face
    down (under the nose, lip and chin, the jaw) in shade."""
    d = face.relief(L, A, Z)
    slope = (face.relief(L, A, Z + 0.0015) - face.relief(L, A, Z - 0.0015)) / 0.003
    k = 1.0 + np.clip(d, -0.008, 0.0) * 14.0 + np.clip(d, 0.0, 0.01) * 3.0
    k -= 0.10 * np.clip(slope, 0.0, 1.6)
    k += 0.035 * np.clip(-slope, 0.0, 1.2)
    k -= 0.10 * np.clip((0.02 - Z) / 0.02, 0.0, 1.0)              # under the jaw
    k -= 0.05 * np.clip((np.abs(A) - 60.0) / 40.0, 0.0, 1.0)      # round the sides
    k = 1.0 + (k - 1.0) * L["shade"]
    img *= k[..., None]
    if L["blush"] > 0:
        _mix(img, face._g(np.abs(A), Z, 35.0, 0.080, 11.0, 0.013), rgb("#d9707a"), 0.22 * L["blush"])
    if L["stubble"] > 0:
        jaw = np.clip((0.072 - Z) / 0.012, 0.0, 1.0) * np.clip((88.0 - np.abs(A)) / 10.0, 0.0, 1.0)
        lips = face._g(A, Z, 0.0, L["mouth_z"], L["mouth_w"] * 1.1, 0.006)
        _mix(img, jaw * (1.0 - lips), L["hair"] * 0.5 + L["skin"] * 0.5, 0.35 * L["stubble"])


def _eye(img, L, x, y, sd):
    """One eye: x outward from its centre, y up, in metres. Almond shaped, the upper lid fuller
    toward the nose, the outer corner lifted by eye_tilt."""
    ew = L["eye_w"] * face.MDEG
    t = x / ew
    inside_t = np.clip(1.0 - t * t, 0.0, 1.0)
    yc = L["eye_tilt"] * t
    up = yc + L["eye_h"] * inside_t ** 0.62 * (1.0 - 0.16 * t)
    low = yc - L["eye_lo"] * inside_t ** 0.85 * (1.0 + 0.12 * t)
    open_ = ((np.abs(t) < 1.0) & (y < up) & (y > low)).astype(np.float32)
    sclera = np.ones_like(img) * L["sclera"]
    shadow = np.clip(1.0 - (up - y) / 0.0018, 0.0, 1.0)            # the lid's shadow on the white
    sclera *= (1.0 - 0.35 * shadow)[..., None]
    xi, yi = L["iris_look"] * ew, yc + 0.0004
    dist = np.sqrt((x - xi) ** 2 + (y - yi) ** 2)
    rr = L["iris_r"]
    iris = np.ones_like(img) * L["iris"]
    iris *= (1.0 + 0.30 * np.clip((yi - y) / rr, 0.0, 1.0) - 0.30 * np.clip((y - yi) / rr, 0.0, 1.0))[..., None]
    iris *= (1.0 - 0.45 * np.clip((dist / rr - 0.78) / 0.22, 0.0, 1.0))[..., None]       # the dark rim
    iris[dist < rr * 0.42] = L["pupil"]
    glint = np.sqrt((x - (xi + 0.30 * rr)) ** 2 + (y - (yi + 0.38 * rr)) ** 2) < rr * 0.24
    iris[glint] = rgb("#fbfaf6")
    iris *= (1.0 - 0.3 * shadow)[..., None]
    eye = np.where((dist < rr)[..., None], iris, sclera)
    m = open_[..., None]
    img *= 1.0 - m
    img += m * eye
    # the lash line along the upper lid, heavier toward the outer corner, and its wing
    th = L["lash"] * (0.65 + 0.55 * np.clip(t, 0.0, 1.0))
    lash = ((y >= up - 0.0002) & (y < up + th) & (np.abs(t) < 1.04)).astype(np.float32)
    if L["wing"] > 0:
        wx = (x - ew) / (ew * L["wing"])
        wy = yc + L["eye_tilt"] + 0.0006 + (x - ew) * 0.45
        lash = np.maximum(lash, ((wx >= 0) & (wx < 1) & (np.abs(y - wy) < L["lash"] * 0.6 * (1 - wx))).astype(np.float32))
    _mix(img, lash, L["lash_col"], 1.0)
    lower = ((y <= low + 0.0001) & (y > low - 0.0006) & (np.abs(t) < 0.92)).astype(np.float32)
    _mix(img, lower, L["lash_col"], L["lower_lash"])
    crease = ((y - up > 0.0026) & (y - up < 0.0034) & (np.abs(t) < 0.85)).astype(np.float32)
    _mix(img, crease, L["skin"] * 0.72, 0.5 * L["crease"])
    _mix(img, ((np.abs(t + 1.0) < 0.07) & (np.abs(y - yc) < 0.0012)).astype(np.float32), rgb("#c98a86"), 0.6)


def _brow(img, L, a, Z):
    """One brow, from brow_in to brow_out degrees: thick toward the nose, arched, thin at the end."""
    t = (a - L["brow_in"]) / (L["brow_out"] - L["brow_in"])
    yb = L["brow_z0"] + (L["brow_z1"] - L["brow_z0"]) * t + L["brow_arch"] * np.sin(np.pi * np.clip(t, 0, 1) ** 0.8)
    half = 0.5 * L["brow_thick"] * (1.0 - 0.62 * np.clip(t, 0.0, 1.0))
    along = np.clip(np.minimum(t / 0.06, (1.0 - t) / 0.08), 0.0, 1.0)
    _mix(img, _band(Z - yb, half, 0.0006) * along, L["brow"], 1.0)


def _mouth(img, L, x, y):
    """Lips: the line where they meet (corners up with smile, one side with smirk), a darker upper
    lip with a cupid's bow, a fuller, lighter lower lip with a highlight."""
    mw = L["mouth_w"] * face.MDEG
    t = x / mw
    inside = np.clip(1.0 - t * t, 0.0, 1.0)
    ym = L["smile"] * t * t + L["smirk"] * t
    hu = L["lip_h_up"] * inside ** 0.6 * (1.0 - 0.2 * np.exp(-(t / 0.12) ** 2))
    hl = L["lip_h_lo"] * inside ** 0.8
    lip = L["lip"]
    upper = ((y > ym) & (y < ym + hu)).astype(np.float32)
    lower = ((y < ym) & (y > ym - hl)).astype(np.float32)
    _mix(img, upper, lip * 0.86, L["lip_sat"])
    _mix(img, lower, lip, L["lip_sat"] * 0.9)
    _mix(img, lower * face._g(x / mw, y, 0.0, ym - hl * 0.45, 0.35, 0.0008), lip * 1.25, 0.35 * L["lip_sat"])
    line = _band(y - ym, 0.00035, 0.0003) * np.clip((1.06 - np.abs(t)) / 0.2, 0.0, 1.0)
    _mix(img, line, lip * 0.42, 0.95)


def _age(img, L, A, Z):
    """Lines that come with years: from the nostril wings to past the mouth corners, crow's feet,
    under the eyes, two across the forehead."""
    k = L["age"]
    dark = L["skin"] * 0.66
    for sd in (1.0, -1.0):
        a = A * sd
        t = np.clip((L["nose_tip_z"] - 0.002 - Z) / (L["nose_tip_z"] - L["mouth_z"] + 0.006), 0.0, 1.0)
        a_line = L["nose_w"] * 1.9 + t * (L["mouth_w"] + 2.5 - L["nose_w"] * 1.9) + 2.5 * np.sin(np.pi * t)
        seg = ((Z < L["nose_tip_z"] - 0.002) & (Z > L["mouth_z"] - 0.006)).astype(np.float32)
        _mix(img, _band((a - a_line) * face.MDEG, 0.0004, 0.0004) * seg, dark, 0.55 * k)
        for dz in (-0.002, 0.0015):
            x0 = L["eye_a"] + L["eye_w"] + 1.5
            seg = ((a > x0) & (a < x0 + 4.0)).astype(np.float32)
            _mix(img, _band(Z - (L["eye_z"] + dz + (a - x0) * 0.0006 * np.sign(dz)), 0.0003, 0.0003) * seg, dark, 0.45 * k)
        bag = _band(Z - (L["eye_z"] - L["eye_lo"] - 0.0028 + 0.0004 * ((a - L["eye_a"]) / L["eye_w"]) ** 2), 0.0003, 0.0004)
        _mix(img, bag * (np.abs(a - L["eye_a"]) < L["eye_w"] * 0.8), dark, 0.4 * k)
    for zf in (0.137, 0.146):
        _mix(img, _band(Z - zf - 0.001 * np.cos(np.radians(A) * 4), 0.0003, 0.0004) * (np.abs(A) < 26), dark, 0.35 * k)
