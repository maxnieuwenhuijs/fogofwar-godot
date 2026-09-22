"""Welke factie staat in deze arena-run het VERST van 50%?

Print eerst de winrates als tabel (stderr-achtige regels) en als LAATSTE regel
het enum-nummer van de uitschieter, zodat een script hem zo kan doorgeven aan
`factiezoeker.py --facties <n>`.

    python tools/balans/verste_factie.py results/<run>/games.jsonl

Een winrate telt beide kanten mee (rij wint als speler 1 en als speler 2), net
als de nachtmatrix en `compare_runs.py`. Spiegelpartijen (Leeuw tegen Leeuw)
staan per definitie op 50% en trekken de uitslag dus naar het midden; dat is
voor deze keuze geen probleem, elke factie heeft er evenveel.
"""
from __future__ import annotations

import collections
import json
import sys
from pathlib import Path

ENUM = {"Varken": 0, "Muis": 1, "Leeuw": 2, "Beer": 3, "Wolf": 4, "Krokodil": 5}


def winrates(pad: Path) -> dict:
    tally = collections.defaultdict(lambda: [0, 0])
    for regel in pad.open(encoding="utf-8-sig"):
        regel = regel.strip()
        if not regel:
            continue
        g = json.loads(regel)
        if g.get("run_meta"):
            continue
        winnaar = g.get("winner")
        for mij, kant in ((g["d1"], 1), (g["d2"], 2)):
            tally[mij][1] += 1
            if winnaar == kant:
                tally[mij][0] += 1
    return {d: 100.0 * w / n for d, (w, n) in tally.items() if n}


def main(argv: list[str]) -> int:
    if not argv:
        sys.exit(__doc__)
    pad = Path(argv[0])
    if not pad.is_absolute():
        pad = Path(__file__).resolve().parents[2] / pad
    if not pad.exists():
        sys.exit("bestand niet gevonden: %s" % pad)
    wr = winrates(pad)
    if not wr:
        sys.exit("geen partijen in %s" % pad)
    for naam, pct in sorted(wr.items(), key=lambda kv: -abs(kv[1] - 50.0)):
        print("%-9s %5.1f%%  (%+.1f van 50)" % (naam, pct, pct - 50.0), file=sys.stderr)
    verste = max(wr, key=lambda d: abs(wr[d] - 50.0))
    print(ENUM.get(verste, 0))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
