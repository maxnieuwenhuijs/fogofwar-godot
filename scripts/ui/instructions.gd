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
	title.text = "Speluitleg"
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
	close.text = "Sluiten"
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
		{"title": "Het spel", "text": _tab_game()},
		{"title": "Beurten", "text": _tab_turns()},
		{"title": "Eenheden", "text": _tab_units()},
		{"title": "Vechten", "text": _tab_combat()},
		{"title": "Facties", "text": _tab_factions()},
	]


func _tab_game() -> String:
	return "\n".join([
		"[b]Wat is Fog of War?[/b]",
		"Twee legers staan tegenover elkaar op een bord van 11×11 vakken. Jij bent rood, de AI is blauw.",
		"",
		"[b]Zo win je[/b]",
		"• Zet [b]2 van je pionnen[/b] op de haven aan de overkant (de gekleurde randvakken), óf",
		"• versla [b]alle[/b] vijandelijke pionnen.",
		"",
		"[b]Het belangrijkste idee[/b]",
		"Je pionnen kunnen pas iets als ze een [b]kaart[/b] hebben. Een pion zonder kaart \"slaapt\": hij kan niks en gaat dood aan één klap of één schot.",
		"",
		"Elke pion heeft een vast type dat je aan het model herkent: de soldaat (met geweer), het beest (de grote broer, kop groter dan de rest) en het kanon (met wielen). De kaart bepaalt hoe sterk hij deze ronde is; het type bepaalt wat hij kán.",
		"",
		"[b]Boven elke actieve pion[/b] zie je blokjes: groen = leven (HP), blauw = energie (Speed), oranje = aanvalskracht.",
		"",
		"[b]Opstellen[/b]",
		"Vóór de slag zet je je leger neer op je twee eigen rijen: eerst je kanonnen, dan je beesten (klik een vak; rechtermuis = ongedaan). De soldaten vullen de rest automatisch aan. Liever snel? Kies de standaard-opstelling.",
	])


func _tab_turns() -> String:
	return "\n".join([
		"[b]Het spel gaat in cycli. Elke cyclus:[/b]",
		"",
		"[b]1. Kaarten maken[/b] (3 rondes)",
		"Je verdeelt punten over HP / Speed / Aanval. De som is altijd je budget (Varken: 7).",
		"",
		"[b]2. Laten zien[/b]",
		"Beide spelers tonen hun kaarten. Wie het meest op Aanval heeft ingezet (het hoogste \"bod\") krijgt het [b]initiatief[/b]: die mag eerst koppelen en straks eerst slaan.",
		"",
		"[b]3. Koppelen[/b]",
		"Om de beurt leg je een kaart op een eigen pion. Die pion wordt wakker met de stats van de kaart.",
		"",
		"[b]4. Vechten (actiefase)[/b]",
		"Om de beurt doe je [b]één actie[/b] met één pion. Speed is de energie van je pion:",
		"• een stap lopen kost 1",
		"• slaan of schieten kost 1",
		"• charge (beest) kost stappen + 1",
		"Een pion mag later in de cyclus wéér, zolang hij energie heeft.",
		"",
		"[b]5. Nieuwe cyclus[/b]",
		"Kan niemand meer iets doen? Dan vervallen alle kaarten en begint alles opnieuw — met de pionnen die nog leven, op de plek waar ze staan.",
		"",
		"[b]Beurt-timer[/b]",
		"Je hebt 20 seconden per beslissing (zie de teller bovenin). Tijd om? Dan kiest het spel voor je: standaard-opstelling, kaarten bevestigd, automatisch gekoppeld, of een verstandige zet in het gevecht. De timer pauzeert als je deze uitleg leest.",
	])


func _tab_units() -> String:
	return "\n".join([
		"[b]Soldaat (infanterie)[/b]",
		"• Loopt zo ver als zijn energie reikt.",
		"• Slaat een vijand op het vak ernaast.",
		"• Of schiet op [b]precies 2 vakken[/b] afstand (schade = je volle Aanval).",
		"• Sterk in de verdediging: wie hem slaat en niet doodt, krijgt zelf −1.",
		"",
		"[b]Beest (cavalerie)[/b]",
		"• [b]Charge[/b]: lopen én slaan in één beurt — klik gewoon een rode vijand aan, ook verderop.",
		"• Springt over je [b]eigen[/b] pionnen heen.",
		"• Doodt hij zijn doelwit, dan schuift hij het vrije vak in: zo wint hij terrein.",
		"• Kan nooit schieten, en terugslaan doet hij hard: −2 voor wie hem prikt en niet afmaakt.",
		"",
		"[b]Kanon (artillerie)[/b]",
		"• Doet [b]1 ding per beurt[/b]: 1 stap lopen óf 1 schot.",
		"• Schiet tot [b]6 vakken[/b] ver in een rechte lijn (Leeuw: 7) met volle Aanval-schade.",
		"• Kan [b]nooit[/b] het vak ernaast raken (dode zone) en niet slaan — kom dichtbij en hij is weerloos.",
		"• Speed = hoe vaak hij per cyclus iets mag doen.",
	])


func _tab_combat() -> String:
	return "\n".join([
		"[b]De kleuren op het bord[/b]",
		"• [color=#55dd66]Groen[/color] = daar kun je lopen (het cijfer = energie-kosten)",
		"• [color=#f04545]Rood[/color] = die vijand kun je slaan (of charge met het beest)",
		"• [color=#ffb054]Oranje[/color] = die vijand kun je beschieten (vaag oranje = je vuurlijn)",
		"• [color=#66dddd]Cyaan[/color] = gratis Wolf-stap na een melee",
		"",
		"[b]Slaan (melee)[/b]",
		"Je doet je volle Aanval als schade. Gaat het doelwit dood, dan MOET je het vrije vak in — zo ruk je op.",
		"",
		"[b]Terugslag[/b]",
		"Overleeft de verdediger jouw klap, dan slaat hij terug:",
		"• soldaat: [b]−1[/b]    • beest: [b]−2[/b]    • kanon: [b]−0[/b] (weerloos)",
		"Slapende pionnen slaan nooit terug. Schieten krijgt nooit terugslag.",
		"",
		"[b]Schieten[/b]",
		"• Raakt alles in een vrije rechte lijn — ook slapende pionnen (die gaan meteen dood).",
		"• Maar: [b]elke[/b] pion ertussen blokkeert het schot, ook je eigen.",
		"• Schieten verovert nooit een vak; alleen lopen en slaan winnen terrein.",
		"",
		"[b]Tip[/b]: rechtermuisklik = pion deselecteren.",
		"[b]Toetsen[/b]: K = schermtrilling aan/uit · J = alle klap-effecten aan/uit · M = geluid dempen.",
	])


func _tab_factions() -> String:
	var lines: Array = [
		"[b]Kies vóór de partij een factie (doctrine). Die bepaalt je leger en je speciale kracht.[/b]",
		"Samenstelling = soldaten / beesten / kanonnen.",
		"",
	]
	for doctrine in Constants.DOCTRINE_DATA.keys():
		var d: Dictionary = Constants.doctrine_data(doctrine)
		lines.append("[b]%s[/b] — %d kaarten × budget %d · leger %d/%d/%d" % [
			d.name, int(d.cards), int(d.budget), d.comp[0], d.comp[1], d.comp[2]])
		lines.append("[color=#7fdd7f]✚ %s[/color]" % d.pro)
		lines.append("[color=#ee8877]✖ %s[/color]" % d.con)
		lines.append("")
	lines.append("[b]Balans-driehoek[/b]: kanonnen > soldaten (dracht), soldaten > beesten (terugslag −1 en goedkoop), beesten > kanonnen (dode zone induiken en slaan).")
	return "\n".join(lines)
