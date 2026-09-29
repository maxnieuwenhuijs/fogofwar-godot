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
## De kaarten van het spelregelscherm (29 september). Via preload: headless
## kent een nieuwe klasse pas als de editor hem inschreef.
const HubRegels := preload("res://scripts/ui/campaign/hub_regels.gd")

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
var _paneel_scroll: ScrollContainer
var _voet: HBoxContainer                 # de hoofdknoppen van de fase, altijd in beeld
var _keuze_laag: Control = null          # het lopende keuzescherm (factie, hervatten, laden)
var _auto_start_ms: int = 0              # wanneer de aftel van het mens-duel begon
var _testament_doel: int = -1            # testament: aan wie
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

## Zoveel nieuwe kaartjes faden onderaan de tijdlijn in; oudere staan er meteen.
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


## 28 juli (Max): doorgaan of opnieuw: nooit meer stilletjes hervatten.
## 27 september: in de stijl van de hub (frame, titelplaat, perkament).
func _toon_hervat_keuze(oud_driver: SoloDriver) -> void:
	var kolom := _keuze_scherm(tr("HUB_RESUME_TITLE"), "HervatKeuze")
	var laag := _keuze_laag
	var mijn: Dictionary = oud_driver.c.spelers.get(oud_driver.mens_id, {})
	_ruimte(kolom)
	var kaart := PanelContainer.new()
	kaart.add_theme_stylebox_override("panel", HubAssets.patch("frames_box/Timeline_action_box_2",
		Vector2(26, 26), Vector4(_u(18), _u(16), _u(18), _u(16))))
	kolom.add_child(kaart)
	var binnen := VBoxContainer.new()
	binnen.add_theme_constant_override("separation", _px(10))
	kaart.add_child(binnen)
	var p := HubAssets.portret(int(mijn.get("doctrine", 0)), true, false, _u(110))
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	binnen.add_child(p)
	var naam := _naamplaat(String(mijn.get("naam", "?")), 13)
	naam.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	binnen.add_child(naam)
	var uitleg := HubAssets.tekst(tr("HUB_RESUME_INFO") % [oud_driver.c.ronde,
		Constants.doctrine_display_name(int(mijn.get("doctrine", 0)))], _px(11), HubAssets.INKT)
	uitleg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	uitleg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	binnen.add_child(uitleg)
	var knoppen := HBoxContainer.new()
	knoppen.alignment = BoxContainer.ALIGNMENT_CENTER
	knoppen.add_theme_constant_override("separation", _px(12))
	kolom.add_child(knoppen)
	var nieuw := _knop(tr("HUB_RESUME_NEW"), "phase-setup", func() -> void:
		_sluit_keuze(laag)
		if FileAccess.file_exists(SAVE_PAD):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PAD))
		CampaignBridge.driver = null
		CampaignBridge.feed_gezien = 0
		_toon_factie_keuze())
	nieuw.name = "HervatNieuw"
	knoppen.add_child(nieuw)
	var door := _rode_knop(tr("HUB_RESUME_CONTINUE_CAPS"), "HervatDoorgaan", func() -> void:
		_sluit_keuze(laag)
		driver = oud_driver
		mens_id = driver.mens_id
		_start())
	door.custom_minimum_size = Vector2(_u(180), _u(44))
	knoppen.add_child(door)
	_ruimte(kolom)


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
## 27 september: in de stijl van de hub (frame, titelplaat).
func _toon_factie_keuze() -> void:
	var kolom := _keuze_scherm(tr("HUB_FACTION_TITLE"), "FactieKeuze", tr("HUB_FACTION_EXPLAIN"))
	var laag := _keuze_laag
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	kolom.add_child(scroll)
	var lijst := VBoxContainer.new()
	lijst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lijst.add_theme_constant_override("separation", _px(8))
	scroll.add_child(lijst)
	var tabel: RulesConfig = CRules.actieve_tabel()
	for doctrine in Constants.DOCTRINE_DATA:
		var kaart := UiFactieKaart.new(int(doctrine), tabel.doctrine_data(int(doctrine)))
		kaart.name = "Factie_%d" % int(doctrine)
		kaart.pressed.connect(_kies_factie.bind(int(doctrine), laag))
		lijst.add_child(kaart)
	# Eerst weten hoe het werkt? De spelregels liggen er bovenop. Een
	# perkamenten knop: een tekstlink verdwijnt op het donkere hout.
	var regels := _knop(tr("HUB_RULES_LINK"), "", _toon_regels)
	regels.name = "RegelsLink"
	regels.icon = HubAssets.tex("icons/Info_icon")
	regels.expand_icon = true
	regels.add_theme_constant_override("icon_max_width", _px(16))
	regels.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	regels.custom_minimum_size = Vector2(_u(290), _u(38))
	kolom.add_child(regels)


func _kies_factie(doctrine: int, keuze_scherm: Control) -> void:
	_sluit_keuze(keuze_scherm)
	driver = SoloDriver.new(int(Time.get_unix_time_from_system()) % 900000,
		mens_id, 16, SAVE_PAD, doctrine)
	_start()


## Een keuzescherm meteen uit de boom (dan staat het niet nog een frame naast
## de hub die erna gebouwd wordt) en vrijgeven.
func _sluit_keuze(laag: Control) -> void:
	if laag != null and is_instance_valid(laag):
		if laag.get_parent() != null:
			laag.get_parent().remove_child(laag)
		laag.queue_free()
	if _keuze_laag == laag:
		_keuze_laag = null


## Een volledig scherm in de stijl van de hub (factiekeuze, hervatten, het
## laadscherm): het hout eromheen, BG.png als frame, bovenin de titelplaat met
## titel en (optioneel) een regel eronder. Geeft de inhoudskolom terug; het
## scherm zelf staat in _keuze_laag.
func _keuze_scherm(titel: String, naam: String, sub: String = "") -> VBoxContainer:
	_vul_scherm(self)
	var vp := get_viewport_rect().size
	_s = minf(vp.x / HubAssets.ONTWERP.x, vp.y / HubAssets.ONTWERP.y)
	var laag := Control.new()
	laag.name = naam
	laag.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(laag)
	laag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	laag.add_child(_veldtafel())
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = Vector2((vp.x - _u(HubAssets.ONTWERP.x)) * 0.5, 0)
	frame.size = Vector2(_u(HubAssets.ONTWERP.x), vp.y)
	laag.add_child(frame)
	var hoogte: float = vp.y / _s
	var bg := HubAssets.plaat("bg/BG")
	bg.size = frame.size
	frame.add_child(bg)
	var plaat := HubAssets.plaat("frames_box/Title_frame")
	plaat.size = Vector2(_u(564), _u(78))
	frame.add_child(plaat)
	var t := HubAssets.tekst(titel, _px(17), HubAssets.INKT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(_u(30), _u(12 if sub != "" else 22))
	t.size = Vector2(_u(504), _u(30))
	frame.add_child(t)
	if sub != "":
		var u := HubAssets.tekst(sub, _px(9), HubAssets.INKT_ZACHT)
		u.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		u.position = Vector2(_u(30), _u(46))
		u.size = Vector2(_u(504), _u(18))
		frame.add_child(u)
	var kolom := VBoxContainer.new()
	kolom.name = "Inhoud"
	kolom.position = Vector2(_u(22), _u(96))
	kolom.size = Vector2(_u(520), _u(hoogte - 116))
	kolom.add_theme_constant_override("separation", _px(12))
	frame.add_child(kolom)
	_keuze_laag = laag
	return kolom


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
	if get_node_or_null("Veldtafel") == null:
		var hout := _veldtafel()
		hout.name = "Veldtafel"
		add_child(hout)
		move_child(hout, 0)
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
	var binnen := VBoxContainer.new()
	binnen.add_theme_constant_override("separation", _px(6))
	kader.add_child(binnen)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Scrollen mag (vinger of wiel), met een dunne inktlijn in plaats van de
	# grijze standaardbalk.
	_inkt_balk(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	binnen.add_child(scroll)
	_paneel_scroll = scroll
	_paneel = VBoxContainer.new()
	_paneel.name = "FasePaneel"
	_paneel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paneel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_paneel.add_theme_constant_override("separation", _px(5))
	scroll.add_child(_paneel)
	# De voet (27 september): de hoofdknoppen van de fase staan altijd in
	# beeld, ook als de inhoud erboven moet scrollen.
	_voet = HBoxContainer.new()
	_voet.name = "FaseVoet"
	_voet.alignment = BoxContainer.ALIGNMENT_CENTER
	_voet.add_theme_constant_override("separation", _px(10))
	binnen.add_child(_voet)
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
	help.pressed.connect(_toon_regels)
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


## Moet de mens nu zijn testament opmaken?
func _testament_open() -> bool:
	return driver.c.fase == CState.Fase.TESTAMENT and driver.wacht_op_mens() and not _bezig \
		and driver.c.pending_testamenten.has(mens_id)


## Wie kan erven: elke levende speler behalve jijzelf, je eigen team eerst
## (de vijand mag ook, dat is een keuze).
func _erfgenamen() -> Array:
	var c: CState = driver.c
	var mijn_team: int = int(c.spelers.get(mens_id, {}).get("team", 0))
	var uit: Array = []
	for team in [mijn_team, 1 - mijn_team]:
		for sid in c.actieve_leden(team):
			if int(sid) != mens_id:
				uit.append(int(sid))
	return uit


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
	b.custom_minimum_size = Vector2(0, _u(90))
	b.tooltip_text = String(sp.naam)
	for staat in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(staat, StyleBoxEmpty.new())
	var status := _lid_status(c, sid)
	var p := HubAssets.portret(int(sp.get("doctrine", 0)), eigen, status == "dood", _u(72), status)
	p.position = Vector2(_u(25), 0)
	p.size = Vector2(_u(72), _u(72))
	var gekozen := (eigen and sid == _keuze_eigen) or (not eigen and sid == _keuze_vijand)
	# Testament (27 september): je erfgenaam kies je net als in de raad door
	# een schild in de kolommen aan te tikken.
	var testament := _testament_open()
	if testament:
		gekozen = sid == _testament_doel
	if _raad_open() or testament:
		if _raad_open() and not kandidaten.has(sid):
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
			gloed.position = Vector2(_u(21), _u(-4))
			gloed.size = Vector2(_u(80), _u(80))
			b.add_child(gloed)
	b.add_child(p)
	if sid == mens_id:
		# "JIJ" als donker lintje op je eigen schild.
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
		# Bovenaan het schild, over de ring (27 september: stond scheef ernaast).
		jij.position = Vector2(_u(46), 0)
		jij.size = Vector2(_u(30), _u(13))
		b.add_child(jij)
	# Versterkingen en CP onder het schild (25 september, Max: "per player wie
	# hoeveel CP en reinforcements hebben, vlakbij hun schild"). D12: van de
	# vijand zie je "?", tenzij je het mag zien (de doden zien alles).
	var saldo := _saldo_regel(c, sid, status == "dood")
	saldo.position = Vector2(0, _u(74))
	saldo.size = Vector2(_u(122), _u(15))
	b.add_child(saldo)
	b.pressed.connect(func() -> void:
		if _raad_open() and kandidaten.has(sid):
			if eigen:
				_keuze_eigen = sid
			else:
				_keuze_vijand = sid
			_ververs_teams()
			_bouw_fase_paneel()
		elif _testament_open() and _erfgenamen().has(sid):
			_testament_doel = sid
			_ververs_teams()
			_bouw_fase_paneel()
		else:
			_toon_lid(sid))
	return b


## De regel met tent + versterkingspunten en medaille + CP: onder een schild
## in de kolommen (ivoor) en op perkament (inkt). "?" voor wat je niet mag
## zien (D12, CView.mag_saldo_zien); leeg voor de doden.
func _saldo_regel(c: CState, sid: int, dood: bool, kleur: Color = HubAssets.IVOOR, maat: float = 9.0) -> HBoxContainer:
	var rij := HBoxContainer.new()
	rij.name = "Saldo"
	rij.alignment = BoxContainer.ALIGNMENT_CENTER
	rij.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rij.add_theme_constant_override("separation", _px(3))
	if dood:
		return rij
	var zien: bool = CView.mag_saldo_zien(c, mens_id, sid)
	var pool: Dictionary = c.pool_van(sid)
	var vst: String = str(maxi(0, int(pool.inf) + 2 * int(pool.cav) + 3 * int(pool.art))) if zien else "?"
	var cp: String = str(c.cp_van(sid)) if zien else "?"
	var tent := HubAssets.icoon("Donation_icon", _u(maat + 3.0), kleur)
	tent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rij.add_child(tent)
	var l_vst := HubAssets.tekst(vst, _px(maat), kleur, true)
	l_vst.name = "Versterkingen"
	rij.add_child(l_vst)
	var tussen := Control.new()
	tussen.custom_minimum_size = Vector2(_u(6), 0)
	tussen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rij.add_child(tussen)
	var medaille := UiAssets.icoon_rect("cp", _u(maat + 3.0), kleur)
	medaille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rij.add_child(medaille)
	var l_cp := HubAssets.tekst(cp, _px(maat), kleur, true)
	l_cp.name = "Cp"
	rij.add_child(l_cp)
	return rij


## Een naamplaatje (licht perkament, inkt-rand), zoals onder de schilden in de raad.
func _naamplaat(tekst: String, grootte: float = 8.0) -> PanelContainer:
	var plaat := PanelContainer.new()
	plaat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#EFE2C4")
	sb.border_color = HubAssets.INKT
	sb.set_border_width_all(maxi(2, _px(1.2)))
	sb.set_corner_radius_all(_px(3))
	sb.content_margin_left = _u(8)
	sb.content_margin_right = _u(8)
	sb.content_margin_top = _u(1)
	sb.content_margin_bottom = _u(1)
	plaat.add_theme_stylebox_override("panel", sb)
	var naam := HubAssets.tekst(tekst, _px(grootte), HubAssets.INKT, true)
	naam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plaat.add_child(naam)
	return plaat


## Een getal met teken: +3, -2, en 0 zonder teken.
static func _teken(n: int) -> String:
	if n > 0:
		return "+%d" % n
	if n < 0:
		return "-%d" % -n
	return "0"


## Een lege ruimte die meegroeit: zet de inhoud van een keuzescherm in het midden.
func _ruimte(kolom: VBoxContainer) -> void:
	var r := Control.new()
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kolom.add_child(r)


## Een dunne inktlijn als schuifbalk (in plaats van de grijze standaardbalk):
## je ziet dat er meer is zonder dat het ontwerp eronder lijdt. Op donker hout
## (het spelregelscherm) in ivoor.
func _inkt_balk(scroll: ScrollContainer, kleur: Color = HubAssets.INKT) -> void:
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var balk := scroll.get_v_scroll_bar()
	balk.custom_minimum_size = Vector2(_u(4), 0)
	balk.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	balk.add_theme_stylebox_override("scroll_focus", StyleBoxEmpty.new())
	for staat in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(kleur, 0.55 if staat == "grabber_pressed" else 0.35)
		sb.set_corner_radius_all(_px(2))
		sb.content_margin_left = _u(2)
		sb.content_margin_right = _u(2)
		balk.add_theme_stylebox_override(staat, sb)


## Een kleine, platte tekstknop voor een bijzaak (Blijf in de hub, Laat niets na).
func _link_knop(tekst: String, naam: String, actie: Callable) -> Button:
	var b := Button.new()
	b.name = naam
	b.text = tekst
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for staat in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(staat, StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", _px(9))
	b.add_theme_color_override("font_color", HubAssets.INKT_ZACHT)
	b.add_theme_color_override("font_hover_color", HubAssets.INKT)
	b.add_theme_color_override("font_pressed_color", HubAssets.INKT)
	var f := UiAssets.font("tekst")
	if f != null:
		b.add_theme_font_override("font", f)
	b.pressed.connect(actie)
	return b


## In de raad: zet een geldige standaardkeuze klaar (jijzelf of de eerste
## kandidaat; het eerste doelwit), en ruim een ongeldige keuze op.
func _kies_standaard() -> void:
	if _testament_open():
		var erf := _erfgenamen()
		if not erf.has(_testament_doel):
			_testament_doel = int(erf[0]) if not erf.is_empty() else -1
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
	# Chat-volgorde (25 september, Max: "van onder naar boven net als bij een
	# chat scherm"): nieuw komt onderaan, ouder schuift omhoog, en de tijdlijn
	# scrolt mee naar onder. Alleen de onderste ONTHUL_MAX nieuwe kaartjes
	# animeren, oudste eerst; de rest staat er meteen.
	var al_gezien: int = CampaignBridge.feed_gezien
	var nieuw_totaal: int = clampi(driver.feed.size() - al_gezien, 1, ONTHUL_MAX)
	# Een snelle golf (27 september): alles binnen ~0,8 s, anders staat het
	# zichtbare stuk onderaan seconden leeg.
	var vertraging_per: float = minf(0.12, 0.8 / float(nieuw_totaal))
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
			# De stemuitslag hoort voor de fasewissel die erop volgt.
			kaarten.push_front(bouwer.stemuitslag(e, _tijd_tekst(idx)))
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
			var van_onder: int = driver.feed.size() - 1 - idx
			if vers and van_onder < ONTHUL_MAX:
				kaart.modulate.a = 0.0
				var tw := (kaart as Control).create_tween()
				tw.tween_interval(0.15 + vertraging_per * float(nieuw_totaal - 1 - van_onder))
				tw.tween_property(kaart, "modulate:a", 1.0, 0.25)
	CampaignBridge.feed_gezien = maxi(CampaignBridge.feed_gezien, driver.feed.size())
	_scroll_naar_onder(_scroll)


## Naar de onderkant scrollen zodra de nieuwe kaartjes hun maat hebben (twee
## frames: de tekst in de kaartjes breekt pas af als de container staat).
func _scroll_naar_onder(scroll: ScrollContainer) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_inside_tree():
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


## F3.3-rest: het hele slagrapport in een pop-up (27 september: twee kolommen
## met schild, naam en factie, en per kant wat het duel kostte en opleverde).
func _toon_report(e: Dictionary) -> void:
	var c: CState = driver.c
	var inhoud := _popup(tr("HUB_TAG_BATTLE_REPORT"), "Rapport")
	var sub := HubAssets.tekst(tr("HUB_RAPPORT_SUB") % [int(e.ronde), int(e.cycli)], _px(10), HubAssets.INKT_ZACHT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inhoud.add_child(sub)
	var mijn_team: int = int(c.spelers.get(mens_id, {}).get("team", 0))
	var a: int = int(e.p1)
	var b: int = int(e.p2)
	if int(c.spelers[a].team) != mijn_team:
		var t := a
		a = b
		b = t
	var rij := HBoxContainer.new()
	rij.alignment = BoxContainer.ALIGNMENT_CENTER
	rij.add_theme_constant_override("separation", _px(12))
	inhoud.add_child(rij)
	rij.add_child(_rapport_kant(e, a))
	var sabels := HubAssets.icoon("Inbattle_icon", _u(34), HubAssets.INKT)
	sabels.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sabels.custom_minimum_size = Vector2(_u(34), _u(70))
	rij.add_child(sabels)
	rij.add_child(_rapport_kant(e, b))
	var w: int = int(e.get("winnaar", -1))
	if w >= 0:
		var slot := HubAssets.tekst(tr("HUB_RAPPORT_WINT") % [String(c.spelers[w].naam),
			_methode_tekst(String(e.get("methode", "")))], _px(12), HubAssets.INKT, true)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inhoud.add_child(slot)


## Een kant van het slagrapport: schild (goud lintje voor de winnaar), naam,
## factie, en wat het duel kostte en opleverde: reserve ingezet, buit, CP en
## wie er op het bord sneuvelde.
func _rapport_kant(e: Dictionary, sid: int) -> Control:
	var c: CState = driver.c
	var sp: Dictionary = c.spelers[sid]
	var mijn_team: int = int(c.spelers.get(mens_id, {}).get("team", 0))
	var kolom := VBoxContainer.new()
	kolom.custom_minimum_size = Vector2(_u(180), 0)
	kolom.add_theme_constant_override("separation", _px(3))
	var p := HubAssets.portret(int(sp.get("doctrine", 0)), int(sp.team) == mijn_team,
		String(sp.status) != "actief", _u(64))
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	kolom.add_child(p)
	var plaat := _naamplaat(String(sp.naam), 10)
	plaat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	kolom.add_child(plaat)
	var factie := HubAssets.tekst(Constants.doctrine_display_name(int(sp.get("doctrine", 0))).to_upper(),
		_px(7), HubAssets.INKT_ZACHT, true)
	factie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolom.add_child(factie)
	# WINNAAR of een lege regel: dan staan de regels van beide kanten gelijk.
	var winnaar: bool = int(e.get("winnaar", -1)) == sid
	var lint := HubAssets.tekst(tr("HUB_WINNAAR") if winnaar else " ", _px(8),
		UiAssets.SELECTIE_GOUD.darkened(0.35), true)
	lint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolom.add_child(lint)
	var z: Dictionary = (e.get("inzet", {}) as Dictionary).get(str(sid), {})
	var kosten: int = int(z.get("inf", 0)) + 2 * int(z.get("cav", 0)) + 3 * int(z.get("art", 0))
	var buit: int = int((e.get("buit", {}) as Dictionary).get(str(sid), 0))
	var cp: int = int((e.get("cp_delta", {}) as Dictionary).get(str(sid), 0))
	kolom.add_child(_rapport_regel("hub:Donation_icon", tr("HUB_RAPPORT_INZET"), _teken(-kosten)))
	kolom.add_child(_rapport_regel("hub:Donation_icon", tr("HUB_RAPPORT_BUIT"), _teken(buit)))
	kolom.add_child(_rapport_regel("cp", tr("HUB_RAPPORT_CP"), _teken(cp)))
	var v: Dictionary = (e.get("verliezen", {}) as Dictionary).get(str(sid), {})
	var dood := HBoxContainer.new()
	dood.alignment = BoxContainer.ALIGNMENT_CENTER
	dood.add_theme_constant_override("separation", _px(3))
	var kop := HubAssets.tekst(tr("HUB_RAPPORT_GESNEUVELD"), _px(7), HubAssets.INKT_ZACHT)
	kolom.add_child(kop)
	kop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for spec in [["unit-infantry", "inf"], ["unit-cavalry", "cav"], ["unit-artillery", "art"]]:
		var n: int = int(v.get(String(spec[1]), 0))
		var ic := UiAssets.icoon_rect(String(spec[0]), _u(14), HubAssets.INKT)
		dood.add_child(ic)
		dood.add_child(HubAssets.tekst(str(n), _px(9), HubAssets.INKT, true))
	kolom.add_child(dood)
	return kolom


## Een regel in het rapport: icoon, wat het is, en het getal rechts.
func _rapport_regel(icoon: String, label: String, waarde: String) -> Control:
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", _px(4))
	var ic: TextureRect
	if icoon.begins_with("hub:"):
		ic = HubAssets.icoon(icoon.substr(4), _u(13), HubAssets.INKT)
	else:
		ic = UiAssets.icoon_rect(icoon, _u(13), HubAssets.INKT)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rij.add_child(ic)
	var l := HubAssets.tekst(label, _px(8), HubAssets.INKT_ZACHT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rij.add_child(l)
	rij.add_child(HubAssets.tekst(waarde, _px(10), HubAssets.INKT, true))
	return rij


## De winmethode in gewone taal.
func _methode_tekst(m: String) -> String:
	match m:
		"haven":
			return tr("HUB_METHOD_HARBOR")
		"eliminatie":
			return tr("HUB_METHOD_ELIMINATION")
		"resign":
			return tr("HUB_METHOD_RESIGN")
		"honger":
			return tr("HUB_METHOD_HUNGER")
	return m


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
	HubAssets.knop(b, "buttons/Quickchat_pop-up_button", Vector2(40, 40), Vector4(_u(24), 0, _u(24), 0))
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
	var titels := {"HUB_QC_STUUR": "HUB_QC_WIE_STUUR", "HUB_QC_PAK": "HUB_QC_WIE_PAK",
		"HUB_QC_DONEER": "HUB_QC_WIE_DONEER"}
	var inhoud := _popup(tr(String(titels.get(sleutel, sleutel))).replace("%s", "..."), "QcDoel")
	if kandidaten.is_empty():
		var leeg := HubAssets.tekst(tr("HUB_QC_NIEMAND"), _px(11), HubAssets.INKT_ZACHT)
		leeg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inhoud.add_child(leeg)
		return
	var midden := CenterContainer.new()
	inhoud.add_child(midden)
	var raster := GridContainer.new()
	raster.columns = mini(4, kandidaten.size())
	raster.add_theme_constant_override("h_separation", _px(8))
	raster.add_theme_constant_override("v_separation", _px(8))
	midden.add_child(raster)
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


## Het spelregelscherm (29 september, Max: "een UI conforme spelregel scherm",
## "simpele taal en zo weinig mogelijk tekst", "en iconen wel gebruiken"): de
## ? in de titelbalk en de link op de factiekeuze. Alle campagneregels op
## kaarten met iconen, in de stijl van de hub; sluiten met de X.
func _toon_regels() -> void:
	var kolom := _keuze_scherm(tr("HUB_RULES_TITLE"), "Spelregels")
	var laag := _keuze_laag
	var sluit := _rond_knop("Close_icon", "RegelsSluit")
	sluit.position = Vector2(_u(506), _u(18))
	sluit.size = Vector2(_u(40), _u(40))
	kolom.get_parent().add_child(sluit)
	sluit.pressed.connect(func() -> void: _sluit_keuze(laag))
	var scroll := ScrollContainer.new()
	scroll.name = "RegelsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inkt_balk(scroll, HubAssets.IVOOR)
	kolom.add_child(scroll)
	# Voor de eerste campagne (factiekeuze) is er nog geen driver: dan de standaardregels.
	var regels: CRules = driver.c.rules if driver != null else CRules.new()
	scroll.add_child(HubRegels.new(regels, _s).bouw())


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


## Tik op een schild: wie het is (factie, stand, tegen wie hij vecht) en wat
## hij heeft; "?" voor wat je niet mag zien (D12).
func _toon_lid(sid: int) -> void:
	var c: CState = driver.c
	var sp: Dictionary = c.spelers[sid]
	var mijn_team: int = int(c.spelers.get(mens_id, {}).get("team", 0))
	var naam := String(sp.naam) + (tr("HUB_YOU_SUFFIX") if sid == mens_id else "")
	var inhoud := _popup(naam, "LidInfo")
	var status := _lid_status(c, sid)
	var rij := HBoxContainer.new()
	rij.alignment = BoxContainer.ALIGNMENT_CENTER
	rij.add_theme_constant_override("separation", _px(16))
	inhoud.add_child(rij)
	var p := HubAssets.portret(int(sp.get("doctrine", 0)), int(sp.team) == mijn_team, status == "dood",
		_u(100), status)
	rij.add_child(p)
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", _px(5))
	rij.add_child(info)
	info.add_child(HubAssets.tekst(Constants.doctrine_display_name(int(sp.get("doctrine", 0))).to_upper(),
		_px(12), HubAssets.INKT, true))
	info.add_child(HubAssets.tekst(tr("HUB_STATUS_" + status.to_upper()), _px(10), HubAssets.INKT_ZACHT))
	for duel in c.duels_deze_ronde:
		if not bool(duel.klaar) and (int(duel.p1) == sid or int(duel.p2) == sid):
			var tegen: int = int(duel.p2) if int(duel.p1) == sid else int(duel.p1)
			info.add_child(HubAssets.tekst(tr("HUB_LID_VECHT") % String(c.spelers[tegen].naam),
				_px(10), HubAssets.INKT))
	if status != "dood":
		var saldo := _saldo_regel(c, sid, false, HubAssets.INKT, 11.0)
		saldo.alignment = BoxContainer.ALIGNMENT_BEGIN
		var tussen := Control.new()
		tussen.custom_minimum_size = Vector2(_u(6), 0)
		saldo.add_child(tussen)
		var ster := UiAssets.icoon_rect("score", _u(14), HubAssets.INKT)
		ster.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		saldo.add_child(ster)
		saldo.add_child(HubAssets.tekst(str(c.punten_van(sid)), _px(11), HubAssets.INKT, true))
		info.add_child(saldo)


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
	for n in berichten.size():
		var idx: int = berichten[n]
		var e: Dictionary = _chat_e.get(idx, {})
		var nieuw: bool = n >= _chat_gezien
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
	_scroll_naar_onder(_paneel_scroll)


## Klokje van een bericht ("14:30"), lokale tijd.
func _klok(idx: int) -> String:
	var t: int = int(_feed_tijd.get(idx, Time.get_unix_time_from_system()))
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(t + bias)
	return "%02d:%02d" % [int(d.hour), int(d.minute)]


# --- Fasepaneel -------------------------------------------------------------------

func _wis_paneel() -> void:
	for houder in [_paneel, _voet]:
		for kind in houder.get_children():
			houder.remove_child(kind)
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
	if not driver.wacht_op_mens():
		if c.fase == CState.Fase.BURGEROORLOG:
			_paneel_burgeroorlog(c)
		var rij := HBoxContainer.new()
		rij.alignment = BoxContainer.ALIGNMENT_CENTER
		rij.add_theme_constant_override("separation", _px(8))
		rij.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var zandloper := HubAssets.icoon("Phase_icon", _u(18), HubAssets.INKT)
		zandloper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		zandloper.pivot_offset = Vector2(_u(9), _u(9))
		if _bezig:
			# Zolang de bots bezig zijn draait de zandloper om.
			var tw := zandloper.create_tween().set_loops()
			tw.tween_property(zandloper, "rotation", PI, 0.5).from(0.0)
			tw.tween_interval(0.35)
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
## 27 september: kampioen met de samenvatting ernaast, de top drie op een rij
## en de knoppen in de voet.
func _paneel_einde(c: CState) -> void:
	var kampioen: Dictionary = c.spelers.get(c.winnaar, {})
	var mijn_team: int = int(c.spelers.get(mens_id, {}).get("team", 0))
	var kop := HBoxContainer.new()
	kop.alignment = BoxContainer.ALIGNMENT_CENTER
	kop.add_theme_constant_override("separation", _px(10))
	if not kampioen.is_empty():
		kop.add_child(HubAssets.portret(int(kampioen.get("doctrine", 0)),
			int(kampioen.get("team", 0)) == mijn_team, false, _u(46)))
	var tekst := VBoxContainer.new()
	tekst.alignment = BoxContainer.ALIGNMENT_CENTER
	tekst.add_theme_constant_override("separation", 0)
	var titel := HubAssets.tekst(tr("HUB_END_CHAMPION") % String(kampioen.get("naam", "?")), _px(14), HubAssets.INKT, true)
	titel.name = "EindTitel"
	tekst.add_child(titel)
	var mijn_punten: int = c.punten_van(mens_id)
	var plek: int = 1
	for id in c.spelers:
		if c.punten_van(int(id)) > mijn_punten:
			plek += 1
	var samen := HubAssets.tekst(tr("HUB_END_SUMMARY") % [c.ronde, driver.duels_gespeeld, mijn_punten, plek,
		c.spelers.size()], _px(8), HubAssets.INKT_ZACHT)
	samen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	samen.custom_minimum_size = Vector2(_u(320), 0)
	tekst.add_child(samen)
	kop.add_child(tekst)
	_paneel.add_child(kop)
	# De top drie op roem: schild, plek en naam, roem.
	var top: Array = LedgerScreen.rijen(c, "punten")
	var podium := HBoxContainer.new()
	podium.name = "Podium"
	podium.alignment = BoxContainer.ALIGNMENT_CENTER
	podium.add_theme_constant_override("separation", _px(22))
	for i in mini(3, top.size()):
		var sp: Dictionary = c.spelers.get(int(top[i].id), {})
		var vak := HBoxContainer.new()
		vak.add_theme_constant_override("separation", _px(4))
		var p := HubAssets.portret(int(sp.get("doctrine", 0)), int(sp.get("team", 0)) == mijn_team,
			String(sp.get("status", "actief")) != "actief", _u(28))
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vak.add_child(p)
		var info := VBoxContainer.new()
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.add_theme_constant_override("separation", 0)
		info.add_child(HubAssets.tekst("%d. %s" % [i + 1, String(top[i].naam)], _px(8),
			HubAssets.ROOD if int(top[i].id) == mens_id else HubAssets.INKT, true))
		var roem := HBoxContainer.new()
		roem.add_theme_constant_override("separation", _px(3))
		roem.add_child(UiAssets.icoon_rect("score", _u(10), HubAssets.INKT))
		roem.add_child(HubAssets.tekst(str(int(top[i].punten)), _px(8), HubAssets.INKT, true))
		info.add_child(roem)
		vak.add_child(info)
		podium.add_child(vak)
	_paneel.add_child(podium)
	var grootboek := _knop(tr("HUB_END_LEDGER_BTN"), "score", _toon_grootboek)
	grootboek.name = "GrootboekEindKnop"
	_voet.add_child(grootboek)
	var opnieuw := _rode_knop(tr("HUB_END_NEW_CAPS"), "NieuweCampagneKnop", func() -> void:
		if FileAccess.file_exists(SAVE_PAD):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PAD))
		CampaignBridge.driver = null
		CampaignBridge.feed_gezien = 0
		get_tree().reload_current_scene())
	opnieuw.custom_minimum_size = Vector2(_u(200), _u(40))
	_voet.add_child(opnieuw)


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
## UX (27 juli, Max): de mens heeft voorrang op de bot-simulaties, en het duel
## start na een korte aftel vanzelf met een laadscherm; "Blijf in de hub"
## annuleert de auto-start. 27 september: jij tegen hem met schild, naam,
## factie en saldo; de rode knop met een aftelbalk in de voet; de andere paren
## van de ronde klein eronder.
func _paneel_duel(c: CState) -> void:
	var d: Dictionary = driver.mens_duel()
	if d.is_empty():
		return
	var vijand: int = int(d.p2) if int(d.p1) == mens_id else int(d.p1)
	var burgeroorlog: bool = c.fase == CState.Fase.BURGEROORLOG
	var kop: String = tr("HUB_DUEL_KOP")
	if burgeroorlog:
		kop = "%s: %s" % [tr("HUB_PHASE_SHORT_CIVIL_WAR"), kop]
	_paneel.add_child(_kop_met_sierlijn(kop, 10, 44))
	_paneel.add_child(_vs_rij(c, vijand))
	# In de burgeroorlog: wie er nog in de strijd is, in plaats van de uitleg.
	_paneel_tekst(_nog_in_strijd(c) if burgeroorlog else tr("HUB_DUEL_UITLEG"), 7.5, HubAssets.INKT_ZACHT)
	# De voet: de rode knop, met de aftel eronder zolang die loopt, en rechts
	# de bijzaken als tekstknop (blijven, de andere paren bekijken).
	var knop_kolom := VBoxContainer.new()
	knop_kolom.add_theme_constant_override("separation", _px(3))
	_voet.add_child(knop_kolom)
	var speel := _rode_knop(tr("HUB_DUEL_PLAY_CAPS"), "SpeelDuelKnop", func() -> void:
		_start_mens_duel(vijand))
	speel.custom_minimum_size = Vector2(_u(210), _u(40))
	knop_kolom.add_child(speel)
	var links := VBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 0)
	_voet.add_child(links)
	if _auto_stop_idx != int(d.idx):
		if _auto_start_idx != int(d.idx):
			_auto_start_idx = int(d.idx)
			_auto_start_ms = Time.get_ticks_msec()
			_auto_start_duel(int(d.idx), vijand)
		knop_kolom.add_child(Aftel.new(_auto_start_ms, 2500, _u(8)))
		links.add_child(_link_knop(tr("HUB_DUEL_STAY_BTN"), "BlijfKnop", func() -> void:
			_auto_stop_idx = int(d.idx)
			_bouw_fase_paneel()))
	# In de burgeroorlog staat de bracket er al boven.
	if c.fase != CState.Fase.BURGEROORLOG and c.duels_deze_ronde.size() > 1:
		links.add_child(_link_knop(tr("HUB_DUEL_PAREN_LINK") % (c.duels_deze_ronde.size() - 1),
			"ParenKnop", _toon_paren))


## De burgeroorlog terwijl jij niet aan zet bent (27 september, was de
## BracketView van de veldtafel): de paren van deze knock-outronde en wie er
## nog in de strijd is.
func _paneel_burgeroorlog(c: CState) -> void:
	_paneel.add_child(_kop_met_sierlijn(tr("HUB_PHASE_SHORT_CIVIL_WAR"), 10, 40))
	var midden := CenterContainer.new()
	_paneel.add_child(midden)
	var raster := GridContainer.new()
	raster.name = "Bracket"
	raster.columns = 2
	raster.add_theme_constant_override("h_separation", _px(22))
	raster.add_theme_constant_override("v_separation", _px(4))
	midden.add_child(raster)
	for duel in c.duels_deze_ronde:
		raster.add_child(_paar_regel(c, duel))
	_paneel_tekst(_nog_in_strijd(c), 7.5, HubAssets.INKT_ZACHT)


## "Nog in de strijd: Max, Piet" (de levende deelnemers van de burgeroorlog).
func _nog_in_strijd(c: CState) -> String:
	var over: Array = []
	for sid in c.spelers:
		if String(c.spelers[sid].status) == "actief":
			over.append(String(c.spelers[sid].naam))
	return tr("BRACKET_REMAINING") % ", ".join(over)


## Alle paren van deze ronde in een venster: twee schildjes met de namen, en
## of het duel al gespeeld is (vinkje) of nog loopt (zandloper).
func _toon_paren() -> void:
	var c: CState = driver.c
	var inhoud := _popup(tr("HUB_DUEL_PAIRS_TITLE"), "Paren")
	var midden := CenterContainer.new()
	inhoud.add_child(midden)
	var raster := GridContainer.new()
	raster.columns = 2
	raster.add_theme_constant_override("h_separation", _px(22))
	raster.add_theme_constant_override("v_separation", _px(8))
	midden.add_child(raster)
	for duel in c.duels_deze_ronde:
		raster.add_child(_paar_regel(c, duel))


## Jij tegen hem, gespiegeld om de sabels: schild met ernaast naam, factie en
## saldo; de tekst staat aan de kant van de sabels.
func _vs_rij(c: CState, vijand: int, portret: float = 54.0) -> HBoxContainer:
	var rij := HBoxContainer.new()
	rij.alignment = BoxContainer.ALIGNMENT_CENTER
	rij.add_theme_constant_override("separation", _px(10))
	rij.add_child(_duel_kant(c, mens_id, true, portret))
	var sabels := HubAssets.icoon("Inbattle_icon", _u(30), HubAssets.INKT)
	sabels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rij.add_child(sabels)
	rij.add_child(_duel_kant(c, vijand, false, portret))
	return rij


func _duel_kant(c: CState, sid: int, eigen: bool, portret: float) -> Control:
	var sp: Dictionary = c.spelers[sid]
	var kant := HBoxContainer.new()
	kant.add_theme_constant_override("separation", _px(6))
	var p := HubAssets.portret(int(sp.get("doctrine", 0)), eigen, false, _u(portret))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.custom_minimum_size = Vector2(_u(104), 0)
	info.add_theme_constant_override("separation", _px(2))
	var plaat := _naamplaat(String(sp.naam), 9)
	plaat.size_flags_horizontal = Control.SIZE_SHRINK_END if eigen else Control.SIZE_SHRINK_BEGIN
	info.add_child(plaat)
	var factie := HubAssets.tekst(Constants.doctrine_display_name(int(sp.get("doctrine", 0))).to_upper(),
		_px(7), HubAssets.INKT_ZACHT, true)
	factie.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if eigen else HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(factie)
	var saldo := _saldo_regel(c, sid, false, HubAssets.INKT, 8.0)
	saldo.alignment = BoxContainer.ALIGNMENT_END if eigen else BoxContainer.ALIGNMENT_BEGIN
	info.add_child(saldo)
	if eigen:
		kant.add_child(info)
		kant.add_child(p)
	else:
		kant.add_child(p)
		kant.add_child(info)
	return kant


## Een paar van deze ronde: twee schildjes met de namen (jouw paar in rood),
## en of het al gespeeld is (vinkje) of nog loopt (zandloper).
func _paar_regel(c: CState, duel: Dictionary) -> Control:
	var mijn_team: int = int(c.spelers.get(mens_id, {}).get("team", 0))
	var van_mij: bool = int(duel.p1) == mens_id or int(duel.p2) == mens_id
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", _px(4))
	for kant in [int(duel.p1), int(duel.p2)]:
		var sp: Dictionary = c.spelers[kant]
		var p := HubAssets.portret(int(sp.get("doctrine", 0)), int(sp.team) == mijn_team,
			String(sp.status) != "actief", _u(26))
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rij.add_child(p)
		var l := HubAssets.tekst(String(sp.naam), _px(10), HubAssets.ROOD if van_mij else HubAssets.INKT, van_mij)
		l.custom_minimum_size = Vector2(_u(58), 0)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rij.add_child(l)
	var klaar: bool = bool(duel.klaar)
	var ic: TextureRect
	if klaar:
		ic = UiAssets.icoon_rect("check", _u(14), HubAssets.INKT)
	else:
		ic = HubAssets.icoon("Phase_icon", _u(14), HubAssets.INKT_ZACHT)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rij.add_child(ic)
	return rij


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
	_toon_lader(vijand)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/game/game.tscn")


## Het laadscherm voor je duel, in de stijl van de hub (27 september): jij
## tegen hem met schild, naam, factie en saldo, en de regel dat het laadt.
func _toon_lader(vijand: int) -> void:
	var kolom := _keuze_scherm(tr("HUB_DUEL_KOP"), "Lader")
	_ruimte(kolom)
	var kaart := PanelContainer.new()
	kaart.add_theme_stylebox_override("panel", HubAssets.patch("frames_box/Timeline_action_box_2",
		Vector2(26, 26), Vector4(_u(18), _u(18), _u(18), _u(18))))
	kolom.add_child(kaart)
	var binnen := VBoxContainer.new()
	binnen.add_theme_constant_override("separation", _px(14))
	kaart.add_child(binnen)
	binnen.add_child(_vs_rij(driver.c, vijand, 72.0))
	var tekst := HubAssets.tekst(tr("HUB_DUEL_LOADING") % String(driver.c.spelers[vijand].naam),
		_px(12), HubAssets.INKT, true)
	tekst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	binnen.add_child(tekst)
	_ruimte(kolom)


## C11-UX (Max): doneren = een plusje achter de naam. [+1] geeft 1
## versterkingspunt (1 soldaat), [+CP] geeft 1 CP; caps bewaakt de reducer.
## 27 september: per teamgenoot zijn saldo en wat hij deze ronde al kreeg; de
## knoppen Ruil en KLAAR staan in de voet (KLAAR is de hoofdactie).
func _paneel_donatie(c: CState) -> void:
	_paneel.add_child(_kop_met_sierlijn(tr("HUB_DONATE_SHORT"), 10, 40))
	_paneel_tekst(tr("HUB_DONATE_HINT_KORT") % [c.rules.donatie_cap_pionnen, c.rules.donatie_cap_cp],
		7.5, HubAssets.INKT_ZACHT)
	var mijn_team: int = int(c.spelers[mens_id].team)
	var mijn_pool: Dictionary = c.pool_van(mens_id)
	var mijn_cp: int = c.cp_van(mens_id)
	for sid in c.actieve_leden(mijn_team):
		if int(sid) == mens_id:
			continue
		var doel: int = int(sid)
		var sp: Dictionary = c.spelers[doel]
		var ontvangen: Dictionary = c.donaties_ontvangen.get(doel, {"pionnen": 0, "cp": 0})
		var rij := HBoxContainer.new()
		rij.add_theme_constant_override("separation", _px(8))
		var p := HubAssets.portret(int(sp.get("doctrine", 0)), true, false, _u(32))
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rij.add_child(p)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		var naam := HubAssets.tekst(String(sp.naam), _px(9), HubAssets.INKT, true)
		naam.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info.add_child(naam)
		var regel := HBoxContainer.new()
		regel.add_theme_constant_override("separation", _px(8))
		var saldo := _saldo_regel(c, doel, false, HubAssets.INKT, 7.5)
		saldo.alignment = BoxContainer.ALIGNMENT_BEGIN
		regel.add_child(saldo)
		regel.add_child(HubAssets.tekst(tr("HUB_DONATE_ONTVANGEN") % [int(ontvangen.pionnen),
			c.rules.donatie_cap_pionnen, int(ontvangen.cp), c.rules.donatie_cap_cp], _px(7), HubAssets.INKT_ZACHT))
		info.add_child(regel)
		rij.add_child(info)
		var plus := _chat_knop(tr("HUB_PLUS_VST"), "Donation_icon", 9)
		plus.custom_minimum_size = Vector2(_u(58), _u(32))
		plus.disabled = int(mijn_pool.inf) <= 0 or int(ontvangen.pionnen) >= c.rules.donatie_cap_pionnen
		plus.pressed.connect(func() -> void:
			if driver.submit_mens_donatie(doel, 1, 0, 0, 0):
				_ververs())
		rij.add_child(plus)
		var plus_cp := _chat_knop(tr("HUB_PLUS_CP"), "ui:cp", 9)
		plus_cp.custom_minimum_size = Vector2(_u(58), _u(32))
		plus_cp.disabled = mijn_cp <= 0 or int(ontvangen.cp) >= c.rules.donatie_cap_cp
		plus_cp.pressed.connect(func() -> void:
			if driver.submit_mens_donatie(doel, 0, 0, 0, 1):
				_ververs())
		rij.add_child(plus_cp)
		_paneel.add_child(rij)
	var koers: int = maxi(1, c.rules.ruil_cp_per_punt)
	var ruil := _knop(tr("HUB_RUIL_BTN") % koers, "cp", func() -> void:
		if driver.submit_mens_ruil(koers):
			_ververs())
	ruil.name = "RuilKnop"
	ruil.disabled = mijn_cp < koers
	_voet.add_child(ruil)
	var klaar := _rode_knop(tr("HUB_DONATE_KLAAR"), "KlaarKnop", func() -> void:
		driver.submit_mens_klaar_met_doneren()
		_werk_door())
	klaar.custom_minimum_size = Vector2(_u(160), _u(40))
	_voet.add_child(klaar)


## Het testament (27 september): wat de helft van je bezit is, en aan wie. De
## erfgenaam kies je door een schild in de kolommen aan te tikken (of het schild
## hier: volgende), net als in de raad; de vijand mag ook. In de voet
## NALATEN AAN <naam> of niets nalaten.
func _paneel_testament(c: CState) -> void:
	_paneel.add_child(_kop_met_sierlijn(tr("HUB_TAG_TESTAMENT"), 10, 40))
	_paneel_tekst(tr("HUB_WILL_UITLEG"), 7.5)
	# Precies wat de reducer toestaat (testament_fractie per type, nooit onder nul).
	var bezit: Dictionary = c.pool_van(mens_id)
	var f: float = c.rules.testament_fractie
	var helft := {"inf": maxi(0, int(floor(int(bezit.inf) * f))), "cav": maxi(0, int(floor(int(bezit.cav) * f))),
		"art": maxi(0, int(floor(int(bezit.art) * f)))}
	var helft_cp: int = maxi(0, int(floor(c.cp_van(mens_id) * f)))
	var kandidaten := _erfgenamen()
	if not kandidaten.has(_testament_doel):
		_testament_doel = int(kandidaten[0]) if not kandidaten.is_empty() else -1
	var rij := HBoxContainer.new()
	rij.alignment = BoxContainer.ALIGNMENT_CENTER
	rij.add_theme_constant_override("separation", _px(16))
	_paneel.add_child(rij)
	# Links wat je nalaat.
	var wat := VBoxContainer.new()
	wat.alignment = BoxContainer.ALIGNMENT_CENTER
	wat.add_theme_constant_override("separation", _px(2))
	var kop := HubAssets.tekst(tr("HUB_WILL_HELFT"), _px(8), HubAssets.INKT_ZACHT, true)
	kop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wat.add_child(kop)
	var getallen := HBoxContainer.new()
	getallen.name = "Nalatenschap"
	getallen.alignment = BoxContainer.ALIGNMENT_CENTER
	getallen.add_theme_constant_override("separation", _px(4))
	getallen.add_child(HubAssets.icoon("Donation_icon", _u(18), HubAssets.INKT))
	getallen.add_child(HubAssets.tekst(str(int(helft.inf) + 2 * int(helft.cav) + 3 * int(helft.art)),
		_px(14), HubAssets.INKT, true))
	var tussen := Control.new()
	tussen.custom_minimum_size = Vector2(_u(8), 0)
	getallen.add_child(tussen)
	getallen.add_child(UiAssets.icoon_rect("cp", _u(18), HubAssets.INKT))
	getallen.add_child(HubAssets.tekst(str(helft_cp), _px(14), HubAssets.INKT, true))
	wat.add_child(getallen)
	rij.add_child(wat)
	var pijl := HubAssets.icoon("Arrow_icon", _u(30))
	pijl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pijl.custom_minimum_size = Vector2(_u(30), _u(48))
	rij.add_child(pijl)
	# Rechts de erfgenaam.
	rij.add_child(_erfgenaam_keuze(c, kandidaten))
	var niets := _link_knop(tr("HUB_WILL_NONE_BTN"), "NietsNalaten", func() -> void:
		driver.submit_mens_testament([])
		_werk_door())
	niets.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_voet.add_child(niets)
	if _testament_doel >= 0:
		var naar: int = _testament_doel
		var geef := _rode_knop(tr("HUB_WILL_NAAR") % String(c.spelers[naar].naam).to_upper(), "NalatenKnop", func() -> void:
			driver.submit_mens_testament([{"naar": naar, "inf": int(helft.inf), "cav": int(helft.cav),
				"art": int(helft.art), "cp": helft_cp}])
			_werk_door())
		geef.custom_minimum_size = Vector2(_u(230), _u(40))
		_voet.add_child(geef)


## De erfgenaam in het testamentpaneel: schild (tik = volgende kandidaat),
## naamplaatje en ERFGENAAM, zoals de keuzes in de raad.
func _erfgenaam_keuze(c: CState, kandidaten: Array) -> Control:
	var kolom := VBoxContainer.new()
	kolom.name = "Erfgenaam"
	kolom.add_theme_constant_override("separation", _px(2))
	var mijn_team: int = int(c.spelers[mens_id].team)
	var knop := Button.new()
	knop.flat = true
	knop.focus_mode = Control.FOCUS_NONE
	knop.custom_minimum_size = Vector2(_u(48), _u(48))
	knop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for staat in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		knop.add_theme_stylebox_override(staat, StyleBoxEmpty.new())
	if _testament_doel >= 0:
		var sp: Dictionary = c.spelers[_testament_doel]
		var p := HubAssets.portret(int(sp.get("doctrine", 0)), int(sp.team) == mijn_team, false, _u(48))
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		knop.add_child(p)
	knop.pressed.connect(func() -> void:
		if kandidaten.is_empty():
			return
		_testament_doel = int(kandidaten[(kandidaten.find(_testament_doel) + 1) % kandidaten.size()])
		_ververs_teams()
		_bouw_fase_paneel())
	kolom.add_child(knop)
	var plaat := _naamplaat(String(c.spelers[_testament_doel].naam) if _testament_doel >= 0 else "-", 8)
	plaat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	kolom.add_child(plaat)
	var rol := HubAssets.tekst(tr("HUB_WILL_ERFGENAAM"), _px(6.5), HubAssets.INKT_ZACHT, true)
	rol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolom.add_child(rol)
	return kolom


## Een aftelbalk die van vol naar leeg loopt, gerekend vanaf `start_ms`: dan
## loopt hij gewoon door als het paneel opnieuw wordt opgebouwd.
class Aftel:
	extends Control
	var start_ms: int
	var duur_ms: int
	var _vul: TextureRect

	func _init(p_start: int, p_duur: int, hoogte: float) -> void:
		start_ms = p_start
		duur_ms = maxi(1, p_duur)
		name = "Aftel"
		custom_minimum_size = Vector2(0, hoogte)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var achter := HubAssets.plaat("nominate/Loading_bar_BG")
		achter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(achter)
		_vul = HubAssets.plaat("nominate/Loading_bar")
		_vul.anchor_bottom = 1.0
		add_child(_vul)

	func _process(_delta: float) -> void:
		var rest: float = clampf(1.0 - float(Time.get_ticks_msec() - start_ms) / float(duur_ms), 0.0, 1.0)
		_vul.anchor_right = rest
		_vul.offset_right = 0.0
