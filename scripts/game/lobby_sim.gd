extends RefCounted

## Oefenen: de lobby van een ONLINE campagne, zonder server (10 november).
## De echte lobby komt met F5.1 (de campagne in de worker); tot die tijd
## speelt dit de andere mensen na, zodat je het scherm uit het ontwerp van
## milestone 4 kunt zien en proberen: 16 stoelen in twee teams van 8, jij
## bent de host op stoel 1 van team blauw, andere mensen komen een voor een
## binnen en melden zich klaar, en als de vultijd om is (of jij als host op
## START NU drukt) worden de lege stoelen bots, zichtbaar gemerkt. Dan telt
## hij af en begint de campagne.
##
## Eigen rng, nooit de globale. De tijd komt van buiten (`tik(ms)`), zodat
## een check hem kan doorspoelen.

const STOELEN := 16
const PER_TEAM := 8
const VUL_SEC := 45.0       # daarna worden lege stoelen bots
const START_SEC := 5.0      # aftel naar de start
const START_NU_SEC := 3.0   # na START NU van de host
## Zoals de roomcodes van de server (auth.ts): geen 0/O en 1/I/L.
const CODE := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
const NAMEN := ["Renard", "Moreau", "Veyron", "Corbin", "Duval", "Lefort", "Marchand", "Rousseau",
	"Girard", "Blanc", "Fabre", "Leroy", "Mercier", "Picard", "Tessier", "Vidal"]
const RANGEN := ["Capt.", "Gen.", "Col.", "Sgt.", "Lt.", "Maj."]

var stoelen: Array = []      # per stoel {soort: "leeg"|"jij"|"mens"|"bot", naam, doctrine, klaar, host, team}
var code: String = ""
var staat: String = "vullen" # "vullen" -> "start" -> gestart
var vul_ms: int = int(VUL_SEC * 1000.0)
var start_ms: int = 0
var gestart: bool = false
var _rng := RandomNumberGenerator.new()
var _plan: Array = []        # [{ms, stoel, klaar_ms}] wie wanneer binnenkomt en klaar meldt
var _tijd_ms: int = 0


func _init(seed_val: int, jouw_naam: String, jouw_doctrine: int) -> void:
	_rng.seed = seed_val
	for i in 5:
		code += CODE[_rng.randi_range(0, CODE.length() - 1)]
	for i in STOELEN:
		stoelen.append({"soort": "leeg", "naam": "", "doctrine": -1, "klaar": false, "host": false,
			"team": 0 if i < PER_TEAM else 1})
	stoelen[0] = {"soort": "jij", "naam": jouw_naam, "doctrine": jouw_doctrine, "klaar": false, "host": true, "team": 0}
	# wie er nog komt: 5 tot 9 mensen, verspreid over de eerste 35 seconden
	var vrij: Array = range(1, STOELEN)
	var aantal: int = _rng.randi_range(5, 9)
	for n in aantal:
		var stoel: int = int(vrij.pop_at(_rng.randi_range(0, vrij.size() - 1)))
		var komt: int = _rng.randi_range(1500, 35000)
		var nooit: bool = _rng.randf() < 0.12
		_plan.append({"ms": komt, "stoel": stoel,
			"klaar_ms": -1 if nooit else komt + _rng.randi_range(1500, 7000),
			"naam": "%s %s" % [RANGEN[_rng.randi_range(0, RANGEN.size() - 1)], NAMEN[_rng.randi_range(0, NAMEN.size() - 1)]],
			"doctrine": _rng.randi_range(0, 5)})


func spelers() -> int:
	var n := 0
	for s in stoelen:
		if String(s.soort) != "leeg":
			n += 1
	return n


func in_team(team: int) -> int:
	var n := 0
	for s in stoelen:
		if int(s.team) == team and String(s.soort) != "leeg":
			n += 1
	return n


func zet_klaar(aan: bool) -> void:
	stoelen[0].klaar = aan


## De host begint nu: de lege stoelen worden bots en de aftel loopt.
func start_nu() -> void:
	if staat != "vullen":
		return
	_naar_start(START_NU_SEC)


func _naar_start(sec: float) -> void:
	for i in STOELEN:
		if String(stoelen[i].soort) == "leeg":
			stoelen[i].soort = "bot"
			stoelen[i].naam = "%s %s" % [RANGEN[_rng.randi_range(0, RANGEN.size() - 1)], NAMEN[_rng.randi_range(0, NAMEN.size() - 1)]]
			stoelen[i].doctrine = _rng.randi_range(0, 5)
			stoelen[i].klaar = true
	_plan = _plan.filter(func(p): return String(stoelen[int(p.stoel)].soort) == "mens")
	staat = "start"
	start_ms = int(sec * 1000.0)


func tik(delta_ms: int) -> void:
	if gestart:
		return
	_tijd_ms += delta_ms
	for p in _plan:
		var s: Dictionary = stoelen[int(p.stoel)]
		if String(s.soort) == "leeg" and staat == "vullen" and _tijd_ms >= int(p.ms):
			s.soort = "mens"
			s.naam = String(p.naam)
			s.doctrine = int(p.doctrine)
		if String(s.soort) == "mens" and not bool(s.klaar) and int(p.klaar_ms) >= 0 and _tijd_ms >= int(p.klaar_ms):
			s.klaar = true
	if staat == "vullen":
		vul_ms = maxi(0, vul_ms - delta_ms)
		if vul_ms <= 0 or spelers() >= STOELEN:
			_naar_start(START_SEC)
	elif staat == "start":
		start_ms = maxi(0, start_ms - delta_ms)
		if start_ms <= 0:
			gestart = true
