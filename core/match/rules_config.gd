class_name RulesConfig
extends RefCounted

# F0.2 — alle regelknoppen als data. Eén RulesConfig per match, onveranderlijk
# tijdens de partij (GameState.clone() deelt daarom de referentie). De defaults
# zijn exact het 4.1.9-hr-gedrag; elke afwijking is een bewuste config-keuze
# die met rules_version + CHANGELOG-entry hoort te reizen.
#
# Handhaving per knop:
# - vuurmodel/schot/terugslag/stamina/haven: Rules.gd (deze stap, F0.2)
# - honger_vanaf_cyclus: reducer (V0, de uitputtingsklok)
# - clock: engine-klokken (F0.8)
# - campaign (cp/pool/spawn/cannon): v4.2 (F2); null = puur 4.1-gedrag

var rules_version: String = "4.3.0"  # V0: geen gelijkspel, uitputtingsklok
var rounds_per_cycle: int = 3
var pawns_in_haven_to_win: int = 2

# --- Vuurmodel (spelregels-v4.1 §8-vraag, nu echt configureerbaar) ---
var fire_hits_inactive: bool = true   # false: standbeelden onraakbaar (blokkeren wel)
var fire_blocked: bool = true         # false: boogvuur — niets blokkeert de lijn
var inf_shot_over_pawn: bool = false  # true: infanterieschot over precies één tussenpion
var statue_threshold: int = 0         # >0: schade moet >= drempel om een standbeeld te elimineren (melee én schot)

# --- Winnen ---
var haven_score_cumulative: bool = false  # true: "touches" tellen — ooit-aangeraakt blijft tellen

# --- Kaartdefinitie ---
var per_stat_cap: int = 0             # >0: harde bovengrens per losse kaart-stat
## C13 (besluit Max, 29 juli): de schutkleur van de Krokodil valt ook weg als
## er een ACTIEVE vijand naast staat -- je ziet wat je van dichtbij bekijkt.
## Zonder dit was de fog-factie te sterk (76% winrate tegen 30% voor Beer):
## tegenstanders moesten een heel potje tegen onbekende waarden spelen.
## false = het oude gedrag (alleen onthullen bij schade).
var schutkleur_onthul_nabij: bool = true

var basis_hp: Dictionary = {}         # C12: basis-HP per type BOVENOP de kaart (bv {"cav": 2}); {} = 4.1-gedrag
## 4.3.5 (Max, 8 september): ondergrens per type, na kaart en bonussen, bv
## {"cav": {"stamina": 2, "attack": 2}}: "een bigbro heeft altijd 2 stamina en
## 2 attack". Sleutels stamina/attack/hp. {} = 4.1-gedrag.
var stat_minimum: Dictionary = {}
## 4.3.6 (Max, 16 september): "het is plus: een cavalry met een 1-attack-kaart
## heeft 3 attack, niet 2". Bonus per type BOVENOP kaart en factie-bonussen,
## sleutels stamina/attack/hp. Vervangt in de configs de ondergrens van 4.3.5.
## 4.3.7 (18 september): alleen nog {"cav": {"attack": 2}}. De +2 stamina van
## 4.3.6 maakte van elke ruiter een havenrenner (nachtmatrix 18 september:
## band 27-69%, Beer 69, Leeuw 27); met alleen de attack-plus band 45-54%
## over 5400 partijen, de smalste ooit gemeten. {} = niets erbij.
var stat_bonus: Dictionary = {}

# --- Schotparameters ---
var inf_shot_range: int = 2           # afstand exact N (min = max)
var inf_shot_cost: int = 1
var inf_shot_full_attack: bool = true # false: schade Attack-1 (v4.1-doc-variant)
var art_min_range: int = 2            # dode zone: alles daaronder onraakbaar
var art_range: int = 6                # vaste dracht (doctrine-bonus komt erbij)
var art_move: int = 1                 # max stappen per beweegactie
var art_shot_cost: int = 1

# --- Melee ---
var retaliation: Dictionary = {"inf": 1, "cav": 2, "art": 0}

# --- Actie-economie ---
var stamina_model: String = "pool"    # "pool" (huisregel) | "one_action" (v4.1-doc: 1 actie per pion per cyclus)

# --- Partijgrenzen (V0, 3 augustus: de uitputtingsklok) ---
# Een duel kent alleen haven en eliminatie. Geen remise, geen tiebreak, geen
# cycluslimiet. In plaats daarvan verhongert vanaf deze cyclus elke speler een
# pion per cyclus (de achterste), zodat het einde uit de regels zelf komt.
# 0 = geen klok (dan kan een partij in theorie eeuwig duren).
# C17: een regel, twee getallen -- campagne-duel later dan een los potje.
var honger_vanaf_cyclus: int = 0

# --- Klokken (handhaving F0.8) ---
var clock: Dictionary = {"bank_sec": 0, "increment_sec": 0, "reconnect_grace_sec": 20}

# --- Doctrine-overrides: {doctrine-int: {veld: waarde}} bovenop DOCTRINE_DATA ---
var doctrines: Dictionary = {}

# --- v4.2-campagneblok (F2); null = v4.1-gedrag ---
var campaign = null

# --- Strategy mode (21 oktober, Max: "ongeacht factie heeft ieder leger een
# Budget voor het gevecht, een speler mag dan helemaal zelf kiezen hoe hij deze
# vult ... Je ziet wel nog je 3d modellen van de factie maar verder geen
# speciale regels"); null = uit, en dan speelt alles byte-identiek als ervoor.
# Aan: elke factie is dezelfde allrounder (geen perks, dezelfde kaarten), en je
# koopt je veldleger zelf uit `budget` in de opstelfase: de opstelling IS de
# keuze, dus blind net als het opstellen zelf. Prijs per stuk = de spawn-kosten
# van het campagneblok (een prijslijst voor leger en versterkingen). Zie
# STRATEGIE_DEFAULTS en docs/spelregels-v4.2.md Deel B "Strategy mode".
var strategie = null

## De knoppen van Strategy mode. Een blok in een config (ook {}) zet de modus
## aan; ontbrekende knoppen krijgen deze waarden.
const STRATEGIE_DEFAULTS := {
	"budget": 30,               # legerpunten voor het veldleger (soldaat 1, big bro 2, kanon 3)
	"kaarten": 3,               # kaarten per ronde, voor elke factie gelijk (de Varken-waarde)
	"kaartbudget": 7,           # punten per kaart, idem
	"standaard": [16, 4, 2],    # het leger van wie niet kiest (en van de standaard-opstelling): 30 punten, 22 pionnen
	"reserve_factor": 0.5,      # versterkingen = budget x dit (x potje_factor), voor iedereen gelijk
}

## De perk-velden van een factie en hun neutrale stand (de Varken, de
## allrounder). In Strategy mode staan ze voor elke factie zo.
const NEUTRALE_PERKS := {
	"move_through_own": false, "hp_bonus": 0, "speed_max": 0, "speed_bonus": 0,
	"wolf_step": false, "hidden_link": false,
	"art_range_bonus": 0, "cav_speed_bonus": 0, "cav_jump_infantry": false,
}


func strategie_actief() -> bool:
	return strategie is Dictionary


## Een strategie-blok normaliseren (JSON-floats terug naar int, ontbrekende
## knoppen erbij). Ook voor de campagnelaag (CRules) en de arena.
static func normaliseer_strategie(blok) -> Dictionary:
	var uit: Dictionary = {}
	var bron: Dictionary = blok if blok is Dictionary else {}
	for k in STRATEGIE_DEFAULTS:
		var dv = STRATEGIE_DEFAULTS[k]
		var v = bron.get(k, dv)
		if dv is float:
			uit[k] = float(v)
		elif dv is int:
			uit[k] = int(v)
		else:
			uit[k] = _diep_int(v)
	var std: Array = uit["standaard"] if uit["standaard"] is Array else []
	if std.size() != 3:
		push_error("RulesConfig: strategie.standaard moet [inf, cav, art] zijn, teruggezet")
		uit["standaard"] = (STRATEGIE_DEFAULTS["standaard"] as Array).duplicate()
		std = uit["standaard"]
	# Past het standaardleger niet in het budget (of niet op het bord), dan
	# loopt elke partij vast op een standaard-opstelling die de engine weigert.
	# Dan een leger uit hetzelfde budget, in de verhouding van de standaard.
	var prijs: Dictionary = CAMPAIGN_DEFAULTS["spawn_kosten"]
	var kost: int = int(std[0]) * int(prijs.inf) + int(std[1]) * int(prijs.cav) + int(std[2]) * int(prijs.art)
	var n: int = int(std[0]) + int(std[1]) + int(std[2])
	if kost > int(uit["budget"]) or n < 1 or n > Constants.PAWNS_PER_PLAYER:
		var budget: int = maxi(1, int(uit["budget"]))
		var art: int = int(floor(budget * 0.2 / float(prijs.art)))
		var cav: int = int(floor(budget * 0.27 / float(prijs.cav)))
		var inf: int = mini(Constants.PAWNS_PER_PLAYER - art - cav, (budget - art * int(prijs.art) - cav * int(prijs.cav)) / int(prijs.inf))
		uit["standaard"] = [maxi(1 if art + cav == 0 else 0, inf), cav, art]
	return uit


## Factie-data zoals Strategy mode hem ziet: naam, map en uiterlijk van de
## factie, maar de perks neutraal en kaarten en kaartbudget voor iedereen
## gelijk. `comp` is het standaardleger; het gekozen leger zet GameState er per
## speler overheen. `comp_factie` bewaart de samenstelling van de factie zelf,
## alleen als smaak voor de bots (AIController.kies_leger).
static func strategie_data(base: Dictionary, blok: Dictionary) -> Dictionary:
	var d: Dictionary = base.duplicate()
	for k in NEUTRALE_PERKS:
		d[k] = NEUTRALE_PERKS[k]
	d["cards"] = int(blok.get("kaarten", STRATEGIE_DEFAULTS["kaarten"]))
	d["budget"] = int(blok.get("kaartbudget", STRATEGIE_DEFAULTS["kaartbudget"]))
	d["comp_factie"] = base.get("comp", [0, 0, 0])
	d["comp"] = (blok.get("standaard", STRATEGIE_DEFAULTS["standaard"]) as Array).duplicate()
	return d

## Defaults van het campaign-blok, exact de F2.1-besluiten (D1-D14; zie
## docs/spelregels-v4.2.md Deel B). Activering van het blok bumpt
## rules_version naar 4.3.10 (4.3.9 met initiatief_deler "hand", 4.3.8 met
## "kaarten", 4.3.7 met ook initiatief_sps uit); zonder blok speelt de engine
## exact 4.1.x.
## De standen van campaign.initiatief_deler (zie CAMPAIGN_DEFAULTS).
const BOD_DELERS: Array[String] = ["kaarten", "hand", "tegenstander"]

const CAMPAIGN_DEFAULTS := {
	"cp_start": 10,                      # D2/D13: vast duel-budget (10 sinds 25 juli, besluit Max)
	"cp_haven": 8, "cp_eliminatie": 4, "cp_raadstem": 1,
	"cp_effect_mode": "define_budget",   # D1: +1 kaartbudget bij definiëren
	"cp_inzet_max": "per_kaart",         # D4: 1 per kaart, geen plafond
	"cp_refund": "none",                 # D2: ingezet = verbrand
	"pool_model": "typen",               # C11: "punten" = reserve is een puntenpot (default typed = compat)
	"spawn_kosten": {"inf": 1, "cav": 2, "art": 3},  # C11: prijs per type in het punten-model
	"cp_start_mode": "vast",             # D13
	"cp_bijschrijving": "campagnelaag",  # D13: verdiensten naar de campagnepot
	# Vaste puntenreserve voor beide spelers (besluit Max, 30 juli): een 1v1
	# start met 15 punten, ongeacht de doctrine-comp. 0 = uit, dan rekent
	# poolfactor x comp het bedrag uit zoals voorheen (campagne doet dat).
	# C15 (besluit Max, 30 juli): BUIT op figuranten. Wie een vaandeldrager
	# neerlegt krijgt versterkingspunten, wie een tamboer neerlegt CP;
	# gekoppeld of niet (4.3.2, 7 september). 0 = uit.
	"buit_vaandel_pt": 2,
	"buit_tamboer_cp": 4,                # 4.3.4 (Max, 8 september): was 2; met één tamboer per leger telt hij dubbel
	# Hoeveel je er bij het opstellen mag aanwijzen (per speler). 4.3.4: één
	# van elk (was 2 en 2), Max: "het staat te vol".
	"vaandels_max": 1,
	"tamboers_max": 1,
	# C21 (besluit Max, 7 september): AURA. Een eigen pion in de vorm om een
	# tamboer krijgt bij het koppelen +1 stamina voor die cyclus; in de vorm om
	# een vaandeldrager slaat en schiet hij +1 harder. De vorm is het blok om
	# de drager (aura_bereik vakken in elke richting, ook diagonaal; 1 = de
	# acht buurvakken). De drager zelf hoort er niet bij, twee dragers
	# stapelen niet, gekoppeld of niet maakt niet uit. 0 = uit.
	"aura_bereik": 1,
	"aura_tamboer_stamina": 1,
	"aura_vaandel_attack": 1,
	# 4.3.8 (Max, 5 oktober: "rock paper scissor bij gelijk spel bid"): zijn
	# het Aanval-bod EN het stamina-bod gelijk, en hebben beide spelers kaarten
	# onthuld, dan beslist steen-papier-schaar wie het initiatief krijgt (in
	# plaats van "cyclus 1 ronde 1: speler 1, anders de vorige houder"). In de
	# code heet het sps: de F0.0-check grept op het andere woord.
	"initiatief_sps": true,
	# Waardoor deelt het initiatief-bod (Max, 7 oktober: "is het een percentage
	# dat je met 1 kaart ook kan winnen? dat is dan toch niet eerlijk, als ik er
	# 5 nog heb")? "kaarten" = de kaarten die je deze ronde speelt (het
	# gemiddelde per kaart, tot en met 4.3.8); "hand" = de volle hand van je
	# factie (4.3.9: met 1 van 5 kaarten hooguit 20%, maar ook de Muis met 4
	# tegen de Leeuw met 2 hooguit 80%); "tegenstander" = 4.3.10, de default:
	# speel je minder kaarten dan je tegenstander, dan tellen de kaarten die je
	# mist mee als kaarten zonder punten, tot je volle hand. Speel je er evenveel
	# of meer, dan blijft het het gemiddelde per kaart. Rules.bod_deler.
	"initiatief_deler": "tegenstander",
	# C17 (besluit Max, 31 juli): EEN REGELSET, en dat is de campagne. "De 1v1 is
	# gewoon een afgeleide van de campagne: in plaats van meerdere duels speel je
	# er een, en dus heb je iets gedowngrade CP en reinforcements, meer niet."
	#
	# De startreserve komt daarom uit dezelfde formule als de campagnelaag
	# (CRules): start_poolfactor x je legersamenstelling, plus de budget-bonus
	# van je factie. `potje_factor` schaalt dat naar een LOS potje: 1.0 = een
	# volwaardige campagne-start, 0.35 = het duel-aandeel van een campagne.
	# Zo staat er nergens meer een tweede economie naast.
	"start_poolfactor": 0.5,
	"budget_bonus": {},        # {"<doctrine>": {"pt": x, "cp": y}}
	"potje_factor": 1.0,
	# Expliciete afwijking (blijft bestaan voor experimenten, maar staat NIET
	# meer in de trainer- of arena-configs): een vaste reserve per factie.
	"punten_start_factie": {},
	"punten_start": 0,
	"poolfactor": 1.5,                   # D5: x doctrine-comp per type (3.0 -> 1.5, besluit Max 25 juli)
	"pool_afboeking": true,              # D5: duel-verliezen raken de campagne-pool
	"pools": null,                       # expliciete startpool {"1": {inf,cav,art}, "2": ...} wint van poolfactor
	"cp": null,                          # F3: expliciet CP-saldo per speler {"1": n, "2": n} wint van cp_start
	"comp_override": null,               # F3/C7: startleger per speler {"1": [inf,cav,art], ...} (arm = kleiner starten)
	"spawn_max": 3,                      # D6: totaal per cyclus, over alle types
	"spawn_totaal_max": 15,              # besluit Max 25 juli: max 15 spawns per potje (te testen)
	"spawn_vanaf_cyclus": 2,             # D7: cyclus 1 = volledige PLACEMENT
	"spawn_vakken": "achterste_rij",     # D6: harde hoekfort-rem
	"kanon_dracht_max": 6,               # D8 (handhaving F2.4)
	"kanon_actie_kost": {"roll": 1, "shoot": 1},  # D9, RETREAT bestaat niet (F2.4)
	"pool_zichtbaar": false,             # D12: vijandelijke pool/CP verborgen
	"skip_mode": "auto",                 # D11
}


func campaign_actief() -> bool:
	return campaign is Dictionary


## Recursief: hele floats (JSON-artefact) terug naar int; dicts krijgen
## string-sleutels (JSON-vorm). Poolfactor blijft bewust float (aparte tak).
static func _diep_int(v):
	if v is Dictionary:
		var uit: Dictionary = {}
		for k in v:
			uit[str(k)] = _diep_int(v[k])
		return uit
	if v is Array:
		var lijst: Array = []
		for e in v:
			lijst.append(_diep_int(e))
		return lijst
	if v is float and v == floorf(v):
		return int(v)
	return v


static func defaults() -> RulesConfig:
	return RulesConfig.new()


## Terugslag-schade voor een verdediger-type (JSON-vriendelijke sleutel-namen).
func retaliation_for(unit_type: int) -> int:
	match unit_type:
		Constants.UnitType.INFANTRY:
			return int(retaliation.get("inf", 0))
		Constants.UnitType.CAVALRY:
			return int(retaliation.get("cav", 0))
		Constants.UnitType.ARTILLERY:
			return int(retaliation.get("art", 0))
	return 0


## Doctrine-data met eventuele config-override eroverheen. Onder Strategy mode
## daarna de neutrale allrounder (strategie_data), gecachet per factie: de
## config is per match onveranderlijk en dit draait in hete lussen (Rules).
func doctrine_data(doctrine: int) -> Dictionary:
	if strategie is Dictionary:
		var tabel: Dictionary = _strategie_tabel()
		if tabel.has(doctrine):
			return tabel[doctrine]
		return strategie_data(_factie_data(doctrine), strategie)
	return _factie_data(doctrine)


## De neutrale tabel voor alle facties tegelijk opgebouwd en pas daarna
## toegewezen (de bot-thread en het scherm lezen hem allebei). Opnieuw als
## iemand `strategie` of `doctrines` vervangt (_potje_regels zet de facties na
## het laden). Alleen-lezen voor aanroepers, net als cached_dict.
var _strategie_cache: Dictionary = {}
var _sc_strat = null
var _sc_docs = null


func _strategie_tabel() -> Dictionary:
	if is_same(_sc_strat, strategie) and is_same(_sc_docs, doctrines):
		return _strategie_cache
	var tabel: Dictionary = {}
	for doc in Constants.DOCTRINE_DATA:
		tabel[int(doc)] = strategie_data(_factie_data(int(doc)), strategie)
	_strategie_cache = tabel
	_sc_strat = strategie
	_sc_docs = doctrines
	return tabel


func _factie_data(doctrine: int) -> Dictionary:
	var base: Dictionary = Constants.doctrine_data(doctrine)
	if doctrines.is_empty():
		return base
	var ov = doctrines.get(doctrine, doctrines.get(str(doctrine), null))
	if ov == null:
		return base
	var merged: Dictionary = base.duplicate()
	for k in ov:
		merged[k] = ov[k]
	return merged


## Gecachet dict voor hot-path-lezers (View bouwt per beslissing een view;
## de config is per match onveranderlijk). ALLEEN-LEZEN — muteer dit nooit.
var _dict_cache = null

func cached_dict() -> Dictionary:
	if _dict_cache == null:
		_dict_cache = to_dict()
	return _dict_cache


func to_dict() -> Dictionary:
	var uit := _to_dict_basis()
	# Strategy mode alleen als hij aan staat: zo blijft elk bestaand snapshot
	# (goldens, saves, replays, uispel) byte- en hash-identiek.
	if strategie is Dictionary:
		uit["strategie"] = (strategie as Dictionary).duplicate(true)
	return uit


func _to_dict_basis() -> Dictionary:
	return {
		"rules_version": rules_version,
		"rounds_per_cycle": rounds_per_cycle,
		"pawns_in_haven_to_win": pawns_in_haven_to_win,
		"fire_hits_inactive": fire_hits_inactive,
		"fire_blocked": fire_blocked,
		"inf_shot_over_pawn": inf_shot_over_pawn,
		"statue_threshold": statue_threshold,
		"haven_score_cumulative": haven_score_cumulative,
		"per_stat_cap": per_stat_cap,
		"basis_hp": basis_hp,
		"stat_minimum": stat_minimum,
		"stat_bonus": stat_bonus,
		"schutkleur_onthul_nabij": schutkleur_onthul_nabij,
		"inf_shot_range": inf_shot_range,
		"inf_shot_cost": inf_shot_cost,
		"inf_shot_full_attack": inf_shot_full_attack,
		"art_min_range": art_min_range,
		"art_range": art_range,
		"art_move": art_move,
		"art_shot_cost": art_shot_cost,
		"retaliation": retaliation.duplicate(),
		"stamina_model": stamina_model,
		"honger_vanaf_cyclus": honger_vanaf_cyclus,
		"clock": clock.duplicate(),
		"doctrines": doctrines.duplicate(true),
		"campaign": (campaign as Dictionary).duplicate(true) if campaign is Dictionary else null,
	}


static func from_dict(d: Dictionary) -> RulesConfig:
	var c := RulesConfig.new()
	c.rules_version = String(d.get("rules_version", c.rules_version))
	c.rounds_per_cycle = int(d.get("rounds_per_cycle", c.rounds_per_cycle))
	c.pawns_in_haven_to_win = int(d.get("pawns_in_haven_to_win", c.pawns_in_haven_to_win))
	c.fire_hits_inactive = bool(d.get("fire_hits_inactive", c.fire_hits_inactive))
	c.fire_blocked = bool(d.get("fire_blocked", c.fire_blocked))
	c.inf_shot_over_pawn = bool(d.get("inf_shot_over_pawn", c.inf_shot_over_pawn))
	c.statue_threshold = int(d.get("statue_threshold", c.statue_threshold))
	c.haven_score_cumulative = bool(d.get("haven_score_cumulative", c.haven_score_cumulative))
	c.per_stat_cap = int(d.get("per_stat_cap", c.per_stat_cap))
	c.schutkleur_onthul_nabij = bool(d.get("schutkleur_onthul_nabij", c.schutkleur_onthul_nabij))
	var bhp = d.get("basis_hp", {})
	if bhp is Dictionary:
		for k in bhp:
			c.basis_hp[String(k)] = int(bhp[k])
	var smin = d.get("stat_minimum", {})
	if smin is Dictionary:
		for k in smin:
			if smin[k] is Dictionary:
				var per_type: Dictionary = {}
				for stat in smin[k]:
					per_type[String(stat)] = int(smin[k][stat])
				c.stat_minimum[String(k)] = per_type
	var sbon = d.get("stat_bonus", {})
	if sbon is Dictionary:
		for k in sbon:
			if sbon[k] is Dictionary:
				var per_type2: Dictionary = {}
				for stat in sbon[k]:
					per_type2[String(stat)] = int(sbon[k][stat])
				c.stat_bonus[String(k)] = per_type2
	c.inf_shot_range = int(d.get("inf_shot_range", c.inf_shot_range))
	c.inf_shot_cost = int(d.get("inf_shot_cost", c.inf_shot_cost))
	c.inf_shot_full_attack = bool(d.get("inf_shot_full_attack", c.inf_shot_full_attack))
	c.art_min_range = int(d.get("art_min_range", c.art_min_range))
	c.art_range = int(d.get("art_range", c.art_range))
	c.art_move = int(d.get("art_move", c.art_move))
	c.art_shot_cost = int(d.get("art_shot_cost", c.art_shot_cost))
	var ret = d.get("retaliation", null)
	if ret is Dictionary:
		c.retaliation = {"inf": int(ret.get("inf", 1)), "cav": int(ret.get("cav", 2)), "art": int(ret.get("art", 0))}
	c.stamina_model = String(d.get("stamina_model", c.stamina_model))
	# V0: cycle_limit en tiebreak bestaan niet meer. Oude configs en oude
	# replays dragen ze nog; die worden STIL genegeerd, want ze beschrijven
	# een regel die er niet meer is. Wie een oude arena-config draait krijgt
	# dus geen klok: daarom staat de nieuwe sleutel in elke meegeleverde
	# config, en gilt de runner als een partij op de noodstop eindigt.
	c.honger_vanaf_cyclus = int(d.get("honger_vanaf_cyclus", c.honger_vanaf_cyclus))
	var clk = d.get("clock", null)
	if clk is Dictionary:
		c.clock = {
			"bank_sec": int(clk.get("bank_sec", 0)),
			"increment_sec": int(clk.get("increment_sec", 0)),
			"reconnect_grace_sec": int(clk.get("reconnect_grace_sec", 20)),
		}
	var docs = d.get("doctrines", null)
	if docs is Dictionary:
		# Sleutels blijven STRING ("2"). Ze eerder naar int normaliseren brak de
		# rondreis to_dict -> from_dict: de tweede keer stond er een int in de
		# sleutel en `String(int)` bestaat niet meer in Godot 4.7, waardoor
		# from_dict null teruggaf. De agent reconstrueert zijn staat langs die
		# weg, dus elke bot viel bij ELKE beslissing terug op legal[0] zodra er
		# een doctrines-blok in de regels stond (3 augustus, factiezoeker).
		# doctrine_data() zoekt op beide vormen, dus string is veilig.
		# Waarden door _diep_int: JSON leest 6 terug als 6.0 en comp moet ints
		# houden, anders lekken floats de legergrootte in.
		c.doctrines = {}
		for k in docs:
			c.doctrines[str(k)] = _diep_int(docs[k]) if docs[k] is Dictionary else docs[k]
			# Een leger moet OP HET BORD PASSEN: je stelt op in twee rijen van
			# elf, dus 22 pionnen is de bovengrens. Paste het niet, dan kwam de
			# partij de opstelfase niet uit en liep hij stil door tot de
			# noodstop -- op 4 augustus een derde van een hele zoekrun. Zo'n
			# config is kapot en hoort dat te zeggen, niet te hangen.
			var ov = c.doctrines[str(k)]
			if ov is Dictionary and (ov as Dictionary).has("comp"):
				var comp: Array = (ov as Dictionary)["comp"]
				var totaal: int = 0
				for n in comp:
					totaal += int(n)
				if totaal > Constants.PAWNS_PER_PLAYER:
					push_error(("RulesConfig: doctrine %s heeft een leger van %d pionnen, " +
						"maar er passen er maar %d op het bord. Die partij loopt vast " +
						"in de opstelfase.") % [str(k), totaal, Constants.PAWNS_PER_PLAYER])
	var camp = d.get("campaign", null)
	if camp is Dictionary:
		# Normaliseren: ontbrekende knoppen krijgen de F2.1-besluitwaarden.
		# Sub-dicts gaan door _diep_int (JSON leest ints als floats terug;
		# zonder normalisatie divergeert de Zobrist-hash na een roundtrip).
		var blok: Dictionary = {}
		for k in CAMPAIGN_DEFAULTS:
			var dv = CAMPAIGN_DEFAULTS[k]
			var v = camp.get(k, dv)
			if dv is bool:
				blok[k] = bool(v)
			elif dv is int:
				blok[k] = int(v)
			elif dv is float:
				blok[k] = float(v)
			elif dv is String:
				blok[k] = String(v)
			else:
				blok[k] = _diep_int(v)
		# 4.3.9 kende alleen de schakelaar initiatief_per_hand (een uur in de
		# repo, 7 oktober): een blok dat hem nog draagt houdt die regel.
		if not camp.has("initiatief_deler") and camp.has("initiatief_per_hand"):
			blok["initiatief_deler"] = "hand" if bool(camp["initiatief_per_hand"]) else "kaarten"
		if not BOD_DELERS.has(String(blok["initiatief_deler"])):
			push_error("RulesConfig: initiatief_deler '%s' bestaat niet (%s), teruggezet naar '%s'" % [
				String(blok["initiatief_deler"]), str(BOD_DELERS), CAMPAIGN_DEFAULTS["initiatief_deler"]])
			blok["initiatief_deler"] = CAMPAIGN_DEFAULTS["initiatief_deler"]
		c.campaign = blok
		# D9-validatie: CANNON_ACT put uit de per-pion stamina-cyclusvoorraad;
		# het one_action-model heeft geen pot en wordt onder campaign geweigerd.
		if c.stamina_model == "one_action":
			push_error("RulesConfig: campaign vereist stamina_model 'pool' — one_action geweigerd, teruggezet naar pool")
			c.stamina_model = "pool"
		# Activering van het campaign-blok IS de regelversie-overgang (B7).
		# V0 (3 augustus): het duel kent geen gelijkspel meer en de honger
		# vervangt de cycluslimiet. Dat raakt ELKE partij, met of zonder
		# campagne-blok, dus de basisversie is nu 4.3.0 en het blok houdt zijn
		# eigen trede daarboven.
		# 4.3.8 (5 oktober): steen-papier-schaar bij een volledig gelijk bod;
		# met de knop uit blijft het 4.3.7. 7 oktober: de deler van het bod,
		# "hand" = 4.3.9, "tegenstander" = 4.3.10 (de default), "kaarten" = 4.3.8.
		# Het label volgt altijd de knoppen (alleen een label: het gedrag zit in
		# de knoppen).
		var oud: Array = ["4.3.0", "4.3.1", "4.3.2", "4.3.3", "4.3.4", "4.3.5", "4.3.6", "4.3.7", "4.3.8", "4.3.9", "4.3.10"]
		if c.rules_version.begins_with("4.1") or c.rules_version.begins_with("4.2") or oud.has(c.rules_version):
			match String(blok["initiatief_deler"]):
				"tegenstander":
					c.rules_version = "4.3.10"
				"hand":
					c.rules_version = "4.3.9"
				_:
					c.rules_version = "4.3.8" if bool(blok.get("initiatief_sps", true)) else "4.3.7"
	else:
		c.campaign = null
	var strat = d.get("strategie", null)
	c.strategie = normaliseer_strategie(strat) if strat is Dictionary else null
	return c


static func load_from_file(path: String) -> RulesConfig:
	if not FileAccess.file_exists(path):
		push_error("RulesConfig: bestand niet gevonden: %s" % path)
		return RulesConfig.new()
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if parsed == null or not (parsed is Dictionary):
		push_error("RulesConfig: ongeldige JSON in %s" % path)
		return RulesConfig.new()
	return from_dict(parsed)


func save_to_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
