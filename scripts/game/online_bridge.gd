extends Node

# F4.3i — autoload "OnlineBridge": de online-identiteit, de verbinding met
# de server en de lopende match, over scene-wissels heen (het patroon van
# CampaignBridge). game.gd praat er alleen tegen vanuit de lobby en bij het
# verlaten van een partij; het spel zelf loopt via de RemoteSession.
#
# De HTTPRequest-kinderen van het transport hangen aan deze node, zodat een
# lopend verzoek een scene-wissel overleeft.

var identiteit: Identiteit = null
var transport: HttpTransport = null
var match_id: String = ""
var seat: int = 0
var match_actief: bool = false


func laad_identiteit() -> Identiteit:
	if identiteit == null:
		identiteit = Identiteit.laad(Identiteit.profiel_uit_args())
	return identiteit


## Verbinden: gast-login op het device-token, dan de core-hash vergelijken.
## klaar(ok: bool, fout: String)
func verbind(klaar: Callable) -> void:
	var id: Identiteit = laad_identiteit()
	transport = HttpTransport.new(self, id.server_url)
	transport.login(id.device_token, id.naam, func(a: Dictionary) -> void:
		if not bool(a.get("ok", false)):
			klaar.call(false, "%s\n%s" % [id.server_url, String(a.get("fout", "geen verbinding"))])
			return
		var user = a.get("user", {})
		if user is Dictionary and String(user.get("naam", "")) != "":
			id.naam = String(user.naam)  # de server kent de (gast)naam; onthouden
			id.bewaar()
		transport.versiecheck(func(v: Dictionary) -> void:
			klaar.call(bool(v.get("ok", false)), String(v.get("fout", "")))
		)
	)


func nieuwe_match(regels: RulesConfig, klaar: Callable) -> void:
	transport.maak_match(regels.rules_version, regels.to_dict(), func(a: Dictionary) -> void:
		if bool(a.get("ok", false)):
			match_id = String(a.match_id)
			seat = 1
			_onthoud()
		klaar.call(a)
	)


func meedoen(id: String, klaar: Callable) -> void:
	transport.join(id, func(a: Dictionary) -> void:
		if bool(a.get("ok", false)):
			match_id = id
			seat = int(a.get("seat", 2))
			_onthoud()
		klaar.call(a)
	)


## Terug naar de match uit identity.cfg; klaar(status-antwoord).
func hervatten(klaar: Callable) -> void:
	var id: Identiteit = laad_identiteit()
	if id.laatste_match_id == "":
		klaar.call({"ok": false, "fout": "geen match om te hervatten"})
		return
	transport.match_id = id.laatste_match_id
	transport.status(func(a: Dictionary) -> void:
		if bool(a.get("ok", false)):
			match_id = id.laatste_match_id
			seat = int(a.get("seat", 0))
		klaar.call(a)
	)


func status(klaar: Callable) -> void:
	transport.status(klaar)


## De sessie voor het bord; game.gd voegt hem als kind toe en start hem.
func sessie() -> RemoteSession:
	match_actief = true
	return RemoteSession.new(transport, seat)


## Na een partij (of annuleren): niets meer te hervatten.
func klaar_met_match() -> void:
	match_actief = false
	match_id = ""
	seat = 0
	var id: Identiteit = laad_identiteit()
	id.laatste_match_id = ""
	id.bewaar()


func _onthoud() -> void:
	var id: Identiteit = laad_identiteit()
	id.laatste_match_id = match_id
	id.bewaar()
