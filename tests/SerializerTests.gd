extends TestSuite

# F0.5 — serializer-tests: round-trip in élke fase, doorspelen na
# deserialisatie, en de expliciete regressietest voor risico 7 uit het
# online-plan: de koppelfase op een gedeserialiseerde staat EINDIGT.


func _class_name() -> String:
	return "SerializerTests"


const CARDS: Array = [{"hp": 3, "stamina": 2, "attack": 2},
	{"hp": 2, "stamina": 2, "attack": 3}, {"hp": 2, "stamina": 3, "attack": 2}]


func _fresh() -> GameState:
	var s := GameState.new()
	s.doctrines[Constants.PLAYER_1] = Constants.Doctrine.MENS
	s.doctrines[Constants.PLAYER_2] = Constants.Doctrine.VOS
	s.phase = Phase.Type.PLACEMENT
	return s


## Speel deterministisch (eerste legale actie) tot een doel-fase bereikt is.
func _play_until(s: GameState, stop_check: Callable, max_steps: int = 400) -> void:
	for _i in max_steps:
		if stop_check.call(s) or s.phase == Phase.Type.GAME_OVER:
			return
		var speler_orde: Array = [s.current_player, Constants.opponent(s.current_player)]
		var acted := false
		for speler in speler_orde:
			var opties: Array = Validator.legal_actions(s, speler)
			if opties.is_empty():
				continue
			Reducer.apply(s, opties[0], speler)
			acted = true
			break
		if not acted:
			return


func _canon(s: GameState) -> String:
	return JSON.stringify(Serializer.state_to_dict(s))


func _roundtrip(s: GameState) -> GameState:
	# Via JSON-string: bewijst meteen dat het formaat JSON-veilig is.
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(Serializer.state_to_dict(s)))
	return Serializer.state_from_dict(parsed)


func test_roundtrip_in_elke_fase() -> void:
	var checks: Dictionary = {
		"placement": func(st: GameState) -> bool: return st.phase == Phase.Type.PLACEMENT,
		"define": func(st: GameState) -> bool: return Phase.is_define(st.phase),
		"reveal": func(st: GameState) -> bool: return Phase.is_reveal(st.phase),
		"linking": func(st: GameState) -> bool: return Phase.is_linking(st.phase),
		"action": func(st: GameState) -> bool: return st.phase == Phase.Type.ACTION,
	}
	for naam in checks:
		var s := _fresh()
		_play_until(s, checks[naam])
		assert_true(checks[naam].call(s), "doel-fase %s bereikt" % naam)
		var terug := _roundtrip(s)
		assert_eq(_canon(terug), _canon(s), "round-trip veld-voor-veld identiek in %s" % naam)
	# GAME_OVER: tot de actiefase spelen en opgeven.
	var eind := _fresh()
	_play_until(eind, func(st: GameState) -> bool: return st.phase == Phase.Type.ACTION)
	Reducer.apply(eind, Actions.make_resign(), eind.current_player)
	assert_eq(eind.phase, Phase.Type.GAME_OVER)
	assert_eq(_canon(_roundtrip(eind)), _canon(eind), "round-trip identiek in game_over")


func test_doorspelen_na_deserialisatie_identiek() -> void:
	# Tot in de actiefase spelen, snapshotten, en dan BEIDE staten met
	# hetzelfde script doorspelen: uitkomst moet identiek zijn.
	var s := _fresh()
	_play_until(s, func(st: GameState) -> bool: return st.phase == Phase.Type.ACTION)
	assert_eq(s.phase, Phase.Type.ACTION)
	var kopie := _roundtrip(s)
	for _i in 40:
		if s.phase == Phase.Type.GAME_OVER:
			break
		var opties_a: Array = Validator.legal_actions(s, s.current_player)
		var opties_b: Array = Validator.legal_actions(kopie, kopie.current_player)
		assert_eq(opties_b.size(), opties_a.size(), "zelfde zetruimte op beide staten")
		if opties_a.is_empty():
			break
		Reducer.apply(s, opties_a[0], s.current_player)
		Reducer.apply(kopie, opties_b[0], kopie.current_player)
	assert_eq(_canon(kopie), _canon(s), "na 40 identieke zetten nog steeds dezelfde staat")


func test_linking_eindigt_na_deserialisatie() -> void:
	# Risico 7 (online-plan): naïef klonen brak kaart-identiteit, waardoor de
	# koppelfase op een gedeserialiseerde staat nooit eindigde.
	var s := _fresh()
	_play_until(s, func(st: GameState) -> bool: return Phase.is_linking(st.phase))
	assert_true(Phase.is_linking(s.phase))
	var terug := _roundtrip(s)
	var guard := 0
	while Phase.is_linking(terug.phase) and guard < 25:
		guard += 1
		var opties: Array = Validator.legal_actions(terug, terug.current_player)
		assert_true(not opties.is_empty(), "koppelbeurt op gedeserialiseerde staat heeft opties")
		Reducer.apply(terug, opties[0], terug.current_player)
	assert_false(Phase.is_linking(terug.phase), "de koppelfase EINDIGT op een gedeserialiseerde staat")


func test_kaart_identiteit_na_deserialisatie() -> void:
	var s := _fresh()
	_play_until(s, func(st: GameState) -> bool: return Phase.is_linking(st.phase))
	var terug := _roundtrip(s)
	for speler in [Constants.PLAYER_1, Constants.PLAYER_2]:
		for c in terug.cards_revealed[speler]:
			assert_true(c == terug.all_cards[c.id],
				"kaart %d in cards_revealed IS het all_cards-object (geen kopie)" % c.id)


func test_clone_is_ref_correct_en_gelijk_aan_serializer() -> void:
	var s := _fresh()
	_play_until(s, func(st: GameState) -> bool: return Phase.is_linking(st.phase))
	var kloon := s.clone()
	# Zelfde inhoud als het serializer-pad (de twee kopieerpaden blijven in lockstep).
	assert_eq(_canon(kloon), _canon(s), "clone en serializer materialiseren dezelfde staat")
	# En ref-correct: koppelen op de kloon eindigt (het oude clone-gat).
	for speler in [Constants.PLAYER_1, Constants.PLAYER_2]:
		for c in kloon.cards_revealed[speler]:
			assert_true(c == kloon.all_cards[c.id], "kloon-kaart %d is één object" % c.id)
	var guard := 0
	while Phase.is_linking(kloon.phase) and guard < 25:
		guard += 1
		var opties: Array = Validator.legal_actions(kloon, kloon.current_player)
		if opties.is_empty():
			break
		Reducer.apply(kloon, opties[0], kloon.current_player)
	assert_false(Phase.is_linking(kloon.phase), "de koppelfase eindigt ook op een kloon")


func test_eliminaties_en_bord_herbouw() -> void:
	# Bord wordt niet geserialiseerd maar herbouwd; geëlimineerde pionnen
	# horen niet op het bord maar wél in de pion-lijst te blijven.
	var s := GameState.new()
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var aanvaller: Pawn = s._spawn_pawn(1, Vector2i(5, 5))
	var kaart := Card.new(s.next_card_id(), 1, 1, 3, 2, 3)
	s.all_cards[kaart.id] = kaart
	aanvaller.link_card(kaart)
	var slachtoffer: Pawn = s._spawn_pawn(2, Vector2i(5, 4))
	s._spawn_pawn(2, Vector2i(0, 0))  # tweede pion zodat de partij niet eindigt
	Reducer.apply(s, Actions.make_melee(aanvaller.id, slachtoffer.id), 1)
	assert_true(s.pawns[slachtoffer.id].is_eliminated)
	var terug := _roundtrip(s)
	assert_true(terug.pawns[slachtoffer.id].is_eliminated, "geëlimineerde pion blijft in de lijst")
	assert_eq(terug.get_pawn_at(Vector2i(5, 4)).id, aanvaller.id,
		"verplichte verplaatsing zichtbaar op het herbouwde bord")
	assert_eq(_canon(terug), _canon(s))


func test_haven_touches_round_trip() -> void:
	var s := GameState.new()
	s.rules = RulesConfig.new()
	s.rules.haven_score_cumulative = true
	s.phase = Phase.Type.ACTION
	var pawn: Pawn = s._spawn_pawn(1, Vector2i(4, 1))
	var card := Card.new(s.next_card_id(), 1, 1, 3, 5, 1)
	s.all_cards[card.id] = card
	pawn.link_card(card)
	s.set_pawn_position(pawn, Vector2i(4, 0))  # touch
	s.set_pawn_position(pawn, Vector2i(4, 5))  # weer weg
	assert_true(s.haven_touches[1].has(pawn.id))
	var terug := _roundtrip(s)
	assert_true(terug.haven_touches[1].has(pawn.id), "touch overleeft de round-trip")
	assert_eq(Rules.count_pawns_in_haven(terug, 1), 1, "cumulatieve telling blijft kloppen")


## 8 augustus: de fuzz draait sinds vandaag op de ECHTE regels (campagne +
## factie-blok) en zijn fold brak meteen op actie 0. Deze test knipt dat op:
## overleeft een CAMPAGNE-staat de rondreis door de serializer, inclusief de
## regels zelf? Zonder dit is elk campagne-replay (en dus elke golden) blind.
func test_campagne_staat_rondreist() -> void:
	var regels := RulesConfig.load_from_file(CRules.REGELS_BESTAND)
	var s := GameState.new()
	s.rules = regels
	s.doctrines[Constants.PLAYER_1] = Constants.Doctrine.MUIS
	s.doctrines[Constants.PLAYER_2] = Constants.Doctrine.BEER
	s.phase = Phase.Type.PLACEMENT
	s.init_pools()
	var voor: Dictionary = Serializer.state_to_dict(s)
	var terug: GameState = Serializer.state_from_dict(voor)
	var na: Dictionary = Serializer.state_to_dict(terug)
	assert_eq(JSON.stringify(na), JSON.stringify(voor), "campagne-staat rondreist byte-identiek")
	assert_eq(Zobrist.state_hash(terug), Zobrist.state_hash(s), "en dezelfde zobrist-hash")
	# De regels moeten mee: zonder campagne-blok of factie-blok speelt de
	# nagespeelde partij een ander spel dan de opgenomen partij.
	assert_true(terug.rules.campaign_actief(), "campagne-blok overleeft de rondreis")
	assert_eq((terug.rules.doctrines as Dictionary).size(),
		(regels.doctrines as Dictionary).size(), "factie-blok overleeft de rondreis")
	assert_eq(int(terug.doctrine_data_of(Constants.PLAYER_1).cards),
		int(regels.doctrine_data(Constants.Doctrine.MUIS).cards),
		"en de Muis houdt zijn kaartaantal")


## C15-BUGFIX (8 augustus): de figurant-rol viel uit de ACTIE weg, niet uit de
## pion. De opstelling gaat als `place`-actie het log in; `Actions.to_dict`
## schreef alleen type en positie, dus elke opgenomen campagne-partij verloor
## zijn vaandeldragers en tamboers. Bij het naspelen viel de C15-buit dan weg
## (2 punten / 2 CP per drager) en liep de staat meteen uit de pas. De fuzz zag
## het niet omdat die tot vandaag op 4.1-regels draaide, waar rollen niet
## bestaan. Deze test is het slot op de deur.
func test_c15_rol_overleeft_de_actie_rondreis() -> void:
	var actie: Dictionary = Actions.make_place([
		{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(0, 10), "rol": "flag"},
		{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(2, 10), "rol": "drum"},
		{"type": Constants.UnitType.CAVALRY, "pos": Vector2i(4, 10)},
	])
	var terug: Dictionary = Actions.from_dict(Actions.to_dict(actie))
	var plc: Array = terug.placements
	assert_eq(plc.size(), 3)
	assert_eq(String(plc[0].get("rol", "")), "flag", "vaandel reist mee")
	assert_eq(String(plc[1].get("rol", "")), "drum", "tamboer reist mee")
	assert_eq(plc[2].pos, Vector2i(4, 10), "positie blijft een Vector2i")
	# Zonder rol GEEN sleutel: logs van voor de fix blijven byte-identiek en
	# spelen zich precies zo af als toen ze werden opgenomen.
	var kaal: Dictionary = Actions.to_dict(Actions.make_place([
		{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(1, 10)}]))
	assert_false((kaal.placements[0] as Dictionary).has("rol"),
		"lege rol voegt geen sleutel toe")
