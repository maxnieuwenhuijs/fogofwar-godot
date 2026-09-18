# -*- coding: utf-8 -*-
"""Geluid-studio: alle geluidsprompts in EEN overzicht, ElevenLabs maakt ze,
jij luistert en drukt op Gebruiken (18 september, Max: "kunnen we alle prompts
voor geluiden niet zo maken dat we met een ElevenLabs-api-call die krijgen, en
als ik op gebruiken druk dat we die opslaan; prompts aanpassen, retry, de
ElevenLabs-instelling aanpassen; een groot makkelijk overzicht met .wav etc").

    python tools/geluid_studio.py [--poort 8765] [--geen-browser]

Een lokale webpagina (alleen op deze machine, http://127.0.0.1:8765):

* Elke categorie die het spel kent staat erin, gegroepeerd: factie-kreten
  (uit de geluid-tracker, met de archetype-varianten van de muis), de
  diorama-props, de wapens (zwaai en klap) en het algemene arsenaal uit
  SOUND-WISHLIST.md. Per categorie: wat er ligt (echt / synthetisch / leeg,
  met een speler per bestand), de prompt, en de ElevenLabs-knoppen.
* Prompt en instellingen (duur, prompt-invloed, model) bewaart hij per
  categorie in `sounds/geluid_studio.json` (gaat mee in git). Leeg = de
  prompt uit de wishlist/tracker.
* "Genereer" roept `POST /v1/sound-generation` aan (output pcm_44100) en
  knipt de clip op stiltes in losse takes: de prompts uit de wishlist vragen
  om "6 short ... in a row, silence between each", dus je krijgt zes losse
  kandidaten. Takes staan in `results/geluid_studio/<categorie>/` (niet in
  git) tot je kiest.
* "Gebruiken" zet een take als `sounds/<map>/<categorie>[_N].wav` (de
  volgende vrije variant; factie-kreten in `sounds/factions/<factie>/`, props
  in `sounds/props/`, wapens in `sounds/melee/`, de rest in `sounds/studio/`).
  "Vervang synthetisch" overschrijft de eerste synthetische placeholder van
  die categorie (een echte opname op dezelfde naam wint, zie
  `synthetisch.json`). Daarna "Importeer in Godot" (kan niet zolang de
  editor open staat) of gewoon het project openen.
* De API-sleutel komt uit `ELEVENLABS_API_KEY` of uit het veld bovenaan; die
  wordt bewaard in `%LOCALAPPDATA%\\FogOfWar\\elevenlabs.key`, nooit in de
  repo.

Zonder ffmpeg op deze machine: als je abonnement geen pcm-uitvoer geeft,
valt hij terug op mp3 en bewaart die als .mp3 naast de takes (Godot speelt
mp3, maar de auto-vondst van het spel zoekt .wav); dat meldt hij.
"""
import argparse
import glob
import hashlib
import io
import json
import os
import re
import socket
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import wave
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import numpy as np

WORTEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(WORTEL)
sys.path.insert(0, os.path.join(WORTEL, "tools"))
import bouw_geluid_tracker as tracker  # noqa: E402

STUDIO_JSON = os.path.join("sounds", "geluid_studio.json")
TAKES_DIR = os.path.join("results", "geluid_studio")
SLEUTEL_PAD = os.path.join(os.environ.get("LOCALAPPDATA", WORTEL), "FogOfWar", "elevenlabs.key")
GODOT_STANDAARD = r"C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
API_URL = "https://api.elevenlabs.io/v1/sound-generation"
FACTIES = ["mouse", "pig", "lion", "bear", "wolf", "crocodile"]
FACTIE_NL = {"mouse": "Muis", "pig": "Varken", "lion": "Leeuw", "bear": "Beer", "wolf": "Wolf", "crocodile": "Krokodil"}
MODELLEN = ["eleven_text_to_sound_v2"]

_lock = threading.Lock()
_import_status = {"bezig": False, "laatste": "", "uitvoer": ""}


# ------------------------------------------------------------------ opslag

def lees_studio():
    try:
        return json.load(io.open(STUDIO_JSON, encoding="utf-8"))
    except (OSError, ValueError):
        return {"prompts": {}, "instellingen": {}, "standaard": {"duur": 0.0, "invloed": 0.3, "model": MODELLEN[0]}}


def schrijf_studio(d):
    os.makedirs(os.path.dirname(STUDIO_JSON), exist_ok=True)
    with io.open(STUDIO_JSON, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, indent=1, sort_keys=True, ensure_ascii=False)


def lees_sleutel():
    k = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if k:
        return k
    try:
        return io.open(SLEUTEL_PAD, encoding="utf-8").read().strip()
    except OSError:
        return ""


def schrijf_sleutel(k):
    os.makedirs(os.path.dirname(SLEUTEL_PAD), exist_ok=True)
    io.open(SLEUTEL_PAD, "w", encoding="utf-8").write(k.strip())


# ------------------------------------------------------------------ overzicht

def wishlist_rijen():
    """Elke tabelrij met een `categorie` vooraan: categorie -> {cellen}."""
    uit = {}
    if not os.path.exists("SOUND-WISHLIST.md"):
        return uit
    for regel in io.open("SOUND-WISHLIST.md", encoding="utf-8"):
        if not regel.startswith("|"):
            continue
        cellen = [c.strip() for c in regel.strip().strip("|").split("|")]
        m = re.match(r"^`([a-z0-9_]+)`", cellen[0])
        if not m or len(cellen) < 2:
            continue
        cat = m.group(1)
        prompt = ""
        for c in reversed(cellen[1:]):
            # de prompt is de lange Engelse cel; "✓ ..." en cijfers niet
            if len(c) > 40 and not c.startswith("✓") and re.search(r"[a-z]{4,} [a-z]{3,}", c):
                prompt = c
                break
        gewenst = 0
        for c in cellen[1:4]:
            nums = re.findall(r"\d+", c)
            if nums and len(c) <= 6:
                gewenst = max(int(x) for x in nums)
                break
        r = uit.setdefault(cat, {"waarvoor": "", "prompt": "", "gewenst": 0})
        if not r["prompt"] and prompt:
            r["prompt"] = prompt
        if not r["gewenst"] and gewenst:
            r["gewenst"] = gewenst
        if not r["waarvoor"]:
            for c in cellen[1:]:
                if c and c != prompt and not re.fullmatch(r"[\d\-–, ]+", c) and not c.startswith("`") and len(c) < 90:
                    r["waarvoor"] = c
                    break
    return uit


# Oude namen in de wishlist die nog niet zijn hernoemd (18 september: geen
# paarden meer): de prompt van de oude naam geldt als terugval voor de nieuwe.
LEGACY = {"cav_die": "horse_die", "cav_move": "horse_move", "cav_select": "horse_select",
          "retaliation_cav": "retaliation_horse"}


def prompt_terugval(cat, wl):
    """Geen eigen prompt? Dan die van de factie (zonder archetype), dan van
    de basis-categorie, dan van de oude naam. Zo heeft een leeg
    `inf_die_bear_hp` toch een startpunt: de beer-kreet."""
    kandidaat = cat
    gezien = []
    while kandidaat:
        gezien.append(kandidaat)
        p = wl.get(kandidaat, {}).get("prompt", "")
        if p:
            return p
        for nieuw_, oud_ in LEGACY.items():
            if kandidaat.startswith(nieuw_):
                p = wl.get(oud_ + kandidaat[len(nieuw_):], {}).get("prompt", "")
                if p:
                    return p
        if "_" not in kandidaat:
            break
        kandidaat = kandidaat.rsplit("_", 1)[0]
    # geen factie-prompt maar wel een per model: neem die van het basismodel
    return wl.get(cat + "_base", {}).get("prompt", "")


_bank_cache = None


def bank():
    """Bestandsnaam -> categorie uit de BANK van audio_manager.gd (de oude
    namen: mellee_hit.wav hoort bij melee_kill, musket2.wav bij musket_fire)."""
    global _bank_cache
    if _bank_cache is not None:
        return _bank_cache
    uit = {}
    try:
        tekst = io.open(os.path.join("scripts", "core", "audio_manager.gd"), encoding="utf-8").read()
        blok = tekst.split("const BANK", 1)[1].split("\n}", 1)[0]
        for m in re.finditer(r'"([a-z0-9_]+)":\s*\[([^\]]*)\]', blok):
            for f in re.findall(r'"([^"]+\.wav)"', m.group(2)):
                uit[f] = m.group(1)
    except (OSError, IndexError):
        pass
    _bank_cache = uit
    return uit


def bestanden_van(cat, synth):
    """Alle geluidsbestanden van deze categorie (naam == cat of cat_N, of via
    de BANK)."""
    echt, kunst = [], []
    b = bank()
    for pad in sorted(glob.glob("sounds/**/*.wav", recursive=True)):
        naam = os.path.basename(pad)
        kaal = os.path.splitext(naam)[0]
        delen = kaal.rsplit("_", 1)
        if len(delen) == 2 and delen[1].isdigit():
            kaal = delen[0]
        if kaal != cat and b.get(naam) != cat:
            continue
        h = hashlib.sha1(open(pad, "rb").read()).hexdigest()
        (kunst if synth.get(naam) == h else echt).append(pad.replace("\\", "/"))
    return echt, kunst


def takes_van(cat):
    map_ = os.path.join(TAKES_DIR, cat)
    uit = []
    if not os.path.isdir(map_):
        return uit
    for mp in sorted(glob.glob(os.path.join(map_, "*.json")), reverse=True):
        try:
            meta = json.load(io.open(mp, encoding="utf-8"))
        except (OSError, ValueError):
            continue
        takes = [t for t in meta.get("takes", []) if os.path.exists(t)]
        if takes:
            meta["takes"] = [t.replace("\\", "/") for t in takes]
            meta["meta"] = mp.replace("\\", "/")
            uit.append(meta)
    return uit


def doelmap(cat):
    if cat.startswith(("prop_", "bewoner_")):
        return os.path.join("sounds", "props")
    if cat.startswith(("slash_", "melee_kill_", "melee_survive_")):
        return os.path.join("sounds", "melee")
    for f in FACTIES:
        if cat.endswith("_" + f) or ("_%s_" % f) in cat:
            return os.path.join("sounds", "factions", f)
    return os.path.join("sounds", "studio")


def overzicht():
    studio = lees_studio()
    synth = tracker.synthetische_hashes()
    wl = wishlist_rijen()
    rijen = []
    gezien = set()

    def voeg(sectie, cat, waarvoor, uitleg, prompt, gewenst):
        if cat in gezien:
            return
        gezien.add(cat)
        echt, kunst = bestanden_van(cat, synth)
        inst = studio.get("instellingen", {}).get(cat, {})
        geerfd = False
        if not prompt:
            prompt = prompt_terugval(cat, wl)
            geerfd = bool(prompt)
        rijen.append({
            "sectie": sectie, "categorie": cat, "waarvoor": waarvoor, "uitleg": uitleg,
            "prompt_bron": prompt, "prompt_geerfd": geerfd, "prompt": studio.get("prompts", {}).get(cat, ""),
            "gewenst": gewenst or 3, "echt": echt, "synth": kunst,
            "duur": inst.get("duur"), "invloed": inst.get("invloed"), "model": inst.get("model"),
            "takes": takes_van(cat), "doelmap": doelmap(cat).replace("\\", "/"),
        })

    facties, _, _ = tracker.bouw()
    for f in facties:
        sectie = "Factie: " + f["naam"]
        for r in f["rijen"]:
            w = wl.get(r["categorie"], {})
            voeg(sectie, r["categorie"], r["label"], r["uitleg"], r["prompt"] or w.get("prompt", ""),
                 w.get("gewenst", 0) or 3)
            for a in r["archetypes"]:
                voeg(sectie, a["bestand"], "%s, model %s" % (r["label"], a["naam"]), "",
                     a["prompt"] or wl.get(a["bestand"], {}).get("prompt", ""), 2)
    for soort, sectie in (("props", "Diorama-props"), ("wapens", "Wapens: zwaai en klap")):
        for r in tracker.bouw_props(soort):
            voeg(sectie, r["categorie"], r["waarvoor"], r["hoe"], r["prompt"], r["gewenst"])
    for cat, w in wl.items():
        voeg("Algemeen (arsenaal)", cat, w["waarvoor"], "", w["prompt"], w["gewenst"])
    # categorieen die wel bestanden hebben maar nergens beschreven staan
    bank_cats = {}
    for f, c in bank().items():
        kaal = os.path.splitext(f)[0]
        d = kaal.rsplit("_", 1)
        bank_cats[d[0] if len(d) == 2 and d[1].isdigit() else kaal] = c
    for cat in sorted(tracker.gevonden_categorieen()):
        # oude namen zonder underscore (step1, ui_click2) horen bij hun basis,
        # en wat in de BANK staat (mellee_hit, musket2) ook
        m = re.match(r"^(.*?)(\d+)$", cat)
        if (m and m.group(1) in gezien) or cat in bank_cats or (m and m.group(1) in bank_cats):
            if cat in bank_cats and bank_cats[cat] not in gezien:
                voeg("Overig (uit de BANK)", bank_cats[cat], "", "", "", 0)
            continue
        voeg("Overig (ligt er, geen prompt)", cat, "", "", "", 0)
    return {"rijen": rijen, "standaard": studio.get("standaard", {}), "sleutel": bool(lees_sleutel()),
            "import": _import_status}


# ------------------------------------------------------------------ ElevenLabs

def elevenlabs(prompt, duur, invloed, model, formaat="pcm_44100"):
    sleutel = lees_sleutel()
    if not sleutel:
        raise RuntimeError("Geen API-sleutel: vul hem bovenaan in (of zet ELEVENLABS_API_KEY).")
    body = {"text": prompt, "prompt_influence": float(invloed)}
    if model:
        body["model_id"] = model
    if duur and float(duur) > 0:
        body["duration_seconds"] = max(0.5, min(30.0, float(duur)))
    req = urllib.request.Request(API_URL + "?" + urllib.parse.urlencode({"output_format": formaat}),
                                 data=json.dumps(body).encode("utf-8"), method="POST",
                                 headers={"xi-api-key": sleutel, "Content-Type": "application/json",
                                          "Accept": "*/*"})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return r.read(), formaat
    except urllib.error.HTTPError as e:
        tekst = e.read().decode("utf-8", "replace")[:600]
        if formaat.startswith("pcm") and e.code in (400, 402, 403, 422):
            # pcm niet in dit abonnement of niet toegestaan: mp3 dan
            return elevenlabs(prompt, duur, invloed, model, "mp3_44100_128")
        raise RuntimeError("ElevenLabs %d: %s" % (e.code, tekst))


def knip_op_stilte(x, sr):
    """Losse takes uit een clip met stiltes ertussen. Geeft [(begin, eind)]."""
    if len(x) < sr // 4:
        return [(0, len(x))]
    venster = max(1, sr // 100)                      # 10 ms
    n = len(x) // venster
    rms = np.sqrt(np.mean(x[:n * venster].reshape(n, venster) ** 2, axis=1))
    piek = float(rms.max()) or 1.0
    aan = rms > max(piek * 0.05, 0.004)
    segs = []
    i = 0
    while i < n:
        if aan[i]:
            j = i
            while j < n and aan[j]:
                j += 1
            segs.append([i, j])
            i = j
        else:
            i += 1
    # korte gaten dichten (< 150 ms), daarna te korte stukjes weg (< 60 ms)
    samen = []
    for s in segs:
        if samen and s[0] - samen[-1][1] < 15:
            samen[-1][1] = s[1]
        else:
            samen.append(s)
    samen = [s for s in samen if s[1] - s[0] >= 6]
    if len(samen) <= 1:
        return [(0, len(x))]
    uit = []
    for a, b in samen:
        a = max(0, (a - 3) * venster)
        b = min(len(x), (b + 5) * venster)
        uit.append((a, b))
    return uit


def schrijf_wav(pad, x, sr):
    x = np.clip(x, -1.0, 1.0)
    n = min(len(x), int(sr * 0.005))
    if n > 0:
        x[:n] *= np.linspace(0.0, 1.0, n)
        x[-n:] *= np.linspace(1.0, 0.0, n)
    with wave.open(pad, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def genereer(cat, prompt, duur, invloed, model, knippen=True):
    data, formaat = elevenlabs(prompt, duur, invloed, model)
    map_ = os.path.join(TAKES_DIR, cat)
    os.makedirs(map_, exist_ok=True)
    stempel = time.strftime("%Y%m%d_%H%M%S")
    meta = {"categorie": cat, "prompt": prompt, "duur": duur, "invloed": invloed, "model": model,
            "tijd": stempel, "formaat": formaat, "takes": [], "melding": ""}
    if formaat.startswith("pcm"):
        sr = int(formaat.split("_")[1])
        x = np.frombuffer(data, dtype="<i2").astype(np.float32) / 32768.0
        stukken = knip_op_stilte(x, sr) if knippen else [(0, len(x))]
        for i, (a, b) in enumerate(stukken):
            pad = os.path.join(map_, "%s_%d.wav" % (stempel, i + 1))
            schrijf_wav(pad, x[a:b].copy(), sr)
            meta["takes"].append(pad.replace("\\", "/"))
        meta["seconden"] = round(len(x) / sr, 2)
    else:
        pad = os.path.join(map_, "%s_1.mp3" % stempel)
        open(pad, "wb").write(data)
        meta["takes"].append(pad.replace("\\", "/"))
        meta["melding"] = ("pcm-uitvoer geweigerd door ElevenLabs (abonnement?); als mp3 bewaard. "
                           "Zonder ffmpeg kan ik hem niet naar .wav zetten, en het spel zoekt .wav.")
    with io.open(os.path.join(map_, stempel + ".json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1, ensure_ascii=False)
    return meta


def gebruik(cat, take, vervang_synth=False):
    """Een take als echte opname in sounds/ zetten. Geeft het doelpad."""
    take = os.path.normpath(take)
    if not take.startswith(os.path.normpath(TAKES_DIR)) or not os.path.exists(take):
        raise RuntimeError("Onbekende take: %s" % take)
    if not take.lower().endswith(".wav"):
        raise RuntimeError("Alleen .wav kan het spel in (dit is een mp3; zie de melding bij de take).")
    synth = tracker.synthetische_hashes()
    echt, kunst = bestanden_van(cat, synth)
    if vervang_synth and kunst:
        doel = kunst[0]
    else:
        map_ = doelmap(cat)
        os.makedirs(map_, exist_ok=True)
        bestaand = {os.path.basename(p) for p in echt + kunst}
        doel = os.path.join(map_, cat + ".wav")
        n = 2
        while os.path.basename(doel) in bestaand or os.path.exists(doel):
            doel = os.path.join(map_, "%s_%d.wav" % (cat, n))
            n += 1
    data = open(take, "rb").read()
    open(doel, "wb").write(data)
    return doel.replace("\\", "/")


def verwijder_take(take):
    take = os.path.normpath(take)
    if take.startswith(os.path.normpath(TAKES_DIR)) and os.path.exists(take):
        os.remove(take)


def godot_import():
    if _import_status["bezig"]:
        return
    godot = os.environ.get("GODOT_PATH") or GODOT_STANDAARD
    if not os.path.exists(godot):
        _import_status["laatste"] = "Godot niet gevonden: zet GODOT_PATH."
        return

    def run():
        import subprocess
        _import_status["bezig"] = True
        _import_status["laatste"] = "bezig..."
        try:
            p = subprocess.run([godot, "--headless", "--path", ".", "--import"], capture_output=True,
                               text=True, timeout=900, errors="replace")
            uit = (p.stdout or "") + (p.stderr or "")
            fouten = [r for r in uit.splitlines() if "ERROR" in r or "error" in r.lower()][:8]
            _import_status["uitvoer"] = "\n".join(fouten)
            _import_status["laatste"] = ("klaar (%s)" % time.strftime("%H:%M:%S")) if p.returncode == 0 \
                else "mislukt (exit %d; staat de editor nog open?)" % p.returncode
        except Exception as e:  # noqa: BLE001
            _import_status["laatste"] = "mislukt: %s" % e
        _import_status["bezig"] = False

    threading.Thread(target=run, daemon=True).start()


# ------------------------------------------------------------------ http

PAGINA = r"""<!DOCTYPE html>
<html lang="nl"><head><meta charset="utf-8"><title>Geluid-studio</title>
<style>
:root{--bg:#1d1a16;--kaart:#2a2620;--rand:#4a4237;--tekst:#eee6d8;--dof:#a89c88;--accent:#e0a53d;--ok:#6dbb6d;--nee:#d9645a;--syn:#c9a25a}
body{margin:0;background:var(--bg);color:var(--tekst);font:14px/1.4 "Segoe UI",sans-serif}
header{position:sticky;top:0;background:#141210;border-bottom:1px solid var(--rand);padding:8px 16px;display:flex;gap:12px;align-items:center;flex-wrap:wrap;z-index:5}
header h1{font-size:17px;margin:0 12px 0 0;color:var(--accent)}
input,textarea,select,button{font:inherit;background:#171410;color:var(--tekst);border:1px solid var(--rand);border-radius:4px;padding:4px 6px}
button{cursor:pointer;background:#3a3225}button:hover{background:#4a4030}button.prim{background:var(--accent);color:#1d1a16;font-weight:600}
button:disabled{opacity:.5;cursor:default}
main{padding:10px 16px 60px}
h2{font-size:15px;margin:22px 0 6px;color:var(--accent);border-bottom:1px solid var(--rand);padding-bottom:3px}
.rij{background:var(--kaart);border:1px solid var(--rand);border-radius:6px;padding:8px 10px;margin:6px 0;display:grid;grid-template-columns:270px 1fr;gap:8px 14px}
.rij.verberg{display:none}
.cat{font-family:Consolas,monospace;font-size:13px;color:#fff}
.klein{color:var(--dof);font-size:12px}
.badge{display:inline-block;padding:0 6px;border-radius:9px;font-size:11px;margin-right:4px}
.b-ok{background:var(--ok);color:#111}.b-syn{background:var(--syn);color:#111}.b-nee{background:var(--nee);color:#111}
audio{height:26px;vertical-align:middle;max-width:220px}
.bestand{display:flex;gap:6px;align-items:center;font-size:12px;margin:2px 0;flex-wrap:wrap}
textarea{width:100%;min-height:52px;resize:vertical;box-sizing:border-box}
.inst{display:flex;gap:8px;align-items:center;margin-top:4px;flex-wrap:wrap}
.inst input{width:60px}
.takes{margin-top:6px;border-top:1px dashed var(--rand);padding-top:4px}
.take{display:flex;gap:6px;align-items:center;margin:3px 0;flex-wrap:wrap;font-size:12px}
.melding{color:var(--nee);font-size:12px}
.tel{color:var(--dof);font-size:12px;margin-left:auto}
#status{font-size:12px;color:var(--dof)}
</style></head><body>
<header>
<h1>Geluid-studio</h1>
<input id="zoek" placeholder="zoek (categorie, tekst)..." style="width:220px">
<select id="filter"><option value="">alles</option><option value="leeg">leeg</option><option value="synth">synthetisch</option><option value="echt">echt</option><option value="takes">met takes</option></select>
<label class="klein">sleutel <input id="sleutel" type="password" placeholder="ElevenLabs API-sleutel" style="width:190px"><button onclick="bewaarSleutel()">bewaar</button></label>
<label class="klein">standaard duur <input id="s_duur" style="width:50px" title="0 = ElevenLabs kiest"></label>
<label class="klein">invloed <input id="s_invloed" style="width:50px"></label>
<button onclick="bewaarStandaard()">bewaar</button>
<button onclick="importeer()" id="btnImport">Importeer in Godot</button>
<span id="status"></span>
<span class="tel" id="tel"></span>
</header>
<main id="main"></main>
<script>
let D=null;
async function api(p,b){const r=await fetch(p,b?{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(b)}:{});const j=await r.json();if(j.fout)throw new Error(j.fout);return j}
function esc(s){return (s||'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]))}
function speler(p){return '<audio controls preload="none" src="/audio?p='+encodeURIComponent(p)+'"></audio>'}
function naam(p){return p.split('/').pop()}
async function laad(){D=await api('/api/overzicht');teken();document.getElementById('sleutel').placeholder=D.sleutel?'sleutel staat (verborgen)':'ElevenLabs API-sleutel';document.getElementById('s_duur').value=D.standaard.duur??0;document.getElementById('s_invloed').value=D.standaard.invloed??0.3;status()}
function status(){const s=D.import;document.getElementById('status').textContent=s.laatste?('import: '+s.laatste):'';document.getElementById('btnImport').disabled=!!s.bezig;if(s.bezig)setTimeout(async()=>{D.import=(await api('/api/import_status'));status()},3000)}
function teken(){
 const m=document.getElementById('main');let h='';let sec='';let leeg=0,syn=0,echt=0;
 for(const r of D.rijen){
  if(r.sectie!==sec){sec=r.sectie;h+='<h2>'+esc(sec)+'</h2>'}
  const st=r.echt.length?'echt':(r.synth.length?'synth':'leeg');if(st==='echt')echt++;else if(st==='synth')syn++;else leeg++;
  let badges=r.echt.length?'<span class="badge b-ok">'+r.echt.length+' echt</span>':'';
  if(r.synth.length)badges+='<span class="badge b-syn">'+r.synth.length+' synthetisch</span>';
  if(!r.echt.length&&!r.synth.length)badges+='<span class="badge b-nee">leeg</span>';
  badges+='<span class="klein">gewenst '+r.gewenst+'</span>';
  let best='';for(const p of r.echt)best+='<div class="bestand">'+speler(p)+'<span>'+esc(naam(p))+'</span></div>';
  for(const p of r.synth)best+='<div class="bestand">'+speler(p)+'<span class="klein">'+esc(naam(p))+' (synthetisch)</span></div>';
  let takes='';for(const g of r.takes){takes+='<div class="klein">'+esc(g.tijd)+' &middot; invloed '+g.invloed+(g.duur?' &middot; '+g.duur+' s':'')+(g.seconden?' &middot; clip '+g.seconden+' s':'')+' &middot; '+esc((g.prompt||'').slice(0,90))+(g.melding?' <span class="melding">'+esc(g.melding)+'</span>':'')+'</div>';
   g.takes.forEach((t,i)=>{takes+='<div class="take">'+speler(t)+'<span>take '+(i+1)+'</span><button class="prim" onclick="gebruik(\''+esc(r.categorie)+'\',\''+esc(t)+'\',false)">Gebruiken</button>'+(r.synth.length?'<button onclick="gebruik(\''+esc(r.categorie)+'\',\''+esc(t)+'\',true)">Vervang synthetisch</button>':'')+'<button onclick="weg(\''+esc(t)+'\')">weg</button></div>'})}
  h+='<div class="rij" data-cat="'+esc(r.categorie)+'" data-st="'+st+'" data-takes="'+(r.takes.length?1:0)+'" data-zoek="'+esc((r.categorie+' '+r.waarvoor+' '+r.uitleg+' '+r.sectie).toLowerCase())+'">'
   +'<div><div class="cat">'+esc(r.categorie)+'</div><div>'+esc(r.waarvoor)+'</div><div class="klein">'+esc(r.uitleg)+'</div><div style="margin:4px 0">'+badges+'</div>'+best+'<div class="klein">&rarr; '+esc(r.doelmap)+'/</div></div>'
   +'<div>'+(r.prompt_geerfd&&!r.prompt?'<div class="klein">prompt geleend van de factie/basis; pas hem aan voor dit model</div>':'')+'<textarea id="p_'+esc(r.categorie)+'" placeholder="'+esc(r.prompt_bron||'(geen prompt in de wishlist; schrijf er een)')+'" onchange="bewaarPrompt(\''+esc(r.categorie)+'\')">'+esc(r.prompt)+'</textarea>'
   +'<div class="inst"><span class="klein">duur</span><input id="d_'+esc(r.categorie)+'" value="'+(r.duur??'')+'" placeholder="'+(D.standaard.duur??0)+'" title="seconden, 0 = ElevenLabs kiest"><span class="klein">invloed</span><input id="i_'+esc(r.categorie)+'" value="'+(r.invloed??'')+'" placeholder="'+(D.standaard.invloed??0.3)+'" title="0-1, hoe strak hij de prompt volgt">'
   +'<label class="klein"><input type="checkbox" id="k_'+esc(r.categorie)+'" checked> knip op stiltes</label>'
   +'<button class="prim" id="g_'+esc(r.categorie)+'" onclick="genereer(\''+esc(r.categorie)+'\')">Genereer</button>'
   +(r.prompt?'<button onclick="herstel(\''+esc(r.categorie)+'\')" title="terug naar de prompt uit de wishlist">herstel prompt</button>':'')
   +'<span class="melding" id="m_'+esc(r.categorie)+'"></span></div>'
   +'<div class="takes" id="t_'+esc(r.categorie)+'">'+takes+'</div></div></div>';
 }
 m.innerHTML=h;document.getElementById('tel').textContent=D.rijen.length+' categorieen: '+echt+' echt, '+syn+' synthetisch, '+leeg+' leeg';filter()}
function filter(){const z=document.getElementById('zoek').value.toLowerCase();const f=document.getElementById('filter').value;
 for(const e of document.querySelectorAll('.rij')){let aan=!z||e.dataset.zoek.includes(z);if(f==='takes')aan=aan&&e.dataset.takes==='1';else if(f)aan=aan&&e.dataset.st===f;e.classList.toggle('verberg',!aan)}
 for(const h of document.querySelectorAll('h2')){let n=h.nextElementSibling,zicht=false;while(n&&n.tagName!=='H2'){if(!n.classList.contains('verberg'))zicht=true;n=n.nextElementSibling}h.style.display=zicht?'':'none'}}
document.getElementById('zoek').oninput=filter;document.getElementById('filter').onchange=filter;
function promptVan(c){const t=document.getElementById('p_'+c);return t.value.trim()||t.placeholder}
async function bewaarPrompt(c){await api('/api/prompt',{categorie:c,prompt:document.getElementById('p_'+c).value,duur:document.getElementById('d_'+c).value,invloed:document.getElementById('i_'+c).value})}
async function herstel(c){document.getElementById('p_'+c).value='';await bewaarPrompt(c);await laad()}
async function genereer(c){const b=document.getElementById('g_'+c),m=document.getElementById('m_'+c);await bewaarPrompt(c);b.disabled=true;b.textContent='bezig...';m.textContent='';
 try{const j=await api('/api/genereer',{categorie:c,prompt:promptVan(c),duur:document.getElementById('d_'+c).value||document.getElementById('s_duur').value,invloed:document.getElementById('i_'+c).value||document.getElementById('s_invloed').value,knippen:document.getElementById('k_'+c).checked});
  D=await api('/api/overzicht');teken();document.getElementById('m_'+c).textContent=j.melding||('klaar: '+j.takes.length+' take(s)');document.querySelector('[data-cat="'+c+'"]').scrollIntoView({block:'center'})}
 catch(e){m.textContent=e.message;b.disabled=false;b.textContent='Genereer'}}
async function gebruik(c,t,v){try{const j=await api('/api/gebruik',{categorie:c,take:t,vervang:v});await laad();document.getElementById('m_'+c).textContent='opgeslagen als '+j.doel+' (nog importeren in Godot)';document.querySelector('[data-cat="'+c+'"]').scrollIntoView({block:'center'})}catch(e){alert(e.message)}}
async function weg(t){await api('/api/weg',{take:t});await laad()}
async function bewaarSleutel(){const k=document.getElementById('sleutel').value.trim();if(!k)return;try{await api('/api/sleutel',{sleutel:k})}catch(e){alert(e.message);return}document.getElementById('sleutel').value='';await laad()}
async function bewaarStandaard(){await api('/api/standaard',{duur:document.getElementById('s_duur').value,invloed:document.getElementById('s_invloed').value});await laad()}
async function importeer(){await api('/api/import',{});D.import={bezig:true,laatste:'bezig...'};status()}
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
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path == "/":
            data = PAGINA.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        elif u.path == "/api/overzicht":
            with _lock:
                self._json(overzicht())
        elif u.path == "/api/import_status":
            self._json(_import_status)
        elif u.path == "/audio":
            p = urllib.parse.parse_qs(u.query).get("p", [""])[0]
            pad = os.path.normpath(p)
            toegestaan = pad.startswith("sounds") or pad.startswith(os.path.normpath(TAKES_DIR))
            if not toegestaan or ".." in pad or not os.path.isfile(pad):
                self.send_error(404)
                return
            data = open(pad, "rb").read()
            self.send_response(200)
            self.send_header("Content-Type", "audio/mpeg" if pad.endswith(".mp3") else "audio/wav")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)
        else:
            self.send_error(404)

    def do_POST(self):
        n = int(self.headers.get("Content-Length", "0") or 0)
        try:
            b = json.loads(self.rfile.read(n).decode("utf-8") or "{}")
        except ValueError:
            b = {}
        try:
            with _lock:
                self._json(self._post(self.path, b))
        except Exception as e:  # noqa: BLE001
            self._json({"fout": str(e)}, 200)

    def _post(self, pad, b):
        if pad == "/api/prompt":
            s = lees_studio()
            cat = str(b.get("categorie", ""))
            if not re.fullmatch(r"[a-z0-9_]+", cat):
                raise RuntimeError("rare categorie")
            p = str(b.get("prompt", "")).strip()
            if p:
                s.setdefault("prompts", {})[cat] = p
            else:
                s.setdefault("prompts", {}).pop(cat, None)
            inst = {}
            for k in ("duur", "invloed"):
                v = str(b.get(k, "")).strip().replace(",", ".")
                if v:
                    inst[k] = float(v)
            if inst:
                s.setdefault("instellingen", {})[cat] = inst
            else:
                s.setdefault("instellingen", {}).pop(cat, None)
            schrijf_studio(s)
            return {"ok": True}
        if pad == "/api/standaard":
            s = lees_studio()
            st = s.setdefault("standaard", {})
            for k in ("duur", "invloed"):
                v = str(b.get(k, "")).strip().replace(",", ".")
                if v:
                    st[k] = float(v)
            schrijf_studio(s)
            return {"ok": True}
        if pad == "/api/sleutel":
            k = str(b.get("sleutel", "")).strip()
            if not k.startswith("sk_"):
                # Max plakte het ID van de sleutel (18 september): ElevenLabs
                # toont de echte sleutel maar een keer, bij het aanmaken.
                raise RuntimeError("Dit is niet de API-sleutel zelf: die begint met 'sk_' en zie je alleen bij "
                                   "het aanmaken of roteren (ElevenLabs > API Keys > Create). Dit lijkt het ID.")
            schrijf_sleutel(k)
            return {"ok": True}
        if pad == "/api/genereer":
            cat = str(b.get("categorie", ""))
            if not re.fullmatch(r"[a-z0-9_]+", cat):
                raise RuntimeError("rare categorie")
            prompt = str(b.get("prompt", "")).strip()
            if not prompt:
                raise RuntimeError("Geen prompt.")
            s = lees_studio()
            st = s.get("standaard", {})
            duur = float(str(b.get("duur") or st.get("duur") or 0).replace(",", ".") or 0)
            invloed = float(str(b.get("invloed") or st.get("invloed") or 0.3).replace(",", "."))
            model = s.get("instellingen", {}).get(cat, {}).get("model") or st.get("model") or MODELLEN[0]
            return genereer(cat, prompt, duur, max(0.0, min(1.0, invloed)), model, bool(b.get("knippen", True)))
        if pad == "/api/gebruik":
            return {"doel": gebruik(str(b.get("categorie", "")), str(b.get("take", "")), bool(b.get("vervang")))}
        if pad == "/api/weg":
            verwijder_take(str(b.get("take", "")))
            return {"ok": True}
        if pad == "/api/import":
            godot_import()
            return {"ok": True}
        raise RuntimeError("onbekend pad %s" % pad)


def vrije_poort(start):
    """De eerste poort vanaf `start` waar niets op luistert. Op Windows laat
    SO_REUSEADDR (dat http.server aanzet) je gewoon binden naast een ander
    programma op dezelfde poort, en dan krijgt DAT de verbindingen: zo kwam
    de pagina leeg terug (Max: "ERR_EMPTY_RESPONSE"). Daarom eerst proberen
    te verbinden en exclusief te binden."""
    for poort in range(start, start + 50):
        try:
            socket.create_connection(("127.0.0.1", poort), 0.25).close()
            continue    # iemand antwoordt al
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--poort", type=int, default=8765)
    ap.add_argument("--geen-browser", action="store_true")
    ap.add_argument("--overzicht", action="store_true", help="alleen het overzicht als json printen (voor een check)")
    a = ap.parse_args()
    if a.overzicht:
        o = overzicht()
        print(json.dumps({"categorieen": len(o["rijen"]),
                          "leeg": sum(1 for r in o["rijen"] if not r["echt"] and not r["synth"]),
                          "synth": sum(1 for r in o["rijen"] if not r["echt"] and r["synth"]),
                          "echt": sum(1 for r in o["rijen"] if r["echt"]),
                          "zonder_prompt": [r["categorie"] for r in o["rijen"] if not (r["prompt"] or r["prompt_bron"])]},
                         indent=1))
        return
    poort = vrije_poort(a.poort)
    srv = ThreadingHTTPServer(("127.0.0.1", poort), Handler)
    url = "http://127.0.0.1:%d/" % poort
    if poort != a.poort:
        print("poort %d is bezet door een ander programma, dus %d" % (a.poort, poort))
    print("Geluid-studio op %s  (Ctrl+C stopt)" % url)
    if not a.geen_browser:
        webbrowser.open(url)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
