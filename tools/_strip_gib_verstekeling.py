# Eenmalig (15 augustus): haal de tripo_node*-verstekeling uit een bestaande
# gibs-glb. In mouse/infantry_atk_gibs.glb bleek het atk-MUSKET-mesh als 12e
# brokstuk te zitten, 18 eenheden naast het lijf: een spook-musket bij elke
# volle gib. Gebruik:
#   blender --background --python tools/_strip_gib_verstekeling.py -- pad.glb
import bpy
import sys

pad = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=pad)
weg = [o for o in bpy.data.objects if o.name.lower().startswith("tripo_node")]
for o in weg:
    print("  verstekeling eruit: %s" % o.name)
    bpy.data.objects.remove(o, do_unlink=True)
if not weg:
    print("  niets te strippen")
    sys.exit(0)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=pad, export_format="GLB",
                          export_image_format="JPEG", export_jpeg_quality=85)
print("HERSCHREVEN: %s (%d delen over)" % (pad, len([o for o in bpy.data.objects if o.type == "MESH"])))
