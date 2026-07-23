class_name AgentL1
extends Agent

# L1 — greedy one-liners (bouwplan §7.1): pak een kill > loop naar de haven >
# doe schade > random. Setup-fasen: de eerste legale optie (deterministisch).
#
# F1.3: L1 leest de VIEW direct (dicts), zonder staat-reconstructie — dit is
# het arena-werkpaard en de reconstructie was de dikste kostenpost per
# beslissing. Gedekte vijandelijke stats ("?") gelden als onbekend: L1 claimt
# er nooit een kill op (conservatief).


func decide(view: Dictionary, legal: Array, decide_rng: SeededRng) -> Dictionary:
	if legal.is_empty():
		return {}
	var eerste_type: String = String(legal[0].type)
	# Setup-fasen (place/define/ack/link) en de Wolf-stap: eerste optie.
	if eerste_type not in [Actions.MOVE, Actions.MELEE, Actions.SHOOT, Actions.CHARGE]:
		return legal[0]
	var pawns: Dictionary = view.pawns
	# 1) Pak een kill (bekende schade >= bekende resterende HP).
	for a in legal:
		if _is_kill(pawns, a):
			return a
	# 2) Loop naar de haven: de zet met de grootste afstandswinst.
	var beste: Dictionary = {}
	var beste_winst: int = 0
	var haven: Array = Constants.get_haven_for_player(player_id)
	for a in legal:
		var t: String = String(a.type)
		if t != Actions.MOVE and t != Actions.CHARGE:
			continue
		var pd: Dictionary = pawns.get(str(int(a.pawn_id)), {})
		if pd.is_empty():
			continue
		var van: Array = pd.position
		var doel: Vector2i = a.target if t == Actions.MOVE else a.move_target
		var winst: int = _haven_afstand(int(van[0]), int(van[1]), haven) \
			- _haven_afstand(doel.x, doel.y, haven)
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


func _is_kill(pawns: Dictionary, a: Dictionary) -> bool:
	var aanvaller_id: int = -1
	var doel_id: int = -1
	match String(a.type):
		Actions.MELEE:
			aanvaller_id = int(a.attacker_id)
			doel_id = int(a.defender_id)
		Actions.SHOOT:
			aanvaller_id = int(a.shooter_id)
			doel_id = int(a.target_id)
		Actions.CHARGE:
			if int(a.defender_id) == -1:
				return false
			aanvaller_id = int(a.pawn_id)
			doel_id = int(a.defender_id)
		_:
			return false
	var att: Dictionary = pawns.get(str(aanvaller_id), {})
	var doel: Dictionary = pawns.get(str(doel_id), {})
	if att.is_empty() or doel.is_empty():
		return false
	if not bool(doel.get("is_active", false)):
		return true  # standbeeld: elke treffer is dodelijk
	if doel.current_hp is String:
		return false  # gedekt ("?"): geen kill claimen op een gok
	return int(att.attack_value) >= int(doel.current_hp)


func _haven_afstand(x: int, y: int, haven: Array) -> int:
	var best: int = 999
	for h in haven:
		best = mini(best, absi(x - h.x) + absi(y - h.y))
	return best


func wants_view(phase: int) -> bool:
	return phase == Phase.Type.ACTION  # setup-fasen: eerste legale optie, geen view nodig
