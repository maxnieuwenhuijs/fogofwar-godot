class_name EventCodec
extends RefCounted

## F4.3d — reducer-events die als JSON-tekst binnenkomen (server, loopback)
## weer in de vorm brengen die game.gd van de in-proces reducer gewend is.
## Twee dingen gaan in JSON verloren en zijn hier GEEN cosmetiek:
##
##   1. elke int wordt een float: `_pawn_views.get(3.0)` is een miss, en een
##      signal met een int-parameter weigert een float;
##   2. Vector2i wordt [x, y]: game.gd rekent bijvoorbeeld
##      `result.defender_pos - result.attacker_from_pos`.
##
## De sleutels die een Vector2i dragen zijn een gesloten lijst; de canary in
## ClientStateTests loopt alle events van een fuzz-partij af en gilt zodra
## een nieuwe Vector2i-sleutel in de reducer verschijnt die hier ontbreekt.
## `pos` in spawns_revealed blijft bewust een array: de reducer zendt hem
## zelf al als [x, y] uit, en zo leest game.gd hem ook.
##
## Floats die echt floats zijn (het initiatief-bod) blijven floats, ook als
## ze toevallig heel zijn: anders wijkt het type af van het in-proces pad.

const VEC_SLEUTELS: Array[String] = [
	"from", "target", "move_target", "position", "defender_pos", "attacker_from_pos", "charge_from",
]
const FLOAT_SLEUTELS: Array[String] = ["bid"]


static func van_json(v, sleutel: String = ""):
	if v is float:
		if FLOAT_SLEUTELS.has(sleutel):
			return v
		return int(v) if v == floorf(v) else v
	if v is Array:
		if VEC_SLEUTELS.has(sleutel) and v.size() == 2 and _is_getal(v[0]) and _is_getal(v[1]):
			return Vector2i(int(v[0]), int(v[1]))
		var a: Array = []
		for item in v:
			a.append(van_json(item))
		return a
	if v is Dictionary:
		var d: Dictionary = {}
		for k in v:
			d[k] = van_json(v[k], String(k))
		return d
	return v


## Een hele client-rij (of een lijst events) in één keer.
static func events_van_json(events: Array) -> Array:
	var uit: Array = []
	for ev in events:
		uit.append(van_json(ev))
	return uit


static func _is_getal(x) -> bool:
	return x is int or x is float
