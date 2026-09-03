extends TestSuite

# F4.3d — de client bouwt uit zijn fog-view een speelbare staat, en dat
# DOOR JSON-TEKST (de echte netwerkroute), niet in-proces:
#   (1) in elke rustfase van echte partijen geeft Validator.legal_actions op de
#       herbouwde staat exact dezelfde lijst als op de volle staat, voor beide
#       kijkers, en bij een reveal wint dezelfde kant het initiatief;
#   (2) gesloten lijst: de herbouwde staat mag alleen afwijken op sleutels
#       die per definitie fog dragen; een nieuwe afwijking is een FAIL;
#   (3) PRE_GAME: na de eigen factiekeuze biedt de herbouwde staat die niet
#       opnieuw aan (anders 422 van de server);
#   (4) de codec: elk client-event overleeft JSON heen en terug met dezelfde
#       typen (int blijft int, Vector2i blijft Vector2i, bod blijft float);
#   (5) de regels overleven de '?'-redactie van het pool-blok.


func _class_name() -> String:
	return "ClientStateTests"


## Het echte spel: campagne-economie en de aangenomen facties.
func _regels() -> RulesConfig:
	return RulesConfig.load_from_file("res://arena/arena_configs/rules_v42_campaign.json")


func _rondreis(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d))


func _json(v) -> String:
	return JSON.stringify(MatchLog._jsonify(v))


## Sleutels van state_to_dict die per definitie mogen afwijken tussen de volle
## staat en de herbouwde staat van een kijker. Alles daarbuiten moet gelijk zijn.
const TOEGESTAAN_AFWIJKEND: Array[String] = [
	"pawns",            # geëlimineerde pionnen weg (view-dieet), gedekte stats geschat
	"all_cards",        # vijandelijke ongeonthulde en dode kaarten weg
	"cards_defined",    # vijandelijke definitie is blind
	"pools", "cp", "cp_bets", "cp_bet_done", "spawn_totaal",  # vijandelijke saldi zijn '?'
	"spawn_commits",    # vijandelijke inzet is blind
	"doctrine_commits", # vijandelijke keuze is blind
	"rules",            # campaign.pools is in de view geredigeerd
	"next_pawn_id", "next_card_id",  # afgeleid uit de hoogste zichtbare id
]


class Verzamelaar:
	var events: Array = []
	func before_action(_s: GameState, _p: int, _a: Dictionary) -> void:
		pass
	func after_action(_s: GameState, _p: int, _a: Dictionary, ev: Array) -> void:
		events.append_array(ev)


func _speel_en_check(seed_val: int, d1: int, d2: int, max_stappen: int) -> Dictionary:
	var runner := AgentRunner.new(AgentL1.new(), AgentL1.new(), d1, d2, seed_val, _regels())
	var verz := Verzamelaar.new()
	runner.metrics = verz
	var fouten: Array = []
	var stappen := 0
	var fasen: Dictionary = {}
	var reveals := 0
	while not runner.done and stappen < max_stappen:
		runner.step()
		stappen += 1
		var s: GameState = runner.state()
		if s.phase == Phase.Type.RESET:
			fouten.append("stap %d: RESET is nooit een ruststaat" % stappen)
			continue
		fasen[s.phase] = true
		for p in [Constants.PLAYER_1, Constants.PLAYER_2]:
			var view: Dictionary = _rondreis(View.for_player(s, p))
			var recon: GameState = ClientState.uit_view(view)
			# (1) dezelfde legale acties
			var a := _json(Validator.legal_actions(recon, p))
			var b := _json(Validator.legal_actions(s, p))
			if a != b and fouten.size() < 4:
				fouten.append("stap %d fase %s kijker %d: legal_actions wijkt af" % [
					stappen, Phase.to_string_phase(s.phase), p])
			if Phase.is_reveal(s.phase):
				reveals += 1
				if Rules.compute_initiative(recon).winner != Rules.compute_initiative(s).winner \
						and fouten.size() < 4:
					fouten.append("stap %d kijker %d: initiatief wijkt af op de herbouwde staat" % [stappen, p])
			# (2) gesloten lijst
			var da: Dictionary = Serializer.state_to_dict(recon)
			var db: Dictionary = Serializer.state_to_dict(s)
			for key in db:
				if TOEGESTAAN_AFWIJKEND.has(String(key)):
					continue
				if not da.has(key) or _json(da[key]) != _json(db[key]):
					if fouten.size() < 4:
						fouten.append("stap %d kijker %d: sleutel '%s' wijkt af buiten de gesloten lijst" % [stappen, p, key])
			for key in da:
				if not db.has(key) and fouten.size() < 4:
					fouten.append("stap %d kijker %d: herbouwde staat kent extra sleutel '%s'" % [stappen, p, key])
			# Pionnen die er zijn staan op de goede plek met de goede eigenaar.
			for id in recon.pawns:
				var pr: Pawn = recon.pawns[id]
				var ps: Pawn = s.pawns.get(id, null)
				if ps == null or ps.position != pr.position or ps.owner_id != pr.owner_id \
						or ps.unit_type != pr.unit_type or ps.is_active != pr.is_active:
					if fouten.size() < 4:
						fouten.append("stap %d kijker %d: pion %d wijkt af (positie/eigenaar/type/actief)" % [stappen, p, id])
			# (5) regels: campagne actief en dezelfde facties, ondanks pools = '?'
			if stappen == 1:
				if recon.rules.campaign_actief() != s.rules.campaign_actief():
					fouten.append("regels: campaign_actief wijkt af na de rondreis")
				if _json(recon.rules.to_dict().get("doctrines", {})) != _json(s.rules.to_dict().get("doctrines", {})):
					fouten.append("regels: doctrines-blok wijkt af na de rondreis")
	return {"fouten": fouten, "stappen": stappen, "fasen": fasen, "reveals": reveals,
		"events": verz.events, "klaar": runner.done}


func test_herbouwde_staat_geeft_dezelfde_legale_acties() -> void:
	# Twee partijen: een met Krokodil (sentinel doet mee), een zonder.
	var uit1: Dictionary = _speel_en_check(777, Constants.Doctrine.VOS, Constants.Doctrine.WOLF, 450)
	var uit2: Dictionary = _speel_en_check(4242, Constants.Doctrine.MUIS, Constants.Doctrine.BEER, 450)
	assert_eq((uit1.fouten as Array).size(), 0, "partij 1: %s" % str(uit1.fouten))
	assert_eq((uit2.fouten as Array).size(), 0, "partij 2: %s" % str(uit2.fouten))
	assert_true(int(uit1.stappen) + int(uit2.stappen) >= 600, "genoeg stappen gemeten")
	assert_true(int(uit1.reveals) + int(uit2.reveals) >= 3, "reveals gezien (initiatief-vergelijking)")
	var fasen: Dictionary = {}
	fasen.merge(uit1.fasen)
	fasen.merge(uit2.fasen)
	for f in [Phase.Type.SETUP_1_DEFINE, Phase.Type.SETUP_1_REVEAL, Phase.Type.SETUP_1_LINKING, Phase.Type.ACTION]:
		assert_true(fasen.has(f), "fase %s bezocht" % Phase.to_string_phase(f))
	assert_true(fasen.has(Phase.Type.CYCLE_SPAWN), "CYCLE_SPAWN bezocht (eigen spawn-commit)")


func test_pre_game_eigen_keuze_wordt_niet_opnieuw_aangeboden() -> void:
	var s := GameState.new()
	s.rules = _regels()
	assert_eq(s.phase, Phase.Type.PRE_GAME)
	assert_true(Reducer.apply(s, Actions.make_choose_doctrine(Constants.Doctrine.MUIS), 1).ok)
	var recon1: GameState = ClientState.uit_view(_rondreis(View.for_player(s, 1)))
	assert_eq(int(recon1.doctrine_commits.get(1, -1)), Constants.Doctrine.MUIS, "eigen commit teruggezet")
	assert_true(Validator.legal_actions(recon1, 1).is_empty(), "geen tweede CHOOSE_DOCTRINE voor wie al koos")
	var view2: Dictionary = _rondreis(View.for_player(s, 2))
	var recon2: GameState = ClientState.uit_view(view2)
	assert_false(recon2.doctrine_commits.has(1), "de keuze van de ander blijft blind")
	assert_eq(Validator.legal_actions(recon2, 2).size(), Validator.legal_actions(s, 2).size(),
		"de ander krijgt nog gewoon zijn keuzes")
	var status: Dictionary = ClientState.tegenstander_status(view2)
	assert_true(bool(status.enemy_has_chosen))
	assert_false(bool(status.enemy_has_defined))


func test_vier_publieke_sleutels_reizen_mee() -> void:
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"clock": {"bank_sec": 180, "increment_sec": 5}})
	s.doctrines[1] = Constants.Doctrine.MENS
	s.doctrines[2] = Constants.Doctrine.MENS
	s.phase = Phase.Type.ACTION
	s.last_initiative_winner = 2
	s.eind_reden = ""
	s.turn_deadline = 123456
	s.clocks = {1: {"bank_ms": 170000}, 2: {"bank_ms": 90000}}
	var view: Dictionary = _rondreis(View.for_player(s, 1))
	assert_eq(int(view.last_initiative_winner), 2)
	assert_eq(int(view.turn_deadline), 123456)
	assert_eq(int(view.clocks["2"].bank_ms), 90000, "de bank van de ander is publiek")
	var recon: GameState = ClientState.uit_view(view)
	assert_eq(recon.last_initiative_winner, 2)
	assert_eq(recon.turn_deadline, 123456)
	assert_eq(int(recon.clocks[1].bank_ms), 170000)
	assert_eq(int(recon.clocks[2].bank_ms), 90000)
	s.winner = 2
	s.eind_reden = "opgave"
	s.phase = Phase.Type.GAME_OVER
	var na: GameState = ClientState.uit_view(_rondreis(View.for_player(s, 1)))
	assert_eq(na.eind_reden, "opgave")
	assert_eq(na.winner, 2)


func _zelfde_typen(a, b, pad: String, fouten: Array) -> void:
	if a is Dictionary and b is Dictionary:
		for k in a:
			if not b.has(str(k)) and not b.has(k):
				fouten.append("%s: sleutel %s ontbreekt na de codec" % [pad, str(k)])
				continue
			_zelfde_typen(a[k], b[str(k)] if b.has(str(k)) else b[k], pad + "." + str(k), fouten)
		return
	if a is Array and b is Array:
		if a.size() != b.size():
			fouten.append("%s: lengte %d != %d" % [pad, a.size(), b.size()])
			return
		for i in a.size():
			_zelfde_typen(a[i], b[i], "%s[%d]" % [pad, i], fouten)
		return
	if typeof(a) != typeof(b):
		fouten.append("%s: type %s werd %s" % [pad, type_string(typeof(a)), type_string(typeof(b))])


func test_codec_canary_elk_client_event_overleeft_json_met_dezelfde_typen() -> void:
	var uit: Dictionary = _speel_en_check(31337, Constants.Doctrine.WOLF, Constants.Doctrine.VOS, 350)
	var client_events: Array = View.client_events(uit.events)
	assert_true(client_events.size() > 200, "genoeg events verzameld (%d)" % client_events.size())
	var typen: Dictionary = {}
	var fouten: Array = []
	for ev in client_events:
		typen[String(ev.type)] = true
		var orig = MatchLog._jsonify(ev)
		var terug = EventCodec.van_json(JSON.parse_string(JSON.stringify(orig)))
		if JSON.stringify(MatchLog._jsonify(terug)) != JSON.stringify(orig) and fouten.size() < 5:
			fouten.append("%s: inhoud wijkt af na de codec" % String(ev.type))
		_zelfde_typen(ev, terug, String(ev.type), fouten)
		if fouten.size() >= 5:
			break
	assert_eq(fouten.size(), 0, "codec-canary: %s" % str(fouten))
	# De canary is alleen iets waard als de dragende events erin zaten.
	for t in [Reducer.EV_ACTION, Reducer.EV_TURN, Reducer.EV_PHASE, Reducer.EV_CARDS_REVEALED,
			Reducer.EV_WOLF_PENDING, Reducer.EV_SPAWNS_REVEALED]:
		assert_true(typen.has(t), "event %s kwam voorbij" % t)
	# En de int-coercie zelf, expliciet: een signal met int-parameter zou een
	# float weigeren.
	var ev_turn = EventCodec.van_json(JSON.parse_string('{"type":"turn_changed","seq":3.0,"payload":{"player_id":2.0}}'))
	assert_true(ev_turn.payload.player_id is int, "player_id is weer een int")
	assert_true(ev_turn.seq is int)
	var ev_move = EventCodec.van_json(JSON.parse_string('{"type":"action_applied","payload":{"action":{"type":"move","from":[1.0,2.0],"target":[1.0,3.0]},"result":{"defender_pos":[5.0,5.0],"bid":1.0}}}'))
	assert_true(ev_move.payload.action.target is Vector2i, "target is weer een Vector2i")
	assert_eq(ev_move.payload.action.target, Vector2i(1, 3))
	assert_true(ev_move.payload.result.defender_pos is Vector2i)
	assert_true(ev_move.payload.result.bid is float, "het bod blijft een float, ook als het heel is")
