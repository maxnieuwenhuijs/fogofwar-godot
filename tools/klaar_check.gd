extends RefCounted

## `-- klaarcheck` (30 september): de loting en de klaarmelding voor de start
## van een campagne, in de echte hub (headless of met venster).
##
##  solo      beweging uit: alle paren meteen, KLAAR open, 15 van 16 klaar,
##            geen klok. KLAAR: de campagne begint, na de pauze is het scherm
##            weg, de golf van de hub liep en de aftel naar het bord staat.
##            Terug in de hub (zelfde driver) komt het scherm niet terug.
##  onthul    beweging aan (geforceerd): de paren komen een voor een (eerst
##            onzichtbaar, daarna in rust), KLAAR pas na de onthulling, en de
##            aftel naar het bord loopt NIET zolang het scherm openstaat.
##            "Alles tonen" haalt alles meteen naar voren.
##  oefenen   de start van een online campagne met nagespeelde spelers: jij te
##            laat is TE LAAT; jij op tijd, een ander te laat: eruit, zoeken,
##            invallen (of een bot), en dan het einde van het oefenen.
##  duel      de weg naar het bord (6 oktober, Max: "ineens rambam bam ben je
##            op het spel"): de hub zegt hoe lang nog en telt af, na 3 s staat
##            hij er nog; NAAR HET BORD toont eerst het duel-intro (de kanten
##            schuiven in), het bord komt pas na het intro, en een tik op het
##            intro gaat meteen door. Zonder scene-wissel (bord_pad leeg).
##
## Exit 1 bij een fout; de grep op "SCRIPT ERROR" hoort erbij.

const Beweging := preload("res://scripts/ui/ui_beweging.gd")
const HUB := "res://scripts/ui/campaign/campaign_hub.gd"
const FASEN := ["solo", "onthul", "oefenen", "duel"]

static var _fouten := 0
static var _host: Node = null


static func run(host: Node, fasen: Array = []) -> int:
	_fouten = 0
	_host = host
	var te_doen: Array = FASEN if fasen.is_empty() else fasen
	for fase in te_doen:
		match String(fase):
			"solo":
				await _solo()
			"onthul":
				await _onthul()
			"oefenen":
				await _oefenen()
			"duel":
				await _duel()
			_:
				_fouten += 1
				print("[KLAAR] onbekende fase: %s (bekend: %s)" % [fase, ", ".join(FASEN)])
	Beweging.forceer(-1)
	print("[KLAAR] %s: %d fouten" % ["PASS" if _fouten == 0 else "FAIL", _fouten])
	return _fouten


static func _ok(voorwaarde: bool, wat: String) -> void:
	if voorwaarde:
		print("[KLAAR]   ok   %s" % wat)
	else:
		_fouten += 1
		print("[KLAAR]   FOUT %s" % wat)


static func _wacht(s: float) -> void:
	await _host.get_tree().create_timer(s, true, false, true).timeout
	await _host.get_tree().process_frame


## Een verse hub op een verse campagne (ronde 1, voor de loting).
static func _hub(oefenen: bool = false) -> Control:
	var driver := SoloDriver.new(42, 0)
	driver.duel_ai = "easy"
	var hub: Control = load(HUB).new()
	hub.set("driver", driver)
	hub.set("mens_id", 0)
	if oefenen:
		hub.set("_oefenen", true)
		hub.set("km_sim_seed", 7)
	_host.add_child(hub)
	return hub


static func _rijen(hub: Control) -> Array:
	var laag: Node = hub.find_child("Klaarmelding", true, false)
	return [] if laag == null else laag.find_children("Paar_*", "", true, false)


## Weg met de hub zonder dat de aftel naar het bord nog een scene-wissel doet.
static func _ruim_op(hub: Control) -> void:
	var driver = hub.get("driver")
	if driver != null:
		var d: Dictionary = driver.mens_duel()
		if not d.is_empty():
			hub.set("_auto_stop_idx", int(d.idx))
		if CampaignBridge.driver == driver:
			CampaignBridge.driver = null
	hub.queue_free()
	await _wacht(0.2)


# --- solo: zonder beweging, alles meteen ------------------------------------------

static func _solo() -> void:
	print("[KLAAR] fase solo")
	Beweging.forceer(0)
	var hub := _hub()
	await _wacht(0.2)
	var rijen := _rijen(hub)
	_ok(rijen.size() == 8, "de loting: 8 paren (%d)" % rijen.size())
	var alle_zichtbaar := true
	for r in rijen:
		if (r as Control).modulate.a < 0.99:
			alle_zichtbaar = false
	_ok(alle_zichtbaar, "zonder beweging staan alle paren er meteen")
	var laatste: Node = rijen.back() if not rijen.is_empty() else null
	_ok(laatste != null and laatste.find_child("JouwDuel", true, false) != null
		and laatste.find_child("Kant_0", true, false) != null, "jouw paar staat onderaan, met JOUW DUEL")
	var km = hub.get("_km")
	_ok(km != null and int(km.aantal_klaar()) == 15 and not bool(km.gestart), "15 van 16 klaar: de bots meteen, jij nog niet")
	_ok(hub.find_child("KlaarKlok", true, false) == null, "solo: geen klok")
	var knop: Button = hub.find_child("KlaarmeldKnop", true, false)
	_ok(knop != null and not knop.disabled, "KLAAR staat open")
	var voet: Node = hub.find_child("FaseVoet", true, false)
	_ok(voet != null and voet.find_child("Aftel", true, false) == null, "geen aftel naar het bord onder het scherm")
	var driver = hub.get("driver")
	var entries_voor: int = (driver.clog.entries as Array).size()
	if knop != null:
		knop.pressed.emit()
	_ok(km != null and bool(km.gestart) and hub.find_child("KlaarStart", true, false) != null,
		"KLAAR: de campagne begint (stempel)")
	_ok((driver.clog.entries as Array).size() == entries_voor, "klaarmelden schrijft niets in het campagnelog")
	await _wacht(1.6)
	_ok(hub.find_child("Klaarmelding", true, false) == null, "na de pauze is het scherm weg")
	_ok(bool(driver.klaar_gemeld) and bool(hub.get("_cascade_gedaan")), "de hub bouwt zich op (golf gedaan)")
	voet = hub.find_child("FaseVoet", true, false)
	_ok(voet != null and voet.find_child("Aftel", true, false) != null
		and voet.find_child("SpeelDuelKnop", true, false) != null, "de aftel naar het bord loopt")
	await _ruim_op(hub)
	# Terug in de hub met dezelfde driver (van het menu of het bord): niet opnieuw.
	var hub2: Control = load(HUB).new()
	hub2.set("driver", driver)
	hub2.set("mens_id", 0)
	_host.add_child(hub2)
	await _wacht(0.2)
	_ok(hub2.find_child("Klaarmelding", true, false) == null, "zelfde campagne terug: geen klaarmelding meer")
	await _ruim_op(hub2)
	Beweging.forceer(-1)


# --- onthul: met beweging, een voor een ---------------------------------------------

static func _onthul() -> void:
	print("[KLAAR] fase onthul")
	Beweging.forceer(1)
	var hub := _hub()
	var t0 := Time.get_ticks_msec()
	var rijen := _rijen(hub)
	var verborgen := 0
	for r in rijen:
		if (r as Control).modulate.a < 0.05:
			verborgen += 1
	_ok(rijen.size() == 8 and verborgen == 8, "bij het openen zijn alle paren nog verborgen (%d van %d)" % [verborgen, rijen.size()])
	_ok(hub.find_child("KlaarmeldKnop", true, false) == null and not bool(hub.get("_km_open")),
		"KLAAR is er nog niet tijdens de onthulling")
	# Halverwege: de eersten staan, de laatsten nog niet.
	var constanten: Dictionary = (load(HUB) as GDScript).get_script_constant_map()
	var km_voor: float = float(constanten.KM_VOOR)
	var km_stap: float = float(constanten.KM_STAP)
	var t_mid: float = km_voor + 3.0 * km_stap + 0.3
	await _wacht(t_mid)
	var zichtbaar := 0
	for r in rijen:
		if (r as Control).modulate.a > 0.9:
			zichtbaar += 1
	var laatste_weg: bool = (rijen.back() as Control).modulate.a < 0.05
	_ok(zichtbaar >= 2 and zichtbaar <= 6 and laatste_weg,
		"na %.1f s: %d paren in beeld, het jouwe nog niet" % [(Time.get_ticks_msec() - t0) / 1000.0, zichtbaar])
	var voet: Node = hub.find_child("FaseVoet", true, false)
	_ok(voet != null and voet.find_child("Aftel", true, false) == null, "tijdens de onthulling geen aftel naar het bord")
	# Na de onthulling: alles in rust, KLAAR open.
	var t_eind: float = km_voor + 8.0 * km_stap + 0.6
	var rest: float = t_eind - (Time.get_ticks_msec() - t0) / 1000.0
	if rest > 0.0:
		await _wacht(rest)
	var t_wacht := Time.get_ticks_msec()
	while Beweging.bezig() > 0 and Time.get_ticks_msec() - t_wacht < 2000:
		await _host.get_tree().process_frame
	var rust := true
	for r in rijen:
		var c := r as Control
		if c.modulate.a < 0.99 or c.scale.distance_to(Vector2.ONE) > 0.001:
			rust = false
	_ok(rust, "na de onthulling staan alle paren in rust")
	var knop: Button = hub.find_child("KlaarmeldKnop", true, false)
	_ok(bool(hub.get("_km_open")) and knop != null and not knop.disabled,
		"KLAAR gaat open na de onthulling (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	await _ruim_op(hub)
	# "Alles tonen": meteen alles, en KLAAR open.
	var hub2 := _hub()
	await _wacht(0.1)
	var alles: Button = hub2.find_child("KmAllesKnop", true, false)
	_ok(alles != null, "tijdens de onthulling staat Alles tonen")
	if alles != null:
		alles.pressed.emit()
	await _wacht(0.45)
	var rust2 := true
	for r in _rijen(hub2):
		if (r as Control).modulate.a < 0.99:
			rust2 = false
	_ok(rust2 and bool(hub2.get("_km_open")) and hub2.find_child("KlaarmeldKnop", true, false) != null,
		"Alles tonen: alle paren meteen en KLAAR open")
	await _ruim_op(hub2)
	Beweging.forceer(-1)


# --- oefenen: de klok, eruit, zoeken, invallen ------------------------------------

## De klok van het scherm doorspoelen in stappen van een halve seconde.
static func _spoel(hub: Control, stappen: int, druk_bij: int = -1) -> void:
	for stap in stappen:
		if hub.get("_km") == null:
			return
		hub.set("_km_klok_ms", int(hub.get("_km_klok_ms")) + 500)
		if stap == druk_bij:
			hub.call("_km_druk_klaar")
		hub.call("_km_tik")


static func _oefenen() -> void:
	print("[KLAAR] fase oefenen")
	Beweging.forceer(0)
	# Jij drukt niet: na de klok TE LAAT.
	var hub := _hub(true)
	await _wacht(0.2)
	var km = hub.get("_km")
	_ok(km != null and hub.find_child("KlaarKlok", true, false) != null, "oefenen: er loopt een klok")
	var bots := 0
	for st in km.stoelen:
		if String(st.soort) == "bot":
			bots += 1
	_ok(bots == 8 and hub.find_children("Bot_*", "", true, false).size() == 8,
		"oefenen: acht bots, zichtbaar met BOT (%d)" % bots)
	_spoel(hub, 44)   # 22 s: voorbij de klok van 20 s
	await _wacht(0.1)
	_ok(hub.find_child("Eruit", true, false) != null and hub.get("_km") == null, "jij te laat: TE LAAT")
	await _ruim_op(hub)
	# Jij op tijd, een ander nooit: eruit, dan een vervanger of een bot, dan klaar.
	var hub2 := _hub(true)
	await _wacht(0.2)
	var km2 = hub2.get("_km")
	var sim = hub2.get("_km_sim")
	var afk: int = int(sim.mensen[0])
	sim.maak_afk(afk)
	_spoel(hub2, 120, 3)
	var soorten: Array = []
	for e in km2.gebeurd:
		if int(e.stoel) == afk:
			soorten.append(String(e.soort))
	_ok(soorten.size() >= 2 and soorten[0] == "eruit" and (soorten[1] == "vervangen" or soorten[1] == "bot"),
		"een ander te laat: eruit, dan %s (%s)" % [soorten[1] if soorten.size() > 1 else "?", ", ".join(soorten)])
	_ok(bool(km2.gestart), "oefenen: iedereen klaar, de campagne begint")
	var regels: Node = hub2.find_child("KlaarMeldingen", true, false)
	_ok(regels != null and regels.get_child_count() >= 1, "er staan regels onder de klok (%d)" %
		(regels.get_child_count() if regels != null else 0))
	await _wacht(1.6)
	_ok(hub2.find_child("OefenEinde", true, false) != null and hub2.find_child("Klaarmelding", true, false) == null,
		"oefenen: daarna het einde van het oefenen")
	_ok(CampaignBridge.driver == null or CampaignBridge.driver != hub2.get("driver"),
		"oefenen raakt de brug niet")
	await _ruim_op(hub2)
	Beweging.forceer(-1)


# --- duel: de weg naar het bord (6 oktober) -----------------------------------------

## Een hub die meteen bij jouw duel staat (de klaarmelding overgeslagen), met
## het orakel (dan zijn de bot-duels die de brug start meteen klaar) en zonder
## scene-wissel naar het bord.
static func _hub_duel() -> Control:
	var hs = load("res://tools/hub_shot.gd")
	var orakel := "res://data/duel_orakel.json" if FileAccess.file_exists("res://data/duel_orakel.json") else ""
	var driver = hs._nieuwe_driver(42, orakel)
	var hub: Control = load(HUB).new()
	hub.set("driver", driver)
	hub.set("mens_id", 0)
	hub.set("klaar_overslaan", true)
	hub.set("bord_pad", "")
	_host.add_child(hub)
	return hub


## Na NAAR HET BORD loopt de brug: zijn bot-duels afwachten en hem leeg achterlaten.
static func _ruim_op_duel(hub: Control) -> void:
	CampaignBridge._wacht_op_sim()
	CampaignBridge.duel_actief = false
	await _ruim_op(hub)


static func _getal(l: Label) -> int:
	if l == null:
		return -1
	var re := RegEx.new()
	re.compile("[0-9]+")
	var m := re.search(l.text)
	return int(m.get_string()) if m != null else -1


static func _duel() -> void:
	print("[KLAAR] fase duel")
	var constanten: Dictionary = (load(HUB) as GDScript).get_script_constant_map()
	var aftel_sec: float = float(constanten.DUEL_AFTEL_SEC)
	var intro_sec: float = float(constanten.DUEL_INTRO_SEC)
	_ok(aftel_sec >= 6.0 and intro_sec >= 2.0, "de aftel duurt %.1f s en het intro %.1f s" % [aftel_sec, intro_sec])
	Beweging.forceer(1)
	var hub := _hub_duel()
	await _wacht(0.3)
	var tekst: Label = hub.find_child("DuelAftelTekst", true, false)
	var getal_1 := _getal(tekst)
	_ok(getal_1 >= int(aftel_sec) - 1 and getal_1 <= int(aftel_sec),
		"de hub zegt hoe lang nog (%s)" % (tekst.text if tekst != null else "-"))
	await _wacht(1.2)
	var getal_2 := _getal(tekst)
	_ok(getal_2 >= 0 and getal_2 < getal_1, "en telt af (%d -> %d)" % [getal_1, getal_2])
	await _wacht(1.5)
	_ok(int(hub.get("naar_bord_ms")) == 0 and hub.find_child("Lader", true, false) == null,
		"na 3 s staat de hub er nog: geen klap naar het bord")
	# NAAR HET BORD: eerst het intro, en het bord pas na het intro.
	var t0 := Time.get_ticks_msec()
	var speel: Button = hub.find_child("SpeelDuelKnop", true, false)
	if speel != null:
		speel.pressed.emit()
	await _wacht(0.1)
	var lader: Node = hub.find_child("Lader", true, false)
	var jij: Control = lader.find_child("IntroJij", true, false) if lader != null else null
	_ok(jij != null and lader.find_child("IntroHij", true, false) != null and lader.find_child("IntroVS", true, false) != null
		and lader.find_child("IntroBalk", true, false) != null, "NAAR HET BORD: eerst het duel-intro, jij tegen hem")
	var rust_x: float = (jij.get_meta("ub_rust_position") as Vector2).x if jij != null and jij.has_meta("ub_rust_position") else 0.0
	var nu_x: float = jij.position.x if jij != null else 0.0
	_ok(jij != null and jij.has_meta("ub_rust_position") and nu_x < rust_x - 20.0,
		"jouw kant schuift van links in (x %.0f, eindplek %.0f)" % [nu_x, rust_x])
	await _wacht(1.0)
	_ok(jij != null and not jij.has_meta("ub_rust_position"), "en staat na een seconde op zijn plek")
	_ok(int(hub.get("naar_bord_ms")) == 0, "na 1 s nog geen bord")
	while int(hub.get("naar_bord_ms")) == 0 and Time.get_ticks_msec() - t0 < 6000:
		await _host.get_tree().process_frame
	var na: float = (int(hub.get("naar_bord_ms")) - t0) / 1000.0
	_ok(na >= intro_sec - 0.1 and na < intro_sec + 1.0, "het bord komt na het intro (%.2f s)" % na)
	await _ruim_op_duel(hub)
	# Een tik op het intro: meteen door.
	var hub2 := _hub_duel()
	await _wacht(0.3)
	var t1 := Time.get_ticks_msec()
	var speel2: Button = hub2.find_child("SpeelDuelKnop", true, false)
	if speel2 != null:
		speel2.pressed.emit()
	await _wacht(0.3)
	var laag: Control = hub2.find_child("Lader", true, false)
	if laag != null:
		var klik := InputEventMouseButton.new()
		klik.button_index = MOUSE_BUTTON_LEFT
		klik.pressed = true
		laag.gui_input.emit(klik)
	while int(hub2.get("naar_bord_ms")) == 0 and Time.get_ticks_msec() - t1 < 4000:
		await _host.get_tree().process_frame
	var na2: float = (int(hub2.get("naar_bord_ms")) - t1) / 1000.0
	_ok(na2 > 0.0 and na2 < 0.9, "een tik op het intro: meteen naar het bord (%.2f s)" % na2)
	await _ruim_op_duel(hub2)
	Beweging.forceer(-1)
