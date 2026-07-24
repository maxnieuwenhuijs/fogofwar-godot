extends TestSuite

# F2.4 — CANNON_ACT (v4.2, config-gated): ROLL en SHOOT uit de stamina-pot,
# dracht/kosten uit campaign.*, RETREAT bestaat niet (D9). Dekt de masterplan-
# CHECK: beide subacties, dode zone en blokkade onder v4.2-config, en het
# 4.1-compat-pad (MOVE/SHOOT blijven daar werken).


func _class_name() -> String:
	return "CannonTests"


## Campagne-actiefase: P1-kanon (stamina 3, attack 2) op (5,5), actieve
## P2-vijand (5 HP) op (5,3) — afstand 2, precies op de dode-zone-grens.
func _kanon_staat(extra_campaign: Dictionary = {}) -> Dictionary:
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": extra_campaign})
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var kanon: Pawn = s._spawn_pawn(1, Vector2i(5, 5), Constants.UnitType.ARTILLERY)
	var kk := Card.new(s.next_card_id(), 1, 1, 2, 3, 2)
	s.all_cards[kk.id] = kk
	kanon.link_card(kk)
	var doel: Pawn = s._spawn_pawn(2, Vector2i(5, 3))
	var dk := Card.new(s.next_card_id(), 2, 1, 5, 2, 1)
	s.all_cards[dk.id] = dk
	doel.link_card(dk)
	s._spawn_pawn(2, Vector2i(10, 10))
	s.init_pools()
	return {"s": s, "kanon": kanon, "doel": doel}


func test_roll_1_vak_kost_1_stamina() -> void:
	var o: Dictionary = _kanon_staat()
	var s: GameState = o.s
	var res: Dictionary = Reducer.apply(s, Actions.make_cannon_roll(o.kanon.id, Vector2i(4, 5)), 1)
	assert_true(res.ok, "roll naar een vrij buurvak")
	assert_eq(o.kanon.position, Vector2i(4, 5))
	assert_eq(o.kanon.remaining_stamina, 2, "roll kost 1 stamina")


func test_roll_kost_uit_config() -> void:
	var o: Dictionary = _kanon_staat({"kanon_actie_kost": {"roll": 2, "shoot": 1}})
	var s: GameState = o.s
	assert_true(Reducer.apply(s, Actions.make_cannon_roll(o.kanon.id, Vector2i(4, 5)), 1).ok)
	assert_eq(o.kanon.remaining_stamina, 1, "rol-kost 2 uit campaign.kanon_actie_kost")


func test_shoot_binnen_dracht_en_schade() -> void:
	var o: Dictionary = _kanon_staat()
	var s: GameState = o.s
	var res: Dictionary = Reducer.apply(s, Actions.make_cannon_shoot(o.kanon.id, o.doel.id), 1)
	assert_true(res.ok, "schot op afstand 2 (= art_min_range)")
	assert_eq(o.doel.current_hp, 3, "schade = attack 2")
	assert_eq(o.kanon.remaining_stamina, 2, "schot kost 1 stamina")


func test_shoot_kost_uit_config() -> void:
	var o: Dictionary = _kanon_staat({"kanon_actie_kost": {"roll": 1, "shoot": 2}})
	var s: GameState = o.s
	assert_true(Reducer.apply(s, Actions.make_cannon_shoot(o.kanon.id, o.doel.id), 1).ok)
	assert_eq(o.kanon.remaining_stamina, 1, "schot-kost 2 uit campaign.kanon_actie_kost")


func test_dracht_uit_config() -> void:
	# kanon_dracht_max 2: het doelwit op afstand 2 raakbaar, op 3 niet meer.
	var o: Dictionary = _kanon_staat({"kanon_dracht_max": 2})
	var s: GameState = o.s
	assert_has(Rules.get_valid_shot_targets(s, o.kanon.id), o.doel.id)
	s.set_pawn_position(o.doel, Vector2i(5, 2))  # afstand 3
	assert_false(Rules.get_valid_shot_targets(s, o.kanon.id).has(o.doel.id),
		"afstand 3 valt buiten kanon_dracht_max 2")
	var res: Dictionary = Reducer.apply(s, Actions.make_cannon_shoot(o.kanon.id, o.doel.id), 1)
	assert_false(res.ok, "schot buiten de campaign-dracht geweigerd")


func test_dode_zone_blijft() -> void:
	var o: Dictionary = _kanon_staat()
	var s: GameState = o.s
	s.set_pawn_position(o.doel, Vector2i(5, 4))  # afstand 1
	var res: Dictionary = Reducer.apply(s, Actions.make_cannon_shoot(o.kanon.id, o.doel.id), 1)
	assert_false(res.ok, "afstand 1 is nooit beschietbaar (art_min_range 2)")


func test_blokkade_blijft() -> void:
	var o: Dictionary = _kanon_staat()
	var s: GameState = o.s
	s._spawn_pawn(1, Vector2i(5, 4))  # eigen standbeeld in de vuurlijn
	var res: Dictionary = Reducer.apply(s, Actions.make_cannon_shoot(o.kanon.id, o.doel.id), 1)
	assert_false(res.ok, "fire_blocked: de tussenpion blokkeert de lijn")


func test_move_en_shoot_geweigerd_onder_campaign() -> void:
	var o: Dictionary = _kanon_staat()
	var s: GameState = o.s
	var mv: Dictionary = Reducer.apply(s, Actions.make_move(o.kanon.id, Vector2i(4, 5)), 1)
	assert_false(mv.ok)
	assert_eq(mv.error, "Kanon beweegt via CANNON_ACT")
	var sh: Dictionary = Reducer.apply(s, Actions.make_shoot(o.kanon.id, o.doel.id), 1)
	assert_false(sh.ok)
	assert_eq(sh.error, "Kanon schiet via CANNON_ACT")


func test_41_compat_move_shoot_werken_zonder_campaign() -> void:
	var o: Dictionary = _kanon_staat()
	var s: GameState = o.s
	s.rules = RulesConfig.new()  # campaign weg -> 4.1-pad
	assert_true(Reducer.apply(s, Actions.make_shoot(o.kanon.id, o.doel.id), 1).ok, "SHOOT onder 4.1")
	s.current_player = 1
	assert_true(Reducer.apply(s, Actions.make_move(o.kanon.id, Vector2i(4, 5)), 1).ok, "MOVE onder 4.1")
	var ca: Dictionary = Reducer.apply(s, Actions.make_cannon_roll(o.kanon.id, Vector2i(4, 4)), 1)
	assert_false(ca.ok, "CANNON_ACT bestaat niet onder 4.1")


func test_retreat_bestaat_niet() -> void:
	var o: Dictionary = _kanon_staat()
	var actie: Dictionary = {"type": Actions.CANNON_ACT, "pawn_id": o.kanon.id, "sub": "retreat"}
	assert_false(Actions.is_wellformed(actie), "D9: RETREAT is geen subactie")
	var res: Dictionary = Reducer.apply(o.s, actie, 1)
	assert_false(res.ok)


func test_alleen_artillerie() -> void:
	var o: Dictionary = _kanon_staat()
	var s: GameState = o.s
	var inf: Pawn = s._spawn_pawn(1, Vector2i(2, 8))
	var ik := Card.new(s.next_card_id(), 1, 1, 3, 2, 1)
	s.all_cards[ik.id] = ik
	inf.link_card(ik)
	var res: Dictionary = Reducer.apply(s, Actions.make_cannon_roll(inf.id, Vector2i(2, 7)), 1)
	assert_false(res.ok, "infanterie kent geen kanon-acties")


func test_legal_actions_spreekt_cannon_act() -> void:
	var o: Dictionary = _kanon_staat()
	var s: GameState = o.s
	var cannon_acts: int = 0
	for a in Validator.legal_actions(s, 1):
		var t: String = String(a.type)
		if t == Actions.CANNON_ACT and int(a.pawn_id) == o.kanon.id:
			cannon_acts += 1
		if (t == Actions.MOVE and int(a.pawn_id) == o.kanon.id) \
				or (t == Actions.SHOOT and int(a.get("shooter_id", -1)) == o.kanon.id):
			assert_true(false, "onder campaign geen MOVE/SHOOT voor het kanon in legal_actions")
	assert_true(cannon_acts > 0, "legal_actions bevat cannon_act-opties (roll en/of shoot)")
