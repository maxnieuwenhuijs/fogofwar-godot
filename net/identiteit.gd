class_name Identiteit
extends RefCounted

## F4.3h — wie ben ik voor de server: het device-token (accounts §9.1,
## gast-eerst) plus wat de client moet onthouden. Staat in
## `user://identity.cfg`; met `-- identiteit=<naam>` op de commandoregel in
## `user://identity_<naam>.cfg`, zodat twee clients op één machine (die
## user:// delen) niet hetzelfde account krijgen en bij het joinen allebei
## seat 1 "herhaald" zouden zien.

var pad: String = "user://identity.cfg"
var device_token: String = ""
var naam: String = ""
var server_url: String = "http://127.0.0.1:8787"  # de POORT-default van server/src/index.ts
var laatste_match_id: String = ""


static func profiel_uit_args() -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("identiteit="):
			return String(a).substr(11)
	return ""


static func laad(profiel: String = "") -> Identiteit:
	var id := Identiteit.new()
	id.pad = "user://identity.cfg" if profiel == "" else "user://identity_%s.cfg" % profiel
	var cf := ConfigFile.new()
	if cf.load(id.pad) == OK:
		id.device_token = String(cf.get_value("identiteit", "device_token", ""))
		id.naam = String(cf.get_value("identiteit", "naam", ""))
		id.server_url = String(cf.get_value("identiteit", "server_url", id.server_url))
		id.laatste_match_id = String(cf.get_value("identiteit", "laatste_match_id", ""))
	# Overschrijven vanaf de commandoregel: -- server=<url>
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("server="):
			id.server_url = String(a).substr(7)
	if id.device_token == "":
		id.device_token = LoopbackTransport._uuid()
		id.bewaar()
	return id


func bewaar() -> void:
	var cf := ConfigFile.new()
	cf.set_value("identiteit", "device_token", device_token)
	cf.set_value("identiteit", "naam", naam)
	cf.set_value("identiteit", "server_url", server_url)
	cf.set_value("identiteit", "laatste_match_id", laatste_match_id)
	cf.save(pad)
