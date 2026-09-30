extends RefCounted

## Oefenen: de klaarmelding van een ONLINE campagne, zonder server (30
## september). Online campagnes komen met F5.1 (de campagne in de worker, de
## deadlines op de server). Tot die tijd speelt dit de andere mensen na, zodat
## je het scherm, de klok, het eruit zetten, het zoeken en het invallen kunt
## zien en proberen. Naast jou zijn MENSEN stoelen "mensen" die op een
## willekeurig moment op KLAAR drukken (een enkeling nooit); de rest is bot.
## Wie eruit ligt krijgt misschien een vervanger (een gast, genoemd zoals de
## server gasten noemt), anders valt er een bot in.
##
## Eigen rng, nooit de globale: met dezelfde seed gebeurt precies hetzelfde,
## ongeacht hoe vaak de klok tikt (er wordt alleen getrokken als er iets
## verandert, in een vaste volgorde).

const Klaarmelding := preload("res://core/campaign/klaarmelding.gd")

## Korter dan het voorstel voor online: je wilt bij het oefenen geen halve
## minuut op een kick wachten.
const REGELS := {"klaar_sec": 20.0, "vervang_sec": 12.0, "zoek_sec": 8.0}
const MENSEN := 7          # andere mensen naast jou
const AFK_KANS := 0.2      # kans dat iemand nooit op KLAAR drukt
const AFK_KANS_INVALLER := 0.1
const VIND_KANS := 0.7     # kans dat het zoeken iemand vindt
## Zoals de gastnamen en roomcodes van de server (auth.ts): geen 0/O en 1/I/L.
const CODE := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"

var mensen: Array = []       # welke stoelen (behalve jij) mensen zijn
var _rng := RandomNumberGenerator.new()
var _plan: Dictionary = {}   # stoel -> seconden na zijn start tot KLAAR (-1 = nooit)
var _start: Dictionary = {}  # stoel -> ms waarop hij begon te wachten
var _vind: Dictionary = {}   # stoel -> {zoek_tot, ms}: wanneer het zoeken iemand vindt (-1 = niemand)


func _init(seed_val: int) -> void:
	_rng.seed = seed_val


## De klaarmelding voor deze campagne: jij, MENSEN andere mensen, de rest bots.
## spelers: per stoel {naam, doctrine, team}; paren uit de loting.
func maak(spelers: Array, paren: Array, jij: int, bot_namen: Array = []) -> Klaarmelding:
	var anderen: Array = []
	for s in spelers.size():
		if s != jij:
			anderen.append(s)
	for i in range(anderen.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = anderen[i]
		anderen[i] = anderen[j]
		anderen[j] = tmp
	mensen = anderen.slice(0, mini(MENSEN, anderen.size()))
	mensen.sort()
	var lijst: Array = []
	for s in spelers.size():
		var sp: Dictionary = (spelers[s] as Dictionary).duplicate()
		sp.soort = Klaarmelding.MENS if (s == jij or mensen.has(s)) else Klaarmelding.BOT
		lijst.append(sp)
	for s in mensen:
		_plan[s] = _trek_plan(AFK_KANS, 1.5, 14.0)
	var km := Klaarmelding.new()
	km.setup(lijst, paren, REGELS, bot_namen)
	return km


## Laat de nagespeelde spelers doen wat ze op dit moment doen. Voor km.tik
## aanroepen: wie op tijd drukt, is dan klaar voordat de klok hem eruit zet.
func stap(km: Klaarmelding, nu_ms: int) -> void:
	if km.open_ms < 0 or km.gestart:
		return
	for s in km.stoelen.size():
		var st: Dictionary = km.stoelen[s]
		match String(st.status):
			Klaarmelding.WACHT:
				if not _plan.has(s):
					continue   # jij: dat doet het scherm
				if not _start.has(s):
					_start[s] = km.open_ms
				var na: float = float(_plan[s])
				if na >= 0.0 and nu_ms >= int(_start[s]) + int(na * 1000.0):
					km.meld_klaar(s, nu_ms)
			Klaarmelding.ZOEKT:
				var zoek: Dictionary = _vind.get(s, {})
				if int(zoek.get("zoek_tot", -1)) != int(st.zoek_tot_ms):
					# Een nieuwe zoektocht voor deze stoel: vindt hij iemand, en wanneer?
					var begin: int = int(st.zoek_tot_ms) - int(float(km.regels.zoek_sec) * 1000.0)
					var ms := -1
					if _rng.randf() < VIND_KANS:
						ms = begin + int(_rng.randf_range(2.0, 6.0) * 1000.0)
					zoek = {"zoek_tot": int(st.zoek_tot_ms), "ms": ms}
					_vind[s] = zoek
				if int(zoek.ms) >= 0 and nu_ms >= int(zoek.ms):
					if bool(km.vervang(s, _gast_naam(), nu_ms).ok):
						_plan[s] = _trek_plan(AFK_KANS_INVALLER, 1.0, 7.0)
						_start[s] = nu_ms


## Voor de plaatjes en checks: deze stoel drukt nooit op KLAAR.
func maak_afk(stoel: int) -> void:
	if _plan.has(stoel):
		_plan[stoel] = -1.0


func _trek_plan(afk: float, van: float, tot: float) -> float:
	if _rng.randf() < afk:
		return -1.0
	return _rng.randf_range(van, tot)


func _gast_naam() -> String:
	var t := "Gast-"
	for i in 4:
		t += CODE[_rng.randi_range(0, CODE.length() - 1)]
	return t
