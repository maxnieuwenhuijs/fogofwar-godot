extends TestSuite

# F3.1 — CampaignCore: de testgevallen uit docs/campagne-spec.md par. 7.
# Mini-campagnes van 2 teams x 3 (de regels zijn data, dus klein testbaar).


func _class_name() -> String:
	return "CampaignTests"


## 6 spelers (ids 0..5): team 0 = {0,1,2}, team 1 = {3,4,5}, allen MENS.
## ronde1_loting staat hier UIT: deze suite test de raad-machinerie (stemmen,
## staking, defaults) — de C9-loting heeft eigen tests hieronder.
func _mini(duels_max: int = 1) -> CState:
	var c := CState.new()
	c.rules = CRules.new()
	c.rules.duels_per_ronde_max = duels_max
	c.rules.ronde1_loting = false
	var lijst: Array = []
	for i in 6:
		lijst.append({"naam": "S%d" % i, "doctrine": Constants.Doctrine.MENS})
	c.setup(lijst, c.rules)
	return c


## Alle actieve leden van het nominatie-team stemmen hetzelfde paar.
func _stem_unaniem(c: CState, eigen: int, vijand: int) -> Dictionary:
	var laatste: Dictionary = {}
	for sid in c.actieve_leden(c.nominatie_team):
		laatste = CReducer.apply(c, CActions.make_nominate(eigen, vijand), sid)
	return laatste


func _sluit_donaties(c: CState) -> void:
	var res: Dictionary = CReducer.apply(c, CActions.make_tick_deadline(), -1)
	assert_true(res.ok, "donatie-venster sluiten via tick")


func test_start_bezit_via_ledger() -> void:
	var c := _mini()
	var comp: Array = Constants.doctrine_data(Constants.Doctrine.MENS).comp
	var pool: Dictionary = c.pool_van(0)
	assert_eq(int(pool.inf), int(floor(comp[0] * 1.5)), "start = comp x 1.5 (1v1-setting)")
	assert_eq(c.cp_van(0), 10)
	assert_eq(c.punten_van(0), 0)
	assert_eq(c.ledger.size(), 6, "1 start-boeking per speler")


func test_nominatie_volgorde_kleinste_team_eerst() -> void:
	var c := _mini(2)
	c.spelers[0].status = "uitgevallen"  # team 0 is kleiner (2 vs 3)
	c.nominatie_team = c.kleinste_team()
	assert_eq(c.nominatie_team, 0, "het kleinste team nomineert eerst")
	assert_eq(c.duels_per_ronde(), 2, "duels = min(2, kleinste teamgrootte)")


func test_stem_meerderheid_en_niet_dubbel() -> void:
	var c := _mini()
	assert_true(CReducer.apply(c, CActions.make_nominate(0, 3), 0).ok)
	assert_true(CReducer.apply(c, CActions.make_nominate(0, 3), 1).ok)
	var res: Dictionary = CReducer.apply(c, CActions.make_nominate(1, 4), 2)
	assert_true(res.ok, "laatste stem sluit de telling")
	assert_eq(c.duels_deze_ronde.size(), 1)
	assert_eq(int(c.duels_deze_ronde[0].p1), 0, "meerderheid wint (2x {0,3})")
	assert_eq(int(c.duels_deze_ronde[0].p2), 3)
	assert_eq(c.fase, CState.Fase.DONATIE, "1 duel -> door naar doneren")
	# Niet 2x per ronde: p1/p2 staan als genomineerd geregistreerd.
	assert_true(c.al_genomineerd.has(0))
	assert_true(c.al_genomineerd.has(3))


func test_stem_staking_kleinste_pool_beslist() -> void:
	var c := _mini()
	# Speler 2 wordt arm gemaakt: doneren kan pas later, dus boek direct.
	c._boek("test", 2, -10, 0, 0, 0, 0)
	assert_true(CReducer.apply(c, CActions.make_nominate(0, 3), 0).ok)
	assert_true(CReducer.apply(c, CActions.make_nominate(1, 4), 1).ok)
	assert_true(CReducer.apply(c, CActions.make_nominate(2, 5), 2).ok)
	# 3 verschillende stemmen -> staking -> de stem van speler 2 (kleinste pool).
	assert_eq(int(c.duels_deze_ronde[0].p1), 2, "staking: kleinste pool beslist")
	assert_eq(int(c.duels_deze_ronde[0].p2), 5)


func test_zelfnominatie_laatste_overlevende() -> void:
	var c := _mini()
	c.spelers[1].status = "uitgevallen"
	c.spelers[2].status = "uitgevallen"
	c.nominatie_team = 0  # team 0 heeft alleen speler 0 nog
	var fout: Dictionary = CReducer.apply(c, CActions.make_nominate(0, 3), 0)
	assert_true(fout.ok, "zichzelf nomineren mag (en moet)")
	# Opnieuw met een ander team-lid als 'eigen' zou geweigerd zijn — bewijs
	# via een verse staat:
	var c2 := _mini()
	c2.spelers[1].status = "uitgevallen"
	c2.spelers[2].status = "uitgevallen"
	c2.nominatie_team = 0
	var res: Dictionary = CReducer.apply(c2, CActions.make_nominate(3, 3), 0)
	assert_false(res.ok, "een vijand als eigen vechter kan sowieso niet")


## C9-helper: verse staat MET loting aan (zoals echte campagnes).
func _mini_loting() -> CState:
	var c := CState.new()
	c.rules = CRules.new()
	var lijst: Array = []
	for i in 6:
		lijst.append({"naam": "S%d" % i, "doctrine": Constants.Doctrine.MENS})
	c.setup(lijst, c.rules)
	return c


func test_c9_loting_ronde_1() -> void:
	var c := _mini_loting()
	# Stemmen in ronde 1 is er niet meer.
	assert_false(CReducer.apply(c, CActions.make_nominate(0, 3), 0).ok,
		"ronde 1 wordt geloot, niet gestemd")
	# Alleen het systeem mag loten.
	var paren: Array = [[0, 3], [1, 4], [2, 5]]
	assert_false(CReducer.apply(c, CActions.make_loting(paren), 0).ok,
		"een speler kan de loting niet indienen")
	# Ongeldige lotingen: binnen een team, dubbel lid, onvolledig.
	assert_false(CReducer.apply(c, CActions.make_loting([[0, 1], [2, 3], [4, 5]]), -1).ok,
		"paar binnen een team geweigerd")
	assert_false(CReducer.apply(c, CActions.make_loting([[0, 3], [0, 4], [2, 5]]), -1).ok,
		"dubbel geloot lid geweigerd")
	assert_false(CReducer.apply(c, CActions.make_loting([[0, 3]]), -1).ok,
		"loting moet iedereen paren")
	# De geldige loting: 3 duels, iedereen genomineerd, door naar doneren.
	assert_true(CReducer.apply(c, CActions.make_loting(paren), -1).ok, "geldige loting")
	assert_eq(c.duels_deze_ronde.size(), 3, "iedereen vecht in ronde 1")
	assert_eq(c.fase, CState.Fase.DONATIE, "na de loting: donatie-venster")
	for sid in 6:
		assert_true(c.al_genomineerd.has(sid), "speler %d is gepaird" % sid)


func test_c9_volle_rondes_default() -> void:
	# De nieuwe standaard: duels per ronde = kleinste teamgrootte (cap 8).
	var c := _mini_loting()
	assert_eq(c.rules.duels_per_ronde_max, 8, "nieuwe default: iedereen vecht")
	assert_eq(c.duels_per_ronde(), 3, "min(cap, kleinste team) = 3 bij 3v3")
	# Compat: een oud campagne-dict zonder de nieuwe sleutels foldt oud gedrag.
	var oud := CRules.from_dict({"team_size": 8})
	assert_eq(oud.duels_per_ronde_max, 2, "oude saves: max 2 duels per ronde")
	assert_false(oud.ronde1_loting, "oude saves: geen loting")


func test_donatiecaps_en_regels() -> void:
	var c := _mini()
	_stem_unaniem(c, 0, 3)
	# Speler 1 doneert aan genomineerde teamgenoot 0: binnen de caps.
	assert_true(CReducer.apply(c, CActions.make_donate(0, 5, 2, 0, 2), 1).ok)
	var pool0: Dictionary = c.pool_van(0)
	var comp: Array = Constants.doctrine_data(Constants.Doctrine.MENS).comp
	assert_eq(int(pool0.inf), int(floor(comp[0] * 1.5)) + 5, "donatie bijgeschreven")
	# Cap pionnen: 7 zat er al (5+2), nog 4 erbij = 11 > 10 -> geweigerd.
	var teveel: Dictionary = CReducer.apply(c, CActions.make_donate(0, 4, 0, 0, 0), 2)
	assert_false(teveel.ok, "donatiecap 10 pionnen per ontvanger per ronde")
	# Cap CP: 2 zat er al, nog 2 = 4 > 3 -> geweigerd.
	var teveel_cp: Dictionary = CReducer.apply(c, CActions.make_donate(0, 0, 0, 0, 2), 2)
	assert_false(teveel_cp.ok, "donatiecap 3 CP per ontvanger per ronde")
	# C9 (26 juli): doneren mag aan élke levende teamgenoot, ook niet-genomineerd.
	assert_true(CReducer.apply(c, CActions.make_donate(1, 1, 0, 0, 0), 2).ok,
		"doneren aan een niet-genomineerde teamgenoot mag (C9)")
	# Vijand -> geweigerd.
	assert_false(CReducer.apply(c, CActions.make_donate(3, 1, 0, 0, 0), 1).ok,
		"doneren aan de vijand kan niet")


func test_match_result_punten_en_cp() -> void:
	var c := _mini()
	_stem_unaniem(c, 0, 3)
	_sluit_donaties(c)
	assert_eq(c.fase, CState.Fase.DUELS)
	var res: Dictionary = CReducer.apply(c, CActions.make_match_result(
		0, 0, "haven", {"0": {"inf": 2}, "3": {"inf": 5, "cav": 1}}, {"0": -3, "3": 2}), -1)
	assert_true(res.ok)
	assert_eq(c.punten_van(0), 3, "haven-winst = 3 punten")
	assert_eq(c.punten_van(3), 0)
	assert_eq(c.cp_van(0), 7, "CP-delta verwerkt (10 - 3)")
	assert_eq(c.cp_van(3), 12)
	var comp: Array = Constants.doctrine_data(Constants.Doctrine.MENS).comp
	assert_eq(int(c.pool_van(3).inf), int(floor(comp[0] * 1.5)) - 5, "verliezen afgeboekt")
	assert_eq(c.ronde, 2, "geen uitvallers -> volgende raadsronde")
	assert_eq(c.fase, CState.Fase.NOMINATIE)


func test_uitvallen_en_testament_flow() -> void:
	var c := _mini()
	_stem_unaniem(c, 0, 3)
	_sluit_donaties(c)
	# Speler 3 verliest ALLES (pool naar 0) maar houdt CP -> testament-fase.
	var pool3: Dictionary = c.pool_van(3)
	var res: Dictionary = CReducer.apply(c, CActions.make_match_result(
		0, 0, "eliminatie",
		{"3": {"inf": int(pool3.inf), "cav": int(pool3.cav), "art": int(pool3.art)}},
		{}), -1)
	assert_true(res.ok)
	assert_eq(String(c.spelers[3].status), "uitgevallen", "C3: verlies + lege voorraad")
	assert_eq(c.fase, CState.Fase.TESTAMENT)
	# Testament: max helft (CP 10 -> max 5), max 2 ontvangers, actieve spelers.
	var teveel: Dictionary = CReducer.apply(c, CActions.make_testament(
		[{"naar": 4, "cp": 6}]), 3)
	assert_false(teveel.ok, "boven de helft geweigerd")
	var drie: Dictionary = CReducer.apply(c, CActions.make_testament(
		[{"naar": 4, "cp": 1}, {"naar": 5, "cp": 1}, {"naar": 1, "cp": 1}]), 3)
	assert_false(drie.ok, "max 2 ontvangers")
	var ok: Dictionary = CReducer.apply(c, CActions.make_testament(
		[{"naar": 4, "cp": 3}, {"naar": 5, "cp": 2}]), 3)
	assert_true(ok.ok)
	assert_eq(c.cp_van(4), 13, "nalatenschap bijgeschreven")
	assert_eq(c.cp_van(5), 12)
	assert_eq(c.cp_van(3), 0, "de rest is verbrand")
	assert_eq(c.ronde, 2, "daarna gewoon door")


func test_testament_timeout_verbrandt() -> void:
	var c := _mini()
	_stem_unaniem(c, 0, 3)
	_sluit_donaties(c)
	var pool3: Dictionary = c.pool_van(3)
	assert_true(CReducer.apply(c, CActions.make_match_result(
		0, 0, "eliminatie",
		{"3": {"inf": int(pool3.inf), "cav": int(pool3.cav), "art": int(pool3.art)}},
		{}), -1).ok)
	assert_eq(c.fase, CState.Fase.TESTAMENT)
	assert_true(CReducer.apply(c, CActions.make_tick_deadline(), -1).ok)
	assert_eq(c.cp_van(3), 0, "timeout: alles verbrand")
	assert_eq(c.pool_totaal_van(3), 0)


func test_remise_beide_tiebreak_punt() -> void:
	var c := _mini()
	_stem_unaniem(c, 0, 3)
	_sluit_donaties(c)
	assert_true(CReducer.apply(c, CActions.make_match_result(0, -1, "tiebreak", {}, {}), -1).ok)
	assert_eq(c.punten_van(0), 1)
	assert_eq(c.punten_van(3), 1)


func test_burgeroorlog_seeding_en_kampioen() -> void:
	var c := _mini()
	# Team 1 volledig uitschakelen + punten-spreiding voor de seeding.
	for sid in [3, 4, 5]:
		c.spelers[sid].status = "uitgevallen"
		c.spelers[sid].testament_af = true
	c._boek("punten", 0, 0, 0, 0, 0, 5)
	c._boek("punten", 1, 0, 0, 0, 0, 3)
	c._boek("punten", 2, 0, 0, 0, 0, 1)
	var events: Array = []
	CReducer._volgende_ronde(c, events)
	assert_eq(c.fase, CState.Fase.BURGEROORLOG)
	# Teambonus ook voor de doden van het winnende team? Team 0 leeft — bonus
	# geldt voor ALLE leden van team 0 (hier niemand dood, maar het tarief telt).
	assert_eq(c.punten_van(0), 7, "5 + teambonus 2")
	# 3 deelnemers: hoogste seed (0) heeft een vrijloting; 1 vs 2 duelleren.
	assert_eq(c.duels_deze_ronde.size(), 1)
	assert_eq(int(c.duels_deze_ronde[0].p1), 1, "seed 2 vs seed 3")
	assert_eq(int(c.duels_deze_ronde[0].p2), 2)
	# Donaties bestaan niet meer in de burgeroorlog.
	assert_false(CReducer.apply(c, CActions.make_donate(1, 1, 0, 0, 0), 0).ok,
		"geen ruil in de burgeroorlog")
	# Speler 1 wint de bracket-partij -> finale 0 vs 1.
	assert_true(CReducer.apply(c, CActions.make_match_result(0, 1, "haven", {}, {}), -1).ok)
	assert_eq(String(c.spelers[2].status), "uitgevallen", "bracket-verlies = knock-out")
	assert_eq(c.duels_deze_ronde.size(), 1, "finale geseed")
	assert_true(CReducer.apply(c, CActions.make_match_result(0, 0, "eliminatie", {}, {}), -1).ok)
	assert_eq(c.winnaar, 0, "kampioen gekroond")
	assert_eq(c.fase, CState.Fase.KLAAR)


func test_teambonus_ook_voor_doden() -> void:
	var c := _mini()
	c.spelers[1].status = "uitgevallen"  # dode teamgenoot van het winnende team
	c.spelers[1].testament_af = true
	for sid in [3, 4, 5]:
		c.spelers[sid].status = "uitgevallen"
		c.spelers[sid].testament_af = true
	var events: Array = []
	CReducer._volgende_ronde(c, events)
	assert_eq(c.punten_van(1), 2, "de dode teamgenoot deelt in de teambonus")


func test_ledger_fold_serialisatie() -> void:
	var c := _mini()
	_stem_unaniem(c, 0, 3)
	assert_true(CReducer.apply(c, CActions.make_donate(0, 3, 1, 0, 2), 1).ok)
	var d: Dictionary = c.to_dict()
	var terug: CState = CState.from_dict(d)
	assert_eq(JSON.stringify(terug.to_dict()), JSON.stringify(d), "roundtrip byte-identiek")
	for sid in 6:
		assert_eq(terug.pool_totaal_van(sid), c.pool_totaal_van(sid))
		assert_eq(terug.cp_van(sid), c.cp_van(sid))


func test_campagne_log_fold_identiek() -> void:
	# Spec-CHECK: het campagne-log replayt naar exact dezelfde eindstand.
	var c := _mini()
	var log := CLog.new()
	log.setup(c)
	var acties: Array = []
	for sid in c.actieve_leden(0):
		acties.append([CActions.make_nominate(0, 3), sid])
	acties.append([CActions.make_donate(0, 2, 0, 0, 1), 1])
	acties.append([CActions.make_tick_deadline(), -1])
	acties.append([CActions.make_match_result(0, 0, "haven", {"3": {"inf": 4}}, {"0": -2}), -1])
	for paar in acties:
		var res: Dictionary = CReducer.apply(c, paar[0], paar[1])
		assert_true(res.ok, "actie in de log-flow moet slagen")
		log.record(paar[1], paar[0])
	var uitkomst: Dictionary = CLog.fold(log.meta.begin, log.entries)
	assert_true(bool(uitkomst.ok), "fold speelt het hele log af")
	assert_eq(JSON.stringify((uitkomst.cstate as CState).to_dict()), JSON.stringify(c.to_dict()),
		"replay = byte-identieke eindstand")


func test_ledger_invariant_som_constant() -> void:
	# Som van alle pion-mutaties = 0 behalve start, loss en verbranding.
	var c := _mini()
	_stem_unaniem(c, 0, 3)
	assert_true(CReducer.apply(c, CActions.make_donate(0, 3, 1, 0, 2), 1).ok)
	var som := 0
	for e in c.ledger:
		if String(e.reason) == "donate" or String(e.reason) == "testament":
			som += int(e.inf) + int(e.cav) + int(e.art) + int(e.cp)
	assert_eq(som, 0, "overdrachten zijn altijd netto nul (niets ontstaat of verdwijnt)")
