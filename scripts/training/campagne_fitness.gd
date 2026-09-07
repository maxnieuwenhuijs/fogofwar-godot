class_name CampagneFitness
extends RefCounted

## Campagne-fitness van de trainer (26 juli, Max: "lange termijn denken"):
## onder v4.2-regels traint de bot op het campagne-puntensysteem in plaats van
## kale winst. Haven (3) > eliminatie (2) > tiebreak (1) > verlies (0), plus een
## kleine spaarbonus: restleger en gespaarde CP gaan in de campagne mee naar het
## volgende duel -- ook voor de verliezer (die houdt zijn rest). Zo leert de bot
## winnen ZONDER zichzelf leeg te vechten.
##
## C15-buit (7 september, Max: "de ai moet daar ook op focussen"): wat je op
## dragers verovert telt apart mee. De reserve en de CP-pot zaten al in de
## spaarbonus (veroverde punten ZIJN reserve), maar dat signaal is te klein om
## het jagen te leren: 2 punten op een startreserve van ~70 is een derde
## procent fitness. Daarom een eigen term, genormeerd op de maximale buit die
## de regels toestaan (vaandels_max x buit_vaandel_pt + tamboers_max x
## buit_tamboer_cp, met 2 CP = 1 punt). Verloren dragers kosten niets extra:
## dat betaalt de tegenstander al met een sterkere reserve, en dat zie je
## terug in de uitslag.
##
## Genormaliseerd naar [0, 1]; de relatieve adoptie-gate van de trainer
## vergelijkt kandidaat en referentie op dezelfde schaal, dus de gate-marge
## blijft geldig. Los van tools/capture.gd zodat de testsuite hem kan raken.

const W_REST := 0.15
const W_CP := 0.05
const W_BUIT := 0.05
const NOEMER := 1.0 + W_REST + W_CP + W_BUIT


## `buit` = {"pt": .., "cp": ..} zoals MatchRunner.buit het per kant telt.
static func score(s: GameState, kant: int, winner: int, buit: Dictionary = {}) -> float:
	var punten: float = 0.0
	if winner == -1:
		punten = 1.0  # remise: beide het tiebreak-punt
	elif winner == kant:
		if Rules.count_pawns_in_haven(s, winner) >= s.rules.pawns_in_haven_to_win:
			punten = 3.0
		else:
			var verliezer: int = Constants.opponent(winner)
			if s.count_alive_pawns_for(verliezer) + s.pool_total(verliezer) == 0:
				punten = 2.0
			else:
				punten = 1.0
	var c: Dictionary = s.rules.campaign if s.rules.campaign_actief() else {}
	var comp: Array = s.doctrine_data_of(kant).comp
	var factor: float = float(c.get("poolfactor", 1.5))
	var start_totaal: int = 0
	var rest: int = 0
	if s.punten_model():
		# C11: alles in puntenwaarde (soldaat 1 / ruiter 2 / kanon 3) zodat
		# een gespaard kanon ook echt 3x een soldaat waard is.
		for t in 3:
			start_totaal += int(comp[t]) * s.spawn_kosten(t) + int(floor(int(comp[t]) * factor)) * s.spawn_kosten(t)
		for pawn in s.pawns.values():
			if not pawn.is_eliminated and pawn.owner_id == kant:
				rest += s.spawn_kosten(pawn.unit_type)
		rest += s.pool_total(kant)
	else:
		for t in 3:
			start_totaal += int(comp[t]) + int(floor(int(comp[t]) * factor))
		rest = s.count_alive_pawns_for(kant) + s.pool_total(kant)
	var rest_fractie: float = clampf(float(rest) / maxf(1.0, float(start_totaal)), 0.0, 1.0)
	var cp_start: float = maxf(1.0, float(c.get("cp_start", 10)))
	var cp_fractie: float = clampf(float(s.cp.get(kant, 0)) / cp_start, 0.0, 1.0)
	return (punten / 3.0 + W_REST * rest_fractie + W_CP * cp_fractie + W_BUIT * buit_fractie(s, buit)) / NOEMER


## Veroverde buit als fractie van wat de regels maximaal toestaan (0 als de
## knoppen uit staan of er geen campagne-blok is).
static func buit_fractie(s: GameState, buit: Dictionary) -> float:
	var maximaal: float = buit_max(s)
	if maximaal <= 0.0:
		return 0.0
	var geboekt: float = float(int(buit.get("pt", 0))) + 0.5 * float(int(buit.get("cp", 0)))
	return clampf(geboekt / maximaal, 0.0, 1.0)


## Maximale buit in punten (2 CP = 1 punt), uit de regelknoppen.
static func buit_max(s: GameState) -> float:
	if s.rules == null or not s.rules.campaign_actief():
		return 0.0
	var c: Dictionary = s.rules.campaign
	var vaandels: float = float(int(c.get("vaandels_max", 2)) * int(c.get("buit_vaandel_pt", 0)))
	var tamboers: float = float(int(c.get("tamboers_max", 2)) * int(c.get("buit_tamboer_cp", 0)))
	return vaandels + 0.5 * tamboers
