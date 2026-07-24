class_name Validator
extends RefCounted

# F0.3 — één legaliteitspoort. Verzamelt álle checks die tot nu toe verspreid
# in GameSession.submit_* zaten (fase, beurt, eigendom, dubbel indienen) plus
# de Rules.get_valid_*-legaliteit. GameSession valideert vanaf nu hierdoorheen;
# straks doen de reducer (F0.4), agents (F1.1), fuzz (F1.4) en de server (F4)
# dat ook — zelfde poort, zelfde antwoorden.
#
# De reason-teksten zijn exact de bestaande foutmeldingen (UI-compat).


static func _ok() -> Dictionary:
	return {"legal": true, "reason": ""}


static func _nee(reason: String) -> Dictionary:
	return {"legal": false, "reason": reason}


## Is deze actie nu legaal voor deze speler?
static func is_legal(state: GameState, action: Dictionary, player_id: int) -> Dictionary:
	if not Actions.is_wellformed(action):
		return _nee("Misvormde actie")
	if state.phase == Phase.Type.GAME_OVER:
		return _nee("De partij is voorbij")
	match String(action.type):
		Actions.PLACE:
			return _check_place(state, action, player_id)
		Actions.DEFINE_CARDS:
			return _check_define(state, action, player_id)
		Actions.ACK_REVEAL:
			if not Phase.is_reveal(state.phase):
				return _nee("Niet in reveal fase")
			if state.reveal_acks.get(player_id, false):
				return _nee("Al bevestigd")
			return _ok()
		Actions.LINK:
			return _check_link(state, action, player_id)
		Actions.MOVE:
			return _check_move(state, action, player_id)
		Actions.MELEE:
			return _check_melee(state, action, player_id)
		Actions.SHOOT:
			return _check_shoot(state, action, player_id)
		Actions.CHARGE:
			return _check_charge(state, action, player_id)
		Actions.WOLF_STEP:
			return _check_wolf_step(state, action, player_id)
		Actions.SKIP_WOLF_STEP:
			return _check_skip_wolf(state, player_id)
		Actions.RESIGN:
			# Effect volgt in F0.4c; legaal in elke speelbare fase.
			return _ok() if state.phase != Phase.Type.PRE_GAME else _nee("De partij is nog niet begonnen")
		Actions.CLAIM_TIMEOUT:
			# Structurele legaliteit; of de deadline écht verstreken is beslist
			# de reducer met now_ms (puur: de validator leest geen klok).
			if int(state.rules.clock.get("bank_sec", 0)) <= 0:
				return _nee("Klokken staan uit in deze match")
			if state.turn_deadline <= 0:
				return _nee("Geen actieve deadline")
			return _ok()
		Actions.SPAWN:
			return _check_spawn(state, action, player_id)
	return _nee("Onbekend actietype")


## F2.2 — blinde spawn-inzet: fase, nog niet ingediend, cap, saldo per type,
## vakken op de EIGEN ACHTERSTE RIJ (D6) en uniek binnen de inzet. Bewust GEEN
## bezet-vak-check hier: de inzet is blind en D6 zegt "geweigerd bij reveal,
## inzet blijft in de pool" — de weigering hoort bij de onthulling (reducer).
static func _check_spawn(state: GameState, action: Dictionary, player_id: int) -> Dictionary:
	if state.phase != Phase.Type.CYCLE_SPAWN:
		return _nee("Niet in de spawn-fase")
	if not state.rules.campaign_actief():
		return _nee("Geen campagne-match")
	if state.spawn_done.get(player_id, false):
		return _nee("Al ingediend")
	var spawns: Array = action.spawns
	if spawns.size() > int(state.rules.campaign.get("spawn_max", 3)):
		return _nee("Meer spawns dan toegestaan")
	var achterste: int = Constants.get_start_rows_for_player(player_id)[0]
	var telling: Dictionary = {}
	var dubbel: Dictionary = {}
	for e in spawns:
		var t: int = int(e.type)
		var pos: Vector2i = e.pos
		if not Constants.is_on_board(pos) or pos.y != achterste:
			return _nee("Spawnvak niet op de eigen achterste rij")
		if dubbel.has(pos):
			return _nee("Dubbel spawnvak in de inzet")
		dubbel[pos] = true
		telling[t] = int(telling.get(t, 0)) + 1
		if telling[t] > state.pool_count(player_id, t):
			return _nee("Onvoldoende pool-voorraad")
	return _ok()


## Deterministische spawn-opties voor legal_actions/agents: niets spawnen,
## 1 pion, en de volle inzet (tot spawn_max) — vrije achterste-rij-cellen van
## het centrum naar buiten, types op beschikbaarheid (inf > cav > art).
static func _sample_spawn_sets(state: GameState, player_id: int) -> Array:
	var out: Array = [[]]
	if state.pool_total(player_id) == 0:
		return out
	var achterste: int = Constants.get_start_rows_for_player(player_id)[0]
	var vrij: Array = []
	for x in [5, 4, 6, 3, 7, 2, 8, 1, 9, 0, 10]:
		var pos := Vector2i(x, achterste)
		if state.is_tile_empty(pos):
			vrij.append(pos)
	if vrij.is_empty():
		return out
	var saldo: Array = [
		state.pool_count(player_id, Constants.UnitType.INFANTRY),
		state.pool_count(player_id, Constants.UnitType.CAVALRY),
		state.pool_count(player_id, Constants.UnitType.ARTILLERY),
	]
	var maximum: int = mini(int(state.rules.campaign.get("spawn_max", 3)), vrij.size())
	var vol: Array = []
	for i in maximum:
		var t: int = -1
		for kandidaat in [Constants.UnitType.INFANTRY, Constants.UnitType.CAVALRY, Constants.UnitType.ARTILLERY]:
			if saldo[kandidaat] > 0:
				t = kandidaat
				break
		if t == -1:
			break
		saldo[t] -= 1
		vol.append({"type": t, "pos": vrij[i]})
	if not vol.is_empty():
		out.append([vol[0]])
		if vol.size() > 1:
			out.append(vol)
	return out


## F1.3 — de SNELLE poort voor de reducer: structuur, fase, beurt, eigendom.
## De dure legaliteit (paden/doelwitten/charge-kosten) dwingt Rules.apply_*
## zelf atomair af; is_legal blijft de volledige poort voor tests/tools/UI.
static func gate_check(state: GameState, action: Dictionary, player_id: int) -> Dictionary:
	if not Actions.is_wellformed(action):
		return _nee("Misvormde actie")
	if state.phase == Phase.Type.GAME_OVER:
		return _nee("De partij is voorbij")
	match String(action.type):
		Actions.PLACE:
			return _check_place(state, action, player_id)
		Actions.DEFINE_CARDS:
			return _check_define(state, action, player_id)
		Actions.ACK_REVEAL, Actions.LINK, Actions.SKIP_WOLF_STEP, Actions.RESIGN, Actions.CLAIM_TIMEOUT, Actions.SPAWN:
			return is_legal(state, action, player_id)  # al goedkoop: geen dure checks
		Actions.MOVE, Actions.CHARGE:
			var gate := _action_turn(state, player_id)
			if not gate.legal:
				return gate
			var pawn: Pawn = state.pawns.get(int(action.pawn_id), null)
			if pawn == null or pawn.owner_id != player_id:
				return _nee("Ongeldige pion")
			return _ok()
		Actions.MELEE:
			var gate_m := _action_turn(state, player_id)
			if not gate_m.legal:
				return gate_m
			var att: Pawn = state.pawns.get(int(action.attacker_id), null)
			if att == null or att.owner_id != player_id:
				return _nee("Ongeldige aanvaller")
			return _ok()
		Actions.SHOOT:
			var gate_s := _action_turn(state, player_id)
			if not gate_s.legal:
				return gate_s
			var sh: Pawn = state.pawns.get(int(action.shooter_id), null)
			if sh == null or sh.owner_id != player_id:
				return _nee("Ongeldige schutter")
			return _ok()
		Actions.WOLF_STEP:
			if state.phase != Phase.Type.ACTION or state.current_player != player_id:
				return _nee("Niet jouw beurt")
			if state.pending_wolf_step_pawn == -1:
				return _nee("Geen Wolf-stap tegoed")
			var wolf: Pawn = state.pawns.get(state.pending_wolf_step_pawn, null)
			if wolf == null or wolf.is_eliminated:
				return _nee("Ongeldige Wolf-stap")
			return _ok()
	return _nee("Onbekend actietype")


static func _check_place(state: GameState, action: Dictionary, player_id: int) -> Dictionary:
	if state.phase != Phase.Type.PLACEMENT:
		return _nee("Niet in opstellingsfase")
	if state.placements_done.get(player_id, false):
		return _nee("Opstelling al ingediend")
	if not state.is_valid_placement(player_id, action.placements):
		return _nee("Ongeldige opstelling")
	return _ok()


## 4.1.10-hr: je definieert per ronde hoogstens zoveel kaarten als je vrije
## (levende, ongekoppelde) pionnen hebt; 0 vrije pionnen = ronde overslaan.
static func expected_define_count(state: GameState, player_id: int) -> int:
	var vrij: int = 0
	for pawn in state.pawns.values():
		if pawn.owner_id == player_id and not pawn.is_eliminated and pawn.linked_card_id == -1:
			vrij += 1
	return mini(int(state.doctrine_data_of(player_id).cards), vrij)


static func _check_define(state: GameState, action: Dictionary, player_id: int) -> Dictionary:
	if not Phase.is_define(state.phase):
		return _nee("Niet in definitie fase")
	if state.cards_defined.get(player_id, []).size() > 0:
		return _nee("Je hebt al gedefinieerd deze ronde")
	var doctrine: Dictionary = state.doctrine_data_of(player_id)
	var expected: int = expected_define_count(state, player_id)
	if expected == 0:
		return _nee("Geen vrije pionnen — deze ronde sla je over")
	if action.cards.size() != expected:
		return _nee("Moet %d kaarten definiëren" % expected)
	for c in action.cards:
		if not Card.is_valid_stats(int(c.hp), int(c.stamina), int(c.attack),
				doctrine.budget, doctrine.speed_max, state.rules.per_stat_cap):
			return _nee("Ongeldige statistieken (som moet %d zijn, elk minstens 1)" % int(doctrine.budget))
	return _ok()


static func _check_link(state: GameState, action: Dictionary, player_id: int) -> Dictionary:
	if not Phase.is_linking(state.phase):
		return _nee("Niet in linking fase")
	if state.current_player != player_id:
		return _nee("Niet jouw beurt")
	var card: Card = state.all_cards.get(int(action.card_id), null)
	if card == null or card.owner_id != player_id or card.round_number != state.round_number or card.is_linked():
		return _nee("Ongeldige kaart")
	var pawn: Pawn = state.pawns.get(int(action.pawn_id), null)
	if pawn == null or pawn.owner_id != player_id or pawn.is_eliminated or pawn.linked_card_id != -1:
		return _nee("Ongeldige pion")
	return _ok()


## De drie actiefase-poortchecks (fase, beurt, openstaande Wolf-stap).
static func _action_turn(state: GameState, player_id: int) -> Dictionary:
	if state.phase != Phase.Type.ACTION:
		return _nee("Niet in actie fase")
	if state.current_player != player_id:
		return _nee("Niet jouw beurt")
	if state.pending_wolf_step_pawn != -1:
		return _nee("Eerst de Wolf-stap afronden (of overslaan)")
	return _ok()


static func _check_move(state: GameState, action: Dictionary, player_id: int) -> Dictionary:
	var gate := _action_turn(state, player_id)
	if not gate.legal:
		return gate
	var pawn: Pawn = state.pawns.get(int(action.pawn_id), null)
	if pawn == null or pawn.owner_id != player_id:
		return _nee("Ongeldige pion")
	if not Rules.get_valid_move_paths(state, pawn.id).has(action.target):
		return _nee("Ongeldige zet")
	return _ok()


static func _check_melee(state: GameState, action: Dictionary, player_id: int) -> Dictionary:
	var gate := _action_turn(state, player_id)
	if not gate.legal:
		return gate
	var attacker: Pawn = state.pawns.get(int(action.attacker_id), null)
	if attacker == null or attacker.owner_id != player_id:
		return _nee("Ongeldige aanvaller")
	if not Rules.get_valid_melee_targets(state, attacker.id).has(int(action.defender_id)):
		return _nee("Ongeldige aanval")
	return _ok()


static func _check_shoot(state: GameState, action: Dictionary, player_id: int) -> Dictionary:
	var gate := _action_turn(state, player_id)
	if not gate.legal:
		return gate
	var shooter: Pawn = state.pawns.get(int(action.shooter_id), null)
	if shooter == null or shooter.owner_id != player_id:
		return _nee("Ongeldige schutter")
	if not Rules.get_valid_shot_targets(state, shooter.id).has(int(action.target_id)):
		return _nee("Ongeldig schot")
	return _ok()


static func _check_charge(state: GameState, action: Dictionary, player_id: int) -> Dictionary:
	var gate := _action_turn(state, player_id)
	if not gate.legal:
		return gate
	var pawn: Pawn = state.pawns.get(int(action.pawn_id), null)
	if pawn == null or pawn.owner_id != player_id:
		return _nee("Ongeldige pion")
	# Charge-validatie is verweven met de uitvoering (atomair, kosten vooraf);
	# een droge run op een kloon geeft gegarandeerd hetzelfde oordeel als apply.
	var probe: GameState = state.clone()
	var result: Dictionary = Rules.apply_charge(probe, pawn.id, action.move_target, int(action.defender_id))
	if not result.success:
		return _nee("Ongeldige charge")
	return _ok()


static func _check_wolf_step(state: GameState, action: Dictionary, player_id: int) -> Dictionary:
	if state.phase != Phase.Type.ACTION or state.current_player != player_id:
		return _nee("Niet jouw beurt")
	var pawn_id: int = state.pending_wolf_step_pawn
	if pawn_id == -1:
		return _nee("Geen Wolf-stap tegoed")
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null or pawn.is_eliminated:
		return _nee("Ongeldige Wolf-stap")
	var dist: int = absi(pawn.position.x - action.target.x) + absi(pawn.position.y - action.target.y)
	if dist != 1 or not state.is_tile_empty(action.target):
		return _nee("Ongeldige Wolf-stap")
	return _ok()


static func _check_skip_wolf(state: GameState, player_id: int) -> Dictionary:
	if state.pending_wolf_step_pawn == -1 or state.current_player != player_id:
		return _nee("Geen Wolf-stap tegoed")
	return _ok()


# =========================================================================
# legal_actions — voor agents (F1.1) en fuzz (F1.4)
# =========================================================================

## Alle legale acties voor deze speler in de huidige staat. Voor PLACE en
## DEFINE_CARDS een generator van geldige voorbeelden (niet exhaustief — die
## ruimtes zijn combinatorisch); voor de overige fasen volledig.
## RESIGN/CLAIM_TIMEOUT worden bewust niet opgesomd (meta-acties).
static func legal_actions(state: GameState, player_id: int) -> Array:
	var out: Array = []
	match state.phase:
		Phase.Type.PRE_GAME, Phase.Type.GAME_OVER:
			return out
		Phase.Type.PLACEMENT:
			if not state.placements_done.get(player_id, false):
				out.append(Actions.make_place(state.default_placement(player_id)))
			return out
	if state.phase == Phase.Type.CYCLE_SPAWN:
		if not state.spawn_done.get(player_id, false):
			for spawns in _sample_spawn_sets(state, player_id):
				out.append(Actions.make_spawn(spawns))
		return out
	if Phase.is_define(state.phase):
		if state.cards_defined.get(player_id, []).size() == 0 \
				and expected_define_count(state, player_id) > 0:
			for cards in _sample_card_sets(state, player_id):
				out.append(Actions.make_define_cards(cards))
		return out
	if Phase.is_reveal(state.phase):
		if not state.reveal_acks.get(player_id, false):
			out.append(Actions.make_ack_reveal())
		return out
	if Phase.is_linking(state.phase):
		if state.current_player != player_id:
			return out
		for c in state.cards_revealed[player_id]:
			if c.is_linked():
				continue
			for pawn in state.pawns.values():
				if pawn.owner_id == player_id and not pawn.is_eliminated and pawn.linked_card_id == -1:
					out.append(Actions.make_link(c.id, pawn.id))
		return out
	# Actiefase.
	if state.current_player != player_id:
		return out
	if state.pending_wolf_step_pawn != -1:
		var wolf: Pawn = state.pawns.get(state.pending_wolf_step_pawn, null)
		if wolf != null and wolf.owner_id == player_id:
			for neighbor in Constants.manhattan_neighbors(wolf.position):
				if Constants.is_on_board(neighbor) and state.is_tile_empty(neighbor):
					out.append(Actions.make_wolf_step(neighbor))
			out.append(Actions.make_skip_wolf_step())
		return out
	for pawn in state.get_active_pawns_for(player_id):
		if pawn.remaining_stamina < 1:
			continue
		# F1.3: kosten-BFS EENMAAL (zonder pad-arrays) en hergebruiken voor
		# moves en charges — apply berekent het volle pad alleen voor de
		# daadwerkelijk gekozen zet.
		var costs: Dictionary = Rules.get_valid_move_costs(state, pawn.id)
		for target in costs:
			out.append(Actions.make_move(pawn.id, target))
		for defender_id in Rules.get_valid_melee_targets(state, pawn.id):
			out.append(Actions.make_melee(pawn.id, defender_id))
		for target_id in Rules.get_valid_shot_targets(state, pawn.id):
			out.append(Actions.make_shoot(pawn.id, target_id))
		if pawn.unit_type == Constants.UnitType.CAVALRY:
			out.append_array(_enumerate_charges(state, pawn, costs))
	return out


## Charges: per bereikbaar eindvak (en de eigen positie) elke aangrenzende
## vijand, mits de kosten uit de resterende stamina te betalen zijn.
static func _enumerate_charges(state: GameState, pawn: Pawn, costs: Dictionary) -> Array:
	var out: Array = []
	var one_action: bool = state.rules.stamina_model == "one_action"
	var end_positions: Array = costs.keys()
	end_positions.append(pawn.position)  # charge zonder verplaatsing (alleen aanval)
	for end_pos in end_positions:
		var steps: int = 0 if end_pos == pawn.position else int(costs[end_pos])
		var cost: int = steps + (0 if one_action else 1)
		if cost > pawn.remaining_stamina:
			continue
		for neighbor in Constants.manhattan_neighbors(end_pos):
			var other: Pawn = state.get_pawn_at(neighbor)
			if other != null and other.owner_id != pawn.owner_id and not other.is_eliminated:
				# "0 stappen en geen aanval" bestaat niet; met aanval is 0 stappen ok.
				out.append(Actions.make_charge(pawn.id, end_pos, other.id))
	return out


## Voorbeelden van geldige kaartsets (gebalanceerd / aanvallend / taai) binnen
## budget, speed_max en per_stat_cap. Deterministisch (geen RNG nodig).
static func _sample_card_sets(state: GameState, player_id: int) -> Array:
	var doctrine: Dictionary = state.doctrine_data_of(player_id)
	var budget: int = int(doctrine.budget)
	var n: int = expected_define_count(state, player_id)
	var speed_max: int = int(doctrine.speed_max)
	var cap: int = state.rules.per_stat_cap
	var sets: Array = []
	for pref in [["hp", "stamina", "attack"], ["attack", "hp", "stamina"], ["stamina", "attack", "hp"]]:
		var card: Dictionary = _fill_card(budget, speed_max, cap, pref)
		if card.is_empty():
			continue
		var cards: Array = []
		for _i in n:
			cards.append(card.duplicate())
		sets.append(cards)
	return sets


## Verdeel het budget: alles start op 1, de rest gaat in voorkeursvolgorde
## zo hoog mogelijk (binnen speed_max/cap).
static func _fill_card(budget: int, speed_max: int, cap: int, pref: Array) -> Dictionary:
	var stats: Dictionary = {"hp": 1, "stamina": 1, "attack": 1}
	var rest: int = budget - 3
	if rest < 0:
		return {}
	for key in pref:
		var limiet: int = budget
		if cap > 0:
			limiet = mini(limiet, cap)
		if key == "stamina" and speed_max > 0:
			limiet = mini(limiet, speed_max)
		var ruimte: int = limiet - stats[key]
		var plus: int = mini(rest, ruimte)
		stats[key] += plus
		rest -= plus
		if rest == 0:
			break
	if rest != 0:
		return {}  # budget past niet binnen de limieten (kan bij extreme caps)
	if not Card.is_valid_stats(stats.hp, stats.stamina, stats.attack, budget, speed_max, cap):
		return {}
	return stats
