"""F7.1b: het duel-orakel bouwen uit gemeten campagne-duels (docs/F7-campagnetrainer.md).

Gebruik:
    python tools/campagne/maak_orakel.py results/<run> [results/<run2> ...]
        [--uit data/duel_orakel.json] [--geen-spiegel] [--controle 0.2]

Leest duels.jsonl uit elke map (de datarun `campagne_arena.ps1` met
campagne_duels.json, en ook echte campagnes) en schrijft een compact bestand
dat `DuelOrakel` (scripts/training/duel_orakel.gd) inleest. Het orakel is
geen model maar een verzameling echt gespeelde duels: voor een nieuw duel
trekt het een duel uit hetzelfde factiepaar met ongeveer hetzelfde
reserve- en CP-verschil. Zo geeft het nooit iets terug dat niet ooit zo
gebeurd is.

Spiegelen (standaard aan): elk duel telt ook met de kanten omgedraaid, want
de campagne zet de vechters willekeurig op kant 1 of 2 en de initiatiefloting
in het duel maakt de kanten gelijk. --geen-spiegel zet dat uit.

Controle: een deel van de campagnes/seeds (--controle, standaard 0,2) blijft
buiten het orakel; daarop meet het script hoe goed het orakel de winkans
voorspelt (Brier-score, en per voorspelde kans hoe vaak het echt zo afliep),
naast een simpel model dat alleen het factiepaar kent. Het orakel moet beter
zijn dan dat simpele model; anders weet het niets van reserve en CP.
"""
import argparse
import json
import math
import random
import sys
from collections import defaultdict
from pathlib import Path

PUNTEN = {"inf": 1, "cav": 2, "art": 3}
RES_STAP = 3     # emmer voor het reserve-verschil (punten)
RES_MAX = 15
CP_STAP = 6      # emmer voor het CP-verschil
CP_MAX = 24
TYPEN = ("inf", "cav", "art")


def punten(pool):
    return sum(int(pool.get(k, 0)) * v for k, v in PUNTEN.items())


def emmer(verschil, stap, maximum):
    # floor(x + 0,5) en niet round(): Python rondt 0,5 af naar even, GDScript
    # weg van nul. Zo kiezen script en DuelOrakel dezelfde emmer.
    v = max(-maximum, min(maximum, verschil))
    return int(math.floor(v / stap + 0.5))


def lees(mappen):
    duels = []
    for m in mappen:
        pad = Path(m) / "duels.jsonl"
        if not pad.exists():
            print(f"[ORAKEL] geen duels.jsonl in {m}", file=sys.stderr)
            continue
        with open(pad, encoding="utf-8-sig") as f:
            for r in f:
                r = r.strip()
                if not r:
                    continue
                d = json.loads(r)
                if d.get("run_meta"):
                    continue
                if int(d.get("w", -1)) not in (1, 2):
                    continue
                d["_bron"] = str(m)
                duels.append(d)
    return duels


def kant(d, k):
    """De velden van kant k ("1" of "2") als (factie, reserve, cp, inzet, cpd, buit, verl)."""
    if k == "1":
        return int(d["fa"]), d.get("ra", {}), int(d.get("cpa", 0))
    return int(d["fb"]), d.get("rb", {}), int(d.get("cpb", 0))


def compact(d, spiegel):
    """Een duel als platte rij, eventueel met de kanten omgedraaid.

    Rij: [fa, fb, res_a, res_b, cp_a, cp_b, winnaar(1/2), methode, cycli,
          inzet_a(3), inzet_b(3), cpd_a, cpd_b, buit_a, buit_b, verl_a(3), verl_b(3)]
    Reserves in punten, inzet en verliezen per type (inf, cav, art).
    """
    a, b = ("2", "1") if spiegel else ("1", "2")
    fa, ra, cpa = kant(d, a)
    fb, rb, cpb = kant(d, b)
    w = int(d["w"])
    if spiegel:
        w = 3 - w
    inzet = d.get("inzet", {}) or {}
    cpd = d.get("cpd", {}) or {}
    buit = d.get("buit", {}) or {}
    verl = d.get("verl", {}) or {}
    rij = [fa, fb, punten(ra), punten(rb), cpa, cpb, w, d.get("m", "eliminatie"), int(d.get("cycli", 0))]
    for k in (a, b):
        rij += [int((inzet.get(k) or {}).get(t, 0)) for t in TYPEN]
    rij += [int(cpd.get(a, 0)), int(cpd.get(b, 0)), int(buit.get(a, 0)), int(buit.get(b, 0))]
    for k in (a, b):
        rij += [int((verl.get(k) or {}).get(t, 0)) for t in TYPEN]
    # De reserve per type ook mee (de inzet schaalt daarop).
    rij += [int(ra.get(t, 0)) for t in TYPEN] + [int(rb.get(t, 0)) for t in TYPEN]
    return rij


def sleutel(rij):
    return (rij[0], rij[1], emmer(rij[2] - rij[3], RES_STAP, RES_MAX), emmer(rij[4] - rij[5], CP_STAP, CP_MAX))


def kans_orakel(index, rijen, fa, fb, dres, dcp, min_n=8):
    """Winkans kant 1 volgens het orakel: dezelfde zoekregel als DuelOrakel.kandidaten."""
    kand = kandidaten(index, fa, fb, dres, dcp, min_n)
    if not kand:
        return 0.5
    return sum(1 for i in kand if rijen[i][6] == 1) / len(kand)


def kandidaten(index, fa, fb, dres, dcp, min_n=8):
    """Zelfde factiepaar, eerst dezelfde emmer, dan steeds wijder (Manhattan in emmers)."""
    br, bc = emmer(dres, RES_STAP, RES_MAX), emmer(dcp, CP_STAP, CP_MAX)
    paar = index.get((fa, fb), {})
    uit = []
    for straal in range(0, 21):  # twee emmers liggen hooguit 10 + 8 stappen uit elkaar
        for (er, ec), lijst in paar.items():
            if abs(er - br) + abs(ec - bc) == straal:
                uit.extend(lijst)
        if len(uit) >= min_n:
            return uit
    return uit


def bouw_index(rijen):
    index = defaultdict(lambda: defaultdict(list))
    for i, rij in enumerate(rijen):
        s = sleutel(rij)
        index[(s[0], s[1])][(s[2], s[3])].append(i)
    return index


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mappen", nargs="+")
    ap.add_argument("--uit", default="data/duel_orakel.json")
    ap.add_argument("--geen-spiegel", action="store_true")
    ap.add_argument("--controle", type=float, default=0.2)
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args()

    duels = lees(args.mappen)
    if not duels:
        print("[ORAKEL] geen duels gevonden")
        return 1
    ai = sorted({d.get("ai", "?") for d in duels})
    honger = sorted({int(d.get("honger", 0)) for d in duels})
    if len(ai) > 1 or len(honger) > 1:
        print(f"[ORAKEL] LET OP: gemengde data (ai {ai}, honger {honger}); het orakel meet dan een mengsel")

    # Controle-set op duel-seed (of campagne-seed): nooit hetzelfde duel in beide.
    rng = random.Random(args.seed)
    def groep(d):
        return (d["_bron"], d.get("campagne", d.get("seed", id(d))))
    groepen = sorted({groep(d) for d in duels}, key=str)
    rng.shuffle(groepen)
    n_controle = int(len(groepen) * args.controle)
    controle_groepen = set(groepen[:n_controle])
    leer = [d for d in duels if groep(d) not in controle_groepen]
    controle = [d for d in duels if groep(d) in controle_groepen]

    def rijen_van(lijst):
        uit = [compact(d, False) for d in lijst]
        if not args.geen_spiegel:
            uit += [compact(d, True) for d in lijst]
        return uit

    leer_rijen = rijen_van(leer)
    index = bouw_index(leer_rijen)

    # Controle: Brier-score van het orakel tegen een model dat alleen het paar kent.
    paar_w = defaultdict(lambda: [0, 0])
    for rij in leer_rijen:
        paar_w[(rij[0], rij[1])][1] += 1
        paar_w[(rij[0], rij[1])][0] += 1 if rij[6] == 1 else 0
    if controle:
        brier_o = brier_p = 0.0
        ijk = defaultdict(lambda: [0, 0])
        for d in controle:
            rij = compact(d, False)
            echt = 1.0 if rij[6] == 1 else 0.0
            p_o = kans_orakel(index, leer_rijen, rij[0], rij[1], rij[2] - rij[3], rij[4] - rij[5])
            w, n = paar_w.get((rij[0], rij[1]), [0, 0])
            p_p = w / n if n else 0.5
            brier_o += (p_o - echt) ** 2
            brier_p += (p_p - echt) ** 2
            e = min(9, int(p_o * 10))
            ijk[e][0] += echt
            ijk[e][1] += 1
        n = len(controle)
        print(f"[ORAKEL] controle op {n} duels: Brier orakel {brier_o / n:.4f}, "
              f"alleen factiepaar {brier_p / n:.4f} (lager is beter)")
        print("[ORAKEL] ijking (voorspelde winkans -> echt gewonnen):")
        for e in sorted(ijk):
            w, m = ijk[e]
            print(f"   {e * 10:3d}-{e * 10 + 9:3d}%: {100.0 * w / m:5.1f}% van {m}")
    else:
        print("[ORAKEL] geen controle-set (te weinig data of --controle 0)")

    # Het orakel zelf: ALLE data (leer + controle), gespiegeld.
    alle_rijen = rijen_van(duels)
    per_paar = defaultdict(int)
    for rij in alle_rijen:
        per_paar[(rij[0], rij[1])] += 1
    dun = [p for p in ((a, b) for a in range(6) for b in range(6)) if per_paar.get(p, 0) < 30]
    uit = {
        "versie": 1,
        "velden": ["fa", "fb", "res_a", "res_b", "cp_a", "cp_b", "w", "m", "cycli",
                   "inzet_a_inf", "inzet_a_cav", "inzet_a_art", "inzet_b_inf", "inzet_b_cav", "inzet_b_art",
                   "cpd_a", "cpd_b", "buit_a", "buit_b",
                   "verl_a_inf", "verl_a_cav", "verl_a_art", "verl_b_inf", "verl_b_cav", "verl_b_art",
                   "ra_inf", "ra_cav", "ra_art", "rb_inf", "rb_cav", "rb_art"],
        "emmers": {"res_stap": RES_STAP, "res_max": RES_MAX, "cp_stap": CP_STAP, "cp_max": CP_MAX},
        "ai": ai,
        "honger": honger,
        "gespiegeld": not args.geen_spiegel,
        "duels": len(duels),
        "bronnen": sorted({d["_bron"] for d in duels}),
        "rijen": alle_rijen,
    }
    Path(args.uit).parent.mkdir(parents=True, exist_ok=True)
    with open(args.uit, "w", encoding="utf-8", newline="\n") as f:
        json.dump(uit, f, separators=(",", ":"))
    print(f"[ORAKEL] {len(duels)} duels ({len(alle_rijen)} rijen) -> {args.uit}")
    if dun:
        namen = ["varken", "muis", "leeuw", "beer", "wolf", "krokodil"]
        print(f"[ORAKEL] dun bezette paren (<30 rijen): {len(dun)} van 36, bv. "
              + ", ".join(f"{namen[a]}-{namen[b]} ({per_paar.get((a, b), 0)})" for a, b in dun[:6]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
