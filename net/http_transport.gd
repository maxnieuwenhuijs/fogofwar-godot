class_name HttpTransport
extends Transport

## F4.3h — het Transport tegen de echte backend (server/, docs/protocol.md)
## over HTTP. Elk verzoek is een VERSE HTTPRequest-node (die verwerkt maar
## één verzoek tegelijk, en view-ophaal, actie-POST en poll lopen door
## elkaar) als kind van `host`, en gaat na het antwoord weg. Antwoorden
## krijgen dezelfde vorm als bij de loopback: {ok, code, ...body}.
##
## Polling is de eerste (en blijvende) terugval voor de push: `npm run dev`
## (tsx watch) herstart bij elke bronwijziging en gooit alle WebSockets
## dicht, dus tijdens het bouwen is dit het normale pad. De WebSocket komt
## in F4.3j; `pollen()` geeft dan false zolang de socket leeft.
##
## Een browser kan geen Authorization-header op een WS-upgrade zetten, maar
## voor gewone verzoeken wel; hier gaat het token altijd als Bearer.

var host: Node
var basis_url: String
var token: String = ""
var match_id: String = ""
var timeout_sec: float = 15.0
## Debug (F4.3i, fog-grep): elk ontvangen antwoord naar dit bestand.
var log_pad: String = ""


func _init(h: Node, url: String) -> void:
	host = h
	basis_url = url.rstrip("/")


func pollen() -> bool:
	return true


# --- Identiteit en lobby (buiten het Transport-contract om) -------------------

## Gast-login: het device-token is het account. Zet het sessie-token.
func login(device_token: String, naam: String, klaar: Callable) -> void:
	var body: Dictionary = {"device_token": device_token}
	if naam != "":
		body["naam"] = naam
	_verzoek(HTTPClient.METHOD_POST, "/auth/gast", body, func(a: Dictionary) -> void:
		if bool(a.ok):
			token = String(a.get("sessie_token", ""))
		klaar.call(a)
	)


## Dezelfde engine als de worker? Anders spelen we een ander spel (§11.5).
func versiecheck(klaar: Callable) -> void:
	_verzoek(HTTPClient.METHOD_GET, "/versie", null, func(a: Dictionary) -> void:
		var eigen: String = CoreHash.bereken()
		var server: String = String(a.get("core_hash", ""))
		var gelijk: bool = bool(a.ok) and server == eigen
		klaar.call({
			"ok": gelijk, "code": int(a.get("code", 0)), "server": server, "client": eigen,
			"fout": "" if gelijk else ("server onbereikbaar" if not bool(a.ok) else "andere engine (core-hash verschilt)"),
		})
	)


func maak_match(rules_version: String, rules: Dictionary, klaar: Callable) -> void:
	_verzoek(HTTPClient.METHOD_POST, "/matches", {"rules_version": rules_version, "rules_config": rules},
		func(a: Dictionary) -> void:
			if bool(a.ok):
				match_id = String(a.get("match_id", ""))
			klaar.call(a)
	)


func join(id: String, klaar: Callable) -> void:
	_verzoek(HTTPClient.METHOD_POST, "/matches/%s/join" % id, {}, func(a: Dictionary) -> void:
		if bool(a.ok):
			match_id = id
		klaar.call(a)
	)


# --- Het Transport-contract ---------------------------------------------------

func status(klaar: Callable) -> void:
	_verzoek(HTTPClient.METHOD_GET, "/matches/%s" % match_id, null, klaar)


func view(klaar: Callable) -> void:
	_verzoek(HTTPClient.METHOD_GET, "/matches/%s/view" % match_id, null, klaar)


func acties(seq_expected: int, action: Dictionary, idem_key: String, klaar: Callable) -> void:
	_verzoek(HTTPClient.METHOD_POST, "/matches/%s/acties" % match_id,
		{"seq_expected": seq_expected, "idem_key": idem_key, "action": action}, klaar)


func events(after: int, klaar: Callable) -> void:
	_verzoek(HTTPClient.METHOD_GET, "/matches/%s/events?after=%d" % [match_id, after], null, klaar)


# --- Intern -------------------------------------------------------------------

func _verzoek(methode: int, pad: String, body, klaar: Callable) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		klaar.call({"ok": false, "code": 0, "fout": "geen host-node in de boom", "events": []})
		return
	var r := HTTPRequest.new()
	r.timeout = timeout_sec
	host.add_child(r)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	r.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, bytes: PackedByteArray) -> void:
		r.queue_free()
		var tekst: String = bytes.get_string_from_utf8()
		if log_pad != "":
			_log(pad, code, tekst)
		if result != HTTPRequest.RESULT_SUCCESS:
			klaar.call({"ok": false, "code": 0, "fout": "verbinding (HTTPRequest %d)" % result, "events": [], "herhaald": false})
			return
		var geparsed = JSON.parse_string(tekst) if tekst.strip_edges() != "" else {}
		var a: Dictionary = geparsed if geparsed is Dictionary else {}
		a["code"] = code
		a["ok"] = code >= 200 and code < 300
		if not a.has("events"):
			a["events"] = []
		if not a.has("herhaald"):
			a["herhaald"] = false
		if not a.has("fout"):
			a["fout"] = "" if bool(a.ok) else "HTTP %d" % code
		klaar.call(a)
	)
	var data: String = JSON.stringify(body) if body != null else ""
	var err: int = r.request(basis_url + pad, headers, methode, data)
	if err != OK:
		r.queue_free()
		klaar.call({"ok": false, "code": 0, "fout": "verzoek niet gestart (%d)" % err, "events": [], "herhaald": false})


func _log(pad: String, code: int, tekst: String) -> void:
	var f := FileAccess.open(log_pad, FileAccess.READ_WRITE if FileAccess.file_exists(log_pad) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s %d %s" % [pad, code, tekst])
	f.close()
