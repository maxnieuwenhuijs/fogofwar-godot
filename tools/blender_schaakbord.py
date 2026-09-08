# Bouw een LOW-POLY schaakbord in de stijl van een oud houten bord: donker
# walnoot-frame, ronde hoeken, een kleine afronding op de bovenrand, en een
# speelveld van losse licht/donker ingelegde stukjes met dunne zwarte lijnen
# ertussen. Alles wat "hout" is zit in EEN textuur; de geometrie is een
# afgeronde plank van een paar honderd driehoeken.
#
#   blender --background --python tools/blender_schaakbord.py -- \
#       --uit assets/models/board/schaakbord/schaakbord.glb [--vakken 8] [--vak 1.0]
#       [--rand 0.55] [--dikte 0.28] [--hoek 0.5] [--hoeksegmenten 4]
#       [--afronding 0.07] [--afrondsegmenten 3] [--textuur 2048] [--seed 7]
#       [--zonder-onderkant] [--oorsprong onder|boven] [--preview <png>]
#       [--geen-preview] [--geen-blend]
#
# Wat er uit komt, naast elkaar (zelfde basisnaam als --uit):
#   <naam>.glb          het bord, Y-up, een materiaal, een mesh; de textuur zit
#                       er standaard NIET in (--textuur-ingebakken wel)
#   <naam>.png          de textuur (albedo, sRGB): het spel legt hem via een
#                       material_override op het bord, en dit is het bestand
#                       dat je vervangt bij een retexture
#   bron/<naam>.blend   het Blender-bestand (textuur niet ingepakt, wijst naar de
#                       png); bron/ krijgt een .gdignore, want Godot wil elke
#                       .blend zelf importeren en struikelt zonder Blender-pad
#   preview             een render zoals de foto (standaard results/schaakbord/)
#
# Waarom zo weinig faces: de bovenkant is EEN n-gon met een plat UV-projectie
# van de textuur; de zijwand en de afronding projecteren dezelfde textuur
# (van boven af naar binnen gevouwen), dus ze bemonsteren het frame-hout en er
# is nergens een naad. Onderkant = een piepklein donker stukje van het frame.
# Driehoeken: caps 2*(M-2) + stroken (afrondsegmenten+1)*M*2 met
# M = 4*(hoeksegmenten+1). Standaard 196, tegen 930 voor het Tripo-bord.
#
# Het spelbord van Fog of War is 11x11 met vakken van 1 eenheid:
#   --vakken 11 --vak 1.0   (dan is de plank 11 + 2*rand eenheden breed)
import bpy
import bmesh
import math
import os
import sys
import time

import numpy as np
from mathutils import Vector

# ---------------------------------------------------------------- argumenten
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def _arg(naam, default, cast=float):
    if naam in argv:
        i = argv.index(naam)
        if i + 1 < len(argv):
            return cast(argv[i + 1])
    return default


uit = _arg("--uit", None, str)
if not uit:
    print("FOUT: geef --uit <pad.glb> mee")
    sys.exit(1)
N = _arg("--vakken", 8, int)               # vakken per zijde
VAK = _arg("--vak", 1.0)                   # grootte van een vak (eenheden)
RAND = _arg("--rand", 0.55)                # breedte van het frame rond het speelveld
DIKTE = _arg("--dikte", 0.28)              # dikte van de plank
HOEK = _arg("--hoek", 0.5)                 # straal van de ronde hoeken (0 = scherp)
HOEKSEG = _arg("--hoeksegmenten", 4, int)  # segmenten per ronde hoek
AFR = _arg("--afronding", 0.07)            # afronding van de bovenrand (0 = uit)
AFRSEG = _arg("--afrondsegmenten", 3, int)  # segmenten in die afronding
TEX = _arg("--textuur", 2048, int)         # textuurgrootte in pixels (vierkant)
SEED = _arg("--seed", 7, int)
ZONDER_ONDERKANT = "--zonder-onderkant" in argv
OORSPRONG = _arg("--oorsprong", "onder", str)   # onder = staat op tafel, boven = speelvlak op z=0
PREVIEW = _arg("--preview", None, str)
GEEN_PREVIEW = "--geen-preview" in argv
GEEN_BLEND = "--geen-blend" in argv
# Standaard blijft de textuur LOS naast de glb (de glb is dan ~60 KB): het spel
# legt hem er via een material_override in Board.tscn op, en Godot trekt een
# ingebakken plaatje anders als <glb>_<naam>.png ernaast (een tweede kopie
# van 3 MB in git). Voor een upload naar een retexture-dienst of een viewer
# die het plaatje in de glb wil: --textuur-ingebakken.
TEXTUUR_INGEBAKKEN = "--textuur-ingebakken" in argv

if HOEK <= 0.0:
    HOEK = 0.0
    HOEKSEG = 0
if AFR > HOEK and HOEK > 0.0:
    print("LET OP: afronding %.3f groter dan hoekstraal %.3f, afronding verkleind" % (AFR, HOEK))
    AFR = HOEK
if HOEK == 0.0 and AFR > 0.0:
    print("LET OP: scherpe hoeken (--hoek 0) kunnen geen afronding dragen, afronding uit")
    AFR = 0.0
if AFR <= 0.0:
    AFR = 0.0
    AFRSEG = 0

S = N * VAK + 2.0 * RAND       # breedte van de hele plank
uit = os.path.abspath(uit)
basis, _ = os.path.splitext(uit)
naam = os.path.basename(basis)
os.makedirs(os.path.dirname(uit), exist_ok=True)
if PREVIEW is None and not GEEN_PREVIEW:
    PREVIEW = os.path.join(os.getcwd(), "results", "schaakbord", naam + "_preview.png")

t0 = time.time()
print("SCHAAKBORD: %dx%d vakken van %.2f, frame %.2f, plank %.2f x %.2f x %.2f, hoek %.2f/%d, afronding %.3f/%d, textuur %d, seed %d"
      % (N, N, VAK, RAND, S, S, DIKTE, HOEK, HOEKSEG, AFR, AFRSEG, TEX, SEED))

# ---------------------------------------------------------------- textuur
# Alles in sRGB 0..255, rechtstreeks in de bytes van het plaatje. Rij 0 is
# de onderkant van het plaatje (Blender-buffers zijn bottom-up), dus rij = y.


def _hash01(ix, iy, seed):
    """Deterministische pseudo-random waarde 0..1 per roosterpunt."""
    h = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263
         + np.int64(seed) * 1013904223) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return ((h & 0xFFFFFF).astype(np.float32)) / np.float32(0xFFFFFF)


def _waardenoise(x, y, cel, seed):
    xs = x / cel
    ys = y / cel
    xi = np.floor(xs)
    yi = np.floor(ys)
    fx = (xs - xi).astype(np.float32)
    fy = (ys - yi).astype(np.float32)
    ux = fx * fx * (3.0 - 2.0 * fx)
    uy = fy * fy * (3.0 - 2.0 * fy)
    xi = xi.astype(np.int64)
    yi = yi.astype(np.int64)
    a = _hash01(xi, yi, seed)
    b = _hash01(xi + 1, yi, seed)
    c = _hash01(xi, yi + 1, seed)
    d = _hash01(xi + 1, yi + 1, seed)
    return (a + (b - a) * ux) + ((c + (d - c) * ux) - (a + (b - a) * ux)) * uy


def fbm(x, y, cel_x, cel_y, octaven, seed):
    """Fractale ruis, 0..1, met een eigen celmaat per as (anisotroop hout)."""
    tot = np.zeros(x.shape, np.float32)
    amp = 1.0
    som = 0.0
    for o in range(octaven):
        # per octaaf een andere schaal per as; aparte seed per octaaf
        n = _waardenoise(x / cel_x, y / cel_y, 1.0 / (2.0 ** o), seed * 131 + o * 17)
        tot += amp * n
        som += amp
        amp *= 0.5
    return tot / som


def bouw_textuur(T, rng):
    ppu = T / S                        # pixels per eenheid
    px = 1.0 / ppu                     # een pixel in eenheden
    kol = (np.arange(T, dtype=np.float32) + 0.5) / ppu
    x = np.broadcast_to(kol[None, :], (T, T))
    y = np.broadcast_to(kol[:, None], (T, T))

    # --- welk stukje hout is dit (elk vak = eigen stukje, frame = 4 latten)
    in_speelveld = (x >= RAND) & (x < S - RAND) & (y >= RAND) & (y < S - RAND)
    i = np.clip(np.floor((x - RAND) / VAK), 0, N - 1).astype(np.int64)
    j = np.clip(np.floor((y - RAND) / VAK), 0, N - 1).astype(np.int64)
    afst = np.stack([y, S - x, S - y, x], axis=0)         # onder, rechts, boven, links
    lat = np.argmin(afst, axis=0).astype(np.int64)         # verstek-verdeling van het frame
    stuk = np.where(in_speelveld, j * N + i, N * N + lat)
    licht = in_speelveld & (((i + j) % 2) == 1)            # linksonder is donker, zoals bij schaken
    soort = np.where(in_speelveld, np.where(licht, 0, 1), 2)  # 0 licht, 1 donker, 2 frame

    # per stukje: nerfrichting (0 of 90 graden, plus een paar graden scheef),
    # een eigen verschuiving in de ruis en een eigen nerfdichtheid
    aantal = N * N + 4
    hoek = rng.integers(0, 2, size=aantal) * (np.pi / 2) + np.radians(rng.uniform(-6.0, 6.0, size=aantal))
    hoek[N * N + 0] = 0.0          # onder/boven: nerf langs de x-as
    hoek[N * N + 2] = 0.0
    hoek[N * N + 1] = np.pi / 2    # links/rechts: nerf langs de y-as
    hoek[N * N + 3] = np.pi / 2
    ca = np.cos(hoek).astype(np.float32)[stuk]
    sa = np.sin(hoek).astype(np.float32)[stuk]
    off_x = rng.uniform(0.0, 40.0, size=aantal).astype(np.float32)
    off_y = rng.uniform(0.0, 40.0, size=aantal).astype(np.float32)
    ringf = rng.uniform(0.75, 1.3, size=aantal).astype(np.float32)
    xl = ca * x + sa * y + off_x[stuk]         # langs de nerf
    yl = (-sa * x + ca * y + off_y[stuk]) * ringf[stuk]   # dwars op de nerf

    # --- de nerf: jaarringen als zaagtand (zacht oplopend, dan een scherpe
    # rand), golvend door ruis op twee schalen; dwars op de nerf dicht opeen
    n1 = fbm(xl, yl, 3.0 * VAK, 0.55 * VAK, 4, SEED + 1)           # lange golven
    n1b = fbm(xl, yl, 0.5 * VAK, 0.12 * VAK, 2, SEED + 6)          # korte wiebel
    ring = yl * (5.5 / VAK) + (n1 - 0.5) * 3.2 + (n1b - 0.5) * 0.5
    t = ring - np.floor(ring)
    band = np.clip((t - 0.55) / 0.40, 0.0, 1.0)
    band = band * band * (3.0 - 2.0 * band)                         # smoothstep
    n2 = fbm(xl, yl, 1.2 * VAK, 0.035 * VAK, 2, SEED + 2)          # fijne streepjes / porien
    n3 = fbm(xl, yl, 1.1 * VAK, 0.8 * VAK, 3, SEED + 3)            # vlammen / kleurvlekken
    # dunne tussenringen: het fijne lijnenspel tussen de brede banden
    ring2 = yl * (16.0 / VAK) + (n1 - 0.5) * 3.2 + (n1b - 0.5) * 0.8
    t2 = ring2 - np.floor(ring2)
    band2 = np.clip((t2 - 0.6) / 0.35, 0.0, 1.0)
    g = (1.0 - 0.55 * band) * (1.0 - 0.14 * band2) * (0.92 + 0.14 * n2) * (0.88 + 0.22 * n3)
    porien = np.clip((n2 - 0.68) / 0.14, 0.0, 1.0) * 0.14           # donkere porien langs de nerf

    # kleuren per houtsoort (sRGB, uit de foto): lo = in de ring, hi = ertussen
    lo = np.array([[152, 114, 74], [56, 36, 22], [62, 38, 24]], np.float32)
    hi = np.array([[208, 172, 124], [122, 88, 58], [130, 90, 60]], np.float32)
    kleur = lo[soort] + (hi[soort] - lo[soort]) * np.clip(g, 0.0, 1.0)[..., None]
    kleur = kleur * (1.0 - porien)[..., None]

    # --- de lijnen: dun zwart tussen de vakken, iets dikker om het speelveld
    tx = (x - RAND) / VAK
    ty = (y - RAND) / VAK
    fx = tx - np.floor(tx)
    fy = ty - np.floor(ty)
    d_in = np.minimum(np.minimum(fx, 1.0 - fx), np.minimum(fy, 1.0 - fy)) * VAK
    d_in = np.where(in_speelveld, d_in, np.float32(1e9))
    # echte afstand tot de rand van het speelveld-vierkant (NIET de lijnen
    # doorgetrokken tot de rand van de plank)
    dx_uit = np.maximum(np.maximum(RAND - x, x - (S - RAND)), 0.0)
    dy_uit = np.maximum(np.maximum(RAND - y, y - (S - RAND)), 0.0)
    d_buiten = np.sqrt(dx_uit * dx_uit + dy_uit * dy_uit)
    d_binnen = np.minimum(np.minimum(x - RAND, (S - RAND) - x), np.minimum(y - RAND, (S - RAND) - y))
    d_uit = np.where(in_speelveld, d_binnen, d_buiten)
    w_in = max(0.022 * VAK, 1.6 * px)
    w_uit = max(0.036 * VAK, 2.2 * px)
    a_in = np.clip((w_in / 2 - d_in) / px + 0.5, 0.0, 1.0)
    a_uit = np.clip((w_uit / 2 - d_uit) / px + 0.5, 0.0, 1.0)
    a_lijn = np.maximum(a_in, a_uit)

    # groefschaduw: het hout loopt heel licht donker naar de lijn toe (ingelegd)
    schaduw = (np.exp(-np.maximum(d_in - w_in / 2, 0.0) / (0.02 * VAK)) * 0.16
               + np.exp(-np.maximum(d_uit - w_uit / 2, 0.0) / (0.025 * VAK)) * 0.16)
    kleur = kleur * (1.0 - np.clip(schaduw, 0.0, 0.3))[..., None]

    # dun licht biesje (ahorn) net buiten de zwarte lijn om het speelveld
    bies_d = d_uit - w_uit / 2
    bies = np.clip((bies_d - 0.02 * VAK) / px + 0.5, 0, 1) * np.clip((0.045 * VAK - bies_d) / px + 0.5, 0, 1)
    bies = bies * (~in_speelveld)
    bies_kleur = np.array([190, 156, 110], np.float32)
    kleur = kleur + (bies_kleur - kleur) * (0.7 * bies)[..., None]

    # --- slijtage: vuil in vlekken, een handjevol spikkels, krassen
    vuil = fbm(x, y, 1.6 * VAK, 1.6 * VAK, 3, SEED + 4)
    kleur = kleur * (0.88 + 0.16 * vuil)[..., None]
    spik = fbm(x, y, 0.02 * VAK, 0.02 * VAK, 2, SEED + 5)
    spik = np.clip((spik - 0.84) / 0.06, 0.0, 1.0)
    kleur = kleur * (1.0 - 0.22 * spik)[..., None]

    kras_n = int(round(40 * (N * VAK / 8.0) ** 2))
    for _ in range(kras_n):
        cx, cy = rng.uniform(0.0, S, size=2)
        richting = rng.uniform(0.0, np.pi)
        lengte = rng.uniform(0.15, 0.9) * VAK
        breed = rng.uniform(0.6, 1.4) * px
        alpha = rng.uniform(0.2, 0.5)
        dx, dy = math.cos(richting) * lengte / 2, math.sin(richting) * lengte / 2
        x0, y0, x1, y1 = cx - dx, cy - dy, cx + dx, cy + dy
        c0 = max(int((min(x0, x1) - 2 * px) * ppu), 0)
        c1 = min(int((max(x0, x1) + 2 * px) * ppu) + 1, T)
        r0 = max(int((min(y0, y1) - 2 * px) * ppu), 0)
        r1 = min(int((max(y0, y1) + 2 * px) * ppu) + 1, T)
        if c1 <= c0 or r1 <= r0:
            continue
        wx = x[r0:r1, c0:c1]
        wy = y[r0:r1, c0:c1]
        vx, vy = x1 - x0, y1 - y0
        ll = vx * vx + vy * vy
        tt = np.clip(((wx - x0) * vx + (wy - y0) * vy) / ll, 0.0, 1.0)
        dist = np.sqrt((wx - (x0 + tt * vx)) ** 2 + (wy - (y0 + tt * vy)) ** 2)
        a = np.clip((breed / 2 - dist) / px + 0.5, 0.0, 1.0) * alpha
        w = kleur[r0:r1, c0:c1]
        doel = np.minimum(w * 1.4 + 22.0, 255.0)
        kleur[r0:r1, c0:c1] = w + (doel - w) * a[..., None]

    # zwarte lijnen er als laatste overheen (die zijn niet gekrast)
    lijn_kleur = np.array([26, 19, 13], np.float32)
    kleur = kleur + (lijn_kleur - kleur) * a_lijn[..., None]
    return np.clip(kleur, 0.0, 255.0)


rng = np.random.default_rng(SEED)
tex = bouw_textuur(TEX, rng)
print("textuur %dx%d gebouwd in %.1fs" % (TEX, TEX, time.time() - t0))
# canary: een zwart of NaN-plaatje is een fout in de generator, niet in Blender
nan_n = int(np.isnan(tex).sum())
print("textuur-stats: min %.1f max %.1f gemiddeld %.1f nan %d" % (np.nanmin(tex), np.nanmax(tex), np.nanmean(tex), nan_n))
if nan_n > 0 or np.nanmax(tex) < 40.0:
    print("FOUT: textuur is leeg of bevat NaN, zie stats hierboven")
    sys.exit(1)

# ---------------------------------------------------------------- scene leeg
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

img = bpy.data.images.new(naam, TEX, TEX, alpha=False)
rgba = np.empty((TEX, TEX, 4), np.float32)
rgba[..., :3] = tex / 255.0
rgba[..., 3] = 1.0
img.pixels.foreach_set(rgba.ravel())
# LET OP: raak hierna img.colorspace_settings NIET aan: die toekenning gooit
# de buffer van een "generated" plaatje weg en je bewaart een zwart vlak
# (gemeten in Blender 5.1.2). sRGB is toch al de standaard.
img.filepath_raw = basis + ".png"
img.file_format = "PNG"
img.save()
# vanaf hier is de png de bron (anders bewaart de .blend een "generated"
# plaatje en staat er na heropenen een leeg vlak)
img.filepath = basis + ".png"
img.source = "FILE"
img.reload()
terug = np.empty(TEX * TEX * 4, np.float32)
img.pixels.foreach_get(terug)
print("png -> %s (teruggelezen: min %.3f max %.3f gemiddeld %.3f)" % (img.filepath_raw, terug.min(), terug.max(), terug[0::4].mean()))

# ---------------------------------------------------------------- geometrie


def omtrek(inzet):
    """Punten van de afgeronde rechthoek, `inzet` naar binnen, tegen de klok in
    vanaf linksonder. Per hoek HOEKSEG+1 punten (bij hoek 0 precies een)."""
    r = HOEK - inzet
    centra = [(HOEK, HOEK, math.pi), (S - HOEK, HOEK, 1.5 * math.pi),
              (S - HOEK, S - HOEK, 0.0), (HOEK, S - HOEK, 0.5 * math.pi)]
    pts = []
    for cx, cy, a0 in centra:
        if HOEKSEG == 0:
            # scherpe hoek: het punt ligt inzet naar binnen langs de diagonaal
            sx = 1.0 if cx < S / 2 else -1.0
            sy = 1.0 if cy < S / 2 else -1.0
            pts.append((cx + sx * inzet, cy + sy * inzet))
            continue
        for k in range(HOEKSEG + 1):
            a = a0 + (math.pi / 2) * k / HOEKSEG
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# ringen van boven naar beneden: (inzet, z)
profiel = [(AFR, DIKTE)]
for k in range(1, AFRSEG + 1):
    th = (math.pi / 2) * k / AFRSEG
    profiel.append((AFR * (1.0 - math.sin(th)), DIKTE - AFR * (1.0 - math.cos(th))))
if AFRSEG == 0:
    profiel = [(0.0, DIKTE)]
profiel.append((0.0, 0.0))

bm = bmesh.new()
uv_lay = bm.loops.layers.uv.new("UVMap")
z_off = -DIKTE if OORSPRONG == "boven" else 0.0
ringen = []
ring_uv = []
for inzet, z in profiel:
    pts = omtrek(inzet)
    verts = [bm.verts.new((px_ - S / 2, py_ - S / 2, z + z_off)) for px_, py_ in pts]
    ringen.append(verts)
    ring_uv.append([(px_ / S, py_ / S) for px_, py_ in pts])
M = len(ringen[0])

# de zijwand (laatste strook) projecteert naar binnen: onderaan de wand zit
# de UV `wand-hoogte` naar binnen, zodat hij het frame-hout bemonstert
buiten = omtrek(0.0)
wand_h = profiel[-2][1] - 0.0
wand_uv_onder = []
for k, (px_, py_) in enumerate(buiten):
    # binnenwaartse richting: naar het hoekcentrum, of loodrecht op de zijde
    if HOEKSEG == 0:
        nx = (1.0 if px_ < S / 2 else -1.0) / math.sqrt(2)
        ny = (1.0 if py_ < S / 2 else -1.0) / math.sqrt(2)
    else:
        hoek_i = k // (HOEKSEG + 1)
        cx, cy = [(HOEK, HOEK), (S - HOEK, HOEK), (S - HOEK, S - HOEK), (HOEK, S - HOEK)][hoek_i]
        nx, ny = cx - px_, cy - py_
        l = math.hypot(nx, ny) or 1.0
        nx, ny = nx / l, ny / l
    wand_uv_onder.append(((px_ + nx * wand_h) / S, (py_ + ny * wand_h) / S))
ring_uv[-1] = wand_uv_onder

faces_strook = []
for r in range(len(ringen) - 1):
    boven, onder = ringen[r], ringen[r + 1]
    uvb, uvo = ring_uv[r], ring_uv[r + 1]
    for k in range(M):
        k2 = (k + 1) % M
        f = bm.faces.new((boven[k], boven[k2], onder[k2], onder[k]))
        f.smooth = True
        uvs = (uvb[k], uvb[k2], uvo[k2], uvo[k])
        for loop, uv in zip(f.loops, uvs):
            loop[uv_lay].uv = uv
        faces_strook.append(f)

top = bm.faces.new(ringen[0])
top.smooth = False
for loop, uv in zip(top.loops, ring_uv[0]):
    loop[uv_lay].uv = uv

if not ZONDER_ONDERKANT:
    bodem = bm.faces.new(list(reversed(ringen[-1])))
    bodem.smooth = False
    # piepklein stukje van de onderste frame-lat: gewoon donker hout
    schaal = (RAND * 0.6) / S
    for loop in bodem.loops:
        v = loop.vert.co
        u = (S / 2 + (v.x) * schaal) / S
        w = (RAND * 0.5 + (v.y) * schaal) / S
        loop[uv_lay].uv = (u, w)

# scherpe randen: de rand van het bovenvlak en de onderrand; de rest vloeit
ring0 = set(ringen[0])
ringl = set(ringen[-1])
for e in bm.edges:
    a, b = e.verts
    if (a in ring0 and b in ring0) or (a in ringl and b in ringl):
        e.smooth = False
    else:
        e.smooth = True

bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new(naam)
bm.to_mesh(me)
bm.free()
me.update()
me.validate(verbose=False)

obj = bpy.data.objects.new(naam, me)
scene.collection.objects.link(obj)

# ---------------------------------------------------------------- materiaal
mat = bpy.data.materials.new(naam)
mat.use_nodes = True
nodes = mat.node_tree.nodes
links = mat.node_tree.links
bsdf = nodes.get("Principled BSDF")
texn = nodes.new("ShaderNodeTexImage")
texn.image = img
texn.interpolation = "Linear"
texn.location = (-400, 200)
links.new(texn.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.55
if "Specular IOR Level" in bsdf.inputs:
    bsdf.inputs["Specular IOR Level"].default_value = 0.35
me.materials.append(mat)

tris = sum(len(p.vertices) - 2 for p in me.polygons)
print("mesh: %d vertices, %d faces, %d driehoeken, %d materialen" % (len(me.vertices), len(me.polygons), tris, len(me.materials)))

# ---------------------------------------------------------------- export
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.export_scene.gltf(
    filepath=uit, export_format="GLB", use_selection=True,
    export_apply=True, export_yup=True, export_texcoords=True,
    export_normals=True, export_materials="EXPORT",
    export_image_format=("AUTO" if TEXTUUR_INGEBAKKEN else "NONE"),
    export_animations=False, export_skins=False, export_morph=False,
    export_lights=False, export_cameras=False,
)
print("glb -> %s (%.2f MB, textuur %s)" % (uit, os.path.getsize(uit) / 1e6,
      "ingebakken" if TEXTUUR_INGEBAKKEN else "los in " + os.path.basename(basis) + ".png"))

# ---------------------------------------------------------------- preview
if not GEEN_PREVIEW:
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    # previews onder results/ zijn geen spel-assets: Godot moet ze niet importeren
    results_map = os.path.join(os.getcwd(), "results")
    if os.path.abspath(PREVIEW).startswith(os.path.abspath(results_map)):
        with open(os.path.join(os.path.dirname(PREVIEW), ".gdignore"), "w") as f:
            f.write("")
    cam_data = bpy.data.cameras.new("Camera")
    cam_data.lens = 55.0
    cam = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam)
    doel = Vector((0.0, 0.0, z_off + DIKTE * 0.5))
    cam.location = Vector((0.12 * S, -1.42 * S, 1.02 * S))
    cam.rotation_euler = (doel - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    zon_data = bpy.data.lights.new("Zon", "SUN")
    zon_data.energy = 3.2
    zon_data.angle = math.radians(12.0)
    zon = bpy.data.objects.new("Zon", zon_data)
    scene.collection.objects.link(zon)
    zon.location = Vector((0.6 * S, -0.5 * S, 1.6 * S))
    zon.rotation_euler = (Vector((0, 0, 0)) - zon.location).to_track_quat("-Z", "Y").to_euler()

    world = bpy.data.worlds.new("Wereld")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg is not None:
        bg.inputs["Color"].default_value = (0.42, 0.42, 0.42, 1.0)
        bg.inputs["Strength"].default_value = 1.0
    scene.world = world

    # een grijs tafelblad zoals in de foto
    vloer_me = bpy.data.meshes.new("Vloer")
    vb = bmesh.new()
    bmesh.ops.create_grid(vb, x_segments=1, y_segments=1, size=S * 4)
    vb.to_mesh(vloer_me)
    vb.free()
    vloer = bpy.data.objects.new("Vloer", vloer_me)
    vloer.location = Vector((0.0, 0.0, z_off - 0.001))
    scene.collection.objects.link(vloer)
    vmat = bpy.data.materials.new("Vloer")
    vmat.use_nodes = True
    vb_bsdf = vmat.node_tree.nodes.get("Principled BSDF")
    vb_bsdf.inputs["Base Color"].default_value = (0.36, 0.36, 0.36, 1.0)
    vb_bsdf.inputs["Roughness"].default_value = 0.9
    vloer_me.materials.append(vmat)

    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.filepath = PREVIEW
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    keus = [e for e in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE") if e in engines]
    gerenderd = False
    for eng in keus:
        try:
            scene.render.engine = eng
            if hasattr(scene, "eevee"):
                scene.eevee.taa_render_samples = 48
            bpy.ops.render.render(write_still=True)
            gerenderd = True
            print("preview (%s) -> %s" % (eng, PREVIEW))
            break
        except Exception as e:  # noqa: BLE001
            print("preview met %s mislukt: %s" % (eng, e))
    if not gerenderd:
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "TEXTURE"
        bpy.ops.render.render(write_still=True)
        print("preview (workbench) -> %s" % PREVIEW)
    # de preview-hulpjes horen niet in de .blend
    for o in (cam, zon, vloer):
        bpy.data.objects.remove(o, do_unlink=True)

if not GEEN_BLEND:
    # Het .blend gaat in een submap bron/ met een .gdignore: Godot probeert
    # elke .blend onder res:// door zijn eigen Blender-importer te halen, en
    # zonder ingesteld Blender-pad breekt dat de HELE import-run (er komt dan
    # ook voor de glb en de png geen .import-bestand). Zelfde afspraak als
    # "assets/new upload folder/".
    bron = os.path.join(os.path.dirname(uit), "bron")
    os.makedirs(bron, exist_ok=True)
    with open(os.path.join(bron, ".gdignore"), "w") as f:
        f.write("")
    blend = os.path.join(bron, naam + ".blend")
    img.filepath = basis + ".png"
    # geen <naam>.blend1-backup bij overschrijven (die hoort niet in git)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True, relative_remap=True)
    for oud in (blend + "1", blend + "2"):
        if os.path.exists(oud):
            os.remove(oud)
    print("blend -> %s (%.1f MB, textuur via %s)" % (blend, os.path.getsize(blend) / 1e6, img.filepath))

print("KLAAR in %.1fs: %d driehoeken, textuur %dx%d" % (time.time() - t0, tris, TEX, TEX))
