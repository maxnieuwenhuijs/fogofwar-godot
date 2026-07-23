#!/usr/bin/env python3
"""F1.6 — vergelijk twee arena-runs (referentie vs sweep) op de console.

Gebruik:  python tools/dashboard/compare_runs.py results/sweep_ref results/sweep_statue2
Toont winrate-delta per doctrine, methode-verdeling en de sweep-metrieken
(standbeeld-kills per profiel, herhalingen, kanonnen-zonder-schot).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_dashboard import lees_runs, winrates_per_doctrine, agg_metrieken  # noqa: E402


def laad_run(map_pad: str):
    p = Path(map_pad)
    runs = lees_runs(p.parent)
    for r in runs:
        if r["naam"] == p.name:
            return r
    sys.exit(f"run niet gevonden: {map_pad}")


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    a, b = laad_run(sys.argv[1]), laad_run(sys.argv[2])
    wa, _ = winrates_per_doctrine(a["games"])
    wb, _ = winrates_per_doctrine(b["games"])
    ma, mb = agg_metrieken(a["games"]), agg_metrieken(b["games"])
    ra = (a["meta"] or {}).get("rules_version", "?")
    rb = (b["meta"] or {}).get("rules_version", "?")
    print(f"A = {a['naam']} ({ra}, {ma['totaal']} partijen)")
    print(f"B = {b['naam']} ({rb}, {mb['totaal']} partijen)\n")
    print(f"{'doctrine':<12} {'A%':>6} {'B%':>6} {'delta':>7}")
    for d in sorted(set(wa) | set(wb)):
        va, vb = wa.get(d, 0.0), wb.get(d, 0.0)
        print(f"{d:<12} {va:>6.1f} {vb:>6.1f} {vb - va:>+7.1f}")
    print("\nmethodes A:", ma["methode"], "| B:", mb["methode"])
    print(f"gem. cycli      A {ma['gem_cycli']:.1f} | B {mb['gem_cycli']:.1f}")
    print(f"herhalingen     A {ma['gem_repetitions']:.1f} | B {mb['gem_repetitions']:.1f}")
    print(f"kanon-stil-%    A {ma['kanon_zonder_schot_pct']:.1f} | B {mb['kanon_zonder_schot_pct']:.1f}")
    top = lambda m: dict(list(m["statue_kills"].items())[:5])
    print("statue-kills    A", top(ma), "| B", top(mb))


if __name__ == "__main__":
    main()
