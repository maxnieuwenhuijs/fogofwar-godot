extends Node

# F4.2 — de Godot-worker: de server-scheidsrechter. Draait headless als
# kindproces van de Node-backend en spreekt NDJSON over een LOKALE TCP-poort:
#
#   godot --headless --path . res://tools/server_worker.tscn -- poort=9331
#
# Waarom TCP en niet stdio: OS.read_string_from_stdin blokkeert op een open
# pijp tot 64K of EOF, dus een gesprek loopt vast (gemeten, 9 augustus).
# Waarom een SCENE en geen --script: --script laadt de autoloads niet en dan
# compileert de halve engine niet (Constants is een autoload; zelfde valkuil
# als bij losse diagnose-scripts). stdout is alleen nog logboek.
#
# Eén JSON-verzoek per regel over de socket, één antwoord per regel terug.
# De worker is STATELOOS: elk verzoek draagt zijn eigen staat (snapshot) en
# staart (acties sinds het snapshot); Node bewaart alles. Dezelfde
# core/-bestanden als de client — dat is het hele punt (een waarheid), en
# de op "core_hash" laat client en worker bewijzen dat ze gelijk lopen.
#
# Ops:
#   {"op":"init","rules":{...}}
#       → {ok, state, hash}          verse PRE_GAME-staat met deze regels
#   {"op":"apply","state":{...},"tail":[{action,player_id,now_ms}...],
#    "action":{...},"player_id":N,"now_ms":M}
#       → {ok, events, client_events, state, hash}   of {ok:false, fout}
#   {"op":"view","state":{...},"tail":[...],"player_id":N}
#       → {ok, view}
#   {"op":"core_hash"}
#       → {ok, core_hash}
#   {"op":"ping"} → {ok:true}

var _peer: StreamPeerTCP = null
var _buffer := ""


func _ready() -> void:
	var poort := 0
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("poort="):
			poort = int(String(a).substr(6))
	if poort <= 0:
		push_error("server_worker: geef -- poort=<n> mee")
		get_tree().quit(1)
		return
	var server := TCPServer.new()
	if server.listen(poort, "127.0.0.1") != OK:
		push_error("server_worker: poort %d is bezet" % poort)
		get_tree().quit(1)
		return
	print("[WORKER] luistert op 127.0.0.1:%d" % poort)
	# Wacht op de ENE verbinding (de Node-backend die ons spawnde).
	while not server.is_connection_available():
		OS.delay_msec(5)
	_peer = server.take_connection()
	_antwoord({"ok": true, "gereed": true, "core_hash": _core_hash()})
	while true:
		var regel := _lees_regel()
		if regel.is_empty():
			break  # verbinding dicht: Node is klaar met ons
		var vraag = JSON.parse_string(regel)
		if not (vraag is Dictionary):
			_antwoord({"ok": false, "fout": "onleesbare regel"})
			continue
		_antwoord(_verwerk(vraag as Dictionary))
	get_tree().quit()


## NDJSON over de socket: bytes bufferen, per regel afleveren. Lege string =
## de verbinding is weg.
func _lees_regel() -> String:
	while true:
		var idx := _buffer.find("\n")
		if idx >= 0:
			var regel := _buffer.substr(0, idx).strip_edges()
			_buffer = _buffer.substr(idx + 1)
			if regel.is_empty():
				continue
			return regel
		_peer.poll()
		if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return ""
		var n := _peer.get_available_bytes()
		if n <= 0:
			OS.delay_msec(2)
			continue
		var res: Array = _peer.get_data(n)
		if int(res[0]) != OK:
			return ""
		_buffer += (res[1] as PackedByteArray).get_string_from_utf8()
	return ""  # onbereikbaar; de parser eist een sluitend pad


func _antwoord(d: Dictionary) -> void:
	_peer.put_data((JSON.stringify(d) + "\n").to_utf8_buffer())


func _verwerk(vraag: Dictionary) -> Dictionary:
	match String(vraag.get("op", "")):
		"ping":
			return {"ok": true}
		"core_hash":
			return {"ok": true, "core_hash": _core_hash()}
		"init":
			return _op_init(vraag)
		"apply":
			return _op_apply(vraag)
		"view":
			return _op_view(vraag)
	return {"ok": false, "fout": "onbekende op"}


func _op_init(vraag: Dictionary) -> Dictionary:
	var rules_d = vraag.get("rules", {})
	if not (rules_d is Dictionary):
		return {"ok": false, "fout": "rules moet een object zijn"}
	var s := GameState.new()
	s.rules = RulesConfig.from_dict(rules_d)
	# De partij begint in PRE_GAME: beide spelers kiezen hun factie blind via
	# CHOOSE_DOCTRINE (F4.0); de reducer opent daarna zelf de opstelfase.
	return {"ok": true, "state": Serializer.state_to_dict(s), "hash": Zobrist.state_hash(s)}


## Snapshot + staart → levende staat. De staart is exact het MatchLog-fold-
## formaat (action/player_id/now_ms), dus dit IS de replay-machine van F0.7.
func _herbouw(vraag: Dictionary) -> Dictionary:
	var state_d = vraag.get("state", null)
	if not (state_d is Dictionary):
		return {"fout": "state ontbreekt"}
	var staart: Array = vraag.get("tail", [])
	var uitkomst: Dictionary = MatchLog.fold(state_d, staart, false)
	if not bool(uitkomst.get("ok", false)):
		return {"fout": "staart speelt niet af op seq %s: %s" % [
			str(uitkomst.get("seq", "?")), str(uitkomst.get("fout", "?"))]}
	return {"state": uitkomst.state}


func _op_apply(vraag: Dictionary) -> Dictionary:
	var basis := _herbouw(vraag)
	if basis.has("fout"):
		return {"ok": false, "fout": basis.fout}
	var s: GameState = basis.state
	var actie_d = vraag.get("action", null)
	if not (actie_d is Dictionary):
		return {"ok": false, "fout": "action ontbreekt"}
	var actie: Dictionary = Actions.from_dict(actie_d)
	var speler: int = int(vraag.get("player_id", 0))
	# Klokloos = -1 doorgeven: zonder klokken raakt now_ms de staat toch niet,
	# maar zo blijft een online partij byte-identiek aan een offline replay.
	var now_ms: int = int(vraag.get("now_ms", -1))
	if not _clocks_actief(s):
		now_ms = -1
	var res: Dictionary = Reducer.apply(s, actie, speler, now_ms)
	if not bool(res.ok):
		return {"ok": false, "fout": String(res.error), "illegaal": true}
	var log := MatchLog.new()
	return {
		"ok": true,
		"events": log._jsonify(res.events),
		"client_events": log._jsonify(View.client_events(res.events)),
		"state": Serializer.state_to_dict(s),
		"hash": Zobrist.state_hash(s),
		"now_ms": now_ms,
	}


func _op_view(vraag: Dictionary) -> Dictionary:
	var basis := _herbouw(vraag)
	if basis.has("fout"):
		return {"ok": false, "fout": basis.fout}
	var speler: int = int(vraag.get("player_id", 0))
	if speler != Constants.PLAYER_1 and speler != Constants.PLAYER_2:
		return {"ok": false, "fout": "player_id moet 1 of 2 zijn"}
	return {"ok": true, "view": View.for_player(basis.state, speler)}


func _clocks_actief(s: GameState) -> bool:
	return int(s.rules.clock.get("bank_sec", 0)) > 0


## De hash van alles wat de spelregels IS: core/ (recursief) plus de pure
## kern onder scripts/core. Client-build en worker vergelijken deze hash
## (bouwplan §11.5): verschillen ze, dan spelen ze een ander spel en weigert
## de server de verbinding.
func _core_hash() -> String:
	var paden: Array = []
	_verzamel_gd("res://core", paden)
	for naam in ["constants.gd", "GameState.gd", "Rules.gd", "Card.gd", "Pawn.gd", "Phase.gd"]:
		paden.append("res://scripts/core/" + naam)
	paden.sort()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for pad in paden:
		ctx.update((String(pad) + "\n").to_utf8_buffer())
		ctx.update(FileAccess.get_file_as_bytes(pad))
	return ctx.finish().hex_encode()


func _verzamel_gd(map: String, uit: Array) -> void:
	var dir := DirAccess.open(map)
	if dir == null:
		return
	dir.list_dir_begin()
	var naam := dir.get_next()
	while naam != "":
		var pad := map + "/" + naam
		if dir.current_is_dir():
			if not naam.begins_with("."):
				_verzamel_gd(pad, uit)
		elif naam.ends_with(".gd"):
			uit.append(pad)
		naam = dir.get_next()
	dir.list_dir_end()
