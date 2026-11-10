extends RefCounted

## `-- hudcheck [fase...]` (10 november): de Match HUD van het ontwerp van
## milestone 3 (scripts/ui/match/match_hud.gd + pion_paneel.gd) in het echte
## spel, headless of met venster.
##
##  menu     voor het potje: de rondebalk toont alleen de titel, geen vaandels,
##           geen voorraad en geen opgeven; "?" staat er wel. Met venster ook
##           plaatjes van het hoofdmenu en de multiplayer-menu's.
##  lobby    de oefen-lobby uit het ontwerp: 16 stoelen in twee teams, jij als
##           host op stoel 1, de code staat erin, spelers komen binnen en
##           melden zich klaar, KLAAR wisselt jouw knop, START NU maakt de
##           lege stoelen bots (elk zichtbaar gemerkt) en telt af, daarna
##           gaat het startsein af; WEG geeft het weg-sein.
##  stemmen  de raad in de campaign hub (ronde 3), met ECHTE muisklikken als er
##           een venster is (headless via het pressed-signaal): een kandidaat
##           in je eigen kolom aantikken zet "jouw strijder", een kandidaat
##           van de vijand zet "doel", beide krijgen de gouden ring, STEM
##           dient de stem in. Meet ook hoeveel kandidaten zonder scrollen in
##           beeld staan en of een tik op een niet-kandidaat zijn kaartje
##           opent in plaats van te stemmen. `stemmen orakel=<pad>`.
##  assets   de levering is compleet (UiPack.VERWACHT) en elk plaatje laadt.
##  boven    een potje tot in de actiefase: de rondebalk (grote en kleine
##           regel), de tellers kloppen met de staat (levend, eigen punten en
##           CP), die van de ander zijn "?" (fog), jij staat links in je
##           eigen kleur, de portretten tonen de twee facties, de aanwijsregel
##           staat in zijn strook, en de oude labels zijn onzichtbaar maar
##           gevuld (render_digest leest de topbalk).
##  paneel   een pion selecteren: het pionpaneel verschijnt met type, factie
##           en de drie getallen uit de staat (HP en stamina als nu/vol,
##           attack los); geen tweede blad en geen pijl; de contextknop staat
##           boven het paneel; deselecteren haalt het weg; een gedekte pion
##           geeft vraagtekens, een standbeeld streepjes.
##  klok     de klok telt mee met de timer van game.gd en wordt rood in de
##           laatste seconden; zonder timer staat er niets.
##  schermen  het inzet-scherm (inzet_scherm.gd): voor een ronde alleen het
##           CP-bod met plus en min (grenzen 0 en het maximum), KLAAR geeft de
##           inzet door; in de versterkingsfase CP en versterkingen in een
##           scherm, plus en min per type (de punten tellen af, de plus gaat
##           uit als het geld of de cyclus op is), KLAAR boekt de spawns en
##           onthoudt de CP-inzet voor ronde 1; zonder CP alleen versterkingen;
##           het scherm sluit zichzelf als het moment voorbij is.
##  markeringen  een staande situatie midden op het bord (infanterist met een
##           schot en een melee, ruiter met een charge, kanon met een
##           vuurlijn): elke soort actie krijgt de ruit van het ontwerp, de
##           ruit ligt naar de camera gedraaid, een doel draagt het icoon
##           ook boven zijn hoofd, een loop-tegel draagt zijn kosten, en de
##           knop `markeringen` op 0 geeft de oude plakken terug.
##
## Met venster ook plaatjes: _shot_hud.png, _shot_hud_paneel.png,
## _shot_hud_cp.png, _shot_hud_inzet.png, _shot_hud_mark_<type>.png. Exit 1 bij een fout; grep ook op "SCRIPT ERROR".

const FASEN := ["menu", "lobby", "assets", "boven", "paneel", "klok", "schermen", "markeringen"]
## Niet in de standaardreeks (heeft een duel-orakel nodig om snel te zijn).
const EXTRA := ["stemmen", "bouwer"]
const GAME := "res://scenes/game/game.tscn"
const Pack := preload("res://scripts/ui/ui_pack.gd")
const PANEEL := preload("res://scripts/ui/match/pion_paneel.gd")
const HUD := preload("res://scripts/ui/match/match_hud.gd")
const MARKERING := preload("res://scripts/game/bord_markeringen.gd")

static var _fouten := 0
static var _host: Node = null


static func run(host: Node, fasen: Array = []) -> int:
	_fouten = 0
	_host = host
	# `nl` ertussen = alles in het Nederlands (langere teksten: uitloop zoeken)
	fasen = fasen.duplicate()
	if fasen.has("nl"):
		fasen.erase("nl")
		TranslationServer.set_locale("nl")
	var te_doen: Array = FASEN if fasen.is_empty() else fasen
	var game: Node = null
	for fase in te_doen:
		match String(fase):
			"assets":
				_assets()
			"menu":
				await _menu()
			"lobby":
				await _lobby()
			"stemmen":
				await _stemmen()
			"bouwer":
				await _bouwer()
			"boven", "paneel", "klok", "schermen", "markeringen":
				if game == null:
					game = await _potje_in_actie()
				if game == null:
					continue
				if String(fase) == "boven":
					await _boven(game)
				elif String(fase) == "paneel":
					await _paneel(game)
				elif String(fase) == "klok":
					await _klok(game)
				elif String(fase) == "schermen":
					await _schermen(game)
				else:
					await _markeringen(game)
			_:
				_fouten += 1
				print("[HUD] onbekende fase: %s (bekend: %s)" % [fase, ", ".join(FASEN)])
	if game != null:
		game.queue_free()
		await _wacht(0.2)
	print("[HUD] %s: %d fouten" % ["PASS" if _fouten == 0 else "FAIL", _fouten])
	return _fouten


static func _ok(voorwaarde: bool, wat: String) -> void:
	if voorwaarde:
		print("[HUD]   ok   %s" % wat)
	else:
		_fouten += 1
		print("[HUD]   FOUT %s" % wat)


static func _wacht(s: float) -> void:
	await _host.get_tree().create_timer(s, true, false, true).timeout
	await _host.get_tree().process_frame


## Wacht tot de inkom-animaties klaar zijn: een zwaar frame (de eerste
## selectie bouwt de markeringen) eet anders de hele wachttijd op.
static func _rustig() -> void:
	await _wacht(0.3)
	for i in 10:
		await _host.get_tree().process_frame
	await _wacht(0.5)


static func _shot(naam: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _rustig()
	await RenderingServer.frame_post_draw
	var img := _host.get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("res://_shot_%s.png" % naam)
		print("[HUD]   plaatje _shot_%s.png" % naam)


static func _menu() -> void:
	print("[HUD] menu")
	var game: Node = load(GAME).instantiate()
	_host.add_child(game)
	await _wacht(0.8)
	var hud = game._hud_balk
	hud._ververs()
	var s: Dictionary = hud.stand()
	_ok(not hud._ronde_plaat.visible and not hud._groot.visible and String(s.klok) == "",
		"voor het potje geen rondebalk (het menu draagt de titel zelf)")
	_ok(hud._knop_help.position.y < 20.0 and hud._knop_help.get_global_rect().end.x <= game.get_viewport().get_visible_rect().size.x,
		"'?' staat rechtsboven in de hoek")
	_ok(not (hud._vaandel[0] as Control).visible and not hud._balk.visible and not bool(s.aanwijs),
		"geen vaandels, geen voorraadbalk, geen aanwijsregel")
	_ok(hud._knop_help.visible and not hud._knop_opgeven.visible, "'?' staat er, opgeven niet")
	_ok(hud._knoppen.find_child("Sfeer", true, false) == null, "geen sfeer-knop in de HUD")
	_ok(game._overlay.visible, "het hoofdmenu staat open")
	await _shot("hud_menu")
	game._show_multi_menu()
	await _shot("hud_multi")
	game._show_online_keuzes()
	await _shot("hud_online")
	game._show_settings_menu()
	await _shot("hud_instellingen")
	# de stijl van 10 november: donkere platen, "terug" een kleine tekstknop
	var knoppen: Array = (game._overlay.get("_buttons") as Node).get_children()
	var terug: Button = knoppen[knoppen.size() - 1]
	_ok(knoppen.size() == 5 and terug.text == game.tr("MENU_BACK") and terug.flat and terug.icon != null
		and not (knoppen[0] as Button).flat, "instellingen: vijf keuzes, 'terug' is de kleine tekstknop met icoon")
	game._show_difficulty_menu()
	knoppen = (game._overlay.get("_buttons") as Node).get_children()
	var met_icoon := 0
	for k in knoppen:
		if (k as Button).icon != null:
			met_icoon += 1
	_ok(knoppen.size() == 4 and met_icoon == 4 and not game._overlay._body.visible,
		"hoofdmenu: vier keuzes met elk een icoon, geen uitlegtekst")
	game._show_solo_menu()
	await _shot("hud_solo")
	# de oefen-lobby in het echte spel: de knoppen van het bord zweven er niet overheen
	game._open_oefen_lobby()
	await _wacht(0.2)
	hud._ververs()
	_ok(game._lobby.visible and not hud._knoppen.visible, "lobby open: '?' en opgeven van het bord zijn weg")
	await _shot("hud_lobby_spel")
	game._lobby.druk_weg()
	await _wacht(0.3)
	hud._ververs()
	_ok(not game._lobby.visible and hud._knoppen.visible and game._overlay.visible,
		"lobby weg: terug in het multiplayer-menu, de knoppen zijn er weer")
	# de schermen die hun paneel en knoppen uit het thema halen (10 november:
	# het lichte perkament en de donkere plaat): factiekeuze en uitleg
	game._overlay.hide()
	game._show_doctrine_menu()
	await _shot("hud_factie")
	_ok(game._factie_keuze.visible, "de factiekeuze opent")
	game._factie_keuze.sluit()
	game._on_help_pressed()
	await _shot("hud_uitleg")
	_ok(game._instructions.visible, "de uitleg opent")
	game._instructions._close()
	await _wacht(0.2)
	var thema: Theme = UiAssets.thema()
	var knop_sb := thema.get_stylebox("normal", "Button") as StyleBoxTexture
	var paneel_sb := thema.get_stylebox("panel", "PaneelVeldtafel") as StyleBoxTexture
	_ok(knop_sb != null and String(knop_sb.texture.resource_path).get_file() == "quick_chat_button_default.png"
		and thema.get_color("font_color", "Button") == UiAssets.WARM_IVOOR,
		"de gewone knop is de donkere plaat met ivoren letters")
	_ok(paneel_sb != null and String(paneel_sb.texture.resource_path).get_file() == "Player_box.png",
		"de grote panelen zijn het lichte perkament met beslag")
	game.queue_free()
	await _wacht(0.3)


static func _lobby() -> void:
	print("[HUD] lobby")
	var scherm = load("res://scripts/ui/lobby/lobby_scherm.gd").new()
	_host.add_child(scherm)
	var sim = load("res://scripts/game/lobby_sim.gd").new(7, "Jij", Constants.Doctrine.MUIS)
	var seinen: Array = []
	scherm.open(sim, func() -> void: seinen.append("start"), func() -> void: seinen.append("weg"))
	scherm.set_process(false)   # de check zet de klok zelf door
	await _wacht(0.3)
	var s: Dictionary = scherm.stand()
	_ok(bool(s.zichtbaar) and int(s.stoelen) == 16 and int(s.spelers) == 1 and int(s.leeg) == 15,
		"16 stoelen, alleen jij zit er (de rest wacht)")
	_ok(String(s.staat) == "vullen" and String(s.code).length() == 5 and s.teams == ["1 / 8", "0 / 8"],
		"vullen, code %s, teams %s" % [s.code, s.teams])
	_ok(not bool(s.klaar) and String(s.klaar_tekst) == scherm.tr("LOBBY_NOT_READY") and bool(s.start_aan),
		"jij bent nog niet klaar; als host mag je starten")
	_ok(String(sim.stoelen[0].soort) == "jij" and bool(sim.stoelen[0].host), "jij bent de host op stoel 1 van team blauw")
	scherm.druk_klaar()
	_ok(bool(scherm.stand().klaar) and String(scherm.stand().klaar_tekst) == scherm.tr("LOBBY_READY"), "KLAAR wisselt je knop naar groen")
	for i in 40:
		scherm.tik_ms(500)   # 20 seconden
	s = scherm.stand()
	_ok(int(s.spelers) > 1 and int(s.spelers) < 16 and String(s.staat) == "vullen" and int(s.bots) == 0,
		"na 20 s zijn er spelers bij gekomen (%d), nog geen bots" % int(s.spelers))
	var klaren := 0
	for st in sim.stoelen:
		if String(st.soort) == "mens" and bool(st.klaar):
			klaren += 1
	_ok(klaren > 0, "en een deel meldde zich klaar (%d)" % klaren)
	await _shot("hud_lobby")
	scherm.druk_start()
	s = scherm.stand()
	_ok(String(s.staat) == "start" and int(s.leeg) == 0 and int(s.bots) > 0 and int(s.bots) == int(s.bots_gemerkt),
		"START NU: geen lege stoelen meer, %d bots, elk gemerkt" % int(s.bots))
	_ok(not bool(s.start_aan) and s.teams == ["8 / 8", "8 / 8"], "de startknop staat uit, beide teams vol")
	await _shot("hud_lobby_start")
	for i in 8:
		scherm.tik_ms(500)
	_ok(seinen == ["start"] and not scherm.visible, "na de aftel gaat het startsein af en sluit de lobby %s" % [seinen])
	# vanzelf vol: de vultijd loopt af
	var sim2 = load("res://scripts/game/lobby_sim.gd").new(11, "Jij", Constants.Doctrine.WOLF)
	scherm.open(sim2, func() -> void: seinen.append("start2"), func() -> void: seinen.append("weg"))
	for i in 95:
		scherm.tik_ms(500)
	_ok(String(sim2.staat) == "start" or sim2.gestart, "zonder host loopt de vultijd af en begint hij vanzelf")
	if scherm.visible:
		scherm.druk_weg()
		_ok(seinen.has("weg") and not scherm.visible, "WEG geeft het weg-sein en sluit")
	scherm.queue_free()
	await _wacht(0.2)


## De legerbouwer van Strategy mode in de stijl van het thema (een plaatje, en
## dat hij in beeld past); de werking toetst `-- strategiecheck bouwer`.
static func _bouwer() -> void:
	print("[HUD] bouwer")
	var sc = load("res://tools/strategie_check.gd")
	sc._host = _host
	var game: Node = await sc._potje_in_bouwer()
	await _rustig()
	var bouwer: Control = game._leger_bouwer
	_ok(bouwer != null and bouwer.visible, "de legerbouwer staat open")
	var beeld: Rect2 = game.get_viewport().get_visible_rect()
	var buiten := 0
	for b in bouwer.find_children("*", "BaseButton", true, false):
		if (b as Control).is_visible_in_tree() and not beeld.grow(1.0).encloses((b as Control).get_global_rect()):
			buiten += 1
	_ok(buiten == 0, "elke knop van de legerbouwer staat in beeld (%d erbuiten)" % buiten)
	await _shot("hud_legerbouwer")
	game.queue_free()
	await _wacht(0.3)


static func _echte_klik(pos: Vector2) -> void:
	for druk in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = druk
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)
		await _host.get_tree().process_frame
		await _host.get_tree().process_frame


## Tik op een knop: met venster een echte muisklik op zijn midden, headless
## het signaal (daar bereiken muis-events de GUI niet).
static func _tik(b: BaseButton) -> void:
	if DisplayServer.get_name() == "headless":
		b.pressed.emit()
		await _host.get_tree().process_frame
	else:
		await _echte_klik(b.get_global_rect().get_center())
	await _wacht(0.25)


static func _stemmen() -> void:
	print("[HUD] stemmen")
	var orakel := "res://data/duel_orakel.json"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("orakel="):
			orakel = String(a).substr(7)
	var hs = load("res://tools/hub_shot.gd")
	var driver = hs._nieuwe_driver(42, orakel)
	hs._spoel_door(driver, "raad")
	var hub: Control = load("res://scripts/ui/campaign/campaign_hub.gd").new()
	hub.driver = driver
	hub.mens_id = 0
	hub.set("klaar_overslaan", true)
	_host.add_child(hub)
	await _wacht(1.2)
	var c = driver.c
	_ok(c.fase == CState.Fase.NOMINATIE and driver.wacht_op_mens() and hub._raad_open(), "de raad is open en wacht op jou (ronde %d)" % c.ronde)
	var mijn_team: int = int(c.spelers[0].team)
	var eigen: Array = hub._kandidaten(mijn_team)
	var vijand: Array = hub._kandidaten(1 - mijn_team)
	_ok(eigen.size() > 0 and vijand.size() > 0, "er zijn kandidaten: %d eigen, %d van de vijand" % [eigen.size(), vijand.size()])
	# wat staat er zonder scrollen in beeld?
	var zicht := {}
	for paar in [[hub._team_links, eigen, "eigen"], [hub._team_rechts, vijand, "vijand"]]:
		var kolom: Control = paar[0]
		var venster: Rect2 = (kolom.get_parent() as Control).get_global_rect()
		var in_beeld := 0
		for sid in paar[1]:
			var b := kolom.get_node_or_null("Lid_%d" % int(sid)) as Control
			if b != null and venster.encloses(Rect2(b.get_global_rect().position, Vector2(b.size.x, b.size.y * 0.8))):
				in_beeld += 1
		zicht[paar[2]] = [in_beeld, (paar[1] as Array).size(), kolom.get_child_count()]
	print("[HUD]   kandidaten zonder scrollen in beeld: eigen %d van %d, vijand %d van %d (kolommen van %d en %d)" % [
		zicht.eigen[0], zicht.eigen[1], zicht.vijand[0], zicht.vijand[1], zicht.eigen[2], zicht.vijand[2]])
	_ok(int(zicht.eigen[0]) == int(zicht.eigen[1]) and int(zicht.vijand[0]) == int(zicht.vijand[1]),
		"alle kandidaten staan zonder scrollen in beeld (levenden bovenaan)")
	# de volgorde: geen levende onder een gevallene
	for kolom in [hub._team_links, hub._team_rechts]:
		var dood_gezien := false
		var fout := false
		for kind in kolom.get_children():
			if kind.is_queued_for_deletion():
				continue
			var sid: int = int(String(kind.name).trim_prefix("Lid_"))
			var leeft: bool = String(c.spelers[sid].get("status", "actief")) == "actief"
			if not leeft:
				dood_gezien = true
			elif dood_gezien:
				fout = true
		_ok(not fout, "kolom %s: levenden bovenaan, gevallenen onderaan" % kolom.name)
	# kies de eerste zichtbare kandidaat aan elke kant die nog niet gekozen is
	var kies := {}
	for paar in [[hub._team_links, eigen, "eigen", hub._keuze_eigen], [hub._team_rechts, vijand, "vijand", hub._keuze_vijand]]:
		var kolom: Control = paar[0]
		var venster: Rect2 = (kolom.get_parent() as Control).get_global_rect()
		for sid in paar[1]:
			var b := kolom.get_node_or_null("Lid_%d" % int(sid)) as Control
			if b != null and int(sid) != int(paar[3]) and venster.has_point(b.get_global_rect().get_center()):
				kies[paar[2]] = int(sid)
				break
	_ok(kies.has("eigen") and kies.has("vijand"), "er is aan elke kant een andere kandidaat om aan te tikken %s" % [kies])
	if kies.has("eigen"):
		await _tik(hub._team_links.get_node("Lid_%d" % int(kies.eigen)))
		_ok(int(hub._keuze_eigen) == int(kies.eigen), "tik op een teamgenoot: hij is jouw strijder (%s)" % String(c.spelers[int(kies.eigen)].naam))
		_ok(hub._team_links.get_node("Lid_%d" % int(kies.eigen)).get_node_or_null("Gloed") != null, "en hij draagt de gouden ring")
	if kies.has("vijand"):
		await _tik(hub._team_rechts.get_node("Lid_%d" % int(kies.vijand)))
		_ok(int(hub._keuze_vijand) == int(kies.vijand), "tik op een vijand: hij is het doel (%s)" % String(c.spelers[int(kies.vijand)].naam))
	var links_paneel: Node = hub.find_child("RaadEigen", true, false)
	var rechts_paneel: Node = hub.find_child("RaadVijand", true, false)
	_ok(links_paneel != null and rechts_paneel != null, "het raadpaneel toont beide keuzes")
	# een niet-kandidaat: geen stem, wel zijn kaartje
	var niet := -1
	for sid in c.spelers:
		if int(c.spelers[sid].team) == mijn_team and not eigen.has(int(sid)) and int(sid) != 0:
			var b := hub._team_links.get_node_or_null("Lid_%d" % int(sid)) as Control
			if b != null and (hub._team_links.get_parent() as Control).get_global_rect().has_point(b.get_global_rect().get_center()):
				niet = int(sid)
				break
	if niet >= 0:
		var was: int = int(hub._keuze_eigen)
		await _tik(hub._team_links.get_node("Lid_%d" % niet))
		_ok(int(hub._keuze_eigen) == was and hub.find_child("Popup", true, false) != null,
			"tik op een niet-kandidaat: geen stem, zijn kaartje opent")
		hub._sluit_popup()
		await _wacht(0.3)
	await _shot("hud_stemmen")
	var stem := hub.find_child("StemKnop", true, false) as Button
	_ok(stem != null and not stem.disabled, "STEM staat aan")
	if stem != null:
		var beeld: Rect2 = hub.get_viewport().get_visible_rect()
		_ok(beeld.encloses(stem.get_global_rect()), "STEM staat helemaal in beeld (%s)" % stem.get_global_rect())
		# de uitkomst meten, niet het moment: na de stem spelen de bots door en
		# is de vlag "ingediend" alweer terug
		var genomineerd_voor: int = c.al_genomineerd.size()
		var feed_voor: int = driver.feed.size()
		var ronde_voor: int = c.ronde
		await _tik(stem)
		for i in 100:
			await _wacht(0.1)
			if not bool(hub.get("_bezig")):
				break
		_ok(c.al_genomineerd.size() > genomineerd_voor or driver.feed.size() > feed_voor
			or c.fase != CState.Fase.NOMINATIE or c.ronde != ronde_voor,
			"STEM dient je stem in: de raad ging verder (genomineerd %d -> %d, tijdlijn %d -> %d)" % [
				genomineerd_voor, c.al_genomineerd.size(), feed_voor, driver.feed.size()])
	hub.queue_free()
	await _wacht(0.3)


static func _assets() -> void:
	print("[HUD] assets")
	var mist: Array = Pack.ontbrekend()
	_ok(mist.is_empty(), "de levering is compleet (%d verwacht, %d ontbreken%s)" % [
		Pack.aantal_verwacht(), mist.size(), "" if mist.is_empty() else ": " + ", ".join(mist.slice(0, 6))])
	var geladen := 0
	for map in Pack.VERWACHT:
		for naam in Pack.VERWACHT[map]:
			var t: Texture2D = Pack.tex("%s/%s" % [map, naam])
			if t != null and t.get_width() > 0:
				geladen += 1
	_ok(geladen == Pack.aantal_verwacht(), "elk plaatje laadt (%d van %d)" % [geladen, Pack.aantal_verwacht()])


## Een potje Muis tegen Wolf tot de mens in de actiefase aan zet is (dezelfde
## weg als `-- play`: de echte functies van game.gd).
static func _potje_in_actie() -> Node:
	var game: Node = load(GAME).instantiate()
	_host.add_child(game)
	await _wacht(0.5)
	game.set("_human_doctrine", Constants.Doctrine.MUIS)
	game.set("_ai_doctrine", Constants.Doctrine.WOLF)
	var hand: CardHand = game.get_node("UI/CardHand")
	var stappen := 0
	while stappen < 900:
		stappen += 1
		var st: GameState = GameSession.state
		if st.phase == Phase.Type.GAME_OVER:
			break
		if st.phase == Phase.Type.ACTION and st.current_player == game._human_id:
			break
		if st.phase == Phase.Type.PRE_GAME:
			game._start_match(1)
		elif st.phase == Phase.Type.PLACEMENT:
			game._confirm_placement()
		elif Phase.is_reveal(st.phase):
			game._continue_after_reveal()
		elif Phase.is_define(st.phase) and st.cards_defined[1].size() == 0:
			if game._inzet.visible:
				game._inzet.druk_klaar()   # het CP-bod: niets inzetten, door naar de kaarten
			elif not hand.visible or hand.get_card_views().is_empty():
				pass   # het bord speelt nog (versterkingen landen): de kaarten komen zo
			else:
				_vul_en_bevestig(hand, st)
		elif Phase.is_linking(st.phase) and st.current_player == 1:
			for i in st.cards_revealed[1].size():
				if not st.cards_revealed[1][i].is_linked():
					game._on_link_card_picked(i)
					break
			for pawn in st.pawns.values():
				if pawn.owner_id == 1 and not pawn.is_eliminated \
						and pawn.linked_card_id == -1 and game._pawn_has_room(pawn):
					game._on_link_pawn_clicked(pawn.id)
					break
		await _wacht(0.04)
	var eind: GameState = GameSession.state
	if eind.phase != Phase.Type.ACTION or eind.current_player != game._human_id:
		_fouten += 1
		print("[HUD]   FOUT het potje kwam niet in de eigen actiebeurt (fase %s, beurt %d, %d stappen)" % [
			Phase.to_string_phase(eind.phase), eind.current_player, stappen])
		game.queue_free()
		return null
	await _wacht(0.6)
	return game


static func _vul_en_bevestig(hand: CardHand, st: GameState) -> void:
	var bud: int = int(st.doctrine_data_of(1).budget)
	for c in hand.get_card_views():
		c.data.hp = 2
		c.data.stamina = mini(bud - 3, 3)
		c.data.attack = bud - 2 - mini(bud - 3, 3)
		c._refresh()
	hand._on_confirm_pressed()


static func _boven(game: Node) -> void:
	print("[HUD] boven")
	var hud = game._hud_balk
	var st: GameState = GameSession.state
	var mens: int = game._human_id
	var ander: int = 2 if mens == 1 else 1
	hud._ververs()
	var s: Dictionary = hud.stand()
	_ok(String(s.groot) == game.tr("HUD_TURN_YOU"), "grote regel in je eigen beurt: '%s'" % s.groot)
	_ok(String(s.klein) == "%s · %s" % [game.tr("HUD_CYCLE_ROUND") % [st.cycle, st.round_number], game.tr("PHASE_ACTION")],
		"kleine regel: '%s'" % s.klein)
	var t: Array = s.tellers
	_ok(t.size() == 6, "zes tellers")
	_ok(String(t[0]) == str(st.get_alive_pawns_for(mens).size()), "jouw levende pionnen: %s" % t[0])
	_ok(String(t[1]) == str(st.pool_total(mens)), "jouw versterkingspunten: %s" % t[1])
	_ok(String(t[2]) == str(int(st.cp.get(mens, 0))), "jouw CP: %s" % t[2])
	_ok(String(t[3]) == str(st.get_alive_pawns_for(ander).size()), "levende pionnen van de ander: %s" % t[3])
	_ok(String(t[4]) == "?" and String(t[5]) == "?", "punten en CP van de ander zijn '?' (fog)")
	# lek-kanarie: het echte saldo van de ander staat nergens op de HUD
	var geheim := [str(st.pool_total(ander)), str(int(st.cp.get(ander, 0)))]
	_ok(String(t[4]) != geheim[0] or geheim[0] == "?", "het saldo van de ander lekt niet")
	_ok(String(s.jij_links) == ("Player_box_2.png" if mens == 1 else "Player_box_1.png"),
		"jij staat links in je eigen kleur (%s)" % s.jij_links)
	_ok(hud._vaandel_naam(1).ends_with("Player_box_2") and hud._vaandel_naam(2).ends_with("Player_box_1"),
		"stoel 1 = het rode vaandel, stoel 2 = het blauwe")
	_ok(hud.balk_gespiegeld() == (mens == 1), "de voorraadbalk is gespiegeld als jij rood bent")
	_ok(s.portretten == [int(st.doctrine_of(mens)), int(st.doctrine_of(ander))],
		"portretten: jouw factie links, die van de ander rechts %s" % [s.portretten])
	_ok(bool(s.aanwijs) and game._prompt_label.visible and game._prompt_label.text != "",
		"de aanwijsregel staat in zijn strook: '%s'" % game._prompt_label.text)
	var r: Rect2 = s.aanwijs_rect
	_ok(hud.TOP_HOOGTE <= 270.0 and r.end.y <= hud.TOP_HOOGTE + 30.0,
		"de drie rijen bovenaan nemen samen hooguit 270 px (%.0f)" % hud.TOP_HOOGTE)
	var lr: Rect2 = game._prompt_label.get_global_rect()
	var strook := Rect2(hud._kolom.global_position + r.position, r.size)
	_ok(strook.grow(1.0).encloses(lr), "het label valt binnen de strook (%s in %s)" % [lr, strook])
	_ok(not game._top_label.visible and game._top_label.text != "", "TopLabel onzichtbaar maar gevuld: '%s'" % game._top_label.text)
	_ok(not game._count_label.visible and game._count_label.text != "", "CountLabel onzichtbaar maar gevuld")
	_ok(String(game.render_digest().get("topbalk", "")) == game._top_label.text, "render_digest leest de topbalk nog")
	_ok(hud._knop_help != null and hud._knop_help.visible and hud._knop_opgeven.visible, "de knoppen '?' en opgeven staan er")
	_ok(hud._knoppen.get_index() > game._overlay.get_index(), "de knoppen liggen boven de overlay")
	_ok(hud.get_index() < game._overlay.get_index() and hud.get_index() < game._card_hand.get_index(),
		"de HUD ligt onder de kaarten en de overlay")
	await _shot("hud")
	# de beurt van de ander: de grote regel wisselt mee
	var oud: int = st.current_player
	st.current_player = ander
	hud._ververs()
	_ok(String(hud.stand().groot) == game.tr("HUD_TURN_OPPONENT"), "in de beurt van de ander: '%s'" % hud.stand().groot)
	st.current_player = oud
	hud._ververs()


static func _kies_pion(game: Node, st: GameState) -> int:
	# liefst een drager (dan staat het rol-vaantje erbij), anders de eerste die kan
	var eerste := -1
	for p in st.pawns.values():
		if p.owner_id != game._human_id or p.is_eliminated or not p.is_active:
			continue
		if not Rules.can_pawn_act(st, p.id):
			continue
		if String(p.rol) != "":
			return p.id
		if eerste < 0:
			eerste = p.id
	return eerste


static func _paneel(game: Node) -> void:
	print("[HUD] paneel")
	var hud = game._hud_balk
	var paneel = hud.paneel
	var st: GameState = GameSession.state
	hud._ververs()
	_ok(not paneel.visible, "zonder selectie geen paneel")
	var pid: int = _kies_pion(game, st)
	_ok(pid >= 0, "er is een eigen pion die kan handelen (pion %d)" % pid)
	if pid < 0:
		return
	game._select_pawn(pid)
	await _rustig()
	hud._ververs()
	var p: Pawn = st.pawns[pid]
	var s: Dictionary = paneel.stand()
	_ok(bool(s.zichtbaar) and int(s.pion) == pid, "het paneel toont de geselecteerde pion")
	_ok(String(s.titel) == game.tr(String(PANEEL.TYPE_SLEUTEL[p.unit_type])), "titel = het type: '%s'" % s.titel)
	_ok(String(s.onder) == game.tr("DOCTRINE_%d_NAME" % int(st.doctrine_of(p.owner_id))), "eronder de factie: '%s'" % s.onder)
	var verwacht: Array = ["%d/%d" % [p.current_hp, p.max_hp],
		"%d/%d" % [Rules.stamina_beschikbaar(st, p), p.max_stamina], str(Rules.effectieve_attack(st, p))]
	_ok(s.cijfers == verwacht, "HP en stamina als nu/vol, attack los: %s" % [s.cijfers])
	_ok(s.labels == [game.tr("HUD_CHIP_HP"), game.tr("HUD_CHIP_STAMINA"), game.tr("HUD_CHIP_ATTACK")], "labels: %s" % [s.labels])
	_ok(paneel.find_child("Blad", true, false) == null, "geen pijl en geen tweede blad")
	if String(p.rol) != "":
		_ok(String(s.rol) == game.tr("HUD_ROLE_FLAG" if String(p.rol) == "flag" else "HUD_ROLE_DRUM"), "de rol staat erbij: '%s'" % s.rol)
	else:
		_ok(String(s.rol) == "", "geen rol, geen vaantje")
	# het paneel past in beeld en de contextknop staat erboven
	var pr: Rect2 = paneel.get_global_rect()
	var beeld: Vector2 = game.get_viewport().get_visible_rect().size
	_ok(pr.position.x >= -0.5 and pr.end.x <= beeld.x + 0.5 and pr.end.y <= beeld.y + 0.5, "het paneel valt binnen het beeld (%s)" % pr)
	game._update_context_knop()
	hud._ververs()
	var ctx: Button = game._context_knop
	_ok(ctx.visible and ctx.text == game.tr("HUD_BTN_DESELECT") and ctx.icon != null, "de contextknop zegt deselecteer, met icoon")
	_ok(ctx.get_global_rect().end.y <= pr.position.y + 8.0, "de contextknop staat boven het paneel (%.0f boven %.0f)" % [
		ctx.get_global_rect().end.y, pr.position.y])
	await _shot("hud_paneel")
	# een klap en een stap: de getallen lopen mee
	var hp_was: int = p.current_hp
	var st_was: int = p.remaining_stamina
	if p.current_hp > 1 and p.remaining_stamina > 0:
		p.current_hp -= 1
		p.remaining_stamina -= 1
		hud._ververs()
		s = paneel.stand()
		_ok(s.cijfers[0] == "%d/%d" % [hp_was - 1, p.max_hp] and s.cijfers[1] == "%d/%d" % [Rules.stamina_beschikbaar(st, p), p.max_stamina],
			"na een klap en een stap: %s" % [s.cijfers])
		await _shot("hud_paneel_geraakt")
		p.current_hp = hp_was
		p.remaining_stamina = st_was
		hud._ververs()
	# fog en standbeeld (de rekenfunctie zelf)
	_ok(PANEEL.waarden(st, p, true) == ["?", "?", "?"], "een gedekte pion geeft vraagtekens")
	var beeldje: Pawn = null
	for q in st.pawns.values():
		if not q.is_eliminated and not q.is_active:
			beeldje = q
			break
	if beeldje != null:
		_ok(PANEEL.waarden(st, beeldje, false) == ["-", "-", "-"], "een standbeeld (geen kaart) geeft streepjes")
	# deselecteren
	game._deselect()
	await _wacht(0.2)
	hud._ververs()
	_ok(not paneel.visible and int(paneel.stand().pion) == -1, "na deselecteren is het paneel weg")
	game._update_context_knop()
	_ok(not ctx.visible, "en de contextknop ook")


static func _klok(game: Node) -> void:
	print("[HUD] klok")
	var hud = game._hud_balk
	_ok(HUD.klok_tekst(16.0) == "00:16" and HUD.klok_tekst(75.2) == "01:16" and HUD.klok_tekst(0.0) == "00:00",
		"de klok schrijft mm:ss (naar boven afgerond)")
	var was_actief: bool = game._timer_active
	var was_over: float = game._timer_left
	game._timer_active = true
	game._timer_left = 16.0
	hud._ververs()
	_ok(String(hud.stand().klok) == "00:16", "met een timer van 16 s staat er 00:16")
	_ok(not bool(hud._oud.get("klok_rood", false)), "en hij is niet rood")
	game._timer_left = 4.2
	hud._ververs()
	_ok(String(hud.stand().klok) == "00:05" and bool(hud._oud.get("klok_rood", false)), "in de laatste 5 s: 00:05 en rood")
	game._timer_active = false
	hud._ververs()
	_ok(String(hud.stand().klok) == "", "zonder timer staat er geen tijd")
	game._timer_active = was_actief
	game._timer_left = was_over
	hud._ververs()


static func _actieve_pion(st: GameState, eigenaar: int, pos: Vector2i, type: int, hp: int, stamina: int, attack: int) -> Pawn:
	var pawn: Pawn = st._spawn_pawn(eigenaar, pos, type)
	var kaart := Card.new(st.next_card_id(), eigenaar, st.round_number, hp, stamina, attack)
	st.all_cards[kaart.id] = kaart
	pawn.link_card(kaart)
	return pawn


static func _soorten(game: Node) -> Dictionary:
	var uit: Dictionary = {}
	for h in game._highlights:
		var soort: String = String((h as Node).get_meta("soort", "plak"))
		uit[soort] = int(uit.get(soort, 0)) + 1
	return uit


static func _markeringen(game: Node) -> void:
	print("[HUD] markeringen")
	var st: GameState = GameSession.state
	var mens: int = game._human_id
	var ander: int = 2 if mens == 1 else 1
	game._deselect()
	# een staande situatie midden op het bord (de vakken daar zijn leeg)
	var vrij := true
	for pos in [Vector2i(5, 6), Vector2i(5, 4), Vector2i(6, 6), Vector2i(2, 6), Vector2i(2, 3), Vector2i(8, 7), Vector2i(8, 4)]:
		if not st.is_tile_empty(pos):
			vrij = false
	_ok(vrij, "het midden van het bord is leeg voor de proef")
	if not vrij:
		return
	var inf: Pawn = _actieve_pion(st, mens, Vector2i(5, 6), Constants.UnitType.INFANTRY, 3, 3, 3)
	var doel_schot: Pawn = st._spawn_pawn(ander, Vector2i(5, 4))
	var doel_melee: Pawn = _actieve_pion(st, ander, Vector2i(6, 6), Constants.UnitType.INFANTRY, 2, 2, 2)
	var cav: Pawn = _actieve_pion(st, mens, Vector2i(2, 6), Constants.UnitType.CAVALRY, 3, 4, 3)
	var doel_charge: Pawn = _actieve_pion(st, ander, Vector2i(2, 3), Constants.UnitType.INFANTRY, 2, 2, 2)
	var kanon: Pawn = _actieve_pion(st, mens, Vector2i(8, 7), Constants.UnitType.ARTILLERY, 1, 4, 2)
	var doel_kanon: Pawn = st._spawn_pawn(ander, Vector2i(8, 4))
	st.current_player = mens
	game._refresh_all()
	await _rustig()
	# de draai: de bovenkant van het platte plaatje wijst het scherm in
	var cam: Camera3D = game._camera
	var kijk: Vector3 = -cam.global_transform.basis.z
	kijk.y = 0.0
	kijk = kijk.normalized()
	var boven: Vector3 = Basis(Vector3.UP, MARKERING.draai_naar(cam)) * Vector3(0.0, 0.0, -1.0)
	_ok(boven.dot(kijk) > 0.999, "een ruit ligt met zijn bovenkant het scherm in (dot %.4f)" % boven.dot(kijk))
	# infanterist: loop, melee, schot en de eigen ruit
	game._select_pawn(inf.id)
	var srt: Dictionary = _soorten(game)
	_ok(int(srt.get("loop", 0)) > 0 and int(srt.get("melee", 0)) == 1 and int(srt.get("schot", 0)) == 1
		and int(srt.get("geselecteerd", 0)) == 1 and not srt.has("plak"),
		"infanterist: loop, 1 melee, 1 schot, de eigen ruit, geen oude plakken %s" % [srt])
	var raak := 0
	var kosten_ok := 0
	var loop_n := 0
	for h in game._highlights:
		var n: Node3D = h
		var soort: String = String(n.get_meta("soort", ""))
		var vak := Vector2i(roundi(n.position.x), roundi(n.position.z))
		if soort == "melee" and vak == doel_melee.position and n.get_node_or_null("Boven") != null:
			raak += 1
		if soort == "schot" and vak == doel_schot.position and n.get_node_or_null("Boven") != null:
			raak += 1
		if soort == "loop":
			loop_n += 1
			var getal := n.get_node_or_null("Kosten") as Label3D
			if getal != null and int(getal.text) >= 1 and n.get_node_or_null("Boven") == null:
				kosten_ok += 1
	_ok(raak == 2, "de melee- en de schot-ruit liggen onder het juiste doel, met het icoon boven zijn hoofd")
	_ok(loop_n > 0 and kosten_ok == loop_n, "elke loop-tegel draagt zijn kosten (%d van %d)" % [kosten_ok, loop_n])
	await _shot("hud_mark_inf")
	# ruiter: de charge heeft een eigen ruit (geen melee-ruit)
	game._select_pawn(cav.id)
	srt = _soorten(game)
	_ok(int(srt.get("charge", 0)) >= 1 and int(srt.get("melee", 0)) == 0, "ruiter: de charge heeft een eigen ruit %s" % [srt])
	var charge_raak := false
	for h in game._highlights:
		if String((h as Node).get_meta("soort", "")) == "charge" 				and Vector2i(roundi(h.position.x), roundi(h.position.z)) == doel_charge.position:
			charge_raak = true
	_ok(charge_raak, "de charge-ruit ligt onder het doel")
	await _shot("hud_mark_cav")
	# kanon: vuurlijn en doel
	game._select_pawn(kanon.id)
	srt = _soorten(game)
	_ok(int(srt.get("vuurlijn", 0)) >= 1 and int(srt.get("schot", 0)) == 1, "kanon: vuurlijn en een doel %s" % [srt])
	await _shot("hud_mark_kanon")
	# de knop: de oude plakken terug, op dezelfde vakken
	var nieuw: Array = []
	for h in game._highlights:
		nieuw.append("%.2f,%.2f" % [h.position.x, h.position.z])
	nieuw.sort()
	var was: float = PawnView.fx("markeringen", 1.0)
	PawnView.set_fx("markeringen", 0.0)
	game._select_pawn(kanon.id)
	srt = _soorten(game)
	var oud: Array = []
	for h in game._highlights:
		oud.append("%.2f,%.2f" % [h.position.x, h.position.z])
	oud.sort()
	_ok(srt.keys() == ["plak"], "knop markeringen op 0: de oude plakken %s" % [srt])
	# de eigen ruit onder de gekozen pion is nieuw: die telt de oude tekening niet
	var zonder_eigen: Array = nieuw.duplicate()
	zonder_eigen.erase("%.2f,%.2f" % [float(kanon.position.x), float(kanon.position.y)])
	_ok(oud == zonder_eigen, "op dezelfde vakken als de ruiten (%d)" % oud.size())
	PawnView.set_fx("markeringen", was)
	game._deselect()
	_ok(game._highlights.is_empty(), "deselecteren ruimt alles op")


static func _schermen(game: Node) -> void:
	print("[HUD] schermen")
	var st: GameState = GameSession.state
	var mens: int = game._human_id
	var inzet = game._inzet
	game._deselect()
	var beeld: Vector2 = game.get_viewport().get_visible_rect().size
	# --- alleen het CP-bod (voor ronde 2 en 3, en in cyclus 1) ---
	var cp_was: int = int(st.cp.get(mens, 0))
	st.cp[mens] = maxi(cp_was, 3)
	var saldo: int = int(st.cp.get(mens, 0))
	var maximaal: int = mini(saldo, Validator.expected_define_count(st, mens))
	var gekozen: Array = [-1]
	inzet.open({"cp": {"saldo": saldo, "max": maximaal}}, func(cp: int, _k: Array) -> void: gekozen[0] = cp)
	await _rustig()
	var s: Dictionary = inzet.stand()
	_ok(bool(s.zichtbaar) and s.delen == ["cp"] and int(s.cp) == 0 and int(s.cp_max) == maximaal,
		"alleen het CP-bod: begint op 0, maximum %d" % maximaal)
	_ok(String(s.totaal_cp) == "%d/%d" % [saldo, saldo] and String(s.totaal_punten) == "",
		"bovenaan je totaal CP als nu/vol: %s" % s.totaal_cp)
	_ok(inzet.find_child("CpMin", true, false).disabled and not inzet.find_child("CpPlus", true, false).disabled,
		"op 0 staat de min uit en de plus aan")
	for i in maximaal + 2:
		inzet.druk_cp(1)
	_ok(int(inzet.stand().cp) == maximaal and inzet.find_child("CpPlus", true, false).disabled,
		"de plus stopt op het maximum (%d)" % maximaal)
	inzet.druk_cp(-1)
	_ok(int(inzet.stand().cp) == maximaal - 1, "de min haalt er een af")
	_ok(String(inzet.stand().totaal_cp) == "%d/%d" % [saldo - (maximaal - 1), saldo],
		"de chip loopt mee met je inzet: %s" % inzet.stand().totaal_cp)
	var paneel: Control = inzet.find_child("Paneel", true, false)
	var pr: Rect2 = paneel.get_global_rect()
	_ok(pr.position.x >= 0.0 and pr.end.x <= beeld.x and pr.position.y >= 0.0 and pr.end.y <= beeld.y,
		"het scherm past in beeld (%s)" % pr)
	_ok(inzet.find_children("*", "Label", true, false).size() <= 6, "weinig tekst (%d labels)" % inzet.find_children("*", "Label", true, false).size())
	await _shot("hud_cp")
	inzet.druk_klaar()
	_ok(int(gekozen[0]) == maximaal - 1 and not inzet.visible, "KLAAR geeft de inzet door (%d) en sluit" % int(gekozen[0]))
	# --- de versterkingsfase: CP en versterkingen in een scherm ---
	var fase_was: int = st.phase
	var gedaan_was = st.spawn_done.get(mens, false)
	st.phase = Phase.Type.CYCLE_SPAWN
	st.spawn_done[mens] = false
	game._show_spawn_overlay()
	await _rustig()
	s = inzet.stand()
	var types: Array = []
	for t in 3:
		if st.kent_type(mens, t):
			types.append(t)
	_ok(bool(s.zichtbaar) and s.delen == ["cp", "spawn"], "in de versterkingsfase staan CP en versterkingen in een scherm %s" % [s.delen])
	_ok(s.types == types and int(s.punten_over) == st.pool_total(mens), "een rij per type dat de factie kent %s, punten %d" % [s.types, int(s.punten_over)])
	_ok(String(s.totaal_cp) == "%d/%d" % [saldo, saldo] and String(s.totaal_punten) == "%d/%d" % [st.pool_total(mens), st.pool_total(mens)],
		"bovenaan totaal CP (%s) en totaal versterkingspunten (%s)" % [s.totaal_cp, s.totaal_punten])
	var cap: int = mini(mini(int(st.rules.campaign.get("spawn_max", 3)), st.spawns_over(mens)),
		Validator.vrije_spawn_vakken(st, mens).size())
	if cap > 0 and st.pool_total(mens) >= st.spawn_kosten(int(types[0])):
		inzet.druk_type(int(types[0]), 1)
		s = inzet.stand()
		_ok(s.keuze == [int(types[0])] and int(s.punten_over) == st.pool_total(mens) - st.spawn_kosten(int(types[0])),
			"plus koopt er een en de punten tellen af (%d over)" % int(s.punten_over))
		_ok(String(s.totaal_punten) == "%d/%d" % [int(s.punten_over), st.pool_total(mens)], "en de chip bovenaan telt mee: %s" % s.totaal_punten)
		inzet.druk_type(int(types[0]), -1)
		_ok(inzet.stand().keuze.is_empty(), "min geeft hem terug")
		for i in 12:
			inzet.druk_type(int(types[0]), 1)
		s = inzet.stand()
		_ok(s.keuze.size() <= cap and int(s.punten_over) >= 0 and not bool(s.plus_aan[int(types[0])]),
			"de plus gaat uit als de cyclus vol is of het geld op (%d gekocht, max %d)" % [s.keuze.size(), cap])
		for i in 12:
			inzet.druk_type(int(types[0]), -1)
		inzet.druk_type(int(types[0]), 1)
	inzet.druk_cp(1)
	await _shot("hud_inzet")
	# KLAAR: de spawns gaan de engine in, de CP-inzet wacht op ronde 1
	var pionnen_was: int = st.get_alive_pawns_for(mens).size()
	var keuze_n: int = inzet.stand().keuze.size()
	var doorgegeven: Array = []
	var echte_submit: Callable = Callable(game, "_on_inzet_klaar")
	# de proef boekt niet echt (de fase is gezet, niet gespeeld): alleen wat het scherm teruggeeft
	inzet._klaar = func(cp: int, keuze: Array) -> void: doorgegeven.append([cp, keuze])
	inzet.druk_klaar()
	_ok(doorgegeven.size() == 1 and int(doorgegeven[0][0]) == 1 and (doorgegeven[0][1] as Array).size() == keuze_n,
		"KLAAR geeft CP (1) en de gekozen types (%d) terug" % keuze_n)
	_ok(echte_submit.is_valid() and st.get_alive_pawns_for(mens).size() == pionnen_was, "de proef raakte de staat niet")
	# zonder CP: alleen versterkingen
	st.cp[mens] = 0
	game._show_spawn_overlay()
	_ok(inzet.stand().delen == ["spawn"], "zonder CP-saldo alleen de versterkingen")
	# het moment is voorbij (de fase schuift door): het scherm sluit zichzelf
	st.phase = fase_was
	st.spawn_done[mens] = gedaan_was
	st.cp[mens] = cp_was
	await _wacht(0.3)
	_ok(not inzet.visible, "is het moment voorbij, dan sluit het scherm zichzelf")
	_ok(not bool(game.render_digest().inzet.zichtbaar), "render_digest telt het inzet-scherm mee")
	game._voor_cp = -1
