class_name CampaignHub
extends Control

# F3.3 — de CampagneHub: tijdlijn ("Among Us-gevoel"), eigen saldi en het
# fase-paneel (raad / doneren / testament) in één mobile-first scherm.
# Leest UITSLUITEND de cview + de feed; alle mens-acties gaan via de
# SoloDriver-submits. Bot-werk (incl. duels) draait op een thread zodat de
# UI niet bevriest.

var driver: SoloDriver
var mens_id: int = 0

## F3.4 — vaste solo-savegame-slot; elke campagne-actie staat direct op schijf.
const SAVE_PAD := "user://campaigns/solo/campagne.jsonl"

var _header: Label
var _saldi: Label
var _team_links: VBoxContainer
var _team_rechts: VBoxContainer
var _tijdlijn: VBoxContainer
var _scroll: ScrollContainer
var _paneel: VBoxContainer
var _thread: Thread
var _bezig: bool = false
var _feed_getoond: int = 0
var _auto_start_idx: int = -1   # duel-idx waarvoor de auto-start-aftel loopt
var _auto_stop_idx: int = -1    # duel-idx waarvoor de mens de auto-start annuleerde
var _duel_start_bezig: bool = false
var _info_label: Label = null

## Bot-duels in de hub: "easy" — eval-gedreven (bloedig, dus de campagne-
## attritie werkt) én snel (seconden per duel; de hang zat specifiek in
## "medium", dat naar de 3000-stappen-noodstop verdedigt). NIET "l1": de
## haven-rusher wint zonder slachtoffers, waardoor niemand ooit door zijn
## pool zakt en de campagne nooit convergeert (test-bevinding 27 juli).
const BOT_DUEL_AI := "easy"
## Vangnet tegen incidentele grind-duels tussen bots; het mens-duel op het
## echte bord behoudt cycluslimiet 0 (besluit 26 juli).
const BOT_DUEL_HONGER_VANAF := 10

const KLEUR_EIGEN := Color(0.30, 0.55, 0.95)
const KLEUR_VIJAND := Color(0.90, 0.35, 0.35)
const KLEUR_DOOD := Color(0.42, 0.40, 0.44)


func _ready() -> void:
	if driver == null and CampaignBridge.driver != null \
			and CampaignBridge.driver.c.fase != CState.Fase.KLAAR:
		# F3.4b: terug van het bord (of een andere scene-wissel) — zelfde campagne.
		driver = CampaignBridge.driver
		mens_id = driver.mens_id
	if driver == null:
		# Lopende solo-campagne? Dan is dat een KEUZE, geen stille hervatting
		# (besluit Max, 28 juli: "ik word meteen een muis, dat wil ik niet").
		if FileAccess.file_exists(SAVE_PAD):
			var oud_driver := SoloDriver.hervat(SAVE_PAD, mens_id)
			if oud_driver != null and oud_driver.c.fase != CState.Fase.KLAAR 					and oud_driver.c.rules.ronde1_loting 					and oud_driver.c.rules.vol_team_start 					and not oud_driver.c.rules.budget_bonus.is_empty():
				# Geldige, actuele save: laat de speler kiezen.
				_toon_hervat_keuze(oud_driver)
				return
		# Geen (bruikbare) save: nieuwe campagne, eerst je factie kiezen.
		_toon_factie_keuze()
		return
	_start()


## 28 juli (Max) — doorgaan of opnieuw: nooit meer stilletjes hervatten.
func _toon_hervat_keuze(oud_driver: SoloDriver) -> void:
	var achtergrond := ColorRect.new()
	achtergrond.color = Color(0.08, 0.09, 0.12)
	achtergrond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(achtergrond)
	var kolom := VBoxContainer.new()
	kolom.name = "HervatKeuze"
	kolom.set_anchors_preset(Control.PRESET_FULL_RECT)
	kolom.offset_left = 24
	kolom.offset_right = -24
	kolom.offset_top = 60
	kolom.add_theme_constant_override("separation", 12)
	achtergrond.add_child(kolom)
	var titel := Label.new()
	titel.text = tr("HUB_RESUME_TITLE")
	titel.add_theme_font_size_override("font_size", 22)
	kolom.add_child(titel)
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var mijn: Dictionary = oud_driver.c.spelers.get(oud_driver.mens_id, {})
	info.text = tr("HUB_RESUME_INFO") % [oud_driver.c.ronde,
		Constants.doctrine_display_name(int(mijn.get("doctrine", 0)))]
	kolom.add_child(info)
	var door := Button.new()
	door.name = "HervatDoorgaan"
	door.text = tr("HUB_RESUME_CONTINUE")
	door.pressed.connect(func() -> void:
		achtergrond.queue_free()
		driver = oud_driver
		mens_id = driver.mens_id
		_start())
	kolom.add_child(door)
	var nieuw_knop := Button.new()
	nieuw_knop.name = "HervatNieuw"
	nieuw_knop.text = tr("HUB_RESUME_NEW")
	nieuw_knop.pressed.connect(func() -> void:
		achtergrond.queue_free()
		if FileAccess.file_exists(SAVE_PAD):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PAD))
		CampaignBridge.driver = null
		CampaignBridge.feed_gezien = 0
		_toon_factie_keuze())
	kolom.add_child(nieuw_knop)


func _start() -> void:
	driver.duel_ai = BOT_DUEL_AI
	driver.bot_duel_honger_vanaf = BOT_DUEL_HONGER_VANAF
	if CampaignBridge.driver != driver:
		CampaignBridge.feed_gezien = 0  # verse of hervatte campagne: teller opnieuw
	CampaignBridge.driver = driver
	_bouw_layout()
	_ververs()
	_werk_door()


## Factiekeuze bij een nieuwe campagne: 6 knoppen met naam + pro/con uit
## DOCTRINE_DATA. De keuze is definitief voor de hele campagne.
func _toon_factie_keuze() -> void:
	var achtergrond := ColorRect.new()
	achtergrond.color = Color(0.08, 0.09, 0.12)
	achtergrond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(achtergrond)
	var kolom := VBoxContainer.new()
	kolom.name = "FactieKeuze"
	kolom.set_anchors_preset(Control.PRESET_FULL_RECT)
	kolom.offset_left = 24
	kolom.offset_right = -24
	kolom.offset_top = 40
	kolom.add_theme_constant_override("separation", 10)
	achtergrond.add_child(kolom)
	var titel := Label.new()
	titel.text = tr("HUB_FACTION_TITLE")
	titel.add_theme_font_size_override("font_size", 24)
	kolom.add_child(titel)
	var uitleg := Label.new()
	uitleg.text = tr("HUB_FACTION_EXPLAIN")
	uitleg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	uitleg.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	kolom.add_child(uitleg)
	for doctrine in Constants.DOCTRINE_DATA:
		var knop := Button.new()
		knop.name = "Factie_%d" % int(doctrine)
		knop.text = tr("HUB_FACTION_BTN") % [Constants.doctrine_display_name(int(doctrine)),
			Constants.doctrine_pro(int(doctrine)), Constants.doctrine_con(int(doctrine))]
		knop.clip_text = false
		knop.alignment = HORIZONTAL_ALIGNMENT_LEFT
		knop.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		knop.pressed.connect(_kies_factie.bind(int(doctrine), achtergrond))
		kolom.add_child(knop)


func _kies_factie(doctrine: int, keuze_scherm: Control) -> void:
	keuze_scherm.queue_free()
	driver = SoloDriver.new(int(Time.get_unix_time_from_system()) % 900000,
		mens_id, 16, SAVE_PAD, doctrine)
	_start()


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _bouw_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var achtergrond := ColorRect.new()
	achtergrond.color = Color(0.08, 0.09, 0.12)
	achtergrond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(achtergrond)
	var kolom := VBoxContainer.new()
	kolom.set_anchors_preset(Control.PRESET_FULL_RECT)
	kolom.offset_left = 12
	kolom.offset_right = -12
	kolom.offset_top = 10
	kolom.offset_bottom = -10
	kolom.add_theme_constant_override("separation", 8)
	add_child(kolom)
	_header = Label.new()
	_header.name = "Header"
	_header.add_theme_font_size_override("font_size", 20)
	kolom.add_child(_header)
	_saldi = Label.new()
	_saldi.name = "Saldi"
	_saldi.add_theme_font_size_override("font_size", 14)
	_saldi.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	kolom.add_child(_saldi)
	var balk := HBoxContainer.new()
	balk.add_theme_constant_override("separation", 8)
	var grootboek := Button.new()
	grootboek.name = "GrootboekKnop"
	grootboek.text = tr("HUB_LEDGER_BTN")
	grootboek.pressed.connect(func() -> void:
		var scherm := LedgerScreen.new()
		add_child(scherm)
		scherm.open(driver.c, mens_id))
	balk.add_child(grootboek)
	kolom.add_child(balk)
	# F3.5-UI — twee teamkolommen: links jouw team, rechts de vijand; elk lid
	# een bolletje met naam, leger (soldaten·cavalerie·kanonnen), CP en punten.
	var teams := HBoxContainer.new()
	teams.name = "Teams"
	teams.add_theme_constant_override("separation", 10)
	_team_links = VBoxContainer.new()
	_team_links.name = "TeamLinks"
	_team_links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_team_links.add_theme_constant_override("separation", 2)
	teams.add_child(_team_links)
	_team_rechts = VBoxContainer.new()
	_team_rechts.name = "TeamRechts"
	_team_rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_team_rechts.add_theme_constant_override("separation", 2)
	teams.add_child(_team_rechts)
	kolom.add_child(teams)
	_scroll = ScrollContainer.new()
	_scroll.name = "Tijdlijn"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kolom.add_child(_scroll)
	_tijdlijn = VBoxContainer.new()
	_tijdlijn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tijdlijn.add_theme_constant_override("separation", 6)
	_scroll.add_child(_tijdlijn)
	_paneel = VBoxContainer.new()
	_paneel.name = "FasePaneel"
	_paneel.add_theme_constant_override("separation", 6)
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
	# "Wachten op de volgende fase." staan terwijl de thread maalde — zet het
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
## werk-thread vervangt (referentie-swap) — veilig genoeg om te tonen zonder
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
	_saldi.text = tr("HUB_BALANCE_PT") % [
		String(mijn.get("naam", "?")), int(mijn.get("team", 0)),
		_pool_punten(pool), c.cp_van(mens_id), c.punten_van(mens_id),
		"" if String(mijn.get("status", "")) == "actief" else tr("HUB_ELIMINATED_SUFFIX")]
	_ververs_teams()
	_ververs_tijdlijn()
	_bouw_fase_paneel()


## F3.5-UI — de teamkolommen: per lid een bolletje + naam + saldi-regel.
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
		var titel := Label.new()
		titel.text = String(gegevens[2])
		titel.add_theme_font_size_override("font_size", 12)
		titel.add_theme_color_override("font_color",
			KLEUR_EIGEN if team == mijn_team else KLEUR_VIJAND)
		houder.add_child(titel)
		for sid in c.spelers:
			if int(c.spelers[sid].team) != team:
				continue
			houder.add_child(_team_rij(c, int(sid), team == mijn_team, vecht_nu.has(int(sid))))


## C11 — waarde van een typed pool in versterkingspunten (soldaat 1 /
## ruiter 2 / kanon 3): overal EEN getal in de UI.
func _pool_punten(pool: Dictionary) -> int:
	return int(pool.inf) + 2 * int(pool.cav) + 3 * int(pool.art)


func _team_rij(c: CState, sid: int, eigen: bool, vecht: bool) -> Control:
	var sp: Dictionary = c.spelers[sid]
	var dood: bool = String(sp.status) != "actief"
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 6)
	var bol := Panel.new()
	bol.custom_minimum_size = Vector2(20, 20)
	var stijl := StyleBoxFlat.new()
	stijl.bg_color = KLEUR_DOOD if dood else (KLEUR_EIGEN if eigen else KLEUR_VIJAND)
	stijl.set_corner_radius_all(10)
	if vecht and not dood:
		stijl.border_color = Color(0.98, 0.85, 0.4)
		stijl.set_border_width_all(2)
	bol.add_theme_stylebox_override("panel", stijl)
	var initiaal := Label.new()
	initiaal.text = String(sp.naam).substr(0, 1)
	initiaal.add_theme_font_size_override("font_size", 11)
	initiaal.set_anchors_preset(Control.PRESET_FULL_RECT)
	initiaal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initiaal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bol.add_child(initiaal)
	rij.add_child(bol)
	var tekst := VBoxContainer.new()
	tekst.add_theme_constant_override("separation", 0)
	var naam := Label.new()
	var markering := ""
	if sid == mens_id:
		markering = tr("HUB_YOU_SUFFIX")
	if vecht and not dood:
		markering += tr("HUB_FIGHTING_SUFFIX")
	naam.text = String(sp.naam) + markering
	naam.add_theme_font_size_override("font_size", 13)
	if dood:
		naam.add_theme_color_override("font_color", KLEUR_DOOD)
	elif sid == mens_id:
		naam.add_theme_color_override("font_color", Color(0.98, 0.85, 0.4))
	tekst.add_child(naam)
	var saldo := Label.new()
	if dood:
		saldo.text = tr("HUB_FALLEN")
	elif CView.mag_saldo_zien(c, mens_id, sid):
		var pool: Dictionary = c.pool_van(sid)
		saldo.text = tr("HUB_ROW_SALDO") % [_pool_punten(pool), c.cp_van(sid), c.punten_van(sid)]
	else:
		# D12/spec 6: voorraad en CP van de tegenstander zijn verborgen. Zijn
		# roem is wel publiek -- dat is de enige maat waar je hem aan afmeet.
		saldo.text = tr("HUB_ROW_SALDO_GEHEIM") % c.punten_van(sid)
	saldo.add_theme_font_size_override("font_size", 11)
	saldo.add_theme_color_override("font_color",
		KLEUR_DOOD if dood else Color(0.72, 0.78, 0.86))
	tekst.add_child(saldo)
	rij.add_child(tekst)
	return rij


func _ververs_tijdlijn() -> void:
	# F3.4c — kaartjes die de mens nog niet zag (bv. gesimuleerd terwijl hij
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
		var kaart := PanelContainer.new()
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 13)
		if String(e.type) == "bark":
			label.text = tr("HUB_FEED_BARK") % [int(e.ronde), String(e.naam), String(e.tekst)]
			label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95))
		elif String(e.type) == "event":
			# Donaties/testamenten — ook je eigen acties (27 juli, Max).
			label.text = "R%d · %s" % [int(e.ronde), String(e.tekst)]
			label.add_theme_color_override("font_color", Color(0.6, 0.88, 0.65))
		elif String(e.type) == "report":
			var c: CState = driver.c
			var p1n := String(c.spelers[int(e.p1)].naam)
			var p2n := String(c.spelers[int(e.p2)].naam)
			var uitslag := tr("HUB_DRAW") if int(e.winnaar) == -1 else tr("HUB_WINS_SHORT") % [
				String(c.spelers[int(e.winnaar)].naam), String(e.methode)]
			label.text = tr("HUB_FEED_REPORT") % [
				int(e.ronde), p1n, p2n, uitslag, int(e.cycli)]
			label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
			# F3.3-rest: tik het kaartje voor het volledige rapport.
			kaart.tooltip_text = tr("HUB_REPORT_TOOLTIP")
			kaart.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
					_toon_report(e))
		kaart.add_child(label)
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


## F3.3-rest — MatchReport-detail: het hele battlereport in een dialoog.
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


func _wis_paneel() -> void:
	for kind in _paneel.get_children():
		kind.queue_free()


func _knop(tekst: String, actie: Callable) -> Button:
	var b := Button.new()
	b.text = tekst
	b.pressed.connect(actie)
	_paneel.add_child(b)
	return b


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
		_info_label = Label.new()
		_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_label.text = tr("HUB_BOTS_BUSY") if _bezig else tr("HUB_WAIT_NEXT_PHASE")
		_paneel.add_child(_info_label)
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


## 27 juli (Max) — het campagne-eindscherm: kampioen, eindstand, opnieuw.
func _paneel_einde(c: CState) -> void:
	var titel := Label.new()
	titel.name = "EindTitel"
	titel.add_theme_font_size_override("font_size", 22)
	titel.add_theme_color_override("font_color", Color(0.98, 0.85, 0.4))
	titel.text = tr("HUB_END_CHAMPION") % String(c.spelers.get(c.winnaar, {}).get("naam", "?"))
	_paneel.add_child(titel)
	var sub := Label.new()
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 13)
	var mijn_punten: int = c.punten_van(mens_id)
	var plek: int = 1
	for id in c.spelers:
		if c.punten_van(int(id)) > mijn_punten:
			plek += 1
	sub.text = tr("HUB_END_SUMMARY") % [c.ronde, driver.duels_gespeeld, mijn_punten, plek, c.spelers.size()]
	_paneel.add_child(sub)
	# Top 3 op roem — de rest staat in het grootboek.
	var top: Array = LedgerScreen.rijen(c, "punten")
	for i in mini(3, top.size()):
		var r := Label.new()
		r.add_theme_font_size_override("font_size", 12)
		r.text = "%d. %s — %d %s" % [i + 1, String(top[i].naam), int(top[i].punten), tr("LEDGER_COL_POINTS").to_lower()]
		if int(top[i].id) == mens_id:
			r.add_theme_color_override("font_color", Color(0.98, 0.85, 0.4))
		_paneel.add_child(r)
	_knop(tr("HUB_END_LEDGER_BTN"), func() -> void:
		var scherm := LedgerScreen.new()
		add_child(scherm)
		scherm.open(driver.c, mens_id))
	var opnieuw := _knop(tr("HUB_END_NEW_BTN"), func() -> void:
		if FileAccess.file_exists(SAVE_PAD):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PAD))
		CampaignBridge.driver = null
		CampaignBridge.feed_gezien = 0
		get_tree().reload_current_scene())
	opnieuw.name = "NieuweCampagneKnop"


func _paneel_nominatie(c: CState) -> void:
	var titel := Label.new()
	titel.text = tr("HUB_NOMINATE_TITLE")
	_paneel.add_child(titel)
	var eigen := OptionButton.new()
	eigen.name = "EigenKeuze"
	var vijand := OptionButton.new()
	vijand.name = "VijandKeuze"
	var mijn_team: int = int(c.spelers[mens_id].team)
	for sid in c.actieve_leden(mijn_team):
		if not c.al_genomineerd.has(sid):
			eigen.add_item(tr("HUB_NAME_YOU") % c.spelers[sid].naam if sid == mens_id else String(c.spelers[sid].naam), sid)
	for sid in c.actieve_leden(1 - mijn_team):
		if not c.al_genomineerd.has(sid):
			vijand.add_item(String(c.spelers[sid].naam), sid)
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 8)
	rij.add_child(eigen)
	rij.add_child(vijand)
	_paneel.add_child(rij)
	_knop(tr("HUB_VOTE_BTN"), func() -> void:
		if eigen.selected >= 0 and vijand.selected >= 0:
			driver.submit_mens_nominatie(eigen.get_selected_id(), vijand.get_selected_id())
			_werk_door())


## F3.4b — het mens-duel speelt op het echte bord: de brug zet de config klaar.
## UX (27 juli, Max): de mens heeft voorrang op de bot-simulaties, het paneel
## toont wie-tegen-wie deze ronde, en het duel start na een korte aftel
## vanzelf met een laadscherm. "Blijf in de hub" annuleert de auto-start.
func _paneel_duel(c: CState) -> void:
	var d: Dictionary = driver.mens_duel()
	if d.is_empty():
		return
	var vijand: int = int(d.p2) if int(d.p1) == mens_id else int(d.p1)
	var kop := Label.new()
	kop.text = tr("HUB_DUEL_PAIRS_TITLE")
	kop.add_theme_font_size_override("font_size", 12)
	kop.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	_paneel.add_child(kop)
	for duel in c.duels_deze_ronde:
		var r := Label.new()
		var status: String = tr("BRACKET_DONE") if bool(duel.klaar) else tr("BRACKET_NOW_PLAYING")
		r.text = tr("BRACKET_DUEL_ROW") % [String(c.spelers[int(duel.p1)].naam),
			String(c.spelers[int(duel.p2)].naam), status]
		r.add_theme_font_size_override("font_size", 12)
		if int(duel.p1) == mens_id or int(duel.p2) == mens_id:
			r.add_theme_color_override("font_color", Color(0.98, 0.85, 0.4))
		elif bool(duel.klaar):
			r.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		_paneel.add_child(r)
	var titel := Label.new()
	titel.text = tr("HUB_DUEL_TITLE") % String(c.spelers[vijand].naam)
	titel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_paneel.add_child(titel)
	var knop := _knop(tr("HUB_DUEL_PLAY_BTN"), func() -> void:
		_start_mens_duel(vijand))
	knop.name = "SpeelDuelKnop"
	if _auto_stop_idx == int(d.idx):
		return
	var info := Label.new()
	info.text = tr("HUB_DUEL_AUTO")
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	_paneel.add_child(info)
	var blijf := _knop(tr("HUB_DUEL_STAY_BTN"), func() -> void:
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


## Laadscherm tonen en dan pas de (zware) scene-wissel doen — geen bevroren
## hub meer tussen klik en bord.
func _start_mens_duel(vijand: int) -> void:
	if _duel_start_bezig or not CampaignBridge.start_mens_duel():
		return
	_duel_start_bezig = true
	var lader := ColorRect.new()
	lader.color = Color(0.05, 0.06, 0.09, 1.0)
	lader.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tekst := Label.new()
	tekst.text = tr("HUB_DUEL_LOADING") % String(driver.c.spelers[vijand].naam)
	tekst.set_anchors_preset(Control.PRESET_FULL_RECT)
	tekst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tekst.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tekst.add_theme_font_size_override("font_size", 22)
	lader.add_child(tekst)
	add_child(lader)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _paneel_donatie(c: CState) -> void:
	# C11-UX (Max): doneren = een plusje achter de naam. [+1] geeft 1
	# versterkingspunt (1 soldaat), [+CP] geeft 1 CP; caps bewaakt de reducer.
	var titel := Label.new()
	titel.text = tr("HUB_DONATE_TITLE_PT")
	titel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_paneel.add_child(titel)
	var mijn_team: int = int(c.spelers[mens_id].team)
	var mijn_pool: Dictionary = c.pool_van(mens_id)
	for sid in c.actieve_leden(mijn_team):
		if int(sid) == mens_id:
			continue
		var rij := HBoxContainer.new()
		rij.add_theme_constant_override("separation", 8)
		var naam := Label.new()
		naam.text = String(c.spelers[int(sid)].naam)
		naam.custom_minimum_size = Vector2(140, 0)
		rij.add_child(naam)
		var doel: int = int(sid)
		var plus := Button.new()
		plus.text = tr("HUB_PLUS_VST")
		plus.disabled = int(mijn_pool.inf) <= 0
		plus.pressed.connect(func() -> void:
			if driver.submit_mens_donatie(doel, 1, 0, 0, 0):
				_ververs())
		rij.add_child(plus)
		var plus_cp := Button.new()
		plus_cp.text = tr("HUB_PLUS_CP")
		plus_cp.disabled = driver.c.cp_van(mens_id) <= 0
		plus_cp.pressed.connect(func() -> void:
			if driver.submit_mens_donatie(doel, 0, 0, 0, 1):
				_ververs())
		rij.add_child(plus_cp)
		_paneel.add_child(rij)
	var koers: int = maxi(1, c.rules.ruil_cp_per_punt)
	var ruil := Button.new()
	ruil.name = "RuilKnop"
	ruil.text = tr("HUB_RUIL_BTN") % koers
	ruil.disabled = c.cp_van(mens_id) < koers
	ruil.pressed.connect(func() -> void:
		if driver.submit_mens_ruil(koers):
			_ververs())
	_paneel.add_child(ruil)
	_knop(tr("HUB_DONATE_DONE_BTN"), func() -> void:
		driver.submit_mens_klaar_met_doneren()
		_werk_door())


func _paneel_testament(c: CState) -> void:
	var titel := Label.new()
	titel.text = tr("HUB_WILL_TITLE")
	titel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_paneel.add_child(titel)
	var doelen := OptionButton.new()
	doelen.name = "TestamentDoel"
	for id in c.spelers:
		if int(id) != mens_id and String(c.spelers[id].status) == "actief":
			doelen.add_item(tr("HUB_WILL_TARGET") % [c.spelers[id].naam, int(c.spelers[id].team)], int(id))
	_paneel.add_child(doelen)
	_knop(tr("HUB_WILL_HALF_BTN"), func() -> void:
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
	_knop(tr("HUB_WILL_NONE_BTN"), func() -> void:
		driver.submit_mens_testament([])
		_werk_door())
