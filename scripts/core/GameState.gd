class_name GameState
extends RefCounted

var phase: int = Phase.Type.PRE_GAME
var cycle: int = 1
var round_number: int = 1

# F0.2: alle regelknoppen als data; onveranderlijk tijdens de match
# (clone() deelt daarom de referentie in plaats van te kopiëren).
var rules: RulesConfig = RulesConfig.defaults()

# Cumulatieve haven-score (rules.haven_score_cumulative): per speler de ids
# van pionnen die ooit een eigen havenvak hebben aangeraakt.
var haven_touches: Dictionary = {
	Constants.PLAYER_1: {},
	Constants.PLAYER_2: {},
}
var current_player: int = Constants.PLAYER_1
var initiative_player: int = Constants.PLAYER_1
var last_initiative_winner: int = Constants.PLAYER_1

# Doctrine per speler (Constants.Doctrine); vast voor de hele partij.
var doctrines: Dictionary = {}

var pawns: Dictionary = {}
var board: Array = []

var cards_defined: Dictionary = {
	Constants.PLAYER_1: [],
	Constants.PLAYER_2: [],
}
var cards_revealed: Dictionary = {
	Constants.PLAYER_1: [],
	Constants.PLAYER_2: [],
}
var all_cards: Dictionary = {}

# Vrije opstelling (v4.1): welke spelers hun opstelling al hebben ingediend.
var placements_done: Dictionary = {}

# Per-speler reveal-bevestiging (F0.4b): de fase gaat pas door als beide
# spelers geackt hebben (het oude single-ack-gat is hiermee dicht).
var reveal_acks: Dictionary = {}

# Wolf-doctrine: pion die na zijn melee nog een optionele gratis stap tegoed heeft.
var pending_wolf_step_pawn: int = -1

# F0.8 — klokken in de staat (rules.clock; bank_sec 0 = klokken uit).
# clocks[speler] = {bank_ms}; turn_deadline is absolute tijd (now_ms-domein
# van de aanroeper: server = servertijd, tests = eigen teller). De reducer
# leest zelf nooit een klok (puur): now_ms komt als parameter mee.
var clocks: Dictionary = {}
var turn_deadline: int = 0

# F2.2 (v4.2) — pionnen-pool per speler {inf, cav, art}; leeg dict = geen
# campaign (4.1-gedrag). spawn_commits[speler] = de blinde spawn-inzet
# (Array [{type, pos}]); spawn_done[speler] markeert "ingediend" — een lege
# inzet is een geldige keuze, dus size==0 kan hier geen commit-signaal zijn.
var pools: Dictionary = {}
var spawn_commits: Dictionary = {}
var spawn_done: Dictionary = {}
# Totaal geslaagde spawns per speler dit POTJE (besluit Max: max
# campaign.spawn_totaal_max = 15) — telt niet per cyclus terug.
var spawn_totaal: Dictionary = {}

# F2.3 (v4.2) — commandopunten. cp[speler] = saldo (init cp_start; leeg dict =
# geen campaign). cp_bets[speler] = de blinde inzet van de HUIDIGE setup-ronde
# (D1: elke ingezette CP staat 1 kaart met budget+1 toe); cp_bet_done markeert
# "ingediend" (bet 0 is een geldige keuze). Inzet is direct verbrand (D2).
var cp: Dictionary = {}
var cp_bets: Dictionary = {}
var cp_bet_done: Dictionary = {}

var winner: int = -1

var _next_pawn_id: int = 0
var _next_card_id: int = 0

func _init() -> void:
	_initialize_board()
	doctrines = {
		Constants.PLAYER_1: Constants.Doctrine.MENS,
		Constants.PLAYER_2: Constants.Doctrine.MENS,
	}
	placements_done = {}

func _initialize_board() -> void:
	board = []
	for y in range(Constants.BOARD_SIZE):
		var row: Array = []
		for x in range(Constants.BOARD_SIZE):
			row.append(Constants.EMPTY_TILE)
		board.append(row)

func doctrine_of(player_id: int) -> int:
	return doctrines.get(player_id, Constants.Doctrine.MENS)

func doctrine_data_of(player_id: int) -> Dictionary:
	# Config-overrides (rules.doctrines) gaan bovenop DOCTRINE_DATA;
	# zonder overrides is dit het snelle pad (geen merge).
	var data: Dictionary = rules.doctrine_data(doctrine_of(player_id))
	# F3/C7 — per-speler startleger uit de campagnelaag (arm = kleiner starten).
	if rules.campaign_actief():
		var override = rules.campaign.get("comp_override", null)
		if override is Dictionary and override.has(str(player_id)):
			data = data.duplicate()
			var c = override[str(player_id)]
			data.comp = [int(c[0]), int(c[1]), int(c[2])]
	return data

## Standaard-opstelling voor beide spelers (gebruikt door tests, AI en auto-plaatsing).
func setup_initial_pawns() -> void:
	for player_id in [Constants.PLAYER_1, Constants.PLAYER_2]:
		apply_placement(player_id, default_placement(player_id))
	init_pools()


## F2.2/F2.3 — campagne-init: startpool (expliciete waarde uit het campaign-
## blok wint (D5, de campagnelaag levert hem in F3 aan); anders poolfactor x
## de doctrine-comp per type) én het CP-startsaldo (D13: altijd exact
## cp_start). Zonder campaign blijft alles leeg (4.1-gedrag).
func init_pools() -> void:
	if not rules.campaign_actief():
		return
	var expliciet = rules.campaign.get("pools", null)
	var factor: float = float(rules.campaign.get("poolfactor", 3.0))
	pools = {}
	var cp_expliciet = rules.campaign.get("cp", null)
	cp = {}
	for pid in [Constants.PLAYER_1, Constants.PLAYER_2]:
		if cp_expliciet is Dictionary and cp_expliciet.has(str(pid)):
			cp[pid] = int(cp_expliciet[str(pid)])
		else:
			cp[pid] = int(rules.campaign.get("cp_start", 6))
	for player_id in [Constants.PLAYER_1, Constants.PLAYER_2]:
		if punten_model():
			# C11 (besluit Max, 27 juli): de reserve is EEN puntenpot; spawnen
			# koopt een pion (soldaat 1 / ruiter 2 / kanon 3). Een expliciete
			# typed-pool uit de (nog typed) campagnelaag wordt op waarde omgezet.
			var pt: int = 0
			# C16: eerst de factie-tabel, anders de vaste waarde voor iedereen.
			var vast: int = int(rules.campaign.get("punten_start", 0))
			var per_factie = rules.campaign.get("punten_start_factie", {})
			if per_factie is Dictionary:
				var sleutel := str(int(doctrines.get(player_id, 0)))
				if per_factie.has(sleutel):
					vast = int(per_factie[sleutel])
			if vast > 0 and not (expliciet is Dictionary and expliciet.has(str(player_id))):
				pools[player_id] = {"pt": vast}
				continue
			if expliciet is Dictionary and expliciet.has(str(player_id)):
				var ex = expliciet[str(player_id)]
				if ex is Dictionary:
					pt = int(ex.get("inf", 0)) * spawn_kosten(Constants.UnitType.INFANTRY) 						+ int(ex.get("cav", 0)) * spawn_kosten(Constants.UnitType.CAVALRY) 						+ int(ex.get("art", 0)) * spawn_kosten(Constants.UnitType.ARTILLERY)
				else:
					pt = int(ex)
			else:
				var comp_p: Array = doctrine_data_of(player_id).comp
				for t in 3:
					pt += int(floor(comp_p[t] * factor)) * spawn_kosten(t)
			pools[player_id] = {"pt": pt}
			continue
		if expliciet is Dictionary and expliciet.has(str(player_id)):
			var e: Dictionary = expliciet[str(player_id)]
			pools[player_id] = {"inf": int(e.get("inf", 0)), "cav": int(e.get("cav", 0)), "art": int(e.get("art", 0))}
		else:
			var comp: Array = doctrine_data_of(player_id).comp
			pools[player_id] = {
				"inf": int(floor(comp[0] * factor)),
				"cav": int(floor(comp[1] * factor)),
				"art": int(floor(comp[2] * factor)),
			}


## C11 — punten-model actief? (default "typen": alle oude configs/goldens
## gedragen zich byte-identiek; v4.2-configs zetten expliciet "punten" aan.)
func punten_model() -> bool:
	if not rules.campaign_actief():
		return false  # 4.1: geen campaign-blok, campaign is null
	return String(rules.campaign.get("pool_model", "typen")) == "punten"


func spawn_kosten(unit_type: int) -> int:
	if not rules.campaign_actief():
		return 1
	var kosten: Dictionary = rules.campaign.get("spawn_kosten", {"inf": 1, "cav": 2, "art": 3})
	return int(kosten.get(["inf", "cav", "art"][unit_type], 1))


## Totale pool-voorraad van een speler (0 zonder campaign).
## C15: punten bijschrijven op de reserve (buit van een vaandel). In de
## punten-economie gaat dat op "pt"; in het oude typed-model boeken we het als
## soldaten, zodat er niets stuk gaat als iemand met typed pools speelt.
func pool_bijschrijven(player_id: int, punten: int) -> void:
	if punten <= 0 or not pools.has(player_id):
		return
	if punten_model():
		pools[player_id]["pt"] = int(pools[player_id].get("pt", 0)) + punten
	else:
		pools[player_id]["inf"] = int(pools[player_id].get("inf", 0)) + punten


func pool_total(player_id: int) -> int:
	var p: Dictionary = pools.get(player_id, {})
	if punten_model():
		return int(p.get("pt", 0))
	return int(p.get("inf", 0)) + int(p.get("cav", 0)) + int(p.get("art", 0))


## Pool-saldo per unit-type (sleutels: Constants.UnitType).
## Mag deze factie dit type überhaupt in het veld brengen? (BUGFIX Max,
## 28 juli: met één puntenpot kon een Muis -- comp 18/4/0, dus GEEN
## artillerie -- ineens een kanon kopen. Je koopt alleen wat je doctrine
## kent; het punten-model bepaalt hoevéél, niet wát.)
func kent_type(player_id: int, unit_type: int) -> bool:
	var comp: Array = doctrine_data_of(player_id).comp
	return unit_type >= 0 and unit_type < comp.size() and int(comp[unit_type]) > 0


func pool_count(player_id: int, unit_type: int) -> int:
	var p: Dictionary = pools.get(player_id, {})
	if punten_model():
		if not kent_type(player_id, unit_type):
			return 0
		return int(p.get("pt", 0)) / spawn_kosten(unit_type)
	match unit_type:
		Constants.UnitType.INFANTRY:
			return int(p.get("inf", 0))
		Constants.UnitType.CAVALRY:
			return int(p.get("cav", 0))
		Constants.UnitType.ARTILLERY:
			return int(p.get("art", 0))
	return 0


func pool_take(player_id: int, unit_type: int) -> void:
	if punten_model():
		pools[player_id]["pt"] = int(pools[player_id].get("pt", 0)) - spawn_kosten(unit_type)
	else:
		var sleutel: String = ["inf", "cav", "art"][unit_type]
		pools[player_id][sleutel] = int(pools[player_id][sleutel]) - 1
	spawn_totaal[player_id] = int(spawn_totaal.get(player_id, 0)) + 1


## Hoeveel spawns dit potje nog mogen (campaign.spawn_totaal_max, besluit Max).
func spawns_over(player_id: int) -> int:
	if not rules.campaign_actief():
		return 0
	var limiet: int = int(rules.campaign.get("spawn_totaal_max", 15))
	return maxi(0, limiet - int(spawn_totaal.get(player_id, 0)))

## Plaats de pionnen van één speler volgens een placement-lijst [{type, pos}, ...].
func apply_placement(player_id: int, placements: Array) -> void:
	for entry in placements:
		# C15: de opstelling mag per pion een figurant-rol meegeven
		# ("flag"/"drum"). Ontbreekt hij, dan is het een gewone soldaat.
		var pion := _spawn_pawn(player_id, entry.pos, int(entry.type))
		pion.rol = String(entry.get("rol", ""))
	placements_done[player_id] = true

## Verwijder de pionnen van één speler weer (her-opstellen tijdens de PLACEMENT-fase).
func clear_placement(player_id: int) -> void:
	var to_remove: Array = []
	for pawn in pawns.values():
		if pawn.owner_id == player_id:
			to_remove.append(pawn)
	for pawn in to_remove:
		board[pawn.position.y][pawn.position.x] = Constants.EMPTY_TILE
		pawns.erase(pawn.id)
	placements_done.erase(player_id)

## Redelijke standaard-opstelling volgens doctrine-samenstelling (v4.1 §2.2/§3.3):
## artillerie vóór op flanken/centrum (schootsveld), infanterie vult de voorste rij
## aan en dan het centrum achter, cavalerie op de achterste rij (randen).
## C15: vaandels en tamboers over de opstelling verdelen. Op de achterste rij is
## de index ook echt de afstand, dus vlag op 0 en 4, tamboer op 2 en 6 geeft
## minimaal 4 vakken tussen twee gelijke rollen (besluit Max, 30 juli). Bots en
## de "vul automatisch"-knop gebruiken dit; de mens kan het in de opstelfase
## zelf aanwijzen.
func _rollen_over_opstelling(placements: Array) -> void:
	if not campaign_actief_rollen():
		return
	var vlaggen: int = int(rules.campaign.get("vaandels_max", 2))
	var tamboers: int = int(rules.campaign.get("tamboers_max", 2))
	if vlaggen <= 0 and tamboers <= 0:
		return
	# Alleen infanterie kan dragen; op leesbare afstand van elkaar.
	var kandidaten: Array = []
	for i in placements.size():
		if int(placements[i].get("type", 0)) == Constants.UnitType.INFANTRY:
			kandidaten.append(i)
	if kandidaten.is_empty():
		return
	var stap: int = maxi(2, int(floor(float(kandidaten.size()) / float(maxi(1, vlaggen + tamboers)))))
	var beurt: Array = []
	for n in vlaggen:
		beurt.append("flag")
	for n in tamboers:
		beurt.append("drum")
	# Afwisselen zodat vlag en tamboer niet naast elkaar staan.
	beurt.sort_custom(func(a: String, b: String) -> bool: return a < b)
	var i2: int = 0
	var plek: int = 0
	while i2 < beurt.size() and plek < kandidaten.size():
		placements[kandidaten[plek]]["rol"] = String(beurt[i2])
		i2 += 1
		plek += stap


func default_placement(player_id: int) -> Array:
	var comp: Array = doctrine_data_of(player_id).comp
	var rows: Array = Constants.get_start_rows_for_player(player_id)
	var back_row: int = rows[0]
	var front_row: int = rows[1]
	var placements: Array = []

	# Volgordes: centrum-uit voor infanterie, flanken-eerst voor artillerie/cavalerie.
	var art_slots: Array = [0, 10, 5]
	var center_out: Array = [5, 4, 6, 3, 7, 2, 8, 1, 9, 0, 10]
	var edges_in: Array = [0, 10, 1, 9, 2, 8, 3, 7, 4, 6, 5]

	var front_used: Dictionary = {}
	var back_used: Dictionary = {}

	var art_left: int = comp[2]
	for x in art_slots:
		if art_left <= 0:
			break
		placements.append({"type": Constants.UnitType.ARTILLERY, "pos": Vector2i(x, front_row)})
		front_used[x] = true
		art_left -= 1

	var inf_left: int = comp[0]
	for x in center_out:
		if inf_left <= 0:
			break
		if front_used.has(x):
			continue
		placements.append({"type": Constants.UnitType.INFANTRY, "pos": Vector2i(x, front_row)})
		front_used[x] = true
		inf_left -= 1
	for x in center_out:
		if inf_left <= 0:
			break
		if back_used.has(x):
			continue
		placements.append({"type": Constants.UnitType.INFANTRY, "pos": Vector2i(x, back_row)})
		back_used[x] = true
		inf_left -= 1

	var cav_left: int = comp[1]
	for x in edges_in:
		if cav_left <= 0:
			break
		if back_used.has(x):
			continue
		placements.append({"type": Constants.UnitType.CAVALRY, "pos": Vector2i(x, back_row)})
		back_used[x] = true
		cav_left -= 1
	for x in edges_in:
		if cav_left <= 0:
			break
		if front_used.has(x):
			continue
		placements.append({"type": Constants.UnitType.CAVALRY, "pos": Vector2i(x, front_row)})
		front_used[x] = true
		cav_left -= 1

	_rollen_over_opstelling(placements)   # C15: vaandels/tamboers erbij
	return placements

## Valideer een placement-lijst voor een speler (samenstelling, thuisrijen, uniek).
func is_valid_placement(player_id: int, placements: Array) -> bool:
	var comp: Array = doctrine_data_of(player_id).comp
	var counts: Array = [0, 0, 0]
	var rows: Array = Constants.get_start_rows_for_player(player_id)
	var seen: Dictionary = {}
	var rollen: Dictionary = {}
	for entry in placements:
		if not (entry is Dictionary) or not entry.has("type") or not entry.has("pos"):
			return false
		var t: int = int(entry.type)
		var pos: Vector2i = entry.pos
		if t < 0 or t > 2:
			return false
		if not Constants.is_on_board(pos) or not rows.has(pos.y):
			return false
		if seen.has(pos):
			return false
		if not is_tile_empty(pos):
			return false
		seen[pos] = true
		counts[t] += 1
		# C15: figurant-rollen. Alleen op infanterie, alleen de twee bekende
		# rollen, en niet meer dan de regels toestaan.
		var rol := String(entry.get("rol", ""))
		if rol != "":
			if rol != "flag" and rol != "drum":
				return false
			if t != Constants.UnitType.INFANTRY:
				return false
			rollen[rol] = int(rollen.get(rol, 0)) + 1
	if not campaign_actief_rollen():
		if not rollen.is_empty():
			return false   # zonder campagne bestaan figurant-rollen niet
	else:
		if int(rollen.get("flag", 0)) > int(rules.campaign.get("vaandels_max", 2)):
			return false
		if int(rollen.get("drum", 0)) > int(rules.campaign.get("tamboers_max", 2)):
			return false
	return counts[0] == comp[0] and counts[1] == comp[1] and counts[2] == comp[2]


## Kleine hulp: mogen er figurant-rollen in de opstelling staan? (C15 hangt aan
## het campagne-blok, zodat 4.1 byte-identiek blijft.)
func campaign_actief_rollen() -> bool:
	return rules != null and rules.campaign_actief()

func _spawn_pawn(owner_id: int, pos: Vector2i, unit_type: int = Constants.UnitType.INFANTRY) -> Pawn:
	var pawn := Pawn.new(_next_pawn_id, owner_id, pos, unit_type)
	_next_pawn_id += 1
	pawns[pawn.id] = pawn
	board[pos.y][pos.x] = pawn.id
	return pawn

func next_card_id() -> int:
	var id := _next_card_id
	_next_card_id += 1
	return id

func get_pawn_at(pos: Vector2i) -> Pawn:
	if not Constants.is_on_board(pos):
		return null
	var id: int = board[pos.y][pos.x]
	if id == Constants.EMPTY_TILE:
		return null
	return pawns.get(id, null)

func is_tile_empty(pos: Vector2i) -> bool:
	if not Constants.is_on_board(pos):
		return false
	return board[pos.y][pos.x] == Constants.EMPTY_TILE

func set_pawn_position(pawn: Pawn, new_pos: Vector2i) -> void:
	board[pawn.position.y][pawn.position.x] = Constants.EMPTY_TILE
	pawn.position = new_pos
	board[new_pos.y][new_pos.x] = pawn.id
	# Cumulatieve haven-score: élke positie-wijziging (move/charge/verplichte
	# verplaatsing/Wolf-stap) loopt hierdoor, dus dit ene haakje dekt alles.
	if rules.haven_score_cumulative \
			and Constants.get_haven_for_player(pawn.owner_id).has(new_pos):
		haven_touches[pawn.owner_id][pawn.id] = true

func remove_pawn(pawn: Pawn) -> void:
	board[pawn.position.y][pawn.position.x] = Constants.EMPTY_TILE
	pawn.is_eliminated = true
	pawn.is_active = false

func get_active_pawns_for(player_id: int) -> Array:
	var result: Array = []
	for pawn in pawns.values():
		if pawn.owner_id == player_id and pawn.is_active and not pawn.is_eliminated:
			result.append(pawn)
	return result

## F1.3: tellen zonder array-allocatie (draait in check_win na élke actie).
func count_alive_pawns_for(player_id: int) -> int:
	var n: int = 0
	for pawn in pawns.values():
		if pawn.owner_id == player_id and not pawn.is_eliminated:
			n += 1
	return n

func get_alive_pawns_for(player_id: int) -> Array:
	var result: Array = []
	for pawn in pawns.values():
		if pawn.owner_id == player_id and not pawn.is_eliminated:
			result.append(pawn)
	return result

func reset_for_new_cycle() -> void:
	for pawn in pawns.values():
		if not pawn.is_eliminated:
			pawn.unlink()
	cards_defined[Constants.PLAYER_1] = []
	cards_defined[Constants.PLAYER_2] = []
	cards_revealed[Constants.PLAYER_1] = []
	cards_revealed[Constants.PLAYER_2] = []
	pending_wolf_step_pawn = -1
	spawn_commits = {}
	spawn_done = {}
	cp_bets = {}
	cp_bet_done = {}
	cycle += 1
	round_number = 1

func reset_for_new_round() -> void:
	cards_defined[Constants.PLAYER_1] = []
	cards_defined[Constants.PLAYER_2] = []
	cards_revealed[Constants.PLAYER_1] = []
	cards_revealed[Constants.PLAYER_2] = []
	cp_bets = {}
	cp_bet_done = {}

func clone() -> GameState:
	var copy := GameState.new()
	copy.rules = rules  # config is per match onveranderlijk → referentie delen
	copy.haven_touches = {}
	for player_id in haven_touches:
		copy.haven_touches[player_id] = haven_touches[player_id].duplicate()
	copy.phase = phase
	copy.cycle = cycle
	copy.round_number = round_number
	copy.current_player = current_player
	copy.initiative_player = initiative_player
	copy.last_initiative_winner = last_initiative_winner
	copy.winner = winner
	copy.doctrines = doctrines.duplicate()
	copy.placements_done = placements_done.duplicate()
	copy.reveal_acks = reveal_acks.duplicate()
	copy.pending_wolf_step_pawn = pending_wolf_step_pawn
	copy.clocks = clocks.duplicate(true)
	copy.turn_deadline = turn_deadline
	copy.pools = pools.duplicate(true)
	copy.spawn_commits = spawn_commits.duplicate(true)
	copy.spawn_done = spawn_done.duplicate()
	copy.spawn_totaal = spawn_totaal.duplicate()
	copy.cp = cp.duplicate()
	copy.cp_bets = cp_bets.duplicate()
	copy.cp_bet_done = cp_bet_done.duplicate()
	copy._next_pawn_id = _next_pawn_id
	copy._next_card_id = _next_card_id
	copy.board = []
	for row in board:
		copy.board.append(row.duplicate())
	copy.pawns = {}
	for pid in pawns:
		copy.pawns[pid] = pawns[pid].clone()
	copy.all_cards = {}
	for cid in all_cards:
		copy.all_cards[cid] = all_cards[cid].clone()
	# F0.5: kaart-identiteit blijft heel — defined/revealed verwijzen naar
	# DEZELFDE kloon-objecten als all_cards (was: drie losse klonen per kaart,
	# waardoor een koppeling op de ene lijst onzichtbaar bleef op de andere).
	for player_id in [Constants.PLAYER_1, Constants.PLAYER_2]:
		copy.cards_defined[player_id] = []
		for c in cards_defined[player_id]:
			copy.cards_defined[player_id].append(copy.all_cards[c.id])
		copy.cards_revealed[player_id] = []
		for c in cards_revealed[player_id]:
			copy.cards_revealed[player_id].append(copy.all_cards[c.id])
	return copy
