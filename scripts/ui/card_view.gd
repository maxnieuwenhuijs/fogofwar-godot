class_name CardView
extends Control

## Een speelkaart op het ontwerp van de UI-assetpack (pdf pagina 3): het
## 645x989-frame met naamplaat, lauwerkrans plus factie-embleem, sierlijn,
## factienaam, drie stat-kolommen (HP / SPEED / ATTACK) en het CP-zegel.
## De kaart tekent op ware grootte (UiAssets.KAART_MAAT); CardHand schaalt
## hem naar de halve maat (322x494) en verder omlaag als er veel kaarten zijn.
##
## Alle onderdelen worden in _ready uit UiAssets gebouwd; de tscn bevat alleen
## de wortel. De unieke namen (%Title, %HpValue, %HpPlus, ..., %TapArea) worden
## in code geregistreerd zodat capture.gd en de tests ze blijven vinden.
##
## Staten (via de setters; de kaart leidt het beeld zelf af in _update_staat):
##   EDITABLE   set_editable(true): een grote plus per stat (besluit Max, 3 september:
##              geen min-knop; plussen haalt het punt bij de grootste andere stat weg)
##   SELECTABLE set_selectable(true) en niet gekoppeld: los lint in teamkleur
##   SELECTED   set_selected_visual(true): lint plus gouden rand en gloed,
##              de kaart 4% groter (op de binnenlaag, de hand houdt de schaal)
##   LINKED     set_linked(true): lint met kettingzegel, kaart gedimd, tikken uit
##   REVEALED   set_onthuld(true): de "REVEALED"-stempel rechtsonder
##   BACK       set_verborgen(true): de kaartrug over alles heen (blind, D12)
##
## De +/- herverdeling (_adjust_stat en de drie hulpjes) is UI-logica die
## capture "carddist" meet; die staat letterlijk zoals hij was.

signal stats_changed
signal tapped(card: CardView)

@export var card_index: int = 0

# Maten van de losse onderdelen in frame-pixels (de png's in het pack).
const NAAMPLAAT_MAAT := Vector2(273, 94)
const KRANS_MAAT := Vector2(283, 266)
const SIERLIJN_MAAT := Vector2(295, 24)
## De stat-kolom (16 september, Max: "het cijfer-ding mag wat langer en
## ietsje smaller, want nu vallen de hokjes er net buiten"): een 9-patch
## van Card_specs_holder.png op eigen maat, niet meer de plaat op 1,14.
## Drie kolommen van 170 met 12 ertussen = 534, binnen het kaartframe
## (de lijst loopt tot x 47 en vanaf 599).
## 17 september: de min-knop is terug, en (Max, later die dag) "het plusje
## weer boven het getal en het minnetje eronder, zelfde grootte knoppen":
## plus 72 op 144, cijfer (88, regelhoogte ~117) vanaf 218, min 72 op 340;
## kolom 420 hoog (onderkant 772), de CP-zegel begint op 778.
const KOLOM_MAAT := Vector2(170, 420)
const SPECS_NAAM_MAAT := Vector2(154, 44)
const SPECS_LIJN_MAAT := Vector2(152, 17)
const CP_MAAT := Vector2(318, 339)
const ONTHULD_MAAT := Vector2(210, 63)
const LINT_MAAT := Vector2(72, 247)
const GEKOPPELD_MAAT := Vector2(187, 247)
const KNOP_MAAT := Vector2(72, 72)   # plus en min even groot
const STAT_ICOON := 64.0
const KOLOM_NAAM_GROOTTE := 24       # HP / STAMINA / ATTACK (Max: "mag kleiner")
# Plaatsing binnen een stat-kolom (contract par. 4). Het icoon staat sinds
# 16 september ruim boven het cijfer (Max: "geef de icon meer ruimte").
const KOLOM_NAAM_Y := 6.0
const KOLOM_ICOON_Y := 54.0
const KOLOM_LIJN_Y := 124.0
const KOLOM_KNOP_Y := 144.0      # de plus, boven het cijfer
const KOLOM_CIJFER_Y := 218.0
const KOLOM_CIJFER_HOOGTE := 118.0   # een Label groeit toch tot zijn regelhoogte (~117 bij 88)
const KOLOM_CIJFER_GROOTTE := 88
const KOLOM_MIN_Y := 340.0       # de min, onder het cijfer
# Selectie en koppeling.
const GESELECTEERD_SCHAAL := 1.04
const GEKOPPELD_DIM := 0.72
const GLOED_RAND := 8.0

var data: CardData = CardData.new()
var _editable: bool = true
var _selected: bool = false
var _selectable: bool = false
var _onthuld: bool = false
var _verborgen: bool = false
var _cp_inzet: bool = false
var _speler_id: int = Constants.PLAYER_1
var _doctrine: int = Constants.Doctrine.MENS
var _kaart_aantal: int = 0
var _gebouwd: bool = false

# Nodes (in _bouw gemaakt).
var _inhoud: Control
var _gloed: Panel
var _kaartlaag: Control
var _title: Label
var _factie_label: Label
var _embleem: TextureRect
var _hp_value: Label
var _sta_value: Label
var _atk_value: Label
var _stat_namen: Array[Label] = []
# De vaste factie-bonus per stat (16 september, Max: "bij het definieren per
# factie al duidelijk op de kaart wat de +1 is, bijv muis stamina heeft al
# +1"): een klein goudkleurig "+1" naast het cijfer. Alleen wat voor ELKE pion
# geldt (Beer +1 HP, Muis +1 Speed); de cavalerie-bonus van de Wolf en de
# ondergrenzen per type hangen van de pion af en staan er niet op.
var _bonus: Array = [0, 0, 0]
var _bonus_labels: Array[Label] = []
var _cp_zegel: TextureRect
var _cp_zegel_2: TextureRect   # tweede laag bij inzet: de plaat is half doorzichtig, twee lagen dekken
var _cp_tekst: Label
var _onthuld_rect: TextureRect
var _lint: TextureRect
var _gekoppeld: TextureRect
var _rug: TextureRect
var _tap_area: Button
var _buttons: Array[Button] = []
var _staat_klaar: bool = false   # UI-beweging: de eerste opbouw animeert nooit

## UI-beweging (30 september): microinteracties op de kaart (scripts/ui/ui_beweging.gd).
## Nooit de root van de kaart, Kaartlaag.modulate, CpZegel modulate/size of de
## statkolommen: die meten -- define en -- sleepcheck.
const Beweging := preload("res://scripts/ui/ui_beweging.gd")


func _ready() -> void:
	custom_minimum_size = UiAssets.KAART_MAAT
	size = UiAssets.KAART_MAAT
	pivot_offset = UiAssets.KAART_MAAT * 0.5
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Thema-overerving loopt alleen via Control/Window-ouders; het spel-UI hangt
	# onder een CanvasLayer en een losse kaart (maak) kan overal staan. Het
	# thema van UiThema hier zelf opleggen kost niets (gedeelde resource).
	if theme == null:
		theme = UiAssets.thema()
	_bouw()
	_pas_team_toe()
	_pas_doctrine_toe()
	_refresh()
	_staat_klaar = true


## Losse weergavekaart (onthulscherm, rapporten): niet bewerkbaar, het
## CP-zegel aan als de stats boven het budget uitkomen (de blinde CP-inzet).
## load() in plaats van preload: de scene verwijst naar dit script.
static func maak(hp: int, stamina: int, attack: int, speler_id: int, doctrine: int, budget: int) -> CardView:
	var scene: PackedScene = load("res://scenes/ui/card_view.tscn")
	var kaart: CardView = scene.instantiate()
	kaart.data.hp = hp
	kaart.data.stamina = stamina
	kaart.data.attack = attack
	kaart.data.budget = budget
	kaart.set_editable(false)
	kaart.set_speler(speler_id)
	kaart.set_doctrine(doctrine)
	kaart.set_cp_inzet(hp + stamina + attack > budget)
	return kaart


# --- Publieke API ---------------------------------------------------------------

func set_editable(enabled: bool) -> void:
	_editable = enabled
	_refresh()


func set_selectable(enabled: bool) -> void:
	_selectable = enabled
	_update_staat()


func set_selected_visual(selected: bool) -> void:
	_selected = selected
	_update_staat()


func set_linked(linked: bool) -> void:
	data.is_linked = linked
	if linked:
		_selected = false
	_refresh()


## Teamkleur van lint, zegels, stempel en rug (rood = speler 1, blauw = 2).
func set_speler(speler_id: int) -> void:
	_speler_id = speler_id
	_pas_team_toe()
	_update_staat()


## Factie van de eigenaar: embleem in de krans en de naam als titel.
func set_doctrine(doctrine: int) -> void:
	_doctrine = doctrine
	_pas_doctrine_toe()
	_refresh()


## Aantal kaarten per ronde (bewaard voor wie het wil tonen; de kaart zelf
## heeft sinds 3 september geen ondertitel meer).
## De vaste factie-bonus per stat (hp, speed, attack), getoond als "+n".
func set_bonus(hp: int, stamina: int, attack: int) -> void:
	_bonus = [hp, stamina, attack]
	_refresh()


func set_kaart_aantal(aantal: int) -> void:
	_kaart_aantal = aantal


## Blinde CP-inzet op deze kaart: het zegel in teamkleur met "CP" erop.
func set_cp_inzet(aan: bool) -> void:
	_cp_inzet = aan
	_update_staat()


## UI-beweging: het CP-zegel stempelt op de kaart (bij het uitdelen, als hij
## landt). Alleen schaal en draai, dus alpha en maat blijven wat -- define cp meet.
func stempel_cp(vertraging: float = 0.0) -> void:
	if _cp_inzet:
		Beweging.stempel(_cp_zegel, vertraging, true)


## UI-beweging: de REVEALED-stempel valt (na het omdraaien op het onthulscherm);
## zijn rust (schaal 0,85 en schuin) blijft.
func stempel_onthuld(vertraging: float = 0.0) -> void:
	if _onthuld_rect != null and _onthuld_rect.visible:
		Beweging.stempel(_onthuld_rect, vertraging)


## De REVEALED-stempel.
func set_onthuld(aan: bool) -> void:
	_onthuld = aan
	_update_staat()


## Kaartrug over alles heen (blinde kaart van de tegenstander).
func set_verborgen(aan: bool) -> void:
	_verborgen = aan
	_update_staat()


func _refresh() -> void:
	if not _gebouwd:
		return
	_title.text = _tekst("CARD_TITLE", [card_index + 1]).to_upper()
	_factie_label.text = Constants.doctrine_display_name(_doctrine).to_upper()
	_hp_value.text = str(data.hp)
	_sta_value.text = str(data.stamina)
	_atk_value.text = str(data.attack)
	var sleutels := ["CARD_STAT_HP", "CARD_STAT_SPEED", "CARD_STAT_ATTACK"]
	for i in _stat_namen.size():
		_stat_namen[i].text = tr(sleutels[i]).to_upper()
	for i in _bonus_labels.size():
		var b: int = int(_bonus[i]) if i < _bonus.size() else 0
		_bonus_labels[i].text = "+%d" % b
		_bonus_labels[i].visible = b > 0
	_cp_tekst.text = tr("CARD_CP_SEAL")
	_update_staat()


# --- Opbouw -----------------------------------------------------------------------

func _bouw() -> void:
	var maat := UiAssets.KAART_MAAT
	# Binnenlaag: schaalt 4% bij selectie, zonder de schaal van de hand te raken.
	_inhoud = _control("Inhoud", Vector2.ZERO, maat)
	_inhoud.pivot_offset = maat * 0.5
	add_child(_inhoud)
	# Gouden rand plus gloed ACHTER de kaart (SELECTED).
	_gloed = Panel.new()
	_gloed.name = "Gloed"
	_gloed.position = Vector2(-GLOED_RAND, -GLOED_RAND)
	_gloed.size = maat + Vector2(GLOED_RAND, GLOED_RAND) * 2.0
	_gloed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gloed_stijl := StyleBoxFlat.new()
	gloed_stijl.bg_color = Color(0, 0, 0, 0)
	gloed_stijl.border_color = UiAssets.SELECTIE_GOUD
	gloed_stijl.set_border_width_all(6)
	gloed_stijl.set_corner_radius_all(28)
	gloed_stijl.shadow_color = Color(UiAssets.SELECTIE_GOUD, 0.55)
	gloed_stijl.shadow_size = 22
	_gloed.add_theme_stylebox_override("panel", gloed_stijl)
	_gloed.visible = false
	_inhoud.add_child(_gloed)
	# De kaart zelf (deze laag dimt bij koppeling).
	_kaartlaag = _control("Kaartlaag", Vector2.ZERO, maat)
	_inhoud.add_child(_kaartlaag)
	_kaartlaag.add_child(_rect("Frame", UiAssets.kaart("frame"), Vector2.ZERO, maat))
	# Naamplaat met "KAART n".
	var naamplaat := _rect("Naamplaat", UiAssets.kaart("naamplaat"),
		Vector2((maat.x - NAAMPLAAT_MAAT.x) * 0.5, UiAssets.KAART_NAAMPLAAT_Y), NAAMPLAAT_MAAT)
	_kaartlaag.add_child(naamplaat)
	_title = _label("Title", "LabelKopInkt", 40, Vector2.ZERO, NAAMPLAAT_MAAT)
	naamplaat.add_child(_title)
	_uniek(_title)
	# Lauwerkrans (zwart) met het embleem van de eigenaar in de opening.
	var krans_maat := KRANS_MAAT * UiAssets.KAART_KRANS_SCHAAL
	var krans := _rect("Krans", UiAssets.kaart("krans"),
		Vector2((maat.x - krans_maat.x) * 0.5, UiAssets.KAART_KRANS_Y), krans_maat)
	_kaartlaag.add_child(krans)
	_embleem = _rect("Embleem", null, Vector2(krans_maat.x * 0.16, krans_maat.y * 0.03),
		Vector2(krans_maat.x * 0.68, krans_maat.y * 0.75))
	krans.add_child(_embleem)
	# Factienaam met de sierlijn eronder (pdf: naam, dan de lijn, dan de kolommen).
	# Geen ondertitel: op 9 px was hij onleesbaar en de HUD zegt het budget al.
	_kaartlaag.add_child(_rect("Sierlijn", UiAssets.kaart("sierlijn"),
		Vector2((maat.x - SIERLIJN_MAAT.x) * 0.5, UiAssets.KAART_SIERLIJN_Y), SIERLIJN_MAAT))
	_factie_label = _label("Titel", "LabelKopInkt", 48, Vector2(0, UiAssets.KAART_TITEL_Y), Vector2(maat.x, 60))
	_kaartlaag.add_child(_factie_label)
	# Drie stat-kolommen: HP links, SPEED midden, ATTACK rechts.
	# drie kolommen op eigen maat, gecentreerd op de kaart
	var kolom_b: float = KOLOM_MAAT.x
	var links: float = (maat.x - (3.0 * kolom_b + 2.0 * UiAssets.KAART_KOLOM_TUSSEN)) * 0.5
	var hp := _bouw_kolom("Hp", "stat-hp", links)
	var sta := _bouw_kolom("Sta", "stat-speed", links + kolom_b + UiAssets.KAART_KOLOM_TUSSEN)
	var atk := _bouw_kolom("Atk", "stat-attack", links + 2.0 * (kolom_b + UiAssets.KAART_KOLOM_TUSSEN))
	_hp_value = hp.waarde
	_sta_value = sta.waarde
	_atk_value = atk.waarde
	_stat_namen = [hp.naam, sta.naam, atk.naam]
	_buttons = [hp.plus, sta.plus, atk.plus, hp.min, sta.min, atk.min]
	(hp.plus as Button).pressed.connect(_on_hp_plus_pressed)
	(sta.plus as Button).pressed.connect(_on_sta_plus_pressed)
	(atk.plus as Button).pressed.connect(_on_atk_plus_pressed)
	(hp.min as Button).pressed.connect(_on_hp_minus_pressed)
	(sta.min as Button).pressed.connect(_on_sta_minus_pressed)
	(atk.min as Button).pressed.connect(_on_atk_minus_pressed)
	# CP-zegel: leeg een vage grijze afdruk, met inzet het teamzegel dubbel
	# (dekkend), iets groter en met een grote "CP" (17 september; maat en
	# plaat wisselen in _update_staat).
	var cp_maat := CP_MAAT * UiAssets.KAART_CP_SCHAAL
	_cp_zegel = _rect("CpZegel", UiAssets.kaart("cp_leeg"), UiAssets.KAART_CP_MIDDEN - cp_maat * 0.5, cp_maat)
	_kaartlaag.add_child(_cp_zegel)
	_cp_zegel_2 = _rect("CpZegel2", null, Vector2.ZERO, cp_maat)
	_cp_zegel_2.visible = false
	_cp_zegel.add_child(_cp_zegel_2)
	_cp_tekst = _label("CpTekst", "LabelKop", UiAssets.KAART_CP_TEKST, Vector2.ZERO, cp_maat)
	_cp_tekst.add_theme_color_override("font_outline_color", Color(UiAssets.INKT, 0.85))
	_cp_tekst.add_theme_constant_override("outline_size", 8)
	_cp_tekst.visible = false
	_cp_zegel.add_child(_cp_tekst)
	# REVEALED-stempel, schuin rechtsonder.
	_onthuld_rect = _rect("Onthuld", null, UiAssets.KAART_ONTHULD_POS, ONTHULD_MAAT)
	_onthuld_rect.pivot_offset = ONTHULD_MAAT * 0.5
	_onthuld_rect.scale = Vector2.ONE * UiAssets.KAART_ONTHULD_SCHAAL
	_onthuld_rect.rotation_degrees = UiAssets.KAART_ONTHULD_HOEK_GRADEN
	_onthuld_rect.visible = false
	_kaartlaag.add_child(_onthuld_rect)
	# Linten (boven de kaartlaag, dimmen niet mee).
	_lint = _rect("Lint", null, Vector2(UiAssets.KAART_LINT_X, 0.0), LINT_MAAT)
	_lint.visible = false
	_inhoud.add_child(_lint)
	_gekoppeld = _rect("Gekoppeld", null, Vector2(UiAssets.KAART_GEKOPPELD_X, 0.0), GEKOPPELD_MAAT)
	_gekoppeld.visible = false
	_inhoud.add_child(_gekoppeld)
	# Tikvlak over de hele kaart; het thema tekent hem niet (lege styleboxes).
	_tap_area = Button.new()
	_tap_area.name = "TapArea"
	_tap_area.flat = true
	_tap_area.focus_mode = Control.FOCUS_NONE
	_tap_area.position = Vector2.ZERO
	_tap_area.size = maat
	for staat in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		_tap_area.add_theme_stylebox_override(staat, StyleBoxEmpty.new())
	_tap_area.visible = false
	_tap_area.pressed.connect(func() -> void: tapped.emit(self))
	# UI-beweging: het tikvlak doet niet mee met indrukken (de kaart heeft zijn
	# eigen lift, en een krimpend tikvlak mist tikken op de rand).
	_tap_area.set_meta("ub_uit", true)
	_inhoud.add_child(_tap_area)
	_uniek(_tap_area)
	# Kaartrug: over alles heen.
	_rug = _rect("Rug", null, Vector2.ZERO, maat)
	_rug.visible = false
	_inhoud.add_child(_rug)
	_gebouwd = true


## Een stat-kolom: lijst, naamplaatje, icoon, sierlijn, groot cijfer en EEN grote
## plus onderaan (besluit Max, 3 september: geen min; de min-functies blijven
## voor de tools). Geeft {waarde, naam, plus} terug.
func _bouw_kolom(voorvoegsel: String, icoon_id: String, x: float) -> Dictionary:
	# 9-patch (randen 16 px) in plaats van een geschaalde plaat: zo kan de
	# kolom smaller en langer zonder dat de getekende lijst vervormt.
	var kolom := Panel.new()
	kolom.name = voorvoegsel + "Kolom"
	kolom.position = Vector2(x, UiAssets.KAART_SPECS_Y)
	kolom.size = KOLOM_MAAT
	kolom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kolom_stijl: StyleBox = UiAssets.paneel_stijl("specs")
	if kolom_stijl != null:
		kolom.add_theme_stylebox_override("panel", kolom_stijl)
	_kaartlaag.add_child(kolom)
	var naam := _rect("Naam", UiAssets.kaart("specs_naam"),
		Vector2((KOLOM_MAAT.x - SPECS_NAAM_MAAT.x) * 0.5, KOLOM_NAAM_Y), SPECS_NAAM_MAAT)
	kolom.add_child(naam)
	var naam_label := _label("NaamTekst", "", KOLOM_NAAM_GROOTTE, Vector2.ZERO, SPECS_NAAM_MAAT)  # standaard Label = ivoor
	naam.add_child(naam_label)
	var icoon := UiAssets.icoon_rect(icoon_id, STAT_ICOON, UiAssets.INKT)
	icoon.name = "Icoon"
	icoon.position = Vector2((KOLOM_MAAT.x - STAT_ICOON) * 0.5, KOLOM_ICOON_Y)
	icoon.size = Vector2(STAT_ICOON, STAT_ICOON)
	kolom.add_child(icoon)
	kolom.add_child(_rect("Lijn", UiAssets.kaart("specs_sierlijn"),
		Vector2((KOLOM_MAAT.x - SPECS_LIJN_MAAT.x) * 0.5, KOLOM_LIJN_Y), SPECS_LIJN_MAAT))
	var waarde := _label(voorvoegsel + "Value", "LabelCijfer", KOLOM_CIJFER_GROOTTE,
		Vector2(0, KOLOM_CIJFER_Y), Vector2(KOLOM_MAAT.x, KOLOM_CIJFER_HOOGTE))
	kolom.add_child(waarde)
	_uniek(waarde)
	var plus_knop := _knop(voorvoegsel + "Plus", "KnopPlus",
		Vector2((KOLOM_MAAT.x - KNOP_MAAT.x) * 0.5, KOLOM_KNOP_Y))
	kolom.add_child(plus_knop)
	_uniek(plus_knop)
	# De min: even groot, onder het cijfer (17 september). Geeft het punt aan
	# de kleinste andere stat (_adjust_stat, delta -1).
	var min_knop := _knop(voorvoegsel + "Minus", "KnopMin",
		Vector2((KOLOM_MAAT.x - KNOP_MAAT.x) * 0.5, KOLOM_MIN_Y))
	kolom.add_child(min_knop)
	_uniek(min_knop)
	# de factie-bonus: klein en goud, rechtsboven naast het cijfer
	var bonus := _label(voorvoegsel + "Bonus", "LabelCijfer", 34,
		Vector2(KOLOM_MAAT.x * 0.5 + 34.0, KOLOM_CIJFER_Y - 4.0), Vector2(56, 40))
	bonus.add_theme_color_override("font_color", UiAssets.SELECTIE_GOUD)
	bonus.add_theme_color_override("font_outline_color", Color(UiAssets.INKT, 0.9))
	bonus.add_theme_constant_override("outline_size", 6)
	bonus.visible = false
	kolom.add_child(bonus)
	_bonus_labels.append(bonus)
	return {"waarde": waarde, "naam": naam_label, "plus": plus_knop, "min": min_knop}


func _control(naam: String, pos: Vector2, maat: Vector2) -> Control:
	var c := Control.new()
	c.name = naam
	c.position = pos
	c.size = maat
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _rect(naam: String, tex: Texture2D, pos: Vector2, maat: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.name = naam
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = pos
	r.size = maat
	return r


func _label(naam: String, variant: String, grootte: int, pos: Vector2, maat: Vector2) -> Label:
	var l := Label.new()
	l.name = naam
	if variant != "":
		l.theme_type_variation = variant
	l.add_theme_font_size_override("font_size", grootte)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = pos
	l.size = maat
	return l


func _knop(naam: String, variant: String, pos: Vector2, maat: Vector2 = KNOP_MAAT) -> Button:
	var b := Button.new()
	b.name = naam
	b.theme_type_variation = variant
	b.text = ""
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = maat
	b.position = pos
	b.size = maat
	return b


## Registreert een in code gemaakte node als %-naam van deze kaart.
func _uniek(node: Node) -> void:
	node.owner = self
	node.unique_name_in_owner = true


## tr() met argumenten; voor de centrale --import toont tr() de sleutel zelf
## (zonder %-plekken), dan wordt er niet geformatteerd.
func _tekst(sleutel: String, args: Array) -> String:
	var s := tr(sleutel)
	if s.find("%") == -1:
		return s
	return s % args


# --- Beeld ---------------------------------------------------------------------------

func _pas_team_toe() -> void:
	if not _gebouwd:
		return
	var team := UiAssets.team_naam(_speler_id)
	_lint.texture = UiAssets.kaart("lint_" + team)
	_gekoppeld.texture = UiAssets.kaart("gekoppeld_" + team)
	_onthuld_rect.texture = UiAssets.kaart("onthuld_" + team)
	_rug.texture = UiAssets.kaart("rug_1" if _speler_id == Constants.PLAYER_1 else "rug_2")


func _pas_doctrine_toe() -> void:
	if not _gebouwd:
		return
	_embleem.texture = UiAssets.embleem(_doctrine)


## Leidt het hele beeld af uit de vlaggen (de enige plek die zichtbaarheid zet).
func _update_staat() -> void:
	if not _gebouwd:
		return
	var gekoppeld := data.is_linked
	var open := not _verborgen
	for button in _buttons:
		button.visible = _editable and open
	_lint.visible = _selectable and not gekoppeld and open
	_gekoppeld.visible = gekoppeld and open
	var gloed_was: bool = _gloed.visible
	_gloed.visible = _selected and not gekoppeld and open
	# UI-beweging: kiezen veert (1,0 naar 1,04 met een veertje), de gouden rand
	# faadt in; de eerste opbouw zet het meteen.
	var inhoud_doel := Vector2.ONE * (GESELECTEERD_SCHAAL if _gloed.visible else 1.0)
	if _staat_klaar:
		Beweging.naar_schaal(_inhoud, inhoud_doel)
		if _gloed.visible and not gloed_was:
			Beweging.fade_in(_gloed, 0.0, 0.12)
	else:
		_inhoud.scale = inhoud_doel
	_kaartlaag.modulate = Color(GEKOPPELD_DIM, GEKOPPELD_DIM, GEKOPPELD_DIM) if gekoppeld else Color.WHITE
	_tap_area.visible = _selectable and not gekoppeld and open
	_onthuld_rect.visible = _onthuld and open
	_rug.visible = _verborgen
	var cp_maat: Vector2 = CP_MAAT * (UiAssets.KAART_CP_SCHAAL_INZET if _cp_inzet else UiAssets.KAART_CP_SCHAAL)
	_cp_zegel.size = cp_maat
	_cp_zegel.position = UiAssets.KAART_CP_MIDDEN - cp_maat * 0.5
	_cp_zegel_2.size = cp_maat
	_cp_tekst.size = cp_maat
	if _cp_inzet:
		var cp_tex: Texture2D = UiAssets.kaart("cp_" + UiAssets.team_naam(_speler_id))
		_cp_zegel.texture = cp_tex
		_cp_zegel_2.texture = cp_tex
		_cp_zegel.modulate = Color.WHITE
	else:
		_cp_zegel.texture = UiAssets.kaart("cp_leeg")
		_cp_zegel_2.texture = null
		# Bijna de kleur van de kaart: een vage afdruk, geen stempel.
		_cp_zegel.modulate = Color(1.0, 1.0, 1.0, UiAssets.KAART_CP_LEEG_ALPHA)
	_cp_zegel_2.visible = _cp_inzet
	_cp_tekst.visible = _cp_inzet


# --- +/- (ongewijzigd; capture "carddist" meet dit) --------------------------------

func _on_hp_plus_pressed() -> void:
	_adjust_stat(&"hp", 1)


func _on_hp_minus_pressed() -> void:
	_adjust_stat(&"hp", -1)


func _on_sta_plus_pressed() -> void:
	_adjust_stat(&"stamina", 1)


func _on_sta_minus_pressed() -> void:
	_adjust_stat(&"stamina", -1)


func _on_atk_plus_pressed() -> void:
	_adjust_stat(&"attack", 1)


func _on_atk_minus_pressed() -> void:
	_adjust_stat(&"attack", -1)


func _adjust_stat(field: StringName, delta: int) -> void:
	if not _editable:
		return
	var changed := false
	var ander: StringName = &""   # UI-beweging: waar het punt vandaan kwam of heen ging
	if delta > 0:
		# +stat: haal een punt weg bij de grootste andere stat (>1).
		var donor := _biggest_other(field, 1)
		ander = donor
		var cap: int = data.budget - 2 * Constants.MIN_STAT
		# Beer: stamina-limiet bij definitie (knop heet nog speed_max).
		if field == &"stamina" and data.speed_max > 0:
			cap = mini(cap, data.speed_max)
		if donor != &"" and int(data.get(field)) < cap:
			data.set(field, int(data.get(field)) + 1)
			data.set(donor, int(data.get(donor)) - 1)
			changed = true
	else:
		# -stat: geef het punt aan de kleinste andere stat (die nog mag groeien).
		if int(data.get(field)) > Constants.MIN_STAT:
			var receiver := _smallest_other(field)
			if receiver == &"stamina" and data.speed_max > 0 and data.stamina >= data.speed_max:
				receiver = &"hp" if field != &"hp" else &"attack"
			data.set(field, int(data.get(field)) - 1)
			data.set(receiver, int(data.get(receiver)) + 1)
			ander = receiver
			changed = true
	if changed:
		Audio.play("card_stat_up" if delta > 0 else "card_stat_down")
		_refresh()
		stats_changed.emit()
		# UI-beweging: het getal dat erbij krijgt springt op, de gever zakt even.
		Beweging.punch(_waarde_label(field if delta > 0 else ander))
		Beweging.dip(_waarde_label(ander if delta > 0 else field))
	else:
		# Kan niet (ondergrens of plafond): de knop schudt nee.
		var i := _stat_index(field)
		if i >= 0 and i + (0 if delta > 0 else 3) < _buttons.size():
			Beweging.schud(_buttons[i + (0 if delta > 0 else 3)])


func _waarde_label(field: StringName) -> Label:
	match field:
		&"hp":
			return _hp_value
		&"stamina":
			return _sta_value
		&"attack":
			return _atk_value
	return null


func _stat_index(field: StringName) -> int:
	match field:
		&"hp":
			return 0
		&"stamina":
			return 1
		&"attack":
			return 2
	return -1


func _other_fields(field: StringName) -> Array:
	var fields: Array = [&"hp", &"stamina", &"attack"]
	fields.erase(field)
	return fields


## Grootste andere stat met waarde > min_value; &"" als geen.
func _biggest_other(field: StringName, min_value: int) -> StringName:
	var best := &""
	var best_val := min_value
	for other in _other_fields(field):
		var v := int(data.get(other))
		if v > best_val:
			best_val = v
			best = other
	return best


func _smallest_other(field: StringName) -> StringName:
	var others := _other_fields(field)
	var best: StringName = others[0]
	for other in others:
		if int(data.get(other)) < int(data.get(best)):
			best = other
	return best
