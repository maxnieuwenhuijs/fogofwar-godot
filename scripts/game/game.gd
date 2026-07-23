extends Node

const PAWN_SCENE := preload("res://scenes/game/pawn_view.tscn")
const BOARD_SCENE := preload("res://Board.tscn")
const OVERLAY_SCENE := preload("res://scenes/ui/overlay.tscn")
const INSTRUCTIONS_SCRIPT := preload("res://scripts/ui/instructions.gd")
const AUTO_AI_SCRIPT := preload("res://scripts/ai/AIMedium.gd")  # timeout-zet voor de mens
const PAWN_Y := 0.05

## AI difficulty: 0 = Easy, 1 = Medium, 2 = Hard
@export var ai_difficulty: int = 1

@onready var _world: Node3D = $World
@onready var _pawns_root: Node3D = $World/Pawns
@onready var _card_hand: CardHand = $UI/CardHand
@onready var _top_label: Label = $UI/TopLabel
@onready var _prompt_label: Label = $UI/PromptLabel
@onready var _count_label: RichTextLabel = $UI/CountLabel

var _board: Node3D
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
var _ambiance_panel: PanelContainer = null
var _dust_motes: Array = []
var _footprints: Array = []  # blijven staan tot de cyclus voorbij is
var _footstep_cache: Dictionary = {}  # pad -> Texture2D of null (assets/textures/footstep/)
var _shake_amt: float = 0.0
var _cam_base: Vector3 = Vector3.ZERO
var _in_hitstop: bool = false
var _dying_views: Dictionary = {}     # pawn_id -> true zolang de ragdoll speelt
var _auto_link_human: bool = false   # koppelen automatisch afmaken na timeout

const PHASE_TIME_LIMIT := 20.0

var _human_id: int = Constants.PLAYER_1
var _ai_id: int = Constants.PLAYER_2


func _ready() -> void:
	_board = BOARD_SCENE.instantiate()
	_world.add_child(_board)
	_world.move_child(_board, 0)
	_pawns_root.reparent(_board, false)
	_setup_battlefield_lighting()
	_setup_board_model()
	_camera = _board.get_node("Camera3D") as Camera3D
	_cam_base = _camera.position  # rustpositie voor de screen shake
	Audio.play_ambient("ambient_field")  # veld-ambience onder menu én spel
	_index_tiles()
	_connect_session_signals()
	_card_hand.define_confirmed.connect(_on_define_confirmed)
	_card_hand.card_picked.connect(_on_link_card_picked)
	_overlay = OVERLAY_SCENE.instantiate()
	$UI.add_child(_overlay)
	_overlay.hide()
	_instructions = INSTRUCTIONS_SCRIPT.new()
	$UI.add_child(_instructions)
	_build_help_button()
	_hp_layer = Control.new()
	_hp_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(_hp_layer)
	# Achter de kaarten/overlay/HUD renderen (blokjes mogen die niet bedekken).
	$UI.move_child(_hp_layer, 0)
	_card_hand.visible = false
	_show_difficulty_menu()


func _process(delta: float) -> void:
	_update_screen_shake(delta)
	_update_health_bars()
	if _timer_active:
		_timer_left -= delta
		if _timer_left <= 0.0:
			_timer_active = false
			_on_phase_timeout()
		else:
			var st: GameState = GameSession.state
			_top_label.text = "Cyclus %d · Ronde %d · %s · nog %ds" % [
				st.cycle, st.round_number, _phase_label(st.phase), int(ceil(_timer_left))]
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
	_timer_left = seconds
	_last_tick_second = -1  # aftel-tikken opnieuw laten beginnen


func _stop_phase_timer() -> void:
	_timer_active = false


func _on_phase_timeout() -> void:
	var ph: int = GameSession.state.phase
	if Phase.is_define(ph) and GameSession.state.cards_defined[_human_id].size() == 0:
		_card_hand._on_confirm_pressed()  # auto-bevestig (altijd geldig)
	elif Phase.is_linking(ph):
		_auto_link_human = true
		if GameSession.state.current_player == _human_id:
			_auto_link(_human_id)
	elif ph == Phase.Type.PLACEMENT and _placement_mode:
		# Tijd om tijdens zelf opstellen → val terug op de standaard-opstelling.
		_cancel_manual_placement()
	elif ph == Phase.Type.ACTION and GameSession.state.current_player == _human_id:
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
	_update_hud("Tijd om — standaard-opstelling gebruikt")
	_confirm_placement()


## Timeout in de actiefase: kies greedy een zet voor de mens (zelfde motor als de AI).
func _auto_action_human() -> void:
	var state: GameState = GameSession.state
	if state.phase != Phase.Type.ACTION or state.current_player != _human_id:
		return
	_deselect()
	if state.pending_wolf_step_pawn != -1:
		_end_wolf_step_mode()
		GameSession.skip_wolf_step(_human_id)
		return
	if _human_auto_ai == null:
		_human_auto_ai = AUTO_AI_SCRIPT.new()
		_human_auto_ai.player_id = _human_id
	var action: Dictionary = _human_auto_ai.best_greedy_action(state)
	if action.is_empty():
		return
	_update_hud("Tijd om — het spel koos een zet voor je")
	match String(action.type):
		"move":
			GameSession.submit_move(_human_id, action.pawn_id, action.target)
		"attack":
			GameSession.submit_attack(_human_id, action.attacker_id, action.defender_id)
		"shot":
			GameSession.submit_shot(_human_id, action.shooter_id, action.target_id)
		"charge":
			GameSession.submit_charge(_human_id, action.pawn_id, action.move_target, action.defender_id)


func _exit_tree() -> void:
	# Wacht een lopende AI-thread netjes af zodat 'ie niet verweesd wordt afgesloten.
	if _ai_thread != null and _ai_thread.is_started():
		_ai_thread.wait_to_finish()
		_ai_thread = null


func _show_difficulty_menu() -> void:
	_card_hand.visible = false
	_clear_highlights()
	_top_label.text = "Fog of War"
	_prompt_label.text = ""
	_overlay.show_choice(
		"Kies je tegenstander",
		"Tegen welke AI wil je oefenen?",
		["Easy", "Medium", "Hard", "Ultra — god mode", "Speluitleg", "AI Trainer bekijken", "Model-tuner"],
		_on_menu_choice,
	)


func _on_menu_choice(index: int) -> void:
	if index == 4:
		_show_rules_overlay(func() -> void: _show_difficulty_menu())
	elif index == 5:
		get_tree().change_scene_to_file("res://scenes/training/Trainer.tscn")
	elif index >= 6:
		get_tree().change_scene_to_file("res://scenes/tools/ModelTuner.tscn")
	else:
		ai_difficulty = index
		_show_doctrine_menu()


## Open het uitleg-tabscherm (scripts/ui/instructions.gd). back = terugknop-actie.
func _show_rules_overlay(back: Callable) -> void:
	_instructions.open(back)


## "?"-knop rechtsboven: uitleg altijd beschikbaar, ook midden in een potje.
## Pauzeert de fase-timer zolang het scherm open staat.
func _build_help_button() -> void:
	var help := Button.new()
	help.text = "?"
	help.custom_minimum_size = Vector2(64, 64)
	help.add_theme_font_size_override("font_size", 34)
	help.anchors_preset = Control.PRESET_TOP_RIGHT
	help.anchor_left = 1.0
	help.anchor_right = 1.0
	help.offset_left = -84.0
	help.offset_right = -20.0
	help.offset_top = 20.0
	help.offset_bottom = 84.0
	help.pressed.connect(_on_help_pressed)
	$UI.add_child(help)
	# "sfeer"-knopje eronder: opent het sfeer-paneel (zelfde als toets L).
	var sfeer := Button.new()
	sfeer.text = "sfeer"
	sfeer.custom_minimum_size = Vector2(64, 40)
	sfeer.add_theme_font_size_override("font_size", 16)
	sfeer.anchors_preset = Control.PRESET_TOP_RIGHT
	sfeer.anchor_left = 1.0
	sfeer.anchor_right = 1.0
	sfeer.offset_left = -84.0
	sfeer.offset_right = -20.0
	sfeer.offset_top = 92.0
	sfeer.offset_bottom = 132.0
	sfeer.modulate = Color(1.0, 1.0, 1.0, 0.55)
	sfeer.pressed.connect(_toggle_ambiance_panel)
	$UI.add_child(sfeer)


var _help_resume_timer: bool = false
var _help_time_left: float = 0.0


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
	var names: Array = []
	var lines: Array = []
	for doctrine in Constants.DOCTRINE_DATA.keys():
		var data: Dictionary = Constants.doctrine_data(doctrine)
		names.append("%s  (%d× budget %d · %d/%d/%d)" % [
			data.name, int(data.cards), int(data.budget),
			data.comp[0], data.comp[1], data.comp[2]])
		lines.append("%s:  ✚ %s   ✖ %s" % [data.name, data.pro, data.con])
	_overlay.show_choice(
		"Kies je doctrine",
		"Vast voor de hele partij. Hierna kies je de tegenstander.\nSamenstelling = Infanterie / Cavalerie / Artillerie.\n\n" + "\n".join(lines),
		names,
		_on_doctrine_choice,
		Color.WHITE, true,
	)


func _on_doctrine_choice(index: int) -> void:
	_human_doctrine = Constants.DOCTRINE_DATA.keys()[index]
	_show_opponent_menu()


## Kies de factie van de AI-tegenstander. "Verrassing" volgt de officiele
## regel (v4.1 §4.1: blinde, gelijktijdige keuze); een vaste factie is
## handig om te oefenen tegen een specifieke matchup.
func _show_opponent_menu() -> void:
	var names: Array = ["Verrassing (AI kiest blind)"]
	for key in Constants.DOCTRINE_DATA.keys():
		var data: Dictionary = Constants.doctrine_data(key)
		names.append("%s  (%d/%d/%d)" % [data.name, data.comp[0], data.comp[1], data.comp[2]])
	_overlay.show_choice(
		"Tegen wie speel je?",
		"Kies de factie van de AI, of laat hem blind loten (standaardregel).",
		names,
		_on_opponent_choice,
		Color.WHITE, true,
	)


func _on_opponent_choice(index: int) -> void:
	if index == 0:
		_ai_doctrine = Constants.DOCTRINE_DATA.keys()[randi() % Constants.DOCTRINE_DATA.size()]
	else:
		_ai_doctrine = Constants.DOCTRINE_DATA.keys()[index - 1]
	_start_match(ai_difficulty)


func _start_match(difficulty: int) -> void:
	_overlay.hide()
	# Combat-feel-state resetten (voor het geval een vorige partij midden in een
	# hitstop/ragdoll eindigde).
	Engine.time_scale = 1.0
	_in_hitstop = false
	_shake_amt = 0.0
	_dying_views.clear()
	_clear_debris(true)  # slagveld van de vorige partij ruimen
	_clear_footprints()
	Audio.play_music("music_battle")  # zacht marcherend bed onder de partij
	ai_difficulty = difficulty
	_setup_ai()
	GameSession.start_new_game(_human_doctrine, _ai_doctrine)
	_show_placement_overlay()


## Vrije opstelling (v4.1 §2.2). Nu: standaard-opstelling bevestigen;
## een sleep-UI voor eigen opstellingen is een latere uitbreiding.
func _show_placement_overlay() -> void:
	var human_data: Dictionary = Constants.doctrine_data(_human_doctrine)
	var ai_data: Dictionary = Constants.doctrine_data(_ai_doctrine)
	var body := "\n".join([
		"Doctrines onthuld:",
		"Jij: %s — ✚ %s" % [human_data.name, human_data.pro],
		"AI: %s — ✚ %s" % [ai_data.name, ai_data.pro],
		"",
		"Zelf opstellen: eerst je kanonnen, dan je paarden — klik vakken in je twee rijen; de soldaten vullen automatisch aan.",
		"Standaard: kanonnen vóór op flank en centrum (vrij schootsveld), cavalerie achteraan.",
		"Doel: 2 pionnen in de haven aan de overkant, of alles uitschakelen.",
	])
	_update_hud("Opstelling")
	_overlay.show_choice("Opstelling", body, ["Zelf opstellen", "Standaard opstelling", "Speluitleg"],
		_on_placement_menu_choice, Color.WHITE, true)


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
	var comp: Array = GameSession.state.doctrine_data_of(_human_id).comp
	var order: Array = [
		{"type": Constants.UnitType.ARTILLERY, "count": int(comp[2])},
		{"type": Constants.UnitType.CAVALRY, "count": int(comp[1])},
	]
	order.sort_custom(func(a, b): return int(a.count) < int(b.count))
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
		var placed := 0
		for p in _placement_placed:
			if int(p.type) == int(step.type):
				placed += 1
		if placed < int(step.count):
			return {"type": int(step.type), "left": int(step.count) - placed}
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
	var type_name := "kanonnen" if int(step.type) == Constants.UnitType.ARTILLERY else "paarden"
	_update_hud("Plaats je %s — klik een vak (nog %d · rechtermuis = ongedaan)" % [type_name, int(step.left)])


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
	_placement_placed.append({"type": int(step.type), "pos": coord})
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
	pv.set_character(GameSession.state.doctrine_of(_human_id), unit_type, null)
	_placement_previews[coord] = pv


func _finish_manual_placement() -> void:
	# Infanterie vult de open vakken aan: voorste rij eerst, centrum naar buiten.
	var comp: Array = GameSession.state.doctrine_data_of(_human_id).comp
	var inf_left: int = int(comp[0])
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
	GameSession.submit_placement(_ai_id, _ai.choose_placement(GameSession.state))
	GameSession.submit_placement(_human_id, _placement_placed)
	_placement_placed = []
	_build_pawn_views()
	_refresh_all()


func _confirm_placement() -> void:
	_overlay.hide()
	GameSession.submit_placement(_ai_id, _ai.choose_placement(GameSession.state))
	GameSession.submit_default_placement(_human_id)
	_build_pawn_views()
	_refresh_all()


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


func _connect_session_signals() -> void:
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.cards_revealed_event.connect(_on_cards_revealed)
	GameSession.wolf_step_pending.connect(_on_wolf_step_pending)
	GameSession.turn_changed.connect(_on_turn_changed)
	GameSession.action_performed.connect(_on_action_performed)
	GameSession.cycle_started.connect(_on_cycle_started)
	GameSession.game_over.connect(_on_game_over)


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
	for pawn in GameSession.state.pawns.values():
		var pv: PawnView = PAWN_SCENE.instantiate()
		pv.pawn_id = pawn.id
		pv.team = Constants.Team.RED if pawn.owner_id == Constants.PLAYER_1 else Constants.Team.BLUE
		pv.position = tile_position(pawn.position.x, pawn.position.y) + Vector3(0.0, PAWN_Y, 0.0)
		_pawns_root.add_child(pv)
		# Kijk naar de vijand: rood naar z=0 (-z), blauw naar z=10 (+z).
		pv.face_dir(Vector2i(0, -1) if pawn.owner_id == Constants.PLAYER_1 else Vector2i(0, 1))
		pv.set_unit_type(pawn.unit_type)
		_pawn_views[pawn.id] = pv
	_build_health_bars()


const HP_COLS := 5
const HP_ROWS := 3
const HP_BLOCK_SIZE := 5.5
const HP_BLOCK_GAP := 1.0
const HP_COLOR_EMPTY := Color(0.06, 0.06, 0.08, 0.92)
const HP_COLOR_HEALTH := Color(0.28, 0.85, 0.38)
const HP_COLOR_STAMINA := Color(0.45, 0.74, 1.0)
const HP_COLOR_ATTACK := Color(0.98, 0.56, 0.3)

func _build_health_bars() -> void:
	if _hp_layer == null:
		return
	for child in _hp_layer.get_children():
		child.free()
	_hp_bars.clear()
	for pawn in GameSession.state.pawns.values():
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.visible = false
		var blocks: Array = []
		for r in HP_ROWS:
			for c in HP_COLS:
				var block := ColorRect.new()
				block.mouse_filter = Control.MOUSE_FILTER_IGNORE
				block.size = Vector2(HP_BLOCK_SIZE, HP_BLOCK_SIZE)
				block.position = Vector2(
					c * (HP_BLOCK_SIZE + HP_BLOCK_GAP),
					r * (HP_BLOCK_SIZE + HP_BLOCK_GAP))
				holder.add_child(block)
				blocks.append(block)
		_hp_layer.add_child(holder)
		_hp_bars[pawn.id] = {"holder": holder, "blocks": blocks}


func _update_health_bars() -> void:
	if _camera == null:
		return
	var state: GameState = GameSession.state
	var total_w := HP_COLS * HP_BLOCK_SIZE + (HP_COLS - 1) * HP_BLOCK_GAP
	var total_h := HP_ROWS * HP_BLOCK_SIZE + (HP_ROWS - 1) * HP_BLOCK_GAP
	for pid in _hp_bars:
		var entry: Dictionary = _hp_bars[pid]
		var pawn: Pawn = state.pawns.get(pid)
		var pv: PawnView = _pawn_views.get(pid)
		if pawn == null or pawn.is_eliminated or not pawn.is_active or pv == null or not pv.visible \
				or _camera.is_position_behind(pv.global_position):
			entry.holder.visible = false
			continue
		# Onderaan het poppetje: anker op de voeten, blokjes er net onder.
		var screen := _camera.unproject_position(pv.global_position)
		entry.holder.visible = true
		entry.holder.position = screen - Vector2(total_w * 0.5, 0.0) + Vector2(0.0, 3.0)
		var blocks: Array = entry.blocks
		for c in HP_COLS:
			blocks[c].color = HP_COLOR_HEALTH if c < pawn.current_hp else HP_COLOR_EMPTY
			blocks[HP_COLS + c].color = HP_COLOR_STAMINA if c < pawn.remaining_stamina else HP_COLOR_EMPTY
			blocks[2 * HP_COLS + c].color = HP_COLOR_ATTACK if c < pawn.attack_value else HP_COLOR_EMPTY


# --- State-sync --------------------------------------------------------------

func _refresh_all() -> void:
	var state: GameState = GameSession.state
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
			pv.position = tile_position(pawn.position.x, pawn.position.y) + Vector3(0.0, PAWN_Y, 0.0)
		# Karaktermodel op basis van de gekoppelde kaart. Verborgen koppelingen (Krokodil-perk)
		# blijven neutraal voor de tegenstander (het archetype zou de kaart verraden);
		# je eigen pionnen tonen hun karakter altijd.
		var card: Card = null
		if pawn.linked_card_id >= 0 and (pawn.card_revealed or pawn.owner_id == _human_id):
			card = state.all_cards.get(pawn.linked_card_id)
		pv.set_character(state.doctrine_of(pawn.owner_id), pawn.unit_type, card)
		pv.set_stats_label(pawn.is_active, pawn.current_hp, pawn.remaining_stamina)
		pv.set_team_ring_active(pawn.is_active)
		if Phase.is_linking(state.phase):
			# Koppel-fase: donkere ring om alles wat nog geen kaart heeft,
			# felle ring op de gehoverde eigen pion.
			var lstate: int = 1 if pawn.linked_card_id == -1 else 0
			if lstate == 1 and pid == _hovered_pawn_id and pawn.owner_id == _human_id:
				lstate = 2
			pv.set_ring_link_state(lstate)
		else:
			pv.set_ring_link_state(0)
		var human_action := state.phase == Phase.Type.ACTION and state.current_player == _human_id \
				and pawn.owner_id == _human_id and pawn.is_active
		pv.set_dimmed(human_action and not Rules.can_pawn_act(state, pid))
		pv.set_selected(pid == _selected_pawn_id)


# --- Define ------------------------------------------------------------------

func _on_define_confirmed(_cards: Array) -> void:
	var dicts: Array = _card_hand.get_defined_dicts()
	_card_hand.visible = false
	GameSession.submit_define_cards(_human_id, dicts)
	var ai_cards: Array = _ai.generate_cards(GameSession.state)
	GameSession.submit_define_cards(_ai_id, ai_cards)


# --- Reveal (initiatief-bod, v4.1 §4.3-B) -------------------------------------

func _on_cards_revealed(t1: Dictionary, t2: Dictionary, initiative_winner: int) -> void:
	var body := "Jij (rood): bod %d%% · aanval %d · speed %d\nAI (blauw): bod %d%% · aanval %d · speed %d\n\nHet hoogste aanval-bod krijgt het initiatief:\ndie speler koppelt én handelt straks als eerste." % [
		int(round(float(t1.get("bid", 0.0)) * 100.0)), int(t1.attack), int(t1.stamina),
		int(round(float(t2.get("bid", 0.0)) * 100.0)), int(t2.attack), int(t2.stamina),
	]
	var title := "%s begint met koppelen" % _player_name(initiative_winner)
	var accent := _player_color(initiative_winner)
	_update_hud("Onthulling")
	# Trommelroffel bij de onthulling. (initiative-bugel staat nu uit.)
	Audio.play("reveal")
	# Audio.play("initiative", 0.6)
	_overlay.show_choice(title, body, ["Doorgaan"], func(_i: int) -> void: _continue_after_reveal(), accent)


func _continue_after_reveal() -> void:
	_overlay.hide()
	GameSession.acknowledge_reveal()


# --- Linking (mens interactief, AI automatisch) -----------------------------

func _begin_human_linking() -> void:
	_selected_link_card_id = -1
	_clear_highlights()
	var flags: Array = []
	for card in GameSession.state.cards_revealed[_human_id]:
		flags.append(card.is_linked())
	_card_hand.open_for_linking(flags)
	_set_turn_prompt("Jouw beurt — kies een kaart, tik dan een pion", _human_id)


func _on_link_card_picked(index: int) -> void:
	var state: GameState = GameSession.state
	if not Phase.is_linking(state.phase) or state.current_player != _human_id:
		return
	var cards: Array = state.cards_revealed[_human_id]
	if index < 0 or index >= cards.size():
		return
	var card: Card = cards[index]
	if card.is_linked():
		return
	_selected_link_card_id = card.id
	_highlight_own_unlinked_pawns()
	_update_hud("Kies een pion om te koppelen")


func _on_link_pawn_clicked(pawn_id: int) -> void:
	if _selected_link_card_id < 0:
		_update_hud("Kies eerst een kaart onderaan")
		return
	var pawn: Pawn = GameSession.state.pawns.get(pawn_id)
	if pawn == null or pawn.owner_id != _human_id or pawn.is_eliminated or pawn.linked_card_id != -1:
		return
	GameSession.submit_link(_human_id, _selected_link_card_id, pawn_id)
	_animate_link(pawn_id)
	if _pawn_views.has(pawn_id):
		(_pawn_views[pawn_id] as PawnView).set_ring_link_state(0)
	_selected_link_card_id = -1
	_clear_highlights()


## Koppel-fase: donkere ring om ALLE nog niet gekoppelde pionnen (beide
## teams); gekoppelde pionnen tonen hun actieve gloeiende team-ring en
## hover maakt de ring fel en iets groter (zie _update_hover).
func _highlight_own_unlinked_pawns() -> void:
	_clear_highlights()
	for pid in _pawn_views:
		var pawn: Pawn = GameSession.state.pawns.get(pid)
		if pawn == null or pawn.is_eliminated:
			continue
		(_pawn_views[pid] as PawnView).set_ring_link_state(1 if pawn.linked_card_id == -1 else 0)


func _auto_link(player_id: int) -> void:
	for card in GameSession.state.cards_revealed[player_id]:
		if card.is_linked():
			continue
		var pawn: Pawn = _pick_link_pawn(player_id)
		if pawn != null:
			GameSession.submit_link(player_id, card.id, pawn.id)
			_animate_link(pawn.id)
		return


## Korte koppel-animatie: pion springt even omhoog + glim-flits.
func _animate_link(pawn_id: int) -> void:
	Audio.play("link_snap")  # kaart klikt vast op de pion
	var pv: PawnView = _pawn_views.get(pawn_id)
	if pv == null:
		return
	pv.flash_ring(Color(0.5, 0.85, 1.0))
	# Rook-pofje verhult de model-wissel: base -> archetype gebeurt ONDER de
	# rook, zodat het poppetje na de pof als z'n nieuwe (bv. spd) versie
	# tevoorschijn komt. Grootte tunebaar via "koppel-pof".
	var puff: int = int(round(4.0 * PawnView.fx("link_puff", 1.0)))
	if puff > 0:
		_spawn_smoke(pv.position + Vector3(0.0, 0.45, 0.0), puff, 0.2, Vector3.UP * 0.25, 1.3)
	# Onder de pof: naar het archetype-model wisselen + daar de ready-flourish.
	var link_pawn: Pawn = GameSession.state.pawns.get(pawn_id)
	var link_card: Card = null
	if link_pawn != null and link_pawn.linked_card_id >= 0:
		link_card = GameSession.state.all_cards.get(link_pawn.linked_card_id)
	get_tree().create_timer(0.14).timeout.connect(func() -> void:
		if not is_instance_valid(pv):
			return
		if link_pawn != null:
			pv.set_character(GameSession.state.doctrine_of(link_pawn.owner_id), link_pawn.unit_type, link_card)
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
	var state: GameState = GameSession.state
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
				_spawn_smoke(pv.position + Vector3(0.0, 0.45, 0.0), puff, 0.2, Vector3.UP * 0.25, 1.3)
			pv.set_character(doctrine, utype, null))  # terug naar base


func _pick_link_pawn(player_id: int) -> Pawn:
	# Bij voorkeur een pion met ademruimte (kan bewegen/aanvallen); anders
	# eindig je met ingeklemde achterste-rij pionnen die niks kunnen.
	var fallback: Pawn = null
	for pawn in GameSession.state.pawns.values():
		if pawn.owner_id != player_id or pawn.is_eliminated or pawn.linked_card_id != -1:
			continue
		if fallback == null:
			fallback = pawn
		if _pawn_has_room(pawn):
			return pawn
	return fallback


func _pawn_has_room(pawn: Pawn) -> bool:
	var state: GameState = GameSession.state
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
	if new_phase == Phase.Type.ACTION:
		_clear_highlights()
	if Phase.is_define(new_phase):
		if Phase.is_linking(old_phase):
			# Laat de zojuist gekoppelde pion(nen) even zien vóór de nieuwe ronde.
			_refresh_all()
			_update_hud("Ronde afgerond")
			await get_tree().create_timer(0.9).timeout
		if GameSession.state.round_number <= 1:
			_clear_footprints()  # nieuwe cyclus: vers slagveld
			_uncouple_cascade()  # gekoppelde stukken poffen snel terug naar base
		Audio.play("phase_change")  # zachte overgang naar een nieuwe definitie-ronde
		var doctrine: Dictionary = GameSession.state.doctrine_data_of(_human_id)
		_card_hand.configure(int(doctrine.cards), int(doctrine.budget), int(doctrine.speed_max))
		_card_hand.open_for_define()
		_update_hud("Definieer je kaarten (%d× budget %d) — HP = leven · Speed = stappen/acties · Aanval = schade" % [
			int(doctrine.cards), int(doctrine.budget)])
		_start_phase_timer(PHASE_TIME_LIMIT)
	elif Phase.is_linking(new_phase):
		_auto_link_human = false
		_highlight_own_unlinked_pawns()  # ringen meteen aan, niet pas na kaart-klik
		_start_phase_timer(PHASE_TIME_LIMIT)
	else:
		_card_hand.visible = false


func _on_turn_changed(player_id: int) -> void:
	var state: GameState = GameSession.state
	if Phase.is_linking(state.phase):
		_refresh_all()
		if player_id == _human_id:
			if _auto_link_human:
				_auto_link(_human_id)
			else:
				_begin_human_linking()
		else:
			_set_turn_prompt("Tegenstander koppelt...", player_id)
			_auto_link(player_id)
	elif state.phase == Phase.Type.ACTION:
		_selected_pawn_id = -1
		_clear_highlights()
		_refresh_all()
		if player_id == _ai_id:
			_stop_phase_timer()
			_set_turn_prompt("Tegenstander is aan zet...", player_id)
			_ai_action_turn()
		else:
			# Beurt-timer voor de mens: tijd om → het spel kiest een zet.
			_start_phase_timer(PHASE_TIME_LIMIT)
			# Audio.play("your_turn")  # staat nu uit
			_set_turn_prompt("Jouw beurt — kies een pion", player_id)


func _ai_action_turn() -> void:
	await get_tree().create_timer(0.3).timeout
	if GameSession.state.phase != Phase.Type.ACTION or GameSession.state.current_player != _ai_id:
		return
	# Reken de AI-zet op een aparte thread → de animaties bevriezen niet.
	var snapshot: GameState = GameSession.state.clone()
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
	if GameSession.state.phase != Phase.Type.ACTION or GameSession.state.current_player != _ai_id:
		return
	if action.is_empty():
		return
	match String(action.type):
		"move":
			GameSession.submit_move(_ai_id, action.pawn_id, action.target)
		"attack":
			GameSession.submit_attack(_ai_id, action.attacker_id, action.defender_id)
		"shot":
			GameSession.submit_shot(_ai_id, action.shooter_id, action.target_id)
		"charge":
			GameSession.submit_charge(_ai_id, action.pawn_id, action.move_target, action.defender_id)


## Wolf-doctrine: na een melee mag de aanvaller 1 gratis stap zetten.
func _on_wolf_step_pending(pawn_id: int) -> void:
	var state: GameState = GameSession.state
	if state.current_player == _ai_id:
		await get_tree().create_timer(0.35).timeout
		if GameSession.state.pending_wolf_step_pawn != pawn_id:
			return
		var step: Dictionary = _ai.choose_wolf_step(GameSession.state)
		if step.has("target"):
			GameSession.submit_wolf_step(_ai_id, step.target)
		else:
			GameSession.skip_wolf_step(_ai_id)
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
	_update_hud("Gratis Wolf-stap — klik een vak (rechtermuis = overslaan)")


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
	var pawn: Pawn = GameSession.state.pawns.get(pawn_id)
	if pawn == null or pawn.is_eliminated:
		return
	if Rules.is_haven_for_player(coord, pawn.owner_id) and Rules.check_win(GameSession.state) == -1:
		Audio.play("haven_score", 0.25)


## Terugslag-geluid: als de terugslaande verdediger een paard is, hoor je het
## paard (hoefgetrappel/hinnik). Bij infanterie-terugslag dekt de melee-klap het al.
func _retaliation_sound(defender_id: int, delay: float) -> void:
	var def: Pawn = GameSession.state.pawns.get(defender_id)
	if def == null:
		return
	if def.unit_type == Constants.UnitType.CAVALRY:
		Audio.play("retaliation_horse", delay)  # paard trapt terug
	else:
		Audio.play("retaliation", delay)  # infanterie: staal-op-staal counter


func _death_sound(pawn_id: int, delay: float) -> void:
	var pawn: Pawn = GameSession.state.pawns.get(pawn_id)
	if pawn == null:
		return
	match pawn.unit_type:
		Constants.UnitType.INFANTRY: Audio.play("inf_die", delay)
		Constants.UnitType.CAVALRY: Audio.play("horse_die", delay)
		Constants.UnitType.ARTILLERY: Audio.play("cannon_die", delay)


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
				# Opruk-choreografie: de aanvaller blijft op zijn eigen vak staan
				# tot ZOWEL zijn eigen stoot-clip klaar is ALS de dood-animatie
				# van de verdediger ver genoeg (opruk-wacht = fractie van de
				# dood-clip; 1.0 = volledig afwachten). Pas daarna + de
				# opruk-vertraging stapt hij het vrijgekomen vak in - dus nooit
				# door een nog-stervende tegenstander heen.
				var move_del: float = hit_del + 0.12
				if attacker != null:
					move_del = maxf(move_del, attacker.last_clip_duration())
				if result.get("eliminated", false) and melee_def != null and attacker != null:
					var dsp: float = melee_def.melee_fx("death_speed", "death_speed", 1.0)
					var death_dur: float = melee_def.clip_duration("die") / maxf(dsp, 0.01)
					move_del = maxf(move_del, hit_del + death_dur * attacker.melee_fx("move_wait", "melee_move_wait", 1.0))
				if attacker != null:
					move_del += attacker.melee_fx("advance_delay", "melee_advance_delay", 0.35)
				get_tree().create_timer(move_del).timeout.connect(
					_animate_move.bind(action.attacker_id, result.attacker_from_pos, result.defender_pos))
			Audio.play("melee_kill" if result.get("eliminated", false) else "melee_survive",
				maxf(hit_del - 0.12, 0.0))
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
				if result.get("attacker_eliminated", false):
					_death_sound(action.attacker_id, ret_del + 0.05)
		"shot":
			var shooter: PawnView = _pawn_views.get(action.shooter_id)
			if shooter != null:
				shooter.face_dir(result.defender_pos - result.attacker_from_pos)
				shooter.play_attack()
			# Projectiel + muzzle flash + rook; de treffer-feedback wacht op de inslag.
			var shooter_pawn: Pawn = GameSession.state.pawns.get(action.shooter_id)
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
			var shot_strength := 1.4 if shooter_type == Constants.UnitType.ARTILLERY else 0.75
			_hit_feedback(action.target_id, result.defender_pos, result.damage, travel + 0.03,
				result.attacker_from_pos, result.get("eliminated", false), shot_strength, "shot")
			if result.get("eliminated", false):
				_death_sound(action.target_id, travel + 0.05)
		"charge":
			Audio.play("charge_yell")  # strijdkreet bij het aanrijden
			var end_pos: Vector2i = result.defender_pos if result.get("forced_move", false) else result.move_target
			if result.get("moved", false) or result.get("forced_move", false):
				_animate_move(action.pawn_id, result.charge_from, end_pos)
			_check_haven_score(action.pawn_id, end_pos)
			var cav: PawnView = _pawn_views.get(action.pawn_id)
			if cav != null and action.get("defender_id", -1) != -1:
				cav.play_melee()
			if action.get("defender_id", -1) != -1:
				# Na de aanrij-animatie: klap op het doelwit, evt. terugslag op het paard.
				Audio.play("melee_kill" if result.get("eliminated", false) else "melee_survive", 0.4)
				_hit_feedback(action.defender_id, result.defender_pos, result.damage, 0.4,
					result.charge_from, result.get("eliminated", false), 0.85)
				if result.get("eliminated", false):
					_death_sound(action.defender_id, 0.5)
				if result.get("retaliation", false):
					_hit_feedback(action.pawn_id, result.move_target, result.get("retaliation_damage", 1), 0.75,
						result.defender_pos, result.get("attacker_eliminated", false), 0.5)
					_retaliation_sound(action.defender_id, 0.75)
					if result.get("attacker_eliminated", false):
						_death_sound(action.pawn_id, 0.8)
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
	{"key": "dust", "label": "stofdeeltjes", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	{"key": "footprints", "label": "voetsporen", "min": 0.0, "max": 1.0, "step": 1.0, "def": 1.0},
	{"key": "footprint_dark", "label": "voetspoor-donkerte", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.32},
	{"key": "wheel_width", "label": "wielspoor-breedte", "min": 0.005, "max": 0.12, "step": 0.001, "def": 0.024},
	{"key": "wheel_base", "label": "wielbasis", "min": 0.05, "max": 0.6, "step": 0.005, "def": 0.17},
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
		fac = Constants.doctrine_name(GameSession.state.doctrine_of(mover.owner_id)).to_lower()
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
func _spawn_smoke(pos: Vector3, count: int, size: float, dir: Vector3 = Vector3.ZERO, life_mult: float = 1.0) -> void:
	PawnView.spawn_powder_smoke(_board, pos, count, size, dir, life_mult)


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
		var hit_pawn: Pawn = GameSession.state.pawns.get(pawn_id)
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
	Engine.time_scale = 0.05
	await get_tree().create_timer(secs, true, false, true).timeout
	Engine.time_scale = 1.0
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


func _animate_move(pawn_id: int, from_coord: Vector2i, to_coord: Vector2i) -> void:
	var pv: PawnView = _pawn_views.get(pawn_id)
	if pv == null:
		return
	pv.face_dir(to_coord - from_coord)
	pv.play_walk()
	var start := tile_position(from_coord.x, from_coord.y) + Vector3(0.0, PAWN_Y, 0.0)
	var end := tile_position(to_coord.x, to_coord.y) + Vector3(0.0, PAWN_Y, 0.0)
	pv.position = start
	_tweening_pawns[pawn_id] = true
	var dist: int = absi(to_coord.x - from_coord.x) + absi(to_coord.y - from_coord.y)
	var dur := clampf(0.13 * float(dist), 0.13, 0.45)
	# Beweeggeluid afhankelijk van het eenheidstype. Cavalerie: één galop-clip
	# per beweging (bevat zelf al meerdere hoefslagen). Infanterie/artillerie:
	# één klap per gelopen vakje (losse voetstappen / wielrollen).
	var mover: Pawn = GameSession.state.pawns.get(pawn_id)
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
		pv.play_idle())


func _on_game_over(winner_id: int) -> void:
	_clear_highlights()
	_card_hand.visible = false
	Audio.stop_music()  # sting krijgt de ruimte; ambience loopt door
	Audio.play("win_fanfare" if winner_id == _human_id else "lose_sting", 0.3)
	_update_hud("%s wint!" % _player_name(winner_id))
	_overlay.show_choice(
		"%s wint!" % _player_name(winner_id),
		"Het spel is afgelopen.",
		["Nieuw spel"],
		func(_i: int) -> void: _show_difficulty_menu(),
	)


# --- Human input (actiefase) -------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_K:  # screen shake aan/uit (motion sickness)
				_screen_shake = not _screen_shake
				_update_hud("Screen shake: %s" % ("aan" if _screen_shake else "uit"))
			KEY_J:  # alle combat-feel (stagger/hitstop/vonken/ragdoll) aan/uit
				_combat_feel = not _combat_feel
				_update_hud("Combat feel: %s" % ("aan" if _combat_feel else "uit"))
			KEY_M:  # geluid dempen
				Audio.set_enabled(not Audio.enabled)
				_update_hud("Geluid: %s" % ("aan" if Audio.enabled else "uit"))
			KEY_L:  # sfeer-paneel: belichting/ambiance live tunen
				_toggle_ambiance_panel()
		return
	if event is InputEventMouseMotion:
		if _placement_mode:
			_update_placement_ghost((event as InputEventMouseMotion).position)
			return
		_update_hover((event as InputEventMouseMotion).position)
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	var state: GameState = GameSession.state
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
				GameSession.submit_wolf_step(_human_id, step_coord)
				return
		_end_wolf_step_mode()
		GameSession.skip_wolf_step(_human_id)
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
	var state: GameState = GameSession.state
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
		GameSession.submit_attack(_human_id, _selected_pawn_id, pawn_id)
	elif _selected_pawn_id >= 0 and _valid_charges.has(pawn_id):
		GameSession.submit_charge(_human_id, _selected_pawn_id, _valid_charges[pawn_id], pawn_id)
	elif _selected_pawn_id >= 0 and _valid_shots.has(pawn_id):
		GameSession.submit_shot(_human_id, _selected_pawn_id, pawn_id)


func _update_piece_counts() -> void:
	var state: GameState = GameSession.state
	var red: int = state.get_alive_pawns_for(Constants.PLAYER_1).size()
	var blue: int = state.get_alive_pawns_for(Constants.PLAYER_2).size()
	var total_red: int = Constants.pawn_total(state.doctrine_of(Constants.PLAYER_1))
	var total_blue: int = Constants.pawn_total(state.doctrine_of(Constants.PLAYER_2))
	_count_label.text = "[color=#f07068]● %d/%d[/color]    [color=#5a9cff]● %d/%d[/color]" % [
		red, total_red, blue, total_blue]


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
	_set_turn_prompt("Jouw beurt — kies een pion", _human_id)


func _on_tile_clicked(coord: Vector2i) -> void:
	if _selected_pawn_id >= 0 and _valid_moves.has(coord):
		GameSession.submit_move(_human_id, _selected_pawn_id, coord)


func _select_pawn(pawn_id: int) -> void:
	var state: GameState = GameSession.state
	if not Rules.can_pawn_act(state, pawn_id):
		Audio.play("ui_error")
		_update_hud("Die pion kan niet handelen")
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
	var hint := "groen = beweeg"
	match pawn.unit_type:
		Constants.UnitType.INFANTRY:
			if pawn.attack_value >= 2:
				hint += ", rood = melee, oranje = schot (afstand 2, schade %d)" % Rules.shot_damage(pawn)
			else:
				hint += ", rood = melee (Aanval 1: schieten kan niet)"
		Constants.UnitType.CAVALRY:
			hint += ", rood = charge (bewegen + aanval in één)"
		Constants.UnitType.ARTILLERY:
			if _valid_shots.is_empty():
				hint += " (1 stap), oranje = vuurlijn (dracht %d) — geen doelwit in zicht" % Constants.ARTILLERY_RANGE
			else:
				hint += " (1 stap), oranje = vuur (dracht %d)" % Constants.ARTILLERY_RANGE
	_update_hud("%s gekozen — %s (stamina %d)" % [Constants.unit_type_name(pawn.unit_type), hint, pawn.remaining_stamina])


## Voor elke vijand die via een charge bereikbaar is: de beste (kortste) zet
## naar een vak naast die vijand. Aangrenzende vijanden vallen onder melee.
## LET OP: de charge kost stappen + 1 (de aanval) — alleen betaalbare charges tonen,
## anders staat er een rode vijand die bij het klikken "blijft staan".
func _compute_charge_targets(state: GameState, pawn_id: int, move_paths: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var best_cost: Dictionary = {}
	var stamina: int = state.pawns[pawn_id].remaining_stamina
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
	var state: GameState = GameSession.state
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
	var state: GameState = GameSession.state
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
	var state: GameState = GameSession.state
	_top_label.text = "Cyclus %d · Ronde %d · %s" % [
		state.cycle, state.round_number, _phase_label(state.phase)
	]
	if prompt != "":
		_prompt_label.text = prompt
		_prompt_label.add_theme_color_override("font_color", Color(0.8, 0.84, 0.92))


func _phase_label(phase: int) -> String:
	if phase == Phase.Type.PLACEMENT:
		return "Opstelling"
	if Phase.is_define(phase):
		return "Definitie"
	if Phase.is_reveal(phase):
		return "Onthulling"
	if Phase.is_linking(phase):
		return "Koppelen"
	if phase == Phase.Type.ACTION:
		return "Actie"
	if phase == Phase.Type.GAME_OVER:
		return "Einde"
	return ""


func _player_name(player_id: int) -> String:
	return "Rood (jij)" if player_id == _human_id else "Blauw (AI)"


func _player_color(player_id: int) -> Color:
	return Color(0.95, 0.45, 0.45) if player_id == _human_id else Color(0.45, 0.62, 1.0)


## Prompt met de kleur van wie aan zet is (rood = jij, blauw = AI).
func _set_turn_prompt(text: String, player_id: int) -> void:
	_update_hud()
	_prompt_label.text = text
	_prompt_label.add_theme_color_override("font_color", _player_color(player_id))
