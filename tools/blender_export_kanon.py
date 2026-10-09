# Kanon-export (9 oktober 2026): van een kanon-blend naar een spel-klaar
# artilleriemodel.
#
#   blender --background "lion Atk.blend" --python tools/blender_export_kanon.py -- \
#       --uit assets/models/lion/artillery/artillery_atk.glb
#   blender --background "lion Atk.blend" --python tools/blender_export_kanon.py -- \
#       --retexture "assets/new upload folder/lion/canon_atk/lion_artillery_atk.glb"
#
# Een kanon-blend (de eerste: de vijf Leeuw-kanonnen van 16 september) heeft
# TWEE rigs: het kanon (Bone, Bone.001 ..., wielen en loop aan botten, de affuit
# geskind) en de bediener, een Mixamo-karakter met een IK-besturingsrig (126
# botten, waarvan 41 mixamorig-deform; de acties keyen ALLEEN de Ctrl_-botten).
# De karakterpijplijn (blender_export_blend + merge_character) gaat uit van een
# rig en van tripo_node = het wapen; hier heet alles tripo_node, ook de leeuw.
# Daarom een eigen export, die op RIG indeelt in plaats van op naam.
#
# Wat hij schrijft (standaard, --uit <map>/artillery_<arch>.glb):
#   artillery_<arch>.glb         kanon + bediener met clips die beide skeletten
#                                tegelijk bewegen: attack (vuren: de bediener ontsteekt,
#                                het kanon slaat terug), walk1/walk2 (duwen, de wielen
#                                een slag per duwcyclus), idle1/idle2 (kanon stil).
#                                Namen die het spel al kent; andere acties van de
#                                bediener gaan mee onder hun eigen naam.
#   artillery_<arch>_cannon.glb  alleen het kanon, statisch: de kanonjas
#                                (<..._cannon>_red.png / _blue.png) hoort daarbij en
#                                uv_check meet hem ertegen.
#   artillery_<arch>_gibs.glb    de brokstukken: het kanon in onderdelen (Kanon_Loop,
#                                Kanon_Affuit, Kanon_Wiel.L ...) en de bediener in de
#                                delen van de infanterie (Hat, Head, Body, Arm.L,
#                                Forarm.L, Upleg.L, Leg.L ...), op de botten geknipt.
# Met --retexture <naam>.glb: de uploads voor de retexture-dienst, kaal en in
# rusthouding: <naam>.glb (de bediener) en <naam>_wapen.glb (het kanon).
#
# Hoe de clips samengaan: per clip een NLA-spoor met DEZELFDE naam op beide
# rigs; de exporter (NLA_TRACKS, samenvoegen op spoornaam) maakt er een
# animatie van met de kanalen van allebei. Alleen deform-botten
# (export_def_bones): de besturingsrig wordt per frame bemonsterd en ingebakken.
# fps: alles op --fps (standaard 30; de blends staan op 24 of 30 met dezelfde
# keyframes, Mixamo levert 30). De blend zelf wordt NOOIT opgeslagen.
import bmesh
import bpy
import json
import math
import os
import struct
import sys
from mathutils import Matrix, Vector

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import blender_botkind_fix  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
UIT = None
RETEXTURE = None
FPS = 30
for i, a in enumerate(argv):
    if a == "--uit" and i + 1 < len(argv):
        UIT = argv[i + 1]
    elif a == "--retexture" and i + 1 < len(argv):
        RETEXTURE = argv[i + 1]
    elif a == "--fps" and i + 1 < len(argv):
        FPS = int(argv[i + 1])
if not UIT and not RETEXTURE:
    print("FOUT: geef --uit <pad.glb> of --retexture <pad.glb> mee")
    sys.exit(1)

sc = bpy.context.scene


# --- 1. Opruimen en indelen ---------------------------------------------------

def ruim_op():
    """De vormpjes van de besturingsrig (cs_*), losse objecten buiten de scene
    (een Mixamo-import die achterbleef) en lege meshes eruit."""
    weg = []
    for o in list(bpy.data.objects):
        if o.name.startswith("cs_"):
            weg.append(o.name)
            bpy.data.objects.remove(o, do_unlink=True)
    for o in list(bpy.data.objects):
        if o.name not in sc.objects:
            weg.append(o.name + " (buiten de scene)")
            bpy.data.objects.remove(o, do_unlink=True)
    for o in list(sc.objects):
        if o.type == "MESH" and len(o.data.vertices) == 0:
            weg.append(o.name + " (leeg)")
            bpy.data.objects.remove(o, do_unlink=True)
    print("  opgeruimd: %d objecten (cs_-vormpjes %d)" % (len(weg), len([w for w in weg if w.startswith("cs_")])))
    for w in weg:
        if not w.startswith("cs_"):
            print("    weg: %s" % w)


def vind_rigs():
    arms = [o for o in sc.objects if o.type == "ARMATURE"]
    crew = [o for o in arms if any(b.name.startswith("mixamorig") for b in o.data.bones)]
    kanon = [o for o in arms if o not in crew]
    if len(crew) != 1 or len(kanon) != 1:
        print("FOUT: verwacht precies een bediener-rig (mixamorig) en een kanon-rig; gevonden %d en %d (%s)"
              % (len(crew), len(kanon), [o.name for o in arms]))
        sys.exit(1)
    return crew[0], kanon[0]


def rig_van(o):
    if o.parent is not None and o.parent.type == "ARMATURE":
        return o.parent
    for m in o.modifiers:
        if m.type == "ARMATURE" and m.object is not None:
            return m.object
    return None


def is_geskind(o, rig):
    """Geskind = armature-modifier met vertexgroepen die echt botten van de rig zijn.
    (Een kanondeel in de spd heeft een modifier zonder groepen en hangt aan een bot.)"""
    if not any(m.type == "ARMATURE" and m.object == rig for m in o.modifiers):
        return False
    botten = {b.name for b in rig.data.bones}
    return any(g.name in botten for g in o.vertex_groups)


def fcurves_van(act):
    uit = []
    for layer in act.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                uit.extend(cb.fcurves)
    return uit


def bot_van_pad(pad):
    return pad.split('"')[1] if pad.startswith('pose.bones["') else None


def deel_acties_in(crew, kanon):
    """{crew: [...], kanon: [...]} op welke rig de botten van de actie passen."""
    cb = {b.name for b in crew.data.bones}
    kb = {b.name for b in kanon.data.bones}
    uit = {"crew": [], "kanon": []}
    for act in bpy.data.actions:
        botten = {bot_van_pad(fc.data_path) for fc in fcurves_van(act)} - {None}
        n_c = len(botten & cb)
        n_k = len(botten & kb)
        if n_c == 0 and n_k == 0:
            print("  actie overgeslagen (past op geen rig): %s" % act.name)
            continue
        uit["crew" if n_c >= n_k else "kanon"].append(act)
    return uit


def rol(naam):
    n = naam.lower()
    if "idle" in n:
        return "idle"
    if "fir" in n or "shoot" in n or "shot" in n:
        return "vuur"
    if "push" in n or "walk" in n or "mov" in n or "roll" in n:
        return "beweeg"
    return "overig"


def cyclus(act):
    return max(1.0, act.frame_range[1] - act.frame_range[0])


def kanaalbereik(act, bot):
    """Grootste uitslag van een bot in een actie (rotatie in radialen, locatie in eenheden)."""
    m = 0.0
    for fc in fcurves_van(act):
        if bot_van_pad(fc.data_path) != bot or fc.data_path.endswith("scale"):
            continue
        v = [k.co[1] for k in fc.keyframe_points]
        if v:
            m = max(m, max(v) - min(v))
    return m


# --- 2. Clips -----------------------------------------------------------------

def kanon_rust(kanon, vuur):
    """Een actie die het kanon stil houdt: de stand van frame 1 van het vuren
    (de wielen staan daar anders dan in de rust-pose van de rig)."""
    act = bpy.data.actions.new("kanon_rust")
    ad = kanon.animation_data or kanon.animation_data_create()
    if vuur is not None:
        ad.action = vuur
        try:
            ad.action_slot = vuur.slots[0]
        except Exception:
            pass
    sc.frame_set(int(vuur.frame_range[0]) if vuur is not None else 1)
    bpy.context.view_layer.update()
    staat = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.rotation_euler.copy(), pb.rotation_mode)
             for pb in kanon.pose.bones}
    ad.action = act
    for pb in kanon.pose.bones:
        loc, quat, eul, mode = staat[pb.name]
        pb.location = loc
        pb.keyframe_insert("location", frame=1)
        if mode == "QUATERNION":
            pb.rotation_quaternion = quat
            pb.keyframe_insert("rotation_quaternion", frame=1)
        else:
            pb.rotation_euler = eul
            pb.keyframe_insert("rotation_euler", frame=1)
    ad.action = None
    return act


def clips_bouwen(crew, kanon, acties):
    """[(clipnaam, bediener-actie, kanon-actie, schaal van de kanon-strip)]"""
    c_per = {"vuur": [], "beweeg": [], "idle": [], "overig": []}
    for a in sorted(acties["crew"], key=lambda x: x.name.lower()):
        c_per[rol(a.name)].append(a)
    k_vuur = next((a for a in acties["kanon"] if rol(a.name) == "vuur"), None)
    k_rij = next((a for a in acties["kanon"] if rol(a.name) == "beweeg"), None)
    rust = kanon_rust(kanon, k_vuur)
    clips = []
    for i, a in enumerate(c_per["vuur"]):
        clips.append(("attack" if i == 0 else "attack%d" % (i + 1), a, k_vuur or rust, None))
    for i, a in enumerate(c_per["beweeg"]):
        schaal = cyclus(a) / cyclus(k_rij) if k_rij is not None else None
        clips.append(("walk%d" % (i + 1), a, k_rij or rust, schaal))
    for i, a in enumerate(c_per["idle"]):
        clips.append(("idle%d" % (i + 1), a, rust, None))
    for a in c_per["overig"]:
        naam = "".join(c if c.isalnum() else "_" for c in a.name).strip("_") or "clip"
        clips.append((naam, a, rust, None))
    if not c_per["vuur"] and k_vuur is not None:
        print("  LET OP: geen vuur-actie voor de bediener; attack = alleen het kanon")
        clips.append(("attack", None, k_vuur, None))
    return clips


def zet_nla(crew, kanon, clips):
    for o in (crew, kanon):
        ad = o.animation_data or o.animation_data_create()
        ad.action = None
        for t in list(ad.nla_tracks):
            ad.nla_tracks.remove(t)

    def spoor(o, naam, act, schaal):
        tr = o.animation_data.nla_tracks.new()
        tr.name = naam
        st = tr.strips.new(naam, 1, act)
        if schaal:
            st.scale = schaal
        # Slot expliciet (Blender 4.4+/5): zonder speelt de strip niets af.
        try:
            if len(act.slots) > 0:
                st.action_slot = act.slots[0]
        except Exception as e:  # noqa
            print("  slot niet gezet op %s/%s: %s" % (o.name, naam, e))
        return st

    for naam, ca, ka, schaal in clips:
        regel = "  clip %-8s" % naam
        if ca is not None:
            s = spoor(crew, naam, ca, None)
            regel += " bediener %-15s %5.0f-%-5.0f" % (ca.name, s.frame_start, s.frame_end)
        if ka is not None:
            s = spoor(kanon, naam, ka, schaal)
            regel += " | kanon %-14s %5.0f-%-5.0f" % (ka.name, s.frame_start, s.frame_end)
        print(regel)


# --- 3. Rust, kopieen en knippen ----------------------------------------------

def rusthouding(crew, kanon, aan=True):
    for o in (crew, kanon):
        o.data.pose_position = "REST" if aan else "POSE"
    bpy.context.view_layer.update()


def kale_kopie(o, naam=None):
    """Statische kopie in de rusthouding: geen modifier, geen ouder, geen animatie;
    de wereldstand blijft (de armature moet op REST staan)."""
    mw = o.matrix_world.copy()
    k = o.copy()
    k.data = o.data.copy()
    k.animation_data_clear()
    sc.collection.objects.link(k)
    for m in list(k.modifiers):
        if m.type == "ARMATURE":
            k.modifiers.remove(m)
    k.parent = None
    k.matrix_world = mw
    if naam:
        k.name = naam
        k.data.name = naam
    return k


def dominante_groep(o):
    """Per vertex de naam van de groep met het grootste gewicht (of None)."""
    namen = {g.index: g.name for g in o.vertex_groups}
    uit = []
    for v in o.data.vertices:
        if v.groups:
            g = max(v.groups, key=lambda x: x.weight)
            uit.append(namen.get(g.group))
        else:
            uit.append(None)
    return uit


def knip(o, face_deel, naam_prefix=""):
    """Knip o in losse objecten, een per deel (face_deel[i] = deel van vlak i).
    Het origin van elk deel komt in zijn midden: dan tolt een brok om zichzelf
    en vliegt hij van het midden van het stuk weg."""
    delen = []
    for deel in sorted(set(face_deel)):
        k = o.copy()
        k.data = o.data.copy()
        sc.collection.objects.link(k)
        bm = bmesh.new()
        bm.from_mesh(k.data)
        bm.faces.ensure_lookup_table()
        weg = [f for f in bm.faces if face_deel[f.index] != deel]
        if weg:
            bmesh.ops.delete(bm, geom=weg, context="FACES")
        bm.to_mesh(k.data)
        bm.free()
        if len(k.data.polygons) == 0:
            bpy.data.objects.remove(k, do_unlink=True)
            continue
        k.name = naam_prefix + deel
        k.data.name = k.name
        zet_origin_midden(k)
        delen.append(k)
    bpy.data.objects.remove(o, do_unlink=True)
    return delen


def zet_origin_midden(o):
    mw = o.matrix_world.copy()
    vs = [v.co for v in o.data.vertices]
    if not vs:
        return
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    mid = (lo + hi) / 2
    o.data.transform(Matrix.Translation(-mid))
    o.matrix_world = mw @ Matrix.Translation(mid)


# Bediener: mixamorig-bot -> deel (dezelfde namen als de infanterie-gibs).
def lijfdeel(bot):
    if bot is None:
        return "Body"
    b = bot.split(":")[-1].lower()
    zijde = ".L" if b.startswith("left") else (".R" if b.startswith("right") else "")
    if b in ("head", "headtop_end", "neck"):
        return "Head"
    if "forearm" in b or "hand" in b:
        return "Forarm" + zijde
    if "shoulder" in b or b.endswith("arm"):
        return "Arm" + zijde
    if "upleg" in b:
        return "Upleg" + zijde
    if b.endswith("leg") or "foot" in b or "toe" in b:
        return "Leg" + zijde
    return "Body"


def kleur_lezer(o):
    """Helderheid op een UV-plek uit de kleurtextuur van het eerste materiaal (of None)."""
    try:
        import numpy as np
    except ImportError:
        return None
    img = None
    for m in o.data.materials:
        if m and m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > 0 and "normal" not in n.image.name.lower():
                    img = n.image
                    break
        if img:
            break
    if img is None:
        return None
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)

    def helder(u, v):
        x = min(w - 1, max(0, int((u % 1.0) * w)))
        y = min(h - 1, max(0, int((v % 1.0) * h)))
        r, g, b, _a = px[y, x]
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    return helder


def pose_coords(crew, kanon, mesh, act):
    """Vertexposities (mesh-ruimte) van de bediener in het eerste frame van `act`.
    De rust-pose van deze rig is een T-pose op een andere plek (op de affuit);
    in de idle staat hij naast het kanon. Daar moeten de brokken vandaan komen."""
    if act is None:
        return None
    rusthouding(crew, kanon, False)
    ad = crew.animation_data or crew.animation_data_create()
    oud = ad.action
    ad.action = act
    try:
        ad.action_slot = act.slots[0]
    except Exception:
        pass
    sc.frame_set(int(act.frame_range[0]))
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(dg)
    m = ev.to_mesh()
    coords = [v.co.copy() for v in m.vertices] if len(m.vertices) == len(mesh.data.vertices) else None
    ev.to_mesh_clear()
    ad.action = oud
    return coords


def knip_bediener(crew, mesh, coords=None):
    """De bediener in lijfdelen, met de muts los als die er duidelijk op zit.
    Indelen gebeurt op de rust-pose (de botten), de vorm komt uit `coords` (de idle)."""
    k = kale_kopie(mesh)
    groep = dominante_groep(k)
    mw = k.matrix_world
    deel_v = [lijfdeel(g) for g in groep]
    face_deel = []
    for p in k.data.polygons:
        tel = {}
        for vi in p.vertices:
            tel[deel_v[vi]] = tel.get(deel_v[vi], 0) + 1
        face_deel.append(max(tel.items(), key=lambda x: (x[1], x[0]))[0])
    # De muts: kop-vlakken boven het midden van het kopbot die donker zijn
    # (de berenmuts is zwart, het gezicht niet). Alleen als het een zinnig stuk is.
    kop = crew.data.bones.get("mixamorig:Head")
    if kop is not None:
        amw = crew.matrix_world
        z0 = (amw @ kop.head_local).z
        z1 = (amw @ kop.tail_local).z
        grens = z0 + 0.42 * (z1 - z0)
        helder = kleur_lezer(k)
        uv = k.data.uv_layers.active
        kop_n = sum(1 for d in face_deel if d == "Head")
        muts = []
        for p in k.data.polygons:
            if face_deel[p.index] != "Head":
                continue
            z = (mw @ p.center).z
            if z < grens:
                continue
            if helder is not None and uv is not None:
                u = sum(uv.data[li].uv[0] for li in p.loop_indices) / len(p.loop_indices)
                v = sum(uv.data[li].uv[1] for li in p.loop_indices) / len(p.loop_indices)
                if helder(u, v) > 0.18:
                    continue
            muts.append(p.index)
        if kop_n and 0.15 <= len(muts) / kop_n <= 0.75:
            for i in muts:
                face_deel[i] = "Hat"
            print("  muts los: %d van %d kop-vlakken" % (len(muts), kop_n))
        else:
            print("  geen losse muts (%d van %d kop-vlakken donker en hoog)" % (len(muts), kop_n))
    if coords is not None:
        # De kopie staat op de wereldplek van het origineel (ouder: de rig), dus de
        # geevalueerde mesh-ruimte past er een op een in.
        for v, c in zip(k.data.vertices, coords):
            v.co = c
    return knip(k, face_deel)


def kanon_rollen(kanon, k_rij):
    """Per bot van het kanon: Wiel, Loop of Affuit.
    Wiel = draait een hele slag in de rij-actie; Loop = het bot onder de wortel
    dat kinderen heeft (de loop-ketting) en alles daaronder; de rest = Affuit."""
    rollen = {}
    wortel = next((b for b in kanon.data.bones if b.parent is None), None)
    wielen = set()
    if k_rij is not None:
        for b in kanon.data.bones:
            if kanaalbereik(k_rij, b.name) > 3.0:
                wielen.add(b.name)
    for b in kanon.data.bones:
        if b.name in wielen:
            rollen[b.name] = "Wiel"
            continue
        r = "Affuit"
        p = b
        while p is not None and p.parent is not None:
            if p.parent == wortel and len(p.children) > 0 and p.name not in wielen:
                r = "Loop"
                break
            p = p.parent
        rollen[b.name] = r
    return rollen


def knip_kanon(kanon, meshes, rollen):
    """Het kanon in onderdelen: geskinde delen op de botten geknipt, bot-delen heel."""
    delen = []
    for o in meshes:
        if is_geskind(o, kanon):
            k = kale_kopie(o)
            groep = dominante_groep(k)
            rol_v = [rollen.get(g, "Affuit") for g in groep]
            face_deel = []
            for p in k.data.polygons:
                tel = {}
                for vi in p.vertices:
                    tel[rol_v[vi]] = tel.get(rol_v[vi], 0) + 1
                face_deel.append(max(tel.items(), key=lambda x: (x[1], x[0]))[0])
            delen += knip(k, face_deel, "Kanon_")
        else:
            r = rollen.get(o.parent_bone, "Affuit") if o.parent_type == "BONE" else "Affuit"
            k = kale_kopie(o, "Kanon_" + r)
            zet_origin_midden(k)
            delen.append(k)
    # Wielen links/rechts op hun plek (x in de ruimte van het kanon), de rest genummerd.
    inv = kanon.matrix_world.inverted()
    tel = {}
    for k in delen:
        basis = k.name.split(".")[0]
        if basis == "Kanon_Wiel":
            x = (inv @ k.matrix_world.translation).x
            basis = "Kanon_Wiel.L" if x > 0 else "Kanon_Wiel.R"
        tel[basis] = tel.get(basis, 0) + 1
        k.name = basis if tel[basis] == 1 else "%s.%03d" % (basis, tel[basis] - 1)
        k.data.name = k.name
    return delen


# --- 4. Export ------------------------------------------------------------------

def verklein_texturen():
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    for img in bpy.data.images:
        if img.size[0] > 1024 or img.size[1] > 1024:
            img.scale(min(img.size[0], 1024), min(img.size[1], 1024))
            print("  textuur verkleind: %s -> %dx%d" % (img.name, img.size[0], img.size[1]))


def exporteer_statisch(objecten, pad, samen=False):
    if samen and len(objecten) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for o in objecten:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objecten[0]
        bpy.ops.object.join()
        objecten = [bpy.context.view_layer.objects.active]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objecten:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objecten[0]
    os.makedirs(os.path.dirname(os.path.abspath(pad)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(pad), export_format="GLB", use_selection=True,
                              export_skins=False, export_animations=False,
                              export_image_format="JPEG", export_jpeg_quality=85)
    tris = 0
    for o in objecten:
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
    return objecten, tris


def lees_glb(pad):
    with open(pad, "rb") as f:
        data = f.read()
    n = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + n].decode("utf-8"))


def node_wereld(js):
    """Wereldmatrix per node-index uit de TRS-hierarchie van een glb."""
    nodes = js["nodes"]
    ouder = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            ouder[c] = i

    def lokaal(n):
        if "matrix" in n:
            m = n["matrix"]
            return Matrix([[m[0], m[4], m[8], m[12]], [m[1], m[5], m[9], m[13]],
                           [m[2], m[6], m[10], m[14]], [m[3], m[7], m[11], m[15]]])
        t = n.get("translation", [0, 0, 0])
        r = n.get("rotation", [0, 0, 0, 1])
        s = n.get("scale", [1, 1, 1])
        from mathutils import Quaternion
        return (Matrix.Translation(Vector(t)) @ Quaternion((r[3], r[0], r[1], r[2])).to_matrix().to_4x4()
                @ Matrix.Diagonal(Vector((s[0], s[1], s[2], 1.0))))
    cache = {}

    def wereld(i):
        if i not in cache:
            cache[i] = (wereld(ouder[i]) @ lokaal(nodes[i])) if i in ouder else lokaal(nodes[i])
        return cache[i]
    return {i: wereld(i) for i in range(len(nodes))}


def controleer_botdelen(pad, objecten, crew, kanon):
    """Staan de bot-geparente kanondelen in de glb waar ze in Blender staan?
    Vergelijkt in de rusthouding (de joints van de glb staan in rust)."""
    rusthouding(crew, kanon, True)
    js = lees_glb(pad)
    wereld = node_wereld(js)
    op_naam = {n.get("name"): i for i, n in enumerate(js["nodes"])}
    slechtst = 0.0
    for o in objecten:
        if o.parent_type != "BONE" or o.name not in op_naam:
            continue
        b = o.matrix_world.translation
        verwacht = Vector((b.x, b.z, -b.y))   # Blender Z-op -> glTF Y-op
        echt = wereld[op_naam[o.name]].translation
        slechtst = max(slechtst, (verwacht - echt).length)
    rusthouding(crew, kanon, False)
    return slechtst


def exporteer_model(pad, crew, kanon, meshes_kanon):
    bot_delen = [o for o in meshes_kanon if o.parent_type == "BONE"]
    # Parent-inverse inbakken (zie blender_export_blend.py): de exporter laat hem
    # bij bot-kinderen weg.
    for o in bot_delen:
        mw = o.matrix_world.copy()
        o.matrix_parent_inverse.identity()
        o.matrix_world = mw
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="SELECT")
    os.makedirs(os.path.dirname(os.path.abspath(pad)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(pad), export_format="GLB",
        export_animation_mode="NLA_TRACKS", export_merge_animation="NLA_TRACK",
        export_def_bones=True, export_force_sampling=True, export_anim_slide_to_zero=True,
        export_image_format="JPEG", export_jpeg_quality=85)
    # Bot-kind-fix (Blender 5.1 zet bot-kinderen naast hun bot), dan nameten.
    blender_botkind_fix.fix_glb(os.path.abspath(pad), bot_delen, kanon)
    fout = controleer_botdelen(pad, bot_delen, crew, kanon)
    print("  bot-delen op hun plek: grootste afwijking %.4f %s" % (fout, "(OK)" if fout < 0.002 else "(FOUT)"))
    return fout < 0.002


def main():
    print("KANON-EXPORT: %s" % bpy.data.filepath)
    ruim_op()
    crew, kanon = vind_rigs()
    meshes = [o for o in sc.objects if o.type == "MESH"]
    m_crew = [o for o in meshes if rig_van(o) == crew]
    m_kanon = [o for o in meshes if rig_van(o) == kanon]
    los = [o for o in meshes if o not in m_crew and o not in m_kanon]
    print("  bediener: %s (%d botten, %d deform), %d mesh(es)" % (
        crew.name, len(crew.data.bones), len([b for b in crew.data.bones if b.use_deform]), len(m_crew)))
    print("  kanon: %s (%d botten), %d mesh(es)" % (kanon.name, len(kanon.data.bones), len(m_kanon)))
    for o in los:
        print("  LET OP: mesh zonder rig, telt als kanon: %s" % o.name)
        m_kanon.append(o)
    if not m_crew or not m_kanon:
        print("FOUT: geen bediener of geen kanon gevonden")
        sys.exit(1)
    print("  fps: %s -> %d" % (sc.render.fps, FPS))
    sc.render.fps = FPS
    sc.render.fps_base = 1.0

    acties = deel_acties_in(crew, kanon)
    k_rij = next((a for a in acties["kanon"] if rol(a.name) == "beweeg"), None)

    if RETEXTURE:
        verklein_texturen()
        rusthouding(crew, kanon, True)
        lijf = [kale_kopie(o) for o in m_crew]
        lijf, tris = exporteer_statisch(lijf, RETEXTURE, samen=True)
        print("RETEXTURE -> %s (%d object(en), %d driehoeken, de bediener)" % (RETEXTURE, len(lijf), tris))
        wpad = os.path.splitext(RETEXTURE)[0] + "_wapen.glb"
        kn = [kale_kopie(o) for o in m_kanon]
        kn, tris = exporteer_statisch(kn, wpad, samen=True)
        print("MUSKET -> %s (%d object(en), %d driehoeken, het kanon)" % (wpad, len(kn), tris))
        return

    # De idle-houding van de bediener vastleggen VOOR de NLA-sporen erop staan
    # (daarna mengen de sporen in elk frame).
    idle = next((a for a in sorted(acties["crew"], key=lambda x: x.name.lower()) if rol(a.name) == "idle"), None)
    houding = {o.name: pose_coords(crew, kanon, o, idle) for o in m_crew}
    clips = clips_bouwen(crew, kanon, acties)
    zet_nla(crew, kanon, clips)
    verklein_texturen()
    ok = exporteer_model(UIT, crew, kanon, m_kanon)
    print("MODEL -> %s (%d clips)" % (UIT, len(clips)))

    # Het kanon los (statisch): de kanonjas en uv_check horen daarbij.
    rusthouding(crew, kanon, True)
    stam = os.path.splitext(UIT)[0]
    kn = [kale_kopie(o) for o in m_kanon]
    kn, tris = exporteer_statisch(kn, stam + "_cannon.glb", samen=True)
    print("KANON -> %s (%d driehoeken)" % (stam + "_cannon.glb", tris))
    for o in kn:
        bpy.data.objects.remove(o, do_unlink=True)

    # Gibs: het kanon in onderdelen, de bediener in lijfdelen.
    rollen = kanon_rollen(kanon, k_rij)
    print("  kanon-botten: %s" % ", ".join("%s=%s" % (b, r) for b, r in sorted(rollen.items())))
    delen = knip_kanon(kanon, m_kanon, rollen)
    for m in m_crew:
        delen += knip_bediener(crew, m, houding.get(m.name))
    _, tris = exporteer_statisch(delen, stam + "_gibs.glb")
    print("GIBS -> %s (%d delen: %s)" % (stam + "_gibs.glb", len(delen), ", ".join(sorted(d.name for d in delen))))
    if not ok:
        print("FOUT: bot-delen staan niet op hun plek in de glb")
        sys.exit(1)
    print("KLAAR")


main()
