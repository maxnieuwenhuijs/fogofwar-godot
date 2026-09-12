# -*- coding: utf-8 -*-
"""Zet een Tripo-glb als diorama-prop in het spel.

    python tools/verwerk_prop.py <bestand.glb> <naam> [--team red|blue] [--draai 90]
        [--textuur 1024] [--doel 1500] [--hoogte 1.0] [--droogloop] [--geen-controles]
        [--geen-preview] [--godot <pad>] [--blender <pad>]

  <naam>            de prop zoals in PROP-WISHLIST.md, zonder `prop_` en zonder team:
                    tent, molen, kanon, toilethuisje ...
  --team red|blue   de arme (red) of de rijke (blue) versie; zonder team is het
                    de gedeelde prop die in beide kampen staat
  --draai <graden>  om de staande as, zodat de voorkant (opening, deur, gezicht)
                    naar +Z wijst: naar de speler toe. Lees hem af van de plaat
                    van tools/blender_prop_preview.py (dit script maakt er een
                    van het resultaat in results/props/).
  --hoogte <eenh>   ware hoogte in bord-eenheden (een tegel is 1, een pion 0,62);
                    schrijft prop_<naam>[_team].json. Zonder: PROP_HOOGTE in
                    omgeving.gd, of de standaard van de plek.

Wat er gebeurt:
  1. de glb wordt gelezen en gemeten: driehoeken, meshes, materialen, texturen, doos
  2. boven --doel driehoeken: tools/blender_decimate.py naar dat aantal (Blender)
  3. de texturen worden afgeslankt: kleur en ruwheid als JPEG, normaal als PNG,
     hoogstens --textuur px (de ruwheid de helft); ze krijgen leesbare namen,
     zodat Godot ze bij de import naast de glb zet als
     prop_<naam>_<team>_kleur.jpg, _normaal.png, _ruwheid.jpg
  4. --draai wordt in de glb gebakken (een wortelknoop met die rotatie)
  5. het resultaat gaat naar assets/models/props/prop_<naam>[_<team>].glb
  6. controles (tenzij --geen-controles): Godot --import; de .import van de
     uitgepakte texturen op VRAM-compressie + mipmaps (de normaal als normal
     map) en nog een --import; dan `-- omgevingcheck`, die PASS moet geven en
     de prop als geleverde glb moet noemen.

Een Tripo-glb is een mesh met een materiaal en drie texturen van 2048 die samen
9 MB wegen; op het scherm is een prop 40-110 px hoog. Na dit script is hij
een halve tot anderhalve MB en ziet niemand het verschil. Het origineel blijft
staan waar het stond.
"""
import argparse
import io
import json
import math
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(PROJ)
sys.path.insert(0, os.path.join(PROJ, "tools"))
try:
    from bouw_modellen import BLENDER_STANDAARD  # noqa: E402
except Exception:  # noqa: BLE001
    BLENDER_STANDAARD = r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"
GODOT_STANDAARD = os.path.join(
    "C:", os.sep, "Users", "maxni", "Downloads", "Godot_v4.7-stable_win64.exe",
    "Godot_v4.7-stable_win64_console.exe")
PROPS_DIR = os.path.join("assets", "models", "props")
TEAMS = {"red": "red", "rood": "red", "blue": "blue", "blauw": "blue"}

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:  # noqa: BLE001
    pass

GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942


# ------------------------------------------------------------------ glb lezen/schrijven

def lees_glb(pad):
    d = open(pad, "rb").read()
    if len(d) < 12:
        raise ValueError("%s is geen glb (te klein)" % pad)
    magic, versie, lengte = struct.unpack_from("<III", d, 0)
    if magic != GLB_MAGIC:
        raise ValueError("%s is geen glb (magic %08x); een .gltf met losse bestanden kan dit script niet aan" % (pad, magic))
    off = 12
    js = None
    bin_ = b""
    while off + 8 <= min(lengte, len(d)):
        cl, ct = struct.unpack_from("<II", d, off)
        off += 8
        chunk = d[off:off + cl]
        off += cl
        if ct == CHUNK_JSON:
            js = json.loads(chunk.decode("utf-8"))
        elif ct == CHUNK_BIN:
            bin_ = chunk
    if js is None:
        raise ValueError("%s: geen JSON-chunk" % pad)
    return js, bin_


def schrijf_glb(pad, js, bin_):
    jb = json.dumps(js, separators=(",", ":")).encode("utf-8")
    jb += b" " * ((4 - len(jb) % 4) % 4)
    bb = bin_ + b"\0" * ((4 - len(bin_) % 4) % 4)
    totaal = 12 + 8 + len(jb) + 8 + len(bb)
    os.makedirs(os.path.dirname(os.path.abspath(pad)) or ".", exist_ok=True)
    with open(pad, "wb") as f:
        f.write(struct.pack("<III", GLB_MAGIC, 2, totaal))
        f.write(struct.pack("<II", len(jb), CHUNK_JSON))
        f.write(jb)
        f.write(struct.pack("<II", len(bb), CHUNK_BIN))
        f.write(bb)


def bufferview_bytes(js, bin_, bvi):
    bv = js["bufferViews"][bvi]
    s = bv.get("byteOffset", 0)
    return bin_[s:s + bv["byteLength"]]


# ------------------------------------------------------------------ meten

def meet(js, bin_):
    """Driehoeken, primitieven, doos en de texturen met hun maat."""
    acc = js.get("accessors", [])
    tris = 0
    prims = 0
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    for m in js.get("meshes", []):
        for pr in m.get("primitives", []):
            prims += 1
            mode = pr.get("mode", 4)
            if "indices" in pr:
                n = acc[pr["indices"]]["count"]
            else:
                n = acc[pr["attributes"]["POSITION"]]["count"]
            if mode == 4:
                tris += n // 3
            elif mode in (5, 6):
                tris += max(n - 2, 0)
            pa = acc[pr["attributes"]["POSITION"]]
            if "min" in pa and "max" in pa:
                for k in range(3):
                    lo[k] = min(lo[k], pa["min"][k])
                    hi[k] = max(hi[k], pa["max"][k])
    doos = [hi[k] - lo[k] for k in range(3)] if hi[0] > -1e8 else [0, 0, 0]
    plaatjes = []
    for i, im in enumerate(js.get("images", [])):
        data = plaatje_bytes(js, bin_, im)
        maat = png_of_jpeg_maat(data)
        plaatjes.append({"i": i, "naam": im.get("name", "image_%d" % i), "mime": im.get("mimeType", ""),
                         "bytes": len(data), "maat": maat})
    return {"tris": tris, "prims": prims, "meshes": len(js.get("meshes", [])),
            "materialen": len(js.get("materials", [])), "doos": doos, "lo": lo, "hi": hi,
            "plaatjes": plaatjes, "skins": len(js.get("skins", [])),
            "animaties": len(js.get("animations", []))}


def plaatje_bytes(js, bin_, im):
    if "bufferView" in im:
        return bufferview_bytes(js, bin_, im["bufferView"])
    uri = im.get("uri", "")
    if uri.startswith("data:"):
        import base64
        return base64.b64decode(uri.split(",", 1)[1])
    raise ValueError("plaatje %s verwijst naar een los bestand (%s); lever een glb met de texturen erin" % (im.get("name"), uri))


def png_of_jpeg_maat(b):
    try:
        from PIL import Image
        im = Image.open(io.BytesIO(b))
        return im.size
    except Exception:  # noqa: BLE001
        if b[:8] == b"\x89PNG\r\n\x1a\n":
            return struct.unpack(">II", b[16:24])
        return (0, 0)


def rollen(js):
    """Plaatje-index -> rol (kleur, normaal, ruwheid, occlusie, emissie) uit de
    materialen; een plaatje dat niemand gebruikt heet extra<N>."""
    tex = js.get("textures", [])
    uit = {}

    def zet(ref, rol):
        if not isinstance(ref, dict) or "index" not in ref:
            return
        ti = ref["index"]
        if ti < 0 or ti >= len(tex) or "source" not in tex[ti]:
            return
        uit.setdefault(tex[ti]["source"], rol)

    for mat in js.get("materials", []):
        pbr = mat.get("pbrMetallicRoughness", {})
        zet(pbr.get("baseColorTexture"), "kleur")
        zet(pbr.get("metallicRoughnessTexture"), "ruwheid")
        zet(mat.get("normalTexture"), "normaal")
        zet(mat.get("occlusionTexture"), "occlusie")
        zet(mat.get("emissiveTexture"), "emissie")
    for i in range(len(js.get("images", []))):
        uit.setdefault(i, "extra%d" % i)
    return uit


# ------------------------------------------------------------------ afslanken

def alfa_beelden(js):
    """Plaatje-indices waarvan de alfa ECHT telt: de kleurtextuur van een
    materiaal met alphaMode BLEND of MASK. Tripo zet in elke kleurtextuur wel
    ergens wat alfa, maar zonder zo'n alphaMode rendert niemand die."""
    tex = js.get("textures", [])
    uit = set()
    for mat in js.get("materials", []):
        if mat.get("alphaMode", "OPAQUE") == "OPAQUE":
            continue
        ref = mat.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if isinstance(ref, dict) and 0 <= ref.get("index", -1) < len(tex) and "source" in tex[ref["index"]]:
            uit.add(tex[ref["index"]]["source"])
    return uit


def slank_plaatje(data, rol, maxpx, alfa_nodig=False):
    """(bytes, mime, ext, (w, h) nieuw, (w, h) oud)."""
    from PIL import Image
    im = Image.open(io.BytesIO(data))
    im.load()
    oud = im.size
    grens = maxpx if rol != "ruwheid" else max(maxpx // 2, 256)
    w, h = im.size
    if max(w, h) > grens:
        s = grens / float(max(w, h))
        im = im.resize((max(1, int(round(w * s))), max(1, int(round(h * s)))), Image.LANCZOS)
    uit = io.BytesIO()
    doorzichtig = False
    if alfa_nodig and rol == "kleur" and im.mode in ("RGBA", "LA"):
        alpha = im.getchannel("A")
        doorzichtig = alpha.getextrema()[0] < 250
    if rol == "normaal" or doorzichtig:
        (im if doorzichtig else im.convert("RGB")).save(uit, "PNG", optimize=True)
        return uit.getvalue(), "image/png", "png", im.size, oud
    # geen chroma-subsampling: de ruwheid zit in losse kanalen (G en B)
    im.convert("RGB").save(uit, "JPEG", quality=88, optimize=True, subsampling=0)
    return uit.getvalue(), "image/jpeg", "jpg", im.size, oud


def herbouw_bin(js, bin_, nieuw):
    """Schrijft de binaire buffer opnieuw met de nieuwe plaatjes (image-index ->
    bytes) op de plek van de oude; alle andere bufferViews gaan ongewijzigd mee."""
    bvs = js.get("bufferViews", [])
    beeld_bv = {}
    for i, im in enumerate(js.get("images", [])):
        if "bufferView" in im:
            beeld_bv[im["bufferView"]] = i
    uit = bytearray()
    for bi, bv in enumerate(bvs):
        if bi in beeld_bv and beeld_bv[bi] in nieuw:
            data = nieuw[beeld_bv[bi]]
        else:
            data = bufferview_bytes(js, bin_, bi)
        while len(uit) % 4:
            uit.append(0)
        bv["byteOffset"] = len(uit)
        bv["byteLength"] = len(data)
        uit += data
    # plaatjes die als data-uri kwamen: alsnog in de buffer
    for i, im in enumerate(js.get("images", [])):
        if "bufferView" not in im and i in nieuw:
            while len(uit) % 4:
                uit.append(0)
            bvs.append({"buffer": 0, "byteOffset": len(uit), "byteLength": len(nieuw[i])})
            im["bufferView"] = len(bvs) - 1
            im.pop("uri", None)
            uit += nieuw[i]
    js["bufferViews"] = bvs
    if not js.get("buffers"):
        js["buffers"] = [{}]
    js["buffers"][0] = {"byteLength": len(uit)}
    return bytes(uit)


def bak_draai(js, graden, naam):
    """Een wortelknoop met de draai om de staande as boven alles wat er was.
    Draai je een tweede keer, dan vervangt hij de hoek in plaats van te stapelen."""
    q = [0.0, math.sin(math.radians(graden) * 0.5), 0.0, math.cos(math.radians(graden) * 0.5)]
    si = js.get("scene", 0)
    scene = js["scenes"][si]
    wortels = scene.get("nodes", [])
    if len(wortels) == 1:
        n = js["nodes"][wortels[0]]
        if n.get("name", "").startswith("draai_") and "mesh" not in n:
            n["rotation"] = q
            n["name"] = "draai_%d" % int(round(graden)) % 360
            return
    js["nodes"].append({"name": "draai_%d" % (int(round(graden)) % 360), "rotation": q, "children": list(wortels)})
    scene["nodes"] = [len(js["nodes"]) - 1]


# ------------------------------------------------------------------ Godot

def _godot(godot, args, timeout=900):
    r = subprocess.run([godot, "--headless", "--path", "."] + args, capture_output=True,
                       text=True, errors="replace", cwd=PROJ, timeout=timeout)
    return r.returncode, (r.stdout + r.stderr).splitlines()


def zet_textuur_import(pad, normaal):
    """De .import van een uitgepakte textuur: VRAM-compressie, mipmaps, geen
    detect_3d-gedoe; een normaal als normal map."""
    ip = pad + ".import"
    if not os.path.exists(ip):
        return False
    s = io.open(ip, encoding="utf-8").read()
    wil = {"compress/mode": "2", "mipmaps/generate": "true", "detect_3d/compress_to": "0",
           "process/size_limit": "0", "compress/normal_map": "1" if normaal else "0"}
    for k, v in wil.items():
        s, n = re.subn(r"(?m)^%s=.*$" % re.escape(k), "%s=%s" % (k, v), s)
        if n == 0:
            s = s.rstrip("\n") + "\n%s=%s\n" % (k, v)
    with open(ip, "wb") as f:
        f.write(s.encode("utf-8"))
    return True


def controleer(godot, bestandsnaam, naam, textuur_max):
    problemen = 0
    if not os.path.exists(godot):
        print("  Godot niet gevonden (%s); controles overgeslagen. Zet GODOT_PATH of --godot <pad>." % godot)
        return 1
    print("  importeren...")
    code, regels = _godot(godot, ["--import"])
    if code != 0:
        print("  FOUT: Godot --import gaf foutcode %d" % code)
        for r in regels[-8:]:
            print("    " + r)
        problemen += 1
    # de texturen die Godot naast de glb heeft gezet
    stam = os.path.splitext(bestandsnaam)[0] + "_"
    uitgepakt = sorted(f for f in os.listdir(PROPS_DIR)
                       if f.startswith(stam) and f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")))
    gewijzigd = 0
    for f in uitgepakt:
        if zet_textuur_import(os.path.join(PROPS_DIR, f), "normaal" in f):
            gewijzigd += 1
    if uitgepakt:
        print("  texturen naast de glb: %s" % ", ".join(uitgepakt))
    if gewijzigd:
        print("  import-instellingen gezet (VRAM-compressie + mipmaps), nog een keer importeren...")
        code, regels = _godot(godot, ["--import"])
        if code != 0:
            print("  FOUT: de tweede --import gaf foutcode %d" % code)
            problemen += 1
    print("  omgevingcheck...")
    code, regels = _godot(godot, ["res://tools/capture.tscn", "--", "omgevingcheck"], timeout=1200)
    gezien = [r for r in regels if "geleverde glb-props" in r and ("prop_%s " % naam) in r and bestandsnaam in r]
    fouten = [r for r in regels if "SCRIPT ERROR" in r or "[OMGEVING] FOUT" in r]
    uitslag = [r for r in regels if r.startswith("[OMGEVING] PASS") or r.startswith("[OMGEVING] FAIL")]
    for r in fouten[:6]:
        print("    " + r.strip())
    if not uitslag or not uitslag[-1].startswith("[OMGEVING] PASS"):
        print("  FOUT: omgevingcheck %s" % (uitslag[-1] if uitslag else "gaf geen uitslag (code %d)" % code))
        problemen += 1
    else:
        print("  omgevingcheck: PASS")
    if gezien:
        print("  in het diorama: " + gezien[0].split("geleverde glb-props: ", 1)[1].strip())
    else:
        print("  FOUT: geen diorama noemt prop_%s uit %s. Staat de naam in DIORAMAS, GLB_VERVANGBAAR of EXTRA_PROPS van omgeving.gd?" % (naam, bestandsnaam))
        problemen += 1
    return problemen


# ------------------------------------------------------------------ hoofdprogramma

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("bestand", help="de glb van Tripo (blijft staan)")
    p.add_argument("naam", help="propnaam zonder prop_ en zonder team, bv tent")
    p.add_argument("--team", default="", help="red/rood of blue/blauw; leeg = gedeeld")
    p.add_argument("--draai", type=float, default=0.0, help="graden om de staande as (voorkant naar +Z)")
    p.add_argument("--textuur", type=int, default=1024, help="grootste textuurmaat in px (standaard 1024)")
    p.add_argument("--doel", type=int, default=1500, help="boven dit aantal driehoeken wordt gedecimeerd")
    p.add_argument("--hoogte", type=float, default=None, help="ware hoogte in bord-eenheden (schrijft het manifest)")
    p.add_argument("--droogloop", action="store_true", help="alleen meten en vertellen, niets schrijven")
    p.add_argument("--geen-controles", action="store_true")
    p.add_argument("--geen-preview", action="store_true")
    p.add_argument("--godot", default=os.environ.get("GODOT_PATH", GODOT_STANDAARD))
    p.add_argument("--blender", default=BLENDER_STANDAARD)
    a = p.parse_args()

    naam = a.naam.strip().lower()
    if naam.startswith("prop_"):
        naam = naam[5:]
    for t in ("_red", "_blue"):
        if naam.endswith(t) and not a.team:
            a.team = t[1:]
            naam = naam[:-len(t)]
    if not re.match(r"^[a-z0-9_]+$", naam):
        print("FOUT: naam '%s' mag alleen kleine letters, cijfers en _ bevatten" % naam)
        return 2
    team = ""
    if a.team:
        team = TEAMS.get(a.team.strip().lower(), "")
        if not team:
            print("FOUT: --team moet red/rood of blue/blauw zijn")
            return 2
    bestandsnaam = "prop_%s%s.glb" % (naam, "_" + team if team else "")
    uit = os.path.join(PROPS_DIR, bestandsnaam)
    bron = a.bestand
    if not os.path.exists(bron):
        print("FOUT: %s bestaat niet" % bron)
        return 2

    js, bin_ = lees_glb(bron)
    m = meet(js, bin_)
    print("%s -> %s%s" % (os.path.basename(bron), uit, "  (droogloop)" if a.droogloop else ""))
    print("  geleverd: %d driehoeken in %d mesh(es), %d primitieven, %d materia(a)l(en); doos %.2f x %.2f x %.2f (b x h x d); %.1f MB"
          % (m["tris"], m["meshes"], m["prims"], m["materialen"], m["doos"][0], m["doos"][1], m["doos"][2],
             os.path.getsize(bron) / 1e6))
    for pl in m["plaatjes"]:
        print("    textuur %s: %dx%d %s, %.1f MB" % (pl["naam"], pl["maat"][0], pl["maat"][1], pl["mime"], pl["bytes"] / 1e6))
    if m["skins"] or m["animaties"]:
        print("  LET OP: %d skin(s) en %d animatie(s); een prop hoort statisch te zijn (een bewoner gaat via verwerk_levering.py)"
              % (m["skins"], m["animaties"]))
    if m["prims"] > 1:
        print("  LET OP: %d primitieven = %d draw calls; een prop als EEN mesh met EEN materiaal is goedkoper op een telefoon" % (m["prims"], m["prims"]))
    if m["tris"] == 0:
        print("FOUT: geen driehoeken gevonden")
        return 1

    # 2. decimeren als het moet
    tmpmap = tempfile.mkdtemp(prefix="prop_")
    try:
        if m["tris"] > a.doel:
            print("  %d driehoeken is boven het doel van %d: decimeren met Blender..." % (m["tris"], a.doel))
            if a.droogloop:
                print("  (droogloop: overgeslagen)")
            else:
                if not os.path.exists(a.blender):
                    print("FOUT: Blender niet gevonden (%s); geef --blender <pad> of een hoger --doel" % a.blender)
                    return 1
                tmp = os.path.join(tmpmap, "gedecimeerd.glb")
                r = subprocess.run([a.blender, "--background", "--python", os.path.join("tools", "blender_decimate.py"),
                                    "--", "--in", os.path.abspath(bron), "--out", tmp, "--doel", str(a.doel)],
                                   capture_output=True, text=True, errors="replace", cwd=PROJ, timeout=900)
                for regel in r.stdout.splitlines():
                    if regel.startswith("DECIMATE"):
                        print("    " + regel)
                if not os.path.exists(tmp):
                    print("FOUT: decimeren mislukt")
                    print(r.stdout[-1500:])
                    print(r.stderr[-1500:])
                    return 1
                js, bin_ = lees_glb(tmp)
                m = meet(js, bin_)
                print("  na decimeren: %d driehoeken" % m["tris"])

        # 3. texturen afslanken en hernoemen
        rol_van = rollen(js)
        met_alfa = alfa_beelden(js)
        nieuw = {}
        totaal_oud = 0
        totaal_nieuw = 0
        for im_i, im in enumerate(js.get("images", [])):
            rol = rol_van.get(im_i, "extra%d" % im_i)
            data = plaatje_bytes(js, bin_, im)
            totaal_oud += len(data)
            try:
                b, mime, ext, maat, oud = slank_plaatje(data, rol, a.textuur, im_i in met_alfa)
            except Exception as e:  # noqa: BLE001
                print("  LET OP: textuur %s niet te lezen (%s), blijft zoals hij is" % (im.get("name"), e))
                continue
            totaal_nieuw += len(b)
            print("    %-8s %dx%d -> %dx%d %s, %.2f MB -> %.2f MB" % (rol, oud[0], oud[1], maat[0], maat[1], ext, len(data) / 1e6, len(b) / 1e6))
            nieuw[im_i] = b
            im["name"] = rol
            im["mimeType"] = mime
        if a.droogloop:
            print("  texturen samen %.1f MB -> %.1f MB; draai %g graden; klaar (droogloop, niets geschreven)"
                  % (totaal_oud / 1e6, totaal_nieuw / 1e6, a.draai))
            return 0
        bin_ = herbouw_bin(js, bin_, nieuw)

        # 4. draai bakken
        if abs(a.draai) > 0.001:
            bak_draai(js, a.draai, naam)
        js.setdefault("asset", {})["generator"] = "Tripo via tools/verwerk_prop.py"
        js["asset"]["version"] = "2.0"
        js["asset"]["extras"] = {"bron": os.path.basename(bron), "draai": a.draai, "naam": naam, "team": team}

        # 5. schrijven
        bestond = os.path.exists(uit)
        schrijf_glb(uit, js, bin_)
        print("  geschreven: %s (%.2f MB%s)" % (uit, os.path.getsize(uit) / 1e6, ", vervangt de vorige" if bestond else ""))
        if a.hoogte is not None:
            mp = os.path.join(PROPS_DIR, os.path.splitext(bestandsnaam)[0] + ".json")
            man = {}
            if os.path.exists(mp):
                try:
                    man = json.load(io.open(mp, encoding="utf-8"))
                except ValueError:
                    man = {}
            man["hoogte"] = a.hoogte
            with open(mp, "wb") as f:
                f.write((json.dumps(man, indent=2) + "\n").encode("utf-8"))
            print("  manifest: %s (hoogte %g)" % (mp, a.hoogte))
    finally:
        shutil.rmtree(tmpmap, ignore_errors=True)

    # preview van het resultaat
    if not a.geen_preview:
        if os.path.exists(a.blender):
            plaat = os.path.join("results", "props", os.path.splitext(bestandsnaam)[0] + "_preview.png")
            r = subprocess.run([a.blender, "--background", "--python", os.path.join("tools", "blender_prop_preview.py"),
                                "--", "--in", os.path.abspath(uit), "--uit", plaat],
                               capture_output=True, text=True, errors="replace", cwd=PROJ, timeout=600)
            if os.path.exists(plaat):
                print("  preview: %s (links = zoals hij nu in het spel staat, gezien vanaf de speler)" % plaat)
            else:
                print("  preview mislukt: %s" % r.stdout[-600:])
        else:
            print("  geen Blender gevonden, geen preview")

    # 6. controles
    problemen = 0
    if not a.geen_controles:
        problemen = controleer(a.godot, bestandsnaam, naam, a.textuur)
    print("KLAAR: %s%s" % (bestandsnaam, "" if problemen == 0 else "  (%d probleem/problemen, zie boven)" % problemen))
    print("  daarna: python tools/bouw_prop_tracker.py, en de bestanden in %s committen (glb, texturen, .import)" % PROPS_DIR)
    return 0 if problemen == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
