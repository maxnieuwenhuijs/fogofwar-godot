class_name Actions
extends RefCounted

# F0.3 — één actietaal voor het hele spel. Een Action is een Dictionary met
# "type" (const string) + payload. Dit is het formaat dat straks de reducer
# (F0.4), het event-log (F0.7), agents (F1.1) en het netwerkprotocol (F4)
# spreken. Serialisatie: to_dict/from_dict (Vector2i ↔ [x, y] voor JSON).
#
# CLAIM_TIMEOUT is hier alleen GEDEFINIEERD en blijft tot F0.8 altijd illegaal
# (klokken bestaan nog niet). RESIGN krijgt zijn effect in F0.4c.

const PLACE := "place"
const DEFINE_CARDS := "define_cards"
const ACK_REVEAL := "ack_reveal"
const LINK := "link"
const MOVE := "move"
const MELEE := "melee"
const SHOOT := "shoot"
const CHARGE := "charge"
const WOLF_STEP := "wolf_step"
const SKIP_WOLF_STEP := "skip_wolf_step"
const RESIGN := "resign"
const CLAIM_TIMEOUT := "claim_timeout"
const SPAWN := "spawn"  # v4.2 (F2.2): blinde spawn-inzet; lege lijst = bewust niets

## Per type: de verplichte payload-velden (voor is_wellformed en from_dict).
const _FIELDS := {
	PLACE: ["placements"],
	DEFINE_CARDS: ["cards"],
	ACK_REVEAL: [],
	LINK: ["card_id", "pawn_id"],
	MOVE: ["pawn_id", "target"],
	MELEE: ["attacker_id", "defender_id"],
	SHOOT: ["shooter_id", "target_id"],
	CHARGE: ["pawn_id", "move_target", "defender_id"],
	WOLF_STEP: ["target"],
	SKIP_WOLF_STEP: [],
	RESIGN: [],
	CLAIM_TIMEOUT: [],
	SPAWN: ["spawns"],
}

## Velden die een Vector2i dragen (serialisatie ↔ [x, y]).
const _VEC_FIELDS := ["target", "move_target"]


# --- Factories ---------------------------------------------------------------

static func make_place(placements: Array) -> Dictionary:
	return {"type": PLACE, "placements": placements}

static func make_define_cards(cards: Array) -> Dictionary:
	# cards: [{hp, stamina, attack}, ...]
	return {"type": DEFINE_CARDS, "cards": cards}

static func make_ack_reveal() -> Dictionary:
	return {"type": ACK_REVEAL}

static func make_link(card_id: int, pawn_id: int) -> Dictionary:
	return {"type": LINK, "card_id": card_id, "pawn_id": pawn_id}

static func make_move(pawn_id: int, target: Vector2i) -> Dictionary:
	return {"type": MOVE, "pawn_id": pawn_id, "target": target}

static func make_melee(attacker_id: int, defender_id: int) -> Dictionary:
	return {"type": MELEE, "attacker_id": attacker_id, "defender_id": defender_id}

static func make_shoot(shooter_id: int, target_id: int) -> Dictionary:
	return {"type": SHOOT, "shooter_id": shooter_id, "target_id": target_id}

static func make_charge(pawn_id: int, move_target: Vector2i, defender_id: int) -> Dictionary:
	return {"type": CHARGE, "pawn_id": pawn_id, "move_target": move_target, "defender_id": defender_id}

static func make_wolf_step(target: Vector2i) -> Dictionary:
	return {"type": WOLF_STEP, "target": target}

static func make_skip_wolf_step() -> Dictionary:
	return {"type": SKIP_WOLF_STEP}

static func make_resign() -> Dictionary:
	return {"type": RESIGN}

static func make_claim_timeout() -> Dictionary:
	return {"type": CLAIM_TIMEOUT}

static func make_spawn(spawns: Array) -> Dictionary:
	# spawns: [{type: UnitType, pos: Vector2i}, ...] — mag leeg (bewust niets).
	return {"type": SPAWN, "spawns": spawns}


# --- Structuurcontrole ---------------------------------------------------------

static func is_wellformed(a) -> bool:
	if not (a is Dictionary) or not a.has("type"):
		return false
	var t: String = String(a.type)
	if not _FIELDS.has(t):
		return false
	for field in _FIELDS[t]:
		if not a.has(field):
			return false
	# Payload-typechecks per veldsoort.
	for field in _VEC_FIELDS:
		if a.has(field) and not (a[field] is Vector2i):
			return false
	for lijstveld in ["placements", "spawns"]:
		if a.has(lijstveld):
			if not (a[lijstveld] is Array):
				return false
			for entry in a[lijstveld]:
				if not (entry is Dictionary) or not entry.has("type") or not entry.has("pos") \
						or not (entry.pos is Vector2i):
					return false
	if a.has("cards"):
		if not (a.cards is Array):
			return false
		for c in a.cards:
			if not (c is Dictionary) or not c.has("hp") or not c.has("stamina") or not c.has("attack"):
				return false
	return true


# --- Serialisatie (JSON-veilig: Vector2i ↔ [x, y], ints geforceerd) -----------

static func to_dict(a: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in a:
		var v = a[k]
		if v is Vector2i:
			out[k] = [v.x, v.y]
		elif k == "placements" or k == "spawns":
			var lst: Array = []
			for entry in v:
				lst.append({"type": int(entry.type), "pos": [entry.pos.x, entry.pos.y]})
			out[k] = lst
		elif k == "cards":
			var cl: Array = []
			for c in v:
				cl.append({"hp": int(c.hp), "stamina": int(c.stamina), "attack": int(c.attack)})
			out[k] = cl
		else:
			out[k] = v
	return out

static func from_dict(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d:
		var v = d[k]
		if _VEC_FIELDS.has(k) and v is Array and v.size() == 2:
			out[k] = Vector2i(int(v[0]), int(v[1]))
		elif (k == "placements" or k == "spawns") and v is Array:
			var lst: Array = []
			for entry in v:
				var p = entry.pos
				lst.append({"type": int(entry.type), "pos": Vector2i(int(p[0]), int(p[1])) if p is Array else p})
			out[k] = lst
		elif k == "cards" and v is Array:
			var cl: Array = []
			for c in v:
				cl.append({"hp": int(c.hp), "stamina": int(c.stamina), "attack": int(c.attack)})
			out[k] = cl
		elif k == "type":
			out[k] = String(v)
		elif v is float and v == floorf(v):
			out[k] = int(v)  # JSON maakt van elke int een float
		else:
			out[k] = v
	return out
