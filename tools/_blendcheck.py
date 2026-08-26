# Inspectie van een aangeleverde karakter-.blend VOOR de export-pijplijn
# (16 augustus; les van de 15e: eerst kijken, dan pas aannemen).
#   blender --background model.blend --python tools/_blendcheck.py
# Print: mesh-delen (naam, tris, parenting), acties, afbeeldingsmaten en
# het ingebakken wapen (tripo_node of wapen-woord) met zijn bevestiging.
import bpy

WAPEN_WOORDEN = ("tripo_node", "musket", "rifle", "gun", "weapon", "sabre",
                 "saber", "sword", "axe", "lance", "pike", "spear", "cutlass",
                 "scythe", "hatchet", "falchion", "dagger")

print("=== BLENDCHECK:", bpy.data.filepath, "===")
arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
print("armatures:", [a.name for a in arms])
for o in bpy.data.objects:
    if o.type != "MESH":
        continue
    wapen = any(w in o.name.lower() for w in WAPEN_WOORDEN)
    hoe = ""
    if o.parent_type == "BONE":
        hoe = "bot-geparent aan %s" % o.parent_bone
    elif any(m.type == "ARMATURE" for m in o.modifiers):
        hoe = "geskind"
    else:
        hoe = "LOS (parent: %s)" % (o.parent.name if o.parent else "geen")
    print("mesh: %-40s %6d tris  %s%s" % (o.name, len(o.data.polygons), hoe,
                                          "  << WAPEN" if wapen else ""))
acts = sorted(a.name for a in bpy.data.actions)
print("acties (%d): %s" % (len(acts), ", ".join(acts)))
for img in bpy.data.images:
    if img.size[0] > 0:
        print("afbeelding: %-50s %dx%d" % (img.name, img.size[0], img.size[1]))
