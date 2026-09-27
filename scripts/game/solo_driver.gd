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
## V0 (3 augustus): duels spelen uit tot haven of eliminatie, en de
## uitputtingsklok (honger) dwingt dat einde af. De cycluslimiet bestaat niet
## meer -- die verzon een winnaar voor een partij die niemand had gewonnen.
## max_steps blijft de technische noodstop, maar levert GEEN uitslag meer op.
var duel_ai: String = "medium"
var duel_honger_vanaf: int = 10
var duel_max_steps: int = 3000

## Aparte hongercyclus voor BOT-duels (-1 = volg duel_honger_vanaf). De hub kan
## hem lager zetten als vangnet tegen lange grindduels; het MENS-duel (via de
## brug, duel_rules_voor zonder override) houdt de gewone waarde.
var bot_duel_honger_vanaf: int = -1

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

## Quick chat (25 september; UI-spec 2b.2, intrige-voorstel P1 en P4): een
## gesloten lijst zinnen, alleen voor je eigen team en nooit in het
## campagnelog. Een verzoek is een wens aan je team: teamgenoten zeggen
## AKKOORD! of NEE. naar hun karakter, en wie akkoord zei komt het na met
## kans `loyaliteit` (de trouwe generaal altijd, de rat bijna nooit). Alles
## hier loopt alleen met een mens erbij en op een eigen rng-stroom, dus de
## headless campagne en haar determinisme blijven gelijk.
const QC_WENS := {
	"HUB_QC_STUUR_MIJ": "stuur", "HUB_QC_STUUR": "stuur", "HUB_QC_PAK": "pak",
	"HUB_QC_NODIG": "doneer", "HUB_QC_DONEER": "doneer", "HUB_QC_NALATEN": "nalaten",
}
## Deze zinnen gaan over de spreker zelf (doel = spreker).
const QC_OVER_ZELF := ["HUB_QC_STUUR_MIJ", "HUB_QC_NODIG", "HUB_QC_NALATEN"]
## bot-id -> {soort: [doel-ids]}: waar een bot deze ronde AKKOORD! op zei.
var toezeggingen: Dictionary = {}
var _toezeg_ronde: int = -1
var _bedankt: Dictionary = {}           # "ronde|ontvanger" -> true
var _chat_rng: SeededRng

## F7.1a (campagne-arena): een Array = elk bot-duel komt erin met zijn invoer
## (facties, reserve, CP) en uitkomst, in het formaat van duel_record. Null
## (standaard) = niets bijhouden.
var duel_log = null
## F7.1b: "echt" (de bots spelen het duel uit) of "orakel" (een gemeten duel
## trekken uit `orakel`, voor de campagne-arena en de trainer). De mens
## speelt altijd echt: zijn duel loopt via de brug, niet via _speel_duel.
var duel_modus: String = "echt"
var orakel = null  # DuelOrakel (ongetypeerd: de driver laadt ook zonder die klasse)
const _OrakelScript := preload("res://scripts/training/duel_orakel.gd")


## Het orakel dat de bots raadplegen voor hun winkans (F7.2a verstand). Los
## van `orakel`/`duel_modus`: een mens-campagne speelt echte duels, maar zijn
## bots mogen wel weten hoe matchups doorgaans uitvallen.
func zet_orakel_voor_bots(o) -> void:
	for sid in agents:
		(agents[sid] as CampaignAgent).orakel = o


var n_spelers: int = 16


## p_mens_doctrine: de gekozen factie van de mens — vast voor de HELE campagne
## (besluit Max, 27 juli). -1 = de oude round-robin-toewijzing (headless/tests).
func _init(seed_val: int = 1, p_mens_id: int = -1, p_n_spelers: int = 16, autosave_pad: String = "", p_mens_doctrine: int = -1) -> void:
	mens_id = p_mens_id
	n_spelers = p_n_spelers
	clog.autosave_pad = autosave_pad
	_rng = SeededRng.new(seed_val)
	_chat_rng = _rng.fork("quick_chat")  # fork trekt niets uit _rng
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
	# C17: de facties waaronder deze campagne speelt komen uit hetzelfde
	# bestand als waar de trainer en de arena op meten, en worden daarna in de
	# save bevroren (hervatten leest het bestand niet meer). Zonder blok in dat
	# bestand is dit een lege dict en verandert er niets.
	var campagne_regels := CRules.new()
	campagne_regels.doctrines = CRules.facties_uit_bestand()
	c.setup(lijst, campagne_regels)
	c.nominatie_team = c.kleinste_team()
	clog.setup(c, {"seed": seed_val})
	for i in n_spelers:
		var agent := CampaignAgent.new()
		agent.speler_id = i
		agent.naam = String(lijst[i].naam)
		agent.profiel = lobby[i].profiel
		agent.rng = _rng.fork("agent_%d" % i)
		# F7.2a: het getrainde verstand (leeg zonder data/campagne_verstand.json)
		# en het orakel voor de winkans (alleen als het verstand hem gebruikt).
		agent.verstand = CampaignAgent.laad_verstand()
		agents[i] = agent
	var met_verstand: bool = not (agents[0] as CampaignAgent).verstand.is_empty()
	if met_verstand and FileAccess.file_exists(_OrakelScript.STANDAARD):
		zet_orakel_voor_bots(_OrakelScript.laad())


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
	driver.feed.append({"type": "bark", "speler": -1, "naam": driver.tr("SOLO_NAME_SYSTEM"),
		"trigger": "hervat", "tekst": driver.tr("SOLO_FEED_RESUMED") % driver.c.ronde,
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
	var fase_voor: int = c.fase
	var res: Dictionary = CReducer.apply(c, action, speler)
	if res.ok:
		clog.record(speler, action)
		_feed_event(action, speler)
		if c.fase != fase_voor:
			_feed_fase(fase_voor)
	return res.ok


## Campagne-hub (23 september): een fasewissel is een eigen kaartje in de
## tijdlijn. Wie uit de raad komt draagt de gekozen paren mee (de stemuitslag).
func _feed_fase(van: int) -> void:
	var paren: Array = []
	if van == CState.Fase.NOMINATIE:
		for duel in c.duels_deze_ronde:
			paren.append([int(duel.p1), int(duel.p2)])
	feed.append({"type": "fase", "ronde": c.ronde, "van": van, "naar": c.fase,
		"paren": paren})
	if c.fase == CState.Fase.DONATIE:
		_bots_vragen_om_steun()


## 27 juli (Max): élke donatie/testament als leesbare regel in de tijdlijn —
## ook wat de mens zelf doet. Het ledger is toch openbaar (Among Us-principe).
func _feed_event(action: Dictionary, speler: int) -> void:
	var t: String = String(action.type)
	if t == CActions.NOMINATE:
		feed.append({"type": "nominatie", "speler": speler, "ronde": c.ronde,
			"eigen": int(action.eigen), "vijand": int(action.vijand)})
	elif t == CActions.DONATE:
		var delen: Array = []
		for veld in [["inf", "SOLO_UNIT_INF"], ["cav", "SOLO_UNIT_CAV"], ["art", "SOLO_UNIT_ART"], ["cp", "SOLO_UNIT_CP"]]:
			var n: int = int(action.get(veld[0], 0))
			if n > 0:
				delen.append("%d %s" % [n, tr(String(veld[1]))])
		feed.append({"type": "event", "soort": "donatie", "speler": speler, "ronde": c.ronde,
			"naar": int(action.naar), "inf": int(action.get("inf", 0)), "cav": int(action.get("cav", 0)),
			"art": int(action.get("art", 0)), "cp": int(action.get("cp", 0)),
			"tekst": tr("SOLO_FEED_DONATE") % [String(c.spelers[speler].naam),
				", ".join(delen), String(c.spelers[int(action.naar)].naam)]})
	elif t == CActions.EXCHANGE:
		var koers: int = maxi(1, c.rules.ruil_cp_per_punt)
		feed.append({"type": "event", "soort": "ruil", "speler": speler, "ronde": c.ronde,
			"cp": int(action.cp),
			"tekst": tr("SOLO_FEED_RUIL") % [String(c.spelers[speler].naam),
				int(action.cp), int(action.cp) / koers]})
	elif t == CActions.TESTAMENT:
		for deel in (action.verdeling as Array):
			var delen2: Array = []
			for veld in [["inf", "SOLO_UNIT_INF"], ["cav", "SOLO_UNIT_CAV"], ["art", "SOLO_UNIT_ART"], ["cp", "SOLO_UNIT_CP"]]:
				var n2: int = int((deel as Dictionary).get(veld[0], 0))
				if n2 > 0:
					delen2.append("%d %s" % [n2, tr(String(veld[1]))])
			if not delen2.is_empty():
				var d: Dictionary = deel
				feed.append({"type": "event", "soort": "testament", "speler": speler, "ronde": c.ronde,
					"naar": int(d.naar), "inf": int(d.get("inf", 0)), "cav": int(d.get("cav", 0)),
					"art": int(d.get("art", 0)), "cp": int(d.get("cp", 0)),
					"tekst": tr("SOLO_FEED_TESTAMENT") % [String(c.spelers[speler].naam),
						", ".join(delen2), String(c.spelers[int((deel as Dictionary).naar)].naam)]})


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
		# Sommige (vertaalde) barks hebben meerdere %s — replace vult ze
		# allemaal en kan nooit een format-error geven (bug: kale %s in de UI).
		tekst = tekst.replace("%s", wie)
	feed.append({"type": "bark", "speler": speler, "naam": agent.naam,
		"trigger": trigger, "tekst": tekst, "ronde": c.ronde})


# --- Quick chat -----------------------------------------------------------------

## Een quick-chat-bericht van `speler` (de mens) plus de antwoorden van zijn
## teamgenoten, alles in de feed. `doel` = de speler waar de zin over gaat
## (Stuur X!, Pak X!, Doneer aan X!); de zinnen over jezelf vullen hem zelf in.
## De doden zwijgen (UI-spec 2b.4).
func quick_chat(speler: int, sleutel: String, doel: int = -1) -> void:
	var sp: Dictionary = c.spelers.get(speler, {})
	if sp.is_empty() or String(sp.status) != "actief" or c.fase == CState.Fase.KLAAR:
		return
	if QC_OVER_ZELF.has(sleutel):
		doel = speler
	_chat(speler, sleutel, doel)
	var bots: Array = []
	for sid in c.actieve_leden(int(sp.team)):
		if int(sid) != speler and int(sid) != mens_id and agents.has(int(sid)):
			bots.append(int(sid))
	if bots.is_empty():
		return
	_chat_rng.shuffle(bots)
	var soort: String = String(QC_WENS.get(sleutel, ""))
	if soort != "":
		_beantwoord_verzoek(bots, soort, doel)
		return
	match sleutel:
		"HUB_QC_SUCCES":
			# Wie deze ronde nog moet vechten, bedankt je (hooguit twee).
			var n := 0
			for bot in bots:
				if n < 2 and _vecht_nog(bot):
					_chat(bot, "HUB_QC_BEDANKT", speler)
					n += 1
		"HUB_QC_GOED_GEVOCHTEN":
			for bot in bots:
				if _vocht_al(bot):
					_chat(bot, "HUB_QC_BEDANKT", speler)
					break
		"HUB_QC_VERTROUW":
			var agent: CampaignAgent = agents[int(bots[0])]
			var ja: bool = _chat_rng.randf() < agent.gewicht("loyaliteit", 0.8)
			_chat(int(bots[0]), "HUB_QC_AKKOORD" if ja else "HUB_QC_NEE", speler)
		"HUB_QC_VERRADER":
			_chat(int(bots[0]), "HUB_QC_VERRADER" if _chat_rng.randf() < 0.5 else "HUB_QC_NEE", -1)


## Een verzoek: wie het over zich hoort (Stuur X!) antwoordt eerst, daarna nog
## twee anderen. AKKOORD! is een toezegging voor de rest van deze ronde.
func _beantwoord_verzoek(bots: Array, soort: String, doel: int) -> void:
	_vers_toezeggingen()
	if soort == "doneer":
		bots.erase(doel)  # niemand belooft zichzelf iets te geven
	elif bots.has(doel):
		bots.erase(doel)
		bots.push_front(doel)
	var n: int = mini(bots.size(), 3 if (not bots.is_empty() and int(bots[0]) == doel) else 2)
	for i in n:
		var bot: int = int(bots[i])
		var agent: CampaignAgent = agents[bot]
		if _chat_rng.randf() < _kans_akkoord(agent, soort, bot == doel):
			var per_soort: Dictionary = toezeggingen.get(bot, {})
			var doelen: Array = per_soort.get(soort, [])
			if not doelen.has(doel):
				doelen.append(doel)
			per_soort[soort] = doelen
			toezeggingen[bot] = per_soort
			_chat(bot, "HUB_QC_AKKOORD", doel)
		else:
			_chat(bot, "HUB_QC_NEE", doel)


## Hoe graag een bot ja zegt, naar zijn karakter. Zelf gestuurd worden hangt
## af van zijn zin in een gevecht (w_zelf) en zijn angst om te verliezen.
func _kans_akkoord(agent: CampaignAgent, soort: String, over_zichzelf: bool) -> float:
	var p: float
	match soort:
		"stuur":
			if over_zichzelf:
				p = 0.15 + 0.5 * agent.gewicht("w_zelf") - 0.25 * agent.gewicht("risico_afslag")
			else:
				p = 0.2 + 0.7 * agent.gewicht("loyaliteit", 0.8)
		"pak":
			p = 0.2 + 0.7 * agent.gewicht("loyaliteit", 0.8)
		"doneer":
			p = 0.1 + 0.8 * agent.gewicht("vrijgevigheid")
		_:
			p = 0.1 + 0.8 * agent.gewicht("loyaliteit", 0.8)
	return clampf(p, 0.05, 0.95)


## Bij de start van het donatievenster vragen teamgenoten van de mens die deze
## ronde vechten soms om versterking (hooguit twee): iets om op te reageren.
func _bots_vragen_om_steun() -> void:
	if mens_id < 0 or String(c.spelers.get(mens_id, {}).get("status", "")) != "actief":
		return
	var team: int = int(c.spelers[mens_id].team)
	var vragers := 0
	for duel in c.duels_deze_ronde:
		for kant in ["p1", "p2"]:
			var sid: int = int(duel[kant])
			if vragers >= 2 or sid == mens_id or int(c.spelers[sid].team) != team:
				continue
			if _chat_rng.randf() < 0.5:
				_chat(sid, "HUB_QC_NODIG", sid)
				vragers += 1


## Een chatregel in de feed; %s wordt de naam van het doel.
func _chat(speler: int, sleutel: String, doel: int) -> void:
	var tekst: String = tr(sleutel)
	if tekst.contains("%s"):
		tekst = tekst.replace("%s", String(c.spelers.get(doel, {}).get("naam", "?")))
	feed.append({"type": "chat", "speler": speler, "naam": String(c.spelers[speler].naam),
		"qc": sleutel, "doel": doel, "tekst": tekst, "ronde": c.ronde})


## Toezeggingen gelden een ronde: daarna begint iedereen weer met een schone lei.
func _vers_toezeggingen() -> void:
	if _toezeg_ronde != c.ronde:
		toezeggingen = {}
		_toezeg_ronde = c.ronde


func _toezeggingen_voor(sid: int) -> Dictionary:
	if toezeggingen.is_empty():
		return {}
	_vers_toezeggingen()
	return toezeggingen.get(sid, {})


func _vecht_nog(sid: int) -> bool:
	for duel in c.duels_deze_ronde:
		if not bool(duel.klaar) and (int(duel.p1) == sid or int(duel.p2) == sid):
			return true
	return false


func _vocht_al(sid: int) -> bool:
	for duel in c.duels_deze_ronde:
		if bool(duel.klaar) and (int(duel.p1) == sid or int(duel.p2) == sid):
			return true
	return false


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


## F3.4b — het open duel waar de mens in zit: {idx, p1, p2}, anders {}.
## De mens heeft VOORRANG (27 juli, Max): zodra zijn duel open staat speelt
## hij eerst en wachten de bot-simulaties — geen minutenlang staren naar
## "bots zijn bezig" voordat je zelf mag.
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


func submit_mens_nominatie(eigen: int, vijand: int) -> bool:
	return _pas_toe(CActions.make_nominate(eigen, vijand), mens_id)


func submit_mens_donatie(naar: int, inf: int, cav: int, art: int, cp: int) -> bool:
	var gelukt := _pas_toe(CActions.make_donate(naar, inf, cav, art, cp), mens_id)
	var sleutel := "%d|%d" % [c.ronde, naar]
	if gelukt and naar != mens_id and agents.has(naar) and not _bedankt.has(sleutel):
		_bedankt[sleutel] = true
		var agent: CampaignAgent = agents[naar]
		if _chat_rng.randf() < 0.4 + 0.6 * agent.gewicht("loyaliteit", 0.8):
			_chat(naar, "HUB_QC_BEDANKT", mens_id)
	return gelukt


func submit_mens_klaar_met_doneren() -> bool:
	return _pas_toe(CActions.make_klaar_met_doneren(), mens_id)


func submit_mens_ruil(cp: int) -> bool:
	return _pas_toe(CActions.make_exchange(cp), mens_id)


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
				var lot := {"type": "bark", "speler": -1, "naam": tr("SOLO_NAME_LOTING"),
					"trigger": "loting",
					"tekst": tr("SOLO_FEED_LOTING"),
					"ronde": c.ronde}
				# De loting komt voor de fasewissel die ze veroorzaakt (die
				# zette _pas_toe er net achteraan): in de tijdlijn eerst het lot.
				if not feed.is_empty() and String(feed.back().get("type", "")) == "fase":
					feed.insert(feed.size() - 1, lot)
				else:
					feed.append(lot)
		return
	var team: int = c.nominatie_team
	for sid in c.actieve_leden(team):
		if sid == mens_id or c.nominatie_stemmen.has(sid) or c.fase != CState.Fase.NOMINATIE:
			continue
		var agent: CampaignAgent = agents[sid]
		agent.toezeggingen = _toezeggingen_voor(sid)
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
			agent.toezeggingen = _toezeggingen_voor(sid)
			# F7.2a: eerst CP ruilen (alleen met verstand; standaard nooit).
			var ruil: int = agent.kies_ruil(CView.for_player(c, sid), maxi(1, c.rules.ruil_cp_per_punt))
			if ruil > 0:
				_pas_toe(CActions.make_exchange(ruil), sid)
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
		if not mens_duel().is_empty():
			return  # voorrang: de mens speelt eerst op het bord, bots daarna
		var open_idx := -1
		for idx in c.duels_deze_ronde.size():
			if not bool(c.duels_deze_ronde[idx].klaar):
				open_idx = idx
				break
		if open_idx == -1:
			return
		var duel: Dictionary = c.duels_deze_ronde[open_idx]
		_speel_duel(open_idx, int(duel.p1), int(duel.p2))


## F3.4c — bot-duels simuleren TERWIJL de mens op het bord staat (aparte
## thread via CampaignBridge). Speelt alle open duels behalve het mens-duel.
## Veilig: de ronde kan pas sluiten als ook het mens-resultaat binnen is
## (fase blijft DUELS/BURGEROORLOG zolang één duel open staat), en de mens
## raakt de driver niet aan tot CampaignBridge.rond_af — die eerst deze
## simulatie laat uitdraaien.
func simuleer_bot_duels() -> void:
	var fase_start: int = c.fase
	for _vangnet in 64:
		if c.fase != fase_start:
			return
		var open_idx := -1
		for idx in c.duels_deze_ronde.size():
			var duel: Dictionary = c.duels_deze_ronde[idx]
			if bool(duel.klaar):
				continue
			if int(duel.p1) == mens_id or int(duel.p2) == mens_id:
				continue
			open_idx = idx
			break
		if open_idx == -1:
			bezig_met = ""
			return
		var duel: Dictionary = c.duels_deze_ronde[open_idx]
		_speel_duel(open_idx, int(duel.p1), int(duel.p2))
	bezig_met = ""


func _stap_testament() -> void:
	for sid in c.pending_testamenten.duplicate():
		if c.fase != CState.Fase.TESTAMENT:
			return
		if sid == mens_id:
			continue  # de UI levert het mens-testament aan
		var agent: CampaignAgent = agents[sid]
		agent.toezeggingen = _toezeggingen_voor(sid)
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
func duel_rules_voor(a: int, b: int, p_honger_vanaf: int = -1) -> RulesConfig:
	var bezit_a: Dictionary = c.pool_van(a)
	var bezit_b: Dictionary = c.pool_van(b)
	# C17: via de campagneregels, net als de startboeking in CState.setup.
	# Rechtstreeks uit Constants lezen gaf een leger dat niet strookte met de
	# voorraad zodra er een doctrines-blok in het spel was.
	var comp_a: Array = c.rules.doctrine_data(int(c.spelers[a].doctrine)).comp
	var comp_b: Array = c.rules.doctrine_data(int(c.spelers[b].doctrine)).comp
	var start_a: Array
	var start_b: Array
	var pool_a: Dictionary
	var pool_b: Dictionary
	if c.rules.vol_team_start:
		# Vol-team-model (27 juli): het bord start HOE DAN OOK met de volle
		# samenstelling; de campagne-pool is puur reinforcements en gaat als
		# in-match-spawnvoorraad mee, gecapt op de duel-inzetruimte zodat de
		# eliminatie-check (bord + pool) altijd bereikbaar blijft.
		start_a = comp_a.duplicate()
		start_b = comp_b.duplicate()
		pool_a = _duel_reserve(bezit_a)
		pool_b = _duel_reserve(bezit_b)
	else:
		# Oud pool-model (campagnes van voor 27 juli): arm = kleiner starten.
		start_a = [mini(int(comp_a[0]), int(bezit_a.inf)), mini(int(comp_a[1]), int(bezit_a.cav)), mini(int(comp_a[2]), int(bezit_a.art))]
		start_b = [mini(int(comp_b[0]), int(bezit_b.inf)), mini(int(comp_b[1]), int(bezit_b.cav)), mini(int(comp_b[2]), int(bezit_b.art))]
		pool_a = {"inf": int(bezit_a.inf) - start_a[0], "cav": int(bezit_a.cav) - start_a[1], "art": int(bezit_a.art) - start_a[2]}
		pool_b = {"inf": int(bezit_b.inf) - start_b[0], "cav": int(bezit_b.cav) - start_b[1], "art": int(bezit_b.art) - start_b[2]}
	return duel_regels(c.rules.doctrines, start_a, start_b, pool_a, pool_b, c.cp_van(a), c.cp_van(b),
		duel_honger_vanaf if p_honger_vanaf < 0 else p_honger_vanaf)


## De duel-config uit losse onderdelen (F7.1a): dezelfde voor de campagne
## (duel_rules_voor) en de datarun van de campagne-arena, zodat het orakel
## meet wat de campagne speelt. start = de opstelling op het bord, pool = de
## reserve die mee het veld op kan, cp = het CP-saldo van elke kant.
static func duel_regels(doctrines: Dictionary, start_a: Array, start_b: Array, pool_a: Dictionary,
		pool_b: Dictionary, cp_a: int, cp_b: int, honger_vanaf: int) -> RulesConfig:
	return RulesConfig.from_dict({"honger_vanaf_cyclus": honger_vanaf,
		"basis_hp": {"cav": 2},  # C12: bigbro altijd minstens 2 HP, kaart erbovenop
		"stat_bonus": {"cav": {"attack": 2}},  # 4.3.7: bigbro +2 attack bovenop de kaart (4.3.6 gaf ook +2 stamina: havenrace; 4.3.5: minstens 2/2)
		# C17: de facties van DEZE campagne mee het bord op. Zonder dit blok
		# vielen kaarten, budget en perks in elk campagne-duel terug op de
		# kale tabel, terwijl de trainer en de arena wel de override maten.
		"doctrines": doctrines,
		"campaign": {
		"pool_model": "punten",  # C11: reserve = puntenpot (typed pools op waarde omgezet)
		"comp_override": {"1": start_a, "2": start_b},
		"pools": {"1": pool_a, "2": pool_b},
		"cp": {"1": cp_a, "2": cp_b},
	}})


## De reinforcements die dit duel mee het veld op kunnen: per type het bezit,
## totaal gecapt op de spawn-ruimte van één duel (duel_spawn_totaal_max) in
## vaste volgorde inf -> cav -> art (deterministisch).
func _duel_reserve(bezit: Dictionary) -> Dictionary:
	var ruimte: int = c.rules.duel_spawn_totaal_max
	var uit := {"inf": 0, "cav": 0, "art": 0}
	for sleutel in ["inf", "cav", "art"]:
		var n: int = mini(int(bezit[sleutel]), ruimte)
		uit[sleutel] = n
		ruimte -= n
	return uit


## De uitkomst van een uitgespeeld duel per bord-kant ("1" en "2"): winnaar,
## methode, verliezen, ingezette reserve, CP-verschil (met het winsttarief) en
## buit. Gedeeld door de campagne (verwerk_duel_uitslag) en de datarun van de
## campagne-arena (F7.1a). cp_1/cp_2 = het CP-saldo bij de start.
static func duel_uitkomst(s: GameState, winnaar_kant: int, cp_1: int, cp_2: int, vol_team: bool) -> Dictionary:
	# Methode bepalen (zoals de arena-metrics). V0 (3 augustus): een duel kent
	# alleen haven en eliminatie (opgeven telt als eliminatie, zie beneden).
	var methode := "eliminatie"
	if Rules.count_pawns_in_haven(s, winnaar_kant) >= s.rules.pawns_in_haven_to_win:
		methode = "haven"
	elif String(s.eind_reden) == "resign":
		# Opgeven telt voor de winnaar als eliminatie (roem en CP), anders is
		# opgeven een goedkope manier om zijn winst te drukken.
		methode = "resign"
	# Verliezen per type = geëlimineerde pionnen (voor het battlereport; onder
	# het vol-team-model kosten die geen pool meer — de inzet doet dat).
	var verliezen: Dictionary = {"1": {"inf": 0, "cav": 0, "art": 0}, "2": {"inf": 0, "cav": 0, "art": 0}}
	for pawn in s.pawns.values():
		if not pawn.is_eliminated:
			continue
		var eigenaar: String = "1" if pawn.owner_id == Constants.PLAYER_1 else "2"
		var sleutel: String = ["inf", "cav", "art"][pawn.unit_type]
		verliezen[eigenaar][sleutel] = int(verliezen[eigenaar][sleutel]) + 1
	# Vol-team-model: ingezette reinforcements = alle ooit-gespawnde pionnen =
	# totaal pionnen van dit type - de startopstelling (comp_override).
	var inzet: Dictionary = {}
	if vol_team:
		inzet = {"1": {"inf": 0, "cav": 0, "art": 0}, "2": {"inf": 0, "cav": 0, "art": 0}}
		var totaal: Dictionary = {"1": [0, 0, 0], "2": [0, 0, 0]}
		for pawn in s.pawns.values():
			var eigenaar: String = "1" if pawn.owner_id == Constants.PLAYER_1 else "2"
			totaal[eigenaar][pawn.unit_type] += 1
		for kant in [["1", Constants.PLAYER_1], ["2", Constants.PLAYER_2]]:
			var comp: Array = s.doctrine_data_of(int(kant[1])).comp
			for t in 3:
				inzet[kant[0]][["inf", "cav", "art"][t]] = maxi(0, int(totaal[kant[0]][t]) - int(comp[t]))
	# CP-delta: eindsaldo - startsaldo, plus het winst-tarief (D13).
	var cp_delta: Dictionary = {
		"1": int(s.cp.get(Constants.PLAYER_1, cp_1)) - cp_1,
		"2": int(s.cp.get(Constants.PLAYER_2, cp_2)) - cp_2,
	}
	if winnaar_kant == Constants.PLAYER_1 or winnaar_kant == Constants.PLAYER_2:
		var tarief: int = 0
		if methode == "haven":
			tarief = int(s.rules.campaign.get("cp_haven", 8))
		elif methode == "eliminatie":
			tarief = int(s.rules.campaign.get("cp_eliminatie", 4))
		cp_delta[str(winnaar_kant)] = int(cp_delta[str(winnaar_kant)]) + tarief
	# C15-buit in de campagne (7 september). In het duel groeit de reserve
	# door buit en krimpt hij door spawns; de campagne boekt alleen de inzet
	# af. Zonder de buit erbij te boeken zakt de campagnepool onder nul zodra
	# een speler zijn buit in het duel uitgeeft (gemeten in SoloTests: pools
	# van -6, waarna een LEEG testament strandde op "boven de helft van het
	# bezit" en de campagne muurvast stond). Spawnen is de enige uitgave en
	# buit de enige inkomst, dus buit = eindreserve - startreserve + inzet.
	var buit: Dictionary = {}
	if vol_team:
		for kant in [["1", Constants.PLAYER_1], ["2", Constants.PLAYER_2]]:
			var kosten: int = 0
			for t in 3:
				kosten += int(inzet[kant[0]][["inf", "cav", "art"][t]]) * s.spawn_kosten(t)
			var pt: int = s.pool_total(int(kant[1])) - _duel_startpunten(s, int(kant[1])) + kosten
			if pt > 0:
				buit[kant[0]] = pt
	# De reserve waarmee elke kant het duel in ging (punten): het kaartje in de
	# tijdlijn toont welk deel ervan verloren ging (27 september).
	var reserve: Dictionary = {"1": _duel_startpunten(s, Constants.PLAYER_1),
		"2": _duel_startpunten(s, Constants.PLAYER_2)}
	return {"winnaar_kant": winnaar_kant, "methode": methode, "verliezen": verliezen,
		"inzet": inzet, "cp_delta": cp_delta, "buit": buit, "cycli": s.cycle, "reserve": reserve}


## Een regel voor duels.jsonl (F7.1a, de data van het duel-orakel): de invoer
## van het duel (facties, reserve per type, CP, honger) en de uitkomst per kant.
static func duel_record(fa: int, fb: int, rules: RulesConfig, cp_a: int, cp_b: int,
		u: Dictionary, ai: String, ms: int) -> Dictionary:
	var pools: Dictionary = (rules.campaign as Dictionary).get("pools", {})
	return {"fa": fa, "fb": fb, "ra": pools.get("1", {}), "rb": pools.get("2", {}),
		"cpa": cp_a, "cpb": cp_b, "honger": rules.honger_vanaf_cyclus, "ai": ai,
		"w": int(u.winnaar_kant), "m": String(u.methode), "cycli": int(u.cycli),
		"inzet": u.inzet, "cpd": u.cp_delta, "buit": u.buit, "verl": u.verliezen, "ms": ms}


## Vertaal een uitgespeelde duel-staat naar MATCH_RESULT + battlereport.
## a = bord-P1, b = bord-P2; cp_a/cp_b = campagne-CP bij de start van het duel.
## Gedeeld door de bot-duels én het mens-duel op het echte bord (F3.4b).
func verwerk_duel_uitslag(idx: int, a: int, b: int, cp_a: int, cp_b: int,
		s: GameState, winnaar_kant: int) -> bool:
	# V0 (3 augustus): een duel kent alleen haven en eliminatie, dus er is geen
	# "tiebreak"-default meer. Kwam er toch geen winnaar van het bord, dan is
	# dat een fout in de uitputtingsklok en niet een uitslag die we stil moeten
	# wegboeken.
	if winnaar_kant == -1:
		push_error("SoloDriver: duel %d zonder winnaar teruggekregen (V0: een duel kent geen gelijkspel)" % idx)
		return false
	return _boek_uitkomst(idx, a, b, duel_uitkomst(s, winnaar_kant, cp_a, cp_b, c.rules.vol_team_start))


## Een duel-uitkomst (per kant "1"/"2", zie duel_uitkomst) boeken: het
## battlereport in de feed en MATCH_RESULT door de reducer. Gedeeld door een
## uitgespeeld duel en een getrokken duel uit het orakel.
func _boek_uitkomst(idx: int, a: int, b: int, u: Dictionary) -> bool:
	var winnaar_kant: int = int(u.winnaar_kant)
	var ids := {"1": a, "2": b}
	var methode: String = u.methode
	var verliezen: Dictionary = {str(a): u.verliezen["1"], str(b): u.verliezen["2"]}
	var inzet: Dictionary = {}
	if not (u.inzet as Dictionary).is_empty():
		inzet = {str(a): u.inzet["1"], str(b): u.inzet["2"]}
	var cp_delta: Dictionary = {str(a): u.cp_delta["1"], str(b): u.cp_delta["2"]}
	var buit: Dictionary = {}
	for kant in u.buit:
		buit[str(ids[kant])] = u.buit[kant]
	var winnaar_id: int = -1
	if winnaar_kant == Constants.PLAYER_1:
		winnaar_id = a
	elif winnaar_kant == Constants.PLAYER_2:
		winnaar_id = b
	duels_gespeeld += 1
	var reserve: Dictionary = u.get("reserve", {})
	feed.append({"type": "report", "ronde": c.ronde, "p1": a, "p2": b,
		"winnaar": winnaar_id, "methode": methode, "verliezen": verliezen,
		"cp_delta": cp_delta, "inzet": inzet, "buit": buit, "cycli": int(u.cycli),
		"reserve": {str(a): int(reserve.get("1", 0)), str(b): int(reserve.get("2", 0))}})
	return _pas_toe(CActions.make_match_result(idx, winnaar_id, methode, verliezen, cp_delta, inzet, buit), -1)


## Startreserve van een duel-kant in punten, uit de expliciete typed pool die
## duel_rules_voor meegaf: dezelfde omrekening als GameState.init_pools
## (soldaat 1 / ruiter 2 / kanon 3).
static func _duel_startpunten(s: GameState, kant: int) -> int:
	var tabel = s.rules.campaign.get("pools", null)
	if not (tabel is Dictionary) or not tabel.has(str(kant)):
		return 0
	var ex = tabel[str(kant)]
	if not (ex is Dictionary):
		return int(ex)
	var pt: int = 0
	for t in 3:
		pt += int(ex.get(["inf", "cav", "art"][t], 0)) * s.spawn_kosten(t)
	return pt


## Bot-vs-bot-duel op vol tempo: het campagne-bezit van beide vechters wordt
## de duel-config (C2/C7); de uitkomst gaat als MATCH_RESULT + battlereport terug.
## "l1"/"l2" spelen via AgentRunner (de F1-arena-route: view + legal_actions +
## Reducer.apply — orde-van-grootte sneller dan de legacy MatchRunner-route).
func _speel_duel(idx: int, a: int, b: int) -> void:
	_duel_teller += 1
	bezig_met = tr("SOLO_BUSY_BOT_DUEL") % [
		idx + 1, c.duels_deze_ronde.size(),
		String(c.spelers[a].naam), String(c.spelers[b].naam)]
	var cp_a: int = c.cp_van(a)
	var cp_b: int = c.cp_van(b)
	var rules := duel_rules_voor(a, b, bot_duel_honger_vanaf)
	if duel_modus == "orakel" and orakel != null:
		var pools: Dictionary = (rules.campaign as Dictionary).get("pools", {})
		var u: Dictionary = orakel.trek(int(c.spelers[a].doctrine), int(c.spelers[b].doctrine),
			pools.get("1", {}), pools.get("2", {}), cp_a, cp_b, _rng.fork("orakel_%d" % _duel_teller))
		if not u.is_empty():
			bezig_met = ""
			_boek_uitkomst(idx, a, b, u)
			if duel_log != null:
				duel_log.append(duel_record(int(c.spelers[a].doctrine), int(c.spelers[b].doctrine), rules,
					cp_a, cp_b, u, "orakel", 0))
			return
		# Leeg orakel: dan toch echt spelen (de push_error staat in DuelOrakel.trek).
	var seed_v: int = _rng.fork("duel_%d" % _duel_teller).randi_range(1, 1 << 30)
	var t0 := Time.get_ticks_msec()
	var uit: Array = speel_duel_staat(duel_ai, int(c.spelers[a].doctrine), int(c.spelers[b].doctrine),
		seed_v, rules, duel_max_steps)
	var eind_staat: GameState = uit[0]
	var winnaar_kant: int = int(uit[1])
	var ms: int = Time.get_ticks_msec() - t0
	bezig_met = ""
	verwerk_duel_uitslag(idx, a, b, cp_a, cp_b, eind_staat, winnaar_kant)
	if duel_log != null and winnaar_kant != -1:
		duel_log.append(duel_record(int(c.spelers[a].doctrine), int(c.spelers[b].doctrine), rules,
			cp_a, cp_b, duel_uitkomst(eind_staat, winnaar_kant, cp_a, cp_b, c.rules.vol_team_start),
			duel_ai, ms))


## Speel een duel uit met bots van niveau `ai` ("l1"/"l2" via AgentRunner,
## "easy"/"medium" via MatchRunner). Geeft [eindstaat, winnaar-kant]. Gedeeld
## door de campagne en de datarun van de campagne-arena (F7.1a).
static func speel_duel_staat(ai: String, fa: int, fb: int, seed_v: int, rules: RulesConfig,
		max_steps: int) -> Array:
	if ai == "l1" or ai == "l2":
		var runner := AgentRunner.new(_duel_agent_voor(ai), _duel_agent_voor(ai), fa, fb, seed_v, rules)
		runner.max_steps = max_steps
		runner.run()
		return [runner.state(), runner.winner]
	var ai_script = AIEasyScript if ai == "easy" else AIMediumScript
	var mr := MatchRunner.new(ai_script.new(), ai_script.new(), fa, fb, seed_v, rules)
	mr.max_steps = max_steps
	while not mr.done:
		mr.step()
	return [mr.state(), mr.winner]


static func _duel_agent_voor(ai: String) -> Agent:
	return AgentL2.new() if ai == "l2" else AgentL1.new()
