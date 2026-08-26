# Haal het INGEBAKKEN musket (de tripo_node_<uuid>-mesh) uit een aangeleverde
# .blend en schrijf het als losse, statische musket-prop:
#
#   blender --background model.blend --python tools/blender_export_musket.py -- --uit pad/infantry_base_musket.glb
#
# Achtergrond (15 augustus, met schaamrood): generators bakken het wapen als
# los mesh mee in het karakterbestand, onder de naam tripo_node_<uuid> -- zie
# de docstring van blender_strip_baked_weapon.py. Dat mesh is hier eerder
# aangezien voor een karakter-duplicaat (een musket en een laagpoly-karakter
# zijn allebei ~900 driehoeken) en weggegooid; een render bewees dat het een
# musket met bajonet is. Dit script is de blend-variant van --wapen-uit:
# armature-modifier eraf, losknippen van het skelet met behoud van stand,
# texture naar 1024, en exporteren als statische glb. weapon_for() in
# pawn_view.gd vindt hem dan vanzelf als per-model musket.
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

wapens = [o for o in bpy.data.objects if o.type == "MESH" and o.name.lower().startswith("tripo_node")]
# Degeneraat gruis overslaan: de cavalerie-blends (16 aug) hebben naast het
# echte wapen ook geskinde tripo-fragmentjes van 1 driehoek. Die horen niet
# in de wapen-glb (ze zouden als zwevende splinter meevliegen bij de dood).
gruis = [o for o in wapens if len(o.data.polygons) < 20]
for o in gruis:
    print("  overgeslagen (gruis, %d tris): %s" % (len(o.data.polygons), o.name))
wapens = [o for o in wapens if o not in gruis]
if not wapens:
    print("GEEN ingebakken wapen in dit bestand")
    sys.exit(1)

for o in wapens:
    for m in list(o.modifiers):
        if m.type == "ARMATURE":
            o.modifiers.remove(m)

bpy.ops.object.select_all(action="DESELECT")
for o in wapens:
    o.select_set(True)
bpy.context.view_layer.objects.active = wapens[0]
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")

# Alleen de textures van HET WAPEN verkleinen; de rest raakt de export niet
# (use_selection pakt alleen de geselecteerde objecten en hun materialen).
for img in bpy.data.images:
    if img.size[0] > 1024 or img.size[1] > 1024:
        img.scale(min(img.size[0], 1024), min(img.size[1], 1024))

bpy.ops.object.select_all(action="DESELECT")
for o in wapens:
    o.select_set(True)
bpy.context.view_layer.objects.active = wapens[0]
os.makedirs(os.path.dirname(os.path.abspath(uit)), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=os.path.abspath(uit),
    export_format="GLB",
    use_selection=True,
    export_image_format="JPEG",
    export_jpeg_quality=85,
)
tris = 0
for o in wapens:
    o.data.calc_loop_triangles()
    tris += len(o.data.loop_triangles)
print("MUSKET -> %s (%d mesh, %d driehoeken)" % (uit, len(wapens), tris))
