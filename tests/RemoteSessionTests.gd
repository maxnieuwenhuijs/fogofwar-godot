extends TestSuite

# F4.3f — RemoteSession op een LoopbackTransport: het actieprotocol van
# docs/protocol.md in-proces, alles door JSON-tekst. Bewijst zonder server:
#   (1) contract: dezelfde gescripte partij via GameSession en via twee
#       RemoteSessions geeft dezelfde signal-reeks (naam + argumenten) en
#       dezelfde staat op de gesloten lijst van fog-afwijkingen;
#   (2) lek-canary: de client-staat kent vóór de reveal geen vijandelijke
#       kaarten, in PLACEMENT geen vijandelijke pionnen, nooit vijandelijke
#       saldi;
#   (3) 409-rebase: een verouderde client haalt in en dient één keer opnieuw in;
#   (4) idem-herhaling maakt geen tweede rij;
#   (5) 422 en de lokale voorcheck: error_occurred, staat ongewijzigd;
#   (6) typed signals: ints blijven ints na het JSON-pad;
#   (7) einde-route: na 'klaar' geeft een 409 de winnaar via de status.


func _class_name() -> String:
	return "RemoteSessionTests"


const TOEGESTAAN_AFWIJKEND: Array[String] = [
	"pawns", "all_cards", "cards_defined", "pools", "cp", "cp_bets", "cp_bet_done",
	"spawn_totaal", "spawn_commits", "doctrine_commits", "rules", "next_pawn_id", "next_card_id",
]


func _regels() -> RulesConfig:
	return RulesConfig.load_from_file("res://arena/arena_configs/rules_v42_campaign.json")


func _json(v) -> String:
	return JSON.stringify(MatchLog._jsonify(v))


## Recorder: hangt aan alle signals van een sessie (behalve state_updated,
## dat online per rij extra vuurt) en legt naam + argumenten vast.
class Recorder:
	var reeks: Array = []
	var typen: Dictionary = {}

	func hang_aan(s: SessionInterface) -> void:
		s.phase_changed.connect(func(a, b): _leg("phase_changed", [a, b]))
		s.placement_submitted.connect(func(a): _leg("placement_submitted", [a]))
		s.cards_revealed_event.connect(func(a, b, c): _leg("cards_revealed_event", [a, b, c]))
		s.turn_changed.connect(func(a): _leg("turn_changed", [a]))
		s.action_performed.connect(func(a, b): _leg("action_performed", [a, b]))
		s.wolf_step_pending.connect(func(a): _leg("wolf_step_pending", [a]))
		s.cycle_started.connect(func(a): _leg("cycle_started", [a]))
		s.game_over.connect(func(a): _leg("game_over", [a]))
		s.doctrines_revealed.connect(func(a): _leg("doctrines_revealed", [a]))
		s.error_occurred.connect(func(a, b): _leg("error_occurred", [a, b]))

	func _leg(naam: String, args: Array) -> void:
		reeks.append([naam, MatchLog._jsonify(args)])
		for a in args:
			typen[naam + ":" + type_string(typeof(a))] = true


## Eén beslisser voor beide werelden: werkt alleen op `sess.state` en de
## legale acties daarvan, dus identieke keuzes zodra de staten gelijk zijn.
func _speel_stap(sess: SessionInterface, p: int, rng: SeededRng) -> bool:
	var st: GameState = sess.state
	var legal: Array = Validator.legal_actions(st, p)
	if legal.is_empty():
		return false
	var a: Dictionary
	if Phase.is_define(st.phase):
		# Eigen kaarten: de eerste geldige definitie (deterministisch).
		a = legal[legal.size() - 1]
		if String(a.type) != Actions.DEFINE_CARDS:
			for x in legal:
				if String(x.type) == Actions.DEFINE_CARDS:
					a = x
					break
		if String(a.type) != Actions.DEFINE_CARDS:
			return false
	else:
		a = legal[rng.randi_range(0, legal.size() - 1)]
	match String(a.type):
		Actions.CHOOSE_DOCTRINE: return sess.submit_choose_doctrine(p, int(a.doctrine))
		Actions.PLACE: return sess.submit_placement(p, a.placements)
		Actions.DEFINE_CARDS: return sess.submit_define_cards(p, a.cards)
		Actions.ACK_REVEAL: return sess.submit_ack_reveal(p)
		Actions.LINK: return sess.submit_link(p, int(a.card_id), int(a.pawn_id))
		Actions.MOVE: return sess.submit_move(p, int(a.pawn_id), a.target)
		Actions.MELEE: return sess.submit_attack(p, int(a.attacker_id), int(a.defender_id))
		Actions.SHOOT: return sess.submit_shot(p, int(a.shooter_id), int(a.target_id))
		Actions.CHARGE: return sess.submit_charge(p, int(a.pawn_id), a.move_target, int(a.defender_id))
		Actions.WOLF_STEP: return sess.submit_wolf_step(p, a.target)
		Actions.SKIP_WOLF_STEP: return sess.skip_wolf_step(p)
		Actions.SPAWN: return sess.submit_spawn(p, a.spawns)
		Actions.CANNON_ACT:
			if String(a.sub) == "roll":
				return sess.submit_cannon_roll(p, int(a.pawn_id), a.target)
			return sess.submit_cannon_shoot(p, int(a.pawn_id), int(a.target_id))
		Actions.BET_CP:
			return false  # online bestaat de losse inzet niet; de define zonder inzet volstaat
	return false


func test_contract_dezelfde_partij_offline_en_via_loopback() -> void:
	# Offline: de autoload GameSession vanaf PRE_GAME.
	var off_rec := Recorder.new()
	GameSession.start_new_game_pre_game(_regels())
	off_rec.hang_aan(GameSession)
	var rng_off := SeededRng.new(4711)
	var stappen_off := 0
	for i in 400:
		if GameSession.state.phase == Phase.Type.GAME_OVER:
			break
		var gedaan := false
		for p in [GameSession.state.current_player, Constants.opponent(GameSession.state.current_player)]:
			if _speel_stap(GameSession, p, rng_off):
				gedaan = true
				stappen_off += 1
				break
		if not gedaan:
			break
	# Online: twee RemoteSessions op één loopback, zelfde beslisser, zelfde seed.
	var lb := LoopbackTransport.new(_regels())
	var s1 := RemoteSession.new(lb.voor_seat(1), 1)
	var s2 := RemoteSession.new(lb.voor_seat(2), 2)
	var on_rec := Recorder.new()
	on_rec.hang_aan(s1)
	s1.start()
	s2.start()
	var rng_on := SeededRng.new(4711)
	var stappen_on := 0
	for i in 400:
		if lb.state.phase == Phase.Type.GAME_OVER:
			break
		var gedaan := false
		for p in [lb.state.current_player, Constants.opponent(lb.state.current_player)]:
			var sess: SessionInterface = s1 if p == 1 else s2
			if _speel_stap(sess, p, rng_on):
				gedaan = true
				stappen_on += 1
				break
		if not gedaan:
			break
	assert_true(stappen_off >= 60, "offline partij kwam op gang (%d stappen)" % stappen_off)
	assert_eq(stappen_on, stappen_off, "evenveel stappen online als offline")
	# Zelfde signal-reeks (state_updated uitgezonderd), incl. argumenten.
	assert_eq(on_rec.reeks.size(), off_rec.reeks.size(), "evenveel signals")
	var eerste_verschil := -1
	for i in mini(on_rec.reeks.size(), off_rec.reeks.size()):
		if _json(on_rec.reeks[i]) != _json(off_rec.reeks[i]):
			eerste_verschil = i
			break
	assert_eq(eerste_verschil, -1, "signal-reeks wijkt af bij %d: %s vs %s" % [eerste_verschil,
		_json(on_rec.reeks[eerste_verschil]) if eerste_verschil >= 0 else "", _json(off_rec.reeks[eerste_verschil]) if eerste_verschil >= 0 else ""])
	assert_false(on_rec.typen.keys().any(func(k): return String(k).begins_with("error_occurred")), "geen fouten online")
	# Zelfde staat op de gesloten lijst, voor de server (loopback) en beide clients.
	var d_off: Dictionary = Serializer.state_to_dict(GameSession.state)
	var d_srv: Dictionary = Serializer.state_to_dict(lb.state)
	assert_eq(_json(d_srv), _json(d_off), "de loopback-server heeft exact de offline staat")
	for sess in [s1, s2]:
		var d_cl: Dictionary = Serializer.state_to_dict(sess.state)
		for key in d_off:
			if TOEGESTAAN_AFWIJKEND.has(String(key)):
				continue
			assert_eq(_json(d_cl.get(key, null)), _json(d_off[key]), "client seat %d: sleutel %s" % [sess.seat, key])
	assert_eq(s1.seq, lb.seq, "client 1 loopt bij")
	assert_eq(s2.seq, lb.seq, "client 2 loopt bij")
	assert_true(Phase.is_define(lb.state.phase) or Phase.is_reveal(lb.state.phase) or Phase.is_linking(lb.state.phase)
		or lb.state.phase == Phase.Type.ACTION or lb.state.phase == Phase.Type.CYCLE_SPAWN
		or lb.state.phase == Phase.Type.GAME_OVER, "de partij kwam voorbij de opstelling")


func test_lek_canary_client_staat() -> void:
	var lb := LoopbackTransport.new(_regels())
	var s1 := RemoteSession.new(lb.voor_seat(1), 1)
	var s2 := RemoteSession.new(lb.voor_seat(2), 2)
	s1.start()
	s2.start()
	assert_true(s1.submit_choose_doctrine(1, Constants.Doctrine.MUIS))
	assert_false(s1.state.doctrine_commits.has(2), "keuze van de ander blind")
	assert_true(s2.submit_choose_doctrine(2, Constants.Doctrine.VOS))
	assert_eq(s1.state.phase, Phase.Type.PLACEMENT)
	assert_true(s1.submit_default_placement(1))
	# Blind opstellen: de ander bestaat nog niet voor mij, en mijn pionnen niet voor hem.
	for pawn in s2.state.pawns.values():
		assert_true(pawn.owner_id == 2, "seat 2 ziet in PLACEMENT geen pionnen van seat 1")
	assert_true(s2.submit_default_placement(2))
	assert_true(Phase.is_define(s1.state.phase))
	assert_eq(s1.state.pawns.size(), lb.state.pawns.size(), "na de opstelling ziet iedereen beide legers")
	# Vijandelijke saldi zijn er niet; eigen wel.
	assert_true(s1.state.cp.has(1))
	assert_false(s1.state.cp.has(2), "vijandelijk CP-saldo blijft weg")
	assert_false(s1.state.pools.has(2), "vijandelijke pool blijft weg")
	# Definities blijven blind tot de reveal.
	var kaarten1: Array = []
	for a in Validator.legal_actions(lb.state, 1):
		if String(a.type) == Actions.DEFINE_CARDS:
			kaarten1 = a.cards
			break
	assert_true(s1.submit_define_cards(1, kaarten1))
	assert_true(s2.state.cards_defined.get(1, []).is_empty(), "seat 2 ziet de definitie van seat 1 niet")
	assert_true(bool(s2.tegenstander_status().enemy_has_defined), "maar wel DAT hij definieerde")
	assert_eq(s2.state.all_cards.size(), 0, "geen enkele vijandelijke kaart vóór de reveal")


func test_409_rebase_verouderde_client() -> void:
	var lb := LoopbackTransport.new(_regels())
	var s1 := RemoteSession.new(lb.voor_seat(1), 1)
	var s2 := RemoteSession.new(lb.voor_seat(2), 2)
	s1.start()
	s2.start()
	# Seat 1 hoort even niets meer (verbinding weg): de push wordt onderdrukt.
	var e1: LoopbackTransport.Eindpunt = lb.voor_seat(1)
	e1.stil = true
	assert_true(s2.submit_choose_doctrine(2, Constants.Doctrine.WOLF))
	assert_eq(s1.seq, 0, "seat 1 miste de rij")
	assert_eq(lb.seq, 1)
	e1.stil = false
	var fouten: Array = []
	s1.error_occurred.connect(func(_p, m): fouten.append(m))
	# Dient in met de oude seq: 409 met inhaal, rebase, één herindiening.
	assert_true(s1.submit_choose_doctrine(1, Constants.Doctrine.MUIS))
	assert_eq(lb.seq, 2, "precies één rij erbij (geen dubbele indiening)")
	assert_eq(s1.seq, 2, "seat 1 is bijgelopen")
	assert_eq(fouten.size(), 0, "geen foutmelding: de rebase slaagde stil (%s)" % str(fouten))
	assert_eq(s1.state.phase, Phase.Type.PLACEMENT, "beide keuzes binnen: opstelfase")
	assert_eq(lb.rijen.size(), 2)


func test_idem_herhaling_maakt_geen_rij() -> void:
	var lb := LoopbackTransport.new(_regels())
	var t1: Transport = lb.voor_seat(1)
	var idem := LoopbackTransport._uuid()
	var actie: Dictionary = Actions.to_dict(Actions.make_choose_doctrine(Constants.Doctrine.BEER))
	var antwoorden: Array = []
	t1.acties(0, actie, idem, func(a): antwoorden.append(a))
	t1.acties(0, actie, idem, func(a): antwoorden.append(a))
	assert_eq(antwoorden.size(), 2)
	assert_eq(int(antwoorden[0].code), 200)
	assert_false(bool(antwoorden[0].herhaald))
	assert_eq(int(antwoorden[1].code), 200)
	assert_true(bool(antwoorden[1].herhaald), "tweede keer: het oorspronkelijke antwoord")
	assert_eq(lb.seq, 1, "één rij")
	assert_eq(int(antwoorden[1].events[0].seq), 1)


func test_422_en_lokale_voorcheck() -> void:
	var lb := LoopbackTransport.new(_regels())
	var s1 := RemoteSession.new(lb.voor_seat(1), 1)
	s1.start()
	var fouten: Array = []
	s1.error_occurred.connect(func(_p, m): fouten.append(m))
	# Lokale voorcheck: resign in PRE_GAME is illegaal, gaat niet eens de deur uit.
	assert_false(s1.submit_resign(1))
	assert_eq(fouten.size(), 1)
	assert_eq(lb.seq, 0, "niets verstuurd")
	# Server-422 (de server is de waarheid): een verkeerd gevormde keuze langs de voorcheck.
	var antwoorden: Array = []
	lb.voor_seat(1).acties(0, {"type": "choose_doctrine", "doctrine": 99}, LoopbackTransport._uuid(),
		func(a): antwoorden.append(a))
	assert_eq(int(antwoorden[0].code), 422)
	assert_eq(lb.seq, 0, "staat ongewijzigd")
	assert_eq(s1.state.phase, Phase.Type.PRE_GAME)
	# Namens de andere stoel: geweigerd voordat er iets verstuurd wordt.
	assert_false(s1.submit_choose_doctrine(2, Constants.Doctrine.MUIS))
	assert_eq(lb.seq, 0)


func test_typed_signals_na_json() -> void:
	var lb := LoopbackTransport.new(_regels())
	var s1 := RemoteSession.new(lb.voor_seat(1), 1)
	var s2 := RemoteSession.new(lb.voor_seat(2), 2)
	s1.start()
	s2.start()
	var rec := Recorder.new()
	rec.hang_aan(s1)
	assert_true(s1.submit_choose_doctrine(1, Constants.Doctrine.MUIS))
	assert_true(s2.submit_choose_doctrine(2, Constants.Doctrine.WOLF))
	assert_true(s1.submit_default_placement(1))
	assert_true(s2.submit_default_placement(2))
	assert_true(rec.typen.has("phase_changed:int"), "phase_changed kreeg ints (%s)" % str(rec.typen.keys()))
	assert_true(rec.typen.has("placement_submitted:int"))
	assert_true(rec.typen.has("cycle_started:int"))
	assert_false(rec.typen.keys().any(func(k): return String(k).ends_with(":float")), "nergens een float: %s" % str(rec.typen.keys()))
	# En de view kwam echt door JSON: sleutels zijn strings, het transport gaf floats.
	assert_true(s1.view.pawns.keys()[0] is String)


func test_einde_via_status_na_409() -> void:
	var lb := LoopbackTransport.new(_regels())
	var s1 := RemoteSession.new(lb.voor_seat(1), 1)
	var s2 := RemoteSession.new(lb.voor_seat(2), 2)
	s1.start()
	s2.start()
	assert_true(s1.submit_choose_doctrine(1, Constants.Doctrine.MUIS))
	assert_true(s2.submit_choose_doctrine(2, Constants.Doctrine.WOLF))
	var e1: LoopbackTransport.Eindpunt = lb.voor_seat(1)
	e1.stil = true  # seat 1 is even weg
	var winnaars: Array = []
	s1.game_over.connect(func(w): winnaars.append(w))
	assert_true(s2.submit_resign(2))
	assert_eq(lb.status_tekst, "klaar")
	assert_eq(winnaars.size(), 0, "seat 1 weet nog van niets")
	e1.stil = false
	# Seat 1 doet iets met een oude seq: 409 'afgelopen' → status → game_over.
	assert_true(s1.submit_default_placement(1))
	assert_eq(winnaars, [1], "de status vertelt seat 1 dat hij won")
	assert_eq(s1.state.phase, Phase.Type.GAME_OVER, "en de view is ververst")


func test_bot_op_de_andere_stoel() -> void:
	var lb := LoopbackTransport.new(_regels())
	lb.zet_bot(2, AgentL1.new(), 99)
	var s1 := RemoteSession.new(lb.voor_seat(1), 1)
	s1.start()
	lb.start()
	assert_true(bool(s1.tegenstander_status().enemy_has_chosen), "de bot koos meteen")
	assert_true(s1.submit_choose_doctrine(1, Constants.Doctrine.LEEUW))
	assert_eq(s1.state.phase, Phase.Type.PLACEMENT)
	assert_true(bool(lb.state.placements_done.get(2, false)), "de bot stelde zich meteen op")
	assert_true(s1.submit_default_placement(1))
	assert_true(Phase.is_define(s1.state.phase))
	assert_true(bool(s1.tegenstander_status().enemy_has_defined), "en definieerde")


## Transport dat antwoorden vasthoudt tot lever(): zo speelt de test het
## asynchrone geval na (HTTP-antwoord komt later dan de WebSocket-push, of
## helemaal door elkaar), precies wat stap h/j gaan brengen.
class VertraagdTransport extends Transport:
	var binnen: Transport
	var wachtend: Array = []

	func _init(t: Transport) -> void:
		binnen = t
		binnen.rijen_binnen.connect(func(r: Array) -> void: rijen_binnen.emit(r))

	func status(klaar: Callable) -> void:
		binnen.status(func(a: Dictionary) -> void: wachtend.append([klaar, a]))

	func view(klaar: Callable) -> void:
		binnen.view(func(a: Dictionary) -> void: wachtend.append([klaar, a]))

	func acties(seq_expected: int, action: Dictionary, idem_key: String, klaar: Callable) -> void:
		binnen.acties(seq_expected, action, idem_key, func(a: Dictionary) -> void: wachtend.append([klaar, a]))

	func events(after: int, klaar: Callable) -> void:
		binnen.events(after, func(a: Dictionary) -> void: wachtend.append([klaar, a]))

	## Levert alleen wat NU klaarstaat; wat tijdens de levering nieuw wordt
	## aangevraagd wacht op de volgende lever(). Zo stapt een test door een
	## keten heen zoals een echt netwerk dat doet: antwoord voor antwoord.
	func lever() -> int:
		var nu: Array = wachtend.duplicate()
		wachtend.clear()
		for p in nu:
			(p[0] as Callable).call(p[1])
		return nu.size()


func test_asynchroon_transport_rij_wacht_op_zijn_view() -> void:
	var lb := LoopbackTransport.new(_regels())
	var vt := VertraagdTransport.new(lb.voor_seat(1))
	var s1 := RemoteSession.new(vt, 1)
	var s2 := RemoteSession.new(lb.voor_seat(2), 2)
	var fouten: Array = []
	s1.error_occurred.connect(func(_p, m): fouten.append(m))
	s1.start()
	assert_true(s1.state == null, "nog niets: status en view zijn onderweg")
	assert_eq(vt.lever(), 2, "status en view komen aan")
	assert_true(s1.state != null)
	s2.start()
	var rec := Recorder.new()
	rec.hang_aan(s1)
	# De ander kiest: de push komt meteen, maar de bijbehorende view hangt.
	assert_true(s2.submit_choose_doctrine(2, Constants.Doctrine.WOLF))
	assert_eq(s1.seq, 0, "rij 1 wacht op zijn view")
	assert_false(bool(s1.tegenstander_status().enemy_has_chosen))
	assert_eq(vt.lever(), 1, "de view komt aan")
	assert_eq(s1.seq, 1, "en dan is rij 1 afgespeeld")
	assert_true(bool(s1.tegenstander_status().enemy_has_chosen))
	# Eigen actie: de push van rij 2 komt VOOR het 200-antwoord binnen.
	assert_true(s1.submit_choose_doctrine(1, Constants.Doctrine.MUIS))
	assert_eq(s1.seq, 1, "rij 2 wacht op zijn view; het 200-antwoord hangt ook nog")
	assert_eq(vt.lever(), 2, "view en 200-antwoord komen aan")
	assert_eq(s1.seq, 2)
	assert_eq(s1.state.phase, Phase.Type.PLACEMENT, "de staat is bij")
	var namen: Array = []
	for r in rec.reeks:
		namen.append(r[0])
	assert_true(namen.has("doctrines_revealed"), "signals kwamen na de view: %s" % str(namen))
	assert_true(namen.has("phase_changed"))
	assert_eq(fouten.size(), 0, str(fouten))
	# En een dubbele levering (WS én 200) blijft één keer afgespeeld.
	assert_eq(namen.count("doctrines_revealed"), 1)


func test_gat_wordt_ingehaald_via_events() -> void:
	var lb := LoopbackTransport.new(_regels())
	var s1 := RemoteSession.new(lb.voor_seat(1), 1)
	var s2 := RemoteSession.new(lb.voor_seat(2), 2)
	s1.start()
	s2.start()
	var fouten: Array = []
	s1.error_occurred.connect(func(_p, m): fouten.append(m))
	var rec := Recorder.new()
	rec.hang_aan(s1)
	assert_true(s1.submit_choose_doctrine(1, Constants.Doctrine.BEER))
	assert_eq(s1.seq, 1)
	var e1: LoopbackTransport.Eindpunt = lb.voor_seat(1)
	e1.stil = true
	assert_true(s2.submit_choose_doctrine(2, Constants.Doctrine.LEEUW))  # rij 2: gemist
	e1.stil = false
	assert_true(s2.submit_default_placement(2))  # rij 3: komt aan, met een gat
	assert_eq(s1.seq, 3, "het gat is via events(after) gedicht en alles is op volgorde afgespeeld")
	assert_eq(s1.state.phase, Phase.Type.PLACEMENT)
	assert_true(bool(s1.state.placements_done.get(2, false)))
	var namen: Array = []
	for r in rec.reeks:
		namen.append(r[0])
	assert_eq(namen.count("doctrines_revealed"), 1, "rij 2 is precies één keer afgespeeld")
	assert_eq(namen.count("placement_submitted"), 1)
	assert_eq(fouten.size(), 0, str(fouten))


func test_409_rebase_wacht_op_de_inhaal_bij_asynchroon_transport() -> void:
	# Twee clients dienen tegelijk hun blinde keuze in met seq 0. De tweede
	# krijgt 409 met een inhaal-rij, maar zijn view komt LATER binnen (HTTP).
	# De herindiening mag pas na die inhaal, anders gaat hij opnieuw met
	# seq 0 de deur uit en eindigt in "De situatie is veranderd".
	var lb := LoopbackTransport.new(_regels())
	var vt := VertraagdTransport.new(lb.voor_seat(2))
	var s1 := RemoteSession.new(lb.voor_seat(1), 1)
	var s2 := RemoteSession.new(vt, 2)
	s1.start()
	s2.start()
	vt.lever()
	var e2: LoopbackTransport.Eindpunt = lb.voor_seat(2)
	e2.stil = true  # s2 hoort niets van de rij van s1 (alleen de 409 vertelt het)
	var fouten: Array = []
	s2.error_occurred.connect(func(_p, m): fouten.append(m))
	assert_true(s1.submit_choose_doctrine(1, Constants.Doctrine.MUIS))
	assert_true(s2.submit_choose_doctrine(2, Constants.Doctrine.WOLF))  # seq 0 -> 409, antwoord hangt
	assert_eq(lb.seq, 1, "alleen de keuze van s1 staat er")
	assert_eq(vt.lever(), 1, "stap 1: de 409 komt binnen; de inhaal-rij wacht op zijn view")
	assert_eq(s2.seq, 0, "nog niets afgespeeld: de view is onderweg")
	assert_eq(lb.seq, 1, "en er is NIET blind opnieuw ingediend")
	assert_eq(vt.lever(), 1, "stap 2: de view komt aan")
	assert_eq(s2.seq, 1, "rij 1 afgespeeld")
	assert_eq(lb.seq, 2, "en daarna pas de herindiening, die slaagde")
	e2.stil = false
	assert_eq(vt.lever(), 1, "stap 3: het 200-antwoord op de herindiening")
	assert_eq(vt.lever(), 1, "stap 4: de view voor rij 2")
	assert_eq(s2.seq, 2, "s2 loopt bij")
	assert_eq(s2.state.phase, Phase.Type.PLACEMENT, "beide keuzes binnen")
	assert_eq(fouten.size(), 0, "geen 'situatie veranderd': %s" % str(fouten))
