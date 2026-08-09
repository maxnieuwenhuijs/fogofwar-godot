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
		Actions.BET_CP:
			return _check_bet_cp(state, action, player_id)
		Actions.CANNON_ACT:
			return _check_cannon_act(state, action, player_id)
		Actions.CHOOSE_DOCTRINE:
			# F4.0 — alleen in PRE_GAME, één keer per speler, bestaande factie.
			if state.phase != Phase.Type.PRE_GAME:
				return _nee("De facties liggen al vast")
			if state.doctrine_commits.has(player_id):
				return _nee("Al een factie gekozen")
			if not Constants.DOCTRINE_DATA.has(int(action.doctrine)):
				return _nee("Onbekende factie")
			return _ok()
	return _nee("Onbekend actietype")


## F2.3 — blinde CP-inzet (D1/D4): vóór de eigen define in dezelfde ronde,
## 0..min(saldo, te definiëren kaarten). De inzet is direct verbrand (D2);
## het effect (kaarten met budget+1) valideert _check_define ertegen.
static func _check_bet_cp(state: GameState, action: Dictionary, player_id: int) -> Dictionary:
	if not Phase.is_define(state.phase):
		return _nee("Niet in definitie fase")
	if not state.rules.campaign_actief():
		return _nee("Geen campagne-match")
	if state.cp_bet_done.get(player_id, false):
		return _nee("Al CP ingezet deze ronde")
	if state.cards_defined.get(player_id, []).size() > 0:
		return _nee("CP inzetten kan alleen vóór je kaartdefinitie")
	var amount: int = int(action.amount)
	if amount < 0:
		return _nee("Ongeldige inzet")
	if amount > int(state.cp.get(player_id, 0)):
		return _nee("Onvoldoende CP")
	if amount > expected_define_count(state, player_id):
		return _nee("Meer CP dan kaarten deze ronde")
	return _ok()


## F2.4 — CANNON_ACT (D8/D9/D14): onder campaign is dit de actietaal voor
## artillerie-bewegen en -schieten (melee blijft een gewone MELEE-actie).
## ROLL = 1 vak, SHOOT via de bestaande vuurlijnen met campaign-dracht;
## kosten uit campaign.kanon_actie_kost. RETREAT bestaat niet (D9).
static func _check_cannon_act(state: GameState, action: Dictionary, player_id: int) -> Dictionary:
	if not state.rules.campaign_actief():
		return _nee("Kanon-acties bestaan alleen onder campaign")
	var gate := _action_turn(state, player_id)
	if not gate.legal:
		return gate
	var pawn: Pawn = state.pawns.get(int(action.pawn_id), null)
	if pawn == null or pawn.owner_id != player_id or pawn.is_eliminated or not pawn.is_active:
		return _nee("Ongeldige pion")
	if pawn.unit_type != Constants.UnitType.ARTILLERY:
		return _nee("Alleen artillerie kent kanon-acties")
	var kost: Dictionary = state.rules.campaign.get("kanon_actie_kost", {"roll": 1, "shoot": 1})
	match String(action.sub):
		"roll":
			if pawn.remaining_stamina < int(kost.get("roll", 1)):
				return _nee("Onvoldoende stamina")
			if not Rules.get_valid_move_costs(state, pawn.id).has(action.target):
				return _nee("Ongeldige rol-bestemming")
			return _ok()
		"shoot":
			if pawn.remaining_stamina < int(kost.get("shoot", 1)):
				return _nee("Onvoldoende stamina")
			if not Rules.get_valid_shot_targets(state, pawn.id).has(int(action.target_id)):
				return _nee("Ongeldig doelwit")
			return _ok()
	return _nee("Onbekende kanon-subactie")


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
	if spawns.size() > state.spawns_over(player_id):
		return _nee("Spawn-limiet van het potje bereikt")
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
		# Je koopt alleen wat je doctrine kent: het punten-model bepaalt
		# HOEVEEL, niet WAT (bugfix Max 28 juli: Muis kocht kanonnen).
		if not state.kent_type(player_id, t):
			return _nee("Deze factie kent dit type niet")
		telling[t] = int(telling.get(t, 0)) + 1
		if telling[t] > state.pool_count(player_id, t):
			return _nee("Onvoldoende pool-voorraad")
	return _ok()


## F2.6 — winst-gerichte spawn-keuze voor bots (besluit Max: bots gaan voor
## de winst, de cycluslimiet is een vangnet): vul alleen VERLIEZEN aan tot de
## doctrine-startgrootte. Maximaal spawnen verstopte het bord, strandde de
## haven-race en duwde 67% van de partijen de tiebreak in.
static func aanvul_spawn_actie(state: GameState, player_id: int) -> Dictionary:
	var comp: Array = state.doctrine_data_of(player_id).comp
	var doel_groot: int = int(comp[0]) + int(comp[1]) + int(comp[2])
	var op_bord: int = 0
	for pawn in state.pawns.values():
		if pawn.owner_id == player_id and not pawn.is_eliminated:
			op_bord += 1
	var gewenst: int = clampi(doel_groot - op_bord, 0, mini(int(state.rules.campaign.get("spawn_max", 3)), state.spawns_over(player_id)))
	if gewenst == 0:
		return Actions.make_spawn([])
	var vol: Array = []
	for s in _sample_spawn_sets(state, player_id):
		if (s as Array).size() > vol.size():
			vol = s
	return Actions.make_spawn(vol.slice(0, gewenst))


## Deterministische spawn-opties voor legal_actions/agents: niets spawnen,
## 1 pion, en de volle inzet (tot spawn_max) — vrije achterste-rij-cellen van
## het centrum naar buiten, types op beschikbaarheid (inf > cav > art).
static func _sample_spawn_sets(state: GameState, player_id: int) -> Array:
	var out: Array = [[]]
	if state.pool_total(player_id) == 0 or state.spawns_over(player_id) == 0:
		return out
	var vrij: Array = vrije_spawn_vakken(state, player_id)
	if vrij.is_empty():
		return out
	var maximum: int = mini(mini(int(state.rules.campaign.get("spawn_max", 3)), vrij.size()), state.spawns_over(player_id))
	# Twee volle inzetten: goedkoop-eerst (inf > cav > art, veel lijven) en
	# duur-eerst (art > cav > inf, kwaliteit) — C11: welke wint is leerbaar
	# (AIController.weights.spawn_duur); de mens kiest zelf per type.
	var vol_goedkoop: Array = _vul_spawns(state, player_id, vrij, maximum,
		[Constants.UnitType.INFANTRY, Constants.UnitType.CAVALRY, Constants.UnitType.ARTILLERY])
	var vol_duur: Array = _vul_spawns(state, player_id, vrij, maximum,
		[Constants.UnitType.ARTILLERY, Constants.UnitType.CAVALRY, Constants.UnitType.INFANTRY])
	if not vol_goedkoop.is_empty():
		out.append([vol_goedkoop[0]])
		if vol_goedkoop.size() > 1:
			out.append(vol_goedkoop)
	if not vol_duur.is_empty() and str(vol_duur) != str(vol_goedkoop):
		out.append(vol_duur)
	return out


## Vrije achterste-rij-vakken in spawn-prioriteitsvolgorde (besluit Max,
## 27 juli): eerst de HAVEN-vakken dichtzetten — midden-havens prio 1, dan
## de hoek-havens, dan de rest van het centrum naar buiten.
static func vrije_spawn_vakken(state: GameState, player_id: int) -> Array:
	var achterste: int = Constants.get_start_rows_for_player(player_id)[0]
	var haven_x: Dictionary = {}
	for hpos in Constants.get_haven_for_player(Constants.opponent(player_id)):
		if int(hpos.y) == achterste:
			haven_x[int(hpos.x)] = true
	var midden_havens: Array = []
	var hoek_havens: Array = []
	var overig: Array = []
	for x in [5, 4, 6, 3, 7, 2, 8, 1, 9, 0, 10]:
		if haven_x.has(x):
			if x == 0 or x == 10:
				hoek_havens.append(x)
			else:
				midden_havens.append(x)
		else:
			overig.append(x)
	var vrij: Array = []
	for x in midden_havens + hoek_havens + overig:
		var pos := Vector2i(x, achterste)
		if state.is_tile_empty(pos):
			vrij.append(pos)
	return vrij


## Vul spawns in type-voorkeursvolgorde, betaalbaar uit de (punten)pool.
static func _vul_spawns(state: GameState, player_id: int, vrij: Array, maximum: int, volgorde: Array) -> Array:
	var punten_over: int = state.pool_total(player_id)
	var saldo: Array = [
		state.pool_count(player_id, Constants.UnitType.INFANTRY),
		state.pool_count(player_id, Constants.UnitType.CAVALRY),
		state.pool_count(player_id, Constants.UnitType.ARTILLERY),
	]
	var uit: Array = []
	for i in maximum:
		var t: int = -1
		for kandidaat in volgorde:
			if not state.kent_type(player_id, kandidaat):
				continue
			var kosten: int = state.spawn_kosten(kandidaat) if state.punten_model() else 1
			if state.punten_model():
				if punten_over >= kosten:
					t = kandidaat
					break
			elif saldo[kandidaat] > 0:
				t = kandidaat
				break
		if t == -1:
			break
		if state.punten_model():
			punten_over -= state.spawn_kosten(t)
		else:
			saldo[t] -= 1
		uit.append({"type": t, "pos": vrij[i]})
	return uit


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
		Actions.ACK_REVEAL, Actions.LINK, Actions.SKIP_WOLF_STEP, Actions.RESIGN, Actions.CLAIM_TIMEOUT, Actions.SPAWN, Actions.BET_CP, Actions.CHOOSE_DOCTRINE:
			return is_legal(state, action, player_id)  # al goedkoop: geen dure checks
		Actions.MOVE, Actions.CHARGE:
			var gate := _action_turn(state, player_id)
			if not gate.legal:
				return gate
			var pawn: Pawn = state.pawns.get(int(action.pawn_id), null)
			if pawn == null or pawn.owner_id != player_id:
				return _nee("Ongeldige pion")
			if String(action.type) == Actions.MOVE and state.rules.campaign_actief() \
					and pawn.unit_type == Constants.UnitType.ARTILLERY:
				return _nee("Kanon beweegt via CANNON_ACT")  # F2.4/B3
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
			if state.rules.campaign_actief() and sh.unit_type == Constants.UnitType.ARTILLERY:
				return _nee("Kanon schiet via CANNON_ACT")  # F2.4/B3
			return _ok()
		Actions.CANNON_ACT:
			# Goedkope poort: campaign/beurt/eigendom/type; de dure legaliteit
			# (rol-bestemming, vuurlijn, kosten) dwingt de reducer atomair af.
			if not state.rules.campaign_actief():
				return _nee("Kanon-acties bestaan alleen onder campaign")
			var gate_c := _action_turn(state, player_id)
			if not gate_c.legal:
				return gate_c
			var kanon: Pawn = state.pawns.get(int(action.pawn_id), null)
			if kanon == null or kanon.owner_id != player_id \
					or kanon.unit_type != Constants.UnitType.ARTILLERY:
				return _nee("Ongeldige pion")
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
	# F2.3 (D1): elke ingezette CP staat precies 1 kaart met budget+1 toe
	# (max 1 CP per kaart, D4). Zonder campaign/bet is dit exact het 4.1-pad.
	var budget: int = int(doctrine.budget)
	var cp_kaarten: int = 0
	for c in action.cards:
		if Card.is_valid_stats(int(c.hp), int(c.stamina), int(c.attack),
				budget, doctrine.speed_max, state.rules.per_stat_cap):
			continue
		if Card.is_valid_stats(int(c.hp), int(c.stamina), int(c.attack),
				budget + 1, doctrine.speed_max, state.rules.per_stat_cap):
			cp_kaarten += 1
			continue
		return _nee("Ongeldige statistieken (som moet %d zijn, elk minstens 1)" % budget)
	if cp_kaarten > int(state.cp_bets.get(player_id, 0)):
		return _nee("Kaart boven budget zonder CP-inzet")
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
	if state.rules.campaign_actief() and pawn.unit_type == Constants.UnitType.ARTILLERY:
		return _nee("Kanon beweegt via CANNON_ACT")  # F2.4/B3
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
	if state.rules.campaign_actief() and shooter.unit_type == Constants.UnitType.ARTILLERY:
		return _nee("Kanon schiet via CANNON_ACT")  # F2.4/B3
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
		Phase.Type.GAME_OVER:
			return out
		Phase.Type.PRE_GAME:
			# F4.0 — blinde factie-keuze: wie al koos, wacht op de ander.
			if not state.doctrine_commits.has(player_id):
				for doc in Constants.DOCTRINE_DATA.keys():
					out.append(Actions.make_choose_doctrine(int(doc)))
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
			# F2.3: vóór de define mag een blinde CP-inzet (0 of maximaal).
			if state.rules.campaign_actief() and not state.cp_bet_done.get(player_id, false):
				out.append(Actions.make_bet_cp(0))
				var maximaal: int = mini(int(state.cp.get(player_id, 0)), expected_define_count(state, player_id))
				if maximaal > 0:
					out.append(Actions.make_bet_cp(maximaal))
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
		# F2.4/B3: onder campaign is CANNON_ACT de actietaal voor artillerie-
		# bewegen en -schieten; melee blijft voor elk type een MELEE-actie.
		var kanon_v42: bool = state.rules.campaign_actief() \
			and pawn.unit_type == Constants.UnitType.ARTILLERY
		for target in costs:
			out.append(Actions.make_cannon_roll(pawn.id, target) if kanon_v42 else Actions.make_move(pawn.id, target))
		for defender_id in Rules.get_valid_melee_targets(state, pawn.id):
			out.append(Actions.make_melee(pawn.id, defender_id))
		for target_id in Rules.get_valid_shot_targets(state, pawn.id):
			out.append(Actions.make_cannon_shoot(pawn.id, target_id) if kanon_v42 else Actions.make_shoot(pawn.id, target_id))
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
	# F2.5: een ingezette CP-bet (F2.3) geeft de eerste `bets` kaarten budget+1
	# — anders zou een sample-define de verbrande inzet onbenut laten.
	var bets: int = int(state.cp_bets.get(player_id, 0))
	var sets: Array = []
	for pref in [["hp", "stamina", "attack"], ["attack", "hp", "stamina"], ["stamina", "attack", "hp"]]:
		var card: Dictionary = _fill_card(budget, speed_max, cap, pref)
		if card.is_empty():
			continue
		var dik: Dictionary = _fill_card(budget + 1, speed_max, cap, pref) if bets > 0 else {}
		var cards: Array = []
		for i in n:
			if i < bets and not dik.is_empty():
				cards.append(dik.duplicate())
			else:
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
