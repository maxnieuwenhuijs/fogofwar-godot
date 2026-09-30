# -*- coding: utf-8 -*-
"""Synthetische UI-geluiden bij de UI-beweging (30 september).

    python tools/maak_ui_geluiden.py [--uit sounds/ui] [--seed 30]

Max: "korte UI geluiden ook nodig toch voor alle animaties en ploffen etc".
Tot de echte opnames er zijn (SOUND-WISHLIST sectie 1, prompts in de tabel
onderaan; de geluid-studio genereert ze) maakt dit script per categorie een
paar varianten uit pure wiskunde, met dezelfde bouwstenen als
`maak_prop_geluiden.py`. Stijlregel: alles klinkt als hout, perkament of
messing uit die tijd, geen synth-piepjes.

    ui_plof     een klein houten "tok" met een opwipje   (iets ploft erin)
    ui_stempel  een houten stempel op perkament en was  (CP-zegel, STEM, winst)
    ui_draai    een stijve perkamenten kaart die omslaat (onthulling)
    ui_tel      een klein messing tikje                 (getallen die optellen)
    ui_munt     een munt die op hout valt               ("+1" dat omhoog zweeft)
    ui_blad     een perkamenten blad dat omslaat        (hub-golf, fasewissel)

Het "kan niet" (nee-schud) speelt `ui_error`: daar ligt al een echte opname
(sounds/studio/ui_error.wav), dus die maakt dit script niet. Het recept
`r_error` staat er nog voor wie hem zonder opname wil (`--ook-error`).

Een echte opname op dezelfde naam verdringt een synthetische (manifest
`synthetisch.json` met sha1's, net als bij de props en de wapens). Na het
draaien: `--import` (met de editor dicht), dan kent het spel ze.
"""
import argparse
import hashlib
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from maak_prop_geluiden import SR, t_as, env, ruis, band, sinus, partialen, klik, schrijf  # noqa: E402


def glij(t, f_van, f_tot, tau):
    """Een sinus die in toonhoogte glijdt (exponentieel naar f_tot)."""
    f = f_tot + (f_van - f_tot) * np.exp(-t / tau)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def r_plof(k, rng):
    # houten pinnetje dat in een gat ploft: kort klikje plus een toontje dat
    # iets omhoog wipt (dat maakt het "vrolijk" zonder piep)
    t = t_as(0.12)
    toon = glij(t, 300 * k, 520 * k, 0.012) * env(t, 0.035, 0.002)
    return klik(t, rng, 700, 3200, 0.010) * 0.7 + toon * 0.8 + sinus(t, 180 * k) * env(t, 0.02) * 0.3


def r_stempel(k, rng):
    # stempel op perkament en was: een doffe houten bons, de klap van het
    # papier en een kort nakraakje
    t = t_as(0.26)
    bons = sinus(t, 92 * k) * env(t, 0.075, 0.003) + sinus(t, 150 * k) * env(t, 0.04, 0.003) * 0.5
    hout = band(ruis(len(t), rng), 220, 1300) * env(t, 0.028, 0.002)
    papier = band(ruis(len(t), rng), 1500, 6500) * env(t, 0.012, 0.001)
    kraak = np.roll(band(ruis(len(t), rng), 900, 3500) * env(t, 0.01), int(SR * 0.05)) * 0.25
    return bons * 1.0 + hout * 0.7 + papier * 0.55 + kraak


def r_draai(k, rng):
    # een stijve kaart die omslaat: een korte zwiep die in toon oploopt en een
    # tikje van de rand die neerkomt
    t = t_as(0.16)
    n = len(t)
    x = ruis(n, rng)
    uit = np.zeros(n, np.float32)
    stukken = 8
    for i in range(stukken):
        a = int(n * i / stukken)
        b = int(n * (i + 1) / stukken)
        fm = 1100 * k * (3.2 ** ((i + 0.5) / stukken))
        venster = np.zeros(n, np.float32)
        venster[a:b] = 1.0
        uit += band(x * venster, fm / 1.6, fm * 1.6)
    bult = np.sin(np.pi * np.clip(t / 0.12, 0.0, 1.0)) ** 2
    rand = np.roll(klik(t, rng, 1800, 5500, 0.006), int(SR * 0.11)) * 0.6
    return uit * bult * 0.9 + rand


def r_tel(k, rng):
    # een klein messing tikje (een telraam-kraal, een gewichtje): hoog en kort;
    # de code laat hem bij optellen per tik iets hoger klinken
    t = t_as(0.07)
    return partialen(t, [2350 * k, 3580 * k, 5100 * k], [0.022, 0.016, 0.01], [1.0, 0.5, 0.25]) \
        + klik(t, rng, 2500, 8000, 0.003) * 0.4


def r_munt(k, rng):
    # een munt die op een houten tafel valt: messing klank met een tweede
    # kleiner stuitertje
    t = t_as(0.34)
    klank = partialen(t, [3150 * k, 4730 * k, 6950 * k, 8200 * k], [0.13, 0.09, 0.06, 0.04], [1.0, 0.7, 0.45, 0.25])
    tik = klik(t, rng, 3000, 9000, 0.004) * 0.6
    stuit = np.roll(partialen(t, [3150 * k, 4730 * k], [0.05, 0.035], [0.45, 0.3]), int(SR * 0.085))
    stuit[: int(SR * 0.085)] = 0
    return klank + tik + stuit


def r_error(k, rng):
    # "kan niet": twee doffe holle klopjes op hout, de tweede lager (nee-nee)
    t = t_as(0.26)
    een = band(ruis(len(t), rng), 160, 750) * env(t, 0.03) + glij(t, 190 * k, 150 * k, 0.03) * env(t, 0.045) * 0.7
    twee = np.roll(band(ruis(len(t), rng), 140, 650) * env(t, 0.03) + glij(t, 160 * k, 120 * k, 0.03) * env(t, 0.05) * 0.7,
                   int(SR * 0.11))
    twee[: int(SR * 0.11)] = 0
    return een + twee * 0.9


def r_blad(k, rng):
    # een perkamenten blad dat omslaat: zacht ruisen dat aanzwelt en wegzakt,
    # met een paar kraakjes van het papier
    t = t_as(0.34)
    bult = np.sin(np.pi * np.clip(t / 0.3, 0.0, 1.0)) ** 1.5
    zacht = band(ruis(len(t), rng), 900 * k, 5200 * k) * bult
    kraakjes = np.zeros(len(t), np.float32)
    for i in range(4):
        op = int(SR * float(rng.uniform(0.03, 0.26)))
        kraakjes += np.roll(klik(t, rng, 2500, 7500, 0.004), op) * float(rng.uniform(0.15, 0.3))
    return zacht * 0.8 + kraakjes


RECEPTEN = {
    "ui_plof": (r_plof, 3),
    "ui_stempel": (r_stempel, 3),
    "ui_draai": (r_draai, 3),
    "ui_tel": (r_tel, 3),
    "ui_munt": (r_munt, 3),
    "ui_blad": (r_blad, 3),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--uit", default="sounds/ui")
    ap.add_argument("--seed", type=int, default=30)
    ap.add_argument("--ook-error", action="store_true", help="ook ui_error maken (alleen zonder echte opname)")
    args = ap.parse_args()
    if args.ook_error:
        RECEPTEN["ui_error"] = (r_error, 2)
    os.makedirs(args.uit, exist_ok=True)
    manifest_pad = os.path.join(args.uit, "synthetisch.json")
    manifest = {}
    if os.path.exists(manifest_pad):
        with open(manifest_pad, encoding="utf-8") as f:
            manifest = json.load(f)
    totaal = 0
    overgeslagen = []
    for cat, (recept, n) in RECEPTEN.items():
        for i in range(n):
            naam = cat + ("" if i == 0 else "_%d" % (i + 1)) + ".wav"
            pad = os.path.join(args.uit, naam)
            # Een echte opname (niet in het manifest, of met een andere hash)
            # laten we staan.
            if os.path.exists(pad):
                oud = hashlib.sha1(open(pad, "rb").read()).hexdigest()
                if manifest.get(naam) != oud:
                    overgeslagen.append(naam)
                    continue
            zaad = args.seed * 1000 + sum(ord(c) for c in cat) * 7 + i
            rng = np.random.default_rng(zaad)
            k = float(rng.uniform(0.93, 1.07))
            schrijf(pad, recept(k, rng))
            manifest[naam] = hashlib.sha1(open(pad, "rb").read()).hexdigest()
            totaal += 1
    with open(manifest_pad, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
    print("%d bestanden in %s, %d categorieen, manifest synthetisch.json" % (totaal, args.uit, len(RECEPTEN)))
    if overgeslagen:
        print("echte opnames blijven staan: %s" % ", ".join(overgeslagen))


if __name__ == "__main__":
    main()
