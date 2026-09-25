"""F7.1a: rapport van een campagne-arena-run (docs/F7-campagnetrainer.md).

Gebruik: python tools/campagne/rapport.py results/<run> [results/<run2> ...]

Leest campagnes.jsonl (als die er is) en duels.jsonl uit elke map en print:
- campagnes: winkans per team-naam, rondes, duels, burgeroorlog, testament
  naar de vijand, donaties en wat de kampioen overhield (poolfactor-check:
  masterplan F7.1 wil 10-25% van de pool over bij de kampioen);
- duels: aantal, duur, methode, en de winkans per factiepaar en per
  reserve-verschil (de ruwe stof van het duel-orakel).
"""
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

FACTIES = {0: "varken", 1: "muis", 2: "leeuw", 3: "beer", 4: "wolf", 5: "krokodil"}
PUNTEN = {"inf": 1, "cav": 2, "art": 3}


def lees_jsonl(pad):
    regels = []
    if not pad.exists():
        return regels
    with open(pad, encoding="utf-8-sig") as f:
        for r in f:
            r = r.strip()
            if not r:
                continue
            d = json.loads(r)
            if d.get("run_meta"):
                continue
            regels.append(d)
    return regels


def punten(pool):
    return sum(int(pool.get(k, 0)) * v for k, v in PUNTEN.items())


def rapport_campagnes(camps):
    print(f"\n== Campagnes: {len(camps)} ==")
    if not camps:
        return
    klaar = [c for c in camps if c.get("klaar")]
    print(f"uitgespeeld: {len(klaar)} van {len(camps)}")
    per_naam = defaultdict(lambda: [0, 0])  # naam -> [gewonnen, gespeeld]
    for c in klaar:
        namen = c.get("teams", ["?", "?"])
        for t in (0, 1):
            per_naam[namen[t]][1] += 1
            if int(c.get("winnend_team", -1)) == t:
                per_naam[namen[t]][0] += 1
    print("winkans per team-naam (per campagne speelt elk team een kant):")
    for naam, (w, n) in sorted(per_naam.items()):
        print(f"  {naam:20s} {w:4d}/{n:<4d} = {100.0 * w / max(1, n):5.1f}%")
    def gem(sleutel):
        waarden = [float(c.get(sleutel, 0)) for c in klaar]
        return sum(waarden) / max(1, len(waarden))
    print(f"rondes gem {gem('rondes'):.1f}, duels gem {gem('duels'):.1f}, "
          f"duur gem {gem('ms') / 1000.0:.0f} s per campagne")
    bo = sum(1 for c in klaar if c.get("burgeroorlog"))
    print(f"burgeroorlog in {bo} van {len(klaar)} ({100.0 * bo / max(1, len(klaar)):.0f}%)")
    tv = sum(int(c.get("testament_naar_vijand", 0)) for c in klaar)
    tt = sum(int(c.get("testamenten", 0)) for c in klaar)
    print(f"testamenten {tt}, waarvan naar de vijand {tv} ({100.0 * tv / max(1, tt):.0f}%)")
    print(f"donaties gem {gem('donaties'):.1f} per campagne ({gem('donatie_pt'):.1f} punten), "
          f"ruil gem {gem('ruil'):.1f}")
    print(f"kampioen houdt over: pool gem {gem('kampioen_pool'):.1f} punten, CP gem {gem('kampioen_cp'):.1f}")
    arche = Counter(c.get("winnaar_archetype", "") for c in klaar)
    print("kampioen per archetype: " + ", ".join(f"{a or '?'} {n}" for a, n in arche.most_common()))
    fac = Counter(FACTIES.get(int(c.get("winnaar_doctrine", -1)), "?") for c in klaar)
    print("kampioen per factie:    " + ", ".join(f"{a} {n}" for a, n in fac.most_common()))


def rapport_duels(duels):
    print(f"\n== Duels: {len(duels)} ==")
    if not duels:
        return
    ms = [int(d.get("ms", 0)) for d in duels]
    print(f"duur gem {sum(ms) / len(ms) / 1000.0:.1f} s per duel (max {max(ms) / 1000.0:.0f} s)")
    methodes = Counter(d.get("m", "?") for d in duels)
    print("methode: " + ", ".join(f"{m} {n}" for m, n in methodes.most_common()))
    # Winkans van kant 1 per factiepaar (ongeordend: kant 1 = de eerste factie).
    paar = defaultdict(lambda: [0, 0])
    for d in duels:
        fa, fb = int(d["fa"]), int(d["fb"])
        wint_a = int(d["w"]) == 1
        paar[(fa, fb)][1] += 1
        paar[(fa, fb)][0] += 1 if wint_a else 0
    print("winkans kant 1 per factiepaar (rij = kant 1, kolom = kant 2; aantal tussen haakjes):")
    kop = "            " + "".join(f"{FACTIES[f][:8]:>13s}" for f in range(6))
    print(kop)
    for fa in range(6):
        cellen = []
        for fb in range(6):
            w, n = paar.get((fa, fb), [0, 0])
            cellen.append(f"{(100.0 * w / n if n else 0):5.0f}% ({n:3d})" if n else f"{'-':>13s}")
        print(f"{FACTIES[fa]:>12s}" + "".join(f"{c:>13s}" for c in cellen))
    # Reserve-verschil in punten (kant 1 - kant 2) tegen de winkans van kant 1.
    emmers = defaultdict(lambda: [0, 0])
    for d in duels:
        verschil = punten(d.get("ra", {})) - punten(d.get("rb", {}))
        emmer = max(-4, min(4, round(verschil / 4)))
        emmers[emmer][1] += 1
        emmers[emmer][0] += 1 if int(d["w"]) == 1 else 0
    print("winkans kant 1 per reserve-verschil (punten, emmers van 4):")
    for e in sorted(emmers):
        w, n = emmers[e]
        print(f"  {e * 4:+4d}: {100.0 * w / n:5.1f}% ({n})")
    cp_emmers = defaultdict(lambda: [0, 0])
    for d in duels:
        verschil = int(d.get("cpa", 0)) - int(d.get("cpb", 0))
        emmer = max(-3, min(3, round(verschil / 6)))
        cp_emmers[emmer][1] += 1
        cp_emmers[emmer][0] += 1 if int(d["w"]) == 1 else 0
    print("winkans kant 1 per CP-verschil (emmers van 6):")
    for e in sorted(cp_emmers):
        w, n = cp_emmers[e]
        print(f"  {e * 6:+4d}: {100.0 * w / n:5.1f}% ({n})")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    camps, duels = [], []
    for map_ in sys.argv[1:]:
        m = Path(map_)
        camps += lees_jsonl(m / "campagnes.jsonl")
        duels += lees_jsonl(m / "duels.jsonl")
    rapport_campagnes(camps)
    rapport_duels(duels)
    return 0


if __name__ == "__main__":
    sys.exit(main())
