extends RefCounted

## `-- inkomfilm [uitmap] [reeks...]` (capture.tscn, alleen met venster): plaatjes
## van de UI-beweging halverwege en aan het eind, om te zien hoe het beweegt.
## Speelt op een lager tempo (ui_tempo 0,3), zodat de tussenstanden vallen.
## Schrijft <uitmap>/<reeks>_<n>.png; standaard user://inkomfilm. Reeksen: menu,
## kaarten, hub, loting, intro, stof (zonder: allemaal).

const Beweging := preload("res://scripts/ui/ui_beweging.gd")
const TEMPO := 0.3

static var _host: Node = null
static var _uit := ""
static var _fouten := 0


static func run(host: Node, uit: String = "", reeksen: Array = []) -> int:
	_host = host
	_fouten = 0
	_uit = uit if uit != "" else "user://inkomfilm"
	if DisplayServer.get_name() == "headless":
		print("[FILM] alleen met venster (headless tekent niets)")
		return 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_uit))
	var tempo_oud: float = Beweging.tempo()
	Beweging.forceer(1)
	Beweging.zet_tempo(TEMPO)
	var alles := reeksen.is_empty()
	if alles or reeksen.has("menu"):
		await _menu()
	if alles or reeksen.has("kaarten"):
		await _kaarten()
	if alles or reeksen.has("hub"):
		await _hub()
	if alles or reeksen.has("loting"):
		await _loting()
	if alles or reeksen.has("intro"):
		await _duel_intro()
	if alles or reeksen.has("stof"):
		await _stof()
	Beweging.zet_tempo(tempo_oud)
	Beweging.forceer(-1)
	print("[FILM] klaar: %s (%d fouten)" % [ProjectSettings.globalize_path(_uit), _fouten])
	return _fouten


static func _schiet(naam: String) -> void:
	await RenderingServer.frame_post_draw
	var tex := _host.get_viewport().get_texture()
	if tex == null or tex.get_image() == null:
		_fouten += 1
		return
	var pad := "%s/%s.png" % [_uit, naam]
	tex.get_image().save_png(pad)
	print("[FILM] %s" % naam)


## Plaatjes op vaste tijden na nu (echte tijd, want de tweens negeren de time_scale).
static func _reeks(naam: String, tijden: Array) -> void:
	var start := Time.get_ticks_msec()
	for i in tijden.size():
		var doel: int = start + int(float(tijden[i]) * 1000.0)
		while Time.get_ticks_msec() < doel:
			await _host.get_tree().process_frame
		await _schiet("%s_%d" % [naam, i + 1])


static func _wacht(s: float) -> void:
	await _host.get_tree().create_timer(s, true, false, true).timeout
	await _host.get_tree().process_frame


# --- Het hoofdmenu komt binnen, dan menu naar menu -----------------------------

static func _menu() -> void:
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	_host.add_child(game)
	Beweging.zet_tempo(TEMPO)   # game._ready zette ui_tempo uit het sfeer-bestand
	await _wacht(1.2)
	var overlay: Control = game.get("_overlay")
	overlay.hide()
	await _wacht(0.4)
	game.call("_show_difficulty_menu")
	await _reeks("menu", [0.05, 0.25, 0.45, 0.7, 1.5])
	overlay.call("_pick", 2)   # de uitleg
	await _reeks("uitleg", [0.05, 0.3, 0.6, 1.5])
	game.queue_free()
	await _wacht(0.3)


# --- Uitdelen met het CP-zegel, en de onthulling ---------------------------------

static func _kaarten() -> void:
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	_host.add_child(game)
	Beweging.zet_tempo(TEMPO)
	await _wacht(1.0)
	game.call("_start_match", 1)
	await _wacht(0.3)
	game.call("_confirm_placement")
	await _wacht(1.6)
	if Phase.is_define(GameSession.state.phase) and not (game.get("_card_hand") as Control).visible:
		game.call("_on_cp_choice", 1)
	await _reeks("uitdelen", [0.4, 1.3, 1.9, 2.5, 4.5])
	var hand: CardHand = game.get("_card_hand")
	hand.call("_on_confirm_pressed")
	var onthul: Control = null
	for i in 100:
		await _host.get_tree().process_frame
		onthul = game.get("_onthul_scherm")
		if onthul != null and onthul.visible:
			break
	if onthul != null and onthul.visible:
		await _reeks("onthul", [0.1, 0.6, 1.0, 1.5, 2.2, 4.0])
	else:
		_fouten += 1
		print("[FILM] geen onthulscherm")
	game.queue_free()
	await _wacht(0.3)


# --- De hub: de golf, een pop-up, en de punten die optellen ---------------------

static func _hub() -> void:
	var hs = load("res://tools/hub_shot.gd")
	var orakel := "res://data/duel_orakel.json" if FileAccess.file_exists("res://data/duel_orakel.json") else ""
	var driver = hs._nieuwe_driver(42, orakel)
	hs._spoel_door(driver, "einde" if orakel != "" else "")
	var hub: Control = load("res://scripts/ui/campaign/campaign_hub.gd").new()
	hub.set("driver", driver)
	hub.set("mens_id", 0)
	hub.set("klaar_overslaan", true)   # de loting heeft een eigen reeks
	_host.add_child(hub)
	await _wacht(2.0)
	hub.call("_cascade")   # de golf van de eerste opening nog eens, nu alles geladen is
	await _reeks("hub", [0.05, 0.4, 0.8, 1.2, 2.5])
	if orakel != "":
		hub.call("_toon_punten")
		await _reeks("punten", [0.1, 0.6, 1.2, 1.8, 2.6, 4.0])
	hub.queue_free()
	await _wacht(0.3)


# --- De loting en de klaarmelding voor de start (30 september) ------------------

static func _loting() -> void:
	var driver := SoloDriver.new(42, 0)
	driver.duel_ai = "easy"
	var hub: Control = load("res://scripts/ui/campaign/campaign_hub.gd").new()
	hub.set("driver", driver)
	hub.set("mens_id", 0)
	_host.add_child(hub)
	# Op tempo 0,3 duurt de onthulling ruim 12 s: ongeveer een plaatje per paar.
	await _reeks("loting", [0.5, 2.0, 3.5, 5.0, 6.5, 8.0, 9.5, 11.0, 13.0])
	var knop: Button = hub.find_child("KlaarmeldKnop", true, false)
	if knop == null:
		_fouten += 1
		print("[FILM] KLAAR ging niet open na de loting")
	else:
		knop.pressed.emit()
		await _reeks("klaar", [0.1, 0.4, 1.0, 2.5])
	var d: Dictionary = driver.mens_duel()
	if not d.is_empty():
		hub.set("_auto_stop_idx", int(d.idx))
	if CampaignBridge.driver == driver:
		CampaignBridge.driver = null
	hub.queue_free()
	await _wacht(0.3)


# --- Het duel-intro: van de hub naar het bord (6 oktober) -----------------------

static func _duel_intro() -> void:
	var driver := SoloDriver.new(42, 0)
	driver.duel_ai = "easy"
	var hub: Control = load("res://scripts/ui/campaign/campaign_hub.gd").new()
	hub.set("driver", driver)
	hub.set("mens_id", 0)
	hub.set("klaar_overslaan", true)
	_host.add_child(hub)
	await _wacht(1.0)
	var d: Dictionary = driver.mens_duel()
	if d.is_empty():
		_fouten += 1
		print("[FILM] geen duel om te tonen")
	else:
		hub.set("_auto_stop_idx", int(d.idx))   # de aftel uit: het intro tonen we zelf
		var vijand: int = int(d.p2) if int(d.p1) == 0 else int(d.p1)
		hub.call("_toon_lader", vijand)
		await _reeks("intro", [0.05, 0.3, 0.6, 1.0, 1.6, 2.4, 3.4])
	if CampaignBridge.driver == driver:
		CampaignBridge.driver = null
	hub.queue_free()
	await _wacht(0.3)


# --- Stof, schaduw en de klik (6 oktober) -----------------------------------------

## Een knop in de voet van de hub: hover (schaduw eronder), indrukken (wolkje),
## dan een pop-up waarvan de rijen landen met stof.
static func _stof() -> void:
	var driver := SoloDriver.new(42, 0)
	driver.duel_ai = "easy"
	var hub: Control = load("res://scripts/ui/campaign/campaign_hub.gd").new()
	hub.set("driver", driver)
	hub.set("mens_id", 0)
	hub.set("klaar_overslaan", true)
	_host.add_child(hub)
	await _wacht(1.5)
	var d: Dictionary = driver.mens_duel()
	if not d.is_empty():
		hub.set("_auto_stop_idx", int(d.idx))   # geen aftel naar het bord
	var knop: BaseButton = null
	for b in (hub.get("_voet") as Node).find_children("*", "BaseButton", true, false):
		if (b as BaseButton).is_visible_in_tree() and not (b as BaseButton).disabled:
			knop = b
			break
	if knop == null:
		_fouten += 1
		print("[FILM] geen knop in de voet")
	else:
		var muis := InputEventMouseMotion.new()
		muis.device = 0
		Beweging.zie_invoer(muis)
		knop.mouse_entered.emit()
		await _reeks("hover", [0.2, 0.7])
		knop.button_down.emit()
		await _reeks("klik", [0.03, 0.12, 0.3, 0.6])
		knop.button_up.emit()
		knop.mouse_exited.emit()
		await _wacht(0.5)
	hub.call("_toon_instellingen")
	await _reeks("popup", [0.15, 0.35, 0.55, 0.8, 1.2, 2.0])
	if CampaignBridge.driver == driver:
		CampaignBridge.driver = null
	hub.queue_free()
	await _wacht(0.3)
