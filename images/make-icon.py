"""Renders icon.tga and the CurseForge avatar. Needs Pillow.

Three markers on an iron plate: star, circle, diamond. Picked to hold three
distinct colour blobs at the 20-24px the AddOns list renders at.
"""

from PIL import Image, ImageDraw, ImageFilter
import math

BG_MID = (38, 42, 60)
BG_DEEP = (8, 9, 14)
IRON = (74, 74, 88)
PLATE = (46, 48, 60)
PLATE_HI = (92, 96, 116)
PLATE_LO = (22, 23, 30)
STAR = (255, 222, 48)
CIRCLE = (255, 128, 32)
DIAMOND = (176, 72, 232)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def render(N, S=8, pad=0.47):
    P = N * S
    c = P / 2

    def canvas():
        return Image.new("RGBA", (P, P), (0, 0, 0, 0))

    def glow(fn, blur, alpha):
        g = canvas()
        fn(ImageDraw.Draw(g))
        g = g.filter(ImageFilter.GaussianBlur(blur))
        g.putalpha(g.split()[3].point(lambda v: int(v * alpha)))
        return g

    def clip_circle(img, r):
        m = Image.new("L", (P, P), 0)
        ImageDraw.Draw(m).ellipse([c - r, c - r, c + r, c + r], fill=255)
        img.putalpha(Image.composite(img.split()[3], Image.new("L", (P, P), 0), m))
        return img

    img = canvas()
    d = ImageDraw.Draw(img)
    for i in range(200, 0, -1):
        t = i / 200
        r = P * pad * t
        d.ellipse([c - r, c - r, c + r, c + r], fill=lerp(BG_MID, BG_DEEP, t**0.8) + (255,))

    # plate
    ph = P * 0.40
    x0, x1 = P * 0.06, P * 0.94
    y0, y1 = c - ph / 2, c + ph / 2
    sh = canvas()
    ImageDraw.Draw(sh).rounded_rectangle([x0, y0 + P * 0.03, x1, y1 + P * 0.03], radius=ph * 0.22, fill=(0, 0, 0, 200))
    img.alpha_composite(clip_circle(sh.filter(ImageFilter.GaussianBlur(P * 0.02)), P * pad * 0.955))
    plate = canvas()
    d = ImageDraw.Draw(plate)
    d.rounded_rectangle([x0, y0, x1, y1], radius=ph * 0.22, fill=PLATE + (255,))
    d.rounded_rectangle([x0, y0, x1, y0 + ph * 0.16], radius=ph * 0.18, fill=PLATE_HI + (255,))
    d.rounded_rectangle([x0, y1 - ph * 0.14, x1, y1], radius=ph * 0.18, fill=PLATE_LO + (255,))
    img.alpha_composite(clip_circle(plate, P * pad * 0.955))

    # markers
    R = P * 0.125
    xs = [c - P * 0.29, c, c + P * 0.29]

    def star(d, cx, cy, r, fill):
        pts = []
        for i in range(10):
            a = -math.pi / 2 + i * math.pi / 5
            rr = r if i % 2 == 0 else r * 0.46
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
        d.polygon(pts, fill=fill)

    def circle(d, cx, cy, r, fill):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)

    def diamond(d, cx, cy, r, fill):
        d.polygon([(cx, cy - r * 1.1), (cx + r * 0.8, cy), (cx, cy + r * 1.1), (cx - r * 0.8, cy)], fill=fill)

    shapes = [(star, STAR, R * 1.15), (circle, CIRCLE, R * 0.95), (diamond, DIAMOND, R * 1.05)]
    for (fn, col, r), x in zip(shapes, xs):
        img.alpha_composite(glow(lambda g, fn=fn, x=x, r=r, col=col: fn(g, x, c, r * 1.15, col + (255,)), P * 0.03, 0.85))
    d = ImageDraw.Draw(img)
    for (fn, col, r), x in zip(shapes, xs):
        fn(d, x, c + P * 0.012, r, lerp(col, (0, 0, 0), 0.55) + (255,))
        fn(d, x, c, r, col + (255,))
        fn(d, x, c - r * 0.10, r * 0.62, lerp(col, (255, 255, 255), 0.35) + (255,))

    # bezel
    d.ellipse([c - P * pad, c - P * pad, c + P * pad, c + P * pad], outline=IRON + (255,), width=int(P * 0.034))
    d.ellipse(
        [c - P * pad * 0.962, c - P * pad * 0.962, c + P * pad * 0.962, c + P * pad * 0.962],
        outline=lerp(IRON, (0, 0, 0), 0.55) + (210,),
        width=int(P * 0.013),
    )
    return img.resize((N, N), Image.LANCZOS)


icon = render(128)
icon.save("images/icon-128.png")
icon.save("icon.tga", compression=None)
render(512, S=4).save("images/curseforge-avatar.png")
print("ok")
