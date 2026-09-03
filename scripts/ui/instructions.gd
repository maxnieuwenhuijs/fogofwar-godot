class_name InstructionsScreen
extends Control

## In-game speluitleg met tabbladen, in simpele taal. Overal te openen via de
## "?"-knop (game.gd) of de "Speluitleg"-knoppen in de menu's.
##
## Sinds de UI-assetpack (september 2026) is het een papieren lijst (Frame_3,
## PaneelPapier) op een gedimd bord: inkt op perkament, de tabs als kleine
## perkamentknoppen, en de iconen van het pack in de tekst ([img]-tags) zodat
## de speler ze hier leert kennen voordat hij ze op de HUD en de kaarten
## tegenkomt. De tekst zelf komt onveranderd uit de HELP_*-sleutels; dit
## bestand voegt alleen iconen en opmaak toe in de compositie-functies.

signal closed

## Icoonmaat in de lopende tekst, van een kop-icoon en van een embleem.
const ICOON_PX := 48
const KOP_ICOON_PX := 56
const EMBLEEM_PX := 96
const PANEEL_MAAT := Vector2(1000, 1600)
const OPSOMMINGSTEKEN := "• "

var _back: Callable = Callable()
var _body: RichTextLabel
var _scroll: ScrollContainer
var _tab_buttons: Array = []
var _tab_groep: ButtonGroup
var _tabs: Array = []  # [{title, text}]


func _ready() -> void:
	visible = false
	# Het thema van het pack expliciet op deze root: het venster-thema van de
	# autoload UiThema reikt niet door een gewone Node of CanvasLayer heen
	# (Godot geeft een thema alleen door via Control/Window-ouders), en dit
	# scherm hangt in game.gd onder $UI.
	theme = UiAssets.thema()
	# Let op: set_anchors_preset() alleen zou de huidige (lege) rect bewaren.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Iconen en emblemen worden van 500 px naar 48-96 px getekend: mipmaps.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "PaneelPapier"
	panel.theme_type_variation = "PaneelPapier"
	panel.custom_minimum_size = PANEEL_MAAT
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# Titel: het "?"-zegel (hidden) in inkt naast de kop.
	var titel_rij := HBoxContainer.new()
	titel_rij.alignment = BoxContainer.ALIGNMENT_CENTER
	titel_rij.add_theme_constant_override("separation", 14)
	vbox.add_child(titel_rij)
	var zegel := UiAssets.icoon_rect("hidden", 56, UiAssets.INKT)
	zegel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titel_rij.add_child(zegel)
	var title := Label.new()
	title.name = "Titel"
	title.theme_type_variation = "LabelKopInkt"
	title.text = tr("HELP_TITLE")
	title.add_theme_font_size_override("font_size", 42)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titel_rij.add_child(title)

	_build_tab_content()

	# Tabbladen: kleine brede perkamentknoppen in een groep; de actieve staat
	# ingedrukt (toggle) en toont daarmee vanzelf de _pressed-texture.
	_tab_groep = ButtonGroup.new()
	var tab_row := HBoxContainer.new()
	tab_row.name = "Tabs"
	tab_row.add_theme_constant_override("separation", 8)
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(tab_row)
	for i in _tabs.size():
		var b := Button.new()
		b.name = "Tab_%d" % i
		b.theme_type_variation = "KnopKleinBreed"
		b.text = _tabs[i].title
		b.toggle_mode = true
		b.button_group = _tab_groep
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		b.pressed.connect(func() -> void:
			Audio.play("ui_toggle")
			_select_tab(idx))
		tab_row.add_child(b)
		_tab_buttons.append(b)

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_body = RichTextLabel.new()
	_body.name = "Body"
	_body.theme_type_variation = "RichInkt"
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 26)
	_body.add_theme_font_size_override("bold_font_size", 27)
	_body.add_theme_constant_override("table_h_separation", 18)
	_body.add_theme_constant_override("line_separation", 4)
	_scroll.add_child(_body)

	var close := Button.new()
	close.name = "Sluit"
	close.theme_type_variation = "KnopBreed"
	close.text = tr("HELP_CLOSE")
	close.custom_minimum_size = Vector2(460, 96)
	close.add_theme_font_size_override("font_size", 28)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close)
	vbox.add_child(close)


## Open het scherm. back = optioneel: wordt na sluiten aangeroepen
## (bv. om het menu waar je vandaan kwam terug te tonen).
func open(back: Callable = Callable()) -> void:
	_back = back
	Audio.play("ui_open")
	visible = true
	move_to_front()
	_select_tab(0)


func _close() -> void:
	Audio.play("ui_back")
	visible = false
	closed.emit()
	if _back.is_valid():
		var cb := _back
		_back = Callable()
		cb.call()


func _select_tab(index: int) -> void:
	if index < 0 or index >= _tabs.size():
		return
	for i in _tab_buttons.size():
		var b: Button = _tab_buttons[i]
		b.button_pressed = (i == index)
	_body.text = _tabs[index].text
	if _scroll != null:
		_scroll.scroll_vertical = 0


func _build_tab_content() -> void:
	_tabs = [
		{"title": tr("HELP_TAB_GAME_TITLE"), "text": _tab_game()},
		{"title": tr("HELP_TAB_TURNS_TITLE"), "text": _tab_turns()},
		{"title": tr("HELP_TAB_UNITS_TITLE"), "text": _tab_units()},
		{"title": tr("HELP_TAB_COMBAT_TITLE"), "text": _tab_combat()},
		{"title": tr("HELP_TAB_FACTIONS_TITLE"), "text": _tab_factions()},
	]


# --- BBCode-bouwstenen ---------------------------------------------------------

## [img]-tag voor een pack-icoon, ingekleurd in inkt; "" als het icoon niet
## geleverd is (dan valt de regel terug op tekst zonder icoon).
static func _img(id: String, grootte: int = ICOON_PX) -> String:
	var tex := UiAssets.icoon(id)
	if tex == null:
		return ""
	return "[img=%d color=#%s]%s[/img]" % [grootte, UiAssets.INKT.to_html(false), tex.resource_path]


## Meerdere iconen naast elkaar, gescheiden door een spatie.
static func _imgs(ids: Array, grootte: int = ICOON_PX) -> String:
	var delen: Array = []
	for id in ids:
		var tag := _img(String(id), grootte)
		if tag != "":
			delen.append(tag)
	return " ".join(delen)


## Tekstregel met icoon(en) vooraan. Het icoon neemt de plaats van het
## opsommingsteken in; zonder icoon blijft het teken gewoon staan.
static func _regel(ids: Array, tekst: String, grootte: int = ICOON_PX) -> String:
	var tags := _imgs(ids, grootte)
	if tags == "":
		return tekst
	return tags + " " + tekst.trim_prefix(OPSOMMINGSTEKEN)


## Kopregel met icoon(en) vooraan; de titel houdt zijn eigen opmaak.
static func _kop(ids: Array, tekst: String, grootte: int = KOP_ICOON_PX) -> String:
	var tags := _imgs(ids, grootte)
	if tags == "":
		return tekst
	return tags + " " + tekst


## Alinea met icoon(en) vooraan (de tekst loopt er direct achter door).
static func _alinea(ids: Array, tekst: String, grootte: int = ICOON_PX) -> String:
	return _kop(ids, tekst, grootte)


## De bordkleuren in de HELP-tekst (groen/rood/oranje/cyaan van de vakken)
## zijn gekozen voor een donkere achtergrond; op perkament worden ze zo ver
## verdonkerd dat het woord leesbaar blijft en de tint herkenbaar is. De
## tekst zelf verandert niet, alleen de kleurwaarde in de [color]-tag.
static func _kleur_op_perkament(tekst: String) -> String:
	var re := RegEx.new()
	re.compile("\\[color=#([0-9a-fA-F]{6})\\]")
	var uit := tekst
	for m in re.search_all(tekst):
		var kleur := Color("#" + m.get_string(1)).darkened(0.5)
		uit = uit.replace(m.get_string(0), "[color=#%s]" % kleur.to_html(false))
	return uit


# --- Tabbladen ------------------------------------------------------------------

func _tab_game() -> String:
	return "\n".join([
		tr("HELP_GAME_WHAT_TITLE"),
		tr("HELP_GAME_WHAT_BODY"),
		"",
		tr("HELP_GAME_WIN_TITLE"),
		_regel(["win-harbor"], tr("HELP_GAME_WIN_1")),
		_regel(["dead"], tr("HELP_GAME_WIN_2")),
		"",
		tr("HELP_GAME_IDEA_TITLE"),
		tr("HELP_GAME_IDEA_BODY"),
		"",
		_alinea(["unit-infantry", "unit-cavalry", "unit-artillery"], tr("HELP_GAME_TYPES_BODY")),
		"",
		_alinea(["stat-hp", "stat-speed", "stat-attack"], tr("HELP_GAME_BARS_BODY")),
		"",
		tr("HELP_GAME_SETUP_TITLE"),
		tr("HELP_GAME_SETUP_BODY"),
		tr("HELP_GAME_SETUP_ROLES"),
	])


func _tab_turns() -> String:
	return "\n".join([
		tr("HELP_TURNS_INTRO"),
		"",
		_kop(["phase-define"], tr("HELP_TURNS_CARDS_TITLE")),
		tr("HELP_TURNS_CARDS_BODY"),
		"",
		_kop(["phase-reveal"], tr("HELP_TURNS_REVEAL_TITLE")),
		tr("HELP_TURNS_REVEAL_BODY"),
		"",
		_kop(["phase-link"], tr("HELP_TURNS_LINK_TITLE")),
		tr("HELP_TURNS_LINK_BODY"),
		"",
		_kop(["act-melee"], tr("HELP_TURNS_FIGHT_TITLE")),
		tr("HELP_TURNS_FIGHT_BODY"),
		_regel(["act-move"], tr("HELP_TURNS_FIGHT_COST_1")),
		_regel(["act-melee", "act-shot"], tr("HELP_TURNS_FIGHT_COST_2")),
		_regel(["act-charge"], tr("HELP_TURNS_FIGHT_COST_3")),
		tr("HELP_TURNS_FIGHT_AGAIN"),
		"",
		_kop(["spawn"], tr("HELP_TURNS_NEWCYCLE_TITLE")),
		tr("HELP_TURNS_NEWCYCLE_BODY"),
		"",
		# Klok: geen icoon in het pack (NOG_NIET_GELEVERD), dus alleen tekst.
		tr("HELP_TURNS_TIMER_TITLE"),
		tr("HELP_TURNS_TIMER_BODY"),
	])


func _tab_units() -> String:
	return "\n".join([
		_kop(["unit-infantry"], tr("HELP_UNITS_INF_TITLE"), 64),
		tr("HELP_UNITS_INF_1"),
		tr("HELP_UNITS_INF_2"),
		tr("HELP_UNITS_INF_3"),
		tr("HELP_UNITS_INF_4"),
		"",
		_kop(["unit-cavalry"], tr("HELP_UNITS_CAV_TITLE"), 64),
		tr("HELP_UNITS_CAV_1"),
		tr("HELP_UNITS_CAV_2"),
		tr("HELP_UNITS_CAV_3"),
		tr("HELP_UNITS_CAV_4"),
		"",
		_kop(["unit-artillery"], tr("HELP_UNITS_ART_TITLE"), 64),
		# Het kanon kent twee acties: rollen of vuren (RETREAT bestaat niet, D9).
		_regel(["act-roll", "act-fire"], tr("HELP_UNITS_ART_1")),
		_regel(["act-fire"], tr("HELP_UNITS_ART_2")),
		tr("HELP_UNITS_ART_3"),
		tr("HELP_UNITS_ART_4"),
	])


func _tab_combat() -> String:
	return "\n".join([
		tr("HELP_COMBAT_COLORS_TITLE"),
		_regel(["act-move"], _kleur_op_perkament(tr("HELP_COMBAT_COLORS_1"))),
		_regel(["act-melee"], _kleur_op_perkament(tr("HELP_COMBAT_COLORS_2"))),
		_regel(["act-shot"], _kleur_op_perkament(tr("HELP_COMBAT_COLORS_3"))),
		_regel(["act-wolfstep"], _kleur_op_perkament(tr("HELP_COMBAT_COLORS_4"))),
		"",
		_kop(["act-melee"], tr("HELP_COMBAT_MELEE_TITLE")),
		tr("HELP_COMBAT_MELEE_BODY"),
		"",
		tr("HELP_COMBAT_RETAL_TITLE"),
		tr("HELP_COMBAT_RETAL_BODY"),
		tr("HELP_COMBAT_RETAL_VALUES"),
		tr("HELP_COMBAT_RETAL_NOTE"),
		"",
		_kop(["act-shot", "act-fire"], tr("HELP_COMBAT_SHOOT_TITLE")),
		tr("HELP_COMBAT_SHOOT_1"),
		tr("HELP_COMBAT_SHOOT_2"),
		tr("HELP_COMBAT_SHOOT_3"),
		"",
		# Buit: versterkingspunten (pool) en CP, dezelfde iconen als op de HUD.
		_kop(["pool", "cp"], tr("HELP_COMBAT_LOOT_TITLE")),
		tr("HELP_COMBAT_LOOT_1"),
		tr("HELP_COMBAT_LOOT_2"),
		tr("HELP_COMBAT_LOOT_3"),
		"",
		tr("HELP_COMBAT_TIP"),
		tr("HELP_COMBAT_KEYS"),
	])


## Een factie: embleem (gravure) links, rechts de regel met kaarten x budget
## en leger, en daaronder pro ("+", inkt) en con ("-", oud bruin).
func _factie_blok(doctrine: int, d: Dictionary) -> String:
	var rij: String = tr("HELP_FACTIONS_ROW") % [
		Constants.doctrine_display_name(doctrine), int(d.cards), int(d.budget), d.comp[0], d.comp[1], d.comp[2]]
	var pro := "+ " + Constants.doctrine_pro(doctrine)
	var con := "[color=#%s]- %s[/color]" % [UiAssets.OUD_BRUIN.to_html(false), Constants.doctrine_con(doctrine)]
	var tekst := "\n".join([rij, pro, con])
	var embleem := UiAssets.embleem(doctrine)
	if embleem == null:
		return tekst
	return "[table=2][cell][img=%d]%s[/img][/cell][cell]%s[/cell][/table]" % [
		EMBLEEM_PX, embleem.resource_path, tekst]


func _tab_factions() -> String:
	var lines: Array = [
		tr("HELP_FACTIONS_INTRO"),
		tr("HELP_FACTIONS_COMP"),
		"",
	]
	# De ACTIEVE tabel, niet de kale uit Constants: anders belooft het
	# help-scherm een leger dat je niet krijgt (C19, 8 augustus).
	var tabel := CRules.actieve_tabel()
	for doctrine in Constants.DOCTRINE_DATA.keys():
		lines.append(_factie_blok(doctrine, tabel.doctrine_data(doctrine)))
		lines.append("")
	lines.append(tr("HELP_FACTIONS_TRIANGLE"))
	return "\n".join(lines)
