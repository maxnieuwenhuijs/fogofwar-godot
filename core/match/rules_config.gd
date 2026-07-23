class_name RulesConfig
extends RefCounted

# F0.2 — alle regelknoppen als data. Eén RulesConfig per match, onveranderlijk
# tijdens de partij (GameState.clone() deelt daarom de referentie). De defaults
# zijn exact het 4.1.9-hr-gedrag; elke afwijking is een bewuste config-keuze
# die met rules_version + CHANGELOG-entry hoort te reizen.
#
# Handhaving per knop:
# - vuurmodel/schot/terugslag/stamina/haven: Rules.gd (deze stap, F0.2)
# - cycle_limit + tiebreak: reducer (F0.4c)
# - clock: engine-klokken (F0.8)
# - campaign (cp/pool/spawn/cannon): v4.2 (F2); null = puur 4.1-gedrag

var rules_version: String = "4.1.10-hr"
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

# --- Partijgrenzen (handhaving F0.4c) ---
var cycle_limit: int = 0              # 0 = uit; anders remise/tiebreak na N cycli
var tiebreak: String = "material_haven_proximity"

# --- Klokken (handhaving F0.8) ---
var clock: Dictionary = {"bank_sec": 0, "increment_sec": 0, "reconnect_grace_sec": 20}

# --- Doctrine-overrides: {doctrine-int: {veld: waarde}} bovenop DOCTRINE_DATA ---
var doctrines: Dictionary = {}

# --- v4.2-campagneblok (F2); null = v4.1-gedrag ---
var campaign = null


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


## Doctrine-data met eventuele config-override eroverheen.
func doctrine_data(doctrine: int) -> Dictionary:
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


func to_dict() -> Dictionary:
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
		"inf_shot_range": inf_shot_range,
		"inf_shot_cost": inf_shot_cost,
		"inf_shot_full_attack": inf_shot_full_attack,
		"art_min_range": art_min_range,
		"art_range": art_range,
		"art_move": art_move,
		"art_shot_cost": art_shot_cost,
		"retaliation": retaliation.duplicate(),
		"stamina_model": stamina_model,
		"cycle_limit": cycle_limit,
		"tiebreak": tiebreak,
		"clock": clock.duplicate(),
		"doctrines": doctrines.duplicate(true),
		"campaign": campaign,
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
	c.cycle_limit = int(d.get("cycle_limit", c.cycle_limit))
	c.tiebreak = String(d.get("tiebreak", c.tiebreak))
	var clk = d.get("clock", null)
	if clk is Dictionary:
		c.clock = {
			"bank_sec": int(clk.get("bank_sec", 0)),
			"increment_sec": int(clk.get("increment_sec", 0)),
			"reconnect_grace_sec": int(clk.get("reconnect_grace_sec", 20)),
		}
	var docs = d.get("doctrines", null)
	if docs is Dictionary:
		# JSON maakt sleutels strings; normaliseer naar int waar mogelijk.
		c.doctrines = {}
		for k in docs:
			var ik: Variant = int(String(k)) if String(k).is_valid_int() else k
			c.doctrines[ik] = (docs[k] as Dictionary).duplicate(true) if docs[k] is Dictionary else docs[k]
	c.campaign = d.get("campaign", null)
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
