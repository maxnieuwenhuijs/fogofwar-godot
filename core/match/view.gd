class_name View
extends RefCounted

# F0.6 — verborgen informatie bestaat alleen nog in de view. View.for_player
# geeft een gefilterde, JSON-serialiseerbare weergave van de staat:
#
# - PLACEMENT: pionnen van de tegenstander zijn onzichtbaar (blind opstellen).
# - Vóór de reveal: eigen cards_defined wel, die van de ander niet — ook geen
#   aantallen-lek via ids (de lijst is gewoon leeg).
# - Krokodil (hidden_link): van gedekte vijandelijke pionnen worden
#   hp/stamina/attack/max_* vervangen door het "?"-sentinel (géén 0/-1 — lege
#   blokjes lekken ook) en wordt de kaart-koppeling weggelaten. Wél zichtbaar:
#   dat de pion actief is + zijn type. De vijandelijke kaart zelf is openbaar
#   (stats waren zichtbaar bij de reveal), maar zijn linked_pawn_id wordt
#   geredacteerd zolang de koppeling gedekt is.
#
# Dit is de payload die de server (F4) naar clients stuurt; de leak-canary
# (ViewTests) bewaakt offline al dat er niets verboden doorheen lekt.

const HIDDEN := "?"


## redacted=false (B8-ablatievlag): zelfde vorm, maar zonder fog — voor het
## meten van wat verborgen informatie waard is (L2-view vs L2-full_state).
static func for_player(state: GameState, player_id: int, redacted: bool = true) -> Dictionary:
	var enemy: int = Constants.opponent(player_id)
	var blind_placement: bool = redacted and state.phase == Phase.Type.PLACEMENT
	# Zichtbare vijandelijke kaarten: onthuld in de huidige ronde, of ooit
	# gekoppeld (eerdere rondes waren per definitie openbaar bij hun reveal).
	var visible_enemy_cards: Dictionary = {}
	for c in state.cards_revealed.get(enemy, []):
		visible_enemy_cards[c.id] = true
	# F1.3 — view-dieet: geëlimineerde pionnen en dode kaarten (verlopen of
	# gekoppeld aan een gesneuvelde pion) blijven weg. Ze zijn beslissings-
	# irrelevant en all_cards accumuleert per cyclus — zonder dit dieet groeit
	# elke view (en straks elke server-payload, F4) onbegrensd mee.
	var pawns_d: Dictionary = {}
	for id in state.pawns:
		var pawn: Pawn = state.pawns[id]
		if pawn.is_eliminated:
			continue
		if pawn.owner_id == enemy and blind_placement:
			continue  # blind opstellen: de ander bestaat nog niet voor jou
		pawns_d[str(id)] = _pawn_view(pawn, player_id) if redacted else pawn.to_dict()
	var eigen_defined: Dictionary = {}
	for c in state.cards_defined.get(player_id, []):
		eigen_defined[c.id] = true
	var cards_d: Dictionary = {}
	for id in state.all_cards:
		var card: Card = state.all_cards[id]
		# Relevant = huidige ronde (defined/revealed) óf gekoppeld aan een
		# levende pion; de rest is historie.
		var linked_alive: bool = false
		if card.linked_pawn_id != -1:
			var drager: Pawn = state.pawns.get(card.linked_pawn_id, null)
			linked_alive = drager != null and not drager.is_eliminated and drager.is_active
		var eigen_huidig: bool = card.owner_id == player_id \
			and (eigen_defined.has(card.id) or card.round_number == state.round_number)
		var vijand_onthuld: bool = visible_enemy_cards.has(card.id)
		if not (linked_alive or eigen_huidig or vijand_onthuld):
			continue
		var covered: bool = redacted and _card_link_covered(state, card)
		if card.owner_id == player_id or not redacted:
			cards_d[str(id)] = card.to_dict()
		elif vijand_onthuld or linked_alive:
			var cd: Dictionary = card.to_dict()
			if covered:
				cd.linked_pawn_id = -1  # de koppeling is het geheim, niet de kaart
			cards_d[str(id)] = cd
		# anders: gedefinieerd maar nog niet onthuld → bestaat niet in deze view
	# F2.2 — pool-saldi: eigen altijd zichtbaar; de vijandelijke pool is het
	# "?"-sentinel (D12: fog voorop) tenzij campaign.pool_zichtbaar of de
	# B8-ablatie (redacted=false). De lopende spawn-INZET is altijd geheim tot
	# de reveal: alleen de eigen commit plus een boolean van de ander.
	var pool_zichtbaar: bool = not redacted \
		or (state.rules.campaign_actief() and bool(state.rules.campaign.get("pool_zichtbaar", false)))
	# Review-fix (F2.2): de rules-dict draagt het campaign-blok integraal mee,
	# en een expliciete startpool daarin (F3-pad: gecodeerde campagne-schade)
	# zou het "?"-sentinel omzeilen — de tegenstander kan het saldo dan de
	# hele match exact bijhouden. Redigeer de kopie; cached_dict zelf is
	# gedeeld en ALLEEN-LEZEN, dus nooit in-place muteren.
	var rules_d: Dictionary = state.rules.cached_dict()
	if not pool_zichtbaar and state.rules.campaign_actief() \
			and state.rules.campaign.get("pools", null) != null:
		rules_d = rules_d.duplicate(true)
		rules_d.campaign["pools"] = HIDDEN
	var pools_d: Dictionary = {}
	if state.pools.has(player_id):
		pools_d[str(player_id)] = (state.pools[player_id] as Dictionary).duplicate()
	if state.pools.has(enemy):
		pools_d[str(enemy)] = (state.pools[enemy] as Dictionary).duplicate() if pool_zichtbaar else HIDDEN
	var eigen_spawns: Array = []
	for e in state.spawn_commits.get(player_id, []):
		eigen_spawns.append({"type": int(e.type), "pos": [e.pos.x, e.pos.y]})
	# F2.3 — CP-saldi volgen dezelfde D12-regel als de pool; de lopende
	# vijandelijke inzet is altijd geheim (geen enemy-bet-veld: de hoogte
	# wordt na de reveal vanzelf afleesbaar uit de kaarten).
	var cp_d: Dictionary = {}
	if state.cp.has(player_id):
		cp_d[str(player_id)] = int(state.cp[player_id])
	if state.cp.has(enemy):
		cp_d[str(enemy)] = int(state.cp[enemy]) if pool_zichtbaar else HIDDEN
	var defined_ids: Array = []
	for c in state.cards_defined.get(player_id, []):
		defined_ids.append(c.id)
	var revealed_ids: Dictionary = {str(player_id): [], str(enemy): []}
	for pid in [player_id, enemy]:
		for c in state.cards_revealed.get(pid, []):
			revealed_ids[str(pid)].append(c.id)
	return {
		"viewer": player_id,
		"phase": state.phase,
		"cycle": state.cycle,
		"round_number": state.round_number,
		"current_player": state.current_player,
		"initiative_player": state.initiative_player,
		"winner": state.winner,
		"pending_wolf_step_pawn": state.pending_wolf_step_pawn,
		"rules": rules_d,
		"doctrines": {str(player_id): state.doctrine_of(player_id), str(enemy): state.doctrine_of(enemy)},
		"pawns": pawns_d,
		"cards": cards_d,
		"own_defined_card_ids": defined_ids,
		"enemy_has_defined": state.cards_defined.get(enemy, []).size() > 0,
		"revealed_card_ids": revealed_ids,
		"placements_done": {
			str(player_id): bool(state.placements_done.get(player_id, false)),
			str(enemy): bool(state.placements_done.get(enemy, false)),
		},
		"reveal_acks": {
			str(player_id): bool(state.reveal_acks.get(player_id, false)),
			str(enemy): bool(state.reveal_acks.get(enemy, false)),
		},
		# Publiek (de "score-race" is voor beide kanten zichtbaar):
		"haven_touches": {
			str(player_id): state.haven_touches.get(player_id, {}).keys(),
			str(enemy): state.haven_touches.get(enemy, {}).keys(),
		},
		"pools": pools_d,
		"own_spawn_commit": eigen_spawns,
		"own_spawn_done": bool(state.spawn_done.get(player_id, false)),
		"enemy_has_spawned": bool(state.spawn_done.get(enemy, false)),
		"cp": cp_d,
		"own_cp_bet": int(state.cp_bets.get(player_id, 0)),
		"own_cp_bet_done": bool(state.cp_bet_done.get(player_id, false)),
		"enemy_defined_ids_hidden": redacted,
	}


## Is de koppeling van deze kaart gedekt (Krokodil-perk, pion nog niet onthuld)?
static func _card_link_covered(state: GameState, card: Card) -> bool:
	if card.linked_pawn_id == -1:
		return false
	var pawn: Pawn = state.pawns.get(card.linked_pawn_id, null)
	return pawn != null and pawn.is_active and not pawn.card_revealed


static func _pawn_view(pawn: Pawn, viewer_id: int) -> Dictionary:
	var d: Dictionary = pawn.to_dict()
	if pawn.owner_id == viewer_id or not pawn.is_active or pawn.card_revealed:
		return d  # eigen pionnen en onthulde/inactieve pionnen: alles zichtbaar
	# Gedekte vijandelijke pion: stats worden het "?"-sentinel, de koppeling
	# verdwijnt. Actief-zijn en type blijven zichtbaar (dat wist je al).
	for veld in ["current_hp", "max_hp", "remaining_stamina", "max_stamina", "attack_value"]:
		d[veld] = HIDDEN
	d.erase("linked_card_id")
	return d
