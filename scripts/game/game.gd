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
# Combat feel (Valheim-stijl "juice"): stagger + screen shake + hitstop + ragdoll.
var _combat_feel: bool = true         # alles behalve shake
var _screen_shake: bool = true        # apart uitzetbaar (motion sickness)
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
	_camera = _board.get_node("Camera3D") as Camera3D
	_cam_base = _camera.position  # rustpositie voor de screen shake
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


func _start_phase_timer(seconds: float) -> void:
	_timer_active = true
	_timer_left = seconds


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
		["Easy", "Medium", "Hard", "Ultra — god mode", "Speluitleg", "AI Trainer bekijken"],
		_on_menu_choice,
	)


func _on_menu_choice(index: int) -> void:
	if index == 4:
		_show_rules_overlay(func() -> void: _show_difficulty_menu())
	elif index >= 5:
		get_tree().change_scene_to_file("res://scenes/training/Trainer.tscn")
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
		"Vast voor de hele partij. De AI kiest blind een eigen doctrine.\nSamenstelling = Infanterie / Cavalerie / Artillerie.\n\n" + "\n".join(lines),
		names,
		_on_doctrine_choice,
		Color.WHITE, true,
	)


func _on_doctrine_choice(index: int) -> void:
	_human_doctrine = Constants.DOCTRINE_DATA.keys()[index]
	# Blinde, gelijktijdige keuze (v4.1 §4.1): de AI kiest onafhankelijk.
	_ai_doctrine = Constants.DOCTRINE_DATA.keys()[randi() % Constants.DOCTRINE_DATA.size()]
	_start_match(ai_difficulty)


func _start_match(difficulty: int) -> void:
	_overlay.hide()
	# Combat-feel-state resetten (voor het geval een vorige partij midden in een
	# hitstop/ragdoll eindigde).
	Engine.time_scale = 1.0
	_in_hitstop = false
	_shake_amt = 0.0
	_dying_views.clear()
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
	GameSession.game_over.connect(_on_game_over)


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
const HP_BLOCK_SIZE := 8.25
const HP_BLOCK_GAP := 1.5
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
		var screen := _camera.unproject_position(pv.global_position + Vector3(0.0, 1.55, 0.0))
		entry.holder.visible = true
		entry.holder.position = screen - Vector2(total_w * 0.5, total_h + 4.0)
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
		pv.set_stats_label(pawn.is_active, pawn.current_hp, pawn.remaining_stamina)
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

func _on_cards_revealed(t1: Dictionary, t2: Dictionary, initiative_winner: int, _needs_rps: bool) -> void:
	var body := "Jij (rood): bod %d%% · aanval %d · speed %d\nAI (blauw): bod %d%% · aanval %d · speed %d\n\nHet hoogste aanval-bod krijgt het initiatief:\ndie speler koppelt én handelt straks als eerste." % [
		int(round(float(t1.get("bid", 0.0)) * 100.0)), int(t1.attack), int(t1.stamina),
		int(round(float(t2.get("bid", 0.0)) * 100.0)), int(t2.attack), int(t2.stamina),
	]
	var title := "%s begint met koppelen" % _player_name(initiative_winner)
	var accent := _player_color(initiative_winner)
	_update_hud("Onthulling")
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
	_selected_link_card_id = -1
	_clear_highlights()


func _highlight_own_unlinked_pawns() -> void:
	_clear_highlights()
	var coords: Array = []
	for pawn in GameSession.state.pawns.values():
		if pawn.owner_id == _human_id and not pawn.is_eliminated and pawn.linked_card_id == -1:
			coords.append(pawn.position)
	_highlight_tiles(coords, Color(0.3, 0.7, 1.0))


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
	var pv: PawnView = _pawn_views.get(pawn_id)
	if pv == null:
		return
	pv.flash_ring(Color(0.5, 0.85, 1.0))
	_tweening_pawns[pawn_id] = true
	var base_y := pv.position.y
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(pv, "position:y", base_y + 0.35, 0.13).set_ease(Tween.EASE_OUT)
	tween.tween_property(pv, "position:y", base_y, 0.17).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _tweening_pawns.erase(pawn_id))


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
		var doctrine: Dictionary = GameSession.state.doctrine_data_of(_human_id)
		_card_hand.configure(int(doctrine.cards), int(doctrine.budget), int(doctrine.speed_max))
		_card_hand.open_for_define()
		_update_hud("Definieer je kaarten (%d× budget %d) — HP = leven · Speed = stappen/acties · Aanval = schade" % [
			int(doctrine.cards), int(doctrine.budget)])
		_start_phase_timer(PHASE_TIME_LIMIT)
	elif Phase.is_linking(new_phase):
		_auto_link_human = false
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
func _death_sound(pawn_id: int, delay: float) -> void:
	var pawn: Pawn = GameSession.state.pawns.get(pawn_id)
	if pawn == null:
		return
	match pawn.unit_type:
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
		"attack":
			var attacker: PawnView = _pawn_views.get(action.attacker_id)
			if attacker != null:
				attacker.face_dir(result.defender_pos - result.attacker_from_pos)
				attacker.play_attack()
			if result.get("forced_move", false):
				_animate_move(action.attacker_id, result.attacker_from_pos, result.defender_pos)
			Audio.play("melee_kill" if result.get("eliminated", false) else "melee_survive")
			_hit_feedback(action.defender_id, result.defender_pos, result.damage, 0.12,
				result.attacker_from_pos, result.get("eliminated", false), 0.7)
			if result.get("eliminated", false):
				_death_sound(action.defender_id, 0.12)
			if result.get("retaliation", false):
				# Terugslag: de aanvaller krijgt even later zelf schade te zien.
				_hit_feedback(action.attacker_id, result.attacker_from_pos, result.get("retaliation_damage", 1), 0.45,
					result.defender_pos, result.get("attacker_eliminated", false), 0.5)
				if result.get("attacker_eliminated", false):
					_death_sound(action.attacker_id, 0.5)
		"shot":
			var shooter: PawnView = _pawn_views.get(action.shooter_id)
			if shooter != null:
				shooter.face_dir(result.defender_pos - result.attacker_from_pos)
				shooter.play_attack()
			# Projectiel + muzzle flash + rook; de treffer-feedback wacht op de inslag.
			var shooter_pawn: Pawn = GameSession.state.pawns.get(action.shooter_id)
			var shooter_type: int = shooter_pawn.unit_type if shooter_pawn != null else Constants.UnitType.INFANTRY
			var travel: float = _fire_projectile(result.attacker_from_pos, result.defender_pos, shooter_type)
			# Geluid: afvuren nu, inslag bij aankomst van het projectiel.
			if shooter_type == Constants.UnitType.ARTILLERY:
				Audio.play("cannon_fire")
				Audio.play("cannon_air", 0.04)
				Audio.play("cannon_hit", travel)
			else:
				Audio.play("musket_fire")
				Audio.play("musket_echo", 0.18)
				Audio.play("musket_hit", travel)
			var shot_strength := 1.4 if shooter_type == Constants.UnitType.ARTILLERY else 0.75
			_hit_feedback(action.target_id, result.defender_pos, result.damage, travel + 0.03,
				result.attacker_from_pos, result.get("eliminated", false), shot_strength)
			if result.get("eliminated", false):
				_death_sound(action.target_id, travel + 0.05)
		"charge":
			var end_pos: Vector2i = result.defender_pos if result.get("forced_move", false) else result.move_target
			if result.get("moved", false) or result.get("forced_move", false):
				_animate_move(action.pawn_id, result.charge_from, end_pos)
			var cav: PawnView = _pawn_views.get(action.pawn_id)
			if cav != null and action.get("defender_id", -1) != -1:
				cav.play_attack()
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
					if result.get("attacker_eliminated", false):
						_death_sound(action.pawn_id, 0.8)
		"wolf_step":
			_animate_move(action.pawn_id, action.from, action.target)
	_refresh_all()


# --- Schiet-VFX (prototype, low-poly): projectiel + muzzle flash + rook --------

## Vuur een projectiel af van vak naar vak. Kanon: grote donkere kogel met een
## boogje; infanterie: klein fel tracer-bolletje, strak en snel.
## Retour: de reistijd, zodat de treffer-feedback op de inslag kan wachten.
func _fire_projectile(from_coord: Vector2i, to_coord: Vector2i, unit_type: int) -> float:
	var start: Vector3 = tile_position(from_coord.x, from_coord.y)
	var end: Vector3 = tile_position(to_coord.x, to_coord.y)
	var flat_dir: Vector3 = (end - start).normalized()
	var is_cannon: bool = unit_type == Constants.UnitType.ARTILLERY
	var muzzle: Vector3 = start + flat_dir * 0.35 + Vector3(0.0, 0.55 if is_cannon else 0.85, 0.0)
	var target: Vector3 = end + Vector3(0.0, 0.55, 0.0)
	var dur: float = clampf(0.06 * (end - start).length(), 0.12, 0.45)

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

	# Kanonskogel krijgt een klein boogje; infanterie schiet strak.
	var arc: float = 0.6 if is_cannon else 0.0
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: proj.position = muzzle.lerp(target, t) + Vector3.UP * (arc * 4.0 * t * (1.0 - t)), 0.0, 1.0, dur)
	tween.tween_callback(proj.queue_free)

	_muzzle_flash(muzzle, is_cannon)
	_spawn_smoke(muzzle, 4 if is_cannon else 2, 0.16 if is_cannon else 0.09)
	# Inslag-rook zodra het projectiel aankomt.
	var impact_count: int = 3 if is_cannon else 2
	var impact_size: float = 0.14 if is_cannon else 0.08
	get_tree().create_timer(dur).timeout.connect(func() -> void: _spawn_smoke(target, impact_count, impact_size))
	return dur


## Korte felle flits + lichtpuls aan de loop.
func _muzzle_flash(pos: Vector3, big: bool) -> void:
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
	flash.position = pos
	flash.scale = Vector3.ONE * 0.5
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.35)
	light.light_energy = 2.6 if big else 1.6
	light.omni_range = 2.6
	flash.add_child(light)
	_board.add_child(flash)
	var tween := create_tween().set_parallel()
	tween.tween_property(flash, "scale", Vector3.ONE * (2.0 if big else 1.4), 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.14).set_ease(Tween.EASE_IN)
	tween.tween_property(light, "light_energy", 0.0, 0.14)
	tween.chain().tween_callback(flash.queue_free)


## Low-poly rookwolkjes: paar grijze bolletjes die opstijgen, groeien en vervagen.
func _spawn_smoke(pos: Vector3, count: int, size: float) -> void:
	for i in count:
		var puff := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radial_segments = 8
		mesh.rings = 4
		var radius: float = size * randf_range(0.75, 1.2)
		mesh.radius = radius
		mesh.height = radius * 2.0
		puff.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.64, 0.64, 0.68, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.material_override = mat
		puff.position = pos + Vector3(randf_range(-0.08, 0.08), randf_range(0.0, 0.08), randf_range(-0.08, 0.08))
		_board.add_child(puff)
		var drift := Vector3(randf_range(-0.22, 0.22), randf_range(0.35, 0.6), randf_range(-0.22, 0.22))
		var life: float = randf_range(0.55, 0.8)
		var tween := create_tween().set_parallel()
		tween.tween_property(puff, "position", puff.position + drift, life).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "scale", Vector3.ONE * 1.9, life)
		tween.tween_property(mat, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(puff.queue_free)


## Treffer-feedback (de "Hit"-fase). Op het inslagmoment (na `delay`): witte flits,
## stagger/knockback, vonken, screen shake, hitstop en een opstijgend "-N"-label.
## Bij `killed` een lichte ragdoll i.p.v. de flits.
## `from_coord` bepaalt de knockback-richting (weg van de aanvaller).
func _hit_feedback(pawn_id: int, coord: Vector2i, damage: int, delay: float = 0.12,
		from_coord: Vector2i = Vector2i(-1, -1), killed: bool = false, strength: float = 0.7) -> void:
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
		_kill_view(pawn_id, world_dir)
	else:
		var pv: PawnView = _pawn_views.get(pawn_id)
		if pv != null and pv.visible:
			pv.flash_hit()
			pv.stagger(world_dir)
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
func _kill_view(pawn_id: int, world_dir: Vector3) -> void:
	_dying_views.erase(pawn_id)
	var pv: PawnView = _pawn_views.get(pawn_id)
	if pv == null:
		return
	_pawn_views.erase(pawn_id)
	if pv.visible:
		pv.play_death(world_dir)  # ruimt zichzelf op (queue_free)
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
	# Sfeer bij selectie: haan spannen (infanterie die kan schieten) / paard (cavalerie).
	if pawn.unit_type == Constants.UnitType.INFANTRY \
			and not Rules.get_valid_shot_targets(state, pawn_id).is_empty():
		Audio.play("musket_cock")
	elif pawn.unit_type == Constants.UnitType.CAVALRY:
		Audio.play("horse_select")
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
	_hovered_pawn_id = hovered
	if hovered >= 0 and _pawn_views.has(hovered):
		_pawn_views[hovered].set_hovered(true)


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
