class_name CampaignHub
extends Control

# F3.3: de CampagneHub: tijdlijn ("Among Us-gevoel"), eigen saldi en het
# fase-paneel (raad / doneren / testament) in één mobile-first scherm.
# Leest UITSLUITEND de cview + de feed; alle mens-acties gaan via de
# SoloDriver-submits. Bot-werk (incl. duels) draait op een thread zodat de
# UI niet bevriest.
#
# UI-assetpack (3 september 2026): het scherm ligt op de veldtafel (donker
# hout) met de perkamenten panelen uit het pack. Tekst op de veldtafel is
# ivoor, tekst op perkament is inkt; leden zijn portretten (embleem in een
# krans in teamkleur) in plaats van bolletjes, saldi staan als icoon + getal.
# Alleen presentatie: geen submit, timer of await is verplaatst.

var driver: SoloDriver
var mens_id: int = 0

## F3.4: vaste solo-savegame-slot; elke campagne-actie staat direct op schijf.
const SAVE_PAD := "user://campaigns/solo/campagne.jsonl"

var _header: Label
var _saldi: Label
var _saldi_pool: UiIcoonTekst
var _saldi_cp: UiIcoonTekst
var _saldi_score: UiIcoonTekst
var _team_links: VBoxContainer
var _team_rechts: VBoxContainer
var _tijdlijn: VBoxContainer
var _scroll: ScrollContainer
var _paneel: VBoxContainer
var _papier_inhoud: VBoxContainer = null   # de inhoud van het perkament in het fasepaneel
var _thread: Thread
var _bezig: bool = false
var _feed_getoond: int = 0
var _auto_start_idx: int = -1   # duel-idx waarvoor de auto-start-aftel loopt
var _auto_stop_idx: int = -1    # duel-idx waarvoor de mens de auto-start annuleerde
var _duel_start_bezig: bool = false
var _info_label: Label = null

## Bot-duels in de hub: "easy": eval-gedreven (bloedig, dus de campagne-
## attritie werkt) én snel (seconden per duel; de hang zat specifiek in
## "medium", dat naar de 3000-stappen-noodstop verdedigt). NIET "l1": de
## haven-rusher wint zonder slachtoffers, waardoor niemand ooit door zijn
## pool zakt en de campagne nooit convergeert (test-bevinding 27 juli).
const BOT_DUEL_AI := "easy"
## Vangnet tegen incidentele grind-duels tussen bots; het mens-duel op het
## echte bord behoudt cycluslimiet 0 (besluit 26 juli).
const BOT_DUEL_HONGER_VANAF := 10

## Jouw team is altijd blauw, de vijand rood (portretkransen, feed-kaartjes),
## ongeacht het teamnummer. Tekstkleuren op de veldtafel: de lichte varianten.
const KLEUR_EIGEN := UiAssets.TEAM_BLAUW_LICHT
const KLEUR_VIJAND := UiAssets.TEAM_ROOD_LICHT
const KLEUR_DOOD := UiAssets.OUD_BRUIN
## Duimmaat (contract §1): primaire knoppen minimaal 84 px hoog op 1080 breed.
const KNOP_HOOGTE := 84.0
## Buitenrand van het scherm en tussenruimte tussen de blokken.
const RAND := 20.0
## Meer donatie-rijen dan dit scrollen, zodat het fasepaneel de tijdlijn niet
## van het scherm drukt.
const DONATIE_RIJEN_ZICHTBAAR := 4


func _ready() -> void:
	# Iconen (500 px) en 9-patches worden fors verkleind: mipmaps voor het
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


# --- Bouwstenen (alleen presentatie) ---------------------------------------------

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


## Een grote duimknop buiten het fasepaneel (keuzeschermen). De callable
## staat achteraan zodat een meerregelige lambda het laatste argument is.
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


## Portret op de VELDTAFEL: het embleem is een inkt-gravure (zwart op
## transparant) en verdwijnt op donker hout. Daarom een perkamenten
## medaillon achter de krans-opening, zoals de emblemen in de pdf op licht
## papier staan. Op perkament (fasepaneel, grootboek) is dit niet nodig.
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


## "blauw" voor jouw team, "rood" voor de vijand (kransen en kaartjes).
func _kant(team: int) -> String:
	var mijn_team: int = int(driver.c.spelers.get(mens_id, {}).get("team", 0))
	return "blauw" if team == mijn_team else "rood"


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
	CampaignBridge.driver = driver
	_bouw_layout()
	_ververs()
	_werk_door()


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


func _bouw_layout() -> void:
	_vul_scherm(self)
	add_child(_veldtafel())
	var kolom := VBoxContainer.new()
	_vul_scherm(kolom)
	kolom.offset_left = RAND
	kolom.offset_right = -RAND
	kolom.offset_top = 16
	kolom.offset_bottom = -16
	kolom.add_theme_constant_override("separation", 12)
	add_child(kolom)
	# De kop: een brede balk (Frame_1) met ronde + fase, de saldi-regel, de
	# saldi als iconen en rechts de grootboekknop.
	var balk := PanelContainer.new()
	balk.name = "KopBalk"
	balk.theme_type_variation = "PaneelBalk"
	kolom.add_child(balk)
	var balk_rij := HBoxContainer.new()
	balk_rij.add_theme_constant_override("separation", 16)
	balk.add_child(balk_rij)
	var kop_kolom := VBoxContainer.new()
	kop_kolom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kop_kolom.add_theme_constant_override("separation", 4)
	balk_rij.add_child(kop_kolom)
	_header = _tekst("", "LabelKopInkt", 30)
	_header.name = "Header"
	kop_kolom.add_child(_header)
	_saldi = _tekst("", "LabelInkt", 20)
	_saldi.name = "Saldi"
	kop_kolom.add_child(_saldi)
	var saldi_rij := HBoxContainer.new()
	saldi_rij.name = "SaldiIconen"
	saldi_rij.add_theme_constant_override("separation", 24)
	kop_kolom.add_child(saldi_rij)
	_saldi_pool = UiIcoonTekst.new("pool", "", 28, UiAssets.INKT)
	_saldi_cp = UiIcoonTekst.new("cp", "", 28, UiAssets.INKT)
	_saldi_score = UiIcoonTekst.new("score", "", 28, UiAssets.INKT)
	for r in [_saldi_pool, _saldi_cp, _saldi_score]:
		(r as UiIcoonTekst).label.add_theme_font_size_override("font_size", 24)
		saldi_rij.add_child(r)
	var grootboek := _grote_knop(tr("HUB_LEDGER_BTN"), "GrootboekKnop", "score", func() -> void:
		var scherm := LedgerScreen.new()
		add_child(scherm)
		scherm.open(driver.c, mens_id))
	grootboek.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balk_rij.add_child(grootboek)
	# F3.5-UI: twee teamkolommen: links jouw team, rechts de vijand; elk lid
	# een portret met naam en saldi (versterkingen, CP, roem).
	var teams := HBoxContainer.new()
	teams.name = "Teams"
	teams.add_theme_constant_override("separation", 16)
	_team_links = VBoxContainer.new()
	_team_links.name = "TeamLinks"
	_team_links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_team_links.add_theme_constant_override("separation", 4)
	teams.add_child(_team_links)
	_team_rechts = VBoxContainer.new()
	_team_rechts.name = "TeamRechts"
	_team_rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_team_rechts.add_theme_constant_override("separation", 4)
	teams.add_child(_team_rechts)
	kolom.add_child(teams)
	_scroll = ScrollContainer.new()
	_scroll.name = "Tijdlijn"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	kolom.add_child(_scroll)
	_tijdlijn = VBoxContainer.new()
	_tijdlijn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tijdlijn.add_theme_constant_override("separation", 8)
	_scroll.add_child(_tijdlijn)
	_paneel = VBoxContainer.new()
	_paneel.name = "FasePaneel"
	_paneel.add_theme_constant_override("separation", 10)
	kolom.add_child(_paneel)


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


func _ververs() -> void:
	var c: CState = driver.c
	var mijn: Dictionary = c.spelers.get(mens_id, {})
	_header.text = tr("HUB_HEADER") % [c.ronde, tr(FASE_NAMEN.get(c.fase, "?"))]
	if c.fase == CState.Fase.KLAAR and c.winnaar != -1:
		_header.text = tr("HUB_CHAMPION") % String(c.spelers[c.winnaar].naam)
	var pool: Dictionary = c.pool_van(mens_id)
	# Naam en team als tekst; de getallen dragen de iconen eronder (de oude
	# volledige saldi-regel wrapte en zei hetzelfde twee keer).
	_saldi.text = tr("HUB_UI_SALDI_KORT") % [
		String(mijn.get("naam", "?")), int(mijn.get("team", 0)),
		"" if String(mijn.get("status", "")) == "actief" else tr("HUB_ELIMINATED_SUFFIX")]
	_saldi_pool.zet_tekst(str(_pool_punten(pool)))
	_saldi_cp.zet_tekst(str(c.cp_van(mens_id)))
	_saldi_score.zet_tekst(str(c.punten_van(mens_id)))
	_ververs_teams()
	_ververs_tijdlijn()
	_bouw_fase_paneel()


## F3.5-UI: de teamkolommen: per lid een portret + naam + saldi-regel.
func _ververs_teams() -> void:
	var c: CState = driver.c
	var mijn_team: int = int(c.spelers.get(mens_id, {}).get("team", 0))
	var vecht_nu: Dictionary = {}
	for duel in c.duels_deze_ronde:
		if not bool(duel.klaar):
			vecht_nu[int(duel.p1)] = true
			vecht_nu[int(duel.p2)] = true
	for gegevens in [[_team_links, mijn_team, tr("HUB_TEAM_YOURS")], [_team_rechts, 1 - mijn_team, tr("HUB_TEAM_ENEMY")]]:
		var houder: VBoxContainer = gegevens[0]
		var team: int = int(gegevens[1])
		for kind in houder.get_children():
			kind.queue_free()
		var titel := _tekst(String(gegevens[2]), "LabelKop", 22, false)
		titel.add_theme_color_override("font_color",
			KLEUR_EIGEN if team == mijn_team else KLEUR_VIJAND)
		houder.add_child(titel)
		for sid in c.spelers:
			if int(c.spelers[sid].team) != team:
				continue
			houder.add_child(_team_rij(c, int(sid), team == mijn_team, vecht_nu.has(int(sid))))


## C11: waarde van een typed pool in versterkingspunten (soldaat 1 /
## ruiter 2 / kanon 3): overal EEN getal in de UI.
func _pool_punten(pool: Dictionary) -> int:
	return int(pool.inf) + 2 * int(pool.cav) + 3 * int(pool.art)


## Mini-saldo (icoon 18 px + getal) voor een teamrij.
static func _mini(icoon_id: String, tekst: String, kleur: Color) -> UiIcoonTekst:
	var r := UiIcoonTekst.new(icoon_id, tekst, 18, kleur)
	r.add_theme_constant_override("separation", 4)
	return r


func _team_rij(c: CState, sid: int, eigen: bool, vecht: bool) -> Control:
	var sp: Dictionary = c.spelers[sid]
	var dood: bool = String(sp.status) != "actief"
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 8)
	var portret := _portret_op_veldtafel(44, int(sp.get("doctrine", 0)), "blauw" if eigen else "rood", dood)
	portret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rij.add_child(portret)
	var naam := _tekst(String(sp.naam) + (tr("HUB_YOU_SUFFIX") if sid == mens_id else ""), "", 20, false)
	naam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	naam.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	naam.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if dood:
		naam.add_theme_color_override("font_color", KLEUR_DOOD)
	elif sid == mens_id:
		naam.add_theme_color_override("font_color", UiAssets.SELECTIE_GOUD)
	rij.add_child(naam)
	if vecht and not dood:
		# Vecht nu: gekruiste sabels in goud naast de naam.
		var sabels := UiAssets.icoon_rect("act-melee", 22, UiAssets.SELECTIE_GOUD)
		rij.add_child(sabels)
	var saldo := HBoxContainer.new()
	saldo.add_theme_constant_override("separation", 12)
	saldo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dood:
		var gevallen := _tekst(tr("HUB_FALLEN"), "", 18, false)
		gevallen.add_theme_color_override("font_color", KLEUR_DOOD)
		saldo.add_child(gevallen)
	elif CView.mag_saldo_zien(c, mens_id, sid):
		var pool: Dictionary = c.pool_van(sid)
		saldo.add_child(_mini("pool", str(_pool_punten(pool)), UiAssets.WARM_IVOOR))
		saldo.add_child(_mini("cp", str(c.cp_van(sid)), UiAssets.WARM_IVOOR))
		saldo.add_child(_mini("score", str(c.punten_van(sid)), UiAssets.WARM_IVOOR))
	else:
		# D12/spec 6: voorraad en CP van de tegenstander zijn verborgen. Zijn
		# roem is wel publiek -- dat is de enige maat waar je hem aan afmeet.
		saldo.add_child(_mini("score", str(c.punten_van(sid)), UiAssets.WARM_IVOOR))
	rij.add_child(saldo)
	return rij


# --- Tijdlijn ---------------------------------------------------------------------

## Welke kant van een feed-item: "blauw" (jouw team), "rood" (vijand) of ""
## (systeem, loting, remise). Een rapport kleurt naar de winnaar.
func _feed_kant(e: Dictionary) -> String:
	var c: CState = driver.c
	var wie: int = int(e.get("winnaar", -1)) if String(e.type) == "report" else int(e.get("speler", -1))
	if wie < 0 or not c.spelers.has(wie):
		return ""
	return _kant(int(c.spelers[wie].team))


## Icoon-id per feed-item ("" = geen icoon: barks krijgen er geen).
func _feed_icoon(e: Dictionary) -> String:
	var soort := String(e.type)
	if soort == "report":
		if int(e.get("winnaar", -1)) == -1:
			return "draw"
		var methode := String(e.get("methode", ""))
		if methode == "haven":
			return "win-harbor"
		if methode == "eliminatie" or methode == "resign":
			return "dead"
		return "act-melee"
	if soort == "event":
		var tekst := String(e.get("tekst", ""))
		if tekst.contains(tr("SOLO_UNIT_CP")):
			return "cp"
		for sleutel in ["SOLO_UNIT_INF", "SOLO_UNIT_CAV", "SOLO_UNIT_ART"]:
			if tekst.contains(tr(String(sleutel))):
				return "pool"
		return "score"
	return ""


## Een feed-kaartje: perkament met teamrand (kant), icoon in inkt en de tekst.
func _feed_kaartje(e: Dictionary) -> PanelContainer:
	var c: CState = driver.c
	var kaart := PanelContainer.new()
	var kant := _feed_kant(e)
	if kant == "blauw":
		kaart.theme_type_variation = "PaneelKaartjeBlauw"
	elif kant == "rood":
		kaart.theme_type_variation = "PaneelKaartjeRood"
	var rij := HBoxContainer.new()
	rij.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rij.add_theme_constant_override("separation", 12)
	kaart.add_child(rij)
	var icoon_id := _feed_icoon(e)
	if icoon_id != "":
		var icoon := UiAssets.icoon_rect(icoon_id, 36, UiAssets.INKT)
		icoon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rij.add_child(icoon)
	var label := _tekst("", "LabelInkt", 20)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if String(e.type) == "bark":
		label.text = tr("HUB_FEED_BARK") % [int(e.ronde), String(e.naam), String(e.tekst)]
	elif String(e.type) == "event":
		# Donaties/testamenten: ook je eigen acties (27 juli, Max).
		label.text = tr("HUB_UI_FEED_EVENT") % [int(e.ronde), String(e.tekst)]
	elif String(e.type) == "report":
		var p1n := String(c.spelers[int(e.p1)].naam)
		var p2n := String(c.spelers[int(e.p2)].naam)
		var uitslag := tr("HUB_DRAW") if int(e.winnaar) == -1 else tr("HUB_WINS_SHORT") % [
			String(c.spelers[int(e.winnaar)].naam), String(e.methode)]
		label.text = tr("HUB_FEED_REPORT") % [
			int(e.ronde), p1n, p2n, uitslag, int(e.cycli)]
	rij.add_child(label)
	return kaart


func _ververs_tijdlijn() -> void:
	# F3.4c: kaartjes die de mens nog niet zag (bv. gesimuleerd terwijl hij
	# op het bord stond) druppelen gefaseerd binnen: fade-in per kaartje, als
	# een afspeel-animatie van de gebeurtenissen. Al-geziene kaartjes (her-
	# opbouw van de hub) verschijnen direct.
	var al_gezien: int = CampaignBridge.feed_gezien
	var nieuw_totaal: int = maxi(1, driver.feed.size() - al_gezien)
	var vertraging_per: float = minf(0.45, 8.0 / float(nieuw_totaal))
	var onthul_i: int = 0
	while _feed_getoond < driver.feed.size():
		var e: Dictionary = driver.feed[_feed_getoond]
		var vers: bool = _feed_getoond >= al_gezien
		_feed_getoond += 1
		var kaart := _feed_kaartje(e)
		if String(e.type) == "report":
			# F3.3-rest: tik het kaartje voor het volledige rapport.
			kaart.tooltip_text = tr("HUB_REPORT_TOOLTIP")
			kaart.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
					_toon_report(e))
		_tijdlijn.add_child(kaart)
		if vers:
			kaart.modulate.a = 0.0
			var tw := kaart.create_tween()
			tw.tween_interval(0.15 + vertraging_per * onthul_i)
			tw.tween_property(kaart, "modulate:a", 1.0, 0.3)
			onthul_i += 1
	CampaignBridge.feed_gezien = maxi(CampaignBridge.feed_gezien, driver.feed.size())
	await get_tree().process_frame
	if is_inside_tree():
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


## F3.3-rest: MatchReport-detail: het hele battlereport in een dialoog.
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
	var dlg := AcceptDialog.new()
	dlg.title = tr("HUB_REPORT_TITLE")
	dlg.dialog_text = "\n".join(regels)
	dlg.ok_button_text = tr("HUB_CLOSE")
	add_child(dlg)
	dlg.popup_centered()


# --- Fasepaneel -------------------------------------------------------------------

func _wis_paneel() -> void:
	# Eerst uit de boom, dan vrijgeven: anders staat de oude FasePapier dit
	# frame nog naast de nieuwe en hernoemt Godot de nieuwe (naamconflict).
	for kind in _paneel.get_children():
		_paneel.remove_child(kind)
		kind.queue_free()
	_papier_inhoud = null


## Het perkament (Frame_3) in het fasepaneel; wordt bij het eerste gebruik na
## _wis_paneel opnieuw gemaakt. Alles in het paneel staat hierop in inkt.
func _papier() -> VBoxContainer:
	if _papier_inhoud != null and is_instance_valid(_papier_inhoud):
		return _papier_inhoud
	var vlak := PanelContainer.new()
	vlak.name = "FasePapier"
	vlak.theme_type_variation = "PaneelPapier"
	_paneel.add_child(vlak)
	_papier_inhoud = VBoxContainer.new()
	_papier_inhoud.add_theme_constant_override("separation", 10)
	vlak.add_child(_papier_inhoud)
	return _papier_inhoud


## Duimknop op het perkament: KnopBreed, minimaal KNOP_HOOGTE hoog, met
## optioneel icoon ("" = geen). De callable staat achteraan (meerregelige lambda).
func _knop(tekst: String, icoon_id: String, actie: Callable) -> Button:
	return _maak_knop(tekst, icoon_id, "KnopBreed", actie)


## De rode variant (gevaar: aanvallen, alles verbranden).
func _knop_rood(tekst: String, icoon_id: String, actie: Callable) -> Button:
	return _maak_knop(tekst, icoon_id, "KnopRood", actie)


func _maak_knop(tekst: String, icoon_id: String, variant: String, actie: Callable) -> Button:
	var b := Button.new()
	b.text = tekst
	b.theme_type_variation = variant
	b.custom_minimum_size = Vector2(0, KNOP_HOOGTE)
	b.add_theme_font_size_override("font_size", 22)
	_knop_icoon(b, icoon_id)
	b.pressed.connect(actie)
	_papier().add_child(b)
	return b


## Keuzelijst op het perkament (het thema tekent hem als perkamentknop).
func _keuzelijst(naam: String) -> OptionButton:
	var o := OptionButton.new()
	o.name = naam
	o.custom_minimum_size = Vector2(0, KNOP_HOOGTE)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.add_theme_font_size_override("font_size", 22)
	return o


func _bouw_fase_paneel() -> void:
	_wis_paneel()
	var c: CState = driver.c
	if c.fase == CState.Fase.KLAAR:
		_paneel_einde(c)
		return
	if c.fase == CState.Fase.BURGEROORLOG:
		var bv := BracketView.new()
		bv.name = "BracketView"
		bv.vul(c)
		_paneel.add_child(bv)
	if not driver.wacht_op_mens():
		_info_label = _tekst(tr("HUB_BOTS_BUSY") if _bezig else tr("HUB_WAIT_NEXT_PHASE"), "LabelInkt", 20)
		_papier().add_child(_info_label)
		return
	_info_label = null
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
	var inhoud := _papier()
	var kampioen: Dictionary = c.spelers.get(c.winnaar, {})
	var kop := HBoxContainer.new()
	kop.add_theme_constant_override("separation", 14)
	kop.add_child(UiAssets.icoon_rect("win-harbor", 44, UiAssets.INKT))
	var titel := _tekst(tr("HUB_END_CHAMPION") % String(kampioen.get("naam", "?")), "LabelKopInkt", 34)
	titel.name = "EindTitel"
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kop.add_child(titel)
	inhoud.add_child(kop)
	if not kampioen.is_empty():
		var portret := UiPortret.new(96)
		portret.zet(int(kampioen.get("doctrine", 0)), _kant(int(kampioen.get("team", 0))))
		portret.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inhoud.add_child(portret)
	var mijn_punten: int = c.punten_van(mens_id)
	var plek: int = 1
	for id in c.spelers:
		if c.punten_van(int(id)) > mijn_punten:
			plek += 1
	inhoud.add_child(_tekst(tr("HUB_END_SUMMARY") % [c.ronde, driver.duels_gespeeld, mijn_punten, plek, c.spelers.size()],
		"LabelInkt", 20))
	# Top 3 op roem: de rest staat in het grootboek.
	var top: Array = LedgerScreen.rijen(c, "punten")
	for i in mini(3, top.size()):
		var rij := HBoxContainer.new()
		rij.add_theme_constant_override("separation", 10)
		var kleur: Color = UiAssets.DIEP_ROOD if int(top[i].id) == mens_id else UiAssets.INKT
		var plaats := _tekst("%d." % (i + 1), "LabelInkt", 20, false)
		plaats.custom_minimum_size = Vector2(36, 0)
		plaats.add_theme_color_override("font_color", kleur)
		rij.add_child(plaats)
		var portret := UiPortret.new(28)
		portret.zonder_krans()
		var sp: Dictionary = c.spelers.get(int(top[i].id), {})
		portret.zet(int(sp.get("doctrine", 0)), "", String(sp.get("status", "actief")) != "actief")
		rij.add_child(portret)
		var naam := _tekst(String(top[i].naam), "LabelInkt", 20, false)
		naam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		naam.add_theme_color_override("font_color", kleur)
		rij.add_child(naam)
		rij.add_child(UiIcoonTekst.new("score", str(int(top[i].punten)), 26, kleur))
		inhoud.add_child(rij)
	_knop(tr("HUB_END_LEDGER_BTN"), "score", func() -> void:
		var scherm := LedgerScreen.new()
		add_child(scherm)
		scherm.open(driver.c, mens_id))
	var opnieuw := _knop(tr("HUB_END_NEW_BTN"), "phase-setup", func() -> void:
		if FileAccess.file_exists(SAVE_PAD):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PAD))
		CampaignBridge.driver = null
		CampaignBridge.feed_gezien = 0
		get_tree().reload_current_scene())
	opnieuw.name = "NieuweCampagneKnop"


func _paneel_nominatie(c: CState) -> void:
	var inhoud := _papier()
	inhoud.add_child(_tekst(tr("HUB_NOMINATE_TITLE"), "LabelInkt", 22))
	var eigen := _keuzelijst("EigenKeuze")
	var vijand := _keuzelijst("VijandKeuze")
	var mijn_team: int = int(c.spelers[mens_id].team)
	for sid in c.actieve_leden(mijn_team):
		if not c.al_genomineerd.has(sid):
			eigen.add_item(tr("HUB_NAME_YOU") % c.spelers[sid].naam if sid == mens_id else String(c.spelers[sid].naam), sid)
	for sid in c.actieve_leden(1 - mijn_team):
		if not c.al_genomineerd.has(sid):
			vijand.add_item(String(c.spelers[sid].naam), sid)
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 12)
	rij.add_child(eigen)
	var sabels := UiAssets.icoon_rect("act-melee", 32, UiAssets.INKT)
	sabels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rij.add_child(sabels)
	rij.add_child(vijand)
	inhoud.add_child(rij)
	_knop(tr("HUB_VOTE_BTN"), "check", func() -> void:
		if eigen.selected >= 0 and vijand.selected >= 0:
			driver.submit_mens_nominatie(eigen.get_selected_id(), vijand.get_selected_id())
			_werk_door())


## F3.4b: het mens-duel speelt op het echte bord: de brug zet de config klaar.
## UX (27 juli, Max): de mens heeft voorrang op de bot-simulaties, het paneel
## toont wie-tegen-wie deze ronde, en het duel start na een korte aftel
## vanzelf met een laadscherm. "Blijf in de hub" annuleert de auto-start.
func _paneel_duel(c: CState) -> void:
	var d: Dictionary = driver.mens_duel()
	if d.is_empty():
		return
	var inhoud := _papier()
	var vijand: int = int(d.p2) if int(d.p1) == mens_id else int(d.p1)
	inhoud.add_child(_tekst(tr("HUB_DUEL_PAIRS_TITLE"), "LabelInkt", 20))
	for duel in c.duels_deze_ronde:
		var rij := HBoxContainer.new()
		rij.add_theme_constant_override("separation", 10)
		var kleur: Color = UiAssets.INKT
		if int(duel.p1) == mens_id or int(duel.p2) == mens_id:
			kleur = UiAssets.DIEP_ROOD
		elif bool(duel.klaar):
			kleur = UiAssets.OUD_BRUIN
		var sabels := UiAssets.icoon_rect("act-melee", 22, kleur)
		sabels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rij.add_child(sabels)
		var status: String = tr("BRACKET_DONE") if bool(duel.klaar) else tr("BRACKET_NOW_PLAYING")
		var r := _tekst(tr("BRACKET_DUEL_ROW") % [String(c.spelers[int(duel.p1)].naam),
			String(c.spelers[int(duel.p2)].naam), status], "LabelInkt", 20)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_theme_color_override("font_color", kleur)
		rij.add_child(r)
		inhoud.add_child(rij)
	inhoud.add_child(_tekst(tr("HUB_DUEL_TITLE") % String(c.spelers[vijand].naam), "LabelInkt", 22))
	var knop := _knop_rood(tr("HUB_DUEL_PLAY_BTN"), "act-melee", func() -> void:
		_start_mens_duel(vijand))
	knop.name = "SpeelDuelKnop"
	if _auto_stop_idx == int(d.idx):
		return
	inhoud.add_child(_tekst(tr("HUB_DUEL_AUTO"), "LabelInkt", 20))
	var blijf := _knop(tr("HUB_DUEL_STAY_BTN"), "", func() -> void:
		_auto_stop_idx = int(d.idx)
		_bouw_fase_paneel())
	blijf.name = "BlijfKnop"
	if _auto_start_idx != int(d.idx):
		_auto_start_idx = int(d.idx)
		_auto_start_duel(int(d.idx), vijand)


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
	var sabels := UiAssets.icoon_rect("act-melee", 96, UiAssets.WARM_IVOOR)
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
	var inhoud := _papier()
	inhoud.add_child(_tekst(tr("HUB_DONATE_TITLE_PT"), "LabelInkt", 20))
	var mijn_team: int = int(c.spelers[mens_id].team)
	var mijn_pool: Dictionary = c.pool_van(mens_id)
	# De rijen scrollen als er meer teamgenoten zijn dan er ruimte is.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inhoud.add_child(scroll)
	var rijen := VBoxContainer.new()
	rijen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rijen.add_theme_constant_override("separation", 8)
	scroll.add_child(rijen)
	var aantal := 0
	for sid in c.actieve_leden(mijn_team):
		if int(sid) == mens_id:
			continue
		aantal += 1
		var rij := HBoxContainer.new()
		rij.add_theme_constant_override("separation", 12)
		var portret := UiPortret.new(44)
		portret.zet(int(c.spelers[int(sid)].get("doctrine", 0)), "blauw")
		portret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rij.add_child(portret)
		var naam := _tekst(String(c.spelers[int(sid)].naam), "LabelInkt", 22, false)
		naam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		naam.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		naam.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rij.add_child(naam)
		var doel: int = int(sid)
		var plus := Button.new()
		plus.text = tr("HUB_PLUS_VST")
		plus.custom_minimum_size = Vector2(150, KNOP_HOOGTE)
		plus.add_theme_font_size_override("font_size", 22)
		_knop_icoon(plus, "pool", 30)
		plus.disabled = int(mijn_pool.inf) <= 0
		plus.pressed.connect(func() -> void:
			if driver.submit_mens_donatie(doel, 1, 0, 0, 0):
				_ververs())
		rij.add_child(plus)
		var plus_cp := Button.new()
		plus_cp.text = tr("HUB_PLUS_CP")
		plus_cp.custom_minimum_size = Vector2(170, KNOP_HOOGTE)
		plus_cp.add_theme_font_size_override("font_size", 22)
		_knop_icoon(plus_cp, "cp", 30)
		plus_cp.disabled = driver.c.cp_van(mens_id) <= 0
		plus_cp.pressed.connect(func() -> void:
			if driver.submit_mens_donatie(doel, 0, 0, 0, 1):
				_ververs())
		rij.add_child(plus_cp)
		rijen.add_child(rij)
	scroll.custom_minimum_size = Vector2(0, mini(aantal, DONATIE_RIJEN_ZICHTBAAR) * (KNOP_HOOGTE + 8))
	var koers: int = maxi(1, c.rules.ruil_cp_per_punt)
	var ruil := _knop(tr("HUB_RUIL_BTN") % koers, "cp", func() -> void:
		if driver.submit_mens_ruil(koers):
			_ververs())
	ruil.name = "RuilKnop"
	ruil.disabled = c.cp_van(mens_id) < koers
	_knop(tr("HUB_DONATE_DONE_BTN"), "check", func() -> void:
		driver.submit_mens_klaar_met_doneren()
		_werk_door())


func _paneel_testament(c: CState) -> void:
	var inhoud := _papier()
	var kop := HBoxContainer.new()
	kop.add_theme_constant_override("separation", 12)
	var schedel := UiAssets.icoon_rect("dead", 40, UiAssets.INKT)
	schedel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kop.add_child(schedel)
	var titel := _tekst(tr("HUB_WILL_TITLE"), "LabelInkt", 22)
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kop.add_child(titel)
	inhoud.add_child(kop)
	var doelen := _keuzelijst("TestamentDoel")
	for id in c.spelers:
		if int(id) != mens_id and String(c.spelers[id].status) == "actief":
			doelen.add_item(tr("HUB_WILL_TARGET") % [c.spelers[id].naam, int(c.spelers[id].team)], int(id))
	inhoud.add_child(doelen)
	_knop(tr("HUB_WILL_HALF_BTN"), "pool", func() -> void:
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
		_werk_door())
	_knop_rood(tr("HUB_WILL_NONE_BTN"), "", func() -> void:
		driver.submit_mens_testament([])
		_werk_door())
