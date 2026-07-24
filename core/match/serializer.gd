class_name Serializer
extends RefCounted

# F0.5 — snapshot zonder kaart-identiteitsbreuk. Kaarten worden éénmaal per id
# geserialiseerd (all_cards); cards_defined/cards_revealed zijn lijsten van
# card-IDS. Reconstructie herstelt referenties naar dezelfde Card-objecten —
# de bekende clone-identiteitsbreuk (risico 7 uit het online-plan: linking op
# een gedeserialiseerde staat eindigde nooit) kan hier niet bestaan.
# Het bord wordt niet geserialiseerd maar herbouwd uit de pion-posities.
#
# JSON-veilig: alle keys strings, Vector2i als [x, y], RulesConfig via zijn
# eigen to_dict/from_dict. Dit is het formaat voor replays (F0.7), savegames
# (F3.4) en server-snapshots (F4).


static func state_to_dict(state: GameState) -> Dictionary:
	var pawns_d: Dictionary = {}
	for id in state.pawns:
		pawns_d[str(id)] = state.pawns[id].to_dict()
	var cards_d: Dictionary = {}
	for id in state.all_cards:
		cards_d[str(id)] = state.all_cards[id].to_dict()
	var defined_ids: Dictionary = {}
	var revealed_ids: Dictionary = {}
	var touches: Dictionary = {}
	var acks: Dictionary = {}
	var placements: Dictionary = {}
	var doctrines: Dictionary = {}
	var pools_d: Dictionary = {}
	var spawn_commits_d: Dictionary = {}
	var spawn_done_d: Dictionary = {}
	for player_id in [Constants.PLAYER_1, Constants.PLAYER_2]:
		var key := str(player_id)
		defined_ids[key] = []
		for c in state.cards_defined.get(player_id, []):
			defined_ids[key].append(c.id)
		revealed_ids[key] = []
		for c in state.cards_revealed.get(player_id, []):
			revealed_ids[key].append(c.id)
		touches[key] = state.haven_touches.get(player_id, {}).keys()
		acks[key] = bool(state.reveal_acks.get(player_id, false))
		placements[key] = bool(state.placements_done.get(player_id, false))
		doctrines[key] = int(state.doctrine_of(player_id))
		if state.pools.has(player_id):
			pools_d[key] = (state.pools[player_id] as Dictionary).duplicate()
		var commits: Array = []
		for e in state.spawn_commits.get(player_id, []):
			commits.append({"type": int(e.type), "pos": [e.pos.x, e.pos.y]})
		spawn_commits_d[key] = commits
		spawn_done_d[key] = bool(state.spawn_done.get(player_id, false))
	return {
		"phase": state.phase,
		"cycle": state.cycle,
		"round_number": state.round_number,
		"current_player": state.current_player,
		"initiative_player": state.initiative_player,
		"last_initiative_winner": state.last_initiative_winner,
		"winner": state.winner,
		"pending_wolf_step_pawn": state.pending_wolf_step_pawn,
		"turn_deadline": state.turn_deadline,
		"clocks": state.clocks.duplicate(true),
		"rules": state.rules.to_dict(),
		"doctrines": doctrines,
		"pawns": pawns_d,
		"all_cards": cards_d,
		"cards_defined": defined_ids,
		"cards_revealed": revealed_ids,
		"placements_done": placements,
		"reveal_acks": acks,
		"haven_touches": touches,
		"pools": pools_d,
		"spawn_commits": spawn_commits_d,
		"spawn_done": spawn_done_d,
		"next_pawn_id": state._next_pawn_id,
		"next_card_id": state._next_card_id,
	}


static func state_from_dict(d: Dictionary) -> GameState:
	var s := GameState.new()
	s.phase = int(d.get("phase", Phase.Type.PRE_GAME))
	s.cycle = int(d.get("cycle", 1))
	s.round_number = int(d.get("round_number", 1))
	s.current_player = int(d.get("current_player", Constants.PLAYER_1))
	s.initiative_player = int(d.get("initiative_player", Constants.PLAYER_1))
	s.last_initiative_winner = int(d.get("last_initiative_winner", Constants.PLAYER_1))
	s.winner = int(d.get("winner", -1))
	s.pending_wolf_step_pawn = int(d.get("pending_wolf_step_pawn", -1))
	s.turn_deadline = int(d.get("turn_deadline", 0))
	s.clocks = {}
	for k in d.get("clocks", {}):
		s.clocks[int(String(k))] = {"bank_ms": int(d.clocks[k].get("bank_ms", 0))}
	s.rules = RulesConfig.from_dict(d.get("rules", {}))
	# Kaarten éérst: één object per id, daarna verwijzen alle lijsten daarnaar.
	s.all_cards = {}
	for key in d.get("all_cards", {}):
		var card: Card = Card.from_dict(d.all_cards[key])
		s.all_cards[card.id] = card
	s.pawns = {}
	for key in d.get("pawns", {}):
		var pawn: Pawn = Pawn.from_dict(d.pawns[key])
		s.pawns[pawn.id] = pawn
	# Bord herbouwen uit de pion-posities (alleen levende pionnen bezetten vakken).
	s._initialize_board()
	for pawn in s.pawns.values():
		if not pawn.is_eliminated:
			s.board[pawn.position.y][pawn.position.x] = pawn.id
	for player_id in [Constants.PLAYER_1, Constants.PLAYER_2]:
		var key := str(player_id)
		s.doctrines[player_id] = int(d.get("doctrines", {}).get(key, Constants.Doctrine.MENS))
		s.cards_defined[player_id] = []
		for cid in d.get("cards_defined", {}).get(key, []):
			s.cards_defined[player_id].append(s.all_cards[int(cid)])
		s.cards_revealed[player_id] = []
		for cid in d.get("cards_revealed", {}).get(key, []):
			s.cards_revealed[player_id].append(s.all_cards[int(cid)])
		if bool(d.get("placements_done", {}).get(key, false)):
			s.placements_done[player_id] = true
		s.reveal_acks[player_id] = bool(d.get("reveal_acks", {}).get(key, false))
		s.haven_touches[player_id] = {}
		for pid in d.get("haven_touches", {}).get(key, []):
			s.haven_touches[player_id][int(pid)] = true
		if d.get("pools", {}).has(key):
			var p: Dictionary = d.pools[key]
			s.pools[player_id] = {"inf": int(p.get("inf", 0)), "cav": int(p.get("cav", 0)), "art": int(p.get("art", 0))}
		var commits: Array = []
		for e in d.get("spawn_commits", {}).get(key, []):
			var pos = e.pos
			commits.append({"type": int(e.type), "pos": Vector2i(int(pos[0]), int(pos[1])) if pos is Array else pos})
		if not commits.is_empty():
			s.spawn_commits[player_id] = commits
		if bool(d.get("spawn_done", {}).get(key, false)):
			s.spawn_done[player_id] = true
	s._next_pawn_id = int(d.get("next_pawn_id", 0))
	s._next_card_id = int(d.get("next_card_id", 0))
	return s
