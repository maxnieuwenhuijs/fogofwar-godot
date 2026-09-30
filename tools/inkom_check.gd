extends RefCounted

## `-- inkomcheck [fase...]` (capture.tscn): bewijst dat de UI-beweging
## (scripts/ui/ui_beweging.gd, 30 september) alleen beeld is. Alles eindigt
## exact in zijn rust, niets schrijft als de beweging uit staat, en de
## schermen en knoppen van het spel doen wat het plan zegt. De check forceert
## de beweging ook headless (`Beweging.forceer(1)`) en gebruikt een eigen
## settings-bestand, zodat de stand van de speler blijft staan.
##
## Fasen (zonder argument: allemaal): module, knoppen.
## Exit 1 bij een fout; de grep op "SCRIPT ERROR" hoort erbij.

const Beweging := preload("res://scripts/ui/ui_beweging.gd")
const CHECK_CFG := "user://settings_inkomcheck.cfg"
const FASEN := ["module", "knoppen"]

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
