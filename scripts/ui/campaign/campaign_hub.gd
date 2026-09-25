class_name CampaignHub
extends Control

# F3.3: de CampagneHub: tijdlijn ("Among Us-gevoel"), eigen saldi en het
# fase-paneel (raad / doneren / testament) in één mobile-first scherm.
# Leest UITSLUITEND de cview + de feed; alle mens-acties gaan via de
# SoloDriver-submits. Bot-werk (incl. duels) draait op een thread zodat de
# UI niet bevriest.
#
# Campaign Hub-ontwerp (23 september 2026, pdf "Campaign_hub" + de map
# Campaign_HUB_UI): een staand frame van 564 x 981 ontwerp-eenheden,
# geschaald naar het scherm (S = breedte / 564). Van boven naar onder: de
# titelbalk met je factievlag, ronde en fase en de knoppen ? en tandwiel; de
# statusbalk (soldaten, ruiters, kanonnen, CP, roem; tik = grootboek); drie
# kolommen: jouw team, de tijdlijn en de vijand, elk lid een rond portret met
# een statusbadge; de tabbladen FASE en CHAT; het fasepaneel (in de raad: je
# vechter, het doelwit, de teamstemmen en STEM); en onderaan de quick chat.
# Alleen presentatie: geen submit, timer of await van de campagne is verplaatst.

var driver: SoloDriver
var mens_id: int = 0

## F3.4: vaste solo-savegame-slot; elke campagne-actie staat direct op schijf.
const SAVE_PAD := "user://campaigns/solo/campagne.jsonl"

var _s: float = 1.0                     # schaal: ontwerp-eenheid -> scherm-pixel
var _frame: Control = null              # het staande frame (BG en alles erop)
var _header: Label                      # "RONDE 3   RAAD"
var _titel: Label
var _vlag: Control
var _status: Dictionary = {}            # sleutel -> Label met het getal
var _team_links: VBoxContainer
var _team_rechts: VBoxContainer
var _tijdlijn: VBoxContainer
var _scroll: ScrollContainer
var _paneel: VBoxContainer
var _tab_fase: Button
var _tab_chat: Button
var _tab: int = 0                        # 0 = fase, 1 = chat
var _thread: Thread
var _bezig: bool = false
var _feed_getoond: int = 0
var _auto_start_idx: int = -1   # duel-idx waarvoor de auto-start-aftel loopt
var _auto_stop_idx: int = -1    # duel-idx waarvoor de mens de auto-start annuleerde
var _duel_start_bezig: bool = false
var _info_label: Label = null
var _keuze_eigen: int = -1      # raad: jouw vechter
var _keuze_vijand: int = -1     # raad: het doelwit
var _chat_wacht: Array = []     # [sleutel, doel] die wacht tot de werk-thread klaar is
var _chat_cache: Array = []     # feed-indexen van het chat-tabblad (alleen buiten het botwerk gelezen)
var _chat_e: Dictionary = {}    # feed-index -> bericht, voor het tabblad tijdens het botwerk
var _qc_label: Label = null
var _qc_knoppen: Array = []     # de drie knoppen in de balk (inhoud per fase)
var _qc_meer: Button = null

## Zoveel nieuwe kaartjes faden bovenaan de tijdlijn in; oudere staan er meteen.
const ONTHUL_MAX := 12

## Wanneer de hub een feed-item voor het eerst zag (unix-tijd), per index.
## Static: overleeft de scene-wissel naar het bord en terug.
static var _feed_tijd: Dictionary = {}
## Hoeveel chatberichten de speler al gezien heeft (voor "CHAT (2)").
static var _chat_gezien: int = 0

## Bot-duels in de hub: "easy": eval-gedreven (bloedig, dus de campagne-
## attritie werkt) én snel (seconden per duel; de hang zat specifiek in
## "medium", dat naar de 3000-stappen-noodstop verdedigt). NIET "l1": de
## haven-rusher wint zonder slachtoffers, waardoor niemand ooit door zijn
## pool zakt en de campagne nooit convergeert (test-bevinding 27 juli).
const BOT_DUEL_AI := "easy"
## Vangnet tegen incidentele grind-duels tussen bots; het mens-duel op het
## echte bord behoudt cycluslimiet 0 (besluit 26 juli).
const BOT_DUEL_HONGER_VANAF := 10

## Duimmaat (contract §1) voor de keuzeschermen buiten het frame.
const KNOP_HOOGTE := 84.0
## Buitenrand van de keuzeschermen.
const RAND := 20.0

## De quick chat (UI-spec 2b.2, intrige-voorstel P1): een gesloten lijst
## zinnen over de raad, de donaties en vertrouwen; geen slagveld-commando's,
## want in de campagne vecht niemand samen op een bord. Per zin het icoon
## ("ui:" = uit het UI-pack) en wie %s is: "" (niemand), "team" (een
## teamgenoot) of "vijand". Antwoorden en toezeggingen van de bots doet de
## SoloDriver (quick_chat).
const QC := {
	"HUB_QC_STUUR_MIJ": ["Inbattle_icon", ""],
	"HUB_QC_STUUR": ["Arrow_icon", "team"],
	"HUB_QC_PAK": ["Nomination_icon", "vijand"],
	"HUB_QC_NODIG": ["Donation_icon", ""],
	"HUB_QC_DONEER": ["Donation_icon", "team"],
	"HUB_QC_BEDANKT": ["WellPlayed_icon", ""],
	"HUB_QC_BLUT": ["Neutral_icon", ""],
	"HUB_QC_SUCCES": ["Active_icon", ""],
	"HUB_QC_GOED_GEVOCHTEN": ["WellPlayed_icon", ""],
	"HUB_QC_NALATEN": ["Testament_icon", ""],
	"HUB_QC_VERTROUW": ["Chat_icon", ""],
	"HUB_QC_VERRADER": ["Dead_icon", ""],
	"HUB_QC_AKKOORD": ["ui:check", ""],
	"HUB_QC_NEE": ["Close_icon", ""],
}
## De groepen in het pop-upvenster.
const QC_GROEPEN := [
	["HUB_QC_GROEP_RAAD", ["HUB_QC_STUUR_MIJ", "HUB_QC_STUUR", "HUB_QC_PAK"]],
	["HUB_QC_GROEP_DONATIE", ["HUB_QC_NODIG", "HUB_QC_DONEER", "HUB_QC_BEDANKT", "HUB_QC_BLUT"]],
	["HUB_QC_GROEP_DUEL", ["HUB_QC_SUCCES", "HUB_QC_GOED_GEVOCHTEN", "HUB_QC_NALATEN"]],
	["HUB_QC_GROEP_ALTIJD", ["HUB_QC_VERTROUW", "HUB_QC_VERRADER", "HUB_QC_AKKOORD", "HUB_QC_NEE"]],
]

func _ready() -> void:
	# Iconen (500 px) en portretten worden fors verkleind: mipmaps voor het
	# hele scherm, de kinderen erven dit. Het thema staat op het venster
	# (autoload UiThema), maar die overerving stopt bij een kale Node als
	# ouder (capture-flow): zelf zetten is dezelfde Theme-resource en kost niets.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	theme = UiAssets.thema()
	if driver == null and CampaignBridge.driver != null \
			and CampaignBridge.driver.c.fase != CState.Fase.KLAAR:
		# F3.4b: terug van het bord (of een andere scene-wissel): zelfde campagne.
		driver = CampaignBridge.driver
		mens_id = driver.mens_id
	if driver == null:
		# Lopende solo-campagne? Dan is dat een KEUZE, geen stille hervatting
		# (besluit Max, 28 juli: "ik word meteen een muis, dat wil ik niet").
		if FileAccess.file_exists(SAVE_PAD):
			var oud_driver := SoloDriver.hervat(SAVE_PAD, mens_id)
			if oud_driver != null and oud_driver.c.fase != CState.Fase.KLAAR \
					and oud_driver.c.rules.ronde1_loting \
					and oud_driver.c.rules.vol_team_start \
					and not oud_driver.c.rules.budget_bonus.is_empty():
				# Geldige, actuele save: laat de speler kiezen.
				_toon_hervat_keuze(oud_driver)
				return
		# Geen (bruikbare) save: nieuwe campagne, eerst je factie kiezen.
		_toon_factie_keuze()
		return
	_start()


# --- Keuzeschermen (voor de hub zelf) ---------------------------------------------

## De veldtafel: het donkere hout waar alle panelen op liggen.
func _veldtafel() -> ColorRect:
	var vlak := ColorRect.new()
	vlak.color = UiAssets.VELDTAFEL
	vlak.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return vlak


## Het hele scherm vullen. set_anchors_preset alleen zou de node op zijn
## minimumgrootte zetten (offsets -1080/-1920) als hij zonder scene-root
## onder een kale Node hangt (capture-flow); anchors EN offsets dus.
func _vul_scherm(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Label met variant uit het thema ("" = ivoor op de veldtafel), fontgrootte en autowrap.
func _tekst(tekst: String, variant: String = "", grootte: int = 0, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = tekst
	if variant != "":
		l.theme_type_variation = variant
	if grootte > 0:
		l.add_theme_font_size_override("font_size", grootte)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Icoon op een knop (wit icoon, het thema tint hem inkt of ivoor).
static func _knop_icoon(b: Button, icoon_id: String, maat: int = 32) -> void:
	if icoon_id == "":
		return
	var tex := UiAssets.icoon(icoon_id)
	if tex == null:
		return
	b.icon = tex
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", maat)


## Een grote duimknop buiten het frame (keuzeschermen). De callable staat
## achteraan zodat een meerregelige lambda het laatste argument is.
func _grote_knop(tekst: String, naam: String, icoon_id: String, actie: Callable) -> Button:
	var b := Button.new()
	b.name = naam
	b.text = tekst
	b.theme_type_variation = "KnopBreed"
	b.custom_minimum_size = Vector2(0, KNOP_HOOGTE)
	b.add_theme_font_size_override("font_size", 22)
	_knop_icoon(b, icoon_id)
	b.pressed.connect(actie)
	return b


## Portret op de VELDTAFEL (keuzeschermen): perkamenten medaillon achter de
## krans, want de inkt-gravure verdwijnt op donker hout.
static func _portret_op_veldtafel(grootte: float, doctrine: int, kant: String, dood: bool) -> Control:
	var houder := Control.new()
	houder.custom_minimum_size = Vector2(grootte, grootte)
	houder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var medaillon := Panel.new()
	medaillon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medaillon.anchor_left = 0.2
	medaillon.anchor_right = 0.8
	medaillon.anchor_top = 0.1
	medaillon.anchor_bottom = 0.8
	var stijl := StyleBoxFlat.new()
	stijl.bg_color = Color(UiAssets.OUD_BRUIN, 0.9) if dood else UiAssets.PERKAMENT_LICHT
	stijl.set_corner_radius_all(int(grootte))
	stijl.set_border_width_all(0)
	medaillon.add_theme_stylebox_override("panel", stijl)
	houder.add_child(medaillon)
	var portret := UiPortret.new(grootte)
	portret.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portret.zet(doctrine, kant, dood)
	houder.add_child(portret)
	return houder


## Kolom met titel + uitleg op de veldtafel (factiekeuze, hervatkeuze).
func _keuze_kolom(achtergrond: Control, naam: String, titel: String, uitleg: String) -> VBoxContainer:
	var kolom := VBoxContainer.new()
	kolom.name = naam
	_vul_scherm(kolom)
	kolom.offset_left = RAND
	kolom.offset_right = -RAND
	kolom.offset_top = 48
	kolom.offset_bottom = -RAND
	kolom.add_theme_constant_override("separation", 16)
	achtergrond.add_child(kolom)
	kolom.add_child(_tekst(titel, "LabelKop", 36))
	kolom.add_child(_tekst(uitleg, "", 22))
	return kolom


## 28 juli (Max): doorgaan of opnieuw: nooit meer stilletjes hervatten.
func _toon_hervat_keuze(oud_driver: SoloDriver) -> void:
	var achtergrond := _veldtafel()
	add_child(achtergrond)
	var mijn: Dictionary = oud_driver.c.spelers.get(oud_driver.mens_id, {})
	var kolom := _keuze_kolom(achtergrond, "HervatKeuze", tr("HUB_RESUME_TITLE"),
		tr("HUB_RESUME_INFO") % [oud_driver.c.ronde,
			Constants.doctrine_display_name(int(mijn.get("doctrine", 0)))])
	var portret := _portret_op_veldtafel(140, int(mijn.get("doctrine", 0)), "blauw", false)
	portret.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	kolom.add_child(portret)
	kolom.add_child(_grote_knop(tr("HUB_RESUME_CONTINUE"), "HervatDoorgaan", "check", func() -> void:
		achtergrond.queue_free()
		driver = oud_driver
		mens_id = driver.mens_id
		_start()))
	kolom.add_child(_grote_knop(tr("HUB_RESUME_NEW"), "HervatNieuw", "phase-setup", func() -> void:
		achtergrond.queue_free()
		if FileAccess.file_exists(SAVE_PAD):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PAD))
		CampaignBridge.driver = null
		CampaignBridge.feed_gezien = 0
		_toon_factie_keuze()))


func _start() -> void:
	driver.duel_ai = BOT_DUEL_AI
	driver.bot_duel_honger_vanaf = BOT_DUEL_HONGER_VANAF
	if CampaignBridge.driver != driver:
		CampaignBridge.feed_gezien = 0  # verse of hervatte campagne: teller opnieuw
		_feed_tijd.clear()
		_chat_gezien = 0
	CampaignBridge.driver = driver
	_bouw_layout()
	get_viewport().size_changed.connect(_herbouw)
	_ververs()
	_werk_door()
	_tik_klok()


## Factiekeuze bij een nieuwe campagne: zes regimentskaarten (UiFactieKaart)
## met portret, kaarten x budget, leger en pro/con. De keuze is definitief
## voor de hele campagne. De kaartdata komt uit de actieve regeltabel (C17).
func _toon_factie_keuze() -> void:
	var achtergrond := _veldtafel()
	add_child(achtergrond)
	var kolom := _keuze_kolom(achtergrond, "FactieKeuze", tr("HUB_FACTION_TITLE"),
		tr("HUB_FACTION_EXPLAIN"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	kolom.add_child(scroll)
	var lijst := VBoxContainer.new()
	lijst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lijst.add_theme_constant_override("separation", 12)
	scroll.add_child(lijst)
	var tabel: RulesConfig = CRules.actieve_tabel()
	for doctrine in Constants.DOCTRINE_DATA:
		var kaart := UiFactieKaart.new(int(doctrine), tabel.doctrine_data(int(doctrine)))
		kaart.name = "Factie_%d" % int(doctrine)
		kaart.pressed.connect(_kies_factie.bind(int(doctrine), achtergrond))
		lijst.add_child(kaart)


func _kies_factie(doctrine: int, keuze_scherm: Control) -> void:
	keuze_scherm.queue_free()
	driver = SoloDriver.new(int(Time.get_unix_time_from_system()) % 900000,
		mens_id, 16, SAVE_PAD, doctrine)
	_start()


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


# --- Het frame ----------------------------------------------------------------------

## Ontwerp-eenheden naar scherm-pixels.
func _u(v: float) -> float:
	return v * _s


func _px(v: float) -> int:
	return int(round(v * _s))


## Een kind op een vaste plek in het frame (ontwerp-eenheden).
func _plaats(kind: Control, x: float, y: float, b: float, h: float, ouder: Control = null) -> Control:
	kind.position = Vector2(_u(x), _u(y))
	kind.size = Vector2(_u(b), _u(h))
	(ouder if ouder != null else _frame).add_child(kind)
	return kind


## Het venster veranderde van maat: het frame opnieuw opbouwen op de nieuwe schaal.
func _herbouw() -> void:
	if _frame == null or not is_inside_tree():
		return
	var oud := _frame
	remove_child(oud)
	oud.queue_free()
	_feed_getoond = 0
	_bouw_layout()
	_ververs()


func _bouw_layout() -> void:
	_vul_scherm(self)
	if get_child_count() == 0:
		add_child(_veldtafel())
	var vp := get_viewport_rect().size
	_s = minf(vp.x / HubAssets.ONTWERP.x, vp.y / HubAssets.ONTWERP.y)
	var hoogte: float = vp.y / _s            # in eenheden; >= 981
	var extra: float = hoogte - HubAssets.ONTWERP.y
	_frame = Control.new()
	_frame.name = "HubFrame"
	_frame.position = Vector2((vp.x - _u(HubAssets.ONTWERP.x)) * 0.5, 0)
	_frame.size = Vector2(_u(HubAssets.ONTWERP.x), vp.y)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_plaats(HubAssets.plaat("bg/BG"), 0, 0, 564, hoogte)
	var kolom_onder: float = 706.0 + extra
	_bouw_kolommen(kolom_onder)
	_bouw_titel()
	_bouw_tabs(kolom_onder + 4)
	var paneel_top: float = kolom_onder + 50
	var paneel_onder: float = 936.0 + extra
	var kader := PanelContainer.new()
	kader.name = "FaseKader"
	kader.add_theme_stylebox_override("panel", HubAssets.patch("frames_box/Phase_chat_frame_VERS2",
		Vector2(34, 34), Vector4(_u(16), _u(12), _u(16), _u(12))))
	_plaats(kader, 0, paneel_top, 564, paneel_onder - paneel_top)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	kader.add_child(scroll)
	_paneel = VBoxContainer.new()
	_paneel.name = "FasePaneel"
	_paneel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paneel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_paneel.add_theme_constant_override("separation", _px(5))
	scroll.add_child(_paneel)
	_bouw_quick_chat(paneel_onder + 2)


## Titelbalk + statusbalk + de factievlag die er overheen hangt.
func _bouw_titel() -> void:
	_plaats(HubAssets.plaat("frames_box/Title_frame"), 0, 0, 564, 78)
	_titel = HubAssets.tekst(tr("HUB_TITLE"), _px(17), HubAssets.INKT, true)
	_titel.name = "Titel"
	_titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plaats(_titel, 120, 12, 324, 30)
	_header = HubAssets.tekst("", _px(9), HubAssets.INKT, true)
	_header.name = "Header"
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plaats(_header, 120, 44, 324, 18)
	var help := _rond_knop("Info_icon", "HelpKnop")
	_plaats(help, 458, 18, 40, 40)
	help.pressed.connect(_toon_help)
	var instel := _rond_knop("Settings_icon", "InstellingenKnop")
	_plaats(instel, 506, 18, 40, 40)
	instel.pressed.connect(_toon_instellingen)
	# Statusbalk: soldaten, ruiters, kanonnen, CP, roem; tik = grootboek.
	var balk := Button.new()
	balk.name = "GrootboekKnop"
	balk.flat = true
	balk.tooltip_text = tr("HUB_STATUS_BAR_TIP")
	balk.focus_mode = Control.FOCUS_NONE
	for staat in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		balk.add_theme_stylebox_override(staat, StyleBoxEmpty.new())
	_plaats(balk, 0, 76, 564, 64)
	var plaat := HubAssets.plaat("frames_box/Status_bar")
	plaat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	balk.add_child(plaat)
	var rij := HBoxContainer.new()
	rij.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rij.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rij.offset_left = _u(110)
	rij.offset_right = -_u(18)
	balk.add_child(rij)
	for spec in [["inf", "Donation_icon", ""], ["cav", "", "unit-cavalry"], ["art", "", "unit-artillery"],
			["cp", "", "cp"], ["roem", "", "score"]]:
		var vak := HBoxContainer.new()
		vak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vak.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vak.alignment = BoxContainer.ALIGNMENT_CENTER
		vak.add_theme_constant_override("separation", _px(6))
		var ic: TextureRect
		if String(spec[1]) != "":
			ic = HubAssets.icoon(String(spec[1]), _u(28), HubAssets.INKT)
		else:
			ic = UiAssets.icoon_rect(String(spec[2]), _u(28), HubAssets.INKT)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vak.add_child(ic)
		var getal := HubAssets.tekst("", _px(15), HubAssets.INKT, true)
		getal.name = "Status_" + String(spec[0])
		getal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		vak.add_child(getal)
		_status[String(spec[0])] = getal
		rij.add_child(vak)
	balk.pressed.connect(_toon_grootboek)
	_vlag = _bouw_vlag()
	_plaats(_vlag, 26, 0, 80, 86)


## De vlag linksboven: het vaandel met de poot (Wolf) of de gravure van je factie.
func _bouw_vlag() -> Control:
	var vlag := Control.new()
	vlag.name = "Vlag"
	vlag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var doek := HubAssets.plaat("frames_box/Flag_frame")
	doek.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vlag.add_child(doek)
	var doctrine: int = int(driver.c.spelers.get(mens_id, {}).get("doctrine", 0))
	var teken: TextureRect
	if doctrine == Constants.Doctrine.WOLF:
		teken = HubAssets.icoon("Flag_icon", 0)
	else:
		teken = TextureRect.new()
		teken.texture = UiAssets.embleem(doctrine)
		teken.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		teken.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		teken.mouse_filter = Control.MOUSE_FILTER_IGNORE
		teken.material = HubAssets.silhouet(HubAssets.IVOOR)
	teken.anchor_left = 0.2
	teken.anchor_right = 0.8
	teken.anchor_top = 0.12
	teken.anchor_bottom = 0.7
	vlag.add_child(teken)
	return vlag


## Ronde knop met een gekleurd icoon (? en tandwiel in de titelbalk).
func _rond_knop(icoon: String, naam: String) -> Button:
	var b := Button.new()
	b.name = naam
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for staat in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(staat, StyleBoxEmpty.new())
	var bol := HubAssets.plaat("team_enemy_holder/Your_enemy_team_holder_status_BG")
	bol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(bol)
	var ic := HubAssets.icoon(icoon, 0)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.anchor_left = 0.2
	ic.anchor_top = 0.2
	ic.anchor_right = 0.8
	ic.anchor_bottom = 0.8
	b.add_child(ic)
	var ring := HubAssets.plaat("team_enemy_holder/Team_holder")
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(ring)
	return b


## De drie kolommen: jouw team (blauw), de tijdlijn en de vijand (rood).
func _bouw_kolommen(onder: float) -> void:
	var top := 144.0
	var h := onder - top
	for spec in [["column/Team_column", 0.0, "TeamLinks", tr("HUB_TEAM_YOURS")],
			["column/Enemy_column", 430.0, "TeamRechts", tr("HUB_COL_ENEMY")]]:
		var achter := PanelContainer.new()
		achter.add_theme_stylebox_override("panel", HubAssets.patch(String(spec[0]), Vector2(24, 60)))
		achter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plaats(achter, float(spec[1]), top, 134, h)
		var kop := HubAssets.tekst(String(spec[3]), _px(9), HubAssets.IVOOR, true)
		kop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_plaats(kop, float(spec[1]), top + 14, 134, 16)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		_plaats(scroll, float(spec[1]) + 6, top + 36, 122, h - 48)
		var lijst := VBoxContainer.new()
		lijst.name = String(spec[2])
		lijst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lijst.add_theme_constant_override("separation", _px(10))
		scroll.add_child(lijst)
		if String(spec[2]) == "TeamLinks":
			_team_links = lijst
		else:
			_team_rechts = lijst
	var tl := PanelContainer.new()
	tl.add_theme_stylebox_override("panel", HubAssets.patch("frames_box/Timeline_frame", Vector2(30, 60)))
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaats(tl, 136, top, 294, h)
	var kop := _kop_met_sierlijn(tr("HUB_TIMELINE"), 9, 44)
	_plaats(kop, 136, top + 12, 294, 18)
	_scroll = ScrollContainer.new()
	_scroll.name = "Tijdlijn"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_plaats(_scroll, 146, top + 36, 274, h - 46)
	_tijdlijn = VBoxContainer.new()
	_tijdlijn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tijdlijn.add_theme_constant_override("separation", _px(6))
	_scroll.add_child(_tijdlijn)


## Kopje met links en rechts de sierlijn (Ornament_1, rechts gespiegeld).
func _kop_met_sierlijn(tekst: String, grootte: float, lijn: float) -> HBoxContainer:
	var rij := HBoxContainer.new()
	rij.alignment = BoxContainer.ALIGNMENT_CENTER
	rij.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rij.add_theme_constant_override("separation", _px(6))
	var links := HubAssets.plaat("ornaments/Ornament_1")
	links.custom_minimum_size = Vector2(_u(lijn), _u(5))
	links.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rij.add_child(links)
	var l := HubAssets.tekst(tekst, _px(grootte), HubAssets.INKT, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rij.add_child(l)
	var rechts := HubAssets.plaat("ornaments/Ornament_1")
	rechts.custom_minimum_size = Vector2(_u(lijn), _u(5))
	rechts.flip_h = true
	rechts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rij.add_child(rechts)
	return rij


## De tabbladen FASE en CHAT boven het paneel.
func _bouw_tabs(y: float) -> void:
	_tab_fase = _tab_knop("Phase_icon", "TabFase")
	_plaats(_tab_fase, 12, y, 262, 44)
	_tab_fase.pressed.connect(func() -> void:
		_tab = 0
		_bouw_fase_paneel())
	_tab_chat = _tab_knop("Chat_icon", "TabChat")
	_plaats(_tab_chat, 290, y, 262, 44)
	_tab_chat.pressed.connect(func() -> void:
		_tab = 1
		_bouw_fase_paneel())


func _tab_knop(icoon: String, naam: String) -> Button:
	var b := Button.new()
	b.name = naam
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", _px(10))
	b.icon = HubAssets.tex("icons/" + icoon)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", _px(16))
	b.add_theme_constant_override("h_separation", _px(8))
	return b


## Stijl van een tab: geselecteerd = licht perkament, anders het donkere.
func _zet_tab(b: Button, gekozen: bool) -> void:
	HubAssets.knop(b, "frames_box/Phase_chat_selected_card" if gekozen else "frames_box/Phase_chat_unselected_card",
		Vector2(20, 20), Vector4(_u(10), 0, _u(10), 0), HubAssets.INKT if gekozen else HubAssets.IVOOR)


## De quick-chat-balk onderaan: label, drie knoppen met de zinnen die bij
## deze fase horen (_ververs_quick_chat) en "..." voor de hele lijst.
func _bouw_quick_chat(y: float) -> void:
	var label := PanelContainer.new()
	label.add_theme_stylebox_override("panel", HubAssets.patch("frames_box/Holder_quickchat", Vector2(30, 30)))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaats(label, 4, y, 104, 40)
	_qc_label = HubAssets.tekst(tr("HUB_QUICK_CHAT"), _px(8), HubAssets.IVOOR, true)
	_qc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_child(_qc_label)
	_qc_knoppen = []
	var x := 114.0
	for i in 3:
		var b := _chat_knop("", "", 7.0)
		b.name = "QC_%d" % i
		_plaats(b, x, y, 112, 40)
		b.pressed.connect(func() -> void:
			if b.has_meta("qc"):
				_stuur_chat(String(b.get_meta("qc")), int(b.get_meta("doel"))))
		_qc_knoppen.append(b)
		x += 116.0
	_qc_meer = _chat_knop("", "Other_message_icon", 0.0)
	_qc_meer.name = "QC_Meer"
	_qc_meer.add_theme_constant_override("icon_max_width", _px(26))
	_plaats(_qc_meer, x, y, 560 - x, 40)
	_qc_meer.pressed.connect(_toon_quick_chat)


## Kleine perkamenten knop met icoon links (quick chat, doneren).
func _chat_knop(tekst: String, icoon: String, grootte: float) -> Button:
	var b := Button.new()
	b.text = tekst
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	HubAssets.knop(b, "buttons/Small_button_quickchat", Vector2(30, 30), Vector4(_u(6), 0, _u(6), 0))
	if grootte > 0:
		b.add_theme_font_size_override("font_size", _px(grootte))
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", _px(14))
	b.add_theme_constant_override("h_separation", _px(3))
	if icoon != "":
		b.icon = _icoon_tex(icoon)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if tekst == "" else HORIZONTAL_ALIGNMENT_LEFT
	return b


## Icoon op naam: uit het hub-pack, of met "ui:" uit het UI-pack.
func _icoon_tex(naam: String) -> Texture2D:
	if naam.begins_with("ui:"):
		return UiAssets.icoon(naam.substr(3))
	return HubAssets.tex("icons/" + naam)


## De zin met de naam van het doel ingevuld (%s).
func _qc_tekst(sleutel: String, doel: int) -> String:
	var tekst: String = tr(sleutel)
	if tekst.contains("%s"):
		var naam: String = String(driver.c.spelers.get(doel, {}).get("naam", "..."))
		tekst = tekst.replace("%s", naam.to_upper())
	return tekst


## De drie knoppen in de balk: de zinnen die bij deze fase horen. In de raad
## gebruiken Stuur en Pak je huidige keuze uit de kolommen.
func _qc_context() -> Array:
	var c: CState = driver.c
	match c.fase:
		CState.Fase.NOMINATIE:
			if not _raad_open():
				return [["HUB_QC_VERTROUW", -1], ["HUB_QC_AKKOORD", -1], ["HUB_QC_NEE", -1]]
			var uit: Array = [["HUB_QC_STUUR_MIJ", mens_id]]
			if _keuze_eigen >= 0 and _keuze_eigen != mens_id:
				uit.append(["HUB_QC_STUUR", _keuze_eigen])
			else:
				uit.append(["HUB_QC_VERTROUW", -1])
			if _keuze_vijand >= 0:
				uit.append(["HUB_QC_PAK", _keuze_vijand])
			else:
				uit.append(["HUB_QC_AKKOORD", -1])
			return uit
		CState.Fase.DONATIE:
			return [["HUB_QC_NODIG", mens_id], ["HUB_QC_BEDANKT", -1], ["HUB_QC_BLUT", -1]]
		CState.Fase.DUELS, CState.Fase.BURGEROORLOG:
			return [["HUB_QC_SUCCES", -1], ["HUB_QC_GOED_GEVOCHTEN", -1], ["HUB_QC_VERTROUW", -1]]
		CState.Fase.TESTAMENT:
			return [["HUB_QC_NALATEN", mens_id], ["HUB_QC_VERTROUW", -1], ["HUB_QC_VERRADER", -1]]
	return [["HUB_QC_GOED_GEVOCHTEN", -1], ["HUB_QC_BEDANKT", -1], ["HUB_QC_AKKOORD", -1]]


## De balk bijwerken: zinnen per fase, verzegeld als je gevallen bent.
func _ververs_quick_chat() -> void:
	if _qc_knoppen.is_empty():
		return
	var dood := _mens_dood()
	_qc_label.text = tr("HUB_QC_VERZEGELD") if dood else tr("HUB_QUICK_CHAT")
	var context := _qc_context()
	for i in _qc_knoppen.size():
		var b: Button = _qc_knoppen[i]
		var sleutel: String = String(context[i][0])
		var doel: int = int(context[i][1])
		b.set_meta("qc", sleutel)
		b.set_meta("doel", doel)
		b.text = _qc_tekst(sleutel, doel)
		b.icon = _icoon_tex(String(QC[sleutel][0]))
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = dood
	_qc_meer.disabled = dood


## Is de mens gevallen? Dan zwijgt hij (UI-spec 2b.4: verzegeld voor de doden).
func _mens_dood() -> bool:
	return String(driver.c.spelers.get(mens_id, {}).get("status", "actief")) != "actief"

# --- Doorwerken: bots draaien op een thread tot de mens aan zet is -------------

func _werk_door() -> void:
	if _bezig or driver.c.fase == CState.Fase.KLAAR or driver.wacht_op_mens():
		_ververs()
		return
	_bezig = true
	_thread = Thread.new()
	_thread.start(_werk_thread)
	# Label-fix (27 juli): _ververs() draaide vóór deze herstart en liet
	# "Wachten op de volgende fase." staan terwijl de thread maalde: zet het
	# busy-label expliciet (géén volledige _ververs: de thread muteert de staat).
	_toon_botwerk_label()
	_poll_thread()


func _werk_thread() -> void:
	# Speel door tot de mens aan zet is, de campagne klaar is, of een tik werk
	# gedaan is (zodat de feed regelmatig ververst).
	var stappen := 0
	while driver.c.fase != CState.Fase.KLAAR and not driver.wacht_op_mens() and stappen < 8:
		driver.stap()
		stappen += 1


func _poll_thread() -> void:
	if _thread.is_alive():
		_toon_botwerk_label()
		await get_tree().create_timer(0.15).timeout
		if is_inside_tree():
			_poll_thread()
		return
	_thread.wait_to_finish()
	_bezig = false
	# Quick chat die tijdens het botwerk verstuurd werd: nu pas naar de driver
	# (de werk-thread schrijft ook in de feed en leest de toezeggingen).
	for wacht in _chat_wacht:
		driver.quick_chat(mens_id, String(wacht[0]), int(wacht[1]))
	_chat_wacht.clear()
	_ververs()
	if driver.c.fase != CState.Fase.KLAAR and not driver.wacht_op_mens():
		_werk_door()


## Live voortgang tijdens het botwerk: driver.bezig_met is een String die de
## werk-thread vervangt (referentie-swap): veilig genoeg om te tonen zonder
## de muterende campagnestaat te lezen.
func _toon_botwerk_label() -> void:
	if _info_label == null or not is_instance_valid(_info_label):
		return
	var voortgang: String = driver.bezig_met
	_info_label.text = voortgang if voortgang != "" else tr("HUB_BOTS_BUSY")


## Elke halve minuut de "3 min geleden" op de kaartjes bijwerken.
func _tik_klok() -> void:
	while is_inside_tree():
		await get_tree().create_timer(30.0).timeout
		if not is_inside_tree() or _tijdlijn == null or not is_instance_valid(_tijdlijn):
			return
		for kaart in _tijdlijn.get_children():
			var t: Label = kaart.find_child("Tijd", true, false)
			if t != null and kaart.has_meta("feed_idx"):
				t.text = _tijd_tekst(int(kaart.get_meta("feed_idx")))


# --- Weergave -------------------------------------------------------------------

## Waarden zijn vertaalsleutels; tr() gebeurt op het moment van tonen.
const FASE_NAMEN := {
	CState.Fase.NOMINATIE: "HUB_PHASE_NOMINATION",
	CState.Fase.DONATIE: "HUB_PHASE_DONATION",
	CState.Fase.DUELS: "HUB_PHASE_DUELS",
	CState.Fase.TESTAMENT: "HUB_PHASE_TESTAMENT",
	CState.Fase.BURGEROORLOG: "HUB_PHASE_CIVIL_WAR",
	CState.Fase.KLAAR: "HUB_PHASE_OVER",
}

## Korte fasenaam voor de titelbalk ("RONDE 3   RAAD").
const FASE_KORT := {
	CState.Fase.NOMINATIE: "HUB_PHASE_SHORT_NOMINATION",
	CState.Fase.DONATIE: "HUB_PHASE_SHORT_DONATION",
	CState.Fase.DUELS: "HUB_PHASE_SHORT_DUELS",
	CState.Fase.TESTAMENT: "HUB_PHASE_SHORT_TESTAMENT",
	CState.Fase.BURGEROORLOG: "HUB_PHASE_SHORT_CIVIL_WAR",
	CState.Fase.KLAAR: "HUB_PHASE_SHORT_OVER",
}


func _ververs() -> void:
	if _frame == null:
		return
	var c: CState = driver.c
	_header.text = tr("HUB_SUBTITLE") % [c.ronde, tr(FASE_KORT.get(c.fase, "?"))]
	_titel.text = tr("HUB_TITLE")
	if c.fase == CState.Fase.KLAAR and c.winnaar != -1:
		_titel.text = tr("HUB_CHAMPION") % String(c.spelers[c.winnaar].naam)
	# C11: de voorraad rekent in versterkingspunten (soldaat 1, ruiter 2,
	# kanon 3; de soldaat-teller kan daardoor negatief staan). De tent toont
	# het totaal in punten, ruiter en kanon hoeveel er in de voorraad zitten.
	var pool: Dictionary = c.pool_van(mens_id)
	_status["inf"].text = str(maxi(0, int(pool.inf) + 2 * int(pool.cav) + 3 * int(pool.art)))
	_status["cav"].text = str(maxi(0, int(pool.cav)))
	_status["art"].text = str(maxi(0, int(pool.art)))
	_status["cp"].text = str(c.cp_van(mens_id))
	_status["roem"].text = str(c.punten_van(mens_id))
	_ververs_teams()
	_ververs_tijdlijn()
	_bouw_fase_paneel()


## Staat van een lid voor de badge: dood, vecht nu, doet mee deze ronde, rust.
func _lid_status(c: CState, sid: int) -> String:
	if String(c.spelers[sid].status) != "actief":
		return "dood"
	for duel in c.duels_deze_ronde:
		if int(duel.p1) == sid or int(duel.p2) == sid:
			return "actief" if bool(duel.klaar) else "strijd"
	if c.al_genomineerd.has(sid):
		return "actief"
	return "rust"


## Mag de mens nu in de raad kiezen, en is dit lid een kandidaat?
func _raad_open() -> bool:
	return driver.c.fase == CState.Fase.NOMINATIE and driver.wacht_op_mens() and not _bezig


func _kandidaten(team: int) -> Array:
	var uit: Array = []
	for sid in driver.c.actieve_leden(team):
		if not driver.c.al_genomineerd.has(sid):
			uit.append(int(sid))
	return uit


## De teamkolommen: per lid een portret met statusbadge. Tik = info, of in
## de raad: kies je vechter (links) of het doelwit (rechts).
func _ververs_teams() -> void:
	var c: CState = driver.c
	var mijn_team: int = int(c.spelers.get(mens_id, {}).get("team", 0))
	_kies_standaard()
	for gegevens in [[_team_links, mijn_team], [_team_rechts, 1 - mijn_team]]:
		var houder: VBoxContainer = gegevens[0]
		var team: int = int(gegevens[1])
		for kind in houder.get_children():
			houder.remove_child(kind)
			kind.queue_free()
		var kandidaten := _kandidaten(team)
		for sid in c.spelers:
			if int(c.spelers[sid].team) != team:
				continue
			houder.add_child(_team_lid(c, int(sid), team == mijn_team, kandidaten))


func _team_lid(c: CState, sid: int, eigen: bool, kandidaten: Array) -> Control:
	var sp: Dictionary = c.spelers[sid]
	var b := Button.new()
	b.name = "Lid_%d" % sid
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, _u(82))
	b.tooltip_text = String(sp.naam)
	for staat in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(staat, StyleBoxEmpty.new())
	var status := _lid_status(c, sid)
	var p := HubAssets.portret(int(sp.get("doctrine", 0)), eigen, status == "dood", _u(80), status)
	p.position = Vector2(_u(21), _u(1))
	p.size = Vector2(_u(80), _u(80))
	var gekozen := (eigen and sid == _keuze_eigen) or (not eigen and sid == _keuze_vijand)
	if _raad_open():
		if not kandidaten.has(sid):
			p.modulate = Color(0.6, 0.6, 0.6, 0.8)
		if gekozen:
			var gloed := Panel.new()
			gloed.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(UiAssets.SELECTIE_GOUD, 0.25)
			sb.border_color = UiAssets.SELECTIE_GOUD
			sb.set_border_width_all(maxi(3, _px(3)))
			sb.set_corner_radius_all(_px(44))
			gloed.add_theme_stylebox_override("panel", sb)
			gloed.position = Vector2(_u(17), _u(-3))
			gloed.size = Vector2(_u(88), _u(88))
			b.add_child(gloed)
	b.add_child(p)
	if sid == mens_id:
		# "JIJ" als donker plaatje onder aan je eigen portret.
		var jij := PanelContainer.new()
		jij.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb_jij := StyleBoxFlat.new()
		sb_jij.bg_color = Color(0.08, 0.06, 0.05, 0.85)
		sb_jij.border_color = UiAssets.SELECTIE_GOUD
		sb_jij.set_border_width_all(maxi(1, _px(1)))
		sb_jij.set_corner_radius_all(_px(4))
		jij.add_theme_stylebox_override("panel", sb_jij)
		var jij_l := HubAssets.tekst(tr("HUB_YOU_TAG"), _px(7), UiAssets.SELECTIE_GOUD, true)
		jij_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		jij.add_child(jij_l)
		jij.position = Vector2(_u(8), _u(66))
		jij.size = Vector2(_u(30), _u(13))
		b.add_child(jij)
	b.pressed.connect(func() -> void:
		if _raad_open() and kandidaten.has(sid):
			if eigen:
				_keuze_eigen = sid
			else:
				_keuze_vijand = sid
			_ververs_teams()
			_bouw_fase_paneel()
		else:
			_toon_lid(sid))
	return b


## In de raad: zet een geldige standaardkeuze klaar (jijzelf of de eerste
## kandidaat; het eerste doelwit), en ruim een ongeldige keuze op.
func _kies_standaard() -> void:
	if not _raad_open():
		return
	var mijn_team: int = int(driver.c.spelers[mens_id].team)
	var eigen := _kandidaten(mijn_team)
	var vijand := _kandidaten(1 - mijn_team)
	if not eigen.has(_keuze_eigen):
		_keuze_eigen = mens_id if eigen.has(mens_id) else (int(eigen[0]) if not eigen.is_empty() else -1)
	if not vijand.has(_keuze_vijand):
		_keuze_vijand = int(vijand[0]) if not vijand.is_empty() else -1


# --- Tijdlijn ---------------------------------------------------------------------

## "zojuist", "3 min geleden": sinds de hub dit item voor het eerst zag.
func _tijd_tekst(idx: int) -> String:
	var sinds: int = int(Time.get_unix_time_from_system()) - int(_feed_tijd.get(idx, Time.get_unix_time_from_system()))
	if sinds < 60:
		return tr("HUB_TIME_NOW")
	if sinds < 3600:
		return tr("HUB_TIME_MIN") % (sinds / 60)
	return tr("HUB_TIME_HOUR") % (sinds / 3600)


func _ververs_tijdlijn() -> void:
	# F3.4c: kaartjes die de mens nog niet zag (bv. gesimuleerd terwijl hij
	# op het bord stond) druppelen gefaseerd binnen: fade-in per kaartje.
	# Nieuw staat bovenaan (pdf: "1m ago" boven, "14m ago" onder).
	# Nieuwste eerst in beeld: de vertraging telt vanaf het nieuwste item, en
	# alleen de bovenste ONTHUL_MAX kaartjes animeren (de rest staat er meteen).
	var al_gezien: int = CampaignBridge.feed_gezien
	var nieuw_totaal: int = clampi(driver.feed.size() - al_gezien, 1, ONTHUL_MAX)
	var vertraging_per: float = minf(0.45, 4.0 / float(nieuw_totaal))
	var bouwer := HubFeedKaart.new(driver.c, mens_id, _s)
	while _feed_getoond < driver.feed.size():
		var idx := _feed_getoond
		var e: Dictionary = driver.feed[idx]
		var vers: bool = idx >= al_gezien
		_feed_getoond += 1
		if not _feed_tijd.has(idx):
			_feed_tijd[idx] = int(Time.get_unix_time_from_system())
		var kaarten: Array = [bouwer.bouw(e, _tijd_tekst(idx))]
		if String(e.get("type", "")) == "fase":
			kaarten.append(bouwer.stemuitslag(e, _tijd_tekst(idx)))
		for kaart in kaarten:
			if kaart == null:
				continue
			(kaart as Control).set_meta("feed_idx", idx)
			if String(e.get("type", "")) == "report":
				# F3.3-rest: tik het kaartje voor het volledige rapport.
				kaart.tooltip_text = tr("HUB_REPORT_TOOLTIP")
				kaart.mouse_filter = Control.MOUSE_FILTER_STOP
				kaart.gui_input.connect(func(ev: InputEvent) -> void:
					if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
							and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
						_toon_report(e))
			_tijdlijn.add_child(kaart)
			_tijdlijn.move_child(kaart, 0)
			var van_boven: int = driver.feed.size() - 1 - idx
			if vers and van_boven < ONTHUL_MAX:
				kaart.modulate.a = 0.0
				var tw := (kaart as Control).create_tween()
				tw.tween_interval(0.15 + vertraging_per * van_boven)
				tw.tween_property(kaart, "modulate:a", 1.0, 0.3)
	CampaignBridge.feed_gezien = maxi(CampaignBridge.feed_gezien, driver.feed.size())
	_scroll.scroll_vertical = 0


## F3.3-rest: MatchReport-detail: het hele battlereport in een pop-up.
func _toon_report(e: Dictionary) -> void:
	var c: CState = driver.c
	var regels: Array = []
	var uitslag := tr("HUB_REPORT_DRAW")
	if int(e.winnaar) != -1:
		uitslag = tr("HUB_REPORT_WINS") % [String(c.spelers[int(e.winnaar)].naam), String(e.methode)]
	regels.append(tr("HUB_REPORT_HEADER") % [
		String(c.spelers[int(e.p1)].naam), String(c.spelers[int(e.p2)].naam),
		int(e.ronde), uitslag, int(e.cycli)])
	regels.append("")
	var cp_delta: Dictionary = e.get("cp_delta", {})
	for sid in [int(e.p1), int(e.p2)]:
		var v: Dictionary = (e.verliezen as Dictionary).get(str(sid), {})
		regels.append(tr("HUB_REPORT_LOSSES") % [
			String(c.spelers[sid].naam), int(v.get("inf", 0)), int(v.get("cav", 0)),
			int(v.get("art", 0)), int(cp_delta.get(str(sid), 0))])
	var inhoud := _popup(tr("HUB_REPORT_TITLE").to_upper(), "Rapport")
	var l := HubAssets.tekst("\n".join(regels), _px(10), HubAssets.INKT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inhoud.add_child(l)


# --- Pop-ups (quick chat, help, instellingen, lid, rapport) ------------------------

## Pop-up in het frame van het ontwerp: donkere waas over de hub, perkament
## met messing hoeken, titel met sierlijn en rechtsboven de sluitknop. Geeft
## de inhouds-kolom terug. Tik naast het perkament sluit ook.
func _popup(titel: String, naam: String = "Popup") -> VBoxContainer:
	_sluit_popup()
	var waas := ColorRect.new()
	waas.name = "Popup"
	waas.color = Color(0, 0, 0, 0.6)
	waas.mouse_filter = Control.MOUSE_FILTER_STOP
	waas.position = Vector2.ZERO
	waas.size = _frame.size
	_frame.add_child(waas)
	waas.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_sluit_popup())
	var vel := PanelContainer.new()
	vel.name = naam
	vel.add_theme_stylebox_override("panel", HubAssets.patch("frames_box/Quickchat_pop-up_frame",
		Vector2(70, 70), Vector4(_u(26), _u(26), _u(26), _u(30))))
	vel.custom_minimum_size = Vector2(_u(488), 0)
	waas.add_child(vel)
	var kolom := VBoxContainer.new()
	kolom.add_theme_constant_override("separation", _px(10))
	vel.add_child(kolom)
	var kop := HubAssets.tekst(titel, _px(26), HubAssets.INKT, true)
	kop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolom.add_child(kop)
	kolom.add_child(_kop_met_sierlijn("", 1, 150))
	var inhoud := VBoxContainer.new()
	inhoud.add_theme_constant_override("separation", _px(8))
	kolom.add_child(inhoud)
	# Plaatsen zodra de maat bekend is: gecentreerd, sluitknop op de hoek.
	var sluit := _rond_knop("Close_icon", "PopupSluit")
	sluit.size = Vector2(_u(52), _u(52))
	waas.add_child(sluit)
	sluit.pressed.connect(_sluit_popup)
	var plaats := func() -> void:
		var m := vel.get_combined_minimum_size()
		vel.size = m
		vel.position = Vector2((_frame.size.x - m.x) * 0.5, maxf(_u(150), (_frame.size.y - m.y) * 0.42))
		sluit.position = vel.position + Vector2(m.x - _u(40), -_u(14))
	vel.minimum_size_changed.connect(plaats)
	plaats.call_deferred()
	return inhoud


func _sluit_popup() -> void:
	if _frame == null:
		return
	var oud := _frame.get_node_or_null("Popup")
	if oud != null:
		_frame.remove_child(oud)
		oud.queue_free()


## Grote perkamenten knop in een pop-up (Quickchat_pop-up_button).
func _popup_knop(tekst: String, naam: String, actie: Callable) -> Button:
	var b := Button.new()
	b.name = naam
	b.text = tekst
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(_u(200), _u(52))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HubAssets.knop(b, "buttons/Quickchat_pop-up_button", Vector2(40, 40), Vector4(_u(10), 0, _u(10), 0))
	b.add_theme_font_size_override("font_size", _px(11))
	b.pressed.connect(actie)
	return b


## Het hele quick-chat-venster, in groepen. Een zin over iemand anders
## (Stuur X!, Pak X!, Doneer aan X!) vraagt eerst wie.
func _toon_quick_chat() -> void:
	if _mens_dood():
		return
	var inhoud := _popup(tr("HUB_QUICK_CHAT"), "QuickChat")
	for groep in QC_GROEPEN:
		var kop := HubAssets.tekst(tr(String(groep[0])), _px(9), HubAssets.INKT_ZACHT, true)
		inhoud.add_child(kop)
		var raster := GridContainer.new()
		raster.columns = 2
		raster.add_theme_constant_override("h_separation", _px(10))
		raster.add_theme_constant_override("v_separation", _px(6))
		inhoud.add_child(raster)
		for sleutel in groep[1]:
			var s: String = sleutel
			var wie: String = String(QC[s][1])
			var b := _popup_knop(tr(s).replace("%s", "..."), "QC_" + s, func() -> void:
				if wie == "":
					_sluit_popup()
					_stuur_chat(s, -1)
				else:
					_kies_doel(s, wie))
			b.custom_minimum_size = Vector2(_u(200), _u(40))
			b.add_theme_font_size_override("font_size", _px(10))
			b.icon = _icoon_tex(String(QC[s][0]))
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", _px(16))
			for staat in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
				b.add_theme_color_override(staat, HubAssets.INKT)
			raster.add_child(b)


## Tweede stap voor een zin over iemand: kies de teamgenoot of de vijand.
## Sturen en pakken kan alleen wie deze ronde nog niet gekozen is.
func _kies_doel(sleutel: String, wie: String) -> void:
	var c: CState = driver.c
	var mijn_team: int = int(c.spelers[mens_id].team)
	var team: int = mijn_team if wie == "team" else 1 - mijn_team
	var kandidaten: Array = []
	for sid in c.actieve_leden(team):
		if int(sid) == mens_id:
			continue
		if sleutel != "HUB_QC_DONEER" and c.al_genomineerd.has(sid):
			continue
		kandidaten.append(int(sid))
	var inhoud := _popup(tr(sleutel).replace("%s", "..."), "QcDoel")
	if kandidaten.is_empty():
		var leeg := HubAssets.tekst(tr("HUB_QC_NIEMAND"), _px(11), HubAssets.INKT_ZACHT)
		leeg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inhoud.add_child(leeg)
		return
	var raster := GridContainer.new()
	raster.columns = 4
	raster.add_theme_constant_override("h_separation", _px(8))
	raster.add_theme_constant_override("v_separation", _px(8))
	inhoud.add_child(raster)
	for sid in kandidaten:
		var doel: int = sid
		var sp: Dictionary = c.spelers[doel]
		var b := Button.new()
		b.name = "Doel_%d" % doel
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(_u(104), _u(84))
		for staat in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(staat, StyleBoxEmpty.new())
		var p := HubAssets.portret(int(sp.get("doctrine", 0)), team == mijn_team, false, _u(60))
		p.position = Vector2(_u(22), 0)
		p.size = Vector2(_u(60), _u(60))
		b.add_child(p)
		var naam := HubAssets.tekst(String(sp.naam), _px(9), HubAssets.INKT, true)
		naam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		naam.position = Vector2(0, _u(62))
		naam.size = Vector2(_u(104), _u(18))
		b.add_child(naam)
		b.pressed.connect(func() -> void:
			_sluit_popup()
			_stuur_chat(sleutel, doel))
		raster.add_child(b)


func _toon_help() -> void:
	var inhoud := _popup(tr("HUB_HELP_TITLE"), "Help")
	var l := HubAssets.tekst(tr("HUB_HELP_TEXT"), _px(10), HubAssets.INKT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inhoud.add_child(l)


func _toon_instellingen() -> void:
	var inhoud := _popup(tr("HUB_SETTINGS_TITLE"), "Instellingen")
	inhoud.add_child(_popup_knop(tr("HUB_LEDGER_BTN").to_upper(), "InstGrootboek", func() -> void:
		_sluit_popup()
		_toon_grootboek()))
	inhoud.add_child(_popup_knop(tr("HUB_MAIN_MENU").to_upper(), "InstHoofdmenu", func() -> void:
		get_tree().change_scene_to_file("res://scenes/game/game.tscn")))
	inhoud.add_child(_popup_knop(tr("HUB_CLOSE").to_upper(), "InstSluit", _sluit_popup))


func _toon_grootboek() -> void:
	var scherm := LedgerScreen.new()
	add_child(scherm)
	scherm.open(driver.c, mens_id)


## Tik op een portret: naam, stand en (als je het mag zien) de saldi.
func _toon_lid(sid: int) -> void:
	var c: CState = driver.c
	var sp: Dictionary = c.spelers[sid]
	var mijn_team: int = int(c.spelers.get(mens_id, {}).get("team", 0))
	var naam := String(sp.naam) + (tr("HUB_YOU_SUFFIX") if sid == mens_id else "")
	var inhoud := _popup(naam, "LidInfo")
	var status := _lid_status(c, sid)
	var p := HubAssets.portret(int(sp.get("doctrine", 0)), int(sp.team) == mijn_team, status == "dood",
		_u(110), status)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inhoud.add_child(p)
	var regels: Array = [Constants.doctrine_display_name(int(sp.get("doctrine", 0))),
		tr("HUB_STATUS_" + status.to_upper())]
	if status != "dood":
		if CView.mag_saldo_zien(c, mens_id, sid):
			regels.append(tr("HUB_ROW_SALDO") % [c.pool_totaal_van(sid), c.cp_van(sid), c.punten_van(sid)])
		else:
			regels.append(tr("HUB_ROW_SALDO_GEHEIM") % c.punten_van(sid))
	var l := HubAssets.tekst("\n".join(regels), _px(11), HubAssets.INKT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inhoud.add_child(l)


# --- Quick chat -------------------------------------------------------------------

## Een quick-chat-zin van de mens. De SoloDriver zet hem in de feed, laat
## teamgenoten antwoorden (AKKOORD! of NEE., naar karakter) en onthoudt wie
## iets toezegde. Tijdens het botwerk wacht hij tot de thread klaar is.
func _stuur_chat(sleutel: String, doel: int = -1) -> void:
	if _mens_dood():
		return
	if _bezig or CampaignBridge.sim_bezig():
		_chat_wacht.append([sleutel, doel])
		return
	driver.quick_chat(mens_id, sleutel, doel)
	if _tab == 1:
		_chat_gezien = _chat_berichten().size()
	_ververs_tijdlijn()
	_bouw_fase_paneel()


## Alles wat in het chat-tabblad hoort: quick chat en barks, alleen van je
## eigen team (UI-spec 2b.2: team-only). Buiten het botwerk opnieuw geteld;
## tijdens het botwerk de laatste telling (de werk-thread schrijft de feed).
func _chat_berichten() -> Array:
	if _bezig or CampaignBridge.sim_bezig():
		return _chat_cache
	var uit: Array = []
	var mijn_team: int = int(driver.c.spelers.get(mens_id, {}).get("team", 0))
	for i in driver.feed.size():
		var e: Dictionary = driver.feed[i]
		var soort := String(e.get("type", ""))
		var sid: int = int(e.get("speler", -1))
		if (soort == "chat" or soort == "bark") and sid >= 0 \
				and int(driver.c.spelers.get(sid, {}).get("team", -1)) == mijn_team:
			uit.append(i)
			_chat_e[i] = e
	_chat_cache = uit
	return uit


func _paneel_chat() -> void:
	if _mens_dood():
		var zegel := HubAssets.tekst(tr("HUB_CHAT_SEALED"), _px(10), HubAssets.INKT_ZACHT)
		zegel.name = "ChatVerzegeld"
		zegel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		zegel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_paneel.add_child(zegel)
		return
	var berichten: Array = _chat_berichten().duplicate()
	if berichten.is_empty():
		var l := HubAssets.tekst(tr("HUB_CHAT_EMPTY"), _px(10), HubAssets.INKT_ZACHT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_paneel.add_child(l)
		return
	var c: CState = driver.c
	var mijn_team: int = int(c.spelers.get(mens_id, {}).get("team", 0))
	berichten.reverse()
	for n in berichten.size():
		var idx: int = berichten[n]
		var e: Dictionary = _chat_e.get(idx, {})
		var nieuw: bool = (berichten.size() - n) > _chat_gezien
		var rij := PanelContainer.new()
		rij.name = "Chat_%d" % idx
		rij.add_theme_stylebox_override("panel", HubAssets.patch(
			"quick_chat/Quickchat_new_message" if nieuw else "quick_chat/Quickchat_message",
			Vector2(18, 18), Vector4(_u(10), _u(5), _u(12), _u(5))))
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", _px(8))
		rij.add_child(r)
		var sid: int = int(e.speler)
		var sp: Dictionary = c.spelers.get(sid, {})
		var p := HubAssets.portret(int(sp.get("doctrine", 0)), int(sp.get("team", 0)) == mijn_team,
			String(sp.get("status", "actief")) != "actief", _u(22))
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(p)
		var naam := HubAssets.tekst(String(e.get("naam", "?")), _px(10), HubAssets.INKT, true)
		naam.custom_minimum_size = Vector2(_u(118), 0)
		naam.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		r.add_child(naam)
		var soort_chat := String(e.type) == "chat"
		var tekst := HubAssets.tekst(String(e.tekst).to_upper() if soort_chat else String(e.tekst),
			_px(10 if soort_chat else 9), HubAssets.INKT, soort_chat)
		tekst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tekst.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.add_child(tekst)
		var tijd := HubAssets.tekst(_klok(idx), _px(7), HubAssets.INKT_ZACHT)
		tijd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(tijd)
		_paneel.add_child(rij)
	_chat_gezien = berichten.size()


## Klokje van een bericht ("14:30"), lokale tijd.
func _klok(idx: int) -> String:
	var t: int = int(_feed_tijd.get(idx, Time.get_unix_time_from_system()))
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(t + bias)
	return "%02d:%02d" % [int(d.hour), int(d.minute)]


# --- Fasepaneel -------------------------------------------------------------------

func _wis_paneel() -> void:
	for kind in _paneel.get_children():
		_paneel.remove_child(kind)
		kind.queue_free()


## Knop op het perkament van het fasepaneel (Button_quickchat). De callable
## staat achteraan (meerregelige lambda).
func _knop(tekst: String, icoon_id: String, actie: Callable) -> Button:
	var b := Button.new()
	b.text = tekst
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, _u(38))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HubAssets.knop(b, "buttons/Button_quickchat", Vector2(34, 34), Vector4(_u(10), 0, _u(10), 0))
	b.add_theme_font_size_override("font_size", _px(10))
	if icoon_id != "":
		b.icon = UiAssets.icoon(icoon_id)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", _px(16))
	b.pressed.connect(actie)
	return b


## De rode knop uit het ontwerp (VOTE), met de lauwerhaakjes om de tekst.
func _rode_knop(tekst: String, naam: String, actie: Callable) -> Button:
	var b := Button.new()
	b.name = naam
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(_u(136), _u(40))
	HubAssets.knop(b, "buttons/Vote_button_default", Vector2(40, 24), Vector4(_u(8), 0, _u(8), 0),
		HubAssets.IVOOR, "buttons/Vote_button_pressed")
	if tekst.length() <= 6:
		# De lauwerhaakjes staan alleen om een kort woord (STEM / VOTE).
		var haakjes := HubAssets.plaat("icons/Vote_icon")
		haakjes.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		haakjes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		haakjes.offset_left = _u(14)
		haakjes.offset_right = -_u(14)
		haakjes.offset_top = _u(7)
		haakjes.offset_bottom = -_u(7)
		b.add_child(haakjes)
	var l := HubAssets.tekst(tekst, _px(14), HubAssets.IVOOR, true)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	b.pressed.connect(actie)
	return b


func _paneel_tekst(tekst: String, grootte: float = 10, kleur: Color = HubAssets.INKT) -> Label:
	var l := HubAssets.tekst(tekst, _px(grootte), kleur)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paneel.add_child(l)
	return l


func _bouw_fase_paneel() -> void:
	if _frame == null:
		return
	_wis_paneel()
	_info_label = null
	_ververs_quick_chat()
	var berichten := _chat_berichten().size()
	_zet_tab(_tab_fase, _tab == 0)
	_zet_tab(_tab_chat, _tab == 1)
	_tab_fase.text = tr("HUB_TAB_PHASE")
	var ongelezen: int = 0 if _tab == 1 else maxi(0, berichten - _chat_gezien)
	_tab_chat.text = tr("HUB_TAB_CHAT") % mini(ongelezen, 99) if ongelezen > 0 else tr("HUB_TAB_CHAT_PLAIN")
	if _tab == 1:
		_paneel_chat()
		_tab_chat.text = tr("HUB_TAB_CHAT_PLAIN")
		return
	var c: CState = driver.c
	if c.fase == CState.Fase.KLAAR:
		_paneel_einde(c)
		return
	if c.fase == CState.Fase.BURGEROORLOG:
		var bv := BracketView.new()
		bv.name = "BracketView"
		bv.vul(c)
		# BracketView is gemaakt voor de veldtafel (ivoor): op perkament in inkt.
		for kind in bv.find_children("*", "Label", true, false):
			(kind as Label).add_theme_color_override("font_color", HubAssets.INKT)
		_paneel.add_child(bv)
	if not driver.wacht_op_mens():
		var rij := HBoxContainer.new()
		rij.alignment = BoxContainer.ALIGNMENT_CENTER
		rij.add_theme_constant_override("separation", _px(8))
		rij.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var zandloper := HubAssets.icoon("Phase_icon", _u(18), HubAssets.INKT)
		zandloper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rij.add_child(zandloper)
		_info_label = HubAssets.tekst(tr("HUB_BOTS_BUSY") if _bezig else tr("HUB_WAIT_NEXT_PHASE"), _px(11), HubAssets.INKT)
		_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rij.add_child(_info_label)
		_paneel.add_child(rij)
		return
	match c.fase:
		CState.Fase.NOMINATIE:
			_paneel_nominatie(c)
		CState.Fase.DONATIE:
			_paneel_donatie(c)
		CState.Fase.TESTAMENT:
			_paneel_testament(c)
		CState.Fase.DUELS, CState.Fase.BURGEROORLOG:
			_paneel_duel(c)


## 27 juli (Max): het campagne-eindscherm: kampioen, eindstand, opnieuw.
func _paneel_einde(c: CState) -> void:
	var kampioen: Dictionary = c.spelers.get(c.winnaar, {})
	var mijn_team: int = int(c.spelers.get(mens_id, {}).get("team", 0))
	var kop := HBoxContainer.new()
	kop.alignment = BoxContainer.ALIGNMENT_CENTER
	kop.add_theme_constant_override("separation", _px(10))
	if not kampioen.is_empty():
		kop.add_child(HubAssets.portret(int(kampioen.get("doctrine", 0)),
			int(kampioen.get("team", 0)) == mijn_team, false, _u(54)))
	var titel := HubAssets.tekst(tr("HUB_END_CHAMPION") % String(kampioen.get("naam", "?")), _px(15), HubAssets.INKT, true)
	titel.name = "EindTitel"
	titel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kop.add_child(titel)
	_paneel.add_child(kop)
	var mijn_punten: int = c.punten_van(mens_id)
	var plek: int = 1
	for id in c.spelers:
		if c.punten_van(int(id)) > mijn_punten:
			plek += 1
	_paneel_tekst(tr("HUB_END_SUMMARY") % [c.ronde, driver.duels_gespeeld, mijn_punten, plek, c.spelers.size()], 9)
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", _px(10))
	rij.add_child(_knop(tr("HUB_END_LEDGER_BTN"), "score", _toon_grootboek))
	var opnieuw := _knop(tr("HUB_END_NEW_BTN"), "phase-setup", func() -> void:
		if FileAccess.file_exists(SAVE_PAD):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PAD))
		CampaignBridge.driver = null
		CampaignBridge.feed_gezien = 0
		get_tree().reload_current_scene())
	opnieuw.name = "NieuweCampagneKnop"
	rij.add_child(opnieuw)
	_paneel.add_child(rij)


## De raad (pdf pagina 1): links jouw vechter -> het doelwit met naamplaatjes,
## rechts de teamstemmen, de voortgang en STEM. Kiezen doe je door een
## portret in de kolommen aan te tikken (of het portret hier: volgende).
func _paneel_nominatie(c: CState) -> void:
	_kies_standaard()
	_paneel.add_child(_kop_met_sierlijn(tr("HUB_COUNCIL_TITLE"), 10, 40))
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", _px(10))
	rij.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_paneel.add_child(rij)
	var mijn_team: int = int(c.spelers[mens_id].team)
	var links := HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links.add_theme_constant_override("separation", _px(6))
	rij.add_child(links)
	links.add_child(_raad_keuze(c, _keuze_eigen, true, tr("HUB_YOUR_FIGHTER"), "strijd", _kandidaten(mijn_team)))
	var pijl := HubAssets.icoon("Arrow_icon", _u(30))
	pijl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pijl.custom_minimum_size = Vector2(_u(30), _u(56))
	links.add_child(pijl)
	links.add_child(_raad_keuze(c, _keuze_vijand, false, tr("HUB_ENEMY_TARGET"), "actief", _kandidaten(1 - mijn_team)))
	var scheiding := HubAssets.plaat("ornaments/Ornament_2")
	scheiding.custom_minimum_size = Vector2(_u(6), _u(100))
	rij.add_child(scheiding)
	var rechts := VBoxContainer.new()
	rechts.custom_minimum_size = Vector2(_u(190), 0)
	rechts.add_theme_constant_override("separation", _px(5))
	rij.add_child(rechts)
	var kop := HubAssets.tekst(tr("HUB_TEAM_VOTES"), _px(8), HubAssets.INKT, true)
	kop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rechts.add_child(kop)
	var stemmen := HBoxContainer.new()
	stemmen.name = "TeamStemmen"
	stemmen.alignment = BoxContainer.ALIGNMENT_CENTER
	stemmen.add_theme_constant_override("separation", _px(3))
	rechts.add_child(stemmen)
	var leden: Array = c.actieve_leden(c.nominatie_team)
	var gestemd := 0
	for sid in leden:
		if c.nominatie_stemmen.has(sid):
			gestemd += 1
			var sp: Dictionary = c.spelers[sid]
			stemmen.add_child(HubAssets.portret(int(sp.get("doctrine", 0)), true, false, _u(22)))
	for i in leden.size() - gestemd:
		stemmen.add_child(HubAssets.leeg_rondje(_u(22)))
	var voortgang := HBoxContainer.new()
	voortgang.add_theme_constant_override("separation", _px(5))
	rechts.add_child(voortgang)
	var zandloper := HubAssets.icoon("Phase_icon", _u(13), HubAssets.INKT)
	voortgang.add_child(zandloper)
	var telling := HubAssets.tekst("%d/%d" % [gestemd, leden.size()], _px(10), HubAssets.INKT, true)
	telling.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	voortgang.add_child(telling)
	var balk := Control.new()
	balk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balk.custom_minimum_size = Vector2(0, _u(11))
	balk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var achter := HubAssets.plaat("nominate/Loading_bar_BG")
	achter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	balk.add_child(achter)
	var vul := HubAssets.plaat("nominate/Loading_bar")
	vul.anchor_bottom = 1.0
	vul.anchor_right = float(gestemd) / float(maxi(1, leden.size()))
	balk.add_child(vul)
	voortgang.add_child(balk)
	var stem := _rode_knop(tr("HUB_VOTE_CAPS"), "StemKnop", func() -> void:
		if _keuze_eigen >= 0 and _keuze_vijand >= 0:
			driver.submit_mens_nominatie(_keuze_eigen, _keuze_vijand)
			_werk_door())
	stem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stem.disabled = _keuze_eigen < 0 or _keuze_vijand < 0
	rechts.add_child(stem)


## Een kant van de raad: portret (tik = volgende kandidaat), naamplaatje en rol.
func _raad_keuze(c: CState, sid: int, eigen: bool, rol: String, badge: String, kandidaten: Array) -> Control:
	var kolom := VBoxContainer.new()
	kolom.name = "RaadEigen" if eigen else "RaadVijand"
	kolom.add_theme_constant_override("separation", _px(2))
	var knop := Button.new()
	knop.flat = true
	knop.focus_mode = Control.FOCUS_NONE
	knop.custom_minimum_size = Vector2(_u(56), _u(56))
	knop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for staat in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		knop.add_theme_stylebox_override(staat, StyleBoxEmpty.new())
	if sid >= 0:
		var sp: Dictionary = c.spelers[sid]
		var p := HubAssets.portret(int(sp.get("doctrine", 0)), eigen, false, _u(56), badge)
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		knop.add_child(p)
	knop.pressed.connect(func() -> void:
		if kandidaten.is_empty():
			return
		var volgende: int = int(kandidaten[(kandidaten.find(sid) + 1) % kandidaten.size()])
		if eigen:
			_keuze_eigen = volgende
		else:
			_keuze_vijand = volgende
		_ververs_teams()
		_bouw_fase_paneel())
	kolom.add_child(knop)
	var plaat := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#EFE2C4")
	sb.border_color = HubAssets.INKT
	sb.set_border_width_all(maxi(2, _px(1.2)))
	sb.set_corner_radius_all(_px(3))
	sb.content_margin_left = _u(6)
	sb.content_margin_right = _u(6)
	sb.content_margin_top = _u(1)
	sb.content_margin_bottom = _u(1)
	plaat.add_theme_stylebox_override("panel", sb)
	var naam := HubAssets.tekst(String(c.spelers[sid].naam) if sid >= 0 else "-", _px(8), HubAssets.INKT, true)
	naam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	naam.custom_minimum_size = Vector2(_u(92), 0)
	naam.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	plaat.add_child(naam)
	kolom.add_child(plaat)
	var r := HubAssets.tekst(rol, _px(6.5), HubAssets.INKT_ZACHT, true)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolom.add_child(r)
	return kolom


## F3.4b: het mens-duel speelt op het echte bord: de brug zet de config klaar.
## UX (27 juli, Max): de mens heeft voorrang op de bot-simulaties, het paneel
## toont wie-tegen-wie deze ronde, en het duel start na een korte aftel
## vanzelf met een laadscherm. "Blijf in de hub" annuleert de auto-start.
func _paneel_duel(c: CState) -> void:
	var d: Dictionary = driver.mens_duel()
	if d.is_empty():
		return
	var vijand: int = int(d.p2) if int(d.p1) == mens_id else int(d.p1)
	var mijn_team: int = int(c.spelers[mens_id].team)
	_paneel_tekst(tr("HUB_DUEL_TITLE") % String(c.spelers[vijand].naam), 8.5)
	var knoppen := HBoxContainer.new()
	knoppen.alignment = BoxContainer.ALIGNMENT_CENTER
	knoppen.add_theme_constant_override("separation", _px(10))
	_paneel.add_child(knoppen)
	var speel := _rode_knop(tr("HUB_DUEL_PLAY_CAPS"), "SpeelDuelKnop", func() -> void:
		_start_mens_duel(vijand))
	speel.custom_minimum_size = Vector2(_u(190), _u(40))
	knoppen.add_child(speel)
	if _auto_stop_idx != int(d.idx):
		var blijf := _knop(tr("HUB_DUEL_STAY_BTN"), "", func() -> void:
			_auto_stop_idx = int(d.idx)
			_bouw_fase_paneel())
		blijf.name = "BlijfKnop"
		knoppen.add_child(blijf)
		_paneel_tekst(tr("HUB_DUEL_AUTO"), 8, HubAssets.INKT_ZACHT)
		if _auto_start_idx != int(d.idx):
			_auto_start_idx = int(d.idx)
			_auto_start_duel(int(d.idx), vijand)
	_paneel.add_child(_kop_met_sierlijn(tr("HUB_DUEL_PAIRS_TITLE"), 9, 40))
	for duel in c.duels_deze_ronde:
		var rij := HBoxContainer.new()
		rij.alignment = BoxContainer.ALIGNMENT_CENTER
		rij.add_theme_constant_override("separation", _px(6))
		var kleur: Color = HubAssets.INKT
		if int(duel.p1) == mens_id or int(duel.p2) == mens_id:
			kleur = HubAssets.ROOD
		elif bool(duel.klaar):
			kleur = HubAssets.INKT_ZACHT
		for kant in [int(duel.p1), int(duel.p2)]:
			var sp: Dictionary = c.spelers[kant]
			rij.add_child(HubAssets.portret(int(sp.get("doctrine", 0)), int(sp.team) == mijn_team,
				String(sp.status) != "actief", _u(20)))
		var status: String = tr("BRACKET_DONE") if bool(duel.klaar) else tr("BRACKET_NOW_PLAYING")
		var r := HubAssets.tekst(tr("BRACKET_DUEL_ROW") % [String(c.spelers[int(duel.p1)].naam),
			String(c.spelers[int(duel.p2)].naam), status], _px(9), kleur)
		r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rij.add_child(r)
		_paneel.add_child(rij)


func _auto_start_duel(idx: int, vijand: int) -> void:
	await get_tree().create_timer(2.5).timeout
	if not is_inside_tree() or _auto_stop_idx == idx:
		return
	var d: Dictionary = driver.mens_duel()
	if d.is_empty() or int(d.idx) != idx:
		return
	_start_mens_duel(vijand)


## Laadscherm tonen en dan pas de (zware) scene-wissel doen: geen bevroren
## hub meer tussen klik en bord.
func _start_mens_duel(vijand: int) -> void:
	if _duel_start_bezig or not CampaignBridge.start_mens_duel():
		return
	_duel_start_bezig = true
	var lader := _veldtafel()
	var midden := CenterContainer.new()
	_vul_scherm(midden)
	lader.add_child(midden)
	var kolom := VBoxContainer.new()
	kolom.add_theme_constant_override("separation", 24)
	midden.add_child(kolom)
	var sabels := HubAssets.icoon("Inbattle_icon", 120, UiAssets.WARM_IVOOR)
	sabels.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	kolom.add_child(sabels)
	var tekst := _tekst(tr("HUB_DUEL_LOADING") % String(driver.c.spelers[vijand].naam), "LabelKop", 30)
	tekst.custom_minimum_size = Vector2(900, 0)
	tekst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolom.add_child(tekst)
	add_child(lader)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _paneel_donatie(c: CState) -> void:
	# C11-UX (Max): doneren = een plusje achter de naam. [+1] geeft 1
	# versterkingspunt (1 soldaat), [+CP] geeft 1 CP; caps bewaakt de reducer.
	_paneel.add_child(_kop_met_sierlijn(tr("HUB_DONATE_SHORT"), 10, 40))
	_paneel_tekst(tr("HUB_DONATE_HINT"), 7.5, HubAssets.INKT_ZACHT)
	var mijn_team: int = int(c.spelers[mens_id].team)
	var mijn_pool: Dictionary = c.pool_van(mens_id)
	var raster := GridContainer.new()
	raster.columns = 2
	raster.add_theme_constant_override("h_separation", _px(10))
	raster.add_theme_constant_override("v_separation", _px(4))
	_paneel.add_child(raster)
	for sid in c.actieve_leden(mijn_team):
		if int(sid) == mens_id:
			continue
		var rij := HBoxContainer.new()
		rij.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rij.add_theme_constant_override("separation", _px(4))
		var sp: Dictionary = c.spelers[int(sid)]
		var portret := HubAssets.portret(int(sp.get("doctrine", 0)), true, false, _u(30))
		portret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rij.add_child(portret)
		var naam := HubAssets.tekst(String(sp.naam), _px(9), HubAssets.INKT, true)
		naam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		naam.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		naam.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rij.add_child(naam)
		var doel: int = int(sid)
		var plus := _chat_knop(tr("HUB_PLUS_VST"), "Donation_icon", 9)
		plus.custom_minimum_size = Vector2(_u(50), _u(32))
		plus.disabled = int(mijn_pool.inf) <= 0
		plus.pressed.connect(func() -> void:
			if driver.submit_mens_donatie(doel, 1, 0, 0, 0):
				_ververs())
		rij.add_child(plus)
		var plus_cp := _chat_knop(tr("HUB_PLUS_CP"), "", 9)
		plus_cp.custom_minimum_size = Vector2(_u(50), _u(32))
		plus_cp.disabled = driver.c.cp_van(mens_id) <= 0
		plus_cp.pressed.connect(func() -> void:
			if driver.submit_mens_donatie(doel, 0, 0, 0, 1):
				_ververs())
		rij.add_child(plus_cp)
		raster.add_child(rij)
	var knoppen := HBoxContainer.new()
	knoppen.add_theme_constant_override("separation", _px(10))
	_paneel.add_child(knoppen)
	var koers: int = maxi(1, c.rules.ruil_cp_per_punt)
	var ruil := _knop(tr("HUB_RUIL_BTN") % koers, "cp", func() -> void:
		if driver.submit_mens_ruil(koers):
			_ververs())
	ruil.name = "RuilKnop"
	ruil.disabled = c.cp_van(mens_id) < koers
	knoppen.add_child(ruil)
	var klaar := _knop(tr("HUB_DONATE_DONE_BTN"), "check", func() -> void:
		driver.submit_mens_klaar_met_doneren()
		_werk_door())
	klaar.name = "KlaarKnop"
	knoppen.add_child(klaar)


func _paneel_testament(c: CState) -> void:
	_paneel.add_child(_kop_met_sierlijn(tr("HUB_TAG_TESTAMENT"), 10, 40))
	_paneel_tekst(tr("HUB_WILL_TITLE"), 8)
	var doelen := OptionButton.new()
	doelen.name = "TestamentDoel"
	doelen.custom_minimum_size = Vector2(0, _u(34))
	doelen.add_theme_font_size_override("font_size", _px(10))
	for id in c.spelers:
		if int(id) != mens_id and String(c.spelers[id].status) == "actief":
			doelen.add_item(tr("HUB_WILL_TARGET") % [c.spelers[id].naam, int(c.spelers[id].team)], int(id))
	_paneel.add_child(doelen)
	var knoppen := HBoxContainer.new()
	knoppen.add_theme_constant_override("separation", _px(10))
	_paneel.add_child(knoppen)
	knoppen.add_child(_knop(tr("HUB_WILL_HALF_BTN"), "pool", func() -> void:
		if doelen.selected < 0:
			return
		var bezit: Dictionary = c.pool_van(mens_id)
		var verdeling: Array = [{
			"naar": doelen.get_selected_id(),
			"inf": int(floor(int(bezit.inf) * 0.5)),
			"cav": int(floor(int(bezit.cav) * 0.5)),
			"art": int(floor(int(bezit.art) * 0.5)),
			"cp": int(floor(c.cp_van(mens_id) * 0.5)),
		}]
		driver.submit_mens_testament(verdeling)
		_werk_door()))
	knoppen.add_child(_knop(tr("HUB_WILL_NONE_BTN"), "", func() -> void:
		driver.submit_mens_testament([])
		_werk_door()))
