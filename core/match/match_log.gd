class_name MatchLog
extends RefCounted

# F0.7 — append-only event-log: per geaccepteerde actie één entry
# {seq, player_id, action, events, hash, ts}. fold() speelt een log af op de
# beginstaat en is daarmee dé replay-machine (en straks de telemetrie, B12:
# het event-log ís de meetlaag). Golden replays in tests/golden_replays/
# zijn de contractvorm: breekt er één, dan is dat een bewuste regelwijziging
# met versie-bump + CHANGELOG-entry (werkafspraak §0).

var meta: Dictionary = {}
var entries: Array = []


## Leg de beginstaat vast (na start_new_game, vóór de eerste actie).
func setup(initial_state: GameState, extra_meta: Dictionary = {}) -> void:
	meta = {
		"formaat": 1,
		"rules_version": initial_state.rules.rules_version,
		"initial_state": Serializer.state_to_dict(initial_state),
		"created": Time.get_datetime_string_from_system(),
	}
	for k in extra_meta:
		meta[k] = extra_meta[k]
	entries = []


## Eén geaccepteerde actie bijschrijven (met post-actie-hash als checksum).
func record(player_id: int, action: Dictionary, events: Array, state_after: GameState) -> void:
	entries.append({
		"seq": entries.size(),
		"player_id": player_id,
		"action": Actions.to_dict(action),
		"events": _jsonify(events),
		"hash": Zobrist.state_hash(state_after),
		"ts": Time.get_unix_time_from_system(),
	})


## Replay: beginstaat reconstrueren en alle acties opnieuw toepassen.
## verify_hashes: per entry de checksum controleren; retourneert bij een
## mismatch {ok:false, seq, verwacht, gekregen}; anders {ok:true, state}.
static func fold(initial_state_dict: Dictionary, log_entries: Array, verify_hashes: bool = true) -> Dictionary:
	var s: GameState = Serializer.state_from_dict(initial_state_dict)
	for e in log_entries:
		var action: Dictionary = Actions.from_dict(e.action)
		var res: Dictionary = Reducer.apply(s, action, int(e.player_id))
		if not res.ok:
			return {"ok": false, "seq": int(e.seq), "fout": "actie geweigerd: %s" % res.error, "state": s}
		if verify_hashes:
			var h: String = Zobrist.state_hash(s)
			if h != String(e.hash):
				return {"ok": false, "seq": int(e.seq), "fout": "hash-mismatch", "verwacht": e.hash, "gekregen": h, "state": s}
	return {"ok": true, "state": s}


func save(path: String, final_state: GameState) -> void:
	var d: Dictionary = {
		"meta": meta,
		"final_hash": Zobrist.state_hash(final_state),
		"final_state": Serializer.state_to_dict(final_state),
		"entries": entries,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("MatchLog: bestand niet gevonden: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Volledige replay-verificatie van een opgeslagen log: fold + eind-hash +
## byte-identieke eindstaat. Retourneert {ok, fout?}.
static func verify_file(path: String) -> Dictionary:
	var d: Dictionary = load_file(path)
	if d.is_empty():
		return {"ok": false, "fout": "bestand leeg of onleesbaar"}
	var uitkomst: Dictionary = fold(d.meta.initial_state, d.entries, true)
	if not uitkomst.ok:
		return {"ok": false, "fout": "fold faalde op seq %d: %s" % [int(uitkomst.seq), String(uitkomst.get("fout", "?"))]}
	var eind: GameState = uitkomst.state
	if Zobrist.state_hash(eind) != String(d.final_hash):
		return {"ok": false, "fout": "eind-hash wijkt af"}
	# Byte-vergelijking: de opgeslagen eindstaat eerst normaliseren (JSON leest
	# ints als floats terug; from_dict → to_dict maakt ze weer canoniek).
	var verwacht: String = JSON.stringify(Serializer.state_to_dict(Serializer.state_from_dict(d.final_state)))
	if JSON.stringify(Serializer.state_to_dict(eind)) != verwacht:
		return {"ok": false, "fout": "eindstaat niet byte-identiek"}
	return {"ok": true}


## Diepe JSON-veilige kopie (Vector2i → [x, y]) voor de event-payloads.
static func _jsonify(v):
	if v is Vector2i:
		return [v.x, v.y]
	if v is Dictionary:
		var d: Dictionary = {}
		for k in v:
			d[str(k)] = _jsonify(v[k])
		return d
	if v is Array:
		var a: Array = []
		for item in v:
			a.append(_jsonify(item))
		return a
	return v
