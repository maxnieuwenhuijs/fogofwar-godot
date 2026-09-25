class_name CampagneArena
extends RefCounted

# F7.1a — de campagne-arena (plan: docs/F7-campagnetrainer.md):
#
#   godot --headless --path . res://arena/arena.tscn -- --campagne --config <json> [--out <map>] [--seed-offset N]
#
# Twee soorten runs:
#
#   "soort": "campagnes"  volledige solo-campagnes met alleen bots (16 stoelen).
#       {"soort": "campagnes", "campagnes": 2, "base_seed": 5000, "spelers": 16,
#        "duel_ai": "easy", "honger": 10, "max_steps": 3000,
#        "teams": [{"naam": "hand", "gewichten": {}}, {"naam": "hand", "gewichten": {}}],
#        "wissel": true}
#     "teams" geeft per team een naam en gewichten die over het profiel van elke
#     bot in dat team heen gaan (leeg = het karakter uit personalities.gd).
#     "wissel": true speelt elke seed ook met de teams omgedraaid, zodat een
#     vergelijking niet aan de loting van de stoelen hangt.
#     "duel_modus": "orakel" (met "orakel": "res://data/duel_orakel.json")
#     trekt de duels uit het duel-orakel in plaats van ze uit te spelen: een
#     campagne kost dan milliseconden (F7.1b).
#     Uitvoer: campagnes.jsonl (een regel per campagne) en duels.jsonl.
#
#   "soort": "duels"  losse campagne-duels over de invoerruimte (de data van het
#       duel-orakel): factie tegen factie, reserve per type, CP.
#       {"soort": "duels", "duels": 200, "base_seed": 7000, "duel_ai": "easy",
#        "honger": 10, "max_steps": 3000, "cp_max": 24}
#     Uitvoer: duels.jsonl.
#
# Beide schrijven duels.jsonl in het formaat van SoloDriver.duel_record: de
# campagne en de datarun tellen een duel precies hetzelfde. Regel 1 van elk
# bestand is de run-metadata. Geen wandklok in de regels behalve "ms" (de duur
# van een duel, om de datarun te plannen).


## Via preload, niet via de klassenaam: dan werkt de arena ook voordat de
## editor de klasse heeft ingeschreven.
const _Orakel := preload("res://scripts/training/duel_orakel.gd")


static func run(config: Dictionary, out_map: String, seed_offset: int, git_sha: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_map))
	var meta := {"run_meta": true, "git_sha": git_sha, "ts": Time.get_datetime_string_from_system(),
		"config": config, "seed_offset": seed_offset,
		"doctrines": CRules.facties_uit_bestand()}
	var soort := String(config.get("soort", "campagnes"))
	if soort == "duels":
		return _run_duels(config, out_map, seed_offset, meta)
	return _run_campagnes(config, out_map, seed_offset, meta)


# --- Volledige campagnes -------------------------------------------------------

static func _run_campagnes(config: Dictionary, out_map: String, seed_offset: int, meta: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var f_camp := FileAccess.open(out_map.path_join("campagnes.jsonl"), FileAccess.WRITE)
	var f_duel := FileAccess.open(out_map.path_join("duels.jsonl"), FileAccess.WRITE)
	f_camp.store_line(JSON.stringify(meta))
	f_duel.store_line(JSON.stringify(meta))
	var teams: Array = config.get("teams", [{"naam": "hand", "gewichten": {}}, {"naam": "hand", "gewichten": {}}])
	var n := int(config.get("campagnes", 1))
	var base_seed := int(config.get("base_seed", 5000))
	var wissel := bool(config.get("wissel", false))
	var gespeeld := 0
	var duels := 0
	for i in n:
		var seed_val: int = base_seed + seed_offset + i
		for omgedraaid in ([false, true] if wissel else [false]):
			var indeling: Array = [teams[1], teams[0]] if omgedraaid else [teams[0], teams[1]]
			var uit := speel_campagne(config, seed_val, indeling)
			uit["omgedraaid"] = omgedraaid
			f_camp.store_line(JSON.stringify(uit.samenvatting))
			for d in uit.duels:
				d["campagne"] = seed_val
				d["omgedraaid"] = omgedraaid
				f_duel.store_line(JSON.stringify(d))
			duels += (uit.duels as Array).size()
			gespeeld += 1
			print("[CAMPAGNE] seed %d%s: team %d wint (%s), %d rondes, %d duels, %.0f s" % [
				seed_val, " (omgedraaid)" if omgedraaid else "", int(uit.samenvatting.winnend_team),
				String(uit.samenvatting.winnaar_naam), int(uit.samenvatting.rondes),
				int(uit.samenvatting.duels), float(uit.samenvatting.ms) / 1000.0])
	f_camp.close()
	f_duel.close()
	return {"campagnes": gespeeld, "duels": duels, "duur": (Time.get_ticks_msec() - t0) / 1000.0,
		"pad": out_map}


## Een campagne met alleen bots; `indeling` = [team 0, team 1], elk
## {"naam", "gewichten"}. Geeft {samenvatting, duels}.
static func speel_campagne(config: Dictionary, seed_val: int, indeling: Array) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var driver := SoloDriver.new(seed_val, -1, int(config.get("spelers", 16)), "")
	driver.duel_ai = String(config.get("duel_ai", "easy"))
	driver.duel_honger_vanaf = int(config.get("honger", 10))
	driver.duel_max_steps = int(config.get("max_steps", 3000))
	driver.duel_log = [] if bool(config.get("duel_log", true)) else null
	if String(config.get("duel_modus", "echt")) == "orakel":
		driver.orakel = _Orakel.laad(String(config.get("orakel", _Orakel.STANDAARD)))
		if driver.orakel != null:
			driver.duel_modus = "orakel"
	for sid in driver.agents:
		var agent: CampaignAgent = driver.agents[sid]
		var team: int = int(driver.c.spelers[sid].team)
		var team_cfg: Dictionary = indeling[team]
		var gewichten: Dictionary = team_cfg.get("gewichten", {})
		for sleutel in gewichten:
			agent.profiel[sleutel] = gewichten[sleutel]
		# F7.2a: het verstand van dit team (ontbreekt de sleutel, dan het
		# verstand uit data/campagne_verstand.json dat de driver al zette).
		if team_cfg.has("verstand"):
			agent.verstand = team_cfg.verstand
	# De bots mogen het orakel raadplegen voor hun winkans (F7.2a).
	var bots_orakel = driver.orakel
	if bots_orakel == null and FileAccess.file_exists(_Orakel.STANDAARD):
		bots_orakel = _Orakel.laad()
	if bots_orakel != null:
		driver.zet_orakel_voor_bots(bots_orakel)
	var kampioen: int = driver.run_headless(int(config.get("max_stappen", 600)))
	var c: CState = driver.c
	var samenvatting := {
		"seed": seed_val,
		"teams": [String(indeling[0].get("naam", "")), String(indeling[1].get("naam", ""))],
		"klaar": c.fase == CState.Fase.KLAAR,
		"winnaar": kampioen,
		"winnaar_naam": String(c.spelers.get(kampioen, {}).get("naam", "-")),
		"winnaar_doctrine": int(c.spelers.get(kampioen, {}).get("doctrine", -1)),
		"winnaar_archetype": String(_archetype(driver, kampioen)),
		"winnend_team": int(c.spelers.get(kampioen, {}).get("team", -1)),
		"rondes": c.ronde,
		"duels": driver.duels_gespeeld,
		"ms": Time.get_ticks_msec() - t0,
	}
	# Wat er in het menu gebeurde (F7.1-metrics): donaties, ruil, testamenten,
	# de burgeroorlog, en wat de kampioen overhield (poolfactor-validatie).
	var don_n := 0
	var don_pt := 0
	var ruil_n := 0
	var test_n := 0
	var test_vijand := 0
	var burgeroorlog := false
	for e in driver.feed:
		var t := String(e.get("type", ""))
		if t == "event":
			match String(e.get("soort", "")):
				"donatie":
					don_n += 1
					don_pt += int(e.get("inf", 0)) + 2 * int(e.get("cav", 0)) + 3 * int(e.get("art", 0))
				"ruil":
					ruil_n += 1
				"testament":
					test_n += 1
					var gever: int = int(e.get("speler", -1))
					var naar: int = int(e.get("naar", -1))
					if c.spelers.has(gever) and c.spelers.has(naar) \
							and int(c.spelers[gever].team) != int(c.spelers[naar].team):
						test_vijand += 1
		elif t == "fase" and int(e.get("naar", -1)) == CState.Fase.BURGEROORLOG:
			burgeroorlog = true
	samenvatting["donaties"] = don_n
	samenvatting["donatie_pt"] = don_pt
	samenvatting["ruil"] = ruil_n
	samenvatting["testamenten"] = test_n
	samenvatting["testament_naar_vijand"] = test_vijand
	samenvatting["burgeroorlog"] = burgeroorlog
	if kampioen >= 0:
		# In punten (C11: soldaat 1, ruiter 2, kanon 3), niet in stuks: de
		# getypeerde voorraad kan per soort negatief staan (ruiters gespawnd
		# uit soldatenpunten), dus pool_totaal_van zegt hier weinig.
		samenvatting["kampioen_pool"] = _Orakel.punten(c.pool_van(kampioen))
		samenvatting["kampioen_cp"] = c.cp_van(kampioen)
	return {"samenvatting": samenvatting, "duels": driver.duel_log if driver.duel_log != null else []}


static func _archetype(driver: SoloDriver, sid: int) -> String:
	if not driver.agents.has(sid):
		return ""
	var profiel: Dictionary = (driver.agents[sid] as CampaignAgent).profiel
	for naam in Personalities.ARCHETYPES:
		if (Personalities.ARCHETYPES[naam] as Dictionary).get("barks", {}) == profiel.get("barks", {}):
			return String(naam)
	return ""


# --- Losse duels (de data van het orakel) ----------------------------------------

static func _run_duels(config: Dictionary, out_map: String, seed_offset: int, meta: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var f := FileAccess.open(out_map.path_join("duels.jsonl"), FileAccess.WRITE)
	f.store_line(JSON.stringify(meta))
	var regels := CRules.new()
	regels.doctrines = CRules.facties_uit_bestand()
	var ai := String(config.get("duel_ai", "easy"))
	var honger := int(config.get("honger", 10))
	var max_steps := int(config.get("max_steps", 3000))
	var cp_max := int(config.get("cp_max", 24))
	var facties: Array = Constants.DOCTRINE_DATA.keys()
	var rng := SeededRng.new(int(config.get("base_seed", 7000)) + seed_offset)
	var n := int(config.get("duels", 100))
	for i in n:
		var fa: int = int(facties[rng.randi_range(0, facties.size() - 1)])
		var fb: int = int(facties[rng.randi_range(0, facties.size() - 1)])
		var comp_a: Array = regels.doctrine_data(fa).comp
		var comp_b: Array = regels.doctrine_data(fb).comp
		var pool_a := trek_reserve(rng, comp_a, regels.duel_spawn_totaal_max)
		var pool_b := trek_reserve(rng, comp_b, regels.duel_spawn_totaal_max)
		var cp_a := rng.randi_range(0, cp_max)
		var cp_b := rng.randi_range(0, cp_max)
		var rules := SoloDriver.duel_regels(regels.doctrines, comp_a.duplicate(), comp_b.duplicate(),
			pool_a, pool_b, cp_a, cp_b, honger)
		var seed_v := rng.randi_range(1, 1 << 30)
		var d0 := Time.get_ticks_msec()
		var uit: Array = SoloDriver.speel_duel_staat(ai, fa, fb, seed_v, rules, max_steps)
		var ms := Time.get_ticks_msec() - d0
		var winnaar: int = int(uit[1])
		if winnaar == -1:
			push_error("CampagneArena: duel zonder winnaar (noodstop), seed %d" % seed_v)
			continue
		var u := SoloDriver.duel_uitkomst(uit[0], winnaar, cp_a, cp_b, true)
		var rec := SoloDriver.duel_record(fa, fb, rules, cp_a, cp_b, u, ai, ms)
		rec["seed"] = seed_v
		f.store_line(JSON.stringify(rec))
		if (i + 1) % 10 == 0:
			print("[CAMPAGNE] %d/%d duels (%.1f s per duel)" % [i + 1, n,
				(Time.get_ticks_msec() - t0) / 1000.0 / float(i + 1)])
	f.close()
	return {"campagnes": 0, "duels": n, "duur": (Time.get_ticks_msec() - t0) / 1000.0, "pad": out_map}


## Een reserve zoals een campagne hem meegeeft: per type, samen hooguit `cap`
## pionnen, en alleen typen die de factie heeft (Muis en Beer: geen kanonnen).
## Soldaten vaak, ruiters soms, kanonnen zelden; ook een lege reserve komt voor.
static func trek_reserve(rng: SeededRng, comp: Array, cap: int) -> Dictionary:
	var inf := rng.randi_range(0, cap)
	var cav := 0
	if int(comp[1]) > 0 and rng.randf() < 0.6:
		cav = rng.randi_range(0, mini(5, cap - inf))
	var art := 0
	if int(comp[2]) > 0 and rng.randf() < 0.35:
		art = rng.randi_range(0, mini(3, cap - inf - cav))
	return {"inf": inf, "cav": cav, "art": art}
