# -*- coding: utf-8 -*-
"""Synthetische kanon-geluiden (9 oktober, de Leeuw-kanonnen).

    python tools/maak_kanon_geluiden.py [--uit sounds/firing] [--seed 9]

Max: "doe maar ook lontstok ja". Een kanon met een bediener ontsteekt
eerst: de lontstok raakt het zundgat (`cannon_lontstok`), de lont sist
(`cannon_fuse`, daar liggen echte opnames), dan de knal. Tot de echte
opname er is (SOUND-WISHLIST sectie 6 en de prompt-tabel; de geluid-studio
genereert hem met de prompt uit tools/maak_geluid_prompts.py) maakt dit
script een paar varianten uit pure wiskunde, met dezelfde bouwstenen als
`maak_prop_geluiden.py`:

    cannon_lontstok  een tikje van de stok op het brons, dan een korte fsst
                     van het kruit in het zundgat dat vlam vat, met een paar
                     knettertjes

Een echte opname op dezelfde naam verdringt een synthetische (manifest
`synthetisch.json` met sha1's, net als bij de props, de wapens en de UI);
in de studio "Vervang synthetisch". Na het draaien: `--import` (met de
editor dicht), dan kent het spel ze.
"""
import argparse
import hashlib
import json
import os
import sys

import numpy as np

import synth_geluid  # noqa: E402  (13 oktober: categorieen met een echte opname overslaan)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from maak_prop_geluiden import SR, t_as, env, ruis, band, sinus, partialen, klik, schrijf  # noqa: E402


def r_lontstok(k, rng):
    # de stok tikt op het brons van de stuitkant: een kort metalen tokje
    t = t_as(0.5)
    tik = partialen(t, [1450 * k, 2380 * k, 3720 * k], [0.05, 0.035, 0.02], [1.0, 0.55, 0.3]) \
        + klik(t, rng, 900, 4000, 0.006) * 0.8
    # het kruit in het zundgat vat vlam: een korte fsst die snel aanzwelt en
    # wegsterft, met een dof plofje eronder
    op = float(rng.uniform(0.03, 0.06))
    n_op = int(SR * op)
    ts = np.clip(t - op, 0.0, None)
    aan = (t >= op).astype(np.float32)
    flits = band(ruis(len(t), rng), 1800 * k, 7500) * env(ts, 0.075, 0.004) * aan
    plof = sinus(ts, 80 * k) * env(ts, 0.05, 0.003) * aan
    # en een paar knettertjes in de staart
    knetter = np.zeros(len(t), np.float32)
    for _ in range(int(rng.integers(5, 10))):
        i = n_op + int(SR * float(rng.uniform(0.01, 0.3)))
        if i + 3 < len(t):
            knetter[i:i + 3] = float(rng.uniform(0.4, 1.0))
    knetter = band(knetter, 1500, 6000) * np.exp(-ts / 0.15) * aan
    return tik * 0.7 + flits * 1.0 + plof * 0.3 + knetter * 0.6


RECEPTEN = {
    "cannon_lontstok": (r_lontstok, 3),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--uit", default="sounds/firing")
    ap.add_argument("--seed", type=int, default=9)
    args = ap.parse_args()
    os.makedirs(args.uit, exist_ok=True)
    manifest_pad = os.path.join(args.uit, "synthetisch.json")
    manifest = {}
    if os.path.exists(manifest_pad):
        with open(manifest_pad, encoding="utf-8") as f:
            manifest = json.load(f)
    totaal = 0
    overgeslagen = []
    for cat, (recept, n) in RECEPTEN.items():
        # al een echte opname van dit geluid (13 oktober): niets maken, anders
        # komen de placeholders terug die de geluid-studio net opruimde
        if synth_geluid.heeft_echte_opname(cat):
            overgeslagen.append(cat)
            continue
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
