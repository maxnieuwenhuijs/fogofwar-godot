# Eenmalig (15 augustus): render het karakter MET ingebakken musket midden in
# een paar animaties, om te beoordelen of de skinning goed genoeg is om het
# musket-in-de-animatie-idee van Max te dragen.
#   blender --background model.blend --python tools/_render_anim.py -- <uitmap>
import bpy
import sys
from mathutils import Vector

uitmap = sys.argv[sys.argv.index("--") + 1]

arm = None
for o in bpy.data.objects:
    if o.type == "ARMATURE":
        arm = o
        break

# Camera + licht een keer opzetten, op het hele karakter gericht.
alles = [o for o in bpy.data.objects if o.type == "MESH"]
bbs = []
for o in alles:
    bbs += [o.matrix_world @ Vector(c) for c in o.bound_box]
midden = sum(bbs, Vector()) / len(bbs)
maat = max((max(v[i] for v in bbs) - min(v[i] for v in bbs)) for i in range(3))

cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
bpy.context.scene.collection.objects.link(cam)
cam.location = midden + Vector((maat * 1.4, -maat * 1.4, maat * 0.35))
cam.rotation_euler = (midden - cam.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = cam

licht_data = bpy.data.lights.new("zon", type="SUN")
licht_data.energy = 4.0
licht = bpy.data.objects.new("zon", licht_data)
bpy.context.scene.collection.objects.link(licht)
licht.rotation_euler = (0.8, 0.2, 0.5)

sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.render.resolution_x = 512
sc.render.resolution_y = 512

if arm.animation_data is None:
    arm.animation_data_create()

for naam in ["Rifle idle 1", "Walk 1", "Bayonet Attack", "Rifle fire ankle shot"]:
    act = bpy.data.actions.get(naam)
    if act is None:
        print("ONTBREEKT:", naam)
        continue
    arm.animation_data.action = act
    # Blender 5: de action-slot moet expliciet gezet (anders speelt er niks).
    if hasattr(act, "slots") and len(act.slots) > 0:
        arm.animation_data.action_slot = act.slots[0]
    frame = int((act.frame_range[0] + act.frame_range[1]) * 0.5)
    sc.frame_set(frame)
    veilig = naam.replace(" ", "_").lower()
    sc.render.filepath = "%s/anim_%s.png" % (uitmap, veilig)
    bpy.ops.render.render(write_still=True)
    print("RENDER %s frame %d -> %s" % (naam, frame, sc.render.filepath))
