"""Regelzoeker: zoekt automatisch naar een betere ONTWERP-balans.

Verschil met de AI-trainer (tools/capture.gd -- train): die zoekt betere BOTS
binnen vaste regels. Deze zoekt betere REGELS met vaste bots. Sinds de nacht van
31 juli (6 facties, 40-142 generaties, 1 adoptie in 7 uur) zit de trainer op een
plateau, en dat betekent dat wat er nog te winnen valt in het ONTWERP zit.

Wat hij draait: elke kandidaat is een regels-json (economie-knoppen). De arena
speelt er een volledige factie-matrix mee, en de uitkomst wordt gescoord op vier
dingen die Max belangrijk vindt:

  1. facties in evenwicht   -- winrates zo dicht mogelijk bij 50%
  2. op eigen kracht        -- de spelers beslissen het, niet de uitputtingsklok
  3. speelduur in de band   -- mediaan cycli tussen ondergrens en bovengrens
  4. levende economie       -- er wordt echt aangevuld en buit gepakt

Gebruik (vanuit de projectmap):
    python tools/balans/regelzoeker.py --minuten 60 --potjes 2 --kandidaten 6

Zonder --minuten draait hij een korte proefronde (2 generaties). Elke generatie
schrijft naar results/balans_<tijd>/: de configs, de ruwe uitslagen, een
log.jsonl met alle scores, en bovenaan het voorstel. Hij verandert NOOIT zelf
een spelconfig: de winnaar komt als voorstel-json op tafel, jij beslist.
"""

import argparse
import json
import math
import os
import random
import shutil
import statistics as st
import subprocess
import sys
import time
from collections import Counter, defaultdict

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GODOT = os.environ.get("GODOT_PATH") or (
    r"C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe")
# C17 (besluit Max, 31 juli): EEN REGELSET. De campagne is het spel, dus de
# zoeker draait op de campagne-config. Een los 1v1 is daar een afgeleide van
# (dezelfde formule maal potje_factor), dus wat hier beter wordt, wordt daar
# vanzelf beter.
BASIS = os.path.join(PROJECT, "arena", "arena_configs", "rules_v42_campaign.json")

# --------------------------------------------------------------- zoekruimte
# Elke knop: (pad in het campaign-blok, ondergrens, bovengrens, geheel getal?)
# De factie-reserves staan apart omdat het er zes zijn.
KNOPPEN = [
    ("start_poolfactor", 0.2, 1.2, False),   # reserve = factor x je legersamenstelling
    ("cp_start", 2, 20, True),
    ("buit_vaandel_pt", 0, 6, True),
    ("buit_tamboer_cp", 0, 8, True),
    ("ruil_cp_per_punt", 1, 4, True),
    ("spawn_max", 1, 6, True),
    ("spawn_totaal_max", 3, 25, True),
    ("spawn_vanaf_cyclus", 1, 4, True),
]
FACTIES = {"0": "Varken", "1": "Muis", "2": "Leeuw", "3": "Beer", "4": "Wolf", "5": "Krokodil"}
# Staat een knop NIET in de basis-json, dan geldt de default uit
# core/match/rules_config.gd (CAMPAIGN_DEFAULTS). Zonder deze tabel begon de
# zoeker op de ondergrens -- en dat zette bijvoorbeeld de buit meteen op 0,
# waarna hij die knop nooit meer kon vinden (gemeten 31 juli: buit 3,11 in de
# nulmeting, 0,00 bij alle kandidaten van generatie 1).
CODE_DEFAULTS = {
    "start_poolfactor": 0.5, "cp_start": 10, "buit_vaandel_pt": 2,
    "buit_tamboer_cp": 2, "ruil_cp_per_punt": 2, "spawn_max": 3,
    "spawn_totaal_max": 15, "spawn_vanaf_cyclus": 2,
}
# Budget-bonus per factie: de compensatie die zwakke facties bij de start
# krijgen. Dit is DE knop voor factie-evenwicht binnen een regelset -- niet een
# aparte 1v1-tabel (die is er niet meer, C17).
BONUS_PT_MAX = 10
BONUS_CP_MAX = 10

# --------------------------------------------------------------- doelstelling
# Gewichten van de score. Hoger = zwaarder mee. Alles wordt op 0..1 genormeerd
# zodat de gewichten leesbaar blijven; de totaalscore is 0..1 (hoger is beter).
DOEL = {
    "evenwicht": 0.45,   # winrates rond 50%
    "op_eigen_kracht": 0.25,  # de spelers beslissen het, niet de honger
    "duur": 0.15,        # mediaan cycli in de band
    "economie": 0.15,    # aanvullen en buit gebeuren echt
}

# V0 (3 augustus): "beslissend" (aandeel haven+eliminatie) werd dood gewicht,
# want onder V0 is dat per definitie 100%. De eerste vervanging was FOUT en is
# door een tegenspraak-ronde onderuit gehaald: die telde partijen waarin de
# honger had ingegrepen, en dat is per constructie hetzelfde als "cycli >= 10"
# (de honger vuurt onvoorwaardelijk vanaf die cyclus). De term mat dus gewoon de
# partijduur nog een keer, tegengesteld aan de duur-term en met een klif waar
# die een helling heeft. Elke mediaan van 1 tot en met 9 scoorde daardoor hoger
# dan het echte spel op 10.
#
# Nu meet hij het AANDEEL van de doden dat door honger valt in plaats van door
# gevecht. Dat is echt iets anders dan duur: een lange partij waarin de spelers
# elkaar te lijf gaan scoort goed, een lange partij waarin ze zich ingraven en
# de klok het werk laat doen scoort slecht. Precies het gedrag dat V0 moest
# wegnemen in plaats van verstoppen.
HONGER_VANAF = 10


def honger_aandeel(games):
    """Welk deel van alle gesneuvelde pionnen viel door de honger (0..1)."""
    honger = 0
    gevecht = 0
    for r in games:
        honger += int(r.get("honger_doden", 0))
        for p in r.get("spelers", {}).values():
            gevecht += int(p.get("kills", 0))
    totaal = honger + gevecht
    return (float(honger) / totaal) if totaal > 0 else 0.0

DUUR_ONDER, DUUR_BOVEN = 6, 9   # gewenste mediaan cycli

# De band moet STRIKT ONDER de hongerdrempel liggen. Lag hij eroverheen (8-13
# met honger op 10), dan waren cyclus 10 tot 13 tegelijk "gewenst" en "door de
# klok beslist", en scoorde elke kortere partij hoger dan het echte spel. Deze
# controle voorkomt dat die twee getallen ooit weer stil uit elkaar lopen.
assert DUUR_BOVEN < HONGER_VANAF, (
    "de duur-band (%d-%d) moet onder de hongerdrempel (%d) blijven"
    % (DUUR_ONDER, DUUR_BOVEN, HONGER_VANAF))


def score_run(games):
    """Scoor een arena-run. Geeft (totaal, detail-dict)."""
    if not games:
        return 0.0, {"reden": "geen partijen"}
    # Spiegelpartijen tellen niet mee (zie factiezoeker): die geven dezelfde
    # factie een winst en een verlies en trekken elke winrate naar 50%.
    win = defaultdict(lambda: [0, 0])
    for r in games:
        if r["d1"] == r["d2"]:
            continue
        for kant, d in ((1, r["d1"]), (2, r["d2"])):
            win[d][1] += 1
            if int(r["winner"]) == kant:
                win[d][0] += 1
    winrates = {d: 100.0 * w / max(t, 1) for d, (w, t) in win.items()}
    # 1) evenwicht: gemiddelde afstand tot 50%, 0 punten bij 25 procentpunt eraf
    afwijking = st.mean(abs(v - 50.0) for v in winrates.values()) if winrates else 50.0
    evenwicht = max(0.0, 1.0 - afwijking / 25.0)
    # 2) op eigen kracht: hoeveel partijen moest de honger komen afmaken?
    m = Counter(r["methode"] for r in games)
    honger_pct = 100.0 * honger_aandeel(games)
    op_eigen_kracht = max(0.0, 1.0 - honger_pct / 40.0)
    # Een partij zonder winnaar is onder V0 geen uitslag maar een kapotte klok.
    afkap = m["afkap"] + m["remise"]
    # 3) duur: mediaan cycli binnen de band = 1, daarbuiten lineair weg
    cycli = st.median([int(r["cycli"]) for r in games])
    if DUUR_ONDER <= cycli <= DUUR_BOVEN:
        duur = 1.0
    else:
        mis = DUUR_ONDER - cycli if cycli < DUUR_ONDER else cycli - DUUR_BOVEN
        duur = max(0.0, 1.0 - mis / 8.0)
    # 4) economie: aanvullen EN buit moeten echt voorkomen (anders is de knop dood)
    def per_partij(veld):
        return st.mean(sum(int(r["spelers"][p].get(veld, 0)) for p in r["spelers"]) for r in games)
    spawns = per_partij("spawns")
    buit = per_partij("buit_pt") + per_partij("buit_cp")
    economie = min(1.0, spawns / 4.0) * 0.6 + min(1.0, buit / 2.0) * 0.4
    totaal = (DOEL["evenwicht"] * evenwicht + DOEL["op_eigen_kracht"] * op_eigen_kracht
              + DOEL["duur"] * duur + DOEL["economie"] * economie)
    # VETO op kant-dominantie (les van 1 augustus, gevonden door de
    # factiezoeker): wint speler 1 structureel, dan is het spel stuk en zeggen
    # de winrates niets meer -- elke factie speelt immers de helft als speler 1.
    p1 = sum(1 for r in games if int(r["winner"]) == 1)
    p2 = sum(1 for r in games if int(r["winner"]) == 2)
    kant_share = 100.0 * p1 / max(p1 + p2, 1)
    veto = kant_veto(kant_share)
    if veto:
        totaal *= 0.25
    # Een afgekapte partij betekent dat de uitputtingsklok niet heeft gewerkt.
    # De uitslagen van zo'n run zijn onbruikbaar: harde nul, geen aftrek.
    if afkap > 0:
        totaal = 0.0
    detail = {
        "score": round(totaal, 4), "speler1_wint_pct": round(kant_share, 1),
        "veto_kant": veto,
        "evenwicht": round(evenwicht, 3), "gem_afwijking_van_50": round(afwijking, 1),
        "op_eigen_kracht": round(op_eigen_kracht, 3), "honger_pct": round(honger_pct, 1),
        "afkap": afkap,
        "cycli": cycli, "duur": round(duur, 3),
        "spawns": round(spawns, 2), "buit": round(buit, 2), "economie": round(economie, 3),
        "winrates": {d: round(v, 1) for d, v in sorted(winrates.items(), key=lambda kv: -kv[1])},
        "partijen": len(games),
    }
    return totaal, detail


def lees_alle(paden):
    """Partijen van alle processen van een kandidaat samen."""
    uit = []
    for p in paden:
        uit.extend(lees_games(p))
    return uit


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


def muteer(regels, rng, sigma):
    """Eén kandidaat: schaal elke knop met log-normale ruis, klem op de grenzen."""
    nieuw = json.loads(json.dumps(regels))
    c = nieuw["campaign"]
    for naam, onder, boven, geheel in KNOPPEN:
        huidig = float(c.get(naam, CODE_DEFAULTS.get(naam, onder)))
        waarde = huidig * math.exp(rng.gauss(0.0, sigma))
        waarde = max(onder, min(boven, waarde))
        c[naam] = int(round(waarde)) if geheel else round(waarde, 3)
    # Factie-evenwicht loopt via de budget-bonus (zelfde knop als de campagne).
    bonus = {k: dict(v) for k, v in (c.get("budget_bonus", {}) or {}).items()}
    for sleutel in FACTIES:
        b = bonus.get(sleutel, {"pt": 0, "cp": 0})
        pt = float(b.get("pt", 0))
        cp = float(b.get("cp", 0))
        # Vanaf nul kan log-normale ruis nooit weg, dus daar tellen we op.
        pt = pt * math.exp(rng.gauss(0.0, sigma)) if pt > 0 else max(0.0, rng.gauss(0.0, 1.5))
        cp = cp * math.exp(rng.gauss(0.0, sigma)) if cp > 0 else max(0.0, rng.gauss(0.0, 1.5))
        bonus[sleutel] = {"pt": int(round(min(BONUS_PT_MAX, pt))),
                          "cp": int(round(min(BONUS_CP_MAX, cp)))}
    c["budget_bonus"] = bonus
    return nieuw


def draai_kandidaat(map_pad, naam, regels, potjes, seed, procs=3):
    """Schrijf de configs en start `procs` arena-processen voor DEZELFDE regels.

    Elk proces speelt de volledige matrix met een eigen seed-offset, dus samen
    leveren ze `procs` x zoveel partijen in dezelfde wandkloktijd. Gemeten op
    31 juli: zes kandidaten in hun eentje = 28 minuten per generatie op een
    machine met 32 threads. Met drie processen per kandidaat draaien er 18
    tegelijk en zakt dat naar ongeveer een derde.
    Geeft (lijst-van-procs, lijst-van-games-paden).
    """
    regels_pad = os.path.join(map_pad, "%s_regels.json" % naam)
    with open(regels_pad, "w", encoding="utf-8") as f:
        json.dump(regels, f, indent=1, ensure_ascii=False, sort_keys=True)
    # tie_break_loting AAN, net als de nachtmatrix. Zonder deze knop is L2
    # volledig deterministisch: dan speelt de arena bij gelijke stand steeds
    # dezelfde zet en zijn 216 "partijen" gewoon 36 unieke potjes die zes keer
    # worden overgetikt. Precies dat gebeurde tot 3 augustus -- drie totaal
    # verschillende base_seeds gaven byte-identieke uitslagen.
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
    procs_uit = []
    paden = []
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


def main():
    p = argparse.ArgumentParser(description="Zoekt een betere ontwerp-balans (regels, niet bots).")
    p.add_argument("--minuten", type=float, default=0.0, help="tijdbudget; 0 = korte proefronde")
    p.add_argument("--kandidaten", type=int, default=6, help="kandidaten per generatie")
    p.add_argument("--potjes", type=int, default=2, help="potjes per matchup per kandidaat")
    p.add_argument("--sigma", type=float, default=0.25, help="mutatie-ruis (log-normaal)")
    p.add_argument("--procs", type=int, default=3,
                   help="processen per kandidaat (meer partijen in dezelfde tijd)")
    p.add_argument("--seed", type=int, default=0)
    args = p.parse_args()

    rng = random.Random(args.seed or int(time.time()))
    stempel = time.strftime("%Y%m%d_%H%M%S")
    map_pad = os.path.join(PROJECT, "results", "balans_" + stempel)
    os.makedirs(map_pad, exist_ok=True)
    log_pad = os.path.join(map_pad, "log.jsonl")

    kampioen = json.load(open(BASIS, encoding="utf-8"))
    print("[BALANS] basis: %s" % os.path.relpath(BASIS, PROJECT))
    print("[BALANS] %d kandidaten per generatie, %d potjes per matchup x %d processen, sigma %.2f"
          % (args.kandidaten, args.potjes, args.procs, args.sigma))
    print("[BALANS] uitvoer: %s" % os.path.relpath(map_pad, PROJECT))

    # Nulmeting: hoe scoort de huidige balans?
    procs0, paden0 = draai_kandidaat(map_pad, "gen0_basis", kampioen, args.potjes,
                                     ZOEK_SEED, args.procs)
    for pr in procs0:
        pr.wait()
    beste_score, beste_detail = score_run(lees_alle(paden0))
    # Veto-drempel ijken op wat DIT spel met DEZE seeds al doet, en de
    # nulmeting daarna opnieuw scoren zodat hij niet zijn eigen veto krijgt.
    globals()["BASIS_KANT"] = float(beste_detail.get("speler1_wint_pct", 50.0))
    beste_score, beste_detail = score_run(lees_alle(paden0))
    print("[BALANS] kant-drempel geijkt: speler 1 wint %.0f%% in de nulmeting, veto boven %.0f%%" % (BASIS_KANT, kant_grens()))
    print("[BALANS] huidige balans: score %.4f  (afwijking %.1f%%, honger %.0f%%, cycli %d, "
          "aanvullen %.2f, buit %.2f)" % (beste_score, beste_detail["gem_afwijking_van_50"],
          beste_detail["honger_pct"], beste_detail["cycli"], beste_detail["spawns"],
          beste_detail["buit"]))
    with open(log_pad, "a", encoding="utf-8") as f:
        f.write(json.dumps({"generatie": 0, "naam": "basis", "detail": beste_detail,
                            "regels": kampioen["campaign"]}, ensure_ascii=False) + "\n")

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
        procs = []
        for i in range(args.kandidaten):
            kandidaat = muteer(kampioen, rng, sigma)
            naam = "gen%d_k%d" % (generatie, i)
            plist, gpaden = draai_kandidaat(map_pad, naam, kandidaat, args.potjes,
                                            ZOEK_SEED, args.procs)
            procs.append((naam, kandidaat, plist, gpaden))
        for naam, kandidaat, plist, gpaden in procs:
            for pr in plist:
                pr.wait()
        beste_van_ronde = None
        for naam, kandidaat, plist, gpaden in procs:
            s, detail = score_run(lees_alle(gpaden))
            with open(log_pad, "a", encoding="utf-8") as f:
                f.write(json.dumps({"generatie": generatie, "naam": naam, "detail": detail,
                                    "regels": kandidaat["campaign"]}, ensure_ascii=False) + "\n")
            if beste_van_ronde is None or s > beste_van_ronde[0]:
                beste_van_ronde = (s, kandidaat, detail, naam)
        s, kandidaat, detail, naam = beste_van_ronde
        beter = s > beste_score
        print("[BALANS] gen %d: beste %.4f (%s) %s  afwijking %.1f%% honger %.0f%% cycli %d "
              "aanvullen %.2f buit %.2f" % (generatie, s, naam,
              "-> ADOPTIE" if beter else "(kampioen blijft)", detail["gem_afwijking_van_50"],
              detail["honger_pct"], detail["cycli"], detail["spawns"], detail["buit"]))
        if beter:
            kampioen, beste_score, beste_detail = kandidaat, s, detail
            sigma = max(0.08, sigma * 0.9)   # dichterbij: fijner zoeken
        else:
            sigma = min(0.5, sigma * 1.05)   # niets gevonden: breder zoeken
        # Voorstel altijd bijwerken, zodat je tussentijds kunt kijken.
        voorstel = os.path.join(map_pad, "voorstel.json")
        with open(voorstel, "w", encoding="utf-8") as f:
            json.dump(kampioen, f, indent=1, ensure_ascii=False, sort_keys=True)

    print("\n[BALANS] klaar na %d generaties (%.1f min). Beste score %.4f" % (
        generatie - 1, (time.time() - start) / 60.0, beste_score))
    print("[BALANS] winrates van het voorstel: %s" % beste_detail.get("winrates"))
    print("[BALANS] voorstel: %s" % os.path.relpath(os.path.join(map_pad, "voorstel.json"), PROJECT))
    print("[BALANS] LET OP: dit verandert niets aan het spel. Vergelijk het voorstel met")
    print("         %s en beslis zelf wat je overneemt." % os.path.relpath(BASIS, PROJECT))
    print("[BALANS] Let vooral op de UITERSTEN, niet op de score: een factie die aan de")
    print("         boven- of ondergrens van de zoekruimte blijft plakken, vertelt je dat")
    print("         je aan de verkeerde knop draait.")


if __name__ == "__main__":
    main()
