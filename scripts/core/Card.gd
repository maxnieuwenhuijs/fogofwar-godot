class_name Card
extends RefCounted

var id: int
var owner_id: int
var round_number: int
var hp: int
var stamina: int
var attack: int
var linked_pawn_id: int = -1

func _init(p_id: int = 0, p_owner: int = 0, p_round: int = 0, p_hp: int = 1, p_stamina: int = 1, p_attack: int = 1) -> void:
	id = p_id
	owner_id = p_owner
	round_number = p_round
	hp = p_hp
	stamina = p_stamina
	attack = p_attack

# v4.1: som = kaartbudget van de doctrine (Mens 7); elke stat min 1.
# speed_max > 0 = doctrinelimiet op Speed bij definitie (Beer: 3).
static func is_valid_stats(p_hp: int, p_stamina: int, p_attack: int, p_budget: int = Constants.STAT_SUM, p_speed_max: int = 0) -> bool:
	if p_hp < Constants.STAT_MIN or p_stamina < Constants.STAT_MIN or p_attack < Constants.STAT_MIN:
		return false
	if p_speed_max > 0 and p_stamina > p_speed_max:
		return false
	return p_hp + p_stamina + p_attack == p_budget

func is_linked() -> bool:
	return linked_pawn_id >= 0

func clone() -> Card:
	var c := Card.new(id, owner_id, round_number, hp, stamina, attack)
	c.linked_pawn_id = linked_pawn_id
	return c

func to_dict() -> Dictionary:
	return {
		"id": id,
		"owner_id": owner_id,
		"round_number": round_number,
		"hp": hp,
		"stamina": stamina,
		"attack": attack,
		"linked_pawn_id": linked_pawn_id,
	}

static func from_dict(d: Dictionary) -> Card:
	var c := Card.new(
		int(d.get("id", 0)),
		int(d.get("owner_id", 0)),
		int(d.get("round_number", 0)),
		int(d.get("hp", 1)),
		int(d.get("stamina", 1)),
		int(d.get("attack", 1)),
	)
	c.linked_pawn_id = int(d.get("linked_pawn_id", -1))
	return c
