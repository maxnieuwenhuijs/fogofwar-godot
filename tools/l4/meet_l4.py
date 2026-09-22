#!/usr/bin/env python
"""L4 neuraal: hoe doet het netje het tegen L2?

Leest de games.jsonl van een of meer arena-runs (l4_vs_l2.json en
l2_vs_l4.json, of elke run waarin precies een kant "l4" speelt) en print de
winst van L4: totaal, per kleur, per factie van L4 en per tegenstander, met
de foutmarge (1,96 x standaardfout). Afgekapte partijen tellen apart.

  python tools/l4/meet_l4.py results/l4_vs_l2_20260922 results/l2_vs_l4_20260922
"""
import glob
import json
import math
import os
import sys
from collections import defaultdict


def lees_run(pad):
    bestanden = [pad] if os.path.isfile(pad) else sorted(glob.glob(os.path.join(pad, "**", "games.jsonl"), recursive=True))
    # arena.ps1 voegt samen naar <run>/games.jsonl; dan de proc-mappen niet dubbel tellen.
    top = os.path.join(pad, "games.jsonl")
    if os.path.isfile(top):
        bestanden = [top]
    partijen = []
    for b in bestanden:
        l4_kant = None
        with open(b, encoding="utf-8-sig") as f:
            for regel in f:
                regel = regel.strip()
                if not regel:
                    continue
                try:
                    d = json.loads(regel)
                except json.JSONDecodeError:
                    continue  # een regel die nog geschreven wordt (run loopt)
                if d.get("run_meta"):
                    ag = d.get("config", {}).get("agents", {})
                    p1 = str(ag.get("p1", "")).lower().startswith("l4")
                    p2 = str(ag.get("p2", "")).lower().startswith("l4")
                    if p1 == p2:
                        print(f"[MEET] {b}: geen (of twee) l4-kanten in de config, overgeslagen", file=sys.stderr)
                        l4_kant = None
                    else:
                        l4_kant = 1 if p1 else 2
                    continue
                if l4_kant is None:
                    continue
                partijen.append((d, l4_kant))
    return partijen


def marge(w, n):
    if n == 0:
        return 0.0
    p = w / n
    return 1.96 * math.sqrt(p * (1 - p) / n) * 100


def rapport(partijen):
    tot = defaultdict(lambda: [0, 0, 0])  # sleutel -> [winst, n, afgekapt]

    def tel(sleutel, d, kant):
        r = tot[sleutel]
        if d.get("afgekapt"):
            r[2] += 1
            return
        r[1] += 1
        w = d.get("winner", d.get("winnaar", 0))
        if w == kant:
            r[0] += 1

    for d, kant in partijen:
        w = d.get("winner")
        if w is None:
            # metrics.finalize schrijft de winnaar als 'winner'; oudere runs anders
            w = d.get("winnaar", 0)
            d["winner"] = w
        f_l4 = d["d1"] if kant == 1 else d["d2"]
        f_l2 = d["d2"] if kant == 1 else d["d1"]
        tel("TOTAAL", d, kant)
        tel(f"kleur {'rood (p1)' if kant == 1 else 'blauw (p2)'}", d, kant)
        tel(f"L4 als {f_l4}", d, kant)
        tel(f"tegen {f_l2}", d, kant)
        tel(f"methode {d.get('methode', '?')}", d, kant)

    def regel(k):
        w, n, a = tot[k]
        pct = (w / n * 100) if n else float("nan")
        extra = f", {a} afgekapt" if a else ""
        return f"  {k:<22} {w:4d}/{n:<4d} {pct:5.1f}% +-{marge(w, n):4.1f}{extra}"

    print("[MEET] winst van L4 tegen L2")
    print(regel("TOTAAL"))
    for k in sorted(tot):
        if k.startswith("kleur"):
            print(regel(k))
    print("[MEET] per factie van L4")
    for k in sorted(tot):
        if k.startswith("L4 als"):
            print(regel(k))
    print("[MEET] per tegenstander")
    for k in sorted(tot):
        if k.startswith("tegen"):
            print(regel(k))
    print("[MEET] per uitslagmethode (hoe vaak L4 wint als de partij zo eindigt)")
    for k in sorted(tot):
        if k.startswith("methode"):
            print(regel(k))


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    partijen = []
    for p in sys.argv[1:]:
        partijen += lees_run(p)
    if not partijen:
        print("[MEET] geen partijen gevonden", file=sys.stderr)
        sys.exit(1)
    print(f"[MEET] {len(partijen)} partijen uit {len(sys.argv) - 1} run(s)")
    rapport(partijen)


if __name__ == "__main__":
    main()
