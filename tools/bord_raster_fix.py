"""Zet een (AI-)retexture van het bord precies op het raster van de tegels.

    python tools/bord_raster_fix.py <plaatje.png|jpg> --uit assets/models/board/spelbord/spelbord.png
        [--vakken 11] [--rand 0.55] [--vak 1.0] [--raster <overlay.png>] [--alleen-meten]

Een retexture-dienst of diffusiemodel schuift het speelveld makkelijk een
paar procent op (8 september: 11,5 px in x en 29 px in y op 1024, een derde
vak). Dan staan de pionnen naast de plots. Dit script meet waar het dambord
in het plaatje WERKELIJK ligt (offset en vakmaat per as, door het
dambord-contrast te maximaliseren: som van (-1)^(i+j) x celgemiddelde) en
warpt het plaatje affien op het raster dat de mesh verwacht: frame van
`rand` en `vakken` vakken van `vak`, precies zoals tools/blender_schaakbord.py
de UV's legt (platte projectie van boven, plaatje = hele plank).

Uitvoer: een RGB-png op de maat van de invoer. Met --raster krijg je een
overlay (rood = verwacht, groen = gemeten) om met eigen ogen te controleren;
met --alleen-meten schrijft hij niets. Daarna: Godot --import, `-- play`.
"""
import argparse
import sys

import numpy as np
from PIL import Image, ImageDraw


def meet(im, n, rand, vak):
    """Offset en vakmaat (px) per as waar het dambord het sterkst is."""
    w, h = im.size
    lum = np.asarray(im.convert("L"), np.float64)
    integ = np.zeros((h + 1, w + 1))
    integ[1:, 1:] = lum.cumsum(0).cumsum(1)
    s = n * vak + 2.0 * rand
    o_exp = rand / s * w
    p_exp = vak / s * w

    def celgem(x0, y0, x1, y1):
        return (integ[y1, x1] - integ[y0, x1] - integ[y1, x0] + integ[y0, x0]) / max((x1 - x0) * (y1 - y0), 1)

    def contrast(ox, px, oy, py, marge=0.2):
        tot = 0.0
        for j in range(n):
            for i in range(n):
                x0 = int(round(ox + (i + marge) * px))
                x1 = int(round(ox + (i + 1 - marge) * px))
                y0 = int(round(oy + (j + marge) * py))
                y1 = int(round(oy + (j + 1 - marge) * py))
                if x1 <= x0 or y1 <= y0 or x0 < 0 or y0 < 0 or x1 > w or y1 > h:
                    return -1.0
                tot += (1 if (i + j) % 2 == 0 else -1) * celgem(x0, y0, x1, y1)
        return abs(tot) / (n * n)

    ox, px, oy, py = o_exp, p_exp, o_exp, p_exp
    c = contrast(ox, px, oy, py)
    c_exp = c
    # grof: per as apart, dan fijn
    for _ in range(3):
        beste = (c, ox, px)
        for dox in np.arange(-0.02 * w, 0.02 * w + 0.1, max(1.0, w / 1024)):
            for dpx in np.arange(-0.004 * w, 0.004 * w + 0.01, max(0.25, w / 4096)):
                cc = contrast(ox + dox, px + dpx, oy, py)
                if cc > beste[0]:
                    beste = (cc, ox + dox, px + dpx)
        c, ox, px = beste
        beste = (c, oy, py)
        for doy in np.arange(-0.02 * h, 0.02 * h + 0.1, max(1.0, h / 1024)):
            for dpy in np.arange(-0.004 * h, 0.004 * h + 0.01, max(0.25, h / 4096)):
                cc = contrast(ox, px, oy + doy, py + dpy)
                if cc > beste[0]:
                    beste = (cc, oy + doy, py + dpy)
        c, oy, py = beste
    for _ in range(2):
        for dox in np.arange(-1, 1.01, 0.25):
            for dpx in np.arange(-0.3, 0.31, 0.05):
                cc = contrast(ox + dox, px + dpx, oy, py)
                if cc > c:
                    c, ox, px = cc, ox + dox, px + dpx
        for doy in np.arange(-1, 1.01, 0.25):
            for dpy in np.arange(-0.3, 0.31, 0.05):
                cc = contrast(ox, px, oy + doy, py + dpy)
                if cc > c:
                    c, oy, py = cc, oy + doy, py + dpy
    return {"ox": ox, "px": px, "oy": oy, "py": py, "contrast": c,
            "o_exp": o_exp, "p_exp": p_exp, "contrast_exp": c_exp}


def afwijking(m, n):
    dx = max(abs(m["ox"] + k * m["px"] - m["o_exp"] - k * m["p_exp"]) for k in range(n + 1))
    dy = max(abs(m["oy"] + k * m["py"] - m["o_exp"] - k * m["p_exp"]) for k in range(n + 1))
    return dx, dy


def teken_raster(im, m, n, pad):
    ov = im.copy()
    d = ImageDraw.Draw(ov)
    w, h = ov.size
    for k in range(n + 1):
        e = m["o_exp"] + k * m["p_exp"]
        d.line([(e, 0), (e, h)], fill=(255, 40, 40), width=1)
        d.line([(0, e), (w, e)], fill=(255, 40, 40), width=1)
        gx = m["ox"] + k * m["px"]
        gy = m["oy"] + k * m["py"]
        d.line([(gx, 0), (gx, h)], fill=(40, 255, 40), width=1)
        d.line([(0, gy), (w, gy)], fill=(40, 255, 40), width=1)
    ov.save(pad)


def affien(m):
    """(a, c, e, f): bestemming (x, y) haalt de bron op (a*x + c, e*y + f),
    zodat het gemeten raster op het verwachte raster komt te liggen."""
    a = m["px"] / m["p_exp"]
    e = m["py"] / m["p_exp"]
    return a, m["ox"] - m["o_exp"] * a, e, m["oy"] - m["o_exp"] * e


def warp(im, t):
    a, c, e, f = t
    return im.transform(im.size, Image.AFFINE, (a, 0, c, 0, e, f), resample=Image.BICUBIC)


def warp_iteratief(im, n, rand, vak, rondes=3, doel_px=1.0):
    """Meet, warp, meet opnieuw; de correcties worden samengesteld tot EEN
    affiene transformatie en het origineel wordt maar een keer herbemonsterd.
    De meting is op een halve pixel per vak onzeker (zachte plotranden), en
    een halve pixel keer elf vakken is aan de verre kant al een paar pixels;
    twee, drie rondes drukken dat onder de pixel."""
    a, c, e, f = 1.0, 0.0, 1.0, 0.0
    uit = im
    m = None
    for _ in range(rondes):
        m = meet(uit, n, rand, vak)
        dx, dy = afwijking(m, n)
        if max(dx, dy) <= doel_px:
            break
        a2, c2, e2, f2 = affien(m)
        # samenstellen: src = T1(T2(dst))
        a, c, e, f = a * a2, a * c2 + c, e * e2, e * f2 + f
        uit = warp(im, (a, c, e, f))
    return uit, m


def main():
    ap = argparse.ArgumentParser(description="Bord-retexture op het tegelraster leggen.")
    ap.add_argument("plaatje")
    ap.add_argument("--uit", help="waar de gecorrigeerde png heen moet")
    ap.add_argument("--vakken", type=int, default=11)
    ap.add_argument("--rand", type=float, default=0.55)
    ap.add_argument("--vak", type=float, default=1.0)
    ap.add_argument("--raster", help="overlay-png schrijven (rood = verwacht, groen = gemeten)")
    ap.add_argument("--alleen-meten", action="store_true")
    args = ap.parse_args()

    im = Image.open(args.plaatje).convert("RGB")
    if im.size[0] != im.size[1]:
        print("LET OP: plaatje is niet vierkant (%dx%d); de UV's zijn dat wel" % im.size)
    n = args.vakken
    m = meet(im, n, args.rand, args.vak)
    dx, dy = afwijking(m, n)
    print("verwacht: offset %.1f px, vakmaat %.2f px (%dx%d)" % (m["o_exp"], m["p_exp"], im.size[0], im.size[1]))
    print("gemeten:  x %.1f/%.2f, y %.1f/%.2f, contrast %.1f (op het verwachte raster %.1f)"
          % (m["ox"], m["px"], m["oy"], m["py"], m["contrast"], m["contrast_exp"]))
    print("grootste naad-afwijking: x %.1f px, y %.1f px" % (dx, dy))
    if args.raster:
        teken_raster(im, m, n, args.raster)
        print("raster-overlay -> %s" % args.raster)
    if args.alleen_meten or not args.uit:
        return 0
    if m["contrast"] < 2.0:
        print("FOUT: geen dambord te vinden (contrast %.1f); niets geschreven" % m["contrast"])
        return 1
    uit, m2 = warp_iteratief(im, n, args.rand, args.vak)
    dx2, dy2 = afwijking(m2, n)
    print("na warp: x %.1f/%.2f, y %.1f/%.2f, afwijking x %.1f px, y %.1f px"
          % (m2["ox"], m2["px"], m2["oy"], m2["py"], dx2, dy2))
    if max(dx2, dy2) > 2.5:
        print("FOUT: na de warp nog %.1f px afwijking; niets geschreven" % max(dx2, dy2))
        return 1
    uit.save(args.uit, optimize=True)
    print("geschreven -> %s (%dx%d RGB)" % (args.uit, uit.size[0], uit.size[1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
