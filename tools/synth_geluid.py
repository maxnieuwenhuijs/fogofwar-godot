# -*- coding: utf-8 -*-
"""Synthetische placeholder-geluiden herkennen en opruimen (13 oktober, Max:
"als er al een synthetisch geluid inzit dat ik dan als ik een nieuwe toevoeg
dat alle synthetische dan weggaan voor dat type sound").

Een placeholder is een wav waarvan de sha1 in een `synthetisch.json` naast hem
staat (de manifesten van tools/maak_prop_geluiden.py, maak_wapen_geluiden.py,
maak_ui_geluiden.py en maak_kanon_geluiden.py). Een echte opname heeft een
andere hash, ook als hij dezelfde naam draagt.

- `ruim_op(cat, behalve)`: de geluid-studio na "Gebruiken": elke placeholder
  van die categorie weg, met zijn .import en zijn regel in het manifest.
- `heeft_echte_opname(cat)`: de generators slaan zo'n categorie over, anders
  zet een nieuwe run de opgeruimde placeholders terug (of overschrijft hij een
  echte opname met dezelfde naam).

Een categorie is de bestandsnaam zonder `.wav` en zonder `_<nummer>`, zoals
`Audio._vind_losse_bestanden` hem groepeert: `prop_bel.wav`, `prop_bel_2.wav`.
"""
import glob
import hashlib
import io
import json
import os

WORTEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def categorie_van(naam):
    kaal = os.path.splitext(os.path.basename(naam))[0]
    delen = kaal.rsplit("_", 1)
    if len(delen) == 2 and delen[1].isdigit():
        return delen[0]
    return kaal


def _sha1(pad):
    with open(pad, "rb") as f:
        return hashlib.sha1(f.read()).hexdigest()


def _manifest(map_):
    pad = os.path.join(map_, "synthetisch.json")
    try:
        with io.open(pad, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def bestanden(cat, wortel=WORTEL):
    """Alle wav's van deze categorie onder sounds/, als (pad, synthetisch)."""
    uit = []
    for pad in sorted(glob.glob(os.path.join(wortel, "sounds", "**", "*.wav"), recursive=True)):
        if categorie_van(pad) != cat:
            continue
        hash_ = _manifest(os.path.dirname(pad)).get(os.path.basename(pad))
        uit.append((pad, hash_ is not None and hash_ == _sha1(pad)))
    return uit


def heeft_echte_opname(cat, wortel=WORTEL):
    return any(not synth for _pad, synth in bestanden(cat, wortel))


def ruim_op(cat, behalve=(), wortel=WORTEL):
    """Alle placeholders van `cat` weg (wav, .import, manifestregel), behalve de
    paden in `behalve`. Geeft de verwijderde bestandsnamen."""
    houd = {os.path.normcase(os.path.abspath(p)) for p in behalve}
    weg = []
    per_map = {}
    for pad, synth in bestanden(cat, wortel):
        if not synth or os.path.normcase(os.path.abspath(pad)) in houd:
            continue
        os.remove(pad)
        try:
            os.remove(pad + ".import")
        except OSError:
            pass
        weg.append(os.path.basename(pad))
        per_map.setdefault(os.path.dirname(pad), []).append(os.path.basename(pad))
    for map_, namen in per_map.items():
        m = _manifest(map_)
        for n in namen:
            m.pop(n, None)
        with io.open(os.path.join(map_, "synthetisch.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(m, f, indent=1, sort_keys=True)
    return sorted(weg)
