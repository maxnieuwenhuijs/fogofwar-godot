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
	return rules.doctrine_data(doctrine_of(player_id))

## Standaard-opstelling voor beide spelers (gebruikt door tests, AI en auto-plaatsing).
func setup_initial_pawns() -> void:
	for player_id in [Constants.PLAYER_1, Constants.PLAYER_2]:
		apply_placement(player_id, default_placement(player_id))

## Plaats de pionnen van één speler volgens een placement-lijst [{type, pos}, ...].
func apply_placement(player_id: int, placements: Array) -> void:
	for entry in placements:
		_spawn_pawn(player_id, entry.pos, int(entry.type))
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

	return placements

## Valideer een placement-lijst voor een speler (samenstelling, thuisrijen, uniek).
func is_valid_placement(player_id: int, placements: Array) -> bool:
	var comp: Array = doctrine_data_of(player_id).comp
	var counts: Array = [0, 0, 0]
	var rows: Array = Constants.get_start_rows_for_player(player_id)
	var seen: Dictionary = {}
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
	return counts[0] == comp[0] and counts[1] == comp[1] and counts[2] == comp[2]

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
	cycle += 1
	round_number = 1

func reset_for_new_round() -> void:
	cards_defined[Constants.PLAYER_1] = []
	cards_defined[Constants.PLAYER_2] = []
	cards_revealed[Constants.PLAYER_1] = []
	cards_revealed[Constants.PLAYER_2] = []

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
