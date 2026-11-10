extends Control

## Strategy mode (21 oktober, Max: "zoveel kanonnen, zoveel mannen, zoveel cav
## etc. Ieder stuk is een aantal punten waard en thats it"): het scherm waarop
## je in de opstelfase je leger koopt. Drie rijen (soldaat, big bro, kanon) met
## min en plus, de stand van je budget en je pionnen, een paar snelle keuzes en
## LEGER KLAAR. Puur een keuzescherm: de engine kent alleen de opstelling die
## game.gd daarna met dit leger indient (GameState.default_placement(..., leger)
## of het zelf opstellen), dus wat hier gebeurt komt niet in de staat.
##
## game.gd maakt hem eenmalig (LEGER_BOUWER_SCRIPT.new(), via preload, zodat
## het parst zonder klassencache) en hangt hem aan $UI; daarna:
##
##   _leger_bouwer.open(session.state, _human_id, start_leger, func(leger): ...)
##
## Alles wat hier mag, mag de engine ook (GameState.leger_geldig): plus stopt
## bij het budget en bij een vol bord, min bij nul, en LEGER KLAAR kan alleen
## met minstens een pion.

const NAAM := "LegerBouwer"
const Beweging := preload("res://scripts/ui/ui_beweging.gd")

const TYPEN := [
	["unit-infantry", "STRAT_TYPE_INF"],
	["unit-cavalry", "STRAT_TYPE_CAV"],
	["unit-artillery", "STRAT_TYPE_ART"],
]
## De snelle keuzes: [i18n-sleutel, deel van het budget voor ruiters, voor kanonnen]
## (GameState.leger_uit_verdeling); "standaard" is het standaardleger van de modus.
const SNEL := [
	["STRAT_PRESET_STANDARD", -1.0, -1.0],
	["STRAT_PRESET_INF", 0.0, 0.0],
	["STRAT_PRESET_CAV", 0.55, 0.0],
	["STRAT_PRESET_ART", 0.0, 0.5],
]

var leger: Array = [0, 0, 0]
var _state: GameState = null
var _speler: int = Constants.PLAYER_1
var _cb: Callable = Callable()
var _aantal: Array = []        # Label per type
var _plus: Array = []          # Button per type
var _min: Array = []           # Button per type
var _punten: Label
var _pionnen: Label
var _reserve: Label
var _klaar: Button
var _dim: ColorRect
var _midden: CenterContainer
var _uitleg: Label


func _init() -> void:
	name = NAAM
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.62)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_midden = CenterContainer.new()
	_midden.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_midden)
	var paneel := PanelContainer.new()
	paneel.theme_type_variation = "PaneelVeldtafel"
	paneel.custom_minimum_size = Vector2(900, 0)
	_midden.add_child(paneel)
	var kolom := VBoxContainer.new()
	kolom.add_theme_constant_override("separation", 16)
	paneel.add_child(kolom)
	var titel := Label.new()
	titel.theme_type_variation = "LabelKopInkt"
	titel.add_theme_font_size_override("font_size", 40)
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titel.text = tr("STRAT_BUILD_TITLE")
	kolom.add_child(titel)
	_uitleg = Label.new()
	_uitleg.theme_type_variation = "LabelInkt"
	_uitleg.add_theme_font_size_override("font_size", 24)
	_uitleg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_uitleg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_uitleg.custom_minimum_size = Vector2(820, 0)
	kolom.add_child(_uitleg)
	for t in 3:
		kolom.add_child(_bouw_rij(t))
	var stand := HBoxContainer.new()
	stand.alignment = BoxContainer.ALIGNMENT_CENTER
	stand.add_theme_constant_override("separation", 40)
	_punten = _stand_label()
	stand.add_child(_punten)
	_pionnen = _stand_label()
	stand.add_child(_pionnen)
	kolom.add_child(stand)
	_reserve = Label.new()
	_reserve.theme_type_variation = "LabelInktZacht"
	_reserve.add_theme_font_size_override("font_size", 22)
	_reserve.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolom.add_child(_reserve)
	var snel := HBoxContainer.new()
	snel.alignment = BoxContainer.ALIGNMENT_CENTER
	snel.add_theme_constant_override("separation", 10)
	for i in SNEL.size():
		var knop := Button.new()
		knop.name = "Snel_%d" % i
		knop.theme_type_variation = "KnopKleinBreed"
		knop.text = tr(String(SNEL[i][0]))
		knop.custom_minimum_size = Vector2(196, 64)
		knop.add_theme_font_size_override("font_size", 20)
		knop.focus_mode = Control.FOCUS_NONE
		knop.pressed.connect(_kies_snel.bind(i))
		snel.add_child(knop)
	kolom.add_child(snel)
	_klaar = Button.new()
	_klaar.name = "LegerKlaar"
	_klaar.theme_type_variation = "KnopBevestig"   # groen, zoals KLAAR op het inzet-scherm
	_klaar.text = tr("STRAT_BUILD_READY")
	_klaar.custom_minimum_size = Vector2(600, 96)
	_klaar.add_theme_font_size_override("font_size", 28)
	_klaar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_klaar.focus_mode = Control.FOCUS_NONE
	var vink := UiAssets.icoon("check")
	if vink != null:
		_klaar.icon = vink
		_klaar.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_klaar.expand_icon = false
		_klaar.add_theme_constant_override("icon_max_width", 48)
	_klaar.pressed.connect(_bevestig)
	kolom.add_child(_klaar)


func _stand_label() -> Label:
	var l := Label.new()
	l.theme_type_variation = "LabelKopInkt"
	l.add_theme_font_size_override("font_size", 28)
	return l


## Een rij: icoon, naam met prijs, min, aantal, plus.
func _bouw_rij(t: int) -> Control:
	var rij := HBoxContainer.new()
	rij.name = "Rij_%d" % t
	rij.add_theme_constant_override("separation", 18)
	rij.alignment = BoxContainer.ALIGNMENT_CENTER
	rij.add_child(UiAssets.icoon_rect(String(TYPEN[t][0]), 64.0, UiAssets.INKT))
	var naam := Label.new()
	naam.name = "Naam"
	naam.theme_type_variation = "LabelInkt"
	naam.add_theme_font_size_override("font_size", 28)
	naam.custom_minimum_size = Vector2(330, 0)
	naam.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rij.add_child(naam)
	var minus := Button.new()
	minus.name = "Min"
	minus.theme_type_variation = "KnopMin"
	minus.custom_minimum_size = Vector2(72, 72)
	minus.focus_mode = Control.FOCUS_NONE
	minus.pressed.connect(_wijzig.bind(t, -1))
	rij.add_child(minus)
	var aantal := Label.new()
	aantal.name = "Aantal"
	aantal.theme_type_variation = "LabelCijfer"
	aantal.add_theme_font_size_override("font_size", 44)
	aantal.custom_minimum_size = Vector2(90, 0)
	aantal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rij.add_child(aantal)
	var plus := Button.new()
	plus.name = "Plus"
	plus.theme_type_variation = "KnopPlus"
	plus.custom_minimum_size = Vector2(72, 72)
	plus.focus_mode = Control.FOCUS_NONE
	plus.pressed.connect(_wijzig.bind(t, 1))
	rij.add_child(plus)
	_aantal.append(aantal)
	_min.append(minus)
	_plus.append(plus)
	return rij


## Toon het scherm voor `speler` met `start` als beginleger (leeg = het
## standaardleger van de modus); cb.call(leger) bij LEGER KLAAR.
func open(state: GameState, speler: int, start: Array, cb: Callable) -> void:
	_state = state
	_speler = speler
	_cb = cb
	leger = (start if start.size() == 3 else state.doctrine_data_of(speler).comp).duplicate()
	var budget: int = int(state.rules.strategie.get("budget", 0))
	_uitleg.text = tr("STRAT_BUILD_BODY") % [budget, Constants.PAWNS_PER_PLAYER]
	for t in 3:
		var naam: Label = (_aantal[t] as Label).get_parent().get_node("Naam")
		naam.text = tr("STRAT_TYPE_PRICE") % [tr(String(TYPEN[t][1])), state.stuk_kosten(t)]
	var pool: int = state.pool_total(speler)
	_reserve.text = tr("STRAT_BUILD_RESERVE") % [pool, int(state.cp.get(speler, 0))]
	_reserve.visible = state.rules.campaign_actief()
	_ververs()
	var vers := not visible
	visible = true
	if vers:
		Audio.play("ui_open")
		Beweging.inkom_scherm(_dim, _midden)


func sluit() -> void:
	visible = false


## Kost dit leger niet meer dan het budget en past het op het bord? (Zonder
## de ondergrens van een pion: tijdens het bouwen mag het even leeg zijn.)
func _past(l: Array) -> bool:
	if l.size() != 3 or int(l[0]) < 0 or int(l[1]) < 0 or int(l[2]) < 0:
		return false
	if int(l[0]) + int(l[1]) + int(l[2]) > Constants.PAWNS_PER_PLAYER:
		return false
	return _state.leger_kosten(l) <= int(_state.rules.strategie.get("budget", 0))


func _wijzig(t: int, delta: int) -> void:
	var nieuw: Array = leger.duplicate()
	nieuw[t] = int(nieuw[t]) + delta
	if not _past(nieuw):
		Beweging.schud(_plus[t] if delta > 0 else _min[t])
		Beweging.klank("ui_error")
		return
	leger = nieuw
	Beweging.punch(_aantal[t])
	Beweging.klank("ui_tel", 0.0, 0.04 * float(int(leger[t])))
	_ververs()


func _kies_snel(i: int) -> void:
	if float(SNEL[i][1]) < 0.0:
		leger = (_state.rules.strategie.get("standaard", [1, 0, 0]) as Array).duplicate()
	else:
		leger = _state.leger_uit_verdeling(float(SNEL[i][1]), float(SNEL[i][2]))
	for t in 3:
		Beweging.punch(_aantal[t])
	Beweging.klank("ui_blad")
	_ververs()


func _ververs() -> void:
	var budget: int = int(_state.rules.strategie.get("budget", 0))
	var kosten: int = _state.leger_kosten(leger)
	var n: int = int(leger[0]) + int(leger[1]) + int(leger[2])
	for t in 3:
		(_aantal[t] as Label).text = str(int(leger[t]))
		var meer: Array = leger.duplicate()
		meer[t] = int(meer[t]) + 1
		(_plus[t] as Button).disabled = not _past(meer)
		(_min[t] as Button).disabled = int(leger[t]) <= 0
	_punten.text = tr("STRAT_BUILD_POINTS") % [kosten, budget]
	_pionnen.text = tr("STRAT_BUILD_PAWNS") % [n, Constants.PAWNS_PER_PLAYER]
	_punten.add_theme_color_override("font_color", UiAssets.INKT if kosten == budget else UiAssets.WAS_ROOD)
	_klaar.disabled = not _state.leger_geldig(leger)


func _bevestig() -> void:
	if _state == null or not _state.leger_geldig(leger):
		return
	Audio.play("ui_click")
	visible = false
	if _cb.is_valid():
		_cb.call(leger.duplicate())
