# Eenmalig (16 augustus): HOE beweegt de tripo_node (het ingebakken musket)
# mee met de animaties? Armature-modifier, bot-parenting, of helemaal niet?
#   blender --background model.blend --python tools/_parentcheck.py
import bpy

for o in bpy.data.objects:
    if not o.name.lower().startswith("tripo_node"):
        continue
    mods = [m.type for m in o.modifiers]
    print("OBJ:", o.name)
    print("  modifiers:", mods)
    print("  parent:", o.parent.name if o.parent else None)
    print("  parent_type:", o.parent_type)
    if o.parent_type == "BONE":
        print("  parent_bone:", o.parent_bone)
    vgs = [g.name for g in o.vertex_groups]
    print("  vertex_groups (%d):" % len(vgs), vgs[:5])
