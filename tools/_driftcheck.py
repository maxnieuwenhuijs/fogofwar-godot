# Eenmalig (26 augustus): dragen de cavalerie-clips root-motion (netto
# heup-verplaatsing)? Een clip die zelf naar voren loopt zou in het spel
# BOVENOP de tween-verplaatsing glijden.
#   blender --background model.blend --python tools/_driftcheck.py
import bpy


def fcurves(act):
    try:
        fcs = list(act.fcurves)
        if fcs:
            return fcs
    except Exception:
        pass
    out = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for bag in getattr(strip, "channelbags", []):
                out.extend(bag.fcurves)
    return out


for act in sorted(bpy.data.actions, key=lambda a: a.name):
    drift = [0.0, 0.0, 0.0]
    for fc in fcurves(act):
        if "Hips" in fc.data_path and fc.data_path.endswith(".location"):
            kps = fc.keyframe_points
            if len(kps) >= 2 and fc.array_index < 3:
                drift[fc.array_index] = abs(kps[-1].co.y - kps[0].co.y)
    print("clip %-38s drift x=%.3f y=%.3f z=%.3f" % (act.name, drift[0], drift[1], drift[2]))
