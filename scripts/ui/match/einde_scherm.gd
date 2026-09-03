class_name EindeScherm
extends RefCounted

## Het einde van een duel in beeld: welk uitslag-icoon (pdf pagina 4,
## "Results") hoort bij HOE de partij eindigde. De reden staat sinds V0
## expliciet in GameState.eind_reden ("haven", "eliminatie", "resign",
## "timeout"); voor een staat zonder reden (oude logs) wordt hij uit het bord
## afgeleid. Alleen presentatie: leest de staat, verandert niets.
##
##   _overlay.show_choice(titel, body, opties, cb, UiAssets.team_kleur(winner_id),
##       false, [], EindeScherm.win_icoon(session.state, winner_id))

## Winreden: "haven" | "eliminatie" | "resign" | "timeout".
static func winreden(state: GameState, winner_id: int) -> String:
	if state == null:
		return ""
	var reden := String(state.eind_reden)
	if reden != "":
		return reden
	# Afleiden: genoeg winnaar-pionnen in de haven -> haven; verliezer zonder
	# levende pionnen -> eliminatie; anders is er opgegeven.
	if Rules.count_pawns_in_haven(state, winner_id) >= state.rules.pawns_in_haven_to_win:
		return "haven"
	var verliezer := Constants.opponent(winner_id)
	if state.get_alive_pawns_for(verliezer).is_empty():
		return "eliminatie"
	return "resign"


## Icoon-id (UiAssets.icoon) bij een winreden.
static func icoon_voor(reden: String) -> String:
	match reden:
		"haven":
			return "win-harbor"
		"eliminatie":
			return "dead"
		"resign", "timeout":
			return "forfeit"
	return "win-harbor"


## Kortste weg: het icoon-id voor de eindstaat van dit duel.
static func win_icoon(state: GameState, winner_id: int) -> String:
	return icoon_voor(winreden(state, winner_id))
