"""Haal de INGEBAKKEN musket uit een karakter-glb.

Generators leveren het wapen vaak als los mesh mee in het karakterbestand
(`tripo_node_<uuid>`). Het spel verbergt dat ding sowieso
(`PawnView._verberg_ingebakken_wapen`) en hangt er de eigen musket-prop voor in
de plaats -- maar het wordt wel geladen, geskind en elke frame meegerekend.

Meestal kost dat niets (zo'n musket is ~900 driehoeken). Maar als de generator
per ongeluk de HOOGPOLY-versie meebakt, is het ineens 917.000 driehoeken op een
karakter van 1.200: dat gebeurde op 4 augustus bij pig mix en spd, en die twee
partijen kwamen daardoor de opstelfase niet eens uit.

Gebruik:
    blender --background --python tools/blender_strip_baked_weapon.py -- \
        --in  assets/models/pig/infantry/infantry_mix.glb \
        --out assets/models/pig/infantry/infantry_mix.glb \
        --wapen-uit assets/models/pig/infantry/infantry_mix_musket.glb

Zonder --out schrijft hij naast het origineel als <naam>_strip.glb.
De animaties, het skelet en de overige delen blijven ongemoeid; alleen de
wapen-meshes gaan eruit.

Met --wapen-uit wordt dat wapen eerst als LOS, statisch model weggeschreven.
Dat is meteen de musket-prop die het spel aan de hand hangt, dus je hoeft er
geen apart bestand voor aan te leveren: het model draagt zijn eigen wapen al
mee, in precies de juiste laagpoly-versie (4 augustus: de los aangeleverde
musket-fbx'en waren 917.031 driehoeken terwijl de ingebakken versie er 946 had).
"""
import bpy
import sys
import os

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
IN = ""
OUT = ""
WAPEN_UIT = ""
i = 0
while i < len(argv):
    if argv[i] == "--in":
        i += 1
        IN = argv[i]
    elif argv[i] == "--out":
        i += 1
        OUT = argv[i]
    elif argv[i] == "--wapen-uit":
        i += 1
        WAPEN_UIT = argv[i]
    i += 1
if not IN:
    print("STRIP: geef --in <model.glb>")
    sys.exit(1)
if not OUT:
    OUT = os.path.splitext(os.path.abspath(IN))[0] + "_strip.glb"

# Zelfde herkenning als het spel: een wapenwoord, of een naamloos
# generator-meshje. Lijfdelen (Body, Head, Arm.L, ...) blijven altijd staan.
WAPENWOORDEN = ("tripo_node", "musket", "rifle", "gun", "weapon")
LIJFWOORDEN = ("body", "head", "hat", "arm", "leg", "tail", "foot", "hand")


def is_wapen(naam):
    kaal = naam.lower().replace("_", "").replace(".", "").replace(" ", "")
    for lijf in LIJFWOORDEN:
        if kaal.startswith(lijf):
            return False
    for w in WAPENWOORDEN:
        if w.replace("_", "") in kaal:
            return True
    return False


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(IN))

def tel_tris():
    n = 0
    for o in bpy.context.scene.objects:
        if o.type == 'MESH':
            o.data.calc_loop_triangles()
            n += len(o.data.loop_triangles)
    return n

voor = tel_tris()
weg = [o for o in bpy.context.scene.objects if o.type == 'MESH' and is_wapen(o.name)]
if not weg:
    print("STRIP: geen ingebakken wapen gevonden in %s" % IN)
else:
    for o in weg:
        o.data.calc_loop_triangles()
        print("STRIP: weg -> %-38s %8d driehoeken" % (o.name, len(o.data.loop_triangles)))
    if WAPEN_UIT:
        # Eerst als LOSSE, statische prop wegschrijven: armature-modifier eraf
        # en losknippen van het skelet, net als bij de gibs. Anders exporteer je
        # een geskinde mesh die aan een skelet hangt dat er niet meer is.
        bpy.ops.object.select_all(action='DESELECT')
        for o in weg:
            o.select_set(True)
        bpy.context.view_layer.objects.active = weg[0]
        bpy.ops.object.duplicate()
        kopie = list(bpy.context.selected_objects)
        for o in kopie:
            for m in list(o.modifiers):
                if m.type == 'ARMATURE':
                    o.modifiers.remove(m)
        bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
        bpy.ops.object.select_all(action='DESELECT')
        for o in kopie:
            o.select_set(True)
        bpy.context.view_layer.objects.active = kopie[0]
        bpy.ops.export_scene.gltf(filepath=os.path.abspath(WAPEN_UIT),
                                  export_format='GLB', use_selection=True,
                                  export_image_format='JPEG', export_jpeg_quality=85)
        print("STRIP: wapen apart -> %s" % WAPEN_UIT)
        bpy.ops.object.delete()
    bpy.ops.object.select_all(action='DESELECT')
    for o in weg:
        o.select_set(True)
    bpy.context.view_layer.objects.active = weg[0]
    bpy.ops.object.delete()

na = tel_tris()
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format='GLB',
                          export_animation_mode='NLA_TRACKS',
                          export_image_format='JPEG', export_jpeg_quality=85)
print("STRIP: %d -> %d driehoeken, geschreven naar %s" % (voor, na, OUT))
