extends Node

# F3.4b — de brug tussen de CampagneHub en het echte bord (autoload
# "CampaignBridge"): draagt de SoloDriver over scene-wissels heen en
# vertaalt het mens-duel heen (duel-config, mens = bord-P1) en terug
# (bord-uitslag -> MATCH_RESULT via SoloDriver.verwerk_duel_uitslag).

var driver: SoloDriver = null
var duel_actief: bool = false
var _ctx: Dictionary = {}  # {idx, a, b, cp_a, cp_b} — a = de mens = bord-P1


## Vanuit de hub: het openstaande mens-duel klaarzetten voor het bord.
func start_mens_duel() -> bool:
	if driver == null:
		return false
	var d: Dictionary = driver.mens_duel()
	if d.is_empty():
		return false
	var a: int = driver.mens_id
	var b: int = int(d.p2) if int(d.p1) == a else int(d.p1)
	_ctx = {"idx": int(d.idx), "a": a, "b": b,
		"cp_a": driver.c.cp_van(a), "cp_b": driver.c.cp_van(b)}
	duel_actief = true
	return true


## De v4.2-duel-config met de mens als bord-P1 (de bord-UI speelt altijd P1).
func duel_rules() -> RulesConfig:
	return driver.duel_rules_voor(int(_ctx.a), int(_ctx.b))


func doctrine_mens() -> int:
	return int(driver.c.spelers[int(_ctx.a)].doctrine)


func doctrine_vijand() -> int:
	return int(driver.c.spelers[int(_ctx.b)].doctrine)


func naam_vijand() -> String:
	return String(driver.c.spelers[int(_ctx.b)].naam)


## Vanuit het bord: de uitslag terugboeken in de campagne.
func rond_af(s: GameState, winnaar_kant: int) -> void:
	duel_actief = false
	driver.verwerk_duel_uitslag(int(_ctx.idx), int(_ctx.a), int(_ctx.b),
		int(_ctx.cp_a), int(_ctx.cp_b), s, winnaar_kant)
	_ctx = {}
