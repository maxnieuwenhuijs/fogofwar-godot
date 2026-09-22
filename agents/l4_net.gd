class_name AgentL4
extends AgentL2

# L4 neuraal (22 september) -- dezelfde 1-ply greedy als L2, maar de waarde
# van een na-staat komt uit een geleerd netje (NeuraalNet op Kenmerken) in
# plaats van uit de handgeschreven evaluate() met 42 gewichten.
#
# Alles buiten de actiefase (opstelling, kaarten, CP-bod, koppelen, spawnen)
# doet nog L2: dat zijn aparte beslissingen met eigen leerbare knoppen, en
# die zijn niet de bottleneck. In de actiefase (en de gratis Wolf-stap) kiest
# het netje. Ontbreekt het netje (of past de kenmerk-versie niet), dan speelt
# deze agent als L2 en zegt dat een keer.
#
# Gelijke waarden: de EERSTE kandidaat wint (deterministisch), tenzij
# tie_break_loting aanstaat, dan loot de match-RNG net als bij L2.

var net_pad: String = NeuraalNet.STANDAARD_PAD
var _net: NeuraalNet = null
var _net_gezocht: bool = false
var _gewaarschuwd: bool = false

## Tweetraps (22 september, na de tiecheck): L2 loot bij 48% van zijn
## beslissingen tussen zetten met exact dezelfde score. Een imitatie-netje
## reproduceert die score, maar kan een loting niet raden. Met een tweede,
## puur op de uitslag getraind WAARDE-netje beslist L4 die lotingen zelf:
## eerst de topgroep op het score-netje (alles binnen `tie_eps` van de
## hoogste), daarbinnen de hoogste waarde. Leeg pad = geen tweede trap.
## Pad-vorm voor de arena: "l4:<score.json>+<waarde.json>".
var waarde_pad: String = ""
var tie_eps: float = 0.3
var _waarde_net: NeuraalNet = null

## Meetgereedschap: hoeveel netje-beslissingen, hoeveel kandidaten totaal,
## en hoe vaak het waarde-netje een topgroep van meer dan een besliste.
var beslissingen: int = 0
var kandidaten_totaal: int = 0
var lotingen: int = 0


func _init(pad: String = "") -> void:
	if pad != "":
		var plus: int = pad.find("+")
		if plus > 0:
			net_pad = pad.substr(0, plus)
			waarde_pad = pad.substr(plus + 1)
		else:
			net_pad = pad


func heeft_net() -> bool:
	_zoek_net()
	return _net != null


func _zoek_net() -> void:
	if _net_gezocht:
		return
	_net_gezocht = true
	_net = NeuraalNet.laad(net_pad)
	if _net == null:
		if not _gewaarschuwd:
			_gewaarschuwd = true
			push_warning("AgentL4: geen netje op %s, speelt als L2" % net_pad)
		return
	if not _versie_ok(_net, net_pad):
		_net = null
		return
	if waarde_pad != "":
		_waarde_net = NeuraalNet.laad(waarde_pad)
		if _waarde_net == null:
			push_warning("AgentL4: geen waarde-netje op %s, lotingen vallen op de eerste kandidaat" % waarde_pad)
		elif not _versie_ok(_waarde_net, waarde_pad):
			_waarde_net = null


func _versie_ok(net: NeuraalNet, pad: String) -> bool:
	if net.kenmerk_versie != Kenmerken.KENMERK_VERSIE or net.kenmerken != Kenmerken.aantal():
		push_warning("AgentL4: netje %s is kenmerk-versie %d met %d kenmerken, het spel is versie %d met %d; niet gebruikt"
			% [pad, net.kenmerk_versie, net.kenmerken, Kenmerken.KENMERK_VERSIE, Kenmerken.aantal()])
		return false
	return true


func heeft_waarde_net() -> bool:
	_zoek_net()
	return _waarde_net != null


func decide(view: Dictionary, legal: Array, decide_rng: SeededRng) -> Dictionary:
	if legal.is_empty():
		return {}
	_zoek_net()
	if _net == null or int(view.phase) != Phase.Type.ACTION:
		return super.decide(view, legal, decide_rng)
	var ai = _get_ai(view)
	var s: GameState = Agent.reconstruct_state(view)
	if s.pending_wolf_step_pawn != -1:
		var wk: Dictionary = Kenmerken.wolf_kandidaten(s, player_id)
		var idx: int = _beste(wk.kenmerken)
		var doel = wk.doelen[idx]
		return Actions.make_skip_wolf_step() if doel == null else Actions.make_wolf_step(doel)
	var k: Dictionary = Kenmerken.kandidaten(ai, s, player_id)
	if (k.acties as Array).is_empty():
		return legal[0]
	var gekozen: int = _beste(k.kenmerken)
	beslissingen += 1
	kandidaten_totaal += (k.acties as Array).size()
	if beslis_log != null and _beslis_aan_de_beurt():
		beslis_log.schrijf_beslissing(beslis_game, player_id,
			int(view.doctrines.get(str(player_id), 0)), k.kenmerken, gekozen)
	var actie: Dictionary = Agent.legacy_to_action(k.acties[gekozen])
	if actie.is_empty():
		return legal[0]
	return _vertaal_kanon(s, actie)


## Index van de kandidaat met de hoogste netwaarde. Met een waarde-netje:
## de topgroep (binnen tie_eps van de hoogste score) wordt daarop beslist.
func _beste(rijen: Array) -> int:
	var scores: PackedFloat64Array = PackedFloat64Array()
	scores.resize(rijen.size())
	var best_idx: int = 0
	var best_val: float = -INF
	var toppers: Array = []
	for i in rijen.size():
		var v: float = _net.waarde(rijen[i])
		scores[i] = v
		if v > best_val:
			best_val = v
			best_idx = i
			toppers = [i]
		elif tie_break_loting and v == best_val:
			toppers.append(i)
	if _waarde_net != null:
		var groep_idx: int = -1
		var groep_val: float = -INF
		var groep_n: int = 0
		for i in rijen.size():
			if scores[i] < best_val - tie_eps:
				continue
			groep_n += 1
			var w: float = _waarde_net.waarde(rijen[i])
			if w > groep_val:
				groep_val = w
				groep_idx = i
		if groep_n > 1:
			lotingen += 1
		return groep_idx
	if tie_break_loting and toppers.size() > 1:
		return toppers[rng.randi_range(0, toppers.size() - 1)]
	return best_idx
