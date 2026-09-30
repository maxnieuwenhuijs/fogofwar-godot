class_name OnthulScherm
extends Control

## Het onthulscherm van het bord (pdf pagina 3, de REVEALED-staat): na de
## definitiefase liggen beide handen open op de veldtafel. Bovenaan de hand
## van de tegenstander, onderaan die van de mens, elke kaart als echte
## CardView met de "REVEALED"-stempel; per rij een kopregel met portret,
## naam en het bod (bod %, aanval, speed). Daaronder de uitleg en de
## doorgaan-knop. Vervangt de tekst-overlay van _on_cards_revealed (game.gd).
##
## game.gd maakt hem lazy (ONTHUL_SCHERM_SCRIPT.new(), via preload zodat het
## parst zonder klassencache) en hangt hem aan $UI direct boven de overlay:
##
##   _onthul_scherm.open(session.state, t1, t2, winnaar, _human_id, _player_name,
##       func(_i: int) -> void: _continue_after_reveal(), session)
##
## Informatie (D12): alleen state.cards_revealed (na de onthulling openbaar
## voor beide kanten) en de doorgegeven totalen t1/t2 (de rekenuitkomst van
## Rules.compute_initiative); niets uit cards_defined, geen CP-saldi. Het
## CP-zegel op een kaart volgt uit de openbare stats (som boven het budget),
## niet uit een saldo.
##
## De sessie is optioneel: is hij meegegeven, dan verbergt het scherm zich
## zodra de onthulfase voorbij is (de capture-modi en de nulmeting bevestigen
## buiten de knop om via game._continue_after_reveal).

const NAAM := "OnthulScherm"
const PANEEL_BREEDTE := 1040.0
const DIM_ALPHA := 0.62
const KOLOM_TUSSEN := 14
const HANDEN_TUSSEN := 18
## Kaarten: dezelfde schaal voor beide rijen, zo groot als de breedste hand
## toelaat (vijf Muis-kaarten naast elkaar = ~0,28 van het 645-frame).
const KAART_TUSSEN := 8.0
const KAART_SCHAAL_MIN := 0.2
const KAART_SCHAAL_MAX := 0.4
const KOP_ICOON := 64.0
const TITEL_FONT := 40
const PORTRET := 48.0
const NAAM_FONT := 26
const WINNAAR_ICOON := 32.0
const BOD_FONT := 22
const BOD_AFSTAND := 14
const UITLEG_FONT := 22
const KNOP_MAAT := Vector2(560, 96)
const KNOP_FONT := 28
const KNOP_ICOON := 48

var _titel: Label
var _handen: VBoxContainer
var _uitleg: Label
var _knop: Button
var _cb: Callable = Callable()
var _sessie: Object = null
var _dim: ColorRect = null
var _midden: CenterContainer = null

## UI-beweging (30 september): inkom en omdraaien (scripts/ui/ui_beweging.gd).
const Beweging := preload("res://scripts/ui/ui_beweging.gd")


func _init() -> void:
	name = NAAM
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Onder de CanvasLayer van het bord komt het venster-thema niet vanzelf
	# aan (alleen via Control/Window-ouders); zelf opleggen kost niets.
	if theme == null:
		theme = UiAssets.thema()
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, DIM_ALPHA)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_dim = dim
	var midden := CenterContainer.new()
	midden.name = "Midden"
	midden.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	midden.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(midden)
	_midden = midden
	var paneel := PanelContainer.new()
	paneel.name = "Paneel"
	paneel.theme_type_variation = "PaneelVeldtafel"
	paneel.custom_minimum_size = Vector2(PANEEL_BREEDTE, 0)
	midden.add_child(paneel)
	var kolom := VBoxContainer.new()
	kolom.name = "Kolom"
	kolom.add_theme_constant_override("separation", KOLOM_TUSSEN)
	paneel.add_child(kolom)
	# Kop: het initiatief-icoon (inkt) met de titel in de teamkleur van de winnaar.
	var kop_houder := CenterContainer.new()
	kop_houder.name = "KopIcoon"
	kop_houder.add_child(UiAssets.icoon_rect("initiative", KOP_ICOON, UiAssets.INKT))
	kolom.add_child(kop_houder)
	_titel = Label.new()
	_titel.name = "Titel"
	_titel.theme_type_variation = "LabelKopInkt"
	_titel.add_theme_font_size_override("font_size", TITEL_FONT)
	_titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kolom.add_child(_titel)
	# De twee handen (gevuld in open, per onthulling opnieuw).
	_handen = VBoxContainer.new()
	_handen.name = "Handen"
	_handen.add_theme_constant_override("separation", HANDEN_TUSSEN)
	kolom.add_child(_handen)
	_uitleg = Label.new()
	_uitleg.name = "Uitleg"
	_uitleg.theme_type_variation = "LabelInkt"
	_uitleg.add_theme_font_size_override("font_size", UITLEG_FONT)
	_uitleg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_uitleg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kolom.add_child(_uitleg)
	_knop = Button.new()
	_knop.name = "Doorgaan"
	_knop.theme_type_variation = "KnopBreed"
	_knop.custom_minimum_size = KNOP_MAAT
	_knop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_knop.add_theme_font_size_override("font_size", KNOP_FONT)
	_knop.focus_mode = Control.FOCUS_NONE
	var vinkje := UiAssets.icoon("check")
	if vinkje != null:
		# Het thema tint het icoon inkt (icon_normal_color van KnopBreed).
		_knop.icon = vinkje
		_knop.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_knop.expand_icon = false
		_knop.add_theme_constant_override("icon_max_width", KNOP_ICOON)
	_knop.pressed.connect(_op_doorgaan)
	kolom.add_child(_knop)


## Toon de onthulling. t1/t2 = de totalen van speler 1 en 2 (met "bid",
## "attack", "stamina"), naam_van(speler_id) -> String (game._player_name),
## cb.call(0) bij doorgaan. sessie: optioneel, om mee te verbergen zodra de
## onthulfase buiten de knop om voorbij is.
func open(state: GameState, t1: Dictionary, t2: Dictionary, initiative_winner: int, mens_id: int,
		naam_van: Callable, cb: Callable, sessie: Object = null) -> void:
	_cb = cb
	_volg_sessie(sessie)
	var tegenstander: int = Constants.PLAYER_1 if mens_id == Constants.PLAYER_2 else Constants.PLAYER_2
	_titel.text = _tekst("PHASE_REVEAL_TITLE", [String(naam_van.call(initiative_winner))])
	_titel.add_theme_color_override("font_color", UiAssets.team_kleur(initiative_winner))
	_uitleg.text = tr("REVEAL_UI_UITLEG")
	_knop.text = tr("MENU_CONTINUE")
	# Vorige onthulling opruimen (het scherm gaat elke ronde opnieuw open).
	for kind in _handen.get_children():
		_handen.remove_child(kind)
		kind.queue_free()
	var boven: Array = state.cards_revealed.get(tegenstander, [])
	var onder: Array = state.cards_revealed.get(mens_id, [])
	var schaal := _kaart_schaal(maxi(boven.size(), onder.size()))
	var hand_boven := _bouw_hand(state, tegenstander, boven, _totalen(t1, t2, tegenstander),
		initiative_winner == tegenstander, naam_van, schaal)
	var hand_onder := _bouw_hand(state, mens_id, onder, _totalen(t1, t2, mens_id),
		initiative_winner == mens_id, naam_van, schaal)
	_handen.add_child(hand_boven)
	_handen.add_child(hand_onder)
	var vers := not visible
	if not visible:
		Audio.play("ui_open")
	visible = true
	if vers:
		_inkom(hand_boven, hand_onder)


func sluit() -> void:
	visible = false


## UI-beweging: de waas en het paneel komen binnen, de kaarten van de
## tegenstander draaien van rug naar voorkant (een voor een, met de stempel
## erop), die van jou komen in een rij, en het initiatief-icoon en de knop
## ploffen. Alleen beeld: de knop werkt meteen, en geen check kijkt hierin.
func _inkom(hand_boven: Control, hand_onder: Control) -> void:
	if not Beweging.aan():
		return
	Beweging.inkom_scherm(null if Beweging.vervangt() else _dim, _midden)
	var i := 0
	for draai in _draaiers(hand_boven):
		var kaart: CardView = (draai as Control).get_child(0) as CardView
		var v := 0.12 + 0.07 * float(i)
		if Beweging.vol():
			kaart.set_verborgen(true)
		var toon := func() -> void:
			if is_instance_valid(kaart):
				kaart.set_verborgen(false)
				kaart.stempel_onthuld(0.10)
		Beweging.draai_om(draai, toon, v)
		i += 1
	Beweging.inkom_rij(_draaiers(hand_onder), 0.10, 0.05)
	for ster in [hand_boven.find_child("Initiatief", true, false), hand_onder.find_child("Initiatief", true, false)]:
		if ster != null:
			Beweging.plof(ster as Control, 0.30, 0.6, false, Vector2(0.5, 0.5), true)
	Beweging.plof(_knop, 0.35, 0.9, false)


## De draaiers (de houder-wrapper om elke kaart) van een hand, van links naar rechts.
func _draaiers(hand: Control) -> Array:
	var uit: Array = []
	var rij := hand.get_node_or_null("Kaarten")
	if rij == null:
		return uit
	for houder in rij.get_children():
		var draai := (houder as Node).get_node_or_null("Draai")
		if draai != null:
			uit.append(draai)
	return uit


# --- Opbouw per hand ----------------------------------------------------------------

## Een rij: kopregel (portret in teamkleur, naam, initiatief-icoon bij de
## winnaar, het bod) en daaronder de kaarten als echte CardViews.
func _bouw_hand(state: GameState, speler: int, kaarten: Array, totalen: Dictionary,
		winnaar: bool, naam_van: Callable, schaal: float) -> VBoxContainer:
	var doctrine: int = state.doctrine_of(speler)
	var budget: int = int(state.doctrine_data_of(speler).get("budget", Constants.STAT_TOTAL))
	var kleur := UiAssets.team_kleur(speler)
	var hand := VBoxContainer.new()
	hand.name = "Hand%d" % speler
	hand.add_theme_constant_override("separation", 6)
	var kop := HBoxContainer.new()
	kop.name = "Kop"
	kop.alignment = BoxContainer.ALIGNMENT_CENTER
	kop.add_theme_constant_override("separation", 12)
	var portret := UiPortret.new(PORTRET)
	portret.zet(doctrine, UiAssets.team_naam(speler))
	portret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kop.add_child(portret)
	var naam := Label.new()
	naam.name = "Naam"
	naam.theme_type_variation = "LabelKopInkt"
	naam.add_theme_font_size_override("font_size", NAAM_FONT)
	naam.add_theme_color_override("font_color", kleur)
	naam.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	naam.text = String(naam_van.call(speler))
	kop.add_child(naam)
	if winnaar:
		var ster := UiAssets.icoon_rect("initiative", WINNAAR_ICOON, kleur)
		ster.name = "Initiatief"
		ster.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kop.add_child(ster)
	var afstand := Control.new()
	afstand.custom_minimum_size = Vector2(BOD_AFSTAND, 0)
	afstand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kop.add_child(afstand)
	var bod := Label.new()
	bod.name = "Bod"
	bod.theme_type_variation = "LabelInkt"
	bod.add_theme_font_size_override("font_size", BOD_FONT)
	bod.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bod.text = _tekst("REVEAL_UI_BOD", [
		int(round(float(totalen.get("bid", 0.0)) * 100.0)),
		int(totalen.get("attack", 0)), int(totalen.get("stamina", 0))])
	kop.add_child(bod)
	hand.add_child(kop)
	var rij := HBoxContainer.new()
	rij.name = "Kaarten"
	rij.alignment = BoxContainer.ALIGNMENT_CENTER
	rij.add_theme_constant_override("separation", int(KAART_TUSSEN))
	for i in kaarten.size():
		var c: Variant = kaarten[i]  # Card (live) of Dictionary (hersteld)
		rij.add_child(_kaart_houder(int(c.hp), int(c.stamina), int(c.attack), speler, doctrine,
			budget, i, kaarten.size(), schaal))
	hand.add_child(rij)
	return hand


## Een kaart in een Control van de geschaalde maat, zodat de HBox hem netjes
## uitlijnt. De kaart tekent op ware grootte (645x989) met de spil in het
## midden: schalen om die spil en zo verschuiven dat zijn linkerbovenhoek op
## (0,0) van de houder valt.
func _kaart_houder(hp: int, stamina: int, attack: int, speler: int, doctrine: int, budget: int,
		index: int, aantal: int, schaal: float) -> Control:
	var houder := Control.new()
	houder.name = "Kaart%d" % (index + 1)
	houder.custom_minimum_size = UiAssets.KAART_MAAT * schaal
	houder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# UI-beweging: een vrije wrapper om de kaart (de houder staat in een HBox,
	# die zijn schaal zou terugzetten); die draait om bij de onthulling.
	var draai := Control.new()
	draai.name = "Draai"
	draai.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draai.size = UiAssets.KAART_MAAT * schaal
	houder.add_child(draai)
	var kaart := CardView.maak(hp, stamina, attack, speler, doctrine, budget)
	kaart.card_index = index
	kaart.set_kaart_aantal(aantal)
	kaart.set_onthuld(true)
	kaart.scale = Vector2.ONE * schaal
	kaart.position = -UiAssets.KAART_MAAT * 0.5 * (1.0 - schaal)
	draai.add_child(kaart)
	return houder


## Schaal waarmee `aantal` kaarten naast elkaar in het paneel passen (met een
## paar pixels speling: de container rondt de kaarthouders naar boven af).
func _kaart_schaal(aantal: int) -> float:
	var n := maxi(1, aantal)
	var binnen := PANEEL_BREEDTE - _paneel_marge_x() - float(n)
	var beschikbaar := binnen - float(n - 1) * KAART_TUSSEN
	return clampf(beschikbaar / (float(n) * UiAssets.KAART_MAAT.x), KAART_SCHAAL_MIN, KAART_SCHAAL_MAX)


## Inhoudsmarges links plus rechts van de veldtafel-lijst (9-patch).
func _paneel_marge_x() -> float:
	var sb: StyleBox = UiAssets.paneel_stijl("veldtafel")
	if sb == null:
		return 120.0
	return sb.get_content_margin(SIDE_LEFT) + sb.get_content_margin(SIDE_RIGHT)


func _totalen(t1: Dictionary, t2: Dictionary, speler: int) -> Dictionary:
	return t1 if speler == Constants.PLAYER_1 else t2


## tr() met argumenten; voor de centrale --import toont tr() de sleutel zelf
## (zonder %-plekken), dan wordt er niet geformatteerd.
func _tekst(sleutel: String, args: Array) -> String:
	var s := tr(sleutel)
	if s.find("%") == -1:
		return s
	return s % args


# --- Sessie volgen -------------------------------------------------------------------

## Verbergt het scherm zodra de sessie de onthulfase verlaat zonder dat de
## knop is gebruikt (capture-modi, nulmeting, een klok aan de andere kant).
func _volg_sessie(sessie: Object) -> void:
	if sessie == _sessie:
		return
	if _sessie != null and is_instance_valid(_sessie) and _sessie.has_signal("phase_changed") \
			and _sessie.is_connected("phase_changed", _bij_fase):
		_sessie.disconnect("phase_changed", _bij_fase)
	_sessie = sessie
	if _sessie != null and _sessie.has_signal("phase_changed"):
		_sessie.connect("phase_changed", _bij_fase)


func _bij_fase(nieuw: int, _oud: int) -> void:
	if visible and not Phase.is_reveal(nieuw):
		visible = false


func _op_doorgaan() -> void:
	Audio.play("ui_click")
	visible = false
	if _cb.is_valid():
		_cb.call(0)
