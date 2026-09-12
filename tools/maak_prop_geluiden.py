# -*- coding: utf-8 -*-
"""Synthetische tik-geluiden voor de props van het diorama (11 september).

    python tools/maak_prop_geluiden.py [--uit sounds/props] [--seed 5]

Max: "iedere prop moet ook z'n eigen geluidjes hebben met variatie per prop".
Tot de echte opnames er zijn (SOUND-WISHLIST sectie 11) maakt dit script per
categorie DRIE varianten uit pure wiskunde: een FM-bel, een glasklink,
aambeeld-partialen, een trommelslag, een kraai, een kikker, een klop op de
deur, een plons, geritsel, en zo verder. Elke variant heeft een eigen
toonhoogte en lengte, dus drie keer klikken klinkt drie keer net anders.

Bestandsnaam = categorie (+ `_2`, `_3` voor de varianten), precies zoals
`Audio._vind_losse_bestanden` ze leest: zet later een echte `prop_bel.wav`
op dezelfde naam en de synthetische wijkt. 22 kHz mono 16-bit, piek -6 dB.
"""
import argparse
import hashlib
import json
import os
import wave

import numpy as np

SR = 22050


def t_as(duur):
    return np.arange(int(SR * duur)) / SR


def env(t, tau, aanval=0.002):
    e = np.exp(-t / tau)
    a = np.clip(t / max(aanval, 1e-4), 0.0, 1.0)
    return e * a


def ruis(n, rng):
    return rng.standard_normal(n).astype(np.float32)


def band(x, lo, hi):
    """Bandfilter via FFT: alles buiten [lo, hi] Hz weg (zacht)."""
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    spec = np.fft.rfft(x)
    masker = np.ones_like(f)
    if lo > 0:
        masker *= np.clip((f - lo * 0.7) / (lo * 0.3 + 1e-6), 0.0, 1.0)
    if hi < SR / 2:
        masker *= np.clip((hi * 1.3 - f) / (hi * 0.3 + 1e-6), 0.0, 1.0)
    return np.fft.irfft(spec * masker, n=len(x)).astype(np.float32)


def sinus(t, f, fase=0.0):
    return np.sin(2 * np.pi * f * t + fase)


def zaag(t, f):
    return 2.0 * ((t * f) % 1.0) - 1.0


def partialen(t, freqs, taus, amps):
    uit = np.zeros_like(t)
    for f, tau, a in zip(freqs, taus, amps):
        uit += a * sinus(t, f) * env(t, tau)
    return uit


def klik(t, rng, lo=800, hi=4000, tau=0.01):
    return band(ruis(len(t), rng), lo, hi) * env(t, tau)


# ---------------------------------------------------------------- recepten
# elk recept: (k = toonfactor 0.9..1.1 per variant, rng) -> float32 array

def r_tik(k, rng):
    t = t_as(0.14)
    return klik(t, rng, 700, 3200, 0.018) * 0.8 + sinus(t, 180 * k) * env(t, 0.045) * 0.7


def r_bel(k, rng):
    t = t_as(1.3)
    f0 = 980 * k
    mod = sinus(t, f0 * 1.41) * 2.2 * np.exp(-t / 0.35)
    drager = np.sin(2 * np.pi * f0 * t + mod) * env(t, 0.55, 0.003)
    boven = partialen(t, [f0 * 2.0, f0 * 2.76, f0 * 3.0], [0.3, 0.2, 0.15], [0.35, 0.25, 0.15])
    return drager + boven + klik(t, rng, 2000, 6000, 0.004) * 0.3


def r_glas(k, rng):
    t = t_as(0.38)
    return partialen(t, [2750 * k, 4150 * k, 5900 * k, 7400 * k], [0.09, 0.06, 0.04, 0.025], [1.0, 0.6, 0.35, 0.2]) \
        + klik(t, rng, 3000, 9000, 0.004) * 0.5


def r_aambeeld(k, rng):
    t = t_as(0.65)
    return partialen(t, [1150 * k, 1720 * k, 2460 * k, 3900 * k, 5200 * k], [0.28, 0.2, 0.14, 0.09, 0.06],
                     [1.0, 0.7, 0.5, 0.35, 0.2]) + klik(t, rng, 1500, 8000, 0.006) * 0.6


def r_kookpot(k, rng):
    t = t_as(0.7)
    return partialen(t, [210 * k, 330 * k, 520 * k, 810 * k], [0.32, 0.22, 0.14, 0.08], [1.0, 0.5, 0.35, 0.2]) \
        + klik(t, rng, 300, 2500, 0.008) * 0.5


def r_trom(k, rng):
    t = t_as(0.32)
    f = 165 * k * np.exp(-t / 0.08) + 52 * k
    fase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(fase) * env(t, 0.13) + band(ruis(len(t), rng), 80, 500) * env(t, 0.035) * 0.6


def r_ton(k, rng):
    t = t_as(0.3)
    return sinus(t, 112 * k) * env(t, 0.1) + sinus(t, 265 * k) * env(t, 0.06) * 0.5 \
        + band(ruis(len(t), rng), 200, 1000) * env(t, 0.03) * 0.5


def r_hoorn(k, rng):
    t = t_as(0.5)
    f = 233 * k * (1 + 0.005 * sinus(t, 5.5))
    fase = 2 * np.pi * np.cumsum(f) / SR
    x = (2.0 * ((fase / (2 * np.pi)) % 1.0) - 1.0) * 0.7 + np.sin(fase * 2) * 0.3
    a = np.clip(t / 0.03, 0, 1) * np.clip((0.5 - t) / 0.1, 0, 1)
    return band(x * a, 100, 1800)


def r_bijl(k, rng):
    t = t_as(0.22)
    return band(ruis(len(t), rng), 250, 1600) * env(t, 0.04) * 0.9 + sinus(t, 95 * k) * env(t, 0.06) * 0.7


def r_kogel(k, rng):
    t = t_as(0.36)
    return partialen(t, [620 * k, 1480 * k, 2130 * k], [0.13, 0.09, 0.06], [1.0, 0.6, 0.4]) + klik(t, rng, 1000, 5000, 0.005) * 0.5


def r_klop(k, rng):
    t = t_as(0.4)
    een = band(ruis(len(t), rng), 250, 1300) * env(t, 0.03) + sinus(t, 140 * k) * env(t, 0.05) * 0.6
    twee = np.roll(een, int(SR * 0.16)) * 0.85
    twee[: int(SR * 0.16)] = 0
    return een + twee


def r_doek(k, rng):
    t = t_as(0.5)
    zwaai = (np.sin(2 * np.pi * 4.5 * k * t) ** 2) * np.clip((0.5 - t) / 0.2, 0, 1) * np.clip(t / 0.02, 0, 1)
    return band(ruis(len(t), rng), 150, 1400) * zwaai


def r_kraai(k, rng):
    t = t_as(0.34)
    f = (640 * k) * np.exp(-t / 0.6)
    fase = 2 * np.pi * np.cumsum(f) / SR
    x = np.sign(np.sin(fase)) * 0.6 + band(ruis(len(t), rng), 500, 3000) * 0.5
    trem = 0.7 + 0.3 * np.sin(2 * np.pi * 32 * t)
    a = np.clip(t / 0.02, 0, 1) * np.clip((0.34 - t) / 0.08, 0, 1)
    return band(x * trem * a, 400, 2600)


def r_kikker(k, rng):
    t = t_as(0.42)
    puls = (np.sin(2 * np.pi * 36 * k * t) > 0.2).astype(np.float32)
    x = sinus(t, 250 * k) * 0.8 + band(ruis(len(t), rng), 300, 1200) * 0.2
    a = np.clip(t / 0.03, 0, 1) * np.clip((0.42 - t) / 0.1, 0, 1)
    return band(x * puls * a, 150, 1500)


def r_kraak(k, rng, duur=0.42, f0=140):
    t = t_as(duur)
    f = f0 * k * (1 + 0.08 * np.sin(2 * np.pi * 8 * t) + 0.03 * np.cumsum(ruis(len(t), rng)) / SR * 40)
    fase = 2 * np.pi * np.cumsum(f) / SR
    x = 2.0 * ((fase / (2 * np.pi)) % 1.0) - 1.0
    a = np.clip(t / 0.05, 0, 1) * np.clip((duur - t) / 0.12, 0, 1)
    return band(x * a, 80, 900)


def r_molen(k, rng):
    t = t_as(0.85)
    x = r_kraak(k, rng, 0.85, 90)
    return x * (0.6 + 0.4 * np.sin(2 * np.pi * 1.6 * t) ** 2)


def r_kanon_tik(k, rng):
    t = t_as(0.26)
    return partialen(t, [900 * k, 2100 * k, 3300 * k], [0.09, 0.06, 0.04], [1.0, 0.5, 0.3]) + klik(t, rng, 1500, 7000, 0.004) * 0.5


def r_kanon(k, rng):
    t = t_as(1.1)
    return band(ruis(len(t), rng), 30, 260) * env(t, 0.35, 0.004) + sinus(t, 45 * k) * env(t, 0.4) * 0.8


def r_emmer(k, rng):
    t = t_as(0.4)
    x = band(ruis(len(t), rng), 200, 1200) * env(t, 0.03) + sinus(t, 170 * k) * env(t, 0.08) * 0.6
    return x


def r_plons(k, rng):
    t = t_as(0.42)
    n = ruis(len(t), rng)
    hoog = band(n, 1800, 6000) * env(t, 0.05, 0.005)
    laag = band(n, 300, 1500) * env(t, 0.16, 0.01) * 0.8
    blips = np.zeros_like(t)
    for _ in range(4):
        s = rng.uniform(0.05, 0.3)
        f = rng.uniform(600, 1400) * k
        m = (t >= s) & (t < s + 0.05)
        blips[m] += np.sin(2 * np.pi * f * (t[m] - s) * (1 + 3 * (t[m] - s))) * np.exp(-(t[m] - s) / 0.015)
    return hoog + laag + blips * 0.5


def r_ritsel(k, rng, lo=2200, hi=8000):
    t = t_as(0.45)
    gate = (rng.random(len(t)) < 0.35).astype(np.float32)
    gate = np.convolve(gate, np.ones(40) / 40, mode="same")
    a = np.clip(t / 0.03, 0, 1) * np.clip((0.45 - t) / 0.12, 0, 1)
    return band(ruis(len(t), rng) * gate, lo, hi) * a


def r_zand(k, rng):
    t = t_as(0.35)
    a = np.sin(np.pi * t / 0.35) ** 0.7
    return band(ruis(len(t), rng), 1500 * k, 6500) * a * 0.8


def r_steen(k, rng):
    t = t_as(0.22)
    return band(ruis(len(t), rng), 120, 900) * env(t, 0.03) + sinus(t, 140 * k) * env(t, 0.05) * 0.5


def r_sneeuw(k, rng):
    t = t_as(0.26)
    return band(ruis(len(t), rng), 80, 600) * env(t, 0.06, 0.01) * 0.9


def r_hooi(k, rng):
    return r_ritsel(k, rng, 900, 4000)


def r_lantaarn(k, rng):
    t = t_as(0.3)
    return partialen(t, [1900 * k, 3400 * k, 5100 * k], [0.1, 0.06, 0.04], [1.0, 0.5, 0.3]) + klik(t, rng, 2000, 8000, 0.003) * 0.3


def r_vuur(k, rng):
    t = t_as(0.45)
    imp = np.zeros_like(t)
    for _ in range(int(rng.integers(6, 12))):
        i = int(rng.uniform(0.0, 0.42) * SR)
        imp[i: i + 3] = rng.uniform(0.4, 1.0)
    return band(imp, 900 * k, 5000) * np.clip((0.45 - t) / 0.1, 0, 1) + band(ruis(len(t), rng), 100, 500) * 0.12


def r_wc(k, rng):
    t = t_as(0.45)
    knok = band(ruis(len(t), rng), 150, 900) * env(t, 0.05) + sinus(t, 110 * k) * env(t, 0.08) * 0.7
    piep_t = t_as(0.18)
    piep = sinus(piep_t, 1200 * k * np.exp(-piep_t / 0.5)) * np.sin(np.pi * piep_t / 0.18) * 0.35
    uit = knok
    uit[: len(piep)] += band(piep, 700, 2500)
    return uit


def r_uil(k, rng):
    t = t_as(0.6)
    uit = np.zeros_like(t)
    for s in (0.0, 0.3):
        m = (t >= s) & (t < s + 0.22)
        tt = t[m] - s
        uit[m] += sinus(tt, 420 * k * (1 + 0.02 * np.sin(2 * np.pi * 6 * tt))) * np.sin(np.pi * tt / 0.22) ** 0.8
    return band(uit, 200, 1200)


def r_kip(k, rng):
    t = t_as(0.5)
    uit = np.zeros_like(t)
    for i in range(4):
        s = 0.1 * i + rng.uniform(0.0, 0.03)
        m = (t >= s) & (t < s + 0.07)
        tt = t[m] - s
        f = (900 + 250 * i) * k
        uit[m] += np.sign(np.sin(2 * np.pi * f * tt)) * 0.5 * np.exp(-tt / 0.03) + sinus(tt, f * 1.5) * np.exp(-tt / 0.02) * 0.4
    return band(uit, 500, 4000)


def r_munt(k, rng):
    t = t_as(0.3)
    return partialen(t, [4200 * k, 6300 * k, 8900 * k], [0.12, 0.08, 0.05], [1.0, 0.5, 0.25])


def r_kokos(k, rng):
    t = t_as(0.25)
    return sinus(t, 80 * k) * env(t, 0.08) + band(ruis(len(t), rng), 150, 700) * env(t, 0.03) * 0.7


def r_boot(k, rng):
    t = t_as(0.35)
    return sinus(t, 180 * k) * env(t, 0.15) * 0.8 + band(ruis(len(t), rng), 200, 1400) * env(t, 0.025) * 0.6


def r_ijs(k, rng):
    t = t_as(0.35)
    imp = np.zeros_like(t)
    for _ in range(int(rng.integers(5, 9))):
        i = int(rng.uniform(0.0, 0.3) * SR)
        imp[i: i + 2] = rng.uniform(0.5, 1.0)
    return band(imp, 1500, 7000) + band(ruis(len(t), rng), 300, 2000) * env(t, 0.06) * 0.6


def r_combo(k, rng):
    t = t_as(0.6)
    uit = np.zeros_like(t)
    for i, f in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
        s = 0.09 * i
        m = t >= s
        tt = t[m] - s
        uit[m] += sinus(tt, f * k) * np.exp(-tt / 0.22) * (0.9 - 0.1 * i)
    return uit


def r_snurken(k, rng):
    t = t_as(0.7)
    x = zaag(t, 85 * k) * (0.5 + 0.5 * np.sin(2 * np.pi * 3.2 * t))
    return band(x, 60, 400) * np.sin(np.pi * t / 0.7)


def r_nies(k, rng):
    t = t_as(0.4)
    aanloop = band(ruis(len(t), rng), 800, 4000) * np.clip(t / 0.15, 0, 1) * (t < 0.15)
    tsjoe = band(ruis(len(t), rng), 2000, 8000) * np.exp(-np.clip(t - 0.15, 0, 1) / 0.08) * (t >= 0.15)
    return aanloop * 0.6 + tsjoe


def r_geit(k, rng):
    t = t_as(0.5)
    f = 330 * k * (1 + 0.06 * np.sin(2 * np.pi * 14 * t))
    fase = 2 * np.pi * np.cumsum(f) / SR
    x = np.sign(np.sin(fase)) * 0.5 + np.sin(fase) * 0.5
    a = np.clip(t / 0.03, 0, 1) * np.clip((0.5 - t) / 0.1, 0, 1)
    return band(x * a, 250, 2500)


RECEPTEN = {
    "prop_tik": (r_tik, 3), "prop_bel": (r_bel, 3), "prop_glas": (r_glas, 3), "prop_aambeeld": (r_aambeeld, 3),
    "prop_kookpot": (r_kookpot, 3), "prop_trom": (r_trom, 3), "prop_ton": (r_ton, 3), "prop_hoorn": (r_hoorn, 3),
    "prop_bijl": (r_bijl, 3), "prop_kogel": (r_kogel, 3), "prop_klop": (r_klop, 3), "prop_doek": (r_doek, 2),
    "prop_kraai": (r_kraai, 3), "prop_kikker": (r_kikker, 3), "prop_wegwijzer": (r_kraak, 2), "prop_hek": (r_kraak, 2),
    "prop_molen": (r_molen, 2), "prop_kanon_tik": (r_kanon_tik, 2), "prop_kanon": (r_kanon, 2), "prop_emmer": (r_emmer, 2),
    "prop_plons": (r_plons, 3), "prop_ritsel": (r_ritsel, 3), "prop_zand": (r_zand, 2), "prop_steen": (r_steen, 3),
    "prop_sneeuw": (r_sneeuw, 2), "prop_hooi": (r_hooi, 2), "prop_lantaarn": (r_lantaarn, 3), "prop_vuur": (r_vuur, 3),
    "prop_wc": (r_wc, 2), "prop_uil": (r_uil, 2), "prop_kip": (r_kip, 2), "prop_munt": (r_munt, 2), "prop_kokos": (r_kokos, 2),
    "prop_boot": (r_boot, 2), "prop_ijs": (r_ijs, 2), "prop_combo": (r_combo, 1), "bewoner_snurken": (r_snurken, 2),
    "prop_nies": (r_nies, 2), "prop_geit": (r_geit, 2),
}


def schrijf(pad, x):
    x = np.asarray(x, np.float32)
    piek = float(np.max(np.abs(x))) or 1.0
    x = x / piek * 0.5
    # korte fade-out tegen tikken aan het eind
    n = min(len(x), int(SR * 0.01))
    x[-n:] *= np.linspace(1.0, 0.0, n)
    with wave.open(pad, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--uit", default="sounds/props")
    ap.add_argument("--seed", type=int, default=5)
    args = ap.parse_args()
    os.makedirs(args.uit, exist_ok=True)
    totaal = 0
    manifest = {}
    for cat, (recept, n) in RECEPTEN.items():
        for i in range(n):
            # vaste seed per bestand (hash() van python wisselt per proces)
            zaad = args.seed * 1000 + sum(ord(c) for c in cat) * 7 + i
            rng = np.random.default_rng(zaad)
            k = float(rng.uniform(0.92, 1.08))
            naam = cat + ("" if i == 0 else "_%d" % (i + 1)) + ".wav"
            pad = os.path.join(args.uit, naam)
            schrijf(pad, recept(k, rng))
            manifest[naam] = hashlib.sha1(open(pad, "rb").read()).hexdigest()
            totaal += 1
    # het manifest laat de geluid-tracker zien welke bestanden nog synthetisch
    # zijn: een echte opname op dezelfde naam heeft een andere hash
    with open(os.path.join(args.uit, "synthetisch.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
    grootte = sum(os.path.getsize(os.path.join(args.uit, f)) for f in os.listdir(args.uit) if f.endswith(".wav"))
    print("%d bestanden in %s (%.1f MB), %d categorieen, manifest synthetisch.json" % (totaal, args.uit, grootte / 1e6, len(RECEPTEN)))


if __name__ == "__main__":
    main()
