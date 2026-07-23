class_name AgentL2
extends Agent

# L2 — de bestaande gewichten-eval (AIController/AIMedium), maar dan op een
# view: de agent reconstrueert een staat uit wat hij mag zien (gedekte
# Krokodil-stats = puntschatting, B11) en laat de vertrouwde eval daarop los.
# Per-doctrine-profielen komen zoals altijd uit data/ai_weights.json.
#
# Met full_state=true (B8) levert de runner een fog-loze view aan en is dit
# exact de oude, alwetende AIMedium — de ablatie-basislijn.

const AIScript := preload("res://scripts/ai/AIMedium.gd")

var _ai = null
var _profiel_geladen: bool = false


func _get_ai(view: Dictionary):
	if _ai == null:
		_ai = AIScript.new()
	_ai.player_id = player_id
	_ai.rng = rng
	if not _profiel_geladen:
		_profiel_geladen = true
		var doctrine: int = int(view.doctrines.get(str(player_id), Constants.Doctrine.MENS))
		var profiel: Dictionary = AIController.load_profile()
		if not profiel.is_empty():
			_ai.weights = (profiel.get(doctrine, AIController.default_weights()) as Dictionary).duplicate()
	return _ai


func decide(view: Dictionary, legal: Array, _decide_rng: SeededRng) -> Dictionary:
	if legal.is_empty():
		return {}
	var ai = _get_ai(view)
	var s: GameState = Agent.reconstruct_state(view)
	var ph: int = s.phase
	if ph == Phase.Type.PLACEMENT:
		return Actions.make_place(ai.choose_placement(s))
	if Phase.is_define(ph):
		var cards: Array = ai.generate_cards(s)
		return Actions.make_define_cards(cards) if not cards.is_empty() else legal[0]
	if Phase.is_reveal(ph):
		return Actions.make_ack_reveal()
	if Phase.is_linking(ph):
		var link: Dictionary = ai.choose_link(s)
		if link.has("card_id"):
			return Actions.make_link(int(link.card_id), int(link.pawn_id))
		return legal[0]
	if ph == Phase.Type.ACTION:
		if s.pending_wolf_step_pawn != -1:
			var stap: Dictionary = ai.choose_wolf_step(s)
			return Actions.make_wolf_step(stap.target) if stap.has("target") else Actions.make_skip_wolf_step()
		var actie: Dictionary = Agent.legacy_to_action(ai.choose_action(s))
		return actie if not actie.is_empty() else legal[0]
	return legal[0]
