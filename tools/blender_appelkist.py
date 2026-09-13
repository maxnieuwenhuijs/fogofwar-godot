"""Een low-poly appelkist, procedureel in Blender (13 september, Max: "kan jij
met blender dit maken, zo low poly mogelijk?" bij een plaatje van een houten
krat met gefacetteerde appels).

    blender --background --python tools/blender_appelkist.py -- \
        --uit results/appelkist/appelkist.glb [--appels 12] [--seed 3] [--textuur 256]

Wat er uit komt: EEN mesh met EEN materiaal (een draw call), platte facetten
(geen smooth shading: dat is de hele low-poly look), en een klein
textuurplaatje met vier vakken: houtnerf, rode appel, groene appel en
donker (stelen en spijkerkoppen). Alles is bmesh-primitieven: twaalf planken
met kieren, vier hoekpalen erachter, een bodem, een schuine lat op de
voorkant (glTF +Z, naar de speler), spijkerkoppen als vierzijdige piramides,
en de appels als icosferen met twee subdivisies (80 driehoeken per appel) met
een steeltje. Ongeveer 1.400 driehoeken, meest appels; `--appels 9` scheelt
er 250.

Daarna in het spel: `python tools/verwerk_prop.py results/appelkist/appelkist.glb appelkist`
(slankt niets meer af, plaatst hem als prop_appelkist.glb, importeert en
draait de omgevingcheck).
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
UIT = "results/appelkist/appelkist.glb"
APPELS = 12
SEED = 3
TEX = 256
GEEN_PREVIEW = False
i = 0
while i < len(argv):
    if argv[i] == "--uit":
        i += 1
        UIT = argv[i]
    elif argv[i] == "--appels":
        i += 1
        APPELS = int(argv[i])
    elif argv[i] == "--seed":
        i += 1
        SEED = int(argv[i])
    elif argv[i] == "--textuur":
        i += 1
        TEX = int(argv[i])
    elif argv[i] == "--geen-preview":
        GEEN_PREVIEW = True
    i += 1

rng = np.random.default_rng(SEED)
# lege scene VOOR het bouwen: een reset daarna gooit de mesh en het object weg
bpy.ops.wm.read_factory_settings(use_empty=True)
UIT = os.path.abspath(UIT)
os.makedirs(os.path.dirname(UIT), exist_ok=True)
BASIS = os.path.splitext(UIT)[0]

# --------------------------------------------------------------- maten (bord-eenheden, Z omhoog in Blender)
BREED = 0.50     # x
DIEP = 0.36      # y
HOOG = 0.28      # z, de bovenrand
PLANK_D = 0.025  # dikte
PLANK_H = 0.062  # hoogte van een plank
PLANK_Z = [0.045, 0.135, 0.225]   # middens van de drie planken
PAAL = 0.03
APPEL_R = 0.052

# --------------------------------------------------------------- textuur: vier vakken
# hout boven (v 0.5..1), rode appel linksonder, groene appel rechtsonder,
# en een donker strookje onderaan voor stelen (links) en spijkers (rechts)
W = H = TEX
img = np.zeros((H, W, 3), np.float32)


def waardenoise(h, w, cel, seed):
    r = np.random.default_rng(seed)
    gh, gw = h // cel + 2, w // cel + 2
    g = r.random((gh, gw)).astype(np.float32)
    ys = np.arange(h) / cel
    xs = np.arange(w) / cel
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


# hout: nerf langs u (horizontaal), lichte en donkere banen, wat vlekken
hh = H // 2
yy = np.arange(hh)[:, None].astype(np.float32)
xx = np.arange(W)[None, :].astype(np.float32)
nerf = np.sin(2 * math.pi * (yy / 9.0 + 0.9 * waardenoise(hh, W, 24, SEED + 1) + 0.15 * waardenoise(hh, W, 6, SEED + 2)))
nerf = 0.5 + 0.5 * nerf
fijn = waardenoise(hh, W, 3, SEED + 3)
licht = 0.72 + 0.22 * nerf + 0.12 * (fijn - 0.5) + 0.1 * (waardenoise(hh, W, 40, SEED + 4) - 0.5)
hout_basis = np.array([0.50, 0.36, 0.22], np.float32)
hout = hout_basis[None, None, :] * licht[:, :, None]
# een handvol donkere nerflijnen
for k in range(7):
    y = int(rng.integers(2, hh - 2))
    hout[y, :, :] *= 0.72 + 0.1 * waardenoise(1, W, 20, SEED + 10 + k)[0][:, None]
img[hh:, :, :] = np.clip(hout, 0, 1)

# appels: verticaal verloop (boven licht, onder donker) met wat vlekjes
qh = H // 4
vy = np.linspace(1.0, 0.0, qh)[:, None]
vlek = waardenoise(qh, W // 2, 8, SEED + 20)
rood_boven = np.array([0.90, 0.36, 0.26], np.float32)
rood_onder = np.array([0.55, 0.10, 0.10], np.float32)
rood = np.broadcast_to(rood_boven[None, None, :] * vy[:, :, None] + rood_onder[None, None, :] * (1 - vy)[:, :, None], (qh, W // 2, 3)).copy()
rood[:, :, 1] += 0.12 * (vlek - 0.5)          # oranje-rode variatie
img[qh:2 * qh, : W // 2, :] = np.clip(rood, 0, 1)
groen_boven = np.array([0.80, 0.82, 0.34], np.float32)
groen_onder = np.array([0.50, 0.56, 0.16], np.float32)
groen = np.broadcast_to(groen_boven[None, None, :] * vy[:, :, None] + groen_onder[None, None, :] * (1 - vy)[:, :, None], (qh, W // 2, 3)).copy()
groen[:, :, 0] += 0.1 * (vlek - 0.5)
img[qh:2 * qh, W // 2:, :] = np.clip(groen, 0, 1)
# donker: stelen links, spijkers rechts
img[:qh, : W // 2, :] = np.array([0.26, 0.17, 0.10], np.float32)
img[:qh, W // 2:, :] = np.array([0.17, 0.16, 0.17], np.float32)

# regio's in uv (u 0..1 van links, v 0..1 van ONDER, zoals Blender)
REG_HOUT = (0.0, 0.5, 1.0, 1.0)
REG_ROOD = (0.0, 0.25, 0.5, 0.5)
REG_GROEN = (0.5, 0.25, 1.0, 0.5)
REG_STEEL = (0.02, 0.02, 0.48, 0.23)
REG_SPIJKER = (0.52, 0.02, 0.98, 0.23)

# --------------------------------------------------------------- bmesh-bouwstenen
bm = bmesh.new()
uv_laag = bm.loops.layers.uv.new("UVMap")


def _in_regio(regio, u, v):
    u0, v0, u1, v1 = regio
    return (u0 + (u1 - u0) * min(max(u, 0.0), 1.0), v0 + (v1 - v0) * min(max(v, 0.0), 1.0))


def uv_plat(faces, regio, per_eenheid, u_off=0.0, v_off=0.0):
    """Platte projectie per vlak langs zijn grootste normaalas, `per_eenheid`
    = welk deel van de regio een bord-eenheid beslaat; met een offset per
    stuk zodat niet elke plank dezelfde nerf toont."""
    for f in faces:
        n = f.normal
        ax = max(range(3), key=lambda k: abs(n[k]))
        a, b = [k for k in range(3) if k != ax]
        for lp in f.loops:
            co = lp.vert.co
            u = (co[a] * per_eenheid + u_off) % 1.0
            v = (co[b] * per_eenheid + v_off) % 1.0
            lp[uv_laag].uv = _in_regio(regio, u, v)


def box(maat, pos, rot=None):
    r = bmesh.ops.create_cube(bm, size=1.0)
    verts = r["verts"]
    m = Matrix.Translation(Vector(pos))
    if rot is not None:
        m = m @ rot
    m = m @ Matrix.Diagonal(Vector(maat).to_4d())
    bmesh.ops.transform(bm, matrix=m, verts=verts)
    faces = list({f for v in verts for f in v.link_faces})
    return faces


def piramide(r, h, pos, richting):
    """Spijkerkop: vierzijdige piramide (geen bodem) met de punt langs `richting`."""
    res = bmesh.ops.create_cone(bm, cap_ends=False, cap_tris=False, segments=4, radius1=r, radius2=0.0, depth=h)
    verts = res["verts"]
    kw = Vector((0, 0, 1)).rotation_difference(Vector(richting).normalized())
    m = Matrix.Translation(Vector(pos) + Vector(richting).normalized() * (h * 0.5)) @ kw.to_matrix().to_4x4() @ Matrix.Rotation(math.pi / 4, 4, "Z")
    bmesh.ops.transform(bm, matrix=m, verts=verts)
    faces = list({f for v in verts for f in v.link_faces})
    for f in faces:
        for lp in f.loops:
            lp[uv_laag].uv = _in_regio(REG_SPIJKER, 0.5, 0.5)
    return faces


def appel(pos, r, regio):
    res = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    verts = res["verts"]
    m = Matrix.Translation(Vector(pos)) @ Matrix.Diagonal(Vector((1.0, 1.0, 0.9)).to_4d()) @ Matrix.Rotation(rng.uniform(0, math.pi), 4, "Z")
    bmesh.ops.transform(bm, matrix=m, verts=verts)
    faces = list({f for v in verts for f in v.link_faces})
    for f in faces:
        for lp in f.loops:
            co = lp.vert.co - Vector(pos)
            lp[uv_laag].uv = _in_regio(regio, 0.5 + 0.42 * co.x / r, 0.5 + 0.45 * co.z / (r * 0.9))
    # steeltje: een dun scheef blokje bovenop
    kant = rng.uniform(-0.35, 0.35)
    st = box((0.009, 0.009, 0.034), (pos[0], pos[1], pos[2] + r * 0.9 + 0.012),
             Matrix.Rotation(kant, 4, "Y") @ Matrix.Rotation(rng.uniform(-0.3, 0.3), 4, "X"))
    for f in st:
        for lp in f.loops:
            lp[uv_laag].uv = _in_regio(REG_STEEL, 0.5, 0.5)
    return faces


# --------------------------------------------------------------- het krat
# hoekpalen (binnen de planken)
for sx in (-1, 1):
    for sy in (-1, 1):
        f = box((PAAL, PAAL, HOOG - 0.02), (sx * (BREED / 2 - PLANK_D - PAAL / 2), sy * (DIEP / 2 - PLANK_D - PAAL / 2), (HOOG - 0.02) / 2 + 0.01))
        uv_plat(f, REG_HOUT, 1.6, rng.uniform(0, 1), rng.uniform(0, 1))
# bodem
f = box((BREED - 2 * PLANK_D, DIEP - 2 * PLANK_D, 0.02), (0.0, 0.0, 0.02))
uv_plat(f, REG_HOUT, 1.6, 0.2, 0.7)
# lange planken (voor en achter, y) met spijkers aan beide einden
for sy in (-1, 1):
    for z in PLANK_Z:
        f = box((BREED, PLANK_D, PLANK_H), (0.0, sy * (DIEP / 2 - PLANK_D / 2), z))
        uv_plat(f, REG_HOUT, 1.6, rng.uniform(0, 1), rng.uniform(0, 1))
        for sx in (-1, 1):
            piramide(0.013, 0.011, (sx * (BREED / 2 - 0.04), sy * DIEP / 2, z + 0.004), (0, sy, 0))
# korte planken (links en rechts, x), tussen de lange
for sx in (-1, 1):
    for z in PLANK_Z:
        f = box((PLANK_D, DIEP - 2 * PLANK_D, PLANK_H), (sx * (BREED / 2 - PLANK_D / 2), 0.0, z))
        uv_plat(f, REG_HOUT, 1.6, rng.uniform(0, 1), rng.uniform(0, 1))
        for sy in (-1, 1):
            piramide(0.013, 0.011, (sx * BREED / 2, sy * (DIEP / 2 - PLANK_D - 0.035), z + 0.004), (sx, 0, 0))
# de schuine lat op de voorkant (-Y = glTF +Z, naar de speler), van linksonder naar rechtsboven
hoek = math.atan2(PLANK_Z[-1] - PLANK_Z[0] + 0.02, BREED - 0.06)
lat_l = math.hypot(BREED - 0.02, PLANK_Z[-1] - PLANK_Z[0] + 0.02)
lat_y = -(DIEP / 2 + PLANK_D / 2 + 0.002)
f = box((lat_l, 0.018, PLANK_H * 0.9), (0.0, lat_y, (PLANK_Z[0] + PLANK_Z[-1]) / 2), Matrix.Rotation(-hoek, 4, "Y"))
uv_plat(f, REG_HOUT, 1.6, 0.6, 0.3)
for s in (-1, 1):
    px = s * (lat_l / 2 - 0.035) * math.cos(hoek)
    pz = (PLANK_Z[0] + PLANK_Z[-1]) / 2 + s * (lat_l / 2 - 0.035) * math.sin(hoek)
    piramide(0.014, 0.012, (px, lat_y - 0.009, pz), (0, -1, 0))

# --------------------------------------------------------------- de appels
kolommen = 4 if APPELS >= 10 else 3
rijen = max(1, int(round(APPELS / kolommen)))
xs = np.linspace(-(BREED / 2 - PLANK_D - APPEL_R - 0.02), BREED / 2 - PLANK_D - APPEL_R - 0.02, kolommen)
ys = np.linspace(-(DIEP / 2 - PLANK_D - APPEL_R - 0.015), DIEP / 2 - PLANK_D - APPEL_R - 0.015, rijen)
n_app = 0
plekken = [(x, y) for y in ys for x in xs]
rng.shuffle(plekken)
for (x, y) in plekken[:APPELS]:
    jx = rng.uniform(-0.008, 0.008)
    jy = rng.uniform(-0.008, 0.008)
    z = HOOG - APPEL_R * 0.9 + rng.uniform(-0.012, 0.014)
    regio = REG_ROOD if rng.random() < 0.62 else REG_GROEN
    appel((float(x + jx), float(y + jy), float(z)), APPEL_R * rng.uniform(0.92, 1.06), regio)
    n_app += 1

# --------------------------------------------------------------- mesh, materiaal, plaatje
bm.normal_update()
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new("prop_appelkist")
bm.to_mesh(me)
bm.free()
for p in me.polygons:
    p.use_smooth = False
ob = bpy.data.objects.new("prop_appelkist", me)
bpy.context.scene.collection.objects.link(ob)

# het plaatje naar png (naast de glb; de export bakt hem in de glb)
png = BASIS + "_kleur.png"
im = bpy.data.images.new("kleur", W, H, alpha=False)
rgba = np.ones((H, W, 4), np.float32)
rgba[:, :, :3] = img
im.pixels.foreach_set(rgba.ravel())
im.filepath_raw = png
im.file_format = "PNG"
im.save()
# canary: teruglezen, niet zwart (bpy-valkuil: nooit colorspace_settings aanraken na foreach_set)
terug = np.zeros(W * H * 4, np.float32)
im.pixels.foreach_get(terug)
if terug[0::4].mean() < 0.05:
    print("FOUT: het plaatje is zwart")
    sys.exit(1)

mat = bpy.data.materials.new("appelkist")
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Roughness"].default_value = 0.85
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = im
tex.interpolation = "Closest"
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
me.materials.append(mat)

me.calc_loop_triangles()
print("appelkist: %d appels, %d vlakken, %d driehoeken, %d vertices, plaatje %dx%d" % (
    n_app, len(me.polygons), len(me.loop_triangles), len(me.vertices), W, H))

# --------------------------------------------------------------- export
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.export_scene.gltf(filepath=UIT, export_format="GLB", use_selection=True,
                          export_image_format="AUTO", export_apply=True, export_yup=True)
print("glb -> %s (%.0f kB)" % (UIT, os.path.getsize(UIT) / 1024.0))
