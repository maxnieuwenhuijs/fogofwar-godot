"""Zet de C11-startcompensatie (`budget_bonus`) van een factie op DRIE plekken
tegelijk, want anders dan het doctrines-blok wordt hij niet uit het
regels-bestand gelezen (CLAUDE.md, kernregels C19/C11):

  1. `core/campaign/crules.gd`        -> CRules.budget_bonus (de campagnelaag)
  2. `arena/arena_configs/rules_v42_campaign.json` -> campaign.budget_bonus
  3. `arena/arena_configs/v42_default.json`        -> campaign.budget_bonus

`CampaignTests.test_c19_budget_bonus_overal_gelijk` bewaakt dat ze gelijk
blijven, dus met de hand een van de drie aanpassen breekt de testsuite.

    python tools/balans/zet_budget_bonus.py leeuw --pt 2 [--cp 0] [--droogloop]

Facties op naam (varken/muis/leeuw/beer/wolf/krokodil) of op enum-nummer.
`--pt 0 --cp 0` haalt de factie weer uit de tabel. Dit is een REGELWIJZIGING:
daarna goldens (`-- makegoldens`), `golden_sims.json` opnieuw ijken, de
testsuite, `-- facties` voor en na, een CHANGELOG-entry en een versie-bump.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

WORTEL = Path(__file__).resolve().parents[2]
CRULES = WORTEL / "core" / "campaign" / "crules.gd"
CONFIGS = [
    WORTEL / "arena" / "arena_configs" / "rules_v42_campaign.json",
    WORTEL / "arena" / "arena_configs" / "v42_default.json",
]
FACTIES = {"varken": 0, "mens": 0, "muis": 1, "leeuw": 2, "beer": 3, "wolf": 4,
           "krokodil": 5, "vos": 5}


def enum_van(naam: str) -> int:
    sleutel = naam.strip().lower()
    if sleutel in FACTIES:
        return FACTIES[sleutel]
    if sleutel.isdigit() and 0 <= int(sleutel) <= 5:
        return int(sleutel)
    sys.exit("onbekende factie: %s (kies uit %s)" % (naam, ", ".join(sorted(FACTIES))))


NAAM = {"0": "Varken", "1": "Muis", "2": "Leeuw", "3": "Beer", "4": "Wolf", "5": "Krokodil"}


def lees_crules() -> tuple[str, dict, dict]:
    tekst = CRULES.read_text(encoding="utf-8")
    m = re.search(r"var budget_bonus: Dictionary = \{(.*?)\n\}", tekst, re.S)
    if not m:
        sys.exit("budget_bonus-blok niet gevonden in crules.gd")
    huidig, notitie = {}, {}
    for regel in m.group(1).splitlines():
        rij = re.search(r'"(\d+)":\s*\{"pt":\s*(-?\d+),\s*"cp":\s*(-?\d+)\}', regel)
        if not rij:
            continue
        huidig[rij.group(1)] = {"pt": int(rij.group(2)), "cp": int(rij.group(3))}
        staart = regel.split("#", 1)
        if len(staart) > 1:
            notitie[rij.group(1)] = staart[1].strip()
    return tekst, huidig, notitie


def schrijf_crules(tekst: str, tabel: dict, droogloop: bool, notitie: dict) -> None:
    # Het commentaar achter elke regel (welk dier, welk besluit) blijft staan;
    # een nieuwe regel krijgt de naam plus de reden die de aanroeper meegeeft.
    regels = "\n".join(
        '\t"%s": {"pt": %d, "cp": %d},    # %s' % (
            k, tabel[k]["pt"], tabel[k]["cp"], notitie.get(k, NAAM.get(k, "?")))
        for k in sorted(tabel, key=int)
    )
    nieuw = re.sub(r"(var budget_bonus: Dictionary = \{)(.*?)(\n\})",
                   lambda m: m.group(1) + "\n" + regels + m.group(3), tekst, count=1, flags=re.S)
    if not droogloop:
        CRULES.write_text(nieuw, encoding="utf-8", newline="\n")


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("factie")
    p.add_argument("--pt", type=int, required=True, help="startpunten erbij")
    p.add_argument("--cp", type=int, default=0, help="start-CP erbij (Wolf heeft er 4)")
    p.add_argument("--reden", default="", help="komt als commentaar achter de nieuwe regel in crules.gd")
    p.add_argument("--droogloop", action="store_true")
    args = p.parse_args(argv)
    sleutel = str(enum_van(args.factie))

    tekst, tabel, notitie = lees_crules()
    was = tabel.get(sleutel, {"pt": 0, "cp": 0})
    if args.pt == 0 and args.cp == 0:
        tabel.pop(sleutel, None)
        notitie.pop(sleutel, None)
    else:
        tabel[sleutel] = {"pt": args.pt, "cp": args.cp}
        notitie.setdefault(sleutel, NAAM.get(sleutel, "?") + (" (%s)" % args.reden if args.reden else ""))
    print("crules.gd: %s %s -> %s" % (NAAM.get(sleutel, sleutel), was, tabel.get(sleutel, "(weg)")))
    schrijf_crules(tekst, tabel, args.droogloop, notitie)

    for pad in CONFIGS:
        data = json.loads(pad.read_text(encoding="utf-8-sig"))
        blok = data.setdefault("campaign", {}).setdefault("budget_bonus", {})
        if args.pt == 0 and args.cp == 0:
            blok.pop(sleutel, None)
        else:
            blok[sleutel] = {"cp": args.cp, "pt": args.pt}
        print("%s: %s" % (pad.relative_to(WORTEL).as_posix(), json.dumps(blok, sort_keys=True)))
        if not args.droogloop:
            pad.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n",
                           encoding="utf-8", newline="\n")
    if args.droogloop:
        print("droogloop: niets geschreven")
    else:
        print("geschreven. Nu: testsuite, `-- facties`, `-- makegoldens`, golden_sims opnieuw ijken, CHANGELOG.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
