"""Naadloze texturen voor het diorama om het bord (scripts/game/omgeving.gd).

    python tools/maak_omgeving_texturen.py [--uit assets/models/board/omgeving] [--seed 3]

Schrijft drie png's, allemaal NAADLOOS (periodieke ruis, dus ze tegelen
zonder rand):

  gras.png          1024x1024, het grasland: kleur uit de plots van
                    spelbord.png (dus hetzelfde palet als de retexture),
                    grove kleurvlekken, fijne grassprieten in twee richtingen,
                    klaver, een paar bloemetjes en wat kale plekken.
  gras_vlekken.png  512x512, grijs 0,78..1,0: de detail-laag (multiply) op een
                    grovere schaal, tegen het herhaal-effect van de tegel.
  wolken.png        512x512 RGBA: donker met zachte wolkvormen in het
                    alfakanaal, de drijvende wolkenschaduw over het land.

Daarna: Godot --import (de png-imports op VRAM-compressie + mipmaps zetten,
zoals spelbord.png), dan `-- play` om te kijken.
"""
import argparse
import os

import numpy as np
from PIL import Image


def _hash01(ix, iy, seed):
    h = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263
         + np.int64(seed) * 1013904223) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return ((h & 0xFFFFFF).astype(np.float32)) / np.float32(0xFFFFFF)


def ruis(u, v, per_x, per_y, seed):
    """Waarde-ruis op een rooster van per_x bij per_y cellen over [0,1)^2:
    periodiek, dus naadloos. u, v in [0,1)."""
    xs = u * per_x
    ys = v * per_y
    xi = np.floor(xs)
    yi = np.floor(ys)
    fx = (xs - xi).astype(np.float32)
    fy = (ys - yi).astype(np.float32)
    ux = fx * fx * (3.0 - 2.0 * fx)
    uy = fy * fy * (3.0 - 2.0 * fy)
    xi = xi.astype(np.int64) % per_x
    yi = yi.astype(np.int64) % per_y
    xi1 = (xi + 1) % per_x
    yi1 = (yi + 1) % per_y
    a = _hash01(xi, yi, seed)
    b = _hash01(xi1, yi, seed)
    c = _hash01(xi, yi1, seed)
    d = _hash01(xi1, yi1, seed)
    return (a + (b - a) * ux) + ((c + (d - c) * ux) - (a + (b - a) * ux)) * uy


def fbm(u, v, per_x, per_y, octaven, seed):
    tot = np.zeros(u.shape, np.float32)
    amp = 1.0
    som = 0.0
    for o in range(octaven):
        tot += amp * ruis(u, v, per_x << o, per_y << o, seed * 131 + o * 17)
        som += amp
        amp *= 0.5
    return tot / som


def palet_uit_bord(pad, n=11, rand=0.55, vak=1.0):
    """Gemiddelde kleur van de lichte en de donkere plots in spelbord.png."""
    im = np.asarray(Image.open(pad).convert("RGB"), np.float32)
    h, w = im.shape[:2]
    s = n * vak + 2 * rand
    licht = []
    donker = []
    for j in range(n):
        for i in range(n):
            x0 = int((rand + (i + 0.25) * vak) / s * w)
            x1 = int((rand + (i + 0.75) * vak) / s * w)
            y0 = int((rand + (j + 0.25) * vak) / s * h)
            y1 = int((rand + (j + 0.75) * vak) / s * h)
            k = im[y0:y1, x0:x1].reshape(-1, 3).mean(0)
            (licht if (i + j) % 2 == 1 else donker).append(k)
    licht = np.mean(licht, 0)
    donker = np.mean(donker, 0)
    # zorg dat "licht" ook echt de lichtste is
    if licht.mean() < donker.mean():
        licht, donker = donker, licht
    return licht, donker


# --- 10 november: rustiger en fijner (Max: "wat nog echt heel lelijk is, is de
# grondtextuur van de diorama's"). De eerste versie bestond uit grote wazige
# vlekken (bruine plekken in het gras, grijze plassen in de modder) en lange
# strepen die op houtnerf leken. Nu: een egale basis met een lichte
# kleurgolf, fijne korrel op de schaal van sprietjes en steentjes, en per
# grondsoort een eigen patroon (kasseien en scheuren uit een naadloze
# Voronoi, ribbels in het zand). Weinig contrast: het bord en de props moeten
# opvallen, niet de grond.

def _rooster(T):
    kol = (np.arange(T, dtype=np.float32) + 0.5) / T
    return np.broadcast_to(kol[None, :], (T, T)), np.broadcast_to(kol[:, None], (T, T))


def _korrel(T, seed, sterkte):
    """Fijne korrel per pixel (naadloos: geen buren)."""
    rng = np.random.default_rng(seed)
    return (rng.random((T, T), dtype=np.float32) - 0.5) * 2.0 * sterkte


def _zacht(x, a, b):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _meng(a, b, t):
    return a[None, None, :] * (1.0 - t[..., None]) + b[None, None, :] * t[..., None]


def _af(img):
    return np.clip(img, 0, 255).astype(np.uint8)


def _stippen(T, n, r_min, r_max, seed, teken=None):
    """n zachte stipjes (plus en min), over de rand heen gewikkeld."""
    rng = np.random.default_rng(seed)
    uit = np.zeros((T, T), np.float32)
    for _ in range(n):
        cx, cy = rng.integers(0, T, size=2)
        r = rng.uniform(r_min, r_max)
        s = int(r * 2) + 1
        d = np.arange(-s, s + 1, dtype=np.float32)
        g = np.exp(-(d[None, :] ** 2 + d[:, None] ** 2) / (r * r))
        k = teken if teken is not None else rng.choice([-1.0, 1.0])
        uit[np.ix_((np.arange(-s, s + 1) + cy) % T, (np.arange(-s, s + 1) + cx) % T)] += g * k
    return uit


def _voronoi(T, cellen, seed, jitter=0.85):
    """Naadloze Voronoi op een rooster van `cellen` bij `cellen`: afstand tot
    het dichtste en het een na dichtste punt (in cellen) en een getal 0..1 per cel."""
    u, v = _rooster(T)
    x = u * cellen
    y = v * cellen
    xi = np.floor(x).astype(np.int64)
    yi = np.floor(y).astype(np.int64)
    f1 = np.full((T, T), 9.0, np.float32)
    f2 = np.full((T, T), 9.0, np.float32)
    cel = np.zeros((T, T), np.float32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cx = xi + dx
            cy = yi + dy
            wx = cx % cellen
            wy = cy % cellen
            px = cx + 0.5 + (_hash01(wx, wy, seed) - 0.5) * jitter
            py = cy + 0.5 + (_hash01(wx, wy, seed + 7) - 0.5) * jitter
            d = np.sqrt((x - px) ** 2 + (y - py) ** 2).astype(np.float32)
            nieuw = d < f1
            f2 = np.where(nieuw, f1, np.minimum(f2, d))
            cel = np.where(nieuw, _hash01(wx, wy, seed + 13), cel)
            f1 = np.where(nieuw, d, f1)
    return f1, f2, cel


def maak_gras(T, licht, donker, seed):
    u, v = _rooster(T)
    # het palet van de plots op het bord, iets groener en rustiger
    groen = (0.55 * donker + 0.45 * licht) * np.array([0.90, 1.03, 0.84], np.float32)
    zon = groen * np.array([1.10, 1.07, 0.96], np.float32)       # waar het gras lichter en geler is
    golf = _zacht(fbm(u, v, 3, 3, 4, seed + 1), 0.30, 0.70)
    img = _meng(groen, zon, golf * 0.75)
    # sprietjes: fijne streepjes in twee richtingen, plus plukjes
    spriet = (0.11 * (ruis(u, v, 230, 38, seed + 2) - 0.5)
              + 0.09 * (ruis(u, v, 42, 250, seed + 3) - 0.5)
              + 0.07 * (ruis(u, v, 140, 140, seed + 4) - 0.5))
    pluk = 0.045 * _stippen(T, 520, 2.5, 6.5, seed + 6)
    img = img * (1.0 + spriet + pluk + _korrel(T, seed + 5, 0.03))[..., None]
    # een paar bloemetjes (wit en geel), heel dun gezaaid
    rng = np.random.default_rng(seed + 9)
    for _ in range(70):
        cx, cy = rng.integers(0, T, size=2)
        kleur = np.array([236, 232, 214] if rng.random() < 0.6 else [226, 196, 92], np.float32)
        for dy in (0, 1):
            for dx in (0, 1):
                yy, xx = (cy + dy) % T, (cx + dx) % T
                img[yy, xx] = 0.45 * img[yy, xx] + 0.55 * kleur
    return _af(img)


def maak_vlekken(T, seed):
    """De grove laag (multiply) tegen het herhaal-effect: heel licht."""
    u, v = _rooster(T)
    n = 0.55 * fbm(u, v, 3, 3, 3, seed + 11) + 0.45 * fbm(u, v, 6, 6, 2, seed + 12)
    g = 0.90 + 0.10 * np.clip(n / 0.9, 0.0, 1.0)
    return (np.clip(g, 0.0, 1.0) * 255).astype(np.uint8)


def maak_wolken(T, seed):
    """Wolkenschaduw: zachte, lichte vormen (de eerste versie gaf donkere vlekken)."""
    u, v = _rooster(T)
    n = 0.7 * fbm(u, v, 2, 2, 4, seed + 21) + 0.3 * fbm(u, v, 5, 5, 2, seed + 22)
    w = _zacht(n, 0.44, 0.86) * 0.55
    rgba = np.zeros((T, T, 4), np.uint8)
    rgba[..., 0] = 14
    rgba[..., 1] = 16
    rgba[..., 2] = 12
    rgba[..., 3] = (w * 255).astype(np.uint8)
    return rgba


def maak_grond(variant, T, seed):
    """Grondvarianten voor de diorama's: sneeuw, zand, modder, kei, bos, rots.
    Allemaal periodiek, dus naadloos."""
    u, v = _rooster(T)
    grof = fbm(u, v, 3, 3, 4, seed + 32)
    if variant == "sneeuw":
        wit = np.array([234, 239, 245], np.float32)
        schaduw = np.array([204, 216, 233], np.float32)
        img = _meng(wit, schaduw, _zacht(grof, 0.40, 0.78) * 0.65)
        rug = np.sin(2.0 * np.pi * (v * 5.0 + 1.4 * fbm(u, v, 2, 2, 3, seed + 33)))
        img = img * (1.0 + 0.018 * rug + _korrel(T, seed + 34, 0.014))[..., None]
    elif variant == "zand":
        zand = np.array([205, 180, 126], np.float32)
        nat = np.array([186, 160, 110], np.float32)
        img = _meng(zand, nat, _zacht(grof, 0.35, 0.80) * 0.6)
        ribbel = np.sin(2.0 * np.pi * (v * 26.0 + 1.8 * fbm(u, v, 3, 3, 3, seed + 33)))
        steen = -0.05 * np.clip(_stippen(T, 150, 1.5, 3.5, seed + 35, 1.0), 0.0, 1.0)
        img = img * (1.0 + 0.030 * ribbel + steen + _korrel(T, seed + 34, 0.030))[..., None]
    elif variant == "modder":
        droog = np.array([98, 77, 54], np.float32)
        nat = np.array([72, 57, 43], np.float32)
        img = _meng(droog, nat, _zacht(fbm(u, v, 4, 4, 4, seed + 33), 0.46, 0.70) * 0.8)
        klont = 0.12 * (fbm(u, v, 28, 28, 3, seed + 36) - 0.5)
        steen = 0.05 * _stippen(T, 320, 1.8, 4.5, seed + 35)
        img = img * (1.0 + klont + steen + _korrel(T, seed + 34, 0.035))[..., None]
    elif variant == "kei":
        # 44 keien over de tegel van 12 vakken: een kei is ruim een kwart vak
        # (met 18 was een kei bijna zo groot als een bordvak)
        f1, f2, cel = _voronoi(T, 44, seed + 37)
        warm = np.array([130, 120, 104], np.float32)
        koel = np.array([118, 118, 114], np.float32)
        img = _meng(warm, koel, _zacht(_voronoi(T, 44, seed + 38)[2], 0.2, 0.8)) * (0.90 + 0.18 * cel)[..., None]
        voeg = _zacht(f2 - f1, 0.0, 0.16)                  # 0 in de voeg, 1 op de steen
        bol = 1.04 - 0.14 * np.clip(f1, 0.0, 1.0)          # de kop van de kei is lichter
        img = img * ((0.55 + 0.45 * voeg) * bol + _korrel(T, seed + 34, 0.03))[..., None]
    elif variant == "bos":
        aarde = np.array([70, 74, 44], np.float32)
        mos = np.array([62, 90, 44], np.float32)
        blad = np.array([104, 82, 46], np.float32)
        img = _meng(aarde, mos, _zacht(grof, 0.42, 0.74) * 0.5)
        f1, f2, cel = _voronoi(T, 54, seed + 37)
        is_blad = (cel > 0.60).astype(np.float32) * _zacht(f2 - f1, 0.0, 0.18)
        img = img * (1.0 - is_blad * 0.55)[..., None] + blad[None, None, :] * (is_blad * 0.55 * (0.8 + 0.4 * cel))[..., None]
        img = img * (1.0 + 0.10 * (fbm(u, v, 60, 60, 2, seed + 36) - 0.5) + _korrel(T, seed + 34, 0.035))[..., None]
    elif variant == "rots":
        steen = np.array([126, 123, 116], np.float32)
        img = steen[None, None, :] * (0.84 + 0.30 * fbm(u, v, 5, 5, 4, seed + 33))[..., None]
        f1, f2, _cel = _voronoi(T, 7, seed + 37, 0.95)
        scheur = (1.0 - _zacht(f2 - f1, 0.0, 0.035)) * (0.4 + 0.6 * ruis(u, v, 36, 36, seed + 39))
        korst = 0.08 * (fbm(u, v, 48, 48, 2, seed + 36) - 0.5)
        img = img * (1.0 - 0.38 * scheur + korst + _korrel(T, seed + 34, 0.03))[..., None]
    else:
        raise SystemExit("onbekende grondvariant: %s" % variant)
    return _af(img)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--uit", default="assets/models/board/omgeving")
    ap.add_argument("--bord", default="assets/models/board/spelbord/spelbord.png")
    ap.add_argument("--seed", type=int, default=3)
    ap.add_argument("--maat", type=int, default=1024)
    ap.add_argument("--varianten", default="sneeuw,zand,modder,kei,bos,rots",
                    help="grondvarianten voor de diorama's (leeg = geen)")
    ap.add_argument("--maat-variant", type=int, default=768)
    args = ap.parse_args()
    os.makedirs(args.uit, exist_ok=True)
    if os.path.exists(args.bord):
        licht, donker = palet_uit_bord(args.bord)
    else:
        licht = np.array([150, 138, 78], np.float32)
        donker = np.array([102, 108, 56], np.float32)
        print("LET OP: %s niet gevonden, vast palet" % args.bord)
    print("palet uit het bord: licht %s donker %s" % (licht.astype(int), donker.astype(int)))
    gras = maak_gras(args.maat, licht, donker, args.seed)
    Image.fromarray(gras, "RGB").save(os.path.join(args.uit, "gras.png"), optimize=True)
    Image.fromarray(maak_vlekken(512, args.seed), "L").save(os.path.join(args.uit, "gras_vlekken.png"), optimize=True)
    Image.fromarray(maak_wolken(512, args.seed), "RGBA").save(os.path.join(args.uit, "wolken.png"), optimize=True)
    for variant in [x.strip() for x in args.varianten.split(",") if x.strip()]:
        grond = maak_grond(variant, args.maat_variant, args.seed)
        Image.fromarray(grond, "RGB").save(os.path.join(args.uit, "grond_%s.png" % variant), optimize=True)
        g2 = grond.astype(np.int16)
        print("grond_%s.png (%d): naad links-rechts %.1f, boven-onder %.1f" % (
            variant, args.maat_variant, np.abs(g2[:, 0] - g2[:, -1]).mean(), np.abs(g2[0, :] - g2[-1, :]).mean()))
    # naadloosheid: linker- en rechterkolom moeten op elkaar lijken (en boven/onder)
    g = gras.astype(np.int16)
    print("naadcheck gras: links-rechts %.1f, boven-onder %.1f (binnen de tegel gemiddeld %.1f)" % (
        np.abs(g[:, 0] - g[:, -1]).mean(), np.abs(g[0, :] - g[-1, :]).mean(), np.abs(g[:, 1:] - g[:, :-1]).mean()))
    print("geschreven -> %s: gras.png (%d), gras_vlekken.png (512), wolken.png (512)" % (args.uit, args.maat))


if __name__ == "__main__":
    main()
