"""Bot-kind-fix voor glb-exports (3 september 2026).

Bevinding: de glTF-exporter van Blender 5.1 schrijft voor een object dat aan
een BOT geparent is (het ingebakken wapen aan mixamorig:RightHand) de X en Z
goed, maar telt bij Y de botlengte GEDEELD DOOR de armature-schaal op in
plaats van de botlengte zelf. Met een Mixamo-rig op schaal 0,009 is dat
4,4 / 0,009 = 490 armature-eenheden: het wapen komt meters van de hand af te
staan en zweeft over het bord (alle cavalerie en de beer/krokodil/wolf-
infanterie). In Blender zelf staat het wapen gewoon in de hand.

Oplossing: na de export de TRANSLATIE van de wapen-node in de glb overschrijven
met de plek die Blender ZELF ziet, relatief aan de bot-kop in de huidige pose.
Godot hangt de node aan het bewegende bot en het wapen volgt de hand.

LET OP -- rotatie en schaal blijven van de exporter (bijstelling 7 september).
Tot die datum overschreef dit script ook de rotatie, met de matrix uit Blender's
BOT-ruimte. Die ruimte heeft +Y langs het bot en is niet de joint-ruimte van
glTF; het verschil is precies 90 graden om X. Gemeten op infantry_mix en
mouse_cavalry_atk:

    exporter :  translation [3.4617, 17.7872, 0.6005]  euler [ -38.6, 80.5, -39.5]
    oude fix :  translation [3.4617, 17.7872, 0.6005]  euler [-128.6, 80.5, -39.5]

De translatie was in beide bestanden AL gelijk -- de fix corrigeerde daar dus
niets -- en de rotatie werd 90 graden gekanteld. Het musket hing op de goede
plek met de bajonet omlaag. Schrijf hier nooit meer een Blender-bot-matrix
rechtstreeks in een glTF-node zonder de bot-as-conversie.

Gebruik vanuit een Blender-script, NA bpy.ops.export_scene.gltf:
    import blender_botkind_fix
    blender_botkind_fix.fix_glb(pad, [wapenobjecten], armature)

De IMPORTER van Blender 5.1 heeft dezelfde fout de andere kant op: een glb met
een correct bot-kind komt in Blender meters naast de hand te staan, en een
export daarna schrijft die verkeerde plek weer weg (de merge-stap). Daarom
voor een import-export-slag (blender_merge_character.py):
    bewaard = blender_botkind_fix.bewaar_botkinderen(basis_glb)   # voor de import
    ...import, bewerken, exporteren...
    blender_botkind_fix.herstel_botkinderen(uit_glb, bewaard)     # na de export
"""
import json
import struct

import bpy


def _bot_relatief(obj, armature):
    pb = armature.pose.bones.get(obj.parent_bone)
    if pb is None:
        return None
    kop_pose = armature.matrix_world @ pb.matrix
    return kop_pose.inverted() @ obj.matrix_world


def _lees_glb(pad):
    with open(pad, "rb") as f:
        data = f.read()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise RuntimeError("geen glb: %s" % pad)
    json_len, json_type = struct.unpack_from("<II", data, 12)
    json_bytes = data[20:20 + json_len]
    rest = data[20 + json_len:]
    return json.loads(json_bytes.decode("utf-8")), rest


def _schrijf_glb(pad, gltf, rest):
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    while len(js) % 4 != 0:
        js += b" "
    body = struct.pack("<II", len(js), 0x4E4F534A) + js + rest
    with open(pad, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + len(body)))
        f.write(body)


def fix_glb(pad, objecten, armature):
    """Corrigeer de TRANSLATIE van elke bot-geparente node in de glb naar de
    plek die Blender ziet. Rotatie en schaal blijven van de exporter: die had ze
    goed, en de bot-ruimte van Blender staat er 90 graden om X naast (zie de
    module-docstring). Geeft het aantal echt gewijzigde nodes terug."""
    gltf, rest = _lees_glb(pad)
    nodes = gltf.get("nodes", [])
    op_naam = {}
    for i, n in enumerate(nodes):
        op_naam.setdefault(n.get("name", ""), i)
    n_fix = 0
    for obj in objecten:
        if obj.parent is None or obj.parent_type != "BONE":
            continue
        rel = _bot_relatief(obj, armature)
        if rel is None:
            print("  bot-kind-fix: bot %s niet gevonden voor %s" % (obj.parent_bone, obj.name))
            continue
        idx = op_naam.get(obj.name)
        if idx is None:
            print("  bot-kind-fix: node %s niet in de glb" % obj.name)
            continue
        t = rel.to_translation()
        node = nodes[idx]
        oud = node.get("translation", [0.0, 0.0, 0.0])
        nieuw = [float(t.x), float(t.y), float(t.z)]
        # Alleen ingrijpen als de exporter er echt naast zit. Zo blijft in het
        # log zichtbaar wanneer de Y-bug van 3 september daadwerkelijk toeslaat,
        # in plaats van dat elke export "gefixt" heet.
        if max(abs(float(a) - b) for a, b in zip(oud, nieuw)) < 1e-4:
            print("  bot-kind: %s aan %s staat goed (%.2f, %.2f, %.2f)" % (
                obj.name, obj.parent_bone, nieuw[0], nieuw[1], nieuw[2]))
            continue
        node["translation"] = nieuw
        node.pop("matrix", None)
        n_fix += 1
        print("  bot-kind-fix: %s aan %s: t %s -> (%.2f, %.2f, %.2f)" % (
            obj.name, obj.parent_bone, [round(float(v), 1) for v in oud], t.x, t.y, t.z))
    if n_fix > 0:
        _schrijf_glb(pad, gltf, rest)
    return n_fix


def _is_joint(gltf, idx):
    for skin in gltf.get("skins", []):
        if idx in skin.get("joints", []):
            return True
    return False


def bewaar_botkinderen(pad):
    """Lees uit een glb de transform van elke node die een KIND van een joint is
    (bot-geparent wapen): {naam: {"translation", "rotation", "scale"}}."""
    gltf, _rest = _lees_glb(pad)
    nodes = gltf.get("nodes", [])
    uit = {}
    for i, n in enumerate(nodes):
        if not _is_joint(gltf, i):
            continue
        for c in n.get("children", []):
            kind = nodes[c]
            if _is_joint(gltf, c) or "mesh" not in kind:
                continue
            uit[kind.get("name", "")] = {
                "translation": kind.get("translation", [0.0, 0.0, 0.0]),
                "rotation": kind.get("rotation", [0.0, 0.0, 0.0, 1.0]),
                "scale": kind.get("scale", [1.0, 1.0, 1.0]),
            }
    return uit


def herstel_botkinderen(pad, bewaard):
    """Zet de bewaarde bot-kind-transforms terug in een (opnieuw geexporteerde)
    glb; matcht op node-naam (Blender houdt objectnamen door de slag heen)."""
    if not bewaard:
        return 0
    gltf, rest = _lees_glb(pad)
    n_fix = 0
    for node in gltf.get("nodes", []):
        naam = node.get("name", "")
        if naam not in bewaard:
            continue
        oud = node.get("translation", [0, 0, 0])
        node["translation"] = list(bewaard[naam]["translation"])
        node["rotation"] = list(bewaard[naam]["rotation"])
        node["scale"] = list(bewaard[naam]["scale"])
        node.pop("matrix", None)
        n_fix += 1
        print("  bot-kind hersteld: %s: t %s -> %s" % (naam, [round(float(v), 1) for v in oud],
            [round(float(v), 2) for v in node["translation"]]))
    if n_fix > 0:
        _schrijf_glb(pad, gltf, rest)
    return n_fix
