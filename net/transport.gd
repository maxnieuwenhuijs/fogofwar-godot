class_name Transport
extends RefCounted

## F4.3f — de draad tussen een RemoteSession en "de server", als contract.
## Eén instantie = één identiteit op één match (zoals een sessie-token aan de
## HTTP-kant). Elke op is callback-stijl: `klaar.call(antwoord)` met een
## Dictionary in de vorm van docs/protocol.md. Geen coroutines: de loopback
## (F4.3f) antwoordt in dezelfde aanroep, de HttpTransport (F4.3h) later; de
## RemoteSession merkt het verschil niet.
##
## Antwoorden:
##   status  → {ok, status, seat, seats:[{seat, naam}], winnaar_seat, eind_reden, seq}
##   view    → {ok, seq, view}                       (View.for_player-dict, door JSON)
##   acties  → {ok, code, events, herhaald, fout}    (code 200/409/422/500)
##   events  → {ok, events}                           (client-rijen sinds `after`)
## Push (WebSocket of loopback): `rijen_binnen(rijen)` met client-rijen
## {seq, player_seat, type, payload:{events}}.

signal rijen_binnen(rijen: Array)


func status(klaar: Callable) -> void:
	_niet_ondersteund("status", klaar)


func view(klaar: Callable) -> void:
	_niet_ondersteund("view", klaar)


func acties(_seq_expected: int, _action: Dictionary, _idem_key: String, klaar: Callable) -> void:
	_niet_ondersteund("acties", klaar)


func events(_after: int, klaar: Callable) -> void:
	_niet_ondersteund("events", klaar)


## Moet de sessie zelf om rijen vragen (polling), of komt er push?
func pollen() -> bool:
	return false


func _niet_ondersteund(op: String, klaar: Callable) -> void:
	push_error("Transport: %s wordt niet ondersteund door %s" % [op, get_class()])
	if klaar.is_valid():
		klaar.call({"ok": false, "code": 500, "fout": "niet ondersteund: " + op, "events": []})
