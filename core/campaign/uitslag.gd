extends RefCounted

## F6.0-P1 (29 september): de uitslag van een afgelopen campagne per speler,
## de grondstof voor de punten (docs/F6-punten-masterplan.md). Puur: leest
## alleen de eindstaat, dus de hub, de campagnetrainer en straks de server
## rekenen precies hetzelfde. Aanspreken via preload (geen class_name: headless
## kent een nieuwe klasse pas als de editor hem inschreef).
##
## Per speler:
##   team, team_won     zijn team, en of dat team de oorlog won
##   roem               zijn roem (C5)
##   kampioen           de kampioen
##   burgeroorlog_over  0 = niet in de burgeroorlog gevallen; 1 = kampioen;
##                      anders hoeveel spelers zijn bracketronde begon
##   stunts             hoe vaak hij in de burgeroorlog een hogere plek versloeg
##   laatste_stand      verliezend team en pas in de laatste ronde gevallen
##   dank               de kampioen bedankte hem
##   koningsmaker       zijn testament ging naar de latere kampioen (eigen team)
##   testament_vijand   zijn testament ging (ook) naar de vijand


static func van(c: CState) -> Dictionary:
	var uit: Dictionary = {}
	if c.winnaar < 0 or not c.spelers.has(c.winnaar):
		return uit
	var win_team: int = int(c.spelers[c.winnaar].team)
	# De duels van een ronde zijn gelijktijdig, dus "laatste stand" is iedereen
	# van het verliezende team die pas in de laatste ronde viel.
	var laatste_ronde: int = -1
	for sid in c.spelers:
		if int(c.spelers[sid].team) != win_team and c.uitval.has(int(sid)):
			laatste_ronde = maxi(laatste_ronde, int(c.uitval[int(sid)].ronde))
	for sid in c.spelers:
		var id: int = int(sid)
		var team: int = int(c.spelers[id].team)
		var val: Dictionary = c.uitval.get(id, {})
		var over: int = 0
		if id == c.winnaar:
			over = 1
		elif bool(val.get("burgeroorlog", false)):
			over = int(val.get("over", 0))
		var koningsmaker := false
		var naar_vijand := false
		for ontvanger in c.testament_naar.get(id, []):
			var o: int = int(ontvanger)
			if int(c.spelers.get(o, {}).get("team", -1)) != team:
				naar_vijand = true
			elif o == c.winnaar:
				koningsmaker = true
		uit[id] = {
			"team": team,
			"team_won": team == win_team,
			"roem": c.punten_van(id),
			"kampioen": id == c.winnaar,
			"burgeroorlog_over": over,
			"stunts": int(c.stunts.get(id, 0)),
			"laatste_stand": team != win_team and not val.is_empty() and int(val.ronde) == laatste_ronde,
			"dank": c.dank_af and c.dank_naar == id,
			"koningsmaker": koningsmaker,
			"testament_vijand": naar_vijand,
		}
	return uit


## Wie gaf wie wat, uit het grootboek: {gever: {ontvanger: waarde}}, met waarde =
## versterkingspunten (soldaat 1, ruiter 2, kanon 3) plus CP, over donaties en
## testamenten samen. De reducer boekt elke gift als twee regels achter elkaar:
## eerst de gever (min), dan de ontvanger (plus).
static func giften(c: CState) -> Dictionary:
	var uit: Dictionary = {}
	var i: int = 0
	while i < c.ledger.size() - 1:
		var a: Dictionary = c.ledger[i]
		var b: Dictionary = c.ledger[i + 1]
		var reden: String = String(a.reason)
		if (reden == "donate" or reden == "testament") and String(b.reason) == reden \
				and _waarde(a) < 0 and _waarde(b) > 0:
			var gever: int = int(a.speler)
			var ontvanger: int = int(b.speler)
			var per_gever: Dictionary = uit.get(gever, {})
			per_gever[ontvanger] = int(per_gever.get(ontvanger, 0)) + _waarde(b)
			uit[gever] = per_gever
			i += 2
			continue
		i += 1
	return uit


static func _waarde(e: Dictionary) -> int:
	return int(e.inf) + 2 * int(e.cav) + 3 * int(e.art) + int(e.cp)
