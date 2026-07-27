class_name SoloDriver
extends RefCounted

# F3.2 — de solo-campagne-motor: draait CampaignCore lokaal met 16 spelers.
# Bots beslissen direct (CampaignAgent op de cview); bot-vs-bot-duels spelen
# op vol tempo via MatchRunner (AIMedium, v4.2-regels met het campagne-bezit
# van beide vechters). Elke actie gaat door CReducer en het CLog: de hele
# campagne is replaybaar. Barks en rapporten landen in `feed` (de UI-tijdlijn).
#
# mens_id -1 = volledig headless (de mens is een 16e bot): de F3.2-CHECK.
# Met een echte mens (F3.4) pauzeert stap() zodra een menselijke beslissing
# nodig is en levert de UI die via de submit_*-methodes aan.

const AIMediumScript := preload("res://scripts/ai/AIMedium.gd")
const AIEasyScript := preload("res://scripts/ai/AIEasy.gd")

## Duel-botniveau: "l1"/"l2" (F1-agents op views via AgentRunner — de snelle
## arena-route, hub-standaard sinds de hang-fix van 27 juli), of legacy
## "medium"/"easy" (MatchRunner + oude AI, blijft voor solocheck/duelstats).
## Cycluslimiet 0 = uit (26 juli, Max): duels spelen uit tot haven of
## eliminatie, net als een los potje; max_steps is de technische noodstop.
var duel_ai: String = "medium"
var duel_cycle_limit: int = 0
var duel_max_steps: int = 3000

## Aparte cycluslimiet voor BOT-duels (-1 = volg duel_cycle_limit). De hub zet
## dit als vangnet tegen 3000-stappen-grindduels; het MENS-duel (via de brug,
## duel_rules_voor zonder override) behoudt de volle duel_cycle_limit.
var bot_duel_cycle_limit: int = -1

## Voortgang voor de UI (dwars door de werk-thread heen leesbaar): welke
## bot-klus er nu maalt. Leeg = geen langlopend werk.
var bezig_met: String = ""

var c: CState = CState.new()
var clog: CLog = CLog.new()
var agents: Dictionary = {}          # speler-id -> CampaignAgent
var feed: Array = []                 # tijdlijn: barks, duel-rapporten, kroning
var mens_id: int = -1
var duels_gespeeld: int = 0
var _rng: SeededRng
var _duel_teller: int = 0


var n_spelers: int = 16


## p_mens_doctrine: de gekozen factie van de mens — vast voor de HELE campagne
## (besluit Max, 27 juli). -1 = de oude round-robin-toewijzing (headless/tests).
func _init(seed_val: int = 1, p_mens_id: int = -1, p_n_spelers: int = 16, autosave_pad: String = "", p_mens_doctrine: int = -1) -> void:
	mens_id = p_mens_id
	n_spelers = p_n_spelers
	clog.autosave_pad = autosave_pad
	_rng = SeededRng.new(seed_val)
	var lobby: Array = Personalities.maak_lobby(n_spelers, _rng.fork("lobby"))
	var doctrines: Array = Constants.DOCTRINE_DATA.keys()
	var lijst: Array = []
	for i in n_spelers:
		var doctrine: int = int(doctrines[i % doctrines.size()])
		if i == mens_id and p_mens_doctrine >= 0:
			doctrine = p_mens_doctrine
		lijst.append({
			"naam": String(lobby[i].naam) if i != mens_id else "Max",
			"doctrine": doctrine,
		})
	c.setup(lijst, CRules.new())
	c.nominatie_team = c.kleinste_team()
	clog.setup(c, {"seed": seed_val})
	for i in n_spelers:
		var agent := CampaignAgent.new()
		agent.speler_id = i
		agent.naam = String(lijst[i].naam)
		agent.profiel = lobby[i].profiel
		agent.rng = _rng.fork("agent_%d" % i)
		agents[i] = agent


## F3.4 — hervatten vanaf een autosave: fold het log op de beginstand.
## De agents worden opnieuw geseed (zelfde campagne-seed); hun rng-stroom
## begint dus vers — de STAAT is byte-identiek (de CHECK-garantie), het
## vervolg is deterministisch-per-hervatting. De feed start met een
## hervat-kaartje (barks/rapporten van voor de herstart zijn presentatie).
static func hervat(pad: String, p_mens_id: int = -1) -> SoloDriver:
	var data: Dictionary = CLog.laad_jsonl(pad)
	if not bool(data.ok):
		return null
	var m: Dictionary = data.meta
	var driver := SoloDriver.new(int(m.get("seed", 1)), p_mens_id,
		(m.begin.spelers as Dictionary).size(), "")
	var uitkomst: Dictionary = CLog.fold(m.begin, data.entries)
	if not bool(uitkomst.ok):
		return null
	driver.c = uitkomst.cstate
	driver.clog.meta = m
	driver.clog.entries = data.entries.duplicate(true)
	driver.clog.autosave_pad = pad
	for e in data.entries:
		if String((e.action as Dictionary).get("type", "")) == CActions.MATCH_RESULT:
			driver._duel_teller += 1
			driver.duels_gespeeld += 1
	driver.feed.append({"type": "bark", "speler": -1, "naam": "Systeem",
		"trigger": "hervat", "tekst": "Campagne hervat in ronde %d." % driver.c.ronde,
		"ronde": driver.c.ronde})
	return driver


## Speel de hele campagne uit (headless). Retourneert de kampioen (-1 = vastgelopen).
func run_headless(max_stappen: int = 400) -> int:
	var guard := 0
	while c.fase != CState.Fase.KLAAR and guard < max_stappen:
		guard += 1
		if wacht_op_mens():
			break  # de UI is aan zet (headless met mens_id -1 komt hier nooit)
		stap()
	return c.winnaar


## Eén campagne-stap: laat de bots doen wat de huidige fase vraagt.
func stap() -> void:
	match c.fase:
		CState.Fase.NOMINATIE:
			_stap_nominatie()
		CState.Fase.DONATIE:
			_stap_donatie()
		CState.Fase.DUELS, CState.Fase.BURGEROORLOG:
			_stap_duels()
		CState.Fase.TESTAMENT:
			_stap_testament()


func _pas_toe(action: Dictionary, speler: int) -> bool:
	var res: Dictionary = CReducer.apply(c, action, speler)
	if res.ok:
		clog.record(speler, action)
	return res.ok


## Fisher-Yates met de campagne-rng (Array.shuffle() zou de globale rng pakken).
func _schud(lijst: Array, rng: SeededRng) -> void:
	for i in range(lijst.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = lijst[i]
		lijst[i] = lijst[j]
		lijst[j] = tmp


func _bark(speler: int, trigger: String, wie: String = "") -> void:
	var agent: CampaignAgent = agents[speler]
	var tekst: String = agent.bark(trigger)
	if tekst == "":
		return
	if tekst.contains("%s"):
		tekst = tekst % wie
	feed.append({"type": "bark", "speler": speler, "naam": agent.naam,
		"trigger": trigger, "tekst": tekst, "ronde": c.ronde})


## Wacht de driver op een beslissing van de mens? (F3.3/F3.4: de UI levert
## die via submit_* aan; bots gaan intussen gewoon door.)
func wacht_op_mens() -> bool:
	if mens_id < 0:
		return false
	# Deadlock-fix (27 juli): het testament komt PRECIES als de mens net
	# "uitgevallen" is — die check moet dus vóór de actief-guard, anders
	# verschijnt het testament-paneel nooit en staat de campagne muurvast
	# (_stap_testament laat het mens-testament expliciet aan de UI).
	if c.fase == CState.Fase.TESTAMENT:
		return c.pending_testamenten.has(mens_id)
	if String(c.spelers.get(mens_id, {}).get("status", "")) != "actief":
		return false
	match c.fase:
		CState.Fase.NOMINATIE:
			if c.rules.ronde1_loting and c.ronde == 1:
				return false  # C9: ronde 1 loot het systeem, niemand stemt
			return int(c.spelers[mens_id].team) == c.nominatie_team and not c.nominatie_stemmen.has(mens_id)
		CState.Fase.DONATIE:
			return not c.donatie_klaar.has(mens_id)
		CState.Fase.DUELS, CState.Fase.BURGEROORLOG:
			return not mens_duel().is_empty()
	return false


## F3.4b — het eerste open duel waar de mens in zit: {idx, p1, p2}, anders {}.
## Alleen als het ook echt het eerstvolgende duel is (duels spelen op volgorde);
## een bot-duel dat eerder in de rij staat, speelt eerst.
func mens_duel() -> Dictionary:
	if mens_id < 0 or not (c.fase == CState.Fase.DUELS or c.fase == CState.Fase.BURGEROORLOG):
		return {}
	for idx in c.duels_deze_ronde.size():
		var duel: Dictionary = c.duels_deze_ronde[idx]
		if bool(duel.klaar):
			continue
		if int(duel.p1) == mens_id or int(duel.p2) == mens_id:
			return {"idx": idx, "p1": int(duel.p1), "p2": int(duel.p2)}
		return {}
	return {}


func submit_mens_nominatie(eigen: int, vijand: int) -> bool:
	return _pas_toe(CActions.make_nominate(eigen, vijand), mens_id)


func submit_mens_donatie(naar: int, inf: int, cav: int, art: int, cp: int) -> bool:
	return _pas_toe(CActions.make_donate(naar, inf, cav, art, cp), mens_id)


func submit_mens_klaar_met_doneren() -> bool:
	return _pas_toe(CActions.make_klaar_met_doneren(), mens_id)


func submit_mens_testament(verdeling: Array) -> bool:
	return _pas_toe(CActions.make_testament(verdeling), mens_id)


func _stap_nominatie() -> void:
	# C9 — ronde 1: het lot paart iedereen, geen raad. De paren komen uit de
	# campagne-rng (deterministisch per seed) en gaan als data het log in.
	if c.rules.ronde1_loting and c.ronde == 1:
		if c.duels_deze_ronde.is_empty():
			var a_leden: Array = c.actieve_leden(0)
			var b_leden: Array = c.actieve_leden(1)
			var rng: SeededRng = _rng.fork("loting")
			_schud(a_leden, rng)
			_schud(b_leden, rng)
			var paren: Array = []
			for i in mini(a_leden.size(), b_leden.size()):
				paren.append([int(a_leden[i]), int(b_leden[i])])
			if _pas_toe(CActions.make_loting(paren), -1):
				feed.append({"type": "bark", "speler": -1, "naam": "De Loting",
					"trigger": "loting",
					"tekst": "Ronde 1: het lot bepaalt de paren — iedereen het bord op!",
					"ronde": c.ronde})
		return
	var team: int = c.nominatie_team
	for sid in c.actieve_leden(team):
		if sid == mens_id or c.nominatie_stemmen.has(sid) or c.fase != CState.Fase.NOMINATIE:
			continue
		var agent: CampaignAgent = agents[sid]
		var keuze: Dictionary = agent.kies_nominatie(CView.for_player(c, sid))
		var gelukt := false
		if not keuze.is_empty():
			gelukt = _pas_toe(CActions.make_nominate(int(keuze.eigen), int(keuze.vijand)), sid)
			if gelukt:
				if int(keuze.eigen) == sid:
					_bark(sid, "zelf_nominatie")
				else:
					_bark(sid, "nominatie_teamgenoot", agents[int(keuze.eigen)].naam)
		if not gelukt:
			# Onmogelijke keuze (bv. alles al genomineerd): defaults afdwingen.
			_pas_toe(CActions.make_tick_deadline(), -1)
			return


func _stap_donatie() -> void:
	for team in [0, 1]:
		for sid in c.actieve_leden(team):
			if c.fase != CState.Fase.DONATIE:
				return
			if sid == mens_id or c.donatie_klaar.has(sid):
				continue
			var agent: CampaignAgent = agents[sid]
			for actie in agent.kies_donaties(CView.for_player(c, sid)):
				if _pas_toe(actie, sid):
					_bark(sid, "donatie", agents[int(actie.naar)].naam)
			_pas_toe(CActions.make_klaar_met_doneren(), sid)


func _stap_duels() -> void:
	# LET OP: MATCH_RESULT kan de duel-lijst vervangen (rondewissel of nieuwe
	# bracketronde) — daarom telkens het eerste open duel opnieuw opzoeken en
	# stoppen zodra de fase wisselt.
	var fase_start: int = c.fase
	for _vangnet in 64:
		if c.fase != fase_start:
			return
		var open_idx := -1
		for idx in c.duels_deze_ronde.size():
			if not bool(c.duels_deze_ronde[idx].klaar):
				open_idx = idx
				break
		if open_idx == -1:
			return
		var duel: Dictionary = c.duels_deze_ronde[open_idx]
		if mens_id >= 0 and (int(duel.p1) == mens_id or int(duel.p2) == mens_id):
			return  # F3.4b: het mens-duel speelt op het echte bord (via de brug)
		_speel_duel(open_idx, int(duel.p1), int(duel.p2))


func _stap_testament() -> void:
	for sid in c.pending_testamenten.duplicate():
		if c.fase != CState.Fase.TESTAMENT:
			return
		if sid == mens_id:
			continue  # de UI levert het mens-testament aan
		var agent: CampaignAgent = agents[sid]
		var keuze: Dictionary = agent.kies_testament(CView.for_player(c, sid))
		var gelukt := false
		if not keuze.is_empty():
			gelukt = _pas_toe(CActions.make_testament(keuze.verdeling), sid)
			if gelukt:
				_bark(sid, "testament_naar_vijand" if bool(keuze.naar_vijand) else "testament")
	if c.fase == CState.Fase.TESTAMENT and not c.pending_testamenten.has(mens_id):
		_pas_toe(CActions.make_tick_deadline(), -1)  # rest verbrandt (spec)


## De duel-config voor a-vs-b uit het campagne-bezit (C2/C7): comp gecapt op
## voorraad, rest wordt reserve, CP per speler. Bord-P1 = a, bord-P2 = b —
## de mens-duel-brug geeft daarom altijd de mens als a mee.
func duel_rules_voor(a: int, b: int, p_cycle_limit: int = -1) -> RulesConfig:
	var bezit_a: Dictionary = c.pool_van(a)
	var bezit_b: Dictionary = c.pool_van(b)
	var comp_a: Array = Constants.doctrine_data(int(c.spelers[a].doctrine)).comp
	var comp_b: Array = Constants.doctrine_data(int(c.spelers[b].doctrine)).comp
	var start_a: Array = [mini(int(comp_a[0]), int(bezit_a.inf)), mini(int(comp_a[1]), int(bezit_a.cav)), mini(int(comp_a[2]), int(bezit_a.art))]
	var start_b: Array = [mini(int(comp_b[0]), int(bezit_b.inf)), mini(int(comp_b[1]), int(bezit_b.cav)), mini(int(comp_b[2]), int(bezit_b.art))]
	return RulesConfig.from_dict({"cycle_limit": duel_cycle_limit if p_cycle_limit < 0 else p_cycle_limit, "campaign": {
		"comp_override": {"1": start_a, "2": start_b},
		"pools": {
			"1": {"inf": int(bezit_a.inf) - start_a[0], "cav": int(bezit_a.cav) - start_a[1], "art": int(bezit_a.art) - start_a[2]},
			"2": {"inf": int(bezit_b.inf) - start_b[0], "cav": int(bezit_b.cav) - start_b[1], "art": int(bezit_b.art) - start_b[2]},
		},
		"cp": {"1": c.cp_van(a), "2": c.cp_van(b)},
	}})


## Vertaal een uitgespeelde duel-staat naar MATCH_RESULT + battlereport.
## a = bord-P1, b = bord-P2; cp_a/cp_b = campagne-CP bij de start van het duel.
## Gedeeld door de bot-duels én het mens-duel op het echte bord (F3.4b).
func verwerk_duel_uitslag(idx: int, a: int, b: int, cp_a: int, cp_b: int,
		s: GameState, winnaar_kant: int) -> bool:
	# Methode bepalen (zoals de arena-metrics).
	var methode := "tiebreak"
	if winnaar_kant != -1:
		if Rules.count_pawns_in_haven(s, winnaar_kant) >= s.rules.pawns_in_haven_to_win:
			methode = "haven"
		else:
			var verliezer_kant: int = Constants.opponent(winnaar_kant)
			if s.count_alive_pawns_for(verliezer_kant) + s.pool_total(verliezer_kant) == 0:
				methode = "eliminatie"
	# Verliezen per type = geëlimineerde pionnen (dood = weg, C-besluiten).
	var verliezen: Dictionary = {str(a): {"inf": 0, "cav": 0, "art": 0}, str(b): {"inf": 0, "cav": 0, "art": 0}}
	for pawn in s.pawns.values():
		if not pawn.is_eliminated:
			continue
		var eigenaar: String = str(a) if pawn.owner_id == Constants.PLAYER_1 else str(b)
		var sleutel: String = ["inf", "cav", "art"][pawn.unit_type]
		verliezen[eigenaar][sleutel] = int(verliezen[eigenaar][sleutel]) + 1
	# CP-delta: eindsaldo - startsaldo, plus het winst-tarief (D13).
	var winnaar_id: int = -1
	if winnaar_kant == Constants.PLAYER_1:
		winnaar_id = a
	elif winnaar_kant == Constants.PLAYER_2:
		winnaar_id = b
	var cp_delta: Dictionary = {
		str(a): int(s.cp.get(Constants.PLAYER_1, cp_a)) - cp_a,
		str(b): int(s.cp.get(Constants.PLAYER_2, cp_b)) - cp_b,
	}
	if winnaar_id != -1:
		var tarief: int = 0
		if methode == "haven":
			tarief = int(s.rules.campaign.get("cp_haven", 8))
		elif methode == "eliminatie":
			tarief = int(s.rules.campaign.get("cp_eliminatie", 4))
		cp_delta[str(winnaar_id)] = int(cp_delta[str(winnaar_id)]) + tarief
	duels_gespeeld += 1
	feed.append({"type": "report", "ronde": c.ronde, "p1": a, "p2": b,
		"winnaar": winnaar_id, "methode": methode, "verliezen": verliezen,
		"cp_delta": cp_delta, "cycli": s.cycle})
	return _pas_toe(CActions.make_match_result(idx, winnaar_id, methode, verliezen, cp_delta), -1)


## Bot-vs-bot-duel op vol tempo: het campagne-bezit van beide vechters wordt
## de duel-config (C2/C7); de uitkomst gaat als MATCH_RESULT + battlereport terug.
## "l1"/"l2" spelen via AgentRunner (de F1-arena-route: view + legal_actions +
## Reducer.apply — orde-van-grootte sneller dan de legacy MatchRunner-route).
func _speel_duel(idx: int, a: int, b: int) -> void:
	_duel_teller += 1
	bezig_met = "De bots spelen duel %d van %d: %s vs %s..." % [
		idx + 1, c.duels_deze_ronde.size(),
		String(c.spelers[a].naam), String(c.spelers[b].naam)]
	var cp_a: int = c.cp_van(a)
	var cp_b: int = c.cp_van(b)
	var rules := duel_rules_voor(a, b, bot_duel_cycle_limit)
	var seed_v: int = _rng.fork("duel_%d" % _duel_teller).randi_range(1, 1 << 30)
	var eind_staat: GameState
	var winnaar_kant: int
	if duel_ai == "l1" or duel_ai == "l2":
		var runner := AgentRunner.new(_maak_duel_agent(), _maak_duel_agent(),
			int(c.spelers[a].doctrine), int(c.spelers[b].doctrine), seed_v, rules)
		runner.max_steps = duel_max_steps
		runner.run()
		eind_staat = runner.state()
		winnaar_kant = runner.winner
	else:
		var ai_script = AIEasyScript if duel_ai == "easy" else AIMediumScript
		var runner := MatchRunner.new(ai_script.new(), ai_script.new(),
			int(c.spelers[a].doctrine), int(c.spelers[b].doctrine), seed_v, rules)
		runner.max_steps = duel_max_steps
		while not runner.done:
			runner.step()
		eind_staat = runner.state()
		winnaar_kant = runner.winner
	bezig_met = ""
	verwerk_duel_uitslag(idx, a, b, cp_a, cp_b, eind_staat, winnaar_kant)


func _maak_duel_agent() -> Agent:
	return AgentL2.new() if duel_ai == "l2" else AgentL1.new()
