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
	var comp: Array = c.rules.doctrine_data(Constants.Doctrine.MENS).comp
	var pool: Dictionary = c.pool_van(0)
	assert_eq(int(pool.inf), int(floor(comp[0] * c.rules.start_poolfactor)),
		"start = reinforcements = comp x poolfactor (vol-team-model)")
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
	# De geldige loting: 3 duels, iedereen genomineerd, direct het bord op
	# (geen donatie-venster in ronde 1 — iedereen heeft zijn factie-start).
	assert_true(CReducer.apply(c, CActions.make_loting(paren), -1).ok, "geldige loting")
	assert_eq(c.duels_deze_ronde.size(), 3, "iedereen vecht in ronde 1")
	assert_eq(c.fase, CState.Fase.DUELS, "na de loting: direct de duels in")
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


func test_c11_ruil_cp_naar_versterkingen() -> void:
	# C11: 2 CP = 1 soldaat (1 punt), alleen in het donatie-venster.
	var c := _mini()
	assert_false(CReducer.apply(c, CActions.make_exchange(2), 0).ok,
		"ruilen buiten het donatie-venster geweigerd")
	_stem_unaniem(c, 0, 3)
	assert_eq(c.fase, CState.Fase.DONATIE)
	var cp_voor: int = c.cp_van(1)
	var inf_voor: int = int(c.pool_van(1).inf)
	assert_false(CReducer.apply(c, CActions.make_exchange(3), 1).ok, "alleen veelvouden van 2")
	assert_false(CReducer.apply(c, CActions.make_exchange(99 * 2), 1).ok, "niet meer dan je saldo")
	assert_true(CReducer.apply(c, CActions.make_exchange(4), 1).ok, "4 CP -> 2 soldaten")
	assert_eq(c.cp_van(1), cp_voor - 4)
	assert_eq(int(c.pool_van(1).inf), inf_voor + 2)


func test_c11_budget_bonus_per_factie() -> void:
	# C11: factie-compensatie als startboeking (Muis +4 pt, Wolf +2 pt/+4 CP).
	var c := CState.new()
	c.rules = CRules.new()
	var lijst: Array = []
	for i in 6:
		lijst.append({"naam": "S%d" % i, "doctrine": i})  # doctrine = index
	c.setup(lijst, c.rules)
	var muis_comp: Array = Constants.doctrine_data(1).comp
	var muis_basis: int = int(floor(muis_comp[0] * c.rules.start_poolfactor))
	assert_eq(int(c.pool_van(1).inf), muis_basis + 4, "Muis: +4 soldaten bonus")
	assert_eq(c.cp_van(4), c.rules.start_cp + 4, "Wolf: +4 CP bonus")
	var varken_comp: Array = Constants.doctrine_data(0).comp
	assert_eq(int(c.pool_van(0).inf), int(floor(varken_comp[0] * c.rules.start_poolfactor)),
		"Varken: geen bonus")
	# Compat: oude regels-dict zonder budget_bonus -> geen bonus bij fold.
	var oud := CRules.from_dict({"team_size": 8})
	assert_true(oud.budget_bonus.is_empty(), "pre-C11-saves: lege bonus-tabel")


func test_donatiecaps_en_regels() -> void:
	var c := _mini()
	_stem_unaniem(c, 0, 3)
	# Speler 1 doneert aan genomineerde teamgenoot 0: binnen de caps.
	assert_true(CReducer.apply(c, CActions.make_donate(0, 5, 2, 0, 2), 1).ok)
	var pool0: Dictionary = c.pool_van(0)
	var comp: Array = Constants.doctrine_data(Constants.Doctrine.MENS).comp
	assert_eq(int(pool0.inf), int(floor(comp[0] * c.rules.start_poolfactor)) + 5, "donatie bijgeschreven")
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
	assert_eq(int(c.pool_van(3).inf), int(floor(comp[0] * c.rules.start_poolfactor)) - 5,
		"oude logs (zonder inzet-veld) boeken verliezen zoals vroeger")
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


## V0 (3 augustus): een duel kent geen gelijkspel meer. Tot vandaag boekte een
## remise BEIDE vechters een punt en verloor niemand iets: precies de uitkomst
## die V0 verbiedt. Zo'n uitslag hoort nu geweigerd te worden, niet stil
## weggeboekt, want hij betekent dat het bord geen winnaar heeft opgeleverd.
func test_v0_duel_zonder_winnaar_geweigerd() -> void:
	var c := _mini()
	_stem_unaniem(c, 0, 3)
	_sluit_donaties(c)
	var res: Dictionary = CReducer.apply(c, CActions.make_match_result(0, -1, "eliminatie", {}, {}), -1)
	assert_false(res.ok, "winnaar -1 wordt geweigerd")
	assert_eq(c.punten_van(0), 0, "en er wordt niets geboekt")
	assert_eq(c.punten_van(3), 0)


## De roem kent nog drie tredes: haven, eliminatie (ook bij opgeven) en verlies.
func test_v0_roem_zonder_tiebreak_trede() -> void:
	var r := CRules.new()
	assert_eq(r.punten_voor_methode("haven"), r.punten_haven)
	assert_eq(r.punten_voor_methode("eliminatie"), r.punten_eliminatie)
	assert_eq(r.punten_voor_methode("resign"), r.punten_eliminatie,
		"opgeven telt voor de winnaar als een eliminatie")
	assert_eq(r.punten_voor_methode("tiebreak"), r.punten_verlies,
		"de tiebreak-trede bestaat niet meer")


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


func test_vijandelijk_saldo_verborgen() -> void:
	# Spec 6 / D12 (aangescherpt 30 juli, Max: "bij ieder potje kan je wel zien
	# wat de reserve is en de CP van je tegenstander"). Roem blijft publiek.
	var c := _mini()
	var kijker: int = -1
	var teamgenoot: int = -1
	var vijand: int = -1
	for id in c.spelers:
		var t: int = int(c.spelers[id].team)
		if kijker < 0:
			kijker = int(id)
		elif teamgenoot < 0 and t == int(c.spelers[kijker].team):
			teamgenoot = int(id)
		elif vijand < 0 and t != int(c.spelers[kijker].team):
			vijand = int(id)
	assert_true(kijker >= 0 and teamgenoot >= 0 and vijand >= 0, "drie spelers gevonden")
	var v: Dictionary = CView.for_player(c, kijker)
	assert_false(v.spelers[str(kijker)].cp is String, "eigen CP zichtbaar")
	assert_false(v.spelers[str(teamgenoot)].cp is String, "teamgenoot zichtbaar")
	assert_true(v.spelers[str(vijand)].cp is String, "vijandelijke CP verborgen")
	assert_true(v.spelers[str(vijand)].pool is String, "vijandelijke voorraad verborgen")
	assert_false(v.spelers[str(vijand)].punten is String, "roem blijft publiek")
	# Grootboek-scherm mag het ook niet doorgeven.
	var rijen: Array = LedgerScreen.rijen(c, "naam", kijker)
	for r in rijen:
		if int(r.id) == vijand:
			assert_false(bool(r.saldo_zichtbaar), "grootboek verbergt het vijandelijke saldo")
		if int(r.id) == kijker:
			assert_true(bool(r.saldo_zichtbaar), "eigen saldo blijft leesbaar")
	# Wie uitgevallen is ziet alles (spec 6).
	c.spelers[kijker]["status"] = "uitgevallen"
	var v2: Dictionary = CView.for_player(c, kijker)
	assert_false(v2.spelers[str(vijand)].cp is String, "doden zien alles")


# --- C17: het doctrines-blok stuurt ook de campagne (3 augustus) ---------------

## De startvoorraad moet hetzelfde leger tellen als de duels opstellen. Deed hij
## niet: CState.setup las Constants rechtstreeks, dus een aangenomen voorstel van
## de factiezoeker veranderde wel de meting en niet het spel.
func test_c17_doctrines_stuurt_startvoorraad() -> void:
	var regels := CRules.new()
	regels.doctrines = {"0": {"comp": [20, 0, 0]}}
	var c := CState.new()
	var lijst: Array = []
	for i in 6:
		lijst.append({"naam": "S%d" % i, "doctrine": Constants.Doctrine.MENS})
	c.setup(lijst, regels)
	var pool: Dictionary = c.pool_van(0)
	assert_eq(int(pool.inf), int(floor(20 * regels.start_poolfactor)),
		"startvoorraad volgt de overschreven comp, niet de tabel")
	assert_eq(int(pool.cav), 0, "override vervangt de comp volledig")
	assert_eq(c.ledger.size(), 6, "nog steeds 1 start-boeking per speler")


## Zonder blok mag er geen komma verschuiven: dat is de garantie waarop alle
## bestaande tests, goldens en ijk-sims leunen.
func test_c17_zonder_blok_verandert_er_niets() -> void:
	var c := CState.new()
	var lijst: Array = []
	for i in 6:
		lijst.append({"naam": "S%d" % i, "doctrine": i % 6})
	c.setup(lijst, CRules.new())
	for i in 6:
		var comp: Array = Constants.doctrine_data(i % 6).comp
		# C11-compensatie komt er als aparte boeking bovenop (Muis +4, Beer +3,
		# Wolf +2) en staat los van het doctrines-blok.
		var bonus: int = int((c.rules.budget_bonus.get(str(i % 6), {}) as Dictionary).get("pt", 0))
		assert_eq(int(c.pool_van(i).inf), int(floor(comp[0] * 0.5)) + bonus,
			"speler %d start op de kale tabel" % i)


## Het blok moet de rondreis naar de save en terug overleven, met INTS.
func test_c17_crules_doctrines_rondreis() -> void:
	var regels := CRules.new()
	regels.doctrines = {"2": {"budget": 9, "comp": [6, 11, 2]}}
	var terug := CRules.from_dict(JSON.parse_string(JSON.stringify(regels.to_dict())))
	assert_eq(int(terug.doctrine_data(2).budget), 9, "override overleeft de save")
	var comp: Array = terug.doctrine_data(2).comp
	for i in 3:
		assert_true(comp[i] is int, "comp moet ints houden, geen JSON-floats")
	assert_eq(int(comp[1]), 11)
	assert_eq(String(terug.doctrine_data(2).name), "Leeuw", "rest blijft de tabel")


## Hervatten moet de BEVROREN facties uit de save gebruiken, niet die van het
## bestand: neemt Max later een ander voorstel aan, dan houdt een lopende
## campagne haar eigen dieren en pakken alleen nieuwe campagnes het nieuwe blok.
func test_c17_save_bevriest_de_facties() -> void:
	var regels := CRules.new()
	regels.doctrines = {"0": {"budget": 3, "comp": [20, 0, 0]}}
	var c := CState.new()
	var lijst: Array = []
	for i in 6:
		lijst.append({"naam": "S%d" % i, "doctrine": Constants.Doctrine.MENS})
	c.setup(lijst, regels)
	var terug := CState.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(int(terug.rules.doctrine_data(0).budget), 3,
		"de campagne draagt haar facties mee in de save")
	assert_eq(int((terug.rules.doctrine_data(0).comp as Array)[0]), 20)
	assert_eq(int(terug.pool_van(0).inf), int(c.pool_van(0).inf),
		"en de voorraad foldt identiek terug")


## Saves van voor 3 augustus missen de sleutel: die moeten leeg terugkomen en
## dus onder hun eigen, oude facties blijven folden.
func test_c17_oude_save_zonder_doctrines() -> void:
	var oud := CRules.from_dict({"team_size": 8, "start_poolfactor": 0.5})
	assert_true(oud.doctrines.is_empty(), "ontbrekende sleutel = leeg blok")
	assert_eq(int(oud.doctrine_data(2).budget),
		int(Constants.doctrine_data(2).budget), "en dus gewoon de kale tabel")


## De SCHERMEN moeten dezelfde facties tonen als het spel opstelt.
## Gevonden 8 augustus: de factiekiezer, de tegenstanderkiezer en het
## help-scherm lazen `Constants.DOCTRINE_DATA` rechtstreeks en beloofden dus
## "4 kaarten" bij een Muis die er vijf uitdeelt. Ze gaan nu via
## `CRules.actieve_tabel()`; deze test bewaakt dat die ingang blijft werken.
func test_c19_actieve_tabel_voor_de_schermen() -> void:
	var tabel := CRules.actieve_tabel()
	var blok := CRules.facties_uit_bestand()
	assert_eq(tabel.doctrines.size(), blok.size(),
		"actieve_tabel draagt hetzelfde blok als het regels-bestand")
	for sleutel in blok:
		var doc := int(sleutel)
		var nu: Dictionary = tabel.doctrine_data(doc)
		for veld in (blok[sleutel] as Dictionary):
			assert_eq(JSON.stringify(nu.get(veld)), JSON.stringify(blok[sleutel][veld]),
				"factie %d, veld %s komt uit het blok" % [doc, String(veld)])
		# Wat het blok NIET overschrijft blijft gewoon de kale tabel.
		assert_eq(String(nu.name), String(Constants.doctrine_data(doc).name),
			"de naam blijft uit constants.gd komen")


## Zonder bestand (of met een onleesbaar pad) mag het scherm niet omvallen:
## dan hoort het gewoon de kale tabel te tonen, net als de engine doet.
func test_c19_actieve_tabel_zonder_bestand() -> void:
	var tabel := CRules.actieve_tabel("res://bestaat_niet_xyz.json")
	assert_true(tabel.doctrines.is_empty(), "geen bestand = leeg blok")
	for doc in Constants.DOCTRINE_DATA.keys():
		assert_eq(int(tabel.doctrine_data(int(doc)).cards),
			int(Constants.doctrine_data(int(doc)).cards),
			"en dus de kale tabel, zonder te crashen")
