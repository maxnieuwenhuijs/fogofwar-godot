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
STUDIO_STEMPEL = "%d-%d" % (os.getpid(), int(time.time()))
_import_status = {"bezig": False, "laatste": "", "uitvoer": ""}


# ------------------------------------------------------------------ opslag

def lees_studio():
    try:
        return json.load(io.open(STUDIO_JSON, encoding="utf-8"))
    except (OSError, ValueError):
        return {"prompts": {}, "instellingen": {}, "standaard": {"duur": 0.0, "invloed": 0.6, "model": MODELLEN[0]}}


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
# rijen uit de wishlist-tabellen die geen geluid zijn (de archetype-tabel)
OVERSLAAN = {"base", "spd", "hp", "atk", "mix"}


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
_sha_cache = {}


def sha1_van(pad):
    """sha1 van een bestand, gecached op (grootte, mtime): het overzicht
    hasht anders 300 wavs per klik."""
    try:
        st = os.stat(pad)
    except OSError:
        return ""
    sleutel = (st.st_size, int(st.st_mtime))
    if _sha_cache.get(pad, (None, None))[0] != sleutel:
        _sha_cache[pad] = (sleutel, hashlib.sha1(open(pad, "rb").read()).hexdigest())
    return _sha_cache[pad][1]


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
        (kunst if synth.get(naam) == sha1_van(pad) else echt).append(pad.replace("\\", "/"))
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


def overzicht(alleen=None):
    """Alle rijen, of (alleen=categorie) precies die ene."""
    studio = lees_studio()
    synth = tracker.synthetische_hashes()
    wl = wishlist_rijen()
    rijen = []
    gezien = set()

    def voeg(sectie, cat, waarvoor, uitleg, prompt, gewenst):
        if cat in gezien or cat in OVERSLAAN or any(cat.startswith(o + "_") or cat == o for o in LEGACY.values()):
            return
        gezien.add(cat)
        if alleen is not None and cat != alleen:
            rijen.append({"sectie": sectie, "categorie": cat})
            return
        echt, kunst = bestanden_van(cat, synth)
        inst = studio.get("instellingen", {}).get(cat, {})
        geerfd = False
        if not prompt:
            prompt = prompt_terugval(cat, wl)
            geerfd = bool(prompt)
        rijen.append({
            "sectie": sectie, "categorie": cat, "waarvoor": waarvoor, "uitleg": uitleg,
            "prompt_bron": prompt, "prompt_geerfd": geerfd, "prompt": studio.get("prompts", {}).get(cat, ""),
            "prompt_generator": studio.get("uit_generator", {}).get(cat, ""),
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
    if alleen is not None:
        rijen = [r for r in rijen if r["categorie"] == alleen and "echt" in r]
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


def takes_map():
    """results/geluid_studio met een .gdignore: anders importeert Max' open
    Godot-editor elke take als resource (en laat .import-bestanden achter)."""
    os.makedirs(TAKES_DIR, exist_ok=True)
    gdi = os.path.join(TAKES_DIR, ".gdignore")
    if not os.path.exists(gdi):
        open(gdi, "w").close()


def genereer(cat, prompt, duur, invloed, model, knippen=True):
    data, formaat = elevenlabs(prompt, duur, invloed, model)
    takes_map()
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
    # onthouden welke take al in het spel zit (de pagina zet er een vinkje bij)
    mp = take.rsplit("_", 1)[0] + ".json"
    try:
        meta = json.load(io.open(mp, encoding="utf-8"))
        meta.setdefault("gebruikt", {})[take.replace("\\", "/")] = doel.replace("\\", "/")
        with io.open(mp, "w", encoding="utf-8") as f:
            json.dump(meta, f, indent=1, ensure_ascii=False)
    except (OSError, ValueError):
        pass
    return doel.replace("\\", "/")


def verwijder_bestand(pad):
    """Een bestaand geluid uit sounds/ weg (18 september, Max: "laat me ook
    bestaande geluiden verwijderen als ik het daar niet mee eens ben"), met
    zijn .import. Alleen wav's onder sounds/. Geeft een waarschuwing terug
    als de BANK in audio_manager.gd het bestand bij naam noemt."""
    pad = os.path.normpath(pad)
    if not pad.startswith("sounds") or ".." in pad or not pad.lower().endswith(".wav") or not os.path.isfile(pad):
        raise RuntimeError("Onbekend geluidsbestand: %s" % pad)
    os.remove(pad)
    try:
        os.remove(pad + ".import")
    except OSError:
        pass
    naam = os.path.basename(pad)
    if naam in bank():
        return "%s stond bij naam in de BANK van audio_manager.gd (categorie %s); haal hem daar ook weg." % (naam, bank()[naam])
    return ""


def ruim_takes_op():
    """Bij het openen van de pagina (18 september, Max: "als ik refresh moet
    je alle takes weghalen die ik niet heb toegevoegd"): elke take die niet
    met Gebruiken in het spel is gezet gaat weg; wat wel gebruikt is blijft
    staan als geheugensteun. Geeft het aantal verwijderde takes."""
    weg = 0
    for mp in glob.glob(os.path.join(TAKES_DIR, "*", "*.json")):
        try:
            meta = json.load(io.open(mp, encoding="utf-8"))
        except (OSError, ValueError):
            continue
        gebruikt = meta.get("gebruikt", {})
        rest = []
        for t in meta.get("takes", []):
            if t in gebruikt:
                rest.append(t)
            else:
                try:
                    os.remove(t)
                    weg += 1
                except OSError:
                    pass
                try:
                    os.remove(t + ".import")
                except OSError:
                    pass
        if rest:
            meta["takes"] = rest
            with io.open(mp, "w", encoding="utf-8") as f:
                json.dump(meta, f, indent=1, ensure_ascii=False)
        else:
            try:
                os.remove(mp)
            except OSError:
                pass
    return weg


def verwijder_take(take):
    take = os.path.normpath(take)
    if take.startswith(os.path.normpath(TAKES_DIR)) and os.path.exists(take):
        os.remove(take)
        try:
            os.remove(take + ".import")
        except OSError:
            pass


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
:root{--bg:#1d1a16;--kaart:#2a2620;--rand:#4a4237;--tekst:#eee6d8;--dof:#a89c88;--accent:#e0a53d;--ok:#6dbb6d;--nee:#d9645a;--syn:#c9a25a;--blauw:#6aa6d9}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--tekst);font:14px/1.4 "Segoe UI",sans-serif}
header{position:sticky;top:0;background:#141210;border-bottom:1px solid var(--rand);padding:8px 16px;z-index:5}
.balk{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
header h1{font-size:17px;margin:0 8px 0 0;color:var(--accent)}
input,textarea,select,button{font:inherit;background:#171410;color:var(--tekst);border:1px solid var(--rand);border-radius:4px;padding:5px 8px}
button{cursor:pointer;background:#3a3225;transition:background .15s}button:hover{background:#4a4030}
button.prim{background:var(--accent);color:#1d1a16;font-weight:600}button.prim:hover{background:#f0b64a}
button.klein{padding:2px 7px;font-size:12px}
button:disabled{opacity:.5;cursor:default}
.nav{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}
.chip{border:1px solid var(--rand);border-radius:14px;padding:2px 10px;font-size:12px;cursor:pointer;background:#1f1b16;display:flex;gap:6px;align-items:center}
.chip:hover{border-color:var(--accent)}
.chip .b{display:inline-block;width:50px;height:6px;border-radius:3px;background:#3b342b;overflow:hidden;position:relative}
.chip .b i{position:absolute;left:0;top:0;bottom:0;background:var(--ok)}.chip .b u{position:absolute;top:0;bottom:0;background:var(--syn)}
main{padding:10px 16px 80px;max-width:1400px}
h2{font-size:15px;margin:22px 0 6px;color:var(--accent);border-bottom:1px solid var(--rand);padding-bottom:3px;display:flex;align-items:center;gap:10px;cursor:pointer;user-select:none}
h2 .pijl{display:inline-block;transition:transform .15s;font-size:12px;color:var(--dof)}h2.dicht .pijl{transform:rotate(-90deg)}
h2 .sub{font-weight:400;font-size:12px;color:var(--dof)}
.sectie.dicht .rij{display:none}
.rij{background:var(--kaart);border:1px solid var(--rand);border-radius:6px;padding:8px 10px;margin:6px 0;display:grid;grid-template-columns:280px 1fr;gap:8px 14px;position:relative}
.rij.verberg{display:none}
.rij.nieuw{animation:flits 1.2s ease-out}
@keyframes flits{from{box-shadow:0 0 0 3px var(--accent)}to{box-shadow:0 0 0 0 transparent}}
.cat{font-family:Consolas,monospace;font-size:13px;color:#fff}
.klein{color:var(--dof);font-size:12px}
.badge{display:inline-block;padding:0 6px;border-radius:9px;font-size:11px;margin-right:4px}
.b-ok{background:var(--ok);color:#111}.b-syn{background:var(--syn);color:#111}.b-nee{background:var(--nee);color:#111}.b-gebruikt{background:var(--blauw);color:#111}
audio{height:26px;vertical-align:middle;max-width:230px}
.bestand{display:flex;gap:6px;align-items:center;font-size:12px;margin:2px 0;flex-wrap:wrap}
textarea{width:100%;min-height:54px;resize:vertical}
.inst{display:flex;gap:8px;align-items:center;margin-top:6px;flex-wrap:wrap}
.inst input{width:64px}
.takes{margin-top:6px;border-top:1px dashed var(--rand);padding-top:4px}
.groep{margin:4px 0 8px;padding-left:8px;border-left:2px solid #3b342b}
.take{display:flex;gap:6px;align-items:center;margin:3px 0;flex-wrap:wrap;font-size:12px}
.take.gebruikt{opacity:.75}
.melding{color:var(--nee);font-size:12px}
.tel{color:var(--dof);font-size:12px;margin-left:auto}
#status{font-size:12px;color:var(--dof);display:flex;align-items:center;gap:6px}
.spin{display:inline-block;width:14px;height:14px;border:2px solid var(--rand);border-top-color:var(--accent);border-radius:50%;animation:draai .8s linear infinite;vertical-align:middle}
@keyframes draai{to{transform:rotate(360deg)}}
.bezig{position:absolute;inset:0;background:rgba(20,18,16,.72);border-radius:6px;display:flex;align-items:center;justify-content:center;gap:10px;font-size:13px;z-index:2}
.bezig .spin{width:22px;height:22px;border-width:3px}
#laden{position:fixed;inset:0;background:rgba(20,18,16,.85);display:flex;align-items:center;justify-content:center;gap:12px;z-index:20;font-size:15px}
#toasts{position:fixed;right:16px;bottom:16px;display:flex;flex-direction:column;gap:6px;z-index:30}
.toast{background:#2f2921;border:1px solid var(--rand);border-left:4px solid var(--ok);padding:8px 12px;border-radius:5px;font-size:13px;max-width:420px;box-shadow:0 4px 14px rgba(0,0,0,.5);animation:op .2s ease-out}
.toast.fout{border-left-color:var(--nee)}.toast.info{border-left-color:var(--blauw)}
@keyframes op{from{transform:translateY(8px);opacity:0}to{transform:none;opacity:1}}
.vt{display:flex;gap:4px;align-items:center;height:26px}
.vt i{display:block;width:3px;background:var(--dof);border-radius:1px}
</style></head><body>
<div id="laden"><span class="spin"></span> overzicht laden...</div>
<header>
<div class="balk">
<h1>Geluid-studio</h1>
<input id="zoek" placeholder="zoek (categorie, tekst)..." style="width:220px">
<select id="filter"><option value="">alles</option><option value="leeg">leeg</option><option value="synth">synthetisch</option><option value="echt">echt</option><option value="takes">met takes</option></select>
<label class="klein">sleutel <input id="sleutel" type="password" placeholder="ElevenLabs API-sleutel (sk_...)" style="width:200px"><button class="klein" onclick="bewaarSleutel()">bewaar</button></label>
<label class="klein">standaard duur <input id="s_duur" style="width:52px" title="seconden, 0 = ElevenLabs kiest"></label>
<label class="klein">invloed <input id="s_invloed" style="width:52px" title="0-1, hoe strak hij de prompt volgt"></label>
<button class="klein" onclick="bewaarStandaard()">bewaar</button>
<button onclick="importeer()" id="btnImport">Importeer in Godot</button>
<span id="status"></span>
<span class="tel" id="tel"></span>
</div>
<div class="nav" id="nav"></div>
</header>
<main id="main"></main>
<div id="toasts"></div>
<script>
let D=null;const open_={};
async function api(p,b){const r=await fetch(p,b?{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(b)}:{});let j;try{j=await r.json()}catch(e){throw new Error('geen antwoord van de studio (draait hij nog?)')}if(j.fout)throw new Error(j.fout);return j}
function esc(s){return String(s||'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function toast(t,soort){const d=document.createElement('div');d.className='toast '+(soort||'');d.textContent=t;document.getElementById('toasts').appendChild(d);setTimeout(()=>{d.style.opacity='0';d.style.transition='opacity .4s';setTimeout(()=>d.remove(),400)},soort==='fout'?7000:3500)}
function speler(p){return '<audio controls preload="none" src="/audio?p='+encodeURIComponent(p)+'"></audio>'}
function naam(p){return p.split('/').pop()}
function st(r){return r.echt.length?'echt':(r.synth.length?'synth':'leeg')}
async function laad(stil){if(!stil)document.getElementById('laden').style.display='flex';try{if(!stil){const o=await api('/api/opruimen');if(o.weg)setTimeout(()=>toast(o.weg+' niet-gebruikte take(s) van de vorige keer opgeruimd','info'),300)}D=await api('/api/overzicht');teken();document.getElementById('sleutel').placeholder=D.sleutel?'sleutel staat (verborgen)':'ElevenLabs API-sleutel (sk_...)';document.getElementById('s_duur').value=D.standaard.duur??0;document.getElementById('s_invloed').value=D.standaard.invloed??0.3;status()}catch(e){toast(e.message,'fout')}document.getElementById('laden').style.display='none'}
function status(){const s=D.import||{};const el=document.getElementById('status');el.innerHTML=s.bezig?'<span class="spin"></span> Godot importeert...':(s.laatste?'import: '+esc(s.laatste):'');document.getElementById('btnImport').disabled=!!s.bezig;if(s.bezig)setTimeout(async()=>{try{D.import=await api('/api/import_status')}catch(e){}status();if(!D.import.bezig){toast('Godot-import '+D.import.laatste,(D.import.laatste||'').startsWith('klaar')?'':'fout');laad(true)}},3000)}
function rijHtml(r){
 const s=st(r);
 let badges=r.echt.length?'<span class="badge b-ok">'+r.echt.length+' echt</span>':'';
 if(r.synth.length)badges+='<span class="badge b-syn">'+r.synth.length+' synthetisch</span>';
 if(!r.echt.length&&!r.synth.length)badges+='<span class="badge b-nee">leeg</span>';
 badges+='<span class="klein">gewenst '+r.gewenst+'</span>';
 let best='';for(const p of r.echt)best+='<div class="bestand">'+speler(p)+'<span>'+esc(naam(p))+'</span><button class="klein" title="dit geluid uit het spel halen" onclick="bestandWeg(\''+esc(r.categorie)+'\',\''+esc(p)+'\')">weg</button></div>';
 for(const p of r.synth)best+='<div class="bestand">'+speler(p)+'<span class="klein">'+esc(naam(p))+' (synthetisch)</span><button class="klein" title="deze placeholder weghalen" onclick="bestandWeg(\''+esc(r.categorie)+'\',\''+esc(p)+'\')">weg</button></div>';
 let takes='';
 for(const g of r.takes){const gb=g.gebruikt||{};
  takes+='<div class="groep"><div class="klein">'+esc(g.tijd)+' &middot; invloed '+g.invloed+(g.duur?' &middot; '+g.duur+' s':'')+(g.seconden?' &middot; clip '+g.seconden+' s':'')+' &middot; <span title="'+esc(g.prompt)+'">'+esc((g.prompt||'').slice(0,80))+(g.prompt&&g.prompt.length>80?'...':'')+'</span>'+(g.melding?' <span class="melding">'+esc(g.melding)+'</span>':'')+'</div>';
  g.takes.forEach((t,i)=>{const u=gb[t];takes+='<div class="take'+(u?' gebruikt':'')+'">'+speler(t)+'<span>take '+(i+1)+'</span>'+(u?'<span class="badge b-gebruikt">in het spel: '+esc(naam(u))+'</span>':'<button class="prim klein" onclick="gebruik(this,\''+esc(r.categorie)+'\',\''+esc(t)+'\',false)">Gebruiken</button>'+(r.synth.length?'<button class="klein" onclick="gebruik(this,\''+esc(r.categorie)+'\',\''+esc(t)+'\',true)" title="overschrijft de eerste synthetische placeholder">Vervang synthetisch</button>':''))+'<button class="klein" onclick="weg(\''+esc(r.categorie)+'\',\''+esc(t)+'\')">weg</button></div>'});
  takes+='</div>'}
 if(r.takes.length)takes+='<div><button class="klein" onclick="allesWeg(\''+esc(r.categorie)+'\')">alle takes van deze categorie weg</button></div>';
 return '<div><div class="cat">'+esc(r.categorie)+'</div><div>'+esc(r.waarvoor)+'</div><div class="klein">'+esc(r.uitleg)+'</div><div style="margin:4px 0">'+badges+'</div>'+best+'<div class="klein">&rarr; '+esc(r.doelmap)+'/</div></div>'
  +'<div>'+(r.prompt_geerfd&&!r.prompt?'<div class="klein">prompt geleend van de factie/basis; pas hem aan voor dit model</div>':'')+'<textarea id="p_'+esc(r.categorie)+'" placeholder="'+esc(r.prompt_bron||'(geen prompt in de wishlist; schrijf er een)')+'" onchange="bewaarPrompt(\''+esc(r.categorie)+'\')">'+esc(r.prompt)+'</textarea>'
  +'<div class="inst"><span class="klein">duur</span><input id="d_'+esc(r.categorie)+'" value="'+(r.duur??'')+'" placeholder="'+(D.standaard.duur??0)+'" title="seconden, 0 = ElevenLabs kiest" onchange="bewaarPrompt(\''+esc(r.categorie)+'\')"><span class="klein">invloed</span><input id="i_'+esc(r.categorie)+'" value="'+(r.invloed??'')+'" placeholder="'+(D.standaard.invloed??0.3)+'" title="0-1, hoe strak hij de prompt volgt" onchange="bewaarPrompt(\''+esc(r.categorie)+'\')">'
  +'<label class="klein" title="aan als de prompt om een reeks vraagt (in a row); uit = de hele clip als een take"><input type="checkbox" id="k_'+esc(r.categorie)+'"'+(/in a row/i.test(r.prompt||r.prompt_bron||'')?' checked':'')+'> knip op stiltes</label>'
  +'<button class="prim" onclick="genereer(\''+esc(r.categorie)+'\',1)">Genereer</button><button onclick="genereer(\''+esc(r.categorie)+'\',3)" title="drie keer achter elkaar, meer keus">&times;3</button>'
  +((r.prompt_generator&&r.prompt!==r.prompt_generator)||(!r.prompt_generator&&r.prompt)?'<button class="klein" onclick="herstel(\''+esc(r.categorie)+'\')" title="'+(r.prompt_generator?'terug naar de prompt van Claude (maak_geluid_prompts.py)':'terug naar de prompt uit de wishlist')+'">herstel prompt</button>':'')
  +'</div><div class="takes" id="t_'+esc(r.categorie)+'">'+takes+'</div></div>';}
function rijAttrs(el,r){el.dataset.cat=r.categorie;el.dataset.st=st(r);el.dataset.takes=r.takes.length?1:0;el.dataset.zoek=(r.categorie+' '+r.waarvoor+' '+r.uitleg+' '+r.sectie).toLowerCase()}
function teken(){
 const m=document.getElementById('main');let h='';let sec='';const secs=[];
 for(const r of D.rijen){
  if(r.sectie!==sec){if(sec)h+='</div>';sec=r.sectie;secs.push({naam:sec,echt:0,syn:0,leeg:0});h+='<div class="sectie'+(open_[sec]===false?' dicht':'')+'" id="s_'+secs.length+'"><h2 class="'+(open_[sec]===false?'dicht':'')+'" onclick="klap(this)"><span class="pijl">&#9660;</span>'+esc(sec)+'<span class="sub" id="sub_'+secs.length+'"></span></h2>'}
  const cur=secs[secs.length-1];const s=st(r);if(s==='echt')cur.echt++;else if(s==='synth')cur.syn++;else cur.leeg++;
  h+='<div class="rij">'+rijHtml(r)+'</div>';
 }
 if(sec)h+='</div>';
 m.innerHTML=h;
 const els=m.querySelectorAll('.rij');D.rijen.forEach((r,i)=>rijAttrs(els[i],r));
 let nav='',E=0,S=0,L=0;secs.forEach((c,i)=>{const n=c.echt+c.syn+c.leeg;E+=c.echt;S+=c.syn;L+=c.leeg;document.getElementById('sub_'+(i+1)).textContent=c.echt+' echt, '+c.syn+' synthetisch, '+c.leeg+' leeg';
  nav+='<span class="chip" onclick="spring('+(i+1)+')">'+esc(c.naam)+'<span class="b"><i style="width:'+(100*c.echt/n)+'%"></i><u style="left:'+(100*c.echt/n)+'%;width:'+(100*c.syn/n)+'%"></u></span><span class="klein">'+c.echt+'/'+n+'</span></span>'});
 document.getElementById('nav').innerHTML=nav;
 document.getElementById('tel').textContent=D.rijen.length+' categorieen: '+E+' echt, '+S+' synthetisch, '+L+' leeg';filter()}
function klap(h){const s=h.parentElement;s.classList.toggle('dicht');h.classList.toggle('dicht');open_[h.textContent.replace(/^\S+/,'').trim().split(/\d+ echt/)[0].trim()]=!s.classList.contains('dicht')}
function spring(i){const s=document.getElementById('s_'+i);s.classList.remove('dicht');s.querySelector('h2').classList.remove('dicht');s.scrollIntoView({block:'start',behavior:'smooth'})}
function filter(){const z=document.getElementById('zoek').value.toLowerCase();const f=document.getElementById('filter').value;
 for(const e of document.querySelectorAll('.rij')){let aan=!z||e.dataset.zoek.includes(z);if(f==='takes')aan=aan&&e.dataset.takes==='1';else if(f)aan=aan&&e.dataset.st===f;e.classList.toggle('verberg',!aan)}
 for(const s of document.querySelectorAll('.sectie')){const zicht=[...s.querySelectorAll('.rij')].some(e=>!e.classList.contains('verberg'));s.style.display=zicht?'':'none'}}
document.getElementById('zoek').oninput=filter;document.getElementById('filter').onchange=filter;
async function ververs(c,flits){try{const r=await api('/api/rij?cat='+encodeURIComponent(c));const el=document.querySelector('.rij[data-cat="'+c+'"]');if(!el)return;const idx=D.rijen.findIndex(x=>x.categorie===c);if(idx>=0)D.rijen[idx]=r;el.innerHTML=rijHtml(r);rijAttrs(el,r);if(flits){el.classList.remove('nieuw');void el.offsetWidth;el.classList.add('nieuw')}filter()}catch(e){toast(e.message,'fout')}}
function promptVan(c){const t=document.getElementById('p_'+c);return t.value.trim()||t.placeholder}
async function bewaarPrompt(c){try{await api('/api/prompt',{categorie:c,prompt:document.getElementById('p_'+c).value,duur:document.getElementById('d_'+c).value,invloed:document.getElementById('i_'+c).value})}catch(e){toast(e.message,'fout')}}
async function herstel(c){const r=D.rijen.find(x=>x.categorie===c);document.getElementById('p_'+c).value=r&&r.prompt_generator?r.prompt_generator:'';await bewaarPrompt(c);await ververs(c);toast('prompt van '+c+' teruggezet','info')}
function bezigAan(c,tekst){const el=document.querySelector('.rij[data-cat="'+c+'"]');if(!el)return null;const d=document.createElement('div');d.className='bezig';d.innerHTML='<span class="spin"></span><span></span>';el.appendChild(d);const t0=Date.now();d.timer=setInterval(()=>{d.lastChild.textContent=tekst+' '+Math.round((Date.now()-t0)/1000)+' s'},250);d.lastChild.textContent=tekst;return d}
function bezigUit(d){if(!d)return;clearInterval(d.timer);d.remove()}
async function genereer(c,n){await bewaarPrompt(c);const duur=document.getElementById('d_'+c).value||document.getElementById('s_duur').value,invloed=document.getElementById('i_'+c).value||document.getElementById('s_invloed').value,knippen=document.getElementById('k_'+c).checked,prompt=promptVan(c);
 let tot=0;for(let i=0;i<n;i++){const d=bezigAan(c,'ElevenLabs genereert'+(n>1?' ('+(i+1)+' van '+n+')':'')+'...');
  try{const j=await api('/api/genereer',{categorie:c,prompt,duur,invloed,knippen});tot+=j.takes.length;if(j.melding)toast(j.melding,'info')}
  catch(e){bezigUit(d);toast(e.message,'fout');break}
  bezigUit(d)}
 await ververs(c,true);if(tot)toast(tot+' take(s) voor '+c+' klaar, luister en kies');}
async function gebruik(btn,c,t,v){btn.disabled=true;btn.innerHTML='<span class="spin"></span>';try{const j=await api('/api/gebruik',{categorie:c,take:t,vervang:v});toast('opgeslagen als '+j.doel+' (nog importeren in Godot)');await ververs(c,true)}catch(e){toast(e.message,'fout');btn.disabled=false;btn.textContent=v?'Vervang synthetisch':'Gebruiken'}}
async function bestandWeg(c,p){if(!confirm(naam(p)+' uit het spel halen? (git kan hem terughalen)'))return;try{const j=await api('/api/bestand_weg',{pad:p});toast(naam(p)+' verwijderd'+(j.melding?' - '+j.melding:''),j.melding?'info':'');await ververs(c,true)}catch(e){toast(e.message,'fout')}}
async function weg(c,t){try{await api('/api/weg',{take:t});await ververs(c)}catch(e){toast(e.message,'fout')}}
async function allesWeg(c){if(!confirm('Alle takes van '+c+' weggooien (wat al in het spel staat blijft)?'))return;try{await api('/api/takes_weg',{categorie:c});await ververs(c)}catch(e){toast(e.message,'fout')}}
async function bewaarSleutel(){const k=document.getElementById('sleutel').value.trim();if(!k)return;try{await api('/api/sleutel',{sleutel:k})}catch(e){toast(e.message,'fout');return}document.getElementById('sleutel').value='';toast('sleutel bewaard');await laad(true)}
async function bewaarStandaard(){try{await api('/api/standaard',{duur:document.getElementById('s_duur').value,invloed:document.getElementById('s_invloed').value});toast('standaard bewaard');await laad(true)}catch(e){toast(e.message,'fout')}}
async function importeer(){try{await api('/api/import',{});D.import={bezig:true,laatste:'bezig...'};status();toast('Godot importeert (duurt een minuut; lukt niet met de editor open)','info')}catch(e){toast(e.message,'fout')}}
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
        if u.path == "/ping":
            self._json({"pong": True, "studio": STUDIO_STEMPEL})
            return
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
        elif u.path == "/api/opruimen":
            with _lock:
                self._json({"weg": ruim_takes_op()})
        elif u.path == "/api/rij":
            cat = urllib.parse.parse_qs(u.query).get("cat", [""])[0]
            with _lock:
                o = overzicht(cat)
            self._json(o["rijen"][0] if o["rijen"] else {"fout": "onbekende categorie"})
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
        if pad == "/api/takes_weg":
            cat = str(b.get("categorie", ""))
            if re.fullmatch(r"[a-z0-9_]+", cat):
                for g in takes_van(cat):
                    for t in g["takes"]:
                        verwijder_take(t)
                    try:
                        os.remove(g["meta"])
                    except OSError:
                        pass
            return {"ok": True}
        if pad == "/api/gebruik":
            return {"doel": gebruik(str(b.get("categorie", "")), str(b.get("take", "")), bool(b.get("vervang")))}
        if pad == "/api/bestand_weg":
            return {"melding": verwijder_bestand(str(b.get("pad", "")))}
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
    # Binden en dan BEWIJZEN dat wij het zijn die antwoorden (18 september,
    # Max: "blijft hangen op overzicht laden"): op deze machine kon een
    # tweede studio naast een ander programma op 8765 binden, waarna de
    # browser bij dat andere programma uitkwam. Dus: bind, vraag /ping aan
    # onszelf, en schuif door als het antwoord niet van dit proces komt.
    takes_map()
    srv = None
    poort = a.poort
    for poging in range(50):
        poort = vrije_poort(a.poort + poging)
        try:
            srv = ThreadingHTTPServer(("127.0.0.1", poort), Handler)
        except OSError:
            continue
        t = threading.Thread(target=srv.serve_forever, daemon=True)
        t.start()
        try:
            with urllib.request.urlopen("http://127.0.0.1:%d/ping" % poort, timeout=3) as r:
                ok = json.loads(r.read().decode("utf-8")).get("studio") == STUDIO_STEMPEL
        except Exception:  # noqa: BLE001
            ok = False
        if ok:
            break
        print("poort %d antwoordt niet als deze studio (iets anders zit ervoor), volgende" % poort)
        srv.shutdown()
        srv.server_close()
        srv = None
    if srv is None:
        print("geen werkende poort gevonden vanaf %d" % a.poort)
        return
    url = "http://127.0.0.1:%d/" % poort
    if poort != a.poort:
        print("poort %d is bezet door een ander programma, dus %d" % (a.poort, poort))
    print("Geluid-studio op %s  (Ctrl+C stopt)" % url)
    if not a.geen_browser:
        webbrowser.open(url)
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        srv.shutdown()


if __name__ == "__main__":
    main()
