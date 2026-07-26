class_name CReducer
extends RefCounted

# F3.1 — de campagne-reducer: apply(cstate, caction, speler) -> {ok, events,
# error}. Zelfde patroon als de match-Reducer: puur, deterministisch,
# muteert in-place, alle regels uit docs/campagne-spec.md (C1-C8).
#
# v1-keuzes (solo, gedocumenteerd in de spec):
# - Nomineren = stemmen: elk actief lid van het nominerende team stemt op een
#   paar {eigen vechter, vijandelijke vechter}; meerderheid wint, staking ->
#   de stem van het lid met de kleinste pool beslist.
# - Bij duel-remise (winnaar -1) krijgen beide vechters het tiebreak-punt.
# - In de burgeroorlog is de bracket-verliezer knock-out (geen testament:
#   er is geen team meer om aan na te laten; restant verbrandt).

const EV_FASE := "cfase"            # {nieuw, oud}
const EV_STEM := "cstem"            # {speler} (inhoud team-only via cview)
const EV_DUEL := "cduel"            # {p1, p2, duel}
const EV_LEDGER := "cledger"        # {entry} — elke boeking is een event
const EV_UITGEVALLEN := "cuit"      # {speler}
const EV_BURGEROORLOG := "cbo"      # {deelnemers, bracket}
const EV_KAMPIOEN := "ckampioen"    # {speler}


static func apply(c: CState, action: Dictionary, speler: int) -> Dictionary:
	if not CActions.is_wellformed(action):
		return _nee("Misvormde campagne-actie")
	if c.fase == CState.Fase.KLAAR:
		return _nee("De campagne is voorbij")
	var events: Array = []
	var fout := ""
	match String(action.type):
		CActions.NOMINATE:
			fout = _do_nominate(c, action, speler, events)
		CActions.DONATE:
			fout = _do_donate(c, action, speler, events)
		CActions.KLAAR_MET_DONEREN:
			fout = _do_klaar_met_doneren(c, speler, events)
		CActions.MATCH_RESULT:
			fout = _do_match_result(c, action, events)
		CActions.TESTAMENT:
			fout = _do_testament(c, action, speler, events)
		CActions.TICK_DEADLINE:
			fout = _do_tick(c, events)
		_:
			return _nee("Onbekend actietype")
	if fout != "":
		return _nee(fout)
	return {"ok": true, "events": events, "error": ""}


static func _nee(reden: String) -> Dictionary:
	return {"ok": false, "events": [], "error": reden}


# --- Nominatie (v1: stemmen in een keer) --------------------------------------

static func _do_nominate(c: CState, action: Dictionary, speler: int, events: Array) -> String:
	if c.fase != CState.Fase.NOMINATIE:
		return "Niet in de nominatie-fase"
	var lid: Dictionary = c.spelers.get(speler, {})
	if lid.is_empty() or String(lid.status) != "actief":
		return "Geen actieve speler"
	if int(lid.team) != c.nominatie_team:
		return "Jouw team nomineert nu niet"
	var eigen: int = int(action.eigen)
	var vijand: int = int(action.vijand)
	var eigen_leden: Array = c.actieve_leden(c.nominatie_team)
	var vijand_leden: Array = c.actieve_leden(1 - c.nominatie_team)
	if not eigen_leden.has(eigen) or c.al_genomineerd.has(eigen):
		return "Ongeldige eigen vechter"
	if not vijand_leden.has(vijand) or c.al_genomineerd.has(vijand):
		return "Ongeldige vijandelijke vechter"
	# Een team met 1 overlevende nomineert zichzelf (spec).
	if eigen_leden.size() == 1 and eigen != eigen_leden[0]:
		return "Laatste overlevende nomineert zichzelf"
	c.nominatie_stemmen[speler] = {"eigen": eigen, "vijand": vijand}
	_ev(events, EV_STEM, {"speler": speler})
	if c.nominatie_stemmen.size() >= eigen_leden.size():
		_sluit_nominatie(c, events)
	return ""


## Telling: meerderheid; staking -> de stem van de kleinste pool beslist.
static func _sluit_nominatie(c: CState, events: Array) -> void:
	var telling: Dictionary = {}
	for sid in c.nominatie_stemmen:
		var stem: Dictionary = c.nominatie_stemmen[sid]
		var sleutel := "%d|%d" % [int(stem.eigen), int(stem.vijand)]
		telling[sleutel] = int(telling.get(sleutel, 0)) + 1
	var beste := ""
	var beste_n := -1
	var staking := false
	for sleutel in telling:
		if int(telling[sleutel]) > beste_n:
			beste_n = int(telling[sleutel])
			beste = sleutel
			staking = false
		elif int(telling[sleutel]) == beste_n:
			staking = true
	if staking:
		# De stem van het lid met de kleinste pool wint (grootste risico).
		var kleinste_id := -1
		var kleinste_pool := 1 << 30
		for sid in c.nominatie_stemmen:
			var p: int = c.pool_totaal_van(int(sid))
			if p < kleinste_pool or (p == kleinste_pool and int(sid) < kleinste_id):
				kleinste_pool = p
				kleinste_id = int(sid)
		var stem: Dictionary = c.nominatie_stemmen[kleinste_id]
		beste = "%d|%d" % [int(stem.eigen), int(stem.vijand)]
	var delen: PackedStringArray = beste.split("|")
	var eigen := int(delen[0])
	var vijand := int(delen[1])
	c.duels_deze_ronde.append({"p1": eigen, "p2": vijand, "klaar": false})
	c.al_genomineerd[eigen] = true
	c.al_genomineerd[vijand] = true
	c.nominatie_stemmen = {}
	_ev(events, EV_DUEL, {"p1": eigen, "p2": vijand, "duel": c.duels_deze_ronde.size() - 1})
	if c.duels_deze_ronde.size() < c.duels_per_ronde():
		c.nominatie_team = 1 - c.nominatie_team  # het andere team nomineert het volgende duel
	else:
		_zet_fase(c, CState.Fase.DONATIE, events)


# --- Donaties -------------------------------------------------------------------

static func _do_donate(c: CState, action: Dictionary, speler: int, events: Array) -> String:
	if c.fase != CState.Fase.DONATIE:
		return "Niet in het donatie-venster"
	var lid: Dictionary = c.spelers.get(speler, {})
	if lid.is_empty() or String(lid.status) != "actief":
		return "Geen actieve speler"
	var naar: int = int(action.naar)
	var doel: Dictionary = c.spelers.get(naar, {})
	if doel.is_empty() or String(doel.status) != "actief" or int(doel.team) != int(lid.team):
		return "Doneren kan alleen aan een actief eigen teamlid"
	var genomineerd := false
	for duel in c.duels_deze_ronde:
		if int(duel.p1) == naar or int(duel.p2) == naar:
			genomineerd = true
	if not genomineerd:
		return "Doneren kan alleen aan een genomineerde"
	if naar == speler:
		return "Aan jezelf doneren heeft geen zin"
	var inf: int = maxi(0, int(action.inf))
	var cav: int = maxi(0, int(action.cav))
	var art: int = maxi(0, int(action.art))
	var cp: int = maxi(0, int(action.cp))
	if inf + cav + art + cp == 0:
		return "Lege donatie"
	var bezit: Dictionary = c.pool_van(speler)
	if inf > int(bezit.inf) or cav > int(bezit.cav) or art > int(bezit.art) or cp > c.cp_van(speler):
		return "Onvoldoende bezit"
	var ontvangen: Dictionary = c.donaties_ontvangen.get(naar, {"pionnen": 0, "cp": 0})
	if int(ontvangen.pionnen) + inf + cav + art > c.rules.donatie_cap_pionnen:
		return "Donatiecap pionnen bereikt (max %d per ontvanger per ronde)" % c.rules.donatie_cap_pionnen
	if int(ontvangen.cp) + cp > c.rules.donatie_cap_cp:
		return "Donatiecap CP bereikt (max %d per ontvanger per ronde)" % c.rules.donatie_cap_cp
	c.donaties_ontvangen[naar] = {
		"pionnen": int(ontvangen.pionnen) + inf + cav + art,
		"cp": int(ontvangen.cp) + cp,
	}
	_boek_ev(c, events, "donate", speler, -inf, -cav, -art, -cp, 0)
	_boek_ev(c, events, "donate", naar, inf, cav, art, cp, 0)
	return ""


static func _do_klaar_met_doneren(c: CState, speler: int, events: Array) -> String:
	if c.fase != CState.Fase.DONATIE:
		return "Niet in het donatie-venster"
	c.donatie_klaar[speler] = true
	var alle_klaar := true
	for team in [0, 1]:
		for id in c.actieve_leden(team):
			if not c.donatie_klaar.has(id):
				alle_klaar = false
	if alle_klaar:
		_zet_fase(c, CState.Fase.DUELS, events)
	return ""


# --- Duel-resultaten -------------------------------------------------------------

static func _do_match_result(c: CState, action: Dictionary, events: Array) -> String:
	if c.fase != CState.Fase.DUELS and c.fase != CState.Fase.BURGEROORLOG:
		return "Geen duels gaande"
	var idx: int = int(action.duel)
	if idx < 0 or idx >= c.duels_deze_ronde.size():
		return "Onbekend duel"
	var duel: Dictionary = c.duels_deze_ronde[idx]
	if bool(duel.klaar):
		return "Duel al verwerkt"
	var p1: int = int(duel.p1)
	var p2: int = int(duel.p2)
	var winnaar: int = int(action.winnaar)  # speler-id of -1 (remise)
	if winnaar != -1 and winnaar != p1 and winnaar != p2:
		return "Winnaar hoort niet bij dit duel"
	var methode: String = String(action.methode)
	# Verliezen en CP-mutaties boeken (het battlereport levert de getallen).
	for sid_str in action.verliezen:
		var sid := int(String(sid_str))
		if sid != p1 and sid != p2:
			return "Verliezen voor een speler buiten het duel"
		var v: Dictionary = action.verliezen[sid_str]
		var vi: int = maxi(0, int(v.get("inf", 0)))
		var vc: int = maxi(0, int(v.get("cav", 0)))
		var va: int = maxi(0, int(v.get("art", 0)))
		if vi + vc + va > 0:
			_boek_ev(c, events, "loss", sid, -vi, -vc, -va, 0, 0)
	for sid_str in action.cp_delta:
		var sid := int(String(sid_str))
		if sid != p1 and sid != p2:
			return "CP-delta voor een speler buiten het duel"
		var delta: int = int(action.cp_delta[sid_str])
		if delta != 0:
			_boek_ev(c, events, "cp_duel", sid, 0, 0, 0, delta, 0)
	# Punten (C5); bij remise (-1) beide het tiebreak-punt.
	if winnaar == -1:
		_boek_ev(c, events, "punten", p1, 0, 0, 0, 0, c.rules.punten_tiebreak)
		_boek_ev(c, events, "punten", p2, 0, 0, 0, 0, c.rules.punten_tiebreak)
	else:
		_boek_ev(c, events, "punten", winnaar, 0, 0, 0, 0, c.rules.punten_voor_methode(methode))
	duel.klaar = true
	# Uitvallen (C3): duel verloren en de voorraad is op.
	if c.fase == CState.Fase.BURGEROORLOG:
		# Knock-out: de verliezer ligt eruit, restant verbrandt (v1-keuze).
		var verliezer_bo: int = p1 if winnaar == p2 else p2
		if winnaar == -1:
			# Remise in de bracket: de hoogste seed (p1) gaat door.
			verliezer_bo = p2
		_verbrand_alles(c, events, verliezer_bo)
		c.spelers[verliezer_bo].status = "uitgevallen"
		c.spelers[verliezer_bo].testament_af = true
		_ev(events, EV_UITGEVALLEN, {"speler": verliezer_bo})
	else:
		for sid in [p1, p2]:
			if sid == winnaar:
				continue
			if c.pool_totaal_van(sid) <= 0 and String(c.spelers[sid].status) == "actief":
				c.spelers[sid].status = "uitgevallen"
				_ev(events, EV_UITGEVALLEN, {"speler": sid})
				if c.cp_van(sid) > 0 or c.pool_totaal_van(sid) > 0:
					c.pending_testamenten.append(sid)
				else:
					c.spelers[sid].testament_af = true
	# Alle duels klaar? Dan door.
	for d in c.duels_deze_ronde:
		if not bool(d.klaar):
			return ""
	if c.fase == CState.Fase.BURGEROORLOG:
		_volgende_bracketronde(c, events)
	elif c.pending_testamenten.is_empty():
		_volgende_ronde(c, events)
	else:
		_zet_fase(c, CState.Fase.TESTAMENT, events)
	return ""


# --- Testament -------------------------------------------------------------------

static func _do_testament(c: CState, action: Dictionary, speler: int, events: Array) -> String:
	if c.fase != CState.Fase.TESTAMENT:
		return "Niet in de testament-fase"
	if not c.pending_testamenten.has(speler):
		return "Geen testament open voor deze speler"
	var verdeling: Array = action.verdeling
	if verdeling.size() > c.rules.testament_ontvangers_max:
		return "Maximaal %d ontvangers" % c.rules.testament_ontvangers_max
	var bezit: Dictionary = c.pool_van(speler)
	var cp_bezit: int = c.cp_van(speler)
	var max_inf: int = int(floor(int(bezit.inf) * c.rules.testament_fractie))
	var max_cav: int = int(floor(int(bezit.cav) * c.rules.testament_fractie))
	var max_art: int = int(floor(int(bezit.art) * c.rules.testament_fractie))
	var max_cp: int = int(floor(cp_bezit * c.rules.testament_fractie))
	var som := {"inf": 0, "cav": 0, "art": 0, "cp": 0}
	for deel in verdeling:
		var naar: int = int(deel.get("naar", -1))
		var doel: Dictionary = c.spelers.get(naar, {})
		if doel.is_empty() or String(doel.status) != "actief":
			return "Nalaten kan alleen aan een actieve speler"
		som.inf += maxi(0, int(deel.get("inf", 0)))
		som.cav += maxi(0, int(deel.get("cav", 0)))
		som.art += maxi(0, int(deel.get("art", 0)))
		som.cp += maxi(0, int(deel.get("cp", 0)))
	if int(som.inf) > max_inf or int(som.cav) > max_cav or int(som.art) > max_art or int(som.cp) > max_cp:
		return "Testament boven de helft van het bezit"
	for deel in verdeling:
		var naar: int = int(deel.get("naar", -1))
		var di: int = maxi(0, int(deel.get("inf", 0)))
		var dc: int = maxi(0, int(deel.get("cav", 0)))
		var da: int = maxi(0, int(deel.get("art", 0)))
		var dp: int = maxi(0, int(deel.get("cp", 0)))
		if di + dc + da + dp > 0:
			_boek_ev(c, events, "testament", speler, -di, -dc, -da, -dp, 0)
			_boek_ev(c, events, "testament", naar, di, dc, da, dp, 0)
	# De rest verbrandt.
	_verbrand_alles(c, events, speler)
	c.spelers[speler].testament_af = true
	c.pending_testamenten.erase(speler)
	if c.pending_testamenten.is_empty():
		_volgende_ronde(c, events)
	return ""


static func _verbrand_alles(c: CState, events: Array, speler: int) -> void:
	var rest: Dictionary = c.pool_van(speler)
	var rest_cp: int = c.cp_van(speler)
	if int(rest.inf) + int(rest.cav) + int(rest.art) + rest_cp > 0:
		_boek_ev(c, events, "verbrand", speler, -int(rest.inf), -int(rest.cav), -int(rest.art), -rest_cp, 0)


# --- Deadline-verwerking (defaults in het log) -----------------------------------

static func _do_tick(c: CState, events: Array) -> String:
	match c.fase:
		CState.Fase.NOMINATIE:
			# Wie niet stemde krijgt de default: sterkste eigen (grootste pool,
			# nog niet genomineerd) tegen de zwakste vijand (kleinste pool).
			var eigen_leden: Array = c.actieve_leden(c.nominatie_team)
			for sid in eigen_leden:
				if c.nominatie_stemmen.has(sid):
					continue
				var eigen := _extreem(c, c.nominatie_team, true)
				var vijand := _extreem(c, 1 - c.nominatie_team, false)
				if eigen == -1 or vijand == -1:
					return "Geen geldige default-nominatie mogelijk"
				c.nominatie_stemmen[sid] = {"eigen": eigen, "vijand": vijand}
				_ev(events, EV_STEM, {"speler": sid})
			_sluit_nominatie(c, events)
		CState.Fase.DONATIE:
			_zet_fase(c, CState.Fase.DUELS, events)
		CState.Fase.TESTAMENT:
			# Timeout: alles verbrandt (spec).
			for sid in c.pending_testamenten.duplicate():
				_verbrand_alles(c, events, sid)
				c.spelers[sid].testament_af = true
				c.pending_testamenten.erase(sid)
			_volgende_ronde(c, events)
		_:
			return "Niets om af te dwingen in deze fase"
	return ""


## Grootste (of kleinste) pool binnen een team, nog niet genomineerd.
static func _extreem(c: CState, team: int, grootste: bool) -> int:
	var beste := -1
	var beste_pool: int = -1 if grootste else (1 << 30)
	for sid in c.actieve_leden(team):
		if c.al_genomineerd.has(sid):
			continue
		var p: int = c.pool_totaal_van(sid)
		if (grootste and p > beste_pool) or (not grootste and p < beste_pool):
			beste_pool = p
			beste = sid
	return beste


# --- Ronde- en eindspel-overgangen ------------------------------------------------

static func _volgende_ronde(c: CState, events: Array) -> void:
	var dood_team: int = c.team_uitgeschakeld()
	if dood_team != -1:
		_start_burgeroorlog(c, events, 1 - dood_team)
		return
	c.ronde += 1
	c.duels_deze_ronde = []
	c.al_genomineerd = {}
	c.nominatie_stemmen = {}
	c.donaties_ontvangen = {}
	c.donatie_klaar = {}
	c.nominatie_team = c.kleinste_team()
	_zet_fase(c, CState.Fase.NOMINATIE, events)


static func _start_burgeroorlog(c: CState, events: Array, winnend_team: int) -> void:
	# Teambonus (C5): +2 per lid van het winnende team, OOK voor de doden.
	for id in c.spelers:
		if int(c.spelers[id].team) == winnend_team:
			_boek_ev(c, events, "teambonus", int(id), 0, 0, 0, 0, c.rules.punten_teambonus)
	var deelnemers: Array = c.actieve_leden(winnend_team)
	if deelnemers.size() == 1:
		_kroon(c, events, deelnemers[0])
		return
	_zet_fase(c, CState.Fase.BURGEROORLOG, events)
	_seed_bracketronde(c, events, deelnemers)


## Seeding punten -> CP -> pool (desc); vrijloting voor de hoogste seed bij
## oneven aantal; paren hoog-vs-laag.
static func _seed_bracketronde(c: CState, events: Array, deelnemers: Array) -> void:
	var seeds: Array = deelnemers.duplicate()
	seeds.sort_custom(func(a, b) -> bool:
		var pa := c.punten_van(a)
		var pb := c.punten_van(b)
		if pa != pb:
			return pa > pb
		var ca := c.cp_van(a)
		var cb := c.cp_van(b)
		if ca != cb:
			return ca > cb
		var la := c.pool_totaal_van(a)
		var lb := c.pool_totaal_van(b)
		if la != lb:
			return la > lb
		return int(a) < int(b))
	c.duels_deze_ronde = []
	c.bracket = []
	var start := 0
	if seeds.size() % 2 == 1:
		start = 1  # vrijloting voor de hoogste seed
	var links := start
	var rechts := seeds.size() - 1
	while links < rechts:
		c.bracket.append([int(seeds[links]), int(seeds[rechts])])
		c.duels_deze_ronde.append({"p1": int(seeds[links]), "p2": int(seeds[rechts]), "klaar": false})
		_ev(events, EV_DUEL, {"p1": int(seeds[links]), "p2": int(seeds[rechts]),
			"duel": c.duels_deze_ronde.size() - 1})
		links += 1
		rechts -= 1
	_ev(events, EV_BURGEROORLOG, {"deelnemers": seeds, "bracket": c.bracket.duplicate(true)})


static func _volgende_bracketronde(c: CState, events: Array) -> void:
	var over: Array = c.actieve_leden(0) + c.actieve_leden(1)
	if over.size() == 1:
		_kroon(c, events, over[0])
		return
	_seed_bracketronde(c, events, over)


static func _kroon(c: CState, events: Array, speler: int) -> void:
	c.winnaar = speler
	_zet_fase(c, CState.Fase.KLAAR, events)
	_ev(events, EV_KAMPIOEN, {"speler": speler})


# --- Helpers ----------------------------------------------------------------------

static func _zet_fase(c: CState, nieuw: int, events: Array) -> void:
	var oud: int = c.fase
	c.fase = nieuw
	_ev(events, EV_FASE, {"nieuw": nieuw, "oud": oud})


static func _boek_ev(c: CState, events: Array, reason: String, speler: int,
		inf: int, cav: int, art: int, cp: int, punten: int) -> void:
	c._boek(reason, speler, inf, cav, art, cp, punten)
	_ev(events, EV_LEDGER, {"entry": c.ledger[c.ledger.size() - 1]})


static func _ev(events: Array, type: String, payload: Dictionary) -> void:
	events.append({"type": type, "seq": events.size(), "payload": payload})
