class_name Rules
extends RefCounted

# Spelregels v4.1 — vuurlijnen & melee, met OPMAAKBARE stamina (huisregels,
# wijken af van v4.1 §3.3/§4.4):
# - Stamina is de actievoorraad van de cyclus: bewegen kost 1 per stap,
#   melee/schot kost 1, charge kost stappen + 1. Een pion mag meerdere beurten
#   handelen zolang er stamina over is. Terugslag en de Wolf-stap zijn gratis.
# - Artillerie doet 1 ding per beurt (1 stap óf 1 schot) en heeft een VASTE
#   dracht van 6 vakken (Constants.ARTILLERY_RANGE), mits vrije rechte lijn.
# - Infanterie: bewegen, melee (afstand 1) óf schot (afstand exact 2, tussenvak leeg,
#   schade = volle Attack). Terugslag: overleeft een actieve infanterist een melee, dan
#   krijgt de aanvaller 1 schade.
# - Cavalerie: charge = 0..Speed stappen + optionele melee (minstens 1 stap óf aanval).
# - Artillerie: 1 stap bewegen óf schieten op afstand 2..6 vaste dracht (+1 Leeuw;
#   vrije rechte lijn, volle Attack). Dode zone: afstand 1 nooit beschietbaar.
# - Vuur raakt alles met vrij zicht (ook inactieve pionnen), wordt door elke
#   tussenliggende pion geblokkeerd en wint nooit terrein.
# - Alleen melee-eliminaties geven de verplichte verplaatsing.

static func is_haven_for_player(pos: Vector2i, player_id: int) -> bool:
	return Constants.get_haven_for_player(player_id).has(pos)

static func count_pawns_in_haven(state: GameState, player_id: int) -> int:
	var haven: Array = Constants.get_haven_for_player(player_id)
	var count := 0
	for pawn in state.pawns.values():
		if pawn.owner_id != player_id or pawn.is_eliminated:
			continue
		# Cumulatief model (config): ooit aangeraakt blijft tellen, ook na
		# weglopen — zolang de pion leeft. Standaard: nu op het vak staan.
		if haven.has(pawn.position) \
				or (state.rules.haven_score_cumulative and state.haven_touches[player_id].has(pawn.id)):
			count += 1
	return count

static func check_win(state: GameState) -> int:
	for player_id in [Constants.PLAYER_1, Constants.PLAYER_2]:
		if count_pawns_in_haven(state, player_id) >= state.rules.pawns_in_haven_to_win:
			return player_id
	# F2.2 (v4.2): eliminatie kijkt naar bord + pool — met reserves ben je nog
	# niet verslagen (je spawnt volgende cyclus). Zonder campaign is de pool 0
	# en is dit exact het 4.1-gedrag.
	var p1_alive: int = state.count_alive_pawns_for(Constants.PLAYER_1) + state.pool_total(Constants.PLAYER_1)
	var p2_alive: int = state.count_alive_pawns_for(Constants.PLAYER_2) + state.pool_total(Constants.PLAYER_2)
	if p1_alive == 0 and p2_alive > 0:
		return Constants.PLAYER_2
	if p2_alive == 0 and p1_alive > 0:
		return Constants.PLAYER_1
	return -1

# =========================================================================
# Bewegen
# =========================================================================

## Maximaal loopbereik van een pion in deze beurt: resterende stamina,
## voor artillerie gemaximeerd op rules.art_move stappen per beurt (v4.1 §3.3).
static func move_range(state: GameState, pawn: Pawn) -> int:
	if pawn.unit_type == Constants.UnitType.ARTILLERY:
		return mini(state.rules.art_move, pawn.remaining_stamina)
	return pawn.remaining_stamina

static func get_valid_moves(state: GameState, pawn_id: int) -> Array:
	return get_valid_move_paths(state, pawn_id).keys()

static func get_valid_move_paths(state: GameState, pawn_id: int) -> Dictionary:
	var paths: Dictionary = {}
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null or pawn.is_eliminated or not pawn.is_active:
		return paths
	var max_steps: int = move_range(state, pawn)
	if max_steps <= 0:
		return paths
	# Doorbewegen (gepasseerde vakken tellen als stappen; eindigen op een bezet
	# vak mag nooit): Muis door eigen pionnen; cavalerie springt ALTIJD over
	# eigen pionnen; Wolf-cavalerie ook over VIJANDELIJKE infanterie.
	var doctrine: Dictionary = state.doctrine_data_of(pawn.owner_id)
	var is_cav: bool = pawn.unit_type == Constants.UnitType.CAVALRY
	var pass_own: bool = doctrine.move_through_own or is_cav
	var jump_enemy_inf: bool = is_cav and doctrine.cav_jump_infantry
	var visited: Dictionary = {}
	visited[pawn.position] = []
	var frontier: Array = [pawn.position]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var current_path: Array = visited[current]
		if current_path.size() >= max_steps:
			continue
		for neighbor in Constants.manhattan_neighbors(current):
			if not Constants.is_on_board(neighbor):
				continue
			if visited.has(neighbor):
				continue
			var occupant: Pawn = state.get_pawn_at(neighbor)
			var passable: bool = occupant == null \
				or (pass_own and occupant.owner_id == pawn.owner_id and occupant.id != pawn.id) \
				or (jump_enemy_inf and occupant.owner_id != pawn.owner_id \
					and occupant.unit_type == Constants.UnitType.INFANTRY)
			if not passable:
				continue
			var new_path: Array = current_path.duplicate()
			new_path.append(neighbor)
			visited[neighbor] = new_path
			frontier.append(neighbor)
			if occupant == null:
				paths[neighbor] = new_path
	return paths

## F1.3 — hot-path-variant: alleen bestemmingen + stap-kosten (géén
## pad-arrays; die kopieën per cel waren de grootste allocatie-post van de
## arena). Zelfde BFS-volgorde als get_valid_move_paths → identieke uitkomst.
## apply_move blijft de volledige paden gebruiken (1× per toegepaste zet).
static func get_valid_move_costs(state: GameState, pawn_id: int) -> Dictionary:
	var costs: Dictionary = {}
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null or pawn.is_eliminated or not pawn.is_active:
		return costs
	var max_steps: int = move_range(state, pawn)
	if max_steps <= 0:
		return costs
	var doctrine: Dictionary = state.doctrine_data_of(pawn.owner_id)
	var is_cav: bool = pawn.unit_type == Constants.UnitType.CAVALRY
	var pass_own: bool = doctrine.move_through_own or is_cav
	var jump_enemy_inf: bool = is_cav and doctrine.cav_jump_infantry
	var depth: Dictionary = {}
	depth[pawn.position] = 0
	var frontier: Array = [pawn.position]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var d: int = depth[current]
		if d >= max_steps:
			continue
		for neighbor in Constants.manhattan_neighbors(current):
			if not Constants.is_on_board(neighbor):
				continue
			if depth.has(neighbor):
				continue
			var occupant: Pawn = state.get_pawn_at(neighbor)
			var passable: bool = occupant == null \
				or (pass_own and occupant.owner_id == pawn.owner_id and occupant.id != pawn.id) \
				or (jump_enemy_inf and occupant.owner_id != pawn.owner_id \
					and occupant.unit_type == Constants.UnitType.INFANTRY)
			if not passable:
				continue
			depth[neighbor] = d + 1
			frontier.append(neighbor)
			if occupant == null:
				costs[neighbor] = d + 1
	return costs


static func apply_move(state: GameState, pawn_id: int, target_pos: Vector2i) -> bool:
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null or not pawn.is_active or pawn.is_eliminated:
		return false
	var paths: Dictionary = get_valid_move_paths(state, pawn_id)
	if not paths.has(target_pos):
		return false
	state.set_pawn_position(pawn, target_pos)
	pawn.spend_stamina((paths[target_pos] as Array).size())
	_after_action_stamina(state, pawn)
	return true

# =========================================================================
# Melee (Infanterie-melee en Cavalerie-charge)
# =========================================================================

## Aangrenzende vijandelijke doelwitten voor een melee-aanval (Infanterie/Cavalerie).
## Kost 1 stamina.
static func get_valid_melee_targets(state: GameState, pawn_id: int) -> Array:
	var targets: Array = []
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null or pawn.is_eliminated or not pawn.is_active or pawn.remaining_stamina < 1:
		return targets
	if pawn.unit_type == Constants.UnitType.ARTILLERY:
		return targets
	for neighbor in Constants.manhattan_neighbors(pawn.position):
		if not Constants.is_on_board(neighbor):
			continue
		var other: Pawn = state.get_pawn_at(neighbor)
		if other != null and other.owner_id != pawn.owner_id and not other.is_eliminated:
			targets.append(other.id)
	return targets

## Melee-aanval op een aangrenzend doelwit. Resolutievolgorde v4.1 §7:
## schade → eliminatie + verplichte verplaatsing → terugslag → (Wolf) stap-tegoed.
static func apply_melee(state: GameState, attacker_id: int, defender_id: int) -> Dictionary:
	var result: Dictionary = _empty_attack_result()
	var attacker: Pawn = state.pawns.get(attacker_id, null)
	var defender: Pawn = state.pawns.get(defender_id, null)
	if attacker == null or defender == null:
		return result
	if not get_valid_melee_targets(state, attacker_id).has(defender_id):
		return result
	result.attacker_from_pos = attacker.position
	result.defender_pos = defender.position
	attacker.spend_stamina(1)
	_resolve_melee(state, attacker, defender, result)
	_after_action_stamina(state, attacker)
	result.success = true
	return result

## Cavalerie-charge: 0..Speed stappen bewegen en daarna optioneel één melee.
## Charge-minimum: minstens 1 stap óf een aanval (v4.1 §3.2).
static func apply_charge(state: GameState, pawn_id: int, move_target: Vector2i, defender_id: int) -> Dictionary:
	var result: Dictionary = _empty_attack_result()
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null or pawn.is_eliminated or not pawn.is_active:
		return result
	if pawn.unit_type != Constants.UnitType.CAVALRY:
		return result
	var moved: bool = move_target != pawn.position
	result.charge_from = pawn.position
	if not moved and defender_id == -1:
		return result  # "0 stappen en geen aanval" bestaat niet
	var steps: int = 0
	if moved:
		var paths: Dictionary = get_valid_move_paths(state, pawn_id)
		if not paths.has(move_target):
			return result
		steps = (paths[move_target] as Array).size()
	# Kosten: stappen + 1 voor de aanval — beide moeten betaald kunnen worden.
	# one_action-model (v4.1-doc): de charge is één actie, de aanval kost geen
	# extra stamina bovenop de stappen (steps <= Speed volstaat).
	var cost: int = steps + (1 if defender_id != -1 and state.rules.stamina_model != "one_action" else 0)
	if cost > pawn.remaining_stamina:
		return result
	# Valideer de aanval VANAF het doelvak vóór we bewegen (atomaire actie).
	if defender_id != -1:
		var defender: Pawn = state.pawns.get(defender_id, null)
		if defender == null or defender.is_eliminated or defender.owner_id == pawn.owner_id:
			return result
		var dist: int = absi(move_target.x - defender.position.x) + absi(move_target.y - defender.position.y)
		if dist != 1:
			return result
	if moved:
		state.set_pawn_position(pawn, move_target)
	result.moved = moved
	result.move_target = move_target
	result.attacker_from_pos = pawn.position
	pawn.spend_stamina(cost)
	if defender_id != -1:
		var defender2: Pawn = state.pawns.get(defender_id, null)
		result.defender_pos = defender2.position
		_resolve_melee(state, pawn, defender2, result)
	_after_action_stamina(state, pawn)
	result.success = true
	return result

## Gedeelde melee-resolutie: schade, eliminatie + verplichte verplaatsing,
## terugslag van actieve infanterie, Wolf-stap-tegoed.
static func _resolve_melee(state: GameState, attacker: Pawn, defender: Pawn, result: Dictionary) -> void:
	# (Vos) onthulling vóór de schaderesolutie.
	attacker.card_revealed = true
	if defender.is_active:
		defender.card_revealed = true
	var damage: int = attacker.attack_value
	result.damage = damage
	var vacated_pos: Vector2i = defender.position
	if defender.is_active:
		defender.current_hp -= damage
		if defender.current_hp <= 0:
			state.remove_pawn(defender)
			result.eliminated = true
	else:
		# Standbeeld: sneuvelt alleen als de schade de drempel haalt
		# (statue_threshold 0 = elke schade > 0, het 4.1.9-hr-gedrag).
		if damage >= maxi(1, state.rules.statue_threshold):
			state.remove_pawn(defender)
			result.eliminated = true
	if result.eliminated:
		# Verplichte verplaatsing naar het vrijgekomen vak (alleen melee).
		state.set_pawn_position(attacker, vacated_pos)
		result.forced_move = true
	elif defender.is_active:
		# Terugslag: type-afhankelijk (config; default infanterie 1, cavalerie 2,
		# artillerie 0); alleen tegen melee, kost geen actie.
		var retaliation: int = state.rules.retaliation_for(defender.unit_type)
		if retaliation > 0:
			attacker.card_revealed = true
			attacker.current_hp -= retaliation
			result.retaliation = true
			result.retaliation_damage = retaliation
			if attacker.current_hp <= 0:
				state.remove_pawn(attacker)
				result.attacker_eliminated = true
				result.attacker_alive = false
	# Wolf: na élke melee-aanval (ook zonder eliminatie) 1 gratis stap tegoed.
	if not attacker.is_eliminated \
			and state.doctrine_data_of(attacker.owner_id).wolf_step \
			and _has_free_neighbor(state, attacker.position):
		result.wolf_step_available = true

## De optionele gratis Wolf-stap na een melee (v4.1 §6.5).
static func apply_wolf_step(state: GameState, pawn_id: int, target: Vector2i) -> bool:
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null or pawn.is_eliminated:
		return false
	var dist: int = absi(pawn.position.x - target.x) + absi(pawn.position.y - target.y)
	if dist != 1 or not state.is_tile_empty(target):
		return false
	state.set_pawn_position(pawn, target)
	return true

static func _has_free_neighbor(state: GameState, pos: Vector2i) -> bool:
	for neighbor in Constants.manhattan_neighbors(pos):
		if Constants.is_on_board(neighbor) and state.is_tile_empty(neighbor):
			return true
	return false

# =========================================================================
# Beschietingen (infanterieschot en artillerie)
# =========================================================================

## Schade die dit schot zou doen (0 = kan niet schieten, bv. cavalerie).
## inf_shot_full_attack (default aan): volle Aanval-stat; uit = Attack-1
## (de v4.1-doc-variant, waarmee een Aanval-1-pion niet kan schieten).
static func shot_damage(state: GameState, pawn: Pawn) -> int:
	match pawn.unit_type:
		Constants.UnitType.INFANTRY:
			return pawn.attack_value if state.rules.inf_shot_full_attack else maxi(pawn.attack_value - 1, 0)
		Constants.UnitType.ARTILLERY:
			return pawn.attack_value
	return 0

## Stamina-kosten van een schot (config; default beide 1).
static func shot_cost(state: GameState, pawn: Pawn) -> int:
	if pawn.unit_type == Constants.UnitType.INFANTRY:
		return state.rules.inf_shot_cost
	# v4.2 (F2.4): onder campaign komt de kanon-schotkost uit de actiepot-config.
	if state.rules.campaign_actief():
		return int(state.rules.campaign.get("kanon_actie_kost", {}).get("shoot", state.rules.art_shot_cost))
	return state.rules.art_shot_cost

## Dracht [min, max] van dit schot volgens de config, of leeg als de pion
## nooit kan schieten (cavalerie).
static func _shot_ranges(state: GameState, pawn: Pawn) -> Array:
	match pawn.unit_type:
		Constants.UnitType.INFANTRY:
			# Afstand exact N: min = max.
			return [state.rules.inf_shot_range, state.rules.inf_shot_range]
		Constants.UnitType.ARTILLERY:
			# Vaste dracht + doctrine-bonus (Leeuw +1); dode zone eronder.
			# v4.2 (F2.4/D8): onder campaign geldt campaign.kanon_dracht_max.
			var basis: int = state.rules.art_range
			if state.rules.campaign_actief():
				basis = int(state.rules.campaign.get("kanon_dracht_max", basis))
			return [state.rules.art_min_range,
				basis + int(state.doctrine_data_of(pawn.owner_id).art_range_bonus)]
	return []

## Gedeelde vuurlijn-scan voor doelwitten én UI-tegels. Vuurmodel-knoppen:
## - fire_blocked (default aan): eerste pion in de lijn blokkeert alles erachter;
##   uit = boogvuur, niets blokkeert.
## - fire_hits_inactive (default aan): uit = standbeelden zijn geen doelwit
##   (maar blokkeren wél als fire_blocked aan staat).
## - inf_shot_over_pawn (default uit): infanterie mag over precies één
##   tussenpion vóór de minimale afstand heen schieten.
static func _scan_fire_lines(state: GameState, pawn: Pawn, collect_tiles: bool) -> Array:
	var out: Array = []
	var ranges: Array = _shot_ranges(state, pawn)
	if ranges.is_empty():
		return out
	var min_range: int = ranges[0]
	var max_range: int = ranges[1]
	if shot_damage(state, pawn) <= 0 or max_range < min_range:
		return out
	var rules: RulesConfig = state.rules
	var may_skip_one: bool = rules.inf_shot_over_pawn \
		and pawn.unit_type == Constants.UnitType.INFANTRY
	for dir in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var skipped: bool = false
		for dist in range(1, max_range + 1):
			var pos: Vector2i = pawn.position + dir * dist
			if not Constants.is_on_board(pos):
				break
			var other: Pawn = state.get_pawn_at(pos)
			if other == null:
				if collect_tiles and dist >= min_range:
					out.append(pos)
				continue
			var targetable: bool = other.owner_id != pawn.owner_id \
				and dist >= min_range \
				and (other.is_active or rules.fire_hits_inactive)
			if targetable:
				out.append(pos if collect_tiles else other.id)
			if rules.fire_blocked:
				# Uitzondering: infanterie mag één blokkerende pion vóór de
				# minimumafstand overslaan (schot over één pion heen).
				if may_skip_one and not skipped and dist < min_range:
					skipped = true
					continue
				break
			# Boogvuur: niets blokkeert, scan de hele lijn af.
	return out

## Geldige schot-doelwitten (pion-ids); vuurmodel volgens de match-config.
static func get_valid_shot_targets(state: GameState, pawn_id: int) -> Array:
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null or pawn.is_eliminated or not pawn.is_active \
			or pawn.remaining_stamina < shot_cost(state, pawn):
		return []
	return _scan_fire_lines(state, pawn, false)

## Vakken binnen dracht met vrije vuurlijn (voor UI-visualisatie): alle lege
## vakken waar dit schot zou kunnen komen, plus de vakken van raakbare doelwitten.
static func get_shot_range_tiles(state: GameState, pawn_id: int) -> Array:
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null or pawn.is_eliminated or not pawn.is_active \
			or pawn.remaining_stamina < shot_cost(state, pawn):
		return []
	return _scan_fire_lines(state, pawn, true)


## Beschieting (v4.1 §7): geen terugslag, geen verplaatsing; het vak blijft leeg.
static func apply_shot(state: GameState, shooter_id: int, target_id: int) -> Dictionary:
	var result: Dictionary = _empty_attack_result()
	var shooter: Pawn = state.pawns.get(shooter_id, null)
	var target: Pawn = state.pawns.get(target_id, null)
	if shooter == null or target == null:
		return result
	if not get_valid_shot_targets(state, shooter_id).has(target_id):
		return result
	result.attacker_from_pos = shooter.position
	result.defender_pos = target.position
	# (Vos) onthulling vóór de schaderesolutie.
	shooter.card_revealed = true
	if target.is_active:
		target.card_revealed = true
	var damage: int = shot_damage(state, shooter)
	result.damage = damage
	result.is_shot = true
	if target.is_active:
		target.current_hp -= damage
		if target.current_hp <= 0:
			state.remove_pawn(target)
			result.eliminated = true
	else:
		# Standbeeld: alleen geëlimineerd als de schade de drempel haalt
		# (statue_threshold 0 = elke schade > 0; het schot is anders verspild).
		if damage >= maxi(1, state.rules.statue_threshold):
			state.remove_pawn(target)
			result.eliminated = true
	shooter.spend_stamina(shot_cost(state, shooter))
	_after_action_stamina(state, shooter)
	result.success = true
	return result

static func _empty_attack_result() -> Dictionary:
	return {
		"success": false,
		"damage": 0,
		"eliminated": false,
		"forced_move": false,
		"retaliation": false,
		"retaliation_damage": 0,
		"attacker_eliminated": false,
		"attacker_alive": true,
		"is_shot": false,
		"moved": false,
		"move_target": Vector2i.ZERO,
		"charge_from": Vector2i.ZERO,
		"wolf_step_available": false,
		"attacker_from_pos": Vector2i.ZERO,
		"defender_pos": Vector2i.ZERO,
	}

# =========================================================================
# Actie-beschikbaarheid en beurtwissel
# =========================================================================

## one_action-model (config): één actie per pion per cyclus — na élke actie
## gaat de resterende stamina naar 0. Onder het (default) pool-model doet
## deze helper niets.
static func _after_action_stamina(state: GameState, pawn: Pawn) -> void:
	if state.rules.stamina_model == "one_action" and not pawn.is_eliminated:
		pawn.remaining_stamina = 0

static func can_pawn_act(state: GameState, pawn_id: int) -> bool:
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null or pawn.is_eliminated or not pawn.is_active or pawn.remaining_stamina < 1:
		return false
	# F1.3: goedkoopste checks eerst (dit draait na élke actie voor beide
	# spelers). Leeg buurvak = 4 lookups; melee = 4 lookups; de schot-scan en
	# de sprong-BFS zijn de dure paden en komen als laatste.
	var kan_bewegen: bool = move_range(state, pawn) > 0
	if kan_bewegen:
		for neighbor in Constants.manhattan_neighbors(pawn.position):
			if Constants.is_on_board(neighbor) and state.is_tile_empty(neighbor):
				return true
	if not get_valid_melee_targets(state, pawn_id).is_empty():
		return true
	if not get_valid_shot_targets(state, pawn_id).is_empty():
		return true
	if kan_bewegen:
		var doctrine: Dictionary = state.doctrine_data_of(pawn.owner_id)
		var can_jump: bool = doctrine.move_through_own \
			or pawn.unit_type == Constants.UnitType.CAVALRY
		if can_jump and not get_valid_move_costs(state, pawn_id).is_empty():
			return true
	return false

static func can_player_act(state: GameState, player_id: int) -> bool:
	# F1.3: directe iteratie (geen tussenliggende array; draait 2x per actie).
	for pawn in state.pawns.values():
		if pawn.owner_id == player_id and pawn.is_active and not pawn.is_eliminated \
				and can_pawn_act(state, pawn.id):
			return true
	return false

# =========================================================================
# Initiatief (v4.1 §4.3-B): bod-percentage i.p.v. totale Attack
# =========================================================================

static func compute_totals(cards: Array) -> Dictionary:
	var total_attack := 0
	var total_stamina := 0
	var total_hp := 0
	for c in cards:
		total_attack += c.attack
		total_stamina += c.stamina
		total_hp += c.hp
	return {"attack": total_attack, "stamina": total_stamina, "hp": total_hp}

## AttackBod = (Σ stat − aantal kaarten) / (aantal kaarten × (budget − 3)).
static func compute_bid(cards: Array, budget: int, stat: String) -> float:
	var n: int = cards.size()
	if n == 0 or budget <= 3:
		return 0.0
	var total: int = 0
	for c in cards:
		total += c.attack if stat == "attack" else c.stamina
	return float(total - n) / float(n * (budget - 3))

## Deterministisch: bod op Attack → bod op Speed → Ronde 1/Cyclus 1: Speler 1,
## anders de vorige initiatiefhouder. (De steen-papier-schaar-tiebreaker uit v1 verviel in v4.1.)
static func compute_initiative(state: GameState) -> Dictionary:
	var cards_p1: Array = state.cards_revealed[Constants.PLAYER_1]
	var cards_p2: Array = state.cards_revealed[Constants.PLAYER_2]
	var budget_p1: int = state.doctrine_data_of(Constants.PLAYER_1).budget
	var budget_p2: int = state.doctrine_data_of(Constants.PLAYER_2).budget
	var totals_p1: Dictionary = compute_totals(cards_p1)
	var totals_p2: Dictionary = compute_totals(cards_p2)
	var bid_p1: float = compute_bid(cards_p1, budget_p1, "attack")
	var bid_p2: float = compute_bid(cards_p2, budget_p2, "attack")
	totals_p1["bid"] = bid_p1
	totals_p2["bid"] = bid_p2
	var result := {
		"winner": -1,
		"totals_p1": totals_p1,
		"totals_p2": totals_p2,
	}
	const EPS := 0.000001
	if bid_p1 > bid_p2 + EPS:
		result.winner = Constants.PLAYER_1
	elif bid_p2 > bid_p1 + EPS:
		result.winner = Constants.PLAYER_2
	else:
		var speed_p1: float = compute_bid(cards_p1, budget_p1, "stamina")
		var speed_p2: float = compute_bid(cards_p2, budget_p2, "stamina")
		if speed_p1 > speed_p2 + EPS:
			result.winner = Constants.PLAYER_1
		elif speed_p2 > speed_p1 + EPS:
			result.winner = Constants.PLAYER_2
		elif state.cycle == 1 and state.round_number == 1:
			result.winner = Constants.PLAYER_1
		else:
			result.winner = state.last_initiative_winner
	return result
