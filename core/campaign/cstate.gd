class_name CState
extends RefCounted

# F3.1 — de campagnestaat. Het LEDGER is de bron van waarheid (bouwplan
# §5.1-principe): elke pion/CP/punten-mutatie is een event {reason, speler,
# inf, cav, art, cp, punten, ronde}; een saldo is altijd de som van het
# ledger, nooit een muteerbaar veld. spelers[] draagt alleen identiteit en
# status; fase/duels/bracket zijn de procesvelden.

enum Fase { NOMINATIE, DONATIE, DUELS, TESTAMENT, BURGEROORLOG, KLAAR }

var rules: CRules = CRules.new()
var ronde: int = 1
var fase: int = Fase.NOMINATIE
var winnaar: int = -1  # kampioen (speler-id), -1 = nog bezig

# spelers[id] = {"naam": String, "doctrine": int, "team": 0|1,
#   "status": "actief"|"uitgevallen", "testament_af": bool}
var spelers: Dictionary = {}

# Het grootboek: append-only. Elke entry:
# {reason, speler, inf, cav, art, cp, punten, ronde}
var ledger: Array = []

# Raadsronde-proces (v1: nomineren = stemmen; elke actieve speler van het
# nominerende team stemt op een paar {eigen, vijand}).
var nominatie_team: int = 0            # welk team nu nomineert
var nominatie_stemmen: Dictionary = {} # speler-id -> {"eigen": id, "vijand": id}
var duels_deze_ronde: Array = []       # [{p1, p2, klaar: bool}]
var al_genomineerd: Dictionary = {}    # speler-id -> true (niet 2x per ronde)
var donaties_ontvangen: Dictionary = {}  # ontvanger-id -> {"pionnen": n, "cp": n} (caps per ronde)
var donatie_klaar: Dictionary = {}     # speler-id -> true (venster gesloten voor deze speler)
var pending_testamenten: Array = []    # speler-ids die nog moeten nalaten
var bracket: Array = []                # burgeroorlog: [[a, b], ...] per ronde


# --- Opbouw -------------------------------------------------------------------

## Campagne-start: 2 teams, startbezit als ledger-events (reason "start").
func setup(namen_doctrines: Array, p_rules: CRules = null) -> void:
	if p_rules != null:
		rules = p_rules
	spelers = {}
	ledger = []
	for i in namen_doctrines.size():
		var nd: Dictionary = namen_doctrines[i]
		var team: int = 0 if i < namen_doctrines.size() / 2 else 1
		spelers[i] = {
			"naam": String(nd.get("naam", "Speler %d" % i)),
			"doctrine": int(nd.get("doctrine", Constants.Doctrine.MENS)),
			"team": team,
			"status": "actief",
			"testament_af": false,
		}
		var comp: Array = Constants.doctrine_data(int(nd.get("doctrine", 0))).comp
		_boek("start", i, int(floor(comp[0] * rules.start_poolfactor)),
			int(floor(comp[1] * rules.start_poolfactor)),
			int(floor(comp[2] * rules.start_poolfactor)), rules.start_cp, 0)
		# C11: per-factie budget-compensatie (tweakknoppen) — extra soldaten
		# (1 punt elk) en/of extra start-CP, als eigen ledger-boeking.
		var bonus: Dictionary = rules.budget_bonus.get(str(int(nd.get("doctrine", 0))), {})
		if int(bonus.get("pt", 0)) > 0 or int(bonus.get("cp", 0)) > 0:
			_boek("budget_bonus", i, int(bonus.get("pt", 0)), 0, 0, int(bonus.get("cp", 0)), 0)
	fase = Fase.NOMINATIE
	nominatie_team = 0
	ronde = 1


func _boek(reason: String, speler: int, inf: int, cav: int, art: int, cp: int, punten: int) -> void:
	ledger.append({"reason": reason, "speler": speler, "inf": inf, "cav": cav,
		"art": art, "cp": cp, "punten": punten, "ronde": ronde})


# --- Saldi (altijd som van het ledger) ----------------------------------------

func pool_van(speler: int) -> Dictionary:
	var uit := {"inf": 0, "cav": 0, "art": 0}
	for e in ledger:
		if int(e.speler) == speler:
			uit.inf += int(e.inf)
			uit.cav += int(e.cav)
			uit.art += int(e.art)
	return uit


func pool_totaal_van(speler: int) -> int:
	var p := pool_van(speler)
	return int(p.inf) + int(p.cav) + int(p.art)


func cp_van(speler: int) -> int:
	var som := 0
	for e in ledger:
		if int(e.speler) == speler:
			som += int(e.cp)
	return som


func punten_van(speler: int) -> int:
	var som := 0
	for e in ledger:
		if int(e.speler) == speler:
			som += int(e.punten)
	return som


# --- Hulpvragen ----------------------------------------------------------------

func actieve_leden(team: int) -> Array:
	var uit: Array = []
	for id in spelers:
		if int(spelers[id].team) == team and String(spelers[id].status) == "actief":
			uit.append(int(id))
	uit.sort()
	return uit


func kleinste_team() -> int:
	var a: int = actieve_leden(0).size()
	var b: int = actieve_leden(1).size()
	if a != b:
		return 0 if a < b else 1
	# Tiebreak: minste teampunten nomineert eerst.
	var pa := 0
	var pb := 0
	for id in spelers:
		var pts: int = punten_van(int(id))
		if int(spelers[id].team) == 0:
			pa += pts
		else:
			pb += pts
	return 0 if pa <= pb else 1


func duels_per_ronde() -> int:
	return mini(rules.duels_per_ronde_max,
		mini(actieve_leden(0).size(), actieve_leden(1).size()))


func team_uitgeschakeld() -> int:
	## -1 = beide leven nog; anders het team-nummer dat leeg is.
	for team in [0, 1]:
		if actieve_leden(team).is_empty():
			return team
	return -1


# --- Serialisatie ---------------------------------------------------------------

func to_dict() -> Dictionary:
	var sp: Dictionary = {}
	for id in spelers:
		sp[str(id)] = (spelers[id] as Dictionary).duplicate()
	var stemmen: Dictionary = {}
	for id in nominatie_stemmen:
		stemmen[str(id)] = (nominatie_stemmen[id] as Dictionary).duplicate()
	var genomineerd: Dictionary = {}
	for id in al_genomineerd:
		genomineerd[str(id)] = true
	var ontvangen: Dictionary = {}
	for id in donaties_ontvangen:
		ontvangen[str(id)] = (donaties_ontvangen[id] as Dictionary).duplicate()
	return {
		"rules": rules.to_dict(),
		"ronde": ronde,
		"fase": fase,
		"winnaar": winnaar,
		"spelers": sp,
		"ledger": ledger.duplicate(true),
		"nominatie_team": nominatie_team,
		"nominatie_stemmen": stemmen,
		"duels_deze_ronde": duels_deze_ronde.duplicate(true),
		"al_genomineerd": genomineerd,
		"donaties_ontvangen": ontvangen,
		"donatie_klaar": _int_keys_naar_str(donatie_klaar),
		"pending_testamenten": pending_testamenten.duplicate(),
		"bracket": bracket.duplicate(true),
	}


static func _int_keys_naar_str(d: Dictionary) -> Dictionary:
	var uit: Dictionary = {}
	for k in d:
		uit[str(k)] = d[k]
	return uit


static func from_dict(d: Dictionary) -> CState:
	var s := CState.new()
	s.rules = CRules.from_dict(d.get("rules", {}))
	s.ronde = int(d.get("ronde", 1))
	s.fase = int(d.get("fase", Fase.NOMINATIE))
	s.winnaar = int(d.get("winnaar", -1))
	for key in d.get("spelers", {}):
		var e: Dictionary = d.spelers[key]
		s.spelers[int(String(key))] = {
			"naam": String(e.get("naam", "")),
			"doctrine": int(e.get("doctrine", 0)),
			"team": int(e.get("team", 0)),
			"status": String(e.get("status", "actief")),
			"testament_af": bool(e.get("testament_af", false)),
		}
	for e in d.get("ledger", []):
		s.ledger.append({"reason": String(e.reason), "speler": int(e.speler),
			"inf": int(e.inf), "cav": int(e.cav), "art": int(e.art),
			"cp": int(e.cp), "punten": int(e.punten), "ronde": int(e.ronde)})
	s.nominatie_team = int(d.get("nominatie_team", 0))
	for key in d.get("nominatie_stemmen", {}):
		var st: Dictionary = d.nominatie_stemmen[key]
		s.nominatie_stemmen[int(String(key))] = {"eigen": int(st.eigen), "vijand": int(st.vijand)}
	for duel in d.get("duels_deze_ronde", []):
		s.duels_deze_ronde.append({"p1": int(duel.p1), "p2": int(duel.p2), "klaar": bool(duel.klaar)})
	for key in d.get("al_genomineerd", {}):
		s.al_genomineerd[int(String(key))] = true
	for key in d.get("donaties_ontvangen", {}):
		var o: Dictionary = d.donaties_ontvangen[key]
		s.donaties_ontvangen[int(String(key))] = {"pionnen": int(o.pionnen), "cp": int(o.cp)}
	for key in d.get("donatie_klaar", {}):
		s.donatie_klaar[int(String(key))] = true
	for id in d.get("pending_testamenten", []):
		s.pending_testamenten.append(int(id))
	for paar in d.get("bracket", []):
		s.bracket.append([int(paar[0]), int(paar[1])])
	return s
