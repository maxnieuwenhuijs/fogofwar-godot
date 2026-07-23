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


static func for_player(state: GameState, player_id: int) -> Dictionary:
	var enemy: int = Constants.opponent(player_id)
	var blind_placement: bool = state.phase == Phase.Type.PLACEMENT
	# Zichtbare vijandelijke kaarten: onthuld in de huidige ronde, of ooit
	# gekoppeld (eerdere rondes waren per definitie openbaar bij hun reveal).
	var visible_enemy_cards: Dictionary = {}
	for c in state.cards_revealed.get(enemy, []):
		visible_enemy_cards[c.id] = true
	var pawns_d: Dictionary = {}
	for id in state.pawns:
		var pawn: Pawn = state.pawns[id]
		if pawn.owner_id == enemy and blind_placement:
			continue  # blind opstellen: de ander bestaat nog niet voor jou
		pawns_d[str(id)] = _pawn_view(pawn, player_id)
	var cards_d: Dictionary = {}
	for id in state.all_cards:
		var card: Card = state.all_cards[id]
		var covered: bool = _card_link_covered(state, card)
		if card.owner_id == player_id:
			cards_d[str(id)] = card.to_dict()
		elif visible_enemy_cards.has(card.id) or card.linked_pawn_id != -1:
			var cd: Dictionary = card.to_dict()
			if covered:
				cd.linked_pawn_id = -1  # de koppeling is het geheim, niet de kaart
			cards_d[str(id)] = cd
		# anders: gedefinieerd maar nog niet onthuld → bestaat niet in deze view
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
		"rules": state.rules.to_dict(),
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
