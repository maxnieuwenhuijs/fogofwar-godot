class_name CActions
extends RefCounted

# F3.1 — de campagne-actietaal (spiegel van Actions voor de match).
# v1 (solo): NOMINATE is meteen de stem (elk actief lid van het nominerende
# team stemt op een paar {eigen vechter, vijandelijke vechter}; meerderheid
# wint, staking -> kleinste pool beslist). VOTE als losse actie is F5-werk.

const NOMINATE := "nominate"        # {eigen, vijand}
const LOTING := "loting"            # {paren: [[team0-lid, team1-lid], ...]} — C9, ronde 1, systeem
const DONATE := "donate"            # {naar, inf, cav, art, cp}
const KLAAR_MET_DONEREN := "klaar_met_doneren"  # {} — sluit jouw donatie-venster
const MATCH_RESULT := "match_result"  # {duel, winnaar, methode, verliezen:{"<id>":{inf,cav,art}}, cp_delta:{"<id>": n}}
                                      # + optioneel inzet:{"<id>":{inf,cav,art}} — vol-team-model (27 juli):
                                      # ingezette reinforcements; aanwezig = díé worden afgeboekt i.p.v. de verliezen
const TESTAMENT := "testament"      # {verdeling: [{naar, inf, cav, art, cp}]}
const TICK_DEADLINE := "tick_deadline"  # {} — defaults afdwingen (ook in het log)

const _FIELDS := {
	NOMINATE: ["eigen", "vijand"],
	LOTING: ["paren"],
	DONATE: ["naar", "inf", "cav", "art", "cp"],
	KLAAR_MET_DONEREN: [],
	MATCH_RESULT: ["duel", "winnaar", "methode", "verliezen", "cp_delta"],
	TESTAMENT: ["verdeling"],
	TICK_DEADLINE: [],
}


static func make_nominate(eigen: int, vijand: int) -> Dictionary:
	return {"type": NOMINATE, "eigen": eigen, "vijand": vijand}

static func make_loting(paren: Array) -> Dictionary:
	return {"type": LOTING, "paren": paren}

static func make_donate(naar: int, inf: int, cav: int, art: int, cp: int) -> Dictionary:
	return {"type": DONATE, "naar": naar, "inf": inf, "cav": cav, "art": art, "cp": cp}

static func make_klaar_met_doneren() -> Dictionary:
	return {"type": KLAAR_MET_DONEREN}

static func make_match_result(duel: int, winnaar: int, methode: String, verliezen: Dictionary, cp_delta: Dictionary, inzet: Dictionary = {}) -> Dictionary:
	var a := {"type": MATCH_RESULT, "duel": duel, "winnaar": winnaar,
		"methode": methode, "verliezen": verliezen, "cp_delta": cp_delta}
	if not inzet.is_empty():
		a["inzet"] = inzet
	return a

static func make_testament(verdeling: Array) -> Dictionary:
	return {"type": TESTAMENT, "verdeling": verdeling}

static func make_tick_deadline() -> Dictionary:
	return {"type": TICK_DEADLINE}


static func is_wellformed(a) -> bool:
	if not (a is Dictionary) or not a.has("type"):
		return false
	var t: String = String(a.type)
	if not _FIELDS.has(t):
		return false
	for field in _FIELDS[t]:
		if not a.has(field):
			return false
	if t == TESTAMENT and not (a.verdeling is Array):
		return false
	if t == LOTING and not (a.paren is Array):
		return false
	return true
