class_name Kenmerken
extends RefCounted

# L4 neuraal (22 september) -- de kenmerk-extractor.
#
# Zet een (na-)staat om in een vaste rij getallen, gezien vanuit speler `me`.
# Dit is de ENIGE plek waar kenmerken worden berekend: de logger in de arena
# schrijft deze rij weg voor de trainer, en AgentL4 voert dezelfde rij aan het
# netwerk. Python rekent dus nooit zelf kenmerken uit: wat je traint is wat je
# speelt, byte voor byte.
#
# De rij bevat om te beginnen ALLE termen van de L2-evaluatie (AIController.
# evaluate), maar dan ongewogen en per kant apart. Een lineair netwerk op deze
# rij kan L2 dus exact nadoen; alles daarboven (combinaties, drempels) is
# winst die de gewichten van L2 niet kunnen uitdrukken.
#
# Verander je de rij (volgorde, schaal, nieuwe termen): KENMERK_VERSIE
# ophogen. Een netwerk draagt de versie waarop het getraind is en AgentL4
# weigert een netwerk van een andere versie.

const KENMERK_VERSIE: int = 1

## Per kant (eerst ik, dan de vijand) dezelfde lijst; daarna de globale
## termen. Namen zijn documentatie en de kolomkoppen in de trainer.
const KANT_NAMEN: Array[String] = [
	"alive",        # levende pionnen / 10
	"inf",          # infanterie / 10
	"cav",          # cavalerie / 10
	"art",          # artillerie / 10
	"actief",       # gekoppelde (actieve) pionnen / 10
	"hp",           # HP-som van actieve pionnen / 30
	"stamina",      # beschikbare stamina-som / 30
	"attack",       # effectieve attack-som van actieve pionnen / 30
	"in_haven",     # pionnen in de eigen doelhaven
	"guard",        # pionnen op de haven van de ander (bewaking)
	"d1",           # afstand dichtstbijzijnde pion tot de doelhaven / 10
	"d2",           # tweede dichtstbijzijnde / 10
	"prox",         # L2-prox: (11-d1)^2 + 0.6*(11-d2)^2, / 100
	"near3",        # pionnen binnen 3 van de doelhaven / 10
	"gem_d",        # gemiddelde afstand tot de doelhaven / 10
	"risk",         # pionnen die volgende beurt gedood kunnen worden / 10
	"reach",        # actieve pionnen die de haven NU kunnen halen
	"ranged",       # schot-doelwitten in de vuurlijn / 10
	"dragers",      # vaandeldrager + tamboer in leven
	"buit_open",    # buitwaarde van dragers binnen vijandelijk bereik / 4
	"aura",         # actieve pionnen in een eigen aura / 10
	"pool",         # reserve (versterkingspunten) / 20; 0 als onbekend
	"cp",           # CP in de pot / 20; 0 als onbekend
	"pool_bekend",  # 1 als de reserve zichtbaar is (fog: vijand = 0)
]

const GLOBAAL_NAMEN: Array[String] = [
	"cyclus",       # cyclus / 20
	"honger",       # 1 als de honger al knaagt
	"tot_honger",   # cycli tot de honger / 10 (0 als al bezig)
	"ronde",        # ronde in de cyclus / 3
	"wanhoop",      # 1 als ik minder dan 7 pionnen heb (L2-drempel)
	"doc_me_0", "doc_me_1", "doc_me_2", "doc_me_3", "doc_me_4", "doc_me_5",
	"doc_opp_0", "doc_opp_1", "doc_opp_2", "doc_opp_3", "doc_opp_4", "doc_opp_5",
]

const DOCTRINES: int = 6


static func namen() -> Array[String]:
	var uit: Array[String] = []
	for n in KANT_NAMEN:
		uit.append("me_" + n)
	for n in KANT_NAMEN:
		uit.append("opp_" + n)
	for n in GLOBAAL_NAMEN:
		uit.append(n)
	return uit


static func aantal() -> int:
	return KANT_NAMEN.size() * 2 + GLOBAAL_NAMEN.size()


## De kenmerkrij van `state` gezien vanuit `me`. Zuiver: geen RNG, geen
## gewichten, geen zijeffecten op de staat.
static func van_staat(state: GameState, me: int) -> PackedFloat32Array:
	var opp: int = Constants.opponent(me)
	var uit := PackedFloat32Array()
	uit.resize(aantal())
	var i: int = 0
	i = _kant(state, me, opp, uit, i)
	i = _kant(state, opp, me, uit, i)
	# Globaal.
	uit[i] = float(state.cycle) / 20.0; i += 1
	var honger_vanaf: int = int(state.rules.honger_vanaf_cyclus)
	var honger: bool = honger_vanaf > 0 and state.cycle >= honger_vanaf
	uit[i] = 1.0 if honger else 0.0; i += 1
	uit[i] = (float(maxi(0, honger_vanaf - state.cycle)) / 10.0) if honger_vanaf > 0 else 0.0; i += 1
	uit[i] = float(state.round_number) / 3.0; i += 1
	var mijn_alive: int = 0
	for pawn in state.pawns.values():
		if not pawn.is_eliminated and pawn.owner_id == me:
			mijn_alive += 1
	uit[i] = 1.0 if mijn_alive < 7 else 0.0; i += 1
	var doc_me: int = int(state.doctrines.get(me, 0))
	var doc_opp: int = int(state.doctrines.get(opp, 0))
	for d in DOCTRINES:
		uit[i] = 1.0 if doc_me == d else 0.0; i += 1
	for d in DOCTRINES:
		uit[i] = 1.0 if doc_opp == d else 0.0; i += 1
	assert(i == uit.size(), "Kenmerken: rij niet volledig gevuld")
	return uit


## Alle kanttermen van `side` (doelhaven van side, bewaking op de haven van
## `other`), weggeschreven vanaf index `i`; geeft de volgende index terug.
static func _kant(state: GameState, side: int, other: int, uit: PackedFloat32Array, i: int) -> int:
	var target: Array = Constants.get_haven_for_player(side)
	var other_target: Array = Constants.get_haven_for_player(other)
	var campagne: bool = state.rules.campaign_actief()
	var alive: int = 0
	var inf: int = 0
	var cav: int = 0
	var art: int = 0
	var actief: int = 0
	var hp: int = 0
	var stamina: int = 0
	var attack: int = 0
	var in_haven: int = 0
	var guard: int = 0
	var d1: int = 99
	var d2: int = 99
	var near3: int = 0
	var d_som: int = 0
	var risk: int = 0
	var reach: int = 0
	var ranged: int = 0
	var dragers: int = 0
	var buit_open: float = 0.0
	var aura: int = 0
	for pawn in state.pawns.values():
		if pawn.is_eliminated or pawn.owner_id != side:
			continue
		alive += 1
		if pawn.unit_type == Constants.UnitType.CAVALRY:
			cav += 1
		elif pawn.unit_type == Constants.UnitType.ARTILLERY:
			art += 1
		else:
			inf += 1
		if target.has(pawn.position):
			in_haven += 1
		if other_target.has(pawn.position):
			guard += 1
		var d: int = _min_dist(pawn.position, target)
		d_som += d
		if d <= 3:
			near3 += 1
		if d < d1:
			d2 = d1
			d1 = d
		elif d < d2:
			d2 = d
		var killable: bool = _is_killable(state, pawn)
		if pawn.is_active:
			actief += 1
			hp += pawn.current_hp
			attack += Rules.effectieve_attack(state, pawn)
			var st: int = Rules.stamina_beschikbaar(state, pawn)
			stamina += st
			if killable:
				risk += 1
			if pawn.unit_type != Constants.UnitType.CAVALRY:
				ranged += Rules.get_valid_shot_targets(state, pawn.id).size()
			if st > 0 and d <= st and _can_reach_haven(state, pawn, target):
				reach += 1
			if campagne:
				if Rules.aura_bonus(state, pawn, "drum") > 0:
					aura += 1
				if Rules.aura_bonus(state, pawn, "flag") > 0:
					aura += 1
		if String(pawn.rol) != "":
			dragers += 1
			if killable:
				buit_open += _buit_waarde(state, pawn)
	if d1 == 99:
		d1 = 22  # geen pion meer: verder dan het bord
	if d2 == 99:
		d2 = 22
	uit[i] = float(alive) / 10.0; i += 1
	uit[i] = float(inf) / 10.0; i += 1
	uit[i] = float(cav) / 10.0; i += 1
	uit[i] = float(art) / 10.0; i += 1
	uit[i] = float(actief) / 10.0; i += 1
	uit[i] = float(hp) / 30.0; i += 1
	uit[i] = float(stamina) / 30.0; i += 1
	uit[i] = float(attack) / 30.0; i += 1
	uit[i] = float(in_haven); i += 1
	uit[i] = float(guard); i += 1
	uit[i] = float(d1) / 10.0; i += 1
	uit[i] = float(d2) / 10.0; i += 1
	uit[i] = (_prox(d1) + 0.6 * _prox(d2)) / 100.0; i += 1
	uit[i] = float(near3) / 10.0; i += 1
	uit[i] = (float(d_som) / float(alive) / 10.0) if alive > 0 else 2.2; i += 1
	uit[i] = float(risk) / 10.0; i += 1
	uit[i] = float(reach); i += 1
	uit[i] = float(ranged) / 10.0; i += 1
	uit[i] = float(dragers); i += 1
	uit[i] = buit_open / 4.0; i += 1
	uit[i] = float(aura) / 10.0; i += 1
	var pool_bekend: bool = state.pools.has(side)
	var cp_bekend: bool = state.cp.has(side)
	uit[i] = (float(state.pool_total(side)) / 20.0) if pool_bekend else 0.0; i += 1
	uit[i] = (float(int(state.cp.get(side, 0))) / 20.0) if cp_bekend else 0.0; i += 1
	uit[i] = 1.0 if pool_bekend else 0.0; i += 1
	return i


static func _prox(d: int) -> float:
	var v: int = maxi(0, Constants.BOARD_SIZE - d)
	return float(v * v)


static func _min_dist(pos: Vector2i, target: Array) -> int:
	var best: int = 99
	for t in target:
		var d: int = abs(pos.x - t.x) + abs(pos.y - t.y)
		if d < best:
			best = d
	return best


## Zelfde regel als AIController._is_killable: een aangrenzende actieve vijand
## met stamina en genoeg attack.
static func _is_killable(state: GameState, pawn: Pawn) -> bool:
	for neighbor in Constants.manhattan_neighbors(pawn.position):
		var enemy: Pawn = state.get_pawn_at(neighbor)
		if enemy != null and not enemy.is_eliminated and enemy.owner_id != pawn.owner_id \
				and enemy.is_active and Rules.stamina_beschikbaar(state, enemy) >= 1 \
				and Rules.effectieve_attack(state, enemy) >= pawn.current_hp:
			return true
	return false


static func _can_reach_haven(state: GameState, pawn: Pawn, target: Array) -> bool:
	for coord in Rules.get_valid_moves(state, pawn.id):
		if target.has(coord):
			return true
	return false


static func _buit_waarde(state: GameState, drager: Pawn) -> float:
	if not state.rules.campaign_actief():
		return 0.0
	if String(drager.rol) == "flag":
		return float(state.rules.campaign.get("buit_vaandel_pt", 0))
	if String(drager.rol) == "drum":
		return float(state.rules.campaign.get("buit_tamboer_cp", 0)) * 0.5
	return 0.0


# =========================================================================
# Kandidaten: alle legale actie-fase-zetten met hun na-staat-kenmerken.
# Gedeeld door de logger (arena) en AgentL4 (spelen).
# =========================================================================

## {acties: Array[Dictionary (legacy-vorm)], kenmerken: Array[PackedFloat32Array]}
## voor de actiefase. `ai` is een AIController (enumerate_actions + simulate).
static func kandidaten(ai, state: GameState, me: int) -> Dictionary:
	var acties: Array = ai.enumerate_actions(state, me)
	var rijen: Array = []
	for a in acties:
		rijen.append(van_staat(ai.simulate(state, a), me))
	return {"acties": acties, "kenmerken": rijen}


## Kandidaten voor de gratis Wolf-stap: index 0 = overslaan (de staat zelf),
## daarna elke lege buurtegel. {doelen: Array (Vector2i of null), kenmerken}
static func wolf_kandidaten(state: GameState, me: int) -> Dictionary:
	var doelen: Array = [null]
	var rijen: Array = [van_staat(state, me)]
	var pawn_id: int = state.pending_wolf_step_pawn
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn != null and not pawn.is_eliminated:
		for neighbor in Constants.manhattan_neighbors(pawn.position):
			if not Constants.is_on_board(neighbor) or not state.is_tile_empty(neighbor):
				continue
			var copy: GameState = state.clone()
			if not Rules.apply_wolf_step(copy, pawn_id, neighbor):
				continue
			doelen.append(neighbor)
			rijen.append(van_staat(copy, me))
	return {"doelen": doelen, "kenmerken": rijen}
