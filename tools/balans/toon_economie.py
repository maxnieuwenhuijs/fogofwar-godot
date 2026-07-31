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
COMP = {"0": ("Varken", (13, 6, 3)), "1": ("Muis", (18, 4, 0)), "2": ("Leeuw", (6, 10, 2)),
        "3": ("Beer", (16, 3, 3)), "4": ("Wolf", (11, 8, 3)), "5": ("Krokodil", (13, 6, 3))}
KOSTEN = (1, 2, 3)


def toon(pad):
    d = json.load(open(pad, encoding="utf-8"))
    c = d.get("campaign", {})
    factor = float(c.get("start_poolfactor", 0.5))
    potje = float(c.get("potje_factor", 1.0))
    bonus = c.get("budget_bonus", {})
    cp_basis = int(c.get("cp_start", 10))
    print("\n=== %s ===" % os.path.relpath(pad, PROJECT))
    print("start_poolfactor %.2f | potje_factor %.2f | cp_start %d | spawn-cap %s | cycluslimiet %s"
          % (factor, potje, cp_basis, c.get("spawn_totaal_max", "?"),
             d.get("cycle_limit") or "uit"))
    print("%-10s %10s %10s %8s" % ("factie", "reserve", "CP", "bonus"))
    for sleutel in sorted(COMP):
        naam, comp = COMP[sleutel]
        punten = sum(int(math.floor(comp[t] * factor)) * KOSTEN[t] for t in range(3))
        b = bonus.get(sleutel, {}) if isinstance(bonus, dict) else {}
        punten += int(b.get("pt", 0))
        cp = cp_basis + int(b.get("cp", 0))
        print("%-10s %10d %10d %8s" % (naam, round(punten * potje), round(cp * potje),
              ("+%dpt" % b["pt"] if b.get("pt") else "") + ("+%dcp" % b["cp"] if b.get("cp") else "")))


if __name__ == "__main__":
    paden = sys.argv[1:] or [
        os.path.join(PROJECT, "arena", "arena_configs", "rules_v42_campaign.json"),
        os.path.join(PROJECT, "arena", "arena_configs", "v42_default.json")]
    for p in paden:
        toon(p)
