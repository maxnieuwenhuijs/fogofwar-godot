# -*- coding: utf-8 -*-
"""Synthetische zwaai- en klapgeluiden per WAPEN (17 september).

    python tools/maak_wapen_geluiden.py [--uit sounds/melee] [--seed 17]

Max: "update de sounds ook voor slashing sounds en zwaard-impactgeluiden per
factie of type wapen". Tot de echte opnames er zijn (SOUND-WISHLIST 6b) maakt
dit script per wapen drie categorieen met elk DRIE varianten uit pure
wiskunde, dezelfde bouwstenen als `maak_prop_geluiden.py`:

    slash_<wapen>          de zwaai (whoosh) net VOOR de klap
    melee_kill_<wapen>     de klap die doodt
    melee_survive_<wapen>  de klap die geblokkeerd wordt / niet doodt

Wapens: sabel (base, mix, de pallasch en de briquet), bijl (hp, de broadaxe
en de enterbijl), lans (spd, de uhlanenlans), bajonet (alle infanterie).
Welk wapen bij welk model hoort staat in `PawnView.melee_wapen` (een plek).
Een factie-opname erbij heet `<categorie>_<factie>.wav`, bv
`melee_kill_bijl_pig.wav`, en wint dan van de wapen-versie; een echte opname
op dezelfde naam als een synthetische verdringt die (manifest
`synthetisch.json` met sha1's, net als bij de props).
"""
import argparse
import hashlib
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from maak_prop_geluiden import SR, t_as, env, ruis, band, sinus, partialen, klik, schrijf  # noqa: E402


def whoosh(t, rng, f_van, f_tot, breedte, piek_op, tau_op, tau_af):
    """Een zwaai: ruis waarvan de bandmidden van f_van naar f_tot glijdt,
    met een bult (aanzwellen tot piek_op, dan wegsterven)."""
    n = len(t)
    x = ruis(n, rng)
    # in stukjes filteren zodat de toonhoogte echt glijdt
    stukken = 12
    uit = np.zeros(n, np.float32)
    for i in range(stukken):
        a = int(n * i / stukken)
        b = int(n * (i + 1) / stukken)
        u = (i + 0.5) / stukken
        fm = f_van * (f_tot / f_van) ** u
        venster = np.zeros(n, np.float32)
        venster[a:b] = 1.0
        # zachte overlap tegen naden
        rand = max(1, (b - a) // 3)
        venster[max(0, a - rand):a] = np.linspace(0.0, 1.0, min(rand, a - max(0, a - rand)))[:a - max(0, a - rand)]
        venster[b:min(n, b + rand)] = np.linspace(1.0, 0.0, min(rand, min(n, b + rand) - b))[:min(n, b + rand) - b]
        uit += band(x * venster, fm / breedte, fm * breedte)
    bult = np.where(t < piek_op, (t / piek_op) ** 2, np.exp(-(t - piek_op) / tau_af))
    bult = bult * np.clip(t / max(tau_op, 1e-4), 0.0, 1.0)
    return uit * bult


def nat(t, rng, tau=0.06, lo=120, hi=900):
    """Natte plof: laag gefilterde ruis met een snelle staart."""
    return band(ruis(len(t), rng), lo, hi) * env(t, tau, 0.003)


def schraap(t, rng, f_van, f_tot, tau):
    """Staal dat langs staal schuurt: smalle ruisband die glijdt."""
    return whoosh(t, rng, f_van, f_tot, 1.25, 0.02, 0.005, tau)


# ---------------------------------------------------------------- zwaai

def r_slash_sabel(k, rng):
    t = t_as(0.30)
    return whoosh(t, rng, 2600 * k, 700 * k, 1.8, 0.12, 0.02, 0.07)


def r_slash_bijl(k, rng):
    t = t_as(0.38)
    return whoosh(t, rng, 1500 * k, 380 * k, 2.0, 0.17, 0.03, 0.09) * 1.0 \
        + whoosh(t, rng, 700 * k, 250 * k, 1.6, 0.19, 0.04, 0.08) * 0.6


def r_slash_lans(k, rng):
    t = t_as(0.22)
    return whoosh(t, rng, 3800 * k, 1600 * k, 1.5, 0.08, 0.015, 0.05)


def r_slash_bajonet(k, rng):
    t = t_as(0.20)
    # korte stoot: dun whoosh plus een vleugje stof/doek
    return whoosh(t, rng, 2200 * k, 1100 * k, 1.6, 0.07, 0.015, 0.05) \
        + band(ruis(len(t), rng), 300, 1200) * env(t, 0.05, 0.02) * 0.25


# ---------------------------------------------------------------- de klap (dood)

def r_kill_sabel(k, rng):
    t = t_as(0.55)
    staal = partialen(t, [2900 * k, 4300 * k, 6100 * k], [0.10, 0.07, 0.05], [0.5, 0.3, 0.2])
    return nat(t, rng, 0.07, 100, 1100) * 1.0 + staal * 0.55 \
        + schraap(t, rng, 3000 * k, 1400 * k, 0.12) * 0.35 + klik(t, rng, 1500, 6000, 0.004) * 0.5


def r_kill_bijl(k, rng):
    t = t_as(0.7)
    hak = sinus(t, 78 * k * np.exp(-t / 0.05) + 55 * k) * env(t, 0.13, 0.002)
    kraak = klik(t, rng, 400, 3500, 0.02) + klik(t, rng, 900, 5000, 0.006) * 0.7
    return hak * 1.0 + kraak * 0.9 + nat(t, rng, 0.11, 90, 700) * 0.9


def r_kill_lans(k, rng):
    t = t_as(0.5)
    prik = klik(t, rng, 2500, 9000, 0.004)
    hout = partialen(t, [420 * k, 690 * k, 1010 * k], [0.09, 0.06, 0.04], [0.5, 0.3, 0.2])
    return prik * 0.8 + nat(t, rng, 0.08, 150, 1300) * 0.9 + hout * 0.4


def r_kill_bajonet(k, rng):
    t = t_as(0.45)
    return nat(t, rng, 0.05, 140, 1400) * 1.0 + klik(t, rng, 2000, 7000, 0.005) * 0.6 \
        + schraap(t, rng, 2400 * k, 1000 * k, 0.09) * 0.4


# ---------------------------------------------------------------- de klap (overleefd)

def r_survive_sabel(k, rng):
    t = t_as(0.5)
    return partialen(t, [2200 * k, 3150 * k, 4700 * k, 6300 * k], [0.16, 0.12, 0.08, 0.05], [1.0, 0.7, 0.45, 0.25]) \
        + klik(t, rng, 2000, 9000, 0.004) * 0.6


def r_survive_bijl(k, rng):
    t = t_as(0.45)
    # dof op kuras of schild, met de steel die natrilt
    return partialen(t, [860 * k, 1300 * k, 1950 * k], [0.12, 0.08, 0.05], [1.0, 0.5, 0.3]) \
        + sinus(t, 110 * k) * env(t, 0.09) * 0.7 + klik(t, rng, 500, 4000, 0.008) * 0.8


def r_survive_lans(k, rng):
    t = t_as(0.4)
    # schampt af: glijdende schraap en een tik
    return schraap(t, rng, 1800 * k, 4200 * k, 0.16) * 1.0 \
        + partialen(t, [1400 * k, 2350 * k], [0.06, 0.04], [0.6, 0.3]) + klik(t, rng, 1500, 6000, 0.004) * 0.5


def r_survive_bajonet(k, rng):
    t = t_as(0.4)
    return partialen(t, [1900 * k, 2800 * k, 4100 * k], [0.09, 0.07, 0.05], [0.8, 0.5, 0.3]) \
        + klik(t, rng, 1200, 6000, 0.005) * 0.7 + band(ruis(len(t), rng), 200, 900) * env(t, 0.04) * 0.3


def r_charge_rumble(k, rng):
    """De dreunende aanloop van een charge: zware stampen die versnellen,
    met een laag gerommel eronder dat de grond laat trillen (18 september,
    Max: "trembling footsteps als iemand een charge doet")."""
    t = t_as(2.4)
    uit = np.zeros_like(t)
    # stappen die versnellen: interval van 0,32 naar 0,17 s
    tijd = 0.05
    n = 0
    while tijd < 2.1:
        i = int(tijd * SR)
        lengte = int(SR * 0.22)
        tt = t_as(0.22)
        stamp = sinus(tt, (52 + 18 * (n % 2)) * k * np.exp(-tt / 0.06) + 38 * k) * env(tt, 0.09, 0.002) \
            + band(ruis(len(tt), rng), 60, 700) * env(tt, 0.05, 0.003) * 0.5
        uit[i:i + lengte] += stamp[:len(uit) - i] * (0.6 + 0.4 * min(1.0, tijd / 1.4))
        tijd += 0.32 - 0.15 * min(1.0, tijd / 1.8) + rng.uniform(-0.015, 0.015)
        n += 1
    # gerommel eronder dat aanzwelt en aan het eind wegsterft
    rommel = band(ruis(len(t), rng), 25, 140) * np.clip(t / 0.8, 0.0, 1.0) * np.exp(-np.clip(t - 1.9, 0.0, None) / 0.25)
    return uit + rommel * 0.9


WAPENS = ["sabel", "bijl", "lans", "bajonet"]
RECEPTEN = {"charge_rumble": (r_charge_rumble, 3)}
for _w, _slash, _kill, _surv in [
        ("sabel", r_slash_sabel, r_kill_sabel, r_survive_sabel),
        ("bijl", r_slash_bijl, r_kill_bijl, r_survive_bijl),
        ("lans", r_slash_lans, r_kill_lans, r_survive_lans),
        ("bajonet", r_slash_bajonet, r_kill_bajonet, r_survive_bajonet)]:
    RECEPTEN["slash_" + _w] = (_slash, 3)
    RECEPTEN["melee_kill_" + _w] = (_kill, 3)
    RECEPTEN["melee_survive_" + _w] = (_surv, 3)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--uit", default="sounds/melee")
    ap.add_argument("--seed", type=int, default=17)
    args = ap.parse_args()
    os.makedirs(args.uit, exist_ok=True)
    totaal = 0
    manifest = {}
    for cat, (recept, n) in RECEPTEN.items():
        for i in range(n):
            zaad = args.seed * 1000 + sum(ord(c) for c in cat) * 7 + i
            rng = np.random.default_rng(zaad)
            k = float(rng.uniform(0.92, 1.08))
            naam = cat + ("" if i == 0 else "_%d" % (i + 1)) + ".wav"
            pad = os.path.join(args.uit, naam)
            schrijf(pad, recept(k, rng))
            manifest[naam] = hashlib.sha1(open(pad, "rb").read()).hexdigest()
            totaal += 1
    with open(os.path.join(args.uit, "synthetisch.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
    grootte = sum(os.path.getsize(os.path.join(args.uit, f)) for f in os.listdir(args.uit) if f.endswith(".wav"))
    print("%d bestanden in %s (%.2f MB), %d categorieen, manifest synthetisch.json" % (totaal, args.uit, grootte / 1e6, len(RECEPTEN)))


if __name__ == "__main__":
    main()
