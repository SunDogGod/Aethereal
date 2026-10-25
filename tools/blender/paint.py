"""The character's texture: one small atlas (256 px) painted in flat colour blocks with a few
crisp lines (seams, trims, buckles). No noise: it should read clean, like a painted toy.

    atlas = Atlas(256)
    r = atlas.rect("jacket", 96, 64)     # reserve a block; r.uv is what loft() wants
    r.fill(BROWN); r.hline(0.1, DARK)    # paint in the block's own 0..1 coordinates
    atlas.save(path)
Coordinates inside a block: u 0..1 left to right (around the part), v 0..1 bottom to top
(first ring to last ring of the loft), matching the uv the loft was given.
"""
import bpy
import numpy as np


def rgb(hexstr):
    h = hexstr.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


def shade(c, k):
    """Lighter (k > 1) or darker (k < 1) version of a colour."""
    return np.clip(np.asarray(c, dtype=np.float32) * k, 0.0, 1.0)


class Rect:
    def __init__(self, atlas, x, y, w, h):
        self.atlas, self.x, self.y, self.w, self.h = atlas, x, y, w, h
        S = atlas.size
        pad = 0.5 / S  # keep UVs half a texel inside so neighbours don't bleed in
        self.uv = (x / S + pad, 1 - (y + h) / S + pad, (x + w) / S - pad, 1 - y / S - pad)

    def px(self, u, v):
        """Pixel (column, row) for block coordinates u, v."""
        return (self.x + min(self.w - 1, max(0, int(u * self.w))),
                self.y + min(self.h - 1, max(0, int((1 - v) * self.h))))

    def box(self, u0, v0, u1, v1, color):
        x0, y1 = self.px(u0, v0)
        x1, y0 = self.px(u1, v1)
        self.atlas.img[min(y0, y1):max(y0, y1) + 1, min(x0, x1):max(x0, x1) + 1] = color

    def fill(self, color):
        self.atlas.img[self.y:self.y + self.h, self.x:self.x + self.w] = color

    def vgrad(self, bottom, top):
        """A gentle bottom-to-top shade (used sparingly: form, not texture)."""
        for row in range(self.h):
            t = 1 - row / max(1, self.h - 1)
            self.atlas.img[self.y + row, self.x:self.x + self.w] = np.asarray(bottom) * (1 - t) + np.asarray(top) * t

    def hline(self, v, color, px=1):
        _, row = self.px(0, v)
        self.atlas.img[row:row + px, self.x:self.x + self.w] = color

    def vline(self, u, color, px=1, v0=0.0, v1=1.0):
        col, r1 = self.px(u, v0)
        _, r0 = self.px(u, v1)
        self.atlas.img[r0:r1 + 1, col:col + px] = color

    def seam(self, u, dark, light, v0=0.0, v1=1.0):
        """A stitched seam: a dark line with a light lip beside it."""
        self.vline(u, dark, 1, v0, v1)
        col, _ = self.px(u, v0)
        if col + 1 < self.x + self.w:
            c, r1 = self.px(u, v0)
            _, r0 = self.px(u, v1)
            self.atlas.img[r0:r1 + 1, c + 1:c + 2] = light

    def dot(self, u, v, color, size=1):
        c, r = self.px(u, v)
        self.atlas.img[r:r + size, c:c + size] = color


class Atlas:
    def __init__(self, size=256, background="#808080"):
        self.size = size
        self.img = np.zeros((size, size, 3), dtype=np.float32)
        self.img[:] = rgb(background)
        self._shelf_x, self._shelf_y, self._shelf_h = 0, 0, 0
        self.rects = {}

    def rect(self, name, w, h, pad=2):
        """Reserves a w x h block (shelf packing, left to right, top to bottom)."""
        if self._shelf_x + w + pad > self.size:
            self._shelf_x, self._shelf_y = 0, self._shelf_y + self._shelf_h
            self._shelf_h = 0
        if self._shelf_y + h + pad > self.size:
            raise ValueError("atlas full at %s" % name)
        r = Rect(self, self._shelf_x + pad // 2, self._shelf_y + pad // 2, w, h)
        self._shelf_x += w + pad
        self._shelf_h = max(self._shelf_h, h + pad)
        self.rects[name] = r
        return r

    def bleed(self):
        """Copies each block's edge pixels one texel outward so mipmaps don't pick up the gaps."""
        for r in self.rects.values():
            y0, y1, x0, x1 = r.y, r.y + r.h, r.x, r.x + r.w
            if y0 > 0:
                self.img[y0 - 1, x0:x1] = self.img[y0, x0:x1]
            if y1 < self.size:
                self.img[y1, x0:x1] = self.img[y1 - 1, x0:x1]
            if x0 > 0:
                self.img[max(0, y0 - 1):y1 + 1, x0 - 1] = self.img[max(0, y0 - 1):y1 + 1, x0]
            if x1 < self.size:
                self.img[max(0, y0 - 1):y1 + 1, x1] = self.img[max(0, y0 - 1):y1 + 1, x1 - 1]

    def save(self, path, name="atlas"):
        self.bleed()
        rgba = np.ones((self.size, self.size, 4), dtype=np.float32)
        rgba[:, :, :3] = self.img
        rgba = rgba[::-1]  # Blender stores the bottom row first
        img = bpy.data.images.get(name) or bpy.data.images.new(name, self.size, self.size)
        img.pixels.foreach_set(rgba.ravel())
        img.filepath_raw = path
        img.file_format = 'PNG'
        img.save()
        return img


def material(name, image):
    """A Blender material showing the atlas (for previews and so the glTF material has a name)."""
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True  # always on (and deprecated) in newer Blender
    except Exception:
        pass
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = 'Closest'
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat
