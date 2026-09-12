"""Vier kanten van een prop op een plaat, om te zien hoe hij staat en welke
draai hij nodig heeft.

    blender --background --python tools/blender_prop_preview.py -- \
        --in <prop.glb> --uit results/props/<naam>_preview.png [--maat 512]

Links op de plaat staat het model ZOALS GELEVERD, gezien vanaf de kant die in
het spel naar de speler wijst (glTF/Godot +Z, in Blender de voorkant, -Y).
De kolommen daarnaast tonen hetzelfde model met een draai van 90, 180 en 270
graden om de staande as: de kolom waarin de voorkant (opening, deur, gezicht)
naar je toe wijst, is de `--draai` die je aan verwerk_prop.py meegeeft. Onder
elke kolom staat die hoek als streepjes-code (1 streep = 90 graden). Eevee als
het kan, anders Workbench.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
IN = ""
UIT = ""
MAAT = 512
i = 0
while i < len(argv):
    if argv[i] == "--in":
        i += 1
        IN = argv[i]
    elif argv[i] == "--uit":
        i += 1
        UIT = argv[i]
    elif argv[i] == "--maat":
        i += 1
        MAAT = int(argv[i])
    i += 1
if not IN or not UIT:
    print("PREVIEW: gebruik --in <glb> --uit <png>")
    sys.exit(2)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(IN))
scene = bpy.context.scene
bronnen = [o for o in scene.objects if o.type == "MESH"]
if not bronnen:
    print("PREVIEW: geen mesh in %s" % IN)
    sys.exit(1)

# omhullende doos van alles wat er geimporteerd is (wereldruimte)
lo = Vector((1e9, 1e9, 1e9))
hi = Vector((-1e9, -1e9, -1e9))
for o in bronnen:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
        hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
midden = (lo + hi) * 0.5
omvang = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, 1e-6)
tris = 0
for o in bronnen:
    o.data.calc_loop_triangles()
    tris += len(o.data.loop_triangles)
print("PREVIEW: %d delen, %d driehoeken, doos %.3f x %.3f x %.3f (breed x diep x hoog)" % (
    len(bronnen), tris, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z))

# een leeg draaipunt per kolom: het hele model eronder, om de staande as gedraaid.
# De wereldmatrices van de wortels VOOR het omhangen bewaren: zodra de scene een
# keer bijgewerkt is (de eerste primitive_cube_add), draagt matrix_world van het
# origineel al de verplaatsing van kolom 0, en dan staan kolom 3 en 4 scheef.
wortels = [o for o in scene.objects if o.parent is None]
oorspronkelijk = {w.name: w.matrix_world.copy() for w in wortels}
stap = omvang * 1.35
kolommen = []
for k, graden in enumerate((0, 90, 180, 270)):
    piv = bpy.data.objects.new("Kolom%d" % graden, None)
    scene.collection.objects.link(piv)
    piv.location = Vector(((k - 1.5) * stap, 0.0, 0.0))
    piv.rotation_euler = (0.0, 0.0, math.radians(graden))
    kolommen.append(piv)
    for w in wortels:
        if k == 0:
            kopie = w
            kinderen = [c for c in scene.objects if c.parent == w]
        else:
            kopie = w.copy()
            if w.data is not None:
                kopie.data = w.data
            scene.collection.objects.link(kopie)
            kinderen = []
            for c in scene.objects:
                if c.parent == w and c.name not in [x.name for x in kolommen]:
                    ck = c.copy()
                    if c.data is not None:
                        ck.data = c.data
                    scene.collection.objects.link(ck)
                    ck.parent = kopie
                    ck.matrix_parent_inverse = c.matrix_parent_inverse.copy()
        # het model met zijn voeten op de grond en zijn midden op het draaipunt
        mw = oorspronkelijk[w.name]
        kopie.parent = piv
        kopie.matrix_parent_inverse.identity()
        kopie.location = mw.translation - Vector((midden.x, midden.y, lo.z))
        kopie.rotation_euler = mw.to_euler()
        kopie.scale = mw.to_scale()
    # de streepjes-code onder de kolom: 1 streep = 90 graden
    for s in range(k):
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        streep = bpy.context.active_object
        streep.scale = (omvang * 0.05, omvang * 0.02, omvang * 0.16)
        streep.location = Vector(((k - 1.5) * stap + (s - (k - 1) * 0.5) * omvang * 0.14,
                                  -omvang * 0.75, omvang * 0.08))
        sm = bpy.data.materials.new("Streep")
        sm.use_nodes = True
        sm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.95, 0.75, 0.2, 1.0)
        streep.data.materials.append(sm)

# vloer
bpy.ops.mesh.primitive_plane_add(size=stap * 6.0)
vloer = bpy.context.active_object
vloer.location = Vector((0.0, 0.0, -0.001))
vm = bpy.data.materials.new("Vloer")
vm.use_nodes = True
vm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.30, 0.36, 0.22, 1.0)
vm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
vloer.data.materials.append(vm)

# camera: orthografisch, van voren (-Y) en iets van boven, zoals het spel
cam_data = bpy.data.cameras.new("Camera")
cam_data.type = "ORTHO"
cam_data.ortho_scale = stap * 4.2
cam = bpy.data.objects.new("Camera", cam_data)
scene.collection.objects.link(cam)
doel = Vector((0.0, 0.0, omvang * 0.35))
cam.location = Vector((0.0, -stap * 6.0, stap * 6.0 * math.tan(math.radians(32.0))))
cam.rotation_euler = (doel - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = cam

zon_data = bpy.data.lights.new("Zon", "SUN")
zon_data.energy = 3.0
zon_data.angle = math.radians(10.0)
zon = bpy.data.objects.new("Zon", zon_data)
scene.collection.objects.link(zon)
zon.location = Vector((stap * 2.0, -stap * 3.0, stap * 4.0))
zon.rotation_euler = (Vector((0, 0, 0)) - zon.location).to_track_quat("-Z", "Y").to_euler()
world = bpy.data.worlds.new("Wereld")
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg is not None:
    bg.inputs["Color"].default_value = (0.55, 0.62, 0.72, 1.0)
    bg.inputs["Strength"].default_value = 0.9
scene.world = world

scene.render.resolution_x = MAAT * 4
scene.render.resolution_y = int(MAAT * 1.15)
scene.render.resolution_percentage = 100
os.makedirs(os.path.dirname(os.path.abspath(UIT)) or ".", exist_ok=True)
scene.render.filepath = os.path.abspath(UIT)
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "Standard"
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
gerenderd = False
for eng in [e for e in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE") if e in engines]:
    try:
        scene.render.engine = eng
        if hasattr(scene, "eevee"):
            scene.eevee.taa_render_samples = 32
        bpy.ops.render.render(write_still=True)
        gerenderd = True
        print("PREVIEW (%s) -> %s" % (eng, UIT))
        break
    except Exception as e:  # noqa: BLE001
        print("PREVIEW met %s mislukt: %s" % (eng, e))
if not gerenderd:
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    bpy.ops.render.render(write_still=True)
    print("PREVIEW (workbench) -> %s" % UIT)
print("PREVIEW: kolommen = draai 0, 90, 180, 270 (streepjes eronder); de kolom waarin de voorkant naar je toe wijst is de --draai")
