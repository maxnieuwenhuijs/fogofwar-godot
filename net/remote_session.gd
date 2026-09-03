class_name RemoteSession
extends SessionInterface

## F4.3f — de online sessie: dezelfde signals en submits als GameSession,
## maar de acties gaan via een Transport naar de server en de staat komt
## terug als fog-view. game.gd merkt het verschil niet (F4.3b/c/e).
##
## Boekhouding: `seq` is de laatst verwerkte client-rij. Elke rij die
## binnenkomt (push, 200-antwoord, 409-inhaal, GET /events) gaat door
## dezelfde poort `_ontvang`: dedupe op seq, dan strikt op volgorde. Vóór het
## afspelen van een rij wordt de view opgehaald (staat vervangen,
## state_updated), daarna de events van die rij door de EventCodec naar de
## signals. Zo ziet game.gd eerst de nieuwe staat en dan wat er gebeurde,
## precies zoals offline (Reducer.apply muteert eerst, _relay_events daarna).
##
## Lek-invariant: hier draait NOOIT Reducer.apply. Alleen Validator, als
## voorcheck (snelle foutmelding, geen ronde naar de server voor iets dat
## toch 422 wordt). De server wint altijd.

var seat: int = 1
var seq: int = 0
var view: Dictionary = {}
var view_seq: int = -1
var transport: Transport = null
var namen: Dictionary = {}
var match_status: String = ""
var _wachtrij: Array = []
var _pomp_bezig: bool = false
var _view_onderweg: bool = false
var _inhaal_onderweg: bool = false
var _gestart: bool = false


func _init(t: Transport, s: int) -> void:
	transport = t
	seat = s
	transport.rijen_binnen.connect(_ontvang)


## Verbinden: status (namen, fase van de match) en de eerste view.
func start(klaar: Callable = Callable()) -> void:
	transport.status(func(st: Dictionary) -> void:
		if bool(st.get("ok", false)):
			match_status = String(st.get("status", ""))
			for x in st.get("seats", []):
				namen[int(x.seat)] = String(x.naam)
	)
	transport.view(func(a: Dictionary) -> void:
		if not bool(a.get("ok", false)):
			error_occurred.emit(seat, "Geen view: %s" % String(a.get("fout", "?")))
			if klaar.is_valid():
				klaar.call(false)
			return
		_neem_view(int(a.seq), a.view, true)
		_gestart = true
		state_updated.emit(state)
		if klaar.is_valid():
			klaar.call(true)
		_pomp()
	)


# --- Rijen -------------------------------------------------------------------

func _ontvang(rijen: Array) -> void:
	for r in rijen:
		var s: int = int(r.seq)
		if s <= seq:
			continue
		var dubbel := false
		for w in _wachtrij:
			if int(w.seq) == s:
				dubbel = true
				break
		if not dubbel:
			_wachtrij.append(r)
	_wachtrij.sort_custom(func(a, b) -> bool: return int(a.seq) < int(b.seq))
	if _gestart:
		_pomp()


## De pomp werkt ook met een ECHT asynchroon transport (HTTP/WS, stap h):
## een rij wordt pas afgespeeld als de view die erbij hoort binnen is, en
## een gat wordt pas gedicht als de inhaal-rijen er zijn. Met de loopback
## komt elk antwoord in dezelfde aanroep terug; dan loopt de lus gewoon
## door. Komt het later, dan roept de callback de pomp opnieuw aan.
func _pomp() -> void:
	if _pomp_bezig or _view_onderweg or _inhaal_onderweg:
		return
	_pomp_bezig = true
	while not _wachtrij.is_empty():
		var r: Dictionary = _wachtrij[0]
		var s: int = int(r.seq)
		if s <= seq:
			_wachtrij.pop_front()
			continue
		if s != seq + 1:
			# Gat: inhalen via de server; de rijen komen door _ontvang terug.
			_inhaal_onderweg = true
			transport.events(seq, _op_inhaal)
			if _inhaal_onderweg:
				break  # asynchroon: verder zodra de rijen er zijn
			continue
		if view_seq < s:
			_view_onderweg = true
			transport.view(_op_view)
			if _view_onderweg:
				break  # asynchroon: verder zodra de view er is
			continue
		_wachtrij.pop_front()
		var events: Array = EventCodec.events_van_json(r.get("payload", {}).get("events", []))
		seq = s
		_relay_events(events)
	_pomp_bezig = false


func _op_view(a: Dictionary) -> void:
	_view_onderweg = false
	if bool(a.get("ok", false)):
		_neem_view(int(a.seq), a.view)
		state_updated.emit(state)
	else:
		error_occurred.emit(seat, "Geen view: %s" % String(a.get("fout", "?")))
	if not _pomp_bezig:
		_pomp()


func _op_inhaal(a: Dictionary) -> void:
	_inhaal_onderweg = false
	if bool(a.get("ok", false)):
		_ontvang(a.get("events", []))
	elif not _pomp_bezig:
		_pomp()


func _ververs_view() -> void:
	if _view_onderweg:
		return
	_view_onderweg = true
	transport.view(_op_view)


## De view overnemen. Alleen bij de koude start (start()) telt de seq van de
## view als vertrekpunt: rijen tot daar zitten al in de view. Daarna blijft
## seq de laatst AFGESPEELDE rij, ook als de view al verder is: elke rij
## krijgt zo zijn signals, met een staat die minstens zo ver is.
func _neem_view(vseq: int, v: Dictionary, koude_start: bool = false) -> void:
	view = v
	view_seq = vseq
	state = ClientState.uit_view(v)
	if koude_start and vseq > seq:
		seq = vseq


# --- Versturen -----------------------------------------------------------------

func _verstuur(player_id: int, action: Dictionary) -> bool:
	if player_id != seat:
		push_error("RemoteSession: actie namens speler %d op stoel %d" % [player_id, seat])
		return false
	if state == null:
		error_occurred.emit(seat, "Nog niet verbonden")
		return false
	var legal: Dictionary = Validator.is_legal(state, action, seat)
	if not legal.legal:
		error_occurred.emit(seat, String(legal.reason))
		return false
	var idem: String = LoopbackTransport._uuid()
	var dict: Dictionary = Actions.to_dict(action)
	transport.acties(seq, dict, idem, func(a: Dictionary) -> void: _op_antwoord(a, action, dict, idem, 0))
	return true


func _op_antwoord(a: Dictionary, action: Dictionary, dict: Dictionary, idem: String, poging: int) -> void:
	var code: int = int(a.get("code", 500))
	match code:
		200:
			_ontvang(a.get("events", []))
		409:
			var fout := String(a.get("fout", ""))
			if fout.begins_with("De match is afgelopen"):
				_einde_via_status()
				return
			_ontvang(a.get("events", []))
			# Rebase: één herindiening als de actie op de nieuwe staat nog kan.
			if poging == 0 and state != null and Validator.is_legal(state, action, seat).legal:
				transport.acties(seq, dict, idem, func(b: Dictionary) -> void: _op_antwoord(b, action, dict, idem, 1))
			else:
				error_occurred.emit(seat, "De situatie is veranderd")
		422:
			error_occurred.emit(seat, String(a.get("fout", "Ongeldige actie")))
		_:
			error_occurred.emit(seat, "Verbinding: %s" % String(a.get("fout", "?")))


## De einde-route zonder rij: de status van de match zegt wie won.
func _einde_via_status() -> void:
	transport.status(func(st: Dictionary) -> void:
		if bool(st.get("ok", false)):
			match_status = String(st.get("status", ""))
			if match_status == "klaar":
				_ververs_view()
				game_over.emit(int(st.get("winnaar_seat", 0) if st.get("winnaar_seat") != null else 0))
	)


# --- De submit-set -----------------------------------------------------------

func submit_choose_doctrine(player_id: int, doctrine: int) -> bool:
	return _verstuur(player_id, Actions.make_choose_doctrine(doctrine))

func submit_placement(player_id: int, placements: Array) -> bool:
	return _verstuur(player_id, Actions.make_place(placements))

func submit_default_placement(player_id: int) -> bool:
	return submit_placement(player_id, state.default_placement(player_id))

func submit_define_cards(player_id: int, cards_data: Array, cp_bet: int = 0) -> bool:
	# Online reist de CP-inzet in de define mee (F4.2b): één rij, geen
	# verklappende losse inzet.
	return _verstuur(player_id, Actions.make_define_cards(cards_data, cp_bet))

func submit_ack_reveal(player_id: int) -> bool:
	return _verstuur(player_id, Actions.make_ack_reveal())

func submit_link(player_id: int, card_id: int, pawn_id: int) -> bool:
	return _verstuur(player_id, Actions.make_link(card_id, pawn_id))

func submit_move(player_id: int, pawn_id: int, target_pos: Vector2i) -> bool:
	return _verstuur(player_id, Actions.make_move(pawn_id, target_pos))

func submit_attack(player_id: int, attacker_id: int, defender_id: int) -> bool:
	return _verstuur(player_id, Actions.make_melee(attacker_id, defender_id))

func submit_shot(player_id: int, shooter_id: int, target_id: int) -> bool:
	return _verstuur(player_id, Actions.make_shoot(shooter_id, target_id))

func submit_charge(player_id: int, pawn_id: int, move_target: Vector2i, defender_id: int) -> bool:
	return _verstuur(player_id, Actions.make_charge(pawn_id, move_target, defender_id))

func submit_wolf_step(player_id: int, target: Vector2i) -> bool:
	return _verstuur(player_id, Actions.make_wolf_step(target))

func submit_resign(player_id: int) -> bool:
	return _verstuur(player_id, Actions.make_resign())

func submit_spawn(player_id: int, spawns: Array) -> bool:
	return _verstuur(player_id, Actions.make_spawn(spawns))

func submit_bet_cp(player_id: int, amount: int) -> bool:
	# Bewust geweigerd: een losse inzet is online een eigen rij en verraadt de
	# inzet (F4.2b). Gebruik submit_define_cards(..., cp_bet).
	push_error("RemoteSession: losse CP-inzet is online niet toegestaan; geef cp_bet mee aan submit_define_cards")
	error_occurred.emit(player_id, "CP-inzet gaat online samen met de definitie")
	return false

func submit_cannon_roll(player_id: int, pawn_id: int, target: Vector2i) -> bool:
	return _verstuur(player_id, Actions.make_cannon_roll(pawn_id, target))

func submit_cannon_shoot(player_id: int, pawn_id: int, target_id: int) -> bool:
	return _verstuur(player_id, Actions.make_cannon_shoot(pawn_id, target_id))

func submit_claim_timeout(player_id: int, _now_ms: int) -> bool:
	return _verstuur(player_id, Actions.make_claim_timeout())

func skip_wolf_step(player_id: int) -> bool:
	return _verstuur(player_id, Actions.make_skip_wolf_step())


# --- Haken ---------------------------------------------------------------------

func local_player_id() -> int:
	return seat

func klok() -> Dictionary:
	return {"deadline_ms": int(view.get("turn_deadline", 0)), "server_now_ms": -1}

func naam_van(player_id: int) -> String:
	return String(namen.get(player_id, ""))

func pion_gedekt(pawn_id: int) -> bool:
	return ClientState.pion_gedekt(view, pawn_id)

func tegenstander_status() -> Dictionary:
	return ClientState.tegenstander_status(view)

func is_online() -> bool:
	return true
