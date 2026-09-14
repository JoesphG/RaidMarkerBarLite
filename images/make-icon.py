"""Renders icon.tga and the CurseForge avatar. Needs Pillow.

The skull marker on an iron plate: the one marker every raider knows, and the
only one of the eight that still reads at the 20px the AddOns list uses.
"""

from PIL import Image, ImageDraw, ImageFilter
import math
IRON = (74, 74, 88)

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

class Ctx:
    def __init__(self, N, S=8, pad=0.47):
        self.N, self.S, self.pad = N, S, pad
        self.P = N * S
        self.c = self.P / 2
        self.img = self.canvas()
    def canvas(self):
        return Image.new("RGBA", (self.P, self.P), (0, 0, 0, 0))
    def bg(self, mid, deep, power=0.8):
        d = ImageDraw.Draw(self.img); c, P = self.c, self.P
        for i in range(200, 0, -1):
            t = i / 200; r = P * self.pad * t
            d.ellipse([c - r, c - r, c + r, c + r], fill=lerp(mid, deep, t ** power) + (255,))
    def glow(self, fn, blur, alpha):
        g = self.canvas(); fn(ImageDraw.Draw(g))
        g = g.filter(ImageFilter.GaussianBlur(blur))
        g.putalpha(g.split()[3].point(lambda v: int(v * alpha)))
        self.img.alpha_composite(g)
    def clip(self, img, r=None):
        r = r or self.P * self.pad * 0.955; c, P = self.c, self.P
        m = Image.new("L", (P, P), 0)
        ImageDraw.Draw(m).ellipse([c - r, c - r, c + r, c + r], fill=255)
        img.putalpha(Image.composite(img.split()[3], Image.new("L", (P, P), 0), m))
        return img
    def bezel(self, col=IRON):
        d = ImageDraw.Draw(self.img); c, P, pad = self.c, self.P, self.pad
        d.ellipse([c - P * pad, c - P * pad, c + P * pad, c + P * pad], outline=col + (255,), width=int(P * 0.034))
        r = P * pad * 0.962
        d.ellipse([c - r, c - r, c + r, c + r], outline=lerp(col, (0, 0, 0), 0.55) + (210,), width=int(P * 0.013))
    def out(self):
        return self.img.resize((self.N, self.N), Image.LANCZOS)

def skull(d, cx, cy, r, col, dark):
    # cranium
    d.ellipse([cx - r, cy - r * 1.05, cx + r, cy + r * 0.55], fill=col)
    # jaw
    d.rounded_rectangle([cx - r * 0.62, cy + r * 0.1, cx + r * 0.62, cy + r * 0.95], radius=r * 0.22, fill=col)
    # cheek notches
    d.polygon([(cx - r, cy + r * 0.25), (cx - r * 0.62, cy + r * 0.25), (cx - r * 0.62, cy + r * 0.7)], fill=dark)
    d.polygon([(cx + r, cy + r * 0.25), (cx + r * 0.62, cy + r * 0.25), (cx + r * 0.62, cy + r * 0.7)], fill=dark)
    # eyes
    er = r * 0.3
    for ex in (cx - r * 0.42, cx + r * 0.42):
        d.ellipse([ex - er, cy - r * 0.35 - er * 0.9, ex + er, cy - r * 0.35 + er * 0.9], fill=dark)
    # nose
    d.polygon([(cx, cy + r * 0.05), (cx - r * 0.14, cy + r * 0.35), (cx + r * 0.14, cy + r * 0.35)], fill=dark)
    # teeth lines
    for tx in (-0.3, -0.1, 0.1, 0.3):
        d.rectangle([cx + r * tx - r * 0.025, cy + r * 0.6, cx + r * tx + r * 0.025, cy + r * 0.95], fill=dark)

def skull(d, cx, cy, r, col, dark):
    # cranium
    d.ellipse([cx - r, cy - r * 1.05, cx + r, cy + r * 0.55], fill=col)
    # jaw
    d.rounded_rectangle([cx - r * 0.62, cy + r * 0.1, cx + r * 0.62, cy + r * 0.95], radius=r * 0.22, fill=col)
    # cheek notches
    d.polygon([(cx - r, cy + r * 0.25), (cx - r * 0.62, cy + r * 0.25), (cx - r * 0.62, cy + r * 0.7)], fill=dark)
    d.polygon([(cx + r, cy + r * 0.25), (cx + r * 0.62, cy + r * 0.25), (cx + r * 0.62, cy + r * 0.7)], fill=dark)
    # eyes
    er = r * 0.3
    for ex in (cx - r * 0.42, cx + r * 0.42):
        d.ellipse([ex - er, cy - r * 0.35 - er * 0.9, ex + er, cy - r * 0.35 + er * 0.9], fill=dark)
    # nose
    d.polygon([(cx, cy + r * 0.05), (cx - r * 0.14, cy + r * 0.35), (cx + r * 0.14, cy + r * 0.35)], fill=dark)
    # teeth lines
    for tx in (-0.3, -0.1, 0.1, 0.3):
        d.rectangle([cx + r * tx - r * 0.025, cy + r * 0.6, cx + r * tx + r * 0.025, cy + r * 0.95], fill=dark)

def render(N, S=8):
    x = Ctx(N, S)
    c, P = x.c, x.P
    x.bg((120, 22, 30), (14, 4, 6))
    # plate under the skull
    ph = P * 0.34
    plate = x.canvas(); d = ImageDraw.Draw(plate)
    d.rounded_rectangle([P * 0.05, c - ph / 2 + P * 0.06, P * 0.95, c + ph / 2 + P * 0.06], radius=ph * 0.2, fill=(30, 26, 32, 255))
    d.rounded_rectangle([P * 0.05, c - ph / 2 + P * 0.06, P * 0.95, c - ph / 2 + P * 0.11], radius=ph * 0.15, fill=(90, 84, 96, 255))
    x.img.alpha_composite(x.clip(plate))
    R = P * 0.3
    x.glow(lambda g: skull(g, c, c - P * 0.02, R * 1.05, (255, 240, 240, 255), (255, 240, 240, 255)), P * 0.04, 0.8)
    d = ImageDraw.Draw(x.img)
    skull(d, c, c + P * 0.01, R, (20, 10, 12, 255), (20, 10, 12, 255))  # shadow
    skull(d, c, c - P * 0.02, R, (245, 240, 236, 255), (40, 12, 16, 255))
    x.bezel(); return x.out()


icon = render(128)
icon.save("images/icon-128.png")
icon.save("icon.tga", compression=None)
render(512, S=4).save("images/curseforge-avatar.png")
print("ok")
