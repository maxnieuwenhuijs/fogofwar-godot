class_name Agent
extends RefCounted

# F1.1 — het harde agent-contract (bouwplan §7.1):
#
#     decide(view, legal, rng) -> Action
#
# Een agent ziet NOOIT de echte GameState — alleen zijn per-speler-view
# (View.for_player) en de lijst legale acties (Validator.legal_actions).
# Daarmee is valsspelen structureel onmogelijk: wat de view niet bevat,
# bestaat niet voor de agent.
#
# B8-ablatievlag: full_state=true laat de runner een ongeredigeerde view
# aanleveren (zelfde vorm, geen fog) — zo is meetbaar wat verborgen
# informatie waard is (L2-view vs L2-full_state).
#
# B11: voor evaluatie/search reconstrueert een agent een speelbare staat uit
# zijn view; gedekte vijandelijke stats krijgen een PUNTSCHATTING (het
# gemiddelde over de onthulde vijandelijke kaarten — determinized sampling
# N=16 is de latere upgrade als de arena aantoont dat dit te zwak is).

var player_id: int = Constants.PLAYER_1
var rng: SeededRng = SeededRng.new(1337)
var full_state: bool = false  # B8: ongeredigeerde view (alleen voor ablatie-metingen)


## Override in subklassen. Default: de eerste legale actie (deterministisch).
func decide(_view: Dictionary, legal: Array, _decide_rng: SeededRng) -> Dictionary:
	return legal[0] if not legal.is_empty() else {}


## F1.3 — zelfverklaring: leest deze agent de view in deze fase? Zo niet, dan
## slaat de runner de (dure) view-opbouw over en levert {} aan. Minder info
## aanvragen kan nooit valsspelen zijn; L2/L3 laten dit gewoon op true.
func wants_view(_phase: int) -> bool:
	return true


## B11 — view → speelbare GameState. Gedekte "?"-stats worden puntschattingen;
## een gedekte pion heeft per definitie nog geen schade gehad (onthulling
## gebeurt bij schade), dus current = max klopt per constructie.
static func reconstruct_state(view: Dictionary) -> GameState:
	var s := GameState.new()
	s.phase = int(view.phase)
	s.cycle = int(view.cycle)
	s.round_number = int(view.round_number)
	s.current_player = int(view.current_player)
	s.initiative_player = int(view.initiative_player)
	s.winner = int(view.winner)
	s.pending_wolf_step_pawn = int(view.pending_wolf_step_pawn)
	s.rules = RulesConfig.from_dict(view.rules)
	for key in view.doctrines:
		s.doctrines[int(String(key))] = int(view.doctrines[key])
	# Kaarten eerst (voor de puntschatting en de referentie-herstelling).
	var max_card_id: int = -1
	for key in view.cards:
		var card: Card = Card.from_dict(view.cards[key])
		s.all_cards[card.id] = card
		max_card_id = maxi(max_card_id, card.id)
	# Puntschattingen per eigenaar: gemiddelde stats over diens zichtbare kaarten.
	var schatting: Dictionary = {}
	for owner in [Constants.PLAYER_1, Constants.PLAYER_2]:
		var som := Vector3i.ZERO
		var n := 0
		for card in s.all_cards.values():
			if card.owner_id == owner:
				som += Vector3i(card.hp, card.stamina, card.attack)
				n += 1
		if n > 0:
			schatting[owner] = Vector3i(
				maxi(1, int(round(float(som.x) / n))),
				maxi(1, int(round(float(som.y) / n))),
				maxi(1, int(round(float(som.z) / n))))
		else:
			schatting[owner] = Vector3i(2, 2, 2)  # niets bekend: neutraal gokje
	var max_pawn_id: int = -1
	for key in view.pawns:
		var pd: Dictionary = (view.pawns[key] as Dictionary).duplicate()
		if pd.get("current_hp") is String:  # "?"-sentinel → puntschatting
			var est: Vector3i = schatting[int(pd.owner_id)]
			pd.current_hp = est.x
			pd.max_hp = est.x
			pd.remaining_stamina = est.y
			pd.max_stamina = est.y
			pd.attack_value = est.z
		var pawn: Pawn = Pawn.from_dict(pd)
		s.pawns[pawn.id] = pawn
		max_pawn_id = maxi(max_pawn_id, pawn.id)
	s._initialize_board()
	for pawn in s.pawns.values():
		if not pawn.is_eliminated:
			s.board[pawn.position.y][pawn.position.x] = pawn.id
	var viewer: int = int(view.viewer)
	var enemy: int = Constants.opponent(viewer)
	for cid in view.own_defined_card_ids:
		if s.all_cards.has(int(cid)):
			s.cards_defined[viewer].append(s.all_cards[int(cid)])
	for key in view.revealed_card_ids:
		for cid in view.revealed_card_ids[key]:
			if s.all_cards.has(int(cid)):
				s.cards_revealed[int(String(key))].append(s.all_cards[int(cid)])
	for key in view.placements_done:
		if bool(view.placements_done[key]):
			s.placements_done[int(String(key))] = true
	for key in view.reveal_acks:
		s.reveal_acks[int(String(key))] = bool(view.reveal_acks[key])
	for key in view.get("haven_touches", {}):
		s.haven_touches[int(String(key))] = {}
		for pid in view.haven_touches[key]:
			s.haven_touches[int(String(key))][int(pid)] = true
	# F2.5 (v4.2) — pool/CP-reconstructie: eigen waarden exact; vijandelijke
	# saldi zijn het "?"-sentinel (D12) en blijven dan gewoon weg — de
	# validator-checks voor EIGEN acties lezen alleen de eigen kant.
	for key in view.get("pools", {}):
		if view.pools[key] is Dictionary:
			var p: Dictionary = view.pools[key]
			s.pools[int(String(key))] = {"inf": int(p.get("inf", 0)), "cav": int(p.get("cav", 0)), "art": int(p.get("art", 0))}
	for key in view.get("cp", {}):
		if not (view.cp[key] is String):
			s.cp[int(String(key))] = int(view.cp[key])
	if int(view.get("own_cp_bet", 0)) > 0:
		s.cp_bets[viewer] = int(view.own_cp_bet)
	if bool(view.get("own_cp_bet_done", false)):
		s.cp_bet_done[viewer] = true
	if bool(view.get("own_spawn_done", false)):
		s.spawn_done[viewer] = true
	if bool(view.get("enemy_has_spawned", false)):
		s.spawn_done[enemy] = true
	# De vijand heeft mogelijk gedefinieerd (commit-gate-signaal), maar wat is
	# geheim: markeer met een placeholder zodat fase-logica niet doorschuift.
	if bool(view.get("enemy_has_defined", false)) and s.cards_defined[enemy].is_empty() \
			and Phase.is_define(s.phase):
		pass  # bewust leeg: agents nemen geen fase-beslissingen op de recon-staat
	s._next_pawn_id = max_pawn_id + 1
	s._next_card_id = max_card_id + 1
	return s


## Legacy-AI-actie ({type:"move"...}) → nieuwe actietaal; leeg dict bij onbekend.
static func legacy_to_action(act: Dictionary) -> Dictionary:
	if act.is_empty():
		return {}
	match String(act.get("type", "")):
		"move":
			return Actions.make_move(int(act.pawn_id), act.target)
		"attack":
			return Actions.make_melee(int(act.attacker_id), int(act.defender_id))
		"shot":
			return Actions.make_shoot(int(act.shooter_id), int(act.target_id))
		"charge":
			return Actions.make_charge(int(act.pawn_id), act.move_target, int(act.defender_id))
	return {}
