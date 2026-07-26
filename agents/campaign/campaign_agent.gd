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


func _w(sleutel: String, standaard: float = 0.0) -> float:
	return float(profiel.get(sleutel, standaard))


## Publieke boekhouding: pool-totaal van eender wie, uit het cview-ledger.
static func pool_uit_ledger(cview: Dictionary, speler: int) -> int:
	var som := 0
	for e in cview.ledger:
		if int(e.speler) == speler:
			som += int(e.inf) + int(e.cav) + int(e.art)
	return som


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
	for kandidaat in vijand_kandidaten:
		var pool := float(pool_uit_ledger(cview, kandidaat))
		var score: float = _w("w_zwakste_vijand") * -pool + _w("w_tank") * pool \
			+ rng.randf() * temp * 10.0
		if score > beste_vs:
			beste_vs = score
			beste_vijand = kandidaat
	# Eigen: sterkste sturen, zelf gaan (berserker), risico-afslag bij armoede.
	var beste_eigen: int = eigen_kandidaten[0]
	var beste_es: float = -1e18
	for kandidaat in eigen_kandidaten:
		var pool := float(pool_uit_ledger(cview, kandidaat))
		var score: float = _w("w_sterkste_eigen") * pool + rng.randf() * temp * 10.0
		if kandidaat == speler_id:
			score += _w("w_zelf") * 20.0 - _w("risico_afslag") * maxf(0.0, 25.0 - pool)
		if score > beste_es:
			beste_es = score
			beste_eigen = kandidaat
	return {"eigen": beste_eigen, "vijand": beste_vijand}


## Donaties aan genomineerde teamgenoten (binnen de caps van de reducer).
## Retourneert een lijst DONATE-acties (mag leeg zijn: houden is een keuze).
func kies_donaties(cview: Dictionary) -> Array:
	var vrijgevigheid: float = _w("vrijgevigheid")
	if vrijgevigheid <= 0.01:
		return []
	var mijn_team: int = int(cview.spelers[str(speler_id)].team)
	var doelen: Array = []
	for duel in cview.duels:
		for kant in ["p1", "p2"]:
			var id := int(duel[kant])
			if id != speler_id and int(cview.spelers[str(id)].team) == mijn_team \
					and String(cview.spelers[str(id)].status) == "actief":
				doelen.append(id)
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
	return String(lijst[rng.randi_range(0, lijst.size() - 1)])
