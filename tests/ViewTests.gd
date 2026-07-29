extends TestSuite

# F0.6 — leak-canary: geen enkel verboden veld mag ooit in een tegenstander-
# view terechtkomen. De property-test fuzzt honderden staten over alle fasen
# (random partijen met Krokodil erin) en checkt per staat de drie geheimen:
# blinde opstelling, niet-onthulde defines, gedekte Krokodil-koppelingen.
# Dit is letterlijk de test die in F4 tegen de echte server draait.


func _class_name() -> String:
	return "ViewTests"


func _fresh(d1: int, d2: int) -> GameState:
	var s := GameState.new()
	s.doctrines[Constants.PLAYER_1] = d1
	s.doctrines[Constants.PLAYER_2] = d2
	s.phase = Phase.Type.PLACEMENT
	return s


## Structurele lek-checks op de view van `viewer`. Retourneert lijst schendingen.
## Spiegelt View._van_dichtbij_gezien: een gedekte pion met een actieve
## vijand ernaast is bewust zichtbaar (C13).
func _naast_eigen_pion(state: GameState, pawn: Pawn, viewer: int) -> bool:
	if not state.rules.schutkleur_onthul_nabij:
		return false
	for buur in Constants.manhattan_neighbors(pawn.position):
		if not Constants.is_on_board(buur):
			continue
		var ander: Pawn = state.get_pawn_at(buur)
		if ander != null and not ander.is_eliminated and ander.is_active 				and ander.owner_id == viewer:
			return true
	return false


func _lekken(state: GameState, viewer: int) -> Array:
	var fouten: Array = []
	var enemy: int = Constants.opponent(viewer)
	var view: Dictionary = View.for_player(state, viewer)
	# De view moet JSON-serialiseerbaar zijn (servergrens).
	var json: String = JSON.stringify(view)
	if json == "":
		fouten.append("view niet JSON-serialiseerbaar")
	# 1) Blind opstellen: tijdens PLACEMENT geen vijandelijke pionnen.
	if state.phase == Phase.Type.PLACEMENT:
		for key in view.pawns:
			if int(view.pawns[key].owner_id) == enemy:
				fouten.append("vijandelijke pion %s zichtbaar tijdens blind opstellen" % key)
	# 2) Niet-onthulde defines van de vijand bestaan niet in de view.
	var revealed_enemy: Dictionary = {}
	for c in state.cards_revealed.get(enemy, []):
		revealed_enemy[c.id] = true
	for c in state.cards_defined.get(enemy, []):
		if not revealed_enemy.has(c.id) and c.linked_pawn_id == -1:
			if view.cards.has(str(c.id)):
				fouten.append("niet-onthulde vijandelijke kaart %d lekt" % c.id)
	# 3) Gedekte Krokodil-pionnen: sentinel-stats, geen koppeling, geen
	#    kaart die naar de pion terugwijst.
	for pawn in state.pawns.values():
		if pawn.owner_id != enemy or not pawn.is_active or pawn.card_revealed:
			continue
		# C13 (29 juli): staat er een ACTIEVE eigen pion naast, dan MAG je hem
		# zien -- dat is de afgezwakte schutkleur, geen lek.
		if _naast_eigen_pion(state, pawn, viewer):
			continue
		var key := str(pawn.id)
		if not view.pawns.has(key):
			continue
		var pv: Dictionary = view.pawns[key]
		for veld in ["current_hp", "max_hp", "remaining_stamina", "max_stamina", "attack_value"]:
			if not (pv[veld] is String and pv[veld] == View.HIDDEN):
				fouten.append("gedekte pion %d lekt %s=%s" % [pawn.id, veld, str(pv[veld])])
		if pv.has("linked_card_id"):
			fouten.append("gedekte pion %d lekt zijn koppeling" % pawn.id)
		for ckey in view.cards:
			if int(view.cards[ckey].get("linked_pawn_id", -1)) == pawn.id:
				fouten.append("kaart %s wijst terug naar gedekte pion %d" % [ckey, pawn.id])
	# 4) own_defined_card_ids bevat alleen eigen kaarten.
	for cid in view.own_defined_card_ids:
		var card: Card = state.all_cards.get(int(cid), null)
		if card == null or card.owner_id != viewer:
			fouten.append("own_defined bevat andermans kaart %s" % str(cid))
	return fouten


func test_leak_canary_200_states() -> void:
	var rng := SeededRng.new(20260711)
	var combos: Array = [
		[Constants.Doctrine.MENS, Constants.Doctrine.VOS],
		[Constants.Doctrine.VOS, Constants.Doctrine.VOS],
		[Constants.Doctrine.VOS, Constants.Doctrine.WOLF],
		[Constants.Doctrine.MUIS, Constants.Doctrine.VOS],
	]
	var states_gecheckt: int = 0
	var alle_fouten: Array = []
	for g in 12:
		var combo: Array = combos[g % combos.size()]
		var s := _fresh(combo[0], combo[1])
		for step in 60:
			if s.phase == Phase.Type.GAME_OVER:
				break
			# Check de views van BEIDE spelers op deze staat.
			for viewer in [Constants.PLAYER_1, Constants.PLAYER_2]:
				var fouten: Array = _lekken(s, viewer)
				if not fouten.is_empty() and alle_fouten.size() < 3:
					alle_fouten.append("game %d stap %d viewer %d: %s" % [g, step, viewer, fouten[0]])
				states_gecheckt += 1
			# Eén random legale actie verder.
			var acted := false
			for speler in ([1, 2] if rng.randi_range(0, 1) == 0 else [2, 1]):
				var opties: Array = Validator.legal_actions(s, speler)
				if opties.is_empty():
					continue
				Reducer.apply(s, opties[rng.randi_range(0, opties.size() - 1)], speler)
				acted = true
				break
			if not acted:
				break
	assert_true(states_gecheckt >= 200, "canary hoort 200+ staten te dekken (kreeg %d)" % states_gecheckt)
	assert_eq(alle_fouten.size(), 0, "lekken gevonden: %s" % str(alle_fouten))


func test_blind_placement() -> void:
	var s := _fresh(Constants.Doctrine.MENS, Constants.Doctrine.MENS)
	Reducer.apply(s, Actions.make_place(s.default_placement(1)), 1)
	var view_p2: Dictionary = View.for_player(s, 2)
	assert_eq(view_p2.pawns.size(), 0, "P2 ziet de opstelling van P1 niet")
	assert_true(view_p2.placements_done["1"], "dat P1 kláár is, is wel openbaar")
	var view_p1: Dictionary = View.for_player(s, 1)
	assert_eq(view_p1.pawns.size(), 22, "P1 ziet zijn eigen opstelling volledig")


func test_defines_verborgen_tot_reveal() -> void:
	var s := _fresh(Constants.Doctrine.MENS, Constants.Doctrine.MENS)
	Reducer.apply(s, Actions.make_place(s.default_placement(1)), 1)
	Reducer.apply(s, Actions.make_place(s.default_placement(2)), 2)
	var cards: Array = [{"hp": 3, "stamina": 2, "attack": 2},
		{"hp": 2, "stamina": 2, "attack": 3}, {"hp": 2, "stamina": 3, "attack": 2}]
	Reducer.apply(s, Actions.make_define_cards(cards), 1)
	var view_p2: Dictionary = View.for_player(s, 2)
	assert_true(view_p2.enemy_has_defined, "dat P1 ingediend heeft is openbaar (commit-gate)")
	assert_eq(view_p2.cards.size(), 0, "de kaarten zelf zijn onzichtbaar tot de reveal")
	Reducer.apply(s, Actions.make_define_cards(cards), 2)
	view_p2 = View.for_player(s, 2)
	assert_eq(view_p2.cards.size(), 6, "na de reveal zijn alle kaarten van deze ronde openbaar")


func test_vos_sentinel_en_kaart_redactie() -> void:
	var s := _fresh(Constants.Doctrine.MENS, Constants.Doctrine.VOS)
	var pawn: Pawn = s._spawn_pawn(2, Vector2i(5, 5))
	var card := Card.new(s.next_card_id(), 2, 1, 3, 2, 2)
	s.all_cards[card.id] = card
	s.cards_revealed[2] = [card]
	pawn.link_card(card)
	pawn.card_revealed = false  # Krokodil-dekking
	s.phase = Phase.Type.ACTION
	var view_p1: Dictionary = View.for_player(s, 1)
	var pv: Dictionary = view_p1.pawns[str(pawn.id)]
	assert_eq(pv.current_hp, View.HIDDEN)
	assert_eq(pv.attack_value, View.HIDDEN)
	assert_false(pv.has("linked_card_id"), "koppeling weggelaten")
	assert_true(bool(pv.is_active), "dat de pion actief is, is zichtbaar")
	assert_eq(int(pv.unit_type), Constants.UnitType.INFANTRY, "het type is zichtbaar")
	assert_eq(int(view_p1.cards[str(card.id)].linked_pawn_id), -1, "kaart wijst nergens naar")
	# De eigenaar ziet gewoon alles.
	var view_p2: Dictionary = View.for_player(s, 2)
	assert_eq(int(view_p2.pawns[str(pawn.id)].current_hp), 3)
	assert_eq(int(view_p2.pawns[str(pawn.id)].linked_card_id), card.id)
	assert_eq(int(view_p2.cards[str(card.id)].linked_pawn_id), pawn.id)
	# Na onthulling (schade) is alles openbaar.
	pawn.card_revealed = true
	view_p1 = View.for_player(s, 1)
	assert_eq(int(view_p1.pawns[str(pawn.id)].current_hp), 3, "na onthulling volledig zichtbaar")


func test_dekking_vervalt_bij_cyclus_reset() -> void:
	var s := _fresh(Constants.Doctrine.MENS, Constants.Doctrine.VOS)
	var pawn: Pawn = s._spawn_pawn(2, Vector2i(5, 5))
	var card := Card.new(s.next_card_id(), 2, 1, 3, 2, 2)
	s.all_cards[card.id] = card
	pawn.link_card(card)
	pawn.card_revealed = false
	s.phase = Phase.Type.ACTION
	assert_eq(View.for_player(s, 1).pawns[str(pawn.id)].current_hp, View.HIDDEN)
	# Cyclus-reset: unlink zet de dekking terug naar openbaar (er valt niets
	# meer te verbergen — de pion is weer een kaal standbeeld).
	s.reset_for_new_cycle()
	var pv: Dictionary = View.for_player(s, 1).pawns[str(pawn.id)]
	assert_eq(int(pv.current_hp), 0, "na de reset gewoon de (lege) stats")
	assert_true(bool(pv.card_revealed))


func test_c13_schutkleur_valt_weg_van_dichtbij() -> void:
	# C13 (besluit Max, 29 juli): de Krokodil is gedekt op afstand, maar zodra
	# er een ACTIEVE vijand naast staat zie je gewoon wat hij is.
	var s := GameState.new()
	s.doctrines[Constants.PLAYER_1] = Constants.Doctrine.VOS       # Krokodil
	s.doctrines[Constants.PLAYER_2] = Constants.Doctrine.MENS
	var gedekt: Pawn = s._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 5))
	var kaart := Card.new(s.next_card_id(), Constants.PLAYER_1, 1, 3, 2, 2)
	s.all_cards[kaart.id] = kaart
	gedekt.link_card(kaart)
	gedekt.card_revealed = false
	var ver: Pawn = s._spawn_pawn(Constants.PLAYER_2, Vector2i(9, 9))
	var kaart2 := Card.new(s.next_card_id(), Constants.PLAYER_2, 1, 2, 2, 2)
	s.all_cards[kaart2.id] = kaart2
	ver.link_card(kaart2)
	# Ver weg: stats gedekt.
	var v1: Dictionary = View.for_player(s, Constants.PLAYER_2)
	assert_eq(v1.pawns[str(gedekt.id)].current_hp, View.HIDDEN, "op afstand: gedekt")
	# Buurman ernaast: gewoon zichtbaar.
	var dichtbij: Pawn = s._spawn_pawn(Constants.PLAYER_2, Vector2i(5, 4))
	var kaart3 := Card.new(s.next_card_id(), Constants.PLAYER_2, 1, 2, 2, 2)
	s.all_cards[kaart3.id] = kaart3
	dichtbij.link_card(kaart3)
	var v2: Dictionary = View.for_player(s, Constants.PLAYER_2)
	assert_eq(int(v2.pawns[str(gedekt.id)].current_hp), gedekt.current_hp, "van dichtbij: zichtbaar")
	# De tegenstander zelf ziet zijn eigen pion natuurlijk altijd.
	var v3: Dictionary = View.for_player(s, Constants.PLAYER_1)
	assert_eq(int(v3.pawns[str(gedekt.id)].current_hp), gedekt.current_hp, "eigen pion altijd zichtbaar")
	# Uitgeschakelde knop = oud gedrag.
	s.rules.schutkleur_onthul_nabij = false
	var v4: Dictionary = View.for_player(s, Constants.PLAYER_2)
	assert_eq(v4.pawns[str(gedekt.id)].current_hp, View.HIDDEN, "knop uit: blijft gedekt")
