extends RefCounted

## De klaarmelding voor de start van een campagne (30 september, Max: "toon
## voordat een campagne begint ook met bots en online. Eerst 1 voor 1 de
## matchup die geloot is wie tegen wie speelt en dan moet je ready up drukken
## binnen bepaalde tijd. anders gekickt en nieuwe player zoeken, maar met bots
## geen tijd wachten op speler etc.").
##
## Na de loting van ronde 1 ziet iedereen de paren; dan meldt elke stoel zich
## klaar. Een bot is meteen klaar. Een mens heeft `klaar_sec` (0 = geen klok:
## solo, je eigen campagne). Wie dan nog niet klaar is ligt eruit en er wordt
## `zoek_sec` lang een nieuwe speler gezocht. Die neemt de plek over: team,
## factie en tegenstander blijven, want het paar is al geloot. Hij krijgt
## `vervang_sec` om zich klaar te melden. Vindt het zoeken niemand, dan neemt
## een bot de plek, en die is meteen klaar. Staan alle stoelen op klaar, dan
## begint de campagne.
##
## Pure logica; de tijd komt van buiten, in milliseconden. Solo rekent met de
## klok van de hub. Online (F5.1) draaien dezelfde functies op de server met
## de serverklok, want alleen daar mag een deadline vallen. Er zit geen rng in:
## wie er invalt (een naam) geeft de aanroeper mee (het zoeken), en een bot
## neemt de volgende naam uit `bot_namen`.
##
## Zonder class_name, dus via preload (headless kent een nieuwe klasse pas als
## de editor hem inschreef).

const WACHT := "wacht"     # een mens die nog op KLAAR moet drukken
const KLAAR := "klaar"
const ZOEKT := "zoekt"     # eruit gezet: er wordt een nieuwe speler gezocht
const MENS := "mens"
const BOT := "bot"

## Solo: geen klok (je eigen campagne); de bots zijn meteen klaar.
const SOLO := {"klaar_sec": 0.0, "vervang_sec": 0.0, "zoek_sec": 0.0}
## Voorstel voor online. De echte duren beslist F5 ("exacte deadline-duren per
## fase" staat nog open in het masterplan).
const ONLINE := {"klaar_sec": 30.0, "vervang_sec": 20.0, "zoek_sec": 20.0}

## Per stoel-id: {naam, doctrine, team, soort, status, deadline_ms,
## zoek_tot_ms, vorige}. `vorige` = wie er het laatst uit werd gezet.
var stoelen: Array = []
var paren: Array = []      # [[a, b], ...] uit de loting
var regels: Dictionary = SOLO.duplicate()
var bot_namen: Array = []  # wie er als bot invalt, in deze volgorde
var open_ms: int = -1      # wanneer KLAAR openging (-1: de paren worden nog getoond)
var gestart: bool = false
## Wat er gebeurde, in volgorde: {ms, soort, stoel, naam, oud}, met soort
## klaar, eruit, vervangen, bot of start. Het scherm toont het, de server
## stuurt het mee.
var gebeurd: Array = []
var _bots_ingevallen: int = 0


## spelers: per stoel {naam, doctrine, team, soort ("mens" of "bot")}.
func setup(spelers: Array, p_paren: Array, p_regels: Dictionary = SOLO, p_bot_namen: Array = []) -> void:
	stoelen.clear()
	for sp in spelers:
		var d: Dictionary = sp
		var soort := String(d.get("soort", MENS))
		stoelen.append({
			"naam": String(d.get("naam", "?")), "doctrine": int(d.get("doctrine", 0)),
			"team": int(d.get("team", 0)), "soort": soort,
			"status": KLAAR if soort == BOT else WACHT,
			"deadline_ms": 0, "zoek_tot_ms": 0, "vorige": "",
		})
	paren = p_paren.duplicate(true)
	regels = SOLO.duplicate()
	regels.merge(p_regels, true)
	bot_namen = p_bot_namen.duplicate()
	open_ms = -1
	gestart = false
	gebeurd.clear()
	_bots_ingevallen = 0


## De paren zijn getoond: KLAAR gaat open en de klok van elke wachtende mens
## begint te lopen. Zijn er alleen bots, dan begint de campagne meteen.
func open(nu_ms: int) -> void:
	if open_ms >= 0:
		return
	open_ms = nu_ms
	for st in stoelen:
		if String(st.status) == WACHT:
			st.deadline_ms = _deadline(nu_ms, "klaar_sec")
	_check_start(nu_ms)


## Een mens drukt op KLAAR. Te vroeg (de paren worden nog getoond), dubbel of
## te laat telt niet.
func meld_klaar(stoel: int, nu_ms: int) -> Dictionary:
	if stoel < 0 or stoel >= stoelen.size():
		return _fout("onbekende stoel %d" % stoel)
	if open_ms < 0:
		return _fout("de paren worden nog getoond")
	var st: Dictionary = stoelen[stoel]
	if String(st.status) != WACHT:
		return _fout("stoel %d wacht niet (%s)" % [stoel, st.status])
	if int(st.deadline_ms) > 0 and nu_ms >= int(st.deadline_ms):
		return _fout("te laat")
	st.status = KLAAR
	_gebeur(nu_ms, "klaar", stoel, String(st.naam))
	_check_start(nu_ms)
	return {"ok": true}


## De klok tikt: wie zijn tijd voorbij is ligt eruit (de stoel gaat zoeken),
## en een stoel die te lang zocht krijgt een bot. Geeft terug wat er in deze
## tik gebeurde.
func tik(nu_ms: int) -> Array:
	var voor := gebeurd.size()
	if open_ms < 0 or gestart:
		return []
	for s in stoelen.size():
		var st: Dictionary = stoelen[s]
		if String(st.status) == WACHT and int(st.deadline_ms) > 0 and nu_ms >= int(st.deadline_ms):
			st.vorige = String(st.naam)
			st.status = ZOEKT
			st.deadline_ms = 0
			st.zoek_tot_ms = nu_ms + int(round(float(regels.zoek_sec) * 1000.0))
			_gebeur(nu_ms, "eruit", s, String(st.vorige))
			st.naam = ""
		elif String(st.status) == ZOEKT and nu_ms >= int(st.zoek_tot_ms):
			st.soort = BOT
			st.status = KLAAR
			st.zoek_tot_ms = 0
			st.naam = _bot_naam()
			_gebeur(nu_ms, "bot", s, String(st.naam), String(st.vorige))
	_check_start(nu_ms)
	return gebeurd.slice(voor)


## Het zoeken vond iemand: hij neemt de plek over (team, factie en
## tegenstander blijven) en krijgt `vervang_sec` om klaar te drukken.
func vervang(stoel: int, naam: String, nu_ms: int) -> Dictionary:
	if stoel < 0 or stoel >= stoelen.size():
		return _fout("onbekende stoel %d" % stoel)
	var st: Dictionary = stoelen[stoel]
	if String(st.status) != ZOEKT:
		return _fout("stoel %d zoekt niet (%s)" % [stoel, st.status])
	if nu_ms >= int(st.zoek_tot_ms):
		return _fout("het zoeken is voorbij")
	st.naam = naam
	st.soort = MENS
	st.status = WACHT
	st.zoek_tot_ms = 0
	st.deadline_ms = _deadline(nu_ms, "vervang_sec")
	_gebeur(nu_ms, "vervangen", stoel, naam, String(st.vorige))
	return {"ok": true}


func aantal_klaar() -> int:
	var n := 0
	for st in stoelen:
		if String(st.status) == KLAAR:
			n += 1
	return n


## De stoelen die nog niet klaar zijn (wachten of zoeken), op volgorde.
func niet_klaar() -> Array:
	var uit: Array = []
	for s in stoelen.size():
		if String(stoelen[s].status) != KLAAR:
			uit.append(s)
	return uit


## De eerstvolgende deadline van een stoel die nog iets moet (wachten: zijn
## klaar-deadline, zoeken: het eind van het zoeken). 0 = er loopt geen klok.
func volgende_deadline() -> int:
	var eerste := 0
	for st in stoelen:
		var d := 0
		if String(st.status) == WACHT:
			d = int(st.deadline_ms)
		elif String(st.status) == ZOEKT:
			d = int(st.zoek_tot_ms)
		if d > 0 and (eerste == 0 or d < eerste):
			eerste = d
	return eerste


func to_dict() -> Dictionary:
	return {"stoelen": stoelen.duplicate(true), "paren": paren.duplicate(true),
		"regels": regels.duplicate(), "bot_namen": bot_namen.duplicate(), "open_ms": open_ms,
		"gestart": gestart, "gebeurd": gebeurd.duplicate(true), "bots_ingevallen": _bots_ingevallen}


## Ook uit JSON (daar worden hele getallen floats): alles terug naar int.
func from_dict(d: Dictionary) -> void:
	stoelen.clear()
	for st in d.get("stoelen", []):
		var s: Dictionary = st
		stoelen.append({"naam": String(s.get("naam", "")), "doctrine": int(s.get("doctrine", 0)),
			"team": int(s.get("team", 0)), "soort": String(s.get("soort", MENS)),
			"status": String(s.get("status", WACHT)), "deadline_ms": int(s.get("deadline_ms", 0)),
			"zoek_tot_ms": int(s.get("zoek_tot_ms", 0)), "vorige": String(s.get("vorige", ""))})
	paren.clear()
	for p in d.get("paren", []):
		paren.append([int(p[0]), int(p[1])])
	regels = SOLO.duplicate()
	for k in (d.get("regels", {}) as Dictionary):
		regels[k] = float(d.regels[k])
	bot_namen.clear()
	for n in d.get("bot_namen", []):
		bot_namen.append(String(n))
	open_ms = int(d.get("open_ms", -1))
	gestart = bool(d.get("gestart", false))
	gebeurd.clear()
	for e in d.get("gebeurd", []):
		var g: Dictionary = e
		gebeurd.append({"ms": int(g.get("ms", 0)), "soort": String(g.get("soort", "")),
			"stoel": int(g.get("stoel", -1)), "naam": String(g.get("naam", "")), "oud": String(g.get("oud", ""))})
	_bots_ingevallen = int(d.get("bots_ingevallen", 0))


func _deadline(nu_ms: int, sleutel: String) -> int:
	var sec: float = float(regels.get(sleutel, 0.0))
	return 0 if sec <= 0.0 else nu_ms + int(round(sec * 1000.0))


func _bot_naam() -> String:
	var i := _bots_ingevallen
	_bots_ingevallen += 1
	if i < bot_namen.size():
		return String(bot_namen[i])
	return "Bot %d" % (i + 1)


func _check_start(nu_ms: int) -> void:
	if gestart or open_ms < 0:
		return
	for st in stoelen:
		if String(st.status) != KLAAR:
			return
	gestart = true
	_gebeur(nu_ms, "start", -1, "")


func _gebeur(nu_ms: int, soort: String, stoel: int, naam: String, oud: String = "") -> void:
	gebeurd.append({"ms": nu_ms, "soort": soort, "stoel": stoel, "naam": naam, "oud": oud})


func _fout(tekst: String) -> Dictionary:
	return {"ok": false, "fout": tekst}
