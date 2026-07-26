class_name CRules
extends RefCounted

# F3.1 — alle campagneregels als data (campagne-spec C1-C8 + masterplan).
# Zelfde filosofie als RulesConfig: één set knoppen per campagne, onveranderlijk.

var team_size: int = 8                    # C1: twee teams van 8
var duels_per_ronde_max: int = 2          # min(dit, kleinste teamgrootte)

# Startbezit per speler (de 1v1-setting als campagne-standaard):
var start_poolfactor: float = 1.5         # voorraad = comp x factor (afgerond omlaag)
var start_cp: int = 10

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
		"start_poolfactor": start_poolfactor,
		"start_cp": start_cp,
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
	c.duels_per_ronde_max = int(d.get("duels_per_ronde_max", c.duels_per_ronde_max))
	c.start_poolfactor = float(d.get("start_poolfactor", c.start_poolfactor))
	c.start_cp = int(d.get("start_cp", c.start_cp))
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
