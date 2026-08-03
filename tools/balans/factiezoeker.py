"""Factiezoeker: zoekt een betere balans in de FACTIE-EIGENSCHAPPEN.

Drie zoekers, drie verschillende vragen:

  trainer (capture.gd -- train)  betere BOTS      met vaste regels
  regelzoeker.py                 betere ECONOMIE  met vaste bots en facties
  factiezoeker.py (dit)          betere FACTIES   met vaste bots en economie

Aanleiding (1 augustus): na C18 stond Leeuw op 74% en Beer op 34% over 3240
partijen. De regelzoeker kan daar niets aan doen -- die draait alleen aan de
pot. Het verschil zit in kaartbudget, kaarten per ronde, legersamenstelling en
de perks, en dat zijn precies de knoppen die hier in de zoekruimte zitten.

Hij schrijft zijn kandidaten als een `doctrines`-blok in een regels-json. Dat is
een bestaand mechanisme (RulesConfig.doctrine_data legt het over DOCTRINE_DATA
heen), dus het VOORSTEL is meteen bruikbaar: geef die json aan de trainer of de
arena mee en ze spelen met de voorgestelde facties.

    python tools/balans/factiezoeker.py --minuten 120 --potjes 2 --kandidaten 6

Hij verandert NOOIT zelf iets aan het spel. Alles komt in
results/facties_<tijd>/: elke kandidaat met zijn cijfers, en `voorstel.json`.

BELANGRIJK -- de identiteits-rem. Zonder tegenwicht is de makkelijkste weg naar
"iedereen 50%" zes identieke facties. Daarom telt naast het evenwicht ook hoe
VER een kandidaat van je oorspronkelijke ontwerp afdrijft: elke verandering
kost een beetje, en grote ingrepen kosten veel. De zoeker mag dus schuiven,
maar moet dat verdienen.
"""

import argparse
import json
import math
import os
import random
import statistics as st
import subprocess
import time
from collections import Counter, defaultdict

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GODOT = os.environ.get("GODOT_PATH") or (
    r"C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe")
BASIS = os.path.join(PROJECT, "arena", "arena_configs", "rules_v42_campaign.json")

FACTIES = {"0": "Varken", "1": "Muis", "2": "Leeuw", "3": "Beer", "4": "Wolf", "5": "Krokodil"}

# De huidige facties (spiegelt scripts/core/constants.gd, stand na C18). Dit is
# het ijkpunt voor de identiteits-rem: hoe verder een kandidaat hiervandaan,
# hoe meer hij moet opleveren.
BASIS_FACTIES = {
    "0": {"cards": 3, "budget": 7, "comp": [13, 6, 3], "speed_max": 0, "hp_bonus": 0,
          "art_range_bonus": 0, "cav_speed_bonus": 0},
    "1": {"cards": 4, "budget": 5, "comp": [18, 4, 0], "speed_max": 0, "hp_bonus": 0,
          "art_range_bonus": 0, "cav_speed_bonus": 0},
    "2": {"cards": 2, "budget": 9, "comp": [6, 10, 2], "speed_max": 0, "hp_bonus": 0,
          "art_range_bonus": 1, "cav_speed_bonus": 0},
    "3": {"cards": 3, "budget": 7, "comp": [16, 3, 3], "speed_max": 4, "hp_bonus": 1,
          "art_range_bonus": 0, "cav_speed_bonus": 0},
    "4": {"cards": 3, "budget": 7, "comp": [11, 8, 3], "speed_max": 0, "hp_bonus": 0,
          "art_range_bonus": 0, "cav_speed_bonus": 1},
    "5": {"cards": 3, "budget": 6, "comp": [13, 6, 3], "speed_max": 0, "hp_bonus": 0,
          "art_range_bonus": 0, "cav_speed_bonus": 0},
}

# Knoppen per factie: (naam, min, max, stapkosten voor de identiteits-rem).
# De kosten zeggen hoe ingrijpend een stapje is: kaartbudget verschuiven voelt
# klein, een perk aan- of uitzetten is groot.
KNOPPEN = [
    ("cards", 2, 5, 0.35),
    ("budget", 4, 10, 0.20),
    ("speed_max", 0, 6, 0.15),
    ("hp_bonus", 0, 2, 0.50),
    ("art_range_bonus", 0, 3, 0.25),
    ("cav_speed_bonus", 0, 2, 0.30),
]
COMP_MIN, COMP_MAX = 0, 20
COMP_TOTAAL_MIN, COMP_TOTAAL_MAX = 16, 24   # legergrootte blijft in de buurt

DOEL = {
    "evenwicht": 0.40,     # winrates rond 50% (zonder spiegelpartijen)
    "kant": 0.20,          # speler 1 mag niet structureel winnen
    "beslissend": 0.12,    # weinig tiebreaks
    "duur": 0.08,          # mediaan cycli in de band
    "identiteit": 0.20,    # blijf in de buurt van het oorspronkelijke ontwerp
}
DUUR_ONDER, DUUR_BOVEN = 8, 13


def identiteits_score(doctrines):
    """1.0 = onveranderd, zakt naarmate een kandidaat verder afdrijft."""
    kosten = 0.0
    for sleutel, basis in BASIS_FACTIES.items():
        ov = doctrines.get(sleutel, {})
        for naam, onder, boven, prijs in KNOPPEN:
            if naam in ov and ov[naam] != basis[naam]:
                kosten += prijs * abs(float(ov[naam]) - float(basis[naam]))
        if "comp" in ov:
            for i in range(3):
                kosten += 0.10 * abs(int(ov["comp"][i]) - int(basis["comp"][i]))
    # 6 punten kosten = helemaal weggedreven
    return max(0.0, 1.0 - kosten / 6.0)


def score_run(games, doctrines):
    if not games:
        return 0.0, {"reden": "geen partijen"}
    # SPIEGELPARTIJEN (zelfde factie tegen zichzelf) tellen NIET mee: die geven
    # per definitie een winst en een verlies aan dezelfde factie en trekken elke
    # winrate naar 50%.
    win = defaultdict(lambda: [0, 0])
    for r in games:
        if r["d1"] == r["d2"]:
            continue
        for kant, d in ((1, r["d1"]), (2, r["d2"])):
            win[d][1] += 1
            if int(r["winner"]) == kant:
                win[d][0] += 1
    winrates = {d: 100.0 * w / max(t, 1) for d, (w, t) in win.items()}
    afwijking = st.mean(abs(v - 50.0) for v in winrates.values()) if winrates else 50.0
    evenwicht = max(0.0, 1.0 - afwijking / 25.0)
    # KANT-EERLIJKHEID (les van 1 augustus): de zoeker vond een kandidaat waar
    # speler 1 ALLE 216 partijen won. Elke factie speelt de helft als speler 1,
    # dus stond iedereen op precies 50% en scoorde dat als perfecte balans. Een
    # spel dat door de beurtvolgorde wordt beslist is juist stuk, dus meten we
    # het apart: 50/50 = 1,0, en 100% voor een kant = 0.
    p1 = sum(1 for r in games if int(r["winner"]) == 1)
    p2 = sum(1 for r in games if int(r["winner"]) == 2)
    kant_share = 100.0 * p1 / max(p1 + p2, 1)
    kant = max(0.0, 1.0 - abs(kant_share - 50.0) / 25.0)
    m = Counter(r["methode"] for r in games)
    beslissend = (m["haven"] + m["eliminatie"]) / len(games)
    cycli = st.median([int(r["cycli"]) for r in games])
    if DUUR_ONDER <= cycli <= DUUR_BOVEN:
        duur = 1.0
    else:
        mis = DUUR_ONDER - cycli if cycli < DUUR_ONDER else cycli - DUUR_BOVEN
        duur = max(0.0, 1.0 - mis / 8.0)
    identiteit = identiteits_score(doctrines)
    totaal = (DOEL["evenwicht"] * evenwicht + DOEL["kant"] * kant
              + DOEL["beslissend"] * beslissend + DOEL["duur"] * duur
              + DOEL["identiteit"] * identiteit)
    # VETO, geen aftrek. Een aftrek van 0,20 was niet genoeg: de kandidaat waar
    # speler 1 alles won scoorde daarmee nog steeds hoger dan het echte spel,
    # want hij haalde de volle evenwicht-punten. Wie een spel maakt dat door de
    # beurtvolgorde wordt beslist, heeft geen balans gevonden maar het spel
    # kapotgemaakt -- en dan zeggen de winrates niets meer.
    veto = kant_veto(kant_share)
    if veto:
        totaal *= 0.25
    return totaal, {
        "score": round(totaal, 4), "gem_afwijking_van_50": round(afwijking, 1),
        "speler1_wint_pct": round(kant_share, 1), "kant": round(kant, 3),
        "veto_kant": veto,
        "tiebreak_pct": round(100.0 * m["tiebreak"] / len(games), 1), "cycli": cycli,
        "identiteit": round(identiteit, 3),
        "winrates": {d: round(v, 1) for d, v in sorted(winrates.items(), key=lambda kv: -kv[1])},
        "partijen": len(games),
    }


# Kant-drempel voor het veto. De zoeker meet ELKE kandidaat met dezelfde
# seed-set, en in die set heeft speler 1 al een voorsprong: gemeten 61% bij de
# 216 partijen van de zoeker tegen 51% over de 3240 partijen van de nachtrun.
# Een vaste drempel op 65% schoot daardoor vrijwel elke kandidaat af (72 van de
# 73 op 3 augustus). Daarom ijken we op de NULMETING van dezelfde run: een
# kandidaat mag niet veel schever zijn dan het spel zelf al is.
BASIS_KANT = 50.0          # wordt na de nulmeting op de gemeten waarde gezet
KANT_SPELING = 12.0        # procentpunten die een kandidaat slechter mag zijn
KANT_ABSOLUUT_MAX = 85.0   # hierboven is het altijd stuk, wat de basis ook doet


# Alle kandidaten spelen DEZELFDE seeds als de nulmeting (515000). Eerder liep
# de seed per generatie op, en dan werd een kandidaat vergeleken met een
# kampioen die op andere partijen was gemeten: dobbelsteen-ruis telde mee als
# verschil. Met vaste seeds is het een eerlijke, gepaarde vergelijking.
#
# Prijs: de zoeker kan zich vastbijten in juist deze 216 partijen. Het VOORSTEL
# is dus een suggestie, geen bewijs -- draai het altijd na met de nachtmatrix op
# andere seeds voor je iets overneemt.
ZOEK_SEED = 515000


def kant_grens():
    return min(max(BASIS_KANT + KANT_SPELING, 62.0), KANT_ABSOLUUT_MAX)


def kant_veto(kant_share):
    return kant_share > kant_grens()


def lees_games(pad):
    uit = []
    if not os.path.exists(pad):
        return uit
    for regel in open(pad, encoding="utf-8-sig"):
        try:
            d = json.loads(regel)
        except Exception:
            continue
        if not d.get("run_meta"):
            uit.append(d)
    return uit


def lees_alle(paden):
    uit = []
    for p in paden:
        uit.extend(lees_games(p))
    return uit


def muteer(regels, rng, sigma, alleen=None):
    """Eén kandidaat: schuif per factie aan een paar knoppen.

    `alleen` = lijst met factie-sleutels die mogen veranderen (bv. ["2"] om
    alleen Leeuw aan te pakken). Leeg = alle facties.
    """
    nieuw = json.loads(json.dumps(regels))
    doctrines = nieuw.get("doctrines") or {}
    for sleutel, basis in BASIS_FACTIES.items():
        if alleen and sleutel not in alleen:
            continue
        ov = dict(doctrines.get(sleutel, {}))
        # Per kandidaat maar een paar knoppen aanraken: grote sprongen in alles
        # tegelijk maken het onmogelijk te zien WAT hielp. Richt je op EEN
        # factie, dan moet er wel iets gebeuren -- anders zit je kandidaten te
        # spelen die identiek zijn aan de kampioen.
        verplicht = rng.choice(KNOPPEN)[0] if alleen else None
        for naam, onder, boven, _prijs in KNOPPEN:
            if naam != verplicht and rng.random() > 0.35:
                continue
            huidig = float(ov.get(naam, basis[naam]))
            stap = rng.gauss(0.0, sigma * 3.0)
            waarde = max(onder, min(boven, huidig + stap))
            if naam == "speed_max" and 0 < waarde < 3:
                # 0 = geen limiet; 1 of 2 maakt een factie kreupel in plaats van
                # traag. Snap naar de dichtstbijzijnde zinnige waarde.
                waarde = 0 if waarde < 1.5 else 3
            ov[naam] = int(round(waarde))
        if rng.random() < 0.25:
            comp = list(ov.get("comp", basis["comp"]))
            i = rng.randrange(3)
            comp[i] = max(COMP_MIN, min(COMP_MAX, comp[i] + int(round(rng.gauss(0.0, 2.0)))))
            totaal = sum(comp)
            if COMP_TOTAAL_MIN <= totaal <= COMP_TOTAAL_MAX:
                ov["comp"] = comp
        # Knoppen die gelijk zijn aan de basis houden we uit het voorstel: dan
        # blijft leesbaar WAT er nu eigenlijk verandert.
        for naam in list(ov.keys()):
            if naam != "comp" and ov.get(naam) == basis.get(naam):
                ov.pop(naam)
            elif naam == "comp" and list(ov["comp"]) == list(basis["comp"]):
                ov.pop(naam)
        if ov:
            doctrines[sleutel] = ov
        else:
            doctrines.pop(sleutel, None)
    nieuw["doctrines"] = doctrines
    return nieuw


def draai_kandidaat(map_pad, naam, regels, potjes, seed, procs=3):
    regels_pad = os.path.join(map_pad, "%s_regels.json" % naam)
    with open(regels_pad, "w", encoding="utf-8") as f:
        json.dump(regels, f, indent=1, ensure_ascii=False, sort_keys=True)
    # tie_break_loting AAN, net als de nachtmatrix. Zonder deze knop is L2
    # volledig deterministisch: dan speelt de arena bij gelijke stand steeds
    # dezelfde zet en zijn 216 "partijen" gewoon 36 unieke potjes die zes keer
    # worden overgetikt. Precies dat gebeurde tot 3 augustus -- drie totaal
    # verschillende base_seeds gaven byte-identieke uitslagen, en de zoeker
    # dacht 216 metingen te hebben terwijl er 36 waren. Het verklaart ook
    # waarom de zoeker op 61% eerste-speler-voorsprong uitkwam en de nachtrun
    # op 51%: dat was geen ander spel, dat was geen spreiding.
    arena_cfg = {
        "matchups": "all", "games_per_matchup": potjes,
        "agents": {"p1": "l2", "p2": "l2"},
        "base_seed": seed, "max_steps": 2500, "track_repetitions": False,
        "tie_break_loting": True,
        "rules": "res://" + os.path.relpath(regels_pad, PROJECT).replace("\\", "/"),
    }
    cfg_pad = os.path.join(map_pad, "%s_arena.json" % naam)
    with open(cfg_pad, "w", encoding="utf-8") as f:
        json.dump(arena_cfg, f, indent=1, ensure_ascii=False)
    procs_uit, paden = [], []
    for i in range(max(1, procs)):
        uit_map = os.path.join(map_pad, "%s_p%d" % (naam, i))
        procs_uit.append(subprocess.Popen(
            [GODOT, "--headless", "--path", PROJECT, "res://arena/arena.tscn", "--",
             "--config", os.path.relpath(cfg_pad, PROJECT).replace("\\", "/"),
             "--out", os.path.relpath(uit_map, PROJECT).replace("\\", "/"),
             "--seed-offset", str(i * 100000)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd=PROJECT))
        paden.append(os.path.join(uit_map, "games.jsonl"))
    return procs_uit, paden


def toon_voorstel(doctrines):
    regels = []
    for sleutel in sorted(FACTIES):
        ov = doctrines.get(sleutel)
        if not ov:
            continue
        basis = BASIS_FACTIES[sleutel]
        stukjes = []
        for naam, _o, _b, _p in KNOPPEN:
            if naam in ov:
                stukjes.append("%s %s->%s" % (naam, basis[naam], ov[naam]))
        if "comp" in ov:
            stukjes.append("comp %s->%s" % (basis["comp"], ov["comp"]))
        regels.append("   %-10s %s" % (FACTIES[sleutel], ", ".join(stukjes)))
    return "\n".join(regels) if regels else "   (niets veranderd)"


def main():
    p = argparse.ArgumentParser(description="Zoekt een betere factie-balans (eigenschappen, geen economie).")
    p.add_argument("--minuten", type=float, default=0.0)
    p.add_argument("--kandidaten", type=int, default=6)
    p.add_argument("--potjes", type=int, default=2)
    p.add_argument("--procs", type=int, default=3)
    p.add_argument("--sigma", type=float, default=0.25)
    p.add_argument("--facties", type=str, default="",
                   help="alleen deze facties aanpassen, bv. 2,3 (Leeuw en Beer)")
    p.add_argument("--seed", type=int, default=0)
    args = p.parse_args()

    alleen = [s.strip() for s in args.facties.split(",") if s.strip()] if args.facties else None
    rng = random.Random(args.seed or int(time.time()))
    stempel = time.strftime("%Y%m%d_%H%M%S")
    map_pad = os.path.join(PROJECT, "results", "facties_" + stempel)
    os.makedirs(map_pad, exist_ok=True)
    log_pad = os.path.join(map_pad, "log.jsonl")

    kampioen = json.load(open(BASIS, encoding="utf-8"))
    kampioen.setdefault("doctrines", {})
    print("[FACTIES] basis: %s" % os.path.relpath(BASIS, PROJECT))
    print("[FACTIES] %d kandidaten, %d potjes x %d processen, sigma %.2f%s"
          % (args.kandidaten, args.potjes, args.procs, args.sigma,
             ", alleen %s" % ", ".join(FACTIES[a] for a in alleen) if alleen else ""))

    procs0, paden0 = draai_kandidaat(map_pad, "gen0_basis", kampioen, args.potjes, ZOEK_SEED, args.procs)
    for pr in procs0:
        pr.wait()
    beste_score, beste_detail = score_run(lees_alle(paden0), kampioen.get("doctrines", {}))
    # Veto-drempel ijken op wat DIT spel met DEZE seeds al doet, en de
    # nulmeting daarna opnieuw scoren zodat hij niet zijn eigen veto krijgt.
    globals()["BASIS_KANT"] = float(beste_detail.get("speler1_wint_pct", 50.0))
    beste_score, beste_detail = score_run(lees_alle(paden0), kampioen.get("doctrines", {}))
    print("[FACTIES] kant-drempel geijkt: speler 1 wint %.0f%% in de nulmeting, veto boven %.0f%%" % (BASIS_KANT, kant_grens()))
    print("[FACTIES] huidige facties: score %.4f (afwijking %.1f%%, speler1 wint %.0f%%) %s" % (
        beste_score, beste_detail["gem_afwijking_van_50"], beste_detail["speler1_wint_pct"],
        beste_detail["winrates"]))
    with open(log_pad, "a", encoding="utf-8") as f:
        f.write(json.dumps({"generatie": 0, "naam": "basis", "detail": beste_detail,
                            "doctrines": kampioen.get("doctrines", {})}, ensure_ascii=False) + "\n")

    start = time.time()
    generatie = 0
    sigma = args.sigma
    while True:
        generatie += 1
        if args.minuten > 0:
            if (time.time() - start) / 60.0 >= args.minuten:
                break
        elif generatie > 2:
            break
        lopend = []
        for i in range(args.kandidaten):
            kandidaat = muteer(kampioen, rng, sigma, alleen)
            naam = "gen%d_k%d" % (generatie, i)
            plist, gpaden = draai_kandidaat(map_pad, naam, kandidaat, args.potjes,
                                            ZOEK_SEED, args.procs)
            lopend.append((naam, kandidaat, plist, gpaden))
        for naam, kandidaat, plist, gpaden in lopend:
            for pr in plist:
                pr.wait()
        beste_ronde = None
        for naam, kandidaat, plist, gpaden in lopend:
            s, detail = score_run(lees_alle(gpaden), kandidaat.get("doctrines", {}))
            with open(log_pad, "a", encoding="utf-8") as f:
                f.write(json.dumps({"generatie": generatie, "naam": naam, "detail": detail,
                                    "doctrines": kandidaat.get("doctrines", {})},
                                   ensure_ascii=False) + "\n")
            if beste_ronde is None or s > beste_ronde[0]:
                beste_ronde = (s, kandidaat, detail, naam)
        s, kandidaat, detail, naam = beste_ronde
        beter = s > beste_score
        print("[FACTIES] gen %d: beste %.4f (%s) %s  afwijking %.1f%%  speler1 %.0f%%  identiteit %.2f" % (
            generatie, s, naam, "-> ADOPTIE" if beter else "(kampioen blijft)",
            detail["gem_afwijking_van_50"], detail["speler1_wint_pct"], detail["identiteit"]))
        if beter:
            kampioen, beste_score, beste_detail = kandidaat, s, detail
            sigma = max(0.08, sigma * 0.9)
            print(toon_voorstel(kampioen.get("doctrines", {})))
        else:
            sigma = min(0.5, sigma * 1.05)
        with open(os.path.join(map_pad, "voorstel.json"), "w", encoding="utf-8") as f:
            json.dump(kampioen, f, indent=1, ensure_ascii=False, sort_keys=True)

    print("\n[FACTIES] klaar na %d generaties (%.1f min). Beste score %.4f" % (
        generatie - 1, (time.time() - start) / 60.0, beste_score))
    print("[FACTIES] winrates: %s" % beste_detail.get("winrates"))
    print("[FACTIES] voorstel:")
    print(toon_voorstel(kampioen.get("doctrines", {})))
    print("[FACTIES] bestand: %s" % os.path.relpath(os.path.join(map_pad, "voorstel.json"), PROJECT))
    print("[FACTIES] Dit verandert NIETS aan het spel. Wil je het proberen zonder")
    print("          constants.gd aan te raken: geef dit bestand mee aan de trainer of")
    print("          de arena als regels-json -- het doctrines-blok legt zich over de")
    print("          facties heen. Bevalt het, dan zetten we het pas daarna vast.")


if __name__ == "__main__":
    main()
