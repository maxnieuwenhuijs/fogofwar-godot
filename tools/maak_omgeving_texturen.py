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


def maak_gras(T, licht, donker, seed):
    kol = (np.arange(T, dtype=np.float32) + 0.5) / T
    u = np.broadcast_to(kol[None, :], (T, T))
    v = np.broadcast_to(kol[:, None], (T, T))
    basis = 0.5 * licht + 0.5 * donker
    basis = basis * np.array([0.92, 1.02, 0.86], np.float32)   # iets donkerder en groener dan het bord
    grijs = basis.mean()
    basis = basis + (basis - grijs) * -0.10              # en iets minder verzadigd
    oker = np.array([150, 128, 70], np.float32)
    aarde = np.array([92, 72, 48], np.float32)

    # grove vlekken: droge plekken (oker) en vollere, donkere plekken
    vlek = fbm(u, v, 4, 4, 3, seed + 1)
    vlek2 = fbm(u, v, 7, 7, 2, seed + 2)
    kleur = basis[None, None, :] * (0.86 + 0.28 * vlek)[..., None]
    kleur = kleur + (oker - kleur) * np.clip((vlek2 - 0.58) / 0.25, 0.0, 1.0)[..., None] * 0.35

    # grassprieten: fijne anisotrope ruis in twee richtingen
    spriet1 = fbm(u, v, 24, 160, 2, seed + 3)            # streepjes langs v (verticaal)
    spriet2 = fbm(u, v, 160, 24, 2, seed + 4)            # streepjes langs u
    meng = fbm(u, v, 3, 3, 2, seed + 5)                  # waar welke richting de overhand heeft
    spriet = spriet1 * meng + spriet2 * (1.0 - meng)
    kleur = kleur * (0.84 + 0.32 * spriet)[..., None]
    fijn = fbm(u, v, 256, 256, 2, seed + 6)
    kleur = kleur * (0.93 + 0.14 * fijn)[..., None]

    # kale plekken (aarde): zeldzaam, met een zachte rand
    kaal = fbm(u, v, 5, 5, 3, seed + 7)
    kaal = np.clip((kaal - 0.66) / 0.10, 0.0, 1.0)
    kleur = kleur + (aarde - kleur) * (0.8 * kaal)[..., None]

    # klaver: kleine donkerdere groene plukjes
    klaver = fbm(u, v, 96, 96, 2, seed + 8)
    klaver = np.clip((klaver - 0.72) / 0.08, 0.0, 1.0)
    klaverkleur = np.array([70, 92, 40], np.float32)
    kleur = kleur + (klaverkleur - kleur) * (0.5 * klaver)[..., None]

    # bloemetjes: een handjevol witte en gele stipjes, naadloos via modulo
    rng = np.random.default_rng(seed)
    # zacht en spaarzaam: felle witte stipjes lazen op afstand als sterren
    aantal = int(T * T / 16000)
    for _ in range(aantal):
        cx, cy = rng.integers(0, T, size=2)
        r = int(rng.integers(1, 3))
        geel = rng.random() < 0.7
        bloem = np.array([200, 176, 70], np.float32) if geel else np.array([200, 196, 178], np.float32)
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    kleur[(cy + dy) % T, (cx + dx) % T] = bloem * 0.5 + kleur[(cy + dy) % T, (cx + dx) % T] * 0.5
    return np.clip(kleur, 0, 255).astype(np.uint8)


def maak_vlekken(T, seed):
    kol = (np.arange(T, dtype=np.float32) + 0.5) / T
    u = np.broadcast_to(kol[None, :], (T, T))
    v = np.broadcast_to(kol[:, None], (T, T))
    n = fbm(u, v, 3, 3, 3, seed + 11)
    n2 = fbm(u, v, 6, 6, 2, seed + 12)
    g = 0.78 + 0.22 * np.clip(0.55 * n + 0.45 * n2, 0.0, 1.0) / 0.9
    g = np.clip(g, 0.0, 1.0)
    return (g * 255).astype(np.uint8)


def maak_wolken(T, seed):
    kol = (np.arange(T, dtype=np.float32) + 0.5) / T
    u = np.broadcast_to(kol[None, :], (T, T))
    v = np.broadcast_to(kol[:, None], (T, T))
    n = fbm(u, v, 2, 2, 4, seed + 21)
    n2 = fbm(u, v, 5, 5, 2, seed + 22)
    w = np.clip((0.7 * n + 0.3 * n2 - 0.46) / 0.30, 0.0, 1.0)
    w = w * w * (3.0 - 2.0 * w)                           # zachte randen
    rgba = np.zeros((T, T, 4), np.uint8)
    rgba[..., 0] = 10
    rgba[..., 1] = 12
    rgba[..., 2] = 8
    rgba[..., 3] = (w * 255).astype(np.uint8)
    return rgba


def maak_grond(variant, T, seed):
    """Grondvarianten voor de diorama's (11 september): sneeuw, zand, modder,
    kei, bos, rots. Allemaal periodiek, dus naadloos."""
    kol = (np.arange(T, dtype=np.float32) + 0.5) / T
    u = np.broadcast_to(kol[None, :], (T, T))
    v = np.broadcast_to(kol[:, None], (T, T))
    fijn = fbm(u, v, 256, 256, 2, seed + 31)
    grof = fbm(u, v, 4, 4, 3, seed + 32)
    rng = np.random.default_rng(seed + 40)

    def stipjes(kleur, aantal, r_max, sterkte):
        for _ in range(aantal):
            cx, cy = rng.integers(0, T, size=2)
            r = int(rng.integers(1, r_max + 1))
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if dx * dx + dy * dy <= r * r:
                        kleur_px = kleur_arr[(cy + dy) % T, (cx + dx) % T]
                        kleur_arr[(cy + dy) % T, (cx + dx) % T] = kleur * sterkte + kleur_px * (1 - sterkte)

    if variant == "sneeuw":
        basis = np.array([228, 233, 240], np.float32)
        kleur_arr = basis[None, None, :] * (0.92 + 0.08 * grof)[..., None] * (0.96 + 0.06 * fijn)[..., None]
        schaduw = np.clip((fbm(u, v, 6, 6, 2, seed + 33) - 0.55) / 0.3, 0, 1)
        kleur_arr = kleur_arr * (1.0 - 0.12 * schaduw)[..., None] * np.array([0.96, 0.98, 1.03], np.float32)
        kaal = np.clip((fbm(u, v, 5, 5, 3, seed + 34) - 0.72) / 0.08, 0, 1)
        kleur_arr = kleur_arr + (np.array([120, 105, 80], np.float32) - kleur_arr) * (0.7 * kaal)[..., None]
    elif variant == "zand":
        basis = np.array([198, 174, 122], np.float32)
        kleur_arr = basis[None, None, :] * (0.9 + 0.14 * grof)[..., None] * (0.95 + 0.08 * fijn)[..., None]
        r = fbm(u, v, 3, 60, 2, seed + 35)
        ribbel = 0.5 + 0.5 * np.sin(2 * np.pi * (v * 90 + (r - 0.5) * 4))
        kleur_arr = kleur_arr * (0.9 + 0.12 * ribbel)[..., None]
        spik = np.clip((fbm(u, v, 180, 180, 2, seed + 36) - 0.78) / 0.06, 0, 1)
        kleur_arr = kleur_arr * (1.0 - 0.3 * spik)[..., None]
    elif variant == "modder":
        basis = np.array([96, 76, 54], np.float32)
        kleur_arr = basis[None, None, :] * (0.85 + 0.3 * grof)[..., None] * (0.92 + 0.14 * fijn)[..., None]
        streep = fbm(u, v, 2, 120, 2, seed + 37)
        kleur_arr = kleur_arr * (0.85 + 0.3 * streep)[..., None]
        plas = np.clip((fbm(u, v, 5, 5, 3, seed + 38) - 0.64) / 0.08, 0, 1)
        kleur_arr = kleur_arr + (np.array([58, 64, 70], np.float32) - kleur_arr) * (0.85 * plas)[..., None]
        stipjes(np.array([70, 95, 40], np.float32), int(T * T / 6000), 2, 0.6)
    elif variant == "kei":
        n = 36   # keien van ~0,33 eenheid (14 was een straatje van reuzen)
        cx = np.floor(u * n)
        cy = np.floor(v * n)
        fx = u * n - cx
        fy = v * n - cy
        jx = (_hash01(cx.astype(np.int64) % n, cy.astype(np.int64) % n, seed + 41) - 0.5) * 0.16
        jy = (_hash01(cx.astype(np.int64) % n, cy.astype(np.int64) % n, seed + 42) - 0.5) * 0.16
        d = np.sqrt((fx - 0.5 - jx) ** 2 + (fy - 0.5 - jy) ** 2)
        steen = np.clip((0.44 - d) / 0.05, 0, 1)
        toon = 112 + 42 * _hash01(cx.astype(np.int64) % n, cy.astype(np.int64) % n, seed + 43)
        kleur_arr = np.stack([toon * 1.02, toon, toon * 0.94], axis=-1) * (0.94 + 0.12 * fijn)[..., None]
        # licht van linksboven: de bovenkant van elke kei net lichter
        kleur_arr = kleur_arr * (1.0 + 0.08 * (0.5 - fy) - 0.04 * (fx - 0.5))[..., None]
        voeg = np.array([66, 62, 56], np.float32)
        kleur_arr = kleur_arr * steen[..., None] + voeg[None, None, :] * (1 - steen)[..., None] * (0.9 + 0.2 * fijn)[..., None]
        kleur_arr = kleur_arr * (0.92 + 0.12 * grof)[..., None]
    elif variant == "bos":
        basis = np.array([72, 80, 44], np.float32)
        kleur_arr = basis[None, None, :] * (0.85 + 0.35 * grof)[..., None] * (0.9 + 0.2 * fijn)[..., None]
        mos = np.clip((fbm(u, v, 6, 6, 3, seed + 44) - 0.58) / 0.15, 0, 1)
        kleur_arr = kleur_arr + (np.array([72, 96, 42], np.float32) - kleur_arr) * (0.7 * mos)[..., None]
        stipjes(np.array([150, 90, 40], np.float32), int(T * T / 900), 2, 0.7)
        stipjes(np.array([110, 70, 30], np.float32), int(T * T / 1200), 2, 0.6)
    else:  # rots
        basis = np.array([122, 118, 110], np.float32)
        kleur_arr = basis[None, None, :] * (0.85 + 0.3 * grof)[..., None] * (0.92 + 0.14 * fijn)[..., None]
        barst = np.clip((fbm(u, v, 90, 90, 3, seed + 45) - 0.66) / 0.03, 0, 1) * np.clip((0.7 - fbm(u, v, 90, 90, 3, seed + 45)) / 0.03, 0, 1)
        kleur_arr = kleur_arr * (1.0 - 0.45 * barst)[..., None]
        sneeuw = np.clip((fbm(u, v, 4, 4, 3, seed + 46) - 0.66) / 0.08, 0, 1)
        kleur_arr = kleur_arr + (np.array([225, 230, 238], np.float32) - kleur_arr) * (0.85 * sneeuw)[..., None]
    return np.clip(kleur_arr, 0, 255).astype(np.uint8)


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
