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
		# Hervat de lopende solo-campagne als die er is; anders vers beginnen.
		if FileAccess.file_exists(SAVE_PAD):
			driver = SoloDriver.hervat(SAVE_PAD, mens_id)
			if driver != null and driver.c.fase == CState.Fase.KLAAR:
				driver = null  # uitgespeelde campagne: nieuwe starten
			elif driver != null and not driver.c.rules.ronde1_loting:
				driver = null  # oude regelset (voor C9): vers beginnen
		if driver == null:
			driver = SoloDriver.new(int(Time.get_unix_time_from_system()) % 900000,
				mens_id, 16, SAVE_PAD)
	CampaignBridge.driver = driver
	_bouw_layout()
	_ververs()
	_werk_door()


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
	grootboek.text = "Grootboek"
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
		await get_tree().create_timer(0.15).timeout
		if is_inside_tree():
			_poll_thread()
		return
	_thread.wait_to_finish()
	_bezig = false
	_ververs()
	if driver.c.fase != CState.Fase.KLAAR and not driver.wacht_op_mens():
		_werk_door()


# --- Weergave -------------------------------------------------------------------

const FASE_NAMEN := {
	CState.Fase.NOMINATIE: "De Raad nomineert",
	CState.Fase.DONATIE: "Donatie-venster",
	CState.Fase.DUELS: "De duels",
	CState.Fase.TESTAMENT: "Testament",
	CState.Fase.BURGEROORLOG: "BURGEROORLOG",
	CState.Fase.KLAAR: "Campagne voorbij",
}


func _ververs() -> void:
	var c: CState = driver.c
	var mijn: Dictionary = c.spelers.get(mens_id, {})
	_header.text = "Ronde %d — %s" % [c.ronde, FASE_NAMEN.get(c.fase, "?")]
	if c.fase == CState.Fase.KLAAR and c.winnaar != -1:
		_header.text = "KAMPIOEN: %s" % String(c.spelers[c.winnaar].naam)
	var pool: Dictionary = c.pool_van(mens_id)
	_saldi.text = "Jij (%s, team %d): %d soldaten · %d cavalerie · %d kanonnen · %d CP · %d punten%s" % [
		String(mijn.get("naam", "?")), int(mijn.get("team", 0)),
		int(pool.inf), int(pool.cav), int(pool.art), c.cp_van(mens_id), c.punten_van(mens_id),
		"" if String(mijn.get("status", "")) == "actief" else "  [UITGEVALLEN — je ziet nu alles]"]
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
	for gegevens in [[_team_links, mijn_team, "JOUW TEAM"], [_team_rechts, 1 - mijn_team, "DE VIJAND"]]:
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
		markering = " (jij)"
	if vecht and not dood:
		markering += "  [VECHT]"
	naam.text = String(sp.naam) + markering
	naam.add_theme_font_size_override("font_size", 13)
	if dood:
		naam.add_theme_color_override("font_color", KLEUR_DOOD)
	elif sid == mens_id:
		naam.add_theme_color_override("font_color", Color(0.98, 0.85, 0.4))
	tekst.add_child(naam)
	var saldo := Label.new()
	if dood:
		saldo.text = "gevallen"
	else:
		var pool: Dictionary = c.pool_van(sid)
		saldo.text = "%d·%d·%d · %d CP · %d pt" % [int(pool.inf), int(pool.cav),
			int(pool.art), c.cp_van(sid), c.punten_van(sid)]
	saldo.add_theme_font_size_override("font_size", 11)
	saldo.add_theme_color_override("font_color",
		KLEUR_DOOD if dood else Color(0.72, 0.78, 0.86))
	tekst.add_child(saldo)
	rij.add_child(tekst)
	return rij


func _ververs_tijdlijn() -> void:
	while _feed_getoond < driver.feed.size():
		var e: Dictionary = driver.feed[_feed_getoond]
		_feed_getoond += 1
		var kaart := PanelContainer.new()
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 13)
		if String(e.type) == "bark":
			label.text = "R%d · %s: \"%s\"" % [int(e.ronde), String(e.naam), String(e.tekst)]
			label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95))
		elif String(e.type) == "report":
			var c: CState = driver.c
			var p1n := String(c.spelers[int(e.p1)].naam)
			var p2n := String(c.spelers[int(e.p2)].naam)
			var uitslag := "remise" if int(e.winnaar) == -1 else "%s wint (%s)" % [
				String(c.spelers[int(e.winnaar)].naam), String(e.methode)]
			label.text = "R%d · BATTLEREPORT: %s vs %s — %s, %d cycli" % [
				int(e.ronde), p1n, p2n, uitslag, int(e.cycli)]
			label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
			# F3.3-rest: tik het kaartje voor het volledige rapport.
			kaart.tooltip_text = "Tik voor het volledige battlereport"
			kaart.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
					_toon_report(e))
		kaart.add_child(label)
		_tijdlijn.add_child(kaart)
	await get_tree().process_frame
	if is_inside_tree():
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


## F3.3-rest — MatchReport-detail: het hele battlereport in een dialoog.
func _toon_report(e: Dictionary) -> void:
	var c: CState = driver.c
	var regels: Array = []
	var uitslag := "Remise — beide een tiebreak-punt."
	if int(e.winnaar) != -1:
		uitslag = "%s wint via %s." % [String(c.spelers[int(e.winnaar)].naam), String(e.methode)]
	regels.append("%s vs %s, ronde %d — %s (%d cycli)" % [
		String(c.spelers[int(e.p1)].naam), String(c.spelers[int(e.p2)].naam),
		int(e.ronde), uitslag, int(e.cycli)])
	regels.append("")
	var cp_delta: Dictionary = e.get("cp_delta", {})
	for sid in [int(e.p1), int(e.p2)]:
		var v: Dictionary = (e.verliezen as Dictionary).get(str(sid), {})
		regels.append("%s: -%d soldaten, -%d cavalerie, -%d kanonnen · CP %+d" % [
			String(c.spelers[sid].naam), int(v.get("inf", 0)), int(v.get("cav", 0)),
			int(v.get("art", 0)), int(cp_delta.get(str(sid), 0))])
	var dlg := AcceptDialog.new()
	dlg.title = "Battlereport"
	dlg.dialog_text = "\n".join(regels)
	dlg.ok_button_text = "Sluiten"
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
		return
	if c.fase == CState.Fase.BURGEROORLOG:
		var bv := BracketView.new()
		bv.name = "BracketView"
		bv.vul(c)
		_paneel.add_child(bv)
	if not driver.wacht_op_mens():
		var info := Label.new()
		info.text = "De bots zijn bezig..." if _bezig else "Wachten op de volgende fase."
		_paneel.add_child(info)
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


func _paneel_nominatie(c: CState) -> void:
	var titel := Label.new()
	titel.text = "Jouw team nomineert: kies de vechters."
	_paneel.add_child(titel)
	var eigen := OptionButton.new()
	eigen.name = "EigenKeuze"
	var vijand := OptionButton.new()
	vijand.name = "VijandKeuze"
	var mijn_team: int = int(c.spelers[mens_id].team)
	for sid in c.actieve_leden(mijn_team):
		if not c.al_genomineerd.has(sid):
			eigen.add_item("%s (jij)" % c.spelers[sid].naam if sid == mens_id else String(c.spelers[sid].naam), sid)
	for sid in c.actieve_leden(1 - mijn_team):
		if not c.al_genomineerd.has(sid):
			vijand.add_item(String(c.spelers[sid].naam), sid)
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 8)
	rij.add_child(eigen)
	rij.add_child(vijand)
	_paneel.add_child(rij)
	_knop("Stem", func() -> void:
		if eigen.selected >= 0 and vijand.selected >= 0:
			driver.submit_mens_nominatie(eigen.get_selected_id(), vijand.get_selected_id())
			_werk_door())


## F3.4b — het mens-duel speelt op het echte bord: de brug zet de config klaar.
func _paneel_duel(c: CState) -> void:
	var d: Dictionary = driver.mens_duel()
	if d.is_empty():
		return
	var vijand: int = int(d.p2) if int(d.p1) == mens_id else int(d.p1)
	var titel := Label.new()
	titel.text = "JOUW DUEL: jij tegen %s. Je hele bezit gaat mee het bord op — wat je verliest ben je kwijt, wat je spaart neem je mee." % String(c.spelers[vijand].naam)
	titel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_paneel.add_child(titel)
	var knop := _knop("Speel het duel op het bord", func() -> void:
		if CampaignBridge.start_mens_duel():
			get_tree().change_scene_to_file("res://scenes/game/game.tscn"))
	knop.name = "SpeelDuelKnop"


func _paneel_donatie(c: CState) -> void:
	var titel := Label.new()
	titel.text = "Doneer aan een teamgenoot (max 10 pionnen / 3 CP per ontvanger), of houd alles."
	titel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_paneel.add_child(titel)
	var mijn_team: int = int(c.spelers[mens_id].team)
	var doelen := OptionButton.new()
	doelen.name = "DoneerDoel"
	# C9: doneren mag aan elke levende teamgenoot.
	for sid in c.actieve_leden(mijn_team):
		if int(sid) != mens_id:
			doelen.add_item(String(c.spelers[int(sid)].naam), int(sid))
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 6)
	var invoer: Dictionary = {}
	for veld in ["inf", "cav", "art", "cp"]:
		var spin := SpinBox.new()
		spin.name = "Spin_" + veld
		spin.min_value = 0
		spin.max_value = 10
		spin.prefix = veld + " "
		invoer[veld] = spin
		rij.add_child(spin)
	if doelen.item_count > 0:
		_paneel.add_child(doelen)
		_paneel.add_child(rij)
		_knop("Doneer", func() -> void:
			if doelen.selected >= 0:
				driver.submit_mens_donatie(doelen.get_selected_id(),
					int(invoer.inf.value), int(invoer.cav.value),
					int(invoer.art.value), int(invoer.cp.value))
				_ververs())
	_knop("Klaar met doneren", func() -> void:
		driver.submit_mens_klaar_met_doneren()
		_werk_door())


func _paneel_testament(c: CState) -> void:
	var titel := Label.new()
	titel.text = "Je bent uitgevallen. Laat maximaal de helft na aan maximaal 2 ontvangers — de rest verbrandt."
	titel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_paneel.add_child(titel)
	var doelen := OptionButton.new()
	doelen.name = "TestamentDoel"
	for id in c.spelers:
		if int(id) != mens_id and String(c.spelers[id].status) == "actief":
			doelen.add_item("%s (team %d)" % [c.spelers[id].naam, int(c.spelers[id].team)], int(id))
	_paneel.add_child(doelen)
	_knop("Laat de helft na aan deze speler", func() -> void:
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
	_knop("Laat niets na (alles verbrandt)", func() -> void:
		driver.submit_mens_testament([])
		_werk_door())
