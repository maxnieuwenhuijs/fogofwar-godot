class_name DuelOrakel
extends RefCounted

## F7.1b: het duel-orakel (docs/F7-campagnetrainer.md §3). Een verzameling
## echt gespeelde campagne-duels (`data/duel_orakel.json`, gebouwd door
## `tools/campagne/maak_orakel.py`). Voor een nieuw duel trekt het een
## gespeeld duel uit hetzelfde factiepaar met ongeveer hetzelfde reserve- en
## CP-verschil (dezelfde zoekregel als het script) en past de uitkomst aan op
## de reserve en de CP van dit duel. Alleen voor bots in de campagne-arena en
## de trainer: de mens speelt altijd echt, en de kampioen van de trainer wordt
## altijd op echte duels nagemeten.

const STANDAARD := "res://data/duel_orakel.json"
## Zoveel gespeelde duels wil het orakel minstens om uit te trekken; is de
## emmer dunner, dan kijkt het steeds een emmer verder.
const MIN_KANDIDATEN := 8
const TYPEN := ["inf", "cav", "art"]
const PUNTEN := [1, 2, 3]

# Kolommen van een rij (zie "velden" in het bestand).
const K_FA := 0
const K_FB := 1
const K_RES_A := 2
const K_RES_B := 3
const K_CP_A := 4
const K_CP_B := 5
const K_W := 6
const K_M := 7
const K_CYCLI := 8
const K_INZET_A := 9    # 3 kolommen
const K_INZET_B := 12   # 3
const K_CPD_A := 15
const K_CPD_B := 16
const K_BUIT_A := 17
const K_BUIT_B := 18
const K_VERL_A := 19    # 3
const K_VERL_B := 22    # 3
const K_RA := 25        # 3: de reserve per type van het gemeten duel
const K_RB := 28        # 3

var rijen: Array = []
var info: Dictionary = {}
var _res_stap := 3
var _res_max := 15
var _cp_stap := 6
var _cp_max := 24
var _per_paar: Dictionary = {}   # "fa|fb" -> {Vector2i(er, ec): [rij-indexen]}
var _alle: Dictionary = {}       # Vector2i(er, ec) -> [rij-indexen] (paar zonder data)

static var _cache: Dictionary = {}


## Het orakel uit een bestand (een keer per proces ingelezen). Null als het
## bestand er niet is of niet klopt. Geen verwijzing naar de eigen klassenaam:
## die kent een headless run pas als de editor de klasse heeft ingeschreven.
static func laad(pad: String = STANDAARD) -> RefCounted:
	if _cache.has(pad):
		return _cache[pad]
	if not FileAccess.file_exists(pad):
		push_error("DuelOrakel: %s bestaat niet (draai de datarun en tools/campagne/maak_orakel.py)" % pad)
		return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(pad))
	if not (data is Dictionary) or not (data.get("rijen") is Array):
		push_error("DuelOrakel: %s is geen orakel" % pad)
		return null
	var o = load("res://scripts/training/duel_orakel.gd").new()
	o.rijen = data.rijen
	var emmers: Dictionary = data.get("emmers", {})
	o._res_stap = int(emmers.get("res_stap", 3))
	o._res_max = int(emmers.get("res_max", 15))
	o._cp_stap = int(emmers.get("cp_stap", 6))
	o._cp_max = int(emmers.get("cp_max", 24))
	o.info = {"pad": pad, "duels": int(data.get("duels", 0)), "rijen": o.rijen.size(),
		"ai": data.get("ai", []), "honger": data.get("honger", [])}
	o._bouw_index()
	_cache[pad] = o
	return o


func _bouw_index() -> void:
	for i in rijen.size():
		var rij: Array = rijen[i]
		var e := Vector2i(_emmer(int(rij[K_RES_A]) - int(rij[K_RES_B]), _res_stap, _res_max),
			_emmer(int(rij[K_CP_A]) - int(rij[K_CP_B]), _cp_stap, _cp_max))
		var paar := "%d|%d" % [int(rij[K_FA]), int(rij[K_FB])]
		if not _per_paar.has(paar):
			_per_paar[paar] = {}
		var emmers: Dictionary = _per_paar[paar]
		if not emmers.has(e):
			emmers[e] = []
		(emmers[e] as Array).append(i)
		if not _alle.has(e):
			_alle[e] = []
		(_alle[e] as Array).append(i)


## floor(x + 0,5), net als het script (niet round: Python rondt 0,5 naar even).
func _emmer(verschil: int, stap: int, maximum: int) -> int:
	var v := clampi(verschil, -maximum, maximum)
	return int(floor(float(v) / float(stap) + 0.5))


static func punten(pool: Dictionary) -> int:
	return int(pool.get("inf", 0)) + 2 * int(pool.get("cav", 0)) + 3 * int(pool.get("art", 0))


## De gemeten duels die bij dit duel passen: zelfde factiepaar, eerst dezelfde
## emmer, dan steeds wijder (Manhattan in emmers); geen data voor het paar =
## alle paren.
func kandidaten(fa: int, fb: int, res_a: int, res_b: int, cp_a: int, cp_b: int) -> Array:
	var doel := Vector2i(_emmer(res_a - res_b, _res_stap, _res_max), _emmer(cp_a - cp_b, _cp_stap, _cp_max))
	var emmers: Dictionary = _per_paar.get("%d|%d" % [fa, fb], {})
	if emmers.is_empty():
		emmers = _alle
	var uit: Array = []
	# Tot 20: twee emmers liggen hooguit 10 + 8 stappen uit elkaar.
	for straal in 21:
		for e in emmers:
			var v: Vector2i = e
			if absi(v.x - doel.x) + absi(v.y - doel.y) == straal:
				uit.append_array(emmers[e])
		if uit.size() >= MIN_KANDIDATEN:
			return uit
	return uit


## De winkans van kant a volgens het orakel (voor de trainer: wat een bot
## verwacht als hij een paar kiest).
func winkans(fa: int, fb: int, pool_a: Dictionary, pool_b: Dictionary, cp_a: int, cp_b: int) -> float:
	var kand := kandidaten(fa, fb, punten(pool_a), punten(pool_b), cp_a, cp_b)
	if kand.is_empty():
		return 0.5
	var w := 0
	for i in kand:
		if int(rijen[i][K_W]) == 1:
			w += 1
	return float(w) / float(kand.size())


## Een duel trekken: dezelfde vorm als SoloDriver.duel_uitkomst (per kant "1"
## en "2"), zodat de campagne hem boekt als een echt duel.
func trek(fa: int, fb: int, pool_a: Dictionary, pool_b: Dictionary, cp_a: int, cp_b: int,
		rng: SeededRng) -> Dictionary:
	var kand := kandidaten(fa, fb, punten(pool_a), punten(pool_b), cp_a, cp_b)
	if kand.is_empty():
		push_error("DuelOrakel: leeg orakel")
		return {}
	var rij: Array = rijen[int(kand[rng.randi_range(0, kand.size() - 1)])]
	var buit := {}
	if int(rij[K_BUIT_A]) > 0:
		buit["1"] = int(rij[K_BUIT_A])
	if int(rij[K_BUIT_B]) > 0:
		buit["2"] = int(rij[K_BUIT_B])
	return {
		"winnaar_kant": int(rij[K_W]),
		"methode": String(rij[K_M]),
		"cycli": int(rij[K_CYCLI]),
		"verliezen": {"1": _per_type(rij, K_VERL_A), "2": _per_type(rij, K_VERL_B)},
		"inzet": {"1": _inzet(rij, K_INZET_A, K_RA, pool_a, int(buit.get("1", 0))),
			"2": _inzet(rij, K_INZET_B, K_RB, pool_b, int(buit.get("2", 0)))},
		# Je kunt niet meer CP kwijtraken dan je had.
		"cp_delta": {"1": maxi(-cp_a, int(rij[K_CPD_A])), "2": maxi(-cp_b, int(rij[K_CPD_B]))},
		"buit": buit,
	}


func _per_type(rij: Array, kolom: int) -> Dictionary:
	return {"inf": int(rij[kolom]), "cav": int(rij[kolom + 1]), "art": int(rij[kolom + 2])}


## De ingezette reserve voor DIT duel: hetzelfde aandeel van de reserve (in
## punten) als in het gemeten duel. Wie toen alles inzette (de verliezer die
## tot de laatste man spawnde) zet nu ook alles in; daar hangt de uitval in de
## campagne aan (C3). Een aandeel boven 1 (betaald uit buit) mag, maar nooit
## meer dan de reserve plus de buit (anders zakt de campagnepool onder nul).
## De soorten in de volgorde waarin het gemeten duel ze inzette.
func _inzet(rij: Array, k_inzet: int, k_res: int, pool: Dictionary, buit: int) -> Dictionary:
	var kosten_toen := 0
	var res_toen := 0
	for t in 3:
		kosten_toen += int(rij[k_inzet + t]) * PUNTEN[t]
		res_toen += int(rij[k_res + t]) * PUNTEN[t]
	var res_nu: int = punten(pool)
	var aandeel: float = 0.0
	if res_toen > 0:
		aandeel = float(kosten_toen) / float(res_toen)
	elif kosten_toen > 0:
		aandeel = 1.0
	var doel: int = mini(res_nu + buit, int(round(aandeel * float(res_nu))))
	var volgorde: Array = [0, 1, 2]
	volgorde.sort_custom(func(a, b) -> bool:
		return int(rij[k_inzet + a]) * PUNTEN[a] > int(rij[k_inzet + b]) * PUNTEN[b])
	var uit := {"inf": 0, "cav": 0, "art": 0}
	var over: int = doel
	for t in volgorde:
		var n: int = mini(maxi(0, int(pool.get(TYPEN[t], 0))), over / PUNTEN[t])
		uit[TYPEN[t]] = n
		over -= n * PUNTEN[t]
	if over > 0:
		uit["inf"] = int(uit["inf"]) + over  # uit de buit betaald, als soldaten
	return uit


func _kosten(inzet: Dictionary) -> int:
	var k := 0
	for t in 3:
		k += int(inzet[TYPEN[t]]) * PUNTEN[t]
	return k
