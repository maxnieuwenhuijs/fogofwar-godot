# Rauwe export: van een aangeleverde .blend naar een geanimeerde .glb, klaar
# voor de kwartslag-fix + gibs van blender_merge_character.py.
#
#   blender --background model.blend --python tools/blender_export_blend.py -- --uit pad/naar/infantry_base.glb
#
# Wat hij doet, en waarom:
#   - tripo_node*-meshes gaan ERUIT: dat is het onopgeknipte origineel van de
#     generator dat naast de losse delen in het bestand blijft hangen. In de
#     muis-referentie zit hij niet; in de leeuw is hij per ongeluk mee
#     geexporteerd (dubbele geometrie + een extra 4K-textureset, en als
#     "gib-brok" een compleet lijk dat wegvliegt).
#   - textures worden verkleind naar max 1024 (zelfde beleid als het
#     merge-script: de albedo wordt in het spel toch vervangen door de losse
#     team-textures, 4K in de glb is alleen maar bloat).
#   - export met ACTIONS-modus: elke actie een animatie, namen blijven de
#     Mixamo-namen (het spel vertaalt ze bij het laden).
import bpy
import os
import sys

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
uit = None
for i, a in enumerate(argv):
    if a == "--uit" and i + 1 < len(argv):
        uit = argv[i + 1]
if not uit:
    print("FOUT: geef --uit <pad.glb> mee")
    sys.exit(1)

# 1. tripo_node*-duplicaten weg (log wat er verdwijnt).
weg = [o for o in bpy.data.objects if o.name.lower().startswith("tripo_node")]
for o in weg:
    print("  origineel-duplicaat verwijderd: %s (%d tris)" % (o.name, len(o.data.polygons)))
    bpy.data.objects.remove(o, do_unlink=True)

# 2. Ongebruikte afbeeldingen opruimen (de textureset van het duplicaat) en
#    de rest verkleinen naar 1024.
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
