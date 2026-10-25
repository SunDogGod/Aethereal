"""Props held or carried: swords, knives, a rifle. Each is built in its own frame: the grip at
the origin, the length along +Y, the cutting edge along +Z (rig.py's attach bones use the same
frame, so the prop lands in the hand). Painted into a block of the character's atlas.
"""
from mathutils import Vector
from mesh import loft
from paint import rgb, shade

Y_RING = {"x": Vector((0, 0, 1)), "y": Vector((1, 0, 0))}   # rings for a loft along +Y
Z_RING = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0))}   # rings for a loft along +Z
X_RING = {"x": Vector((0, 1, 0)), "y": Vector((0, 0, 1))}   # rings for a loft along +X


def rod(part, rows, uv, sides=6, start=-90.0, caps=(None, None), smooth=True, along="y"):
    """rows: (position along the axis, radius toward +Z / +X, radius toward +X / +Y[, offset Vector]).
    A first or last row with radius 0 is a point: that end closes to it."""
    rows = list(rows)
    caps = list(caps)
    tips = [0.0, 0.0]
    if rows[0][1] == 0.0:
        tips[0] = abs(rows[1][0] - rows.pop(0)[0])
        caps[0] = "pole"
    if rows[-1][1] == 0.0:
        tips[1] = abs(rows.pop()[0] - rows[-1][0])
        caps[1] = "pole"
    rings = []
    for row in rows:
        p, rx, ry = row[:3]
        off = Vector(row[3]) if len(row) > 3 else Vector()
        c = {"y": Vector((0, p, 0)), "z": Vector((0, 0, p)), "x": Vector((p, 0, 0))}[along] + off
        axes = {"y": Y_RING, "z": Z_RING, "x": X_RING}[along]
        rings.append({"c": c, "x": axes["x"], "y": axes["y"], "rx": rx, "ry": ry, "n": 2.0, "w": {}})
    rings[0]["cap_len"], rings[-1]["cap_len"] = tips
    return loft(part, rings, sides, uv, start=start, cap0=caps[0], cap1=caps[1], smooth=smooth)


def sword(part, atlas, length=0.86, width=0.024, steel="#c4cad3", guard="#b08a3e", grip="#3b2618", name="sword"):
    """A straight one-handed sword with curved quillons, a wrapped grip and a round pommel."""
    r_blade = atlas.rect(name + "_blade", 48, 12)
    r_hilt = atlas.rect(name + "_hilt", 24, 12)
    r_guard = atlas.rect(name + "_guard", 16, 8)
    st, gd, gp = rgb(steel), rgb(guard), rgb(grip)
    L = length
    rod(part, [(0.09, width * 0.92, 0.006), (0.15, width, 0.0062), (0.09 + L * 0.55, width * 0.92, 0.0056),
               (0.09 + L * 0.85, width * 0.72, 0.005), (0.09 + L * 0.96, width * 0.36, 0.004),
               (0.09 + L, 0.0, 0.0)], r_blade.uv, sides=4, start=0.0, smooth=False)
    r_blade.fill(st)
    for u in (0.0, 0.5, 1.0):
        r_blade.vline(min(u, 0.99), shade(st, 1.2), 2)       # bright edges
    for u in (0.25, 0.75):
        r_blade.vline(u, shade(st, 0.72), 1, 0.0, 0.7)      # the fuller
    r_blade.box(0, 0, 1, 0.05, shade(st, 0.8))
    rod(part, [(-0.085, 0.0155, 0.0155), (0.0, 0.0168, 0.0168), (0.075, 0.015, 0.015)], r_hilt.uv, sides=6)
    rod(part, [(-0.118, 0.0, 0.0), (-0.112, 0.014, 0.014), (-0.10, 0.024, 0.024), (-0.088, 0.017, 0.017),
               (-0.082, 0.0, 0.0)], r_guard.uv, sides=6, caps=(None, None))
    r_hilt.fill(gp)
    for k in range(6):
        r_hilt.hline(0.1 + k * 0.16, shade(gp, 0.6))           # leather wrap
    rod(part, [(-0.105, 0.0, 0.0, (0, 0.10, 0)), (-0.098, 0.011, 0.012, (0, 0.096, 0)),
               (-0.06, 0.012, 0.016, (0, 0.088, 0)), (0.0, 0.013, 0.018, (0, 0.085, 0)),
               (0.06, 0.012, 0.016, (0, 0.088, 0)), (0.098, 0.011, 0.012, (0, 0.096, 0)),
               (0.105, 0.0, 0.0, (0, 0.10, 0))], r_guard.uv, sides=6, along="z")
    r_guard.fill(gd)
    r_guard.hline(0.5, shade(gd, 1.3))


def scabbard(part, atlas, length=0.86, width=0.024, leather="#3a2416", metal="#a8873e", name="scabbard"):
    """The scabbard for sword(): built in the sword's own frame, so with the sword's grip at the
    origin the blade sits inside it. A brass locket at the mouth (just past the guard), a belt
    loop below it, a worn leather body and a brass chape at the tip."""
    r_body = atlas.rect(name + "_body", 48, 12)
    r_metal = atlas.rect(name + "_metal", 16, 8)
    lt, mt = rgb(leather), rgb(metal)
    w, t = width + 0.009, 0.0125   # half width (along the edge, +Z) and half thickness
    L0, L1 = 0.104, 0.104 + length + 0.02
    rod(part, [(L0, w * 1.12, t * 1.25), (L0 + 0.045, w * 1.12, t * 1.25)], r_metal.uv, sides=6)
    rod(part, [(L0 + 0.04, w, t), (L0 + 0.35, w * 0.97, t * 0.96), (L1 - 0.09, w * 0.80, t * 0.86),
               (L1 - 0.02, w * 0.62, t * 0.8)], r_body.uv, sides=6)
    rod(part, [(L1 - 0.075, w * 0.86, t * 1.05), (L1 - 0.01, w * 0.66, t * 0.95), (L1 + 0.012, 0.0, 0.0)],
        r_metal.uv, sides=6)
    rod(part, [(L0 + 0.10, w * 1.18, t * 1.6), (L0 + 0.13, w * 1.18, t * 1.6)], r_metal.uv, sides=6)  # loop
    r_body.fill(lt)
    r_body.vgrad(shade(lt, 1.1), shade(lt, 0.8))         # v runs mouth to tip: darker toward the tip
    for u in (0.25, 0.75):
        r_body.vline(u, shade(lt, 1.35), 1, 0.05, 0.98)  # the edges catch the light
    r_body.hline(0.55, shade(lt, 0.7))                    # a scuffed seam
    r_metal.fill(mt)
    r_metal.hline(0.5, shade(mt, 0.7))


def knife(part, atlas, name="knife"):
    r_blade = atlas.rect(name + "_blade", 24, 8)
    r_hilt = atlas.rect(name + "_hilt", 16, 8)
    st, gp = rgb("#b9bfc8"), rgb("#2c2119")
    rod(part, [(0.055, 0.014, 0.004), (0.10, 0.015, 0.0038), (0.17, 0.011, 0.003), (0.205, 0.0, 0.0)],
        r_blade.uv, sides=4, start=0.0, smooth=False)
    r_blade.fill(st)
    r_blade.vline(0.0, shade(st, 1.25), 2)
    r_blade.vline(0.5, shade(st, 1.25), 1)
    rod(part, [(-0.06, 0.0, 0.0), (-0.055, 0.012, 0.012), (0.0, 0.013, 0.013), (0.045, 0.012, 0.012),
               (0.055, 0.02, 0.008), (0.062, 0.0, 0.0)], r_hilt.uv, sides=6)
    r_hilt.fill(gp)
    r_hilt.hline(0.2, shade(gp, 1.6))
    r_hilt.hline(0.9, rgb("#8d7a52"))


def rifle(part, atlas, name="rifle"):
    """A plain bolt-action rifle, about a metre long, its middle at the origin, muzzle at +Y."""
    r_wood = atlas.rect(name + "_wood", 40, 12)
    r_metal = atlas.rect(name + "_metal", 24, 8)
    wood, metal = rgb("#6b4426"), rgb("#3a3d44")
    # Stock (butt to wrist), rings: height toward +Z (the sights side), width toward +X.
    rod(part, [(-0.50, 0.0, 0.0, (0, 0, -0.01)), (-0.495, 0.060, 0.021, (0, 0, -0.012)),
               (-0.40, 0.055, 0.022, (0, 0, -0.012)), (-0.24, 0.032, 0.019, (0, 0, -0.004)),
               (-0.16, 0.024, 0.018), (-0.12, 0.024, 0.018)], r_wood.uv, sides=6, start=0.0)
    rod(part, [(0.04, 0.022, 0.017, (0, 0, -0.008)), (0.30, 0.020, 0.016, (0, 0, -0.008)),
               (0.31, 0.0, 0.0, (0, 0, -0.008))], r_wood.uv, sides=6, start=0.0)
    r_wood.fill(wood)
    r_wood.hline(0.3, shade(wood, 0.8))
    r_wood.box(0, 0.0, 1, 0.08, shade(wood, 0.55))   # butt plate
    # Receiver and barrel.
    rod(part, [(-0.13, 0.0, 0.0, (0, 0, 0.006)), (-0.125, 0.020, 0.016, (0, 0, 0.006)),
               (0.06, 0.020, 0.016, (0, 0, 0.006)), (0.065, 0.0, 0.0, (0, 0, 0.006))],
        r_metal.uv, sides=4, start=45.0, smooth=False)
    rod(part, [(0.06, 0.0105, 0.0105, (0, 0, 0.012)), (0.52, 0.0095, 0.0095, (0, 0, 0.012)),
               (0.525, 0.0, 0.0, (0, 0, 0.012))], r_metal.uv, sides=6)
    rod(part, [(-0.05, 0.0, 0.0, (0.02, 0, 0.022)), (-0.045, 0.006, 0.006, (0.02, 0, 0.022)),
               (-0.03, 0.006, 0.006, (0.03, 0, 0.022)), (-0.025, 0.0, 0.0, (0.03, 0, 0.022))],
        r_metal.uv, sides=4)   # bolt handle
    r_metal.fill(metal)
    r_metal.hline(0.75, shade(metal, 1.5))
