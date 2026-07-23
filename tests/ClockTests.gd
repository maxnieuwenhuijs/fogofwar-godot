extends TestSuite

# F0.8 — klokken en CLAIM_TIMEOUT. De reducer is puur: now_ms komt als
# parameter mee (tests gebruiken een eigen milliseconden-teller). Model:
# setup-fasen = increment per beslissing (defaults bij overschrijding),
# actiefase = increment + bank (overschot eet de bank; deadline = forfeit).


func _class_name() -> String:
	return "ClockTests"


const CARDS: Array = [{"hp": 3, "stamina": 2, "attack": 2},
	{"hp": 2, "stamina": 2, "attack": 3}, {"hp": 2, "stamina": 3, "attack": 2}]


## Actiefase-staat met klokken aan (bank 60s, increment 5s).
func _klok_state() -> GameState:
	var s := GameState.new()
	s.rules = RulesConfig.new()
	s.rules.clock = {"bank_sec": 60, "increment_sec": 5, "reconnect_grace_sec": 20}
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var p1: Pawn = s._spawn_pawn(1, Vector2i(5, 8))
	var c1 := Card.new(s.next_card_id(), 1, 1, 3, 4, 2)
	s.all_cards[c1.id] = c1
	p1.link_card(c1)
	var p2: Pawn = s._spawn_pawn(2, Vector2i(5, 2))
	var c2 := Card.new(s.next_card_id(), 2, 1, 3, 4, 2)
	s.all_cards[c2.id] = c2
	p2.link_card(c2)
	return s


func test_increment_na_actie_spaart_de_bank() -> void:
	var s := _klok_state()
	# Eerste actie op t=1000 zet de deadline (bank nog onaangeroerd).
	var mover: int = s.get_pawn_at(Vector2i(5, 8)).id
	var res: Dictionary = Reducer.apply(s, Actions.make_move(mover, Vector2i(5, 7)), 1, 1000)
	assert_true(res.ok)
	assert_eq(int(s.clocks[1].bank_ms), 60000, "eerste actie: bank onaangeroerd")
	assert_eq(s.turn_deadline, 1000 + 5000 + 60000, "deadline = now + increment + bank van de beurtspeler")
	# P2 handelt binnen zijn increment (3s van de 5s): bank blijft vol.
	var mover2: int = s.get_pawn_at(Vector2i(5, 2)).id
	res = Reducer.apply(s, Actions.make_move(mover2, Vector2i(5, 3)), 2, 4000)
	assert_true(res.ok)
	assert_eq(int(s.clocks[2].bank_ms), 60000, "binnen de increment kost een beurt geen bank")


func test_trage_actie_eet_de_bank() -> void:
	var s := _klok_state()
	var mover: int = s.get_pawn_at(Vector2i(5, 8)).id
	Reducer.apply(s, Actions.make_move(mover, Vector2i(5, 7)), 1, 1000)
	# P2 doet er 12s over: 5s increment gratis, 7s uit de bank.
	var mover2: int = s.get_pawn_at(Vector2i(5, 2)).id
	Reducer.apply(s, Actions.make_move(mover2, Vector2i(5, 3)), 2, 13000)
	assert_eq(int(s.clocks[2].bank_ms), 53000, "7s overschot van de bank af")


func test_claim_voor_deadline_geweigerd() -> void:
	var s := _klok_state()
	var mover: int = s.get_pawn_at(Vector2i(5, 8)).id
	Reducer.apply(s, Actions.make_move(mover, Vector2i(5, 7)), 1, 1000)
	var res: Dictionary = Reducer.apply(s, Actions.make_claim_timeout(), 1, 30000)
	assert_false(res.ok, "claim ruim vóór de deadline moet geweigerd worden")
	assert_eq(res.error, "Deadline nog niet verstreken")


func test_lege_bank_claim_is_forfeit() -> void:
	var s := _klok_state()
	var mover: int = s.get_pawn_at(Vector2i(5, 8)).id
	Reducer.apply(s, Actions.make_move(mover, Vector2i(5, 7)), 1, 1000)
	# Deadline van P2 = 1000 + 5000 + 60000 = 66000; P1 claimt op 70000.
	var res: Dictionary = Reducer.apply(s, Actions.make_claim_timeout(), 1, 70000)
	assert_true(res.ok, "claim na de deadline is legaal")
	assert_eq(s.phase, Phase.Type.GAME_OVER, "bank leeg -> forfeit")
	assert_eq(s.winner, Constants.PLAYER_1, "de tegenstander van de beurtspeler wint")
	assert_eq(int(s.clocks[2].bank_ms), 0)


func test_timeout_in_define_geeft_default_loadout() -> void:
	var s := GameState.new()
	s.rules = RulesConfig.new()
	s.rules.clock = {"bank_sec": 60, "increment_sec": 5, "reconnect_grace_sec": 20}
	s.phase = Phase.Type.PLACEMENT
	# Opstelling met klok: P1 dient in op t=1000 (zet meteen de deadline).
	var res: Dictionary = Reducer.apply(s, Actions.make_place(s.default_placement(1)), 1, 1000)
	assert_true(res.ok)
	assert_true(s.turn_deadline > 0, "deadline staat na de eerste actie")
	# P2 laat de opstellings-deadline verlopen -> default-opstelling.
	res = Reducer.apply(s, Actions.make_claim_timeout(), 1, s.turn_deadline + 1000)
	assert_true(res.ok)
	assert_true(Phase.is_define(s.phase), "beide opstellingen binnen -> define")
	# P1 definieert; P2 laat de define-deadline verlopen -> default-loadout.
	Reducer.apply(s, Actions.make_define_cards(CARDS), 1, s.turn_deadline - 1000)
	assert_true(Phase.is_define(s.phase), "commit-gate wacht op P2")
	res = Reducer.apply(s, Actions.make_claim_timeout(), 1, s.turn_deadline + 1000)
	assert_true(res.ok, "timeout-claim in define moet slagen")
	assert_eq(s.cards_defined[2].size(), 3, "P2 kreeg de default-loadout")
	assert_true(Phase.is_reveal(s.phase), "beide loadouts binnen -> reveal")


func test_klokken_uit_claim_illegaal() -> void:
	var s := _klok_state()
	s.rules = RulesConfig.new()  # default: bank_sec 0 = klokken uit
	var verdict: Dictionary = Validator.is_legal(s, Actions.make_claim_timeout(), 1)
	assert_false(verdict.legal)
	assert_eq(verdict.reason, "Klokken staan uit in deze match")


func test_klokken_serialiseren_mee() -> void:
	var s := _klok_state()
	var mover: int = s.get_pawn_at(Vector2i(5, 8)).id
	Reducer.apply(s, Actions.make_move(mover, Vector2i(5, 7)), 1, 1000)
	Reducer.apply(s, Actions.make_move(s.get_pawn_at(Vector2i(5, 2)).id, Vector2i(5, 3)), 2, 13000)
	var terug: GameState = Serializer.state_from_dict(JSON.parse_string(JSON.stringify(Serializer.state_to_dict(s))))
	assert_eq(int(terug.clocks[2].bank_ms), 53000, "bank overleeft de round-trip")
	assert_eq(terug.turn_deadline, s.turn_deadline)
	assert_eq(JSON.stringify(Serializer.state_to_dict(terug)), JSON.stringify(Serializer.state_to_dict(s)))


func test_timeout_in_reveal_ackt_achterblijver() -> void:
	var s := GameState.new()
	s.rules = RulesConfig.new()
	s.rules.clock = {"bank_sec": 60, "increment_sec": 5, "reconnect_grace_sec": 20}
	s.phase = Phase.Type.PLACEMENT
	Reducer.apply(s, Actions.make_place(s.default_placement(1)), 1, 1000)
	Reducer.apply(s, Actions.make_place(s.default_placement(2)), 2, 2000)
	Reducer.apply(s, Actions.make_define_cards(CARDS), 1, 3000)
	Reducer.apply(s, Actions.make_define_cards(CARDS), 2, 4000)
	assert_true(Phase.is_reveal(s.phase))
	Reducer.apply(s, Actions.make_ack_reveal(), 1, 5000)
	assert_true(Phase.is_reveal(s.phase), "wachten op de trage P2")
	var res: Dictionary = Reducer.apply(s, Actions.make_claim_timeout(), 1, s.turn_deadline + 500)
	assert_true(res.ok)
	assert_true(Phase.is_linking(s.phase), "timeout in reveal ackt de achterblijver -> koppelen")


func test_timeout_in_linking_koppelt_automatisch() -> void:
	var s := GameState.new()
	s.rules = RulesConfig.new()
	s.rules.clock = {"bank_sec": 60, "increment_sec": 5, "reconnect_grace_sec": 20}
	s.phase = Phase.linking_for_round(1)
	s.current_player = 1
	s.initiative_player = 1
	var vrij: Pawn = s._spawn_pawn(1, Vector2i(5, 9))
	var kaart := Card.new(s.next_card_id(), 1, 1, 3, 2, 2)
	s.all_cards[kaart.id] = kaart
	s.cards_revealed[1] = [kaart]
	s._spawn_pawn(2, Vector2i(5, 1))
	s.turn_deadline = 10000  # koppel-deadline loopt
	var res: Dictionary = Reducer.apply(s, Actions.make_claim_timeout(), 2, 11000)
	assert_true(res.ok)
	assert_eq(vrij.linked_card_id, kaart.id, "timeout koppelt automatisch de eerste legale optie")
	assert_false(Phase.is_linking(s.phase), "geen koppelwerk meer -> fase schuift door")
