"""Bouwstenen voor de low-poly props uit Blender (13 september, Max: "56
voorbeelden, exact zo moeten ze in Blender"). Wordt door tools/blender_props/
bouw_props.py binnen Blender geladen; de recepten in recepten.py bouwen elke
prop uit deze stenen.

Principes (zie ook tools/blender_appelkist.py, de eerste):
  - EEN mesh, EEN materiaal, EEN plaatje per prop: de atlas (1024 px, een
    raster van 8 x 8 stofjes van 128 px: hout, duigen, schors, ijzer, roest,
    goud, touw, doek, steen, ...) komt uit numpy en is per vak tileerbaar.
  - Platte facetten op kisten en planken; ronde dingen (tonnen, emmers,
    ketels) zijn draaivormen (`lathe`) met 10-14 segmenten, staven zijn
    dus letterlijk de facetten. `glad=True` voor kannen en ketels.
  - Per vlak past de uv in EEN stofje (geen wrap over de rand van het
    vak); rondom een draaivorm loopt u een keer rond (naad op een facetrand).
  - Alles staat met de voeten op z = 0 en de VOORKANT naar -Y (glTF +Z, naar
    de speler); de maten zijn bord-eenheden (een tegel 1, een pion 0,62).
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ATLAS_PX = 1024
RASTER = 8
VAK = ATLAS_PX // RASTER

# stofje -> (kolom, rij) in het raster (rij 0 = bovenaan het plaatje)
SWATCHES = {
    "hout_licht": (0, 0), "hout_donker": (1, 0), "hout_verweerd": (2, 0), "hout_blauw": (3, 0),
    "schors": (4, 0), "kops": (5, 0), "duigen_licht": (6, 0), "duigen_verweerd": (7, 0),
    "duigen_blauw": (0, 1), "ijzer": (1, 1), "roest": (2, 1), "goud": (3, 1),
    "koper": (4, 1), "zilver": (5, 1), "leer": (6, 1), "touw": (7, 1),
    "jute": (0, 2), "linnen_wit": (1, 2), "linnen_grijs": (2, 2), "blauw_fluweel": (3, 2),
    "blauw_goudrand": (4, 2), "steen": (5, 2), "klei": (6, 2), "glas": (7, 2),
    "was": (0, 3), "lei": (1, 3), "donker": (2, 3), "fleur": (3, 3),
    "kroon": (4, 3), "brood": (5, 3), "riet": (6, 3), "grond": (7, 3),
    "tapijt": (0, 4), "wapen": (1, 4), "rood_doek": (2, 4), "hout_rood": (3, 4),
}


# ---------------------------------------------------------------- de atlas (numpy)

def pnoise(n, cel, seed):
    """Periodieke value-noise n x n met cellen van `cel` px (tileerbaar)."""
    r = np.random.default_rng(seed)
    g = n // cel
    grid = r.random((g, g)).astype(np.float32)
    s = np.arange(n) / cel
    i0 = np.floor(s).astype(int)
    f = (s - i0).astype(np.float32)
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % g
    a = grid[np.ix_(i0 % g, i0 % g)]
    b = grid[np.ix_(i0 % g, i1)]
    c = grid[np.ix_(i1, i0 % g)]
    d = grid[np.ix_(i1, i1)]
    fx = f[None, :]
    fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(n, seed, cellen=(64, 32, 16, 8), gewichten=(0.5, 0.25, 0.15, 0.1)):
    uit = np.zeros((n, n), np.float32)
    for k, (c, w) in enumerate(zip(cellen, gewichten)):
        uit += w * pnoise(n, c, seed + 7 * k)
    return uit / sum(gewichten)


def _kleur(rgb):
    return np.array(rgb, np.float32)[None, None, :]


def hout(n, seed, basis, contrast=0.22, lijnen=5, verticaal=False, grijs=0.0):
    """Planken: nerf langs u (of langs v), een paar donkere lijnen, vlekken."""
    yy = np.arange(n)[:, None].astype(np.float32)
    nerf = np.sin(2 * math.pi * (yy / 11.0 + 0.9 * pnoise(n, 32, seed) + 0.2 * pnoise(n, 8, seed + 1)))
    licht = 0.78 + contrast * (0.5 + 0.5 * nerf) + 0.1 * (fbm(n, seed + 2) - 0.5)
    img = _kleur(basis) * licht[:, :, None]
    r = np.random.default_rng(seed + 3)
    for k in range(lijnen):
        y = int(r.integers(0, n))
        d = 0.7 + 0.15 * pnoise(n, 16, seed + 10 + k)[y % n]
        img[y, :, :] *= d[:, None]
    if grijs > 0:
        g = img.mean(axis=2, keepdims=True)
        img = img * (1 - grijs) + g * grijs
    if verticaal:
        img = np.transpose(img, (1, 0, 2))
    return np.clip(img, 0, 1)


def duigen(n, seed, basis, aantal=7, contrast=0.2, grijs=0.0):
    """Duigen: verticale nerf plus een donkere naad per duig, elke duig iets anders."""
    img = hout(n, seed, basis, contrast, lijnen=3, verticaal=True, grijs=grijs)
    breedte = n / aantal
    xx = np.arange(n)
    r = np.random.default_rng(seed + 5)
    for k in range(aantal):
        x0 = int(k * breedte)
        x1 = int((k + 1) * breedte)
        img[:, x0:x1, :] *= r.uniform(0.9, 1.06)
        img[:, x0 % n, :] *= 0.55
        if x0 + 1 < n:
            img[:, (x0 + 1) % n, :] *= 0.8
    return np.clip(img, 0, 1)


def schors(n, seed):
    img = hout(n, seed, (0.3, 0.22, 0.14), 0.45, lijnen=12, verticaal=True)
    img *= (0.75 + 0.5 * pnoise(n, 8, seed + 20))[:, :, None]
    return np.clip(img, 0, 1)


def kops(n, seed, basis=(0.72, 0.58, 0.38)):
    """Kopse kant: jaarringen om het midden, een paar scheuren."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    rr = np.hypot(xx - n / 2 + 3, yy - n / 2 - 2)
    ringen = 0.5 + 0.5 * np.sin(rr * 0.55 + 2.0 * pnoise(n, 16, seed))
    img = _kleur(basis) * (0.72 + 0.28 * ringen)[:, :, None]
    hoek = np.arctan2(yy - n / 2, xx - n / 2)
    for h in (0.3, 2.4, -1.7):
        scheur = np.exp(-((hoek - h) ** 2) / 0.0015) * (rr > 8)
        img *= (1 - 0.55 * scheur)[:, :, None]
    rand = np.clip((rr - n * 0.47) / 3.0, 0, 1)
    img = img * (1 - rand)[:, :, None] + _kleur((0.3, 0.22, 0.14)) * rand[:, :, None]
    return np.clip(img, 0, 1)


def metaal(n, seed, basis, kras=0.12, vlek=0.1):
    img = _kleur(basis) * (0.86 + 0.28 * (fbm(n, seed) - 0.5) * 2)[:, :, None]
    yy = np.arange(n)[:, None]
    krassen = 0.5 + 0.5 * np.sin(2 * math.pi * (yy / 3.0 + 3.0 * pnoise(n, 64, seed + 3)))
    img *= (1 - kras * krassen)[:, :, None]
    img *= (1 - vlek * (pnoise(n, 16, seed + 4) > 0.65))[:, :, None]
    return np.clip(img, 0, 1)


def roest(n, seed):
    img = metaal(n, seed, (0.28, 0.24, 0.22), 0.1, 0.0)
    m = np.clip((fbm(n, seed + 30) - 0.42) * 3.0, 0, 1)
    roestkleur = _kleur((0.55, 0.27, 0.12)) * (0.8 + 0.4 * pnoise(n, 8, seed + 31))[:, :, None]
    return np.clip(img * (1 - m)[:, :, None] + roestkleur * m[:, :, None], 0, 1)


def stof(n, seed, basis, weefsel=0.06, vlek=0.08):
    yy, xx = np.mgrid[0:n, 0:n]
    weef = 0.5 + 0.5 * np.sin(xx * math.pi / 2) * np.sin(yy * math.pi / 2)
    img = _kleur(basis) * (1 - weefsel * weef + vlek * (fbm(n, seed) - 0.5) * 2)[:, :, None]
    return np.clip(img, 0, 1)


def touw(n, seed):
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    streng = 0.5 + 0.5 * np.sin(2 * math.pi * (xx / n * 10 + yy / n * 2.0))
    img = _kleur((0.62, 0.52, 0.34)) * (0.72 + 0.3 * streng + 0.1 * (pnoise(n, 8, seed) - 0.5))[:, :, None]
    return np.clip(img, 0, 1)


def jute(n, seed):
    yy, xx = np.mgrid[0:n, 0:n]
    lijn = ((xx % 6 == 0) | (yy % 6 == 0)).astype(np.float32)
    img = _kleur((0.58, 0.48, 0.32)) * (0.95 - 0.25 * lijn + 0.1 * (fbm(n, seed) - 0.5))[:, :, None]
    return np.clip(img, 0, 1)


def riet(n, seed):
    """Vlechtwerk: afwisselend liggende en staande bandjes."""
    yy, xx = np.mgrid[0:n, 0:n]
    cel = 16
    cx = (xx // cel) % 2
    cy = (yy // cel) % 2
    horizontaal = (cx + cy) % 2 == 0
    fase = np.where(horizontaal, (yy % cel) / cel, (xx % cel) / cel)
    band = 0.55 + 0.45 * np.sin(fase * math.pi)
    img = _kleur((0.45, 0.33, 0.2)) * (0.6 + 0.5 * band + 0.08 * (fbm(n, seed) - 0.5))[:, :, None]
    return np.clip(img, 0, 1)


def steen(n, seed):
    yy, xx = np.mgrid[0:n, 0:n]
    rij = yy // 24
    xs = (xx + (rij % 2) * 20) % 40
    voeg = ((yy % 24) < 3) | (xs < 3)
    img = _kleur((0.55, 0.53, 0.5)) * (0.8 + 0.3 * pnoise(n, 16, seed) + 0.1 * (fbm(n, seed + 1) - 0.5))[:, :, None]
    img = np.where(voeg[:, :, None], _kleur((0.32, 0.3, 0.28)), img)
    return np.clip(img, 0, 1)


def lei(n, seed):
    yy, xx = np.mgrid[0:n, 0:n]
    rij = yy // 21
    xs = (xx + (rij % 2) * 16) % 32
    voeg = ((yy % 21) < 2) | (xs < 2)
    img = _kleur((0.3, 0.32, 0.36)) * (0.85 + 0.25 * pnoise(n, 8, seed))[:, :, None]
    img = np.where(voeg[:, :, None], _kleur((0.15, 0.16, 0.18)), img)
    return np.clip(img, 0, 1)


def goudrand(n, seed, basis=(0.13, 0.2, 0.5), rand=(0.85, 0.68, 0.25), dikte=9, marge=6):
    """Doek met een gouden bies langs de rand (niet tileerbaar: een heel vlak per stofje)."""
    img = stof(n, seed, basis, 0.05, 0.1)
    yy, xx = np.mgrid[0:n, 0:n]
    d = np.minimum(np.minimum(xx, n - 1 - xx), np.minimum(yy, n - 1 - yy))
    bies = (d >= marge) & (d < marge + dikte)
    img = np.where(bies[:, :, None], _kleur(rand) * (0.9 + 0.2 * pnoise(n, 8, seed + 2))[:, :, None], img)
    dun = (d >= marge + dikte + 4) & (d < marge + dikte + 6)
    img = np.where(dun[:, :, None], _kleur(rand) * 0.9, img)
    return np.clip(img, 0, 1)


def _ellips(xx, yy, cx, cy, rx, ry, hoek=0.0):
    c, s = math.cos(hoek), math.sin(hoek)
    dx = (xx - cx) * c + (yy - cy) * s
    dy = -(xx - cx) * s + (yy - cy) * c
    return (dx / rx) ** 2 + (dy / ry) ** 2 <= 1.0


def fleur(n, seed, basis=(0.13, 0.2, 0.5), goud=(0.85, 0.68, 0.25)):
    """Een fleur-de-lis in goud op blauw (drie lobben, een bandje en een voet)."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    cx, cy = n / 2, n / 2
    m = _ellips(xx, yy, cx, cy - 10, 9, 34)                      # middenblad
    m |= _ellips(xx, yy, cx, cy - 46, 7, 9)                      # punt
    m |= _ellips(xx, yy, cx - 24, cy - 6, 8, 22, -0.55)          # linkerblad
    m |= _ellips(xx, yy, cx + 24, cy - 6, 8, 22, 0.55)           # rechterblad
    m |= _ellips(xx, yy, cx - 28, cy - 26, 9, 7)
    m |= _ellips(xx, yy, cx + 28, cy - 26, 9, 7)
    m |= (np.abs(xx - cx) < 26) & (np.abs(yy - (cy + 20)) < 5)   # bandje
    m |= _ellips(xx, yy, cx, cy + 36, 8, 14)                     # voet
    m |= _ellips(xx, yy, cx - 12, cy + 42, 8, 7)
    m |= _ellips(xx, yy, cx + 12, cy + 42, 8, 7)
    img = stof(n, seed, basis, 0.05, 0.1)
    glans = (0.85 + 0.3 * np.clip(1 - (yy - cy + 40) / 90, 0, 1))[:, :, None]
    return np.clip(np.where(m[:, :, None], _kleur(goud) * glans, img), 0, 1)


def kroon(n, seed, basis=(0.13, 0.2, 0.5), goud=(0.85, 0.68, 0.25)):
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    cx, cy = n / 2, n / 2
    m = (np.abs(xx - cx) < 36) & (yy > cy) & (yy < cy + 22)            # band
    for k in (-28, -14, 0, 14, 28):
        m |= (np.abs(xx - (cx + k)) < 5) & (yy > cy - 26) & (yy <= cy)   # punten
        m |= _ellips(xx, yy, cx + k, cy - 30, 6, 6)                      # bolletjes
    m |= (np.abs(xx - cx) < 32) & (np.abs(yy - (cy + 11)) < 2)
    img = stof(n, seed, basis, 0.05, 0.1)
    return np.clip(np.where(m[:, :, None], _kleur(goud), img), 0, 1)


def wapen(n, seed):
    """Wapenschild: gouden rand, blauw veld, fleur in het midden."""
    img = fleur(n, seed)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    cx = n / 2
    breedte = np.where(yy < n * 0.55, n * 0.42, n * 0.42 * (1 - (yy - n * 0.55) / (n * 0.45)) ** 0.7)
    binnen = np.abs(xx - cx) <= breedte
    rand = binnen & (np.abs(xx - cx) > breedte - 7)
    rand |= binnen & (yy < 9)
    buiten = ~binnen
    img = np.where(rand[:, :, None], _kleur((0.85, 0.68, 0.25)), img)
    img = np.where(buiten[:, :, None], _kleur((0.3, 0.22, 0.14)) * 0.9, img)
    return np.clip(img, 0, 1)


def tapijt(n, seed, basis=(0.12, 0.18, 0.46), goud=(0.8, 0.64, 0.24)):
    img = goudrand(n, seed, basis, goud, 6, 4)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    cx, cy = n / 2, n / 2
    d = np.abs(xx - cx) + np.abs(yy - cy)
    m = (d > 30) & (d < 36)
    m |= (np.hypot(xx - cx, yy - cy) > 14) & (np.hypot(xx - cx, yy - cy) < 18)
    m |= (np.abs(xx - cx) < 3) & (np.abs(yy - cy) < 12)
    m |= (np.abs(yy - cy) < 3) & (np.abs(xx - cx) < 12)
    for (px, py) in ((cx - 42, cy - 42), (cx + 42, cy - 42), (cx - 42, cy + 42), (cx + 42, cy + 42)):
        m |= _ellips(xx, yy, px, py, 8, 8) & ~_ellips(xx, yy, px, py, 4, 4)
    rand = np.minimum(np.minimum(xx, n - 1 - xx), np.minimum(yy, n - 1 - yy))
    m |= (rand > 16) & (rand < 19)
    return np.clip(np.where(m[:, :, None], _kleur(goud), img), 0, 1)


def brood(n, seed):
    img = _kleur((0.72, 0.48, 0.24)) * (0.85 + 0.3 * pnoise(n, 16, seed))[:, :, None]
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    for k in range(4):
        snede = np.abs((xx - n / 2) * 0.35 - (yy - n * (0.25 + 0.17 * k))) < 2.0
        img = np.where(snede[:, :, None], _kleur((0.9, 0.78, 0.5)), img)
    return np.clip(img, 0, 1)


def maak_atlas(seed=1):
    """Het hele plaatje (rij 0 bovenaan), float32 h x w x 3."""
    n = VAK
    img = np.zeros((ATLAS_PX, ATLAS_PX, 3), np.float32)
    recepten = {
        "hout_licht": hout(n, seed, (0.66, 0.5, 0.32)),
        "hout_donker": hout(n, seed + 1, (0.42, 0.3, 0.18), 0.25),
        "hout_verweerd": hout(n, seed + 2, (0.5, 0.44, 0.34), 0.3, lijnen=8, grijs=0.35),
        "hout_blauw": hout(n, seed + 3, (0.16, 0.24, 0.5), 0.18),
        "schors": schors(n, seed + 4),
        "kops": kops(n, seed + 5),
        "duigen_licht": duigen(n, seed + 6, (0.62, 0.46, 0.28)),
        "duigen_verweerd": duigen(n, seed + 7, (0.48, 0.42, 0.33), grijs=0.4),
        "duigen_blauw": duigen(n, seed + 8, (0.16, 0.24, 0.52), contrast=0.15),
        "ijzer": metaal(n, seed + 9, (0.24, 0.24, 0.26)),
        "roest": roest(n, seed + 10),
        "goud": metaal(n, seed + 11, (0.85, 0.66, 0.24), 0.08, 0.05),
        "koper": metaal(n, seed + 12, (0.66, 0.4, 0.24), 0.1, 0.15),
        "zilver": metaal(n, seed + 13, (0.72, 0.72, 0.74), 0.08, 0.05),
        "leer": stof(n, seed + 14, (0.32, 0.2, 0.12), 0.03, 0.2),
        "touw": touw(n, seed + 15),
        "jute": jute(n, seed + 16),
        "linnen_wit": stof(n, seed + 17, (0.88, 0.85, 0.76), 0.08, 0.06),
        "linnen_grijs": stof(n, seed + 18, (0.55, 0.52, 0.46), 0.08, 0.14),
        "blauw_fluweel": stof(n, seed + 19, (0.13, 0.2, 0.5), 0.04, 0.12),
        "blauw_goudrand": goudrand(n, seed + 20),
        "steen": steen(n, seed + 21),
        "klei": stof(n, seed + 22, (0.62, 0.36, 0.24), 0.02, 0.18),
        "glas": stof(n, seed + 23, (0.95, 0.72, 0.35), 0.0, 0.1),
        "was": stof(n, seed + 24, (0.92, 0.86, 0.7), 0.0, 0.06),
        "lei": lei(n, seed + 25),
        "donker": stof(n, seed + 26, (0.07, 0.06, 0.05), 0.0, 0.1),
        "fleur": fleur(n, seed + 27),
        "kroon": kroon(n, seed + 28),
        "brood": brood(n, seed + 29),
        "riet": riet(n, seed + 30),
        "grond": stof(n, seed + 31, (0.3, 0.26, 0.18), 0.02, 0.25),
        "tapijt": tapijt(n, seed + 32),
        "wapen": wapen(n, seed + 33),
        "rood_doek": stof(n, seed + 34, (0.55, 0.18, 0.14), 0.06, 0.14),
        "hout_rood": hout(n, seed + 35, (0.5, 0.2, 0.14), 0.2),
    }
    for naam, (kol, rij) in SWATCHES.items():
        vak = recepten.get(naam)
        if vak is None:
            continue
        img[rij * n:(rij + 1) * n, kol * n:(kol + 1) * n, :] = vak
    return img


def atlas_naar_blender(img, naam, png_pad):
    """Numpy-plaatje (rij 0 boven) als Blender-image, opgeslagen als png (de
    glTF-export bakt hem in). Bpy-valkuil: nooit colorspace_settings aanraken
    na foreach_set."""
    h, w, _ = img.shape
    im = bpy.data.images.new(naam, w, h, alpha=False)
    rgba = np.ones((h, w, 4), np.float32)
    rgba[:, :, :3] = img[::-1, :, :]     # Blender begint onderaan
    im.pixels.foreach_set(rgba.ravel())
    im.filepath_raw = png_pad
    im.file_format = "PNG"
    im.save()
    terug = np.zeros(w * h * 4, np.float32)
    im.pixels.foreach_get(terug)
    if terug[0::4].mean() < 0.05:
        raise RuntimeError("de atlas is zwart (bpy colorspace-valkuil?)")
    return im


# ---------------------------------------------------------------- de bouwer

class Bouwer:
    """Een prop in aanbouw: bmesh + uv-laag, de stenen schrijven hun uv's meteen."""

    def __init__(self, atlas_image, rng):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.atlas = atlas_image
        self.rng = rng
        self.glad_faces = set()
        self.dubbelzijdig = False

    # --- uv-hulpjes ---------------------------------------------------------
    @staticmethod
    def _vak(swatch, fu, fv):
        kol, rij = SWATCHES[swatch]
        fu = min(max(fu, 0.004), 0.996)
        fv = min(max(fv, 0.004), 0.996)
        return ((kol + fu) / RASTER, 1.0 - (rij + 1 - fv) / RASTER)

    def uv_vlak(self, faces, swatch, per_eenheid=2.0, nerf_as=None, vast=None):
        """Per vlak een platte projectie in het stofje; `per_eenheid` = hoeveel
        stofjes een bord-eenheid beslaat (kleiner als het vlak anders niet past);
        `nerf_as` ('x','y','z') legt de nerf (u) langs die as; `vast` = (fu, fv)
        legt het hele vlak op een punt (effen kleur)."""
        for f in faces:
            if vast is not None:
                for lp in f.loops:
                    lp[self.uv].uv = self._vak(swatch, vast[0], vast[1])
                continue
            n = f.normal
            if n.length < 1e-9:
                f.normal_update()
                n = f.normal
            ax = max(range(3), key=lambda k: abs(n[k]))
            assen = [k for k in range(3) if k != ax]
            if nerf_as is not None:
                w = "xyz".index(nerf_as)
                if w in assen and assen[0] != w:
                    assen.reverse()
            a, b = assen
            cos = [lp.vert.co for lp in f.loops]
            mina, maxa = min(c[a] for c in cos), max(c[a] for c in cos)
            minb, maxb = min(c[b] for c in cos), max(c[b] for c in cos)
            ea, eb = max(maxa - mina, 1e-6), max(maxb - minb, 1e-6)
            schaal = min(per_eenheid, 0.96 / ea, 0.96 / eb)
            ou = self.rng.uniform(0.0, max(0.0, 0.98 - ea * schaal))
            ov = self.rng.uniform(0.0, max(0.0, 0.98 - eb * schaal))
            for lp in f.loops:
                c = lp.vert.co
                lp[self.uv].uv = self._vak(swatch, ou + (c[a] - mina) * schaal, ov + (c[b] - minb) * schaal)

    # --- primitieven --------------------------------------------------------
    def _faces_van(self, verts):
        return list({f for v in verts for f in v.link_faces})

    def box(self, maat, pos, rot=None, swatch="hout_licht", per_eenheid=2.0, nerf_as="auto", vast=None):
        r = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = r["verts"]
        m = Matrix.Translation(Vector(pos))
        if rot is not None:
            m = m @ rot
        m = m @ Matrix.Diagonal(Vector(maat).to_4d())
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        faces = self._faces_van(verts)
        if nerf_as == "auto":
            nerf_as = "xyz"[max(range(3), key=lambda k: maat[k])]
        self.uv_vlak(faces, swatch, per_eenheid, nerf_as, vast)
        return faces

    def lathe(self, profiel, pos, segs=12, swatch="duigen_licht", boven=None, onder=None, glad=False,
              draai=0.0, rot=None, u_herhaal=1.0):
        """Draaivorm om de z-as: profiel [(r, z), ...] van onder naar boven. Een
        r van 0 wordt een punt. `boven`/`onder` = stofje voor de deksels (None
        = open). u loopt `u_herhaal` keer rond, v van onder naar boven."""
        bm = self.bm
        ringen = []
        for (r, z) in profiel:
            if r <= 1e-6:
                ringen.append([bm.verts.new(Vector((0.0, 0.0, z)))])
            else:
                ring = []
                for j in range(segs):
                    a = 2 * math.pi * j / segs + draai
                    ring.append(bm.verts.new(Vector((r * math.cos(a), r * math.sin(a), z))))
                ringen.append(ring)
        # v-parameter: cumulatieve lengte langs het profiel
        lengte = [0.0]
        for i in range(1, len(profiel)):
            dr = profiel[i][0] - profiel[i - 1][0]
            dz = profiel[i][1] - profiel[i - 1][1]
            lengte.append(lengte[-1] + math.hypot(dr, dz))
        tot = max(lengte[-1], 1e-6)
        faces = []
        for i in range(len(ringen) - 1):
            r0, r1 = ringen[i], ringen[i + 1]
            v0, v1 = lengte[i] / tot, lengte[i + 1] / tot
            for j in range(segs):
                j1 = (j + 1) % segs
                u0, u1 = j / segs * u_herhaal, (j + 1) / segs * u_herhaal
                if len(r0) == 1 and len(r1) == 1:
                    continue
                if len(r0) == 1:
                    f = bm.faces.new((r0[0], r1[j1], r1[j]))
                    uvs = [(0.5 * (u0 + u1), v0), (u1, v1), (u0, v1)]
                elif len(r1) == 1:
                    f = bm.faces.new((r0[j], r0[j1], r1[0]))
                    uvs = [(u0, v0), (u1, v0), (0.5 * (u0 + u1), v1)]
                else:
                    f = bm.faces.new((r0[j], r0[j1], r1[j1], r1[j]))
                    uvs = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
                for lp, (u, v) in zip(f.loops, uvs):
                    lp[self.uv].uv = self._vak(swatch, u % 1.0 if u_herhaal != 1.0 else u, v)
                faces.append(f)
        deksels = []
        if boven is not None and len(ringen[-1]) > 1:
            f = bm.faces.new(ringen[-1])
            deksels.append((f, boven))
        if onder is not None and len(ringen[0]) > 1:
            f = bm.faces.new(list(reversed(ringen[0])))
            deksels.append((f, onder))
        alle = faces + [f for f, _ in deksels]
        m = Matrix.Translation(Vector(pos))
        if rot is not None:
            m = m @ rot
        verts = list({v for f in alle for v in f.verts})
        bmesh.ops.transform(bm, matrix=m, verts=verts)
        for f, sw in deksels:
            f.normal_update()
            self.uv_vlak([f], sw, 2.0)
        if glad:
            self.glad_faces.update(faces)
        return alle

    def cil(self, r, h, pos, segs=8, swatch="hout_licht", boven="kops", onder="kops", rot=None, glad=False, r2=None):
        """Cilinder (of kegelstomp met r2) met de voet op pos."""
        prof = [(r, 0.0), (r2 if r2 is not None else r, h)]
        return self.lathe(prof, pos, segs, swatch, boven, onder, glad, rot=rot)

    def bol(self, r, pos, subdiv=2, swatch="ijzer", glad=False, schaal=(1.0, 1.0, 1.0)):
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=r)
        verts = res["verts"]
        m = Matrix.Translation(Vector(pos)) @ Matrix.Diagonal(Vector(schaal).to_4d())
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        faces = self._faces_van(verts)
        for f in faces:
            for lp in f.loops:
                c = lp.vert.co - Vector(pos)
                lp[self.uv].uv = self._vak(swatch, 0.5 + 0.42 * c.x / (r * schaal[0]), 0.5 + 0.45 * c.z / (r * schaal[2]))
        if glad:
            self.glad_faces.update(faces)
        return faces

    def piramide(self, r, h, pos, richting, swatch="ijzer"):
        """Spijkerkop of punt: vierzijdige piramide zonder bodem, punt langs `richting`."""
        res = bmesh.ops.create_cone(self.bm, cap_ends=False, cap_tris=False, segments=4, radius1=r, radius2=0.0, depth=h)
        verts = res["verts"]
        d = Vector(richting).normalized()
        kw = Vector((0, 0, 1)).rotation_difference(d)
        m = Matrix.Translation(Vector(pos) + d * (h * 0.5)) @ kw.to_matrix().to_4x4() @ Matrix.Rotation(math.pi / 4, 4, "Z")
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        faces = self._faces_van(verts)
        self.uv_vlak(faces, swatch, vast=(0.5, 0.5))
        return faces

    def touw(self, punten, r=0.018, segs=6, swatch="touw", gesloten=False):
        """Een touw: een zeshoek langs een polylijn (open of gesloten)."""
        bm = self.bm
        pts = [Vector(p) for p in punten]
        n = len(pts)
        ringen = []
        lengte = 0.0
        ups = Vector((0, 0, 1))
        for i in range(n):
            if gesloten:
                t = (pts[(i + 1) % n] - pts[(i - 1) % n]).normalized()
            elif i == 0:
                t = (pts[1] - pts[0]).normalized()
            elif i == n - 1:
                t = (pts[-1] - pts[-2]).normalized()
            else:
                t = (pts[i + 1] - pts[i - 1]).normalized()
            hint = ups if abs(t.dot(ups)) < 0.9 else Vector((1, 0, 0))
            n1 = hint.cross(t).normalized()
            n2 = t.cross(n1).normalized()
            ring = [bm.verts.new(pts[i] + r * (n1 * math.cos(2 * math.pi * j / segs) + n2 * math.sin(2 * math.pi * j / segs))) for j in range(segs)]
            ringen.append((ring, lengte))
            if i < n - 1:
                lengte += (pts[i + 1] - pts[i]).length
        if gesloten:
            lengte += (pts[0] - pts[-1]).length
        faces = []
        paren = list(range(n - 1)) + ([n - 1] if gesloten else [])
        for i in paren:
            r0, l0 = ringen[i]
            r1, l1 = ringen[(i + 1) % n]
            if gesloten and i == n - 1:
                l1 = lengte
            for j in range(segs):
                j1 = (j + 1) % segs
                f = bm.faces.new((r0[j], r0[j1], r1[j1], r1[j]))
                u0, u1 = (l0 / lengte) * 0.98, (l1 / lengte) * 0.98
                v0, v1 = j / segs, (j + 1) / segs
                for lp, (u, v) in zip(f.loops, [(u0, v0), (u0, v1), (u1, v1), (u1, v0)]):
                    lp[self.uv].uv = self._vak(swatch, u, v)
                faces.append(f)
        return faces

    def cirkel_punten(self, R, z, n=16, cx=0.0, cy=0.0, ruis=0.0):
        return [(cx + (R + self.rng.uniform(-ruis, ruis)) * math.cos(2 * math.pi * j / n),
                 cy + (R + self.rng.uniform(-ruis, ruis)) * math.sin(2 * math.pi * j / n), z) for j in range(n)]

    def doek(self, breedte, hoogte, pos, rot=None, swatch="linnen_wit", nx=2, ny=4, buik=0.0, zoom=0.0):
        """Een lap: raster in het xz-vlak (voorkant -y), met een buik naar -y en
        een golvende zoom; tweezijdig."""
        bm = self.bm
        grid = []
        for iy in range(ny + 1):
            rij = []
            fy = iy / ny
            for ix in range(nx + 1):
                fx = ix / nx
                x = (fx - 0.5) * breedte
                z = (1.0 - fy) * hoogte
                y = -buik * math.sin(fy * math.pi) - zoom * 0.5 * (1 - math.cos(fx * 2 * math.pi)) * fy
                rij.append(bm.verts.new(Vector((x, y, z))))
            grid.append(rij)
        faces = []
        for iy in range(ny):
            for ix in range(nx):
                f = bm.faces.new((grid[iy][ix], grid[iy + 1][ix], grid[iy + 1][ix + 1], grid[iy][ix + 1]))
                for lp, (fx, fy) in zip(f.loops, [(ix / nx, 1 - iy / ny), (ix / nx, 1 - (iy + 1) / ny), ((ix + 1) / nx, 1 - (iy + 1) / ny), ((ix + 1) / nx, 1 - iy / ny)]):
                    lp[self.uv].uv = self._vak(swatch, fx, fy)
                faces.append(f)
        m = Matrix.Translation(Vector(pos))
        if rot is not None:
            m = m @ rot
        bmesh.ops.transform(bm, matrix=m, verts=list({v for f in faces for v in f.verts}))
        self.dubbelzijdig = True
        self.glad_faces.update(faces)
        return faces

    def verplaats(self, faces, m):
        bmesh.ops.transform(self.bm, matrix=m, verts=list({v for f in faces for v in f.verts}))

    # --- afronden -----------------------------------------------------------
    def klaar(self, naam, ruwheid=0.85):
        bm = self.bm
        bm.normal_update()
        me = bpy.data.meshes.new(naam)
        glad_idx = set()
        for i, f in enumerate(bm.faces):
            if f in self.glad_faces:
                glad_idx.add(i)
        bm.faces.ensure_lookup_table()
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = p.index in glad_idx
        ob = bpy.data.objects.new(naam, me)
        bpy.context.scene.collection.objects.link(ob)
        mat = bpy.data.materials.new(naam)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Roughness"].default_value = ruwheid
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = self.atlas
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        mat.use_backface_culling = not self.dubbelzijdig
        me.materials.append(mat)
        me.calc_loop_triangles()
        return ob


def exporteer(ob, pad):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=pad, export_format="GLB", use_selection=True,
                              export_image_format="AUTO", export_apply=True, export_yup=True)


def rot_x(graden):
    return Matrix.Rotation(math.radians(graden), 4, "X")


def rot_y(graden):
    return Matrix.Rotation(math.radians(graden), 4, "Y")


def rot_z(graden):
    return Matrix.Rotation(math.radians(graden), 4, "Z")
