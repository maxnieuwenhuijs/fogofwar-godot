class_name CampaignAgent
extends RefCounted

# F3.2 — de campagne-bot: beslist nominaties, donaties en testamenten op de
# CVIEW (nooit de echte cstate). Saldi van anderen leest hij zoals een mens
# dat zou doen: door het publieke grootboek op te tellen (de Among Us-skill).
# Persoonlijkheid = gewichten + temperatuur + barks (Personalities).
#
# v1-afwijking van het bouwplan-contract (decide_campaign(cview, legal, rng)):
# campagne-acties zijn combinatorisch (donatie-bedragen, testament-verdeling),
# dus de agent heeft per beslissing een methode; de driver orkestreert.

var speler_id: int = 0
var naam: String = ""
var profiel: Dictionary = {}
var rng: SeededRng = SeededRng.new(7)
## Quick chat (25 september): waar deze bot deze ronde AKKOORD! op zei,
## {soort: [doel-ids]} met soort stuur/pak/doneer/nalaten. De driver zet het
## voor elke keuze. De bot komt het na met kans `loyaliteit`, een trekking per
## toezegging; zonder toezeggingen trekt hij niets extra, dus zonder mens
## speelt alles precies als voorheen.
var toezeggingen: Dictionary = {}
## F7.2a verstand (docs/F7-campagnetrainer.md §2): getrainde gewichten die voor
## alle bots gelden, bovenop het karakter. Leeg = alles speelt precies als
## voorheen (geen extra trekkingen, dezelfde keuzes). Sleutels (zie VERSTAND):
##   w_matchup   de raad kiest het PAAR, met de winkans uit het duel-orakel erbij
##   w_don_nood  geef aan de vechter wiens winkans een gift het meest optilt
##   w_geef      geef naar verhouding meer of minder: vrijgevigheid x (1 + w_geef),
##               dus de gierigaard (0) blijft gierig: karakter blijft karakter
##   w_houden    houd meer voor jezelf als je deze ronde zelf vecht
##   w_ruil      ruil CP boven een reserve om in versterkingen (0 = nooit)
## F6.0-P4 (30 september), eigenbelang voor de burgeroorlog. Beide wegen met de
## druk (0 zolang de vijand minstens zo groot is als je team, 1 als hij weg
## is): vroeg help je je team, vlak voor de burgeroorlog jezelf.
##   w_sparen    geef minder weg naarmate de oorlog gewonnen raakt
##   w_rivaal    werk tegen teamgenoten die boven je staan in de zaaiing: geen
##               versterkingen voor ze, en stuur ze in de raad het duel in
var verstand: Dictionary = {}
## Het duel-orakel voor de winkans (DuelOrakel; null = die termen vallen weg).
var orakel = null

## De sleutels van het verstand met hun grenzen (voor de trainer).
const VERSTAND := {
	"w_matchup": [-2.0, 4.0],
	"w_don_nood": [0.0, 4.0],
	"w_geef": [-0.9, 2.0],
	"w_houden": [0.0, 1.0],
	"w_ruil": [0.0, 1.0],
	"w_sparen": [0.0, 1.0],
	"w_rivaal": [0.0, 2.0],
}
## De knoppen van het eigenbelang (F6.0-P4): alleen de puntentrainer verschuift ze.
const VERSTAND_EIGENBELANG := ["w_sparen", "w_rivaal"]
const VERSTAND_PAD := "res://data/campagne_verstand.json"
static var _verstand_cache = null


func _w(sleutel: String, standaard: float = 0.0) -> float:
	return float(profiel.get(sleutel, standaard))


func _v(sleutel: String) -> float:
	return float(verstand.get(sleutel, 0.0))


## Het getrainde verstand uit data/campagne_verstand.json ({} als het er niet
## is: dan spelen de bots met alleen hun karakter).
static func laad_verstand(pad: String = VERSTAND_PAD) -> Dictionary:
	if _verstand_cache != null and pad == VERSTAND_PAD:
		return _verstand_cache
	var uit := {}
	if FileAccess.file_exists(pad):
		var data = JSON.parse_string(FileAccess.get_file_as_string(pad))
		if data is Dictionary and data.get("gewichten") is Dictionary:
			uit = data.gewichten
	if pad == VERSTAND_PAD:
		_verstand_cache = uit
	return uit


## Saldo van eender wie uit het publieke grootboek: voorraad per soort en CP.
static func saldo_uit_ledger(cview: Dictionary, speler: int) -> Dictionary:
	var pool := {"inf": 0, "cav": 0, "art": 0}
	var cp := 0
	for e in cview.ledger:
		if int(e.speler) == speler:
			pool.inf += int(e.inf)
			pool.cav += int(e.cav)
			pool.art += int(e.art)
			cp += int(e.get("cp", 0))
	return {"pool": pool, "cp": cp}


## De reserve die mee het duel in gaat, zoals de driver hem bouwt
## (_duel_reserve: per soort, samen hooguit `cap` stuks), extra geld erbij.
static func duel_reserve(pool: Dictionary, cap: int = 15, extra_inf: int = 0) -> Dictionary:
	var ruimte := cap
	var uit := {"inf": 0, "cav": 0, "art": 0}
	for sleutel in ["inf", "cav", "art"]:
		var bezit: int = maxi(0, int(pool.get(sleutel, 0)) + (extra_inf if sleutel == "inf" else 0))
		var n: int = mini(bezit, ruimte)
		uit[sleutel] = n
		ruimte -= n
	return uit


## Winkans van `wie` tegen `tegen` volgens het orakel, met `extra` soldaten
## bij `wie` (een gift). 0,5 zonder orakel.
func winkans(cview: Dictionary, wie: int, tegen: int, extra: int = 0) -> float:
	if orakel == null:
		return 0.5
	var a: Dictionary = saldo_uit_ledger(cview, wie)
	var b: Dictionary = saldo_uit_ledger(cview, tegen)
	return orakel.winkans(int(cview.spelers[str(wie)].doctrine), int(cview.spelers[str(tegen)].doctrine),
		duel_reserve(a.pool, 15, extra), duel_reserve(b.pool), maxi(0, int(a.cp)), maxi(0, int(b.cp)))


## Publieke boekhouding: pool-totaal van eender wie, uit het cview-ledger.
static func pool_uit_ledger(cview: Dictionary, speler: int) -> int:
	var som := 0
	for e in cview.ledger:
		if int(e.speler) == speler:
			som += int(e.inf) + int(e.cav) + int(e.art)
	return som


## Hoe dicht de oorlog bij winst is voor mijn team (F6.0-P4): 0 zolang de
## vijand minstens zo groot is als mijn team, 1 als hij weg is (1 - vijand/eigen).
func druk(cview: Dictionary) -> float:
	var mijn_team: int = int(cview.spelers[str(speler_id)].team)
	var eigen := 0
	var vijand := 0
	for id_str in cview.spelers:
		var sp: Dictionary = cview.spelers[id_str]
		if String(sp.status) != "actief":
			continue
		if int(sp.team) == mijn_team:
			eigen += 1
		else:
			vijand += 1
	return clampf(1.0 - float(vijand) / float(maxi(1, eigen)), 0.0, 1.0)


## De plekken in de zaaiing van de burgeroorlog als die vandaag begon, binnen
## een team: {id: plek} met 1 = bovenaan. Roem, dan CP, dan pool, dan id, net
## als CReducer.seed_volgorde. Het eigen team ziet die saldi (team-only).
static func zaai_plekken(cview: Dictionary, team: int) -> Dictionary:
	var leden: Array = []
	var score: Dictionary = {}
	for id_str in cview.spelers:
		var sp: Dictionary = cview.spelers[id_str]
		if int(sp.team) != team or String(sp.status) != "actief":
			continue
		var id := int(String(id_str))
		leden.append(id)
		var cp = sp.get("cp", 0)
		var pool = sp.get("pool", null)
		var stuks: int = 0
		if pool is Dictionary:
			stuks = int(pool.get("inf", 0)) + int(pool.get("cav", 0)) + int(pool.get("art", 0))
		else:
			stuks = pool_uit_ledger(cview, id)
		score[id] = [int(sp.get("punten", 0)), 0 if cp is String else int(cp), stuks]
	leden.sort_custom(func(a, b) -> bool:
		var sa: Array = score[a]
		var sb: Array = score[b]
		for i in 3:
			if int(sa[i]) != int(sb[i]):
				return int(sa[i]) > int(sb[i])
		return a < b)
	var uit: Dictionary = {}
	for i in leden.size():
		uit[leden[i]] = i + 1
	return uit


## Mijn plek in de zaaiing van mijn team (zaai_plekken).
func plek(cview: Dictionary, id: int) -> int:
	return int(zaai_plekken(cview, int(cview.spelers[str(id)].team)).get(id, 0))


## Een gewicht uit het profiel (ook voor de driver: antwoorden in de quick chat).
func gewicht(sleutel: String, standaard: float = 0.0) -> float:
	return _w(sleutel, standaard)


## De toegezegde doelen van een soort die nog geldig zijn en die de bot deze
## keer ook echt nakomt.
func _nagekomen(soort: String, geldig: Array) -> Array:
	var uit: Array = []
	for doel in toezeggingen.get(soort, []):
		if geldig.has(int(doel)) and rng.randf() < _w("loyaliteit", 0.8):
			uit.append(int(doel))
	return uit


## Nominatie-stem: {eigen, vijand} volgens de persoonlijkheid.
func kies_nominatie(cview: Dictionary) -> Dictionary:
	var mijn_team: int = int(cview.spelers[str(speler_id)].team)
	var genomineerd: Array = cview.al_genomineerd
	var eigen_kandidaten: Array = []
	var vijand_kandidaten: Array = []
	for id_str in cview.spelers:
		var sp: Dictionary = cview.spelers[id_str]
		var id := int(String(id_str))
		if String(sp.status) != "actief" or genomineerd.has(id):
			continue
		if int(sp.team) == mijn_team:
			eigen_kandidaten.append(id)
		else:
			vijand_kandidaten.append(id)
	if eigen_kandidaten.is_empty() or vijand_kandidaten.is_empty():
		return {}
	var temp: float = _w("temperatuur", 0.2)
	# Vijand: zwakste (kleine pool) vs de tank laten bloeden (grote pool).
	var beste_vijand: int = vijand_kandidaten[0]
	var beste_vs: float = -1e18
	var vs_score: Dictionary = {}
	for kandidaat in vijand_kandidaten:
		var pool := float(pool_uit_ledger(cview, kandidaat))
		var score: float = _w("w_zwakste_vijand") * -pool + _w("w_tank") * pool \
			+ rng.randf() * temp * 10.0
		vs_score[kandidaat] = score
		if score > beste_vs:
			beste_vs = score
			beste_vijand = kandidaat
	# Eigen: sterkste sturen, zelf gaan (berserker), risico-afslag bij armoede.
	var beste_eigen: int = eigen_kandidaten[0]
	var beste_es: float = -1e18
	var es_score: Dictionary = {}
	for kandidaat in eigen_kandidaten:
		var pool := float(pool_uit_ledger(cview, kandidaat))
		var score: float = _w("w_sterkste_eigen") * pool + rng.randf() * temp * 10.0
		if kandidaat == speler_id:
			score += _w("w_zelf") * 20.0 - _w("risico_afslag") * maxf(0.0, 25.0 - pool)
		es_score[kandidaat] = score
		if score > beste_es:
			beste_es = score
			beste_eigen = kandidaat
	# F6.0-P4: wie boven me staat in de zaaiing mag het duel in (hij riskeert
	# zijn reserves, ik rust), zwaarder naarmate de oorlog gewonnen raakt.
	var rivalen: Array = []
	var w_r := _v("w_rivaal")
	if w_r > 0.0:
		var d := druk(cview)
		if d > 0.0:
			var plekken: Dictionary = zaai_plekken(cview, mijn_team)
			var mijn_plek: int = int(plekken.get(speler_id, 0))
			for e in eigen_kandidaten:
				if e != speler_id and int(plekken.get(e, 0)) < mijn_plek:
					rivalen.append(e)
					es_score[e] = float(es_score[e]) + w_r * d * 20.0
			if not rivalen.is_empty() and orakel == null:
				var beste_r: float = -1e18
				for e in eigen_kandidaten:
					if float(es_score[e]) > beste_r:
						beste_r = float(es_score[e])
						beste_eigen = e
	# Verstand (F7.2a): kies het PAAR, met de winkans uit het orakel erbij.
	# Een rivaal (P4) liefst tegen een vijand waar hij van verliest.
	var w_m := _v("w_matchup")
	if (w_m != 0.0 or not rivalen.is_empty()) and orakel != null:
		var beste_paar: float = -1e18
		var d_r: float = druk(cview) if not rivalen.is_empty() else 0.0
		for e in eigen_kandidaten:
			for v in vijand_kandidaten:
				var kans: float = winkans(cview, e, v)
				var score: float = float(es_score[e]) + float(vs_score[v]) + w_m * 20.0 * (kans - 0.5)
				if rivalen.has(e):
					score -= w_r * d_r * 20.0 * (kans - 0.5)
				if score > beste_paar:
					beste_paar = score
					beste_eigen = e
					beste_vijand = v
	# Toegezegd in de quick chat (Stuur X!, Pak X!): nakomen of niet.
	var stuur := _nagekomen("stuur", eigen_kandidaten)
	if not stuur.is_empty():
		beste_eigen = int(stuur[0])
	var pak := _nagekomen("pak", vijand_kandidaten)
	if not pak.is_empty():
		beste_vijand = int(pak[0])
	return {"eigen": beste_eigen, "vijand": beste_vijand}


## Donaties aan genomineerde teamgenoten (binnen de caps van de reducer).
## Retourneert een lijst DONATE-acties (mag leeg zijn: houden is een keuze).
func kies_donaties(cview: Dictionary) -> Array:
	var vrijgevigheid: float = _w("vrijgevigheid")
	if vrijgevigheid <= 0.01:
		return []
	# Verstand: naar verhouding meer of minder geven, en meer houden als je
	# zelf vecht. Met een leeg verstand verandert hier niets.
	vrijgevigheid = clampf(vrijgevigheid * (1.0 + _v("w_geef")), 0.0, 1.0)
	# F6.0-P4: vlak voor de burgeroorlog houd je meer voor jezelf.
	var d_eigen: float = 0.0
	if _v("w_sparen") > 0.0 or _v("w_rivaal") > 0.0:
		d_eigen = druk(cview)
	if _v("w_sparen") > 0.0:
		vrijgevigheid *= clampf(1.0 - _v("w_sparen") * d_eigen, 0.0, 1.0)
	if _v("w_houden") > 0.0:
		for duel in cview.duels:
			if int(duel.p1) == speler_id or int(duel.p2) == speler_id:
				vrijgevigheid *= clampf(1.0 - _v("w_houden"), 0.0, 1.0)
				break
	var mijn_team: int = int(cview.spelers[str(speler_id)].team)
	var doelen: Array = []
	for duel in cview.duels:
		for kant in ["p1", "p2"]:
			var id := int(duel[kant])
			if id != speler_id and int(cview.spelers[str(id)].team) == mijn_team \
					and String(cview.spelers[str(id)].status) == "actief":
				doelen.append(id)
	# Verstand: de vechter wiens winkans een gift het meest optilt eerst
	# (w_don_nood weegt dat tegen de volgorde van de duels).
	var w_nood := _v("w_don_nood")
	if w_nood > 0.0 and orakel != null and doelen.size() > 1:
		var gift: int = maxi(1, int(floor(int(cview.eigen_pool.inf) * vrijgevigheid)))
		var waarde: Dictionary = {}
		for i in doelen.size():
			var f: int = int(doelen[i])
			waarde[f] = w_nood * 100.0 * _gift_winst(cview, f, gift) - float(i)
		doelen.sort_custom(func(a, b) -> bool: return float(waarde[a]) > float(waarde[b]))
	# F6.0-P4: wie boven me staat in de zaaiing, tref ik straks in de
	# burgeroorlog. Die schuiven achteraan, en bij genoeg druk vallen ze af.
	if _v("w_rivaal") > 0.0 and d_eigen > 0.0 and not doelen.is_empty():
		var plekken: Dictionary = zaai_plekken(cview, mijn_team)
		var mijn_plek: int = int(plekken.get(speler_id, 0))
		var vrienden: Array = []
		var rivalen: Array = []
		for f in doelen:
			if int(plekken.get(int(f), 0)) < mijn_plek:
				rivalen.append(f)
			else:
				vrienden.append(f)
		doelen = vrienden if _v("w_rivaal") * d_eigen >= 0.5 else vrienden + rivalen
	# Toegezegd in de quick chat (Versterking nodig!, Doneer aan X!): die
	# teamgenoot eerst, ook als hij deze ronde niet vecht.
	var beloofd: Array = []
	if toezeggingen.has("doneer"):
		var teamgenoten: Array = []
		for id_str in cview.spelers:
			var sp: Dictionary = cview.spelers[id_str]
			if int(String(id_str)) != speler_id and int(sp.team) == mijn_team \
					and String(sp.status) == "actief":
				teamgenoten.append(int(String(id_str)))
		beloofd = _nagekomen("doneer", teamgenoten)
		if not beloofd.is_empty():
			doelen.erase(beloofd[0])
			doelen.push_front(beloofd[0])
	if doelen.is_empty():
		return []
	var bezit: Dictionary = cview.eigen_pool
	var cp: int = int(cview.eigen_cp)
	# Concentratie 1.0: alles naar het eerste doel; lager: verdelen.
	var doel: int = doelen[0]
	var inf: int = int(floor(int(bezit.inf) * vrijgevigheid))
	var cav: int = int(floor(int(bezit.cav) * vrijgevigheid * 0.5))
	var art: int = 0  # kanonnen geef je niet zomaar weg
	var cp_gift: int = int(floor(cp * vrijgevigheid * 0.3))
	if not beloofd.is_empty() and inf + cav == 0 and int(bezit.inf) > 0:
		inf = 1  # een toezegging kost minstens een soldaat
	# Binnen de harde caps blijven (de reducer weigert anders de hele actie).
	var ontvangen: Dictionary = (cview.donaties_ontvangen as Dictionary).get(str(doel), {"pionnen": 0, "cp": 0})
	var pion_ruimte: int = maxi(0, 10 - int(ontvangen.pionnen))
	var cp_ruimte: int = maxi(0, 3 - int(ontvangen.cp))
	while inf + cav > pion_ruimte and inf + cav > 0:
		if inf >= cav:
			inf -= 1
		else:
			cav -= 1
	cp_gift = mini(cp_gift, cp_ruimte)
	if inf + cav + art + cp_gift == 0:
		return []
	return [CActions.make_donate(doel, inf, cav, art, cp_gift)]


## Wat `gift` soldaten extra aan de winkans van vechter `f` doen (tegen zijn
## tegenstander van deze ronde); 0 als hij niet vecht.
func _gift_winst(cview: Dictionary, f: int, gift: int) -> float:
	for duel in cview.duels:
		if bool(duel.get("klaar", false)):
			continue
		var tegen: int = -1
		if int(duel.p1) == f:
			tegen = int(duel.p2)
		elif int(duel.p2) == f:
			tegen = int(duel.p1)
		if tegen >= 0:
			return winkans(cview, f, tegen, gift) - winkans(cview, f, tegen)
	return 0.0


## F7.2a: CP ruilen voor versterkingen (C11-ruil, in het donatievenster).
## Alleen met verstand (w_ruil > 0): wat boven een reserve uitkomt, in hele
## ruilen van `koers` CP. De reserve krimpt naarmate w_ruil groeit (24 CP bij
## een klein beetje, 0 bij 1).
func kies_ruil(cview: Dictionary, koers: int) -> int:
	var w := _v("w_ruil")
	if w <= 0.0 or koers <= 0:
		return 0
	var reserve: int = int(round(24.0 * clampf(1.0 - w, 0.0, 1.0)))
	var over: int = int(cview.eigen_cp) - reserve
	if over < koers:
		return 0
	return (over / koers) * koers


## Testament: max helft, max 2 ontvangers; loyaliteit bepaalt team of vijand.
func kies_testament(cview: Dictionary) -> Dictionary:
	var bezit: Dictionary = cview.eigen_pool
	var cp: int = int(cview.eigen_cp)
	var mijn_team: int = int(cview.spelers[str(speler_id)].team)
	var naar_team: bool = rng.randf() < _w("loyaliteit", 0.8)
	var kandidaten: Array = []
	for id_str in cview.spelers:
		var sp: Dictionary = cview.spelers[id_str]
		var id := int(String(id_str))
		if id == speler_id or String(sp.status) != "actief":
			continue
		if (int(sp.team) == mijn_team) == naar_team:
			kandidaten.append(id)
	if kandidaten.is_empty():
		# Niemand aan de gekozen kant meer: dan maar de andere kant.
		for id_str in cview.spelers:
			var sp: Dictionary = cview.spelers[id_str]
			if int(String(id_str)) != speler_id and String(sp.status) == "actief":
				kandidaten.append(int(String(id_str)))
	if kandidaten.is_empty():
		return {}
	# Grootste pool eerst (de erfenis moet renderen), max 2 ontvangers.
	kandidaten.sort_custom(func(a, b) -> bool:
		return pool_uit_ledger(cview, a) > pool_uit_ledger(cview, b))
	if naar_team:
		# Toegezegd in de quick chat (Laat het aan mij na): die eerst.
		var beloofd := _nagekomen("nalaten", kandidaten)
		if not beloofd.is_empty():
			kandidaten.erase(beloofd[0])
			kandidaten.push_front(beloofd[0])
	var ontvangers: Array = kandidaten.slice(0, 2)
	var verdeling: Array = []
	var n: int = ontvangers.size()
	for i in n:
		verdeling.append({
			"naar": ontvangers[i],
			"inf": int(floor(int(bezit.inf) * 0.5)) / n,
			"cav": int(floor(int(bezit.cav) * 0.5)) / n,
			"art": int(floor(int(bezit.art) * 0.5)) / n,
			"cp": int(floor(cp * 0.5)) / n,
		})
	return {"verdeling": verdeling, "naar_vijand": not naar_team}


## Bark-tekst voor een trigger; %s wordt door de driver ingevuld.
func bark(trigger: String) -> String:
	var barks: Dictionary = profiel.get("barks", {})
	var lijst: Array = barks.get(trigger, [])
	if lijst.is_empty():
		return ""
	return tr(String(lijst[rng.randi_range(0, lijst.size() - 1)]))
