"""Breng een te zwaar model terug naar een doel-aantal driehoeken.

    blender --background --python tools/blender_decimate.py -- \
        --in <bestand.fbx|glb> --out <bestand.glb> --doel 1200

Noodgreep, geen vervanging van een fatsoenlijke laagpoly-export: Decimate
gooit driehoeken weg uit een bestaande mesh en kan de vorm aantasten. Gebruik
hem om niet te hoeven wachten op een nieuwe export, en vervang het model alsnog
zodra de generator een echte Laag Poly-versie levert.
"""
import bpy
import sys
import os

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
IN = ""
OUT = ""
DOEL = 1200
i = 0
while i < len(argv):
    if argv[i] == "--in":
        i += 1
        IN = argv[i]
    elif argv[i] == "--out":
        i += 1
        OUT = argv[i]
    elif argv[i] == "--doel":
        i += 1
        DOEL = int(argv[i])
    i += 1

bpy.ops.wm.read_factory_settings(use_empty=True)
ext = os.path.splitext(IN)[1].lower()
if ext == ".fbx":
    bpy.ops.import_scene.fbx(filepath=os.path.abspath(IN))
else:
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(IN))


def tel():
    n = 0
    for o in bpy.context.scene.objects:
        if o.type == 'MESH':
            o.data.calc_loop_triangles()
            n += len(o.data.loop_triangles)
    return n


voor = tel()
if voor <= DOEL:
    print("DECIMATE: %s zit al op %d driehoeken, niets te doen" % (os.path.basename(IN), voor))
else:
    ratio = float(DOEL) / float(voor)
    for o in bpy.context.scene.objects:
        if o.type != 'MESH':
            continue
        m = o.modifiers.new(name="Decimate", type='DECIMATE')
        m.decimate_type = 'COLLAPSE'
        m.ratio = ratio
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=m.name)
    print("DECIMATE: %s  %d -> %d driehoeken (ratio %.5f)" % (
        os.path.basename(IN), voor, tel(), ratio))

bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format='GLB',
                          export_image_format='JPEG', export_jpeg_quality=85)
print("DECIMATE: geschreven naar %s" % OUT)
