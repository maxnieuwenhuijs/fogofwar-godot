class_name CRules
extends RefCounted

# F3.1 — alle campagneregels als data (campagne-spec C1-C8 + masterplan).
# Zelfde filosofie als RulesConfig: één set knoppen per campagne, onveranderlijk.

var team_size: int = 8                    # C1: twee teams van 8
var duels_per_ronde_max: int = 8          # min(dit, kleinste teamgrootte) — 8 = iedereen vecht
var ronde1_loting: bool = true            # C9: ronde 1 = random 1v1-paren, geen raad

# Vol-team-model (besluit Max, 27 juli): elk duel start je HOE DAN OOK met de
# volledige factie-samenstelling op het bord; de pool is puur REINFORCEMENTS
# en slinkt alleen door ze in te zetten (spawns), donaties en testamenten.
# Uitvallen (C3) blijft: duel verloren én reinforcements op.
var vol_team_start: bool = true

# Startbezit per speler: reinforcements = comp x factor (afgerond omlaag).
# 0.5 houdt het totale startbezit gelijk aan het oude 1v1-besluit
# (1x comp veldleger + 0.5x comp reserve = het oude 1.5x); arena-tunebaar.
var start_poolfactor: float = 0.5
var start_cp: int = 10

# C11 (besluit Max, 27 juli): CP inruilen voor versterkingen, 2 CP = 1 punt
# (geboekt als soldaat, waarde 1). Alleen in het donatie-venster.
var ruil_cp_per_punt: int = 2

# C11: per-factie budget-compensatie bij de start (tweakknoppen, Max).
# Sleutel = doctrine-int als string; pt = extra soldaten (1 punt elk),
# cp = extra start-CP. Basis: nachtdata 26-28 juli (Muis/Beer zwak,
# Wolf 2 nachten 0 adopties -> CP-steun).
var budget_bonus: Dictionary = {
	"1": {"pt": 4, "cp": 0},    # Muis
	"3": {"pt": 3, "cp": 0},    # Beer
	"4": {"pt": 2, "cp": 4},    # Wolf
}

# Donaties (per ontvanger per raadsronde):
var donatie_cap_pionnen: int = 10
var donatie_cap_cp: int = 3

# Testament (C3): max helft, max 2 ontvangers; timeout/forfeit = verbranden.
var testament_fractie: float = 0.5
var testament_ontvangers_max: int = 2

# Punten (C5): roem, bepaalt de burgeroorlog-seeding.
var punten_haven: int = 3
var punten_eliminatie: int = 2
var punten_tiebreak: int = 1
var punten_verlies: int = 0
var punten_teambonus: int = 2             # aan het einde, ook voor doden

# Duel-koppeling (C2/C7/C8): volledige voorraad mee; comp opstellen gecapt
# op de voorraad, rest = spawn-reserve; de vaste v4.2-duelregels gelden
# (cp uit het campagnesaldo, 15-spawn-cap via spawn_totaal_max).
var duel_spawn_totaal_max: int = 15


func to_dict() -> Dictionary:
	return {
		"team_size": team_size,
		"duels_per_ronde_max": duels_per_ronde_max,
		"ronde1_loting": ronde1_loting,
		"vol_team_start": vol_team_start,
		"start_poolfactor": start_poolfactor,
		"start_cp": start_cp,
		"ruil_cp_per_punt": ruil_cp_per_punt,
		"budget_bonus": budget_bonus,
		"donatie_cap_pionnen": donatie_cap_pionnen,
		"donatie_cap_cp": donatie_cap_cp,
		"testament_fractie": testament_fractie,
		"testament_ontvangers_max": testament_ontvangers_max,
		"punten_haven": punten_haven,
		"punten_eliminatie": punten_eliminatie,
		"punten_tiebreak": punten_tiebreak,
		"punten_verlies": punten_verlies,
		"punten_teambonus": punten_teambonus,
		"duel_spawn_totaal_max": duel_spawn_totaal_max,
	}


static func from_dict(d: Dictionary) -> CRules:
	var c := CRules.new()
	c.team_size = int(d.get("team_size", c.team_size))
	# Compat: oude campagnes (voor 26 juli) misten deze sleutels — die logs
	# moeten onder hun eigen, oude regels blijven folden (max 2 duels, geen
	# loting). Nieuwe campagnes schrijven de nieuwe waarden altijd uit.
	c.duels_per_ronde_max = int(d.get("duels_per_ronde_max", 2))
	c.ronde1_loting = bool(d.get("ronde1_loting", false))
	# Compat: campagnes van voor 27 juli kennen het vol-team-model niet en
	# moeten onder het oude pool-model (gecapte starts, verliezen-afboeking)
	# blijven folden; hun opgeslagen poolfactor (1.5) blijft dan ook gelden.
	c.vol_team_start = bool(d.get("vol_team_start", false))
	c.start_poolfactor = float(d.get("start_poolfactor", c.start_poolfactor))
	c.start_cp = int(d.get("start_cp", c.start_cp))
	c.ruil_cp_per_punt = int(d.get("ruil_cp_per_punt", c.ruil_cp_per_punt))
	# Compat: pre-C11-saves misten budget_bonus -> leeg (geen bonus achteraf).
	var bb = d.get("budget_bonus", {})
	c.budget_bonus = {}
	if bb is Dictionary:
		for k in bb:
			c.budget_bonus[String(k)] = {"pt": int((bb[k] as Dictionary).get("pt", 0)), "cp": int((bb[k] as Dictionary).get("cp", 0))}
	c.donatie_cap_pionnen = int(d.get("donatie_cap_pionnen", c.donatie_cap_pionnen))
	c.donatie_cap_cp = int(d.get("donatie_cap_cp", c.donatie_cap_cp))
	c.testament_fractie = float(d.get("testament_fractie", c.testament_fractie))
	c.testament_ontvangers_max = int(d.get("testament_ontvangers_max", c.testament_ontvangers_max))
	c.punten_haven = int(d.get("punten_haven", c.punten_haven))
	c.punten_eliminatie = int(d.get("punten_eliminatie", c.punten_eliminatie))
	c.punten_tiebreak = int(d.get("punten_tiebreak", c.punten_tiebreak))
	c.punten_verlies = int(d.get("punten_verlies", c.punten_verlies))
	c.punten_teambonus = int(d.get("punten_teambonus", c.punten_teambonus))
	c.duel_spawn_totaal_max = int(d.get("duel_spawn_totaal_max", c.duel_spawn_totaal_max))
	return c


func punten_voor_methode(methode: String) -> int:
	match methode:
		"haven":
			return punten_haven
		"eliminatie":
			return punten_eliminatie
		"tiebreak":
			return punten_tiebreak
	return punten_verlies
