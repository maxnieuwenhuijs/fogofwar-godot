"""Bouwt de low-poly props uit recepten.py, exporteert elke prop als glb en
zet ze allemaal op een plaat.

    blender --background --python tools/blender_props/bouw_props.py -- \
        [--alleen kruitvat,kogels] [--batch 1] [--uit results/props_blender] [--seed 1] [--geen-plaat]

Per prop: results/props_blender/prop_<naam>.glb (atlas ingebakken), en een
regel met driehoeken. De plaat (Eevee, orthografisch van schuin voor zoals
het spel) heet results/props_blender/plaat_<batch of alleen>.png. Daarna:
python tools/verwerk_props_bulk.py results/props_blender (in het spel zetten).
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

HIER = os.path.dirname(os.path.abspath(__file__))
if HIER not in sys.path:
    sys.path.insert(0, HIER)
import bouwstenen as bs  # noqa: E402
import recepten  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
UIT = "results/props_blender"
ALLEEN = []
BATCH = 0
SEED = 1
PLAAT = True
i = 0
while i < len(argv):
    if argv[i] == "--uit":
        i += 1
        UIT = argv[i]
    elif argv[i] == "--alleen":
        i += 1
        ALLEEN = [x.strip() for x in argv[i].split(",") if x.strip()]
    elif argv[i] == "--batch":
        i += 1
        BATCH = int(argv[i])
    elif argv[i] == "--seed":
        i += 1
        SEED = int(argv[i])
    elif argv[i] == "--geen-plaat":
        PLAAT = False
    i += 1

UIT = os.path.abspath(UIT)
os.makedirs(UIT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

lijst = ALLEEN if ALLEEN else [n for n, (fn, b) in recepten.RECEPTEN.items() if BATCH == 0 or b == BATCH]
onbekend = [n for n in lijst if n not in recepten.RECEPTEN]
if onbekend:
    print("PROPS: onbekend recept:", ", ".join(onbekend))
    sys.exit(2)

atlas_np = bs.maak_atlas(SEED)
atlas = bs.atlas_naar_blender(atlas_np, "atlas", os.path.join(UIT, "atlas.png"))

objecten = []
for naam in lijst:
    fn, _batch = recepten.RECEPTEN[naam]
    rng = np.random.default_rng(SEED * 1000 + sum(ord(c) for c in naam))
    b = bs.Bouwer(atlas, rng)
    fn(b)
    ob = b.klaar("prop_" + naam)
    pad = os.path.join(UIT, "prop_%s.glb" % naam)
    bs.exporteer(ob, pad)
    me = ob.data
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    print("PROPS: %-22s %5d driehoeken %5d vertices  doos %.2f x %.2f x %.2f (b x d x h)  %4.0f kB" % (
        naam, len(me.loop_triangles), len(me.vertices), max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs),
        os.path.getsize(pad) / 1024.0))
    objecten.append(ob)

if PLAAT and objecten:
    kol = min(6, len(objecten))
    rijen = (len(objecten) + kol - 1) // kol
    cel = 1.5
    # de hoogste achteraan, anders verbergt een ton het houtblok in de rij erachter
    def hoogte(o):
        return max(v.co.z for v in o.data.vertices) if len(o.data.vertices) else 0.0
    objecten.sort(key=hoogte, reverse=True)
    for k, ob in enumerate(objecten):
        ob.location = Vector(((k % kol - (kol - 1) / 2) * cel, -(k // kol) * cel * 1.1, 0.0))
    scene = bpy.context.scene
    bpy.ops.mesh.primitive_plane_add(size=cel * (kol + 2))
    vloer = bpy.context.active_object
    vloer.location = Vector((0.0, -(rijen - 1) * cel * 0.55, -0.001))
    vm = bpy.data.materials.new("Vloer")
    vm.use_nodes = True
    vm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.32, 0.38, 0.24, 1.0)
    vloer.data.materials.append(vm)
    cam_data = bpy.data.cameras.new("Camera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = cel * kol * 1.05
    cam = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam)
    midden = Vector((0.0, -(rijen - 1) * cel * 0.55, 0.35))
    afstand = cel * kol * 3.0
    cam.location = midden + Vector((0.0, -afstand, afstand * math.tan(math.radians(38.0))))
    cam.rotation_euler = (midden - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    zon_data = bpy.data.lights.new("Zon", "SUN")
    zon_data.energy = 3.0
    zon_data.angle = math.radians(10.0)
    zon = bpy.data.objects.new("Zon", zon_data)
    scene.collection.objects.link(zon)
    zon.location = Vector((afstand * 0.4, -afstand * 0.5, afstand * 0.8))
    zon.rotation_euler = (midden - zon.location).to_track_quat("-Z", "Y").to_euler()
    world = bpy.data.worlds.new("Wereld")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg is not None:
        bg.inputs["Color"].default_value = (0.55, 0.62, 0.72, 1.0)
        bg.inputs["Strength"].default_value = 0.9
    scene.world = world
    scene.render.resolution_x = 400 * kol
    scene.render.resolution_y = int(400 * kol * (rijen * 1.1 + 0.7) / (kol * 1.05))
    scene.render.resolution_percentage = 100
    label = ("batch%d" % BATCH) if BATCH else ("alleen" if ALLEEN else "alles")
    plaat = os.path.join(UIT, "plaat_%s.png" % label)
    scene.render.filepath = plaat
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
            break
        except Exception as e:  # noqa: BLE001
            print("PROPS: render met %s mislukt: %s" % (eng, e))
    if not gerenderd:
        scene.render.engine = "BLENDER_WORKBENCH"
        bpy.ops.render.render(write_still=True)
    print("PROPS: plaat -> %s (van hoog naar laag: %s)" % (plaat, ", ".join(o.name[5:] for o in objecten)))
print("PROPS: klaar, %d props in %s" % (len(objecten), UIT))
