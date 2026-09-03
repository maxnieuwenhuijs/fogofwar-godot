class_name ClientState
extends RefCounted

## F4.3d — van fog-view naar een speelbare, renderbare GameState aan de
## CLIENT-kant. De kern is Agent.reconstruct_state (B11): dat bouwt al elke
## arena-partij een staat uit een view, met puntschattingen voor gedekte
## '?'-stats, en gaf in de proef van 3 september 4672 van de 4672 keer exact
## dezelfde legale acties als de volle staat. Die functie blijft onaangeraakt
## (trainingspaden, ablaties); dit is de wrapper die aanvult wat een CLIENT
## nog mist en een agent niet:
##
##   - de eigen blinde commits (doctrine, spawn) terugzetten, anders biedt de
##     validator opnieuw CHOOSE_DOCTRINE/SPAWN aan en antwoordt de server 422;
##   - de vier publieke sleutels van F4.3d: last_initiative_winner (tiebreak
##     bij een gelijk bod), eind_reden, turn_deadline en clocks.
##
## Lek-invariant: de client past NOOIT lokaal Reducer.apply toe op deze staat
## (kaart-ids zijn server-toegewezen); alleen Validator voor highlights. De
## view komt als JSON-tekst binnen, dus elk getal kan een float zijn: alles
## gaat door int()/String().

static func uit_view(view: Dictionary) -> GameState:
	var s: GameState = Agent.reconstruct_state(view)
	var viewer: int = int(view.viewer)
	# Volgorde herstellen. JSON sorteert object-sleutels (Godot: alfabetisch,
	# dus "10" vóór "2"; Node: numeriek) en een Dictionary volgt de tekst-
	# volgorde. In de echte staat staan pionnen en kaarten op id-volgorde
	# (ids lopen op bij spawnen), en daar leunt alles op wat over de dict
	# itereert: Validator.legal_actions, _build_pawn_views, de HUD. Zonder
	# deze stap wijkt de client af van de server in iets dat er semantisch
	# niet toe hoort te doen maar in tests en highlights wel opvalt.
	_sorteer_op_id(s)
	# Eigen blinde factiekeuze (PRE_GAME): zichtbaar in de eigen view, en de
	# validator moet weten dat hij al gedaan is.
	var commit: int = int(view.get("own_doctrine_commit", -1))
	if commit >= 0:
		s.doctrine_commits[viewer] = commit
	# Eigen spawn-inzet (CYCLE_SPAWN): posities komen als [x, y].
	var spawns: Array = []
	for e in view.get("own_spawn_commit", []):
		var pos = e.get("pos", null)
		var v: Vector2i = pos if pos is Vector2i \
			else Vector2i(int(pos[0]), int(pos[1])) if pos is Array and pos.size() == 2 \
			else Vector2i.ZERO
		spawns.append({"type": int(e.get("type", 0)), "pos": v})
	if not spawns.is_empty():
		s.spawn_commits[viewer] = spawns
	# De vier publieke sleutels (F4.3d).
	s.last_initiative_winner = int(view.get("last_initiative_winner", s.last_initiative_winner))
	s.eind_reden = String(view.get("eind_reden", ""))
	s.turn_deadline = int(view.get("turn_deadline", 0))
	s.clocks = {}
	var clocks = view.get("clocks", {})
	if clocks is Dictionary:
		for k in clocks:
			var bank = clocks[k]
			s.clocks[int(String(k))] = {"bank_ms": int(bank.get("bank_ms", 0)) if bank is Dictionary else 0}
	return s


static func _sorteer_op_id(s: GameState) -> void:
	var pawn_ids: Array = s.pawns.keys()
	pawn_ids.sort()
	var pawns: Dictionary = {}
	for id in pawn_ids:
		pawns[id] = s.pawns[id]
	s.pawns = pawns
	var card_ids: Array = s.all_cards.keys()
	card_ids.sort()
	var cards: Dictionary = {}
	for id in card_ids:
		cards[id] = s.all_cards[id]
	s.all_cards = cards


## Wat de client over de tegenstander mag weten in de commit-fasen: alleen
## DAT hij iets deed, nooit wat. Voor de wachtteksten in game.gd.
static func tegenstander_status(view: Dictionary) -> Dictionary:
	return {
		"enemy_has_chosen": bool(view.get("enemy_has_chosen", false)),
		"enemy_has_defined": bool(view.get("enemy_has_defined", false)),
		"enemy_has_spawned": bool(view.get("enemy_has_spawned", false)),
	}


## Is deze pion voor de kijker gedekt (Krokodil-schutkleur)? In de view is
## dat het '?'-sentinel op de stats; dit is de client-kant van
## SessionInterface.pion_gedekt.
static func pion_gedekt(view: Dictionary, pawn_id: int) -> bool:
	var pd = (view.get("pawns", {}) as Dictionary).get(str(pawn_id), null)
	if pd == null:
		return false
	return pd.get("current_hp", 0) is String
