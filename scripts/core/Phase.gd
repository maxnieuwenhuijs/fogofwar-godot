class_name Phase
extends RefCounted

enum Type {
	PRE_GAME,
	PLACEMENT,
	SETUP_1_DEFINE,
	SETUP_1_REVEAL,
	SETUP_1_LINKING,
	SETUP_2_DEFINE,
	SETUP_2_REVEAL,
	SETUP_2_LINKING,
	SETUP_3_DEFINE,
	SETUP_3_REVEAL,
	SETUP_3_LINKING,
	ACTION,
	GAME_OVER,
}

static func is_define(phase: int) -> bool:
	return phase == Type.SETUP_1_DEFINE or phase == Type.SETUP_2_DEFINE or phase == Type.SETUP_3_DEFINE

static func is_reveal(phase: int) -> bool:
	return phase == Type.SETUP_1_REVEAL or phase == Type.SETUP_2_REVEAL or phase == Type.SETUP_3_REVEAL

static func is_linking(phase: int) -> bool:
	return phase == Type.SETUP_1_LINKING or phase == Type.SETUP_2_LINKING or phase == Type.SETUP_3_LINKING

static func is_setup(phase: int) -> bool:
	return is_define(phase) or is_reveal(phase) or is_linking(phase)

static func round_of(phase: int) -> int:
	match phase:
		Type.SETUP_1_DEFINE, Type.SETUP_1_REVEAL, Type.SETUP_1_LINKING:
			return 1
		Type.SETUP_2_DEFINE, Type.SETUP_2_REVEAL, Type.SETUP_2_LINKING:
			return 2
		Type.SETUP_3_DEFINE, Type.SETUP_3_REVEAL, Type.SETUP_3_LINKING:
			return 3
	return 0

static func define_for_round(round_num: int) -> int:
	match round_num:
		1: return Type.SETUP_1_DEFINE
		2: return Type.SETUP_2_DEFINE
		3: return Type.SETUP_3_DEFINE
	return Type.PRE_GAME

static func reveal_for_round(round_num: int) -> int:
	match round_num:
		1: return Type.SETUP_1_REVEAL
		2: return Type.SETUP_2_REVEAL
		3: return Type.SETUP_3_REVEAL
	return Type.PRE_GAME

static func linking_for_round(round_num: int) -> int:
	match round_num:
		1: return Type.SETUP_1_LINKING
		2: return Type.SETUP_2_LINKING
		3: return Type.SETUP_3_LINKING
	return Type.PRE_GAME

static func to_string_phase(phase: int) -> String:
	return Type.keys()[phase]
