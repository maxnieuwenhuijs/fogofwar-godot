extends RefCounted

## `-- strategiecheck [fase...]` (21 oktober): Strategy mode door de echte UI
## van het bord en de campagne, headless of met venster.
##
##  menu       SOLO toont Strategy mode; via 1v1 en de factiekeuze (alleen het
##             uiterlijk, geen factieregels op de kaarten) staat het potje in
##             Strategy mode en opent de opstelfase met de legerbouwer.
##  bouwer     de legerbouwer: begint op het standaardleger, plus stopt bij het
##             budget, een snelle keuze, min en plus; LEGER KLAAR, dan het
##             opstelmenu met "leger aanpassen"; de standaard-opstelling zet
##             precies dat leger op het bord, en de bot kocht een eigen leger.
##  handmatig  zelf opstellen met een kanonnenleger (8 kanonnen: meer dan de
##             oude drie kanonplekken), het leger klopt in de engine.
##  potje      een hele partij uit (de mens via het timeout-pad, zoals uispel):
##             een winnaar, en een gekoppelde soldaat heeft precies de stamina
##             van zijn kaart (geen factie-perk, ook niet bij de Muis).
##  campagne   een Strategy-campagne tot het mens-duel; het bord krijgt de
##             strategieregels via de brug, de legerbouwer opent, en de uitslag
##             boekt terug in de campagne.
##  hub        de hub van een Strategy-campagne: de factiekeuze toont alleen het
##             uiterlijk en de spelregels zeggen dat je je leger koopt.
##  online     de online-weg van game.gd (RemoteSession op een loopback met een
##             bot, zonder server): de modus komt uit de regels van de match
##             (ook zonder de menuvlag), de factiekeuze en de legerbouwer
##             volgen, je leger gaat over de draad en de bot stelt het zijne op.
##             Tegen de echte server: `-- lobbycheck [url] strategie`.
##
## Raakt de echte save niet: de campagne en de hub draaien zonder autosave.
## Exit 1 bij een fout; de grep op "SCRIPT ERROR" hoort erbij.

const FASEN := ["menu", "bouwer", "handmatig", "potje", "campagne", "hub", "online"]
const GAME := "res://scenes/game/game.tscn"
const HUB := "res://scripts/ui/campaign/campaign_hub.gd"

static var _fouten := 0
static var _host: Node = null


static func run(host: Node, fasen: Array = []) -> int:
	_fouten = 0
	_host = host
	var te_doen: Array = FASEN if fasen.is_empty() else fasen
	for fase in te_doen:
		match String(fase):
			"menu", "bouwer":
				# de bouwer loopt via het menu; samen gevraagd = een keer
				if String(fase) == "menu" and te_doen.has("bouwer"):
					continue
				await _menu_en_bouwer(String(fase) == "bouwer")
			"handmatig":
				await _handmatig()
			"potje":
				await _potje()
			"campagne":
				await _campagne()
			"hub":
				await _hub()
			"online":
				await _online()
			_:
				_fouten += 1
				print("[STRAT] onbekende fase: %s (bekend: %s)" % [fase, ", ".join(FASEN)])
	print("[STRAT] %s: %d fouten" % ["PASS" if _fouten == 0 else "FAIL", _fouten])
	return _fouten


static func _ok(voorwaarde: bool, wat: String) -> void:
	if voorwaarde:
		print("[STRAT]   ok   %s" % wat)
	else:
		_fouten += 1
		print("[STRAT]   FOUT %s" % wat)


static func _wacht(s: float) -> void:
	await _host.get_tree().create_timer(s, true, false, true).timeout
	await _host.get_tree().process_frame


static func _nieuw_bord() -> Node:
	var game: Node = load(GAME).instantiate()
	_host.add_child(game)
	await _wacht(0.5)
	return game


static func _weg(game: Node) -> void:
	game.queue_free()
	await _wacht(0.2)


## Een Strategy-potje tot in de legerbouwer, zonder de menu's (Muis tegen Wolf).
static func _potje_in_bouwer() -> Node:
	var game: Node = await _nieuw_bord()
	game.set("_strategie", true)
	game.set("_human_doctrine", Constants.Doctrine.MUIS)
	game.set("_ai_doctrine", Constants.Doctrine.WOLF)
	game._start_match(1)
	await _wacht(0.1)
	return game


static func _telling(st: GameState, speler: int) -> Array:
	var t := [0, 0, 0]
	for p in st.pawns.values():
		if p.owner_id == speler and not p.is_eliminated:
			t[p.unit_type] += 1
	return t


# --- menu en legerbouwer ----------------------------------------------------------

static func _menu_en_bouwer(ook_bouwer: bool) -> void:
	print("[STRAT] fase menu")
	var game: Node = await _nieuw_bord()
	var overlay = game.get("_overlay")
	game._show_solo_menu()
	var knoppen: Array = overlay.get_node("%Buttons").get_children()
	var teksten: Array = []
	for k in knoppen:
		teksten.append(String((k as Button).text))
	_ok(teksten.has(game.tr("MENU_SOLO_STRATEGY")), "SOLO toont Strategy mode (%s)" % ", ".join(PackedStringArray(teksten)))
	overlay._pick(2)
	_ok(String(overlay.get_node("%Title").text) == game.tr("MENU_STRATEGY_TITLE"), "het Strategy-menu staat open")
	overlay._pick(0)
	_ok(bool(game.get("_strategie")), "1v1 in Strategy mode gekozen")
	overlay._pick(1)   # medium
	var keuze = game.get("_factie_keuze")
	_ok(keuze != null and keuze.visible and bool(keuze.get("_alleen_uiterlijk")), "de factiekeuze toont alleen het uiterlijk")
	var kaarten: Array = keuze.find_children("*", "UiFactieKaart", true, false)
	var met_feiten := 0
	for k in kaarten:
		for l in (k as Node).find_children("*", "Label", true, false):
			if String((l as Label).text).begins_with("+ "):
				met_feiten += 1
	_ok(kaarten.size() == 6 and met_feiten == 0, "zes kaarten zonder pro/con (%d kaarten, %d pro-regels)" % [kaarten.size(), met_feiten])
	keuze._kies(1)     # Muis
	await _wacht(0.05)
	keuze._kies(5)     # tegenstander: positie 4 = Wolf
	await _wacht(0.2)
	var st: GameState = GameSession.state
	_ok(st.rules.strategie_actief(), "het potje speelt in Strategy mode")
	_ok(st.phase == Phase.Type.PLACEMENT, "de opstelfase")
	var bouwer = game.get("_leger_bouwer")
	_ok(bouwer != null and bouwer.visible and not overlay.visible, "de legerbouwer opent eerst (het opstelmenu nog niet)")
	_ok(int(st.doctrine_data_of(1).cards) == 3 and not bool(st.doctrine_data_of(1).move_through_own),
		"de Muis speelt als allrounder: 3 kaarten, niet door eigen pionnen")
	if not ook_bouwer:
		await _weg(game)
		return
	print("[STRAT] fase bouwer")
	_ok(bouwer.leger == [16, 4, 2], "begint op het standaardleger (%s)" % str(bouwer.leger))
	var plus_art: Button = bouwer.find_child("Rij_2", true, false).get_node("Plus")
	_ok(plus_art.disabled, "budget vol: plus staat uit")
	plus_art.pressed.emit()
	_ok(bouwer.leger == [16, 4, 2], "een plus over het budget verandert niets")
	(bouwer.find_child("Snel_3", true, false) as Button).pressed.emit()
	_ok(bouwer.leger == [15, 0, 5], "snelle keuze veel kanonnen (%s)" % str(bouwer.leger))
	var min_inf: Button = bouwer.find_child("Rij_0", true, false).get_node("Min")
	for i in 3:
		min_inf.pressed.emit()
	_ok(bouwer.leger == [12, 0, 5] and not plus_art.disabled, "drie soldaten minder: ruimte voor een kanon")
	plus_art.pressed.emit()
	_ok(bouwer.leger == [12, 0, 6] and plus_art.disabled, "een kanon erbij: weer vol (%s)" % str(bouwer.leger))
	var klaar: Button = bouwer.find_child("LegerKlaar", true, false)
	_ok(klaar != null and not klaar.disabled, "LEGER KLAAR kan")
	klaar.pressed.emit()
	await _wacht(0.05)
	_ok(game.get("_leger_keuze") == [12, 0, 6] and not bouwer.visible, "het leger is gekozen, de bouwer dicht")
	_ok(overlay.visible and overlay.get_node("%Buttons").get_child_count() == 4, "het opstelmenu met leger aanpassen")
	overlay._pick(2)   # leger aanpassen
	_ok(bouwer.visible and bouwer.leger == [12, 0, 6], "leger aanpassen opent de bouwer op je keuze")
	bouwer.find_child("LegerKlaar", true, false).pressed.emit()
	await _wacht(0.05)
	overlay._pick(1)   # standaard opstelling
	await _wacht(0.3)
	st = GameSession.state
	_ok(st.leger.get(1) == [12, 0, 6] and _telling(st, 1) == [12, 0, 6], "de engine en het bord hebben jouw leger")
	var bot: Array = st.leger.get(2, [])
	_ok(st.leger_geldig(bot) and int(bot[1]) > 4, "de bot (Wolf) kocht een eigen leger met veel big bro's: %s" % str(bot))
	_ok(st.phase != Phase.Type.PLACEMENT, "de opstelfase is voorbij")
	await _weg(game)


# --- zelf opstellen -------------------------------------------------------------

static func _handmatig() -> void:
	print("[STRAT] fase handmatig")
	var game: Node = await _potje_in_bouwer()
	var bouwer = game.get("_leger_bouwer")
	bouwer.leger = [6, 0, 8]
	bouwer._ververs()
	bouwer.find_child("LegerKlaar", true, false).pressed.emit()
	await _wacht(0.05)
	game.get("_overlay")._pick(0)   # zelf opstellen
	await _wacht(0.05)
	_ok(bool(game.get("_placement_mode")), "zelf opstellen loopt")
	var stappen := 0
	while bool(game.get("_placement_mode")) and stappen < 30:
		stappen += 1
		var vrij: Array = game._placement_free_tiles()
		game._on_placement_tile_clicked(vrij[0])
		await _host.get_tree().process_frame
	var st: GameState = GameSession.state
	_ok(stappen == 10, "acht kanonnen en twee dragers zelf neergezet (%d tikken)" % stappen)
	_ok(st.leger.get(1) == [6, 0, 8] and _telling(st, 1) == [6, 0, 8], "het kanonnenleger staat (%s)" % str(_telling(st, 1)))
	await _weg(game)


# --- een hele partij ------------------------------------------------------------

static func _potje() -> void:
	print("[STRAT] fase potje")
	seed(4242)
	var game: Node = await _potje_in_bouwer()
	game.get("_leger_bouwer").find_child("Snel_2", true, false).pressed.emit()   # veel big bro's
	game.get("_leger_bouwer").find_child("LegerKlaar", true, false).pressed.emit()
	await _wacht(0.05)
	var zonder_perk := [0, 0]   # [gekoppelde soldaten, waarvan max_stamina == kaart]
	var t0 := Time.get_ticks_msec()
	var stil_sinds := Time.get_ticks_msec()
	while GameSession.state.phase != Phase.Type.GAME_OVER and Time.get_ticks_msec() - t0 < 15 * 60 * 1000:
		var st: GameState = GameSession.state
		if st.phase == Phase.Type.PLACEMENT and not st.placements_done.get(1, false):
			game._confirm_placement()
			stil_sinds = Time.get_ticks_msec()
		elif Phase.is_reveal(st.phase) and not st.reveal_acks.get(1, false):
			game._continue_after_reveal()
			stil_sinds = Time.get_ticks_msec()
		elif bool(game.get("_timer_active")):
			game.set("_timer_left", 0.0)
			stil_sinds = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - stil_sinds > 3000 and st.current_player == 1 \
				and (st.phase == Phase.Type.ACTION or Phase.is_linking(st.phase)):
			game._on_phase_timeout()
			stil_sinds = Time.get_ticks_msec()
		if st.phase == Phase.Type.ACTION and zonder_perk[0] == 0:
			for p in st.pawns.values():
				if p.owner_id == 1 and p.unit_type == Constants.UnitType.INFANTRY and p.linked_card_id != -1:
					var kaart: Card = st.all_cards.get(p.linked_card_id)
					zonder_perk[0] += 1
					if kaart != null and p.max_stamina == kaart.stamina:
						zonder_perk[1] += 1
		await _host.get_tree().create_timer(0.05).timeout
	var eind: GameState = GameSession.state
	_ok(eind.phase == Phase.Type.GAME_OVER and (eind.winner == 1 or eind.winner == 2),
		"de partij eindigt met een winnaar (%d, cyclus %d, %s)" % [eind.winner, eind.cycle, eind.eind_reden])
	_ok(zonder_perk[0] > 0 and zonder_perk[0] == zonder_perk[1],
		"gekoppelde muis-soldaten zonder +1 stamina: %d van %d" % [zonder_perk[1], zonder_perk[0]])
	_ok(eind.leger.get(1) == [14, 8, 0], "het gekozen leger (veel big bro's) bleef staan (%s)" % str(eind.leger.get(1)))
	print("[STRAT]   zobrist %s" % Zobrist.state_hash(eind))
	await _weg(game)


# --- campagne: het mens-duel op het bord ------------------------------------------

static func _campagne() -> void:
	print("[STRAT] fase campagne")
	var driver := SoloDriver.new(42, 0, 16, "", Constants.Doctrine.MUIS, true)
	driver.duel_ai = "easy"
	driver.bot_duel_honger_vanaf = 10
	_ok(driver.c.rules.strategie_actief(), "een campagne in Strategy mode")
	var voorraad: Dictionary = {}
	for sid in driver.c.spelers:
		voorraad[driver.c.pool_totaal_van(int(sid))] = true
	_ok(voorraad.size() == 1, "iedereen start met dezelfde voorraad (%s)" % str(voorraad.keys()))
	for i in 4:
		if not driver.mens_duel().is_empty():
			break
		driver.stap()
	_ok(not driver.mens_duel().is_empty(), "het mens-duel staat klaar")
	CampaignBridge.driver = driver
	CampaignBridge.campagne_moeilijkheid = 0
	_ok(CampaignBridge.start_mens_duel(), "de brug zet het duel klaar")
	var game: Node = await _nieuw_bord()
	var st: GameState = GameSession.state
	_ok(st.rules.strategie_actief() and st.rules.campaign.get("comp_override") == null,
		"het bord kreeg de strategieregels, zonder vaste opstelling")
	var bouwer = game.get("_leger_bouwer")
	_ok(bouwer.visible, "de legerbouwer opent in het campagne-duel")
	bouwer.find_child("LegerKlaar", true, false).pressed.emit()
	await _wacht(0.05)
	game.get("_overlay")._pick(1)
	await _wacht(0.2)
	st = GameSession.state
	_ok(st.leger.has(1) and st.leger.has(2), "beide kanten hebben gekozen")
	var reserve_voor: int = int(st.pools[1].pt)
	# Kort houden: geef op (de uitslag telt als eliminatie voor de ander).
	GameSession.submit_resign(1)
	await _wacht(0.1)
	var duels_voor: int = driver.duels_gespeeld
	CampaignBridge.rond_af(GameSession.state, GameSession.state.winner)
	_ok(driver.duels_gespeeld > duels_voor, "de uitslag is in de campagne geboekt")
	var rapport: Dictionary = {}
	for e in driver.feed:
		if String(e.get("type", "")) == "report" and (int(e.p1) == 0 or int(e.p2) == 0):
			rapport = e
	_ok(not rapport.is_empty() and int((rapport.get("reserve", {}) as Dictionary).get("0", -1)) == reserve_voor,
		"het slagrapport kent jouw reserve (%d)" % reserve_voor)
	var p: Dictionary = driver.c.pool_van(0)
	_ok(int(p.inf) >= 0 and int(p.cav) >= 0 and int(p.art) >= 0, "geen negatieve voorraad na het duel")
	CampaignBridge.driver = null
	await _weg(game)


# --- online: de online-weg van game.gd op een loopback --------------------------

static func _online() -> void:
	print("[STRAT] fase online")
	var game: Node = await _nieuw_bord()
	game.set("_strategie", true)
	game._start_oefenpotje(Constants.PLAYER_1)
	# De regels van de match zijn nu gebouwd; vanaf hier mag niets meer op de
	# menuvlag leunen (wie online meedoet heeft hem ook niet).
	game.set("_strategie", false)
	var keuze = game.get("_factie_keuze")
	var t0 := Time.get_ticks_msec()
	while not keuze.visible and Time.get_ticks_msec() - t0 < 8000:
		await _host.get_tree().process_frame
	var sessie = game.get("session")
	_ok(sessie != null and sessie.is_online(), "het potje loopt via de online-weg")
	_ok(sessie.state.rules.strategie_actief(), "de regels van de match dragen Strategy mode")
	_ok(keuze.visible and bool(keuze.get("_alleen_uiterlijk")), "de factiekeuze toont alleen het uiterlijk (uit de regels)")
	game._on_doctrine_choice(Constants.DOCTRINE_DATA.keys().find(Constants.Doctrine.MUIS))
	var bouwer = game.get("_leger_bouwer")
	t0 = Time.get_ticks_msec()
	while not bouwer.visible and Time.get_ticks_msec() - t0 < 8000:
		await _host.get_tree().process_frame
	_ok(sessie.state.phase == Phase.Type.PLACEMENT and bouwer.visible, "de opstelfase opent met de legerbouwer")
	bouwer.leger = [12, 0, 6]
	bouwer._ververs()
	bouwer.find_child("LegerKlaar", true, false).pressed.emit()
	await _wacht(0.05)
	game.get("_overlay")._pick(1)   # standaard opstelling
	t0 = Time.get_ticks_msec()
	while sessie.state.phase == Phase.Type.PLACEMENT and Time.get_ticks_msec() - t0 < 8000:
		await _host.get_tree().process_frame
	var st: GameState = sessie.state
	_ok(st.phase != Phase.Type.PLACEMENT, "beide kanten opgesteld (fase %s)" % String(Phase.Type.find_key(st.phase)))
	_ok(st.leger.get(1) == [12, 0, 6] and _telling(st, 1) == [12, 0, 6], "je leger ging over de draad (%s)" % str(st.leger.get(1)))
	var bot: Array = st.leger.get(2, [])
	_ok(st.leger_geldig(bot) and _telling(st, 2) == bot, "de bot stelde een eigen leger op: %s" % str(bot))
	await _weg(game)


# --- de hub ---------------------------------------------------------------------

static func _hub() -> void:
	print("[STRAT] fase hub")
	var driver := SoloDriver.new(42, 0, 16, "", Constants.Doctrine.MUIS, true)
	driver.duel_ai = "easy"
	driver.klaar_gemeld = true
	var hub: Control = load(HUB).new()
	hub.set("driver", driver)
	hub.set("mens_id", 0)
	_host.add_child(hub)
	await _wacht(0.3)
	hub._toon_regels()
	await _wacht(0.1)
	var gevonden := false
	for l in hub.find_children("*", "Label", true, false):
		if String((l as Label).text) == hub.tr("HUB_RULE_LEGER_STRAT") % 30:
			gevonden = true
	_ok(gevonden, "de spelregels zeggen dat je je leger koopt (30 punten)")
	var oud: bool = CampaignBridge.strategie
	CampaignBridge.strategie = true
	hub._toon_factie_keuze()
	await _wacht(0.1)
	var uiterlijk := 0
	var pro := 0
	for k in hub.find_children("Factie_*", "", true, false):
		for l in (k as Node).find_children("*", "Label", true, false):
			if String((l as Label).text) == hub.tr("STRAT_FACTION_LOOK"):
				uiterlijk += 1
			elif String((l as Label).text).begins_with("+ "):
				pro += 1
	_ok(uiterlijk == 6 and pro == 0, "de factiekeuze: zes keer alleen het uiterlijk (%d), geen pro/con (%d)" % [uiterlijk, pro])
	CampaignBridge.strategie = oud
	var d: Dictionary = driver.mens_duel()
	if not d.is_empty():
		hub.set("_auto_stop_idx", int(d.idx))
	if CampaignBridge.driver == driver:
		CampaignBridge.driver = null
	hub.queue_free()
	await _wacht(0.2)
