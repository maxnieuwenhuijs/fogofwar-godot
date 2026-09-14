# De hakbijl van Max' plaatje (assets/models/props/previews/prop_axe.jpg),
# gebouwd in een DRAAIENDE Blender via de Blender-MCP-connector (14 september,
# Max: "gebruik de blender mcp connector", "textures kan je achterwege laten").
# Steel langs z (midden op de oorsprong), kop bovenaan, snede naar -x: dezelfde
# conventie als prop_axe.glb in het spel. Platte kleuren via een 64x64-palet
# (vier blokken, UV per vlak op het blokmidden): een mesh, een materiaal, 316
# driehoeken. Draaien: in de connector `exec(open(pad).read(), ns)`, daarna
# `ns["render"](png)`; exporteren met export_scene.gltf (export_yup) en dan
# `python tools/verwerk_prop.py results/props_blender/hakbijl/hakbijl.glb axe`.
# Voor headless: blender --background --python tools/blender_props/hakbijl_mcp.py
import bpy
import bmesh
import math
import random
from mathutils import Vector, Matrix

NAAM = "hakbijl"
rng = random.Random(7)


def opruimen():
    for ob in list(bpy.data.objects):
        if ob.name.startswith(NAAM) or ob.name.startswith("kijk_"):
            bpy.data.objects.remove(ob, do_unlink=True)
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)
    for m in list(bpy.data.materials):
        if m.name.startswith(NAAM) and m.users == 0:
            bpy.data.materials.remove(m)
    for im in list(bpy.data.images):
        if im.name.startswith(NAAM) and im.users == 0:
            bpy.data.images.remove(im)
    for ob in bpy.data.objects:
        if ob.name in ("Cube", "Light"):
            ob.hide_render = True
            ob.hide_viewport = True


def nieuw_object(naam, bm, materialen):
    me = bpy.data.meshes.new(naam)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(naam, me)
    bpy.context.scene.collection.objects.link(ob)
    for m in materialen:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = False
    return ob


# ---------------------------------------------------------------- materialen
def _ramp(cr, stops):
    el = cr.color_ramp.elements
    while len(el) > 1:
        el.remove(el[-1])
    el[0].position = stops[0][0]
    el[0].color = stops[0][1]
    for pos, kleur in stops[1:]:
        e = el.new(pos)
        e.color = kleur


def mat_hout(naam, donker, midden, licht, schaal=22.0, ruw=0.62):
    m = bpy.data.materials.new(naam)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0, 1.0, 0.18)
    golf = nt.nodes.new("ShaderNodeTexWave")
    golf.wave_type = "BANDS"
    golf.bands_direction = "X"
    golf.inputs["Scale"].default_value = schaal
    golf.inputs["Distortion"].default_value = 3.2
    golf.inputs["Detail"].default_value = 5.0
    golf.inputs["Detail Roughness"].default_value = 0.6
    ruis = nt.nodes.new("ShaderNodeTexNoise")
    ruis.inputs["Scale"].default_value = 9.0
    ruis.inputs["Detail"].default_value = 4.0
    # fac = golf*0.6 + (ruis-0.5)*0.5, dus ruwweg 0..0.85
    ruis_c = nt.nodes.new("ShaderNodeMath")
    ruis_c.operation = "MULTIPLY_ADD"
    ruis_c.inputs[1].default_value = 0.5
    ruis_c.inputs[2].default_value = -0.25
    meng = nt.nodes.new("ShaderNodeMath")
    meng.operation = "MULTIPLY_ADD"
    meng.inputs[1].default_value = 0.6
    cr = nt.nodes.new("ShaderNodeValToRGB")
    _ramp(cr, [(0.0, donker), (0.45, midden), (0.85, licht)])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.10
    bump.inputs["Distance"].default_value = 0.01
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], golf.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], ruis.inputs["Vector"])
    nt.links.new(golf.outputs["Fac"], meng.inputs[0])
    nt.links.new(ruis.outputs["Fac"], ruis_c.inputs[0])
    nt.links.new(ruis_c.outputs[0], meng.inputs[2])
    nt.links.new(meng.outputs[0], cr.inputs["Fac"])
    nt.links.new(cr.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(golf.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = ruw
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def mat_staal(naam):
    m = bpy.data.materials.new(naam)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    # roestvlekken: grove ruis -> masker
    roest = nt.nodes.new("ShaderNodeTexNoise")
    roest.inputs["Scale"].default_value = 7.0
    roest.inputs["Detail"].default_value = 6.0
    roest.inputs["Roughness"].default_value = 0.7
    masker = nt.nodes.new("ShaderNodeValToRGB")
    _ramp(masker, [(0.56, (0, 0, 0, 1)), (0.70, (1, 1, 1, 1))])
    # gehamerd/vlekkerig staal: fijne ruis
    vlek = nt.nodes.new("ShaderNodeTexNoise")
    vlek.inputs["Scale"].default_value = 30.0
    vlek.inputs["Detail"].default_value = 5.0
    staal = nt.nodes.new("ShaderNodeValToRGB")
    _ramp(staal, [(0.3, (0.05, 0.055, 0.065, 1)), (0.7, (0.17, 0.18, 0.20, 1))])
    roestkleur = nt.nodes.new("ShaderNodeValToRGB")
    _ramp(roestkleur, [(0.3, (0.09, 0.055, 0.03, 1)), (0.7, (0.21, 0.125, 0.06, 1))])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    ruwmix = nt.nodes.new("ShaderNodeMath")
    ruwmix.operation = "MULTIPLY_ADD"  # ruw = masker*0.3 + 0.6
    ruwmix.inputs[1].default_value = 0.25
    ruwmix.inputs[2].default_value = 0.7
    metmix = nt.nodes.new("ShaderNodeMath")
    metmix.operation = "MULTIPLY_ADD"  # metaal = masker*-0.55 + 0.65
    metmix.inputs[1].default_value = -0.3
    metmix.inputs[2].default_value = 0.4
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    bump.inputs["Distance"].default_value = 0.01
    nt.links.new(tc.outputs["Object"], roest.inputs["Vector"])
    nt.links.new(tc.outputs["Object"], vlek.inputs["Vector"])
    nt.links.new(roest.outputs["Fac"], masker.inputs["Fac"])
    nt.links.new(vlek.outputs["Fac"], staal.inputs["Fac"])
    nt.links.new(vlek.outputs["Fac"], roestkleur.inputs["Fac"])
    nt.links.new(masker.outputs["Color"], mix.inputs["Factor"])
    nt.links.new(staal.outputs["Color"], mix.inputs[6])
    nt.links.new(roestkleur.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    nt.links.new(masker.outputs["Color"], ruwmix.inputs[0])
    nt.links.new(ruwmix.outputs[0], bsdf.inputs["Roughness"])
    nt.links.new(masker.outputs["Color"], metmix.inputs[0])
    nt.links.new(metmix.outputs[0], bsdf.inputs["Metallic"])
    nt.links.new(vlek.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def mat_slijpband(naam):
    m = bpy.data.materials.new(naam)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (0.2, 1.0, 1.0)
    golf = nt.nodes.new("ShaderNodeTexWave")
    golf.wave_type = "BANDS"
    golf.bands_direction = "Z"
    golf.inputs["Scale"].default_value = 120.0
    golf.inputs["Distortion"].default_value = 0.5
    golf.inputs["Detail"].default_value = 3.0
    cr = nt.nodes.new("ShaderNodeValToRGB")
    _ramp(cr, [(0.0, (0.70, 0.72, 0.75, 1)), (1.0, (0.84, 0.85, 0.87, 1))])
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], golf.inputs["Vector"])
    nt.links.new(golf.outputs["Fac"], cr.inputs["Fac"])
    nt.links.new(cr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.25
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


# ---------------------------------------------------------------- geometrie
def bouw_steel(bm, mat_index):
    """Stations van boven naar beneden: (z, x-midden, rx, ry). Ovaal, 10 kanten,
    lange as in het vlak van het blad (x)."""
    stations = [
        (0.535, 0.000, 0.0440, 0.0300),
        (0.505, 0.000, 0.0450, 0.0310),
        (0.330, 0.000, 0.0480, 0.0330),
        (0.300, 0.000, 0.0500, 0.0340),
        (0.150, 0.006, 0.0480, 0.0330),
        (0.000, 0.012, 0.0450, 0.0320),
        (-0.150, 0.012, 0.0420, 0.0305),
        (-0.290, 0.004, 0.0410, 0.0300),
        (-0.390, -0.008, 0.0450, 0.0320),
        (-0.455, -0.020, 0.0560, 0.0380),
        (-0.485, -0.028, 0.0570, 0.0385),
        (-0.505, -0.034, 0.0470, 0.0330),
    ]
    N = 8
    ringen = []
    for i, (z, xc, rx, ry) in enumerate(stations):
        ring = []
        for k in range(N):
            a = 2 * math.pi * k / N + math.pi / N
            r = 1.0 + rng.uniform(-0.025, 0.025)
            x = xc + rx * r * math.cos(a)
            y = ry * r * math.sin(a)
            zz = z
            if i == len(stations) - 1:
                zz += 0.014 * math.cos(a)  # schuin afgezaagd
            ring.append(bm.verts.new((x, y, zz)))
        ringen.append(ring)
    faces = []
    for r0, r1 in zip(ringen, ringen[1:]):
        for k in range(N):
            f = bm.faces.new((r0[k], r0[(k + 1) % N], r1[(k + 1) % N], r1[k]))
            faces.append(f)
    faces.append(bm.faces.new(list(reversed(ringen[0]))))
    faces.append(bm.faces.new(ringen[-1]))
    for f in faces:
        f.material_index = mat_index
    return faces


# De kop als loft van dwarsdoorsneden langs x (snede naar -x), naar Max' plaatje:
# een dik blokkig lijf (poll en oog even hoog, vlakke bovenkant), een blad dat
# breed uitloopt met een slijpvouw, kop ruim de helft van de steel-lengte breed.
# station: (x, z_onder, z_boven, dikte, buik) - buik = hoeveel het midden van de
# snede verder naar -x ligt (bolle snede)
STATIONS = [
    (0.140, 0.325, 0.485, 0.085, 0.0),   # poll-vlak (afgeschuind)
    (0.125, 0.310, 0.500, 0.110, 0.0),   # lijf
    (-0.020, 0.310, 0.500, 0.110, 0.0),  # lijf, begin van het blad
    (-0.100, 0.290, 0.505, 0.085, 0.0),  # wang
    (-0.235, 0.215, 0.510, 0.030, 0.0),  # slijpvouw
    (-0.285, 0.190, 0.510, 0.004, 0.016),  # snede
]
BAND_VANAF = 4  # vanaf dit station is het de blinkende slijpband
M = 4  # punten per station langs z (onder .. boven)


def bouw_kop(bm, mat_staal_i, mat_band_i):
    ringen = []
    for (x, z0, z1, t, buik) in STATIONS:
        ring = {1: [], -1: []}
        for i in range(M + 1):
            u = i / M
            z = z0 + (z1 - z0) * u
            xx = x - buik * (1.0 - (2 * u - 1) ** 2)
            for s_ in (1, -1):
                ring[s_].append(bm.verts.new((xx, s_ * t * 0.5, z)))
        ringen.append(ring)
    faces = []
    band = []
    for k in range(len(STATIONS) - 1):
        r0, r1 = ringen[k], ringen[k + 1]
        doel = band if k + 1 >= BAND_VANAF else faces
        for i in range(M):
            doel.append(bm.faces.new((r0[1][i], r1[1][i], r1[1][i + 1], r0[1][i + 1])))
            doel.append(bm.faces.new((r0[-1][i + 1], r1[-1][i + 1], r1[-1][i], r0[-1][i])))
        doel.append(bm.faces.new((r0[-1][0], r1[-1][0], r1[1][0], r0[1][0])))          # onderkant
        doel.append(bm.faces.new((r0[1][M], r1[1][M], r1[-1][M], r0[-1][M])))          # bovenkant
    # poll-vlak en de snede (dun randje) dicht
    r = ringen[0]
    faces.append(bm.faces.new([r[1][i] for i in range(M + 1)] + [r[-1][i] for i in range(M, -1, -1)]))
    r = ringen[-1]
    band.append(bm.faces.new([r[-1][i] for i in range(M + 1)] + [r[1][i] for i in range(M, -1, -1)]))
    alle = faces + band
    bmesh.ops.recalc_face_normals(bm, faces=alle)
    bm.normal_update()
    for f in faces:
        f.material_index = mat_staal_i
    for f in band:
        f.material_index = mat_band_i


def bouw_wig(bm, mat_index):
    # wig bovenop in het oog: iets schuin, lichter hout
    c = Vector((0.0, 0.0, 0.534))
    sx, sy, sz = 0.07, 0.018, 0.03
    pts = []
    for dz in (-1, 1):
        for dy in (-1, 1):
            for dx in (-1, 1):
                k = 1.0 if dz > 0 else 0.8
                pts.append(bm.verts.new((c.x + dx * sx * 0.5 * k, c.y + dy * sy * 0.5 * k, c.z + dz * sz * 0.5)))
    idx = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    for q in idx:
        f = bm.faces.new([pts[i] for i in q])
        f.material_index = mat_index
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))


def mat_plat(naam, kleur, ruw=0.6, metaal=0.0):
    m = bpy.data.materials.new(naam)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = kleur
    bsdf.inputs["Roughness"].default_value = ruw
    bsdf.inputs["Metallic"].default_value = metaal
    return m


def bouw():
    opruimen()
    m_hout = mat_plat(NAAM + "_hout", (0.19, 0.095, 0.038, 1), ruw=0.8)
    m_staal = mat_plat(NAAM + "_staal", (0.07, 0.075, 0.085, 1), ruw=0.55, metaal=0.5)
    m_band = mat_plat(NAAM + "_slijpband", (0.42, 0.44, 0.47, 1), ruw=0.3, metaal=0.9)
    m_wig = mat_plat(NAAM + "_wig", (0.30, 0.16, 0.07, 1), ruw=0.8)
    bm = bmesh.new()
    bouw_steel(bm, 0)
    bouw_kop(bm, 1, 2)
    bouw_wig(bm, 3)
    ob = nieuw_object(NAAM, bm, [m_hout, m_staal, m_band, m_wig])
    return ob


def kijkscene(ob):
    sc = bpy.context.scene
    for o in list(bpy.data.objects):
        if o.name.startswith("kijk_"):
            bpy.data.objects.remove(o, do_unlink=True)
    cam_data = bpy.data.cameras.new("kijk_cam")
    cam = bpy.data.objects.new("kijk_cam", cam_data)
    sc.collection.objects.link(cam)
    cam_data.lens = 70
    cam.location = (0.3, -2.6, 0.45)
    cam.rotation_euler = (math.radians(86), 0, math.radians(10))
    sc.camera = cam
    def lamp(naam, soort, loc, energie, kleur=(1, 1, 1), maat=1.0):
        d = bpy.data.lights.new(naam, soort)
        d.energy = energie
        d.color = kleur
        if soort == "AREA":
            d.size = maat
        o = bpy.data.objects.new(naam, d)
        sc.collection.objects.link(o)
        o.location = loc
        # richt op de bijl
        richting = Vector((0, 0, 0)) - Vector(loc)
        o.rotation_euler = richting.to_track_quat("-Z", "Y").to_euler()
        return o
    lamp("kijk_key", "AREA", (-1.4, -1.6, 1.8), 150, (1.0, 0.96, 0.9), 1.5)
    lamp("kijk_fill", "AREA", (1.8, -1.4, 0.4), 45, (0.85, 0.9, 1.0), 2.5)
    lamp("kijk_rim", "AREA", (0.6, 1.6, 1.2), 110, (1, 1, 1), 1.0)
    w = sc.world or bpy.data.worlds.new("World")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.09, 0.09, 0.09, 1)
        bg.inputs[1].default_value = 1.0
    sc.render.engine = "BLENDER_EEVEE"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.resolution_x = 900
    sc.render.resolution_y = 900
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    # de bijl schuin zoals op het voorbeeld: kop linksboven, steel naar rechtsonder
    ob.rotation_euler = (0.0, math.radians(-32), math.radians(18))
    ob.location = (0.0, 0.0, 0.05)


def render_hoek(pad, loc, rot):
    cam = bpy.data.objects.get("kijk_cam")
    oud = (tuple(cam.location), tuple(cam.rotation_euler))
    cam.location = loc
    cam.rotation_euler = rot
    render(pad)
    cam.location, cam.rotation_euler = oud


def render(pad):
    sc = bpy.context.scene
    sc.render.filepath = pad
    sc.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)


ob = bouw()
kijkscene(ob)
me = ob.data
result = {"verts": len(me.vertices), "faces": len(me.polygons),
          "tris": sum(len(p.vertices) - 2 for p in me.polygons),
          "mats": [m.name for m in me.materials]}
