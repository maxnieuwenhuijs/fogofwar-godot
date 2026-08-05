"""Tel de driehoeken per object in een model (glb of fbx). Alleen meten.

    blender --background --python tools/blender_tel_tris.py -- <bestand> [<bestand> ...]
"""
import bpy
import sys
import os

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for pad in argv:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ext = os.path.splitext(pad)[1].lower()
    if ext == ".glb" or ext == ".gltf":
        bpy.ops.import_scene.gltf(filepath=os.path.abspath(pad))
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=os.path.abspath(pad))
    else:
        print("TEL: onbekend formaat %s" % pad)
        continue
    delen = []
    for o in bpy.context.scene.objects:
        if o.type != 'MESH':
            continue
        o.data.calc_loop_triangles()
        delen.append((o.name, len(o.data.loop_triangles)))
    delen.sort(key=lambda x: -x[1])
    print("TEL: %-46s %d delen, %d driehoeken" % (
        os.path.basename(pad), len(delen), sum(n for _, n in delen)))
    for naam, n in delen[:4]:
        print("TEL:     %-38s %8d" % (naam, n))
