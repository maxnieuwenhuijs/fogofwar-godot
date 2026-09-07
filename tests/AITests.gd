extends "res://tests/TestSuite.gd"

func _class_name() -> String:
	return "AITests"

func _make_initial_state() -> GameState:
	var state := GameState.new()
	state.setup_initial_pawns()
	return state

func _fake_reveal_cards(state: GameState, player_id: int) -> void:
	state.cards_revealed[player_id] = []
	for i in Constants.CARDS_PER_ROUND:
		var c := Card.new(state.next_card_id(), player_id, 1, 2, 3, 2)
		state.cards_revealed[player_id].append(c)
		state.all_cards[c.id] = c

# AI moet in ronde 1 nooit een achterste-rij-pion koppelen als er een
# voorste-rij-pion beschikbaar is, want die zit ingeklemd.
func test_ai_easy_picks_front_row_in_round_one() -> void:
	var ai = preload("res://scripts/ai/AIEasy.gd").new()
	ai.player_id = Constants.PLAYER_2
	var state: GameState = _make_initial_state()
	_fake_reveal_cards(state, Constants.PLAYER_2)
	for i in 30:
		var choice: Dictionary = ai.choose_link(state)
		assert_true(choice.has("pawn_id"))
		var picked: Pawn = state.pawns[choice.pawn_id]
		# Row 1 is de voorste rij voor P2 (dichter bij het midden).
		assert_eq(picked.position.y, 1)

func test_ai_medium_picks_front_row_in_round_one() -> void:
	var ai = preload("res://scripts/ai/AIMedium.gd").new()
	ai.player_id = Constants.PLAYER_2
	var state: GameState = _make_initial_state()
	_fake_reveal_cards(state, Constants.PLAYER_2)
	var choice: Dictionary = ai.choose_link(state)
	assert_true(choice.has("pawn_id"))
	var picked: Pawn = state.pawns[choice.pawn_id]
	assert_eq(picked.position.y, 1)

# Als de hele voorste rij al gelinkt of verwijderd is, moet de AI wel
# terugvallen op de resterende pionnen.
func test_ai_easy_falls_back_when_no_movable_pawns() -> void:
	var ai = preload("res://scripts/ai/AIEasy.gd").new()
	ai.player_id = Constants.PLAYER_2
	var state := GameState.new()
	# Zet pionnen naast elkaar in een hoek zodat ze ingeklemd zijn.
	state._spawn_pawn(Constants.PLAYER_2, Vector2i(0, 0))
	state._spawn_pawn(Constants.PLAYER_2, Vector2i(1, 0))
	state._spawn_pawn(Constants.PLAYER_2, Vector2i(0, 1))
	state._spawn_pawn(Constants.PLAYER_2, Vector2i(1, 1))
	state._spawn_pawn(Constants.PLAYER_2, Vector2i(2, 0))
	state._spawn_pawn(Constants.PLAYER_2, Vector2i(2, 1))
	_fake_reveal_cards(state, Constants.PLAYER_2)
	# Niet crashen, wel een keuze teruggeven.
	var choice: Dictionary = ai.choose_link(state)
	assert_true(choice.has("pawn_id"))
	assert_true(state.pawns.has(choice.pawn_id))

# =========================================================================
# v4.1: kaartgeneratie per doctrine
# =========================================================================

func _assert_cards_valid(cards: Array, doctrine: int) -> void:
	var data: Dictionary = Constants.doctrine_data(doctrine)
	assert_eq(cards.size(), int(data.cards))
	for c in cards:
		assert_true(Card.is_valid_stats(int(c.hp), int(c.stamina), int(c.attack), data.budget, data.speed_max),
			"kaart %s doctrine %s" % [str(c), Constants.doctrine_name(doctrine)])

func test_generate_cards_respects_doctrine_budgets() -> void:
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_1
	for doctrine in Constants.DOCTRINE_DATA.keys():
		var state := GameState.new()
		state.doctrines[Constants.PLAYER_1] = doctrine
		state.setup_initial_pawns()  # 4.1.10-hr: kaart-aantal hangt van vrije pionnen af
		var cards: Array = ai.generate_cards(state)
		_assert_cards_valid(cards, doctrine)

func test_choose_link_prefers_attack_card_on_artillery() -> void:
	# Type-bewust koppelen: de aanvalskaart hoort op het kanon (zware granaten),
	# niet de sprinterkaart.
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_1
	var state := GameState.new()
	var gun: Pawn = state._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.ARTILLERY)
	var atk_card := Card.new(state.next_card_id(), Constants.PLAYER_1, 1, 1, 1, 5)
	var spd_card := Card.new(state.next_card_id(), Constants.PLAYER_1, 1, 1, 5, 1)
	state.all_cards[atk_card.id] = atk_card
	state.all_cards[spd_card.id] = spd_card
	state.cards_revealed[Constants.PLAYER_1] = [spd_card, atk_card]
	var choice: Dictionary = ai.choose_link(state)
	assert_eq(choice.pawn_id, gun.id)
	assert_eq(choice.card_id, atk_card.id)

func test_choose_placement_weights_put_artillery_front() -> void:
	# Met de default opstellings-gewichten staan kanonnen op de voorste rij.
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_2
	var state := GameState.new()
	var placements: Array = ai.choose_placement(state)
	var front_row: int = Constants.get_start_rows_for_player(Constants.PLAYER_2)[1]
	for entry in placements:
		if int(entry.type) == Constants.UnitType.ARTILLERY:
			assert_eq(entry.pos.y, front_row)

func test_choose_placement_is_valid() -> void:
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_2
	for doctrine in [Constants.Doctrine.MENS, Constants.Doctrine.LEEUW, Constants.Doctrine.MUIS]:
		var state := GameState.new()
		state.doctrines[Constants.PLAYER_2] = doctrine
		var placements: Array = ai.choose_placement(state)
		assert_true(state.is_valid_placement(Constants.PLAYER_2, placements))

# =========================================================================
# v4.1: actie-enumeratie met schoten en charges
# =========================================================================

func test_enumerate_includes_shots() -> void:
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_1
	var state := GameState.new()
	var shooter: Pawn = state._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 5))
	var enemy: Pawn = state._spawn_pawn(Constants.PLAYER_2, Vector2i(5, 3))
	var card := Card.new(state.next_card_id(), Constants.PLAYER_1, 1, 3, 1, 3)
	state.all_cards[card.id] = card
	shooter.link_card(card)
	var found_shot := false
	for a in ai.enumerate_actions(state, Constants.PLAYER_1):
		if a.type == "shot" and a.target_id == enemy.id:
			found_shot = true
	assert_true(found_shot)

func test_enumerate_includes_charges() -> void:
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_1
	var state := GameState.new()
	var cav: Pawn = state._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 6), Constants.UnitType.CAVALRY)
	var enemy: Pawn = state._spawn_pawn(Constants.PLAYER_2, Vector2i(5, 3))
	# Speed 3: 2 stappen + aanval past in de charge-kosten.
	var card := Card.new(state.next_card_id(), Constants.PLAYER_1, 1, 3, 3, 2)
	state.all_cards[card.id] = card
	cav.link_card(card)
	var found_charge := false
	for a in ai.enumerate_actions(state, Constants.PLAYER_1):
		if a.type == "charge" and a.defender_id == enemy.id and a.move_target == Vector2i(5, 4):
			found_charge = true
	assert_true(found_charge)

func test_simulate_handles_all_action_types() -> void:
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_1
	var state := GameState.new()
	var shooter: Pawn = state._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 5))
	var _enemy: Pawn = state._spawn_pawn(Constants.PLAYER_2, Vector2i(5, 3))
	var card := Card.new(state.next_card_id(), Constants.PLAYER_1, 1, 3, 1, 3)
	state.all_cards[card.id] = card
	shooter.link_card(card)
	for a in ai.enumerate_actions(state, Constants.PLAYER_1):
		var copy: GameState = ai.simulate(state, a)
		# De actie moet in de kopie zijn uitgevoerd (stamina besteed), niet in het origineel.
		assert_true(copy.pawns[shooter.id].remaining_stamina < state.pawns[shooter.id].remaining_stamina)
		assert_eq(state.pawns[shooter.id].remaining_stamina, 1)

func test_choose_wolf_step_returns_valid_or_skip() -> void:
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_1
	var state := GameState.new()
	state.doctrines[Constants.PLAYER_1] = Constants.Doctrine.WOLF
	var wolf: Pawn = state._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 5))
	var card := Card.new(state.next_card_id(), Constants.PLAYER_1, 1, 3, 2, 2)
	state.all_cards[card.id] = card
	wolf.link_card(card)
	state.pending_wolf_step_pawn = wolf.id
	var choice: Dictionary = ai.choose_wolf_step(state)
	if choice.has("target"):
		var target: Vector2i = choice.target
		var dist: int = absi(target.x - 5) + absi(target.y - 5)
		assert_eq(dist, 1)
		assert_true(state.is_tile_empty(target))
	else:
		assert_true(choice.is_empty())


# =========================================================================
# C15-buit in de bot (7 september 2026): de veroverde buit telt in de eval,
# een gekoppelde drager telt mee (4.3.2), de kill op een drager wint het van
# een gewone kill, en waar de eigen dragers staan is leerbaar.
# =========================================================================

## Campagne-regels met een lege reserve en een lege CP-pot, zodat elke
## verschuiving in de eval uit de buit komt en niet uit de startvoorraad.
func _buit_staat() -> GameState:
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {
		"pool_model": "punten", "pools": {"1": 0, "2": 0}, "cp_start": 0,
	}})
	s.doctrines[Constants.PLAYER_1] = Constants.Doctrine.MENS
	s.doctrines[Constants.PLAYER_2] = Constants.Doctrine.MENS
	s.init_pools()
	s.phase = Phase.Type.ACTION
	s.current_player = Constants.PLAYER_1
	return s


func _actieve_pion(s: GameState, owner: int, pos: Vector2i, hp: int, spd: int, atk: int) -> Pawn:
	var p: Pawn = s._spawn_pawn(owner, pos, Constants.UnitType.INFANTRY)
	var c := Card.new(s.next_card_id(), owner, 0, hp, spd, atk)
	s.all_cards[c.id] = c
	p.link_card(c)
	return p


## De eval wordt naar int afgekapt; een verschil van 1 is afkapruis.
func _assert_ongeveer(werkelijk: int, verwacht: int, boodschap: String) -> void:
	assert_true(absi(werkelijk - verwacht) <= 1, "%s: %d, verwacht %d" % [boodschap, werkelijk, verwacht])


func test_c15_eval_waardeert_veroverde_buit() -> void:
	# Tot 7 september kwam een veroverd vaandel wel in de staat (reserve +2)
	# maar niet in de score: de bot zag alleen een dode pion.
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_1
	var s := _buit_staat()
	_actieve_pion(s, Constants.PLAYER_1, Vector2i(5, 8), 2, 2, 2)
	_actieve_pion(s, Constants.PLAYER_2, Vector2i(5, 2), 2, 2, 2)
	var voor: int = ai.evaluate(s, Constants.PLAYER_1)
	s.pool_bijschrijven(Constants.PLAYER_1, 2)   # een vaandel geboekt
	var na_vaandel: int = ai.evaluate(s, Constants.PLAYER_1)
	_assert_ongeveer(na_vaandel - voor, int(2.0 * float(ai.weights.reserve_pt)), "2 punten reserve = 2 x reserve_pt")
	s.cp[Constants.PLAYER_1] = int(s.cp.get(Constants.PLAYER_1, 0)) + 2   # een tamboer geboekt
	var na_tamboer: int = ai.evaluate(s, Constants.PLAYER_1)
	_assert_ongeveer(na_tamboer - na_vaandel, int(2.0 * float(ai.weights.reserve_cp)), "2 CP = 2 x reserve_cp")
	# Zero-sum: dezelfde buit bij de vijand kost mij evenveel.
	s.pool_bijschrijven(Constants.PLAYER_2, 2)
	_assert_ongeveer(ai.evaluate(s, Constants.PLAYER_1), na_tamboer - int(2.0 * float(ai.weights.reserve_pt)), "vijandelijke reserve telt negatief")
	# Zonder campagne-blok bestaat er geen reserve: geen term, geen crash.
	var kaal := GameState.new()
	kaal.doctrines[Constants.PLAYER_1] = Constants.Doctrine.MENS
	kaal.doctrines[Constants.PLAYER_2] = Constants.Doctrine.MENS
	_actieve_pion(kaal, Constants.PLAYER_1, Vector2i(5, 8), 2, 2, 2)
	_actieve_pion(kaal, Constants.PLAYER_2, Vector2i(5, 2), 2, 2, 2)
	assert_eq(ai.evaluate(kaal, Constants.PLAYER_1), voor, "4.1: zelfde score als de lege campagne-staat")


func test_c15_eval_telt_gekoppelde_drager_als_buit() -> void:
	# 4.3.2: een drager levert buit op, gekoppeld of niet; de jacht-term hoort
	# hem dus ook gekoppeld te zien. Tot 7 september telde alleen een
	# ongekoppeld standbeeld mee.
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_1
	var s := _buit_staat()
	var jager: Pawn = _actieve_pion(s, Constants.PLAYER_1, Vector2i(5, 5), 3, 2, 3)
	var drager: Pawn = _actieve_pion(s, Constants.PLAYER_2, Vector2i(5, 4), 1, 2, 1)
	drager.rol = "flag"
	ai.weights.buit_jacht = 0.0
	var zonder: int = ai.evaluate(s, Constants.PLAYER_1)
	ai.weights.buit_jacht = 100.0
	_assert_ongeveer(ai.evaluate(s, Constants.PLAYER_1) - zonder, 200, "gekoppelde vaandeldrager binnen bereik = 2 punten x buit_jacht")
	# Buiten bereik (HP boven mijn attack): geen jacht-term.
	drager.current_hp = 5
	drager.max_hp = 5
	ai.weights.buit_jacht = 0.0
	var zonder2: int = ai.evaluate(s, Constants.PLAYER_1)
	ai.weights.buit_jacht = 100.0
	assert_eq(ai.evaluate(s, Constants.PLAYER_1), zonder2, "niet pakbaar = geen jacht")
	# Mijn eigen gekoppelde tamboer naast een vijand die hem kan doden: hoede.
	jager.rol = "drum"
	drager.attack_value = 3
	ai.weights.buit_hoede = 0.0
	var veilig: int = ai.evaluate(s, Constants.PLAYER_1)
	ai.weights.buit_hoede = 100.0
	_assert_ongeveer(veilig - ai.evaluate(s, Constants.PLAYER_1), 100, "eigen tamboer in gevaar = 1 punt x buit_hoede")


func test_c15_greedy_slaat_de_drager_boven_een_gewone_soldaat() -> void:
	# Twee standbeelden naast mijn jager: links een vaandeldrager, rechts een
	# gewone soldaat. Tot 7 september koos de eval de GEWONE soldaat: de kill
	# op de drager liet zijn jacht-term wegvallen en de 2 punten telden niet.
	var ai = preload("res://scripts/ai/AIMedium.gd").new()
	ai.player_id = Constants.PLAYER_1
	var s := _buit_staat()
	var jager: Pawn = _actieve_pion(s, Constants.PLAYER_1, Vector2i(5, 5), 3, 2, 3)
	var drager: Pawn = s._spawn_pawn(Constants.PLAYER_2, Vector2i(4, 5), Constants.UnitType.INFANTRY)
	drager.rol = "flag"
	var gewoon: Pawn = s._spawn_pawn(Constants.PLAYER_2, Vector2i(6, 5), Constants.UnitType.INFANTRY)
	# Eigen standbeelden voor en achter de jager: dan blijven alleen de twee
	# kills over als zet. En genoeg eigen pionnen om de wanhoop-modus (minder
	# dan 7) buiten de deur te houden, want die rent liever naar de haven.
	s._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 4), Constants.UnitType.INFANTRY)
	s._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 6), Constants.UnitType.INFANTRY)
	for x in 5:
		s._spawn_pawn(Constants.PLAYER_1, Vector2i(x, 10), Constants.UnitType.INFANTRY)
	assert_eq(ai.enumerate_actions(s, Constants.PLAYER_1).size(), 2, "precies de twee kills als keuze")
	var keuze: Dictionary = ai.choose_action(s)
	assert_eq(String(keuze.get("type", "")), "attack", "de bot slaat")
	assert_eq(int(keuze.get("defender_id", -1)), drager.id, "en kiest de drager (2 punten reserve)")
	assert_true(jager.is_active and not drager.is_eliminated, "het origineel is niet aangeraakt")
	# Gespiegeld (de drager rechts): dan mag het niet aan de volgorde liggen.
	drager.rol = ""
	gewoon.rol = "flag"
	var keuze2: Dictionary = ai.choose_action(s)
	assert_eq(int(keuze2.get("defender_id", -1)), gewoon.id, "spiegel: weer de drager")


func test_c15_dragers_staan_leerbaar_achteraan() -> void:
	# Default drager_front -1: de dragers gaan naar de achterste rij, en niet
	# naar de beste infanterievakken (met inf_front 0.6 was dat de voorste
	# rij). drager_front hoog: vooraan. Altijd een geldige opstelling met
	# precies vaandels_max en tamboers_max dragers.
	var ai = preload("res://scripts/ai/AIController.gd").new()
	for pid in [Constants.PLAYER_1, Constants.PLAYER_2]:
		ai.player_id = pid
		var rows: Array = Constants.get_start_rows_for_player(pid)
		var s := GameState.new()
		s.rules = RulesConfig.from_dict({"campaign": {}})
		s.doctrines[pid] = Constants.Doctrine.MENS
		var pl: Array = ai.choose_placement(s)
		assert_true(s.is_valid_placement(pid, pl), "geldige opstelling met dragers (speler %d)" % pid)
		var rollen: Dictionary = {"flag": 0, "drum": 0}
		for e in pl:
			var rol := String(e.get("rol", ""))
			if rol == "":
				continue
			rollen[rol] += 1
			assert_eq(int(e.pos.y), int(rows[0]), "default: drager op de achterste rij (speler %d)" % pid)
		assert_eq(int(rollen.flag), 2, "twee vaandels")
		assert_eq(int(rollen.drum), 2, "twee tamboers")
	ai.player_id = Constants.PLAYER_1
	ai.weights.drager_front = 5.0
	var s2 := GameState.new()
	s2.rules = RulesConfig.from_dict({"campaign": {}})
	s2.doctrines[Constants.PLAYER_1] = Constants.Doctrine.MENS
	var front: int = Constants.get_start_rows_for_player(Constants.PLAYER_1)[1]
	var vooraan: int = 0
	for e in ai.choose_placement(s2):
		if String(e.get("rol", "")) != "":
			vooraan += 1
			assert_eq(int(e.pos.y), front, "geleerd vooraan: drager op de voorste rij")
	assert_eq(vooraan, 4)
	# Zonder campagne-blok bestaan rollen niet.
	var s41 := GameState.new()
	s41.doctrines[Constants.PLAYER_1] = Constants.Doctrine.MENS
	for e in ai.choose_placement(s41):
		assert_false(e.has("rol"), "4.1: geen rollen")


func test_c15_hard_zet_de_dragerkill_vooraan() -> void:
	# De beam van Hard/Ultra snoeit op _quick; een drager-kill moet daar voor
	# een gewone kill staan, anders komt de eval er nooit aan toe.
	var ai = preload("res://scripts/ai/AIHard.gd").new()
	ai.player_id = Constants.PLAYER_1
	var s := _buit_staat()
	var jager: Pawn = _actieve_pion(s, Constants.PLAYER_1, Vector2i(5, 5), 3, 2, 3)
	var drager: Pawn = s._spawn_pawn(Constants.PLAYER_2, Vector2i(4, 5), Constants.UnitType.INFANTRY)
	drager.rol = "drum"
	var gewoon: Pawn = s._spawn_pawn(Constants.PLAYER_2, Vector2i(6, 5), Constants.UnitType.INFANTRY)
	var op_drager: Dictionary = {"type": "attack", "attacker_id": jager.id, "defender_id": drager.id}
	var op_gewoon: Dictionary = {"type": "attack", "attacker_id": jager.id, "defender_id": gewoon.id}
	assert_true(ai._quick(s, Constants.PLAYER_1, op_drager) > ai._quick(s, Constants.PLAYER_1, op_gewoon),
		"de drager-kill sorteert voor de gewone kill")
