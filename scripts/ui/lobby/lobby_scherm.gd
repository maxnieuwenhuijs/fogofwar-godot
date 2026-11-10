extends Control

## De multiplayer-lobby uit het ontwerp van milestone 4 (pdf "Multiplayer
## Lobby", assets in assets/ui/lobby/): 16 stoelen in twee teams van 8.
## Voorlopig een OEFENVERSIE: de andere spelers worden nagespeeld door
## scripts/game/lobby_sim.gd (de echte lobby komt met F5.1). Het scherm zelf
## weet daar niets van: het tekent wat de naspeler zegt en geeft de knoppen
## door.
##
## Van boven naar beneden, 1080 breed (de plaatjes op ware grootte):
##   kop        vaandel, "Multiplayer-lobby", "?"
##   infobalk   lobbycode met kopieerknop | tempo | soort
##   statusbalk host | spelers en wanneer hij begint
##   teams      TEAM BLAUW 3/8 | TEAM ROOD 2/8
##   stoelen    twee kolommen van 8: nummer, portret, naam, bot-teken, klaar
##   onderaan   de stand, en WEG | KLAAR of NIET KLAAR | START NU (host)
## Chat en instellingen uit het ontwerp staan er nog niet: die doen in de
## oefenversie niets.
##
##   _lobby = LOBBY_SCHERM.new()
##   $UI.add_child(_lobby)
##   _lobby.open(LOBBY_SIM.new(seed, naam, factie), bij_start, bij_weg)
##
## Voor de checks: stand(), tik_ms(ms), druk_klaar(), druk_start(), druk_weg().

const Pack := preload("res://scripts/ui/ui_pack.gd")
const Beweging := preload("res://scripts/ui/ui_beweging.gd")

const BREEDTE := 1080.0
const HOOGTE := 1920.0
## 10 november: de drie balken bovenaan een derde lager dan het ontwerp (kop
## 112, infobalk 104, statusbalk 76 in plaats van 171, 154 en 111); de
## stoelen kregen die ruimte.
const RIJ := 140.0
const STOEL_Y := 420.0
const INKT := Color("#2A1D12")
const INKT_ZACHT := Color("#6A543C")
const IVOOR := Color("#F1E6CF")

var sim = null
var _bij_start: Callable = Callable()
var _bij_weg: Callable = Callable()
var _kolom: Control = null
var _status: Label = null
var _stand_tekst: Label = null
var _team_tel: Array = [null, null]
var _stoel_node: Array = []     # per stoel de houder
var _stoel_sleutel: Array = []  # wat er nu getekend staat
var _klaar_knop: Button = null
var _klaar_icoon: TextureRect = null
var _klaar_tekst: Label = null
var _start_knop: Button = null
var _code: Label = null


func _init() -> void:
	name = "LobbyScherm"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open(naspeler, bij_start: Callable, bij_weg: Callable) -> void:
	sim = naspeler
	_bij_start = bij_start
	_bij_weg = bij_weg
	_bouw()
	visible = true
	_ververs()
	Audio.play("ui_open")
	Beweging.inkom_scherm(null, _kolom)


func sluit() -> void:
	visible = false
	sim = null


func _process(delta: float) -> void:
	if visible and sim != null:
		tik_ms(int(delta * 1000.0))


## De klok een stuk verder (het scherm zelf, of een check die doorspoelt).
func tik_ms(ms: int) -> void:
	if sim == null:
		return
	sim.tik(ms)
	_ververs()
	if sim.gestart:
		var start := _bij_start
		sluit()
		if start.is_valid():
			start.call()


# --- Bouwen ----------------------------------------------------------------------

func _tekst(t: String, grootte: int, kleur: Color, rol: String, x: float, y: float, b: float, h: float,
		midden: bool = false) -> Label:
	var l := Pack.tekst(t, grootte, kleur, rol)
	l.position = Vector2(x, y)
	l.size = Vector2(b, h)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	if midden:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kolom.add_child(l)
	return l


func _icoon(naam: String, x: float, y: float, maat: float, kleur: Color) -> TextureRect:
	var r := Pack.icoon(naam, maat, kleur)
	r.position = Vector2(x, y)
	_kolom.add_child(r)
	return r


## Een knop op een heel plaatje, met een icoon boven een woord.
## Een plaat als 9-patch (het beslag in de hoeken houdt zijn vorm).
func _negen(naam: String, r: Rect2, mx: int, my: int) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = Pack.tex(naam)
	n.patch_margin_left = mx
	n.patch_margin_right = mx
	n.patch_margin_top = my
	n.patch_margin_bottom = my
	n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.position = r.position
	n.size = r.size
	_kolom.add_child(n)
	return n


func _grote_knop(plaat: String, ingedrukt: String, x: float, y: float, b: float, h: float,
		icoon: String, woord: String) -> Button:
	var k := Button.new()
	Pack.knop(k, plaat, ingedrukt)
	k.position = Vector2(x, y)
	k.size = Vector2(b, h)
	_kolom.add_child(k)
	var ic := Pack.icoon(icoon, 84.0, IVOOR)
	ic.name = "Icoon"
	ic.position = Vector2((b - 84.0) * 0.5, 28.0)
	k.add_child(ic)
	var l := Pack.tekst(woord, 24, IVOOR, "kop")
	l.name = "Woord"
	l.position = Vector2(4.0, h - 70.0)
	l.size = Vector2(b - 8.0, 40.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	k.add_child(l)
	return k


func _bouw() -> void:
	for kind in get_children():
		remove_child(kind)
		kind.queue_free()
	var achter := Pack.plaat("lobby/bg/BG")
	achter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	achter.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(achter)
	_kolom = Control.new()
	_kolom.name = "Kolom"
	_kolom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kolom.anchor_left = 0.5
	_kolom.anchor_right = 0.5
	_kolom.offset_left = -BREEDTE * 0.5
	_kolom.offset_right = BREEDTE * 0.5
	_kolom.offset_bottom = HOOGTE
	add_child(_kolom)
	# kop
	_negen("lobby/box/Multiplayer_lobby_holder", Rect2(126, 0, 828, 112), 40, 36)
	Pack.zet_plaat(_kolom, "lobby/box/Player_box_1", 0, 0, 126, 120)
	_tekst(tr("LOBBY_TITLE"), 34, INKT, "kop", 146, 12, 788, 48, true)
	_tekst(tr("LOBBY_SUB"), 22, INKT, "tekst", 146, 60, 788, 34, true)
	# infobalk: code | tempo | soort
	_negen("lobby/box/Lobby_Info_Bar", Rect2(0, 112, 1080, 104), 44, 34)
	_icoon("lobby/icons/Code", 42, 138, 52, INKT)
	_code = _tekst(String(sim.code), 31, INKT, "kop", 112, 126, 220, 42)
	_tekst(tr("LOBBY_CODE"), 19, INKT_ZACHT, "tekst", 112, 166, 220, 28)
	var kopieer := Button.new()
	kopieer.name = "Kopieer"
	kopieer.flat = true
	kopieer.focus_mode = Control.FOCUS_NONE
	for staat in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		kopieer.add_theme_stylebox_override(staat, StyleBoxEmpty.new())
	kopieer.position = Vector2(356, 136)
	kopieer.size = Vector2(56, 56)
	kopieer.icon = Pack.tex("lobby/icons/Copy")
	kopieer.expand_icon = true
	for staat in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		kopieer.add_theme_color_override(staat, INKT)
	kopieer.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(String(sim.code))
		Audio.play("ui_click")
		Beweging.punch(_code, 1.12, Vector2(0.0, 0.5)))
	_kolom.add_child(kopieer)
	Pack.zet_plaat(_kolom, "lobby/ornaments/Divider", 452, 130, 4, 68)
	_icoon("lobby/icons/Time_icon", 492, 138, 52, INKT)
	_tekst(tr("LOBBY_LIVE"), 31, INKT, "kop", 562, 126, 140, 42)
	_tekst(tr("LOBBY_PACE"), 19, INKT_ZACHT, "tekst", 562, 166, 140, 28)
	Pack.zet_plaat(_kolom, "lobby/ornaments/Divider", 716, 130, 4, 68)
	_icoon("lobby/icons/Globe", 754, 138, 52, INKT)
	_tekst(tr("LOBBY_PRACTICE"), 31, INKT, "kop", 824, 126, 240, 42)
	_tekst(tr("LOBBY_NO_LADDER"), 19, INKT_ZACHT, "tekst", 824, 166, 240, 28)
	# statusbalk
	_negen("lobby/box/Lobby_Status_Bar", Rect2(2, 216, 1076, 76), 40, 28)
	_tekst(tr("LOBBY_HOST") % String(sim.stoelen[0].naam), 22, INKT, "kop", 44, 226, 290, 56)
	Pack.zet_plaat(_kolom, "lobby/ornaments/Divider", 344, 230, 4, 48)
	_icoon("lobby/icons/Players", 376, 231, 46, INKT)
	_status = _tekst("", 23, INKT, "kop", 438, 226, 620, 56)
	# teams
	for team in 2:
		var x: float = team * 540.0
		Pack.zet_plaat(_kolom, "lobby/box/Team_Box_%d" % (team + 1), x, 292, 540, 124)
		var tent := UiAssets.icoon_rect("pool", 58.0, IVOOR)
		tent.position = Vector2(x + 48, 324)
		tent.size = Vector2(58, 58)
		_kolom.add_child(tent)
		_tekst(tr("LOBBY_TEAM_BLUE") if team == 0 else tr("LOBBY_TEAM_RED"), 30, IVOOR, "kop", x + 130, 310, 300, 42, true)
		_team_tel[team] = _tekst("", 30, IVOOR, "kop", x + 130, 350, 300, 42, true)
		Pack.zet_plaat(_kolom, "lobby/box/Players_frame_BG", x, 412, 540, RIJ * 8.0 + 14.0)
	# stoelen
	_stoel_node = []
	_stoel_sleutel = []
	for i in sim.stoelen.size():
		var houder := Control.new()
		houder.name = "Stoel_%d" % i
		houder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		houder.position = Vector2(float(int(sim.stoelen[i].team)) * 540.0 + 2.0, STOEL_Y + float(i % 8) * RIJ)
		houder.size = Vector2(536, RIJ - 4.0)
		_kolom.add_child(houder)
		_stoel_node.append(houder)
		_stoel_sleutel.append("")
	# onderaan
	var onder: float = STOEL_Y + 8.0 * RIJ + 12.0
	Pack.zet_plaat(_kolom, "lobby/box/State_holder", 24, onder, 313, 66)
	_stand_tekst = _tekst("", 26, IVOOR, "kop", 44, onder + 4, 290, 58)
	var ky: float = onder + 84.0
	var weg := _grote_knop("lobby/buttons/Leave_button_default", "lobby/buttons/Leave_button_pressed",
		138, ky, 204, 194, "lobby/icons/Leave", tr("LOBBY_LEAVE"))
	weg.name = "WegKnop"
	weg.pressed.connect(druk_weg)
	_klaar_knop = _grote_knop("lobby/buttons/Not_ready_box", "", 362, ky, 355, 194, "lobby/icons/Not_ready", "")
	_klaar_knop.name = "KlaarKnop"
	_klaar_icoon = _klaar_knop.get_node("Icoon")
	_klaar_tekst = _klaar_knop.get_node("Woord")
	_klaar_tekst.add_theme_font_size_override("font_size", 32)
	_klaar_knop.pressed.connect(druk_klaar)
	_start_knop = _grote_knop("lobby/buttons/Start_now_Active", "lobby/buttons/Start_now_Pressed",
		737, ky, 204, 194, "match_hud/icons/attack", tr("LOBBY_START"))
	_start_knop.name = "StartKnop"
	_start_knop.pressed.connect(druk_start)


## Een stoel opnieuw tekenen: nummer, portret, naam, bot-teken of "host", klaar.
func _teken_stoel(i: int) -> void:
	var s: Dictionary = sim.stoelen[i]
	var houder: Control = _stoel_node[i]
	for kind in houder.get_children():
		houder.remove_child(kind)
		kind.queue_free()
	var team: int = int(s.team)
	var soort: String = String(s.soort)
	var leeg: bool = soort == "leeg"
	var plaat := "lobby/buttons/Lobby_Player_Slot_%d_%s" % [team + 1, "pressed" if soort == "jij" else "default"]
	Pack.zet_plaat(houder, plaat, 0, 0, 536, RIJ - 4.0)
	Pack.zet_plaat(houder, "lobby/ornaments/Lobby_Player_Slot_number_holder", 44, 35, 38, 66)
	var nr := Pack.tekst(str(i % 8 + 1), 22, IVOOR, "kop")
	nr.position = Vector2(44, 35)
	nr.size = Vector2(38, 66)
	nr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	houder.add_child(nr)
	var p := Pack.portret(-1 if leeg else int(s.doctrine), 116.0,
		"lobby/box/Lobby_Player_Slot_player_BG%d" % (team + 1))
	p.position = Vector2(108, 10)
	houder.add_child(p)
	var naam := Pack.tekst(tr("LOBBY_WAITING") if leeg else String(s.naam), 25,
		INKT_ZACHT if leeg else INKT, "tekst" if leeg else "kop")
	naam.position = Vector2(240, 30 if (bool(s.host) or soort == "bot") else 48)
	naam.size = Vector2(206, 40)
	naam.clip_text = true
	houder.add_child(naam)
	if bool(s.host):
		var host := Pack.tekst(tr("LOBBY_HOST_TAG"), 21, INKT_ZACHT, "tekst")
		host.position = Vector2(240, 70)
		host.size = Vector2(206, 30)
		houder.add_child(host)
	elif soort == "bot":
		# een bot is altijd zichtbaar gemerkt (nooit alleen aan de naam te zien)
		var bot := Pack.icoon("lobby/icons/Bot", 30.0, INKT)
		bot.name = "Bot"
		bot.position = Vector2(240, 72)
		houder.add_child(bot)
	var klaar := Pack.plaat("lobby/buttons/Ready_Status_Icon_checked" if bool(s.klaar) else "lobby/buttons/Ready_Status_Icon_off")
	klaar.position = Vector2(450, 35)
	klaar.size = Vector2(66, 66)
	houder.add_child(klaar)


static func _klok(ms: int) -> String:
	var s: int = int(ceil(float(ms) / 1000.0))
	return "%d:%02d" % [int(s / 60.0), s % 60]


func _ververs() -> void:
	if sim == null or _kolom == null:
		return
	for i in sim.stoelen.size():
		var s: Dictionary = sim.stoelen[i]
		var sleutel := "%s|%s|%s|%d" % [s.soort, s.naam, s.klaar, int(s.doctrine)]
		if sleutel != String(_stoel_sleutel[i]):
			var eerste: bool = String(_stoel_sleutel[i]) == ""
			_stoel_sleutel[i] = sleutel
			_teken_stoel(i)
			if not eerste:
				Beweging.plof(_stoel_node[i], 0.0, 0.92, false, Vector2(0.5, 0.5), false)
	for team in 2:
		(_team_tel[team] as Label).text = "%d / 8" % sim.in_team(team)
	if String(sim.staat) == "vullen":
		_status.text = tr("LOBBY_STATUS_FILL") % [sim.spelers(), _klok(int(sim.vul_ms))]
		_stand_tekst.text = tr("LOBBY_STATE") % tr("LOBBY_STATE_FILLING")
	else:
		_status.text = tr("LOBBY_STATUS_START") % int(ceil(float(sim.start_ms) / 1000.0))
		_stand_tekst.text = tr("LOBBY_STATE") % tr("LOBBY_STATE_STARTING")
	var klaar: bool = bool(sim.stoelen[0].klaar)
	if _klaar_knop.get_meta("klaar", null) != klaar:
		_klaar_knop.set_meta("klaar", klaar)
		if klaar:
			Pack.knop(_klaar_knop, "lobby/buttons/Ready_box_default", "lobby/buttons/Ready_box_pressed")
		else:
			Pack.knop(_klaar_knop, "lobby/buttons/Not_ready_box")
		_klaar_icoon.texture = Pack.tex("lobby/icons/Ready" if klaar else "lobby/icons/Not_ready")
		_klaar_icoon.modulate = Color.WHITE
		_klaar_tekst.text = tr("LOBBY_READY") if klaar else tr("LOBBY_NOT_READY")
	var kan_starten: bool = String(sim.staat) == "vullen"
	if _start_knop.disabled == kan_starten:
		_start_knop.disabled = not kan_starten
		Pack.knop(_start_knop, "lobby/buttons/Start_now_Active" if kan_starten else "lobby/buttons/Start_now_blocked",
			"lobby/buttons/Start_now_Pressed" if kan_starten else "")
		(_start_knop.get_node("Icoon") as CanvasItem).modulate = Color(IVOOR, 1.0 if kan_starten else 0.45)
		(_start_knop.get_node("Woord") as CanvasItem).modulate = Color(1, 1, 1, 1.0 if kan_starten else 0.45)


# --- Knoppen --------------------------------------------------------------------------

func druk_klaar() -> void:
	if sim == null:
		return
	sim.zet_klaar(not bool(sim.stoelen[0].klaar))
	Audio.play("ui_click")
	_ververs()
	Beweging.punch(_klaar_tekst, 1.15)


func druk_start() -> void:
	if sim == null or String(sim.staat) != "vullen":
		return
	sim.start_nu()
	Audio.play("ui_click")
	_ververs()


func druk_weg() -> void:
	var weg := _bij_weg
	Audio.play("ui_click")
	sluit()
	if weg.is_valid():
		weg.call()


func stand() -> Dictionary:
	if sim == null:
		return {"zichtbaar": visible}
	var bots := 0
	var gemerkt := 0
	var leeg := 0
	for i in sim.stoelen.size():
		var soort: String = String(sim.stoelen[i].soort)
		if soort == "bot":
			bots += 1
			if (_stoel_node[i] as Node).get_node_or_null("Bot") != null:
				gemerkt += 1
		elif soort == "leeg":
			leeg += 1
	return {
		"zichtbaar": visible,
		"stoelen": _stoel_node.size(),
		"spelers": sim.spelers(),
		"leeg": leeg,
		"bots": bots,
		"bots_gemerkt": gemerkt,
		"staat": String(sim.staat),
		"status": _status.text if _status != null else "",
		"teams": [(_team_tel[0] as Label).text, (_team_tel[1] as Label).text],
		"klaar": bool(sim.stoelen[0].klaar),
		"klaar_tekst": _klaar_tekst.text if _klaar_tekst != null else "",
		"start_aan": not _start_knop.disabled if _start_knop != null else false,
		"code": String(sim.code),
	}
