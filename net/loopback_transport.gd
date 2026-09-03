class_name LoopbackTransport
extends RefCounted

## F4.3f — een server in het klein, in-proces, zonder Node of MySQL: precies
## het actieprotocol van docs/protocol.md (seq_expected + idem_key, 409 met
## inhaal, 422 uit de echte Validator, geredigeerde client-rijen) op één
## volle GameState. Alles wat naar een client gaat, gaat door JSON-tekst
## (floats, gesorteerde sleutels), zodat een RemoteSession hier exact
## hetzelfde meemaakt als tegen de echte backend.
##
## Gebruik: `var lb := LoopbackTransport.new(regels)`, dan per stoel
## `lb.voor_seat(1)` (een Transport) voor een RemoteSession. Optioneel een
## bot op de andere stoel (`zet_bot(2, AgentL1.new(), seed)`) die na elke
## rij zijn legale zetten doet, zoals een tegenstander achter de server.

const EV_GAME_OVER := "game_over"

var state: GameState
var rules: RulesConfig
var seq: int = 0
var status_tekst: String = "bezig"
var winnaar_seat: int = 0
var eind_reden: String = ""
var namen: Dictionary = {1: "Speler 1", 2: "Speler 2"}
## Client-rijen (geredigeerd, door JSON), index = seq - 1.
var rijen: Array = []
## Server-only log (het MatchLog-formaat: action/events/hash per rij).
var log: Array = []
var _idem: Dictionary = {}
var _eindpunten: Dictionary = {}
var _bot: Agent = null
var _bot_seat: int = 0
var _bot_bezig: bool = false


func _init(regels: RulesConfig = null) -> void:
	rules = regels if regels != null else RulesConfig.new()
	state = GameState.new()
	state.rules = rules  # PRE_GAME: beide kanten kiezen blind (F4.0)


## Het transport voor één stoel.
func voor_seat(seat: int) -> Transport:
	if not _eindpunten.has(seat):
		_eindpunten[seat] = Eindpunt.new(self, seat)
	return _eindpunten[seat]


## Een bot op een stoel: hij handelt na elke rij zolang hij legale zetten
## heeft (commit-fasen én zijn eigen beurten), net als een tegenstander die
## achter de server meespeelt. `start()` laat hem meteen beginnen.
func zet_bot(seat: int, agent: Agent, seed_val: int = 0) -> void:
	_bot = agent
	_bot_seat = seat
	agent.player_id = seat
	agent.rng = SeededRng.new(seed_val).fork("loopback_bot")


func start() -> void:
	_bot_zetten()


# --- Het protocol ----------------------------------------------------------

func status_van(seat: int) -> Dictionary:
	var lijst: Array = []
	for s in [1, 2]:
		lijst.append({"seat": s, "naam": String(namen.get(s, "Speler %d" % s))})
	return _door_json({
		"ok": true, "status": status_tekst, "seat": seat, "seats": lijst,
		"winnaar_seat": winnaar_seat if winnaar_seat > 0 else null,
		"eind_reden": eind_reden if eind_reden != "" else null, "seq": seq,
	})


func view_van(seat: int) -> Dictionary:
	return _door_json({"ok": true, "seq": seq, "view": View.for_player(state, seat)})


func rijen_sinds(na: int) -> Array:
	var uit: Array = []
	for r in rijen:
		if int(r.seq) > na:
			uit.append(r)
	return uit


func post_actie(seat: int, seq_expected: int, action_dict: Dictionary, idem_key: String) -> Dictionary:
	# Idempotentie eerst, ook na het einde (protocol.md).
	if _idem.has(idem_key):
		return {"ok": true, "code": 200, "events": _idem[idem_key], "herhaald": true, "fout": ""}
	if status_tekst != "bezig":
		return {"ok": false, "code": 409, "events": [], "herhaald": false,
			"fout": "De match is afgelopen" if status_tekst == "klaar" else "De match is nog niet begonnen"}
	if seq_expected != seq:
		return {"ok": false, "code": 409, "events": rijen_sinds(seq_expected), "herhaald": false,
			"fout": "seq_expected loopt achter"}
	var actie: Dictionary = Actions.from_dict(action_dict)
	var legal: Dictionary = Validator.is_legal(state, actie, seat)
	if not legal.legal:
		return {"ok": false, "code": 422, "events": [], "herhaald": false, "fout": String(legal.reason)}
	var res: Dictionary = Reducer.apply(state, actie, seat)
	if not res.ok:
		return {"ok": false, "code": 422, "events": [], "herhaald": false, "fout": String(res.error)}
	seq += 1
	log.append({
		"seq": seq, "player_id": seat, "action": Actions.to_dict(actie),
		"events": MatchLog._jsonify(res.events), "hash": Zobrist.state_hash(state),
	})
	var rij: Dictionary = _door_json({
		"seq": seq, "player_seat": seat, "type": "action_applied",
		"payload": {"events": MatchLog._jsonify(View.client_events(res.events))},
	})
	rijen.append(rij)
	for ev in res.events:
		if String(ev.type) == EV_GAME_OVER:
			status_tekst = "klaar"
			winnaar_seat = int(ev.payload.winner)
			eind_reden = state.eind_reden
	_idem[idem_key] = [rij]
	_push([rij])
	_bot_zetten()
	return {"ok": true, "code": 200, "events": [rij], "herhaald": false, "fout": ""}


# --- Snapshot (voor de resumecheck van F4.3g) --------------------------------

func snapshot() -> Dictionary:
	return {
		"state": Serializer.state_to_dict(state), "seq": seq, "status": status_tekst,
		"winnaar_seat": winnaar_seat, "eind_reden": eind_reden,
		"rijen": rijen.duplicate(true), "log": log.duplicate(true), "idem": _idem.duplicate(true),
	}


func herstel(snap: Dictionary) -> void:
	state = Serializer.state_from_dict(snap.state)
	seq = int(snap.seq)
	status_tekst = String(snap.status)
	winnaar_seat = int(snap.winnaar_seat)
	eind_reden = String(snap.eind_reden)
	rijen = (snap.rijen as Array).duplicate(true)
	log = (snap.log as Array).duplicate(true)
	_idem = (snap.idem as Dictionary).duplicate(true)


# --- Intern -------------------------------------------------------------------

func _push(nieuwe: Array) -> void:
	for seat in _eindpunten:
		var e: Eindpunt = _eindpunten[seat]
		if not e.stil:
			e.rijen_binnen.emit(nieuwe.duplicate(true))


func _bot_zetten() -> void:
	if _bot == null or _bot_bezig:
		return
	_bot_bezig = true
	var rondjes := 0
	while status_tekst == "bezig" and rondjes < 50:
		rondjes += 1
		var legal: Array = Validator.legal_actions(state, _bot_seat)
		if legal.is_empty():
			break
		var actie: Dictionary = _bot.decide(View.for_player(state, _bot_seat), legal, _bot.rng)
		if actie.is_empty():
			actie = legal[0]
		var uit: Dictionary = post_actie(_bot_seat, seq, Actions.to_dict(actie), _uuid())
		if int(uit.code) != 200:
			break
	_bot_bezig = false


static func _door_json(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d))


static func _uuid() -> String:
	var b: PackedByteArray = Crypto.new().generate_random_bytes(16)
	var h: String = b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


## Het transport van één stoel: dezelfde vier ops als de HTTP-kant, elk
## meteen beantwoord. `stil = true` onderdrukt de push (voor reconnect-tests:
## een client die rijen mist en moet inhalen).
class Eindpunt extends Transport:
	var _lb: WeakRef
	var seat: int
	var stil: bool = false

	func _init(lb: LoopbackTransport, s: int) -> void:
		_lb = weakref(lb)
		seat = s

	func _server() -> LoopbackTransport:
		return _lb.get_ref() as LoopbackTransport

	func status(klaar: Callable) -> void:
		var lb := _server()
		klaar.call(lb.status_van(seat) if lb != null else {"ok": false, "code": 500, "fout": "loopback weg"})

	func view(klaar: Callable) -> void:
		var lb := _server()
		klaar.call(lb.view_van(seat) if lb != null else {"ok": false, "code": 500, "fout": "loopback weg"})

	func acties(seq_expected: int, action: Dictionary, idem_key: String, klaar: Callable) -> void:
		var lb := _server()
		if lb == null:
			klaar.call({"ok": false, "code": 500, "fout": "loopback weg", "events": [], "herhaald": false})
			return
		# Door JSON: de server ziet nooit een Vector2i, alleen tekst.
		klaar.call(lb.post_actie(seat, seq_expected, LoopbackTransport._door_json(action), idem_key))

	func events(after: int, klaar: Callable) -> void:
		var lb := _server()
		klaar.call({"ok": true, "events": lb.rijen_sinds(after)} if lb != null else {"ok": false, "code": 500, "events": []})
