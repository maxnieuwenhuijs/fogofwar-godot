extends TestSuite

# 30 september: de klaarmelding voor de start van een campagne
# (core/campaign/klaarmelding.gd) en de nagespeelde online spelers
# (scripts/game/klaar_sim.gd). Pure logica met een nepklok in milliseconden.

const Klaarmelding := preload("res://core/campaign/klaarmelding.gd")
const KlaarSim := preload("res://scripts/game/klaar_sim.gd")


func _class_name() -> String:
	return "KlaarmeldingTests"


## 16 stoelen, 0-7 team 0 en 8-15 team 1; `mensen` zijn mens, de rest bot.
func _spelers(mensen: Array) -> Array:
	var uit: Array = []
	for s in 16:
		uit.append({"naam": "S%d" % s, "doctrine": s % 6, "team": 0 if s < 8 else 1,
			"soort": Klaarmelding.MENS if mensen.has(s) else Klaarmelding.BOT})
	return uit


func _paren() -> Array:
	var uit: Array = []
	for i in 8:
		uit.append([i, i + 8])
	return uit


func _soorten(km) -> Array:
	var uit: Array = []
	for e in km.gebeurd:
		uit.append("%s:%d" % [e.soort, int(e.stoel)])
	return uit


func test_solo_bots_meteen_klaar_en_geen_klok() -> void:
	var km := Klaarmelding.new()
	km.setup(_spelers([0]), _paren(), Klaarmelding.SOLO)
	assert_eq(km.aantal_klaar(), 15, "de bots zijn meteen klaar")
	assert_false(bool(km.meld_klaar(0, 100).ok), "te vroeg: de paren worden nog getoond")
	km.open(1000)
	assert_eq(int(km.stoelen[0].deadline_ms), 0, "solo: geen klok")
	km.tik(10000000)
	assert_eq(String(km.stoelen[0].status), Klaarmelding.WACHT, "zonder klok ligt niemand eruit, hoe lang ook")
	assert_false(km.gestart)
	assert_true(bool(km.meld_klaar(0, 10000001).ok), "jij drukt KLAAR")
	assert_true(km.gestart, "iedereen klaar: de campagne begint")
	assert_eq(_soorten(km), ["klaar:0", "start:-1"])
	assert_false(bool(km.meld_klaar(0, 10000002).ok), "dubbel telt niet")


func test_alleen_bots_begint_bij_openen() -> void:
	var km := Klaarmelding.new()
	km.setup(_spelers([]), _paren(), Klaarmelding.ONLINE)
	km.open(0)
	assert_true(km.gestart, "zonder mensen begint het meteen")


func test_te_laat_eruit_zoeken_vervanger_start() -> void:
	var km := Klaarmelding.new()
	km.setup(_spelers([0, 3]), _paren(), {"klaar_sec": 30.0, "vervang_sec": 20.0, "zoek_sec": 15.0})
	km.open(1000)
	assert_eq(int(km.stoelen[3].deadline_ms), 31000, "30 s vanaf het openen")
	assert_true(bool(km.meld_klaar(0, 5000).ok))
	assert_eq(km.tik(30999), [], "net voor de klok: niets")
	assert_false(bool(km.meld_klaar(3, 31000).ok), "precies op de klok: te laat")
	var nu: Array = km.tik(31000)
	assert_eq(nu.size(), 1, "een gebeurtenis in deze tik")
	assert_eq(String(nu[0].soort), "eruit")
	assert_eq(String(nu[0].naam), "S3", "met de naam van wie eruit ligt")
	var st: Dictionary = km.stoelen[3]
	assert_eq(String(st.status), Klaarmelding.ZOEKT)
	assert_eq(int(st.zoek_tot_ms), 46000, "15 s zoeken")
	assert_eq(String(st.vorige), "S3")
	assert_false(bool(km.vervang(3, "Gast-AB23", 46000).ok), "na het zoeken is het te laat voor een vervanger")
	assert_true(bool(km.vervang(3, "Gast-AB23", 36000).ok), "het zoeken vond iemand")
	st = km.stoelen[3]
	assert_eq(String(st.naam), "Gast-AB23")
	assert_eq(int(st.team), 0, "team blijft")
	assert_eq(int(st.doctrine), 3, "factie blijft")
	assert_eq(km.paren[3], [3, 11], "het paar blijft")
	assert_eq(int(st.deadline_ms), 56000, "de vervanger krijgt 20 s")
	assert_true(bool(km.meld_klaar(3, 40000).ok))
	assert_true(km.gestart)
	assert_eq(_soorten(km), ["klaar:0", "eruit:3", "vervangen:3", "klaar:3", "start:-1"])
	var vervangen: Dictionary = km.gebeurd[2]
	assert_eq(String(vervangen.oud), "S3", "de regel weet wie hij vervangt")


func test_niemand_gevonden_bot_valt_in() -> void:
	var km := Klaarmelding.new()
	km.setup(_spelers([0, 9]), _paren(), {"klaar_sec": 10.0, "vervang_sec": 10.0, "zoek_sec": 5.0},
		["Aart", "Bea"])
	km.open(0)
	km.meld_klaar(0, 1000)
	km.tik(10000)
	assert_eq(String(km.stoelen[9].status), Klaarmelding.ZOEKT)
	km.tik(14999)
	assert_false(km.gestart, "nog aan het zoeken")
	var nu: Array = km.tik(15000)
	assert_eq(String(nu[0].soort), "bot")
	assert_eq(String(nu[0].naam), "Aart", "de eerste naam uit bot_namen")
	assert_eq(String(nu[0].oud), "S9")
	assert_eq(String(km.stoelen[9].soort), Klaarmelding.BOT)
	assert_eq(String(km.stoelen[9].status), Klaarmelding.KLAAR, "een bot is meteen klaar")
	assert_true(km.gestart, "en dan begint het")


func test_vervanger_ook_te_laat_opnieuw_eruit() -> void:
	var km := Klaarmelding.new()
	km.setup(_spelers([5]), _paren(), {"klaar_sec": 10.0, "vervang_sec": 4.0, "zoek_sec": 10.0})
	km.open(0)
	km.tik(10000)
	km.vervang(5, "Gast-2222", 12000)
	km.tik(15999)
	assert_eq(String(km.stoelen[5].status), Klaarmelding.WACHT)
	km.tik(16000)
	assert_eq(String(km.stoelen[5].status), Klaarmelding.ZOEKT, "de vervanger was ook te laat")
	assert_eq(String(km.stoelen[5].vorige), "Gast-2222")
	assert_eq(_soorten(km), ["eruit:5", "vervangen:5", "eruit:5"])


func test_volgende_deadline_en_niet_klaar() -> void:
	var km := Klaarmelding.new()
	km.setup(_spelers([0, 1]), _paren(), {"klaar_sec": 30.0, "vervang_sec": 20.0, "zoek_sec": 15.0})
	assert_eq(km.volgende_deadline(), 0, "voor het openen loopt er niets")
	km.open(0)
	assert_eq(km.niet_klaar(), [0, 1])
	assert_eq(km.volgende_deadline(), 30000)
	km.meld_klaar(0, 100)
	km.tik(30000)
	assert_eq(km.niet_klaar(), [1])
	assert_eq(km.volgende_deadline(), 45000, "nu het eind van het zoeken")


func test_to_dict_rondje() -> void:
	var km := Klaarmelding.new()
	km.setup(_spelers([0, 2]), _paren(), Klaarmelding.ONLINE, ["Aart"])
	km.open(0)
	km.meld_klaar(0, 10)
	km.tik(30000)
	var kopie := Klaarmelding.new()
	kopie.from_dict(JSON.parse_string(JSON.stringify(km.to_dict())))
	# JSON maakt van ints floats: vergelijk langs dezelfde route.
	assert_eq(JSON.stringify(kopie.to_dict()), JSON.stringify(km.to_dict()), "opslaan en teruglezen verandert niets")
	kopie.tik(50000)
	km.tik(50000)
	assert_eq(_soorten(kopie), _soorten(km), "en daarna loopt het hetzelfde")


## De nagespeelde spelers met een nepklok: tot de start, jij drukt na 2 s.
func _speel_sim(seed_val: int, afk_eerste: bool = false) -> Array:
	var sim := KlaarSim.new(seed_val)
	var spelers: Array = []
	for s in 16:
		spelers.append({"naam": "S%d" % s, "doctrine": s % 6, "team": 0 if s < 8 else 1})
	var km = sim.maak(spelers, _paren(), 0, ["Aart", "Bea", "Cor", "Dop"])
	if afk_eerste:
		sim.maak_afk(int(sim.mensen[0]))
	km.open(0)
	var nu := 0
	while not km.gestart and nu < 300000:
		nu += 100
		if nu == 2000:
			km.meld_klaar(0, nu)
		sim.stap(km, nu)
		km.tik(nu)
	return [km, sim, nu]


func test_sim_mensen_bots_en_regels() -> void:
	var sim := KlaarSim.new(3)
	var spelers: Array = []
	for s in 16:
		spelers.append({"naam": "S%d" % s, "doctrine": 0, "team": 0 if s < 8 else 1})
	var km = sim.maak(spelers, _paren(), 0)
	assert_eq(sim.mensen.size(), KlaarSim.MENSEN, "zeven andere mensen")
	assert_false(sim.mensen.has(0), "jij hoort er niet bij")
	var mensen := 0
	for st in km.stoelen:
		if String(st.soort) == Klaarmelding.MENS:
			mensen += 1
	assert_eq(mensen, KlaarSim.MENSEN + 1, "met jou acht mensen, de rest bots")
	assert_eq(float(km.regels.klaar_sec), float(KlaarSim.REGELS.klaar_sec))


func test_sim_komt_altijd_tot_de_start() -> void:
	for seed_val in range(1, 25):
		var uit: Array = _speel_sim(seed_val, true)
		assert_true(bool(uit[0].gestart), "seed %d: iedereen klaar binnen 5 minuten nepklok (%d ms)" % [seed_val, int(uit[2])])


func test_sim_een_afk_ligt_eruit_en_wordt_vervangen_of_bot() -> void:
	var uit: Array = _speel_sim(7, true)
	var km = uit[0]
	var afk: int = int(uit[1].mensen[0])
	var soorten: Array = []
	for e in km.gebeurd:
		if int(e.stoel) == afk:
			soorten.append(String(e.soort))
	assert_eq(soorten[0], "eruit", "wie nooit drukt, ligt eruit")
	assert_true(soorten[1] == "vervangen" or soorten[1] == "bot", "en krijgt een vervanger of een bot")


func test_sim_deterministisch_en_zonder_globale_rng() -> void:
	seed(1234)
	var a := randi()
	seed(1234)
	var eerste: Array = _speel_sim(11)
	var b := randi()
	assert_eq(a, b, "de nagespeelde spelers trekken niet uit de globale rng")
	var tweede: Array = _speel_sim(11)
	assert_eq(JSON.stringify(eerste[0].gebeurd), JSON.stringify(tweede[0].gebeurd), "zelfde seed: precies hetzelfde")
