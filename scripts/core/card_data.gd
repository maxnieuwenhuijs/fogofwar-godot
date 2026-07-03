class_name CardData
extends Resource

@export var hp: int = 3
@export var stamina: int = 2
@export var attack: int = 2
var is_linked: bool = false
var linked_pawn_id: int = -1

# v4.1: budget en Speed-limiet volgen uit de doctrine (Mens: 7, geen limiet).
var budget: int = Constants.STAT_TOTAL
var speed_max: int = 0


func stat_sum() -> int:
	return hp + stamina + attack


func remaining_points() -> int:
	return budget - stat_sum()


func is_valid() -> bool:
	if speed_max > 0 and stamina > speed_max:
		return false
	return (
		hp >= Constants.MIN_STAT
		and stamina >= Constants.MIN_STAT
		and attack >= Constants.MIN_STAT
		and stat_sum() == budget
	)


func reset_stats() -> void:
	# Het budget start al verdeeld (1/1/1 + vrije punten om-en-om); +/− in de
	# UI herverdeelt. Budget 7 → 3/2/2, budget 5 → 2/2/1, budget 9 → 3/3/3.
	hp = 1
	stamina = 1
	attack = 1
	var free: int = budget - 3
	for i in free:
		match i % 3:
			0: hp += 1
			1: stamina += 1
			2: attack += 1
	# Beer: Speed-limiet bij definitie — overschot naar HP.
	if speed_max > 0 and stamina > speed_max:
		hp += stamina - speed_max
		stamina = speed_max
	is_linked = false
	linked_pawn_id = -1
