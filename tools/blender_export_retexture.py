# Vis het KALE LIJF uit een .blend, klaar om te uploaden voor een retexture.
#
#   blender --background model.blend --python tools/blender_export_retexture.py -- \
#       --uit results/retexture/mouse_infantry_mix.glb
#
# Waarvoor: een teamjas (<model>_red.png / _blue.png) is niets anders dan een
# nieuwe albedo over dezelfde UV-indeling. Een retexture-dienst levert die,
# MITS je hem een model geeft waar hij de UV's van laat staan. Wat je daarvoor
# NIET moet meesturen:
#
#   - het skelet en de animaties. Een gerigd, geanimeerd model brengt de
#     diensten in de war en komt vaak opnieuw uitgevouwen terug. Dan past de
#     jas niet meer op het model in het spel, en dat zie je pas in de partij.
#     Daarom exporteert dit script in de RUSTHOUDING, zonder armature.
#   - het ingebakken wapen (de tripo_node-mesh). Dat heeft zijn eigen atlas en
#     het spel laat die met rust: `_apply_team_texture` haalt de override er
#     juist af. Meesturen is dus verspilde moeite en verspilde texels.
#
# De losse lichaamsdelen worden standaard aan elkaar geplakt tot een object
# (--los laat ze los). Dat verandert niets aan de UV's -- ze blijven per vlak
# staan -- maar de meeste diensten willen liever een mesh dan twaalf.
#
# Wat je terugkrijgt zet je als <model>_<team>.png naast de glb. Controleer
# daarna ALTIJD of hij past:
#
#   python tools/uv_check.py assets/models/<factie>/<type>/<model>.glb <de png>
import bpy
import os
import sys

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
uit = None
los = False
met_wapen = False
for i, a in enumerate(argv):
    if a == "--uit" and i + 1 < len(argv):
        uit = argv[i + 1]
    elif a == "--los":
        los = True
    elif a == "--met-wapen":
        met_wapen = True
if not uit:
    print("FOUT: geef --uit <pad.glb> mee")
    sys.exit(1)

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
# De tripo_node-mesh is het ingebakken wapen (zie blender_export_musket.py).
wapens = [o for o in meshes if o.name.lower().startswith("tripo_node")]
lijf = [o for o in meshes if o not in wapens]
if met_wapen:
    lijf += wapens
if not lijf:
    print("FOUT: geen lijf-meshes in dit bestand")
    sys.exit(1)

# Rusthouding: de armature op REST zetten VOOR we de modifiers weghalen, zodat
# het lijf in zijn A-pose komt te staan en niet in frame 1 van een dood-animatie.
for arm in [o for o in bpy.data.objects if o.type == "ARMATURE"]:
    arm.data.pose_position = "REST"
bpy.context.view_layer.update()

for o in lijf:
    for m in list(o.modifiers):
        if m.type == "ARMATURE":
            o.modifiers.remove(m)

bpy.ops.object.select_all(action="DESELECT")
for o in lijf:
    o.select_set(True)
bpy.context.view_layer.objects.active = lijf[0]
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")

if not los and len(lijf) > 1:
    bpy.ops.object.select_all(action="DESELECT")
    for o in lijf:
        o.select_set(True)
    bpy.context.view_layer.objects.active = lijf[0]
    bpy.ops.object.join()
    lijf = [bpy.context.view_layer.objects.active]

# Texturen mee als referentie voor de dienst, maar niet in 4K: 1024 is genoeg
# om te laten zien wat het NU is, en het spel gebruikt toch de losse jas.
for img in bpy.data.images:
    if img.size[0] > 1024 or img.size[1] > 1024:
        img.scale(min(img.size[0], 1024), min(img.size[1], 1024))

bpy.ops.object.select_all(action="DESELECT")
for o in lijf:
    o.select_set(True)
bpy.context.view_layer.objects.active = lijf[0]
os.makedirs(os.path.dirname(os.path.abspath(uit)), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=os.path.abspath(uit),
    export_format="GLB",
    use_selection=True,
    export_skins=False,
    export_animations=False,
    export_image_format="JPEG",
    export_jpeg_quality=85,
)

tris = 0
uvs = set()
for o in lijf:
    o.data.calc_loop_triangles()
    tris += len(o.data.loop_triangles)
    uvs |= {laag.name for laag in o.data.uv_layers}
print("RETEXTURE -> %s (%d object(en), %d driehoeken, UV-lagen: %s)"
      % (uit, len(lijf), tris, ", ".join(sorted(uvs)) or "GEEN"))
print("Upload dit bestand. Vraag de dienst de UV's te LATEN STAAN (geen nieuwe unwrap).")
print("Terug: zet de png als <model>_<team>.png naast de glb en draai tools/uv_check.py.")
