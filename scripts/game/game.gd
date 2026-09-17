extends Node

const PAWN_SCENE := preload("res://scenes/game/pawn_view.tscn")
const BOARD_SCENE := preload("res://Board.tscn")
const OVERLAY_SCENE := preload("res://scenes/ui/overlay.tscn")
const INSTRUCTIONS_SCRIPT := preload("res://scripts/ui/instructions.gd")
const AUTO_AI_SCRIPT := preload("res://scripts/ai/AIMedium.gd")  # timeout-zet voor de mens
## UI-assetpack (3 september): via preload, zodat game.gd ook parst voordat de
## klassencache (--import) de class_names HudBalk / FactieKeuzeScherm /
## EindeScherm kent.
const HUD_BALK_SCRIPT := preload("res://scripts/ui/match/hud_balk.gd")
const FACTIE_KEUZE_SCRIPT := preload("res://scripts/ui/match/factie_keuze_scherm.gd")
const EINDE_SCHERM_SCRIPT := preload("res://scripts/ui/match/einde_scherm.gd")
const ONTHUL_SCHERM_SCRIPT := preload("res://scripts/ui/match/onthul_scherm.gd")
const PAWN_Y := 0.05

## AI difficulty: 0 = Easy, 1 = Medium, 2 = Hard
@export var ai_difficulty: int = 1

@onready var _world: Node3D = $World
@onready var _pawns_root: Node3D = $World/Pawns
@onready var _card_hand: CardHand = $UI/CardHand
var _koppel_pijl: KoppelPijl = null   # 16 september: gebogen pijl bij het slepen van een kaart naar een pion
const VLUCHT_DUUR := 0.34   # de kaart die na het loslaten langs de pijl naar de pion gaat
@onready var _top_label: Label = $UI/TopLabel
@onready var _prompt_label: Label = $UI/PromptLabel
@onready var _count_label: RichTextLabel = $UI/CountLabel

var _board: Node3D
var _omgeving: Omgeving = null   # het diorama om het bord (gras, wolken, klik-props)
var _camera: Camera3D
var _instructions = null  # InstructionsScreen (uitleg-tab, altijd via "?" te openen)
var _human_auto_ai = null # greedy zet-kiezer voor de mens bij beurt-timeout
var _tiles: Dictionary = {}          # Vector2i -> tile Node3D
var _pawn_views: Dictionary = {}     # pawn_id -> PawnView
var _highlights: Array[Node3D] = []
var _ai = null
var _ai_thread: Thread = null
var _overlay = null

var _selected_pawn_id: int = -1
var _selected_link_card_id: int = -1
var _valid_moves: Array = []
var _valid_attacks: Array = []       # pawn ids: melee-doelwitten (aangrenzend)
var _valid_shots: Array = []         # pawn ids: schot-doelwitten (vuurlijn)
var _valid_charges: Dictionary = {}  # enemy pawn id -> beste move_target (cavalerie)
var _wolf_step_mode: bool = false    # wacht op klik voor de gratis Wolf-stap
var _wolf_step_tiles: Array = []
# Zelf opstellen: minste type eerst (kanonnen → paarden), infanterie vult aan.
var _placement_mode: bool = false
var _placement_steps: Array = []     # [{type, count}] handmatig te plaatsen
var _placement_placed: Array = []    # [{type, pos}]
var _placement_previews: Dictionary = {}  # Vector2i -> PawnView (voorvertoning)
var _placement_ghost: Node3D = null       # semi-doorzichtig stuk onder de muis
var _placement_ghost_type: int = -1
var _human_doctrine: int = Constants.Doctrine.MENS
var _ai_doctrine: int = Constants.Doctrine.MENS
var _campaign_mode: bool = true  # elk potje is een v4.2-duel (CP + versterkingen)
var _hovered_pawn_id: int = -1
var _hp_layer: Control = null
var _hp_bars: Dictionary = {}        # pawn_id -> {holder, blocks}
var _tweening_pawns: Dictionary = {} # pawn_id -> true tijdens beweeg-animatie
var _timer_active: bool = false
var _timer_left: float = 0.0
var _last_tick_second: int = -1      # laatst afgespeelde aftel-tik
var _tick_accum: float = 0.0         # tempo-teller voor de snelle eind-tikken
# Combat feel (Valheim-stijl "juice"): stagger + screen shake + hitstop + ragdoll.
var _combat_feel: bool = true         # alles behalve shake
var _screen_shake: bool = true        # apart uitzetbaar (motion sickness)
# --- Sfeer/ambiance (toets L: paneel met live licht-sliders) ---
var _sun_light: DirectionalLight3D = null
var _spot_light: SpotLight3D = null
var _rim_light: DirectionalLight3D = null
var _env: Environment = null
var _grid_mat: StandardMaterial3D = null
var _haven_mats: Array = []  # doorzichtige haven-plakkaten (rood/blauw)
var _aura_gloed: Array = []       # C21: per aura-tegel {node, mat, basis, rol, pos}; de gloeiende rand
var _aura_sleutel: String = ""    # C21: staat-sleutel van de gebouwde auras (alleen herbouwen bij verandering)
var _ambiance_panel: PanelContainer = null
var _audio_panel: PanelContainer = null   # geluidsinstellingen (instellingenmenu)
var _dust_motes: Array = []
var _footprints: Array = []  # blijven staan tot de cyclus voorbij is
var _footstep_cache: Dictionary = {}  # pad -> Texture2D of null (assets/textures/footstep/)
var _shake_amt: float = 0.0
var _cam_base: Vector3 = Vector3.ZERO
var _in_hitstop: bool = false
var _dying_views: Dictionary = {}     # pawn_id -> true zolang de ragdoll speelt
# BUG-FIX (Max, 30 juli): de regels zetten een melee-winnaar METEEN op het
# vrijgekomen vak, dus de eerste _refresh_all teleporteerde hem er al naartoe
# terwijl zijn stoot nog liep. Zolang hij hier staat, houdt de view hem op zijn
# eigen tegel; _begin_advance haalt hem eruit en laat hem netjes overlopen.
var _advance_holds: Dictionary = {}   # pawn_id -> Vector2i (tegel waar hij nog staat)
var _auto_link_human: bool = false   # koppelen automatisch afmaken na timeout

const PHASE_TIME_LIMIT := 20.0

var _human_id: int = Constants.PLAYER_1
var _ai_id: int = Constants.PLAYER_2

## F4.3b -- de sessie waar game.gd tegen praat. Offline de autoload
## GameSession (die IS de LocalSession), online straks een RemoteSession met
## dezelfde signals en submits. De enige regel die GameSession nog bij naam
## noemt is de toewijzing in _ready.
var session: SessionInterface = null
var _verbonden_sessie: Object = null
var _loopback: LoopbackTransport = null   # F4.3g: houdt de oefen-server in leven
var _kijk_pivot: Node3D = null            # F4.3g: camera + lichten; draait voor speler 2
var _cp_bet_keuze: int = 0                 # F4.3g: online reist de inzet in de define mee

## UI-assetpack (3 september): de perkamenten HUD-balk achter de drie labels
## (scripts/ui/match/hud_balk.gd) en het factie-keuzescherm (regimentskaarten,
## scripts/ui/match/factie_keuze_scherm.gd), in _ready direct boven de overlay.
var _hud_balk: HUD_BALK_SCRIPT = null
var _factie_keuze: FACTIE_KEUZE_SCRIPT = null
## Het onthulscherm (beide handen als echte kaarten, scripts/ui/match/
## onthul_scherm.gd): lazy in _on_cards_revealed, direct boven de overlay.
var _onthul_scherm: ONTHUL_SCHERM_SCRIPT = null


func _ready() -> void:
	session = GameSession
	_board = BOARD_SCENE.instantiate()
	_world.add_child(_board)
	_world.move_child(_board, 0)
	_pawns_root.reparent(_board, false)
	_setup_battlefield_lighting()
	_setup_board_model()
	_camera = _board.get_node("Camera3D") as Camera3D
	_cam_base = _camera.position  # rustpositie voor de screen shake
	# F4.3g: camera EN lichten onder één kijk-pivot, zodat voor speler 2 het
	# hele gezichtspunt (inclusief zon, spot en rim) 180 graden om het
	# bordcentrum draait. De pivot staat op identiteit, dus de kinderen
	# houden hun bord-coördinaten en het sfeer-paneel blijft gewoon werken.
	_kijk_pivot = Node3D.new()
	_kijk_pivot.name = "Kijkrichting"
	_board.add_child(_kijk_pivot)
	for node in [_camera, _sun_light, _spot_light, _rim_light]:
		if node != null:
			(node as Node3D).reparent(_kijk_pivot, true)
	_setup_omgeving()
	Audio.play_ambient("ambient_field")  # veld-ambience onder menu én spel
	_index_tiles()
	_connect_session_signals()
	_card_hand.define_confirmed.connect(_on_define_confirmed)
	_card_hand.card_picked.connect(_on_link_card_picked)
	_card_hand.drag_moved.connect(_on_koppel_sleep)
	_card_hand.drag_dropped.connect(_on_koppel_drop)
	_card_hand.drag_cancelled.connect(_on_koppel_annuleer)
	_overlay = OVERLAY_SCENE.instantiate()
	$UI.add_child(_overlay)
	_overlay.hide()
	# De sleep-pijl bovenop alles in de UI-laag (vangt nooit invoer).
	_koppel_pijl = KoppelPijl.new()
	_koppel_pijl.name = "KoppelPijl"
	$UI.add_child(_koppel_pijl)
	_factie_keuze = FACTIE_KEUZE_SCRIPT.new()  # direct boven de overlay, onder uitleg en knoppen
	$UI.add_child(_factie_keuze)
	_instructions = INSTRUCTIONS_SCRIPT.new()
	$UI.add_child(_instructions)
	_build_help_button()
	_bouw_context_knop()
	_hud_balk = HUD_BALK_SCRIPT.new()
	_hud_balk.bouw_in($UI, _top_label, _prompt_label, _count_label)
	_hp_layer = Control.new()
	_hp_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(_hp_layer)
	# Achter de kaarten/overlay/HUD renderen (blokjes mogen die niet bedekken).
	$UI.move_child(_hp_layer, 0)
	_card_hand.visible = false
	if CampaignBridge.duel_actief:
		_start_campagne_duel()  # F3.4b: de hub heeft dit duel klaargezet
	else:
		_show_difficulty_menu()


func _process(delta: float) -> void:
	_update_screen_shake(delta)
	_update_health_bars()
	_werk_aura_bij()
	_update_context_knop()
	if _timer_active:
		_timer_left -= delta
		if _timer_left <= 0.0:
			_timer_active = false
			_on_phase_timeout()
		else:
			var st: GameState = session.state
			_top_label.text = tr("HUD_TOPBAR_TIMER") % [
				st.cycle, st.round_number, _phase_label(st.phase), int(ceil(_timer_left))]
			if _hud_balk != null: _hud_balk.zet_timer(_timer_left)
			# Aftel-tik in de laatste 5 sec; de laatste 3 sec tikt dezelfde klok
			# op dubbel tempo en iets hoger — versnelling i.p.v. een apart geluid.
			var sec_left: int = int(ceil(_timer_left))
			if sec_left > 3:
				_tick_accum = 0.5  # zodat de snelle reeks direct start bij 3 sec
				if sec_left <= 5 and sec_left != _last_tick_second:
					_last_tick_second = sec_left
					Audio.play("timer_tick")
			else:
				_tick_accum += delta
				if _tick_accum >= 0.5:
					_tick_accum -= 0.5
					Audio.play("timer_tick", 0.0, -1, 1.12)


func _start_phase_timer(seconds: float) -> void:
	_timer_active = true
	# F0.8: staan er klokken in de match-config (state.turn_deadline gezet),
	# dan is de engine-deadline leidend; anders het vaste offline-limiet.
	# F4.3c: de klok komt via de sessie (paar deadline/servertijd; F4.4 zet
	# de server-offset). Zonder klok en zonder bot (online) loopt er GEEN
	# lokale timer: dan zou game.gd zelf zetten kiezen namens de mens.
	var k: Dictionary = session.klok()
	if int(k.deadline_ms) > 0:
		_timer_left = maxf(0.1, float(int(k.deadline_ms) - Time.get_ticks_msec()) / 1000.0)
	elif _ai == null:
		_timer_active = false
		return
	else:
		_timer_left = seconds
	_last_tick_second = -1  # aftel-tikken opnieuw laten beginnen


## Opgeven met bevestiging; de winst gaat via het normale game_over-pad.
func _on_resign_pressed() -> void:
	var ph: int = session.state.phase
	if ph == Phase.Type.GAME_OVER or ph == Phase.Type.PRE_GAME:
		return
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = tr("MENU_RESIGN_CONFIRM")
	dlg.ok_button_text = tr("MENU_RESIGN_OK")
	dlg.cancel_button_text = tr("MENU_RESIGN_CANCEL")
	dlg.confirmed.connect(func() -> void: session.submit_resign(_human_id))
	$UI.add_child(dlg)
	dlg.popup_centered()


func _stop_phase_timer() -> void:
	_timer_active = false


func _on_phase_timeout() -> void:
	var ph: int = session.state.phase
	if Phase.is_define(ph) and session.state.cards_defined[_human_id].size() == 0 \
			and Validator.expected_define_count(session.state, _human_id) > 0:
		if session.state.rules.campaign_actief() and not _card_hand.visible:
			# CP-bod-overlay stond nog open: zonder inzet door naar de waaier.
			_overlay.hide()
			_open_define_hand(int(session.state.cp_bets.get(_human_id, 0)))
		_card_hand._on_confirm_pressed()  # auto-bevestig (altijd geldig)
	elif ph == Phase.Type.CYCLE_SPAWN and not session.state.spawn_done.get(_human_id, false):
		_overlay.hide()
		_update_hud(tr("HUD_TIMEOUT_SPAWN"))
		session.submit_spawn(_human_id, Validator.aanvul_spawn_actie(session.state, _human_id).spawns)
		if _ai == null and session.state.phase == Phase.Type.CYCLE_SPAWN:
			_update_hud(tr("HUD_WAIT_OPPONENT"))
	elif Phase.is_linking(ph):
		_auto_link_human = true
		if session.state.current_player == _human_id:
			_auto_link(_human_id)
	elif ph == Phase.Type.PLACEMENT and _placement_mode:
		# Tijd om tijdens zelf opstellen → val terug op de standaard-opstelling.
		_cancel_manual_placement()
	elif ph == Phase.Type.ACTION and session.state.current_player == _human_id:
		# Tijd om in de actiefase → het spel doet een redelijke zet voor je.
		_auto_action_human()


## Zelf opstellen afbreken (bv. timeout) → previews opruimen + standaard-opstelling.
func _cancel_manual_placement() -> void:
	_placement_mode = false
	_placement_placed = []
	_clear_highlights()
	if _placement_ghost != null:
		_placement_ghost.queue_free()
		_placement_ghost = null
		_placement_ghost_type = -1
	for pv in _placement_previews.values():
		pv.queue_free()
	_placement_previews = {}
	_update_hud(tr("HUD_TIMEOUT_PLACEMENT"))
	_confirm_placement()


## Timeout in de actiefase: kies greedy een zet voor de mens (zelfde motor als de AI).
func _auto_action_human() -> void:
	var state: GameState = session.state
	if state.phase != Phase.Type.ACTION or state.current_player != _human_id:
		return
	_deselect()
	if state.pending_wolf_step_pawn != -1:
		_end_wolf_step_mode()
		session.skip_wolf_step(_human_id)
		return
	if _human_auto_ai == null:
		_human_auto_ai = AUTO_AI_SCRIPT.new()
		_human_auto_ai.player_id = _human_id
	var action: Dictionary = _human_auto_ai.best_greedy_action(state)
	if action.is_empty():
		return
	_update_hud(tr("HUD_TIMEOUT_ACTION"))
	match String(action.type):
		"move":
			if _kanon_v42(int(action.pawn_id)):
				session.submit_cannon_roll(_human_id, action.pawn_id, action.target)
			else:
				session.submit_move(_human_id, action.pawn_id, action.target)
		"attack":
			session.submit_attack(_human_id, action.attacker_id, action.defender_id)
		"shot":
			if _kanon_v42(int(action.shooter_id)):
				session.submit_cannon_shoot(_human_id, action.shooter_id, action.target_id)
			else:
				session.submit_shot(_human_id, action.shooter_id, action.target_id)
		"charge":
			session.submit_charge(_human_id, action.pawn_id, action.move_target, action.defender_id)


func _exit_tree() -> void:
	# Wacht een lopende AI-thread netjes af zodat 'ie niet verweesd wordt afgesloten.
	if _ai_thread != null and _ai_thread.is_started():
		_ai_thread.wait_to_finish()
		_ai_thread = null


func _show_difficulty_menu() -> void:
	_card_hand.visible = false
	_clear_highlights()
	_top_label.text = tr("MENU_TITLE")
	_prompt_label.text = ""
	# Hoofdmenu-herstructurering (besluit Max, 27 juli): vier simpele knoppen.
	# SOLO -> 1v1 of Campagne -> dan pas de moeilijkheid; AI Trainer is uit
	# het menu, Model-tuner zit onder Instellingen.
	_overlay.show_choice(
		tr("MENU_MAIN_TITLE"),
		tr("MENU_MAIN_BODY"),
		[tr("MENU_SOLO"), tr("MENU_MULTI"), tr("MENU_RULES_OPTION"), tr("MENU_SETTINGS")],
		_on_hoofdmenu_choice,
		Color.WHITE, false, ["act-melee", "", "hidden", ""],
	)


func _on_hoofdmenu_choice(index: int) -> void:
	if index == 0:
		_show_solo_menu()
	elif index == 1:
		_show_multi_menu()
	elif index == 2:
		_show_rules_overlay(func() -> void: _show_difficulty_menu())
	else:
		_show_settings_menu()


## F4.3g -- multiplayer-menu: oefenen via de online-weg (RemoteSession op een
## loopback met een bot), als rood of als blauw; "Online" komt met stap i.
func _show_multi_menu() -> void:
	_overlay.show_choice(tr("MENU_MULTI"), tr("MENU_MULTI_BODY"),
		[tr("MENU_MULTI_PRACTICE_RED"), tr("MENU_MULTI_PRACTICE_BLUE"), tr("MENU_MULTI_ONLINE"), tr("MENU_BACK")],
		func(i: int) -> void:
			if i == 0:
				_start_oefenpotje(Constants.PLAYER_1)
			elif i == 1:
				_start_oefenpotje(Constants.PLAYER_2)
			elif i == 2:
				_show_online_lobby()
			else:
				_show_difficulty_menu())


# --- Online lobby (F4.3i) --------------------------------------------------------

var _online_wachten: bool = false


## Verbinden (gast-login + core-hash) en dan de keuzes tonen.
func _show_online_lobby() -> void:
	_overlay.hide()
	_update_hud(tr("MENU_ONLINE_CONNECTING"))
	OnlineBridge.verbind(func(ok: bool, fout: String) -> void:
		if not ok:
			_online_fout(fout, func() -> void: _show_multi_menu())
			return
		_show_online_keuzes()
	)


func _show_online_keuzes() -> void:
	var id: Identiteit = OnlineBridge.laad_identiteit()
	var opties: Array = [tr("MENU_ONLINE_NEW"), tr("MENU_ONLINE_JOIN")]
	var hervat: bool = id.laatste_match_id != ""
	if hervat:
		opties.append(tr("MENU_ONLINE_RESUME"))
	opties.append(tr("MENU_BACK"))
	_update_hud("")
	_overlay.show_choice(tr("MENU_MULTI_ONLINE_TITLE"),
		tr("MENU_ONLINE_BODY") % [id.naam, id.server_url], opties,
		func(i: int) -> void:
			if i == 0:
				_online_nieuwe_match()
			elif i == 1:
				_online_meedoen()
			elif hervat and i == 2:
				_online_hervatten()
			else:
				_show_multi_menu(),
		Color.WHITE, true)


func _online_fout(fout: String, terug: Callable) -> void:
	_overlay.show_choice(tr("MENU_ONLINE_ERROR_TITLE"), fout, [tr("MENU_BACK")],
		func(_i: int) -> void: terug.call())


func _online_nieuwe_match() -> void:
	OnlineBridge.nieuwe_match(_potje_regels(), func(a: Dictionary) -> void:
		if not bool(a.get("ok", false)):
			_online_fout(String(a.get("fout", "?")), func() -> void: _show_online_keuzes())
			return
		_wacht_op_tegenstander()
	)


## De match-id groot in beeld (met kopieerknop) tot de ander meedoet.
func _wacht_op_tegenstander() -> void:
	var id: String = OnlineBridge.match_id
	_overlay.show_choice(tr("MENU_ONLINE_WAIT_TITLE"), tr("MENU_ONLINE_WAIT_BODY") % id,
		[tr("MENU_ONLINE_COPY"), tr("MENU_ONLINE_CANCEL")],
		func(i: int) -> void:
			if i == 0:
				DisplayServer.clipboard_set(id)
				_wacht_op_tegenstander()
			else:
				_online_wachten = false
				OnlineBridge.klaar_met_match()
				_show_online_keuzes())
	if not _online_wachten:
		_online_wachten = true
		_poll_tot_bezig()


func _poll_tot_bezig() -> void:
	if not _online_wachten:
		return
	OnlineBridge.status(func(a: Dictionary) -> void:
		if not _online_wachten:
			return
		if bool(a.get("ok", false)) and String(a.get("status", "")) == "bezig":
			_online_wachten = false
			_overlay.hide()
			_start_online(OnlineBridge.sessie())
		else:
			get_tree().create_timer(2.0).timeout.connect(_poll_tot_bezig)
	)


## Meedoen: een invoerveld voor de match-id (het klembord vult hem in als
## daar net een id op staat).
func _online_meedoen() -> void:
	_overlay.hide()
	var midden := CenterContainer.new()
	midden.set_anchors_preset(Control.PRESET_FULL_RECT)
	var paneel := PanelContainer.new()
	midden.add_child(paneel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	paneel.add_child(box)
	var kop := Label.new()
	kop.text = tr("MENU_ONLINE_JOIN_HINT")
	kop.add_theme_font_size_override("font_size", 24)
	box.add_child(kop)
	var invoer := LineEdit.new()
	invoer.custom_minimum_size = Vector2(620, 48)
	invoer.add_theme_font_size_override("font_size", 22)
	var klem: String = DisplayServer.clipboard_get().strip_edges()
	if klem.length() == 36 and klem.count("-") == 4:
		invoer.text = klem
	box.add_child(invoer)
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 12)
	box.add_child(rij)
	var ok := Button.new()
	ok.text = tr("MENU_ONLINE_JOIN")
	ok.custom_minimum_size = Vector2(300, 52)
	rij.add_child(ok)
	var terug := Button.new()
	terug.text = tr("MENU_BACK")
	terug.custom_minimum_size = Vector2(200, 52)
	rij.add_child(terug)
	$UI.add_child(midden)
	invoer.grab_focus()
	terug.pressed.connect(func() -> void:
		midden.queue_free()
		_show_online_keuzes())
	var doe := func() -> void:
		var id: String = invoer.text.strip_edges()
		if id.length() < 8:
			return
		midden.queue_free()
		OnlineBridge.meedoen(id, func(a: Dictionary) -> void:
			if not bool(a.get("ok", false)):
				_online_fout(String(a.get("fout", "?")), func() -> void: _show_online_keuzes())
				return
			_start_online(OnlineBridge.sessie()))
	ok.pressed.connect(doe)
	invoer.text_submitted.connect(func(_t: String) -> void: doe.call())


func _online_hervatten() -> void:
	OnlineBridge.hervatten(func(a: Dictionary) -> void:
		var st: String = String(a.get("status", ""))
		if not bool(a.get("ok", false)):
			_online_fout(String(a.get("fout", "?")), func() -> void: _show_online_keuzes())
		elif st == "bezig":
			_start_online(OnlineBridge.sessie())
		elif st == "klaar":
			OnlineBridge.klaar_met_match()
			_online_fout(tr("MENU_ONLINE_FINISHED"), func() -> void: _show_online_keuzes())
		else:
			_wacht_op_tegenstander()
	)


func _show_solo_menu() -> void:
	_overlay.show_choice(tr("MENU_SOLO"), tr("MENU_SOLO_BODY"),
		[tr("MENU_SOLO_1V1"), tr("MENU_SOLO_CAMPAIGN"), tr("MENU_BACK")],
		func(i: int) -> void:
			if i == 0:
				_show_1v1_difficulty()
			elif i == 1:
				_show_campagne_difficulty()
			else:
				_show_difficulty_menu(),
		Color.WHITE, false, ["act-melee", "score", ""])


func _show_1v1_difficulty() -> void:
	_overlay.show_choice(tr("MENU_DIFF_TITLE"), tr("MENU_DIFF_BODY"),
		[tr("MENU_DIFF_EASY"), tr("MENU_DIFF_MEDIUM"), tr("MENU_DIFF_HARD"), tr("MENU_DIFF_ULTRA"), tr("MENU_BACK")],
		func(i: int) -> void:
			if i >= 4:
				_show_solo_menu()
			else:
				ai_difficulty = i
				_show_doctrine_menu())


## De campagne-moeilijkheid schaalt jouw bord-tegenstander (easy/medium/hard).
func _show_campagne_difficulty() -> void:
	_overlay.show_choice(tr("MENU_SOLO_CAMPAIGN"), tr("MENU_CAMP_DIFF_BODY"),
		[tr("MENU_DIFF_EASY"), tr("MENU_DIFF_MEDIUM"), tr("MENU_DIFF_HARD"), tr("MENU_BACK")],
		func(i: int) -> void:
			if i >= 3:
				_show_solo_menu()
				return
			CampaignBridge.campagne_moeilijkheid = i
			get_tree().change_scene_to_file("res://scenes/campaign/campaign.tscn"))


func _show_settings_menu() -> void:
	var taal_optie: String = "Language: English" if Constants.get_language() == "nl" else "Taal: Nederlands"
	_overlay.show_choice(tr("MENU_SETTINGS"), "",
		[taal_optie, tr("MENU_AUDIO"), tr("MENU_DIFF_TUNER"), tr("MENU_BACK")],
		func(i: int) -> void:
			if i == 0:
				Constants.set_language("en" if Constants.get_language() == "nl" else "nl")
				_show_settings_menu()
			elif i == 1:
				_show_audio_panel()
			elif i == 2:
				get_tree().change_scene_to_file("res://scenes/tools/ModelTuner.tscn")
			else:
				_show_difficulty_menu())


## Geluidsinstellingen (Max, 8 september: "audio controllers in settings,
## belangrijk"): vier schuiven (alles, muziek, effecten, omgeving), meteen
## hoorbaar en bewaard in user://settings.cfg via Audio.zet_volume. Toets M
## dempt daarnaast alles tijdelijk. Elke keer opnieuw opgebouwd, zodat een
## taalwissel in hetzelfde menu meteen doorwerkt.
const AUDIO_SOORTEN: Array = [
	["alles", "MENU_AUDIO_ALL"], ["muziek", "MENU_AUDIO_MUSIC"],
	["effecten", "MENU_AUDIO_SFX"], ["omgeving", "MENU_AUDIO_AMBIENT"],
]


func _show_audio_panel() -> void:
	_overlay.hide()
	if _audio_panel != null:
		_audio_panel.queue_free()
	_audio_panel = PanelContainer.new()
	_audio_panel.custom_minimum_size = Vector2(600.0, 0.0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_audio_panel.add_child(vbox)
	var title := Label.new()
	title.text = tr("MENU_AUDIO")
	title.theme_type_variation = "LabelInkt"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	for soort in AUDIO_SOORTEN:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var lbl := Label.new()
		lbl.text = tr(String(soort[1]))
		lbl.theme_type_variation = "LabelInkt"
		lbl.custom_minimum_size = Vector2(170.0, 0.0)
		lbl.add_theme_font_size_override("font_size", 22)
		row.add_child(lbl)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.value = round(Audio.volume(String(soort[0])) * 100.0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.custom_minimum_size = Vector2(260.0, 0.0)
		row.add_child(slider)
		var val := Label.new()
		val.text = "%d%%" % int(slider.value)
		val.theme_type_variation = "LabelInkt"
		val.custom_minimum_size = Vector2(70.0, 0.0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.add_theme_font_size_override("font_size", 22)
		row.add_child(val)
		slider.value_changed.connect(_on_audio_slider.bind(String(soort[0]), val))
		# Loslaten = een proefgeluid, zodat je hoort wat je instelde.
		slider.drag_ended.connect(func(_veranderd: bool) -> void: Audio.play("inf_select"))
		vbox.add_child(row)
	var hint := Label.new()
	hint.text = tr("MENU_AUDIO_HINT")
	hint.theme_type_variation = "LabelInktZacht"
	hint.add_theme_font_size_override("font_size", 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	var terug := Button.new()
	terug.text = tr("MENU_BACK")
	terug.theme_type_variation = "KnopBreed"
	terug.pressed.connect(func() -> void:
		_audio_panel.visible = false
		_show_settings_menu())
	vbox.add_child(terug)
	$UI.add_child(_audio_panel)
	# Gecentreerd, en dat blijft zo als het paneel met de inhoud meegroeit.
	_audio_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_audio_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_audio_panel.grow_vertical = Control.GROW_DIRECTION_BOTH


func _on_audio_slider(value: float, soort: String, val_label: Label) -> void:
	Audio.zet_volume(soort, value / 100.0)
	val_label.text = "%d%%" % int(value)


## F3.4b — een campagne-duel vanuit de hub: config komt van de brug, geen menu's.
func _start_campagne_duel() -> void:
	_campaign_mode = true
	_human_doctrine = CampaignBridge.doctrine_mens()
	_ai_doctrine = CampaignBridge.doctrine_vijand()
	ai_difficulty = clampi(int(CampaignBridge.campagne_moeilijkheid), 0, 2)
	_start_match(ai_difficulty)


## Open het uitleg-tabscherm (scripts/ui/instructions.gd). back = terugknop-actie.
func _show_rules_overlay(back: Callable) -> void:
	_instructions.open(back)


## "?"-knop rechtsboven: uitleg altijd beschikbaar, ook midden in een potje.
## Pauzeert de fase-timer zolang het scherm open staat.
func _build_help_button() -> void:
	# UI-assetpack: de knoppenkolom staat NAAST de HUD-balk (x 976..1064).
	var help := Button.new()
	help.text = tr("HUD_BTN_HELP")
	help.theme_type_variation = "KnopRond"
	help.custom_minimum_size = Vector2(88, 88)
	help.add_theme_font_size_override("font_size", 40)
	help.focus_mode = Control.FOCUS_NONE
	help.anchors_preset = Control.PRESET_TOP_RIGHT
	help.anchor_left = 1.0
	help.anchor_right = 1.0
	help.offset_left = -104.0
	help.offset_right = -16.0
	help.offset_top = 12.0
	help.offset_bottom = 100.0
	help.pressed.connect(_on_help_pressed)
	$UI.add_child(help)
	# "sfeer"-knopje eronder: opent het sfeer-paneel (zelfde als toets L).
	var sfeer := Button.new()
	sfeer.text = tr("HUD_BTN_AMBIANCE")
	sfeer.theme_type_variation = "KnopVierkant"
	HUD_BALK_SCRIPT.compacte_knop(sfeer, "vierkant", Vector2(88, 88), Vector2i(2, 4))
	sfeer.add_theme_font_size_override("font_size", 16)
	sfeer.focus_mode = Control.FOCUS_NONE
	sfeer.anchors_preset = Control.PRESET_TOP_RIGHT
	sfeer.anchor_left = 1.0
	sfeer.anchor_right = 1.0
	sfeer.offset_left = -104.0
	sfeer.offset_right = -16.0
	sfeer.offset_top = 108.0
	sfeer.offset_bottom = 196.0
	sfeer.modulate = Color(1.0, 1.0, 1.0, 0.9)
	sfeer.pressed.connect(_toggle_ambiance_panel)
	$UI.add_child(sfeer)
	# F0.8: opgeven-knop (RESIGN bestaat sinds F0.4c), onder de sfeer-knop.
	var geef_op := Button.new()
	# Alleen het witte-vlag-icoon: tekst van 14 px over het rode vlak was
	# onleesbaar; de bevestigingsdialoog legt uit wat de knop doet.
	geef_op.text = ""
	geef_op.tooltip_text = tr("HUD_BTN_RESIGN")
	# Dezelfde vierkante plaat als de sfeer-knop (de rode 9-patch is een breed
	# rechthoek en verwringt op 88x88); het gevaar zit in de rode vlag.
	geef_op.theme_type_variation = "KnopVierkant"
	HUD_BALK_SCRIPT.compacte_knop(geef_op, "vierkant", Vector2(88, 88))
	geef_op.icon = UiAssets.icoon("forfeit")
	for staat in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		geef_op.add_theme_color_override(staat, UiAssets.DIEP_ROOD)
	geef_op.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	geef_op.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	geef_op.expand_icon = false
	geef_op.add_theme_constant_override("icon_max_width", 44)
	geef_op.focus_mode = Control.FOCUS_NONE
	geef_op.anchors_preset = Control.PRESET_TOP_RIGHT
	geef_op.anchor_left = 1.0
	geef_op.anchor_right = 1.0
	geef_op.offset_left = -104.0
	geef_op.offset_right = -16.0
	geef_op.offset_top = 204.0
	geef_op.offset_bottom = 292.0
	geef_op.modulate = Color(1.0, 1.0, 1.0, 0.9)
	geef_op.pressed.connect(_on_resign_pressed)
	$UI.add_child(geef_op)


var _help_resume_timer: bool = false
var _help_time_left: float = 0.0
var _context_knop: Button


## F3.3-rest — touch-equivalent voor de rechtermuis-acties: één contextuele
## knop linksonder (ongedaan / overslaan / deselecteer). Rechtermuis blijft
## gewoon werken; dit is dezelfde actie voor vingers.
func _bouw_context_knop() -> void:
	_context_knop = Button.new()
	_context_knop.name = "ContextKnop"
	_context_knop.visible = false
	_context_knop.theme_type_variation = "KnopKleinBreed"
	_context_knop.custom_minimum_size = Vector2(240, 84)
	_context_knop.add_theme_font_size_override("font_size", 22)
	_context_knop.focus_mode = Control.FOCUS_NONE
	_context_knop.anchors_preset = Control.PRESET_BOTTOM_LEFT
	_context_knop.anchor_top = 1.0
	_context_knop.anchor_bottom = 1.0
	_context_knop.offset_left = 20.0
	_context_knop.offset_top = -108.0
	_context_knop.offset_right = 260.0
	_context_knop.offset_bottom = -24.0
	_context_knop.pressed.connect(_on_context_knop)
	$UI.add_child(_context_knop)


func _update_context_knop() -> void:
	if _context_knop == null:
		return
	if _placement_mode:
		_context_knop.text = tr("HUD_BTN_UNDO")
		_context_knop.visible = true
		return
	if _wolf_step_mode:
		_context_knop.text = tr("HUD_BTN_SKIP")
		_context_knop.visible = true
		return
	var st: GameState = session.state
	if st != null and st.phase == Phase.Type.ACTION and _selected_pawn_id >= 0 \
			and st.current_player == _human_id:
		_context_knop.text = tr("HUD_BTN_DESELECT")
		_context_knop.visible = true
		return
	_context_knop.visible = false


func _on_context_knop() -> void:
	if _placement_mode:
		_undo_placement()
	elif _wolf_step_mode:
		_end_wolf_step_mode()
		session.skip_wolf_step(_human_id)
	elif _selected_pawn_id >= 0:
		_deselect()


func _on_help_pressed() -> void:
	if _instructions.visible:
		return
	_help_resume_timer = _timer_active
	_help_time_left = _timer_left
	_stop_phase_timer()
	_instructions.open(_after_help_closed)


func _after_help_closed() -> void:
	if _help_resume_timer:
		_help_resume_timer = false
		_start_phase_timer(maxf(_help_time_left, 5.0))


func _show_doctrine_menu() -> void:
	# C17: het keuzescherm leest dezelfde facties als de campagne, de trainer
	# en de arena (CRules.actieve_tabel()). Index = positie in
	# Constants.DOCTRINE_DATA.keys(), zoals het oude overlay-menu.
	_overlay.hide()
	_factie_keuze.open(tr("MENU_DOCTRINE_TITLE"), tr("HUD_UI_DOCTRINE_UITLEG"), false, _on_doctrine_choice)


func _on_doctrine_choice(index: int) -> void:
	# UI-assetpack: het factie-keuzescherm sluit ook als de keuze niet via
	# een tik binnenkomt (capture, online-pad: -- play online).
	if _factie_keuze != null:
		_factie_keuze.sluit()
	_human_doctrine = Constants.DOCTRINE_DATA.keys()[index]
	if session.is_online():
		# F4.3g: online is de keuze een blinde actie in de engine (F4.0); de
		# ander kiest zelf, de server loot niets.
		_overlay.hide()
		session.submit_choose_doctrine(_human_id, _human_doctrine)
		if session.state.phase == Phase.Type.PRE_GAME:
			_update_hud(tr("HUD_WAIT_OPPONENT"))
		return
	_show_opponent_menu()


## Kies de factie van de AI-tegenstander. "Verrassing" volgt de officiele
## regel (v4.1 §4.1: blinde, gelijktijdige keuze); een vaste factie is
## handig om te oefenen tegen een specifieke matchup.
func _show_opponent_menu() -> void:
	# 0 = verrassing, 1.. = positie in Constants.DOCTRINE_DATA.keys() + 1.
	_overlay.hide()
	_factie_keuze.open(tr("MENU_OPP_TITLE"), tr("MENU_OPP_BODY"), true, _on_opponent_choice)


func _on_opponent_choice(index: int) -> void:
	# UI-assetpack: het factie-keuzescherm sluit ook als de keuze niet via
	# een tik binnenkomt (capture, online-pad: -- play online).
	if _factie_keuze != null:
		_factie_keuze.sluit()
	if index == 0:
		# BEWUSTE UITZONDERING op F0.1 (net als audio/VFX): de doctrine-loting is
		# pre-match invoer in de mens-vs-AI-flow, geen in-match spellogica. Voor
		# reproduceerbare partijen (sim/arena/replay) gaan doctrines als args mee.
		_ai_doctrine = Constants.DOCTRINE_DATA.keys()[randi() % Constants.DOCTRINE_DATA.size()]
	else:
		_ai_doctrine = Constants.DOCTRINE_DATA.keys()[index - 1]
	# Er is nog maar EEN spel (besluit Max, 29 juli): elk duel speelt met de
	# v4.2-economie -- CP en versterkingen. 4.1 blijft alleen als
	# regressie-ijkpunt in de tests bestaan, niet meer als speelbare optie.
	_campaign_mode = true
	_start_match(ai_difficulty)


func _start_match(difficulty: int) -> void:
	_overlay.hide()
	if _factie_keuze != null:
		_factie_keuze.sluit()
	# Combat-feel-state resetten (voor het geval een vorige partij midden in een
	# hitstop/ragdoll eindigde).
	Engine.time_scale = 1.0
	_in_hitstop = false
	_shake_amt = 0.0
	_dying_views.clear()
	_advance_holds.clear()
	_clear_debris(true)  # slagveld van de vorige partij ruimen
	_clear_footprints()
	Audio.play_music("music_battle")  # zacht marcherend bed onder de partij
	ai_difficulty = difficulty
	_loot_wind()
	# F4.3c: de kant van de mens komt uit de sessie (offline altijd 1), de
	# tegenstander is de andere kant. Voor vs-AI is dat 1/2, zoals altijd.
	_human_id = session.local_player_id()
	_ai_id = Constants.opponent(_human_id)
	_setup_ai()
	var regels: RulesConfig = null
	if CampaignBridge.duel_actief:
		regels = CampaignBridge.duel_rules()  # F3.4b: bezit/CP uit de campagne
	else:
		regels = _potje_regels()
	session.start_new_game(_human_doctrine, _ai_doctrine, regels)
	_omgeving_facties()
	_show_placement_overlay()


## De bewoners van het diorama volgen de facties: die van jou vooraan, die
## van de ander aan de overkant (Omgeving.zet_facties). Aanroepen zodra de
## keuzes bekend zijn: bij de start van een potje, als ze online binnenkomen
## en bij een herstart vanaf de staat.
func _omgeving_facties() -> void:
	if _omgeving != null:
		# Het diorama (11 september) volgt uit de windrichting, die per potje
		# geloot is (online uit het match-id, dus beide stoelen hetzelfde).
		# GEEN eigen trek uit de globale RNG en niet voor start_new_game
		# bouwen: dat verschuift de seed van de sessie en -- uispel klopt niet
		# meer (gemeten 11 september). De knop `diorama` in het sfeer-paneel
		# wint van de loting.
		var w: Vector3 = PawnView.wind_richting
		_omgeving.loot_diorama(int(round(atan2(w.z, w.x) * 1000.0)), false)
		# stoel 1 is rood (het arme kamp), stoel 2 blauw (het rijke)
		_omgeving.zet_facties(_human_doctrine, _ai_doctrine, "red" if _human_id == Constants.PLAYER_1 else "blue")


## De regels van een los potje (F4.3g: ook de online-weg gebruikt deze).
## Elk potje speelt v4.2: CP, versterkingen en de spawn-fase. De
## 1v1-instelling staat in v42_default.json (cp_start, poolfactor,
## spawn_totaal_max), zodat een los duel en een campagne-duel dezelfde
## economie kennen. C17: de facties komen uit hetzelfde bestand als de
## campagne, de trainer en de arena; anders speelt een los potje andere
## dieren dan de campagne zodra er een voorstel van de factiezoeker is
## aangenomen.
func _potje_regels() -> RulesConfig:
	var regels := RulesConfig.load_from_file("res://arena/arena_configs/v42_default.json")
	var facties := CRules.facties_uit_bestand()
	if not facties.is_empty():
		regels.doctrines = facties
	return regels


## F4.3g -- oefenen via de online-weg: een RemoteSession op een loopback met
## een bot op de andere stoel. Zelfde pad als straks tegen de server (alleen
## de eigen view, wachtteksten, seat 2 met gedraaid bord), zonder netwerk.
func _start_oefenpotje(seat: int) -> void:
	_overlay.hide()
	_loopback = LoopbackTransport.new(_potje_regels())
	_loopback.namen[seat] = tr("MENU_MULTI_YOU")
	_loopback.namen[Constants.opponent(seat)] = tr("MENU_MULTI_PRACTICE_BOT")
	_loopback.zet_bot(Constants.opponent(seat), AgentL1.new(), randi())
	_loopback.start()
	_start_online(RemoteSession.new(_loopback.voor_seat(seat), seat))


## F4.3g -- een online partij starten: eerst de sessie verbinden (status +
## eerste view), dan het scherm opbouwen vanaf de staat. Elke online start is
## per definitie een herstart.
## Wind van dit potje (Max, 8 september): een richting, alle vlaggen wapperen
## die kant op, ook die van de vijand. Los potje: willekeurig. Online: uit
## het match-id, zodat beide stoelen dezelfde wind zien zonder dat de engine
## er iets van hoeft te weten. Puur visueel: geen staat, geen digest.
func _loot_wind() -> void:
	var hoek: float = randf() * TAU
	if session != null and session.is_online() and String(OnlineBridge.match_id) != "":
		hoek = float(hash(String(OnlineBridge.match_id)) % 360) * TAU / 360.0
	PawnView.wind_richting = Vector3(cos(hoek), 0.0, sin(hoek))


func _start_online(sessie: RemoteSession) -> void:
	if sessie.get_parent() == null:
		add_child(sessie)
	sessie.start(func(ok: bool) -> void:
		if ok:
			_start_vanaf_sessie(sessie)
		else:
			_update_hud(tr("MENU_MULTI_NO_CONNECTION"))
			_show_difficulty_menu()
	)


## F4.3g -- het bord gedraaid voor speler 2: het kijk-pivot (camera, zon,
## spot en rim) 180 graden om het bordcentrum (board-lokaal), zodat je eigen
## haven onderaan staat en het licht van dezelfde kant komt als voor rood
## (Max, 4 september: "het licht is nu te eenzijdig"). GEEN coördinaat-
## spiegeling: picking (unproject), hp-blokjes en highlights volgen de
## camera vanzelf; de camera zelf houdt zijn lokale stand, dus de screen
## shake (`_cam_base`) verandert niet.
func _orient_camera_for(player_id: int) -> void:
	var t := Transform3D.IDENTITY
	if player_id == Constants.PLAYER_2:
		var c: Vector3 = tile_position(5, 5)
		c.y = 0.0
		var r := Basis(Vector3.UP, PI)
		t = Transform3D(r, c - r * c)
	_kijk_pivot.transform = t
	_cam_base = _camera.position
	_shake_amt = 0.0


## Vrije opstelling (v4.1 §2.2). Nu: standaard-opstelling bevestigen;
## een sleep-UI voor eigen opstellingen is een latere uitbreiding.
func _show_placement_overlay() -> void:
	var body := "\n".join([
		tr("PHASE_PLACEMENT_REVEAL_HEADER"),
		tr("PHASE_PLACEMENT_YOU") % [Constants.doctrine_display_name(_human_doctrine), Constants.doctrine_pro(_human_doctrine)],
		tr("PHASE_PLACEMENT_AI") % [Constants.doctrine_display_name(_ai_doctrine), Constants.doctrine_pro(_ai_doctrine)],
		"",
		tr("PHASE_PLACEMENT_MANUAL_HINT"),
		tr("PHASE_PLACEMENT_DEFAULT_HINT"),
		tr("PHASE_PLACEMENT_GOAL"),
	])
	_update_hud(tr("PHASE_PLACEMENT"))
	_overlay.show_choice(tr("PHASE_PLACEMENT"), body, [tr("PHASE_PLACEMENT_MANUAL"), tr("PHASE_PLACEMENT_STANDARD"), tr("MENU_RULES_OPTION")],
		_on_placement_menu_choice, Color.WHITE, true, ["phase-setup", "check", "hidden"], "phase-setup")


func _on_placement_menu_choice(index: int) -> void:
	if index == 0:
		_begin_manual_placement()
	elif index == 2:
		_show_rules_overlay(func() -> void: _show_placement_overlay())
	else:
		_confirm_placement()


# --- Zelf opstellen ------------------------------------------------------------

## Handmatige opstelling: plaats het schaarste type eerst (kanonnen → paarden);
## de infanterie vult daarna automatisch aan (voorste rij, centrum eerst).
func _begin_manual_placement() -> void:
	_overlay.hide()
	var comp: Array = session.state.doctrine_data_of(_human_id).comp
	var order: Array = [
		{"type": Constants.UnitType.ARTILLERY, "count": int(comp[2])},
		{"type": Constants.UnitType.CAVALRY, "count": int(comp[1])},
	]
	order.sort_custom(func(a, b): return int(a.count) < int(b.count))
	# C15 (besluit Max, 30 juli): je zet je vaandeldragers en tamboers ZELF neer.
	# Ze staan vooraan in de plaats-reeks als losse stappen, dus je kiest hun vak
	# net als bij een kanon. Wat je niet plaatst, wordt gewone infanterie.
	var camp: Dictionary = session.state.rules.campaign
	if session.state.rules.campaign_actief():
		for rol_stap in [["flag", int(camp.get("vaandels_max", 1))],
				["drum", int(camp.get("tamboers_max", 1))]]:
			if int(rol_stap[1]) > 0:
				order.append({"type": Constants.UnitType.INFANTRY,
					"count": int(rol_stap[1]), "rol": String(rol_stap[0])})
	_placement_steps = []
	for entry in order:
		if int(entry.count) > 0:
			_placement_steps.append(entry)
	_placement_placed = []
	_placement_mode = true
	if _placement_steps.is_empty():
		_finish_manual_placement()  # bv. Muis: alles is infanterie
		return
	_refresh_placement_ui()
	_start_phase_timer(PHASE_TIME_LIMIT)


func _placement_current() -> Dictionary:
	for step in _placement_steps:
		var rol := String(step.get("rol", ""))
		var placed := 0
		for p in _placement_placed:
			if int(p.type) == int(step.type) and String(p.get("rol", "")) == rol:
				placed += 1
		if placed < int(step.count):
			return {"type": int(step.type), "rol": rol,
				"left": int(step.count) - placed}
	return {}


func _placement_free_tiles() -> Array:
	var tiles: Array = []
	for row in Constants.get_start_rows_for_player(_human_id):
		for x in range(Constants.BOARD_SIZE):
			var pos := Vector2i(x, row)
			if not _placement_previews.has(pos):
				tiles.append(pos)
	return tiles


func _refresh_placement_ui() -> void:
	_clear_highlights()
	var step: Dictionary = _placement_current()
	if step.is_empty():
		return
	_highlight_tiles(_placement_free_tiles(), Color(0.4, 0.9, 0.9), 0.35)
	_update_placement_ghost_type()
	var type_name := tr("HUD_PLACE_TYPE_CANNONS") if int(step.type) == Constants.UnitType.ARTILLERY else tr("HUD_PLACE_TYPE_HORSES")
	match String(step.get("rol", "")):
		"flag": type_name = tr("HUD_PLACE_TYPE_FLAG")
		"drum": type_name = tr("HUD_PLACE_TYPE_DRUM")
	_update_hud(tr("HUD_PLACE_PROMPT") % [type_name, int(step.left)])


## Ghost-stuk: semi-doorzichtige voorvertoning van het type dat je nu plaatst.
func _update_placement_ghost_type() -> void:
	var step: Dictionary = _placement_current()
	var t: int = int(step.type) if not step.is_empty() else -1
	if t == _placement_ghost_type and _placement_ghost != null:
		return
	if _placement_ghost != null:
		_placement_ghost.queue_free()
		_placement_ghost = null
	_placement_ghost_type = t
	if t < 0:
		return
	var scene: PackedScene = PawnView.PIECE_SCENES.get(t)
	if scene == null:
		return
	var ghost: Node3D = scene.instantiate()
	var team_col := Color(0.85, 0.25, 0.28) if _human_id == Constants.PLAYER_1 else Color(0.2, 0.45, 0.9)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(team_col.r, team_col.g, team_col.b, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for shape in ghost.find_children("*", "CSGShape3D", true, false):
		(shape as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shape.material_override = mat
	ghost.visible = false
	_pawns_root.add_child(ghost)
	_placement_ghost = ghost


## Laat de ghost het vrije vak onder de muis volgen (onzichtbaar buiten de rijen).
func _update_placement_ghost(screen_pos: Vector2) -> void:
	if not _placement_mode or _placement_ghost == null:
		return
	var coord: Vector2i = _pick_coord(screen_pos, _placement_free_tiles())
	if coord.x >= 0:
		_placement_ghost.visible = true
		_placement_ghost.position = tile_position(coord.x, coord.y) + Vector3(0.0, PAWN_Y, 0.0)
	else:
		_placement_ghost.visible = false


func _on_placement_tile_clicked(coord: Vector2i) -> void:
	var step: Dictionary = _placement_current()
	if step.is_empty():
		return
	_placement_placed.append({"type": int(step.type), "pos": coord,
		"rol": String(step.get("rol", ""))})
	Audio.play("place_pawn")
	_spawn_placement_preview(int(step.type), coord)
	if _placement_ghost != null:
		_placement_ghost.visible = false  # tot de volgende muisbeweging
	if _placement_current().is_empty():
		_finish_manual_placement()
	else:
		_refresh_placement_ui()


func _undo_placement() -> void:
	# Alleen handmatig geplaatste stukken (kanonnen/paarden) terugnemen.
	if _placement_placed.is_empty():
		return
	var last: Dictionary = _placement_placed.pop_back()
	var pv: PawnView = _placement_previews.get(last.pos)
	if pv != null:
		pv.queue_free()
	_placement_previews.erase(last.pos)
	_refresh_placement_ui()


func _spawn_placement_preview(unit_type: int, coord: Vector2i) -> void:
	var pv: PawnView = PAWN_SCENE.instantiate()
	pv.team = Constants.Team.RED if _human_id == Constants.PLAYER_1 else Constants.Team.BLUE
	pv.position = tile_position(coord.x, coord.y) + Vector3(0.0, PAWN_Y, 0.0)
	_pawns_root.add_child(pv)
	pv.face_dir(Vector2i(0, -1) if _human_id == Constants.PLAYER_1 else Vector2i(0, 1))
	pv.set_unit_type(unit_type)
	# Neutraal factie-model (basis) als dat bestaat; kaarten zijn er nog niet.
	pv.set_character(session.state.doctrine_of(_human_id), unit_type, null)
	_placement_previews[coord] = pv


func _finish_manual_placement() -> void:
	# Infanterie vult de open vakken aan: voorste rij eerst, centrum naar buiten.
	var comp: Array = session.state.doctrine_data_of(_human_id).comp
	# BUG-FIX (Max, 30 juli: "de hover highlight dat een ring gloeit is niet
	# meer"). Sinds C15 plaats je zelf vaandeldragers en tamboers, en dat zijn
	# ook INFANTERIE. Zonder deze aftrek vulde de code er nog comp[0] bij, kwam
	# de opstelling 4 pionnen te hoog uit, keurde de engine hem af en bleef de
	# partij in de opstelfase hangen -- dus nooit een koppel-fase en dus ook
	# geen gloeiende ring.
	var al_inf: int = 0
	for al in _placement_placed:
		if int(al.get("type", 0)) == Constants.UnitType.INFANTRY:
			al_inf += 1
	var inf_left: int = maxi(0, int(comp[0]) - al_inf)
	var rows: Array = Constants.get_start_rows_for_player(_human_id)  # [achter, voor]
	var center_out: Array = [5, 4, 6, 3, 7, 2, 8, 1, 9, 0, 10]
	for row in [rows[1], rows[0]]:
		for x in center_out:
			if inf_left <= 0:
				break
			var pos := Vector2i(x, row)
			if _placement_previews.has(pos):
				continue
			_placement_placed.append({"type": Constants.UnitType.INFANTRY, "pos": pos})
			inf_left -= 1
	_placement_mode = false
	_stop_phase_timer()
	_clear_highlights()
	if _placement_ghost != null:
		_placement_ghost.queue_free()
		_placement_ghost = null
		_placement_ghost_type = -1
	for pv in _placement_previews.values():
		pv.queue_free()
	_placement_previews = {}
	if _ai != null:  # F4.3c: online stelt de tegenstander zichzelf op
		session.submit_placement(_ai_id, _ai.choose_placement(session.state))
	session.submit_placement(_human_id, _placement_placed)
	_placement_placed = []
	_build_pawn_views()
	_refresh_all()
	if _ai == null and session.state.phase == Phase.Type.PLACEMENT:
		_update_hud(tr("HUD_WAIT_OPPONENT"))  # F4.3e: online wacht je op de ander


func _confirm_placement() -> void:
	_overlay.hide()
	if _ai != null:  # F4.3c: online stelt de tegenstander zichzelf op
		session.submit_placement(_ai_id, _ai.choose_placement(session.state))
	session.submit_default_placement(_human_id)
	_build_pawn_views()
	_refresh_all()
	if _ai == null and session.state.phase == Phase.Type.PLACEMENT:
		_update_hud(tr("HUD_WAIT_OPPONENT"))  # F4.3e: online wacht je op de ander


# --- Setup -------------------------------------------------------------------

func _setup_ai() -> void:
	var path := "res://scripts/ai/AIMedium.gd"
	if ai_difficulty == 0:
		path = "res://scripts/ai/AIEasy.gd"
	elif ai_difficulty == 2:
		path = "res://scripts/ai/AIHard.gd"
	elif ai_difficulty == 3:
		path = "res://scripts/ai/AIUltra.gd"  # god mode: diepte 5 + denktijd-budget
	_ai = load(path).new()
	_ai.player_id = _ai_id
	# Gebruik geleerde gewichten uit de Trainer als die er zijn — de set die
	# bij de doctrine van de AI hoort (per-factie-profiel).
	var profile := AIController.load_profile()
	if not profile.is_empty():
		_ai.weights = (profile.get(int(_ai_doctrine), AIController.default_weights()) as Dictionary).duplicate()


## F4.3b -- idempotent per sessie-object: wisselt de sessie (online), dan
## gaan de oude koppelingen los en komen dezelfde op de nieuwe. Volgorde is
## die van altijd; de twee laatste zijn de online-haken (lichaam in F4.3c/g).
func _sessie_verbindingen() -> Array:
	return [
		["phase_changed", _on_phase_changed],
		["cards_revealed_event", _on_cards_revealed],
		["wolf_step_pending", _on_wolf_step_pending],
		["turn_changed", _on_turn_changed],
		["action_performed", _on_action_performed],
		["cycle_started", _on_cycle_started],
		["game_over", _on_game_over],
		["doctrines_revealed", _on_doctrines_revealed],
		["state_updated", _on_state_updated],
	]


func _connect_session_signals() -> void:
	if session == _verbonden_sessie:
		return
	if _verbonden_sessie != null:
		for paar in _sessie_verbindingen():
			if _verbonden_sessie.is_connected(paar[0], paar[1]):
				_verbonden_sessie.disconnect(paar[0], paar[1])
	for paar in _sessie_verbindingen():
		session.connect(paar[0], paar[1])
	_verbonden_sessie = session


## F4.3b -- haken voor de online-sessie; offline gebeurt hier (nog) niets.
func _on_doctrines_revealed(_doctrines: Dictionary) -> void:
	# F4.3g: beide keuzes binnen; de facties komen uit de staat (online is
	# dat de enige bron). De opstel-overlay volgt uit de fasewissel.
	_human_doctrine = session.state.doctrine_of(_human_id)
	_ai_doctrine = session.state.doctrine_of(_ai_id)
	_omgeving_facties()


func _on_state_updated(_state: GameState) -> void:
	# F4.3c: online vervangt de sessie de staat per batch; verse pionnen (het
	# vijandelijke leger na de opstelling, de spawns) moeten dan op het bord
	# komen zonder op _refresh_all te wachten. Met een bot is dit een no-op:
	# offline verandert er niets aan de flow.
	if _ai == null:
		_sync_new_pawn_views()
		_update_piece_counts()


## F4.3e -- een partij tonen vanaf een sessie die de staat al heeft (herstel
## na een koude start, online). Geen bot: de tegenstander leeft buiten dit
## proces. Er is bewust geen apart "vers"-pad: elke online start is een
## herstart, en `-- herstelcheck` bewijst dat dit pad elke fase aankan.
func _start_vanaf_sessie(sessie: SessionInterface) -> void:
	_overlay.hide()
	if _factie_keuze != null:
		_factie_keuze.sluit()
	Engine.time_scale = 1.0
	_in_hitstop = false
	_shake_amt = 0.0
	_dying_views.clear()
	_advance_holds.clear()
	_tweening_pawns.clear()
	_clear_debris(true)
	_clear_footprints()
	if _ai_thread != null and _ai_thread.is_started():
		_ai_thread.wait_to_finish()
	_ai_thread = null
	_ai = null
	if sessie.get_parent() == null:
		add_child(sessie)
	session = sessie
	_loot_wind()
	_human_id = session.local_player_id()
	_ai_id = Constants.opponent(_human_id)
	assert(not (CampaignBridge.duel_actief and session.is_online()),
		"een online partij is geen campagne-duel (F5.1 boekt dat in de worker)")
	_connect_session_signals()
	_campaign_mode = true
	_cp_bet_keuze = 0
	_orient_camera_for(_human_id)
	Audio.play_music("music_battle")
	_toon_fase_vanaf_staat()


## F4.3e -- render-vanaf-snapshot: elke fase opbouwbaar uit de staat ALLEEN,
## zonder events. Het bord was al staatgedreven (_build_pawn_views,
## _refresh_all); dit is de fase-UI die aan de signals hing: kaartwaaier,
## CP-bod, onthul-scherm, koppel-ringen, beurt-prompt, wolf-stap,
## spawn-overlay, einde. Bewust dezelfde functies als de signal-handlers,
## zodat "live" en "hersteld" hetzelfde scherm geven (-- herstelcheck).
func _toon_fase_vanaf_staat() -> void:
	var st: GameState = session.state
	var me: int = _human_id
	_human_doctrine = st.doctrine_of(me)
	_ai_doctrine = st.doctrine_of(_ai_id)
	_omgeving_facties()
	_card_hand.visible = false
	_overlay.hide()
	_end_wolf_step_mode()
	_selected_pawn_id = -1
	_auto_link_human = false
	_build_pawn_views()
	_refresh_all()
	_update_hud()
	if st.phase == Phase.Type.PRE_GAME:
		if st.doctrine_commits.has(me):
			_update_hud(tr("HUD_WAIT_OPPONENT"))
		else:
			_show_doctrine_menu()
	elif st.phase == Phase.Type.PLACEMENT:
		if bool(st.placements_done.get(me, false)):
			_update_hud(tr("HUD_WAIT_OPPONENT"))
		else:
			_show_placement_overlay()
	elif Phase.is_define(st.phase):
		if st.cards_defined.get(me, []).size() == 0 and Validator.expected_define_count(st, me) > 0:
			_open_define_fase()
		else:
			_update_hud(tr("HUD_WAIT_OPPONENT"))
	elif Phase.is_reveal(st.phase):
		if bool(st.reveal_acks.get(me, false)):
			_update_hud(tr("HUD_WAIT_OPPONENT"))
		else:
			var init: Dictionary = Rules.compute_initiative(st)
			_toon_reveal(init.totals_p1, init.totals_p2, int(init.winner))
	elif Phase.is_linking(st.phase):
		_toon_linking_hand()
		_highlight_own_unlinked_pawns()
		_on_turn_changed(st.current_player)
	elif st.phase == Phase.Type.ACTION:
		_on_turn_changed(st.current_player)
		if st.pending_wolf_step_pawn != -1:
			_on_wolf_step_pending(st.pending_wolf_step_pawn)
	elif st.phase == Phase.Type.CYCLE_SPAWN:
		_open_spawn_fase()
	elif st.phase == Phase.Type.GAME_OVER:
		_on_game_over(st.winner)
	else:
		push_error("_toon_fase_vanaf_staat: %s is nooit een ruststaat" % Phase.to_string_phase(st.phase))


## Beweegt er nog iets op het bord? Loop-tweens, ragdolls, opruk-holds, hitstop
## of een lopende poef-reveal van verse versterkingen.
##
## Hier wachten de kaarten en de schermen op (besluit Max, 7 september: "speel
## altijd eerst alle animaties af voordat de nieuwe kaarten of schermen in beeld
## komen"). Bewust ZONDER _fase_overgang_bezig en _define_open_bezig: dat zijn
## vlaggen die juist gezet worden terwijl we staan te wachten, en daarop wachten
## zou zichzelf blokkeren.
func _animaties_bezig() -> bool:
	return not _tweening_pawns.is_empty() or not _dying_views.is_empty() \
		or not _advance_holds.is_empty() or _in_hitstop \
		or Time.get_ticks_msec() < _spawn_reveal_tot_ms + 250


## Wacht tot het bord stilstaat. De vangrail is er voor het geval een tween ooit
## blijft hangen: liever een kaartwaaier die iets te vroeg komt dan een spel dat
## niet meer verder kan.
func _wacht_op_animaties(max_sec: float = 6.0) -> void:
	# Headless kijkt niemand mee: daar wachten kost alleen tijd in de checks
	# (-- uispel liep er minuten langer op) en verandert niets aan de acties die
	# er ingaan. Het wachten is puur presentatie.
	if DisplayServer.get_name() == "headless":
		return
	var tot: int = Time.get_ticks_msec() + int(max_sec * 1000.0)
	while _animaties_bezig() and Time.get_ticks_msec() < tot:
		await get_tree().process_frame


## F4.3e -- staat het scherm stil? Geen beweging (zie _animaties_bezig) en geen
## fase-overgang of kaartwaaier die staat te wachten. De herstelcheck vergelijkt
## pas dan.
func is_rustig() -> bool:
	return not _animaties_bezig() \
		and not _fase_overgang_bezig and not _define_open_bezig


## F4.3e -- waar tijdens de 0,9 s "ronde klaar"-pauze (koppelen -> define),
## en zolang een scherm (spawn-keuze, CP-bod, kaartwaaier) op het bord wacht:
## de poef-reveal van verse spawns met zijn kijkpauze, of een nalopende
## animatie (16 september).
var _fase_overgang_bezig: bool = false
var _define_open_bezig: bool = false


## F4.3e -- deterministische samenvatting van wat er op het scherm staat, om
## "live" en "hersteld vanaf een view" te vergelijken. Bewust NIET erin:
## figurant-rollen (geschiedenis-afhankelijk, cosmetisch), lijken en
## brokstukken (het view-dieet laat gesneuvelde pionnen weg), de prompt
## zolang een overlay het scherm domineert (daaronder staat vaak een oude
## tekst), en de waaier-modus als de waaier onzichtbaar is.
func render_digest() -> Dictionary:
	var pawns: Dictionary = {}
	var ids: Array = _pawn_views.keys()
	ids.sort()
	for pid in ids:
		var pv: PawnView = _pawn_views[pid]
		if not pv.visible:
			continue
		var blokjes := ""
		var vraagteken := false
		var bar = _hp_bars.get(pid, null)
		if bar != null and bar.holder.visible:
			for b in bar.blocks:
				if not (b as ColorRect).visible:
					continue
				blokjes += "1" if (b as ColorRect).color != HP_COLOR_EMPTY else "0"
			vraagteken = bar.has("qlabel") and bar.qlabel.visible
		pawns[str(pid)] = {
			# Halve tegels: een stagger (terugslag-animatie) mag nog uitlopen,
			# een verkeerde tegel valt er nog steeds uit.
			"pos": [snappedf(pv.position.x, 0.5), snappedf(pv.position.z, 0.5)],
			"ring": pv._ring_active,
			"ring_link": pv._ring_link_state,
			"gedimd": pv._dimmed,
			"geselecteerd": pv._selected,
			"blokjes": blokjes,
			"vraagteken": vraagteken,
		}
	var highlights: Array = []
	for h in _highlights:
		highlights.append("%.2f,%.2f" % [h.position.x, h.position.z])
	highlights.sort()
	var aura: Array = []
	for e in _aura_gloed:
		aura.append("%s%s:%d,%d" % [String(e.rol), "R" if int(e.get("team", 0)) == Constants.Team.RED else "B",
			(e.pos as Vector2i).x, (e.pos as Vector2i).y])
	aura.sort()
	var tegels: Array = []
	for t in _wolf_step_tiles:
		tegels.append([t.x, t.y])
	var overlay_zichtbaar: bool = _overlay != null and _overlay.visible
	return {
		"fase": Phase.to_string_phase(session.state.phase),
		"pawns": pawns,
		"kaarthand": {
			"zichtbaar": _card_hand.visible,
			"modus": _card_hand.phase if _card_hand.visible else -1,
			"aantal": _card_hand.get_card_views().size() if _card_hand.visible else 0,
		},
		"overlay": {
			"zichtbaar": overlay_zichtbaar,
			"titel": String(_overlay._title.text) if overlay_zichtbaar else "",
			"knoppen": _overlay._buttons.get_child_count() if overlay_zichtbaar else 0,
		},
		"prompt": "" if overlay_zichtbaar else _prompt_label.text,
		"topbalk": _top_label.text,
		"wolf": {"modus": _wolf_step_mode, "tegels": tegels},
		"highlights": highlights,
		"aura": aura,
		"timer": _timer_active,
		"selectie": _selected_pawn_id,
	}


## Hoornstoot bij een nieuwe cyclus (niet de allereerste — daar loopt de setup al).
## En: het slagveld wordt geruimd — lijken, brokstukken en bloed zinken weg.
func _on_cycle_started(cycle_number: int) -> void:
	if cycle_number >= 2:
		Audio.play("cycle_start")
	_clear_debris()


## Alles in de groep "battlefield_debris" (lijken, gibs, musketten, bloed)
## opruimen. instant = zonder wegzink-animatie (bij een nieuwe match).
func _clear_debris(instant: bool = false) -> void:
	for n in get_tree().get_nodes_in_group("battlefield_debris"):
		var n3 := n as Node3D
		if n3 == null or not is_instance_valid(n3):
			continue
		n3.remove_from_group("battlefield_debris")
		if instant:
			n3.queue_free()
		else:
			var tw := n3.create_tween()
			tw.tween_interval(randf() * 0.4)
			tw.tween_property(n3, "position:y", n3.position.y - 1.3, 0.5).set_ease(Tween.EASE_IN)
			tw.tween_callback(n3.queue_free)


func _index_tiles() -> void:
	var tiles_node := _board.get_node_or_null("Tiles")
	if tiles_node == null:
		return
	for tile in tiles_node.get_children():
		if tile is Node3D:
			var coord := Vector2i(
				int(round((tile as Node3D).position.x)),
				int(round((tile as Node3D).position.z)),
			)
			_tiles[coord] = tile


func tile_position(gx: int, gz: int) -> Vector3:
	var tile: Node3D = _tiles.get(Vector2i(gx, gz))
	if tile != null:
		return tile.position
	return Vector3(gx, 0.0, gz)


func _build_pawn_views() -> void:
	for child in _pawns_root.get_children():
		child.queue_free()
	_pawn_views.clear()
	for pawn in session.state.pawns.values():
		_maak_pawn_view(pawn)
	_build_health_bars()


func _maak_pawn_view(pawn: Pawn) -> void:
	var pv: PawnView = PAWN_SCENE.instantiate()
	pv.pawn_id = pawn.id
	pv.team = Constants.Team.RED if pawn.owner_id == Constants.PLAYER_1 else Constants.Team.BLUE
	pv.position = tile_position(pawn.position.x, pawn.position.y) + Vector3(0.0, PAWN_Y, 0.0)
	_pawns_root.add_child(pv)
	# Kijk naar de vijand: rood naar z=0 (-z), blauw naar z=10 (+z).
	pv.face_dir(Vector2i(0, -1) if pawn.owner_id == Constants.PLAYER_1 else Vector2i(0, 1))
	pv.set_unit_type(pawn.unit_type)
	_zet_figurant_info(pv, pawn)
	_pawn_views[pawn.id] = pv


## F2.6-bugfix (speeltest Max): gespawnde pionnen bestonden wel in de engine
## maar kregen geen 3D-view of hp-balk — onzichtbaar en onklikbaar, waardoor
## koppelen op een spawn onmogelijk was en de partij voor de mens vastliep.
## Volgnummer van een pion binnen het eigen leger (alleen infanterie telt mee).
## Gesneuvelde pionnen tellen door, zodat het nummer -- en dus de figurant-rol
## -- de hele partij hetzelfde blijft: koppel je een vaandeldrager en koppel je
## hem later los, dan pakt hij zijn vaandel weer op.
const FIGURANT_MIN_AFSTAND := 4   # vakken tussen twee gelijke rollen (Max, 30 juli)

var _figurant_rollen: Dictionary = {}   # pawn_id -> "flag"/"drum"


## Vaandels en trommels ruimtelijk verdelen (Max, 30 juli: "staan niet genoeg
## uit elkaar"). Een volgnummer in de rij zegt niets over de afstand op het
## bord, dus we kiezen hier: houd bestaande dragers vast zolang ze mogen dragen,
## en vul vacatures met de kandidaat die het VERST van de andere dragers staat,
## met een harde ondergrens van FIGURANT_MIN_AFSTAND vakken tussen twee gelijke
## rollen. Deterministisch (kandidaten op pion-id), dus replays blijven gelijk.
func _werk_figurant_rollen_bij() -> void:
	var state: GameState = session.state
	if state == null:
		return
	# C15: draagt dit potje echte rollen (campagne-blok, en sinds C17 is dat
	# elk potje), dan is de STAAT de enige waarheid, ook als alle dragers van
	# een leger al gesneuveld zijn. Tot 12 september keek dit alleen naar de
	# LEVENDE dragers: waren die allebei dood, dan vulde de oude cosmetische
	# verdeling de vacatures weer op en kwam een verse spawn met trom of vlag
	# het bord op (Max: "als ze dood zijn zijn ze dood"). Alleen zonder
	# campagne-blok (kaal 4.1) verdelen we hier nog iets.
	if state.campaign_actief_rollen():
		if not _figurant_rollen.is_empty():
			_figurant_rollen.clear()
		return
	for pid in _figurant_rollen.keys():
		var p: Pawn = state.pawns.get(pid)
		if p == null or p.is_eliminated or p.linked_card_id != -1:
			_figurant_rollen.erase(pid)   # gesneuveld of gekoppeld: rol vervalt
	for owner in [Constants.PLAYER_1, Constants.PLAYER_2]:
		# C15 (besluit Max, 30 juli): heeft dit leger rollen UIT DE STAAT, dan
		# is dat de waarheid en verdelen we hier niets meer. De rol hoort bij de
		# pion: koppel je hem, dan bergt hij zijn vaandel op; ontkoppel je hem,
		# dan pakt hij hetzelfde vaandel weer op. Hij geeft het nooit door.
		var uit_staat := false
		for p in state.pawns.values():
			if p.owner_id == owner and not p.is_eliminated and String(p.rol) != "":
				uit_staat = true
				break
		if uit_staat:
			for pid in _figurant_rollen.keys():
				var pp2: Pawn = state.pawns.get(pid)
				if pp2 != null and pp2.owner_id == owner:
					_figurant_rollen.erase(pid)
			continue
		var kandidaten: Array = []
		var totaal: int = 0
		for p in state.pawns.values():
			if p.owner_id != owner or p.unit_type != Constants.UnitType.INFANTRY \
					or p.is_eliminated:
				continue
			totaal += 1
			if p.linked_card_id == -1 and not _figurant_rollen.has(p.id):
				kandidaten.append(p)
		kandidaten.sort_custom(func(a: Pawn, b: Pawn) -> bool: return a.id < b.id)
		var per_rol: int = 2 if totaal >= PawnView.TWEEDE_STEL_VANAF else 1
		# Dragers kunnen tijdens het oprukken naar elkaar toe lopen. Staan twee
		# gelijke rollen te dicht op elkaar EN is er een kandidaat die het wel
		# haalt, dan geeft de jongste zijn rol af (de oudste houdt hem vast,
		# zodat het niet heen en weer flappert).
		for rol in ["flag", "drum"]:
			var dragers: Array = []
			for pid in _figurant_rollen:
				if String(_figurant_rollen[pid]) != rol:
					continue
				var dp: Pawn = state.pawns.get(pid)
				if dp != null and dp.owner_id == owner:
					dragers.append(dp)
			dragers.sort_custom(func(a: Pawn, b: Pawn) -> bool: return a.id < b.id)
			for i in dragers.size():
				for j in range(i + 1, dragers.size()):
					if _vak_afstand(dragers[i].position, dragers[j].position) 							>= FIGURANT_MIN_AFSTAND:
						continue
					var beter := false
					for k in kandidaten:
						if _vak_afstand(k.position, dragers[i].position) 								>= FIGURANT_MIN_AFSTAND:
							beter = true
							break
					if beter:
						_figurant_rollen.erase(dragers[j].id)
						kandidaten.append(dragers[j])
		for rol in ["flag", "drum"]:
			var bezet: Array = []
			for pid in _figurant_rollen:
				if String(_figurant_rollen[pid]) != rol:
					continue
				var pp: Pawn = state.pawns.get(pid)
				if pp != null and pp.owner_id == owner:
					bezet.append(pp)
			while bezet.size() < per_rol:
				var keus: Pawn = _verste_kandidaat(kandidaten, bezet, state, owner)
				if keus == null:
					break
				_figurant_rollen[keus.id] = rol
				bezet.append(keus)
				kandidaten.erase(keus)


## Kandidaat die zo ver mogelijk van de huidige dragers staat. Gelijke rol weegt
## honderd keer zwaarder dan "ver van alle figuranten": twee vaandels ver uit
## elkaar is belangrijker dan een vaandel ver van een trommel.
func _verste_kandidaat(kandidaten: Array, zelfde_rol: Array, state: GameState,
		owner: int) -> Pawn:
	var beste: Pawn = null
	var beste_score: float = -1.0e9
	for k in kandidaten:
		var d_zelfde: int = 99
		for z in zelfde_rol:
			d_zelfde = mini(d_zelfde, _vak_afstand(k.position, z.position))
		var d_alle: int = 99
		for pid in _figurant_rollen:
			var pp: Pawn = state.pawns.get(pid)
			if pp != null and pp.owner_id == owner:
				d_alle = mini(d_alle, _vak_afstand(k.position, pp.position))
		var score: float = float(d_zelfde) * 100.0 + float(d_alle)
		if not zelfde_rol.is_empty() and d_zelfde < FIGURANT_MIN_AFSTAND:
			score -= 1.0e6   # mag alleen als er echt niets verder weg staat
		if score > beste_score:
			beste_score = score
			beste = k
	return beste


func _vak_afstand(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _zet_figurant_info(pv: PawnView, pawn: Pawn) -> void:
	if pawn.unit_type != Constants.UnitType.INFANTRY:
		pv.figurant_index = -1
		pv.rol_vast = ""
		pv.rol_echt = ""
		return
	pv.rol_echt = String(pawn.rol)
	pv.rol_vast = String(_figurant_rollen.get(pawn.id, ""))
	var ids: Array = []
	for p in session.state.pawns.values():
		if p.owner_id == pawn.owner_id and p.unit_type == Constants.UnitType.INFANTRY:
			ids.append(p.id)
	ids.sort()
	pv.figurant_index = ids.find(pawn.id)
	pv.figurant_totaal = ids.size()


func _sync_new_pawn_views() -> void:
	var vers: Array = []
	for pawn in session.state.pawns.values():
		if pawn.is_eliminated or _pawn_views.has(pawn.id):
			continue
		_maak_pawn_view(pawn)
		vers.append(_pawn_views[pawn.id])
	if vers.is_empty():
		return
	_build_health_bars()  # herbouwt alle balken, incl. de nieuwe pionnen
	# Poef-reveal (besluit Max, 27 juli): verse spawns verschijnen één voor
	# één op het bord vóórdat de define-hand opent — alleen mid-match
	# (cyclus 2+); de opstellingsfase bouwt gewoon in stilte.
	if session.state.cycle >= 2:
		_poef_reveal(vers)


var _spawn_reveal_tot_ms: int = 0


## Verse spawns "poef" gefaseerd het bord op; de kaarten wachten (zie
## _open_define_hand). Schaal-pop met een place-tik per poppetje.
func _poef_reveal(views: Array) -> void:
	var stagger := 0.18
	# Na de laatste poef nog even naar het bord met beide legers kijken
	# voordat het CP-bod opent (knop spawn_kijk_pauze in effects_tuning.json).
	var kijk: float = PawnView.fx("spawn_kijk_pauze", 0.8)
	_spawn_reveal_tot_ms = Time.get_ticks_msec() + int((0.45 + stagger * views.size() + 0.25 + kijk) * 1000.0)
	_card_hand.visible = false  # eerst het bord laten zien
	for i in views.size():
		var pv: Node3D = views[i]
		var doel: Vector3 = pv.scale
		pv.scale = Vector3(0.01, 0.01, 0.01)
		var tw := pv.create_tween()
		tw.tween_interval(0.45 + stagger * i)
		tw.tween_callback(func() -> void: Audio.play("place_pawn", 0.0, -1, 1.0 + 0.03 * i))
		tw.tween_property(pv, "scale", doel, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


const HP_COLS := 5        # minste kolommen (het gewone raster)
const HP_COLS_MAX := 9    # met CP-inzet en bonussen kan een stat tot 6, 7 gaan (16 september, Max)
const HP_ROWS := 3
const HP_BLOCK_SIZE := 5.5
const HP_BLOCK_GAP := 1.0
const HP_COLOR_EMPTY := Color(0.06, 0.06, 0.08, 0.92)
const HP_COLOR_HEALTH := Color(0.28, 0.85, 0.38)
const HP_COLOR_STAMINA := Color(0.45, 0.74, 1.0)
const HP_COLOR_ATTACK := Color(0.98, 0.56, 0.3)

## Het rol-icoon onder de HP-blokjes: vaandeldrager of tamboer.
##
## Staat op EIGEN en op VIJANDELIJKE pionnen. Sinds 4.3.2 levert elke drager
## buit op -- gekoppeld of niet -- dus je moet kunnen zien waar hij staat. De rol
## reist al mee in de fog-view: `rol` zit in Pawn.to_dict() en View._pawn_view
## redigeert hem niet (alleen hp/stamina/attack worden "?" en de koppeling
## verdwijnt). ViewTests legt dat vast, zodat een latere redactie-uitbreiding het
## niet stilletjes wegneemt.
##
## Tekens in plaats van een texture: het UI-pack heeft nog geen vaandel- of
## trom-icoon, en een letter met een dikke rand leest op deze maat prima. Zodra
## de assets er zijn is dit een TextureRect.
const ROL_TEKEN := {"flag": "\u2691", "drum": "\u266A"}
## Aura-kleur per TEAM en rol (8 september, Max: "geef de teams hun eigen
## kleur invloed-area"). Binnen een team is het vaandel de lichte, warme
## tint en de trom de diepe tint, zodat je op het bord in een oogopslag ziet
## WIENS vorm het is en WELKE. Rood: oranjerood / karmijn; blauw:
## hemelsblauw / indigo. Dezelfde kleur zit om de extra stat-blokjes en op
## het rol-icoon onder de blokjes.
const AURA_KLEUR := {
	Constants.Team.RED: {"flag": Color(1.0, 0.58, 0.30), "drum": Color(1.0, 0.30, 0.42)},
	Constants.Team.BLUE: {"flag": Color(0.45, 0.80, 1.0), "drum": Color(0.42, 0.48, 1.0)},
}


## Team van een eigenaar (speler 1 = rood, speler 2 = blauw), voor de kleuren.
static func _team_van(owner_id: int) -> int:
	return Constants.Team.RED if owner_id == Constants.PLAYER_1 else Constants.Team.BLUE


## De aura-kleur van een rol voor het team van deze eigenaar.
static func rol_kleur(rol: String, owner_id: int) -> Color:
	var per_team: Dictionary = AURA_KLEUR[_team_van(owner_id)]
	return per_team.get(rol, Color.WHITE)


func _werk_rol_iconen_bij(state: GameState, total_w: float, total_h: float) -> void:
	for pid in _hp_bars:
		var bar: Dictionary = _hp_bars[pid]
		var lbl: Label = bar.get("rol", null)
		if lbl == null:
			continue
		var pawn: Pawn = state.pawns.get(pid, null)
		var rol: String = "" if pawn == null else String(pawn.rol)
		if pawn == null or pawn.is_eliminated or not ROL_TEKEN.has(rol):
			lbl.visible = false
			continue
		lbl.text = String(ROL_TEKEN[rol])
		lbl.add_theme_color_override("font_color", rol_kleur(rol, pawn.owner_id))
		lbl.visible = true
		# Onder de blokjes, gecentreerd op de kolom-breedte.
		lbl.position = Vector2(total_w * 0.5 - 5.0, total_h + 1.0)


# --- C21-aura op het bord (7 september) ----------------------------------------

## Een minimale gloeiende RAND op elke tegel in de vorm om een levende tamboer
## (+1 stamina bij het koppelen) of vaandeldrager (+1 attack), in de kleur van
## het TEAM van de drager (AURA_KLEUR: vaandel licht, trom diep), in
## de kleuren van het rol-icoon; de tegel van de drager zelf niet. Max wilde
## expres geen vlak ("vreselijk"): alleen de rand, en dezelfde kleurrand om
## de stat-blokjes die uit de aura komen (zie _update_health_bars). Eén dun
## vlak per tegel met een vierkant verloop dat alleen bij de rand oplicht,
## additief, dus twee auras over dezelfde tegel worden iets lichter. Ook de
## aura van de VIJAND is zichtbaar (zijn rol staat sinds 4.3.2 in de fog-view
## en het icoon toont hem al), wat gedimder. Puur uit de staat afgeleid, dus
## na een herstart identiek (render_digest telt de tegels mee). Sterkte: knop
## `aura_gloed` in het sfeer-paneel (toets L) / effects_tuning.json.
const AURA_HOOGTE := 0.056   # net boven de tegel (top 0.05), onder de highlights (vanaf 0.06)
const AURA_ALPHA := 0.34     # sterkte van de rand; het verloop zelf is smal ("minimaal", Max)
const AURA_VIJAND := 0.6


func _werk_aura_bij() -> void:
	var state: GameState = session.state if session != null else null
	if state == null or _board == null or state.phase == Phase.Type.PRE_GAME \
			or state.rules == null or not state.rules.campaign_actief():
		_wis_aura()
		return
	var c: Dictionary = state.rules.campaign
	var bereik: int = int(c.get("aura_bereik", 1))
	var knoppen: Dictionary = {"drum": int(c.get("aura_tamboer_stamina", 0)), "flag": int(c.get("aura_vaandel_attack", 0))}
	# Per tegel en rol: eigen aura wint van een vijandelijke (die is gedimd).
	var tegels: Dictionary = {}
	if bereik > 0:
		for pawn in state.pawns.values():
			var rol: String = String(pawn.rol)
			if pawn.is_eliminated or not knoppen.has(rol) or int(knoppen[rol]) <= 0:
				continue
			var eigen: bool = pawn.owner_id == _human_id
			var team: int = _team_van(pawn.owner_id)
			for dx in range(-bereik, bereik + 1):
				for dy in range(-bereik, bereik + 1):
					if dx == 0 and dy == 0:
						continue
					var vak := Vector2i(pawn.position.x + dx, pawn.position.y + dy)
					if not Constants.is_on_board(vak):
						continue
					var key: String = "%s:%d,%d" % [rol, vak.x, vak.y]
					# Per tegel en rol een rand; eigen wint van vijand, en de rand
					# draagt de kleur van het team dat hem wint.
					if not tegels.has(key):
						tegels[key] = {"rol": rol, "pos": vak, "eigen": eigen, "team": team}
					elif eigen and not bool(tegels[key].eigen):
						tegels[key].eigen = true
						tegels[key].team = team
	var keys: Array = tegels.keys()
	keys.sort()
	var delen: PackedStringArray = []
	for key in keys:
		delen.append("%s%s%s" % [key, "+" if bool(tegels[key].eigen) else "-",
			"R" if int(tegels[key].team) == Constants.Team.RED else "B"])
	var sleutel: String = "%d|%s" % [bereik, ",".join(delen)]
	if sleutel == _aura_sleutel:
		return
	_wis_aura()
	_aura_sleutel = sleutel
	for key in keys:
		var t: Dictionary = tegels[key]
		_maak_aura_rand(t.pos, String(t.rol), bool(t.eigen), int(t.team))


## Een dunne gloeiende rand op één tegel: vierkant verloop dat pas bij de
## buitenste ~10% oplicht (zachte binnenkant, felle rand).
func _maak_aura_rand(vak: Vector2i, rol: String, eigen: bool, team: int) -> void:
	var kleur: Color = (AURA_KLEUR[team] as Dictionary)[rol]
	var basis: float = AURA_ALPHA * (1.0 if eigen else AURA_VIJAND)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.80, 0.93, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.55)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_SQUARE
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 96
	tex.height = 96
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	mat.albedo_color = Color(kleur.r, kleur.g, kleur.b, basis * PawnView.fx("aura_gloed", 1.0))
	var mesh := QuadMesh.new()
	# Twee auras op een tegel: de vaandelrand buiten, de tromrand er net
	# binnen, zodat ze naast elkaar staan in plaats van wit op te tellen.
	var maat: float = 0.98 if rol == "flag" else 0.88
	mesh.size = Vector2(maat, maat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	mi.position = tile_position(vak.x, vak.y) + Vector3(0.0, AURA_HOOGTE, 0.0)
	_board.add_child(mi)
	_aura_gloed.append({"node": mi, "mat": mat, "basis": basis, "rol": rol, "pos": vak, "team": team})


func _wis_aura() -> void:
	for e in _aura_gloed:
		if is_instance_valid(e.node):
			e.node.queue_free()
	_aura_gloed.clear()
	_aura_sleutel = ""


## De vaste factie-bonus per stat voor op de kaart (16 september): wat elke
## pion van deze factie bij het koppelen krijgt bovenop de kaart (Beer +1 HP,
## Muis +1 Speed). Type-afhankelijke dingen (cavalerie-bonus, basis-HP,
## ondergrenzen) horen niet op een kaart die nog aan niemand hangt.
func _factie_bonus_van(doctrine: Dictionary) -> Array:
	return [int(doctrine.get("hp_bonus", 0)), int(doctrine.get("speed_bonus", 0)), 0]


func _build_health_bars() -> void:
	if _hp_layer == null:
		return
	for child in _hp_layer.get_children():
		child.free()
	_hp_bars.clear()
	for pawn in session.state.pawns.values():
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.visible = false
		var blocks: Array = []
		var randen: Array = []
		for r in HP_ROWS:
			for c in HP_COLS_MAX:
				var block := ColorRect.new()
				block.mouse_filter = Control.MOUSE_FILTER_IGNORE
				block.size = Vector2(HP_BLOCK_SIZE, HP_BLOCK_SIZE)
				block.position = Vector2(
					c * (HP_BLOCK_SIZE + HP_BLOCK_GAP),
					r * (HP_BLOCK_SIZE + HP_BLOCK_GAP))
				holder.add_child(block)
				blocks.append(block)
				# C21: rand in de aura-kleur om een blokje dat uit de aura komt
				# (+1 stamina van de trom, +1 attack van het vaandel). Verborgen
				# tot _update_health_bars hem aanzet.
				var rand := ReferenceRect.new()
				rand.editor_only = false
				rand.border_width = 1.5
				rand.mouse_filter = Control.MOUSE_FILTER_IGNORE
				rand.size = Vector2(HP_BLOCK_SIZE + 3.0, HP_BLOCK_SIZE + 3.0)
				rand.position = block.position - Vector2(1.5, 1.5)
				rand.visible = false
				holder.add_child(rand)
				randen.append(rand)
		# F0.6: "?"-label voor gedekte Krokodil-pionnen (stats zijn geheim; lege
		# blokjes zouden 0-waarden lekken, dus de hele rij wordt een vraagteken).
		var qlabel := Label.new()
		qlabel.text = "?"
		qlabel.visible = false
		qlabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		qlabel.add_theme_font_size_override("font_size", 20)
		qlabel.add_theme_color_override("font_color", UiAssets.WARM_IVOOR)
		qlabel.add_theme_color_override("font_outline_color", Color(UiAssets.INKT, 0.9))
		qlabel.add_theme_constant_override("outline_size", 5)
		qlabel.position = Vector2(HP_COLS * (HP_BLOCK_SIZE + HP_BLOCK_GAP) * 0.5 - 6.0, -4.0)   # x volgt per frame de breedte
		holder.add_child(qlabel)
		# Rol-icoon (C15 / 4.3.2): vaandeldrager of tamboer, net onder de
		# HP-blokjes. Ook op VIJANDELIJKE pionnen -- sinds 4.3.2 levert elke
		# drager buit op, dus je moet er gericht op kunnen jagen. De rol zit al
		# in de fog-view (View._pawn_view redigeert hem niet), dus dit kost geen
		# engine-wijziging.
		var rol_lbl := Label.new()
		rol_lbl.visible = false
		rol_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rol_lbl.add_theme_font_size_override("font_size", 13)
		rol_lbl.add_theme_color_override("font_outline_color", Color(UiAssets.INKT, 0.95))
		rol_lbl.add_theme_constant_override("outline_size", 4)
		holder.add_child(rol_lbl)
		_hp_layer.add_child(holder)
		_hp_bars[pawn.id] = {"holder": holder, "blocks": blocks, "qlabel": qlabel,
			"rol": rol_lbl, "randen": randen}


func _update_health_bars() -> void:
	if _camera == null:
		return
	var state: GameState = session.state
	var total_w := HP_COLS * HP_BLOCK_SIZE + (HP_COLS - 1) * HP_BLOCK_GAP
	var total_h := HP_ROWS * HP_BLOCK_SIZE + (HP_ROWS - 1) * HP_BLOCK_GAP
	_werk_rol_iconen_bij(state, total_w, total_h)
	for pid in _hp_bars:
		var entry: Dictionary = _hp_bars[pid]
		var pawn: Pawn = state.pawns.get(pid)
		var pv: PawnView = _pawn_views.get(pid)
		if pawn == null or pawn.is_eliminated or not pawn.is_active or pv == null or not pv.visible \
				or _camera.is_position_behind(pv.global_position):
			entry.holder.visible = false
			continue
		var blocks: Array = entry.blocks
		# Zoveel kolommen als deze pion nodig heeft (16 september, Max: "je kan
		# ook met CP en bonus 6 of 7 krijgen"): het gewone raster is 5 breed,
		# een pion met een hogere stat krijgt er kolommen bij, gecentreerd
		# onder de voeten; wat erbuiten valt blijft verborgen.
		var covered: bool = session.pion_gedekt(pawn.id)
		var attack_nu: int = Rules.effectieve_attack(state, pawn)
		var stamina_nu: int = Rules.stamina_beschikbaar(state, pawn)
		var kolommen: int = HP_COLS
		if not covered:
			kolommen = clampi(maxi(maxi(HP_COLS, pawn.max_hp), maxi(maxi(stamina_nu, pawn.max_stamina), attack_nu)), HP_COLS, HP_COLS_MAX)
		var breedte: float = kolommen * HP_BLOCK_SIZE + (kolommen - 1) * HP_BLOCK_GAP
		for r in HP_ROWS:
			for c in HP_COLS_MAX:
				(blocks[r * HP_COLS_MAX + c] as ColorRect).visible = c < kolommen
		# Onderaan het poppetje: anker op de voeten, blokjes er net onder.
		var screen := _camera.unproject_position(pv.global_position)
		entry.holder.visible = true
		entry.holder.position = screen - Vector2(breedte * 0.5, 0.0) + Vector2(0.0, 3.0)
		if entry.has("rol"):
			(entry.rol as Label).position.x = breedte * 0.5 - 5.0
		if entry.has("qlabel"):
			(entry.qlabel as Label).position.x = breedte * 0.5 - 6.0
		# F0.6: gedekte vijandelijke pion (Krokodil) → "?"-staat, geen echte stats.
		# F4.3c: één gate voor alle vijandelijke stat-uitlezingen; online komt
		# het antwoord uit het '?'-sentinel van de view.
		if entry.has("qlabel"):
			entry.qlabel.visible = covered
		var randen: Array = entry.get("randen", [])
		if covered:
			for b in blocks:
				b.color = HP_COLOR_EMPTY
			for rr in randen:
				rr.visible = false
			continue
		# C21-aura: het stamina-blokje boven de eigen voorraad is de trom-bonus
		# (4.3.5: alleen zolang de pion in de vorm staat en hem nog niet gebruikte);
		# de attack boven de kaart komt van het vaandel, zolang hij in die vorm
		# staat. Die extra blokjes krijgen een rand in de aura-kleur, zodat je ziet
		# wat je aan de drager te danken hebt.
		for c in HP_COLS_MAX:
			blocks[c].color = HP_COLOR_HEALTH if c < pawn.current_hp else HP_COLOR_EMPTY
			blocks[HP_COLS_MAX + c].color = HP_COLOR_STAMINA if c < stamina_nu else HP_COLOR_EMPTY
			blocks[2 * HP_COLS_MAX + c].color = HP_COLOR_ATTACK if c < attack_nu else HP_COLOR_EMPTY
			if randen.size() == blocks.size():
				randen[c].visible = false
				var trom: bool = c >= pawn.remaining_stamina and c < stamina_nu and c < kolommen
				randen[HP_COLS_MAX + c].visible = trom
				if trom:
					randen[HP_COLS_MAX + c].border_color = rol_kleur("drum", pawn.owner_id)
				var vaandel: bool = c >= pawn.attack_value and c < attack_nu and c < kolommen
				randen[2 * HP_COLS_MAX + c].visible = vaandel
				if vaandel:
					randen[2 * HP_COLS_MAX + c].border_color = rol_kleur("flag", pawn.owner_id)


# --- State-sync --------------------------------------------------------------

func _refresh_all() -> void:
	var state: GameState = session.state
	_werk_figurant_rollen_bij()   # vaandels/trommels ruimtelijk verdelen
	_sync_new_pawn_views()  # F2.6: verse spawns direct zichtbaar en klikbaar
	_update_piece_counts()
	for pid in _pawn_views:
		var pv: PawnView = _pawn_views[pid]
		var pawn: Pawn = state.pawns.get(pid)
		if pawn == null or pawn.is_eliminated:
			# Ragdoll bezig? Laat 'm staan; _kill_view ruimt hem op na de animatie.
			if not _dying_views.has(pid):
				pv.visible = false
			continue
		pv.visible = true
		if not _tweening_pawns.has(pid):
			# Melee-winnaar die nog moet oprukken: laat hem op zijn eigen vak
			# staan, ook al zegt de staat al dat hij verderop staat.
			var toon: Vector2i = _advance_holds.get(pid, pawn.position)
			pv.position = tile_position(toon.x, toon.y) + Vector3(0.0, PAWN_Y, 0.0)
		# Karaktermodel op basis van de gekoppelde kaart. Verborgen koppelingen (Krokodil-perk)
		# blijven neutraal voor de tegenstander (het archetype zou de kaart verraden);
		# je eigen pionnen tonen hun karakter altijd.
		var card: Card = null
		if pawn.linked_card_id >= 0 and not session.pion_gedekt(pawn.id):
			card = state.all_cards.get(pawn.linked_card_id)
		# Rol kan verhuizen (drager sneuvelt of koppelt): set_character weegt
		# hem opnieuw, want _rol zit in de karakter-sleutel.
		if pawn.unit_type == Constants.UnitType.INFANTRY:
			pv.rol_echt = String(pawn.rol)
			pv.rol_vast = String(_figurant_rollen.get(pawn.id, ""))
		pv.set_character(state.doctrine_of(pawn.owner_id), pawn.unit_type, card)
		pv.set_stats_label(pawn.is_active, pawn.current_hp, Rules.stamina_beschikbaar(state, pawn))
		pv.set_team_ring_active(pawn.is_active)
		if Phase.is_linking(state.phase):
			# Koppel-fase: donkere ring om EIGEN pionnen die nog geen kaart
			# hebben, felle ring op de gehoverde. F4.3e: geen ring op vijandelijke
			# pionnen, want hun koppelstaat is fog (gedekte Krokodil-pionnen
			# tonen in de view geen koppeling) en het scherm mag offline niets
			# laten zien dat online niet bestaat.
			var lstate: int = 1 if pawn.linked_card_id == -1 and pawn.owner_id == _human_id else 0
			if lstate == 1 and pid == _hovered_pawn_id:
				lstate = 2
			pv.set_ring_link_state(lstate)
		else:
			pv.set_ring_link_state(0)
		var human_action := state.phase == Phase.Type.ACTION and state.current_player == _human_id \
				and pawn.owner_id == _human_id and pawn.is_active
		pv.set_dimmed(human_action and not Rules.can_pawn_act(state, pid))
		pv.set_selected(pid == _selected_pawn_id)


# --- v4.2 (F2.6): CP-bod, versterkingen en de kanon-taal ----------------------

## Blinde CP-inzet (D1): elke CP maakt 1 kaart deze ronde budget+1.
func _show_cp_overlay() -> void:
	var st: GameState = session.state
	var saldo: int = int(st.cp.get(_human_id, 0))
	var maximaal: int = mini(saldo, Validator.expected_define_count(st, _human_id))
	var opties: Array = []
	var iconen: Array = []
	for n in maximaal + 1:
		opties.append(tr("MENU_CP_NONE") if n == 0 else tr("MENU_CP_OPTION") % [n, n])
		iconen.append("" if n == 0 else "cp")
	_overlay.show_choice(
		tr("MENU_CP_TITLE") % saldo,
		tr("MENU_CP_BODY"),
		opties, _on_cp_choice, Color.WHITE, true, iconen, "cp")


func _on_cp_choice(index: int) -> void:
	_overlay.hide()
	if _ai == null:
		# F4.3g/F4.2b: online reist de inzet in de define mee (één rij, geen
		# verklappende losse inzet); onthouden tot de waaier bevestigd is.
		_cp_bet_keuze = index
	elif index > 0:
		session.submit_bet_cp(_human_id, index)
	_open_define_hand(index)


## Kaartwaaier openen; de eerste `bonus` kaarten dragen het CP-budgetpunt.
func _open_define_hand(bonus: int) -> void:
	# Eerst het bord z'n moment geven, dan pas de kaarten. Dat was er al voor de
	# poef-reveal van verse versterkingen (besluit 27 juli: spawns zien landen
	# vóór de define-fase); sinds 7 september geldt het voor ELKE animatie --
	# ook een sterfte of een beweging die nog naloopt. Zo zie je de
	# versterkingen een voor een op het bord ploppen en pas daarna de kaarten.
	if _animaties_bezig():
		_define_open_bezig = true
		await _wacht_op_animaties()
		_define_open_bezig = false
		if session.state == null or not Phase.is_define(session.state.phase):
			return
	var doctrine: Dictionary = session.state.doctrine_data_of(_human_id)
	# 4.1.10-hr: hoogstens zoveel kaarten als vrije pionnen (bij 0 slaat de
	# engine deze ronde zelf over en schuift de fase vanzelf door).
	var kaart_aantal: int = Validator.expected_define_count(session.state, _human_id)
	_card_hand.configure(kaart_aantal, int(doctrine.budget), int(doctrine.speed_max), bonus, _human_id, _human_doctrine,
		_factie_bonus_van(doctrine))
	_card_hand.open_for_define()
	var uitleg := tr("HUD_DEFINE_PROMPT") % [kaart_aantal, int(doctrine.budget)]
	if bonus > 0:
		uitleg += tr("HUD_DEFINE_CP_SUFFIX") % bonus
	# De legenda (HP = leven, ...) is sinds de nieuwe kaarten dubbelop: elke
	# stat-kolom draagt zijn icoon. Zo blijft de prompt op een regel.
	_update_hud(uitleg)


## Versterkingen (v4.2): blinde aanvul-keuze; spawns landen op de achterste rij.
## C11 (besluit Max, 28 juli): zelf kiezen wat je koopt — soldaat (1 pt),
## ruiter (2 pt) of kanon (3 pt) uit je versterkingspot, max spawn_max per
## cyclus. De overlay herbouwt na elke keuze; vakken volgen de haven-prio.
var _spawn_keuze: Array = []


func _show_spawn_overlay() -> void:
	var st: GameState = session.state
	var kosten: Array = [st.spawn_kosten(0), st.spawn_kosten(1), st.spawn_kosten(2)]
	var besteed := 0
	var telling: Array = [0, 0, 0]
	for t in _spawn_keuze:
		besteed += kosten[t]
		telling[int(t)] += 1
	var punten_over: int = st.pool_total(_human_id) - besteed
	var cap: int = mini(mini(int(st.rules.campaign.get("spawn_max", 3)), st.spawns_over(_human_id)),
		Validator.vrije_spawn_vakken(st, _human_id).size())
	var body := "
".join([
		tr("PHASE_SPAWN_POINTS") % [punten_over, telling[0], telling[1], telling[2]],
		tr("PHASE_SPAWN_INFO") % [cap, st.spawns_over(_human_id)],
		tr("PHASE_SPAWN_BLIND"),
	])
	var opties: Array = []
	var acties: Array = []
	if _spawn_keuze.size() < cap:
		for t in 3:
			# Alleen types die je doctrine kent (Muis heeft geen artillerie).
			if not st.kent_type(_human_id, t):
				continue
			if punten_over >= kosten[t]:
				opties.append(tr("PHASE_SPAWN_BUY_%d" % t) % kosten[t])
				acties.append(t)
	opties.append(tr("PHASE_SPAWN_CONFIRM") % _spawn_keuze.size())
	acties.append("bevestig")
	if not _spawn_keuze.is_empty():
		opties.append(tr("PHASE_SPAWN_RESET"))
		acties.append("reset")
	_spawn_acties = acties
	_overlay.show_choice(tr("PHASE_SPAWN_TITLE"), body, opties, _on_spawn_choice, Color.WHITE, true,
		acties.map(Callable(HUD_BALK_SCRIPT, "spawn_icoon")), "spawn")


var _spawn_acties: Array = []


func _on_spawn_choice(index: int) -> void:
	_overlay.hide()
	if index < 0 or index >= _spawn_acties.size():
		return
	var actie = _spawn_acties[index]
	if actie is int:
		_spawn_keuze.append(int(actie))
		_show_spawn_overlay()
		return
	if String(actie) == "reset":
		_spawn_keuze = []
		_show_spawn_overlay()
		return
	# Bevestigen: vakken toewijzen in haven-prioriteitsvolgorde.
	var st: GameState = session.state
	var vrij: Array = Validator.vrije_spawn_vakken(st, _human_id)
	var inzet: Array = []
	for i in _spawn_keuze.size():
		if i >= vrij.size():
			break
		inzet.append({"type": int(_spawn_keuze[i]), "pos": vrij[i]})
	_spawn_keuze = []
	session.submit_spawn(_human_id, inzet)
	if _ai == null and session.state.phase == Phase.Type.CYCLE_SPAWN:
		_update_hud(tr("HUD_WAIT_OPPONENT"))  # F4.3e: online wacht je op de ander


## F2.4/B3: onder campaign spreekt artillerie CANNON_ACT (roll/shoot).
func _kanon_v42(pawn_id: int) -> bool:
	if not session.state.rules.campaign_actief():
		return false
	var p: Pawn = session.state.pawns.get(pawn_id, null)
	return p != null and p.unit_type == Constants.UnitType.ARTILLERY


# --- Define ------------------------------------------------------------------

func _on_define_confirmed(_cards: Array) -> void:
	var dicts: Array = _card_hand.get_defined_dicts()
	_card_hand.visible = false
	var inzet: int = _cp_bet_keuze if _ai == null else 0
	_cp_bet_keuze = 0
	session.submit_define_cards(_human_id, dicts, inzet)
	if _ai == null:
		# F4.3c: online definieert de tegenstander zelf; wij wachten (tenzij
		# de gate al dichtklapte en de fase doorschoof).
		if Phase.is_define(session.state.phase):
			_update_hud(tr("HUD_WAIT_OPPONENT"))
		return
	_ai_define_beurt()


## De bot definieert (met zijn CP-inzet) zodra de mens klaar is, of meteen als
## de mens deze ronde niets te definiëren heeft (F4.3e: dan opent er geen lege
## waaier meer, maar de bot moet wel aan de beurt komen).
func _ai_define_beurt() -> void:
	if _ai == null or not Phase.is_define(session.state.phase):
		return
	# F2.6 (v4.2): AI-bet op de ronde-3-kaarten (zelfde heuristiek als de arena).
	var st_ai: GameState = session.state
	var ai_bet: int = _ai.choose_cp_bet(st_ai)
	if ai_bet > 0:
		session.submit_bet_cp(_ai_id, ai_bet)
	var ai_cards: Array = _ai.generate_cards(session.state)
	for i in mini(ai_bet, ai_cards.size()):
		ai_cards[i].hp = int(ai_cards[i].hp) + 1
	if not session.submit_define_cards(_ai_id, ai_cards) and ai_bet > 0:
		for i in mini(ai_bet, ai_cards.size()):
			ai_cards[i].hp = int(ai_cards[i].hp) - 1
		session.submit_define_cards(_ai_id, ai_cards)


# --- Reveal (initiatief-bod, v4.1 §4.3-B) -------------------------------------

func _on_cards_revealed(t1: Dictionary, t2: Dictionary, initiative_winner: int) -> void:
	_toon_reveal(t1, t2, initiative_winner)


## F4.3e -- het onthul-scherm vanuit de totalen (uit het event, of uit
## Rules.compute_initiative op een herbouwde staat: dezelfde getallen).
## UI-assetpack: het scherm toont beide handen als echte kaarten (OnthulScherm).
func _toon_reveal(t1: Dictionary, t2: Dictionary, initiative_winner: int) -> void:
	# Ook het onthul-scherm wacht op het bord (besluit Max, 7 september): een
	# scherm dat over een lopende dood heen klapt, kost je precies het moment
	# waar je op zat te wachten.
	if _animaties_bezig():
		_fase_overgang_bezig = true
		await _wacht_op_animaties()
		_fase_overgang_bezig = false
		if session.state == null:
			return
	_update_hud(tr("PHASE_REVEAL"))
	# Trommelroffel bij de onthulling. (initiative-bugel staat nu uit.)
	Audio.play("reveal")
	# Audio.play("initiative", 0.6)
	# UI-assetpack (3 september): beide handen als echte kaarten op de veldtafel
	# in plaats van de tekst-overlay; het scherm hangt direct boven de overlay.
	if _onthul_scherm == null:
		_onthul_scherm = ONTHUL_SCHERM_SCRIPT.new()
		$UI.add_child(_onthul_scherm)
		$UI.move_child(_onthul_scherm, _overlay.get_index() + 1)
	_onthul_scherm.open(session.state, t1, t2, initiative_winner, _human_id, _player_name,
		func(_i: int) -> void: _continue_after_reveal(), session)


func _continue_after_reveal() -> void:
	_overlay.hide()
	if _ai != null:
		session.acknowledge_reveal()  # offline: de shim ackt voor beide kanten
	else:
		session.submit_ack_reveal(_human_id)  # F4.3c: online alleen de eigen ack
		if Phase.is_reveal(session.state.phase):
			_update_hud(tr("HUD_WAIT_OPPONENT"))


# --- Linking (mens interactief, AI automatisch) -----------------------------

func _begin_human_linking() -> void:
	# Max (12 september): "houd mijn kaart geselecteerd ook al is de AI eerst
	# aan de beurt, totdat ik gelinkt heb". De keuze uit de beurt van de
	# tegenstander blijft staan; alleen een kaart die intussen gekoppeld is of
	# niet van deze ronde is, valt weg.
	var kaarten: Array = session.state.cards_revealed.get(_human_id, [])
	var index := _link_kaart_index(kaarten)
	if index < 0:
		_selected_link_card_id = -1
	_clear_highlights()
	_toon_linking_hand()
	_set_turn_prompt(tr("HUD_LINK_PROMPT"), _human_id)
	if index >= 0:
		_card_hand.selecteer(index)
		_highlight_own_unlinked_pawns()
		_update_hud(tr("HUD_LINK_PICK_PAWN"))


## Index van de gekozen koppel-kaart in de onthulde kaarten van deze ronde,
## -1 als er geen keuze staat of die kaart al gekoppeld is.
func _link_kaart_index(kaarten: Array) -> int:
	if _selected_link_card_id < 0:
		return -1
	for i in kaarten.size():
		var c: Card = kaarten[i]
		if c.id == _selected_link_card_id:
			return -1 if c.is_linked() else i
	return -1


## F4.3e -- de koppel-waaier vanuit de STAAT: de onthulde kaarten van deze
## ronde met hun stats en koppel-vlaggen. Live en hersteld dezelfde bron; de
## waaier van de define-fase is na een koude start immers weg, en de
## standaard-drie tonen zou de speler zijn eigen kaarten verkeerd laten zien.
func _toon_linking_hand() -> void:
	var st: GameState = session.state
	var kaarten: Array = st.cards_revealed.get(_human_id, [])
	if kaarten.is_empty():
		_card_hand.visible = false
		return
	var doctrine: Dictionary = st.doctrine_data_of(_human_id)
	# UI-assetpack: de kaart draagt embleem en teamkleur; het CP-zegel volgt
	# uit de stats zelf (som boven het budget = de blinde inzet van die ronde).
	_card_hand.configure(kaarten.size(), int(doctrine.budget), int(doctrine.speed_max), 0,
		_human_id, _human_doctrine, _factie_bonus_van(doctrine))
	var views: Array = _card_hand.get_card_views()
	var flags: Array = []
	for i in kaarten.size():
		var card: Card = kaarten[i]
		if i < views.size():
			var cv: CardView = views[i]
			cv.data.hp = card.hp
			cv.data.stamina = card.stamina
			cv.data.attack = card.attack
			cv.set_cp_inzet(card.hp + card.stamina + card.attack > int(doctrine.budget))
			cv._refresh()
		flags.append(card.is_linked())
	_card_hand.open_for_linking(flags)


func _on_link_card_picked(index: int) -> void:
	var state: GameState = session.state
	# Een kaart kiezen mag de hele koppel-fase, ook terwijl de tegenstander
	# koppelt (Max, 12 september); de pion volgt zodra jij aan de beurt bent.
	if not Phase.is_linking(state.phase):
		return
	var cards: Array = state.cards_revealed.get(_human_id, [])
	if index < 0 or index >= cards.size():
		return
	var card: Card = cards[index]
	if card.is_linked():
		return
	_selected_link_card_id = card.id
	_highlight_own_unlinked_pawns()
	if state.current_player == _human_id:
		_update_hud(tr("HUD_LINK_PICK_PAWN"))
	else:
		_update_hud(tr("HUD_LINK_CARD_READY"))


func _on_link_pawn_clicked(pawn_id: int) -> void:
	if _selected_link_card_id < 0:
		_update_hud(tr("HUD_LINK_PICK_CARD_FIRST"))
		return
	if session.state.current_player != _human_id:
		# de kaart staat klaar; koppelen kan pas in je eigen beurt
		_update_hud(tr("HUD_LINK_CARD_READY"))
		return
	var pawn: Pawn = session.state.pawns.get(pawn_id)
	if pawn == null or pawn.owner_id != _human_id or pawn.is_eliminated or pawn.linked_card_id != -1:
		return
	session.submit_link(_human_id, _selected_link_card_id, pawn_id)
	_animate_link(pawn_id)
	if _pawn_views.has(pawn_id):
		(_pawn_views[pawn_id] as PawnView).set_ring_link_state(0)
	_selected_link_card_id = -1
	_clear_highlights()
	# de waaier meteen bijwerken (de gekoppelde kaart dimt), zodat een volgende
	# keuze tijdens de beurt van de tegenstander op de juiste kaarten valt
	if Phase.is_linking(session.state.phase):
		_toon_linking_hand()


# --- Slepen: kaart naar pion (16 september) ----------------------------------

## Eigen, levende, nog ongekoppelde pion onder dit schermpunt; anders -1.
func _koppel_doel(pos: Vector2) -> int:
	var pid: int = _raycast_pawn(pos)
	if pid < 0:
		return -1
	var pawn: Pawn = session.state.pawns.get(pid)
	if pawn == null or pawn.owner_id != _human_id or pawn.is_eliminated or pawn.linked_card_id != -1:
		return -1
	return pid


## Schermpunt boven een pion (kop van de pijl, doel van de vliegende kaart).
func _pion_schermpunt(pid: int, hoogte: float) -> Vector2:
	if _camera == null or not _pawn_views.has(pid):
		return Vector2.ZERO
	return _camera.unproject_position((_pawn_views[pid] as Node3D).global_position + Vector3(0.0, hoogte, 0.0))


## Elke sleepbeweging: pijl van de kaart naar de vinger, of vastgeklikt op
## de pion eronder (goud, pulserende ring); de pion zelf licht op via
## dezelfde hover als een muisbeweging over het bord.
func _on_koppel_sleep(index: int, pos: Vector2) -> void:
	if _koppel_pijl == null:
		return
	var pid: int = _koppel_doel(pos)
	var eind: Vector2 = pos
	if pid >= 0:
		eind = _pion_schermpunt(pid, 0.55)
	_update_hover(pos)
	_koppel_pijl.toon(_card_hand.kaart_punt(index), eind, pid >= 0, UiAssets.team_kleur(_human_id, true))


## Losgelaten: boven een koppelbare pion vliegt de kaart ernaartoe en koppelt
## hij (zelfde weg als tik-tik, dus dezelfde checks en meldingen); ernaast
## blijft de kaart gekozen, zodat een tik op een pion alsnog koppelt.
func _on_koppel_drop(index: int, pos: Vector2) -> void:
	var pid: int = _koppel_doel(pos)
	var vliegt: bool = pid >= 0 and _selected_link_card_id >= 0 and session.state.current_player == _human_id
	if vliegt:
		_vlieg_kaart_naar(index, pid)   # haalt de pijl in en verbergt hem aan het eind
	elif _koppel_pijl != null:
		_koppel_pijl.verberg()
	if pid < 0:
		_update_hover(pos)
		return
	_on_link_pawn_clicked(pid)


func _on_koppel_annuleer(_index: int) -> void:
	if _koppel_pijl != null:
		_koppel_pijl.verberg()


## De kaart gaat langs de pijl naar de pion (Max, 16 september: "laat de
## kaart verdwijnen na slepen, niet zo omhoog animeren, of het pad van de
## arrow volgen"): een spookkaart met dezelfde stats hangt met zijn
## bovenkant (het beginpunt van de pijl) precies op de boog en volgt die
## naar de kop, met de neus langs de raaklijn, krimpend; de pijl wordt
## ingehaald (zijn begin schuift met de kaart mee) en verdwijnt aan het
## eind. De echte kaart is uit de hand zolang de vlucht duurt en komt
## daarna gedimd (gekoppeld) terug. Daaronder speelt _animate_link.
func _vlieg_kaart_naar(index: int, pid: int) -> void:
	var views: Array = _card_hand.get_card_views()
	if index < 0 or index >= views.size() or _camera == null or not _pawn_views.has(pid):
		return
	var bron: CardView = views[index]
	var doctrine: Dictionary = session.state.doctrine_data_of(_human_id)
	var spook: CardView = CardView.maak(bron.data.hp, bron.data.stamina, bron.data.attack,
		_human_id, _human_doctrine, int(doctrine.get("budget", bron.data.budget)))
	spook.name = "Spookkaart"
	spook.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(spook)
	# Anker bovenaan in het midden: dat is het beginpunt van de pijl, en dat
	# punt blijft op de boog; de kaart hangt eronder en krimpt weg.
	var anker := Vector2(UiAssets.KAART_MAAT.x * 0.5, 0.0)
	spook.pivot_offset = anker
	var van: Vector2 = _card_hand.kaart_punt(index)
	var naar: Vector2 = _pion_schermpunt(pid, 0.55)
	var schaal_van: Vector2 = bron.scale
	var draai_van: float = bron.rotation
	# `position`, niet `global_position`: die setter zet in 4.7 de OORSPRONG van
	# de transform (die bij een draai om een spil verschuift), en de spil hoort
	# op het pad. De UI-laag heeft geen eigen verschuiving.
	spook.position = van - anker
	spook.rotation = draai_van
	spook.scale = schaal_van
	bron.modulate.a = 0.0
	var kleur: Color = UiAssets.team_kleur(_human_id, true)
	var tween := create_tween().set_parallel()
	tween.tween_method(func(t: float) -> void:
		if not is_instance_valid(spook):
			return
		var p: Vector2 = KoppelPijl.boogpunt(van, naar, t)
		spook.position = p - anker
		spook.scale = schaal_van.lerp(Vector2.ONE * 0.12, sqrt(t))   # snel klein, dan de laatste meters als een stip
		var raaklijn: Vector2 = KoppelPijl.boogpunt(van, naar, minf(t + 0.03, 1.0)) \
			- KoppelPijl.boogpunt(van, naar, maxf(t - 0.03, 0.0))
		if raaklijn.length() > 0.5:
			spook.rotation = lerp_angle(draai_van, raaklijn.angle() + PI * 0.5, clampf(t * 3.0, 0.0, 1.0))
		if _koppel_pijl != null:
			_koppel_pijl.toon(p, naar, true, kleur), 0.0, 1.0, VLUCHT_DUUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(spook, "modulate:a", 0.0, 0.12).set_delay(VLUCHT_DUUR - 0.12)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(spook):
			spook.queue_free()
		if _koppel_pijl != null:
			_koppel_pijl.verberg()
		if is_instance_valid(bron):
			var terug := create_tween()
			terug.tween_property(bron, "modulate:a", 1.0, 0.25))


## Koppel-fase: donkere ring om de EIGEN nog niet gekoppelde pionnen (F4.3e:
## niet meer om die van de tegenstander, dat is fog); gekoppelde pionnen
## tonen hun actieve gloeiende team-ring en hover maakt de ring fel en iets
## groter (zie _update_hover).
func _highlight_own_unlinked_pawns() -> void:
	_clear_highlights()
	for pid in _pawn_views:
		var pawn: Pawn = session.state.pawns.get(pid)
		if pawn == null or pawn.is_eliminated:
			continue
		# F4.3e: alleen EIGEN koppelbare pionnen krijgen de ring. De koppelstaat
		# van een gedekte vijand is fog (de view wist hem), dus een ring daar
		# zou offline iets tonen dat online niet bestaat.
		var koppelbaar: bool = pawn.owner_id == _human_id and pawn.linked_card_id == -1
		(_pawn_views[pid] as PawnView).set_ring_link_state(1 if koppelbaar else 0)


func _auto_link(player_id: int) -> void:
	for card in session.state.cards_revealed[player_id]:
		if card.is_linked():
			continue
		var pawn: Pawn = _pick_link_pawn(player_id)
		if pawn != null:
			session.submit_link(player_id, card.id, pawn.id)
			_animate_link(pawn.id)
		return


## Korte koppel-animatie: pion springt even omhoog + glim-flits.
func _animate_link(pawn_id: int) -> void:
	Audio.play("link_snap")  # kaart klikt vast op de pion
	# Koppelen is het moment dat een standbeeld een SOLDAAT wordt; Max wil daar
	# het spawn-geluid onder (30 juli). Via play_getuned, dus dB en timing stel
	# je bij in de Model-tuner (tab Geluid) zonder code.
	Audio.play_getuned("spawn_sound")
	var pv: PawnView = _pawn_views.get(pawn_id)
	if pv == null:
		return
	pv.flash_ring(Color(0.5, 0.85, 1.0))
	# Rook-pofje verhult de model-wissel: base -> archetype gebeurt ONDER de
	# rook, zodat het poppetje na de pof als z'n nieuwe (bv. spd) versie
	# tevoorschijn komt. Grootte tunebaar via "koppel-pof".
	var puff: int = int(round(4.0 * PawnView.fx("link_puff", 1.0)))
	if puff > 0:
		# Witte wolk voor de koppel-/spawn-pof (Max, 30 juli): kruitrook hoort
		# bij schieten, een verse soldaat komt uit een schone witte pof.
		_spawn_smoke(pv.position + Vector3(0.0, 0.45, 0.0), puff, 0.2,
			Vector3.UP * 0.25, 1.3, "white_smoke")
	# Onder de pof: naar het archetype-model wisselen + daar de ready-flourish.
	var link_pawn: Pawn = session.state.pawns.get(pawn_id)
	var link_card: Card = null
	# F4.3e: dezelfde gate als _refresh_all. Een gedekte Krokodil-koppeling
	# van de tegenstander wisselt NIET naar het archetype-model: dat verraadt
	# de kaart, en de view geeft hem niet.
	if link_pawn != null and link_pawn.linked_card_id >= 0 and not session.pion_gedekt(pawn_id):
		link_card = session.state.all_cards.get(link_pawn.linked_card_id)
	get_tree().create_timer(0.14).timeout.connect(func() -> void:
		if not is_instance_valid(pv):
			return
		if link_pawn != null:
			pv.set_character(session.state.doctrine_of(link_pawn.owner_id), link_pawn.unit_type, link_card)
		if randf() < PawnView.fx("ready_chance", 0.3):
			pv.play_ready())
	_tweening_pawns[pawn_id] = true
	var base_y := pv.position.y
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(pv, "position:y", base_y + 0.35, 0.13).set_ease(Tween.EASE_OUT)
	tween.tween_property(pv, "position:y", base_y, 0.17).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _tweening_pawns.erase(pawn_id))


## Ontkoppel-cascade (nieuwe cyclus): elk gekoppeld stuk krijgt snel na
## elkaar een rook-pofje waaronder het model terugwisselt naar base -
## precies de omgekeerde beweging van de koppel-pof. Reserves (al base)
## en lege vakken doen niks mee.
func _uncouple_cascade() -> void:
	var state: GameState = session.state
	var idx := 0
	for pid in _pawn_views:
		var pv: PawnView = _pawn_views[pid]
		var pawn: Pawn = state.pawns.get(pid)
		if pawn == null or pawn.is_eliminated or not pv.visible or not pv.has_archetype_look():
			continue
		var delay := float(idx) * 0.03  # snelle golf over de linie
		idx += 1
		var doctrine: int = state.doctrine_of(pawn.owner_id)
		var utype: int = pawn.unit_type
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if not is_instance_valid(pv):
				return
			var puff: int = int(round(4.0 * PawnView.fx("link_puff", 1.0)))
			if puff > 0:
				_spawn_smoke(pv.position + Vector3(0.0, 0.45, 0.0), puff, 0.2,
					Vector3.UP * 0.25, 1.3, "white_smoke")
			pv.set_character(doctrine, utype, null))  # terug naar base


func _pick_link_pawn(player_id: int) -> Pawn:
	# Bij voorkeur een pion met ademruimte (kan bewegen/aanvallen); anders
	# eindig je met ingeklemde achterste-rij pionnen die niks kunnen.
	var fallback: Pawn = null
	for pawn in session.state.pawns.values():
		if pawn.owner_id != player_id or pawn.is_eliminated or pawn.linked_card_id != -1:
			continue
		if fallback == null:
			fallback = pawn
		if _pawn_has_room(pawn):
			return pawn
	return fallback


func _pawn_has_room(pawn: Pawn) -> bool:
	var state: GameState = session.state
	for neighbor in Constants.manhattan_neighbors(pawn.position):
		if not Constants.is_on_board(neighbor):
			continue
		if state.is_tile_empty(neighbor):
			return true
		var other: Pawn = state.get_pawn_at(neighbor)
		if other != null and other.owner_id != pawn.owner_id and not other.is_eliminated:
			return true
	return false


# --- Phase / turn ------------------------------------------------------------

func _on_phase_changed(new_phase: int, old_phase: int) -> void:
	_stop_phase_timer()
	_selected_link_card_id = -1  # een kaartkeuze leeft alleen binnen een koppel-fase
	if new_phase == Phase.Type.ACTION:
		_clear_highlights()
	if Phase.is_define(new_phase):
		if Phase.is_linking(old_phase):
			# Laat de zojuist gekoppelde pion(nen) even zien vóór de nieuwe ronde.
			_refresh_all()
			_update_hud(tr("HUD_ROUND_DONE"))
			_fase_overgang_bezig = true
			await get_tree().create_timer(0.9).timeout
			_fase_overgang_bezig = false
		if session.state.round_number <= 1:
			_clear_footprints()  # nieuwe cyclus: vers slagveld
			_uncouple_cascade()  # gekoppelde stukken poffen snel terug naar base
		Audio.play("phase_change")  # zachte overgang naar een nieuwe definitie-ronde
		_open_define_fase()
	elif Phase.is_linking(new_phase):
		_auto_link_human = false
		_toon_linking_hand()  # F4.3e: je kaarten staan de hele koppel-fase in beeld
		_highlight_own_unlinked_pawns()  # ringen meteen aan, niet pas na kaart-klik
		_start_phase_timer(PHASE_TIME_LIMIT)
	elif new_phase == Phase.Type.CYCLE_SPAWN:
		_open_spawn_fase()
	elif new_phase == Phase.Type.PLACEMENT and _ai == null:
		# F4.3g: online opent de opstelfase pas als beide facties bekend zijn.
		_card_hand.visible = false
		_show_placement_overlay()
	else:
		_card_hand.visible = false


## F4.3e -- de define-fase openen vanuit de staat alleen (ook bij herstel).
## F2.6 (v4.2): eerst de blinde CP-inzet (D1), dan de kaartwaaier.
func _open_define_fase() -> void:
	var st_def: GameState = session.state
	_update_hud()  # topbalk op de nieuwe fase, ook als eerst het CP-bod opent
	if st_def.cards_defined.get(_human_id, []).size() > 0:
		# Al gedefinieerd (herstel, of een late fase-overgang): alleen wachten.
		_card_hand.visible = false
		if _ai == null:
			_update_hud(tr("HUD_WAIT_OPPONENT"))
		return
	if Validator.expected_define_count(st_def, _human_id) == 0:
		# Geen vrije pionnen: deze ronde sla je over (4.1.10-hr). Geen lege
		# waaier met een bevestigknop die een ongeldige define zou sturen; de
		# bot komt meteen aan de beurt, online wacht je op de ander.
		_card_hand.visible = false
		if _ai != null:
			_ai_define_beurt()
		else:
			_update_hud(tr("HUD_WAIT_OPPONENT"))
		return
	# Eerst het bord, dan pas een scherm (Max, 16 september: "je ziet het bord
	# de soldaten spawnen bij beide teams, dan daarna kies je CP en definieer
	# je de kaarten"). De poef-reveal van de versterkingen (plus de kijkpauze
	# erna), de ontkoppel-golf en een nalopende sterfte spelen uit vóórdat het
	# CP-bod opent. Daarvoor wachtte alleen de kaartwaaier (na het bod) en
	# schoof het bod-scherm over de landende versterkingen heen. Headless
	# wacht niet (zie _wacht_op_animaties), dus uispel blijft gelijk.
	if _animaties_bezig():
		_card_hand.visible = false
		_define_open_bezig = true
		if st_def.round_number <= 1:
			_update_hud(tr("HUD_SPAWN_LANDING"))
		await _wacht_op_animaties()
		_define_open_bezig = false
		st_def = session.state
		if st_def == null or not Phase.is_define(st_def.phase) \
				or st_def.cards_defined.get(_human_id, []).size() > 0:
			return  # intussen doorgeschoven (timeout, herstel): niets openen
		_update_hud()
	if st_def.rules.campaign_actief() and not st_def.cp_bet_done.get(_human_id, false) \
			and int(st_def.cp.get(_human_id, 0)) > 0 \
			and Validator.expected_define_count(st_def, _human_id) > 0:
		_card_hand.visible = false  # de koppel-waaier van de vorige ronde weg
		_show_cp_overlay()
	else:
		_open_define_hand(int(st_def.cp_bets.get(_human_id, 0)))
	_start_phase_timer(PHASE_TIME_LIMIT)


## F4.3e -- de spawn-fase openen vanuit de staat alleen (ook bij herstel).
## F2.6 (v4.2): versterkingen - de bot dient blind zijn aanvul-inzet in, de
## mens kiest via de overlay. Beide binnen -> gelijktijdige reveal.
func _open_spawn_fase() -> void:
	_card_hand.visible = false
	_refresh_all()
	_update_hud(tr("PHASE_SPAWN_TITLE"))
	if _ai != null and not session.state.spawn_done.get(_ai_id, false):
		session.submit_spawn(_ai_id, _ai.choose_spawn(session.state))
	# Ook hier eerst het bord (de laatste sterfte van de ronde, een lijk dat
	# wegzakt), dan pas het keuzescherm (Max, 7 september: "speel altijd eerst
	# alle animaties af voordat de nieuwe kaarten of schermen in beeld komen").
	if _animaties_bezig():
		_define_open_bezig = true
		await _wacht_op_animaties()
		_define_open_bezig = false
		if session.state == null or session.state.phase != Phase.Type.CYCLE_SPAWN:
			return  # intussen doorgeschoven (timeout, herstel)
	if session.state.phase == Phase.Type.CYCLE_SPAWN \
			and not session.state.spawn_done.get(_human_id, false):
		_show_spawn_overlay()
		_start_phase_timer(PHASE_TIME_LIMIT)
	elif _ai == null and session.state.phase == Phase.Type.CYCLE_SPAWN:
		_update_hud(tr("HUD_WAIT_OPPONENT"))  # eigen inzet staat al: wachten


func _on_turn_changed(player_id: int) -> void:
	var state: GameState = session.state
	if Phase.is_linking(state.phase):
		_refresh_all()
		if player_id == _human_id:
			if _auto_link_human:
				_auto_link(_human_id)
			else:
				_begin_human_linking()
		else:
			_set_turn_prompt(tr("HUD_OPPONENT_LINKING"), player_id)
			if _ai == null:
				return  # F4.3c: online koppelt de tegenstander zelf; wij wachten
			# ADEMRUIMTE (Max, 30 juli: "als ik mijn character koppel dan freezed
			# ie en is de ai meteen ook gekoppeld"). De tegenstander koppelde in
			# dezelfde tel als jij, inclusief zijn model-wissel: dat leest als
			# een hapering. Nu wacht hij eerst even zichtbaar "na te denken".
			# Knop: ai_link_denktijd in effects_tuning.json (0 = meteen).
			var denktijd: float = PawnView.fx("ai_link_denktijd", 0.55)
			if denktijd > 0.0:
				await get_tree().create_timer(denktijd).timeout
			# Fase kan intussen zijn doorgeschoven (timeout, forfeit).
			var nu: GameState = session.state
			if not Phase.is_linking(nu.phase) or nu.current_player != player_id:
				return
			_auto_link(player_id)
	elif state.phase == Phase.Type.ACTION:
		_selected_pawn_id = -1
		_clear_highlights()
		_refresh_all()
		if player_id == _ai_id:
			_stop_phase_timer()
			_set_turn_prompt(tr("HUD_OPPONENT_TURN"), player_id)
			if _ai != null:  # F4.3c: online zet de tegenstander zelf
				_ai_action_turn()
		else:
			# Beurt-timer voor de mens: tijd om → het spel kiest een zet.
			_start_phase_timer(PHASE_TIME_LIMIT)
			# Audio.play("your_turn")  # staat nu uit
			_set_turn_prompt(tr("HUD_YOUR_TURN"), player_id)


func _ai_action_turn() -> void:
	await get_tree().create_timer(0.3).timeout
	if session.state.phase != Phase.Type.ACTION or session.state.current_player != _ai_id:
		return
	# Reken de AI-zet op een aparte thread → de animaties bevriezen niet.
	var snapshot: GameState = session.state.clone()
	var thread := Thread.new()
	_ai_thread = thread
	thread.start(_ai.choose_action.bind(snapshot))
	while thread.is_alive():
		await get_tree().process_frame
		if _ai_thread != thread:
			return  # opgeruimd (scene sluit of nieuwe match) — niet dubbel joinen
	if _ai_thread != thread:
		return
	var action: Dictionary = thread.wait_to_finish()
	_ai_thread = null
	if session.state.phase != Phase.Type.ACTION or session.state.current_player != _ai_id:
		return
	if action.is_empty():
		return
	match String(action.type):
		"move":
			if _kanon_v42(int(action.pawn_id)):
				session.submit_cannon_roll(_ai_id, action.pawn_id, action.target)
			else:
				session.submit_move(_ai_id, action.pawn_id, action.target)
		"attack":
			session.submit_attack(_ai_id, action.attacker_id, action.defender_id)
		"shot":
			if _kanon_v42(int(action.shooter_id)):
				session.submit_cannon_shoot(_ai_id, action.shooter_id, action.target_id)
			else:
				session.submit_shot(_ai_id, action.shooter_id, action.target_id)
		"charge":
			session.submit_charge(_ai_id, action.pawn_id, action.move_target, action.defender_id)


## Wolf-doctrine: na een melee mag de aanvaller 1 gratis stap zetten.
func _on_wolf_step_pending(pawn_id: int) -> void:
	var state: GameState = session.state
	if state.current_player == _ai_id:
		if _ai == null:
			_update_hud(tr("HUD_WAIT_WOLF"))  # F4.3c: online kiest de tegenstander zelf
			return
		await get_tree().create_timer(0.35).timeout
		if session.state.pending_wolf_step_pawn != pawn_id:
			return
		var step: Dictionary = _ai.choose_wolf_step(session.state)
		if step.has("target"):
			session.submit_wolf_step(_ai_id, step.target)
		else:
			session.skip_wolf_step(_ai_id)
		return
	# Mens: klik een gemarkeerd vak, of rechtermuis/pion-klik om over te slaan.
	_wolf_step_mode = true
	_wolf_step_tiles = []
	var pawn: Pawn = state.pawns.get(pawn_id)
	if pawn != null:
		for neighbor in Constants.manhattan_neighbors(pawn.position):
			if Constants.is_on_board(neighbor) and state.is_tile_empty(neighbor):
				_wolf_step_tiles.append(neighbor)
	_clear_highlights()
	_highlight_tiles(_wolf_step_tiles, Color(0.4, 0.9, 0.9))
	_update_hud(tr("HUD_WOLF_STEP"))


func _end_wolf_step_mode() -> void:
	_wolf_step_mode = false
	_wolf_step_tiles = []
	_clear_highlights()


## Sterf-geluid per type (nu alleen cavalerie: horse_die). Het pion-object blijft
## na eliminatie in state.pawns bestaan (alleen is_eliminated=true), dus het type
## is nog opvraagbaar.
## Chime als een pion de doelhaven bereikt (maar de partij nog niet gewonnen is —
## de winnende 2e pion krijgt de win-fanfare, niet deze chime).
func _check_haven_score(pawn_id: int, coord: Vector2i) -> void:
	var pawn: Pawn = session.state.pawns.get(pawn_id)
	if pawn == null or pawn.is_eliminated:
		return
	if Rules.is_haven_for_player(coord, pawn.owner_id) and Rules.check_win(session.state) == -1:
		Audio.play("haven_score", 0.25)


## Terugslag-geluid: als de terugslaande verdediger een paard is, hoor je het
## paard (hoefgetrappel/hinnik). Bij infanterie-terugslag dekt de melee-klap het al.
## De zwaai en de klap van een melee-aanval, per WAPEN en factie (17
## september, Max: "slashing sounds en zwaard-impactgeluiden per factie of
## type wapen"). De zwaai (`slash_<wapen>`) klinkt `melee_slash_voor` (0,18 s,
## Model-tuner) voor de klap; de klap is `melee_kill_<wapen>` of
## `melee_survive_<wapen>`, met een factie-opname erboven als die er ligt
## (Audio.melee_keten), en anders het oude algemene melee_kill/melee_survive.
func _melee_geluid(attacker_id: int, attacker: PawnView, gedood: bool, klap_delay: float) -> void:
	var pawn: Pawn = session.state.pawns.get(attacker_id)
	if pawn == null:
		return
	var doc: int = session.state.doctrine_of(pawn.owner_id)
	var arch: String = attacker.archetype() if attacker != null else ""
	var wapen: String = PawnView.melee_wapen(pawn.unit_type, arch, doc)
	var voor: float = (attacker.melee_fx("slash_voor", "melee_slash_voor", 0.18)
			if attacker != null else PawnView.fx("melee_slash_voor", 0.18))
	Audio.play_melee("slash", wapen, doc, maxf(klap_delay - voor, 0.0))
	Audio.play_melee("melee_kill" if gedood else "melee_survive", wapen, doc, klap_delay)


func _retaliation_sound(defender_id: int, delay: float) -> void:
	var def: Pawn = session.state.pawns.get(defender_id)
	if def == null:
		return
	if def.unit_type == Constants.UnitType.CAVALRY:
		Audio.play("retaliation_horse", delay)  # paard trapt terug
	else:
		Audio.play("retaliation", delay)  # infanterie: staal-op-staal counter


## kanon = geraakt door artillerie: dan een eigen, zwaardere kreet die VLAK
## VOOR de inslag inzet (besluit Max, 28 juli) -- je hoort het slachtoffer al
## gillen terwijl de kogel nog onderweg is.
## Materiaal-laag onder de treffer (SOUND-WISHLIST 7b-2, besluit Max 30 juli).
## Het schot en de klap houden hun eigen geluid; hier komt eronder te liggen
## WAT er geraakt is, zodat een kanon anders klinkt dan een lijf:
##   artillerie geraakt      -> impact_wood (affuit en wielen)
##   hp-archetype geraakt    -> impact_armor (die draagt het kuras)
##   al het andere leven     -> impact_flesh
##   dodelijke melee erbij   -> impact_bone (kans, anders wordt het een deuntje)
##   schot dat NIET doodt    -> ricochet erbij (kogel zingt weg langs het lijf)
## De keuze zelf staat in PawnView.impact_categorie -- één plek, zodat de
## tuner exact hoort wat het spel speelt.
## Tijden en volumes stel je per categorie af in de tuner (Geluid-tab).
func _impact_laag(target_id: int, damage: int, gedood: bool, delay: float,
		melee: bool = false) -> void:
	var pawn: Pawn = session.state.pawns.get(target_id)
	if pawn == null or damage <= 0:
		return
	var pv: PawnView = _pawn_views.get(target_id)
	var arch: String = pv.archetype() if pv != null else ""
	Audio.play_getuned(PawnView.impact_categorie(pawn.unit_type, arch), delay)
	if gedood:
		if melee and randf() < 0.5:
			Audio.play_getuned("impact_bone", delay + 0.05)
		return
	# Overleefd schot: de kogel ketst af in plaats van door te dringen. Dit is
	# het enige moment waarop je een afketser hoort -- schade is in de regels
	# altijd minstens 1, dus een "mis" bestaat niet (audit 30 juli).
	if not melee and randf() < 0.4:
		Audio.play_getuned("ricochet", delay + 0.03)


func _death_sound(pawn_id: int, delay: float, kanon: bool = false) -> void:
	var pawn: Pawn = session.state.pawns.get(pawn_id)
	if pawn == null:
		return
	if kanon and pawn.unit_type == Constants.UnitType.INFANTRY:
		# Kanon: de zwaardere kreet zet vóór de inslag in (anticipatie), dus
		# die blijft hier staan -- een kanontreffer slaat er sowieso delen af.
		# Archetype van dit model erbij: een dikke hp-pion mag anders klinken.
		var pv_k: PawnView = _pawn_views.get(pawn_id)
		var arch: String = pv_k._archetype if pv_k != null else ""
		Audio.play_factie("inf_kanon_die", session.state.doctrine_of(pawn.owner_id),
			delay, 0.0, "inf_die", arch)
		# De pion weet nu dat zijn kreet al klonk en zwijgt bij de inslag.
		if pv_k != null:
			pv_k.kreet_al_gespeeld = true
		return
	# Factie-variant als die bestaat (SOUND-WISHLIST 7b), anders het algemene
	# geluid: een muis piept, een grizzly brult.
	var doc: int = session.state.doctrine_of(pawn.owner_id)
	match pawn.unit_type:
		# Infanterie: het sterfgeluid van de FACTIE (Max, 30 juli: "ik hoor nog
		# gewoon de normale die sound"). Hier stond `Audio.play("inf_die")`, dus
		# een muis stierf met het algemene soldatengeluid en zijn eigen zes
		# muizen-kreten klonken alleen in de 15%-gevallen van PawnView. Nu loopt
		# het door de keten inf_die_<factie>_<archetype> -> inf_die_<factie> ->
		# inf_die: een muis piept dus altijd als een muis, en een factie zonder
		# eigen bestanden valt netjes terug op het algemene geluid.
		Constants.UnitType.INFANTRY:
			var pv_d: PawnView = _pawn_views.get(pawn_id)
			var arch_d: String = pv_d._archetype if pv_d != null else ""
			Audio.play_factie("inf_die", doc, delay, 0.0, "", arch_d)
			# PawnView hoeft niet nog eens: anders hoor je hem dubbel.
			if pv_d != null:
				pv_d.kreet_al_gespeeld = true
		Constants.UnitType.CAVALRY: Audio.play_factie("horse_die", doc, delay)
		Constants.UnitType.ARTILLERY:
			Audio.play_factie("cannon_die", doc, delay)
			# Een affuit die het opgeeft verliest een wiel (Max, 30 juli): de
			# crash eerst, daarna rolt het wiel weg. Niet altijd, anders wordt
			# het een deuntje; de vertraging stel je af in de tuner.
			if randf() < 0.6:
				Audio.play_getuned("cannon_wheel_loose",
					delay + Audio.basis_vertraging("cannon_wheel_loose"))


func _on_action_performed(action: Dictionary, result: Dictionary) -> void:
	_selected_pawn_id = -1
	_valid_moves = []
	_valid_attacks = []
	_valid_shots = []
	_valid_charges = {}
	_clear_highlights()
	match String(action.get("type", "")):
		"move":
			_animate_move(action.pawn_id, action.from, action.target)
			_check_haven_score(action.pawn_id, action.target)
		"attack":
			var attacker: PawnView = _pawn_views.get(action.attacker_id)
			if attacker != null:
				attacker.face_dir(result.defender_pos - result.attacker_from_pos)
				# melee-draai: sommige stoot-clips prikken schuin t.o.v. de
				# kijkrichting; deze knop draait de aanvaller bij zodat de
				# bajonet echt richting het doelwit gaat.
				attacker.rotate_y(deg_to_rad(attacker.melee_fx("yaw", "melee_yaw", 0.0)))
				attacker.play_melee()
			# Verdediger draait zich naar de aanvaller: je vangt de stoot recht
			# van voren en valt straks van de aanvaller af.
			var melee_def: PawnView = _pawn_views.get(action.defender_id)
			if melee_def != null:
				melee_def.face_dir(result.attacker_from_pos - result.defender_pos)
			# melee-raakmoment: de klap landt pas op het stoot-frame van de
			# clip; alles hieronder (schade, geluid, opruk, terugslag) volgt.
			var hit_del: float = (attacker.melee_fx("hit_delay", "melee_hit_delay", 0.55)
					if attacker != null else PawnView.fx("melee_hit_delay", 0.55))
			if result.get("forced_move", false):
				# Opruk-choreografie (Max, 30 juli: "maak dat wachten altijd
				# hetzelfde, dan gaat die dood-animatie maar langer door, moet
				# snel naar die plek"). VASTE wachttijd: het stoot-frame plus de
				# opruk-vertraging. Hij wacht dus NIET meer op de lengte van de
				# dood-clip -- die duurt per variant 1,8 tot 3,8 seconden en
				# maakte elke kill anders lang. Het slachtoffer ligt inmiddels op
				# de grond of is al ragdoll, dus hij loopt niet door iemand heen.
				var move_del: float = hit_del
				if attacker != null:
					move_del += attacker.melee_fx("advance_delay", "melee_advance_delay", 0.35)
				# Visueel vastzetten op zijn eigen vak tot de opruk begint.
				_advance_holds[int(action.attacker_id)] = result.attacker_from_pos
				if attacker != null:
					attacker.position = tile_position(
						result.attacker_from_pos.x, result.attacker_from_pos.y) \
						+ Vector3(0.0, PAWN_Y, 0.0)
				get_tree().create_timer(move_del).timeout.connect(
					_begin_advance.bind(action.attacker_id, result.attacker_from_pos, result.defender_pos))
			# Zwaai en klap per wapen (17 september): de bajonet van deze
			# aanvaller, met zijn factie erbij als die een eigen opname heeft.
			_melee_geluid(action.attacker_id, attacker, result.get("eliminated", false),
				maxf(hit_del - 0.12, 0.0))
			_impact_laag(action.defender_id, int(result.get("damage", 0)),
				result.get("eliminated", false), maxf(hit_del - 0.12, 0.0), true)
			_hit_feedback(action.defender_id, result.defender_pos, result.damage, hit_del,
				result.attacker_from_pos, result.get("eliminated", false), 0.7)
			if result.get("eliminated", false):
				_death_sound(action.defender_id, hit_del)
			if result.get("retaliation", false):
				# Terugslag: de aanvaller krijgt even later zelf schade te zien.
				var ret_del: float = hit_del + (melee_def.melee_fx("retaliation_delay", "melee_retaliation_delay", 0.35)
						if melee_def != null else 0.35)
				_hit_feedback(action.attacker_id, result.attacker_from_pos, result.get("retaliation_damage", 1), ret_del,
					result.defender_pos, result.get("attacker_eliminated", false), 0.5)
				_retaliation_sound(action.defender_id, ret_del)
				_impact_laag(action.attacker_id, int(result.get("retaliation_damage", 1)),
					result.get("attacker_eliminated", false), ret_del, true)
				if result.get("attacker_eliminated", false):
					_death_sound(action.attacker_id, ret_del + 0.05)
		"cannon_act":
			# BUG-FIX (28 juli, Max: "kanon schiet zonder geluid/animatie"):
			# het v4.2-actietype viel dwars door deze match — regels verwerkten
			# de kill maar kogel/geluid/ragdoll werden nooit aangeroepen.
			# Vertaal naar het 4.1-equivalent; het result heeft dezelfde velden.
			if String(action.get("sub", "")) == "shoot":
				_on_action_performed({"type": "shot", "shooter_id": action.pawn_id,
					"target_id": action.target_id}, result)
			elif String(action.get("sub", "")) == "roll":
				_on_action_performed({"type": "move", "pawn_id": action.pawn_id,
					"from": action.from, "target": action.target}, result)
		"shot":
			var shooter: PawnView = _pawn_views.get(action.shooter_id)
			if shooter != null:
				shooter.face_dir(result.defender_pos - result.attacker_from_pos)
				shooter.play_attack()
			# Projectiel + muzzle flash + rook; de treffer-feedback wacht op de inslag.
			var shooter_pawn: Pawn = session.state.pawns.get(action.shooter_id)
			var shooter_type: int = shooter_pawn.unit_type if shooter_pawn != null else Constants.UnitType.INFANTRY
			var travel: float = _fire_projectile(result.attacker_from_pos, result.defender_pos, shooter_type, action.shooter_id)
			# Geluid: afvuren nu, inslag bij aankomst van het projectiel.
			if shooter_type == Constants.UnitType.ARTILLERY:
				Audio.play("cannon_fuse")  # lont-sis, samen met de knal
				Audio.play("cannon_fire")
				Audio.play("cannon_air", 0.04)
				Audio.play("cannon_hit", travel)
			else:
				Audio.play("musket_fire")
				Audio.play("musket_echo", 0.18)
				Audio.play("musket_hit", travel)
			_impact_laag(action.target_id, int(result.get("damage", 0)),
				result.get("eliminated", false), travel)
			var shot_strength := 1.4 if shooter_type == Constants.UnitType.ARTILLERY else 0.75
			_hit_feedback(action.target_id, result.defender_pos, result.damage, travel + 0.03,
				result.attacker_from_pos, result.get("eliminated", false), shot_strength, "shot")
			if result.get("eliminated", false):
				# Kanon: de kreet begint vóór de inslag (kogel is nog onderweg).
				if shooter_type == Constants.UnitType.ARTILLERY:
					_death_sound(action.target_id, maxf(0.0, travel - 0.10), true)
				else:
					_death_sound(action.target_id, travel + 0.05)
		"charge":
			Audio.play("charge_yell")  # strijdkreet bij het aanrijden
			var end_pos: Vector2i = result.defender_pos if result.get("forced_move", false) else result.move_target
			# Choreografie in fasen (26 aug, Max: "jump en dan melee, dat is
			# voor de charge"): eerst aanrijden op de rush-clip, dan de
			# sprong-stoot ("charge"-clip), en de klap op het stoot-frame --
			# niet meer de vaste 0.4s dwars door het rijden. Sinds 16
			# september (Max: "start de jump attack animatie 2 blokjes eerder
			# afstand, dan komt ie mooi uit, en dan pas de bloed walk en alles
			# afspelen op bijna het einde van die jump attack") begint de
			# sprong al `charge_aanloop_vakken` (2) voor de aankomst, zodat
			# hij op het doelvak neerkomt, en valt de klap
			# `charge_raak_voor_einde` (0,5 s) voor het einde van de clip.
			# Zonder sprong-clip (alleen de muis heeft er een) blijft het de
			# melee-stoot bij aankomst met charge_hit_delay.
			var heeft_doel: bool = action.get("defender_id", -1) != -1
			var cav: PawnView = _pawn_views.get(action.pawn_id)
			var rij_dist := 0
			var rijdt: bool = result.get("moved", false) or result.get("forced_move", false)
			if rijdt:
				rij_dist = absi(end_pos.x - result.charge_from.x) + absi(end_pos.y - result.charge_from.y)
			# Dezelfde tijdlijn als de knop "charge" in de Model-tuner. De rit
			# duurt tl.rij_dur: sinds 16 september eindigt hij op de landing
			# van de sprong (de sprong zelf loopt op zijn plaats, root motion
			# weggecompenseerd), dus de pion springt op het doelvak.
			var tijdlijn: Dictionary = cav.charge_tijdlijn(rij_dist) if cav != null \
				else {"rij_dur": -1.0, "sprong_start": 0.0, "klap_del": 0.35}
			if rijdt:
				# Met een doel zet de rit-tween aan het eind geen idle: de
				# sprong loopt dan nog en keert zelf naar idle terug.
				_animate_move(action.pawn_id, result.charge_from, end_pos, true, not heeft_doel, float(tijdlijn.get("rij_dur", -1.0)))
			var sprong_start: float = tijdlijn.sprong_start
			_check_haven_score(action.pawn_id, end_pos)
			if cav != null and heeft_doel:
				var richting: Vector2i = result.defender_pos - end_pos
				var start_sprong := func() -> void:
					if is_instance_valid(cav):
						if richting != Vector2i.ZERO:
							cav.face_dir(richting)
						cav.play_charge()
				if sprong_start <= 0.0:
					start_sprong.call()
				else:
					get_tree().create_timer(sprong_start).timeout.connect(start_sprong)
			if heeft_doel:
				var klap_del: float = tijdlijn.klap_del
				# sabel, lans of bijl van deze ruiter (17 september)
				_melee_geluid(action.pawn_id, cav, result.get("eliminated", false), klap_del)
				_impact_laag(action.defender_id, int(result.get("damage", 0)),
					result.get("eliminated", false), klap_del, true)
				_hit_feedback(action.defender_id, result.defender_pos, result.damage, klap_del,
					result.charge_from, result.get("eliminated", false), 0.85, "charge")  # sabel: doormidden (16 september)
				if result.get("eliminated", false):
					_death_sound(action.defender_id, klap_del + 0.1)
				if result.get("retaliation", false):
					var ret_del: float = klap_del + 0.35
					_hit_feedback(action.pawn_id, result.move_target, result.get("retaliation_damage", 1), ret_del,
						result.defender_pos, result.get("attacker_eliminated", false), 0.5)
					_retaliation_sound(action.defender_id, ret_del)
					_impact_laag(action.pawn_id, int(result.get("retaliation_damage", 1)),
						result.get("attacker_eliminated", false), ret_del, true)
					if result.get("attacker_eliminated", false):
						_death_sound(action.pawn_id, ret_del + 0.05)
		"wolf_step":
			_animate_move(action.pawn_id, action.from, action.target)
			_check_haven_score(action.pawn_id, action.target)
	_refresh_all()


# --- Schiet-VFX (prototype, low-poly): projectiel + muzzle flash + rook --------

## Vuur een projectiel af van vak naar vak. Kanon: snelle rechte kogel-streep,
## keihard rechtdoor; infanterie: klein fel tracer-bolletje, strak en snel.
## Retour: de reistijd, zodat de treffer-feedback op de inslag kan wachten.
func _fire_projectile(from_coord: Vector2i, to_coord: Vector2i, unit_type: int, shooter_id: int = -1) -> float:
	var start: Vector3 = tile_position(from_coord.x, from_coord.y)
	var end: Vector3 = tile_position(to_coord.x, to_coord.y)
	var flat_dir: Vector3 = (end - start).normalized()
	var is_cannon: bool = unit_type == Constants.UnitType.ARTILLERY
	var muzzle: Vector3 = start + flat_dir * 0.35 + Vector3(0.0, 0.55 if is_cannon else 0.85, 0.0)
	# Per model ingemeten vuurmond (Model-tuner) zodra de schutter een view
	# heeft; de schutter is al naar het doel gedraaid (face_dir hierboven).
	var spv: PawnView = _pawn_views.get(shooter_id)
	if spv != null and spv._tune_key != "":
		muzzle = _board.to_local(spv.muzzle_world())
	var target: Vector3 = end + Vector3(0.0, 0.55, 0.0)
	# Kanon vliegt razendsnel (keihard), infanterie iets rustiger.
	var dist_len: float = (end - start).length()
	var dur: float = clampf(0.016 * dist_len, 0.05, 0.22) if is_cannon \
		else clampf(0.06 * dist_len, 0.1, 0.4)

	var proj := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	var radius: float = 0.13 if is_cannon else 0.055
	mesh.radius = radius
	mesh.height = radius * 2.0
	proj.mesh = mesh
	var mat := StandardMaterial3D.new()
	if is_cannon:
		mat.albedo_color = Color(0.16, 0.16, 0.18)
		mat.metallic = 0.5
	else:
		mat.albedo_color = Color(1.0, 0.9, 0.5)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.85, 0.4)
		mat.emission_energy_multiplier = 1.6
	proj.material_override = mat
	proj.position = muzzle
	_board.add_child(proj)

	# Kanonskogel: rek de bol uit langs de vliegrichting → een strakke streep,
	# keihard rechtdoor (geen boog). Infanterie blijft een rond tracer-bolletje.
	if is_cannon and muzzle.distance_to(target) > 0.01:
		proj.look_at_from_position(muzzle, target, Vector3.UP)
		proj.scale = Vector3(0.6, 0.6, 4.0)  # uitgerekt langs de kijkas (-Z)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: proj.position = muzzle.lerp(target, t), 0.0, 1.0, dur)
	tween.tween_callback(proj.queue_free)

	_muzzle_flash(muzzle, is_cannon)
	# vuur-schok: korte terugslag-shake bij het afvuren (kanon harder).
	_shake((0.55 if is_cannon else 0.3) * PawnView.fx("fire_shake", 1.0))
	# de windvlaag van het schot op de capes in de buurt (alleen binnen een straal)
	_cape_vlaag(_board.to_global(muzzle), is_cannon)
	# Rook drift met de schot-richting mee, van de loop af.
	var shot_dir := Vector3.ZERO
	if muzzle.distance_to(target) > 0.01:
		shot_dir = (target - muzzle).normalized()
	_spawn_smoke(muzzle, 4 if is_cannon else 2, 0.16 if is_cannon else 0.09, shot_dir)
	# Inslag-rook zodra het projectiel aankomt (zelfde richting = momentum).
	var impact_count: int = 3 if is_cannon else 2
	var impact_size: float = 0.14 if is_cannon else 0.08
	get_tree().create_timer(dur).timeout.connect(func() -> void: _spawn_smoke(target, impact_count, impact_size, shot_dir, PawnView.fx("impact_smoke_life", 0.6)))
	return dur


## Het diorama om het bord (8 september): graslandschap, wolkenschaduwen,
## vignet en klik-props, gebouwd door Omgeving (scripts/game/omgeving.gd)
## onder de kijk-pivot, zodat beide stoelen hun eigen kamp vooraan zien.
## Uit te zetten met de knop "omgeving" in het sfeer-paneel.
func _setup_omgeving() -> void:
	# De orthografische camera tekent niets achter zijn eigen positie (het
	# near-vlak), en die staat maar 5 hoog en net voor het bord: het gras en
	# het kamp vooraan vielen daardoor in een zwarte band weg. Langs de
	# kijkrichting naar achteren schuiven verandert een orthografisch beeld
	# niet (geen perspectief), maar zet het near-vlak ruim achter alles.
	_camera.position += _camera.transform.basis.z * 40.0
	_cam_base = _camera.position
	_omgeving = Omgeving.new()
	_kijk_pivot.add_child(_omgeving)
	_omgeving.bouw(_camera, $UI)


## Het 3D-bordmodel staat als node "BoardModel" in Board.tscn - plaats en
## schaal het gewoon in de Godot-editor. Staat het er, dan verbergen we hier
## de checker-CSG-tegels (het model is de vloer) en gaan de haven-tegels een
## fractie omhoog tegen z-fighting. Geen model = het klassieke tegel-bord.
func _setup_board_model() -> void:
	var bm := _board.get_node_or_null("BoardModel")
	if bm == null:
		return
	# Het bord werpt zelf geen schaduw: alleen de pionnen mogen schaduwen
	# gooien (de dioramarand gaf anders lange vegen over het speelveld).
	for mi in bm.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tiles_node := _board.get_node_or_null("Tiles")
	if tiles_node == null:
		return
	for tile in tiles_node.get_children():
		if not (tile is CSGBox3D):
			continue
		(tile as CSGBox3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat: StandardMaterial3D = (tile as CSGBox3D).material_override as StandardMaterial3D
		if mat == null:
			continue
		var c := mat.albedo_color
		if absf(c.r - c.g) + absf(c.g - c.b) > 0.3:
			# Haven: gloeiende vierkante rand om de tegel (een dichte plaat
			# verdween onder het golvende diorama-oppervlak; een rand leest
			# bovendien ook met een pion erop).
			_spawn_haven_marker((tile as CSGBox3D).position, c.r > c.b)
		(tile as CSGBox3D).visible = false
	_build_grid_lines()


## Dun donkergrijs raster op de tegelgrenzen, net boven het bordoppervlak —
## zo zie je de vakken op het modder-bord zonder het beeld te verstoren.
## Zichtbaarheid tunebaar via de knop "raster" (0 = uit).
## Gloeiende vierkante rand om een haven-tegel: doorzichtig donkerrood of
## donkerblauw, zwevend boven het golvende bordoppervlak. Zichtbaarheid
## tunebaar via het sfeer-paneel (haven-zichtbaarheid, 0 = uit).
func _spawn_haven_marker(tile_pos: Vector3, is_red: bool) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var a: float = PawnView.fx("haven_alpha", 0.45)
	mat.albedo_color = Color(0.55, 0.07, 0.06, a) if is_red else Color(0.08, 0.16, 0.6, a)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.15, 0.12) if is_red else Color(0.15, 0.35, 1.0)
	mat.emission_energy_multiplier = 0.5
	_haven_mats.append(mat)
	var root := Node3D.new()
	root.position = Vector3(tile_pos.x, 0.12, tile_pos.z)
	_board.add_child(root)
	for i in 4:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.88, 0.012, 0.055) if i < 2 else Vector3(0.055, 0.012, 0.88)
		bar.mesh = bm
		bar.material_override = mat
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var off := 0.4125
		if i < 2:
			bar.position = Vector3(0.0, 0.0, -off if i == 0 else off)
		else:
			bar.position = Vector3(-off if i == 2 else off, 0.0, 0.0)
		root.add_child(bar)


func _build_grid_lines() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.12, 0.12, 0.13, PawnView.fx("grid_alpha", 0.3))
	_grid_mat = mat  # live bij te stellen via het sfeer-paneel (alpha 0 = uit)
	var root := Node3D.new()
	root.name = "GridLines"
	_board.add_child(root)
	var w := 0.02  # lijndikte
	for k in range(12):  # 11 tegels → 12 grenslijnen per as
		var b: float = float(k) - 0.5
		# Lijn langs X (op z-grens b).
		var lx := MeshInstance3D.new()
		var mx := BoxMesh.new()
		mx.size = Vector3(11.0, 0.004, w)
		lx.mesh = mx
		lx.material_override = mat
		lx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lx.position = Vector3(5.0, 0.052, b)
		root.add_child(lx)
		# Lijn langs Z (op x-grens b).
		var lz := MeshInstance3D.new()
		var mz := BoxMesh.new()
		mz.size = Vector3(w, 0.004, 11.0)
		lz.mesh = mz
		lz.material_override = mat
		lz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lz.position = Vector3(b, 0.052, 5.0)
		root.add_child(lz)


## Grimmige slagveld-belichting: semi-donker en modderig-warm, maar alles
## blijft leesbaar. Laag warm zonlicht, vuilbruin strooilicht, filmische
## tonemap, ietsje ontkleurd en een vleugje grondmist. Tunebaar via de
## Wereld-tab in de Model-tuner (wereld-licht / wereld-ambient).
func _setup_battlefield_lighting() -> void:
	_sun_light = _board.get_node_or_null("DirectionalLight3D")
	if _sun_light != null:
		_sun_light.light_color = Color(1.0, 0.92, 0.8)
		# Geen zon-schaduwen: de lage zonnestand rekt schaduwen metersver uit.
		# De schaduw komt van de spot boven het bord (kort, direct onder de pion).
		_sun_light.shadow_enabled = false
	# Spotlight boven het bordcentrum: fel in het midden, dooft naar de randen
	# uit (radiale falloff = diorama-onder-een-lamp).
	_spot_light = SpotLight3D.new()
	_spot_light.light_color = Color(1.0, 0.9, 0.74)
	_spot_light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)  # kegel recht omlaag
	_spot_light.shadow_enabled = true
	_spot_light.shadow_blur = 1.2  # zachte miniatuur-schaduwrand
	_board.add_child(_spot_light)
	# Gritty rim/fill: koel tegenlicht vanuit lage schuine hoek dat de
	# silhouetten van de pionnen aanzet (warm spot + koele rand = filmisch).
	_rim_light = DirectionalLight3D.new()
	_rim_light.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
	_rim_light.light_color = Color(0.7, 0.73, 0.8)
	_rim_light.light_specular = 1.4
	_board.add_child(_rim_light)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.58, 0.55, 0.5)
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.adjustment_enabled = true
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.07, 0.065, 0.06)
	var we := WorldEnvironment.new()
	we.environment = _env
	_world.add_child(we)
	_apply_ambiance()
	_refresh_dust()


## Alle sfeer-knoppen (belichting, mist, raster, ring-gloed, stof) in een keer
## toepassen op de live scene. Draait bij het opstarten en bij elke
## slider-beweging in het sfeer-paneel (toets L).
func _apply_ambiance() -> void:
	if _sun_light != null:
		_sun_light.light_energy = 0.65 * PawnView.fx("world_light", 1.0)
	if _spot_light != null:
		_spot_light.light_energy = 3.4 * PawnView.fx("spot_light", 1.0)
		_spot_light.spot_range = 14.0 * PawnView.fx("spot_range", 1.0)
		_spot_light.spot_attenuation = PawnView.fx("spot_atten", 0.9)
		_spot_light.spot_angle = PawnView.fx("spot_angle", 60.0)
		_spot_light.spot_angle_attenuation = PawnView.fx("spot_angle_soft", 1.2)
		_spot_light.position = Vector3(PawnView.fx("spot_x", 5.0),
				PawnView.fx("spot_height", 7.5), PawnView.fx("spot_z", 5.0))
		var sh: float = PawnView.fx("shadow", 0.75)
		_spot_light.shadow_enabled = sh > 0.0
		_spot_light.shadow_opacity = clampf(sh, 0.0, 1.0)
		_spot_light.shadow_bias = PawnView.fx("shadow_bias", 0.03)
		_spot_light.shadow_normal_bias = 1.0
	if _rim_light != null:
		_rim_light.light_energy = 0.45 * PawnView.fx("rim_light", 1.0)
	if _env != null:
		_env.ambient_light_energy = 0.32 * PawnView.fx("world_ambient", 1.0)
		var bg: float = 0.015 * PawnView.fx("bg_bright", 1.0)
		_env.background_color = Color(bg, bg, bg * 1.25)
		_env.adjustment_saturation = PawnView.fx("saturation", 0.88)
		_env.adjustment_contrast = PawnView.fx("contrast", 1.12)
		_env.fog_density = PawnView.fx("fog_density", 0.002)
	if _grid_mat != null:
		_grid_mat.albedo_color.a = PawnView.fx("grid_alpha", 0.3)
	for hm in _haven_mats:
		(hm as StandardMaterial3D).albedo_color.a = PawnView.fx("haven_alpha", 0.45)
	for fp in _footprints:
		if is_instance_valid(fp):
			var fpm := (fp as MeshInstance3D).material_override as StandardMaterial3D
			if fpm != null and fpm.albedo_color.a > 0.001:  # nog niet verschenen sporen overslaan
				fpm.albedo_color.a = PawnView.fx("footprint_dark", 0.32)
	for pv in _pawn_views.values():
		if is_instance_valid(pv):
			(pv as PawnView).set_ring_glow(PawnView.fx("ring_glow", 1.0))
	for e in _aura_gloed:
		if is_instance_valid(e.node):
			(e.mat as StandardMaterial3D).albedo_color.a = float(e.basis) * PawnView.fx("aura_gloed", 1.0)
	if _omgeving != null:
		_omgeving.pas_toe()


# --- Sfeer-paneel (toets L): live licht-sliders op het echte bord ------------

const AMBIANCE_DEFS: Array = [
	{"key": "world_light", "label": "zon", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	{"key": "world_ambient", "label": "omgevingslicht", "min": 0.0, "max": 4.0, "step": 0.01, "def": 1.0},
	{"key": "spot_light", "label": "spot-licht", "min": 0.0, "max": 4.0, "step": 0.01, "def": 1.0},
	{"key": "spot_range", "label": "spot-bereik", "min": 0.3, "max": 3.0, "step": 0.01, "def": 1.0},
	{"key": "spot_atten", "label": "spot-falloff", "min": 0.2, "max": 4.0, "step": 0.01, "def": 0.9},
	{"key": "spot_height", "label": "spot-hoogte", "min": 2.0, "max": 20.0, "step": 0.1, "def": 7.5},
	{"key": "spot_x", "label": "spot-plaats X", "min": -2.0, "max": 12.0, "step": 0.1, "def": 5.0},
	{"key": "spot_z", "label": "spot-plaats Z", "min": -2.0, "max": 12.0, "step": 0.1, "def": 5.0},
	{"key": "spot_angle", "label": "spot-hoek", "min": 10.0, "max": 90.0, "step": 0.5, "def": 60.0},
	{"key": "spot_angle_soft", "label": "spot-hoek-zachtheid", "min": 0.2, "max": 4.0, "step": 0.01, "def": 1.2},
	{"key": "rim_light", "label": "rand-licht", "min": 0.0, "max": 4.0, "step": 0.01, "def": 1.0},
	{"key": "shadow", "label": "schaduw-sterkte", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.75},
	{"key": "shadow_bias", "label": "schaduw-offset", "min": 0.0, "max": 0.3, "step": 0.005, "def": 0.03},
	{"key": "fog_density", "label": "mist", "min": 0.0, "max": 0.02, "step": 0.0005, "def": 0.002},
	{"key": "bg_bright", "label": "achtergrond", "min": 0.0, "max": 20.0, "step": 0.1, "def": 1.0},
	{"key": "saturation", "label": "verzadiging", "min": 0.3, "max": 1.5, "step": 0.01, "def": 0.88},
	{"key": "contrast", "label": "contrast", "min": 0.7, "max": 1.6, "step": 0.01, "def": 1.12},
	{"key": "grid_alpha", "label": "raster", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.3},
	{"key": "haven_alpha", "label": "haven-zichtbaarheid", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.45},
	{"key": "ring_glow", "label": "ring-gloed", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	{"key": "aura_gloed", "label": "aura-gloed (trom en vaandel)", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	{"key": "dust", "label": "stofdeeltjes", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	{"key": "footprints", "label": "voetsporen", "min": 0.0, "max": 1.0, "step": 1.0, "def": 1.0},
	{"key": "footprint_dark", "label": "voetspoor-donkerte", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.32},
	{"key": "wheel_width", "label": "wielspoor-breedte", "min": 0.005, "max": 0.12, "step": 0.001, "def": 0.024},
	{"key": "wheel_base", "label": "wielbasis", "min": 0.05, "max": 0.6, "step": 0.005, "def": 0.17},
	{"key": "omgeving", "label": "omgeving (landschap om het bord)", "min": 0.0, "max": 1.0, "step": 1.0, "def": 1.0},
	{"key": "omgeving_licht", "label": "omgeving-helderheid", "min": 0.2, "max": 3.0, "step": 0.01, "def": 1.0},
	{"key": "wolken", "label": "wolkenschaduw", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	{"key": "vignet", "label": "vignet (donkere randen)", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.5},
	{"key": "props", "label": "props (kamp, klikbaar)", "min": 0.0, "max": 1.0, "step": 1.0, "def": 1.0},
	{"key": "diorama", "label": "diorama (0 = loten per potje, 1-12 vast)", "min": 0.0, "max": 12.0, "step": 1.0, "def": 0.0},
	{"key": "tik_pauze", "label": "tik-combo: pauze tot herstart (s)", "min": 0.15, "max": 1.5, "step": 0.05, "def": 0.6},
	{"key": "tik_toon", "label": "tik-combo: toon omhoog per klik", "min": 0.0, "max": 0.15, "step": 0.005, "def": 0.07},
	{"key": "cape_blauw", "label": "cape blauw team (0/1)", "min": 0.0, "max": 1.0, "step": 1.0, "def": 1.0},
	{"key": "cape_rood", "label": "cape rood team (0/1)", "min": 0.0, "max": 1.0, "step": 1.0, "def": 0.0},
	{"key": "cape_lengte", "label": "cape-lengte (x pionhoogte)", "min": 0.25, "max": 0.9, "step": 0.01, "def": 0.5},
	{"key": "cape_breedte", "label": "cape-breedte (x pionhoogte)", "min": 0.2, "max": 0.7, "step": 0.01, "def": 0.4},
	{"key": "cape_wapper", "label": "cape-wapper", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	{"key": "cape_drape", "label": "cape-drape (plooien, om de schouders)", "min": 0.0, "max": 2.5, "step": 0.01, "def": 1.0},
	{"key": "cape_slinger", "label": "cape-slinger (sleept bij bewegen)", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	{"key": "cape_sim", "label": "cape-cloth (1 = Jolt-simulatie, 0 = vlakke shader-lap)", "min": 0.0, "max": 1.0, "step": 1.0, "def": 1.0},
	{"key": "cape_sim_precisie", "label": "cape-cloth: solver-iteraties", "min": 1.0, "max": 8.0, "step": 1.0, "def": 5.0},
	{"key": "cape_voering_goud", "label": "cape: binnenkant goudzijde (1) of het plaatje (0)", "min": 0.0, "max": 1.0, "step": 1.0, "def": 1.0},
	{"key": "cape_wind", "label": "cape-wind", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	{"key": "cape_vlaag", "label": "cape-vlaag van een schot (0 = uit)", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	{"key": "idle_afwijkers", "label": "idle: hoeveel pionnen tegelijk een andere idle doen (0 = niemand)", "min": 0.0, "max": 6.0, "step": 1.0, "def": 2.0},
	{"key": "cape_vlaag_straal", "label": "cape-vlaag: straal musket (vakken)", "min": 0.0, "max": 6.0, "step": 0.1, "def": 2.0},
	{"key": "cape_vlaag_straal_kanon", "label": "cape-vlaag: straal kanon (vakken)", "min": 0.0, "max": 8.0, "step": 0.1, "def": 3.5},
]


func _toggle_ambiance_panel() -> void:
	if _ambiance_panel == null:
		_build_ambiance_panel()
		return
	_ambiance_panel.visible = not _ambiance_panel.visible


func _build_ambiance_panel() -> void:
	_ambiance_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.93)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	_ambiance_panel.add_theme_stylebox_override("panel", sb)
	_ambiance_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_ambiance_panel.offset_left = -520.0
	_ambiance_panel.offset_right = -12.0
	_ambiance_panel.offset_top = 140.0
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_ambiance_panel.add_child(vbox)
	var title := Label.new()
	title.text = "Sfeer-instellingen (L om te sluiten)"
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480.0, 640.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 2)
	scroll.add_child(rows)
	for d in AMBIANCE_DEFS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lbl := Label.new()
		lbl.text = String(d["label"])
		lbl.custom_minimum_size = Vector2(200.0, 0.0)
		lbl.add_theme_font_size_override("font_size", 20)
		row.add_child(lbl)
		var slider := HSlider.new()
		slider.min_value = d["min"]
		slider.max_value = d["max"]
		slider.step = d["step"]
		slider.value = PawnView.fx(String(d["key"]), float(d["def"]))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(slider)
		var val := Label.new()
		val.text = String.num(slider.value, 3)
		val.custom_minimum_size = Vector2(76.0, 0.0)
		val.add_theme_font_size_override("font_size", 20)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		slider.value_changed.connect(_on_ambiance_slider.bind(String(d["key"]), val))
		rows.add_child(row)
	var save := Button.new()
	save.text = "OPSLAAN"
	save.pressed.connect(_save_ambiance)
	vbox.add_child(save)
	var hud_layer := get_node_or_null("UI")
	if hud_layer != null:
		hud_layer.add_child(_ambiance_panel)
	else:
		add_child(_ambiance_panel)


func _on_ambiance_slider(value: float, key: String, val_label: Label) -> void:
	PawnView.set_fx(key, value)
	val_label.text = String.num(value, 3)
	_apply_ambiance()
	if key == "dust":
		_refresh_dust()
	if key.begins_with("cape_"):
		for pv in _pawn_views.values():
			(pv as PawnView).herhang_cape()
		if _omgeving != null:
			_omgeving.herhang_capes()


## Schrijft alle knoppen (sfeer + effecten) terug naar effects_tuning.json:
## dezelfde file die de Model-tuner gebruikt.
func _save_ambiance() -> void:
	var f := FileAccess.open(PawnView.EFFECTS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(PawnView.fx_all(), "\t") + "\n")
		f.close()
		_update_hud("Sfeer opgeslagen")


## Artillerie-spoor: twee parallelle onderbroken wielstrepen links en
## rechts van de aslijn (optioneel met wiel.png als texture).
func _spawn_wheel_tracks(flat_a: Vector3, flat_b: Vector3, dirn: Vector3, side: Vector3, dur: float) -> void:
	var dist := flat_a.distance_to(flat_b)
	var count := int(dist / 0.16)
	var tex := _footstep_texture(["wiel"])
	for i in range(count):
		var t := float(i + 1) / float(count + 1)
		for lane in [-1.0, 1.0]:
			# wielbasis: hart-op-hart afstand tussen de twee banen.
			var p: Vector3 = flat_a.lerp(flat_b, t) + side * (PawnView.fx("wheel_base", 0.17) * 0.5 * float(lane))
			var fp := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(PawnView.fx("wheel_width", 0.024), 0.15)
			fp.mesh = pm
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			if tex != null:
				mat.albedo_texture = tex
				mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
			else:
				mat.albedo_color = Color(0.05, 0.045, 0.04, 0.0)
			fp.material_override = mat
			fp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fp.position = Vector3(p.x, 0.0543 + 0.0002 * float(i % 3), p.z)
			fp.rotation.y = atan2(-dirn.x, -dirn.z)
			_board.add_child(fp)
			_footprints.append(fp)
			var tw := fp.create_tween()
			tw.tween_interval(maxf(dur * t - 0.02, 0.0))
			tw.tween_property(mat, "albedo_color:a", PawnView.fx("footprint_dark", 0.32), 0.08)


# --- Stofdeeltjes: langzaam dwarrelende motes in het spotlicht ---------------

func _refresh_dust() -> void:
	var target := int(round(16.0 * PawnView.fx("dust", 1.0)))
	while _dust_motes.size() > target:
		var m: Node = _dust_motes.pop_back()
		if is_instance_valid(m):
			m.queue_free()
	while _dust_motes.size() < target:
		_dust_motes.append(_spawn_dust_mote())


func _spawn_dust_mote() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	var r := randf_range(0.01, 0.024)
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.94, 0.8, randf_range(0.08, 0.22))
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(randf_range(0.0, 10.0), randf_range(0.2, 2.4), randf_range(0.0, 10.0))
	_board.add_child(m)
	_drift_dust_mote(m)
	return m


func _drift_dust_mote(m: MeshInstance3D) -> void:
	if not is_instance_valid(m) or m.is_queued_for_deletion():
		return
	var target := m.position + Vector3(randf_range(-0.7, 0.7), randf_range(-0.3, 0.3), randf_range(-0.7, 0.7))
	target.x = clampf(target.x, -0.5, 10.5)
	target.y = clampf(target.y, 0.15, 2.6)
	target.z = clampf(target.z, -0.5, 10.5)
	var tw := m.create_tween()
	tw.tween_property(m, "position", target, randf_range(4.0, 9.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_drift_dust_mote.bind(m))


# --- Voetsporen: vervagende stapjes in de modder langs het looppad -----------

## Slagveld vegen: alle voetsporen weg (nieuwe cyclus of nieuw potje).
func _clear_footprints() -> void:
	for fp in _footprints:
		if is_instance_valid(fp):
			(fp as Node).queue_free()
	_footprints.clear()


## Spoor-texture uit assets/textures/footstep/: probeert de kandidaten op
## volgorde (specifiek -> generiek). Conventie, klaar voor dierenpoten:
##   infanterie:  <factie>_left.png -> left.png            (bv. muis_left.png)
##   cavalerie:   <factie>_hoef_left.png -> hoef_left.png  (idem rechts)
##   artillerie:  wiel.png (optioneel; anders kale strepen)
## Niets gevonden = null: het spoor valt terug op een kaal donker vormpje.
func _footstep_texture(candidates: Array) -> Texture2D:
	for c in candidates:
		var path: String = "res://assets/textures/footstep/" + String(c) + ".png"
		if not _footstep_cache.has(path):
			_footstep_cache[path] = load(path) if ResourceLoader.exists(path) else null
		if _footstep_cache[path] != null:
			return _footstep_cache[path]
	return null


func _spawn_footprints(a: Vector3, b: Vector3, dur: float, mover: Pawn = null) -> void:
	if PawnView.fx("footprints", 1.0) <= 0.0:
		return
	var flat_a := Vector3(a.x, 0.0, a.z)
	var flat_b := Vector3(b.x, 0.0, b.z)
	var dist := flat_a.distance_to(flat_b)
	if dist < 0.05:
		return
	var dirn := (flat_b - flat_a).normalized()
	var side := dirn.cross(Vector3.UP).normalized()
	# Artillerie rolt: twee parallelle wielsporen i.p.v. voetstappen.
	if mover != null and mover.unit_type == Constants.UnitType.ARTILLERY:
		_spawn_wheel_tracks(flat_a, flat_b, dirn, side, dur)
		return
	var fac := ""
	if mover != null:
		fac = Constants.doctrine_name(session.state.doctrine_of(mover.owner_id)).to_lower()
	var is_cav: bool = mover != null and mover.unit_type == Constants.UnitType.CAVALRY
	var count := int(dist / 0.28)
	for i in range(count):
		var t := float(i + 1) / float(count + 1)
		var p := flat_a.lerp(flat_b, t) + side * (0.055 if i % 2 == 0 else -0.055)
		var fp := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		var lr: String = "left" if i % 2 == 0 else "right"
		var boot: Texture2D = null
		if is_cav:
			boot = _footstep_texture([fac + "_hoef_" + lr, "hoef_" + lr])
		else:
			boot = _footstep_texture([fac + "_" + lr, lr])
		if boot != null:
			# Verhouding van de texture zelf aanhouden (laars, poot, hoef...).
			var asp: float = float(boot.get_width()) / maxf(float(boot.get_height()), 1.0)
			pm.size = Vector2(0.135 * asp, 0.135)
		else:
			pm.size = Vector2(0.045, 0.07) if is_cav else Vector2(0.05, 0.1)
		fp.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if boot != null:
			mat.albedo_texture = boot  # eigen donkere kleur + alpha zit in de PNG
			mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
		else:
			mat.albedo_color = Color(0.05, 0.045, 0.04, 0.0)
		fp.material_override = mat
		fp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fp.position = Vector3(p.x, 0.0545 + 0.0002 * float(i % 3), p.z)
		# Tenen in de looprichting (PlaneMesh: beeld-bovenkant ligt op -Z).
		fp.rotation.y = atan2(-dirn.x, -dirn.z)
		_board.add_child(fp)
		_footprints.append(fp)
		# Geen vervaging: de sporen blijven staan tot alle kaarten van de
		# cyclus gespeeld zijn - het slagveld vertelt het verhaal van de slag.
		var tw := fp.create_tween()
		tw.tween_interval(maxf(dur * t - 0.02, 0.0))
		tw.tween_property(mat, "albedo_color:a", PawnView.fx("footprint_dark", 0.32), 0.08)


## Korte felle flits + lichtpuls aan de loop. Met een texture in
## assets/textures/fire/ een echte vlam-billboard; anders de bol-flits.
func _muzzle_flash(pos: Vector3, big: bool) -> void:
	var textured := PawnView.spawn_muzzle_fire(_board, pos, big)
	var holder := Node3D.new()
	holder.position = pos
	_board.add_child(holder)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.35)
	# vuur-licht: hoe fel de omgeving even oplicht bij het schot.
	light.light_energy = (2.6 if big else 1.6) * PawnView.fx("fire_light", 1.6)
	light.omni_range = 2.8
	holder.add_child(light)
	var tween := create_tween().set_parallel()
	if not textured:
		var flash := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var radius: float = 0.16 if big else 0.09
		mesh.radius = radius
		mesh.height = radius * 2.0
		flash.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.75, 0.25, 0.9)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.7, 0.2)
		mat.emission_energy_multiplier = 2.5
		flash.material_override = mat
		flash.scale = Vector3.ONE * 0.5
		holder.add_child(flash)
		tween.tween_property(flash, "scale", Vector3.ONE * (2.0 if big else 1.4), 0.12).set_ease(Tween.EASE_OUT)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.14).set_ease(Tween.EASE_IN)
	tween.tween_property(light, "light_energy", 0.0, 0.18)
	tween.chain().tween_callback(holder.queue_free)


## Zwartkruit-rook via de gedeelde spawner in PawnView: textures uit
## assets/textures/smoke/ (billboards die echt uitzetten), zonder textures
## grijze bol-wolkjes. Knoppen in de Model-tuner: rook-aantal/-maat/-groei/-duur.
func _spawn_smoke(pos: Vector3, count: int, size: float, dir: Vector3 = Vector3.ZERO,
		life_mult: float = 1.0, tex_wens: String = "") -> void:
	PawnView.spawn_powder_smoke(_board, pos, count, size, dir, life_mult, tex_wens)


## Treffer-feedback (de "Hit"-fase). Op het inslagmoment (na `delay`): witte flits,
## stagger/knockback, vonken, screen shake, hitstop en een opstijgend "-N"-label.
## Bij `killed` een lichte ragdoll i.p.v. de flits.
## `from_coord` bepaalt de knockback-richting (weg van de aanvaller).
func _hit_feedback(pawn_id: int, coord: Vector2i, damage: int, delay: float = 0.12,
		from_coord: Vector2i = Vector2i(-1, -1), killed: bool = false, strength: float = 0.7,
		kind: String = "melee") -> void:
	# Synchroon markeren zodat _refresh_all de stervende pion laat staan.
	if killed:
		_dying_views[pawn_id] = true
	if damage <= 0 and not killed:
		return
	var world_dir := _knockback_dir(from_coord, coord)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var s: float = strength + (0.4 if killed else 0.0)
	_spawn_sparks(tile_position(coord.x, coord.y) + Vector3(0.0, 0.6, 0.0), s)
	_shake(s)
	_hitstop(0.03 + 0.03 * clampf(s, 0.0, 1.6))
	if killed:
		_kill_view(pawn_id, world_dir, s, kind)
	else:
		var pv: PawnView = _pawn_views.get(pawn_id)
		# Levende stukken (infanterie/cavalerie) bloeden; een kanon niet.
		var hit_pawn: Pawn = session.state.pawns.get(pawn_id)
		var bloedt: bool = hit_pawn != null and hit_pawn.unit_type != Constants.UnitType.ARTILLERY
		if pv != null and pv.visible:
			pv.flash_hit()
			pv.stagger(world_dir)
			pv.play_hit()  # incasseer-animatie (hit1/hit2) bij overleven
			if bloedt:
				pv.play_wound(world_dir)  # spetters + druppels: gewond maar staand
		if bloedt:
			Audio.play("blood_splash")
	if damage > 0:
		_spawn_damage_float(coord, "-%d" % damage)


## Wereld-richting van aanvaller → doelwit (voor knockback/stagger/topple).
func _knockback_dir(from_coord: Vector2i, to_coord: Vector2i) -> Vector3:
	if from_coord.x < 0 or from_coord == to_coord:
		return Vector3.ZERO
	var a := tile_position(from_coord.x, from_coord.y)
	var b := tile_position(to_coord.x, to_coord.y)
	return (b - a)


## Start de ragdoll van een geëlimineerde pion en haal 'm uit de view-map,
## zodat _refresh_all/_update_health_bars hem verder met rust laten.
func _kill_view(pawn_id: int, world_dir: Vector3, strength: float = 0.7, kind: String = "melee") -> void:
	_dying_views.erase(pawn_id)
	var pv: PawnView = _pawn_views.get(pawn_id)
	if pv == null:
		return
	_pawn_views.erase(pawn_id)
	if pv.visible:
		pv.play_death(world_dir, strength, kind)  # blijft als debris liggen
	else:
		pv.queue_free()


## Korte vonken-/stofexplosie op het inslagpunt.
func _spawn_sparks(pos: Vector3, strength: float) -> void:
	if not _combat_feel:
		return
	var n: int = int(clampf(6.0 * strength, 3.0, 12.0))
	for i in n:
		var spark := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radial_segments = 6
		mesh.rings = 3
		var r := randf_range(0.02, 0.05)
		mesh.radius = r
		mesh.height = r * 2.0
		spark.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.4)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.3)
		mat.emission_energy_multiplier = 2.0
		spark.material_override = mat
		spark.position = pos
		_board.add_child(spark)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.3, 1.2), randf_range(-1, 1)).normalized()
		var dist := randf_range(0.3, 0.7) * maxf(strength, 0.4)
		var life := randf_range(0.25, 0.45)
		var tw := create_tween().set_parallel()
		tw.tween_property(spark, "position", pos + dir * dist, life).set_ease(Tween.EASE_OUT)
		tw.tween_property(mat, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(spark.queue_free)


## De windvlaag van een schot op de capes in de buurt (16 september, Max:
## "alle capes reageren nu op een schot, dat moet niet: alleen binnen een
## bepaalde straal rondom het schot, en bij kanon nog iets grotere straal").
## Straal in vakken: knoppen cape_vlaag_straal (musket, 2) en
## cape_vlaag_straal_kanon (3,5); de sterkte loopt lineair af naar de rand,
## het kanon duwt harder. Een cape buiten de straal krijgt NIETS. Puur
## visueel. Check: `-- capeschot`.
func _cape_vlaag(bron_w: Vector3, is_cannon: bool) -> void:
	var straal: float = PawnView.fx("cape_vlaag_straal_kanon", 3.5) if is_cannon else PawnView.fx("cape_vlaag_straal", 2.0)
	if straal <= 0.0:
		return
	for pv in _pawn_views.values():
		var v := pv as PawnView
		if v == null or not is_instance_valid(v) or v._cape == null:
			continue
		var d: Vector3 = v.global_position - bron_w
		d.y = 0.0
		var afstand: float = d.length()
		if afstand > straal:
			continue
		var richting: Vector3 = d.normalized() if afstand > 0.05 else -v.global_transform.basis.z
		var sterkte: float = (1.0 - afstand / straal) * (1.0 if is_cannon else 0.6)
		v.vlaag(richting, sterkte)


## Screen shake aanzwengelen (schaalt met impact). Uitzetbaar (motion sickness).
func _shake(strength: float) -> void:
	if not _combat_feel or not _screen_shake:
		return
	_shake_amt = maxf(_shake_amt, 0.08 * clampf(strength, 0.2, 1.6))


func _update_screen_shake(delta: float) -> void:
	if _camera == null:
		return
	if _shake_amt > 0.001:
		var off := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake_amt
		_camera.position = _cam_base + off
		_shake_amt *= exp(-delta * 14.0)  # snel uitdempen (~0.2s)
	elif _camera.position != _cam_base:
		_camera.position = _cam_base
		_shake_amt = 0.0


## Hitstop: bevries het beeld heel kort (Valheim/Street Fighter). De timer negeert
## de time_scale zodat de freeze een vaste real-time duur heeft.
func _hitstop(secs: float) -> void:
	if not _combat_feel or _in_hitstop or secs <= 0.0:
		return
	_in_hitstop = true
	# de physics helemaal stil (16 september): met alleen time_scale 0,05
	# vlogen ALLE cloth-capes (SoftBody3D op Jolt) na de hitstop van de rug,
	# ook zeven vakken van het schot; Max: "alle capes reageren nu op een
	# schot, dat moet niet". Gemeten met `-- capeschot`.
	PhysicsServer3D.set_active(false)
	Engine.time_scale = 0.05
	await get_tree().create_timer(secs, true, false, true).timeout
	Engine.time_scale = 1.0
	PhysicsServer3D.set_active(true)
	_in_hitstop = false


func _spawn_damage_float(coord: Vector2i, text: String, color: Color = Color(1.0, 0.32, 0.26)) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 88
	label.outline_size = 16
	label.outline_modulate = Color(0.05, 0.02, 0.02, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.position = tile_position(coord.x, coord.y) + Vector3(0.0, 1.5, 0.0)
	_board.add_child(label)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 0.9, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


## Opruk na een gewonnen melee: eerst de vasthoud-vlag weg, dan pas lopen.
## Zo kan geen enkele refresh hem tussentijds naar het doelvak snappen, en zie
## je hem echt vanaf zijn eigen tegel oversteken (Max, 30 juli).
func _begin_advance(pawn_id: int, from_coord: Vector2i, to_coord: Vector2i) -> void:
	_advance_holds.erase(pawn_id)
	_animate_move(pawn_id, from_coord, to_coord)


## idle_na (16 september): false als er na de rit nog een clip loopt die
## zelf naar idle terugkeert (de sprong-stoot van de charge begint al voor
## de aankomst; een play_idle aan het eind van de tween kapte hem af).
func _animate_move(pawn_id: int, from_coord: Vector2i, to_coord: Vector2i, rush: bool = false,
		idle_na: bool = true, dur_override: float = -1.0) -> void:
	var pv: PawnView = _pawn_views.get(pawn_id)
	if pv == null:
		return
	pv.face_dir(to_coord - from_coord)
	# rush (26 aug): de cavalerie-charge rijdt aan op de run-clip.
	if rush:
		pv.play_rush()
	else:
		pv.play_walk()
	var start := tile_position(from_coord.x, from_coord.y) + Vector3(0.0, PAWN_Y, 0.0)
	var end := tile_position(to_coord.x, to_coord.y) + Vector3(0.0, PAWN_Y, 0.0)
	pv.position = start
	_tweening_pawns[pawn_id] = true
	var dist: int = absi(to_coord.x - from_coord.x) + absi(to_coord.y - from_coord.y)
	var dur := clampf(0.13 * float(dist), 0.13, 0.45)
	if dur_override > 0.0:
		dur = dur_override   # de charge: de rit eindigt op de landing van de sprong
	# Beweeggeluid afhankelijk van het eenheidstype. Cavalerie: één galop-clip
	# per beweging (bevat zelf al meerdere hoefslagen). Infanterie/artillerie:
	# één klap per gelopen vakje (losse voetstappen / wielrollen).
	var mover: Pawn = session.state.pawns.get(pawn_id)
	_spawn_footprints(start, end, dur, mover)
	if mover != null and mover.unit_type == Constants.UnitType.CAVALRY:
		Audio.play("horse_move")
	else:
		var move_sfx := "cannon_move" if (mover != null and mover.unit_type == Constants.UnitType.ARTILLERY) else "step"
		Audio.play_footsteps(dist, dur, move_sfx)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(pv, "position", end, dur)
	tween.tween_callback(func() -> void:
		_tweening_pawns.erase(pawn_id)
		pv.position = end
		if idle_na:
			pv.play_idle())


func _on_game_over(winner_id: int) -> void:
	_clear_highlights()
	_card_hand.visible = false
	Audio.stop_music()  # sting krijgt de ruimte; ambience loopt door
	Audio.play("win_fanfare" if winner_id == _human_id else "lose_sting", 0.3)
	_update_hud(tr("END_WINNER") % _player_name(winner_id))
	if CampaignBridge.duel_actief:
		# F3.4b: uitslag terugboeken en naar de hub — de campagne gaat door.
		_overlay.show_choice(
			tr("END_WINNER") % _player_name(winner_id),
			tr("END_CAMPAIGN_BODY"),
			[tr("END_BACK_TO_CAMPAIGN")],
			func(_i: int) -> void:
				CampaignBridge.rond_af(session.state, winner_id)
				get_tree().change_scene_to_file("res://scenes/campaign/campaign.tscn"),
			UiAssets.team_kleur(winner_id), false, [], EINDE_SCHERM_SCRIPT.win_icoon(session.state, winner_id))
		return
	if session.is_online():
		# F4.3g: online alleen winnaar + reden en terug naar het menu; de
		# uitslag staat op de server (battlereport: F4.4).
		var reden: String = String(session.state.eind_reden)
		_overlay.show_choice(
			tr("END_WINNER") % _player_name(winner_id),
			tr("END_BODY") + ("" if reden == "" else "\n" + tr("END_REASON") % reden),
			[tr("END_BACK_TO_MENU")],
			func(_i: int) -> void: _verlaat_online(),
		)
		return
	_overlay.show_choice(
		tr("END_WINNER") % _player_name(winner_id),
		tr("END_BODY"),
		[tr("END_NEW_GAME")],
		func(_i: int) -> void: _show_difficulty_menu(),
		UiAssets.team_kleur(winner_id), false, [], EINDE_SCHERM_SCRIPT.win_icoon(session.state, winner_id),
	)


## F4.3g -- terug naar het menu na een online partij: sessie los, camera
## terug naar de stand van speler 1, de loopback (als die er was) weg.
func _verlaat_online() -> void:
	if session != null and session.is_online() and session != GameSession:
		var oude := session
		session = GameSession
		_connect_session_signals()
		oude.queue_free()
	_loopback = null
	_online_wachten = false
	if OnlineBridge.match_actief:
		OnlineBridge.klaar_met_match()  # F4.3i: niets meer te hervatten
	_human_id = Constants.PLAYER_1
	_ai_id = Constants.PLAYER_2
	_orient_camera_for(_human_id)
	_show_difficulty_menu()


# --- Human input (actiefase) -------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_K:  # screen shake aan/uit (motion sickness)
				_screen_shake = not _screen_shake
				_update_hud(tr("HUD_TOGGLE_SHAKE") % (tr("HUD_ON") if _screen_shake else tr("HUD_OFF")))
			KEY_J:  # alle combat-feel (stagger/hitstop/vonken/ragdoll) aan/uit
				_combat_feel = not _combat_feel
				_update_hud(tr("HUD_TOGGLE_FEEL") % (tr("HUD_ON") if _combat_feel else tr("HUD_OFF")))
			KEY_M:  # geluid dempen
				Audio.set_enabled(not Audio.enabled)
				_update_hud(tr("HUD_TOGGLE_SOUND") % (tr("HUD_ON") if Audio.enabled else tr("HUD_OFF")))
			KEY_L:  # sfeer-paneel: belichting/ambiance live tunen
				_toggle_ambiance_panel()
		return
	if event is InputEventMouseMotion:
		if _omgeving != null:
			_omgeving.beweeg((event as InputEventMouseMotion).position)   # mini-game: wegschuiven breekt af
		if _placement_mode:
			_update_placement_ghost((event as InputEventMouseMotion).position)
			return
		_update_hover((event as InputEventMouseMotion).position)
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		# Vinger los: de mini-games in het diorama (12 september) werpen bij het
		# loslaten; voor de rest van het spel telt alleen het indrukken.
		if mb.button_index == MOUSE_BUTTON_LEFT and _omgeving != null:
			_omgeving.laat_los(mb.position)
		return
	# Diorama-props om het bord (Omgeving): klikken mag altijd, juist ook
	# terwijl je op de tegenstander wacht. Ze liggen buiten het bord, dus
	# een prop-klik kan nooit een tegel-klik zijn.
	if mb.button_index == MOUSE_BUTTON_LEFT and _omgeving != null and _omgeving.klik(mb.position):
		return
	var state: GameState = session.state
	if state.current_player != _human_id:
		return
	# Zelf opstellen: klik een vrij vak in je thuisrijen; rechtermuis = ongedaan.
	if state.phase == Phase.Type.PLACEMENT and _placement_mode:
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_undo_placement()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var place_coord: Vector2i = _pick_coord(mb.position, _placement_free_tiles())
			if place_coord.x >= 0:
				_on_placement_tile_clicked(place_coord)
		return
	# Wolf-stap: klik een gemarkeerd vak = stap, al het andere = overslaan.
	if _wolf_step_mode:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var step_coord: Vector2i = _pick_wolf_tile(mb.position)
			if step_coord.x >= 0:
				_end_wolf_step_mode()
				session.submit_wolf_step(_human_id, step_coord)
				return
		_end_wolf_step_mode()
		session.skip_wolf_step(_human_id)
		return
	# Rechtermuis = deselecteren (in de actiefase).
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		if state.phase == Phase.Type.ACTION and _selected_pawn_id >= 0:
			_deselect()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if Phase.is_linking(state.phase):
		var link_pawn: int = _raycast_pawn(mb.position)
		if link_pawn >= 0:
			_on_link_pawn_clicked(link_pawn)
		return
	if state.phase != Phase.Type.ACTION:
		return
	var pawn_id: int = _raycast_pawn(mb.position)
	if pawn_id >= 0:
		# Door de geselecteerde pion heen klikken: door de camerahoek hangt de
		# pion óver het vakje ervoor. Ligt er een geldig zet-vak onder de klik,
		# dan wint dat vak (deselecteren kan altijd nog via rechtermuis of de
		# bovenkant van de pion).
		if pawn_id == _selected_pawn_id:
			var through: Vector2i = _pick_move_tile(mb.position)
			if through.x >= 0:
				_on_tile_clicked(through)
				return
		_on_pawn_clicked(pawn_id)
		return
	var coord: Vector2i = _pick_move_tile(mb.position)
	if coord.x >= 0:
		_on_tile_clicked(coord)


func _on_pawn_clicked(pawn_id: int) -> void:
	var state: GameState = session.state
	var pawn: Pawn = state.pawns.get(pawn_id)
	if pawn == null:
		return
	# Nogmaals op de geselecteerde pion klikken = deselecteren.
	if pawn_id == _selected_pawn_id:
		_deselect()
		return
	if pawn.owner_id == _human_id:
		_select_pawn(pawn_id)
	elif _selected_pawn_id >= 0 and _valid_attacks.has(pawn_id):
		session.submit_attack(_human_id, _selected_pawn_id, pawn_id)
	elif _selected_pawn_id >= 0 and _valid_charges.has(pawn_id):
		session.submit_charge(_human_id, _selected_pawn_id, _valid_charges[pawn_id], pawn_id)
	elif _selected_pawn_id >= 0 and _valid_shots.has(pawn_id):
		if _kanon_v42(_selected_pawn_id):
			session.submit_cannon_shoot(_human_id, _selected_pawn_id, pawn_id)
		else:
			session.submit_shot(_human_id, _selected_pawn_id, pawn_id)


## Legergrootte uit de ACTIEVE facties (rules.doctrine_data, C17), niet uit
## de kale tabel van constants.gd: die gaf 19/22 bij de start (bevinding
## 3 september; de telregel is alleen presentatie).
func _leger_totaal(state: GameState, pid: int) -> int:
	var comp: Array = state.doctrine_data_of(pid).get("comp", [0, 0, 0])
	return int(comp[0]) + int(comp[1]) + int(comp[2])


func _update_piece_counts() -> void:
	var state: GameState = session.state
	var red: int = state.get_alive_pawns_for(Constants.PLAYER_1).size()
	var blue: int = state.get_alive_pawns_for(Constants.PLAYER_2).size()
	var total_red: int = _leger_totaal(state, Constants.PLAYER_1)
	var total_blue: int = _leger_totaal(state, Constants.PLAYER_2)
	_count_label.text = HUD_BALK_SCRIPT.telling_bbcode(red, total_red, blue, total_blue)
	# F2.6 (v4.2): eigen reserve + CP-saldo (D12: die van de AI blijven geheim).
	if state.rules.campaign_actief():
		_count_label.text += HUD_BALK_SCRIPT.reserve_bbcode(
			state.pool_total(_human_id), int(state.cp.get(_human_id, 0)))


func _deselect() -> void:
	if _selected_pawn_id >= 0:
		Audio.play("deselect")
	_selected_pawn_id = -1
	_valid_moves = []
	_valid_attacks = []
	_valid_shots = []
	_valid_charges = {}
	_clear_highlights()
	_refresh_all()
	_set_turn_prompt(tr("HUD_YOUR_TURN"), _human_id)


func _on_tile_clicked(coord: Vector2i) -> void:
	if _selected_pawn_id >= 0 and _valid_moves.has(coord):
		if _kanon_v42(_selected_pawn_id):
			session.submit_cannon_roll(_human_id, _selected_pawn_id, coord)
		else:
			session.submit_move(_human_id, _selected_pawn_id, coord)


func _select_pawn(pawn_id: int) -> void:
	var state: GameState = session.state
	if not Rules.can_pawn_act(state, pawn_id):
		Audio.play("ui_error")
		_update_hud(tr("HUD_PAWN_CANNOT_ACT"))
		return
	_selected_pawn_id = pawn_id
	_clear_highlights()
	var pawn: Pawn = state.pawns.get(pawn_id)
	# Sfeer bij selectie, per type.
	match pawn.unit_type:
		Constants.UnitType.INFANTRY:
			# Haan spannen als hij kan schieten, anders het gewone aanleggen.
			if not Rules.get_valid_shot_targets(state, pawn_id).is_empty():
				Audio.play("musket_cock")
			else:
				Audio.play("inf_select")
		Constants.UnitType.CAVALRY:
			Audio.play("horse_select")
		Constants.UnitType.ARTILLERY:
			Audio.play("cannon_select")
	var move_paths: Dictionary = Rules.get_valid_move_paths(state, pawn_id)
	_valid_moves = move_paths.keys()
	_highlight_move_tiles(move_paths)
	# Melee (rood), schoten (oranje) en cavalerie-charges (rood, verderop).
	_valid_attacks = Rules.get_valid_melee_targets(state, pawn_id)
	_valid_shots = Rules.get_valid_shot_targets(state, pawn_id)
	_valid_charges = {}
	if pawn.unit_type == Constants.UnitType.CAVALRY:
		_valid_charges = _compute_charge_targets(state, pawn_id, move_paths)
	var melee_positions: Array = []
	for aid in _valid_attacks:
		var enemy: Pawn = state.pawns.get(aid)
		if enemy != null:
			melee_positions.append(enemy.position)
	for aid in _valid_charges.keys():
		var enemy2: Pawn = state.pawns.get(aid)
		if enemy2 != null:
			melee_positions.append(enemy2.position)
	_highlight_tiles(melee_positions, Color(0.95, 0.25, 0.25))
	# Vuurlijnen zichtbaar maken: vaag oranje = binnen dracht (vrije lijn),
	# vol oranje = raakbaar doelwit.
	var lane_tiles: Array = []
	var shot_positions: Array = []
	for sid in _valid_shots:
		var target: Pawn = state.pawns.get(sid)
		if target != null:
			shot_positions.append(target.position)
	for lane_pos in Rules.get_shot_range_tiles(state, pawn_id):
		if not shot_positions.has(lane_pos):
			lane_tiles.append(lane_pos)
	_highlight_tiles(lane_tiles, Color(1.0, 0.72, 0.2), 0.18)
	_highlight_tiles(shot_positions, Color(1.0, 0.72, 0.2))
	_refresh_all()
	var hint := tr("HUD_HINT_MOVE")
	match pawn.unit_type:
		Constants.UnitType.INFANTRY:
			if pawn.attack_value >= 2:
				hint += tr("HUD_HINT_INF_SHOT") % Rules.shot_damage(session.state, pawn)
			else:
				hint += tr("HUD_HINT_INF_NO_SHOT")
		Constants.UnitType.CAVALRY:
			hint += tr("HUD_HINT_CAV")
		Constants.UnitType.ARTILLERY:
			if _valid_shots.is_empty():
				hint += tr("HUD_HINT_ART_NO_TARGET") % Constants.ARTILLERY_RANGE
			else:
				hint += tr("HUD_HINT_ART") % Constants.ARTILLERY_RANGE
	_update_hud(tr("HUD_SELECTED") % [Constants.unit_type_name(pawn.unit_type), hint, Rules.stamina_beschikbaar(session.state, pawn)])


## Voor elke vijand die via een charge bereikbaar is: de beste (kortste) zet
## naar een vak naast die vijand. Aangrenzende vijanden vallen onder melee.
## LET OP: de charge kost stappen + 1 (de aanval) — alleen betaalbare charges tonen,
## anders staat er een rode vijand die bij het klikken "blijft staan".
func _compute_charge_targets(state: GameState, pawn_id: int, move_paths: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var best_cost: Dictionary = {}
	var stamina: int = Rules.stamina_beschikbaar(state, state.pawns[pawn_id])
	for pos in move_paths.keys():
		var cost: int = (move_paths[pos] as Array).size() + 1  # stappen + aanval
		if cost > stamina:
			continue
		for neighbor in Constants.manhattan_neighbors(pos):
			var other: Pawn = state.get_pawn_at(neighbor)
			if other == null or other.is_eliminated or other.owner_id == state.pawns[pawn_id].owner_id:
				continue
			if _valid_attacks.has(other.id):
				continue  # al aangrenzend: gewone melee
			if not best_cost.has(other.id) or cost < best_cost[other.id]:
				best_cost[other.id] = cost
				result[other.id] = pos
	return result


# --- Raycast helpers ---------------------------------------------------------

func _update_hover(screen_pos: Vector2) -> void:
	var state: GameState = session.state
	var hovered := -1
	if state.current_player == _human_id:
		if Phase.is_linking(state.phase):
			var pid := _raycast_pawn(screen_pos)
			if pid >= 0:
				var pawn: Pawn = state.pawns.get(pid)
				if pawn != null and pawn.owner_id == _human_id and not pawn.is_eliminated \
						and pawn.linked_card_id == -1:
					hovered = pid
		elif state.phase == Phase.Type.ACTION:
			hovered = _raycast_pawn(screen_pos)
	if hovered == _hovered_pawn_id:
		return
	if _hovered_pawn_id >= 0 and _pawn_views.has(_hovered_pawn_id):
		_pawn_views[_hovered_pawn_id].set_hovered(false)
		if Phase.is_linking(state.phase):
			var old_pawn: Pawn = state.pawns.get(_hovered_pawn_id)
			var still_linkable: bool = (old_pawn != null and old_pawn.owner_id == _human_id
					and not old_pawn.is_eliminated and old_pawn.linked_card_id == -1)
			_pawn_views[_hovered_pawn_id].set_ring_link_state(1 if still_linkable else 0)
	_hovered_pawn_id = hovered
	if hovered >= 0 and _pawn_views.has(hovered):
		_pawn_views[hovered].set_hovered(true)
		if Phase.is_linking(state.phase):
			_pawn_views[hovered].set_ring_link_state(2)


## Pion-picking via schermprojectie (geen physics): pak de pion wiens
## geprojecteerde positie het dichtst bij de klik ligt, binnen een straal.
func _raycast_pawn(screen_pos: Vector2) -> int:
	if _camera == null:
		return -1
	var state: GameState = session.state
	var best_id := -1
	var best_dist := 44.0
	for pid in _pawn_views:
		var pv: PawnView = _pawn_views[pid]
		if not pv.visible:
			continue
		var pawn: Pawn = state.pawns.get(pid)
		if pawn == null or pawn.is_eliminated:
			continue
		var world := pv.global_position + Vector3(0.0, 0.6, 0.0)
		if _camera.is_position_behind(world):
			continue
		var d := _camera.unproject_position(world).distance_to(screen_pos)
		if d < best_dist:
			best_dist = d
			best_id = pid
	return best_id


## Kies het gemarkeerde Wolf-stap-vak dat het dichtst bij de klik ligt.
func _pick_wolf_tile(screen_pos: Vector2) -> Vector2i:
	return _pick_coord(screen_pos, _wolf_step_tiles)


## Kies uit een lijst coördinaten het vak dat het dichtst bij de klik ligt.
func _pick_coord(screen_pos: Vector2, coords: Array) -> Vector2i:
	if _camera == null:
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_dist := 52.0
	for coord in coords:
		var world: Vector3 = _board.to_global(tile_position(coord.x, coord.y) + Vector3(0.0, 0.1, 0.0))
		if _camera.is_position_behind(world):
			continue
		var d := _camera.unproject_position(world).distance_to(screen_pos)
		if d < best_dist:
			best_dist = d
			best = coord
	return best


## Kies de geldige zet-tegel die het dichtst bij de klik ligt.
func _pick_move_tile(screen_pos: Vector2) -> Vector2i:
	if _camera == null:
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_dist := 52.0
	for coord in _valid_moves:
		var world: Vector3 = _board.to_global(tile_position(coord.x, coord.y) + Vector3(0.0, 0.1, 0.0))
		if _camera.is_position_behind(world):
			continue
		var d := _camera.unproject_position(world).distance_to(screen_pos)
		if d < best_dist:
			best_dist = d
			best = coord
	return best


# --- Highlights --------------------------------------------------------------

## Groene bewegings-tiles met daarop klein de stamina-kosten (pad-lengte).
func _highlight_move_tiles(move_paths: Dictionary) -> void:
	for coord in move_paths:
		var cost: int = (move_paths[coord] as Array).size()
		var box := CSGBox3D.new()
		box.size = Vector3(0.9, 0.06, 0.9)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.9, 0.35, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.9, 0.35)
		mat.emission_energy_multiplier = 0.4
		box.material_override = mat
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box.position = tile_position(coord.x, coord.y) + Vector3(0.0, 0.09, 0.0)
		var label := Label3D.new()
		label.text = str(cost)
		label.font_size = 40
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.04, 0.16, 0.05)
		label.outline_size = 6
		label.outline_modulate = Color(1.0, 1.0, 1.0, 0.85)
		label.position = Vector3(0.0, 0.22, 0.0)
		box.add_child(label)
		_board.add_child(box)
		_highlights.append(box)


func _highlight_tiles(coords: Array, color: Color, alpha: float = 0.55) -> void:
	for coord in coords:
		var box := CSGBox3D.new()
		box.size = Vector3(0.9, 0.06, 0.9)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color.r, color.g, color.b, alpha)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.4
		box.material_override = mat
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box.position = tile_position(coord.x, coord.y) + Vector3(0.0, 0.09, 0.0)
		_board.add_child(box)
		_highlights.append(box)


func _clear_highlights() -> void:
	for node in _highlights:
		node.queue_free()
	_highlights.clear()


# --- HUD ---------------------------------------------------------------------

func _update_hud(prompt: String = "") -> void:
	var state: GameState = session.state
	_top_label.text = tr("HUD_TOPBAR") % [
		state.cycle, state.round_number, _phase_label(state.phase)
	]
	if prompt != "":
		_prompt_label.text = prompt
		_prompt_label.add_theme_color_override("font_color", Color(0.8, 0.84, 0.92))
	if _hud_balk != null: _hud_balk.ververs(state.phase, prompt != "")


func _phase_label(phase: int) -> String:
	if phase == Phase.Type.PLACEMENT:
		return tr("PHASE_PLACEMENT")
	if Phase.is_define(phase):
		return tr("PHASE_DEFINE")
	if Phase.is_reveal(phase):
		return tr("PHASE_REVEAL")
	if Phase.is_linking(phase):
		return tr("PHASE_LINKING")
	if phase == Phase.Type.ACTION:
		return tr("PHASE_ACTION")
	if phase == Phase.Type.GAME_OVER:
		return tr("PHASE_GAME_OVER")
	if phase == Phase.Type.CYCLE_SPAWN:
		return tr("PHASE_SPAWN_TITLE")  # F4.3e: de topbalk kende deze fase niet
	return ""


## F4.3g: de naam volgt de SEAT (rood = 1, blauw = 2) plus wie erop zit: jij,
## de AI, of online de naam die de sessie kent (terugval: de kleur).
func _player_name(player_id: int) -> String:
	if player_id != _human_id and CampaignBridge.duel_actief:
		return tr("HUD_PLAYER_CAMPAIGN_AI") % CampaignBridge.naam_vijand()  # F3.4b: de campagne-vijand
	var kleur: String = tr("HUD_COLOR_RED") if player_id == Constants.PLAYER_1 else tr("HUD_COLOR_BLUE")
	if player_id == _human_id:
		return tr("HUD_PLAYER_YOU") % kleur
	if session.is_online():
		var naam: String = session.naam_van(player_id)
		return tr("HUD_PLAYER_OPP") % (naam if naam != "" else kleur)
	return tr("HUD_PLAYER_AI") % kleur


## F4.3c: de kleur hangt aan de SEAT (rood = speler 1, blauw = speler 2), net
## als de teamringen op het bord. Voor de mens als speler 1 is dat wat het
## altijd was; online als seat 2 ben je blauw, en dat klopt met je pionnen.
func _player_color(player_id: int) -> Color:
	return Color(0.95, 0.45, 0.45) if player_id == Constants.PLAYER_1 else Color(0.45, 0.62, 1.0)


## Prompt met de kleur van wie aan zet is (rood = speler 1, blauw = speler 2).
func _set_turn_prompt(text: String, player_id: int) -> void:
	_update_hud()
	_prompt_label.text = text
	_prompt_label.add_theme_color_override("font_color", _player_color(player_id))
	if _hud_balk != null: _hud_balk.zet_beurt(player_id)
