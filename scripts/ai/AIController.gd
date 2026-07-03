class_name AIController
extends RefCounted

var player_id: int = Constants.PLAYER_2

## Evaluatie-gewichten — instelbaar zodat de Trainer ze kan leren (self-play).
var weights: Dictionary = default_weights()

## In het project → commit-baar en met de hand aan te passen.
const WEIGHTS_PATH := "res://data/ai_weights.json"

## PER-FACTIE PROFIEL: elke doctrine heeft z'n eigen gewichtenset — een
## Muis-zwerm wil andere voorkeuren dan een Leeuw-elite.
## Bestandsformaat: { "<doctrine-int>": {gewichten}, ... }. Een oud "plat"
## bestand (één set) wordt herkend en voor alle doctrines gebruikt.

static func default_profile() -> Dictionary:
	var profile: Dictionary = {}
	for doctrine in Constants.DOCTRINE_DATA.keys():
		profile[int(doctrine)] = default_weights()
	return profile

static func save_profile(profile: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var out: Dictionary = {}
	for doctrine in profile:
		out[str(int(doctrine))] = profile[doctrine]
	var f := FileAccess.open(WEIGHTS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "\t"))

## Laad het profiel; elke set gemerged over de defaults (robuust bij handmatig
## editen en bij nieuw toegevoegde gewichten). {} als er niets opgeslagen is.
static func load_profile() -> Dictionary:
	var has_any_override := false
	for doctrine in Constants.DOCTRINE_DATA.keys():
		if FileAccess.file_exists(override_path(int(doctrine))):
			has_any_override = true
			break
	if not FileAccess.file_exists(WEIGHTS_PATH) and not has_any_override:
		return {}
	var profile: Dictionary = {}
	var data = null
	if FileAccess.file_exists(WEIGHTS_PATH):
		var f := FileAccess.open(WEIGHTS_PATH, FileAccess.READ)
		if f != null:
			data = JSON.parse_string(f.get_as_text())
	if data is Dictionary and not data.is_empty():
		if data.values()[0] is Dictionary:
			# Nieuw formaat: per doctrine een set.
			for key in data:
				var merged := default_weights()
				for k in data[key]:
					merged[k] = float(data[key][k])
				profile[int(key)] = merged
		else:
			# Oud plat formaat: één set → gebruik 'm voor elke doctrine.
			var merged := default_weights()
			for k in data:
				merged[k] = float(data[k])
			for doctrine in Constants.DOCTRINE_DATA.keys():
				profile[int(doctrine)] = merged.duplicate()
	# Ontbrekende doctrines aanvullen met defaults.
	for doctrine in Constants.DOCTRINE_DATA.keys():
		if not profile.has(int(doctrine)):
			profile[int(doctrine)] = default_weights()
	# Per-factie override-bestanden (parallelle trainingsprocessen) winnen.
	for doctrine in Constants.DOCTRINE_DATA.keys():
		var override := _load_faction_override(int(doctrine))
		if not override.is_empty():
			profile[int(doctrine)] = override
	return profile

## PARALLEL TRAINEN (64-cores-route): elk trainingsproces traint één factie en
## schrijft een eigen override-bestand — geen schrijfconflicten tussen processen.
## load_profile() merget die overrides automatisch over het hoofdbestand.
static func override_path(doctrine: int) -> String:
	return "res://data/ai_weights_f%d.json" % doctrine

static func save_faction_override(doctrine: int, w: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(override_path(doctrine), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(w, "\t"))

static func _load_faction_override(doctrine: int) -> Dictionary:
	if not FileAccess.file_exists(override_path(doctrine)):
		return {}
	var f := FileAccess.open(override_path(doctrine), FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary) or data.is_empty():
		return {}
	var merged := default_weights()
	for k in data:
		merged[k] = float(data[k])
	return merged

## Compat-helpers (oude aanroepen/tools): één set = hetzelfde voor elke doctrine.
static func save_weights(w: Dictionary) -> void:
	var profile: Dictionary = {}
	for doctrine in Constants.DOCTRINE_DATA.keys():
		profile[int(doctrine)] = w.duplicate()
	save_profile(profile)

static func load_weights() -> Dictionary:
	var profile := load_profile()
	if profile.is_empty():
		return {}
	return profile[int(Constants.Doctrine.MENS)]

static func default_weights() -> Dictionary:
	return {
		"haven": 6000.0,     # pion in de doelhaven (beslissend)
		"prox_scale": 8.0,   # hoe zwaar nabijheid tot de haven telt
		"prox_second": 0.6,  # gewicht van de 2e dichtstbijzijnde pion
		"guard": 320.0,      # bewaking van de winvakjes
		"material": 32.0,    # levende pionnen (basiswaarde, elk type)
		"cav_value": 10.0,   # extra materiaalwaarde per cavalerist (mobiliteit/charge)
		"art_value": 24.0,   # extra materiaalwaarde per kanon (schaars, dracht 6+)
		"hp": 3.0,           # HP van actieve pionnen
		"protect": 160.0,    # bescherming: pionnen niet gratis laten pakken (melee-dreiging)
		"ranged": 40.0,      # vuurdreiging: schot-doelwitten van mijn schutters minus die van de vijand
		"reach": 500.0,      # pion die z'n doelhaven kan bereiken (scoort/dreigt); blokkade telt mee
		"card_atk": 1.0,     # kaart-voorkeur: attack (→ initiatief + schade)
		"card_hp": 1.0,      # kaart-voorkeur: hp (→ overleven/terugslag-muur)
		"card_stam": 1.0,    # kaart-voorkeur: stamina (→ actievoorraad)
		"r3_initiative": 1.6, # ronde 3: extra attack om als eerste te mogen slaan
		# --- Opstelling (leerbaar): voorkeur per type voor voorste rij / centrum.
		# front: 0 = achteraan, hoger = voorste rij; center: >0 = centrum, <0 = flank.
		"art_front": 1.0,
		"art_center": -0.4,
		"cav_front": 0.0,
		"cav_center": -0.7,
		"inf_front": 0.6,
		"inf_center": 0.5,
		# --- Koppelen (leerbaar): affiniteit kaartstat × piontype.
		# Kaart × type is de kern van v4.1: dezelfde 1/5/1 is sprinter op cavalerie
		# en actievoorraad op artillerie.
		"aff_inf_hp": 1.0,
		"aff_inf_spd": 0.5,
		"aff_inf_atk": 0.8,
		"aff_cav_hp": 0.5,
		"aff_cav_spd": 1.2,
		"aff_cav_atk": 1.0,
		"aff_art_hp": 0.3,
		"aff_art_spd": 0.9,
		"aff_art_atk": 1.2,
		"link_advance": 0.4, # voorkeur voor pionnen dichter bij de doelhaven
	}

# =========================================================================
# Setup: kaarten definiëren + koppelen
# =========================================================================

func generate_cards(state: GameState) -> Array:
	# Vrije punten per kaart (budget − 3, bovenop 1/1/1), verdeeld volgens
	# tunebare voorkeuren. Aantal kaarten en budget volgen uit de doctrine.
	var doctrine: Dictionary = Constants.doctrine_data(Constants.Doctrine.MENS)
	if state != null:
		doctrine = state.doctrine_data_of(player_id)
	var wa: float = weights.get("card_atk", 1.0)
	var wh: float = weights.get("card_hp", 1.0)
	var ws: float = weights.get("card_stam", 1.0)
	# Ronde 3 bepaalt wie de ACTIEFASE begint (eerst mogen slaan!) → harder om
	# initiatief vechten met meer attack.
	if state != null and state.round_number >= Constants.ROUNDS_PER_CYCLE:
		wa *= weights.get("r3_initiative", 1.6)
	# Wisselende nadruk (renner / slager / anker / allrounder) voor variatie.
	var profiles: Array = [
		[wh, ws * 1.7, wa],        # renner (speed → vluchten/dracht)
		[wh, ws, wa * 1.7],        # slager (attack → initiatief)
		[wh * 1.7, ws, wa],        # anker (hp → overleven)
		[wh, ws * 1.3, wa * 1.3],  # allrounder
	]
	var cards: Array = []
	for i in int(doctrine.cards):
		var p: Array = profiles[i % profiles.size()]
		cards.append(_gen_card(p[0], p[1], p[2], int(doctrine.budget), int(doctrine.speed_max)))
	return cards


func _gen_card(pref_hp: float, pref_stam: float, pref_atk: float, budget: int = Constants.STAT_SUM, speed_max: int = 0) -> Dictionary:
	var hp := 1
	var stam := 1
	var atk := 1
	var stat_cap: int = budget - 2  # min 1 op de andere twee stats
	var stam_cap: int = stat_cap if speed_max <= 0 else mini(stat_cap, speed_max)
	var pref := {"hp": maxf(0.01, pref_hp), "stamina": maxf(0.01, pref_stam), "attack": maxf(0.01, pref_atk)}
	for _i in budget - 3:
		var best := ""
		var best_v := -1.0
		for k in pref:
			var cur: int = hp if k == "hp" else (stam if k == "stamina" else atk)
			var cap: int = stam_cap if k == "stamina" else stat_cap
			if cur >= cap:
				continue
			if pref[k] > best_v:
				best_v = pref[k]
				best = k
		if best == "hp":
			hp += 1
		elif best == "stamina":
			stam += 1
		else:
			atk += 1
		pref[best] *= 0.55  # spreid de punten
	return {"hp": hp, "stamina": stam, "attack": atk}


## Vrije opstelling (v4.1), LEERBAAR: elk vak krijgt per type een score uit de
## front/center-gewichten; het schaarste type kiest eerst de beste vakken.
func choose_placement(state: GameState) -> Array:
	var comp: Array = state.doctrine_data_of(player_id).comp
	var rows: Array = Constants.get_start_rows_for_player(player_id)  # [achter, voor]
	var slots: Array = []
	for row_i in 2:
		for x in range(Constants.BOARD_SIZE):
			slots.append({
				"pos": Vector2i(x, rows[row_i]),
				"front": 1.0 if row_i == 1 else 0.0,
				"center": 1.0 - absf(float(x) - 5.0) / 5.0,
			})
	var placements: Array = []
	var taken: Dictionary = {}
	var specs: Array = [
		{"type": Constants.UnitType.ARTILLERY, "count": int(comp[2]), "wf": "art_front", "wc": "art_center"},
		{"type": Constants.UnitType.CAVALRY, "count": int(comp[1]), "wf": "cav_front", "wc": "cav_center"},
		{"type": Constants.UnitType.INFANTRY, "count": int(comp[0]), "wf": "inf_front", "wc": "inf_center"},
	]
	for spec in specs:
		if int(spec.count) <= 0:
			continue
		var wf: float = float(weights.get(spec.wf, 0.5))
		var wc: float = float(weights.get(spec.wc, 0.0))
		var scored: Array = []
		for s in slots:
			if taken.has(s.pos):
				continue
			# Vaste, kleine tiebreak zodat de volgorde deterministisch is.
			var tie: float = float(s.pos.x) * 0.001 + float(s.pos.y) * 0.0001
			scored.append({"key": wf * s.front + wc * s.center - tie, "pos": s.pos})
		scored.sort_custom(func(a, b): return a.key > b.key)
		for i in int(spec.count):
			taken[scored[i].pos] = true
			placements.append({"type": spec.type, "pos": scored[i].pos})
	return placements


func choose_link(state: GameState) -> Dictionary:
	var cards: Array = []
	for c in state.cards_revealed[player_id]:
		if not c.is_linked():
			cards.append(c)
	if cards.is_empty():
		return {}
	var pawns: Array = []
	for p in state.pawns.values():
		if p.owner_id == player_id and not p.is_eliminated and p.linked_card_id == -1:
			pawns.append(p)
	if pawns.is_empty():
		return {}
	# Nooit een ingeklemde pion koppelen als er pionnen met ruimte zijn.
	var movable: Array = _filter_movable_pawns(state, pawns)
	var pool: Array = movable if not movable.is_empty() else pawns
	# LEERBAAR en type-bewust: kies het kaart×pion-paar met de hoogste affiniteit
	# (kaartstats × type-gewichten) plus een bonus voor pionnen dichter bij de haven.
	var my_haven: Array = Constants.get_haven_for_player(player_id)
	var advance: float = float(weights.get("link_advance", 0.4))
	var best: Dictionary = {}
	var best_score: float = -1e18
	for c in cards:
		for p in pool:
			var score: float = _link_affinity(c, p.unit_type) \
				+ advance * float(Constants.BOARD_SIZE - _min_dist(p.position, my_haven))
			if score > best_score:
				best_score = score
				best = {"card_id": c.id, "pawn_id": p.id}
	return best


## Affiniteit van een kaart voor een piontype (tunebare aff_*-gewichten).
func _link_affinity(card: Card, unit_type: int) -> float:
	var prefix := "inf"
	match unit_type:
		Constants.UnitType.CAVALRY: prefix = "cav"
		Constants.UnitType.ARTILLERY: prefix = "art"
	return float(card.hp) * float(weights.get("aff_%s_hp" % prefix, 0.5)) \
		+ float(card.stamina) * float(weights.get("aff_%s_spd" % prefix, 0.5)) \
		+ float(card.attack) * float(weights.get("aff_%s_atk" % prefix, 0.5))


func choose_action(_state: GameState) -> Dictionary:
	return {}


# =========================================================================
# Gedeelde evaluatie (positief = goed voor `me`)
# =========================================================================

func evaluate(state: GameState, me: int) -> int:
	var opp: int = Constants.opponent(me)
	var my_target: Array = Constants.get_haven_for_player(me)
	var opp_target: Array = Constants.get_haven_for_player(opp)
	var score: float = 0.0

	# 1) Beslissend: pionnen in de doelhavens.
	score += Rules.count_pawns_in_haven(state, me) * weights.haven
	score -= Rules.count_pawns_in_haven(state, opp) * weights.haven

	# 2) Opmars (aanval) vs bedreiging (verdediging): 2 dichtstbijzijnde pionnen,
	#    niet-lineair zodat "bijna binnen" veel zwaarder telt. Symmetrisch → negamax-safe.
	var my_near: Array = _two_closest(state, me, my_target)
	var opp_near: Array = _two_closest(state, opp, opp_target)
	score += _prox(my_near[0]) + _prox(my_near[1]) * weights.prox_second
	score -= _prox(opp_near[0]) + _prox(opp_near[1]) * weights.prox_second

	# 3) Materiaal, HP, bewaking én bescherming (alles zero-sum).
	var my_guard: int = 0
	var opp_guard: int = 0
	var my_alive: int = 0
	var opp_alive: int = 0
	var my_hp: int = 0
	var opp_hp: int = 0
	# Bescherm je pionnen: aanvallen zijn eenrichting, dus een pion naast een
	# vijand die 'm kan doden staat volgende beurt op de kop → straffen.
	var my_risk: int = 0
	var opp_risk: int = 0
	var my_reach: int = 0
	var opp_reach: int = 0
	var my_cav: int = 0
	var opp_cav: int = 0
	var my_art: int = 0
	var opp_art: int = 0
	var my_ranged: int = 0
	var opp_ranged: int = 0
	for pawn in state.pawns.values():
		if pawn.is_eliminated:
			continue
		var mine: bool = pawn.owner_id == me
		var tgt: Array = my_target if mine else opp_target
		if mine:
			my_alive += 1
			if pawn.unit_type == Constants.UnitType.CAVALRY:
				my_cav += 1
			elif pawn.unit_type == Constants.UnitType.ARTILLERY:
				my_art += 1
			if opp_target.has(pawn.position):
				my_guard += 1
			if pawn.is_active:
				my_hp += pawn.current_hp
		else:
			opp_alive += 1
			if pawn.unit_type == Constants.UnitType.CAVALRY:
				opp_cav += 1
			elif pawn.unit_type == Constants.UnitType.ARTILLERY:
				opp_art += 1
			if my_target.has(pawn.position):
				opp_guard += 1
			if pawn.is_active:
				opp_hp += pawn.current_hp
		if pawn.is_active and _is_killable(state, pawn):
			if mine:
				my_risk += 1
			else:
				opp_risk += 1
		# Vuurdreiging: hoeveel doelwitten hebben mijn schutters NU in de vuurlijn?
		if pawn.is_active and pawn.unit_type != Constants.UnitType.CAVALRY:
			var shots: int = Rules.get_valid_shot_targets(state, pawn.id).size()
			if mine:
				my_ranged += shots
			else:
				opp_ranged += shots
		# Bereik: kan deze actieve pion z'n doelhaven halen? Goedkope voorfilter,
		# dan de echte looppaden (houdt rekening met blokkades → blokkeren beloond).
		if pawn.is_active and pawn.remaining_stamina > 0 \
				and _min_dist(pawn.position, tgt) <= pawn.remaining_stamina \
				and _can_reach_haven(state, pawn, tgt):
			if mine:
				my_reach += 1
			else:
				opp_reach += 1
	score += (my_guard - opp_guard) * weights.guard
	score += (my_alive - opp_alive) * weights.material
	score += (my_cav - opp_cav) * weights.get("cav_value", 10.0)
	score += (my_art - opp_art) * weights.get("art_value", 24.0)
	score += (my_hp - opp_hp) * weights.hp
	score += (opp_risk - my_risk) * weights.protect
	score += (my_ranged - opp_ranged) * weights.get("ranged", 40.0)
	score += (my_reach - opp_reach) * weights.reach
	return int(score)


## Kan de pion via een geldig pad op een (leeg) havenvak eindigen?
func _can_reach_haven(state: GameState, pawn: Pawn, target: Array) -> bool:
	for coord in Rules.get_valid_moves(state, pawn.id):
		if target.has(coord):
			return true
	return false


## Kan een aangrenzende, actieve vijand deze pion volgende beurt doden?
func _is_killable(state: GameState, pawn: Pawn) -> bool:
	for neighbor in Constants.manhattan_neighbors(pawn.position):
		var enemy: Pawn = state.get_pawn_at(neighbor)
		if enemy != null and not enemy.is_eliminated and enemy.owner_id != pawn.owner_id \
				and enemy.is_active and enemy.remaining_stamina >= 1 \
				and enemy.attack_value >= pawn.current_hp:
			return true
	return false


func _prox(d: int) -> float:
	var v: int = maxi(0, Constants.BOARD_SIZE - d)
	return float(v * v) * weights.prox_scale


func _two_closest(state: GameState, side: int, target: Array) -> Array:
	var d1: int = 99999
	var d2: int = 99999
	for pawn in state.pawns.values():
		if pawn.owner_id != side or pawn.is_eliminated:
			continue
		var d: int = _min_dist(pawn.position, target)
		if d < d1:
			d2 = d1
			d1 = d
		elif d < d2:
			d2 = d
	return [d1, d2]


func _min_dist(pos: Vector2i, target: Array) -> int:
	var best: int = 99999
	for t in target:
		var d: int = abs(pos.x - t.x) + abs(pos.y - t.y)
		if d < best:
			best = d
	return best


# =========================================================================
# Actie-enumeratie + simulatie (voor greedy/negamax)
# =========================================================================

func enumerate_actions(state: GameState, side: int) -> Array:
	var actions: Array = []
	for pawn in state.get_active_pawns_for(side):
		if not Rules.can_pawn_act(state, pawn.id):
			continue
		# Melee (infanterie + cavalerie-op-de-plaats).
		for target_id in Rules.get_valid_melee_targets(state, pawn.id):
			actions.append({"type": "attack", "attacker_id": pawn.id, "defender_id": target_id})
		# Beschietingen (infanterieschot / artillerievuur).
		for target_id in Rules.get_valid_shot_targets(state, pawn.id):
			actions.append({"type": "shot", "shooter_id": pawn.id, "target_id": target_id})
		# Bewegen (voor cavalerie is dit de charge zonder aanval).
		var paths: Dictionary = Rules.get_valid_move_paths(state, pawn.id)
		for pos in paths.keys():
			actions.append({"type": "move", "pawn_id": pawn.id, "target": pos})
		# Cavalerie: charge = bewegen + melee in één actie (kost stappen + 1).
		if pawn.unit_type == Constants.UnitType.CAVALRY:
			for pos in paths.keys():
				if (paths[pos] as Array).size() + 1 > pawn.remaining_stamina:
					continue
				for neighbor in Constants.manhattan_neighbors(pos):
					var other: Pawn = state.get_pawn_at(neighbor)
					if other != null and other.owner_id != side and not other.is_eliminated:
						actions.append({
							"type": "charge",
							"pawn_id": pawn.id,
							"move_target": pos,
							"defender_id": other.id,
						})
	return actions


func simulate(state: GameState, action: Dictionary) -> GameState:
	var copy: GameState = state.clone()
	match String(action.type):
		"move":
			Rules.apply_move(copy, action.pawn_id, action.target)
		"attack":
			Rules.apply_melee(copy, action.attacker_id, action.defender_id)
		"shot":
			Rules.apply_shot(copy, action.shooter_id, action.target_id)
		"charge":
			Rules.apply_charge(copy, action.pawn_id, action.move_target, action.defender_id)
	return copy


## Wolf-doctrine: kies de gratis stap na een melee (of sla hem over).
## Retour: {} = overslaan, {"target": Vector2i} = stap.
func choose_wolf_step(state: GameState) -> Dictionary:
	var pawn_id: int = state.pending_wolf_step_pawn
	if pawn_id == -1:
		return {}
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null or pawn.is_eliminated:
		return {}
	var best_val: int = evaluate(state, player_id)  # overslaan als baseline
	var best: Dictionary = {}
	for neighbor in Constants.manhattan_neighbors(pawn.position):
		if not Constants.is_on_board(neighbor) or not state.is_tile_empty(neighbor):
			continue
		var copy: GameState = state.clone()
		if not Rules.apply_wolf_step(copy, pawn_id, neighbor):
			continue
		var v: int = evaluate(copy, player_id)
		if v > best_val:
			best_val = v
			best = {"target": neighbor}
	return best


func best_greedy_action(state: GameState) -> Dictionary:
	var actions: Array = enumerate_actions(state, player_id)
	if actions.is_empty():
		return {}
	var best: Dictionary = actions[0]
	var best_val: int = -2147483647
	for a in actions:
		var v: int = evaluate(simulate(state, a), player_id)
		if v > best_val:
			best_val = v
			best = a
	return best


# =========================================================================
# Helpers
# =========================================================================

func _pawn_has_room_to_act(state: GameState, pawn: Pawn) -> bool:
	for neighbor in Constants.manhattan_neighbors(pawn.position):
		if not Constants.is_on_board(neighbor):
			continue
		if state.is_tile_empty(neighbor):
			return true
		var other: Pawn = state.get_pawn_at(neighbor)
		if other != null and other.owner_id != pawn.owner_id and not other.is_eliminated:
			return true
	return false


func _filter_movable_pawns(state: GameState, pawns: Array) -> Array:
	var result: Array = []
	for pawn in pawns:
		if _pawn_has_room_to_act(state, pawn):
			result.append(pawn)
	return result
