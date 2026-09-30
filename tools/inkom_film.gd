extends RefCounted

## `-- inkomfilm [uitmap]` (capture.tscn, alleen met venster): plaatjes van de
## UI-beweging halverwege en aan het eind, om te zien hoe het beweegt. Speelt op
## een lager tempo (ui_tempo 0,3), zodat de tussenstanden vallen. Schrijft
## <uitmap>/<reeks>_<n>.png; standaard user://inkomfilm.

const Beweging := preload("res://scripts/ui/ui_beweging.gd")
const TEMPO := 0.3

static var _host: Node = null
static var _uit := ""
static var _fouten := 0


static func run(host: Node, uit: String = "") -> int:
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
	await _menu()
	await _kaarten()
	await _hub()
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
	_host.add_child(hub)
	await _wacht(2.0)
	hub.call("_cascade")   # de golf van de eerste opening nog eens, nu alles geladen is
	await _reeks("hub", [0.05, 0.4, 0.8, 1.2, 2.5])
	if orakel != "":
		hub.call("_toon_punten")
		await _reeks("punten", [0.1, 0.6, 1.2, 1.8, 2.6, 4.0])
	hub.queue_free()
	await _wacht(0.3)
