extends RefCounted

## `-- inkomcheck [fase...]` (capture.tscn): bewijst dat de UI-beweging
## (scripts/ui/ui_beweging.gd, 30 september) alleen beeld is. Alles eindigt
## exact in zijn rust, niets schrijft als de beweging uit staat, en de
## schermen en knoppen van het spel doen wat het plan zegt. De check forceert
## de beweging ook headless (`Beweging.forceer(1)`) en gebruikt een eigen
## settings-bestand, zodat de stand van de speler blijft staan.
##
## Fasen (zonder argument: allemaal): module, knoppen, schermen, kaart, hub,
## beloning (die alleen met data/duel_orakel.json), instelling.
## Exit 1 bij een fout; de grep op "SCRIPT ERROR" hoort erbij.

const Beweging := preload("res://scripts/ui/ui_beweging.gd")
const CHECK_CFG := "user://settings_inkomcheck.cfg"
const FASEN := ["module", "knoppen", "schermen", "kaart", "hub", "beloning", "instelling"]

static var _fouten := 0
static var _host: Node = null


static func run(host: Node, fasen: Array = []) -> int:
	_fouten = 0
	_host = host
	var pad_oud: String = Beweging.instellingen_pad
	var stand_oud: int = Beweging.stand()
	var tempo_oud: float = Beweging.tempo()
	Beweging.instellingen_pad = CHECK_CFG
	Beweging.forceer(1)
	Beweging.zet_tempo(1.0)
	Beweging.zet_stand(Beweging.NORMAAL)
	var proef := Control.new()
	print("[INKOM] headless=%s pivot_offset_ratio=%s" % [DisplayServer.get_name() == "headless",
		proef.get("pivot_offset_ratio") != null])
	proef.free()
	var te_doen: Array = FASEN if fasen.is_empty() else fasen
	for fase in te_doen:
		match String(fase):
			"module":
				await _module()
			"knoppen":
				await _knoppen()
			"schermen":
				await _schermen()
			"kaart":
				await _kaart()
			"hub":
				await _hub()
			"beloning":
				await _beloning()
			"instelling":
				await _instelling()
			_:
				_fouten += 1
				print("[INKOM] onbekende fase: %s (bekend: %s)" % [fase, ", ".join(FASEN)])
	Beweging.zet_stand(stand_oud)
	Beweging.zet_tempo(tempo_oud)
	Beweging.forceer(-1)
	Beweging.instellingen_pad = pad_oud
	if FileAccess.file_exists(CHECK_CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECK_CFG))
	print("[INKOM] %s: %d fouten" % ["PASS" if _fouten == 0 else "FAIL", _fouten])
	return _fouten


static func _ok(voorwaarde: bool, wat: String) -> void:
	if voorwaarde:
		print("[INKOM]   ok   %s" % wat)
	else:
		_fouten += 1
		print("[INKOM]   FOUT %s" % wat)


## Wachten in echte tijd (ook als een check de tijd vertraagt), plus een frame:
## een timer gaat af in process_timers, VOOR de tweens van datzelfde frame hun
## stap zetten (en het eerste frame na het opstarten heeft een grote delta).
static func _wacht(s: float) -> void:
	await _host.get_tree().create_timer(s, true, false, true).timeout
	await _host.get_tree().process_frame


static func _frame() -> void:
	await _host.get_tree().process_frame


static func _gelijk(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.001


static func _blok(ouder: Node, naam: String, pos: Vector2) -> Control:
	var c := ColorRect.new()
	c.name = naam
	c.color = Color(0.8, 0.6, 0.3)
	c.custom_minimum_size = Vector2(120, 48)
	c.size = Vector2(120, 48)
	c.position = pos
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ouder.add_child(c)
	return c


# --- Fase module: de helpers zelf ------------------------------------------------

static func _module() -> void:
	print("[INKOM] fase module")
	var wortel := Control.new()
	wortel.name = "InkomWortel"
	wortel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wortel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.add_child(wortel)
	for k in 3:
		await _frame()   # opwarmen: het eerste frame na het opstarten is lang

	# plof: begint klein, draait om het midden en eindigt exact in rust
	var a := _blok(wortel, "A", Vector2(100, 100))
	Beweging.plof(a)
	_ok(a.scale.x < 0.99 and a.modulate.a < 0.5, "plof begint klein en doorzichtig (%.2f, %.2f)" % [a.scale.x, a.modulate.a])
	if a.has_method("get_combined_pivot_offset"):
		var spil: Vector2 = a.call("get_combined_pivot_offset")
		_ok(spil.distance_to(a.size * 0.5) < 0.01, "spil in het midden (%s)" % str(spil))
	await _wacht(0.5)
	_ok(_gelijk(a.scale, Vector2.ONE) and is_equal_approx(a.modulate.a, 1.0),
		"plof eindigt in rust (%s, %.3f)" % [str(a.scale), a.modulate.a])

	# alpha 0,9 blijft 0,9, ook als de fade halverwege opnieuw begint
	var b := _blok(wortel, "B", Vector2(300, 100))
	b.modulate.a = 0.9
	Beweging.fade_in(b)
	await _wacht(0.06)
	Beweging.fade_in(b)
	await _wacht(0.5)
	_ok(is_equal_approx(b.modulate.a, 0.9), "alpha 0,9 blijft 0,9 (%.3f)" % b.modulate.a)

	# een expliciete spil blijft van de eigenaar
	var c := _blok(wortel, "C", Vector2(500, 100))
	c.pivot_offset = Vector2(5, 5)
	Beweging.punch(c)
	var ratio = c.get("pivot_offset_ratio")
	_ok(c.pivot_offset == Vector2(5, 5) and (ratio == null or ratio == Vector2.ZERO), "expliciete spil onaangeroerd")

	# een node buiten de boom: niets, en geen fout
	var los := Control.new()
	Beweging.plof(los)
	Beweging.punch(los)
	Beweging.fade_in(los)
	Beweging.schud(los)
	Beweging.stempel(los, 0.0, true)
	Beweging.inkom_rij([los])
	_ok(los.scale == Vector2.ONE and is_equal_approx(los.modulate.a, 1.0) and not los.has_meta("ub_rust_scale"),
		"buiten de boom: niets geschreven")
	los.free()

	# spook-uitgang: voor de logica meteen weg, na 0,3 s ook echt
	var laag := _blok(wortel, "Laag", Vector2(100, 300))
	var knop := Button.new()
	knop.name = "Knop"
	laag.add_child(knop)
	Beweging.spook_weg(laag)
	_ok(wortel.get_node_or_null("Laag") == null and laag.has_meta("ub_weg"), "spook: de naam is meteen weg")
	_ok(laag.mouse_filter == Control.MOUSE_FILTER_IGNORE and knop.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"spook: invoer meteen uit, ook op de kinderen")
	await _wacht(0.3)
	_ok(not is_instance_valid(laag), "spook: na 0,3 s vrijgegeven")

	# hitstop zet de tijd op 0,05: de tween loopt toch in echte tijd
	var d := _blok(wortel, "D", Vector2(300, 300))
	Engine.time_scale = 0.05
	Beweging.plof(d)
	await _wacht(0.45)
	Engine.time_scale = 1.0
	_ok(_gelijk(d.scale, Vector2.ONE), "hitstop: toch klaar in echte tijd")

	# tempo 0,5 is dubbel zo lang
	var e := _blok(wortel, "E", Vector2(500, 300))
	Beweging.zet_tempo(0.5)
	Beweging.plof(e)
	await _wacht(0.3)
	var nog_bezig := not _gelijk(e.scale, Vector2.ONE)
	await _wacht(0.45)
	Beweging.zet_tempo(1.0)
	_ok(nog_bezig and _gelijk(e.scale, Vector2.ONE), "tempo 0,5: na 0,3 s nog bezig, na 0,75 s klaar")

	# uit: geen schrijfacties en geen tweens
	Beweging.forceer(0)
	var f := _blok(wortel, "F", Vector2(100, 500))
	Beweging.plof(f)
	Beweging.inkom_rij([f])
	Beweging.stempel(f, 0.0, true)
	Beweging.fade_in(f)
	_ok(f.scale == Vector2.ONE and is_equal_approx(f.modulate.a, 1.0) and not f.has_meta("ub_tw_schaal")
		and not f.has_meta("ub_rust_scale"), "uit: geen schrijfacties, geen tweens")
	Beweging.forceer(1)

	# rustig: alleen alpha, geen schaal of draai
	Beweging.zet_stand(Beweging.RUSTIG)
	var g := _blok(wortel, "G", Vector2(300, 500))
	Beweging.plof(g)
	Beweging.inkom_scherm(null, g)
	Beweging.punch(g)
	Beweging.schud(g)
	Beweging.stempel(g, 0.0, true)
	_ok(g.scale == Vector2.ONE and g.rotation == 0.0 and g.modulate.a < 0.5, "rustig: geen schaal of draai, wel alpha")
	await _wacht(0.4)
	_ok(is_equal_approx(g.modulate.a, 1.0), "rustig: alpha terug")
	Beweging.zet_stand(Beweging.NORMAAL)

	# optellen: de eindtekst is exact; uit is meteen
	var l := Label.new()
	wortel.add_child(l)
	Beweging.tel_op(l, 0, 10)
	_ok(l.text == "0", "tel_op begint op 0")
	await _wacht(0.7)
	_ok(l.text == "10", "tel_op eindigt exact op 10 (%s)" % l.text)
	Beweging.forceer(0)
	Beweging.tel_op(l, 10, 3)
	_ok(l.text == "3", "tel_op uit: meteen de eindtekst")
	Beweging.forceer(1)

	# schud en stempel eindigen exact in hun eigen rust
	var h := _blok(wortel, "H", Vector2(500, 500))
	Beweging.schud(h)
	var i := _blok(wortel, "I", Vector2(100, 700))
	i.scale = Vector2(0.85, 0.85)
	i.rotation = 0.2
	Beweging.stempel(i, 0.0, true)
	_ok(i.scale.x < 0.05, "stempel verbergt tot hij valt")
	await _wacht(0.5)
	_ok(is_zero_approx(h.rotation), "schud eindigt op draai 0")
	_ok(_gelijk(i.scale, Vector2(0.85, 0.85)) and is_equal_approx(i.rotation, 0.2),
		"stempel eindigt op zijn eigen rust (0,85 en 0,2)")

	# inkom_rij in een container: gespreid, de hele lijst binnen 0,45 s in rust
	var rij := VBoxContainer.new()
	rij.position = Vector2(700, 100)
	wortel.add_child(rij)
	var items: Array = []
	for k in 12:
		items.append(_blok(rij, "R%d" % k, Vector2.ZERO))
	await _frame()
	Beweging.inkom_rij(items)
	var gespreid: bool = (items[0] as Control).modulate.a == 0.0 and (items[11] as Control).modulate.a == 0.0
	await _wacht(0.45)
	var rust_ok := true
	for it in items:
		if not (_gelijk((it as Control).scale, Vector2.ONE) and is_equal_approx((it as Control).modulate.a, 1.0)):
			rust_ok = false
	_ok(gespreid and rust_ok, "inkom_rij: 12 items gespreid, binnen 0,45 s in rust")

	# duw: na een tijd niets doen een zachte puls, daarna weer in rust
	var j := Button.new()
	j.text = "duw"
	j.position = Vector2(300, 700)
	j.size = Vector2(160, 60)
	wortel.add_child(j)
	await _frame()
	Beweging.zet_laatste_invoer_ms(Time.get_ticks_msec() - 7000)
	Beweging.duw(j, 0.5)
	var puls_gezien := false
	for stap in 22:
		await _wacht(0.1)
		if j.scale.x > 1.001:
			puls_gezien = true
	_ok(puls_gezien, "duw: na een tijd niets doen een puls")
	await _wacht(0.6)
	_ok(_gelijk(j.scale, Vector2.ONE) or j.scale.x > 1.0, "duw: de knop valt terug of pulst nog")
	j.queue_free()

	await _wacht(0.1)
	_ok(Beweging.bezig() == 0, "geen UI-tweens meer bezig (%d)" % Beweging.bezig())
	wortel.queue_free()
	await _frame()


# --- Fase knoppen: elke knop deukt in en veert terug -------------------------------

static func _knoppen() -> void:
	print("[INKOM] fase knoppen")
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	_host.add_child(game)
	await _wacht(0.8)
	var ui: Node = game.get_node("UI")
	# 1. het haakje zit op elke knop die de boom in kwam
	var knoppen: Array = []
	_verzamel_knoppen(game, knoppen)
	var zonder := 0
	for k in knoppen:
		if not (k as Node).has_meta("ub_knop"):
			zonder += 1
	_ok(knoppen.size() >= 5 and zonder == 0, "haakje op elke knop (%d knoppen, %d zonder)" % [knoppen.size(), zonder])
	var help: Button = null
	var sfeer: Button = null
	for k in ui.get_children():
		if k is Button and (k as Button).theme_type_variation == "KnopRond":
			help = k
		elif k is Button and (k as Button).theme_type_variation == "KnopVierkant" and sfeer == null:
			sfeer = k
	_ok(help != null and sfeer != null, "hoekknoppen gevonden")
	if help == null or sfeer == null:
		game.queue_free()
		return
	# 2. indrukken en loslaten: kleiner, dan exact terug
	help.button_down.emit()
	await _wacht(0.1)
	var ingedrukt := help.scale.x
	help.button_up.emit()
	await _wacht(0.35)
	_ok(ingedrukt < 0.999 and _gelijk(help.scale, Vector2.ONE), "help: in (%.3f) en exact terug" % ingedrukt)
	# 3. uitgezet terwijl hij ingedrukt staat: toch terug in rust
	sfeer.button_down.emit()
	await _wacht(0.1)
	sfeer.disabled = true
	await _wacht(0.35)
	_ok(_gelijk(sfeer.scale, Vector2.ONE), "uitgezet tijdens indrukken: terug in rust (%.3f)" % sfeer.scale.x)
	sfeer.disabled = false
	# 4. menu naar menu: de knop is al uit de boom als button_up komt
	var overlay: Node = game.get("_overlay")
	var oude: Button = null
	for k in (overlay.get("_buttons") as Node).get_children():
		if k is Button:
			oude = k
			break
	_ok(oude != null, "overlay-knop gevonden")
	if oude != null:
		oude.button_down.emit()
		await _wacht(0.1)
		overlay.call("_pick", 0)
		oude.button_up.emit()
		_ok(not oude.is_inside_tree() and _gelijk(oude.scale, Vector2.ONE), "button_up na menu-wissel: geen fout, in rust")
		await _wacht(0.1)
		game.call("_show_difficulty_menu")
		await _wacht(0.1)
	# 5. een toggle (tab van de uitleg) ploft bij het aangaan
	var uitleg: Node = game.get("_instructions")
	uitleg.call("open")
	await _wacht(0.1)
	var tab: Button = uitleg.find_child("Tab_1", true, false)
	_ok(tab != null, "tab van de uitleg gevonden")
	if tab != null:
		tab.button_down.emit()
		await _wacht(0.1)
		tab.button_pressed = true
		tab.button_up.emit()
		await _wacht(0.06)
		var piek := tab.scale.x
		await _wacht(0.35)
		_ok(piek > 1.0 and _gelijk(tab.scale, Vector2.ONE), "toggle ploft (%.3f) en valt terug" % piek)
	uitleg.call("_close")
	await _wacht(0.1)
	# 6. hover: niets met touch, wel met een echte muis
	var touch := InputEventScreenTouch.new()
	Beweging.zie_invoer(touch)
	help.mouse_entered.emit()
	await _wacht(0.2)
	var na_touch := help.scale.x
	help.mouse_exited.emit()
	var muis := InputEventMouseMotion.new()
	muis.device = 0
	Beweging.zie_invoer(muis)
	help.mouse_entered.emit()
	await _wacht(0.2)
	var na_muis := help.scale.x
	help.mouse_exited.emit()
	await _wacht(0.25)
	_ok(is_equal_approx(na_touch, 1.0) and na_muis > 1.0 and _gelijk(help.scale, Vector2.ONE),
		"hover: touch niets (%.3f), muis groter (%.3f), daarna rust" % [na_touch, na_muis])
	# 7. rustig: indrukken is kort donkerder, de schaal blijft
	Beweging.zet_stand(Beweging.RUSTIG)
	var sm := help.self_modulate
	help.button_down.emit()
	await _wacht(0.05)
	var donker := help.self_modulate.r < sm.r and _gelijk(help.scale, Vector2.ONE)
	help.button_up.emit()
	_ok(donker and help.self_modulate == sm, "rustig: donkerder in plaats van kleiner, en exact terug")
	Beweging.zet_stand(Beweging.NORMAAL)
	# 8. beweging uit: niets
	Beweging.forceer(0)
	help.button_down.emit()
	await _wacht(0.1)
	var uit_ok := _gelijk(help.scale, Vector2.ONE) and not help.has_meta("ub_in")
	help.button_up.emit()
	Beweging.forceer(1)
	_ok(uit_ok, "uit: indrukken doet niets")
	# 9. het tikvlak van een kaart doet niet mee (de kaart heeft zijn eigen lift)
	var kaart: CardView = CardView.maak(3, 2, 2, Constants.PLAYER_1, Constants.Doctrine.MUIS, 7)
	_host.add_child(kaart)
	await _frame()
	var tik: Button = kaart.find_child("TapArea", true, false)
	tik.visible = true
	tik.button_down.emit()
	await _wacht(0.1)
	_ok(_gelijk(tik.scale, Vector2.ONE), "tikvlak van de kaart doet niet mee")
	tik.button_up.emit()
	kaart.queue_free()
	# 10. met venster: een echte klik (en een tik 4 px binnen de rand met een wiebel)
	if DisplayServer.get_name() != "headless":
		await _echte_klik(help, uitleg, Vector2(0.5, 0.5), "echte klik op help opent de uitleg")
		await _echte_klik(help, uitleg, Vector2(-1, 0.5), "tik 4 px binnen de rand met een wiebel vuurt")
	game.queue_free()
	await _wacht(0.2)


static func _verzamel_knoppen(n: Node, uit: Array) -> void:
	if n is BaseButton:
		uit.append(n)
	for k in n.get_children():
		_verzamel_knoppen(k, uit)


## Echte muis-events op een knop (alleen met venster: headless bereiken ze de GUI
## niet). plek (0,5, 0,5) = het midden; x = -1 betekent 4 px binnen de linkerrand.
static func _echte_klik(knop: Button, uitleg: Node, plek: Vector2, wat: String) -> void:
	var r := knop.get_global_rect()
	var p := r.position + r.size * plek
	if plek.x < 0.0:
		p = Vector2(r.position.x + 4.0, r.position.y + r.size.y * plek.y)
	var beweeg := InputEventMouseMotion.new()
	beweeg.position = p
	beweeg.global_position = p
	Input.parse_input_event(beweeg)
	await _frame()
	var druk := InputEventMouseButton.new()
	druk.button_index = MOUSE_BUTTON_LEFT
	druk.pressed = true
	druk.position = p
	druk.global_position = p
	Input.parse_input_event(druk)
	await _wacht(0.1)
	var wiebel := InputEventMouseMotion.new()
	wiebel.position = p + Vector2(1, 0)
	wiebel.global_position = wiebel.position
	Input.parse_input_event(wiebel)
	await _frame()
	var los := InputEventMouseButton.new()
	los.button_index = MOUSE_BUTTON_LEFT
	los.pressed = false
	los.position = wiebel.position
	los.global_position = wiebel.position
	Input.parse_input_event(los)
	await _wacht(0.3)
	_ok((uitleg as Control).visible, wat)
	if (uitleg as Control).visible:
		uitleg.call("_close")
	await _wacht(0.3)


# --- Fase schermen: de modale schermen van het bord ------------------------------

static func _schermen() -> void:
	print("[INKOM] fase schermen")
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	_host.add_child(game)
	await _wacht(0.8)
	var overlay: Control = game.get("_overlay")
	var midden: Control = overlay.get_node("Center")
	var dim: Control = overlay.get_node("Dim")
	var knoppen: Node = overlay.get("_buttons")
	# 1. het hoofdmenu kwam binnen en staat in rust
	_ok(_gelijk(midden.scale, Vector2.ONE) and is_equal_approx(dim.modulate.a, 1.0) and _alle_rust(knoppen),
		"hoofdmenu: na 0,8 s in rust")
	# 2. menu naar menu: de waas blijft staan, de inhoud wisselt
	overlay.call("_pick", 0)
	var waas_bleef := is_equal_approx(dim.modulate.a, 1.0)
	var wisselt := midden.scale.x < 0.999 or not _alle_rust(knoppen)
	await _wacht(0.5)
	_ok(waas_bleef and wisselt and _gelijk(midden.scale, Vector2.ONE) and _alle_rust(knoppen),
		"menu naar menu: waas blijft, inhoud wisselt, daarna rust")
	# 3. dezelfde titel opnieuw in hetzelfde frame (spawn kopen): niets beweegt
	var titel: String = (overlay.get("_title") as Label).text
	overlay.hide()
	overlay.call("show_choice", titel, "", ["a", "b"], Callable())
	_ok(_gelijk(midden.scale, Vector2.ONE) and _alle_rust(knoppen), "zelfde titel in hetzelfde frame: niets beweegt")
	await _wacht(0.3)
	# 4. een scherm dat een ander vervangt: de factie-achtergrond flitst niet
	overlay.hide()
	var factie: Control = game.get("_factie_keuze")
	factie.call("open", "Titel", "Uitleg", false, func(_i: int) -> void: pass)
	var achter: Control = factie.get("_achtergrond")
	_ok(is_equal_approx(achter.modulate.a, 1.0), "vervangt: de achtergrond van de factiekeuze blijft dicht")
	await _wacht(0.6)
	_ok(_alle_rust(factie.get("_lijst")), "factiekeuze: de lijst staat in rust")
	factie.call("sluit")
	await _wacht(0.1)
	# 5. de uitleg: paneel in, tabwissel laat de inhoud overvloeien
	var uitleg: Control = game.get("_instructions")
	uitleg.call("open")
	var um: Control = uitleg.get("_midden")
	var klein := um.scale.x < 0.999
	await _wacht(0.5)
	_ok(klein and _gelijk(um.scale, Vector2.ONE), "uitleg: ploft en staat in rust")
	uitleg.call("_select_tab", 1, true)
	var scroll: Control = uitleg.get("_scroll")
	var vloeit := scroll.modulate.a < 0.999
	await _wacht(0.35)
	_ok(vloeit and is_equal_approx(scroll.modulate.a, 1.0) and _gelijk(scroll.scale, Vector2.ONE),
		"uitleg: tabwissel vloeit over en eindigt in rust")
	uitleg.call("_close")
	await _wacht(0.1)
	# 6. het geluidspaneel: de 4 schuiven staan er meteen, het paneel ploft
	game.call("_show_audio_panel")
	var paneel: Control = game.get("_audio_panel")
	var schuiven: int = paneel.find_children("*", "HSlider", true, false).size()
	await _wacht(0.5)
	_ok(schuiven == 4 and _gelijk(paneel.scale, Vector2.ONE) and is_equal_approx(paneel.modulate.a, 1.0),
		"geluidspaneel: 4 schuiven meteen, daarna in rust")
	paneel.visible = false
	# 7. de hoekknoppen ploften in en houden hun alpha 0,9
	var help: Control = null
	var sfeer: Control = null
	for k in game.get_node("UI").get_children():
		if k is Button and (k as Button).theme_type_variation == "KnopRond":
			help = k
		elif k is Button and (k as Button).theme_type_variation == "KnopVierkant" and sfeer == null:
			sfeer = k
	_ok(help != null and _gelijk(help.scale, Vector2.ONE) and sfeer != null and is_equal_approx(sfeer.modulate.a, 0.9),
		"hoekknoppen in rust, sfeer-knop houdt alpha 0,9")
	game.queue_free()
	await _wacht(0.2)


## Staan alle zichtbare kinderen in rust (alpha 1, schaal 1, draai 0)?
static func _alle_rust(ouder: Node) -> bool:
	for k in ouder.get_children():
		if k is Control and (k as Control).visible and not (k as Node).is_queued_for_deletion():
			var c := k as Control
			if not (_gelijk(c.scale, Vector2.ONE) and is_equal_approx(c.modulate.a, 1.0) and is_zero_approx(c.rotation)):
				return false
	return true


# --- Fase kaart: uitdelen met stempel, statpunten, nee, onthulling ---------------

static func _kaart() -> void:
	print("[INKOM] fase kaart")
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	_host.add_child(game)
	await _wacht(0.8)
	game.call("_start_match", 1)
	await _wacht(0.2)
	game.call("_confirm_placement")
	await _wacht(0.8)
	if Phase.is_define(GameSession.state.phase) and not (game.get("_card_hand") as Control).visible:
		game.call("_on_cp_choice", 1)
	await _wacht(0.1)
	var hand: CardHand = game.get("_card_hand")
	var views: Array = hand.get_card_views()
	_ok(views.size() >= 2, "waaier open met kaarten (%d)" % views.size())
	if views.size() < 2:
		game.queue_free()
		return
	var zegel: Control = (views[0] as Node).find_child("CpZegel", true, false)
	var verstopt := zegel.scale.x < 0.5
	await _wacht(1.4)
	var zegels_rust := true
	for v in views:
		var z: Control = (v as Node).find_child("CpZegel", true, false)
		if not (_gelijk(z.scale, Vector2.ONE) and is_zero_approx(z.rotation)):
			zegels_rust = false
	_ok(verstopt and zegels_rust and zegel.modulate.a >= 0.99, "CP-zegel verstopt tot hij landt, stempelt, eindigt in rust")
	# statpunt: het getal dat stijgt springt op, de gever zakt, daarna rust
	var kaart: CardView = views[0]
	var hp: Label = kaart.find_child("HpValue", true, false)
	var voor: int = kaart.data.hp
	kaart.call("_adjust_stat", &"hp", 1)
	await _wacht(0.04)
	var veranderd: bool = kaart.data.hp != voor
	var sprong := hp != null and hp.scale.x > 1.0
	await _wacht(0.4)
	_ok(not veranderd or (sprong and _gelijk(hp.scale, Vector2.ONE)), "statpunt: springt op en valt terug")
	# nee: blijf plussen tot het niet meer kan, dan schudt de knop
	var plus: Button = kaart.find_child("HpPlus", true, false)
	var schudde := false
	for i in 12:
		var v0: int = kaart.data.hp
		kaart.call("_adjust_stat", &"hp", 1)
		if kaart.data.hp == v0:
			await _wacht(0.06)
			schudde = plus != null and not is_zero_approx(plus.rotation)
			break
	await _wacht(0.4)
	_ok(schudde and plus != null and is_zero_approx(plus.rotation), "kan niet: de plus schudt nee en staat weer recht")
	# de kaartwortels staan waar de hand ze zet (geen beweging op de root)
	var wortels_ok := true
	for v in views:
		if (v as Control).has_meta("ub_tw_schaal") or (v as Control).has_meta("ub_rust_scale"):
			wortels_ok = false
	_ok(wortels_ok, "geen UI-beweging op de wortel van een kaart")
	# onthulling: bevestig, de bot definieert, het onthulscherm komt
	hand.call("_on_confirm_pressed")
	var onthul: Control = null
	for i in 60:
		await _wacht(0.1)
		onthul = game.get("_onthul_scherm")
		if onthul != null and onthul.visible:
			break
	_ok(onthul != null and onthul.visible, "onthulscherm open")
	if onthul != null and onthul.visible:
		await _wacht(0.05)
		var draaiers: Array = onthul.find_children("Draai", "", true, false)
		var eerste_bezig := false
		for d in draaiers:
			if (d as Control).scale.x < 0.999:
				eerste_bezig = true
		await _wacht(1.3)
		var alles_rust := true
		var rug := false
		for d in draaiers:
			if not (_gelijk((d as Control).scale, Vector2.ONE) and is_equal_approx((d as Control).modulate.a, 1.0)):
				alles_rust = false
			var cv: CardView = (d as Node).get_child(0)
			if (cv.find_child("Rug", true, false) as Control).visible:
				rug = true
			var st: Control = cv.find_child("Onthuld", true, false)
			if st.visible and not _gelijk(st.scale, Vector2.ONE * UiAssets.KAART_ONTHULD_SCHAAL):
				alles_rust = false
		_ok(draaiers.size() >= 2 and eerste_bezig and alles_rust and not rug,
			"onthulling: kaarten draaien om en staan daarna open en in rust (%d)" % draaiers.size())
	game.queue_free()
	await _wacht(0.2)


# --- Fase hub: golf, fasepaneel, dubbeltik, pop-ups, grootboek, beloning ----------

static func _hub() -> void:
	print("[INKOM] fase hub")
	var hs = load("res://tools/hub_shot.gd")
	var orakel := "res://data/duel_orakel.json" if FileAccess.file_exists("res://data/duel_orakel.json") else ""
	var driver = hs._nieuwe_driver(42, orakel)
	hs._spoel_door(driver, "raad")
	var hub: Control = load("res://scripts/ui/campaign/campaign_hub.gd").new()
	hub.set("driver", driver)
	hub.set("mens_id", 0)
	_host.add_child(hub)
	# Meteen meten: _ready bouwt de hub en start de golf, en het eerste frame
	# daarna is headless zo lang dat de golf dan al klaar kan zijn.
	var frame: Control = hub.get("_frame")
	var schuift := 0
	for k in frame.get_children():
		if k.has_meta("hub_groep") and (k as Node).has_meta("ub_rust_position"):
			schuift += 1
	# Met venster start de golf twee frames na het (zware) bouwframe (vasthouden),
	# en op een drukke machine duurt dat bouwframe zelf soms langer dan een vaste
	# wachttijd. Dus: wachten tot er geen UI-tween meer loopt (plafond 3 s).
	var t0 := Time.get_ticks_msec()
	await _wacht(0.5)
	while Beweging.bezig() > 0 and Time.get_ticks_msec() - t0 < 3000:
		await _frame()
	var ms := Time.get_ticks_msec() - t0
	var rust := true
	for k in frame.get_children():
		if k.has_meta("ub_rust_position"):
			rust = false
	_ok(schuift >= 8 and rust and ms < 3000, "hub: de golf loopt (%d stukken) en staat na %d ms in rust" % [schuift, ms])
	# hetzelfde paneel nog eens: geen nieuwe inkom (dat gebeurt na elke tik)
	var voor: int = Beweging.bezig()
	hub.call("_bouw_fase_paneel")
	_ok(Beweging.bezig() <= voor, "dezelfde sleutel: geen nieuwe inkom")
	# pop-up: erin, dicht voor de logica meteen, spook na 0,3 s weg
	hub.call("_toon_instellingen")
	await _wacht(0.05)
	var waas: Control = frame.get_node_or_null("Popup")
	var vel: Control = waas.find_child("Instellingen", false, false) if waas != null else null
	await _wacht(0.4)
	_ok(vel != null and _gelijk(vel.scale, Vector2.ONE) and is_equal_approx(vel.modulate.a, 1.0), "pop-up ploft en staat in rust")
	if waas != null and vel != null:
		var klik := InputEventMouseButton.new()
		klik.button_index = MOUSE_BUTTON_LEFT
		klik.pressed = true
		klik.position = vel.position + vel.size * 0.5
		waas.gui_input.emit(klik)
		_ok(frame.get_node_or_null("Popup") != null, "een tik op het perkament sluit niet")
	hub.call("_sluit_popup")
	_ok(frame.get_node_or_null("Popup") == null, "sluiten: de naam Popup is meteen vrij")
	await _wacht(0.3)
	var spook := false
	for k in frame.get_children():
		if String(k.name).begins_with("Popup"):
			spook = true
	_ok(not spook, "sluiten: na 0,3 s geen spook meer")
	# grootboek: 16 rijen, in rust
	hub.call("_toon_grootboek")
	await _wacht(0.55)
	var tabel: Node = hub.find_child("GrootboekTabel", true, false)
	var rijen := 0
	if tabel != null:
		for r in tabel.get_children():
			if not r.is_queued_for_deletion():
				rijen += 1
	_ok(rijen == 16 and tabel != null and _alle_rust(tabel), "grootboek: 16 rijen in rust na 0,55 s (%d)" % rijen)
	var boek: Node = hub.find_child("Grootboek", true, false)
	if boek != null and boek.get_parent() != null:
		boek.get_parent().queue_free()
	await _wacht(0.1)
	# dubbeltik op STEM: de eerste telt, de rest van het paneel gaat uit
	var stem: Button = hub.find_child("StemKnop", true, false)
	if stem != null and not stem.disabled:
		stem.pressed.emit()
		var dicht: bool = bool(hub.get("_ingediend")) and stem.disabled
		stem.pressed.emit()
		_ok(dicht, "STEM: meteen uit na de eerste tik, de tweede telt niet")
		for i in 100:
			await _wacht(0.1)
			if not bool(hub.get("_bezig")):
				break
	else:
		print("[INKOM]   (geen STEM te drukken in deze stand)")
	await _wacht(0.3)
	hub.queue_free()
	await _wacht(0.2)


# --- Fase beloning: punten en eindscherm ---------------------------------------

static func _beloning() -> void:
	print("[INKOM] fase beloning")
	var hs = load("res://tools/hub_shot.gd")
	var orakel := "res://data/duel_orakel.json" if FileAccess.file_exists("res://data/duel_orakel.json") else ""
	if orakel == "":
		print("[INKOM]   (geen duel_orakel.json: fase beloning overgeslagen)")
		return
	var driver = hs._nieuwe_driver(42, orakel)
	hs._spoel_door(driver, "einde")
	var hub: Control = load("res://scripts/ui/campaign/campaign_hub.gd").new()
	hub.set("driver", driver)
	hub.set("mens_id", 0)
	_host.add_child(hub)
	await _wacht(1.1)
	var rij: Node = hub.find_child("JouwPunten", true, false)
	var mijn: Dictionary = driver.punten().get(0, {"totaal": 0})
	_ok(rij == null or (rij.get_child(2) as Label).text == str(int(mijn.totaal)),
		"eindpaneel: je punten staan na het optellen exact goed")
	hub.call("_toon_punten")
	await _wacht(0.85)
	var popup: Node = hub.find_child("Punten", true, false)
	var totaal_ok := false
	if popup != null:
		for l in popup.find_children("*", "Label", true, false):
			if (l as Label).text == str(int(mijn.totaal)):
				totaal_ok = true
	_ok(popup != null and totaal_ok, "puntenvenster: het totaal staat na 0,85 s exact goed")
	_ok(hub.find_children("Zweef", "", true, false).is_empty(), "geen zweef-labels achtergebleven")
	hub.queue_free()
	await _wacht(0.2)


# --- Fase instelling: Animaties normaal / rustig / uit ----------------------------

static func _instelling() -> void:
	print("[INKOM] fase instelling")
	# op schijf en terug (het eigen check-bestand, niet dat van de speler)
	Beweging.zet_stand(Beweging.UIT)
	Beweging.zet_stand(Beweging.NORMAAL)
	Beweging.zet_stand(Beweging.RUSTIG)
	var cfg := ConfigFile.new()
	cfg.load(CHECK_CFG)
	Beweging.zet_stand(Beweging.NORMAAL)
	var bewaard: String = String(cfg.get_value("ui", "beweging", "?"))
	Beweging.laad()
	_ok(bewaard == "rustig" and Beweging.stand() == Beweging.NORMAAL, "stand op schijf (%s) en terug geladen" % bewaard)
	# het rondje normaal -> rustig -> uit -> normaal
	var rondje: Array = []
	for i in 3:
		Beweging.zet_stand(Beweging.volgende_stand())
		rondje.append(Beweging.stand())
	_ok(rondje == [Beweging.RUSTIG, Beweging.UIT, Beweging.NORMAAL], "rondje normaal, rustig, uit, normaal")
	# uit: niets beweegt, en ook het uitdelen en de tijdlijn gaan direct
	var wortel := Control.new()
	_host.add_child(wortel)
	var a := _blok(wortel, "A", Vector2(100, 100))
	Beweging.zet_stand(Beweging.UIT)
	Beweging.plof(a)
	Beweging.inkom_scherm(null, a)
	_ok(a.scale == Vector2.ONE and is_equal_approx(a.modulate.a, 1.0) and not a.has_meta("ub_rust_scale")
		and Beweging.uit_gekozen(), "uit: geen beweging, en uit_gekozen voor waaier en tijdlijn")
	Beweging.zet_stand(Beweging.NORMAAL)
	_ok(not Beweging.uit_gekozen(), "normaal: waaier en tijdlijn bewegen gewoon")
	wortel.queue_free()
	# de knop in het instellingenmenu van het bord
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	_host.add_child(game)
	await _wacht(0.8)
	game.call("_show_settings_menu")
	var overlay: Node = game.get("_overlay")
	var knoppen: Array = (overlay.get("_buttons") as Node).get_children()
	var verwacht: String = game.tr("MENU_MOTION") % game.tr(Beweging.stand_sleutel(Beweging.NORMAAL))
	var tekst_ok: bool = knoppen.size() == 5 and (knoppen[2] as Button).text == verwacht
	overlay.call("_pick", 2)
	var na: Array = (overlay.get("_buttons") as Node).get_children()
	var verwacht_na: String = game.tr("MENU_MOTION") % game.tr(Beweging.stand_sleutel(Beweging.RUSTIG))
	var gewisseld: bool = Beweging.stand() == Beweging.RUSTIG and na.size() == 5 and (na[2] as Button).text == verwacht_na
	_ok(tekst_ok and gewisseld, "bord-menu: '%s' en tikken zet hem op rustig" % verwacht)
	Beweging.zet_stand(Beweging.NORMAAL)
	game.queue_free()
	await _wacht(0.2)
	# de knop in de instellingen van de hub
	var hs = load("res://tools/hub_shot.gd")
	var driver = hs._nieuwe_driver(42, "")
	var hub: Control = load("res://scripts/ui/campaign/campaign_hub.gd").new()
	hub.set("driver", driver)
	hub.set("mens_id", 0)
	_host.add_child(hub)
	await _wacht(0.3)
	hub.call("_toon_instellingen")
	await _wacht(0.1)
	var knop: Button = hub.find_child("InstBeweging", true, false)
	var voor: String = knop.text if knop != null else ""
	if knop != null:
		knop.pressed.emit()
	_ok(knop != null and Beweging.stand() == Beweging.RUSTIG and knop.text != voor and knop.text == knop.text.to_upper(),
		"hub-instellingen: '%s' wordt '%s'" % [voor, knop.text if knop != null else "?"])
	Beweging.zet_stand(Beweging.NORMAAL)
	hub.queue_free()
	await _wacht(0.2)
