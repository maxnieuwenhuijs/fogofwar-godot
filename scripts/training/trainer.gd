extends Control

# AI-trainer dashboard: speelt 4 potjes tegelijk (uitdager vs kampioen), leert
# de eval-gewichten via hill-climbing self-play, en vertelt in spreektaal wat er
# gebeurt. Snelheid instelbaar; pauzeerbaar; terug naar het spel.

const AIScript := preload("res://scripts/ai/AIMedium.gd")
const GAMES_PER_GEN := 8  # balans: betrouwbaar signaal, maar ~2× sneller dan 16
const MAX_POOL := 8
const EVAL_GAMES := 4   # kampioen vs baseline, voor de kracht-grafiek
const ADOPT_MARGIN := 2 # uitdager moet met ≥2 potjes verschil winnen (geen geluk)

const KEY_PHRASE := {
	"haven": "pionnen in de haven krijgen",
	"prox_scale": "oprukken naar de haven",
	"prox_second": "een tweede pion mee laten oprukken",
	"guard": "de winvakjes bewaken",
	"material": "pionnen in leven houden",
	"cav_value": "cavalerie in leven houden",
	"art_value": "kanonnen in leven houden",
	"hp": "sterke (hoge-HP) pionnen",
	"protect": "je pionnen beschermen tegen melee",
	"ranged": "vuurlijnen op de vijand houden (schot-dreiging)",
	"reach": "de haven kunnen bereiken / de vijand de weg versperren",
	"card_atk": "aanvallende kaarten (om het initiatief te pakken)",
	"card_hp": "sterke (hoge-HP) kaarten om te overleven",
	"card_stam": "snelle (hoge-stamina) kaarten om weg te komen",
	"r3_initiative": "in ronde 3 harder vechten om het initiatief (als eerste mogen slaan)",
	"art_front": "kanonnen vooraan opstellen",
	"art_center": "kanonnen in het centrum (vs op de flank)",
	"cav_front": "cavalerie vooraan opstellen",
	"cav_center": "cavalerie in het centrum (vs op de flank)",
	"inf_front": "infanterie vooraan opstellen",
	"inf_center": "infanterie in het centrum (vs op de flank)",
	"aff_inf_hp": "taaie kaarten op infanterie (terugslag-muur)",
	"aff_inf_spd": "snelle kaarten op infanterie",
	"aff_inf_atk": "aanvalskaarten op infanterie (melee + schot)",
	"aff_cav_hp": "taaie kaarten op cavalerie",
	"aff_cav_spd": "snelle kaarten op cavalerie (charge-bereik)",
	"aff_cav_atk": "aanvalskaarten op cavalerie",
	"aff_art_hp": "taaie kaarten op kanonnen",
	"aff_art_spd": "snelle kaarten op kanonnen (meer acties)",
	"aff_art_atk": "aanvalskaarten op kanonnen (zware granaten)",
	"link_advance": "koppelen aan pionnen die al ver opgerukt zijn",
}

# Kampioen/uitdager zijn PROFIELEN: per doctrine een eigen gewichtenset
# (doctrine-int -> weights). Elke generatie muteert één factie; de uitdager
# speelt die factie dan ook (anders meet je alleen ruis).
var _champion: Dictionary
var _challenger: Dictionary
var _mutated_doctrine: int = 0
var _last_change_desc: String = ""
var _generation: int = 0
var _adoptions: int = 0

var _runners: Array[MatchRunner] = []
var _boards: Array[MiniBoard] = []
var _chal_side: Array[int] = []
var _chal_wins: int = 0
var _champ_wins: int = 0
var _draws: int = 0

var _steps_per_frame: int = 1
var _paused: bool = false

var _pool: Array = []          # oude kampioenen om robuust tegen te trainen
var _baseline: Dictionary      # de originele start-AI (vast ijkpunt)
var _eval_runners: Array = []  # kampioen vs baseline (gestapeld, voor de grafiek)
var _eval_side: Array = []
var _eval_running: bool = false
var _eval_is_new: bool = false
var _eval_champ_wins: int = 0
var _log: RichTextLabel
var _stats: Label
var _speed_label: Label
var _graph = null


func _ready() -> void:
	_build_ui()
	# Ga verder waar we gebleven waren: laad het opgeslagen per-factie-profiel.
	var saved := AIController.load_profile()
	if saved.is_empty():
		_champion = AIController.default_profile()
		_log_line("[b]AI Trainer gestart.[/b] Kampioen begint met de handmatige (default) gewichten — per factie een eigen set.")
	else:
		_champion = saved
		_log_line("[b]AI Trainer gestart.[/b] Opgeslagen per-factie-profiel geladen — training gaat verder.")
		_log_line("[color=#9fb4d4]Mens-set: %s[/color]" % _weights_str(_champion[int(Constants.Doctrine.MENS)]))
	# Baseline = originele start-AI (vast ijkpunt voor de grafiek).
	_baseline = AIController.default_profile()
	# Pool: baseline + huidige kampioen (groeit met elke verbetering).
	_pool = [_deep_copy(_baseline), _deep_copy(_champion)]
	_start_eval(false)  # startpunt: huidige kampioen vs baseline
	_start_generation()


func _exit_tree() -> void:
	_clear_runners()
	_clear_eval_runners()


func _process(_delta: float) -> void:
	if _paused:
		return
	for i in _runners.size():
		var r: MatchRunner = _runners[i]
		var budget := _steps_per_frame
		while budget > 0 and not r.done:
			r.step()
			budget -= 1
		if i < _boards.size():
			_boards[i].set_state(r.state())
	# Evaluatie-batch (kampioen vs baseline) stapt mee op de achtergrond.
	if _eval_running:
		var eval_done := true
		for er in _eval_runners:
			var eb := clampi(_steps_per_frame, 8, 25)  # bounded: nooit te zware frames
			while eb > 0 and not er.done:
				er.step()
				eb -= 1
			if not er.done:
				eval_done = false
		if eval_done:
			_finish_eval()
	var all_done := true
	for r in _runners:
		if not r.done:
			all_done = false
			break
	_update_stats()
	if all_done:
		_finish_generation()


# --- Generatie-lus -----------------------------------------------------------

func _start_generation() -> void:
	_generation += 1
	_challenger = _mutate(_champion)
	_chal_wins = 0
	_champ_wins = 0
	_draws = 0
	_log_line("[b]Generatie %d[/b] — probeer: %s" % [_generation, _last_change_desc])
	_clear_runners()
	var doctrines: Array = Constants.DOCTRINE_DATA.keys()
	for i in GAMES_PER_GEN:
		# Speel om en om als P1/P2, tegen de huidige kampioen (spel 0) en tegen
		# willekeurige oude kampioenen uit de pool (variatie → geen overfit).
		# De UITDAGER speelt altijd de gemuteerde factie (daar zit het signaal);
		# de tegenstander krijgt per potje een willekeurige factie.
		var chal_is_p1: bool = i % 2 == 0
		var opp_profile: Dictionary = _champion if i == 0 else _pool[randi() % _pool.size()]
		var opp_doctrine: int = doctrines[randi() % doctrines.size()]
		var chal_ai = AIScript.new()
		chal_ai.weights = (_challenger[_mutated_doctrine] as Dictionary).duplicate()
		var opp_ai = AIScript.new()
		opp_ai.weights = (opp_profile[opp_doctrine] as Dictionary).duplicate()
		var a1 = chal_ai if chal_is_p1 else opp_ai
		var a2 = opp_ai if chal_is_p1 else chal_ai
		var d1: int = _mutated_doctrine if chal_is_p1 else opp_doctrine
		var d2: int = opp_doctrine if chal_is_p1 else _mutated_doctrine
		var runner := MatchRunner.new(a1, a2, d1, d2)
		_runners.append(runner)
		_chal_side.append(Constants.PLAYER_1 if chal_is_p1 else Constants.PLAYER_2)
		if i < _boards.size():
			_boards[i].set_state(runner.state())


func _finish_generation() -> void:
	for i in _runners.size():
		var w: int = _runners[i].winner
		if w == -1:
			_draws += 1
		elif w == _chal_side[i]:
			_chal_wins += 1
		else:
			_champ_wins += 1
	var adopted: bool = (_chal_wins - _champ_wins) >= ADOPT_MARGIN
	if adopted:
		_champion = _challenger
		_pool.append(_deep_copy(_champion))
		if _pool.size() > MAX_POOL:
			_pool.remove_at(1)  # houd [0] = baseline, laat de oudste kampioen vallen
		_adoptions += 1
		AIController.save_profile(_champion)
		_log_line("[color=#7fe08a]✔ Uitdager wint de pool %d-%d (%d gelijk) → nieuwe kampioen! De AI leert: %s[/color]" % [
			_chal_wins, _champ_wins, _draws, _last_change_desc])
		_log_line("[color=#78d0ff]💾 Automatisch opgeslagen → res://data/ai_weights.json (het spel gebruikt dit).[/color]")
	else:
		var verdict := "geen overtuigende winst (marge < %d)" % ADOPT_MARGIN if _chal_wins > _champ_wins else "verliest de pool"
		_log_line("[color=#e58a8a]✗ Uitdager %s: %d-%d (%d gelijk) → kampioen blijft.[/color]" % [
			verdict, _chal_wins, _champ_wins, _draws])
	if adopted:
		_start_eval(true)  # meet de nieuwe kampioen tegen de baseline
	_start_generation()


## Muteer één gewicht van één factie en beschrijf de verandering in spreektaal.
## De gemuteerde factie wordt onthouden zodat de uitdager ermee speelt.
func _mutate(profile: Dictionary) -> Dictionary:
	var out := _deep_copy(profile)
	var doctrines: Array = out.keys()
	_mutated_doctrine = doctrines[randi() % doctrines.size()]
	var w: Dictionary = out[_mutated_doctrine]
	var keys := w.keys()
	var k: String = keys[randi() % keys.size()]
	var old_v: float = w[k]
	# Altijd een betekenisvolle stap (min ±12%), nooit bijna-geen-verandering.
	# Multiplicatief → het teken blijft behouden (flankvoorkeuren zijn negatief).
	var factor: float = randf_range(1.12, 1.5) if randf() < 0.5 else randf_range(0.55, 0.88)
	var new_v: float = old_v * factor
	if absf(new_v) < 0.01:
		new_v = 0.01 if new_v >= 0.0 else -0.01
	w[k] = new_v
	var dir := "méér" if new_v > old_v else "minder"
	_last_change_desc = "bij de [b]%s[/b]: %s nadruk op %s (%s → %s)" % [
		Constants.doctrine_name(_mutated_doctrine), dir, KEY_PHRASE.get(k, k), _fmt(old_v), _fmt(new_v)]
	return out


## Diepe kopie van een profiel (doctrine -> weights-dict).
func _deep_copy(profile: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for d in profile:
		out[d] = (profile[d] as Dictionary).duplicate()
	return out


func _fmt(v: float) -> String:
	return str(snappedf(v, 0.01))


func _clear_runners() -> void:
	for r in _runners:
		r.dispose()
	_runners.clear()
	_chal_side.clear()


# --- Kracht-evaluatie: kampioen vs baseline (voor de grafiek) -----------------

func _start_eval(is_new: bool) -> void:
	if _eval_running:
		return
	_eval_running = true
	_eval_is_new = is_new
	_eval_champ_wins = 0
	_clear_eval_runners()
	# Vaste matchup-rotatie (geen ruis in de kracht-grafiek): alle 6 doctrines
	# komen langs, kampioen wisselt van kant.
	var eval_matchups: Array = [
		[Constants.Doctrine.MENS, Constants.Doctrine.MENS],
		[Constants.Doctrine.MUIS, Constants.Doctrine.LEEUW],
		[Constants.Doctrine.BEER, Constants.Doctrine.WOLF],
		[Constants.Doctrine.VOS, Constants.Doctrine.MENS],
	]
	for i in EVAL_GAMES:
		var champ_p1: bool = i % 2 == 0
		var pair: Array = eval_matchups[i % eval_matchups.size()]
		var champ_doctrine: int = pair[0] if champ_p1 else pair[1]
		var base_doctrine: int = pair[1] if champ_p1 else pair[0]
		var ca = AIScript.new()
		ca.weights = (_champion[champ_doctrine] as Dictionary).duplicate()
		var ba = AIScript.new()
		ba.weights = (_baseline[base_doctrine] as Dictionary).duplicate()
		var a1 = ca if champ_p1 else ba
		var a2 = ba if champ_p1 else ca
		var r := MatchRunner.new(a1, a2, pair[0], pair[1])
		_eval_runners.append(r)
		_eval_side.append(Constants.PLAYER_1 if champ_p1 else Constants.PLAYER_2)


func _finish_eval() -> void:
	for i in _eval_runners.size():
		if _eval_runners[i].winner == _eval_side[i]:
			_eval_champ_wins += 1
	var strength: float = float(_eval_champ_wins) / float(EVAL_GAMES)
	if _graph != null:
		_graph.push(strength, _eval_is_new)
	_eval_running = false
	_clear_eval_runners()


func _clear_eval_runners() -> void:
	for r in _eval_runners:
		r.dispose()
	_eval_runners.clear()
	_eval_side.clear()


# --- UI ----------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "AI Trainer — self-play over alle facties (4 potjes tegelijk)"
	title.add_theme_font_size_override("font_size", 34)
	title.position = Vector2(30, 14)
	add_child(title)

	var legend := Label.new()
	legend.text = "● soldaat    ▲ paard    ▮ kanon    ·    rood = P1, blauw = P2, donker = slapend (geen kaart)"
	legend.add_theme_font_size_override("font_size", 20)
	legend.add_theme_color_override("font_color", Color(0.72, 0.76, 0.85))
	legend.position = Vector2(30, 58)
	add_child(legend)

	var back := Button.new()
	back.text = "← Terug"
	back.position = Vector2(860, 20)
	back.custom_minimum_size = Vector2(190, 52)
	back.pressed.connect(_on_back)
	add_child(back)

	# 4 mini-borden in 2×2
	var bsize := 490.0
	var positions := [Vector2(40, 90), Vector2(550, 90), Vector2(40, 590), Vector2(550, 590)]
	for i in positions.size():
		var mb := MiniBoard.new()
		mb.position = positions[i]
		mb.custom_minimum_size = Vector2(bsize, bsize)
		mb.size = Vector2(bsize, bsize)
		add_child(mb)
		_boards.append(mb)

	_stats = Label.new()
	_stats.position = Vector2(40, 1095)
	_stats.custom_minimum_size = Vector2(1000, 60)
	_stats.add_theme_font_size_override("font_size", 22)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD
	_stats.size = Vector2(1000, 120)
	add_child(_stats)

	var graph_label := Label.new()
	graph_label.text = "Kracht kampioen vs start-AI (boven 50% = sterker geworden; groen = nieuwe kampioen)"
	graph_label.position = Vector2(40, 1230)
	graph_label.add_theme_font_size_override("font_size", 20)
	add_child(graph_label)

	_graph = preload("res://scripts/training/train_graph.gd").new()
	_graph.position = Vector2(40, 1265)
	_graph.size = Vector2(1000, 150)
	add_child(_graph)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.position = Vector2(40, 1430)
	_log.size = Vector2(1000, 300)
	_log.add_theme_font_size_override("normal_font_size", 22)
	add_child(_log)

	# Snelheid + pauze
	_speed_label = Label.new()
	_speed_label.position = Vector2(40, 1748)
	_speed_label.custom_minimum_size = Vector2(300, 40)
	add_child(_speed_label)

	_add_button("Langzamer", Vector2(40, 1798), func() -> void: _change_speed(-10))
	_add_button("Pauze", Vector2(260, 1798), _toggle_pause)
	_add_button("Sneller", Vector2(480, 1798), func() -> void: _change_speed(10))
	_add_button("Bewaar kampioen", Vector2(700, 1798), _on_save_champion)
	_update_speed_label()


func _on_save_champion() -> void:
	AIController.save_profile(_champion)
	_log_line("[color=#78d0ff]💾 Kampioen (per-factie-profiel) opgeslagen — het spel gebruikt deze gewichten nu.[/color]")


func _add_button(text: String, pos: Vector2, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = Vector2(200, 56)
	b.pressed.connect(cb)
	add_child(b)


func _change_speed(delta: int) -> void:
	_steps_per_frame = clampi(_steps_per_frame + delta, 1, 400)
	_update_speed_label()


func _toggle_pause() -> void:
	_paused = not _paused
	_update_speed_label()


func _update_speed_label() -> void:
	_speed_label.text = "Snelheid: %d stappen/frame%s" % [_steps_per_frame, "  (gepauzeerd)" if _paused else ""]


func _update_stats() -> void:
	_stats.text = "Generatie %d · kampioen %d× verbeterd · pool: %d · deze ronde uitdager (%s) %d - pool %d\nKampioen Mens-set: %s" % [
		_generation, _adoptions, _pool.size(), Constants.doctrine_name(_mutated_doctrine),
		_chal_wins, _champ_wins, _weights_str(_champion[int(Constants.Doctrine.MENS)])]


func _weights_str(w: Dictionary) -> String:
	return "haven %s · oprukken %s · bewaken %s · materiaal %s · hp %s · bescherming %s" % [
		_fmt(w.haven), _fmt(w.prox_scale), _fmt(w.guard), _fmt(w.material), _fmt(w.hp), _fmt(w.protect)]


func _log_line(bb: String) -> void:
	_log.append_text(bb + "\n")


func _on_back() -> void:
	_clear_runners()
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")
