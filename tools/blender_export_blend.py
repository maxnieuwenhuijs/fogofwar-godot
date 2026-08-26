# Rauwe export: van een aangeleverde .blend naar een geanimeerde .glb, klaar
# voor de kwartslag-fix + gibs van blender_merge_character.py.
#
#   blender --background model.blend --python tools/blender_export_blend.py -- --uit pad/naar/infantry_base.glb
#
# Wat hij doet, en waarom:
#   - de tripo_node*-mesh (het INGEBAKKEN MUSKET van de generator) blijft er
#     sinds 16 augustus IN: hij is geskind aan de hand-botten, dus in het spel
#     richt, draagt en steekt hij met de animaties mee (besluit Max — een
#     stijve hand-prop kan dat nooit). Het spel herkent hem op naam en laat
#     hem staan; bij de dood vliegt de losse musket-glb (uit
#     blender_export_musket.py) vanaf de hand als brokstuk weg. Wil je toch
#     een kale export zonder wapen (generator-rommel): --zonder-wapen.
#     (Op 15 augustus werd de tripo_node nog voor een karakter-duplicaat
#     aangezien — musket en laagpoly-karakter zijn allebei ~900 tris; een
#     render toonde de bajonet. Bij twijfel: renderen, geen naam-scan.)
#   - textures worden verkleind naar max 1024 (zelfde beleid als het
#     merge-script: de albedo van het LIJF wordt in het spel vervangen door de
#     losse team-textures; het musket houdt zijn eigen atlas, ook 1024 zat).
#   - export met ACTIONS-modus: elke actie een animatie, namen blijven de
#     Mixamo-namen (het spel vertaalt ze bij het laden).
import bpy
import os
import sys

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
uit = None
zonder_wapen = False
for i, a in enumerate(argv):
    if a == "--uit" and i + 1 < len(argv):
        uit = argv[i + 1]
    elif a == "--zonder-wapen":
        zonder_wapen = True
if not uit:
    print("FOUT: geef --uit <pad.glb> mee")
    sys.exit(1)

# 1. Het ingebakken wapen: standaard HOUDEN (zie kop), op verzoek strippen.
#    Degeneraat gruis (geskinde tripo-fragmentjes van 1 driehoek, gezien in de
#    cavalerie-blends van 16 aug) gaat er ALTIJD uit: het is geen wapen en
#    geen lijfdeel, alleen ruis in de karakter-glb.
wapens = [o for o in bpy.data.objects if o.name.lower().startswith("tripo_node")]
gruis = [o for o in wapens if len(o.data.polygons) < 20]
for o in gruis:
    print("  gruis verwijderd (%d tris): %s" % (len(o.data.polygons), o.name))
    bpy.data.objects.remove(o, do_unlink=True)
wapens = [o for o in wapens if o not in gruis]
if zonder_wapen:
    for o in wapens:
        print("  ingebakken wapen verwijderd (--zonder-wapen): %s (%d tris)" % (o.name, len(o.data.polygons)))
        bpy.data.objects.remove(o, do_unlink=True)
else:
    for o in wapens:
        # Meebewegen kan op twee manieren: een armature-modifier (geskind) of
        # bot-parenting (Tripo/Mixamo hangt het musket rigide aan RightHand;
        # Godot maakt daar bij import een BoneAttachment3D van). Allebei goed.
        heeft_skin = any(m.type == "ARMATURE" for m in o.modifiers)
        if heeft_skin:
            hoe = "geskind"
        elif o.parent_type == "BONE" and o.parent_bone:
            hoe = "bot-geparent aan %s" % o.parent_bone
        else:
            hoe = "LOS — gaat NIET meebewegen!"
        print("  ingebakken musket blijft in het model: %s (%d tris, %s)"
              % (o.name, len(o.data.polygons), hoe))

# 2. Ongebruikte data opruimen en de overgebleven textures verkleinen naar 1024.
bpy.ops.outliner.orphans_purge(do_recursive=True)
for img in bpy.data.images:
    if img.size[0] > 1024 or img.size[1] > 1024:
        img.scale(min(img.size[0], 1024), min(img.size[1], 1024))
        print("  texture verkleind: %s -> %dx%d" % (img.name, img.size[0], img.size[1]))

# 3. Alles selecteren en exporteren.
bpy.ops.object.select_all(action="SELECT")
os.makedirs(os.path.dirname(os.path.abspath(uit)), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=os.path.abspath(uit),
    export_format="GLB",
    export_animation_mode="ACTIONS",
    export_image_format="JPEG",
    export_jpeg_quality=85,
)
mesh_n = len([o for o in bpy.data.objects if o.type == "MESH"])
act_n = len(bpy.data.actions)
print("EXPORT KLAAR: %s (%d mesh-delen, %d acties)" % (uit, mesh_n, act_n))
