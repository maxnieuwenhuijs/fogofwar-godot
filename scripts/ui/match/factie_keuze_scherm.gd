class_name FactieKeuzeScherm
extends Control

## Het modale factie-keuzescherm van het bord (brief §6): de zes facties als
## regimentskaarten (UiFactieKaart) onder elkaar op de veldtafel, met een
## titel en een uitlegregel erboven. Vervangt de tekstlijst in de overlay
## van het doctrine-menu en het tegenstander-menu (game.gd).
##
## game.gd maakt hem eenmalig in _ready (FACTIE_KEUZE_SCRIPT.new(), via
## preload zodat het parst zonder klassencache) en hangt hem aan $UI direct
## boven de overlay; daarna:
##
##   _factie_keuze.open(tr("MENU_DOCTRINE_TITLE"), tr("HUD_UI_DOCTRINE_UITLEG"),
##       false, _on_doctrine_choice)
##
## Index-betekenis van de callback (gelijk aan de oude menu's):
##   zonder verrassing: index = positie in Constants.DOCTRINE_DATA.keys();
##   met verrassing:    0 = verrassing (blinde loting), 1.. = positie + 1.
## Factie-data komt uit CRules.actieve_tabel().doctrine_data(d) (C17: dezelfde
## bron als de campagne, de trainer en de arena).

const NAAM := "FactieKeuzeScherm"
const TITEL_FONT := 36
const UITLEG_FONT := 22
const KNOP_HOOGTE := 96.0
const KNOP_FONT := 28
const KNOP_ICOON := 48
## Rechts blijft een strook vrij voor de knoppenkolom van game.gd ("?",
## sfeer, opgeven op x 976..1064): die staat later in de boom en tekent dus
## over dit scherm heen.
const MARGE_RECHTS := 130

var _titel: Label
var _uitleg: Label
var _scroll: ScrollContainer
var _lijst: VBoxContainer
var _cb: Callable = Callable()
var _met_verrassing: bool = false


func _init() -> void:
	name = NAAM
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var achtergrond := PanelContainer.new()
	achtergrond.theme_type_variation = "PaneelDonker"
	achtergrond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(achtergrond)
	var marge := MarginContainer.new()
	marge.add_theme_constant_override("margin_left", 40)
	marge.add_theme_constant_override("margin_right", MARGE_RECHTS)
	marge.add_theme_constant_override("margin_top", 56)
	marge.add_theme_constant_override("margin_bottom", 40)
	achtergrond.add_child(marge)
	var kolom := VBoxContainer.new()
	kolom.add_theme_constant_override("separation", 18)
	marge.add_child(kolom)
	_titel = Label.new()
	_titel.theme_type_variation = "LabelKop"
	_titel.add_theme_font_size_override("font_size", TITEL_FONT)
	_titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kolom.add_child(_titel)
	_uitleg = Label.new()
	_uitleg.add_theme_font_size_override("font_size", UITLEG_FONT)
	_uitleg.add_theme_color_override("font_color", UiAssets.WARM_IVOOR)
	_uitleg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_uitleg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kolom.add_child(_uitleg)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kolom.add_child(_scroll)
	_lijst = VBoxContainer.new()
	_lijst.add_theme_constant_override("separation", 14)
	_lijst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_lijst)


## Toon het scherm; bij een tik cb.call(index) en het scherm verbergt zich.
func open(titel: String, uitleg: String, met_verrassing: bool, cb: Callable) -> void:
	_titel.text = titel
	_uitleg.text = uitleg
	_uitleg.visible = uitleg != ""
	_met_verrassing = met_verrassing
	_cb = cb
	_bouw_lijst()
	if not visible:
		Audio.play("ui_open")
	visible = true
	_scroll.scroll_vertical = 0


func sluit() -> void:
	visible = false


func _bouw_lijst() -> void:
	# Kan vanuit een pressed-signaal van een kaart in deze lijst komen
	# (doctrine-menu -> tegenstander-menu), dus niet hard free()-en.
	for kind in _lijst.get_children():
		_lijst.remove_child(kind)
		kind.queue_free()
	var offset := 0
	if _met_verrassing:
		var verrassing := Button.new()
		verrassing.theme_type_variation = "KnopBreed"
		verrassing.text = tr("MENU_OPP_SURPRISE")
		verrassing.custom_minimum_size = Vector2(0, KNOP_HOOGTE)
		verrassing.add_theme_font_size_override("font_size", KNOP_FONT)
		verrassing.focus_mode = Control.FOCUS_NONE
		var icoon := UiAssets.icoon("hidden")
		if icoon != null:
			verrassing.icon = icoon
			verrassing.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			verrassing.expand_icon = false
			verrassing.add_theme_constant_override("icon_max_width", KNOP_ICOON)
		verrassing.pressed.connect(func() -> void: _kies(0))
		_lijst.add_child(verrassing)
		offset = 1
	var tabel := CRules.actieve_tabel()
	var sleutels: Array = Constants.DOCTRINE_DATA.keys()
	for i in sleutels.size():
		var doctrine: int = sleutels[i]
		var kaart := UiFactieKaart.new(doctrine, tabel.doctrine_data(doctrine), true)
		var index := offset + i
		kaart.pressed.connect(func() -> void: _kies(index))
		_lijst.add_child(kaart)


func _kies(index: int) -> void:
	Audio.play("ui_click")
	visible = false
	if _cb.is_valid():
		_cb.call(index)
