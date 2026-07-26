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

## Duel-botniveau: "medium" (standaard) of "easy" (snelle tests/CI);
## de limieten zijn instelbaar zodat checks korte duels kunnen draaien.
var duel_ai: String = "medium"
var duel_cycle_limit: int = 6
var duel_max_steps: int = 700

var c: CState = CState.new()
var clog: CLog = CLog.new()
var agents: Dictionary = {}          # speler-id -> CampaignAgent
var feed: Array = []                 # tijdlijn: barks, duel-rapporten, kroning
var mens_id: int = -1
var duels_gespeeld: int = 0
var _rng: SeededRng
var _duel_teller: int = 0


var n_spelers: int = 16


func _init(seed_val: int = 1, p_mens_id: int = -1, p_n_spelers: int = 16) -> void:
	mens_id = p_mens_id
	n_spelers = p_n_spelers
	_rng = SeededRng.new(seed_val)
	var lobby: Array = Personalities.maak_lobby(n_spelers, _rng.fork("lobby"))
	var doctrines: Array = Constants.DOCTRINE_DATA.keys()
	var lijst: Array = []
	for i in n_spelers:
		lijst.append({
			"naam": String(lobby[i].naam) if i != mens_id else "Max",
			"doctrine": doctrines[i % doctrines.size()],
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


## Speel de hele campagne uit (headless). Retourneert de kampioen (-1 = vastgelopen).
func run_headless(max_stappen: int = 400) -> int:
	var guard := 0
	while c.fase != CState.Fase.KLAAR and guard < max_stappen:
		guard += 1
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


func _bark(speler: int, trigger: String, wie: String = "") -> void:
	var agent: CampaignAgent = agents[speler]
	var tekst: String = agent.bark(trigger)
	if tekst == "":
		return
	if tekst.contains("%s"):
		tekst = tekst % wie
	feed.append({"type": "bark", "speler": speler, "naam": agent.naam,
		"trigger": trigger, "tekst": tekst, "ronde": c.ronde})


func _stap_nominatie() -> void:
	var team: int = c.nominatie_team
	for sid in c.actieve_leden(team):
		if c.nominatie_stemmen.has(sid) or c.fase != CState.Fase.NOMINATIE:
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
			if c.donatie_klaar.has(sid):
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
		_speel_duel(open_idx, int(duel.p1), int(duel.p2))


func _stap_testament() -> void:
	for sid in c.pending_testamenten.duplicate():
		if c.fase != CState.Fase.TESTAMENT:
			return
		var agent: CampaignAgent = agents[sid]
		var keuze: Dictionary = agent.kies_testament(CView.for_player(c, sid))
		var gelukt := false
		if not keuze.is_empty():
			gelukt = _pas_toe(CActions.make_testament(keuze.verdeling), sid)
			if gelukt:
				_bark(sid, "testament_naar_vijand" if bool(keuze.naar_vijand) else "testament")
	if c.fase == CState.Fase.TESTAMENT:
		_pas_toe(CActions.make_tick_deadline(), -1)  # rest verbrandt (spec)


## Bot-vs-bot-duel op vol tempo: het campagne-bezit van beide vechters wordt
## de duel-config (C2/C7); de uitkomst gaat als MATCH_RESULT + battlereport terug.
func _speel_duel(idx: int, a: int, b: int) -> void:
	_duel_teller += 1
	var bezit_a: Dictionary = c.pool_van(a)
	var bezit_b: Dictionary = c.pool_van(b)
	var comp_a: Array = Constants.doctrine_data(int(c.spelers[a].doctrine)).comp
	var comp_b: Array = Constants.doctrine_data(int(c.spelers[b].doctrine)).comp
	var start_a: Array = [mini(int(comp_a[0]), int(bezit_a.inf)), mini(int(comp_a[1]), int(bezit_a.cav)), mini(int(comp_a[2]), int(bezit_a.art))]
	var start_b: Array = [mini(int(comp_b[0]), int(bezit_b.inf)), mini(int(comp_b[1]), int(bezit_b.cav)), mini(int(comp_b[2]), int(bezit_b.art))]
	var cp_a: int = c.cp_van(a)
	var cp_b: int = c.cp_van(b)
	var rules := RulesConfig.from_dict({"cycle_limit": duel_cycle_limit, "campaign": {
		"comp_override": {"1": start_a, "2": start_b},
		"pools": {
			"1": {"inf": int(bezit_a.inf) - start_a[0], "cav": int(bezit_a.cav) - start_a[1], "art": int(bezit_a.art) - start_a[2]},
			"2": {"inf": int(bezit_b.inf) - start_b[0], "cav": int(bezit_b.cav) - start_b[1], "art": int(bezit_b.art) - start_b[2]},
		},
		"cp": {"1": cp_a, "2": cp_b},
	}})
	var ai_script = AIEasyScript if duel_ai == "easy" else AIMediumScript
	var runner := MatchRunner.new(ai_script.new(), ai_script.new(),
		int(c.spelers[a].doctrine), int(c.spelers[b].doctrine),
		_rng.fork("duel_%d" % _duel_teller).randi_range(1, 1 << 30), rules)
	runner.max_steps = duel_max_steps
	while not runner.done:
		runner.step()
	var s: GameState = runner.state()
	# Methode bepalen (zoals de arena-metrics).
	var methode := "tiebreak"
	if runner.winner != -1:
		if Rules.count_pawns_in_haven(s, runner.winner) >= s.rules.pawns_in_haven_to_win:
			methode = "haven"
		else:
			var verliezer_kant: int = Constants.opponent(runner.winner)
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
	if runner.winner == Constants.PLAYER_1:
		winnaar_id = a
	elif runner.winner == Constants.PLAYER_2:
		winnaar_id = b
	var cp_delta: Dictionary = {
		str(a): int(s.cp.get(Constants.PLAYER_1, cp_a)) - cp_a,
		str(b): int(s.cp.get(Constants.PLAYER_2, cp_b)) - cp_b,
	}
	if winnaar_id != -1:
		var tarief: int = int(s.rules.campaign.get("cp_haven", 8)) if methode == "haven" \
			else int(s.rules.campaign.get("cp_eliminatie", 4)) if methode == "eliminatie" else 0
		cp_delta[str(winnaar_id)] = int(cp_delta[str(winnaar_id)]) + tarief
	duels_gespeeld += 1
	feed.append({"type": "report", "ronde": c.ronde, "p1": a, "p2": b,
		"winnaar": winnaar_id, "methode": methode, "verliezen": verliezen,
		"cycli": s.cycle})
	_pas_toe(CActions.make_match_result(idx, winnaar_id, methode, verliezen, cp_delta), -1)
