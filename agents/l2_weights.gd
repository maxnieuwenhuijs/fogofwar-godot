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
var tie_break_loting: bool = false  # arena-config zet dit aan (meet-spreiding)


func _get_ai(view: Dictionary):
	if _ai == null:
		_ai = AIScript.new()
	_ai.player_id = player_id
	_ai.rng = rng
	_ai.tie_break_loting = tie_break_loting
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
	# F2.5 (v4.2): spawn maximaal — de laatste legal-optie is de volste inzet.
	if ph == Phase.Type.CYCLE_SPAWN:
		var volste: Dictionary = legal[0]
		for a in legal:
			if String(a.type) == Actions.SPAWN and (a.spawns as Array).size() > (volste.spawns as Array).size():
				volste = a
		return volste
	if Phase.is_define(ph):
		# F2.5-heuristiek (masterplan): CP op de ronde-3-kaarten. Eerst blind
		# bieden; de volgende decide-beurt verdikt generate_cards de eerste
		# `bet` kaarten met het extra budgetpunt (hp).
		if int(view.get("round_number", 1)) == 3 and not bool(view.get("own_cp_bet_done", true)):
			var saldo: int = int(view.cp.get(str(player_id), 0)) if view.has("cp") else 0
			for a in legal:
				if String(a.type) == Actions.BET_CP and int(a.amount) > 0 and int(a.amount) <= saldo:
					return a
		var cards: Array = ai.generate_cards(s)
		if cards.is_empty():
			return legal[0]
		var bet: int = int(view.get("own_cp_bet", 0))
		for i in mini(bet, cards.size()):
			cards[i].hp = int(cards[i].hp) + 1  # het CP-budgetpunt (D1)
		var actie := Actions.make_define_cards(cards)
		if Validator.is_legal(s, actie, player_id).legal:
			return actie
		return legal[0]
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
		if actie.is_empty():
			return legal[0]
		# F2.5/B3: onder campaign spreekt artillerie CANNON_ACT — vertaal de
		# legacy move/shot van de eval naar de kanon-taal.
		actie = _vertaal_kanon(s, actie)
		return actie
	return legal[0]


## MOVE/SHOOT van een artilleriepion onder campaign -> cannon_roll/shoot.
func _vertaal_kanon(s: GameState, actie: Dictionary) -> Dictionary:
	if not s.rules.campaign_actief():
		return actie
	match String(actie.type):
		Actions.MOVE:
			var pion: Pawn = s.pawns.get(int(actie.pawn_id), null)
			if pion != null and pion.unit_type == Constants.UnitType.ARTILLERY:
				return Actions.make_cannon_roll(int(actie.pawn_id), actie.target)
		Actions.SHOOT:
			var schutter: Pawn = s.pawns.get(int(actie.shooter_id), null)
			if schutter != null and schutter.unit_type == Constants.UnitType.ARTILLERY:
				return Actions.make_cannon_shoot(int(actie.shooter_id), int(actie.target_id))
	return actie
