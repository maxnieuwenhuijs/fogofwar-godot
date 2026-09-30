class_name Overlay
extends Control

## Het modale keuzescherm van het bord: een perkamenten paneel (Frame_2) met
## titel, uitleg en brede knoppen (button_2), eventueel met een icoon per
## knop en een icoon bij de titel (pdf pagina 4, 6 en 7).

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _buttons: VBoxContainer = %Buttons
@onready var _titel_icoon_houder: CenterContainer = %TitelIcoon
@onready var _dim: ColorRect = $Dim
@onready var _midden: Control = $Center

## UI-beweging (30 september): de inkom van het paneel (scripts/ui/ui_beweging.gd).
const Beweging := preload("res://scripts/ui/ui_beweging.gd")

const KNOP_MAAT := Vector2(600, 96)
const KNOP_FONT := 28
const KNOP_ICOON := 48
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
	if vers:
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
		button.theme_type_variation = "KnopBreed"
		button.text = str(options[i])
		button.custom_minimum_size = KNOP_MAAT
		button.add_theme_font_size_override("font_size", KNOP_FONT)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.focus_mode = Control.FOCUS_NONE
		var icoon_id: String = String(iconen[i]) if i < iconen.size() else ""
		var tex: Texture2D = UiAssets.icoon(icoon_id) if icoon_id != "" else null
		if tex != null:
			# Het thema tint het icoon inkt (icon_normal_color van KnopBreed).
			button.icon = tex
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.expand_icon = false
			button.add_theme_constant_override("icon_max_width", KNOP_ICOON)
		var idx := i
		button.pressed.connect(func() -> void: _pick(idx))
		# Hover-geluid alleen met een echte muis: op de telefoon komt een tik als
		# nagebootste muis binnen, en dan klonk elke tik dubbel.
		button.mouse_entered.connect(func() -> void:
			if Beweging.echte_muis():
				Audio.play("ui_hover"))
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
