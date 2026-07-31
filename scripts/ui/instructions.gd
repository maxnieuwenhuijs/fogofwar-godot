class_name InstructionsScreen
extends Control

## In-game speluitleg met tabbladen, in simpele taal. Overal te openen via de
## "?"-knop (game.gd) of de "Speluitleg"-knoppen in de menu's.

signal closed

var _back: Callable = Callable()
var _body: RichTextLabel
var _tab_buttons: Array = []
var _tabs: Array = []  # [{title, text}]

const PANEL_BG := Color(0.13, 0.15, 0.21, 1.0)
const PANEL_BORDER := Color(0.42, 0.48, 0.66, 0.85)
const TAB_ACTIVE := Color(0.32, 0.42, 0.62)
const TAB_IDLE := Color(0.19, 0.22, 0.3)


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.content_margin_left = 34.0
	style.content_margin_right = 34.0
	style.content_margin_top = 26.0
	style.content_margin_bottom = 26.0
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(1000, 1560)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = tr("HELP_TITLE")
	title.add_theme_font_size_override("font_size", 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_build_tab_content()

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(tab_row)
	for i in _tabs.size():
		var b := Button.new()
		b.text = _tabs[i].title
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_size_override("font_size", 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		b.pressed.connect(func() -> void:
			Audio.play("ui_toggle")
			_select_tab(idx))
		tab_row.add_child(b)
		_tab_buttons.append(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 27)
	_body.add_theme_font_size_override("bold_font_size", 28)
	_body.add_theme_color_override("default_color", Color(0.85, 0.88, 0.94))
	scroll.add_child(_body)

	var close := Button.new()
	close.text = tr("HELP_CLOSE")
	close.custom_minimum_size = Vector2(320, 62)
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
	for i in _tab_buttons.size():
		var b: Button = _tab_buttons[i]
		var style := StyleBoxFlat.new()
		style.bg_color = TAB_ACTIVE if i == index else TAB_IDLE
		style.set_corner_radius_all(10)
		style.content_margin_left = 12.0
		style.content_margin_right = 12.0
		b.add_theme_stylebox_override("normal", style)
	_body.text = _tabs[index].text


func _build_tab_content() -> void:
	_tabs = [
		{"title": tr("HELP_TAB_GAME_TITLE"), "text": _tab_game()},
		{"title": tr("HELP_TAB_TURNS_TITLE"), "text": _tab_turns()},
		{"title": tr("HELP_TAB_UNITS_TITLE"), "text": _tab_units()},
		{"title": tr("HELP_TAB_COMBAT_TITLE"), "text": _tab_combat()},
		{"title": tr("HELP_TAB_FACTIONS_TITLE"), "text": _tab_factions()},
	]


func _tab_game() -> String:
	return "\n".join([
		tr("HELP_GAME_WHAT_TITLE"),
		tr("HELP_GAME_WHAT_BODY"),
		"",
		tr("HELP_GAME_WIN_TITLE"),
		tr("HELP_GAME_WIN_1"),
		tr("HELP_GAME_WIN_2"),
		"",
		tr("HELP_GAME_IDEA_TITLE"),
		tr("HELP_GAME_IDEA_BODY"),
		"",
		tr("HELP_GAME_TYPES_BODY"),
		"",
		tr("HELP_GAME_BARS_BODY"),
		"",
		tr("HELP_GAME_SETUP_TITLE"),
		tr("HELP_GAME_SETUP_BODY"),
		tr("HELP_GAME_SETUP_ROLES"),
	])


func _tab_turns() -> String:
	return "\n".join([
		tr("HELP_TURNS_INTRO"),
		"",
		tr("HELP_TURNS_CARDS_TITLE"),
		tr("HELP_TURNS_CARDS_BODY"),
		"",
		tr("HELP_TURNS_REVEAL_TITLE"),
		tr("HELP_TURNS_REVEAL_BODY"),
		"",
		tr("HELP_TURNS_LINK_TITLE"),
		tr("HELP_TURNS_LINK_BODY"),
		"",
		tr("HELP_TURNS_FIGHT_TITLE"),
		tr("HELP_TURNS_FIGHT_BODY"),
		tr("HELP_TURNS_FIGHT_COST_1"),
		tr("HELP_TURNS_FIGHT_COST_2"),
		tr("HELP_TURNS_FIGHT_COST_3"),
		tr("HELP_TURNS_FIGHT_AGAIN"),
		"",
		tr("HELP_TURNS_NEWCYCLE_TITLE"),
		tr("HELP_TURNS_NEWCYCLE_BODY"),
		"",
		tr("HELP_TURNS_TIMER_TITLE"),
		tr("HELP_TURNS_TIMER_BODY"),
	])


func _tab_units() -> String:
	return "\n".join([
		tr("HELP_UNITS_INF_TITLE"),
		tr("HELP_UNITS_INF_1"),
		tr("HELP_UNITS_INF_2"),
		tr("HELP_UNITS_INF_3"),
		tr("HELP_UNITS_INF_4"),
		"",
		tr("HELP_UNITS_CAV_TITLE"),
		tr("HELP_UNITS_CAV_1"),
		tr("HELP_UNITS_CAV_2"),
		tr("HELP_UNITS_CAV_3"),
		tr("HELP_UNITS_CAV_4"),
		"",
		tr("HELP_UNITS_ART_TITLE"),
		tr("HELP_UNITS_ART_1"),
		tr("HELP_UNITS_ART_2"),
		tr("HELP_UNITS_ART_3"),
		tr("HELP_UNITS_ART_4"),
	])


func _tab_combat() -> String:
	return "\n".join([
		tr("HELP_COMBAT_COLORS_TITLE"),
		tr("HELP_COMBAT_COLORS_1"),
		tr("HELP_COMBAT_COLORS_2"),
		tr("HELP_COMBAT_COLORS_3"),
		tr("HELP_COMBAT_COLORS_4"),
		"",
		tr("HELP_COMBAT_MELEE_TITLE"),
		tr("HELP_COMBAT_MELEE_BODY"),
		"",
		tr("HELP_COMBAT_RETAL_TITLE"),
		tr("HELP_COMBAT_RETAL_BODY"),
		tr("HELP_COMBAT_RETAL_VALUES"),
		tr("HELP_COMBAT_RETAL_NOTE"),
		"",
		tr("HELP_COMBAT_SHOOT_TITLE"),
		tr("HELP_COMBAT_SHOOT_1"),
		tr("HELP_COMBAT_SHOOT_2"),
		tr("HELP_COMBAT_SHOOT_3"),
		"",
		"",
		tr("HELP_COMBAT_LOOT_TITLE"),
		tr("HELP_COMBAT_LOOT_1"),
		tr("HELP_COMBAT_LOOT_2"),
		tr("HELP_COMBAT_LOOT_3"),
		"",
		tr("HELP_COMBAT_TIP"),
		tr("HELP_COMBAT_KEYS"),
	])


func _tab_factions() -> String:
	var lines: Array = [
		tr("HELP_FACTIONS_INTRO"),
		tr("HELP_FACTIONS_COMP"),
		"",
	]
	for doctrine in Constants.DOCTRINE_DATA.keys():
		var d: Dictionary = Constants.doctrine_data(doctrine)
		lines.append(tr("HELP_FACTIONS_ROW") % [
			Constants.doctrine_display_name(doctrine), int(d.cards), int(d.budget), d.comp[0], d.comp[1], d.comp[2]])
		lines.append("[color=#7fdd7f]✚ %s[/color]" % Constants.doctrine_pro(doctrine))
		lines.append("[color=#ee8877]✖ %s[/color]" % Constants.doctrine_con(doctrine))
		lines.append("")
	lines.append(tr("HELP_FACTIONS_TRIANGLE"))
	return "\n".join(lines)
