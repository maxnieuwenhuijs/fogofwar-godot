"""F6.0-P4: puntenbots naast elkaar (docs/F6-punten-masterplan.md §8).

Gebruik: python tools/campagne/punten_rapport.py results/punten_<stempel> [--uit rapport.md]

Leest in die map elke submap meet_<naam>/campagnes.jsonl (een meting met op
alle stoelen hetzelfde verstand: hand, team, k1, k2, k3) en train_<naam>/train.log
(de puntentrainer van die tabel), en zet per verstand naast elkaar:

- donaties per donatieronde (versterkingspunten: soldaat 1, ruiter 2, kanon 3)
- hoe vaak er een burgeroorlog komt, met hoeveel spelers
- hoe vaak de raad de roemleider van het team stuurt, en in een slechte matchup
  (winkans onder de 40% volgens het orakel)
- testament naar de vijand, teamwinst links en rechts, lengte van de campagne
- de punten: gemiddeld per stoel, van de kampioen en van het verliezende team

en toetst de doelen uit §8 tegen de meting "team" (bots die alleen op
teamwinst trainden): donaties minstens 60% daarvan, campagnes hooguit 20%
langer. De burgeroorlog (hoe vaak, met hoeveel) staat erbij als informatie,
niet als eis (Max, 30 september: "hangt toch gewoon af van het verloop").
"""
import json
import re
import sys
from pathlib import Path

VOLGORDE = ["hand", "team", "k1", "k2", "k3"]


def lees_jsonl(pad):
    meta, regels = {}, []
    if not pad.exists():
        return meta, regels
    with open(pad, encoding="utf-8-sig") as f:
        for r in f:
            r = r.strip()
            if not r:
                continue
            d = json.loads(r)
            if d.get("run_meta"):
                meta = d
                continue
            regels.append(d)
    return meta, regels


def meet(camps):
    klaar = [c for c in camps if c.get("klaar")]
    n = len(klaar)
    if n == 0:
        return None
    som = lambda k: sum(float(c.get(k, 0)) for c in klaar)
    bo = [c for c in klaar if c.get("burgeroorlog")]
    bo_spelers = [int(c.get("burgeroorlog_spelers", 0)) for c in bo]
    nom = som("nominaties")
    leider = som("leider_gestuurd")
    tt = som("testamenten")
    punten_stoel, punten_kampioen, punten_verliezer = [], [], []
    for c in klaar:
        p = c.get("punten", {})
        if not p:
            continue
        punten_stoel += [int(v) for v in p.values()]
        punten_kampioen.append(int(p.get(str(c.get("winnaar")), 0)))
        # Het verliezende team: stoelen 0-7 zijn team 0, 8-15 team 1.
        helft = len(p) // 2
        verliezer = 1 - int(c.get("winnend_team", 0))
        punten_verliezer += [int(p[str(i)]) for i in range(verliezer * helft, (verliezer + 1) * helft)
                             if str(i) in p]
    gem = lambda xs: sum(xs) / len(xs) if xs else 0.0
    return {
        "n": n,
        "don_ronde": som("donatie_pt") / max(1.0, som("donatie_rondes")),
        "don_campagne": som("donatie_pt") / n,
        "bo": len(bo) / n,
        "bo_spelers": gem(bo_spelers),
        "bo_3plus": sum(1 for s in bo_spelers if s >= 3) / max(1, len(bo_spelers)),
        "leider": leider / max(1.0, nom),
        "leider_slecht": som("leider_slecht") / max(1.0, leider),
        "slecht": som("slecht_gestuurd") / max(1.0, nom),
        "raad_gemeten": nom > 0,
        "test_vijand": som("testament_naar_vijand") / max(1.0, tt),
        "team0": sum(1 for c in klaar if int(c.get("winnend_team", -1)) == 0) / n,
        "rondes": som("rondes") / n,
        "lp_stoel": gem(punten_stoel),
        "lp_kampioen": gem(punten_kampioen),
        "lp_verliezer": gem(punten_verliezer),
    }


def train_samenvatting(pad):
    """Adopties, laatste check en de kampioen uit een train.log."""
    if not pad.exists():
        return None
    regels = pad.read_text(encoding="utf-8", errors="replace").splitlines()
    adopties = sum(1 for r in regels if "-> ADOPTIE" in r)
    generaties = sum(1 for r in regels if re.match(r"\[TRAIN\] gen \d+:", r))
    check = [r for r in regels if r.startswith("[TRAIN] check gen")]
    # De laatste kampioen: bij de start, na elke adoptie, en aan het eind.
    kampioen = ""
    for r in regels:
        for patroon in (r"kampioen bij de start: (\{.*?\})", r"-> ADOPTIE (\{.*?\})", r"klaar: .*kampioen (\{.*?\})"):
            m = re.search(patroon, r)
            if m:
                kampioen = m.group(1)
    return {"generaties": generaties, "adopties": adopties,
            "check": check[-1].replace("[TRAIN] ", "") if check else "", "kampioen": kampioen}


def pct(x):
    return f"{100.0 * x:.0f}%"


def main():
    args = sys.argv[1:]
    uit = None
    if "--uit" in args:
        i = args.index("--uit")
        uit = Path(args[i + 1])
        del args[i:i + 2]
    if not args:
        print(__doc__)
        return 1
    basis = Path(args[0])
    uit = uit or basis / "rapport.md"
    namen = [p.name[len("meet_"):] for p in sorted(basis.glob("meet_*")) if p.is_dir()]
    namen.sort(key=lambda n: (VOLGORDE.index(n) if n in VOLGORDE else 99, n))
    metingen, tabellen = {}, {}
    for naam in namen:
        meta, camps = lees_jsonl(basis / f"meet_{naam}" / "campagnes.jsonl")
        m = meet(camps)
        if m:
            metingen[naam] = m
            tabellen[naam] = (meta.get("config") or {}).get("tabel", {})
    if not metingen:
        print(f"geen metingen in {basis}/meet_*/campagnes.jsonl")
        return 1
    rijen = [
        ("campagnes", lambda m: f"{m['n']}"),
        ("kampioen krijgt", lambda m: ""),
        ("donaties per donatieronde (punten)", lambda m: f"{m['don_ronde']:.1f}"),
        ("donaties per campagne (punten)", lambda m: f"{m['don_campagne']:.1f}"),
        ("burgeroorlog", lambda m: pct(m["bo"])),
        ("spelers in de burgeroorlog (gem)", lambda m: f"{m['bo_spelers']:.1f}"),
        ("burgeroorlog met 3 of meer", lambda m: pct(m["bo_3plus"])),
        ("raad stuurt de roemleider", lambda m: pct(m["leider"]) if m["raad_gemeten"] else "-"),
        ("  daarvan in een slechte matchup", lambda m: pct(m["leider_slecht"]) if m["raad_gemeten"] else "-"),
        ("raad stuurt iemand in een slechte matchup", lambda m: pct(m["slecht"]) if m["raad_gemeten"] else "-"),
        ("testament naar de vijand", lambda m: pct(m["test_vijand"])),
        ("teamwinst links (team 0)", lambda m: pct(m["team0"])),
        ("rondes (gem)", lambda m: f"{m['rondes']:.1f}"),
        ("punten per stoel (gem)", lambda m: f"{m['lp_stoel']:.1f}"),
        ("punten van de kampioen (gem)", lambda m: f"{m['lp_kampioen']:.1f}"),
        ("punten verliezend team (gem)", lambda m: f"{m['lp_verliezer']:.1f}"),
    ]
    kop = ["meting"] + list(metingen)
    tabel = []
    for label, f in rijen:
        if label == "kampioen krijgt":
            tabel.append([label] + [str(int(tabellen[n].get("kampioen", 40))) for n in metingen])
        else:
            tabel.append([label] + [f(metingen[n]) for n in metingen])
    breed = [max(len(r[i]) for r in [kop] + tabel) for i in range(len(kop))]
    regels = ["# F6.0-P4: puntenbots naast elkaar", "",
              f"Map: `{basis.as_posix()}`. Elke meting: alle stoelen hetzelfde verstand, duels uit het orakel.", "",
              "| " + " | ".join(k.ljust(breed[i]) for i, k in enumerate(kop)) + " |",
              "|" + "|".join("-" * (b + 2) for b in breed) + "|"]
    for r in tabel:
        regels.append("| " + " | ".join(c.ljust(breed[i]) for i, c in enumerate(r)) + " |")
    # De doelen uit §8, tegen de meting "team".
    regels += ["", "## Doelen uit het plan (hoofdstuk 8)", ""]
    if "team" in metingen:
        t = metingen["team"]
        for naam in metingen:
            if not naam.startswith("k"):
                continue
            m = metingen[naam]
            don = m["don_ronde"] / t["don_ronde"] if t["don_ronde"] > 0 else 0.0
            lengte = m["rondes"] / t["rondes"] - 1.0 if t["rondes"] > 0 else 0.0
            doelen = [
                (f"donaties {pct(don)} van team", don >= 0.6),
                (f"lengte {lengte * 100.0:+.0f}%", lengte <= 0.2),
            ]
            regels.append(f"- **{naam}** (kampioen {int(tabellen[naam].get('kampioen', 40))}): " + ", ".join(
                f"{tekst} {'ok' if ok else 'NIET'}" for tekst, ok in doelen)
                + f"; ter info: burgeroorlog {pct(m['bo'])}, met 3 of meer {pct(m['bo_3plus'])}")
        if not any(n.startswith("k") for n in metingen):
            regels.append("Nog geen meting van een puntentabel (k1, k2, k3).")
    else:
        regels.append("Geen meting `team`: de doelen zijn relatief, dus niet getoetst.")
    # De trainers.
    trainers = sorted(p for p in basis.glob("train_*") if p.is_dir())
    if trainers:
        regels += ["", "## Trainers", ""]
        for p in trainers:
            s = train_samenvatting(p / "train.log")
            if not s:
                continue
            regels.append(f"- **{p.name[len('train_'):]}**: {s['generaties']} generaties, {s['adopties']} adopties, "
                          f"kampioen `{s['kampioen']}`")
            if s["check"]:
                regels.append(f"  - {s['check']}")
    tekst = "\n".join(regels) + "\n"
    print(tekst)
    uit.write_text(tekst, encoding="utf-8")
    print(f"-> {uit}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
