class_name Overlay
extends Control

## Het modale keuzescherm van het bord: titel, eventueel een korte uitleg en
## de keuzes onder elkaar, eventueel met een icoon per knop en een icoon bij
## de titel.
##
## Sinds 10 november in de stijl van het ontwerp van milestone 3 (Max: "het
## huidige pop over menu's en alle opties veel mooier stylen"): perkament met
## beslag (hetzelfde als het inzet-scherm), een dunne lijn onder de titel, de
## uitleg klein en zacht, en elke keuze een donkere plaat met ivoren letters
## en een icoon. "Terug" en "annuleren" zijn een kleinere tekstknop onderaan.
## Een keuze zonder icoon krijgt er vanzelf een als zijn tekst in
## ICOON_PER_SLEUTEL staat. De werking is ongewijzigd: dezelfde Buttons in
## dezelfde volgorde als directe kinderen van %Buttons, met hun tekst.

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _buttons: VBoxContainer = %Buttons
@onready var _titel_icoon_houder: CenterContainer = %TitelIcoon
@onready var _dim: ColorRect = $Dim
@onready var _midden: Control = $Center

## UI-beweging (30 september): de inkom van het paneel (scripts/ui/ui_beweging.gd).
const Beweging := preload("res://scripts/ui/ui_beweging.gd")
const Pack := preload("res://scripts/ui/ui_pack.gd")

const KNOP_MAAT := Vector2(600, 88)
const KNOP_FONT := 28
const KNOP_ICOON := 44
const TERUG_MAAT := Vector2(0, 60)   # zo breed als icoon en tekst samen
const INKT_ZACHT := Color("#6A543C")
const IVOOR := Color("#F1E6CF")
const GOUD := Color("#F3C56B")
## Icoon per keuze, op de vertaalsleutel van zijn tekst ("pack:<pad>" = de
## levering van milestone 3 + 4, "hub:<naam>" = een icoon van de campaign hub,
## anders een id van UiAssets). Een keuze met een eigen icoon houdt die.
const ICOON_PER_SLEUTEL := {
	"MENU_SOLO": "act-melee",
	"MENU_MULTI": "pack:lobby/icons/Players",
	"MENU_RULES_OPTION": "hub:Info_icon",
	"MENU_SETTINGS": "hub:Settings_icon",
	"MENU_SOLO_1V1": "act-melee",
	"MENU_SOLO_CAMPAIGN": "score",
	"MENU_SOLO_STRATEGY": "pool",
	"MENU_MULTI_PRACTICE_RED": "pack:lobby/icons/Bot",
	"MENU_MULTI_PRACTICE_BLUE": "pack:lobby/icons/Bot",
	"MENU_MULTI_ONLINE": "pack:lobby/icons/Globe",
	"MENU_MULTI_CAMPAIGN_PRACTICE": "pack:lobby/icons/Players",
	"MENU_ONLINE_NEW": "pack:lobby/icons/Code",
	"MENU_ONLINE_NEW_STRAT": "pool",
	"MENU_ONLINE_JOIN": "pack:lobby/icons/Code",
	"MENU_ONLINE_RESUME": "pack:lobby/icons/Time_icon",
	"MENU_ONLINE_COPY": "pack:lobby/icons/Copy",
	"MENU_DIFF_EASY": "unit-infantry",
	"MENU_DIFF_MEDIUM": "unit-cavalry",
	"MENU_DIFF_HARD": "unit-artillery",
	"MENU_DIFF_ULTRA": "win-harbor",
	"PHASE_PLACEMENT_MANUAL": "phase-setup",
	"PHASE_PLACEMENT_STANDARD": "check",
	"STRAT_PLACEMENT_CHANGE": "unit-infantry",
	"END_NEW_GAME": "act-melee",
}
## Deze keuzes zijn de weg terug: een kleine tekstknop onderaan.
const TERUG_SLEUTELS := ["MENU_BACK", "MENU_ONLINE_CANCEL", "END_BACK_TO_MENU", "END_BACK_TO_CAMPAIGN"]
const TITEL_ICOON := 64.0
const BODY_BREEDTE_LINKS := 820.0

var _cb: Callable = Callable()
var _titel_icoon: TextureRect = null
var _getoond: bool = false        # ooit getoond (de hide in game._ready telt niet als weg)
var _weg_frame: int = -100        # het frame waarin hij voor het laatst verdween


func _ready() -> void:
	_titel_icoon = UiAssets.icoon_rect("", TITEL_ICOON, UiAssets.INKT)
	_titel_icoon_houder.add_child(_titel_icoon)
	_titel_icoon_houder.visible = false
	visibility_changed.connect(_bij_zichtbaar)
	_stijl_paneel()


## Het paneel in de stijl van het ontwerp: perkament met beslag, een dunne
## lijn onder de titel, de uitleg klein en zacht.
func _stijl_paneel() -> void:
	var paneel := $Center/Panel as PanelContainer
	paneel.custom_minimum_size = Vector2(840, 0)
	paneel.add_theme_stylebox_override("panel", Pack.patch("match_hud/box/Player_box", Vector2(44, 44),
		Vector4(56, 44, 56, 48)))
	var kolom := _title.get_parent() as VBoxContainer
	var lijn := ColorRect.new()
	lijn.name = "Lijn"
	lijn.color = Color(UiAssets.INKT, 0.28)
	lijn.custom_minimum_size = Vector2(0, 2)
	lijn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kolom.add_child(lijn)
	kolom.move_child(lijn, _title.get_index() + 1)
	_body.add_theme_font_size_override("font_size", 23)
	_body.add_theme_color_override("font_color", INKT_ZACHT)
	_buttons.add_theme_constant_override("separation", 12)


## Texture bij een icoon-id: "pack:<pad>", "hub:<naam>" of een id van UiAssets.
static func icoon_tex(id: String) -> Texture2D:
	if id == "":
		return null
	if id.begins_with("pack:"):
		return Pack.tex(id.substr(5))
	if id.begins_with("hub:"):
		return HubAssets.tex("icons/" + id.substr(4))
	return UiAssets.icoon(id)


## De vertaalsleutel waarvan dit de tekst is ("" als hij in geen lijst staat).
func _sleutel_van(tekst: String, sleutels: Array) -> String:
	for k in sleutels:
		if tr(String(k)) == tekst:
			return String(k)
	return ""


## Een keuze als donkere plaat met ivoren letters; de weg terug als kleine
## tekstknop in inkt.
func _stijl_knop(button: Button, terug: bool) -> void:
	if terug:
		button.flat = true
		for staat in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(staat, StyleBoxEmpty.new())
		for staat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(staat, INKT_ZACHT)
		for staat in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
			button.add_theme_color_override(staat, INKT_ZACHT)
		var f := UiAssets.font("kop")
		if f != null:
			button.add_theme_font_override("font", f)
		button.custom_minimum_size = TERUG_MAAT
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_constant_override("icon_max_width", 30)
		button.add_theme_constant_override("h_separation", 10)
		return
	Pack.knop(button, "lobby/buttons/quick_chat_button_default", "lobby/buttons/quick_chat_button_pressed",
		"", IVOOR, Vector2(34, 30))
	for staat in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := button.get_theme_stylebox(staat) as StyleBoxTexture
		if sb != null:
			sb.content_margin_left = 30.0
			sb.content_margin_right = 30.0
	for staat in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		button.add_theme_color_override(staat, GOUD)
	button.custom_minimum_size = KNOP_MAAT
	button.add_theme_font_size_override("font_size", KNOP_FONT)
	button.add_theme_constant_override("icon_max_width", KNOP_ICOON)
	button.add_theme_constant_override("h_separation", 16)


func _bij_zichtbaar() -> void:
	if not visible and _getoond:
		_weg_frame = Engine.get_process_frames()
		Beweging.meld_weg()


## Toon een modaal keuzescherm. options = knop-labels; cb.call(index) bij keuze.
## accent kleurt de titel (bv. de teamkleur van de winnaar); Color.WHITE
## betekent "geen accent" en wordt inkt (tekst op perkament).
## body_left: lange uitlegteksten links uitlijnen en breder laten wrappen.
## iconen: per optie een icoon-id (UiAssets.icoon) of ""; titel_icoon: een
## icoon-id boven de titel (64 px, inkt).
func show_choice(title: String, body: String, options: Array, cb: Callable = Callable(),
		accent: Color = Color.WHITE, body_left: bool = false, iconen: Array = [],
		titel_icoon: String = "") -> void:
	# UI-beweging: vers geopend (verborgen sinds een eerder frame), of in
	# hetzelfde frame opnieuw getoond (menu naar menu, of spawn kopen). Het
	# openen zelf blijft synchroon: knoppen, teksten en visible staan meteen.
	var terug_zelfde_frame: bool = not visible and _getoond \
		and Engine.get_process_frames() - _weg_frame <= 1
	var vers: bool = not visible and not terug_zelfde_frame
	var zelfde_titel: bool = _title.text == title
	var vervangt: bool = vers and Beweging.vervangt()
	if vers and _getoond:
		# Niet bij het allereerste menu na het opstarten (Max, 10 november: "ik
		# hoor een soort inadem-geluidje steeds bij start, dat hoeft niet").
		Audio.play("ui_open")
	visible = true
	_getoond = true
	_title.text = title
	_title.add_theme_color_override("font_color", UiAssets.INKT if accent == Color.WHITE else accent)
	_zet_titel_icoon(titel_icoon)
	_body.text = body
	_body.visible = body != ""
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if body_left else HORIZONTAL_ALIGNMENT_CENTER
	_body.custom_minimum_size = Vector2(BODY_BREEDTE_LINKS, 0) if body_left else Vector2(0, 0)
	# Kan aangeroepen worden vanuit een button-pressed-signaal (menu -> menu);
	# de knop is dan nog locked, dus niet hard free()-en.
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	for i in options.size():
		var button := Button.new()
		button.text = str(options[i])
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.focus_mode = Control.FOCUS_NONE
		var terug: bool = _sleutel_van(button.text, TERUG_SLEUTELS) != ""
		_stijl_knop(button, terug)
		if terug:
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var icoon_id: String = String(iconen[i]) if i < iconen.size() else ""
		if icoon_id == "":
			icoon_id = "pack:lobby/icons/Leave" if terug else String(ICOON_PER_SLEUTEL.get(
				_sleutel_van(button.text, ICOON_PER_SLEUTEL.keys()), ""))
		var tex: Texture2D = icoon_tex(icoon_id)
		if tex != null:
			button.icon = tex
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			# de tekstknop is zo breed als zijn inhoud: daar houdt het icoon zijn eigen maat
			button.expand_icon = not terug
		var idx := i
		button.pressed.connect(func() -> void: _pick(idx))
		# Het hover-geluid (alleen met een echte muis) en de schaduw doet de
		# UI-beweging voor elke knop (Beweging.koppel_knop).
		_buttons.add_child(button)
	_cb = cb
	if vers and not vervangt:
		Beweging.inkom_scherm(_dim, _midden)
		Beweging.inkom_rij(_buttons.get_children(), 0.06)
		Beweging.plof(_titel_icoon, 0.10, 0.6, false)
	elif vers or not zelfde_titel:
		# Een ander scherm verdween net, of menu naar menu: de waas blijft
		# staan en de inhoud wisselt. Dezelfde titel (spawn kopen): niets.
		Beweging.wissel(_midden)
		Beweging.inkom_rij(_buttons.get_children(), 0.03)
		Beweging.klank("ui_blad")


## UI-beweging: de titel stempelt erop (winst op het eindscherm).
func stempel_titel() -> void:
	Beweging.stempel(_title, 0.18)


func _zet_titel_icoon(id: String) -> void:
	if _titel_icoon == null:
		return
	_titel_icoon.texture = UiAssets.icoon(id) if id != "" else null
	_titel_icoon.visible = _titel_icoon.texture != null
	_titel_icoon_houder.visible = _titel_icoon.visible


func _pick(index: int) -> void:
	Audio.play("ui_click")
	visible = false
	if _cb.is_valid():
		_cb.call(index)
