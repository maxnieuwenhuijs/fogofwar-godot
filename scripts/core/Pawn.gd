class_name Pawn
extends RefCounted

var id: int
var owner_id: int
var position: Vector2i
var unit_type: int = 0  # Constants.UnitType (INFANTRY/CAVALRY/ARTILLERY) — vast voor de hele partij
var is_active: bool = false
var linked_card_id: int = -1
var current_hp: int = 0
var max_hp: int = 0
var remaining_stamina: int = 0  # OPMAAKBAAR: stap=1, melee/schot=1; meerdere acties per cyclus
var max_stamina: int = 0        # Speed-stat (dracht van artillerie krimpt níét mee)
var attack_value: int = 0
var card_revealed: bool = true  # Vos: false tot de kaart onthuld wordt (schade geven/krijgen)
var is_eliminated: bool = false

func _init(p_id: int = 0, p_owner: int = 0, p_pos: Vector2i = Vector2i.ZERO, p_type: int = 0) -> void:
	id = p_id
	owner_id = p_owner
	position = p_pos
	unit_type = p_type

## Speed-stat van de gekoppelde kaart (dracht voor artillerie, loopbereik voor de rest).
func speed() -> int:
	return max_stamina

func link_card(card: Card, hp_bonus: int = 0, speed_bonus: int = 0) -> void:
	linked_card_id = card.id
	is_active = true
	current_hp = card.hp + hp_bonus
	max_hp = card.hp + hp_bonus
	remaining_stamina = card.stamina + speed_bonus
	max_stamina = card.stamina + speed_bonus
	attack_value = card.attack
	card.linked_pawn_id = id

func unlink() -> void:
	linked_card_id = -1
	is_active = false
	current_hp = 0
	max_hp = 0
	remaining_stamina = 0
	max_stamina = 0
	attack_value = 0
	card_revealed = true

func spend_stamina(amount: int) -> void:
	remaining_stamina = maxi(0, remaining_stamina - amount)

func clone() -> Pawn:
	var p := Pawn.new(id, owner_id, position, unit_type)
	p.is_active = is_active
	p.linked_card_id = linked_card_id
	p.current_hp = current_hp
	p.max_hp = max_hp
	p.remaining_stamina = remaining_stamina
	p.max_stamina = max_stamina
	p.attack_value = attack_value
	p.card_revealed = card_revealed
	p.is_eliminated = is_eliminated
	return p

func to_dict() -> Dictionary:
	return {
		"id": id,
		"owner_id": owner_id,
		"position": [position.x, position.y],
		"unit_type": unit_type,
		"is_active": is_active,
		"linked_card_id": linked_card_id,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"remaining_stamina": remaining_stamina,
		"max_stamina": max_stamina,
		"attack_value": attack_value,
		"card_revealed": card_revealed,
		"is_eliminated": is_eliminated,
	}

static func from_dict(d: Dictionary) -> Pawn:
	var pos_arr: Array = d.get("position", [0, 0])
	var p := Pawn.new(
		int(d.get("id", 0)),
		int(d.get("owner_id", 0)),
		Vector2i(int(pos_arr[0]), int(pos_arr[1])),
		int(d.get("unit_type", 0)),
	)
	p.is_active = bool(d.get("is_active", false))
	p.linked_card_id = int(d.get("linked_card_id", -1))
	p.current_hp = int(d.get("current_hp", 0))
	p.max_hp = int(d.get("max_hp", p.current_hp))
	p.remaining_stamina = int(d.get("remaining_stamina", 0))
	p.max_stamina = int(d.get("max_stamina", p.remaining_stamina))
	p.attack_value = int(d.get("attack_value", 0))
	p.card_revealed = bool(d.get("card_revealed", true))
	p.is_eliminated = bool(d.get("is_eliminated", false))
	return p
