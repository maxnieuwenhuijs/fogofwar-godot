class_name CLog
extends RefCounted

# F3.1 — het campagne-actielog: elke geaccepteerde campagne-actie één entry.
# fold() speelt het log af op de beginstand en is daarmee de replay-machine
# (en de basis voor server-hervalidatie in F5). Zelfde contract als MatchLog.

var meta: Dictionary = {}
var entries: Array = []


func setup(begin: CState, extra_meta: Dictionary = {}) -> void:
	meta = {
		"formaat": 1,
		"begin": begin.to_dict(),
	}
	for k in extra_meta:
		meta[k] = extra_meta[k]
	entries = []


func record(speler: int, action: Dictionary) -> void:
	entries.append({"seq": entries.size(), "speler": speler, "action": action.duplicate(true)})


## Replay: beginstand reconstrueren en alle acties opnieuw toepassen.
static func fold(begin_dict: Dictionary, log_entries: Array) -> Dictionary:
	var c: CState = CState.from_dict(begin_dict)
	for e in log_entries:
		var res: Dictionary = CReducer.apply(c, e.action, int(e.speler))
		if not res.ok:
			return {"ok": false, "seq": int(e.seq), "fout": res.error, "cstate": c}
	return {"ok": true, "cstate": c}


func save(path: String, eind: CState) -> void:
	var d := {"meta": meta, "eind": eind.to_dict(), "entries": entries}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
