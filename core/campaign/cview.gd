class_name CView
extends RefCounted

# F3.1 — de per-speler campagne-view.
#
# BIJGESTELD 30 juli (Max: "bij ieder potje kan je wel zien wat de reserve is en
# de CP van je tegenstander"). Hier stond dat het grootboek volledig publiek is,
# maar spec 6 is duidelijker: "Vijandelijke voorraad en CP zijn verborgen -- in
# duels (D12) EN op de campagnekaart. De informatiebron is het battlereport."
# Zonder dat is de fog in het duel zinloos: je leest de saldi gewoon in de hub.
#
# Dus: roem (punten), namen, teams, status, duels en bracket blijven publiek;
# de SALDI (voorraad en CP) zijn team-only. Wie uitgevallen is ziet alles
# (spec: "wie dood is ziet alles"). Het verborgen saldo is het "?"-sentinel,
# net als in de duel-view (D12).


## Zelfde sentinel als de duel-view (View.HIDDEN): "?" betekent "niet te zien".
const HIDDEN := "?"


## Mag deze kijker het saldo van die speler zien? Eigen team wel, de vijand
## niet, en wie zelf uitgevallen is ziet alles.
static func mag_saldo_zien(c: CState, viewer: int, speler: int) -> bool:
	var kijker: Dictionary = c.spelers.get(viewer, {})
	if kijker.is_empty():
		return false
	if String(kijker.get("status", "actief")) != "actief":
		return true
	var doel: Dictionary = c.spelers.get(speler, {})
	if doel.is_empty():
		return false
	return int(doel.get("team", -2)) == int(kijker.get("team", -1))


static func for_player(c: CState, viewer: int) -> Dictionary:
	var kijker: Dictionary = c.spelers.get(viewer, {})
	var dood: bool = not kijker.is_empty() and String(kijker.status) != "actief"
	var eigen_team: int = int(kijker.get("team", -1))
	var spelers_d: Dictionary = {}
	for id in c.spelers:
		var sp: Dictionary = c.spelers[id]
		var mag_saldo: bool = dood or int(sp.get("team", -2)) == eigen_team
		spelers_d[str(id)] = {
			"naam": String(sp.naam),
			"team": int(sp.team),
			"status": String(sp.status),
			"punten": c.punten_van(int(id)),
			# Team-only (D12): de vijand ziet "?" in plaats van een saldo.
			"pool": c.pool_van(int(id)) if mag_saldo else HIDDEN,
			"cp": c.cp_van(int(id)) if mag_saldo else HIDDEN,
		}
	var stemmen: Dictionary = {}
	for sid in c.nominatie_stemmen:
		var stemmer_team: int = int(c.spelers[sid].team)
		if dood or stemmer_team == eigen_team:
			stemmen[str(sid)] = (c.nominatie_stemmen[sid] as Dictionary).duplicate()
	return {
		"viewer": viewer,
		"ronde": c.ronde,
		"fase": c.fase,
		"winnaar": c.winnaar,
		"nominatie_team": c.nominatie_team,
		"duels_per_ronde": c.duels_per_ronde(),
		"spelers": spelers_d,
		"ledger": c.ledger.duplicate(true),  # publiek grootboek
		"duels": c.duels_deze_ronde.duplicate(true),
		"bracket": c.bracket.duplicate(true),
		"al_genomineerd": c.al_genomineerd.keys(),
		"donaties_ontvangen": CState._int_keys_naar_str(c.donaties_ontvangen),
		"pending_testamenten": c.pending_testamenten.duplicate(),
		"team_stemmen": stemmen,  # team-only (doden zien alles)
		# Gemak voor de UI: de eigen saldi kant-en-klaar (uit het ledger).
		"eigen_pool": c.pool_van(viewer),
		"eigen_cp": c.cp_van(viewer),
		"eigen_punten": c.punten_van(viewer),
	}
