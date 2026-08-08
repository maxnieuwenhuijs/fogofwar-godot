"""Laat zien wat de economie per factie oplevert onder een regels-json.

Eén regelset (C17): de campagne is de bron, een los potje is dezelfde formule
maal `potje_factor`. Dit scriptje rekent dat voor, zodat je in één oogopslag
ziet wat een speler krijgt.

    python tools/balans/toon_economie.py [pad-naar-regels.json ...]
"""
import json
import math
import os
import sys

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# De KALE tabel uit `scripts/core/constants.gd`, in doctrine-volgorde. Ligt er in
# de regels-json een `doctrines`-blok, dan gaat dat hieroverheen -- precies zoals
# het spel het doet. Zonder die overlay rekende dit scriptje sinds C19 (8
# augustus) met legers die niemand meer opstelt.
KALE_COMP = {"0": ("Varken", (13, 6, 3)), "1": ("Muis", (18, 4, 0)), "2": ("Leeuw", (6, 10, 2)),
             "3": ("Beer", (16, 3, 3)), "4": ("Wolf", (11, 8, 3)), "5": ("Krokodil", (13, 6, 3))}
KOSTEN = (1, 2, 3)


def facties_bestand():
    """Het doctrines-blok uit de campagne-regels (CRules.REGELS_BESTAND)."""
    pad = os.path.join(PROJECT, "arena", "arena_configs", "rules_v42_campaign.json")
    try:
        return (json.load(open(pad, encoding="utf-8")) or {}).get("doctrines") or {}
    except (OSError, ValueError):
        return {}


def comps_van(d):
    """Naam + comp per factie, met het doctrines-blok uit deze json eroverheen.

    Staat er geen blok in dit bestand, dan pakken we dat van de campagne-regels.
    Dat is precies wat `game.gd` doet voor een los potje: het laadt
    `v42_default.json` (dat bewust geen facties draagt) en legt er
    `CRules.facties_uit_bestand()` overheen, zodat een los duel dezelfde dieren
    speelt als de campagne.
    """
    blok = d.get("doctrines") or facties_bestand()
    uit = {}
    for sleutel, (naam, comp) in KALE_COMP.items():
        ov = blok.get(sleutel) or {}
        uit[sleutel] = (naam, tuple(int(n) for n in ov.get("comp", comp)), bool(ov))
    return uit


def toon(pad):
    d = json.load(open(pad, encoding="utf-8"))
    c = d.get("campaign", {})
    factor = float(c.get("start_poolfactor", 0.5))
    potje = float(c.get("potje_factor", 1.0))
    bonus = c.get("budget_bonus", {})
    cp_basis = int(c.get("cp_start", 10))
    honger = d.get("honger_vanaf_cyclus")
    print("\n=== %s ===" % os.path.relpath(pad, PROJECT))
    print("start_poolfactor %.2f | potje_factor %.2f | cp_start %d | spawn-cap %s | honger vanaf %s"
          % (factor, potje, cp_basis, c.get("spawn_totaal_max", "?"),
             ("cyclus %s" % honger) if honger else "uit"))
    comps = comps_van(d)
    print("%-10s %-12s %10s %10s %8s" % ("factie", "leger", "reserve", "CP", "bonus"))
    for sleutel in sorted(comps):
        naam, comp, afwijkend = comps[sleutel]
        punten = sum(int(math.floor(comp[t] * factor)) * KOSTEN[t] for t in range(3))
        b = bonus.get(sleutel, {}) if isinstance(bonus, dict) else {}
        punten += int(b.get("pt", 0))
        cp = cp_basis + int(b.get("cp", 0))
        leger = "%d/%d/%d%s" % (comp[0], comp[1], comp[2], " *" if afwijkend else "")
        print("%-10s %-12s %10d %10d %8s" % (naam, leger, round(punten * potje), round(cp * potje),
              ("+%dpt" % b["pt"] if b.get("pt") else "") + ("+%dcp" % b["cp"] if b.get("cp") else "")))
    if any(a for _, _, a in comps.values()):
        bron = "dit bestand" if d.get("doctrines") else "rules_v42_campaign.json"
        print("(* = uit het doctrines-blok van %s, niet uit constants.gd)" % bron)


if __name__ == "__main__":
    paden = sys.argv[1:] or [
        os.path.join(PROJECT, "arena", "arena_configs", "rules_v42_campaign.json"),
        os.path.join(PROJECT, "arena", "arena_configs", "v42_default.json")]
    for p in paden:
        toon(p)
