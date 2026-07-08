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
import math
import mathutils

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


def lock_hips_location(act):
    """Zet de heup-LOCATIE volledig vast op het eerste frame (rotaties blijven).
    Voor hit-reacties: Mixamo bakt er een stapje in dat als "loopje" leest;
    de reactie zelf zit in romp/armen/hoofd en blijft intact."""
    for fc in iter_fcurves(act):
        if 'Hips' not in fc.data_path or not fc.data_path.endswith('.location'):
            continue
        kps = fc.keyframe_points
        if len(kps) < 2:
            continue
        v0 = kps[0].co.y
        moved = max(abs(kp.co.y - v0) for kp in kps)
        if moved < 1e-6:
            continue
        for kp in kps:
            kp.co.y = v0
            kp.handle_left.y = v0
            kp.handle_right.y = v0
        print("  vastgezet: %s heup-kanaal (uitslag %.3f) -> eerste frame (%s)" % (act.name, moved, fc.data_path))


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


def hips_first_quat(act):
    """Eerste-frame heup-rotatie (pose-space) uit de fcurves; None als afwezig."""
    comps = {}
    for fc in iter_fcurves(act):
        if 'Hips' in fc.data_path and fc.data_path.endswith('.rotation_quaternion'):
            if len(fc.keyframe_points):
                comps[fc.array_index] = fc.keyframe_points[0].co.y
    if len(comps) < 4:
        return None
    return mathutils.Quaternion((comps[0], comps[1], comps[2], comps[3]))


def yaw_between(q_ref_arm, q_clip_arm):
    """Getekende draai (graden) om de wereld-Z tussen twee armature-space rotaties."""
    d = q_clip_arm @ q_ref_arm.inverted()
    twist = mathutils.Quaternion((d.w, 0.0, d.y, 0.0))
    if twist.magnitude < 1e-9:
        return 0.0
    twist.normalize()
    return math.degrees(twist.to_euler().y)


def fix_quarter_turn(act, q_rest, q_ref_arm, ref_name):
    """Mixamo levert clips soms een kwart- of halve slag gedraaid (bayonet/hit).
    Meet de heup-yaw op frame 0 t.o.v. de referentie-clip; ligt het verschil op
    een veelvoud van 90 graden, draai dan de HELE clip (rotatie- en
    locatie-keys van de heup) terug. Kleine bedoelde draaiingen (<45) blijven."""
    q0 = hips_first_quat(act)
    if q0 is None:
        return
    yaw = yaw_between(q_ref_arm, q_rest @ q0)
    snap = round(yaw / 90.0) * 90.0
    if abs(snap) < 45.0 or abs(yaw - snap) > 35.0:
        return
    q_corr = mathutils.Quaternion((0.0, 1.0, 0.0), math.radians(-snap))
    q_fix = q_rest.inverted() @ q_corr @ q_rest
    rot_fcs = sorted([fc for fc in iter_fcurves(act)
                      if 'Hips' in fc.data_path and fc.data_path.endswith('.rotation_quaternion')],
                     key=lambda fc: fc.array_index)
    if len(rot_fcs) == 4 and len({len(fc.keyframe_points) for fc in rot_fcs}) == 1:
        for k in range(len(rot_fcs[0].keyframe_points)):
            q_old = mathutils.Quaternion((rot_fcs[0].keyframe_points[k].co.y,
                                          rot_fcs[1].keyframe_points[k].co.y,
                                          rot_fcs[2].keyframe_points[k].co.y,
                                          rot_fcs[3].keyframe_points[k].co.y))
            q_new = q_fix @ q_old
            for idx, comp in enumerate((q_new.w, q_new.x, q_new.y, q_new.z)):
                kp = rot_fcs[idx].keyframe_points[k]
                dy = comp - kp.co.y
                kp.co.y = comp
                kp.handle_left.y += dy
                kp.handle_right.y += dy
    loc_fcs = sorted([fc for fc in iter_fcurves(act)
                      if 'Hips' in fc.data_path and fc.data_path.endswith('.location')],
                     key=lambda fc: fc.array_index)
    if len(loc_fcs) == 3 and len({len(fc.keyframe_points) for fc in loc_fcs}) == 1:
        for k in range(len(loc_fcs[0].keyframe_points)):
            v_old = mathutils.Vector((loc_fcs[0].keyframe_points[k].co.y,
                                      loc_fcs[1].keyframe_points[k].co.y,
                                      loc_fcs[2].keyframe_points[k].co.y))
            v_new = q_fix @ v_old
            for idx in range(3):
                kp = loc_fcs[idx].keyframe_points[k]
                dy = v_new[idx] - kp.co.y
                kp.co.y = v_new[idx]
                kp.handle_left.y += dy
                kp.handle_right.y += dy
    print("  kwartslag-fix: %s stond %.0f graden gedraaid t.o.v. %s -> teruggedraaid" % (act.name, snap, ref_name))


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
q_rest_hips = base_hips.matrix_local.to_quaternion() if base_hips else mathutils.Quaternion()
ref_act = next((a for a in bpy.data.actions if a.name.startswith('idle')), None)
q_ref_arm = None
if ref_act is not None:
    _q0 = hips_first_quat(ref_act)
    if _q0 is not None:
        q_ref_arm = q_rest_hips @ _q0

# Bestaande clips: track garanderen + walk/idle in place maken.
tracked = {t.name for t in base.animation_data.nla_tracks}
for act in list(bpy.data.actions):
    if act.name not in tracked and not act.name.startswith("_"):
        add_track(base, act, act.name)
    if q_ref_arm is not None and not act.name.startswith("idle"):
        fix_quarter_turn(act, q_rest_hips, q_ref_arm, ref_act.name)
    if act.name.startswith(("hit", "bayonet", "melee")):
        lock_hips_location(act)
    elif act.name.startswith(("walk", "idle")):
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
        if q_ref_arm is not None and not clip_name.startswith("idle"):
            fix_quarter_turn(act, q_rest_hips, q_ref_arm, ref_act.name)
        if clip_name.startswith(("hit", "bayonet", "melee")):
            lock_hips_location(act)
        elif clip_name.startswith(("walk", "idle")):
            detrend_root_motion(act)
        add_track(base, act, clip_name)
        print("clip toegevoegd:", clip_name)
    for o in new_objs:
        bpy.data.objects.remove(o, do_unlink=True)

base.animation_data.action = None
# Textures klein houden: de game overschrijft de albedo toch met de losse
# team-textures (<basis>_red/_blue.png); een volle 4K-PNG in de glb is 10+ MB
# bloat. Verklein naar max 1024 en exporteer als JPEG (mobile-target).
for img in bpy.data.images:
    if img.size[0] > 1024 or img.size[1] > 1024:
        img.scale(min(img.size[0], 1024), min(img.size[1], 1024))
        print('  texture verkleind: %s -> %dx%d' % (img.name, img.size[0], img.size[1]))
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format='GLB',
                          export_animation_mode='NLA_TRACKS',
                          export_image_format='JPEG', export_jpeg_quality=85)
print("KLAAR ->", OUT)
