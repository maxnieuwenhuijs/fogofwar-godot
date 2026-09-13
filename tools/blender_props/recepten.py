"""De recepten: elke prop uit de 56 voorbeelden van Max (13 september) als
functie op een Bouwer. RECEPTEN: naam -> (functie, batch). Maten in
bord-eenheden, voeten op z = 0, voorkant naar -y (glTF +Z). Zie bouwstenen.py.

Batch 1: hout en ijzer (kruitvat, kogels, houtstapel, houtblok, takkenbos,
hakblok, zaag, axe, touwrol, barrel, barrel_red, bierton_red, emmer,
emmer_red, kist, kist_red, lantaarn, fakkel, aambeeld, blaasbalg, werkbank, put).
"""
import math

from mathutils import Matrix, Vector

from bouwstenen import rot_x, rot_y, rot_z


def _straal(prof, z):
    """Straal van een profiel op hoogte z (lineair)."""
    for i in range(1, len(prof)):
        (r0, z0), (r1, z1) = prof[i - 1], prof[i]
        if z0 <= z <= z1:
            t = (z - z0) / max(z1 - z0, 1e-9)
            return r0 + (r1 - r0) * t
    return prof[-1][0]


def _band(b, prof, z, dikte=0.05, swatch="ijzer", extra=0.012, segs=12, pos=(0, 0, 0)):
    r = _straal(prof, z) + extra
    return b.lathe([(r, z - dikte / 2), (r, z + dikte / 2)], pos, segs, swatch)


def _binnenwand(b, prof, swatch, dikte=0.015, segs=12, pos=(0, 0, 0), bodem=None):
    """De binnenkant van een open vorm: hetzelfde profiel iets kleiner, van
    boven naar beneden (normalen naar binnen); `bodem` = stofje van de vloer."""
    binnen = [(max(r - dikte, 0.001), z) for (r, z) in reversed(prof)]
    return b.lathe(binnen, pos, segs, swatch, boven=bodem, onder=None)


def _richting_rot(d):
    return Vector((0, 0, 1)).rotation_difference(Vector(d).normalized()).to_matrix().to_4x4()


def _boogpunten(a, bpt, n=7, hoogte=0.1):
    """Punten van a naar b met een boog omhoog (voor touwgrepen)."""
    a, bpt = Vector(a), Vector(bpt)
    uit = []
    for i in range(n + 1):
        t = i / n
        p = a.lerp(bpt, t)
        p.z += hoogte * math.sin(t * math.pi)
        uit.append(tuple(p))
    return uit


# ---------------------------------------------------------------- batch 1: hout en ijzer

def kruitvat(b):
    prof = [(0.13, 0.0), (0.147, 0.07), (0.16, 0.2), (0.147, 0.33), (0.13, 0.4)]
    b.lathe(prof, (0, 0, 0), 12, "duigen_licht", boven="hout_licht", onder="hout_licht")
    for z in (0.07, 0.2, 0.33):
        _band(b, prof, z, 0.035, "ijzer")
    b.cil(0.024, 0.045, (0.03, 0.03, 0.4), 8, "hout_donker", boven="hout_donker", onder=None)
    b.touw([(0.03, 0.03, 0.445), (0.05, 0.02, 0.475), (0.05, -0.02, 0.5), (0.02, -0.045, 0.515), (-0.01, -0.04, 0.52)],
           r=0.009, segs=5, swatch="touw")
    b.bol(0.013, (-0.01, -0.04, 0.52), 1, "donker")


def kogels(b):
    r = 0.07
    for laag, n in enumerate((3, 2, 1)):
        dz = laag * r * 1.36
        for i in range(n):
            for j in range(n):
                x = (i - (n - 1) / 2) * 2 * r * 0.98
                y = (j - (n - 1) / 2) * 2 * r * 0.98
                b.bol(r, (x, y, r + dz), 2, "ijzer")


def _stam(b, lengte, r, pos, langs, swatch="schors", segs=8):
    """Een stam met kopse kanten; `langs` = 'x' of 'y', pos = het midden."""
    if langs == "x":
        rot = rot_y(90)
        voet = (pos[0] - lengte / 2, pos[1], pos[2])
    else:
        rot = rot_x(-90)
        voet = (pos[0], pos[1] - lengte / 2, pos[2])
    return b.cil(r, lengte, voet, segs, swatch, boven="kops", onder="kops", rot=rot)


def houtstapel(b):
    r = 0.055
    for k, y in enumerate((-0.2, -0.067, 0.067, 0.2)):
        _stam(b, 0.6 + b.rng.uniform(-0.04, 0.04), r * b.rng.uniform(0.9, 1.05), (0, y, r), "x")
    for x in (-0.14, 0.0, 0.14):
        _stam(b, 0.56 + b.rng.uniform(-0.04, 0.04), r * b.rng.uniform(0.9, 1.05), (x, 0, 3 * r), "y")
    for y in (-0.08, 0.08):
        _stam(b, 0.5 + b.rng.uniform(-0.04, 0.04), r * b.rng.uniform(0.9, 1.05), (0, y, 5 * r), "x")
    _stam(b, 0.44, r, (0, 0, 7 * r), "y")


def houtblok(b):
    _stam(b, 0.42, 0.065, (0, 0, 0.065), "x")
    b.box((0.42, 0.1, 0.02), (0, 0, 0.128), swatch="hout_licht", nerf_as="x")


def takkenbos(b):
    for k in range(7):
        a = 2 * math.pi * k / 6
        rr = 0.034 if k else 0.0
        x0 = rr * math.cos(a)
        z0 = 0.062 + rr * math.sin(a)
        _stam(b, 0.5 + b.rng.uniform(-0.06, 0.06), 0.02 + b.rng.uniform(-0.004, 0.004), (x0, 0, z0), "y", segs=6)
    for y in (-0.15, 0.15):
        b.touw([(0.075 * math.cos(2 * math.pi * j / 12), y, 0.062 + 0.075 * math.sin(2 * math.pi * j / 12)) for j in range(12)],
               r=0.011, segs=5, gesloten=True)


def hakblok(b):
    prof = [(0.15, 0.0), (0.16, 0.12), (0.15, 0.28)]
    b.lathe(prof, (0, 0, 0), 12, "schors", boven="kops", onder=None)
    b.box((0.09, 0.02, 0.05), (0.04, 0.03, 0.275), rot=rot_z(25), swatch="donker", vast=(0.5, 0.5))


def zaag(b):
    L, H = 0.9, 0.09
    faces = []
    faces += b.box((L, 0.006, H), (0, 0, H / 2 + 0.025), swatch="ijzer")
    n = 22
    for k in range(n):
        x = -L / 2 + 0.05 + k * (L - 0.1) / (n - 1)
        faces += b.box((0.026, 0.006, 0.026), (x, 0, 0.025), rot=rot_y(45), swatch="ijzer")
    for sx in (-1, 1):
        x = sx * (L / 2 - 0.035)
        faces += b.box((0.055, 0.022, 0.11), (x, 0, H / 2 + 0.06), swatch="ijzer")
        faces += b.cil(0.02, 0.22, (x, 0, H + 0.06), 8, "hout_licht", boven="hout_licht", onder="hout_licht", r2=0.017)
        faces += b.piramide(0.012, 0.01, (x, -0.011, H / 2 + 0.085), (0, -1, 0), "ijzer")
    # leunt met de rug tegen een blok
    b.verplaats(faces, Matrix.Translation(Vector((0, -0.08, 0))) @ rot_x(-28))
    _stam(b, 0.36, 0.07, (0, 0.05, 0.07), "x")


def axe(b):
    # steel langs z (glTF y) rond het midden, kop bovenaan; het spel legt hem
    # met schaal 0,46 en -90 graden om z op de stronk, zoals de Tripo-bijl
    b.lathe([(0.03, -0.5), (0.028, 0.0), (0.024, 0.42)], (0, 0, 0), 8, "hout_licht", boven="hout_licht", onder="hout_licht")
    b.box((0.17, 0.05, 0.1), (-0.04, 0, 0.4), swatch="ijzer")
    b.box((0.12, 0.012, 0.17), (-0.17, 0, 0.4), swatch="ijzer")
    b.box((0.04, 0.05, 0.11), (0.06, 0, 0.4), swatch="ijzer")


def touwrol(b):
    for R, z in ((0.13, 0.02), (0.126, 0.056), (0.12, 0.092), (0.104, 0.126)):
        b.touw(b.cirkel_punten(R, z, 16, ruis=0.004), r=0.018, segs=6, gesloten=True)
    b.touw([(0.1, -0.07, 0.14), (0.15, -0.13, 0.1), (0.2, -0.2, 0.03), (0.26, -0.24, 0.018)], r=0.016, segs=6)


def _ton(b, duig, band, h=1.0, r=0.3, buik=0.36, banden=(0.12, 0.5, 0.88), deksel="hout_licht", segs=12, pos=(0, 0, 0)):
    prof = [(r, 0.0), (r + (buik - r) * 0.65, h * 0.2), (buik, h * 0.5), (r + (buik - r) * 0.65, h * 0.8), (r, h)]
    faces = b.lathe(prof, pos, segs, duig, boven=deksel, onder=deksel)
    for zf in banden:
        faces += _band(b, prof, zf * h, 0.06, band, 0.012, segs, pos)
    return faces, prof


def barrel(b):
    _ton(b, "duigen_licht", "ijzer")


def barrel_red(b):
    faces, prof = _ton(b, "duigen_verweerd", "roest", banden=(0.14, 0.86))
    # touw om de buik, een gat in een duig
    b.touw(b.cirkel_punten(_straal(prof, 0.42) + 0.01, 0.42, 16, ruis=0.006), r=0.02, segs=6, gesloten=True)
    b.box((0.09, 0.02, 0.16), (0, -_straal(prof, 0.6), 0.6), swatch="donker", vast=(0.5, 0.5))


def bierton_red(b):
    faces, prof = _ton(b, "duigen_verweerd", "roest", h=0.75, r=0.22, buik=0.27, banden=(0.12, 0.88), deksel="hout_verweerd")
    # liggend op een bok, kraan naar voren (-y)
    b.verplaats(faces, Matrix.Translation(Vector((0, 0.375, 0.34))) @ rot_x(90))
    for sx in (-1, 1):
        b.box((0.06, 0.9, 0.06), (sx * 0.2, 0, 0.03), swatch="hout_donker", nerf_as="y")
    for sy in (-0.3, 0.3):
        b.box((0.5, 0.05, 0.05), (0, sy, 0.085), swatch="hout_donker", nerf_as="x")
    b.cil(0.018, 0.07, (0, -0.375, 0.24), 6, "koper", boven="koper", onder=None, rot=rot_x(90))
    b.box((0.05, 0.012, 0.02), (0, -0.44, 0.27), swatch="koper")
    b.touw(b.cirkel_punten(_straal(prof, 0.28) + 0.01, 0.0, 16, ruis=0.004), r=0.016, segs=6, gesloten=True)


def _emmer(b, duig, band, h=0.28, r0=0.11, r1=0.135, banden=(0.22, 0.78), band_swatch=None, touwgreep=True, oren=True, segs=12):
    prof = [(r0, 0.0), (r1, h)]
    b.lathe(prof, (0, 0, 0), segs, duig, boven=None, onder="hout_verweerd")
    _binnenwand(b, prof, "hout_verweerd", 0.014, segs, bodem="hout_verweerd")
    for zf in banden:
        _band(b, prof, zf * h, 0.03, band_swatch or band, 0.006, segs)
    if oren:
        for sx in (-1, 1):
            b.box((0.05, 0.02, 0.13), (sx * (r1 - 0.005), 0, h + 0.03), swatch=duig, nerf_as="z")
    if touwgreep:
        b.touw(_boogpunten((-r1 + 0.02, 0, h + 0.07), (r1 - 0.02, 0, h + 0.07), 8, 0.13), r=0.012, segs=5)
    return prof


def emmer(b):
    _emmer(b, "duigen_licht", "ijzer")


def emmer_red(b):
    prof = _emmer(b, "duigen_verweerd", "roest", banden=(0.7,))
    b.touw(b.cirkel_punten(_straal(prof, 0.06) + 0.008, 0.06, 12, ruis=0.003), r=0.011, segs=5, gesloten=True)
    b.box((0.03, 0.02, 0.1), (0.06, -_straal(prof, 0.16), 0.16), swatch="donker", vast=(0.5, 0.5))


def _kist(b, hout, beslag, breed=0.5, diep=0.3, hoog=0.22, deksel=0.1, banden=(-0.16, 0.16), slot=True, hoeken=False):
    b.box((breed, diep, hoog), (0, 0, hoog / 2), swatch=hout, nerf_as="x")
    b.box((breed, diep, deksel * 0.55), (0, 0, hoog + deksel * 0.275), swatch=hout, nerf_as="x")
    b.box((breed, diep * 0.66, deksel * 0.5), (0, 0, hoog + deksel * 0.72), swatch=hout, nerf_as="x")
    tot = hoog + deksel
    for x in banden:
        b.box((0.045, diep + 0.014, tot + 0.006), (x, 0, tot / 2), swatch=beslag, nerf_as="z")
    if slot:
        b.box((0.07, 0.012, 0.1), (0, -diep / 2 - 0.006, hoog - 0.03), swatch=beslag, vast=(0.5, 0.5))
        b.box((0.02, 0.012, 0.03), (0, -diep / 2 - 0.012, hoog - 0.04), swatch="donker", vast=(0.5, 0.5))
    if hoeken:
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.box((0.05, 0.05, 0.05), (sx * (breed / 2 - 0.02), sy * (diep / 2 - 0.02), 0.03), swatch=beslag, vast=(0.5, 0.5))
    for sx in (-1, 1):
        b.touw(_boogpunten((sx * (breed / 2 + 0.005), -0.06, hoog * 0.6), (sx * (breed / 2 + 0.005), 0.06, hoog * 0.6), 6, 0.0), r=0.012, segs=5)
    return tot


def kist(b):
    _kist(b, "hout_donker", "roest", banden=(-0.18, 0.0, 0.18), hoeken=True)


def kist_red(b):
    tot = _kist(b, "hout_verweerd", "roest", banden=(-0.14, 0.14))
    b.box((0.12, 0.008, 0.08), (0.12, -0.154, 0.09), swatch="jute")
    b.box((0.09, 0.01, 0.06), (-0.17, -0.155, 0.16), swatch="hout_licht", nerf_as="x")
    # touw eromheen
    d, w = 0.152, 0.252
    pts = [(-w, -d, 0.12), (w, -d, 0.12), (w, d, 0.12), (-w, d, 0.12)]
    b.touw(pts, r=0.014, segs=5, gesloten=True)


def lantaarn(b):
    b.box((0.07, 0.07, 0.95), (0, 0, 0.475), swatch="hout_donker", nerf_as="z")
    b.box((0.38, 0.05, 0.05), (0.17, 0, 0.9), swatch="hout_donker", nerf_as="x")
    b.box((0.05, 0.04, 0.22), (0.13, 0, 0.79), rot=rot_y(-40), swatch="hout_donker", nerf_as="z")
    x = 0.34
    b.cil(0.006, 0.09, (x, 0, 0.79), 4, "ijzer", boven=None, onder=None)
    b.lathe([(0.03, 0.0), (0.05, 0.02), (0.05, 0.14), (0.03, 0.17), (0.012, 0.2)], (x, 0, 0.59), 8, "glas", boven="ijzer", onder="ijzer", glad=True)
    for a in (45, 135, 225, 315):
        b.box((0.008, 0.008, 0.13), (x + 0.048 * math.cos(math.radians(a)), 0.048 * math.sin(math.radians(a)), 0.68), swatch="ijzer", vast=(0.5, 0.5))
    b.lathe([(0.04, 0.0), (0.055, 0.015)], (x, 0, 0.6), 8, "ijzer")


def fakkel(b):
    for a in (90, 210, 330):
        x, y = 0.12 * math.cos(math.radians(a)), 0.12 * math.sin(math.radians(a))
        d = Vector((-x, -y, 0.5))
        b.cil(0.012, d.length, (x, y, 0), 6, "ijzer", boven=None, onder=None, rot=_richting_rot(d))
    prof = [(0.05, 0.0), (0.1, 0.09), (0.12, 0.2)]
    b.lathe(prof, (0, 0, 0.48), 10, "ijzer", boven=None, onder="ijzer")
    _binnenwand(b, prof, "donker", 0.012, 10, pos=(0, 0, 0.48), bodem="donker")
    _band(b, prof, 0.2, 0.025, "ijzer", 0.006, 10, pos=(0, 0, 0.48))
    b.touw(b.cirkel_punten(0.06, 0.5, 8), r=0.01, segs=4, swatch="ijzer", gesloten=True)


def aambeeld(b):
    prof = [(0.17, 0.0), (0.17, 0.3)]
    b.lathe(prof, (0, 0, 0), 10, "duigen_licht", boven="kops", onder=None)
    _band(b, prof, 0.12, 0.04, "ijzer", 0.008, 10)
    b.box((0.17, 0.13, 0.05), (0.02, 0, 0.325), swatch="ijzer")
    b.box((0.13, 0.09, 0.06), (0.02, 0, 0.38), swatch="ijzer")
    b.box((0.34, 0.13, 0.09), (0.03, 0, 0.455), swatch="ijzer")
    b.cil(0.045, 0.17, (-0.14, 0, 0.455), 8, "ijzer", boven=None, onder=None, r2=0.0, rot=rot_y(-90))
    b.box((0.03, 0.03, 0.02), (0.15, 0.04, 0.51), swatch="donker", vast=(0.5, 0.5))
    b.cil(0.013, 0.3, (-0.2, -0.11, 0.315), 6, "hout_licht", boven="hout_licht", onder="hout_licht", rot=rot_y(90))
    b.box((0.06, 0.04, 0.04), (0.12, -0.11, 0.32), swatch="ijzer")


def blaasbalg(b):
    b.box((0.2, 0.3, 0.02), (0, 0.03, 0.01), swatch="hout_licht", nerf_as="y")
    for k in range(3):
        b.box((0.17 - 0.015 * k, 0.26, 0.012), (0, 0.03, 0.026 + 0.013 * k), swatch="leer", vast=(0.5, 0.5))
    b.box((0.2, 0.3, 0.02), (0, 0.03, 0.075), swatch="hout_licht", nerf_as="y")
    b.box((0.05, 0.08, 0.06), (0, 0.06, 0.115), swatch="leer", vast=(0.5, 0.5))
    b.box((0.08, 0.08, 0.02), (0, -0.14, 0.04), swatch="leer", vast=(0.5, 0.5))
    b.cil(0.022, 0.14, (0, -0.16, 0.04), 8, "ijzer", boven="donker", onder=None, r2=0.008, rot=rot_x(90))
    for x, y in ((-0.07, 0.12), (0.07, 0.12), (-0.08, -0.04), (0.08, -0.04), (-0.05, -0.1), (0.05, -0.1)):
        b.piramide(0.011, 0.008, (x, y, 0.085), (0, 0, 1), "ijzer")


def werkbank(b):
    b.box((0.7, 0.32, 0.05), (0, 0, 0.375), swatch="hout_licht", nerf_as="x")
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((0.05, 0.05, 0.35), (sx * 0.3, sy * 0.12, 0.175), swatch="hout_donker", nerf_as="z")
    b.box((0.6, 0.26, 0.02), (0, 0, 0.12), swatch="hout_donker", nerf_as="x")
    b.box((0.7, 0.02, 0.16), (0, 0.15, 0.48), swatch="hout_licht", nerf_as="x")
    b.cil(0.01, 0.18, (-0.24, -0.02, 0.405), 6, "hout_licht", rot=rot_y(90))
    b.box((0.05, 0.035, 0.035), (-0.03, -0.02, 0.418), swatch="hout_donker")
    b.box((0.16, 0.02, 0.008), (0.15, 0.0, 0.404), swatch="ijzer", vast=(0.5, 0.5))
    b.box((0.05, 0.02, 0.008), (0.24, 0.0, 0.404), swatch="hout_licht")
    b.box((0.12, 0.05, 0.04), (0.2, 0.08, 0.42), swatch="hout_donker", nerf_as="x")
    b.box((0.06, 0.04, 0.06), (-0.32, -0.19, 0.36), swatch="ijzer", vast=(0.5, 0.5))
    b.cil(0.008, 0.12, (-0.32, -0.22, 0.36), 6, "ijzer", boven="ijzer", onder=None, rot=rot_x(90))
    b.box((0.02, 0.02, 0.1), (-0.1, 0.152, 0.49), swatch="ijzer", vast=(0.5, 0.5))
    b.box((0.03, 0.02, 0.12), (0.05, 0.152, 0.5), swatch="hout_donker", nerf_as="z")


def put(b):
    prof = [(0.3, 0.0), (0.32, 0.16), (0.3, 0.36)]
    b.lathe(prof, (0, 0, 0), 12, "steen", boven=None, onder=None)
    b.lathe([(0.22, 0.36), (0.22, 0.05)], (0, 0, 0), 12, "donker", boven="donker", onder=None)
    b.lathe([(0.22, 0.36), (0.32, 0.375)], (0, 0, 0), 12, "steen")
    for sx in (-1, 1):
        b.box((0.06, 0.06, 0.92), (sx * 0.26, 0, 0.46), swatch="hout_donker", nerf_as="z")
    b.box((0.7, 0.06, 0.06), (0, 0, 0.94), swatch="hout_donker", nerf_as="x")
    for s in (-1, 1):
        b.box((0.78, 0.36, 0.03), (0, s * 0.15, 1.08), rot=rot_x(s * 36), swatch="lei", nerf_as="x")
    b.box((0.78, 0.05, 0.05), (0, 0, 1.19), swatch="hout_donker", nerf_as="x")
    b.cil(0.03, 0.5, (-0.25, 0, 0.86), 8, "hout_licht", boven="hout_licht", onder="hout_licht", rot=rot_y(90))
    b.touw([(0, 0, 0.86), (0, 0, 0.54)], r=0.008, segs=4)
    prof2 = [(0.05, 0.0), (0.06, 0.1)]
    b.lathe(prof2, (0, 0, 0.42), 8, "duigen_verweerd", boven=None, onder="hout_verweerd")
    _binnenwand(b, prof2, "hout_verweerd", 0.01, 8, pos=(0, 0, 0.42), bodem="hout_verweerd")
    b.touw(_boogpunten((-0.055, 0, 0.52), (0.055, 0, 0.52), 6, 0.05), r=0.006, segs=4, swatch="ijzer")


RECEPTEN = {
    "kruitvat": (kruitvat, 1), "kogels": (kogels, 1), "houtstapel": (houtstapel, 1), "houtblok": (houtblok, 1),
    "takkenbos": (takkenbos, 1), "hakblok": (hakblok, 1), "zaag": (zaag, 1), "axe": (axe, 1), "touwrol": (touwrol, 1),
    "barrel": (barrel, 1), "barrel_red": (barrel_red, 1), "bierton_red": (bierton_red, 1), "emmer": (emmer, 1),
    "emmer_red": (emmer_red, 1), "kist": (kist, 1), "kist_red": (kist_red, 1), "lantaarn": (lantaarn, 1),
    "fakkel": (fakkel, 1), "aambeeld": (aambeeld, 1), "blaasbalg": (blaasbalg, 1), "werkbank": (werkbank, 1), "put": (put, 1),
}


# ---------------------------------------------------------------- batch 2: kannen, ketels, kommen, manden, blauw en goud

def _decal(b, swatch, breedte, hoogte, pos, rot=None):
    """Een plat plaatje (fleur, kroon, wapen) net voor een vlak; voorkant -y."""
    return b.doek(breedte, hoogte, pos, rot, swatch, nx=1, ny=1)


def emmer_blue(b):
    h, r0, r1 = 0.3, 0.115, 0.14
    prof = [(r0, 0.0), (r1, h)]
    b.lathe(prof, (0, 0, 0), 12, "duigen_blauw", boven=None, onder="hout_blauw")
    _binnenwand(b, prof, "hout_blauw", 0.014, 12, bodem="hout_blauw")
    for zf in (0.08, 0.5, 0.95):
        _band(b, prof, zf * h, 0.028, "goud", 0.007, 12)
    for sx in (-1, 1):
        b.box((0.05, 0.02, 0.13), (sx * (r1 - 0.005), 0, h + 0.03), swatch="hout_blauw", nerf_as="z")
        b.box((0.055, 0.006, 0.135), (sx * (r1 - 0.005), -0.013, h + 0.03), swatch="goud", vast=(0.5, 0.5))
    b.touw(_boogpunten((-r1 + 0.02, 0, h + 0.07), (r1 - 0.02, 0, h + 0.07), 10, 0.14), r=0.011, segs=6, swatch="goud")
    b.cil(0.018, 0.09, (-0.045, 0, h + 0.2), 8, "hout_blauw", boven="goud", onder="goud", rot=rot_y(90))
    _decal(b, "fleur", 0.12, 0.13, (0, -_straal(prof, 0.14) - 0.004, 0.08))


def _blauwe_kist(b, breed, diep, hoog, deksel, banden, decal="fleur", hoeken=True):
    tot = _kist(b, "hout_blauw", "goud", breed, diep, hoog, deksel, banden, slot=True, hoeken=hoeken)
    _decal(b, decal, 0.13, 0.13, (breed * 0.25, -diep / 2 - 0.004, hoog * 0.5))
    _decal(b, decal, 0.13, 0.13, (-breed * 0.25, -diep / 2 - 0.004, hoog * 0.5))
    return tot


def kist_blue(b):
    _blauwe_kist(b, 0.5, 0.3, 0.22, 0.1, (-0.17, 0.17))


def vergulde_kist(b):
    _blauwe_kist(b, 0.52, 0.32, 0.24, 0.14, (-0.19, 0.0, 0.19), decal="wapen")
    b.box((0.54, 0.34, 0.02), (0, 0, 0.01), swatch="goud", vast=(0.5, 0.5))


def barrel_blue(b):
    faces, prof = _ton(b, "duigen_blauw", "goud", deksel="hout_blauw")
    b.cil(0.02, 0.09, (0, -_straal(prof, 0.18), 0.18), 6, "goud", boven="goud", onder=None, rot=rot_x(90))
    b.box((0.06, 0.014, 0.02), (0, -_straal(prof, 0.18) - 0.08, 0.21), swatch="goud", vast=(0.5, 0.5))
    _decal(b, "fleur", 0.2, 0.22, (0, -_straal(prof, 0.55) - 0.004, 0.44))


def wijnvat(b):
    faces, prof = _ton(b, "duigen_blauw", "goud", h=0.75, r=0.22, buik=0.27, banden=(0.1, 0.5, 0.9), deksel="hout_blauw")
    b.verplaats(faces, Matrix.Translation(Vector((0, 0.375, 0.36))) @ rot_x(90))
    for sx in (-1, 1):
        b.box((0.06, 0.9, 0.06), (sx * 0.2, 0, 0.03), swatch="hout_donker", nerf_as="y")
        b.box((0.07, 0.92, 0.012), (sx * 0.2, 0, 0.066), swatch="goud", vast=(0.5, 0.5))
    for sy in (-0.3, 0.3):
        b.box((0.5, 0.05, 0.05), (0, sy, 0.085), swatch="hout_donker", nerf_as="x")
    b.cil(0.018, 0.07, (0, -0.375, 0.26), 6, "goud", boven="goud", onder=None, rot=rot_x(90))
    b.box((0.05, 0.012, 0.02), (0, -0.44, 0.29), swatch="goud", vast=(0.5, 0.5))
    _decal(b, "wapen", 0.24, 0.26, (0, -0.38, 0.36))


def _ketel(b, romp, metaal, h=0.26, r=0.13, glad=True):
    prof = [(0.06, 0.0), (0.11, 0.02), (r, h * 0.35), (r * 0.9, h * 0.72), (0.06, h * 0.86), (0.07, h)]
    b.lathe(prof, (0, 0, 0), 12, romp, boven=None, onder=romp, glad=glad)
    # deksel met knop
    b.lathe([(0.075, 0.0), (0.06, 0.03), (0.02, 0.05), (0.0, 0.07)], (0, 0, h - 0.005), 10, metaal, onder=metaal, glad=glad)
    b.bol(0.016, (0, 0, h + 0.07), 1, metaal)
    # tuit naar voren (-y): een gebogen buis
    b.touw([(0, -r * 0.8, h * 0.4), (0, -r * 1.25, h * 0.55), (0, -r * 1.55, h * 0.9), (0, -r * 1.6, h * 1.05)], r=0.02, segs=6, swatch=metaal)
    # hengsel over de top
    b.touw(_boogpunten((-r * 0.85, 0, h * 0.75), (r * 0.85, 0, h * 0.75), 10, h * 0.6), r=0.014, segs=6, swatch=metaal)
    return prof


def ketel_blue(b):
    _ketel(b, "blauw_fluweel", "goud")
    b.cil(0.022, 0.1, (-0.05, 0, 0.26 + 0.6 * 0.26 * 0.9), 8, "hout_blauw", boven="goud", onder="goud", rot=rot_y(90))
    for a in (30, 150, 270):
        x, y = 0.09 * math.cos(math.radians(a)), 0.09 * math.sin(math.radians(a))
        b.piramide(0.02, 0.03, (x, y, 0.03), (0, 0, -1), "goud")
    _decal(b, "fleur", 0.08, 0.09, (0, -0.13 * 0.98 - 0.004, 0.11))


def ketel_red(b):
    _ketel(b, "koper", "koper")
    b.cil(0.02, 0.09, (-0.045, 0, 0.26 + 0.6 * 0.26 * 0.9), 8, "leer", boven="koper", onder="koper", rot=rot_y(90))
    b.box((0.06, 0.006, 0.05), (0.06, -0.12, 0.1), swatch="jute", rot=rot_z(-25))


def _kruik(b, romp, glad=True):
    prof = [(0.05, 0.0), (0.1, 0.06), (0.115, 0.15), (0.09, 0.26), (0.055, 0.31), (0.06, 0.36), (0.075, 0.38)]
    b.lathe(prof, (0, 0, 0), 12, romp, boven=None, onder=romp, glad=glad)
    _binnenwand(b, [(0.055, 0.31), (0.06, 0.36), (0.075, 0.38)], "donker", 0.012, 12, bodem="donker")
    return prof


def kruik_blue(b):
    prof = _kruik(b, "blauw_fluweel")
    for z in (0.15, 0.36):
        _band(b, prof, z, 0.02, "goud", 0.005, 12)
    b.touw([(0, 0.075, 0.36), (0, 0.16, 0.33), (0, 0.17, 0.22), (0, 0.11, 0.14)], r=0.013, segs=6, swatch="goud")
    _decal(b, "fleur", 0.09, 0.1, (0, -_straal(prof, 0.17) - 0.004, 0.12))


def kruik_red(b):
    prof = _kruik(b, "klei")
    b.touw(b.cirkel_punten(_straal(prof, 0.31) + 0.004, 0.31, 10, ruis=0.002), r=0.01, segs=5, gesloten=True)
    b.touw([(0, 0.07, 0.35), (0, 0.15, 0.32), (0, 0.16, 0.22), (0, 0.1, 0.14)], r=0.014, segs=6, swatch="klei")
    b.box((0.06, 0.006, 0.05), (0.05, -_straal(prof, 0.12) + 0.002, 0.12), swatch="jute", rot=rot_z(15))


def _kom(b, hout, r=0.15, h=0.1, glad=False):
    prof = [(0.07, 0.0), (0.13, 0.04), (r, h)]
    b.lathe(prof, (0, 0, 0), 12, hout, boven=None, onder=hout, glad=glad)
    _binnenwand(b, prof, hout, 0.014, 12, bodem=hout)
    # lepel: steel en blad, leunend op de rand
    b.cil(0.008, 0.22, (0.0, 0.0, h - 0.01), 6, "hout_licht", boven="hout_licht", onder="hout_licht", rot=rot_y(-55) @ rot_x(0))
    b.bol(0.03, (-0.02, 0.0, h - 0.035), 1, "hout_licht", schaal=(1.0, 0.7, 0.4))
    return prof


def kom_blue(b):
    prof = _kom(b, "hout_blauw")
    _band(b, prof, 0.095, 0.015, "goud", 0.004, 12)
    b.doek(0.14, 0.12, (0.09, -0.1, 0.1), rot_z(-40) @ rot_x(-75), "blauw_goudrand", nx=2, ny=2, buik=0.02)


def kom_red(b):
    prof = _kom(b, "hout_donker")
    b.touw(b.cirkel_punten(_straal(prof, 0.085) + 0.006, 0.085, 12, ruis=0.003), r=0.01, segs=5, gesloten=True)


def _mand(b, riet, breed=0.36, diep=0.26, hoog=0.16, doek=None, broden=4, rand=None):
    b.box((breed, diep, hoog), (0, 0, hoog / 2), swatch=riet, per_eenheid=3.0, nerf_as="x")
    b.box((breed - 0.03, diep - 0.03, hoog - 0.02), (0, 0, hoog / 2 + 0.02), swatch="donker", vast=(0.5, 0.5))
    if rand is not None:
        b.box((breed + 0.01, diep + 0.01, 0.015), (0, 0, hoog), swatch=rand, vast=(0.5, 0.5))
    for sx in (-1, 1):
        b.touw(_boogpunten((sx * breed / 2, -0.05, hoog - 0.02), (sx * breed / 2, 0.05, hoog - 0.02), 6, 0.06), r=0.012, segs=5, swatch=riet)
    if doek is not None:
        b.doek(breed - 0.02, diep * 0.9, (0, -diep * 0.45, hoog - 0.01), rot_x(-90), doek, nx=2, ny=2, buik=0.0)
    for k in range(broden):
        x = (k - (broden - 1) / 2) * (breed - 0.1) / max(broden - 1, 1)
        b.bol(0.05, (x, b.rng.uniform(-0.03, 0.03), hoog + 0.02), 1, "brood", schaal=(1.0, 1.5, 0.75), glad=True)


def broodmand_red(b):
    _mand(b, "riet", broden=3, doek="linnen_grijs")


def broodmand_blue(b):
    _mand(b, "riet", hoog=0.15, broden=5, doek="blauw_goudrand", rand="goud")


def kandelaar(b):
    b.lathe([(0.1, 0.0), (0.09, 0.02), (0.05, 0.05), (0.03, 0.08), (0.02, 0.3)], (0, 0, 0), 10, "zilver", onder="zilver", glad=True)
    _band(b, [(0.1, 0.0), (0.09, 0.02)], 0.01, 0.02, "blauw_fluweel", 0.004, 10)
    b.bol(0.035, (0, 0, 0.3), 1, "zilver", glad=True)
    kaarsen = [(0, 0, 0.36)]
    for sx in (-1, 1):
        b.touw([(0, 0, 0.3), (sx * 0.06, 0, 0.28), (sx * 0.11, 0, 0.3), (sx * 0.13, 0, 0.35)], r=0.012, segs=6, swatch="zilver")
        kaarsen.append((sx * 0.13, 0, 0.35))
    for (x, y, z) in kaarsen:
        b.lathe([(0.03, 0.0), (0.035, 0.02)], (x, y, z), 8, "zilver", onder="zilver")
        b.cil(0.014, 0.12 + b.rng.uniform(-0.02, 0.02), (x, y, z + 0.02), 8, "was", boven="was", onder=None)


RECEPTEN.update({
    "emmer_blue": (emmer_blue, 2), "kist_blue": (kist_blue, 2), "vergulde_kist_blue": (vergulde_kist, 2),
    "barrel_blue": (barrel_blue, 2), "wijnvat_blue": (wijnvat, 2), "ketel_blue": (ketel_blue, 2), "ketel_red": (ketel_red, 2),
    "kruik_blue": (kruik_blue, 2), "kruik_red": (kruik_red, 2), "kom_blue": (kom_blue, 2), "kom_red": (kom_red, 2),
    "broodmand_red": (broodmand_red, 2), "broodmand_blue": (broodmand_blue, 2), "kandelaar_blue": (kandelaar, 2),
})


# ---------------------------------------------------------------- batch 3: doek, vaandels, het rijke kamp

def _lap(b, breedte, hoogte, pos, swatch, buik=0.02, zoom=0.02, rot=None):
    return b.doek(breedte, hoogte, pos, rot, swatch, nx=3, ny=4, buik=buik, zoom=zoom)


def _lijn(b, van, naar, doorhang=0.06, n=10, r=0.008, swatch="touw"):
    van, naar = Vector(van), Vector(naar)
    pts = []
    for i in range(n + 1):
        t = i / n
        p = van.lerp(naar, t)
        p.z -= doorhang * math.sin(t * math.pi)
        pts.append(tuple(p))
    b.touw(pts, r=r, segs=5, swatch=swatch)
    return pts


def _hangend(b, pts, lapjes):
    """Lapjes aan een lijn: (t langs de lijn, breedte, hoogte, stofje)."""
    for (t, breed, hoog, sw) in lapjes:
        i = min(int(t * (len(pts) - 1)), len(pts) - 2)
        f = t * (len(pts) - 1) - i
        p = Vector(pts[i]).lerp(Vector(pts[i + 1]), f)
        _lap(b, breed, hoog, (p.x, p.y - 0.005, p.z - hoog), sw, buik=0.03, zoom=0.025)


def tapijt(b):
    b.doek(0.9, 0.7, (0, -0.35, 0.006), rot_x(-90), "tapijt", nx=3, ny=3)
    for sy in (-1, 1):
        b.box((0.9, 0.03, 0.006), (0, sy * 0.365, 0.004), swatch="goud", vast=(0.5, 0.5))


def _veldbed(b, hout, doek_sw, rol_sw, knoppen=None):
    for sx in (-1, 1):
        for s in (-1, 1):
            b.box((0.03, 0.03, 0.48), (sx * 0.3, 0, 0.21), rot=rot_x(s * 34), swatch=hout, nerf_as="z")
    for sy in (-1, 1):
        b.box((0.82, 0.03, 0.03), (0, sy * 0.15, 0.4), swatch=hout, nerf_as="x")
        if knoppen:
            for sx in (-1, 1):
                b.bol(0.022, (sx * 0.41, sy * 0.15, 0.41), 1, knoppen)
    b.doek(0.78, 0.3, (0, -0.15, 0.4), rot_x(-90), doek_sw, nx=4, ny=2, buik=-0.05)
    b.cil(0.05, 0.28, (-0.3, -0.14, 0.44), 8, rol_sw, boven=rol_sw, onder=rol_sw, rot=rot_x(-90), glad=True)


def veldbed_red(b):
    _veldbed(b, "hout_verweerd", "linnen_grijs", "jute")
    _lap(b, 0.22, 0.2, (0.2, -0.16, 0.22), "linnen_grijs", buik=0.04, zoom=0.03)


def veldbed_blue(b):
    _veldbed(b, "hout_donker", "blauw_goudrand", "blauw_fluweel", knoppen="goud")
    _lap(b, 0.3, 0.26, (0.15, -0.16, 0.16), "blauw_goudrand", buik=0.04, zoom=0.03)
    for sx in (-1, 1):
        b.box((0.06, 0.06, 0.012), (sx * 0.3, 0, 0.005), swatch="goud", vast=(0.5, 0.5))


def _kruispaal(b, x, hoogte=0.9, swatch="hout_donker"):
    for s in (-1, 1):
        b.cil(0.018, hoogte, (x + s * 0.11, 0, 0), 6, swatch, boven=swatch, onder=None, rot=rot_y(-s * 14))


def waslijn_red(b):
    _kruispaal(b, -0.5)
    _kruispaal(b, 0.5)
    pts = _lijn(b, (-0.5, 0, 0.86), (0.5, 0, 0.86), 0.07)
    _hangend(b, pts, [(0.18, 0.18, 0.24, "linnen_grijs"), (0.42, 0.2, 0.3, "jute"), (0.64, 0.14, 0.22, "linnen_grijs"), (0.84, 0.16, 0.26, "rood_doek")])


def voddenlijn(b):
    _kruispaal(b, -0.5, 0.8)
    _kruispaal(b, 0.5, 0.85)
    pts = _lijn(b, (-0.5, 0, 0.76), (0.5, 0, 0.81), 0.09)
    _hangend(b, pts, [(0.12, 0.14, 0.2, "jute"), (0.3, 0.16, 0.26, "linnen_grijs"), (0.5, 0.12, 0.2, "rood_doek"),
                      (0.68, 0.18, 0.24, "jute"), (0.88, 0.1, 0.16, "linnen_grijs")])
    b.doek(0.18, 0.14, (0.2, -0.22, 0.004), rot_x(-90), "linnen_grijs", nx=2, ny=2)


def waslijn_blue(b):
    for x in (-0.55, 0.55):
        b.box((0.06, 0.06, 0.95), (x, 0, 0.475), swatch="hout_blauw", nerf_as="z")
        b.box((0.16, 0.16, 0.05), (x, 0, 0.025), swatch="goud", vast=(0.5, 0.5))
        b.box((0.08, 0.08, 0.03), (x, 0, 0.965), swatch="goud", vast=(0.5, 0.5))
        b.bol(0.035, (x, 0, 1.01), 1, "goud", glad=True)
        for z in (0.3, 0.6):
            b.box((0.07, 0.07, 0.015), (x, 0, z), swatch="goud", vast=(0.5, 0.5))
    pts = _lijn(b, (-0.55, 0, 0.9), (0.55, 0, 0.9), 0.06)
    _hangend(b, pts, [(0.16, 0.2, 0.32, "blauw_goudrand"), (0.4, 0.14, 0.24, "linnen_wit"), (0.6, 0.2, 0.3, "blauw_goudrand"), (0.82, 0.13, 0.22, "linnen_wit")])


def kaarttafel_red(b):
    b.box((0.6, 0.4, 0.03), (0, 0, 0.415), swatch="hout_verweerd", nerf_as="x")
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((0.04, 0.04, 0.4), (sx * 0.26, sy * 0.16, 0.2), swatch="hout_verweerd", nerf_as="z")
    b.box((0.36, 0.28, 0.005), (0.04, 0.0, 0.433), rot=rot_z(8), swatch="linnen_wit")
    b.lathe([(0.03, 0.0), (0.035, 0.01), (0.015, 0.02)], (-0.2, 0.1, 0.43), 8, "ijzer", onder="ijzer")
    b.cil(0.014, 0.1, (-0.2, 0.1, 0.45), 8, "was", boven="was", onder=None)
    b.cil(0.02, 0.03, (0.22, 0.12, 0.43), 8, "donker", boven="donker", onder=None)
    b.lathe([(0.025, 0.0), (0.03, 0.07)], (0.2, -0.1, 0.43), 8, "zilver", onder="zilver")
    _lap(b, 0.22, 0.24, (0.18, -0.2, 0.19), "linnen_grijs", buik=0.03, zoom=0.02)


def _musket(b, rijk):
    faces = []
    faces += b.box((0.04, 0.05, 0.3), (0, 0, 0.15), swatch="hout_donker", nerf_as="z")
    faces += b.box((0.035, 0.04, 0.32), (0, 0, 0.45), swatch="hout_donker", nerf_as="z")
    faces += b.cil(0.011, 0.68, (0, -0.012, 0.36), 6, "zilver" if rijk else "ijzer", boven="ijzer", onder=None)
    faces += b.box((0.045, 0.012, 0.05), (0, 0.025, 0.36), swatch="ijzer", vast=(0.5, 0.5))
    faces += b.box((0.04, 0.05, 0.02), (0, 0, 0.01), swatch="goud" if rijk else "ijzer", vast=(0.5, 0.5))
    if rijk:
        for z in (0.55, 0.8):
            faces += b.lathe([(0.02, z - 0.01), (0.02, z + 0.01)], (0, -0.006, 0), 6, "goud")
    return faces


def _musketrek(b, rijk):
    for k in range(3):
        a = math.radians(90 + 120 * k)
        voet = Vector((0.18 * math.cos(a), 0.18 * math.sin(a), 0.0))
        d = Vector((0, 0, 1.02)) - voet
        faces = _musket(b, rijk)
        b.verplaats(faces, Matrix.Translation(voet) @ _richting_rot(d) @ rot_z(a + math.pi / 2))
    b.touw(b.cirkel_punten(0.045, 0.86, 8), r=0.01, segs=5, swatch="leer", gesloten=True)


def musketrek_red(b):
    _musketrek(b, False)


def musketrek_blue(b):
    _musketrek(b, True)


def _schildplaat(b, breed, hoog, pos):
    """Wapenschild: een lap met het wapen-stofje (goudrand en fleur op blauw)."""
    return b.doek(breed, hoog, pos, None, "wapen", nx=2, ny=3)


def schild_blue(b):
    b.box((0.36, 0.22, 0.06), (0, 0, 0.03), swatch="hout_donker", nerf_as="x")
    b.box((0.3, 0.16, 0.02), (0, 0, 0.07), swatch="goud", vast=(0.5, 0.5))
    b.box((0.16, 0.1, 0.08), (0, 0, 0.12), swatch="hout_donker")
    b.cil(0.02, 0.5, (0, 0, 0.16), 8, "goud", boven="goud", onder=None)
    _schildplaat(b, 0.36, 0.44, (0, -0.03, 0.4))
    b.box((0.04, 0.02, 0.44), (0, -0.01, 0.62), swatch="goud", vast=(0.5, 0.5))
    b.cil(0.015, 0.64, (-0.32, 0.02, 0.86), 6, "hout_donker", boven="goud", onder="goud", rot=rot_y(90))
    for sx in (-1, 1):
        b.bol(0.03, (sx * 0.33, 0.02, 0.86), 1, "goud", glad=True)
        _lap(b, 0.15, 0.5, (sx * 0.26, 0.0, 0.36), "blauw_goudrand", buik=0.03, zoom=0.02)
    b.piramide(0.03, 0.08, (0, -0.01, 0.86), (0, 0, 1), "goud")


def vaandel_blue(b):
    b.box((0.64, 0.18, 0.05), (0, 0, 0.025), swatch="hout_donker", nerf_as="x")
    b.box((0.6, 0.14, 0.015), (0, 0, 0.057), swatch="goud", vast=(0.5, 0.5))
    for sx in (-1, 1):
        b.cil(0.02, 1.0, (sx * 0.25, 0.04, 0.05), 8, "hout_donker", boven=None, onder=None)
        b.piramide(0.03, 0.09, (sx * 0.25, 0.04, 1.05), (0, 0, 1), "goud")
        _lap(b, 0.14, 0.62, (sx * 0.25, 0.09, 0.4), "blauw_goudrand", buik=0.03, zoom=0.02)
    b.cil(0.014, 0.5, (-0.25, 0.04, 0.92), 6, "goud", boven=None, onder=None, rot=rot_y(90))
    b.box((0.06, 0.06, 0.32), (0, 0.03, 0.22), swatch="hout_donker", nerf_as="z")
    _schildplaat(b, 0.4, 0.52, (0, -0.02, 0.36))


def tent_blue(b):
    wand = [(0.55, 0.0), (0.55, 0.72)]
    b.lathe(wand, (0, 0, 0), 12, "blauw_goudrand", boven=None, onder=None, draai=math.pi / 12)
    b.lathe([(0.62, 0.72), (0.0, 1.32)], (0, 0, 0), 12, "blauw_fluweel", boven=None, onder=None, draai=math.pi / 12)
    b.lathe([(0.58, 0.7), (0.63, 0.72)], (0, 0, 0), 12, "goud", draai=math.pi / 12)
    b.touw(b.cirkel_punten(0.62, 0.72, 16), r=0.014, segs=5, swatch="goud", gesloten=True)
    b.cil(0.02, 0.1, (0, 0, 1.3), 6, "goud", boven="goud", onder=None)
    b.bol(0.045, (0, 0, 1.42), 1, "goud", glad=True)
    b.doek(0.32, 0.6, (0, -0.553, 0.02), None, "donker", nx=1, ny=1)
    for a in (-42.0, 42.0):
        ra = math.radians(a)
        b.doek(0.18, 0.2, (0.555 * math.sin(ra), -0.555 * math.cos(ra), 0.32), rot_z(ra), "fleur", nx=1, ny=1)
    for a in range(0, 360, 60):
        ra = math.radians(a + 15)
        b.touw([(0.6 * math.sin(ra), -0.6 * math.cos(ra), 0.7), (0.78 * math.sin(ra), -0.78 * math.cos(ra), 0.0)], r=0.008, segs=4, swatch="goud")


def _vlagstandaard(b, rijk):
    hout = "hout_donker"
    for k in range(3):
        a = math.radians(90 + 120 * k)
        voet = Vector((0.2 * math.cos(a), 0.2 * math.sin(a), 0.0))
        d = Vector((0, 0, 0.3)) - voet
        b.cil(0.014, d.length, tuple(voet), 6, hout, boven=None, onder=None, rot=_richting_rot(d))
    b.cil(0.02, 1.3, (0, 0, 0.02), 8, hout, boven=None, onder=None)
    if rijk:
        for z in (0.5, 0.9):
            b.lathe([(0.026, z - 0.012), (0.026, z + 0.012)], (0, 0, 0), 8, "goud")
        b.bol(0.035, (0, 0, 1.34), 1, "goud", glad=True)
        _lap(b, 0.42, 0.28, (0.23, -0.02, 1.0), "blauw_goudrand", buik=0.05, zoom=0.03)
    else:
        b.piramide(0.02, 0.06, (0, 0, 1.32), (0, 0, 1), "ijzer")
        _lap(b, 0.4, 0.26, (0.22, -0.02, 1.0), "rood_doek", buik=0.05, zoom=0.04)


def vlagstandaard_red(b):
    _vlagstandaard(b, False)


def vlagstandaard_blue(b):
    _vlagstandaard(b, True)


RECEPTEN.update({
    "tapijt_blue": (tapijt, 3), "veldbed_red": (veldbed_red, 3), "veldbed_blue": (veldbed_blue, 3),
    "waslijn_red": (waslijn_red, 3), "waslijn_blue": (waslijn_blue, 3), "voddenlijn_red": (voddenlijn, 3),
    "kaarttafel_red": (kaarttafel_red, 3), "musketrek_red": (musketrek_red, 3), "musketrek_blue": (musketrek_blue, 3),
    "schild_blue": (schild_blue, 3), "vaandel_blue": (vaandel_blue, 3), "tent_blue": (tent_blue, 3),
    "vlagstandaard_red": (vlagstandaard_red, 3), "vlagstandaard_blue": (vlagstandaard_blue, 3),
})
