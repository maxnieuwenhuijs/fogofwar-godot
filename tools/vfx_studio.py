# -*- coding: utf-8 -*-
"""VFX-studio: per effect concept-plaatjes en filmpjes, naast de versie uit het
spel (6 oktober 2026, docs/VFX-studio.md stap 7).

Max: "moet dan met plaatjes werken als concept een prompt box of iets en dan ook
nog met seedance 2.5 een filmpje maken op basis van de het concept vfx en dat dan
maken?", en zijn voorstel: "Webpagina, zoals de geluid-studio: elk effect is een
rij. Er staat in waar en wanneer het gebeurt, met een promptvak voor
concept-plaatjes, een knop 'maak filmpje' (Seedance), een knop 'dit is hem' en
notities. Daarnaast staat de huidige versie uit het spel."

    python tools/vfx_studio.py [--poort 8775] [--geen-browser]
    python tools/vfx_studio.py --overzicht    telling als check (geen netwerk)
    python tools/vfx_studio.py --proef        alles tegen een nep-Replicate (kost niets)

Een lokale webpagina (alleen op deze machine):

* Elk effect uit de catalogus (scripts/vfx/vfx_catalogus.gd) is een rij, per
  groep: waar en wanneer, de status, de knoppen, en de wens en de
  concept-prompt uit VFX-WISHLIST.md. Een wens die alleen in de wishlist staat
  komt er ook bij; met "nieuwe wens" zet je er zelf een in de wishlist.
* "In het spel nu": het effect zoals de VFX-tuner het afspeelt, opgenomen door
  Godot (`-- vfxstudio`, met venster) via de knop "Spelbeelden maken". Een klik
  op een beeldje maakt het de basis voor een concept.
* Promptvak (Engels; leeg = de prompt uit de wishlist), "Maak plaatje" (een
  beeldmodel op Replicate, met of zonder een basis), per plaatje "Maak filmpje"
  (Seedance 2.5, het plaatje als eerste beeld) en "Filmpje van het spelbeeld"
  (het spel zelf als eerste beeld).
* "Dit is hem" zet een plaatje of filmpje in assets/vfx/referentie/<id>/ (in
  git; .gdignore, Godot kijkt er niet in): de afspraak over hoe het effect
  eruit moet zien. Prompts, notities, keuzes en instellingen staan in
  assets/vfx/referentie/studio.json.
* Wat Replicate maakt staat in results/vfx_studio/concept/<id>/ (niet in git)
  en blijft staan tot je het weggooit: elk plaatje en vooral elk filmpje kost
  geld. De pagina doet niets vanzelf. Een opdracht die nog loopt als je de
  studio sluit, haalt hij bij de volgende start alsnog op.
* De sleutel komt uit REPLICATE_API_TOKEN of uit het veld bovenaan; die wordt
  bewaard in %LOCALAPPDATA%\\FogOfWar\\replicate.key, nooit in de repo.

Texturen en decals (stap 8; Max: "het doel is om met de studio ook de textures
en alle decals die nodig zijn aan te leveren, en voor jou te zien wat er
gebeurt"): een groep met een rij per onderdeel uit ONDERDELEN in de catalogus
(kruitdamp, vlammen, bloed, voetsporen, krater, stof...). Per rij wat er nu in
assets/textures/<map>/ staat (een flipbook speelt af, op een ruitjesachtergrond
voor de doorzichtigheid) en de kandidaten: zelf erin slepen (png, jpg, webp,
gif, mp4), laten maken (plaatje of filmpje, vierkant), een flipbook uit een
filmpje knippen (OpenCV), de achtergrond weghalen (zwart, wit of groen wordt
doorzichtig), en "in het spel": de juiste naam in de juiste map, de oude naar
results/vfx_studio/backup/. Godot importeert hem daarna (de editor zelf, of de
knop "Importeer in Godot" als de editor dicht is). Van elk filmpje maakt de
studio een contactvel (12 beelden met de tijd), zodat Claude kan zien wat er
gebeurt.
"""
import argparse
import base64
import glob
import io
import itertools
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import threading
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    from PIL import Image, ImageDraw, ImageSequence
except ImportError:  # zonder PIL: geen bewegend spelbeeld, geen verkleinde basis, geen onderdelen
    Image = ImageDraw = ImageSequence = None
try:
    import numpy as np
except ImportError:
    np = None

WORTEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(WORTEL)

CATALOGUS_GD = os.path.join("scripts", "vfx", "vfx_catalogus.gd")
STIJL_GD = os.path.join("scripts", "vfx", "stijl.gd")
TUNING_JSON = os.path.join("assets", "models", "effects_tuning.json")
GODOT_STANDAARD = r"C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
UA = "FogOfWar-vfx-studio/1.0"

# Paden en de API in een dict, zodat --proef ze kan omleggen.
P = {
    "wishlist": "VFX-WISHLIST.md",
    "texturen": os.path.join("assets", "textures"),
    "ref": os.path.join("assets", "vfx", "referentie"),
    "werk": os.path.join("results", "vfx_studio"),
    "sleutel": os.path.join(os.environ.get("LOCALAPPDATA", WORTEL), "FogOfWar", "replicate.key"),
    "api": os.environ.get("REPLICATE_API_BASE", "https://api.replicate.com/v1"),
    "poll_beeld": 2.0,
    "poll_film": 5.0,
}

BEELDMODELLEN = [
    ["google/nano-banana-2", "Nano Banana 2 (Google): snel, goed op een basis"],
    ["google/nano-banana-pro", "Nano Banana Pro (Google): het mooiste, duurder"],
    ["bytedance/seedream-5-lite", "Seedream 5 Lite (ByteDance)"],
    ["bytedance/seedream-4.5", "Seedream 4.5 (ByteDance)"],
]
FILMMODELLEN = [
    ["bytedance/seedance-2.5", "Seedance 2.5 (ByteDance)"],
]
STANDAARD = {
    "beeldmodel": "google/nano-banana-2",
    "filmmodel": "bytedance/seedance-2.5",
    "duur": 5,
    "resolutie": "480p",
    "geluid": False,
    "filmzin": "Fixed camera: no camera movement, no zoom and no cuts. The effect plays once, in real time.",
    "basiszin": "Keep this image exactly as it is (the board, the figures, the camera and the light) "
                "and only add or change this effect: ",
}

# Wat de modellen aannemen, voor als Replicate (nog) geen schema geeft: zonder
# sleutel, offline, en in de proef. Overgenomen van hun API-pagina's (6 oktober).
_BANANA = {
    "prompt": {"type": "string"},
    "image_input": {"type": "array"},
    "aspect_ratio": {"type": "string", "enum": ["match_input_image", "1:1", "2:3", "3:2", "3:4", "4:3", "4:5",
                                                "5:4", "9:16", "16:9", "21:9"]},
    "resolution": {"type": "string", "enum": ["1K", "2K", "4K"]},
    "output_format": {"type": "string", "enum": ["jpg", "png"]},
}
_SEEDREAM_AR = ["match_input_image", "1:1", "4:3", "3:4", "16:9", "9:16", "3:2", "2:3", "21:9"]
BEKEND = {
    "google/nano-banana-2": _BANANA,
    "google/nano-banana-pro": _BANANA,
    "bytedance/seedream-5-lite": {
        "prompt": {"type": "string"}, "image_input": {"type": "array"},
        "size": {"type": "string", "enum": ["2K", "3K"]},
        "aspect_ratio": {"type": "string", "enum": _SEEDREAM_AR},
        "output_format": {"type": "string", "enum": ["png", "jpeg"]},
    },
    "bytedance/seedream-4.5": {
        "prompt": {"type": "string"}, "image_input": {"type": "array"},
        "size": {"type": "string", "enum": ["2K", "4K", "custom"]},
        "aspect_ratio": {"type": "string", "enum": _SEEDREAM_AR},
    },
    "bytedance/seedance-2.5": {
        "prompt": {"type": "string"},
        "image": {"type": "string", "format": "uri"},
        "last_frame_image": {"type": "string", "format": "uri"},
        "reference_images": {"type": "array"},
        "duration": {"type": "integer", "minimum": -1, "maximum": 30},
        "resolution": {"type": "string", "enum": ["480p", "720p"]},
        "aspect_ratio": {"type": "string", "enum": ["16:9", "4:3", "1:1", "3:4", "9:16", "21:9", "adaptive"]},
        "generate_audio": {"type": "boolean"},
        "watermark": {"type": "boolean"},
        "output_format": {"type": "string", "enum": ["mp4", "mov"]},
        "seed": {"type": "integer"},
    },
}
FILM_EXT = (".mp4", ".mov", ".webm")
BEELD_EXT = (".png", ".jpg", ".jpeg", ".webp")
MIME = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp",
        ".gif": "image/gif", ".mp4": "video/mp4", ".mov": "video/quicktime", ".webm": "video/webm",
        ".json": "application/json"}

_lock = threading.RLock()        # studio.json, de wishlist en de meta's
_teller = itertools.count(1)
STUDIO_STEMPEL = "%d-%d" % (os.getpid(), int(time.time()))
_account = {"naam": "", "fout": ""}
_schemas = {}
_spel = {"bezig": False, "nu": "", "klaar": 0, "totaal": 0, "laatste": "", "fouten": []}
_cat_fout = ""


def _n(p):
    return p.replace("\\", "/") if p else ""


def studio_json():
    return os.path.join(P["ref"], "studio.json")


def spel_dir():
    return os.path.join(P["werk"], "spel")


def concept_dir():
    return os.path.join(P["werk"], "concept")


def mappen():
    """De mappen, elk met een .gdignore: de editor importeert anders elk plaatje."""
    for d in (P["ref"], P["werk"]):
        os.makedirs(d, exist_ok=True)
        gi = os.path.join(d, ".gdignore")
        if not os.path.exists(gi):
            io.open(gi, "w").close()


def _id_ok(eid):
    if not re.fullmatch(r"[a-z0-9_]+", str(eid or "")):
        raise RuntimeError("rare effect-id: %r" % eid)
    return str(eid)


def _veilig(p, onder=None):
    """Een pad van de pagina terug naar schijf, alleen binnen de werk- of
    referentiemap (of `onder`)."""
    a = os.path.abspath(os.path.normpath(str(p or "")))
    toegestaan = onder or [P["werk"], P["ref"], P["texturen"]]
    for d in toegestaan:
        dd = os.path.abspath(d)
        if a.startswith(dd + os.sep) and os.path.isfile(a):
            return a
    raise RuntimeError("bestand niet gevonden of buiten de studio: %s" % p)


def _rel(a):
    """Absoluut pad terug naar wat de pagina kent (relatief aan het project als dat kan)."""
    try:
        r = os.path.relpath(a, WORTEL)
        if not r.startswith(".."):
            return _n(r)
    except ValueError:
        pass
    return _n(a)


# ------------------------------------------------------------------ opslag

def lees_studio():
    try:
        d = json.load(io.open(studio_json(), encoding="utf-8"))
        if not isinstance(d, dict):
            d = {}
    except (OSError, ValueError):
        d = {}
    for k in ("prompts", "notities", "keuze", "goed"):
        if not isinstance(d.get(k), dict):
            d[k] = {}
    inst = dict(STANDAARD)
    inst.update(d.get("instellingen") or {})
    d["instellingen"] = inst
    return d


def schrijf_studio(d):
    os.makedirs(P["ref"], exist_ok=True)
    tmp = studio_json() + ".tmp"
    with io.open(tmp, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, indent=1, sort_keys=True, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, studio_json())


def lees_sleutel():
    k = os.environ.get("REPLICATE_API_TOKEN", "").strip()
    if k:
        return k
    try:
        return io.open(P["sleutel"], encoding="utf-8").read().strip()
    except OSError:
        return ""


def schrijf_sleutel(k):
    os.makedirs(os.path.dirname(P["sleutel"]), exist_ok=True)
    io.open(P["sleutel"], "w", encoding="utf-8").write(k.strip())


# ------------------------------------------------------------------ catalogus

def _gd_statement(tekst, i):
    """De expressie vanaf `i` tot het eind van het statement (een regeleinde
    buiten haakjes), zonder commentaar."""
    diep = 0
    in_str = False
    esc = False
    uit = []
    while i < len(tekst):
        c = tekst[i]
        if in_str:
            uit.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
            uit.append(c)
        elif c == "#":
            j = tekst.find("\n", i)
            i = len(tekst) if j < 0 else j
            continue
        elif c == "\n" and diep == 0:
            break
        else:
            if c in "[{(":
                diep += 1
            elif c in "]})":
                diep -= 1
            uit.append(c)
        i += 1
    return "".join(uit).strip()


class _Consts(dict):
    """De constanten van een GDScript-bestand, pas uitgerekend als iemand ze
    nodig heeft: de catalogus bouwt zijn knoppenlijsten uit andere constanten
    (`_VUUR + ["pan_flits"] + _ROOK`). Lijsten, dicts, getallen en teksten
    schrijft GDScript net als Python; dit leest alleen de eigen bronnen van het
    project, zonder builtins."""

    def __init__(self, pad):
        super().__init__(true=True, false=False, null=None)
        tekst = io.open(pad, encoding="utf-8").read()
        self.bron = {m.group(1): _gd_statement(tekst, m.end())
                     for m in re.finditer(r"^const\s+(\w+)\b[^=\n]*=\s*", tekst, re.M)}

    def __missing__(self, naam):
        if naam not in self.bron:
            raise KeyError(naam)
        try:
            waarde = eval(self.bron[naam], {"__builtins__": {}}, self)  # noqa: S307
        except Exception as e:  # noqa: BLE001
            raise RuntimeError("%s is niet te lezen: %s" % (naam, e))
        self[naam] = waarde
        return waarde


def _const(pad, naam):
    c = _Consts(pad)
    if naam not in c.bron:
        raise RuntimeError("%s niet gevonden in %s" % (naam, pad))
    return c[naam]


def _tuning():
    try:
        d = json.load(io.open(TUNING_JSON, encoding="utf-8"))
        return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def catalogus():
    """Groepen en effecten, met de knoppen en hun huidige waarde. Rechtstreeks uit
    de GDScript-bronnen (snel, Godot hoeft niet te draaien); lukt dat niet, dan uit
    de export die elke opname in Godot naast de spelbeelden legt."""
    global _cat_fout
    try:
        groepen = _const(CATALOGUS_GD, "GROEPEN")
        effecten = _const(CATALOGUS_GD, "EFFECTEN")
        knoppen = dict(_const(STIJL_GD, "KNOPPEN"))
        knoppen.update(_const(CATALOGUS_GD, "KNOPPEN"))
        bron = _n(CATALOGUS_GD)
        _cat_fout = ""
    except (OSError, ValueError, RuntimeError) as fout:
        try:
            d = json.load(io.open(os.path.join(spel_dir(), "catalogus.json"), encoding="utf-8"))
        except (OSError, ValueError):
            raise RuntimeError("De catalogus is niet te lezen (%s) en er is nog geen export." % fout)
        _cat_fout = "catalogus niet te lezen (%s); de export van de laatste opname wordt gebruikt" % fout
        groepen, effecten, knoppen = d["groepen"], d["effecten"], {}
        for e in effecten:
            for k in e.get("knoppen", []):
                if isinstance(k, dict):
                    knoppen[k["sleutel"]] = k
        bron = "export van de laatste opname"
    t = _tuning()
    uit = []
    for e in effecten:
        e = dict(e)
        ks = []
        for k in e.get("knoppen", []):
            sleutel = k["sleutel"] if isinstance(k, dict) else str(k)
            m = knoppen.get(sleutel, {})
            ks.append({"sleutel": sleutel, "label": m.get("label", sleutel),
                       "waarde": t.get(sleutel, m.get("def")), "def": m.get("def")})
        e["knoppen"] = ks
        uit.append(e)
    return {"groepen": groepen, "effecten": uit, "bron": bron}


# ------------------------------------------------------------------ wishlist

KOP_RE = re.compile(r"^##\s+(?:\d+\.\s*)?(.+?)\s*$")
WL_KOP = "| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |"


def _gelijk(s):
    return re.sub(r"\s+", " ", str(s or "").strip().lower())


def slug(naam, voor="wens_"):
    s = unicodedata.normalize("NFKD", str(naam)).encode("ascii", "ignore").decode("ascii").lower()
    s = re.sub(r"[^a-z0-9]+", "_", s).strip("_")
    return voor + (s or "zonder_naam")


def wishlist():
    """[(sectietitel, [rij...])] uit VFX-WISHLIST.md; een rij heeft naam,
    wanneer, status, notitie en prompt."""
    uit = []
    huidig = None
    try:
        regels = io.open(P["wishlist"], encoding="utf-8").read().split("\n")
    except OSError:
        return uit
    for regel in regels:
        m = KOP_RE.match(regel)
        if m:
            huidig = (m.group(1), [])
            uit.append(huidig)
            continue
        if huidig is None or not regel.startswith("|"):
            continue
        cellen = [c.strip() for c in regel.strip().strip("|").split("|")]
        if len(cellen) < 5 or cellen[0] in ("", "Effect") or set(cellen[0]) <= set("-: "):
            continue
        huidig[1].append({"naam": cellen[0], "wanneer": cellen[1], "status": cellen[2],
                          "notitie": cellen[3], "prompt": cellen[4]})
    return uit


def nieuwe_wens(groepnaam, naam, wanneer="", notitie="", prompt=""):
    """Een rij in de tabel van die groep in VFX-WISHLIST.md (een nieuwe sectie
    als de groep er nog niet staat). Geeft de id van de rij in de studio."""
    def cel(s):
        return re.sub(r"\s+", " ", str(s or "").replace("|", "/")).strip()
    naam = cel(naam)
    groepnaam = cel(groepnaam)
    if not naam:
        raise RuntimeError("Geef de wens een naam.")
    if not groepnaam:
        raise RuntimeError("In welke groep?")
    with _lock:
        for _t, rs in wishlist():
            if any(_gelijk(r["naam"]) == _gelijk(naam) for r in rs):
                raise RuntimeError("'%s' staat al in de wishlist." % naam)
        try:
            regels = io.open(P["wishlist"], encoding="utf-8").read().split("\n")
        except OSError:
            regels = ["# VFX-WISHLIST", ""]
        rij = "| %s | %s | wens | %s | %s |" % (naam, cel(wanneer), cel(notitie), cel(prompt))
        start = None
        for i, r in enumerate(regels):
            m = KOP_RE.match(r)
            if m and _gelijk(m.group(1)) == _gelijk(groepnaam):
                start = i
                break
        if start is None:
            nummer = 1 + sum(1 for r in regels if KOP_RE.match(r))
            while regels and regels[-1] == "":
                regels.pop()
            regels += ["", "## %d. %s" % (nummer, groepnaam), "", WL_KOP, "|---|---|---|---|---|", rij, ""]
        else:
            laatste = None
            i = start + 1
            while i < len(regels) and not KOP_RE.match(regels[i]):
                if regels[i].startswith("|"):
                    laatste = i
                i += 1
            if laatste is None:
                regels[start + 1:start + 1] = ["", WL_KOP, "|---|---|---|---|---|", rij]
            else:
                regels.insert(laatste + 1, rij)
        with io.open(P["wishlist"], "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(regels))
    return slug(naam)


# ------------------------------------------------------------------ spelbeelden

def spel_van(eid):
    d = os.path.join(spel_dir(), eid)
    if not os.path.isdir(d):
        return {}
    beelden = sorted(glob.glob(os.path.join(d, "spel_*.jpg")))
    rust = os.path.join(d, "rust.jpg")
    anim = ""
    for naam in ("spel.webp", "spel.gif"):
        if os.path.exists(os.path.join(d, naam)):
            anim = os.path.join(d, naam)
            break
    if not beelden and not os.path.exists(rust):
        return {}
    v = int(os.path.getmtime(beelden[-1] if beelden else rust))
    return {"rust": _rel(os.path.abspath(rust)) if os.path.exists(rust) else "",
            "beelden": [_rel(os.path.abspath(b)) for b in beelden],
            "anim": _rel(os.path.abspath(anim)) if anim else "",
            "tijd": time.strftime("%d-%m %H:%M", time.localtime(v)), "v": v}


def bouw_anim(eid):
    """Een bewegend plaatje (webp, anders gif) uit de opgenomen beelden, op ware
    snelheid: de rust kort, dan het effect, en een tel stil op het eind."""
    if Image is None:
        return False
    d = os.path.join(spel_dir(), eid)
    beelden = sorted(glob.glob(os.path.join(d, "spel_*.jpg")))
    if not beelden:
        return False
    try:
        info = json.load(io.open(os.path.join(d, "info.json"), encoding="utf-8"))
    except (OSError, ValueError):
        info = {}
    stap = max(0.04, float(info.get("stap", 0.12)))
    rust = os.path.join(d, "rust.jpg")
    paden = ([rust] if os.path.exists(rust) else []) + beelden
    ims = []
    for p in paden:
        im = Image.open(p).convert("RGB")
        if im.width > 480:
            im = im.resize((480, max(1, round(im.height * 480 / im.width))), Image.LANCZOS)
        ims.append(im)
    duren = [int(stap * 1000)] * len(ims)
    if os.path.exists(rust):
        duren[0] = 450
    duren[-1] = 800
    for oud in ("spel.webp", "spel.gif"):
        try:
            os.remove(os.path.join(d, oud))
        except OSError:
            pass
    try:
        ims[0].save(os.path.join(d, "spel.webp"), "WEBP", save_all=True, append_images=ims[1:],
                    duration=duren, loop=0, quality=80, method=4)
    except (OSError, ValueError, KeyError):
        ims[0].save(os.path.join(d, "spel.gif"), "GIF", save_all=True, append_images=ims[1:],
                    duration=duren, loop=0)
    return True


def spelbeelden(alleen=""):
    """Godot (met venster) speelt elk effect in de VFX-tuner af en neemt het op:
    `-- vfxstudio <map> [id]`. Draait los; de pagina vraagt de stand op."""
    if _spel["bezig"]:
        raise RuntimeError("Godot neemt al op.")
    if alleen:
        _id_ok(alleen)
    godot = os.environ.get("GODOT_PATH") or GODOT_STANDAARD
    if not os.path.exists(godot):
        raise RuntimeError("Godot niet gevonden: zet GODOT_PATH.")
    totaal = sum(1 for e in catalogus()["effecten"] if e.get("speel") and (not alleen or e["id"] == alleen))
    if totaal == 0:
        raise RuntimeError("Dit effect is nog niet af te spelen in de tuner.")
    os.makedirs(spel_dir(), exist_ok=True)
    _spel.update(bezig=True, nu="", klaar=0, totaal=totaal, laatste="Godot start...", fouten=[])

    def run():
        cmd = [godot, "--path", ".", "res://tools/capture.tscn", "--", "vfxstudio",
               os.path.abspath(spel_dir()).replace("\\", "/")]
        if alleen:
            cmd.append(alleen)
        try:
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                 encoding="utf-8", errors="replace")
            wacht = threading.Timer(1500, p.kill)
            wacht.start()
            for regel in p.stdout:
                regel = regel.rstrip()
                if "SCRIPT ERROR" in regel:
                    _spel["fouten"].append(regel[:200])
                m = re.match(r"\[VFXSTUDIO\] bezig (\S+)", regel)
                if m:
                    _spel["nu"] = m.group(1)
                m = re.match(r"\[VFXSTUDIO\] (\S+) (ok|FOUT)\b(.*)", regel)
                if m:
                    if m.group(2) == "ok":
                        bouw_anim(m.group(1))
                        _spel["klaar"] += 1
                    else:
                        _spel["fouten"].append(regel)
            p.wait(timeout=120)
            wacht.cancel()
            _spel["laatste"] = "klaar: %d van %d opgenomen%s" % (
                _spel["klaar"], _spel["totaal"],
                (", %d fout(en): %s" % (len(_spel["fouten"]), _spel["fouten"][0])) if _spel["fouten"] else "")
        except Exception as e:  # noqa: BLE001
            _spel["laatste"] = "mislukt: %s" % e
        _spel["bezig"] = False
        _spel["nu"] = ""

    threading.Thread(target=run, daemon=True).start()


# ------------------------------------------------------------------ Replicate

class ReplicateFout(RuntimeError):
    pass


def _vertaal(code, detail):
    if code == 401:
        return "De Replicate-sleutel klopt niet (401). Maak er een op replicate.com onder Account, API tokens."
    if code == 402:
        return "Geen tegoed op je Replicate-account (402): zet een betaalmethode of tegoed klaar onder Billing."
    if code == 404:
        return "Niet gevonden op Replicate (404): %s" % detail
    if code == 422:
        return "Replicate snapt de invoer niet (422): %s" % detail
    if code == 429:
        return "Te veel opdrachten tegelijk (429); probeer het zo opnieuw."
    return "Replicate gaf %d: %s" % (code, detail)


def _verzoek(methode, url, body=None, timeout=60, sleutel=None):
    sleutel = sleutel or lees_sleutel()
    if not sleutel:
        raise ReplicateFout("Geen Replicate-sleutel: plak hem bovenaan (replicate.com, Account, API tokens).")
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=methode)
    req.add_header("Authorization", "Bearer " + sleutel)
    req.add_header("User-Agent", UA)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            tekst = r.read().decode("utf-8")
            return json.loads(tekst) if tekst.strip() else {}
    except urllib.error.HTTPError as e:
        tekst = e.read().decode("utf-8", "replace")
        try:
            d = json.loads(tekst)
            detail = d.get("detail") or d.get("title") or tekst
        except ValueError:
            detail = tekst[:300]
        raise ReplicateFout(_vertaal(e.code, str(detail)[:400]))
    except (urllib.error.URLError, socket.timeout, ConnectionError) as e:
        raise ReplicateFout("Replicate niet bereikbaar: %s" % getattr(e, "reason", e))


def check_account(sleutel=None):
    try:
        d = _verzoek("GET", P["api"] + "/account", timeout=20, sleutel=sleutel)
        _account.update(naam=str(d.get("username") or d.get("name") or "?"), fout="")
    except ReplicateFout as e:
        _account.update(naam="", fout=str(e))
    return dict(_account)


def schema(slug_):
    """De invoer die een model aanneemt (properties uit zijn OpenAPI-schema), van
    Replicate zelf; anders de laatste keer, anders wat hierboven in BEKEND staat."""
    basis = slug_.split(":")[0]
    if basis in _schemas:
        return _schemas[basis]
    cache = os.path.join(P["werk"], "schema_%s.json" % basis.replace("/", "__"))
    props = None
    try:
        d = _verzoek("GET", P["api"] + "/models/" + basis, timeout=30)
        api = (d.get("latest_version") or {}).get("openapi_schema") or {}
        comps = (api.get("components") or {}).get("schemas") or {}
        props = (comps.get("Input") or {}).get("properties") or {}
        for p in props.values():
            if isinstance(p, dict) and "enum" not in p:
                for ref in p.get("allOf", []):
                    naam = str(ref.get("$ref", "")).split("/")[-1]
                    if "enum" in comps.get(naam, {}):
                        p["enum"] = comps[naam]["enum"]
        if props:
            with io.open(cache, "w", encoding="utf-8") as f:
                json.dump(props, f, indent=1)
    except (ReplicateFout, ValueError, AttributeError, TypeError, OSError):
        props = None
    if not props:
        try:
            props = json.load(io.open(cache, encoding="utf-8"))
        except (OSError, ValueError):
            props = BEKEND.get(basis, {})
    _schemas[basis] = props
    return props


def _kies_enum(p, wensen):
    enum = (p or {}).get("enum")
    if not enum:
        return wensen[0]
    for w in wensen:
        if w in enum:
            return w
    return p.get("default", enum[0])


def beeld_invoer(model, prompt, basis_uri="", verhouding="16:9"):
    """`verhouding`: 16:9 voor een concept, 1:1 voor een onderdeel (textuur)."""
    s = schema(model)
    inv = {"prompt": prompt}
    if basis_uri:
        veld = next((v for v in ("image_input", "input_images", "image", "input_image") if v in s),
                    None if s else "image_input")
        if veld is None:
            raise RuntimeError("Dit beeldmodel neemt geen beeld als basis; kies een ander of zet de basis uit.")
        lijst = veld in ("image_input", "input_images") or (s.get(veld) or {}).get("type") == "array"
        inv[veld] = [basis_uri] if lijst else basis_uri
    if "aspect_ratio" in s:
        inv["aspect_ratio"] = _kies_enum(s["aspect_ratio"], ["match_input_image"] if basis_uri else [verhouding, "16:9"])
    if "resolution" in s:
        inv["resolution"] = _kies_enum(s["resolution"], ["1K", "2K"])
    if "size" in s:
        inv["size"] = _kies_enum(s["size"], ["2K"])
    if "output_format" in s:
        inv["output_format"] = _kies_enum(s["output_format"], ["jpg", "jpeg", "png"])
    return inv


def film_invoer(model, prompt, eerste_uri, inst, verhouding="16:9"):
    s = schema(model)
    inv = {"prompt": prompt}
    if eerste_uri:
        veld = next((v for v in ("image", "first_frame_image", "start_image", "input_image") if v in s),
                    None if s else "image")
        if veld is None:
            raise RuntimeError("Dit filmmodel neemt geen eerste beeld.")
        inv[veld] = eerste_uri
    if "duration" in s or not s:
        p = s.get("duration") or {}
        d = int(inst.get("duur", 5))
        if p.get("enum"):
            d = min(p["enum"], key=lambda x: abs(int(x) - d))
        else:
            d = max(max(1, int(p.get("minimum", 1))), min(int(p.get("maximum", 30)), d))
        inv["duration"] = d
    if "resolution" in s:
        inv["resolution"] = _kies_enum(s["resolution"], [str(inst.get("resolutie", "480p")), "480p", "720p"])
    if "aspect_ratio" in s:
        inv["aspect_ratio"] = _kies_enum(s["aspect_ratio"], ["adaptive"] if eerste_uri else [verhouding, "16:9"])
    if "generate_audio" in s:
        inv["generate_audio"] = bool(inst.get("geluid"))
    if "watermark" in s:
        inv["watermark"] = False
    if "camera_fixed" in s:
        inv["camera_fixed"] = True
    if "output_format" in s:
        inv["output_format"] = _kies_enum(s["output_format"], ["mp4"])
    return inv


def data_uri(pad, max_px=1280):
    """Een plaatje als data-URI (Replicate raadt dat aan onder 1 MB): verkleind
    tot hooguit `max_px` en als jpeg, dan blijft het daar ruim onder."""
    if Image is not None:
        im = Image.open(pad).convert("RGB")
        if max(im.size) > max_px:
            im.thumbnail((max_px, max_px), Image.LANCZOS)
        b = io.BytesIO()
        im.save(b, "JPEG", quality=90)
        data, mime = b.getvalue(), "image/jpeg"
    else:
        data = open(pad, "rb").read()
        mime = MIME.get(os.path.splitext(pad)[1].lower(), "image/jpeg")
    return "data:%s;base64,%s" % (mime, base64.b64encode(data).decode("ascii"))


def _zonder_data(invoer):
    uit = {}
    for k, v in invoer.items():
        if isinstance(v, str) and v.startswith("data:"):
            uit[k] = "(beeld)"
        elif isinstance(v, list):
            uit[k] = ["(beeld)" if isinstance(x, str) and x.startswith("data:") else x for x in v]
        else:
            uit[k] = v
    return uit


def _voorspel_url(model):
    if ":" in model:
        return P["api"] + "/predictions", {"version": model.split(":", 1)[1]}
    return P["api"] + "/models/%s/predictions" % model, {}


def _ext(u, soort):
    if u.startswith("data:"):
        m = re.match(r"data:([^;,]+)", u)
        for e, t in MIME.items():
            if m and t == m.group(1):
                return e
    else:
        e = os.path.splitext(urllib.parse.urlparse(u).path)[1].lower()
        if e in FILM_EXT + BEELD_EXT:
            return e
    return ".mp4" if soort == "film" else ".png"


def _download(u, pad):
    tmp = pad + ".deel"
    if u.startswith("data:"):
        data = base64.b64decode(u.split(",", 1)[1])
        with open(tmp, "wb") as f:
            f.write(data)
    else:
        req = urllib.request.Request(u, headers={"User-Agent": UA})
        if urllib.parse.urlparse(u).netloc == urllib.parse.urlparse(P["api"]).netloc:
            req.add_header("Authorization", "Bearer " + lees_sleutel())
        with urllib.request.urlopen(req, timeout=300) as r, open(tmp, "wb") as f:
            shutil.copyfileobj(r, f)
    os.replace(tmp, pad)


# ------------------------------------------------------------------ opdrachten

def _meta_pad(eid, stempel):
    return os.path.join(concept_dir(), eid, stempel + ".json")


def lees_meta(eid, stempel):
    try:
        return json.load(io.open(_meta_pad(eid, stempel), encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def werk_meta(eid, stempel, **velden):
    """Lezen, bijwerken en atomair terugschrijven, onder het slot (de opdracht
    loopt in zijn eigen thread, stop en weg komen van de pagina)."""
    with _lock:
        meta = lees_meta(eid, stempel)
        meta.update(velden)
        pad = _meta_pad(eid, stempel)
        os.makedirs(os.path.dirname(pad), exist_ok=True)
        with io.open(pad + ".tmp", "w", encoding="utf-8", newline="\n") as f:
            json.dump(meta, f, indent=1, ensure_ascii=False)
        os.replace(pad + ".tmp", pad)
        return meta


def nieuwe_stempel():
    return "%s_%04d" % (time.strftime("%Y%m%d_%H%M%S"), next(_teller))


def start_opdracht(eid, soort, model, prompt, volle_prompt, maak_invoer, extra):
    stempel = nieuwe_stempel()
    velden = {"soort": soort, "status": "start", "model": model, "prompt": prompt,
              "volle_prompt": volle_prompt, "tijd": time.strftime("%Y-%m-%d %H:%M"), "start": time.time()}
    velden.update(extra)
    werk_meta(eid, stempel, **velden)
    threading.Thread(target=_draai, args=(eid, stempel, maak_invoer), daemon=True).start()
    return stempel


def _draai(eid, stempel, maak_invoer=None):
    meta = lees_meta(eid, stempel)
    begin = float(meta.get("start") or time.time())
    try:
        if not meta.get("pred_get"):
            if maak_invoer is None:
                raise ReplicateFout("onderbroken voordat Replicate de opdracht kreeg (niets betaald)")
            invoer = maak_invoer()
            url, extra = _voorspel_url(meta["model"])
            body = dict(extra)
            body["input"] = invoer
            p = _verzoek("POST", url, body, timeout=120)
            urls = p.get("urls") or {}
            meta = werk_meta(eid, stempel, status="bezig", prediction=p.get("id", ""),
                             pred_get=urls.get("get") or "%s/predictions/%s" % (P["api"], p.get("id", "")),
                             pred_cancel=urls.get("cancel", ""), invoer=_zonder_data(invoer))
            if meta.get("stop") and meta.get("pred_cancel"):
                _verzoek("POST", meta["pred_cancel"], {}, timeout=30)
        film = meta.get("soort") == "film"
        poll = P["poll_film"] if film else P["poll_beeld"]
        grens = time.time() + (3600 if film else 900)
        missers = 0
        while True:
            try:
                p = _verzoek("GET", meta["pred_get"], timeout=60)
                missers = 0
            except ReplicateFout:
                missers += 1
                if missers >= 6:
                    raise
                time.sleep(poll * 2)
                continue
            s = p.get("status")
            if s == "succeeded":
                break
            if s == "canceled":
                raise ReplicateFout("gestopt")
            if s == "failed":
                raise ReplicateFout("Replicate: %s" % (p.get("error") or "mislukt"))
            if time.time() > grens:
                raise ReplicateFout("duurde te lang; kijk op replicate.com onder Predictions")
            time.sleep(poll)
        uit = p.get("output")
        lijst = uit if isinstance(uit, list) else [uit]
        bestanden = []
        vellen = []
        for i, u in enumerate([u for u in lijst if isinstance(u, str) and u]):
            pad = os.path.join(concept_dir(), eid, "%s_%d%s" % (stempel, i + 1, _ext(u, meta.get("soort"))))
            _download(u, pad)
            bestanden.append(_rel(os.path.abspath(pad)))
            if os.path.splitext(pad)[1].lower() in FILM_EXT:
                vel = maak_vel(pad)    # zodat Claude kan zien wat er in het filmpje gebeurt
                if vel:
                    vellen.append(_rel(os.path.abspath(vel)))
        if not bestanden:
            raise ReplicateFout("Replicate gaf geen bestand terug")
        werk_meta(eid, stempel, status="klaar", bestanden=bestanden, vellen=vellen,
                  seconden=int(time.time() - begin), metrics=p.get("metrics") or {})
    except Exception as e:  # noqa: BLE001
        werk_meta(eid, stempel, status="mislukt", fout=str(e), seconden=int(time.time() - begin))


def stop_opdracht(eid, stempel):
    meta = lees_meta(eid, stempel)
    if meta.get("status") not in ("start", "bezig"):
        return
    if meta.get("pred_cancel"):
        _verzoek("POST", meta["pred_cancel"], {}, timeout=30)
    else:
        werk_meta(eid, stempel, stop=True)


def _alle_metas():
    for pad in sorted(glob.glob(os.path.join(concept_dir(), "*", "*.json"))):
        yield os.path.basename(os.path.dirname(pad)), os.path.splitext(os.path.basename(pad))[0]


def hervat_opdrachten():
    """Wat nog liep toen de studio dichtging: verder pollen (Replicate maakt het
    toch af, en het is al betaald)."""
    n = 0
    for eid, stempel in _alle_metas():
        meta = lees_meta(eid, stempel)
        if meta.get("status") == "bezig" and meta.get("pred_get"):
            threading.Thread(target=_draai, args=(eid, stempel), daemon=True).start()
            n += 1
        elif meta.get("status") == "start":
            werk_meta(eid, stempel, status="mislukt",
                      fout="onderbroken voordat Replicate de opdracht kreeg (niets betaald)")
    return n


def lopend():
    uit = []
    for eid, stempel in _alle_metas():
        meta = lees_meta(eid, stempel)
        if meta.get("status") in ("start", "bezig"):
            uit.append({"id": eid, "stempel": stempel, "soort": meta.get("soort"), "start": meta.get("start"),
                        "model": meta.get("model", "")})
    return uit


def concepten_van(eid):
    uit = []
    for pad in sorted(glob.glob(os.path.join(concept_dir(), eid, "*.json")), reverse=True):
        stempel = os.path.splitext(os.path.basename(pad))[0]
        meta = lees_meta(eid, stempel)
        if not meta:
            continue
        meta["stempel"] = stempel
        meta["bestanden"] = [b for b in meta.get("bestanden", []) if os.path.exists(os.path.join(WORTEL, b))
                             or os.path.exists(b)]
        meta.pop("invoer", None)
        uit.append(meta)
    return uit


def keuze_van(eid, st):
    k = dict(st.get("keuze", {}).get(eid) or {})
    v = 0
    for soort in ("beeld", "film"):
        p = k.get(soort)
        if p and os.path.exists(p if os.path.isabs(p) else os.path.join(WORTEL, p)):
            v = max(v, int(os.path.getmtime(p if os.path.isabs(p) else os.path.join(WORTEL, p))))
        else:
            k.pop(soort, None)
    vel = os.path.join(P["ref"], eid, "film_vel.jpg")
    if k.get("film") and os.path.exists(vel):
        k["film_vel"] = _rel(os.path.abspath(vel))
    k["v"] = v
    return k


def kies(eid, pad):
    """Dit is hem: het plaatje of filmpje naar assets/vfx/referentie/<id>/."""
    eid = _id_ok(eid)
    bron = _veilig(pad, [os.path.join(concept_dir(), eid)])
    ext = os.path.splitext(bron)[1].lower()
    soort = "film" if ext in FILM_EXT else "beeld"
    doelmap = os.path.join(P["ref"], eid)
    os.makedirs(doelmap, exist_ok=True)
    with _lock:
        for oud in glob.glob(os.path.join(doelmap, soort + ".*")):
            os.remove(oud)
        doel = os.path.join(doelmap, soort + ext)
        shutil.copyfile(bron, doel)
        if soort == "film":
            # het contactvel gaat mee: daarop ziet Claude wat er in het filmpje gebeurt
            vel = os.path.splitext(bron)[0] + "_vel.jpg"
            if not os.path.exists(vel):
                vel = maak_vel(bron)
            if vel and os.path.exists(vel):
                shutil.copyfile(vel, os.path.join(doelmap, "film_vel.jpg"))
        meta = lees_meta(eid, os.path.basename(bron).rsplit("_", 1)[0])
        st = lees_studio()
        k = st["keuze"].setdefault(eid, {})
        k[soort] = _rel(os.path.abspath(doel))
        k[soort + "_prompt"] = meta.get("volle_prompt") or meta.get("prompt", "")
        k[soort + "_model"] = meta.get("model", "")
        k[soort + "_bron"] = _rel(bron)
        k["tijd"] = time.strftime("%Y-%m-%d %H:%M")
        schrijf_studio(st)
    return k[soort]


def kies_af(eid, soort):
    eid = _id_ok(eid)
    if soort not in ("beeld", "film"):
        raise RuntimeError("beeld of film")
    with _lock:
        for oud in glob.glob(os.path.join(P["ref"], eid, soort + ".*")) + \
                glob.glob(os.path.join(P["ref"], eid, soort + "_vel.jpg")):
            os.remove(oud)
        st = lees_studio()
        k = st["keuze"].get(eid, {})
        for sl in (soort, soort + "_prompt", soort + "_model", soort + "_bron"):
            k.pop(sl, None)
        if not any(k.get(s) for s in ("beeld", "film")):
            st["keuze"].pop(eid, None)
        schrijf_studio(st)


def weg(eid, pad="", stempel=""):
    """Een concept weggooien (of een mislukte opdracht); de meta gaat mee als er
    niets meer van over is."""
    eid = _id_ok(eid)
    with _lock:
        if pad:
            a = _veilig(pad, [os.path.join(concept_dir(), eid)])
            os.remove(a)
            stempel = os.path.basename(a).rsplit("_", 1)[0]
        if not re.fullmatch(r"[0-9_]+", stempel or ""):
            raise RuntimeError("rare stempel")
        meta = lees_meta(eid, stempel)
        if meta.get("status") in ("start", "bezig"):
            raise RuntimeError("Die loopt nog; stop hem eerst.")
        over = [b for b in meta.get("bestanden", []) if os.path.exists(b) or os.path.exists(os.path.join(WORTEL, b))]
        if not over:
            try:
                os.remove(_meta_pad(eid, stempel))
            except OSError:
                pass


# ------------------------------------------------------------------ onderdelen (texturen en decals)

ONDERDEEL_VOOR = "o_"      # kandidaten en opdrachten van een onderdeel: conceptmap o_<onderdeel>
_GRID_RE = re.compile(r"_(\d+)x(\d+)$")
MAX_TEXTUUR = 1024         # assets/textures/*/README: hooguit ~1024 px per bestand
UPLOAD_EXT = BEELD_EXT + FILM_EXT + (".gif",)
MAX_UPLOAD = 300 * 1024 * 1024
_import_status = {"bezig": False, "laatste": "", "uitvoer": ""}


def onderdelen():
    """De onderdelen uit de catalogus (ONDERDELEN), anders uit de laatste export."""
    try:
        d = _const(CATALOGUS_GD, "ONDERDELEN")
        if isinstance(d, dict):
            return d
    except (OSError, RuntimeError):
        pass
    try:
        return json.load(io.open(os.path.join(spel_dir(), "catalogus.json"), encoding="utf-8")).get("onderdelen", {})
    except (OSError, ValueError, AttributeError):
        return {}


def _onderdeel(oid):
    o = onderdelen().get(str(oid or ""))
    if not o:
        raise RuntimeError("onbekend onderdeel: %r" % oid)
    return o


def _rooster(base):
    m = _GRID_RE.search(base)
    return [int(m.group(1)), int(m.group(2))] if m else [1, 1]


def _heeft_alpha(im):
    if im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info):
        return im.convert("RGBA").getchannel("A").getextrema()[0] < 250
    return False


def _hoort_bij(o, base):
    b = str(o["bestand"]).lower()
    if o["soort"] == "flipbook":
        return b in base               # zoals PawnView._vfx_entry: de naam bevat de wens
    if o["soort"] == "varianten":
        return base.startswith(b)      # zoals PawnView._blood_texture: de naam begint ermee
    return base == b


def spel_bestanden(oid):
    """Wat er nu in het spel staat voor dit onderdeel, in de volgorde waarin het
    spel de map leest (bij een flipbook pakt het spel de eerste)."""
    o = _onderdeel(oid)
    d = os.path.join(P["texturen"], o["map"])
    uit = []
    if not os.path.isdir(d):
        return uit
    for f in sorted(os.listdir(d), key=str.lower):
        base, ext = os.path.splitext(f)
        if ext.lower() not in BEELD_EXT or not _hoort_bij(o, base.lower()):
            continue
        p = os.path.join(d, f)
        info = {"pad": _rel(os.path.abspath(p)), "naam": f, "rooster": _rooster(base.lower()),
                "v": int(os.path.getmtime(p)), "actief": o["soort"] != "flipbook" or not uit}
        if Image is not None:
            try:
                with Image.open(p) as im:
                    info["maat"] = list(im.size)
                    info["alpha"] = _heeft_alpha(im)
            except OSError:
                pass
        uit.append(info)
    return uit


def lees_beelden(pad, n, start=0.0, eind=0.0):
    """`n` beelden op gelijke afstanden tussen `start` en `eind` (seconden; 0 =
    tot het eind) uit een filmpje (OpenCV) of gif, als [(tijd, PIL-beeld)], en de
    duur."""
    if Image is None:
        raise RuntimeError("PIL ontbreekt")
    n = max(1, int(n))
    if os.path.splitext(pad)[1].lower() == ".gif":
        beelden, tijden, t = [], [], 0.0
        with Image.open(pad) as im:
            for fr in ImageSequence.Iterator(im):
                beelden.append(fr.convert("RGB"))
                tijden.append(t)
                t += max(0.02, float(fr.info.get("duration", 100) or 100) / 1000.0)
        duur = t
        eind = duur if not eind or eind <= 0 else min(float(eind), duur)
        start = max(0.0, min(float(start or 0.0), eind))
        uit = []
        for i in range(n):
            tt = start + (eind - start) * (i + 0.5) / n
            k = max([j for j in range(len(tijden)) if tijden[j] <= tt] or [0])
            uit.append((tt, beelden[k]))
        return uit, duur
    try:
        import cv2
    except ImportError:
        raise RuntimeError("OpenCV ontbreekt (pip install opencv-python): zonder kan de studio geen filmpje lezen")
    cap = cv2.VideoCapture(pad)
    if not cap.isOpened():
        raise RuntimeError("filmpje niet te openen: %s" % os.path.basename(pad))
    fps = cap.get(cv2.CAP_PROP_FPS) or 24.0
    tel = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    duur = tel / fps if tel > 0 else 0.0
    eind = duur if not eind or eind <= 0 or duur == 0 else min(float(eind), duur)
    start = max(0.0, min(float(start or 0.0), eind))
    willen = {}
    for i in range(n):
        tt = start + (eind - start) * (i + 0.5) / n
        willen.setdefault(min(max(tel - 1, 0), int(tt * fps)), []).append((i, tt))
    uit = [None] * n
    nr = 0
    laatste = max(willen)
    while nr <= laatste:
        ok, f = cap.read()
        if not ok:
            break
        if nr in willen:
            im = Image.fromarray(cv2.cvtColor(f, cv2.COLOR_BGR2RGB))
            for i, tt in willen[nr]:
                uit[i] = (tt, im)
        nr += 1
    cap.release()
    vorige = None
    for i in range(n):              # wat voorbij het laatste beeld viel: dat beeld herhalen
        if uit[i] is None:
            uit[i] = vorige
        vorige = uit[i]
    uit = [u for u in uit if u is not None]
    if not uit:
        raise RuntimeError("geen beelden te lezen uit %s" % os.path.basename(pad))
    return uit, duur


def maak_vel(pad, n=12, kolommen=4):
    """Een contactvel van een filmpje: `n` beelden met de tijd erbij, als
    <naam>_vel.jpg naast het filmpje. Zo kan Claude zien wat er gebeurt (een
    plaatje lezen kan hij, een filmpje niet). Geeft het pad, of "" (een vel is
    een hulpje, nooit een fout)."""
    try:
        beelden, _duur = lees_beelden(pad, n)
        w0, h0 = beelden[0][1].size
        cel_w = 320
        cel_h = max(1, round(cel_w * h0 / max(w0, 1)))
        rijen = (len(beelden) + kolommen - 1) // kolommen
        vel = Image.new("RGB", (kolommen * cel_w, rijen * (cel_h + 22)), (20, 18, 16))
        teken = ImageDraw.Draw(vel)
        for i, (t, im) in enumerate(beelden):
            x, y = (i % kolommen) * cel_w, (i // kolommen) * (cel_h + 22)
            vel.paste(im.resize((cel_w, cel_h), Image.LANCZOS), (x, y))
            teken.text((x + 6, y + cel_h + 5), "%d   t = %.2f s" % (i + 1, t), fill=(230, 220, 200))
        uit = os.path.splitext(pad)[0] + "_vel.jpg"
        vel.save(uit, "JPEG", quality=85)
        return uit
    except Exception:  # noqa: BLE001
        return ""


def upload(eid, naam, data):
    """Een eigen bestand erin (een plaatje, gif of filmpje), als kandidaat bij een
    effect of een onderdeel (o_<onderdeel>). Een vel met `_4x4` in de naam krijgt
    dat rooster mee."""
    eid = _id_ok(eid)
    if eid.startswith(ONDERDEEL_VOOR):
        _onderdeel(eid[len(ONDERDEEL_VOOR):])
    ext = os.path.splitext(str(naam or ""))[1].lower()
    if ext not in UPLOAD_EXT:
        raise RuntimeError("Alleen png, jpg, webp, gif, mp4, mov of webm.")
    if not data:
        raise RuntimeError("leeg bestand")
    stempel = nieuwe_stempel()
    pad = os.path.join(concept_dir(), eid, "%s_1%s" % (stempel, ext))
    os.makedirs(os.path.dirname(pad), exist_ok=True)
    with open(pad, "wb") as f:
        f.write(data)
    film = ext in FILM_EXT
    if ext == ".gif" and Image is not None:
        with Image.open(pad) as im:
            film = getattr(im, "n_frames", 1) > 1
    velden = {"soort": "film" if film else "beeld", "status": "klaar", "model": "upload", "bron": "upload",
              "naam": os.path.basename(str(naam)), "prompt": "", "tijd": time.strftime("%Y-%m-%d %H:%M"),
              "start": time.time(), "bestanden": [_rel(os.path.abspath(pad))], "seconden": 0,
              "rooster": _rooster(os.path.splitext(os.path.basename(str(naam)))[0].lower())}
    if film:
        vel = maak_vel(pad)
        if vel:
            velden["vellen"] = [_rel(os.path.abspath(vel))]
    werk_meta(eid, stempel, **velden)
    return stempel


def maak_flipbook(oid, film, start=0.0, eind=0.0, kolommen=4, rijen=4, cel=256, zoom=1.0):
    """Een flipbook uit een filmpje of gif: kolommen x rijen beelden op gelijke
    afstanden tussen `start` en `eind`, elk een vierkant uit het midden (`zoom` >
    1 snijdt dichter op het midden), cel x cel per beeld en het vel hooguit 1024
    breed. Het filmpje mag van het onderdeel zijn of van een effect."""
    _onderdeel(oid)
    eid = ONDERDEEL_VOOR + oid
    bron = _veilig(film, [concept_dir(), P["ref"]])
    if os.path.splitext(bron)[1].lower() not in FILM_EXT + (".gif",):
        raise RuntimeError("Een flipbook komt uit een filmpje of gif.")
    kolommen = max(1, min(16, int(kolommen)))
    rijen = max(1, min(16, int(rijen)))
    cel = max(16, min(int(cel), MAX_TEXTUUR // max(kolommen, rijen)))
    z = max(1.0, min(6.0, float(zoom or 1.0)))
    beelden, duur = lees_beelden(bron, kolommen * rijen, float(start or 0.0), float(eind or 0.0))
    vel = Image.new("RGB", (kolommen * cel, rijen * cel), (0, 0, 0))
    for i, (_t, im) in enumerate(beelden[:kolommen * rijen]):
        w, h = im.size
        zijde = min(w, h) / z
        links, boven = (w - zijde) / 2.0, (h - zijde) / 2.0
        stuk = im.crop((int(links), int(boven), int(links + zijde), int(boven + zijde))).resize((cel, cel), Image.LANCZOS)
        vel.paste(stuk, ((i % kolommen) * cel, (i // kolommen) * cel))
    stempel = nieuwe_stempel()
    pad = os.path.join(concept_dir(), eid, "%s_1.png" % stempel)
    os.makedirs(os.path.dirname(pad), exist_ok=True)
    vel.save(pad, "PNG")
    werk_meta(eid, stempel, soort="beeld", status="klaar", model="flipbook", bron="flipbook", van=_rel(bron),
              van_s=round(float(start or 0.0), 2), tot_s=round(float(eind or 0.0) or duur, 2),
              rooster=[kolommen, rijen], cel=cel, zoom=z, prompt="", tijd=time.strftime("%Y-%m-%d %H:%M"),
              start=time.time(), bestanden=[_rel(os.path.abspath(pad))], seconden=0)
    return stempel


def vrijstaand(oid, pad, methode, sterkte=1.0):
    """Achtergrond weg, als PNG met doorzichtigheid. "zwart": dekking uit de
    helderheid (zoals het spel laadt, maar met schone randen); "wit": dekking uit
    hoe donker het is; "groen": alles wat groen is valt weg. `sterkte` > 1
    maakt het dekkender."""
    if np is None or Image is None:
        raise RuntimeError("numpy en PIL zijn nodig")
    _onderdeel(oid)
    eid = ONDERDEEL_VOOR + oid
    bron = _veilig(pad, [os.path.join(concept_dir(), eid)])
    a = np.asarray(Image.open(bron).convert("RGB")).astype(np.float32) / 255.0
    k = max(0.2, min(5.0, float(sterkte or 1.0)))
    if methode == "zwart":
        alpha = np.clip(a.max(axis=2) * k, 0.0, 1.0)
        kleur = np.clip(a / np.maximum(alpha[..., None], 1e-3), 0.0, 1.0)
    elif methode == "wit":
        alpha = np.clip((1.0 - a.min(axis=2)) * k, 0.0, 1.0)
        kleur = np.clip((a - (1.0 - alpha[..., None])) / np.maximum(alpha[..., None], 1e-3), 0.0, 1.0)
    elif methode == "groen":
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        alpha = 1.0 - np.clip((g - np.maximum(r, b)) * 3.0 * k, 0.0, 1.0)
        kleur = a.copy()
        kleur[..., 1] = np.minimum(g, np.maximum(r, b))     # geen groene rand
    else:
        raise RuntimeError("zwart, wit of groen")
    beeld = Image.fromarray((np.dstack([kleur, alpha]) * 255.0 + 0.5).astype(np.uint8), "RGBA")
    meta_bron = lees_meta(eid, os.path.basename(bron).rsplit("_", 1)[0])
    stempel = nieuwe_stempel()
    uit = os.path.join(concept_dir(), eid, "%s_1.png" % stempel)
    beeld.save(uit, "PNG")
    werk_meta(eid, stempel, soort="beeld", status="klaar", model="vrijstaand", bron="vrijstaand", methode=methode,
              sterkte=k, van=_rel(bron), rooster=meta_bron.get("rooster") or [1, 1],
              prompt=meta_bron.get("prompt", ""), tijd=time.strftime("%Y-%m-%d %H:%M"), start=time.time(),
              bestanden=[_rel(os.path.abspath(uit))], seconden=0)
    return stempel


def zet_rooster(oid, stempel, kolommen, rijen):
    eid = ONDERDEEL_VOOR + _id_ok(oid)
    if not re.fullmatch(r"[0-9_]+", str(stempel or "")):
        raise RuntimeError("rare stempel")
    werk_meta(eid, stempel, rooster=[max(1, min(16, int(kolommen))), max(1, min(16, int(rijen)))])


def editor_open():
    """Staat de Godot-editor (of de projectmanager) open? Die importeert nieuwe
    bestanden zelf, en een tweede --import ernaast gaat mis."""
    if os.name != "nt":
        return False
    try:
        uit = subprocess.run(["powershell", "-NoProfile", "-Command",
                              "Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | "
                              "ForEach-Object { $_.CommandLine }"],
                             capture_output=True, text=True, timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return False
    for regel in uit.splitlines():
        r = regel.strip().lower()
        if r and "--headless" not in r and "res://" not in r:
            return True
    return False


def in_spel(oid, pad, modus="vervang", doel=""):
    """Zet een kandidaat in het spel: als PNG (hooguit 1024 per kant; een vel
    blijft deelbaar door zijn rooster) onder de naam die het spel zoekt, in
    assets/textures/<map>/. Wat er stond gaat eerst naar
    results/vfx_studio/backup/<map>/ (en git heeft het ook nog)."""
    if Image is None:
        raise RuntimeError("PIL ontbreekt")
    o = _onderdeel(oid)
    eid = ONDERDEEL_VOOR + oid
    bron = _veilig(pad, [os.path.join(concept_dir(), eid)])
    if os.path.splitext(bron)[1].lower() not in BEELD_EXT:
        raise RuntimeError("Alleen een plaatje kan in het spel; maak van een filmpje eerst een flipbook.")
    stempel_bron = os.path.basename(bron).rsplit("_", 1)[0]
    meta = lees_meta(eid, stempel_bron)
    k, r = [int(x) for x in (meta.get("rooster") or [1, 1])[:2]]
    im = Image.open(bron)
    alpha = _heeft_alpha(im)
    if o["achtergrond"] == "alpha" and not alpha:
        raise RuntimeError("Dit onderdeel moet doorzichtig zijn: haal eerst de achtergrond weg (wit, zwart of groen).")
    im = im.convert("RGBA" if alpha else "RGB")
    if max(im.size) > MAX_TEXTUUR:
        schaal = MAX_TEXTUUR / float(max(im.size))
        cw, ch = max(1, int(im.width * schaal / k)), max(1, int(im.height * schaal / r))
        im = im.resize((cw * k, ch * r), Image.LANCZOS)
    huidig = spel_bestanden(oid)
    if o["soort"] == "varianten" and modus == "variant":
        namen = {h["naam"].lower() for h in huidig}
        n = 1
        while any(x.startswith("%s%d." % (o["bestand"].lower(), n)) for x in namen):
            n += 1
        naam, weg_lijst = "%s%d.png" % (o["bestand"], n), []
    elif o["soort"] == "varianten":
        h = next((h for h in huidig if doel in (h["pad"], h["naam"])), None)
        if h is None:
            raise RuntimeError("Welke variant vervang je? Kies er een, of zet hem erbij.")
        naam, weg_lijst = os.path.splitext(h["naam"])[0] + ".png", [h]
    elif o["soort"] == "flipbook":
        naam = ("%s_%dx%d.png" % (o["bestand"], k, r)) if (k, r) != (1, 1) else "%s.png" % o["bestand"]
        weg_lijst = huidig            # het spel pakt de eerste die past: er mag er maar een zijn
    else:
        naam, weg_lijst = "%s.png" % o["bestand"], huidig
    mapd = os.path.join(P["texturen"], o["map"])
    os.makedirs(mapd, exist_ok=True)
    backup = os.path.join(P["werk"], "backup", o["map"])
    stempel = nieuwe_stempel()
    with _lock:
        for h in weg_lijst:
            a = os.path.abspath(h["pad"])
            os.makedirs(backup, exist_ok=True)
            shutil.copyfile(a, os.path.join(backup, "%s_%s" % (stempel, h["naam"])))
            if os.path.basename(a).lower() != naam.lower():
                os.remove(a)
                if os.path.exists(a + ".import"):
                    os.remove(a + ".import")
        doelpad = os.path.join(mapd, naam)
        im.save(doelpad, "PNG")
    werk_meta(eid, stempel_bron, in_spel=_rel(os.path.abspath(doelpad)), in_spel_tijd=time.strftime("%Y-%m-%d %H:%M"))
    return {"doel": _rel(os.path.abspath(doelpad)),
            "weg": [h["naam"] for h in weg_lijst if h["naam"].lower() != naam.lower()],
            "editor": editor_open()}


def godot_import():
    """`--import` op de achtergrond (alleen als de editor dicht is; anders doet
    die het zelf zodra je naar zijn venster gaat)."""
    if _import_status["bezig"]:
        return
    if editor_open():
        _import_status["laatste"] = "de editor staat open: die importeert de nieuwe texturen zelf zodra je naar zijn venster gaat"
        return
    godot = os.environ.get("GODOT_PATH") or GODOT_STANDAARD
    if not os.path.exists(godot):
        _import_status["laatste"] = "Godot niet gevonden: zet GODOT_PATH."
        return

    def run():
        _import_status.update(bezig=True, laatste="bezig...")
        try:
            p = subprocess.run([godot, "--headless", "--path", ".", "--import"], capture_output=True,
                               text=True, timeout=900, errors="replace")
            uit = (p.stdout or "") + (p.stderr or "")
            _import_status["uitvoer"] = "\n".join([r for r in uit.splitlines() if "ERROR" in r][:8])
            _import_status["laatste"] = ("klaar (%s)" % time.strftime("%H:%M:%S")) if p.returncode == 0 \
                else "mislukt (exit %d)" % p.returncode
        except Exception as e:  # noqa: BLE001
            _import_status["laatste"] = "mislukt: %s" % e
        _import_status["bezig"] = False

    threading.Thread(target=run, daemon=True).start()


def onderdeel_rij(oid, cat=None, st=None):
    o = _onderdeel(oid)
    cat = cat or catalogus()
    st = st or lees_studio()
    eid = ONDERDEEL_VOOR + oid
    effecten = [e for e in cat["effecten"] if oid in (e.get("onderdelen") or [])]
    # filmpjes om een flipbook uit te knippen: die van dit onderdeel en die van zijn effecten
    films = []
    for bron_id, label in [(eid, "eigen")] + [(e["id"], e.get("naam", e["id"])) for e in effecten]:
        for m in concepten_van(bron_id):
            for p in m.get("bestanden", []):
                if os.path.splitext(p)[1].lower() in FILM_EXT + (".gif",):
                    films.append({"pad": p, "label": "%s, %s" % (label, m.get("tijd", ""))})
        k = st["keuze"].get(bron_id, {})
        if k.get("film"):
            films.append({"pad": k["film"], "label": "%s, dit is hem" % label})
    return {"id": oid, "eid": eid, "naam": o.get("naam", oid), "map": o["map"], "bestand": o["bestand"],
            "soort": o["soort"], "achtergrond": o["achtergrond"], "boost": float(o.get("boost", 2.3)),
            "gebruikt": bool(o.get("gebruikt", True)), "uitleg": o.get("uitleg", ""),
            "prompt_bron": o.get("prompt", ""), "film_bron": o.get("film", ""),
            "prompt": st["prompts"].get(eid, ""), "notitie": st["notities"].get(eid, ""),
            "effecten": [{"id": e["id"], "naam": e.get("naam", e["id"])} for e in effecten],
            "spel": spel_bestanden(oid), "kandidaten": concepten_van(eid), "films": films}


def onderdeel_rijen():
    cat = catalogus()
    st = lees_studio()
    return [onderdeel_rij(oid, cat, st) for oid in onderdelen()]


# ------------------------------------------------------------------ overzicht

def _rij(e, w, g, st, od=None):
    if e is not None:
        eid, naam = e["id"], e.get("naam", e["id"])
        wanneer, status = e.get("wanneer", ""), e.get("status", "")
    else:
        eid, naam = slug(w["naam"]), w["naam"]
        wanneer, status = w.get("wanneer", ""), (w.get("status") or "wens")
    return {
        "id": eid, "groep": g["id"], "groepnaam": g["naam"], "naam": naam, "wanneer": wanneer,
        "status": status, "alleen_wishlist": e is None, "in_wishlist": w is not None,
        "speelbaar": bool(e and e.get("speel")), "notitie_cat": (e or {}).get("notitie", ""),
        "wl_notitie": (w or {}).get("notitie", ""), "prompt_bron": (w or {}).get("prompt", ""),
        "prompt": st["prompts"].get(eid, ""), "notitie": st["notities"].get(eid, ""),
        "goed": bool(st["goed"].get(eid)), "knoppen": (e or {}).get("knoppen", []),
        "spel": spel_van(eid), "keuze": keuze_van(eid, st), "concepten": concepten_van(eid),
        "onderdelen": [{"id": x, "naam": (od or {}).get(x, {}).get("naam", x)} for x in (e or {}).get("onderdelen", [])],
    }


def overzicht(alleen=None):
    cat = catalogus()
    od = onderdelen()
    wl = wishlist()
    st = lees_studio()
    per_titel = {}
    for t, rs in wl:
        per_titel.setdefault(_gelijk(t), []).extend(rs)
    rijen = []
    gehad = set()
    for g in cat["groepen"]:
        gehad.add(_gelijk(g["naam"]))
        wrs = per_titel.get(_gelijk(g["naam"]), [])
        per_naam = {_gelijk(w["naam"]): w for w in wrs}
        gebruikt = set()
        for e in cat["effecten"]:
            if e.get("groep") != g["id"]:
                continue
            w = per_naam.get(_gelijk(e.get("naam", "")))
            if w is not None:
                gebruikt.add(_gelijk(w["naam"]))
            if alleen is None or e["id"] == alleen:
                rijen.append(_rij(e, w, g, st, od))
        for w in wrs:
            if _gelijk(w["naam"]) not in gebruikt and (alleen is None or slug(w["naam"]) == alleen):
                rijen.append(_rij(None, w, g, st, od))
    for t, rs in wl:
        if _gelijk(t) in gehad:
            continue
        gehad.add(_gelijk(t))
        g = {"id": slug(t, "groep_"), "naam": t}
        for w in per_titel.get(_gelijk(t), []):
            if alleen is None or slug(w["naam"]) == alleen:
                rijen.append(_rij(None, w, g, st, od))
    return {"rijen": rijen, "bron": cat["bron"], "instellingen": st["instellingen"]}


def samenvatting(o):
    rijen = o["rijen"]
    return {
        "effecten": len(rijen), "groepen": len({r["groep"] for r in rijen}),
        "speelbaar": sum(1 for r in rijen if r["speelbaar"]),
        "met_prompt": sum(1 for r in rijen if r["prompt"] or r["prompt_bron"]),
        "zonder_prompt": [r["id"] for r in rijen if not (r["prompt"] or r["prompt_bron"])],
        "niet_in_wishlist": [r["id"] for r in rijen if not r["in_wishlist"]],
        "alleen_in_wishlist": [r["id"] for r in rijen if r["alleen_wishlist"]],
        "met_spelbeelden": sum(1 for r in rijen if r["spel"]),
        "keuzes": sum(1 for r in rijen if r["keuze"].get("beeld") or r["keuze"].get("film")),
        "goed": sum(1 for r in rijen if r["goed"]),
        "concepten": sum(len(r["concepten"]) for r in rijen),
        "lopend": len(lopend()), "catalogus": o["bron"], "fout": _cat_fout, "sleutel": bool(lees_sleutel()),
        "onderdelen": len(onderdelen()),
        "onderdelen_met_bestand": [oid for oid in onderdelen() if spel_bestanden(oid)],
        "onderdelen_leeg": [oid for oid in onderdelen() if not spel_bestanden(oid)],
    }


def _volle_overzicht():
    o = overzicht()
    o.update({"fout": _cat_fout, "modellen": {"beeld": BEELDMODELLEN, "film": FILMMODELLEN},
              "sleutel": bool(lees_sleutel()), "account": dict(_account), "taken": lopend(),
              "spel": dict(_spel), "onderdelen": onderdeel_rijen(), "import": dict(_import_status)})
    return o


# ------------------------------------------------------------------ http

PAGINA = r"""<!DOCTYPE html>
<html lang="nl"><head><meta charset="utf-8"><title>VFX-studio</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
:root{--bg:#1d1a16;--kaart:#2a2620;--rand:#4a4237;--tekst:#eee6d8;--dof:#a89c88;--accent:#e0a53d;--ok:#6dbb6d;--nee:#d9645a;--wens:#c9a25a;--blauw:#6aa6d9}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--tekst);font:14px/1.4 "Segoe UI",sans-serif}
header{position:sticky;top:0;background:#141210;border-bottom:1px solid var(--rand);padding:8px 16px;z-index:5}
.balk{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.balk+.balk{margin-top:6px}
h1{font-size:17px;margin:0 8px 0 0;color:var(--accent)}
input,textarea,select,button{font:inherit;background:#171410;color:var(--tekst);border:1px solid var(--rand);border-radius:4px;padding:5px 8px}
button{cursor:pointer;background:#3a3225;transition:background .15s}button:hover{background:#4a4030}
button.prim{background:var(--accent);color:#1d1a16;font-weight:600}button.prim:hover{background:#f0b64a}
button.klein{padding:2px 7px;font-size:12px}
button:disabled{opacity:.5;cursor:default}
.klein{color:var(--dof);font-size:12px}
.nav{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}
.chip{border:1px solid var(--rand);border-radius:14px;padding:2px 10px;font-size:12px;cursor:pointer;background:#1f1b16}
.chip:hover{border-color:var(--accent)}
main{padding:10px 16px 80px;max-width:1500px}
h2{font-size:15px;margin:22px 0 6px;color:var(--accent);border-bottom:1px solid var(--rand);padding-bottom:3px;cursor:pointer;user-select:none;display:flex;gap:10px;align-items:baseline}
h2 .sub{font-weight:400;font-size:12px;color:var(--dof)}
.sectie.dicht .rij,.sectie.dicht .wensform{display:none}
.rij{background:var(--kaart);border:1px solid var(--rand);border-radius:6px;padding:10px;margin:8px 0;display:grid;grid-template-columns:240px 300px 1fr;gap:10px 16px}
.rij.verberg{display:none}
.rij.nieuw{animation:flits 1.2s ease-out}
@keyframes flits{from{box-shadow:0 0 0 3px var(--accent)}to{box-shadow:0 0 0 0 transparent}}
@media (max-width:1000px){.rij{grid-template-columns:1fr}}
.naam{font-weight:600;font-size:15px;color:#fff}
.id{font-family:Consolas,monospace;font-size:12px;color:var(--dof)}
.badge{display:inline-block;padding:0 7px;border-radius:9px;font-size:11px;margin-left:5px;vertical-align:middle;font-weight:400}
.b-spel{background:var(--ok);color:#111}.b-wens{background:var(--wens);color:#111}.b-diorama{background:var(--blauw);color:#111}.b-goed{background:#9ad19a;color:#111}.b-keuze{background:var(--accent);color:#111}
.wanneer{margin:4px 0}
details{margin:4px 0;font-size:12px}summary{cursor:pointer;color:var(--dof)}
.knoppenlijst div{display:flex;justify-content:space-between;gap:8px;color:var(--dof)}
textarea{width:100%;resize:vertical}
textarea.notitie{min-height:48px;margin-top:6px}
textarea.prompt{min-height:66px}
.kop{font-size:11px;color:var(--dof);margin-bottom:4px;text-transform:uppercase;letter-spacing:.05em}
.spelbeeld{width:100%;border-radius:4px;border:1px solid var(--rand);cursor:zoom-in;display:block;background:#000}
.leeg{border:1px dashed var(--rand);border-radius:4px;padding:22px 10px;text-align:center;color:var(--dof);font-size:12px}
.strip{display:flex;gap:4px;margin-top:5px}
.strip img{width:20%;min-width:0;border:2px solid transparent;border-radius:3px;cursor:pointer;opacity:.7}
.strip img.basis{border-color:var(--accent);opacity:1}
.inst{display:flex;gap:8px;align-items:center;margin-top:6px;flex-wrap:wrap}
.galerij{display:flex;flex-wrap:wrap;gap:8px;margin-top:8px}
.kaart{background:#221e19;border:1px solid var(--rand);border-radius:5px;padding:5px;width:228px;font-size:12px}
.kaart img,.kaart video{width:100%;border-radius:3px;display:block;background:#000}
.kaart img{cursor:zoom-in}
.kaart .knopjes{display:flex;gap:4px;flex-wrap:wrap;margin-top:5px}
.kaart.mislukt{border-color:var(--nee)}
.kaart.bezig{display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:130px;gap:8px;text-align:center}
.kaart.gekozen{border-color:var(--accent);box-shadow:0 0 0 1px var(--accent)}
.kaart.basis{outline:2px dashed var(--blauw)}
.keuze{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:10px}
.keuze .kaart{width:300px}
.fout{color:var(--nee)}
.spin{display:inline-block;width:16px;height:16px;border:2px solid var(--rand);border-top-color:var(--accent);border-radius:50%;animation:draai .8s linear infinite;vertical-align:middle}
.kaart.bezig .spin{width:24px;height:24px;border-width:3px}
@keyframes draai{to{transform:rotate(360deg)}}
#laden{position:fixed;inset:0;background:rgba(20,18,16,.85);display:flex;align-items:center;justify-content:center;gap:12px;z-index:20;font-size:15px}
#toasts{position:fixed;right:16px;bottom:16px;display:flex;flex-direction:column;gap:6px;z-index:30}
.toast{background:#2f2921;border:1px solid var(--rand);border-left:4px solid var(--ok);padding:8px 12px;border-radius:5px;font-size:13px;max-width:440px;box-shadow:0 4px 14px rgba(0,0,0,.5);animation:op .2s ease-out}
.toast.fout{border-left-color:var(--nee)}.toast.info{border-left-color:var(--blauw)}
@keyframes op{from{transform:translateY(8px);opacity:0}to{transform:none;opacity:1}}
#groot{position:fixed;inset:0;background:rgba(0,0,0,.88);display:none;align-items:center;justify-content:center;z-index:40;cursor:zoom-out}
#groot img{max-width:94vw;max-height:94vh}
.wensform{margin:6px 0 4px;font-size:12px}
.wensform .velden{display:none;gap:6px;flex-wrap:wrap;align-items:center;margin-top:6px;background:var(--kaart);border:1px dashed var(--rand);border-radius:6px;padding:8px}
.wensform.open .velden{display:flex}
.wensform input{width:200px}.wensform input.breed{width:420px;max-width:100%}
.kosten{font-size:12px;color:var(--dof);margin-top:6px}
.zinnen{display:none;margin-top:6px;gap:6px;flex-direction:column}
.zinnen.open{display:flex}
.zinnen label{display:flex;gap:8px;align-items:center}.zinnen input{flex:1}
.melding{color:var(--nee);font-size:12px;margin-top:4px}
.ond-chips{display:flex;gap:4px;flex-wrap:wrap;margin:5px 0;align-items:center}
.ond-chips .chip{font-size:11px;padding:1px 8px}
.b-flipbook{background:#9b86d9;color:#111}.b-varianten{background:#cf9a63;color:#111}.b-vast{background:#7fb0a8;color:#111}.b-wacht{background:#5a534a;color:#eee}
canvas.vel{width:150px;height:150px;border-radius:4px;border:1px solid var(--rand);display:block;cursor:zoom-in;background:#26221e}
.kaart canvas.vel{width:100%;height:auto}
.spelvel{display:flex;gap:8px;flex-wrap:wrap}
.spelvel .kaart{width:170px}
.spelvel.veel .kaart{width:96px}.spelvel.veel .klein{font-size:10px}
.drop{border:1px dashed var(--rand);border-radius:6px;padding:12px;text-align:center;color:var(--dof);font-size:12px;margin-top:8px;cursor:pointer}
.drop.over{border-color:var(--accent);color:var(--tekst);background:#2d2820}
.fb{display:none;gap:8px;flex-wrap:wrap;align-items:center;margin-top:6px;background:#221e19;border:1px dashed var(--rand);border-radius:6px;padding:8px;font-size:12px}
.fb.open{display:flex}
.fb input{width:58px}.fb select{max-width:280px}
.kaart select{font-size:12px;padding:1px 4px;max-width:100%}
.actief{color:var(--ok)}
</style></head><body>
<div id="laden"><span class="spin"></span> overzicht laden...</div>
<header>
<div class="balk">
<h1>VFX-studio</h1>
<input id="zoek" placeholder="zoek..." style="width:170px">
<select id="filter">
<option value="">alles</option>
<option value="wens">wensen</option>
<option value="open">nog geen keuze en niet goed</option>
<option value="keuze">met een keuze (dit is hem)</option>
<option value="goed">zo is hij goed</option>
<option value="concepten">met concepten</option>
<option value="texturen">texturen en decals</option>
</select>
<button id="btnSpel" data-act="spelAlle" title="Godot speelt elk effect in de VFX-tuner af en neemt het op; er gaat een venster open, het duurt een paar minuten">Spelbeelden maken (alle)</button>
<span id="spelstatus" class="klein"></span>
<button id="btnImport" data-act="importeer" title="Godot importeert nieuwe texturen; staat de editor open, dan doet die het zelf">Importeer in Godot</button>
<span id="importstatus" class="klein"></span>
<span class="klein" style="margin-left:auto" id="tel"></span>
</div>
<div class="balk">
<label class="klein">Replicate-sleutel <input id="sleutel" type="password" style="width:180px"></label><button class="klein" data-act="sleutel">bewaar</button><span id="account" class="klein"></span>
<label class="klein">beeld <select id="i_beeldmodel" data-inst="beeldmodel"></select></label>
<label class="klein">film <select id="i_filmmodel" data-inst="filmmodel"></select></label>
<label class="klein">duur <select id="i_duur" data-inst="duur"><option>4</option><option>5</option><option>6</option><option>8</option><option>10</option></select> s</label>
<label class="klein"><select id="i_resolutie" data-inst="resolutie"><option>480p</option><option>720p</option></select></label>
<label class="klein"><input type="checkbox" id="i_geluid" data-inst="geluid"> met geluid</label>
<button class="klein" data-act="zinnen" title="de zinnen die de studio voor of achter je prompt zet">zinnen</button>
</div>
<div class="zinnen" id="zinnen">
<label class="klein">achter elk filmpje <input id="i_filmzin" data-inst="filmzin"></label>
<label class="klein">voor een plaatje op een basis <input id="i_basiszin" data-inst="basiszin"></label>
</div>
<div class="kosten">Elke knop is een opdracht op je Replicate-account; de pagina doet niets vanzelf. Een plaatje kost een paar cent (Nano Banana Pro rond $0,13), een filmpje van 5 s ongeveer $0,60 op 480p en ruim $1,20 op 720p (indicatie).</div>
<div class="melding" id="melding"></div>
<div class="nav" id="nav"></div>
</header>
<main id="main"></main>
<div id="groot"><img alt="groot"></div>
<div id="toasts"></div>
<script>
let D=null;const dicht={};const basis={};const spelBasis={};const metBasis={};let poll=null;let spelTimer=null;const bekend=new Set();
const SOORT={beeld:'plaatje',film:'filmpje'};
async function api(p,b){const r=await fetch(p,b?{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(b)}:{});let j;try{j=await r.json()}catch(e){throw new Error('geen antwoord van de studio (draait hij nog?)')}if(j.fout)throw new Error(j.fout);return j}
function esc(s){return String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function toast(t,soort){const d=document.createElement('div');d.className='toast '+(soort||'');d.textContent=t;document.getElementById('toasts').appendChild(d);setTimeout(()=>{d.style.opacity='0';d.style.transition='opacity .4s';setTimeout(()=>d.remove(),400)},soort==='fout'?8000:3500)}
function url(p,v){return '/bestand?p='+encodeURIComponent(p)+(v?'&v='+v:'')}
function rij(id){return D.rijen.find(r=>r.id===id)}
function getal(v){return typeof v==='number'?(Math.round(v*100)/100).toString().replace('.',','):esc(v)}
function isFilm(p){return /\.(mp4|mov|webm)$/i.test(p)}
async function laad(stil){
 if(!stil)document.getElementById('laden').style.display='flex';
 try{D=await api('/api/overzicht');kop();teken();if(!stil&&location.hash==='#texturen'){document.getElementById('filter').value='texturen';filter()}for(const t of D.taken)bekend.add(t.stempel);if(D.taken.length)startPoll();if(D.spel.bezig)spelPoll()}
 catch(e){toast(e.message,'fout')}
 document.getElementById('laden').style.display='none'}
function vul(id,lijst,waarde){const s=document.getElementById(id);let h='',gevonden=false;for(const [slug,naam] of lijst){h+='<option value="'+esc(slug)+'">'+esc(naam)+'</option>';if(slug===waarde)gevonden=true}if(!gevonden&&waarde)h+='<option value="'+esc(waarde)+'">'+esc(waarde)+'</option>';s.innerHTML=h;s.value=waarde}
function kop(){const i=D.instellingen;
 vul('i_beeldmodel',D.modellen.beeld,i.beeldmodel);vul('i_filmmodel',D.modellen.film,i.filmmodel);
 document.getElementById('i_duur').value=String(i.duur);document.getElementById('i_resolutie').value=i.resolutie;
 document.getElementById('i_geluid').checked=!!i.geluid;document.getElementById('i_filmzin').value=i.filmzin;document.getElementById('i_basiszin').value=i.basiszin;
 document.getElementById('sleutel').placeholder=D.sleutel?'sleutel staat (verborgen)':'r8_...';
 const a=D.account;document.getElementById('account').innerHTML=a.naam?'ingelogd als <b>'+esc(a.naam)+'</b>':(a.fout?'<span class="fout">'+esc(a.fout)+'</span>':(D.sleutel?'':'nog geen sleutel'));
 document.getElementById('melding').textContent=D.fout||'';spelStatus();importStatus()}
function stripBeelden(s){const uit=[];if(s.rust)uit.push(s.rust);const n=(s.beelden||[]).length;for(const f of [0.2,0.4,0.6,0.85]){if(n){const p=s.beelden[Math.min(n-1,Math.floor(f*n))];if(!uit.includes(p))uit.push(p)}}return uit}
function basisTekst(id){const p=basis[id]||spelBasis[id];if(!p)return '';return p.includes('/concept/')?'(het gekozen plaatje)':'(het gekozen spelbeeld)'}
function rijHtml(r){const id=esc(r.id),s=r.spel||{};
 const statusBadge='<span class="badge b-'+esc(r.status||'wens')+'">'+esc(r.status||'wens')+'</span>';
 let a='<div><div class="naam">'+esc(r.naam)+statusBadge+(r.goed?'<span class="badge b-goed">goed</span>':'')+((r.keuze.beeld||r.keuze.film)?'<span class="badge b-keuze">keuze</span>':'')+'</div>';
 a+='<div class="id">'+id+'</div><div class="wanneer">'+esc(r.wanneer)+'</div>';
 if(r.alleen_wishlist)a+='<div class="klein">staat alleen in de wishlist: nog niet gebouwd</div>';
 if(r.wl_notitie)a+='<div class="klein">'+esc(r.wl_notitie)+'</div>';
 if(r.notitie_cat)a+='<div class="klein">'+esc(r.notitie_cat)+'</div>';
 if(r.knoppen.length){a+='<details><summary>knoppen ('+r.knoppen.length+')</summary><div class="knoppenlijst">';for(const k of r.knoppen)a+='<div><span>'+esc(k.label)+'</span><span>'+getal(k.waarde)+'</span></div>';a+='</div></details>'}
 if(r.onderdelen&&r.onderdelen.length){a+='<div class="ond-chips"><span class="klein">texturen:</span>';for(const o of r.onderdelen)a+='<span class="chip" data-act="naarOnd" data-ond="'+esc(o.id)+'" title="naar deze textuur">'+esc(o.naam)+'</span>';a+='</div>'}
 a+='<textarea class="notitie" data-veld="notitie" data-id="'+id+'" placeholder="notities: wat moet er anders?">'+esc(r.notitie)+'</textarea>';
 a+='<label class="klein"><input type="checkbox" data-veld="goed" data-id="'+id+'"'+(r.goed?' checked':'')+'> zo is hij goed (in het spel)</label></div>';
 let b='<div><div class="kop">in het spel nu</div>';
 if(s.anim||s.rust){const hoofd=s.anim||s.rust;
  b+='<img class="spelbeeld" loading="lazy" src="'+url(hoofd,s.v)+'" data-act="groot" data-src="'+esc(s.rust||hoofd)+'" alt="'+esc(r.naam)+' in het spel" title="opgenomen '+esc(s.tijd)+'">';
  const keus=stripBeelden(s);if(!spelBasis[r.id]||!keus.includes(spelBasis[r.id]))spelBasis[r.id]=keus[0];
  b+='<div class="strip">';for(const p of keus)b+='<img loading="lazy" src="'+url(p,s.v)+'" alt="spelbeeld" class="'+(spelBasis[r.id]===p?'basis':'')+'" data-act="basis" data-id="'+id+'" data-pad="'+esc(p)+'" title="maak dit de basis voor een plaatje of filmpje">';b+='</div>';
  b+='<div class="klein">klik een beeldje: dat wordt de basis &middot; '+esc(s.tijd)+'</div>';
 }else b+='<div class="leeg">'+(r.speelbaar?'nog niet opgenomen':(r.alleen_wishlist?'bestaat nog niet in het spel':'nog niet af te spelen in de tuner'))+'</div>';
 if(r.speelbaar)b+='<div class="inst"><button class="klein" data-act="spel" data-id="'+id+'" title="Godot speelt dit effect in de VFX-tuner af en neemt het op">'+(s.rust?'opnieuw opnemen':'opnemen in Godot')+'</button></div>';
 b+='</div>';
 let c='<div>';
 if(r.keuze.beeld||r.keuze.film){c+='<div class="kop">dit is hem</div><div class="keuze">';
  if(r.keuze.beeld)c+='<div class="kaart gekozen"><img src="'+url(r.keuze.beeld,r.keuze.v)+'" alt="gekozen plaatje" data-act="groot" data-src="'+esc(r.keuze.beeld)+'" title="'+esc(r.keuze.beeld_prompt||'')+'"><div class="knopjes"><button class="klein" data-act="kiesAf" data-id="'+id+'" data-soort="beeld">kies af</button></div></div>';
  if(r.keuze.film)c+='<div class="kaart gekozen"><video src="'+url(r.keuze.film,r.keuze.v)+'" controls loop muted playsinline preload="metadata" title="'+esc(r.keuze.film_prompt||'')+'"></video><div class="knopjes">'+(r.keuze.film_vel?'<button class="klein" data-act="groot" data-src="'+esc(r.keuze.film_vel)+'" title="12 beelden uit het filmpje">vel</button>':'')+'<button class="klein" data-act="kiesAf" data-id="'+id+'" data-soort="film">kies af</button></div></div>';
  c+='</div>'}
 c+='<div class="kop">concept</div><textarea class="prompt" id="p_'+id+'" data-veld="prompt" data-id="'+id+'" placeholder="'+esc(r.prompt_bron||'nog geen prompt in de wishlist: schrijf er een, in het Engels')+'">'+esc(r.prompt)+'</textarea>';
 c+='<div class="inst"><button class="prim" data-act="beeld" data-id="'+id+'" data-n="1">Maak plaatje</button><button data-act="beeld" data-id="'+id+'" data-n="3" title="drie keer, meer keus">&times;3</button>';
 c+='<label class="klein" title="het volgende plaatje bouwt voort op een spelbeeld (klik er een in de strip) of op een eerder plaatje (verder hierop)"><input type="checkbox" id="b_'+id+'" data-basis="'+id+'"'+(metBasis[r.id]?' checked':'')+((s.rust||basis[r.id])?'':' disabled')+'> op de basis <span id="bt_'+id+'">'+basisTekst(r.id)+'</span></label>';
 c+='<button data-act="filmSpel" data-id="'+id+'"'+(s.rust?'':' disabled')+' title="Seedance begint bij het gekozen spelbeeld">Filmpje van het spelbeeld</button>';
 if(r.prompt&&r.prompt_bron)c+='<button class="klein" data-act="herstel" data-id="'+id+'" title="terug naar de prompt uit de wishlist">herstel prompt</button>';
 c+='</div><div class="galerij">'+galerij(r)+'</div>';
 c+='<div class="drop" data-id="'+id+'" data-act="kiesBestand">Sleep hier een eigen plaatje of filmpje als concept (of klik)<input type="file" multiple accept=".png,.jpg,.jpeg,.webp,.gif,.mp4,.mov,.webm" hidden></div></div>';
 return a+b+c}
function galerij(r){let h='';const id=esc(r.id);
 for(const m of r.concepten){const naam=SOORT[m.soort]||m.soort;
  if(m.status==='start'||m.status==='bezig'){const t=m.soort==='film'?'Seedance maakt het filmpje':'het plaatje komt';h+='<div class="kaart bezig"><span class="spin"></span><span class="tijd" data-tekst="'+t+'" data-start="'+(m.start||0)+'">'+t+'</span><span class="klein">'+esc(m.model)+'</span><button class="klein" data-act="stop" data-id="'+id+'" data-stempel="'+esc(m.stempel)+'">stop</button></div>';continue}
  if(m.status==='mislukt'){h+='<div class="kaart mislukt"><div class="fout">'+esc(naam)+' mislukt: '+esc(m.fout||'')+'</div><div class="klein" title="'+esc(m.volle_prompt||m.prompt)+'">'+esc(m.tijd)+'</div><div class="knopjes"><button class="klein" data-act="weg" data-id="'+id+'" data-stempel="'+esc(m.stempel)+'">weg</button></div></div>';continue}
  for(const p of m.bestanden||[]){const film=isFilm(p);const gek=(r.keuze.film_bron===p||r.keuze.beeld_bron===p);
   h+='<div class="kaart'+(gek?' gekozen':'')+(basis[r.id]===p?' basis':'')+'">'+(film?'<video src="'+url(p)+'" controls loop muted playsinline preload="metadata"></video>':'<img loading="lazy" src="'+url(p)+'" alt="concept" data-act="groot" data-src="'+esc(p)+'">');
   h+='<div class="knopjes">'+(film?'':'<button class="klein prim" data-act="film" data-id="'+id+'" data-pad="'+esc(p)+'" title="Seedance maakt een filmpje met dit plaatje als eerste beeld">Maak filmpje</button><button class="klein" data-act="verder" data-id="'+id+'" data-pad="'+esc(p)+'" title="het volgende plaatje op dit plaatje laten voortbouwen">verder hierop</button>')+(film&&velVan(m,p)?'<button class="klein" data-act="groot" data-src="'+esc(velVan(m,p))+'" title="12 beelden uit het filmpje">vel</button>':'')+'<button class="klein" data-act="kies" data-id="'+id+'" data-pad="'+esc(p)+'">Dit is hem</button><button class="klein" data-act="weg" data-id="'+id+'" data-pad="'+esc(p)+'">weg</button></div>';
   h+='<div class="klein" title="'+esc(m.volle_prompt||m.prompt)+'">'+esc(m.tijd)+' &middot; '+esc(m.bron==='upload'?'eigen bestand':(m.model||'').split('/').pop())+(m.basis?' &middot; op een basis':'')+(film&&m.bron?' &middot; vanaf '+(m.bron.includes('/spel/')?'het spelbeeld':'een plaatje'):'')+(m.seconden?' &middot; '+m.seconden+' s':'')+'</div></div>'}}
 return h||'<div class="klein">nog geen concepten</div>'}
function velVan(m,p){const b=p.replace(/\.[^.]+$/,'');return (m.vellen||[]).find(v=>v.startsWith(b))||''}
function ond(id){return (D.onderdelen||[]).find(o=>o.id===id)}
function ondPrompt(o,film){const t=document.getElementById('p_'+o.eid);return (t&&t.value.trim())||(film?o.film_bron:o.prompt_bron)||''}
const ROOSTERS=['1x1','2x2','3x3','4x4','5x5','6x6','8x8','3x1','4x1','8x1'];
function velCanvas(pad,v,k,r,o){return '<canvas class="vel" data-src="'+esc(pad)+'" data-v="'+(v||0)+'" data-k="'+k+'" data-r="'+r+'" data-zwart="'+(o.achtergrond==='zwart'?1:0)+'" data-boost="'+o.boost+'" data-act="groot"></canvas>'}
function ondHtml(o){const id=esc(o.id),eid=esc(o.eid);
 let a='<div><div class="naam">'+esc(o.naam)+'<span class="badge b-'+esc(o.soort)+'">'+esc(o.soort)+'</span>'+(o.gebruikt?'':'<span class="badge b-wacht">wacht op code</span>')+'</div>';
 a+='<div class="id">assets/textures/'+esc(o.map)+'/'+esc(o.bestand)+(o.soort==='flipbook'?'_KxR.png (rooster, bv. _4x4)':(o.soort==='varianten'?'1.png, 2.png ...':'.png'))+'</div>';
 a+='<div class="wanneer">'+esc(o.uitleg)+'</div>';
 a+='<div class="klein">'+(o.achtergrond==='zwart'?'zwart wordt doorzichtig (helderheid maal '+getal(o.boost)+'); een PNG met doorzichtigheid mag ook':'een PNG met doorzichtigheid: haal de achtergrond weg')+(o.soort==='flipbook'?'; de beeldjes spelen na elkaar af, het rooster staat in de naam':'')+'</div>';
 if(o.effecten.length){a+='<div class="ond-chips"><span class="klein">gebruikt door:</span>';for(const e of o.effecten)a+='<span class="chip" data-act="naarEffect" data-id="'+esc(e.id)+'">'+esc(e.naam)+'</span>';a+='</div>'}
 a+='<textarea class="notitie" data-veld="notitie" data-id="'+eid+'" placeholder="notities: wat moet er anders?">'+esc(o.notitie)+'</textarea></div>';
 let b='<div><div class="kop">in het spel nu</div>';
 if(o.spel.length){b+='<div class="spelvel'+(o.spel.length>2?' veel':'')+'">';for(const f of o.spel)b+='<div class="kaart">'+velCanvas(f.pad,f.v,f.rooster[0],f.rooster[1],o)+'<div class="klein">'+esc(f.naam)+(f.maat?' &middot; '+f.maat[0]+'x'+f.maat[1]:'')+(f.rooster[0]*f.rooster[1]>1?' &middot; '+f.rooster[0]+'x'+f.rooster[1]+' beeldjes':'')+(o.soort==='flipbook'?(f.actief?' &middot; <span class="actief">in gebruik</span>':' &middot; niet in gebruik (het spel pakt de eerste)'):'')+'</div></div>';b+='</div>'}
 else b+='<div class="leeg">'+(o.gebruikt?'nog niets: het spel tekent nu een vervanger':'nog niets, en het spel kijkt hier nog niet')+'</div>';
 b+='</div>';
 let c='<div><div class="kop">nieuw</div><textarea class="prompt" id="p_'+eid+'" data-veld="prompt" data-id="'+eid+'" placeholder="'+esc(o.prompt_bron)+'">'+esc(o.prompt)+'</textarea>';
 c+='<div class="inst"><button class="prim" data-act="ondBeeld" data-ond="'+id+'" data-n="1" title="vierkant, met de prompt hierboven">Maak plaatje</button><button data-act="ondBeeld" data-ond="'+id+'" data-n="3" title="drie keer, meer keus">&times;3</button>';
 if(o.film_bron)c+='<button data-act="ondFilm" data-ond="'+id+'" title="Seedance maakt een vierkant filmpje van alleen dit onderdeel, op zwart: daar knip je een flipbook uit. Leeg vak = de filmprompt: '+esc(o.film_bron)+'">Maak filmpje (op zwart)</button>';
 c+='<button data-act="fbOpen" data-ond="'+id+'"'+(o.films.length?'':' disabled')+' title="knip een flipbook uit een filmpje van dit onderdeel of van een effect dat het gebruikt">Flipbook uit filmpje</button></div>';
 c+=fbForm(o);
 c+='<div class="drop" data-ond="'+id+'" data-act="kiesBestand">Sleep hier een PNG, JPG, GIF of MP4 (of klik): eigen werk, een pakket, iets van elders<input type="file" multiple accept=".png,.jpg,.jpeg,.webp,.gif,.mp4,.mov,.webm" hidden></div>';
 c+='<div class="galerij">'+ondGalerij(o)+'</div></div>';
 return a+b+c}
function fbForm(o){const id=esc(o.id);let opts='';for(const f of o.films)opts+='<option value="'+esc(f.pad)+'">'+esc(f.label)+'</option>';
 return '<div class="fb" id="fb_'+id+'"><label>filmpje <select data-fb="film">'+opts+'</select></label><label>van <input data-fb="start" value="0"> s</label><label>tot <input data-fb="eind" value="0" title="0 = tot het eind"> s</label><label>rooster <select data-fb="rooster">'+ROOSTERS.slice(1).map(x=>'<option'+(x==='4x4'?' selected':'')+'>'+x+'</option>').join('')+'</select></label><label>beeldje <select data-fb="cel"><option>128</option><option>192</option><option selected>256</option><option>384</option><option>512</option></select> px</label><label>inzoomen <input data-fb="zoom" value="1" title="1 = het grootste vierkant uit het midden, 2 = de helft daarvan"></label><button class="prim klein" data-act="fbMaak" data-ond="'+id+'">Maak flipbook</button><span class="klein">tot 0 = tot het eind; het vel wordt hooguit 1024 px</span></div>'}
function ondGalerij(o){let h='';const id=esc(o.id),eid=esc(o.eid);
 for(const m of o.kandidaten){
  if(m.status==='start'||m.status==='bezig'){const t=m.soort==='film'?'Seedance maakt het filmpje':'het plaatje komt';h+='<div class="kaart bezig"><span class="spin"></span><span class="tijd" data-tekst="'+t+'" data-start="'+(m.start||0)+'">'+t+'</span><span class="klein">'+esc(m.model)+'</span><button class="klein" data-act="stop" data-id="'+eid+'" data-stempel="'+esc(m.stempel)+'">stop</button></div>';continue}
  if(m.status==='mislukt'){h+='<div class="kaart mislukt"><div class="fout">'+esc(SOORT[m.soort]||m.soort)+' mislukt: '+esc(m.fout||'')+'</div><div class="knopjes"><button class="klein" data-act="weg" data-id="'+eid+'" data-stempel="'+esc(m.stempel)+'">weg</button></div></div>';continue}
  for(const p of m.bestanden||[]){const film=m.soort==='film';const k=(m.rooster||[1,1])[0],r=(m.rooster||[1,1])[1];
   h+='<div class="kaart'+(m.in_spel?' gekozen':'')+'">';
   if(film){h+=(/\.gif$/i.test(p)?'<img loading="lazy" src="'+url(p)+'" alt="gif" data-act="groot" data-src="'+esc(p)+'">':'<video src="'+url(p)+'" controls loop muted playsinline preload="metadata"></video>');
    h+='<div class="knopjes"><button class="klein prim" data-act="fbOpen" data-ond="'+id+'" data-film="'+esc(p)+'">flipbook hiervan</button>'+(velVan(m,p)?'<button class="klein" data-act="groot" data-src="'+esc(velVan(m,p))+'" title="12 beelden uit het filmpje">vel</button>':'')+'<button class="klein" data-act="weg" data-id="'+eid+'" data-pad="'+esc(p)+'">weg</button></div>'}
   else{h+=velCanvas(p,0,k,r,o)+'<div class="knopjes">';
    if(o.soort==='varianten'){h+='<button class="klein prim" data-act="variant" data-ond="'+id+'" data-pad="'+esc(p)+'" title="erbij als nieuwe variant: het spel kiest er dan ook deze uit">erbij in het spel</button>';
     if(o.spel.length)h+='<select data-vervang="'+id+'" data-pad="'+esc(p)+'"><option value="">vervang...</option>'+o.spel.map(f=>'<option value="'+esc(f.naam)+'">'+esc(f.naam)+'</option>').join('')+'</select>'}
    else h+='<button class="klein prim" data-act="inSpel" data-ond="'+id+'" data-pad="'+esc(p)+'" title="onder de goede naam in assets/textures/'+esc(o.map)+'/ (de oude gaat naar een backup)">In het spel</button>';
    h+='<select data-vrij="'+id+'" data-pad="'+esc(p)+'"><option value="">achtergrond weg...</option><option value="zwart">zwart wordt doorzichtig</option><option value="wit">wit wordt doorzichtig</option><option value="groen">groen wordt doorzichtig</option></select>';
    h+='<select data-rooster="'+id+'" data-stempel="'+esc(m.stempel)+'" title="hoeveel beeldjes staan er op dit vel?">'+ROOSTERS.map(x=>'<option'+(x===k+'x'+r?' selected':'')+'>'+x+'</option>').join('')+'</select>';
    if(o.film_bron)h+='<button class="klein" data-act="ondFilm" data-ond="'+id+'" data-pad="'+esc(p)+'" title="Seedance maakt een filmpje met dit plaatje als eerste beeld">filmpje hiervan</button>';
    h+='<button class="klein" data-act="weg" data-id="'+eid+'" data-pad="'+esc(p)+'">weg</button></div>'}
   const bron={upload:'eigen bestand'+(m.naam?': '+m.naam:''),flipbook:'flipbook uit een filmpje',vrijstaand:'achtergrond weg ('+(m.methode||'')+')'}[m.bron]||((m.model||'').split('/').pop());
   h+='<div class="klein" title="'+esc(m.volle_prompt||m.prompt||'')+'">'+esc(m.tijd)+' &middot; '+esc(bron)+(m.in_spel?' &middot; <span class="actief">in het spel</span>':'')+'</div></div>'}}
 return h||'<div class="klein">nog geen kandidaten</div>'}
function ondAttrs(el,o){if(!el)return;el.dataset.zoek=(o.naam+' '+o.id+' '+o.map+' '+o.bestand+' '+o.uitleg+' '+o.notitie).toLowerCase()}
function ruit(ctx,w,h){const s=10;for(let y=0;y<h;y+=s)for(let x=0;x<w;x+=s){ctx.fillStyle=((Math.floor(x/s)+Math.floor(y/s))%2)?'#3b352f':'#26221e';ctx.fillRect(x,y,s,s)}}
// een textuur zoals het spel hem ziet: op ruitjes (doorzichtigheid), een vel speelt zijn beeldjes af,
// en "zwart" krijgt zijn doorzichtigheid uit de helderheid, net als PawnView._black_to_alpha
function startVellen(root){(root||document).querySelectorAll('canvas.vel:not([data-aan])').forEach(cv=>{cv.dataset.aan=1;const k=Math.max(1,+cv.dataset.k||1),r=Math.max(1,+cv.dataset.r||1),zwart=cv.dataset.zwart==='1',boost=+cv.dataset.boost||2.3;const img=new Image();
 img.onload=()=>{const fw=img.width/k,fh=img.height/r;cv.width=150;cv.height=Math.max(1,Math.round(150*fh/fw));const ctx=cv.getContext('2d');const tmp=document.createElement('canvas');tmp.width=cv.width;tmp.height=cv.height;const tc=tmp.getContext('2d',{willReadFrequently:true});
  let alpha=false;{const t2=document.createElement('canvas');t2.width=Math.min(img.width,200);t2.height=Math.min(img.height,200);const c2=t2.getContext('2d',{willReadFrequently:true});c2.drawImage(img,0,0,t2.width,t2.height);const d=c2.getImageData(0,0,t2.width,t2.height).data;for(let i=3;i<d.length;i+=4){if(d[i]<250){alpha=true;break}}}
  const n=k*r;let f=0;
  const stap=()=>{tc.clearRect(0,0,tmp.width,tmp.height);tc.drawImage(img,(f%k)*fw,Math.floor(f/k)*fh,fw,fh,0,0,tmp.width,tmp.height);
   if(zwart&&!alpha){const id=tc.getImageData(0,0,tmp.width,tmp.height),d=id.data;for(let i=0;i<d.length;i+=4){d[i+3]=Math.min(255,Math.max(d[i],d[i+1],d[i+2])*boost)}tc.putImageData(id,0,0)}
   ruit(ctx,cv.width,cv.height);ctx.drawImage(tmp,0,0);f=(f+1)%n};
  stap();if(n>1){const t=setInterval(()=>{if(!cv.isConnected){clearInterval(t);return}stap()},Math.max(45,1200/n))}};
 img.src=url(cv.dataset.src,cv.dataset.v)})}
async function verversOnd(id,flits){try{const o=await api('/api/onderdeel?id='+encodeURIComponent(id));const i=(D.onderdelen||[]).findIndex(x=>x.id===id);if(i>=0)D.onderdelen[i]=o;const el=document.querySelector('.rij.ond[data-ond="'+id+'"]');if(!el)return;
 const fb=document.getElementById('fb_'+id);const fbOpen=fb&&fb.classList.contains('open');const t=document.getElementById('p_'+o.eid);const tik=t&&document.activeElement===t?t.value:null;
 el.innerHTML=ondHtml(o);ondAttrs(el,o);if(fbOpen)document.getElementById('fb_'+id).classList.add('open');if(tik!==null){const t2=document.getElementById('p_'+o.eid);t2.value=tik;t2.focus()}
 startVellen(el);if(flits){el.classList.remove('nieuw');void el.offsetWidth;el.classList.add('nieuw')}}catch(e){toast(e.message,'fout')}}
async function zetInSpel(oid,pad,modus,doel){try{const j=await api('/api/in_spel',{id:oid,pad,modus,doel});toast('in het spel: '+j.doel+(j.weg.length?' (weg, met backup: '+j.weg.join(', ')+')':'')+(j.editor?'. De editor importeert hem zodra je naar zijn venster gaat.':'. Druk op Importeer in Godot, of open de editor.'));await verversOnd(oid,true)}catch(e){toast(e.message,'fout')}}
async function uploadBestanden(eid,files,oid,id){for(const f of files){try{const r=await fetch('/api/upload?id='+encodeURIComponent(eid)+'&naam='+encodeURIComponent(f.name),{method:'POST',body:f});const j=await r.json();if(j.fout)throw new Error(j.fout);toast(f.name+' staat erin')}catch(e){toast(f.name+': '+e.message,'fout')}}if(oid)await verversOnd(oid,true);else if(id)await ververs(id,true)}
function importStatus(){const s=D.import||{};const el=document.getElementById('importstatus');el.innerHTML=s.bezig?'<span class="spin"></span> Godot importeert...':(s.laatste?'import: '+esc(s.laatste):'');document.getElementById('btnImport').disabled=!!s.bezig}
let importTimer=null;
function importPoll(){if(importTimer)return;importTimer=setInterval(async()=>{let s;try{s=await api('/api/import_status')}catch(e){return}D.import=s;importStatus();if(!s.bezig){clearInterval(importTimer);importTimer=null;toast('Godot-import '+s.laatste,(s.laatste||'').startsWith('klaar')?'':'fout')}},3000)}
function wensForm(c){return '<div class="wensform" data-groep="'+esc(c.id)+'"><button class="klein" data-act="wensOpen">+ nieuwe wens in '+esc(c.naam)+'</button><div class="velden"><input class="breed" placeholder="naam, bv. Rookpluim boven een brandend huis" data-w="naam"><input placeholder="wanneer in het spel" data-w="wanneer"><input class="breed" placeholder="wens of notitie" data-w="notitie"><input class="breed" placeholder="concept-prompt in het Engels (mag leeg)" data-w="prompt"><button class="prim klein" data-act="wens" data-naam="'+esc(c.naam)+'">zet in de wishlist</button></div></div>'}
function teken(){const m=document.getElementById('main');let h='',sec=null;const secs=[];
 for(const r of D.rijen){
  if(r.groep!==sec){if(sec!==null)h+=wensForm(secs[secs.length-1])+'</div>';sec=r.groep;secs.push({id:r.groep,naam:r.groepnaam,n:0,keuze:0,goed:0});h+='<div class="sectie'+(dicht[sec]?' dicht':'')+'" data-groep="'+esc(sec)+'"><h2 data-act="klap" data-groep="'+esc(sec)+'">'+esc(r.groepnaam)+'<span class="sub"></span></h2>'}
  const c=secs[secs.length-1];c.n++;if(r.keuze.beeld||r.keuze.film)c.keuze++;if(r.goed)c.goed++;
  h+='<div class="rij" data-id="'+esc(r.id)+'">'+rijHtml(r)+'</div>'}
 if(sec!==null)h+=wensForm(secs[secs.length-1])+'</div>';
 const O=D.onderdelen||[];
 if(O.length){h+='<div class="sectie'+(dicht.onderdelen?' dicht':'')+'" data-groep="onderdelen"><h2 data-act="klap" data-groep="onderdelen">Texturen en decals<span class="sub">'+O.length+' onderdelen, '+O.filter(o=>o.spel.length).length+' met een bestand in het spel, '+O.reduce((t,o)=>t+o.kandidaten.length,0)+' kandidaten</span></h2>';for(const o of O)h+='<div class="rij ond" data-ond="'+esc(o.id)+'">'+ondHtml(o)+'</div>';h+='</div>'}
 m.innerHTML=h;
 for(const r of D.rijen)attrs(document.querySelector('.rij[data-id="'+r.id+'"]'),r);
 for(const o of O)ondAttrs(document.querySelector('.rij.ond[data-ond="'+o.id+'"]'),o);
 startVellen(m);
 let nav='';for(const c of secs){const s=document.querySelector('.sectie[data-groep="'+c.id+'"] .sub');if(s)s.textContent=c.n+' effecten, '+c.keuze+' met een keuze, '+c.goed+' goed';nav+='<span class="chip" data-act="spring" data-groep="'+esc(c.id)+'">'+esc(c.naam)+' <span class="klein">'+c.keuze+'/'+c.n+'</span></span>'}
 if(O.length)nav+='<span class="chip" data-act="spring" data-groep="onderdelen">Texturen en decals <span class="klein">'+O.length+'</span></span>';
 document.getElementById('nav').innerHTML=nav;tel();filter()}
function tel(){const n=D.rijen.length,k=D.rijen.filter(r=>r.keuze.beeld||r.keuze.film).length,g=D.rijen.filter(r=>r.goed).length,c=D.rijen.reduce((s,r)=>s+r.concepten.length,0);document.getElementById('tel').textContent=n+' effecten: '+k+' met een keuze, '+g+' goed, '+c+' concepten'}
function attrs(el,r){if(!el)return;el.dataset.zoek=(r.naam+' '+r.id+' '+r.wanneer+' '+r.groepnaam+' '+r.notitie).toLowerCase();el.dataset.status=r.status;el.dataset.keuze=(r.keuze.beeld||r.keuze.film)?1:0;el.dataset.goed=r.goed?1:0;el.dataset.concepten=r.concepten.length?1:0}
function filter(){const z=document.getElementById('zoek').value.toLowerCase(),f=document.getElementById('filter').value;
 for(const e of document.querySelectorAll('.rij')){let aan=!z||e.dataset.zoek.includes(z);
  if(f==='wens')aan=aan&&e.dataset.status==='wens';else if(f==='open')aan=aan&&e.dataset.keuze==='0'&&e.dataset.goed==='0';else if(f==='keuze')aan=aan&&e.dataset.keuze==='1';else if(f==='goed')aan=aan&&e.dataset.goed==='1';else if(f==='concepten')aan=aan&&e.dataset.concepten==='1';else if(f==='texturen')aan=aan&&e.classList.contains('ond');
  e.classList.toggle('verberg',!aan)}
 for(const s of document.querySelectorAll('.sectie')){const zicht=[...s.querySelectorAll('.rij')].some(e=>!e.classList.contains('verberg'));s.style.display=(zicht||(!z&&!f))?'':'none'}}
document.getElementById('zoek').oninput=filter;document.getElementById('filter').onchange=filter;
async function ververs(id,flits){try{const r=await api('/api/rij?id='+encodeURIComponent(id));const i=D.rijen.findIndex(x=>x.id===id);if(i>=0)D.rijen[i]=r;const el=document.querySelector('.rij[data-id="'+id+'"]');if(!el)return;
 const t=document.getElementById('p_'+id);const tik=t&&document.activeElement===t?t.value:null;
 el.innerHTML=rijHtml(r);attrs(el,r);if(tik!==null){const t2=document.getElementById('p_'+id);t2.value=tik;t2.focus()}
 if(flits){el.classList.remove('nieuw');void el.offsetWidth;el.classList.add('nieuw')}tel();filter()}catch(e){toast(e.message,'fout')}}
function promptVan(id){const t=document.getElementById('p_'+id);return (t&&t.value.trim())||((rij(id)||{}).prompt_bron||'')}
async function bewaar(id,veld,waarde){try{await api('/api/'+veld,{id,waarde})}catch(e){toast(e.message,'fout')}}
async function bestelFilm(b,id,pad){const prompt=promptVan(id);if(!prompt){toast('Geen prompt: schrijf in het vak wat er moet gebeuren (Engels).','fout');return}
 const i=D.instellingen;const kost=(Number(i.duur)*(i.resolutie==='720p'?0.27:0.12)).toFixed(2).replace('.',',');
 if(!confirm('Filmpje van '+i.duur+' s op '+i.resolutie+' bij '+i.filmmodel+' bestellen? Dat kost ongeveer $'+kost+' (indicatie).'))return;
 b.disabled=true;try{const j=await api('/api/film',{id,prompt,bron:pad});bekend.add(j.stempel);toast('filmpje besteld; dat duurt een paar minuten','info');await ververs(id);startPoll()}catch(e){toast(e.message,'fout')}b.disabled=false}
async function spelbeelden(id){try{await api('/api/spelbeelden',{id});toast('Godot neemt op'+(id?' ('+id+')':'')+'; er gaat een venster open','info');spelPoll()}catch(e){toast(e.message,'fout')}}
function spelStatus(){const s=D.spel||{};const el=document.getElementById('spelstatus');el.innerHTML=s.bezig?'<span class="spin"></span> Godot neemt op: '+esc(s.nu||'...')+' ('+s.klaar+' van '+s.totaal+')':(s.laatste?esc(s.laatste):'');document.getElementById('btnSpel').disabled=!!s.bezig}
function spelPoll(){if(spelTimer)return;spelTimer=setInterval(async()=>{let s;try{s=await api('/api/spel_status')}catch(e){return}D.spel=s;spelStatus();if(!s.bezig){clearInterval(spelTimer);spelTimer=null;toast('opnemen '+s.laatste,(s.fouten&&s.fouten.length)?'fout':'');await laad(true)}},2000)}
function startPoll(){if(!poll)poll=setInterval(pollTaken,2500);pollTaken()}
async function pollTaken(){let j;try{j=await api('/api/taken')}catch(e){return}
 const nu=new Set(j.taken.map(t=>t.stempel));
 for(const s of [...bekend]){if(nu.has(s))continue;bekend.delete(s);const r=D.rijen.find(x=>x.concepten.some(m=>m.stempel===s));
  if(r){await ververs(r.id,true);const m=(rij(r.id)||{concepten:[]}).concepten.find(x=>x.stempel===s);if(m)toast(m.status==='klaar'?(SOORT[m.soort]+' voor '+r.naam+' is er'):(SOORT[m.soort]+' voor '+r.naam+' mislukt: '+(m.fout||'')),m.status==='klaar'?'':'fout');continue}
  const o=(D.onderdelen||[]).find(x=>x.kandidaten.some(m=>m.stempel===s));
  if(o){await verversOnd(o.id,true);const m=(ond(o.id)||{kandidaten:[]}).kandidaten.find(x=>x.stempel===s);if(m)toast(m.status==='klaar'?(SOORT[m.soort]+' voor '+o.naam+' is er'):(SOORT[m.soort]+' voor '+o.naam+' mislukt: '+(m.fout||'')),m.status==='klaar'?'':'fout')}}
 for(const t of j.taken)bekend.add(t.stempel);
 const sec=Date.now()/1000;document.querySelectorAll('.kaart.bezig .tijd').forEach(t=>{const s=+t.dataset.start;if(s)t.textContent=t.dataset.tekst+', '+Math.max(0,Math.round(sec-s))+' s'});
 if(!j.taken.length){clearInterval(poll);poll=null}}
const ACT={
 groot:b=>{const g=document.getElementById('groot');g.querySelector('img').src=url(b.dataset.src);g.style.display='flex'},
 basis:b=>{const id=b.dataset.id;spelBasis[id]=b.dataset.pad;basis[id]=b.dataset.pad;metBasis[id]=true;b.parentElement.querySelectorAll('img').forEach(i=>i.classList.toggle('basis',i===b));const cb=document.getElementById('b_'+id);if(cb){cb.disabled=false;cb.checked=true}const bt=document.getElementById('bt_'+id);if(bt)bt.textContent=basisTekst(id);document.querySelectorAll('.rij[data-id="'+id+'"] .galerij .kaart.basis').forEach(k=>k.classList.remove('basis'))},
 verder:b=>{const id=b.dataset.id;basis[id]=b.dataset.pad;metBasis[id]=true;const cb=document.getElementById('b_'+id);if(cb){cb.disabled=false;cb.checked=true}const bt=document.getElementById('bt_'+id);if(bt)bt.textContent=basisTekst(id);document.querySelectorAll('.rij[data-id="'+id+'"] .galerij .kaart').forEach(k=>k.classList.toggle('basis',k.contains(b)));toast('het volgende plaatje bouwt voort op dit plaatje; pas de prompt aan en druk op Maak plaatje','info')},
 klap:b=>{const s=b.parentElement;s.classList.toggle('dicht');dicht[b.dataset.groep]=s.classList.contains('dicht')},
 spring:b=>{const s=document.querySelector('.sectie[data-groep="'+b.dataset.groep+'"]');if(!s)return;s.classList.remove('dicht');dicht[b.dataset.groep]=false;s.scrollIntoView({block:'start',behavior:'smooth'})},
 zinnen:()=>document.getElementById('zinnen').classList.toggle('open'),
 sleutel:async()=>{const k=document.getElementById('sleutel').value.trim();if(!k)return;try{const j=await api('/api/sleutel',{sleutel:k});document.getElementById('sleutel').value='';toast(j.naam?'sleutel bewaard, ingelogd als '+j.naam:'sleutel bewaard'+(j.melding?' ('+j.melding+')':''));await laad(true)}catch(e){toast(e.message,'fout')}},
 beeld:async b=>{const id=b.dataset.id,n=+b.dataset.n;const prompt=promptVan(id);if(!prompt){toast('Geen prompt: schrijf er een in het vak (Engels).','fout');return}
  const cb=document.getElementById('b_'+id);const bp=(cb&&cb.checked)?(basis[id]||spelBasis[id]||''):'';
  b.disabled=true;try{for(let i=0;i<n;i++){const j=await api('/api/beeld',{id,prompt,basis:bp});bekend.add(j.stempel)}toast((n>1?n+' plaatjes':'plaatje')+' besteld','info');await ververs(id);startPoll()}catch(e){toast(e.message,'fout')}b.disabled=false},
 film:async b=>{await bestelFilm(b,b.dataset.id,b.dataset.pad)},
 filmSpel:async b=>{const id=b.dataset.id;const r=rij(id)||{};const p=spelBasis[id]||((r.spel||{}).rust);if(!p){toast('Nog geen spelbeelden: neem het effect eerst op.','fout');return}await bestelFilm(b,id,p)},
 stop:async b=>{try{await api('/api/stop',{id:b.dataset.id,stempel:b.dataset.stempel});toast('gestopt; wat al gemaakt is rekent Replicate wel','info')}catch(e){toast(e.message,'fout')}},
 kies:async b=>{try{const j=await api('/api/kies',{id:b.dataset.id,pad:b.dataset.pad});toast('dit is hem: '+j.doel);await ververs(b.dataset.id,true)}catch(e){toast(e.message,'fout')}},
 kiesAf:async b=>{try{await api('/api/kies_af',{id:b.dataset.id,soort:b.dataset.soort});await ververs(b.dataset.id)}catch(e){toast(e.message,'fout')}},
 weg:async b=>{if(b.dataset.pad&&!confirm('Weggooien? Terughalen kan niet (het kostte geld).'))return;try{await api('/api/weg',{id:b.dataset.id,pad:b.dataset.pad||'',stempel:b.dataset.stempel||''});if(basis[b.dataset.id]===b.dataset.pad)delete basis[b.dataset.id];await ververs(b.dataset.id)}catch(e){toast(e.message,'fout')}},
 herstel:async b=>{const id=b.dataset.id;document.getElementById('p_'+id).value='';await bewaar(id,'prompt','');await ververs(id)},
 spel:async b=>{await spelbeelden(b.dataset.id)},
 spelAlle:async()=>{if(!confirm('Godot opent een venster en speelt alle effecten af (een paar minuten). Doorgaan?'))return;await spelbeelden('')},
 naarOnd:b=>{const el=document.querySelector('.rij.ond[data-ond="'+b.dataset.ond+'"]');if(!el)return;const s=el.closest('.sectie');s.classList.remove('dicht');dicht.onderdelen=false;el.scrollIntoView({block:'center',behavior:'smooth'});el.classList.remove('nieuw');void el.offsetWidth;el.classList.add('nieuw')},
 naarEffect:b=>{const el=document.querySelector('.rij[data-id="'+b.dataset.id+'"]');if(!el)return;const s=el.closest('.sectie');s.classList.remove('dicht');el.scrollIntoView({block:'center',behavior:'smooth'});el.classList.remove('nieuw');void el.offsetWidth;el.classList.add('nieuw')},
 ondBeeld:async b=>{const o=ond(b.dataset.ond);if(!o)return;const prompt=ondPrompt(o,false);if(!prompt){toast('Geen prompt: schrijf er een in het vak (Engels).','fout');return}const n=+b.dataset.n||1;b.disabled=true;try{for(let i=0;i<n;i++){const j=await api('/api/beeld',{id:o.eid,prompt,basis:''});bekend.add(j.stempel)}toast((n>1?n+' plaatjes':'plaatje')+' besteld (vierkant)','info');await verversOnd(o.id);startPoll()}catch(e){toast(e.message,'fout')}b.disabled=false},
 ondFilm:async b=>{const o=ond(b.dataset.ond);if(!o)return;const prompt=ondPrompt(o,true);if(!prompt){toast('Geen prompt: schrijf in het vak wat er moet gebeuren (Engels).','fout');return}const i=D.instellingen;const kost=(Number(i.duur)*(i.resolutie==='720p'?0.27:0.12)).toFixed(2).replace('.',',');
  if(!confirm('Filmpje van '+i.duur+' s op '+i.resolutie+(b.dataset.pad?' vanaf dit plaatje':' (vierkant, op zwart)')+' bij '+i.filmmodel+' bestellen? Dat kost ongeveer $'+kost+' (indicatie).'))return;
  b.disabled=true;try{const j=await api('/api/film',{id:o.eid,prompt,bron:b.dataset.pad||''});bekend.add(j.stempel);toast('filmpje besteld; dat duurt een paar minuten','info');await verversOnd(o.id);startPoll()}catch(e){toast(e.message,'fout')}b.disabled=false},
 fbOpen:b=>{const f=document.getElementById('fb_'+b.dataset.ond);if(!f)return;f.classList.add('open');if(b.dataset.film){const s=f.querySelector('[data-fb="film"]');if(s){if(![...s.options].some(x=>x.value===b.dataset.film)){const op=document.createElement('option');op.value=b.dataset.film;op.textContent='dit filmpje';s.appendChild(op)}s.value=b.dataset.film}}f.scrollIntoView({block:'nearest',behavior:'smooth'})},
 fbMaak:async b=>{const f=document.getElementById('fb_'+b.dataset.ond);const v={};f.querySelectorAll('[data-fb]').forEach(i=>v[i.dataset.fb]=i.value);if(!v.film){toast('Kies een filmpje.','fout');return}const [k,r]=v.rooster.split('x').map(Number);const getal_=x=>parseFloat(String(x).replace(',','.'))||0;
  b.disabled=true;try{await api('/api/flipbook',{id:b.dataset.ond,film:v.film,start:getal_(v.start),eind:getal_(v.eind),kolommen:k,rijen:r,cel:+v.cel,zoom:getal_(v.zoom)||1});toast('flipbook gemaakt: een nieuwe kandidaat');await verversOnd(b.dataset.ond,true)}catch(e){toast(e.message,'fout')}b.disabled=false},
 inSpel:async b=>{if(!confirm('In het spel zetten? Wat er nu staat gaat naar een backup.'))return;await zetInSpel(b.dataset.ond,b.dataset.pad,'vervang','')},
 variant:async b=>{await zetInSpel(b.dataset.ond,b.dataset.pad,'variant','')},
 kiesBestand:b=>{const i=b.querySelector('input[type=file]');if(i)i.click()},
 importeer:async()=>{try{const s=await api('/api/import',{});D.import=s;importStatus();if(s.bezig)importPoll();else if(s.laatste)toast(s.laatste,'info')}catch(e){toast(e.message,'fout')}},
 wensOpen:b=>b.closest('.wensform').classList.toggle('open'),
 wens:async b=>{const f=b.closest('.wensform');const v={};f.querySelectorAll('[data-w]').forEach(i=>v[i.dataset.w]=i.value.trim());if(!v.naam){toast('Geef de wens een naam.','fout');return}
  try{const j=await api('/api/wens',Object.assign({groep:b.dataset.naam},v));toast('in de wishlist gezet: '+v.naam);await laad(true);const el=document.querySelector('.rij[data-id="'+j.id+'"]');if(el){el.scrollIntoView({block:'center'});el.classList.add('nieuw')}}catch(e){toast(e.message,'fout')}},
};
document.addEventListener('click',e=>{if(e.target.tagName==='INPUT'&&e.target.type==='file')return;const b=e.target.closest('[data-act]');if(!b||b.disabled)return;const f=ACT[b.dataset.act];if(f){e.preventDefault();f(b)}});
document.addEventListener('change',async e=>{const t=e.target;
 if(t.dataset.basis!==undefined){metBasis[t.dataset.basis]=t.checked;return}
 if(t.type==='file'&&t.closest('.drop')){const d=t.closest('.drop');const files=[...t.files];t.value='';if(files.length)await uploadBestanden(d.dataset.ond?('o_'+d.dataset.ond):d.dataset.id,files,d.dataset.ond||'',d.dataset.id||'');return}
 if(t.dataset.vrij){if(!t.value)return;const m=t.value;t.value='';try{await api('/api/vrijstaand',{id:t.dataset.vrij,pad:t.dataset.pad,methode:m});toast('achtergrond weg ('+m+'): een nieuwe kandidaat');await verversOnd(t.dataset.vrij,true)}catch(e){toast(e.message,'fout')}return}
 if(t.dataset.rooster){const [k,r]=t.value.split('x').map(Number);try{await api('/api/rooster',{id:t.dataset.rooster,stempel:t.dataset.stempel,kolommen:k,rijen:r});await verversOnd(t.dataset.rooster)}catch(e){toast(e.message,'fout')}return}
 if(t.dataset.vervang){if(!t.value)return;const doel=t.value;t.value='';if(!confirm('Variant '+doel+' vervangen? De oude gaat naar een backup.'))return;await zetInSpel(t.dataset.vervang,t.dataset.pad,'vervang',doel);return}
 if(t.dataset.fb)return;
 if(t.dataset.veld){const id=t.dataset.id;await bewaar(id,t.dataset.veld,t.type==='checkbox'?t.checked:t.value);const r=rij(id);if(r){if(t.dataset.veld==='goed'){r.goed=t.checked;await ververs(id)}else r[t.dataset.veld]=t.value}}
 else if(t.dataset.inst){try{const j=await api('/api/instellingen',{[t.dataset.inst]:t.type==='checkbox'?t.checked:t.value});D.instellingen=j.instellingen;toast('instelling bewaard','info')}catch(e){toast(e.message,'fout')}}});
document.getElementById('groot').onclick=()=>{document.getElementById('groot').style.display='none'};
document.addEventListener('dragover',e=>{e.preventDefault();const d=e.target.closest&&e.target.closest('.drop');if(d)d.classList.add('over')});
document.addEventListener('dragleave',e=>{const d=e.target.closest&&e.target.closest('.drop');if(d)d.classList.remove('over')});
document.addEventListener('drop',async e=>{e.preventDefault();const d=e.target.closest&&e.target.closest('.drop');if(!d)return;d.classList.remove('over');const files=[...((e.dataTransfer&&e.dataTransfer.files)||[])];if(files.length)await uploadBestanden(d.dataset.ond?('o_'+d.dataset.ond):d.dataset.id,files,d.dataset.ond||'',d.dataset.id||'')});
document.addEventListener('play',e=>{if(e.target.tagName!=='VIDEO')return;document.querySelectorAll('video').forEach(v=>{if(v!==e.target&&!v.paused)v.pause()})},true);
laad();
</script></body></html>
"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # stil
        pass

    def _json(self, obj, code=200):
        data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _bestand(self, p):
        try:
            pad = _veilig(p)
        except RuntimeError:
            self.send_error(404)
            return
        grootte = os.path.getsize(pad)
        begin, eind, code = 0, grootte - 1, 200
        m = re.match(r"bytes=(\d*)-(\d*)", self.headers.get("Range", "") or "")
        if m and (m.group(1) or m.group(2)):
            if m.group(1):
                begin = int(m.group(1))
                if m.group(2):
                    eind = min(int(m.group(2)), grootte - 1)
            else:
                begin = max(0, grootte - int(m.group(2)))
            code = 206
        if begin > eind:
            self.send_error(416)
            return
        with open(pad, "rb") as f:
            f.seek(begin)
            data = f.read(eind - begin + 1)
        self.send_response(code)
        self.send_header("Content-Type", MIME.get(os.path.splitext(pad)[1].lower(), "application/octet-stream"))
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Accept-Ranges", "bytes")
        if code == 206:
            self.send_header("Content-Range", "bytes %d-%d/%d" % (begin, eind, grootte))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try:
            self.wfile.write(data)
        except (ConnectionError, OSError):
            pass    # de browser brak een video-verzoek af

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(u.query)
        try:
            if u.path == "/ping":
                self._json({"pong": True, "studio": STUDIO_STEMPEL})
            elif u.path == "/":
                data = PAGINA.encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            elif u.path == "/api/overzicht":
                self._json(_volle_overzicht())
            elif u.path == "/api/rij":
                o = overzicht(_id_ok(q.get("id", [""])[0]))
                self._json(o["rijen"][0] if o["rijen"] else {"fout": "onbekend effect"})
            elif u.path == "/api/taken":
                self._json({"taken": lopend(), "nu": time.time()})
            elif u.path == "/api/spel_status":
                self._json(dict(_spel))
            elif u.path == "/api/onderdeel":
                self._json(onderdeel_rij(q.get("id", [""])[0]))
            elif u.path == "/api/import_status":
                self._json(dict(_import_status))
            elif u.path == "/bestand":
                self._bestand(q.get("p", [""])[0])
            else:
                self.send_error(404)
        except Exception as e:  # noqa: BLE001
            self._json({"fout": str(e)})

    def do_POST(self):
        n = int(self.headers.get("Content-Length", "0") or 0)
        u = urllib.parse.urlparse(self.path)
        if u.path == "/api/upload":
            try:
                if n > MAX_UPLOAD:
                    raise RuntimeError("te groot (hooguit %d MB)" % (MAX_UPLOAD // (1024 * 1024)))
                q = urllib.parse.parse_qs(u.query)
                data = self.rfile.read(n)
                self._json({"stempel": upload(q.get("id", [""])[0], q.get("naam", [""])[0], data)})
            except Exception as e:  # noqa: BLE001
                self._json({"fout": str(e)})
            return
        try:
            b = json.loads(self.rfile.read(n).decode("utf-8") or "{}")
        except ValueError:
            b = {}
        try:
            self._json(self._post(urllib.parse.urlparse(self.path).path, b))
        except Exception as e:  # noqa: BLE001
            self._json({"fout": str(e)})

    def _post(self, pad, b):
        if pad == "/api/sleutel":
            k = str(b.get("sleutel", "")).strip()
            if not k.startswith("r8_"):
                raise RuntimeError("Dit lijkt geen Replicate-sleutel: die begint met r8_ "
                                   "(replicate.com, Account, API tokens).")
            a = check_account(k)
            if a["fout"] and "(401)" in a["fout"]:
                raise RuntimeError(a["fout"])
            schrijf_sleutel(k)
            _schemas.clear()
            return {"naam": a["naam"], "melding": a["fout"]}
        if pad == "/api/instellingen":
            with _lock:
                st = lees_studio()
                inst = st["instellingen"]
                for k, v in b.items():
                    if k in ("beeldmodel", "filmmodel"):
                        v = str(v).strip()
                        if not re.fullmatch(r"[a-z0-9][a-z0-9._-]*/[a-z0-9._-]+(:[0-9a-f]{8,})?", v):
                            raise RuntimeError("Een model is eigenaar/naam, bv. google/nano-banana-2.")
                    elif k == "duur":
                        v = max(1, min(30, int(float(str(v).replace(",", ".")))))
                    elif k == "resolutie":
                        v = str(v)
                    elif k == "geluid":
                        v = bool(v)
                    elif k in ("filmzin", "basiszin"):
                        v = str(v)
                    else:
                        continue
                    inst[k] = v
                schrijf_studio(st)
            return {"instellingen": st["instellingen"]}
        if pad in ("/api/prompt", "/api/notitie", "/api/goed"):
            eid = _id_ok(b.get("id"))
            veld = {"/api/prompt": "prompts", "/api/notitie": "notities", "/api/goed": "goed"}[pad]
            with _lock:
                st = lees_studio()
                w = b.get("waarde")
                w = bool(w) if veld == "goed" else str(w or "").strip()
                if w:
                    st[veld][eid] = w
                else:
                    st[veld].pop(eid, None)
                schrijf_studio(st)
            return {"ok": True}
        if pad in ("/api/beeld", "/api/film") and not lees_sleutel():
            raise RuntimeError("Geen Replicate-sleutel: plak hem bovenaan (replicate.com, Account, API tokens).")
        if pad == "/api/beeld":
            eid = _id_ok(b.get("id"))
            prompt = str(b.get("prompt", "")).strip()
            if not prompt:
                raise RuntimeError("Geen prompt.")
            inst = lees_studio()["instellingen"]
            model = inst["beeldmodel"]
            bp = _veilig(b["basis"]) if b.get("basis") else ""
            volle = (inst["basiszin"] + prompt) if bp else prompt

            verhouding = "1:1" if eid.startswith(ONDERDEEL_VOOR) else "16:9"

            def maak():
                return beeld_invoer(model, volle, data_uri(bp) if bp else "", verhouding)
            return {"stempel": start_opdracht(eid, "beeld", model, prompt, volle, maak,
                                              {"basis": _rel(bp) if bp else ""})}
        if pad == "/api/film":
            eid = _id_ok(b.get("id"))
            prompt = str(b.get("prompt", "")).strip()
            if not prompt:
                raise RuntimeError("Geen prompt.")
            bron = _veilig(b.get("bron")) if b.get("bron") else ""
            if bron and os.path.splitext(bron)[1].lower() not in BEELD_EXT:
                raise RuntimeError("Een filmpje begint bij een plaatje.")
            inst = lees_studio()["instellingen"]
            model = inst["filmmodel"]
            volle = (prompt + " " + inst["filmzin"]).strip()
            verhouding = "1:1" if eid.startswith(ONDERDEEL_VOOR) else "16:9"

            def maak():
                return film_invoer(model, volle, data_uri(bron) if bron else "", inst, verhouding)
            return {"stempel": start_opdracht(eid, "film", model, prompt, volle, maak,
                                              {"bron": _rel(bron) if bron else "", "duur": inst["duur"],
                                               "resolutie": inst["resolutie"]})}
        if pad == "/api/stop":
            stop_opdracht(_id_ok(b.get("id")), str(b.get("stempel", "")))
            return {"ok": True}
        if pad == "/api/kies":
            return {"doel": kies(b.get("id"), b.get("pad"))}
        if pad == "/api/kies_af":
            kies_af(b.get("id"), str(b.get("soort", "")))
            return {"ok": True}
        if pad == "/api/weg":
            weg(b.get("id"), str(b.get("pad") or ""), str(b.get("stempel") or ""))
            return {"ok": True}
        if pad == "/api/spelbeelden":
            spelbeelden(str(b.get("id") or ""))
            return {"ok": True}
        if pad == "/api/flipbook":
            return {"stempel": maak_flipbook(str(b.get("id", "")), b.get("film"), b.get("start") or 0,
                                             b.get("eind") or 0, b.get("kolommen") or 4, b.get("rijen") or 4,
                                             b.get("cel") or 256, b.get("zoom") or 1)}
        if pad == "/api/vrijstaand":
            return {"stempel": vrijstaand(str(b.get("id", "")), b.get("pad"), str(b.get("methode", "")),
                                          b.get("sterkte") or 1.0)}
        if pad == "/api/rooster":
            zet_rooster(str(b.get("id", "")), str(b.get("stempel", "")), b.get("kolommen") or 1, b.get("rijen") or 1)
            return {"ok": True}
        if pad == "/api/in_spel":
            return in_spel(str(b.get("id", "")), b.get("pad"), str(b.get("modus") or "vervang"), str(b.get("doel") or ""))
        if pad == "/api/import":
            godot_import()
            return dict(_import_status)
        if pad == "/api/wens":
            return {"id": nieuwe_wens(b.get("groep"), b.get("naam"), b.get("wanneer"), b.get("notitie"),
                                      b.get("prompt"))}
        raise RuntimeError("onbekend pad %s" % pad)


def vrije_poort(start):
    """De eerste poort vanaf `start` waar niets op luistert (zie de geluid-studio:
    op Windows kan een tweede server naast een ander programma binden)."""
    for poort in range(start, start + 50):
        try:
            socket.create_connection(("127.0.0.1", poort), 0.25).close()
            continue
        except OSError:
            pass
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            if hasattr(socket, "SO_EXCLUSIVEADDRUSE"):
                s.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
            s.bind(("127.0.0.1", poort))
            return poort
        except OSError:
            continue
        finally:
            s.close()
    raise RuntimeError("geen vrije poort vanaf %d" % start)


def start_server(poort_vanaf):
    """Binden en bewijzen dat wij het zijn die antwoorden (de les van de
    geluid-studio, 18 september)."""
    for poging in range(50):
        poort = vrije_poort(poort_vanaf + poging)
        try:
            srv = ThreadingHTTPServer(("127.0.0.1", poort), Handler)
        except OSError:
            continue
        srv.daemon_threads = True
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        try:
            with urllib.request.urlopen("http://127.0.0.1:%d/ping" % poort, timeout=3) as r:
                ok = json.loads(r.read().decode("utf-8")).get("studio") == STUDIO_STEMPEL
        except Exception:  # noqa: BLE001
            ok = False
        if ok:
            return srv, poort
        srv.shutdown()
        srv.server_close()
    raise RuntimeError("geen werkende poort gevonden vanaf %d" % poort_vanaf)


# ------------------------------------------------------------------ proef

def _testfilm(pad, n=24, maat=128):
    """Een klein echt filmpje (OpenCV): een witte bol die groeit, op zwart."""
    import cv2
    vw = cv2.VideoWriter(pad, cv2.VideoWriter_fourcc(*"mp4v"), 24, (maat, maat))
    for i in range(n):
        f = np.zeros((maat, maat, 3), np.uint8)
        cv2.circle(f, (maat // 2, maat // 2), 4 + i * 2, (210, 210, 210), -1)
        vw.write(f)
    vw.release()


def proef():
    """De hele keten tegen een nep-Replicate op deze machine: sleutel, plaatje met
    en zonder basis, filmpje, dit is hem, weggooien, geen tegoed, stoppen,
    hervatten na een herstart, een nieuwe wens en de webserver. Kost niets en
    raakt de echte mappen en de echte wishlist niet."""
    import tempfile
    tmp = tempfile.mkdtemp(prefix="vfx_studio_proef_")
    P.update(ref=os.path.join(tmp, "referentie"), werk=os.path.join(tmp, "werk"),
             sleutel=os.path.join(tmp, "replicate.key"), wishlist=os.path.join(tmp, "VFX-WISHLIST.md"),
             texturen=os.path.join(tmp, "textures"), poll_beeld=0.05, poll_film=0.05)
    os.environ.pop("REPLICATE_API_TOKEN", None)
    shutil.copyfile("VFX-WISHLIST.md", P["wishlist"])
    shutil.copytree(os.path.join("assets", "textures"), P["texturen"])
    testfilm = os.path.join(tmp, "testfilm.mp4")
    _testfilm(testfilm)
    filmdata = open(testfilm, "rb").read()
    mappen()
    _schemas.clear()
    fouten = []

    def ok(v, wat):
        print("[PROEF] %s %s" % ("ok  " if v else "FOUT", wat))
        if not v:
            fouten.append(wat)

    def jpeg(kleur):
        b = io.BytesIO()
        Image.new("RGB", (96, 72), kleur).save(b, "JPEG")
        return b.getvalue()

    nep = {"pred": {}, "invoer": [], "bestanden": {}}

    class Nep(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def _j(self, obj, code=200):
            data = json.dumps(obj).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _auth(self):
            if self.headers.get("Authorization") != "Bearer r8_proef":
                self._j({"detail": "Invalid token"}, 401)
                return False
            return True

        def do_GET(self):
            m = re.match(r"^/out/(.+)$", self.path)
            if m:
                data = nep["bestanden"][m.group(1)]
                self.send_response(200)
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
                return
            if not self._auth():
                return
            if self.path == "/v1/account":
                return self._j({"type": "user", "username": "proef"})
            m = re.match(r"^/v1/models/([^/]+/[^/]+)$", self.path)
            if m:
                props = json.loads(json.dumps(BEKEND.get(m.group(1), {})))
                return self._j({"latest_version": {"openapi_schema": {"components": {"schemas": {
                    "Input": {"properties": props}}}}}})
            m = re.match(r"^/v1/predictions/(\w+)$", self.path)
            if m:
                p = nep["pred"][m.group(1)]
                p["polls"] += 1
                if p["gestopt"]:
                    return self._j({"id": m.group(1), "status": "canceled"})
                if p["polls"] >= p["klaar_na"]:
                    return self._j({"id": m.group(1), "status": "succeeded", "output": p["uit"],
                                    "metrics": {"predict_time": 1.5}})
                return self._j({"id": m.group(1), "status": "processing"})
            self._j({"detail": "Not found"}, 404)

        def do_POST(self):
            if not self._auth():
                return
            n = int(self.headers.get("Content-Length", "0") or 0)
            body = json.loads(self.rfile.read(n).decode("utf-8") or "{}")
            m = re.match(r"^/v1/models/([^/]+/[^/]+)/predictions$", self.path)
            if m:
                inv = body.get("input", {})
                nep["invoer"].append((m.group(1), inv))
                if "GEEN TEGOED" in inv.get("prompt", ""):
                    return self._j({"detail": "You have insufficient credit"}, 402)
                pid = "p%d" % len(nep["pred"])
                film = "seedance" in m.group(1)
                naam = pid + (".mp4" if film else ".jpg")
                nep["bestanden"][naam] = filmdata if film else jpeg((200, 90, 40))
                adres = "http://127.0.0.1:%d" % nep_poort
                nep["pred"][pid] = {"polls": 0, "gestopt": False, "klaar_na": 10 ** 9 if "TRAAG" in inv.get("prompt", "") else 2,
                                    "uit": (adres + "/out/" + naam) if film else [adres + "/out/" + naam]}
                return self._j({"id": pid, "status": "starting",
                                "urls": {"get": adres + "/v1/predictions/" + pid,
                                         "cancel": adres + "/v1/predictions/" + pid + "/cancel"}}, 201)
            m = re.match(r"^/v1/predictions/(\w+)/cancel$", self.path)
            if m:
                nep["pred"][m.group(1)]["gestopt"] = True
                return self._j({"id": m.group(1), "status": "canceled"})
            self._j({"detail": "Not found"}, 404)

    nep_poort = vrije_poort(18900)
    nep_srv = ThreadingHTTPServer(("127.0.0.1", nep_poort), Nep)
    threading.Thread(target=nep_srv.serve_forever, daemon=True).start()
    P["api"] = "http://127.0.0.1:%d/v1" % nep_poort
    srv, poort = start_server(18950)
    basis_url = "http://127.0.0.1:%d" % poort

    def post(pad, body):
        req = urllib.request.Request(basis_url + pad, data=json.dumps(body).encode("utf-8"),
                                     headers={"Content-Type": "application/json"}, method="POST")
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode("utf-8"))

    def get(pad, headers=None):
        req = urllib.request.Request(basis_url + pad, headers=headers or {})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.status, r.read()
        except urllib.error.HTTPError as e:
            return e.code, b""

    def wacht_klaar(seconden=10.0):
        eind = time.time() + seconden
        while time.time() < eind:
            if not lopend():
                return True
            time.sleep(0.05)
        return False

    def concept(eid, stempel):
        return next((m for m in concepten_van(eid) if m["stempel"] == stempel), {})

    try:
        # catalogus en wishlist
        o = overzicht()
        ids = {r["id"] for r in o["rijen"]}
        cat = catalogus()
        ok(o["bron"] == _n(CATALOGUS_GD) and all(e["id"] in ids for e in cat["effecten"]),
           "catalogus rechtstreeks uit de GDScript-bron: %d effecten, alle als rij" % len(cat["effecten"]))
        ok(all(r["in_wishlist"] for r in o["rijen"]), "elk effect heeft een rij in de wishlist")
        # sleutel
        ok("sleutel" in post("/api/beeld", {"id": "schot_musket", "prompt": "x", "basis": ""}).get("fout", "")
           and not lopend(), "zonder sleutel: meteen een melding, geen opdracht")
        ok("fout" in post("/api/sleutel", {"sleutel": "geen_sleutel"}), "een sleutel zonder r8_ wordt geweigerd")
        ok("401" in post("/api/sleutel", {"sleutel": "r8_fout"}).get("fout", "") and not lees_sleutel(),
           "een verkeerde sleutel wordt niet bewaard")
        ok(post("/api/sleutel", {"sleutel": "r8_proef"}).get("naam") == "proef" and lees_sleutel() == "r8_proef",
           "de goede sleutel wordt bewaard en het account gelezen")
        # spelbeelden (nep: Godot draait hier niet)
        sd = os.path.join(spel_dir(), "schot_musket")
        os.makedirs(sd, exist_ok=True)
        Image.new("RGB", (540, 520), (60, 50, 40)).save(os.path.join(sd, "rust.jpg"))
        for i in range(6):
            Image.new("RGB", (540, 520), (60 + 30 * i, 50, 40)).save(os.path.join(sd, "spel_%02d.jpg" % i))
        with io.open(os.path.join(sd, "info.json"), "w", encoding="utf-8") as f:
            json.dump({"stap": 0.1}, f)
        bouw_anim("schot_musket")
        r = overzicht("schot_musket")["rijen"][0]
        ok(bool(r["spel"].get("anim")) and len(r["spel"]["beelden"]) == 6 and bool(r["spel"]["rust"]),
           "spelbeelden: bewegend plaatje, rust en 6 beelden")
        r_spel_rust = r["spel"]["rust"]
        # plaatje zonder basis
        st1 = post("/api/beeld", {"id": "schot_musket", "prompt": "A musket firing", "basis": ""})["stempel"]
        ok(wacht_klaar(), "plaatje klaar")
        m1 = concept("schot_musket", st1)
        model, inv = nep["invoer"][-1]
        ok(m1.get("status") == "klaar" and len(m1.get("bestanden", [])) == 1 and os.path.exists(m1["bestanden"][0]),
           "plaatje staat in de conceptmap")
        ok(model == "google/nano-banana-2" and inv == {"prompt": "A musket firing", "aspect_ratio": "16:9",
                                                        "resolution": "1K", "output_format": "jpg"},
           "plaatje: invoer voor Nano Banana 2 zonder basis %s" % json.dumps(inv))
        # plaatje op het spelbeeld
        st2 = post("/api/beeld", {"id": "schot_musket", "prompt": "Thicker smoke", "basis": r["spel"]["rust"]})["stempel"]
        ok(wacht_klaar(), "plaatje op een basis klaar")
        model, inv = nep["invoer"][-1]
        ok(isinstance(inv.get("image_input"), list) and inv["image_input"][0].startswith("data:image/jpeg;base64,")
           and inv.get("aspect_ratio") == "match_input_image" and inv["prompt"].startswith(STANDAARD["basiszin"])
           and inv["prompt"].endswith("Thicker smoke"), "plaatje op het spelbeeld: basis als data-URI, basiszin ervoor")
        # filmpje van het eerste plaatje
        beeld1 = m1["bestanden"][0]
        st3 = post("/api/film", {"id": "schot_musket", "prompt": "The musket fires", "bron": beeld1})["stempel"]
        ok(wacht_klaar(), "filmpje klaar")
        m3 = concept("schot_musket", st3)
        model, inv = nep["invoer"][-1]
        ok(model == "bytedance/seedance-2.5" and inv.get("image", "").startswith("data:image/jpeg;base64,")
           and inv.get("aspect_ratio") == "adaptive" and inv.get("duration") == 5 and inv.get("resolution") == "480p"
           and inv.get("generate_audio") is False and inv.get("watermark") is False
           and inv.get("output_format") == "mp4" and inv["prompt"].endswith(STANDAARD["filmzin"]),
           "filmpje: Seedance 2.5 met het plaatje als eerste beeld, adaptive, 5 s, 480p, zonder geluid")
        ok(m3.get("status") == "klaar" and m3["bestanden"][0].endswith(".mp4"), "filmpje staat als mp4 in de conceptmap")
        # dit is hem
        post("/api/kies", {"id": "schot_musket", "pad": beeld1})
        post("/api/kies", {"id": "schot_musket", "pad": m3["bestanden"][0]})
        st = lees_studio()
        k = st["keuze"].get("schot_musket", {})
        ok(os.path.exists(os.path.join(P["ref"], "schot_musket", "beeld.jpg"))
           and os.path.exists(os.path.join(P["ref"], "schot_musket", "film.mp4"))
           and k.get("film_prompt", "").startswith("The musket fires") and k.get("beeld_prompt") == "A musket firing",
           "dit is hem: plaatje en filmpje in de referentiemap, met hun prompt in studio.json")
        post("/api/kies_af", {"id": "schot_musket", "soort": "film"})
        ok(not os.path.exists(os.path.join(P["ref"], "schot_musket", "film.mp4"))
           and "film" not in lees_studio()["keuze"].get("schot_musket", {}), "kies af haalt het filmpje weer weg")
        # weggooien
        m2 = concept("schot_musket", st2)
        post("/api/weg", {"id": "schot_musket", "pad": m2["bestanden"][0]})
        ok(not os.path.exists(m2["bestanden"][0]) and not concept("schot_musket", st2), "weg: bestand en meta weg")
        ok("fout" in post("/api/weg", {"id": "schot_musket", "pad": "../../VFX-WISHLIST.md"}),
           "weg buiten de conceptmap wordt geweigerd")
        # geen tegoed
        st4 = post("/api/beeld", {"id": "kruitdamp", "prompt": "GEEN TEGOED", "basis": ""})["stempel"]
        ok(wacht_klaar(), "opdracht zonder tegoed loopt af")
        ok("tegoed" in concept("kruitdamp", st4).get("fout", ""), "geen tegoed: mislukt met een Nederlandse uitleg")
        # stoppen
        st5 = post("/api/film", {"id": "kruitdamp", "prompt": "TRAAG", "bron": r["spel"]["rust"]})["stempel"]
        eind = time.time() + 5
        while time.time() < eind and concept("kruitdamp", st5).get("status") != "bezig":
            time.sleep(0.05)
        post("/api/stop", {"id": "kruitdamp", "stempel": st5})
        ok(wacht_klaar() and concept("kruitdamp", st5).get("fout") == "gestopt", "stop: Replicate annuleert, de kaart zegt gestopt")
        # hervatten na een herstart
        adres = "http://127.0.0.1:%d" % nep_poort
        req = urllib.request.Request(P["api"] + "/models/google/nano-banana-2/predictions", method="POST",
                                     data=json.dumps({"input": {"prompt": "na de herstart"}}).encode("utf-8"),
                                     headers={"Authorization": "Bearer r8_proef", "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            pr = json.loads(resp.read().decode("utf-8"))
        werk_meta("vuur_bord", "20261006_120000_9001", soort="beeld", status="bezig", model="google/nano-banana-2",
                  prompt="na de herstart", start=time.time(), pred_get=pr["urls"]["get"])
        werk_meta("vuur_bord", "20261006_120000_9002", soort="beeld", status="start", model="google/nano-banana-2",
                  prompt="nooit verstuurd", start=time.time())
        ok(hervat_opdrachten() == 1 and wacht_klaar(), "hervatten: de lopende opdracht wordt verder gepold")
        ok(concept("vuur_bord", "20261006_120000_9001").get("status") == "klaar"
           and "niets betaald" in concept("vuur_bord", "20261006_120000_9002").get("fout", ""),
           "hervatten: de lopende is klaar, de onverstuurde staat als mislukt (niets betaald)")
        ok(adres in pr["urls"]["get"], "nep-Replicate gaf zijn eigen adres")
        # notities, prompt, goed, instellingen
        post("/api/notitie", {"id": "schot_musket", "waarde": "de rook mag dikker"})
        post("/api/prompt", {"id": "schot_musket", "waarde": "A musket firing, thick smoke"})
        post("/api/goed", {"id": "kruitdamp", "waarde": True})
        st = lees_studio()
        ok(st["notities"].get("schot_musket") == "de rook mag dikker" and st["goed"].get("kruitdamp") is True
           and st["prompts"].get("schot_musket") == "A musket firing, thick smoke", "notitie, prompt en goed in studio.json")
        ok(post("/api/instellingen", {"resolutie": "720p", "duur": "8"})["instellingen"]["resolutie"] == "720p"
           and lees_studio()["instellingen"]["duur"] == 8, "instellingen bewaard")
        ok("fout" in post("/api/instellingen", {"beeldmodel": "geen model"}), "een rare modelnaam wordt geweigerd")
        # nieuwe wens
        j = post("/api/wens", {"groep": "Vuur en explosies", "naam": "Brandend huis", "wanneer": "in het diorama",
                               "notitie": "rook | en vlammen", "prompt": "A burning house"})
        tekst = io.open(P["wishlist"], encoding="utf-8").read()
        r = overzicht(j.get("id"))["rijen"]
        ok(j.get("id") == "wens_brandend_huis" and "| Brandend huis | in het diorama | wens | rook / en vlammen | A burning house |" in tekst
           and r and r[0]["alleen_wishlist"] and r[0]["groep"] == "vuur", "nieuwe wens: rij in de goede sectie, zichtbaar als wens")
        ok("fout" in post("/api/wens", {"groep": "Vuur en explosies", "naam": "brandend huis"}), "een wens die er al staat wordt geweigerd")
        # --- stap 8: texturen en decals
        od = onderdelen()
        rm = onderdeel_rij("rook_musket")
        ok(len(od) >= 13 and [f["naam"] for f in rm["spel"]] == ["musket_3x3.png"] and rm["spel"][0]["actief"]
           and rm["spel"][0]["rooster"] == [3, 3] and {"schot_musket", "kruitdamp"} <= {e["id"] for e in rm["effecten"]},
           "onderdelen: kruitdamp ziet musket_3x3.png (actief, 3x3) en zijn effecten")
        ok(len(onderdeel_rij("bloed_spetter")["spel"]) == 6, "onderdelen: zes bloedspetters als varianten")
        # een eigen plaatje (met doorzichtigheid) en een eigen filmpje erin
        b = io.BytesIO()
        spat = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        ImageDraw.Draw(spat).ellipse((16, 16, 48, 48), fill=(150, 10, 10, 230))
        spat.save(b, "PNG")

        def upl(eid, naam, data):
            req = urllib.request.Request(basis_url + "/api/upload?id=%s&naam=%s" % (eid, naam), data=data, method="POST")
            with urllib.request.urlopen(req, timeout=30) as r_:
                return json.loads(r_.read().decode("utf-8"))
        st_spat = upl("o_bloed_spetter", "spat_eigen.png", b.getvalue()).get("stempel", "")
        st_film = upl("o_rook_musket", "rook.mp4", filmdata).get("stempel", "")
        ok("fout" in upl("o_rook_musket", "iets.exe", b"x"), "upload: een ander soort bestand wordt geweigerd")
        mf = next((m for m in concepten_van("o_rook_musket") if m["stempel"] == st_film), {})
        ok(mf.get("soort") == "film" and mf.get("vellen") and os.path.exists(mf["vellen"][0]),
           "upload: een filmpje wordt een filmkandidaat, met een contactvel erbij")
        # flipbook uit het filmpje, dan de achtergrond weg
        stf = post("/api/flipbook", {"id": "rook_musket", "film": mf["bestanden"][0], "kolommen": 4, "rijen": 4,
                                     "cel": 64, "start": 0, "eind": 0})["stempel"]
        mfb = next((m for m in concepten_van("o_rook_musket") if m["stempel"] == stf), {})
        with Image.open(mfb["bestanden"][0]) as im:
            ok(im.size == (256, 256) and mfb.get("rooster") == [4, 4], "flipbook: 4x4 beeldjes van 64 px uit het filmpje")
        stv = post("/api/vrijstaand", {"id": "rook_musket", "pad": mfb["bestanden"][0], "methode": "zwart"})["stempel"]
        mv = next((m for m in concepten_van("o_rook_musket") if m["stempel"] == stv), {})
        with Image.open(mv["bestanden"][0]) as im:
            ok(im.mode == "RGBA" and im.getpixel((0, 0))[3] == 0 and im.getpixel((32, 32))[3] > 100 and mv.get("rooster") == [4, 4],
               "achtergrond weg (zwart): de hoek doorzichtig, het midden niet, het rooster gaat mee")
        # in het spel: de oude naar de backup, de nieuwe onder de naam die het spel zoekt
        j = post("/api/in_spel", {"id": "rook_musket", "pad": mv["bestanden"][0], "modus": "vervang"})
        rook = os.path.join(P["texturen"], "smoke")
        ok(j.get("doel", "").endswith("smoke/musket_4x4.png") and os.path.exists(os.path.join(rook, "musket_4x4.png"))
           and not os.path.exists(os.path.join(rook, "musket_3x3.png")) and not os.path.exists(os.path.join(rook, "musket_3x3.png.import"))
           and os.path.exists(os.path.join(rook, "white_smoke_3x3.png"))
           and glob.glob(os.path.join(P["werk"], "backup", "smoke", "*_musket_3x3.png")),
           "in het spel (flipbook): musket_4x4.png erin, musket_3x3 naar de backup, de witte pof blijft")
        ok([f["naam"] for f in onderdeel_rij("rook_musket")["spel"]] == ["musket_4x4.png"], "het onderdeel ziet zijn nieuwe vel")
        ok("doorzichtig" in post("/api/in_spel", {"id": "bloed_spetter", "pad": mfb["bestanden"][0].replace("o_rook_musket", "o_bloed_spetter"),
                                                   "modus": "variant"}).get("fout", "")
           or "fout" in post("/api/in_spel", {"id": "bloed_spetter", "pad": mfb["bestanden"][0], "modus": "variant"}),
           "in het spel: een plaatje van een ander onderdeel wordt geweigerd")
        stz = post("/api/vrijstaand", {"id": "bloed_spetter", "pad": next(m for m in concepten_van("o_bloed_spetter")
                                                                          if m["stempel"] == st_spat)["bestanden"][0],
                                       "methode": "wit"})["stempel"]
        b2 = io.BytesIO()
        Image.new("RGB", (32, 32), (200, 0, 0)).save(b2, "PNG")
        st_zonder = upl("o_bloed_spetter", "zonder_alpha.png", b2.getvalue())["stempel"]
        pz = next(m for m in concepten_van("o_bloed_spetter") if m["stempel"] == st_zonder)["bestanden"][0]
        ok("doorzichtig" in post("/api/in_spel", {"id": "bloed_spetter", "pad": pz, "modus": "variant"}).get("fout", ""),
           "in het spel: een bloedspetter zonder doorzichtigheid wordt geweigerd")
        ps = next(m for m in concepten_van("o_bloed_spetter") if m["stempel"] == st_spat)["bestanden"][0]
        j = post("/api/in_spel", {"id": "bloed_spetter", "pad": ps, "modus": "variant"})
        ok(j.get("doel", "").endswith("blood/splat7.png") and len(onderdeel_rij("bloed_spetter")["spel"]) == 7,
           "erbij als variant: splat7.png, nu zeven spetters")
        j = post("/api/in_spel", {"id": "bloed_spetter", "pad": ps, "modus": "vervang", "doel": "splat1.png"})
        ok(j.get("doel", "").endswith("blood/splat1.png") and len(onderdeel_rij("bloed_spetter")["spel"]) == 7
           and glob.glob(os.path.join(P["werk"], "backup", "blood", "*_splat1.png")), "vervang een variant: splat1.png, de oude in de backup")
        ok(bool(stz), "achtergrond weg (wit) maakt een kandidaat")
        # een onderdeel vraagt vierkant; een filmpje van een onderdeel mag zonder eerste beeld
        post("/api/beeld", {"id": "o_stof", "prompt": "A puff of dust", "basis": ""})
        ok(wacht_klaar() and nep["invoer"][-1][1].get("aspect_ratio") == "1:1", "plaatje voor een onderdeel: vierkant")
        post("/api/film", {"id": "o_stof", "prompt": "Dust puffs out", "bron": ""})
        ok(wacht_klaar() and nep["invoer"][-1][1].get("aspect_ratio") == "1:1" and "image" not in nep["invoer"][-1][1],
           "filmpje voor een onderdeel: vierkant, zonder eerste beeld")
        mst = next((m for m in concepten_van("o_stof") if m.get("soort") == "film"), {})
        ok(mst.get("status") == "klaar" and mst.get("vellen"), "een filmpje van Replicate krijgt een contactvel")
        # dit is hem voor een filmpje: het vel gaat mee naar de referentie
        stc = post("/api/film", {"id": "kruitdamp", "prompt": "Smoke rolls", "bron": r_spel_rust})["stempel"]
        ok(wacht_klaar(), "filmpje voor een effect klaar")
        filmpad = concept("kruitdamp", stc)["bestanden"][0]
        post("/api/kies", {"id": "kruitdamp", "pad": filmpad})
        ok(os.path.exists(os.path.join(P["ref"], "kruitdamp", "film_vel.jpg"))
           and keuze_van("kruitdamp", lees_studio()).get("film_vel"), "dit is hem (filmpje): het contactvel staat in de referentie")
        code, data = get("/api/onderdeel?id=rook_musket")
        ok(code == 200 and json.loads(data.decode("utf-8"))["spel"][0]["naam"] == "musket_4x4.png", "onderdeel via http")
        code, _ = get("/bestand?p=" + urllib.parse.quote(os.path.join(rook, "musket_4x4.png")))
        ok(code == 200, "texturen uit het spel worden geserveerd (voor de voorbeelden)")
        # webserver
        code, data = get("/")
        ok(code == 200 and b"VFX-studio" in data, "de pagina laadt")
        code, data = get("/api/overzicht")
        d = json.loads(data.decode("utf-8"))
        ok(code == 200 and len(d["rijen"]) == len(o["rijen"]) + 1 and d["account"]["naam"] == "proef", "overzicht via http")
        film = concept("schot_musket", st3)["bestanden"][0]
        code, data = get("/bestand?p=" + urllib.parse.quote(film), {"Range": "bytes=0-9"})
        ok(code == 206 and len(data) == 10, "video in stukjes (Range), zodat de browser kan spoelen")
        code, _ = get("/bestand?p=" + urllib.parse.quote(os.path.abspath("VFX-WISHLIST.md")))
        ok(code == 404, "bestanden buiten de studio worden niet geserveerd")
    except Exception as e:  # noqa: BLE001
        import traceback
        traceback.print_exc()
        fouten.append("uitzondering: %s" % e)
    srv.shutdown()
    nep_srv.shutdown()
    shutil.rmtree(tmp, ignore_errors=True)
    print("[PROEF] %s (%d fouten)" % ("PASS" if not fouten else "FAIL", len(fouten)))
    return 0 if not fouten else 1


# ------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(description="VFX-studio: concept-plaatjes en filmpjes per effect")
    ap.add_argument("--poort", type=int, default=8775)
    ap.add_argument("--geen-browser", action="store_true")
    ap.add_argument("--overzicht", action="store_true", help="alleen de telling als json (check, geen netwerk)")
    ap.add_argument("--proef", action="store_true", help="de hele keten tegen een nep-Replicate (kost niets)")
    a = ap.parse_args()
    if a.proef:
        sys.exit(proef())
    mappen()
    if a.overzicht:
        print(json.dumps(samenvatting(overzicht()), indent=1, ensure_ascii=False))
        return
    n = hervat_opdrachten()
    if n:
        print("%d opdracht(en) van de vorige keer worden verder opgehaald" % n)
    if lees_sleutel():
        threading.Thread(target=check_account, daemon=True).start()
    srv, poort = start_server(a.poort)
    url = "http://127.0.0.1:%d/" % poort
    print("VFX-studio op %s  (Ctrl+C stopt)" % url)
    if not a.geen_browser:
        webbrowser.open(url)
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        srv.shutdown()


if __name__ == "__main__":
    main()
