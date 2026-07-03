extends Node

const BOARD_SIZE: int = 11
const ROUNDS_PER_CYCLE: int = 3
const PAWNS_IN_HAVEN_TO_WIN: int = 2

# Referentiewaarden (Mens-doctrine); het echte budget/aantal komt uit DOCTRINE_DATA.
const PAWNS_PER_PLAYER: int = 22
const CARDS_PER_ROUND: int = 3
const STAT_SUM: int = 7
const STAT_MIN: int = 1

# Compat-aliassen voor de bestaande kaart-UI (card_view / card_data)
const STAT_TOTAL: int = 7
const MIN_STAT: int = 1

# Vuurregels (v4.1 + huisregels)
const INFANTRY_SHOT_RANGE: int = 2   # schot: afstand exact 2
const INFANTRY_SHOT_COST: int = 1    # elk schot kost gewoon 1 stamina
const ARTILLERY_MIN_RANGE: int = 2   # dode zone: afstand 1 nooit beschietbaar
const ARTILLERY_RANGE: int = 6       # vaste dracht: 6 vakken, mits vrije lijn
const ARTILLERY_SHOT_COST: int = 1   # elk schot kost gewoon 1 stamina
const ARTILLERY_MOVE: int = 1        # artillerie beweegt max 1 stap per beurt

# Terugslag per verdediger-type: schade op de aanvaller als een ACTIEVE
# verdediger een melee overleeft (huisregel: type-afhankelijk).
const RETALIATION_DAMAGE: Dictionary = {
	UnitType.INFANTRY: 1,
	UnitType.CAVALRY: 2,   # paarden slaan hard terug
	UnitType.ARTILLERY: 0, # kanonnen zijn weerloos in melee
}

const PLAYER_1: int = 1
const PLAYER_2: int = 2

const EMPTY_TILE: int = -1

enum ActionType { MOVE, ATTACK, SHOT, CHARGE }

enum UnitType { INFANTRY, CAVALRY, ARTILLERY }

enum Doctrine { MENS, MUIS, LEEUW, BEER, WOLF, VOS }

# Compat-enums voor UI / presentatie (RED = speler 1, BLUE = speler 2)
enum Team { RED, BLUE }
enum UiPhase { DEFINE, LINKING, DONE }

# Doctrine-data (spelregels v4.1 §6 + huisregel-perks). comp = [Inf, Cav, Art].
# speed_max: maximum Speed bij kaartdefinitie (0 = geen limiet).
# art_range_bonus: extra dracht op de vaste 6; cav_speed_bonus: +Speed op
# cavalerie bij koppeling; cav_jump_infantry: cavalerie springt óók over
# VIJANDELIJKE infanterie. (Cavalerie springt sowieso over eigen pionnen.)
const DOCTRINE_DATA: Dictionary = {
	Doctrine.MENS: {
		"name": "Mens", "cards": 3, "budget": 7, "comp": [13, 6, 3],
		"move_through_own": false, "hp_bonus": 0, "speed_max": 0,
		"wolf_step": false, "hidden_link": false,
		"art_range_bonus": 0, "cav_speed_bonus": 0, "cav_jump_infantry": false,
		"pro": "Allrounder zonder zwaktes",
		"con": "Nergens de beste in",
	},
	Doctrine.MUIS: {
		"name": "Muis", "cards": 4, "budget": 5, "comp": [22, 0, 0],
		"move_through_own": true, "hp_bonus": 0, "speed_max": 0, "speed_bonus": 1,
		"wolf_step": false, "hidden_link": false,
		"art_range_bonus": 0, "cav_speed_bonus": 0, "cav_jump_infantry": false,
		"pro": "4 kaarten, +1 Speed op elke muis, beweegt door eigen pionnen (zwerm)",
		"con": "Budget 5: stats max 3, geen cavalerie of kanonnen",
	},
	Doctrine.LEEUW: {
		"name": "Leeuw", "cards": 2, "budget": 9, "comp": [6, 10, 2],
		"move_through_own": false, "hp_bonus": 0, "speed_max": 0,
		"wolf_step": false, "hidden_link": false,
		"art_range_bonus": 1, "cav_speed_bonus": 0, "cav_jump_infantry": false,
		"pro": "Budget 9: monsterkaarten (tot Aanval 7) en kanonnen met dracht 7",
		"con": "Maar 2 kaarten per ronde en 18 pionnen",
	},
	Doctrine.BEER: {
		"name": "Beer", "cards": 3, "budget": 7, "comp": [16, 3, 3],
		"move_through_own": false, "hp_bonus": 1, "speed_max": 3,
		"wolf_step": false, "hidden_link": false,
		"art_range_bonus": 0, "cav_speed_bonus": 0, "cav_jump_infantry": false,
		"pro": "Elke koppeling gratis +1 HP: muren tot 6 HP",
		"con": "Speed max 3: traag over het bord",
	},
	Doctrine.WOLF: {
		"name": "Wolf", "cards": 3, "budget": 7, "comp": [11, 8, 3],
		"move_through_own": false, "hp_bonus": 0, "speed_max": 0,
		"wolf_step": true, "hidden_link": false,
		"art_range_bonus": 0, "cav_speed_bonus": 0, "cav_jump_infantry": true,
		"pro": "Gratis stap na elke melee; cavalerie springt óók over vijandelijke infanterie",
		"con": "Stap geldt niet na schoten; lichte samenstelling",
	},
	Doctrine.VOS: {
		"name": "Vos", "cards": 3, "budget": 7, "comp": [13, 6, 3],
		"move_through_own": false, "hp_bonus": 0, "speed_max": 0,
		"wolf_step": false, "hidden_link": true,
		"art_range_bonus": 0, "cav_speed_bonus": 1, "cav_jump_infantry": false,
		"pro": "Koppeling geheim tot eerste schade (bluf) en cavalerie +1 Speed",
		"con": "Kaarten zelf zijn openbaar; standaard leger",
	},
}

const HAVEN_P1: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(4, 0),
	Vector2i(5, 0),
	Vector2i(6, 0),
	Vector2i(10, 0),
]

const HAVEN_P2: Array[Vector2i] = [
	Vector2i(0, 10),
	Vector2i(4, 10),
	Vector2i(5, 10),
	Vector2i(6, 10),
	Vector2i(10, 10),
]

func doctrine_data(doctrine: int) -> Dictionary:
	return DOCTRINE_DATA.get(doctrine, DOCTRINE_DATA[Doctrine.MENS])

func doctrine_name(doctrine: int) -> String:
	return doctrine_data(doctrine).name

func pawn_total(doctrine: int) -> int:
	var comp: Array = doctrine_data(doctrine).comp
	return comp[0] + comp[1] + comp[2]

func unit_type_name(unit_type: int) -> String:
	match unit_type:
		UnitType.INFANTRY: return "Infanterie"
		UnitType.CAVALRY: return "Cavalerie"
		UnitType.ARTILLERY: return "Artillerie"
	return "?"

func unit_type_letter(unit_type: int) -> String:
	match unit_type:
		UnitType.INFANTRY: return "I"
		UnitType.CAVALRY: return "C"
		UnitType.ARTILLERY: return "A"
	return "?"

func get_haven_for_player(player_id: int) -> Array[Vector2i]:
	if player_id == PLAYER_1:
		return HAVEN_P1
	return HAVEN_P2

func get_start_rows_for_player(player_id: int) -> Array[int]:
	# [achterste rij, voorste rij] (voorste = dichtst bij de vijand)
	if player_id == PLAYER_1:
		return [10, 9]
	return [0, 1]

func opponent(player_id: int) -> int:
	if player_id == PLAYER_1:
		return PLAYER_2
	return PLAYER_1

func is_on_board(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE

func manhattan_neighbors(pos: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(pos.x, pos.y - 1),
		Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x, pos.y + 1),
		Vector2i(pos.x - 1, pos.y),
	]
