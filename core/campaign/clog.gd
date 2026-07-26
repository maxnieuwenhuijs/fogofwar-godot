class_name CLog
extends RefCounted

# F3.1 — het campagne-actielog: elke geaccepteerde campagne-actie één entry.
# fold() speelt het log af op de beginstand en is daarmee de replay-machine
# (en de basis voor server-hervalidatie in F5). Zelfde contract als MatchLog.

var meta: Dictionary = {}
var entries: Array = []

## F3.4 — autosave: pad naar een jsonl-bestand; elke actie wordt direct
## gepersisteerd (append + close per record = "durf te sluiten": een kill
## verliest hooguit de actie die nog onderweg was). Regel 1 = meta.
var autosave_pad: String = ""


func setup(begin: CState, extra_meta: Dictionary = {}) -> void:
	meta = {
		"formaat": 1,
		"begin": begin.to_dict(),
	}
	for k in extra_meta:
		meta[k] = extra_meta[k]
	entries = []
	if autosave_pad != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(autosave_pad.get_base_dir()))
		var f := FileAccess.open(autosave_pad, FileAccess.WRITE)
		f.store_line(JSON.stringify(meta))
		f.close()


func record(speler: int, action: Dictionary) -> void:
	var entry := {"seq": entries.size(), "speler": speler, "action": action.duplicate(true)}
	entries.append(entry)
	if autosave_pad != "":
		var f := FileAccess.open(autosave_pad, FileAccess.READ_WRITE)
		f.seek_end()
		f.store_line(JSON.stringify(entry))
		f.close()


## F3.4 — een autosave-bestand teruglezen: {ok, meta, entries}.
static func laad_jsonl(pad: String) -> Dictionary:
	if not FileAccess.file_exists(pad):
		return {"ok": false, "fout": "bestand niet gevonden"}
	var f := FileAccess.open(pad, FileAccess.READ)
	var regels: Array = []
	while not f.eof_reached():
		var regel := f.get_line().strip_edges()
		if regel != "":
			regels.append(regel)
	f.close()
	if regels.is_empty():
		return {"ok": false, "fout": "leeg bestand"}
	var m = JSON.parse_string(regels[0])
	if not (m is Dictionary) or not m.has("begin"):
		return {"ok": false, "fout": "meta onleesbaar"}
	var lijst: Array = []
	for i in range(1, regels.size()):
		var e = JSON.parse_string(regels[i])
		if e is Dictionary and e.has("action"):
			lijst.append({"seq": int(e.seq), "speler": int(e.speler), "action": e.action})
	return {"ok": true, "meta": m, "entries": lijst}


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
