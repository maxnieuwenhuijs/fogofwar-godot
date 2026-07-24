class_name AgentRunner
extends RefCounted

# F1.1 — speelt een partij tussen twee Agents, volledig op het nieuwe contract:
#
#   view  = View.for_player(state, p, redacted)   ← fog per speler
#   legal = Validator.legal_actions(state, p)
#   actie = agent.decide(view, legal, agent.rng)
#   Reducer.apply(state, actie, p)
#
# Eén uniforme lus voor álle fasen (legal_actions is al fase-bewust): geen
# fase-dispatch, geen Node, geen signals. Dit is de kiem van arena/run.gd
# (F1.2) en het model voor de server-workers (F4).
#
# Vangnetten (gemeten, niet verstopt): kiest een agent niets of iets
# illegaals, dan valt de runner terug op de eerste legale actie en telt dat
# in fallback_count/illegal_count — een gezonde agent houdt beide op 0.

var done: bool = false
var winner: int = -1
var steps: int = 0
var illegal_count: int = 0
var fallback_count: int = 0
var max_steps: int = 3000

## Optionele metrics-collector (arena/metrics.gd): before_action/after_action
## worden rond elke geslaagde apply aangeroepen. Duck-typed — de runner blijft
## bruikbaar zonder arena-laag.
var metrics = null

var _state: GameState
var _agents: Dictionary = {}


func _init(agent1: Agent, agent2: Agent, doctrine1: int = Constants.Doctrine.MENS,
		doctrine2: int = Constants.Doctrine.MENS, seed_val: int = 0, rules: RulesConfig = null) -> void:
	agent1.player_id = Constants.PLAYER_1
	agent2.player_id = Constants.PLAYER_2
	var match_rng := SeededRng.new(seed_val)
	agent1.rng = match_rng.fork("p1")
	agent2.rng = match_rng.fork("p2")
	_agents = {Constants.PLAYER_1: agent1, Constants.PLAYER_2: agent2}
	_state = GameState.new()
	if rules != null:
		_state.rules = rules
	_state.doctrines[Constants.PLAYER_1] = doctrine1
	_state.doctrines[Constants.PLAYER_2] = doctrine2
	_state.phase = Phase.Type.PLACEMENT
	_state.init_pools()  # F2.5: pools + CP onder een campaign-config


func state() -> GameState:
	return _state


## Eén beslissing verder; bedient in simultane fasen één speler per stap.
func step() -> void:
	if done:
		return
	steps += 1
	if steps > max_steps:
		done = true
		winner = Reducer.tiebreak_winner(_state)
		return
	if _state.phase == Phase.Type.GAME_OVER:
		done = true
		winner = _state.winner
		return
	var acted := false
	for p in [_state.current_player, Constants.opponent(_state.current_player)]:
		var legal: Array = Validator.legal_actions(_state, p)
		if legal.is_empty():
			continue
		var agent: Agent = _agents[p]
		var view: Dictionary = View.for_player(_state, p, not agent.full_state) \
			if agent.wants_view(_state.phase) else {}
		var actie: Dictionary = agent.decide(view, legal, agent.rng)
		if actie.is_empty():
			fallback_count += 1
			actie = legal[0]
		if metrics != null:
			metrics.before_action(_state, p, actie)
		var res: Dictionary = Reducer.apply(_state, actie, p)
		if not res.ok:
			illegal_count += 1
			actie = legal[0]
			if metrics != null:
				metrics.before_action(_state, p, actie)
			res = Reducer.apply(_state, actie, p)
		if metrics != null and res.ok:
			metrics.after_action(_state, p, actie, res.events)
		acted = true
		break
	if not acted:
		# Niemand een legale actie buiten GAME_OVER: hoort niet te bestaan
		# (de reducer reset cycli zelf) — tel als anomalie en stop.
		illegal_count += 1
		done = true
		winner = Reducer.tiebreak_winner(_state)
		return
	if _state.phase == Phase.Type.GAME_OVER:
		done = true
		winner = _state.winner


## Gemak: speel de hele partij uit.
func run() -> int:
	while not done:
		step()
	return winner
