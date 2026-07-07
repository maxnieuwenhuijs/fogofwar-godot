"""Karakter-bouwer: voeg Mixamo-clips samen met een basis-glb tot 1 spel-klare glb.

Gebruik (headless Blender):
  blender --background --python tools/blender_merge_character.py -- \
      --base assets/models/muis/infanterie_basis.glb \
      --out  assets/models/muis/infanterie_basis.glb \
      idle="C:/pad/Rifle Idle.fbx" walk="C:/pad/Walk With Rifle.fbx" ...

- Clipnamen: idle/walk/attack/die (+ varianten idle2, walk3, die2, ...).
- Zonder clip-argumenten is dit een pure fix-pass over de basis.
- Walk-/idle-clips worden automatisch "in place" gemaakt: de netto verplaatsing
  (root motion) wordt uit de heup-locatiecurves gerekend, de sway/bob blijft.
  Mixamo's "In Place"-vinkje is dus welkom maar niet meer verplicht.
"""
import bpy
import sys
import os

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
BASE = ""
OUT = ""
CLIPS = []  # (naam, pad)
i = 0
while i < len(argv):
    a = argv[i]
    if a == "--base":
        i += 1
        BASE = argv[i]
    elif a == "--out":
        i += 1
        OUT = argv[i]
    elif "=" in a:
        name, path = a.split("=", 1)
        CLIPS.append((name, path))
    i += 1
if not BASE:
    raise SystemExit("--base ontbreekt")
OUT = OUT or BASE

bpy.ops.wm.read_factory_settings(use_empty=True)


def scene_armatures():
    return [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']


def iter_fcurves(act):
    try:
        fcs = list(act.fcurves)
        if fcs:
            return fcs
    except Exception:
        pass
    out = []
    for layer in getattr(act, 'layers', []):
        for strip in layer.strips:
            for bag in getattr(strip, 'channelbags', []):
                out.extend(bag.fcurves)
    return out


def detrend_root_motion(act):
    """Haal de netto verplaatsing uit de heup-locatiecurves (in place maken)."""
    for fc in iter_fcurves(act):
        if 'Hips' not in fc.data_path or not fc.data_path.endswith('.location'):
            continue
        kps = fc.keyframe_points
        if len(kps) < 2:
            continue
        x0, v0 = kps[0].co.x, kps[0].co.y
        x1, v1 = kps[-1].co.x, kps[-1].co.y
        drift = v1 - v0
        if abs(drift) < 1e-6 or abs(x1 - x0) < 1e-6:
            continue
        for kp in kps:
            f = (kp.co.x - x0) / (x1 - x0)
            kp.co.y -= drift * f
            kp.handle_left.y -= drift * f
            kp.handle_right.y -= drift * f
        print("  in-place: %s drift %.3f verwijderd (%s)" % (act.name, drift, fc.data_path))


def add_track(arm, act, name):
    act.name = name
    act.use_fake_user = True
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    start = max(int(act.frame_range[0]), 0)
    strip = track.strips.new(name, start, act)
    strip.name = name
    try:
        if hasattr(strip, "action_slot") and len(act.slots):
            strip.action_slot = act.slots[0]
    except Exception as e:
        print("slot-koppeling:", name, e)


bpy.ops.import_scene.gltf(filepath=os.path.abspath(BASE))
base = scene_armatures()[0]
print("BASIS:", base.name)
if base.animation_data is None:
    base.animation_data_create()
base_hips = base.data.bones.get('mixamorig:Hips')
base_len = base_hips.head_local.length if base_hips else 1.0

# Bestaande clips: track garanderen + walk/idle in place maken.
tracked = {t.name for t in base.animation_data.nla_tracks}
for act in list(bpy.data.actions):
    if act.name not in tracked and not act.name.startswith("_"):
        add_track(base, act, act.name)
    if act.name.startswith(("walk", "idle", "bayonet", "melee")):
        detrend_root_motion(act)

for clip_name, path in CLIPS:
    before_obj = set(bpy.context.scene.objects)
    before_act = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=os.path.abspath(path))
    new_objs = [o for o in bpy.context.scene.objects if o not in before_obj]
    new_acts = [a for a in bpy.data.actions if a not in before_act]
    if not new_acts:
        print("WAARSCHUWING: geen actie in", path)
    else:
        act = new_acts[0]
        donor = next((o for o in new_objs if o.type == 'ARMATURE'), None)
        ratio = 1.0
        if donor is not None:
            dh = donor.data.bones.get('mixamorig:Hips')
            if dh is not None and dh.head_local.length > 1e-9:
                ratio = base_len / dh.head_local.length
        if abs(ratio - 1.0) > 1e-3:
            for fc in iter_fcurves(act):
                if fc.data_path.endswith('.location'):
                    for kp in fc.keyframe_points:
                        kp.co.y *= ratio
                        kp.handle_left.y *= ratio
                        kp.handle_right.y *= ratio
        if clip_name.startswith(("walk", "idle", "bayonet", "melee")):
            detrend_root_motion(act)
        add_track(base, act, clip_name)
        print("clip toegevoegd:", clip_name)
    for o in new_objs:
        bpy.data.objects.remove(o, do_unlink=True)

base.animation_data.action = None
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format='GLB',
                          export_animation_mode='NLA_TRACKS')
print("KLAAR ->", OUT)
