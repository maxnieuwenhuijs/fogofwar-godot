extends TestSuite

# F2.3 — BET_CP: blinde CP-inzet naast de kaartdefinitie (v4.2, config-gated).
# Dekt de masterplan-CHECK: cap per kaart, saldo nooit negatief, view verbergt
# vijandelijke inzet en saldo (D12), plus verbrand-regel (D2), bet-voor-define,
# het D3-initiatief-via-stats en de serialisatie-roundtrip.


func _class_name() -> String:
	return "CpTests"


## Campagne-staat in de eerste define-ronde: 1 vrije pion per kant.
func _define_staat() -> GameState:
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {}})
	s.phase = Phase.Type.SETUP_1_DEFINE
	s.current_player = 1
	s._spawn_pawn(1, Vector2i(5, 9))
	s._spawn_pawn(2, Vector2i(5, 1))
	s.init_pools()
	return s


func _budget(s: GameState, speler: int) -> int:
	return int(s.doctrine_data_of(speler).budget)


## Kaart met som = budget + extra (hp vangt de rest, stamina 1, attack 1).
func _kaart(s: GameState, speler: int, extra: int) -> Dictionary:
	return {"hp": _budget(s, speler) + extra - 2, "stamina": 1, "attack": 1}


func test_cp_start_saldo() -> void:
	var s := _define_staat()
	assert_eq(int(s.cp[1]), 6, "D13: duel start met exact cp_start")
	assert_eq(int(s.cp[2]), 6)


func test_bet_boven_saldo_geweigerd_saldo_nooit_negatief() -> void:
	var s := _define_staat()
	s.cp[1] = 0
	var res: Dictionary = Reducer.apply(s, Actions.make_bet_cp(1), 1)
	assert_false(res.ok, "bet boven saldo geweigerd")
	assert_eq(res.error, "Onvoldoende CP")
	assert_eq(int(s.cp[1]), 0, "saldo blijft 0, nooit negatief")


func test_bet_boven_kaartaantal_geweigerd() -> void:
	var s := _define_staat()
	# 1 vrije pion -> expected 1 -> bet 2 is meer CP dan kaarten (D4).
	var res: Dictionary = Reducer.apply(s, Actions.make_bet_cp(2), 1)
	assert_false(res.ok)
	assert_eq(res.error, "Meer CP dan kaarten deze ronde")


func test_bet_na_define_geweigerd() -> void:
	var s := _define_staat()
	assert_true(Reducer.apply(s, Actions.make_define_cards([_kaart(s, 1, 0)]), 1).ok)
	var res: Dictionary = Reducer.apply(s, Actions.make_bet_cp(1), 1)
	assert_false(res.ok, "bet moet voor de eigen define")


func test_bet_zonder_campaign_geweigerd() -> void:
	var s := _define_staat()
	s.rules = RulesConfig.new()
	var res: Dictionary = Reducer.apply(s, Actions.make_bet_cp(1), 1)
	assert_false(res.ok, "BET_CP bestaat alleen onder campaign")


func test_dikke_kaart_zonder_bet_geweigerd() -> void:
	var s := _define_staat()
	var res: Dictionary = Reducer.apply(s, Actions.make_define_cards([_kaart(s, 1, 1)]), 1)
	assert_false(res.ok)
	assert_eq(res.error, "Kaart boven budget zonder CP-inzet")


func test_cap_1_cp_per_kaart() -> void:
	var s := _define_staat()
	assert_true(Reducer.apply(s, Actions.make_bet_cp(1), 1).ok)
	# budget+2 op een kaart kan nooit (max 1 CP per kaart, D4).
	var res: Dictionary = Reducer.apply(s, Actions.make_define_cards([_kaart(s, 1, 2)]), 1)
	assert_false(res.ok, "budget+2 is boven de 1-CP-per-kaart-cap")


func test_bet_verbrandt_ook_ongebruikt() -> void:
	var s := _define_staat()
	assert_true(Reducer.apply(s, Actions.make_bet_cp(1), 1).ok)
	assert_eq(int(s.cp[1]), 5, "D2: inzet direct verbrand")
	# Define zonder dikke kaart: de CP komt NIET terug.
	assert_true(Reducer.apply(s, Actions.make_define_cards([_kaart(s, 1, 0)]), 1).ok)
	assert_eq(int(s.cp[1]), 5, "geen refund voor ongebruikte inzet")


func test_dikke_kaart_met_bet_en_reveal_flow() -> void:
	var s := _define_staat()
	assert_true(Reducer.apply(s, Actions.make_bet_cp(1), 1).ok)
	assert_true(Reducer.apply(s, Actions.make_define_cards([_kaart(s, 1, 1)]), 1).ok)
	var res: Dictionary = Reducer.apply(s, Actions.make_define_cards([_kaart(s, 2, 0)]), 2)
	assert_true(res.ok)
	assert_true(Phase.is_reveal(s.phase), "beide defines binnen -> reveal")
	var admin: Dictionary = {}
	for ev in res.events:
		if String(ev.type) == Reducer.EV_CP_ADMIN:
			admin = ev.payload
	assert_eq(int(admin.bets["1"]), 1, "cp_admin-ledger draagt de bets")
	assert_eq(int(admin.saldi["1"]), 5)


func test_initiatief_via_stats_d3() -> void:
	# D3: geen aparte bod-regel — het extra punt in Aanval wint het bod vanzelf.
	var s := _define_staat()
	var b: int = _budget(s, 1)
	assert_true(Reducer.apply(s, Actions.make_bet_cp(1), 1).ok)
	assert_true(Reducer.apply(s, Actions.make_define_cards([
		{"hp": b - 2, "stamina": 1, "attack": 2}]), 1).ok)  # attack 2 dankzij CP
	assert_true(Reducer.apply(s, Actions.make_define_cards([
		{"hp": b - 2, "stamina": 1, "attack": 1}]), 2).ok)
	assert_true(Reducer.apply(s, Actions.make_ack_reveal(), 1).ok)
	assert_true(Reducer.apply(s, Actions.make_ack_reveal(), 2).ok)
	assert_eq(s.initiative_player, 1, "het CP-punt in Aanval wint het initiatief")


func test_view_verbergt_vijandelijke_cp_en_inzet() -> void:
	var s := _define_staat()
	assert_true(Reducer.apply(s, Actions.make_bet_cp(1), 1).ok)
	var view2: Dictionary = View.for_player(s, 2)
	assert_eq(view2.cp[str(2)], 6, "eigen saldo zichtbaar")
	assert_eq(view2.cp[str(1)], "?", "D12: vijandelijk saldo verborgen")
	assert_eq(int(view2.own_cp_bet), 0, "own_cp_bet is de EIGEN inzet, niet die van de ander")
	assert_false(view2.has("enemy_cp_bet"), "vijandelijke inzet bestaat niet in de view")
	var view1: Dictionary = View.for_player(s, 1)
	assert_eq(int(view1.own_cp_bet), 1)
	# Full-state-ablatie ziet alles.
	var open: Dictionary = View.for_player(s, 2, false)
	assert_eq(int(open.cp[str(1)]), 5)


func test_cp_serialisatie_roundtrip_mid_bet() -> void:
	var s := _define_staat()
	assert_true(Reducer.apply(s, Actions.make_bet_cp(1), 1).ok)
	var d: Dictionary = Serializer.state_to_dict(s)
	var terug: GameState = Serializer.state_from_dict(d)
	assert_eq(JSON.stringify(Serializer.state_to_dict(terug)), JSON.stringify(d), "roundtrip byte-identiek")
	assert_eq(int(terug.cp[1]), 5)
	assert_eq(int(terug.cp_bets.get(1, 0)), 1)
	assert_true(bool(terug.cp_bet_done.get(1, false)))


func test_cp_earned_ledger_bij_winst() -> void:
	# D13: haven-winst logt cp_earned (tarief 8) zonder het saldo te raken.
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {}})
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	s.init_pools()
	var loper: Pawn = s._spawn_pawn(1, Vector2i(4, 1))
	var kaart := Card.new(s.next_card_id(), 1, 1, 3, 2, 1)
	s.all_cards[kaart.id] = kaart
	loper.link_card(kaart)
	s._spawn_pawn(1, Vector2i(0, 0))  # al in de haven (2e haven-pion na de zet)
	s._spawn_pawn(2, Vector2i(10, 10))
	var saldo_voor: int = int(s.cp[1])
	var res: Dictionary = Reducer.apply(s, Actions.make_move(loper.id, Vector2i(4, 0)), 1)
	assert_true(res.ok)
	assert_eq(s.winner, Constants.PLAYER_1)
	var earned: Dictionary = {}
	for ev in res.events:
		if String(ev.type) == Reducer.EV_CP_EARNED:
			earned = ev.payload
	assert_eq(String(earned.reden), "haven")
	assert_eq(int(earned.amount), 8)
	assert_eq(int(s.cp[1]), saldo_voor, "verdienste raakt het duel-saldo niet (campagnepot)")
