class_name AgentL1
extends Agent

# L1 — greedy one-liners (bouwplan §7.1): pak een kill > loop naar de haven >
# doe schade > random. Setup-fasen: de eerste legale optie (deterministisch).
# Bewust dom gehouden: L1 is het snelle arena-werkpaard (F1.3-benchmark) en
# de leesbare referentie waar L2/L3 zich tegen bewijzen.


func decide(view: Dictionary, legal: Array, decide_rng: SeededRng) -> Dictionary:
	if legal.is_empty():
		return {}
	var eerste_type: String = String(legal[0].type)
	# Setup-fasen (place/define/ack/link) en de Wolf-stap: eerste optie.
	if eerste_type not in [Actions.MOVE, Actions.MELEE, Actions.SHOOT, Actions.CHARGE]:
		return legal[0]
	var s: GameState = Agent.reconstruct_state(view)
	# 1) Pak een kill (geschatte schade >= resterende HP van het doelwit).
	for a in legal:
		if _is_kill(s, a):
			return a
	# 2) Loop naar de haven: de zet met de grootste afstandswinst.
	var beste: Dictionary = {}
	var beste_winst: int = 0
	var haven: Array = Constants.get_haven_for_player(player_id)
	for a in legal:
		var t: String = String(a.type)
		if t != Actions.MOVE and t != Actions.CHARGE:
			continue
		var pawn: Pawn = s.pawns.get(int(a.pawn_id), null)
		if pawn == null:
			continue
		var doel: Vector2i = a.target if t == Actions.MOVE else a.move_target
		var winst: int = _haven_afstand(pawn.position, haven) - _haven_afstand(doel, haven)
		if winst > beste_winst:
			beste_winst = winst
			beste = a
	if not beste.is_empty():
		return beste
	# 3) Doe schade (melee of schot), anders 4) random.
	for a in legal:
		var t: String = String(a.type)
		if t == Actions.MELEE or t == Actions.SHOOT:
			return a
	return legal[decide_rng.randi_range(0, legal.size() - 1)]


func _is_kill(s: GameState, a: Dictionary) -> bool:
	match String(a.type):
		Actions.MELEE:
			var att: Pawn = s.pawns.get(int(a.attacker_id), null)
			var def: Pawn = s.pawns.get(int(a.defender_id), null)
			return att != null and def != null \
				and (not def.is_active or att.attack_value >= def.current_hp)
		Actions.SHOOT:
			var sh: Pawn = s.pawns.get(int(a.shooter_id), null)
			var doel: Pawn = s.pawns.get(int(a.target_id), null)
			return sh != null and doel != null \
				and (not doel.is_active or Rules.shot_damage(s, sh) >= doel.current_hp)
		Actions.CHARGE:
			if int(a.defender_id) == -1:
				return false
			var cav: Pawn = s.pawns.get(int(a.pawn_id), null)
			var slachtoffer: Pawn = s.pawns.get(int(a.defender_id), null)
			return cav != null and slachtoffer != null \
				and (not slachtoffer.is_active or cav.attack_value >= slachtoffer.current_hp)
	return false


func _haven_afstand(pos: Vector2i, haven: Array) -> int:
	var best: int = 999
	for h in haven:
		best = mini(best, absi(pos.x - h.x) + absi(pos.y - h.y))
	return best
