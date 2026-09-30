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


## De startcompensatie per factie (C11) staat op DRIE plekken en wordt, anders
## dan het doctrines-blok, NIET uit het regels-bestand gelezen: `CRules` heeft
## zijn eigen tabel voor de campagnelaag, en `campaign.budget_bonus` staat in
## rules_v42_campaign.json (duels/arena/trainer) en in v42_default.json (los
## potje). Lopen ze uit elkaar, dan krijgt een factie zijn punten wel in een
## duel en niet in de campagne -- precies de soort splitsing die C17 verbiedt.
## Toegevoegd op 9 augustus, toen Krokodil er +3 bij kreeg.
func test_c19_budget_bonus_overal_gelijk() -> void:
	var kern: Dictionary = CRules.new().budget_bonus
	for pad in ["res://arena/arena_configs/rules_v42_campaign.json",
			"res://arena/arena_configs/v42_default.json"]:
		assert_true(FileAccess.file_exists(pad), "regels-bestand bestaat: %s" % pad)
		var j = JSON.parse_string(FileAccess.get_file_as_string(pad))
		assert_true(j is Dictionary, "leesbare json: %s" % pad)
		var bb = ((j as Dictionary).get("campaign", {}) as Dictionary).get("budget_bonus", null)
		assert_true(bb is Dictionary, "%s draagt een budget_bonus" % pad)
		assert_eq((bb as Dictionary).size(), kern.size(),
			"%s: evenveel facties met compensatie als CRules" % pad)
		for sleutel in kern:
			var uit_bestand = (bb as Dictionary).get(sleutel, null)
			assert_true(uit_bestand is Dictionary, "%s kent factie %s" % [pad, sleutel])
			assert_eq(int((uit_bestand as Dictionary).get("pt", 0)),
				int((kern[sleutel] as Dictionary).get("pt", 0)),
				"%s factie %s: pt gelijk aan CRules" % [pad, sleutel])
			assert_eq(int((uit_bestand as Dictionary).get("cp", 0)),
				int((kern[sleutel] as Dictionary).get("cp", 0)),
				"%s factie %s: cp gelijk aan CRules" % [pad, sleutel])


# --- C15-buit in de campagne-boekhouding (7 september 2026) -------------------

func test_c15_buit_uit_een_duel_komt_op_de_campagnepool() -> void:
	# De inzet wordt afgeboekt, de buit komt als soldaten terug: netto -1.
	var c := _mini()
	_stem_unaniem(c, 0, 3)
	_sluit_donaties(c)
	assert_eq(c.fase, CState.Fase.DUELS)
	var voor: int = int(c.pool_van(0).inf)
	var res: Dictionary = CReducer.apply(c, CActions.make_match_result(
		0, 0, "haven", {}, {}, {"0": {"inf": 3}, "3": {"inf": 0}}, {"0": 2}), -1)
	assert_true(res.ok, "match_result met buit: %s" % str(res.get("error", "")))
	assert_eq(int(c.pool_van(0).inf), voor - 3 + 2, "inzet 3 af, buit 2 erbij")
	var buit_entries: Array = []
	for e in c.ledger:
		if String(e.reason) == "buit":
			buit_entries.append(e)
	assert_eq(buit_entries.size(), 1, "een buit-boeking in het ledger")
	assert_eq(int(buit_entries[0].speler), 0)
	assert_eq(int(buit_entries[0].inf), 2, "buit komt als soldaten binnen")
	# Buit voor een speler buiten het duel: geweigerd.
	var c2 := _mini()
	_stem_unaniem(c2, 0, 3)
	_sluit_donaties(c2)
	var fout: Dictionary = CReducer.apply(c2, CActions.make_match_result(
		0, 0, "haven", {}, {}, {"0": {"inf": 1}}, {"4": 2}), -1)
	assert_false(fout.ok, "buit voor een buitenstaander mag niet")
	# Zonder inzet-veld (oude logs) wordt de buit niet geboekt: het oude pad
	# boekt verliezen en kent geen inzet om te compenseren.
	var c3 := _mini()
	_stem_unaniem(c3, 0, 3)
	_sluit_donaties(c3)
	var voor3: int = int(c3.pool_van(0).inf)
	assert_true(CReducer.apply(c3, CActions.make_match_result(0, 0, "haven", {}, {}, {}, {"0": 2}), -1).ok)
	assert_eq(int(c3.pool_van(0).inf), voor3, "zonder inzet geen buit-boeking (oude logs folden gelijk)")


func test_c15_leeg_testament_kan_niet_stranden_op_een_negatieve_pool() -> void:
	# Vangnet: een pool die door welke boekingsfout ook onder nul staat mag
	# een leeg testament niet blokkeren (gemeten 7 september: pool -6 en de
	# campagne stond muurvast op "boven de helft van het bezit").
	var c := _mini()
	_stem_unaniem(c, 0, 3)
	_sluit_donaties(c)
	var pool3: Dictionary = c.pool_van(3)
	# Speler 3 verliest alles en nog 4 soldaten meer (negatief), houdt CP.
	assert_true(CReducer.apply(c, CActions.make_match_result(
		0, 0, "eliminatie", {}, {},
		{"3": {"inf": int(pool3.inf) + 4, "cav": int(pool3.cav), "art": int(pool3.art)}}), -1).ok)
	assert_eq(String(c.spelers[3].status), "uitgevallen")
	assert_eq(c.fase, CState.Fase.TESTAMENT)
	assert_true(c.pool_totaal_van(3) < 0, "de pool staat expres onder nul")
	var leeg: Dictionary = CReducer.apply(c, CActions.make_testament([]), 3)
	assert_true(leeg.ok, "een leeg testament gaat altijd door: %s" % str(leeg.get("error", "")))
	assert_true(c.fase != CState.Fase.TESTAMENT, "en de campagne loopt door")


# --- Quick chat (25 september): toezeggingen van bots --------------------------

## Een bot met het profiel van de trouwe generaal, eigen loyaliteit en seed.
func _qc_bot(speler: int, loyaliteit: float, seed_val: int) -> CampaignAgent:
	var agent := CampaignAgent.new()
	agent.speler_id = speler
	agent.profiel = (Personalities.ARCHETYPES["trouwe_generaal"] as Dictionary).duplicate(true)
	agent.profiel["loyaliteit"] = loyaliteit
	agent.rng = SeededRng.new(seed_val)
	return agent


func test_qc_toezegging_raad_nakomen() -> void:
	# Loyaliteit 1: de bot stemt precies wat hij toezegde (Stuur 2!, Pak 5!).
	var c := _mini()
	var cview: Dictionary = CView.for_player(c, 1)
	for seed_val in [1, 2, 3, 4, 5]:
		var trouw := _qc_bot(1, 1.0, seed_val)
		trouw.toezeggingen = {"stuur": [2], "pak": [5]}
		var keuze: Dictionary = trouw.kies_nominatie(cview)
		assert_eq(int(keuze.eigen), 2, "trouwe bot stuurt wie hij toezegde")
		assert_eq(int(keuze.vijand), 5, "en pakt wie hij toezegde")
		# Loyaliteit 0: breekt zijn woord, en kiest dan precies wat hij zonder
		# toezegging gekozen had (de nakom-trekkingen komen na de gewone).
		var rat := _qc_bot(1, 0.0, seed_val)
		rat.toezeggingen = {"stuur": [2], "pak": [5]}
		var zonder := _qc_bot(1, 0.0, seed_val)
		assert_eq(rat.kies_nominatie(cview), zonder.kies_nominatie(cview),
			"woordbreker kiest als zonder toezegging")


func test_qc_toezegging_ongeldig_doel_telt_niet() -> void:
	# Al genomineerd of dood: de toezegging vervalt, de bot kiest gewoon.
	var c := _mini(2)
	_stem_unaniem(c, 2, 5)
	var cview: Dictionary = CView.for_player(c, 1)
	var bot := _qc_bot(1, 1.0, 9)
	bot.toezeggingen = {"stuur": [2], "pak": [5]}
	var keuze: Dictionary = bot.kies_nominatie(cview)
	assert_true(int(keuze.eigen) != 2 and int(keuze.vijand) != 5,
		"wie al gekozen is kan niet nog eens")


func test_qc_toezegging_doneren() -> void:
	# Na de raad (0 tegen 3) geeft een bot normaal aan de vechter; met een
	# toezegging aan teamgenoot 2 (die niet vecht) geeft hij aan 2.
	var c := _mini()
	_stem_unaniem(c, 0, 3)
	assert_eq(c.fase, CState.Fase.DONATIE)
	var cview: Dictionary = CView.for_player(c, 1)
	var bot := _qc_bot(1, 1.0, 3)
	var gewoon: Array = bot.kies_donaties(cview)
	assert_eq(gewoon.size(), 1)
	assert_eq(int(gewoon[0].naar), 0, "zonder toezegging: aan de vechter")
	bot.toezeggingen = {"doneer": [2]}
	var beloofd: Array = bot.kies_donaties(cview)
	assert_eq(beloofd.size(), 1)
	assert_eq(int(beloofd[0].naar), 2, "met toezegging: aan wie hij het beloofde")
	assert_true(CReducer.apply(c, beloofd[0], 1).ok, "en de reducer neemt het aan")


func test_qc_driver_antwoorden_en_log() -> void:
	# De driver zet de zin en de antwoorden in de feed, nooit in het log;
	# AKKOORD! is precies de lijst toezeggingen; de doden zwijgen.
	var driver := SoloDriver.new(4242, 0, 6)
	var log_voor: int = driver.clog.entries.size()
	var feed_voor: int = driver.feed.size()
	driver.quick_chat(0, "HUB_QC_STUUR_MIJ")
	assert_eq(driver.clog.entries.size(), log_voor, "quick chat staat nooit in het campagnelog")
	var nieuw: Array = driver.feed.slice(feed_voor)
	assert_true(nieuw.size() >= 2, "zin plus minstens een antwoord")
	assert_eq(String(nieuw[0].qc), "HUB_QC_STUUR_MIJ")
	assert_eq(int(nieuw[0].doel), 0, "Stuur mij gaat over de spreker")
	var team: int = int(driver.c.spelers[0].team)
	var akkoord := 0
	for e in nieuw.slice(1):
		var wie: int = int(e.speler)
		assert_eq(int(driver.c.spelers[wie].team), team, "alleen het eigen team antwoordt")
		if String(e.qc) == "HUB_QC_AKKOORD":
			akkoord += 1
			assert_true((driver.toezeggingen[wie].stuur as Array).has(0), "akkoord is een toezegging")
		else:
			assert_eq(String(e.qc), "HUB_QC_NEE")
			assert_true(not driver.toezeggingen.has(wie), "nee is geen toezegging")
	assert_eq(akkoord, driver.toezeggingen.size())
	driver.c.spelers[0].status = "uitgevallen"
	var n: int = driver.feed.size()
	driver.quick_chat(0, "HUB_QC_VERTROUW")
	assert_eq(driver.feed.size(), n, "de doden zwijgen")


# --- F6.0: punten verdienen en krijgen (docs/F6-punten-masterplan.md) -----------

const _Uitslag := preload("res://core/campaign/uitslag.gd")
const _Punten := preload("res://core/campaign/puntentabel.gd")


## Het rekenvoorbeeld uit het plan (§2) geeft precies 79 / 55 / 44 / 16 / 0.
func test_f6_punten_voorbeeld_uit_het_plan() -> void:
	var leeg := {"team": 0, "team_won": false, "roem": 0, "kampioen": false, "burgeroorlog_over": 0,
		"stunts": 0, "laatste_stand": false, "dank": false, "koningsmaker": false, "testament_vijand": false}
	var vera: Dictionary = leeg.duplicate()
	vera.merge({"team_won": true, "roem": 9, "kampioen": true, "burgeroorlog_over": 1, "stunts": 1}, true)
	var karel: Dictionary = leeg.duplicate()
	karel.merge({"team_won": true, "roem": 10, "burgeroorlog_over": 2}, true)
	var bruno: Dictionary = leeg.duplicate()
	bruno.merge({"team_won": true, "roem": 4, "dank": true, "koningsmaker": true}, true)
	var ida: Dictionary = leeg.duplicate()
	ida.merge({"team": 1, "roem": 6, "laatste_stand": true}, true)
	var otto: Dictionary = leeg.duplicate()
	otto.merge({"team": 1, "roem": 3}, true)
	var p: Dictionary = _Punten.bereken({0: vera, 1: karel, 2: bruno, 3: ida, 4: otto}, {},
		{"vertrokken": [4]})
	assert_eq(int(p[0].totaal), 79, "Vera: 5 + 20 + 9 + 40 + 5")
	assert_eq(int(p[1].totaal), 55, "Karel: 5 + 20 + 10 + 20")
	assert_eq(int(p[2].totaal), 44, "Bruno: 5 + 20 + 4 + 10 + 5")
	assert_eq(int(p[3].totaal), 16, "Ida: 5 + 6 + 5")
	assert_eq(int(p[4].totaal), 0, "wie vertrok krijgt niets")
	var redenen: Array = []
	for regel in p[0].regels:
		redenen.append(String(regel[0]))
	assert_eq(redenen, ["uitgespeeld", "team", "roem", "kampioen", "stunt"], "regels in vaste volgorde")
	assert_eq(_Punten.badges(karel), ["kroonprins"])
	assert_eq(_Punten.badges(bruno), ["koningsmaker"])
	# Een andere tabel (P4 meet de kroonfactor): alleen de kampioen verandert.
	var drie: Dictionary = _Punten.bereken({0: vera}, {"kampioen": 60})
	assert_eq(int(drie[0].totaal), 99, "kroonfactor 3: kampioen 60")
	# Een bot verdient niets.
	var bot: Dictionary = _Punten.bereken({0: vera}, {}, {"bots": [0]})
	assert_eq(int(bot[0].totaal), 0, "bots verdienen niets")


## Een duelronde in de mini-campagne: het nominerende team stemt het paar, de
## donaties sluiten, en het duel wordt geboekt. Met `uitval` verliest de
## verliezer zijn hele voorraad (C3: dan ligt hij eruit).
func _f6_duel(c: CState, winnaar: int, verliezer: int, uitval: bool) -> void:
	var t: int = c.nominatie_team
	var eigen: int = winnaar if int(c.spelers[winnaar].team) == t else verliezer
	var vijand: int = verliezer if eigen == winnaar else winnaar
	_stem_unaniem(c, eigen, vijand)
	_sluit_donaties(c)
	var verliezen: Dictionary = {}
	if uitval:
		var pool: Dictionary = c.pool_van(verliezer)
		verliezen[str(verliezer)] = {"inf": int(pool.inf), "cav": int(pool.cav), "art": int(pool.art)}
	assert_true(CReducer.apply(c, CActions.make_match_result(0, winnaar, "eliminatie", verliezen, {}), -1).ok,
		"duel %d tegen %d geboekt" % [winnaar, verliezer])


## Een hele mini-campagne door de reducer: elke puntenregel komt een keer langs.
## Team 1 (3, 4, 5) valt; 2 valt voor team 0 en laat zijn CP na aan 1; in de
## burgeroorlog verslaat 1 (de lagere plek) 0; de kampioen bedankt 2.
func test_f6_uitslag_uit_een_mini_campagne() -> void:
	var c := _mini()
	_f6_duel(c, 0, 3, true)
	assert_eq(c.fase, CState.Fase.TESTAMENT)
	assert_true(CReducer.apply(c, CActions.make_testament([{"naar": 4, "cp": 5}]), 3).ok)
	_f6_duel(c, 4, 2, true)
	assert_true(CReducer.apply(c, CActions.make_testament([{"naar": 1, "cp": 5}]), 2).ok)
	_f6_duel(c, 1, 4, true)
	assert_true(CReducer.apply(c, CActions.make_tick_deadline(), -1).ok, "4 laat niets na")
	_f6_duel(c, 0, 5, true)
	assert_true(CReducer.apply(c, CActions.make_tick_deadline(), -1).ok, "5 laat niets na")
	assert_eq(c.fase, CState.Fase.BURGEROORLOG, "team 1 is weg")
	assert_eq(c.bracket_grootte, 2)
	assert_eq(CReducer.seed_volgorde(c, c.actieve_leden(0)), [0, 1], "0 staat hoger (meer roem)")
	assert_eq(int(c.duels_deze_ronde[0].p1), 0, "p1 is de hogere plek")
	assert_true(CReducer.apply(c, CActions.make_match_result(0, 1, "eliminatie", {}, {}), -1).ok)
	assert_eq(c.winnaar, 1, "de lagere plek wint: kampioen")
	assert_eq(int(c.stunts.get(1, 0)), 1, "dat is een stunt")
	assert_eq(int(c.uitval[0].over), 2, "0 viel in de finale")
	assert_true(bool(c.uitval[0].burgeroorlog))
	assert_eq(int(c.uitval[3].ronde), 1)
	assert_eq(c.testament_naar.get(2, []), [1])
	# Na de kroning: alleen de kampioen bedankt, een keer, een gevallen teamgenoot.
	assert_false(CReducer.apply(c, CActions.make_tick_deadline(), -1).ok, "verder is het klaar")
	assert_false(CReducer.apply(c, CActions.make_dank(2), 0).ok, "alleen de kampioen bedankt")
	assert_false(CReducer.apply(c, CActions.make_dank(3), 1).ok, "geen vijand")
	assert_false(CReducer.apply(c, CActions.make_dank(1), 1).ok, "niet jezelf")
	assert_true(CReducer.apply(c, CActions.make_dank(2), 1).ok, "een gevallen teamgenoot")
	assert_false(CReducer.apply(c, CActions.make_dank(0), 1).ok, "maar een keer")
	var u: Dictionary = _Uitslag.van(c)
	assert_true(bool(u[1].kampioen) and int(u[1].burgeroorlog_over) == 1)
	assert_eq(int(u[0].burgeroorlog_over), 2, "finalist")
	assert_true(bool(u[2].team_won), "ook wie eruit ligt wint met zijn team")
	assert_true(bool(u[2].koningsmaker), "2 liet na aan de latere kampioen")
	assert_true(bool(u[2].dank))
	assert_false(bool(u[3].testament_vijand), "3 liet na aan zijn eigen team")
	assert_true(bool(u[5].laatste_stand), "5 viel pas in de laatste ronde van team 1")
	assert_false(bool(u[4].laatste_stand))
	var p: Dictionary = _Punten.bereken(u)
	assert_eq(int(p[1].totaal), 5 + 20 + 6 + 40 + 5, "kampioen: roem 2 + teambonus 2 + finale 2, plus een stunt")
	assert_eq(int(p[0].totaal), 5 + 20 + 6 + 20, "finalist")
	assert_eq(int(p[2].totaal), 5 + 20 + 2 + 10 + 5, "gevallen, maar dank en koningsmaker")
	assert_eq(int(p[3].totaal), 5)
	assert_eq(int(p[4].totaal), 5 + 2)
	assert_eq(int(p[5].totaal), 5 + 5, "laatste stand")
	# De nieuwe velden overleven opslaan en teruglezen.
	var d: Dictionary = c.to_dict()
	assert_eq(JSON.stringify(CState.from_dict(d).to_dict()), JSON.stringify(d), "roundtrip byte-identiek")


func test_f6_niemand_bedanken_en_oude_saves() -> void:
	var c := _mini()
	for sid in [3, 4, 5]:
		c.spelers[sid].status = "uitgevallen"
		c.spelers[sid].testament_af = true
	c._boek("punten", 0, 0, 0, 0, 0, 5)
	CReducer._volgende_ronde(c, [])
	while c.fase == CState.Fase.BURGEROORLOG:
		var duel: Dictionary = c.duels_deze_ronde[0]
		assert_true(CReducer.apply(c, CActions.make_match_result(0, int(duel.p1), "haven", {}, {}), -1).ok)
	assert_eq(c.winnaar, 0)
	assert_true(CReducer.apply(c, CActions.make_dank(-1), 0).ok, "niemand bedanken mag")
	assert_true(c.dank_af)
	assert_false(bool(_Uitslag.van(c)[1].dank))
	# Een save van voor F6.0 mist de velden: leeg, en de uitslag rekent gewoon.
	var d: Dictionary = c.to_dict()
	for sleutel in ["uitval", "stunts", "testament_naar", "dank_naar", "dank_af", "bracket_grootte"]:
		d.erase(sleutel)
	var oud: CState = CState.from_dict(d)
	assert_eq(oud.dank_naar, -1)
	assert_false(oud.dank_af)
	assert_eq(_Uitslag.van(oud).size(), 6, "uitslag voor iedereen")


func test_f6_giften_uit_het_grootboek() -> void:
	var c := _mini()
	_stem_unaniem(c, 0, 3)
	assert_true(CReducer.apply(c, CActions.make_donate(0, 2, 1, 0, 1), 1).ok)
	assert_true(CReducer.apply(c, CActions.make_donate(2, 1, 0, 0, 0), 1).ok)
	var g: Dictionary = _Uitslag.giften(c)
	assert_eq(int(g[1][0]), 2 + 2 + 1, "2 soldaten, 1 ruiter (2) en 1 CP")
	assert_eq(int(g[1][2]), 1)
	assert_false(g.has(0), "0 gaf niets")


## De bot-kampioen bedankt wie hem het meest gaf; zonder giften wie de meeste
## roem heeft; de rat niemand.
func test_f6_bot_kampioen_bedankt_leesbaar() -> void:
	var driver := SoloDriver.new(4242, -1, 6)
	var c: CState = driver.c
	var kampioen: int = -1
	var rat: int = -1
	for sid in driver.agents:
		var trouw: float = (driver.agents[sid] as CampaignAgent).gewicht("loyaliteit", 0.8)
		if trouw >= 0.3 and kampioen < 0:
			kampioen = int(sid)
		elif trouw < 0.3 and rat < 0:
			rat = int(sid)
	assert_true(kampioen >= 0, "er is een bot die bedankt")
	var team: int = int(c.spelers[kampioen].team)
	var maten: Array = []
	for sid in c.spelers:
		if int(sid) != kampioen and int(c.spelers[sid].team) == team:
			maten.append(int(sid))
			c.spelers[sid].status = "uitgevallen"
	c.fase = CState.Fase.KLAAR
	c.winnaar = kampioen
	c._boek("punten", int(maten[1]), 0, 0, 0, 0, 4)
	assert_eq(driver.bot_dank_keuze(), int(maten[1]), "zonder giften: de meeste roem")
	c._boek("donate", int(maten[0]), -2, 0, 0, 0, 0)
	c._boek("donate", kampioen, 2, 0, 0, 0, 0)
	assert_eq(driver.bot_dank_keuze(), int(maten[0]), "wie het meest gaf")
	if rat >= 0:
		c.winnaar = rat
		assert_eq(driver.bot_dank_keuze(), -1, "de rat bedankt niemand")


# --- F6.0-P4: bots op punten (docs/F6-punten-masterplan.md hoofdstuk 8) --------

## De zaaiplek die een bot rekent is die van de reducer: roem, CP, pool, id.
func test_p4_zaai_plekken_zoals_de_reducer() -> void:
	var c := _mini()
	c._boek("punten", 2, 0, 0, 0, 0, 3)  # 2 de meeste roem
	c._boek("cp", 1, 0, 0, 0, 4, 0)      # 1 meer CP dan 0
	c._boek("donate", 4, 2, 0, 0, 0, 0)  # 4 twee soldaten meer dan 3 en 5
	for team in [0, 1]:
		var kijker: int = 0 if team == 0 else 3
		var plekken: Dictionary = CampaignAgent.zaai_plekken(CView.for_player(c, kijker), team)
		var volgorde: Array = CReducer.seed_volgorde(c, c.actieve_leden(team))
		for i in volgorde.size():
			assert_eq(int(plekken[int(volgorde[i])]), i + 1, "plek %d van team %d" % [i + 1, team])
	assert_eq(CReducer.seed_volgorde(c, c.actieve_leden(0)), [2, 1, 0])
	assert_eq(CReducer.seed_volgorde(c, c.actieve_leden(1)), [4, 3, 5], "gelijk: laagste id eerst")
	assert_eq(_qc_bot(0, 1.0, 1).plek(CView.for_player(c, 0), 0), 3)


## Druk: 0 zolang de vijand minstens zo groot is, 1 als hij weg is.
func test_p4_druk() -> void:
	var c := _mini()
	var bot := _qc_bot(1, 1.0, 1)
	assert_eq(bot.druk(CView.for_player(c, 1)), 0.0, "even groot: geen druk")
	c.spelers[5].status = "uitgevallen"
	assert_true(absf(bot.druk(CView.for_player(c, 1)) - 1.0 / 3.0) < 0.001, "3 tegen 2: een derde")
	c.spelers[4].status = "uitgevallen"
	assert_true(absf(bot.druk(CView.for_player(c, 1)) - 2.0 / 3.0) < 0.001, "3 tegen 1: twee derde")
	c.spelers[3].status = "uitgevallen"
	assert_eq(bot.druk(CView.for_player(c, 1)), 1.0, "de vijand is weg")
	var d := _mini()
	d.spelers[0].status = "uitgevallen"
	d.spelers[2].status = "uitgevallen"
	assert_eq(bot.druk(CView.for_player(d, 1)), 0.0, "de vijand is groter: geen druk, niet negatief")


## De eigenbelang-knoppen op 0 (of afwezig): dezelfde keuzes en precies
## evenveel trekkingen. Zo speelt een verstand van voor P4 als voorheen.
func test_p4_eigenbelang_op_nul_verandert_niets() -> void:
	var c := _mini()
	c._boek("punten", 0, 0, 0, 0, 0, 5)
	c.spelers[5].status = "uitgevallen"  # er is druk
	var basis := {"w_geef": 0.3, "w_houden": 0.2, "w_ruil": 0.4}
	var nul := basis.duplicate()
	nul["w_sparen"] = 0.0
	nul["w_rivaal"] = 0.0
	for seed_val in [1, 2, 3, 4]:
		var a := _qc_bot(1, 1.0, seed_val)
		var b := _qc_bot(1, 1.0, seed_val)
		a.verstand = basis
		b.verstand = nul
		var cview: Dictionary = CView.for_player(c, 1)
		assert_eq(a.kies_nominatie(cview), b.kies_nominatie(cview), "zelfde stem")
		assert_eq(a.rng.randf(), b.rng.randf(), "evenveel trekkingen")
	_stem_unaniem(c, 0, 3)
	for seed_val in [1, 2]:
		var a := _qc_bot(1, 1.0, seed_val)
		var b := _qc_bot(1, 1.0, seed_val)
		a.verstand = basis
		b.verstand = nul
		var cview: Dictionary = CView.for_player(c, 1)
		assert_eq(a.kies_donaties(cview), b.kies_donaties(cview), "zelfde donaties")
		assert_eq(a.rng.randf(), b.rng.randf(), "evenveel trekkingen")


## w_rivaal: geen versterkingen voor wie boven je staat, wel voor wie onder je
## staat. Zonder druk (de vijand even groot) geeft hij gewoon.
func test_p4_rivaal_geeft_niet_aan_wie_boven_hem_staat() -> void:
	var c := _mini()
	c._boek("punten", 0, 0, 0, 0, 0, 5)  # 0 staat boven 1
	c._boek("punten", 2, 0, 0, 0, 0, 9)  # 2 staat boven 0
	_stem_unaniem(c, 0, 3)
	assert_eq(c.fase, CState.Fase.DONATIE)
	var rivaal := {"w_rivaal": 2.0}
	var een := _qc_bot(1, 1.0, 3)
	een.verstand = rivaal
	assert_eq(int(een.kies_donaties(CView.for_player(c, 1))[0].naar), 0, "zonder druk: gewoon aan de vechter")
	c.spelers[5].status = "uitgevallen"
	c.spelers[4].status = "uitgevallen"
	assert_eq(een.kies_donaties(CView.for_player(c, 1)), [], "1 geeft niets aan 0: die staat boven hem")
	var twee := _qc_bot(2, 1.0, 3)
	twee.verstand = rivaal
	var gift: Array = twee.kies_donaties(CView.for_player(c, 2))
	assert_eq(gift.size(), 1)
	assert_eq(int(gift[0].naar), 0, "2 geeft wel aan 0: die staat onder hem")
	var trouw := _qc_bot(1, 1.0, 3)
	assert_eq(int(trouw.kies_donaties(CView.for_player(c, 1))[0].naar), 0, "zonder w_rivaal: aan de vechter")


## w_sparen: naarmate de oorlog gewonnen raakt geef je minder weg.
func test_p4_sparen_geeft_minder() -> void:
	var c := _mini()
	_stem_unaniem(c, 0, 3)
	var gewoon := _qc_bot(1, 1.0, 3)
	var spaarder := _qc_bot(1, 1.0, 3)
	spaarder.verstand = {"w_sparen": 1.0}
	assert_eq(spaarder.kies_donaties(CView.for_player(c, 1)), gewoon.kies_donaties(CView.for_player(c, 1)),
		"zonder druk: evenveel")
	c.spelers[5].status = "uitgevallen"
	c.spelers[4].status = "uitgevallen"
	var g: Array = gewoon.kies_donaties(CView.for_player(c, 1))
	var s: Array = spaarder.kies_donaties(CView.for_player(c, 1))
	var stuks := func(lijst: Array) -> int:
		return 0 if lijst.is_empty() else int(lijst[0].inf) + int(lijst[0].cav)
	assert_true(stuks.call(s) < stuks.call(g), "met druk geeft de spaarder minder (%d tegen %d)" % [
		stuks.call(s), stuks.call(g)])


## w_rivaal in de raad: wie boven je staat, stuur je het duel in.
func test_p4_rivaal_stuurt_de_leider_de_raad_in() -> void:
	var c := _mini()
	c._boek("punten", 0, 0, 0, 0, 0, 5)  # 0 is de roemleider
	c.spelers[5].status = "uitgevallen"
	c.spelers[4].status = "uitgevallen"
	for seed_val in [1, 2, 3, 4, 5]:
		var bot := _qc_bot(1, 1.0, seed_val)
		bot.verstand = {"w_rivaal": 2.0}
		assert_eq(int(bot.kies_nominatie(CView.for_player(c, 1)).eigen), 0, "1 stuurt de leider (seed %d)" % seed_val)
		var leider := _qc_bot(0, 1.0, seed_val)
		leider.verstand = {"w_rivaal": 2.0}
		assert_eq(leider.kies_nominatie(CView.for_player(c, 0)), _qc_bot(0, 1.0, seed_val).kies_nominatie(
			CView.for_player(c, 0)), "de leider zelf heeft geen rivaal en stemt gewoon")


## Een klein nep-orakel voor de tests: wie meer reserve heeft wint vaker, de
## verliezer zet alles in en verliest het. Op een pad, want de arena laadt het
## orakel van een pad.
func _p4_orakel() -> String:
	var rijen: Array = []
	for ra in [0, 3, 6, 9, 12, 15]:
		for rb in [0, 3, 6, 9, 12, 15]:
			var p: float = clampf(0.5 + 0.1 * float(ra - rb) / 3.0, 0.1, 0.9)
			for i in 10:
				var w: int = 1 if float(i) < p * 10.0 else 2
				var inzet_a: int = ra if w == 2 else ra / 2
				var inzet_b: int = rb if w == 1 else rb / 2
				rijen.append([0, 0, ra, rb, 0, 0, w, "eliminatie", 5,
					inzet_a, 0, 0, inzet_b, 0, 0, 0, 0, 0, 0,
					inzet_a if w == 2 else 0, 0, 0, inzet_b if w == 1 else 0, 0, 0,
					ra, 0, 0, rb, 0, 0])
	var pad := "user://p4_test_orakel.json"
	var f := FileAccess.open(pad, FileAccess.WRITE)
	f.store_string(JSON.stringify({"rijen": rijen, "duels": rijen.size()}))
	f.close()
	return pad


## De puntenfitness: hetzelfde verstand in beide helften geeft precies de
## helft en geen verschil (de stoelen wisselen per seed), en de arena telt de
## punten per stoel, de burgeroorlog en de raad.
func test_p4_puntenfitness_en_arena() -> void:
	var speel := {"spelers": 16, "duel_modus": "orakel", "orakel": _p4_orakel(), "duel_log": false,
		"max_stappen": 400, "tabel": {"kampioen": 60}, "meet_raad": true}
	var v := {"w_geef": 0.2, "w_houden": 0.1}
	var p: Dictionary = CampagneTrainer.speel_punten(speel, v, v, [11])
	assert_eq(int(p.n), 2, "twee campagnes per seed, beide uitgespeeld")
	assert_eq(float(p.kans), 0.5, "zelfde verstand: precies de helft")
	assert_eq(float(p.verschil), 0.0, "en geen verschil")
	var uit: Dictionary = CampagneArena.speel_campagne(speel, 11,
		[{"naam": "a", "verstand": v}, {"naam": "b", "verstand": v}])
	var s: Dictionary = uit.samenvatting
	assert_true(bool(s.klaar), "uitgespeeld")
	assert_eq((s.punten as Dictionary).size(), 16, "punten voor elke stoel")
	assert_true(int(s.punten[str(int(s.winnaar))]) >= 85, "de kampioen: 5 + 20 + 60 van deze tabel")
	assert_true(int(s.nominaties) > 0, "de raad koos duels")
	assert_true(int(s.leider_gestuurd) <= int(s.nominaties) and int(s.leider_slecht) <= int(s.leider_gestuurd)
		and int(s.slecht_gestuurd) <= int(s.nominaties), "de tellingen passen in elkaar")
	assert_true(int(s.donatie_rondes) > 0, "er waren donatierondes")
	if bool(s.burgeroorlog):
		assert_true(int(s.burgeroorlog_spelers) >= 2, "een burgeroorlog heeft minstens twee spelers")


## De trainer: welke knoppen hij standaard verschuift, en waar hij begint.
func test_p4_trainer_sleutels_en_start() -> void:
	var team: Array = CampagneTrainer.standaard_sleutels("team")
	var punten: Array = CampagneTrainer.standaard_sleutels("punten")
	assert_false(team.has("w_sparen") or team.has("w_rivaal"), "de teamtrainer laat het eigenbelang met rust")
	assert_true(punten.has("w_sparen") and punten.has("w_rivaal"), "de puntentrainer niet")
	assert_eq(punten.size(), CampaignAgent.VERSTAND.size())
	var pad := "user://p4_test_start.json"
	var f := FileAccess.open(pad, FileAccess.WRITE)
	f.store_string(JSON.stringify({"versie": 1, "gewichten": {"w_matchup": 0.7, "w_rivaal": 0.5}}))
	f.close()
	var start: Dictionary = CampagneTrainer._start({"start": pad}, "user://bestaat_niet_p4.json")
	assert_eq(float(start.w_matchup), 0.7, "zonder uitvoer begint hij bij het startverstand")
	assert_eq(float(start.w_rivaal), 0.5)
	assert_eq(float(start.w_sparen), 0.0, "ontbrekende knoppen op 0")
