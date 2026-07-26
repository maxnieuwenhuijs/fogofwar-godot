class_name CView
extends RefCounted

# F3.1 — de per-speler campagne-view. Het grootboek is PUBLIEK (spec §6:
# "Among Us-gevoel" — wie goed boekhoudt kent ieders voorraad; dat is de
# skill). Team-only: de lopende nominatie-stemmen van het eigen team.
# Wie uitgevallen is ziet alles (spec: "wie dood is ziet alles").


static func for_player(c: CState, viewer: int) -> Dictionary:
	var kijker: Dictionary = c.spelers.get(viewer, {})
	var dood: bool = not kijker.is_empty() and String(kijker.status) != "actief"
	var eigen_team: int = int(kijker.get("team", -1))
	var spelers_d: Dictionary = {}
	for id in c.spelers:
		var sp: Dictionary = c.spelers[id]
		spelers_d[str(id)] = {
			"naam": String(sp.naam),
			"team": int(sp.team),
			"status": String(sp.status),
			"punten": c.punten_van(int(id)),
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
