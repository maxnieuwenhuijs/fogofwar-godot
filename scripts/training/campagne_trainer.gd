class_name CampagneTrainer
extends RefCounted

# F7.2b — de campagnetrainer (docs/F7-campagnetrainer.md §4): leert het
# verstand van de campagnebots (CampaignAgent.VERSTAND: hoe ze handelen in
# het campagnemenu), los van de duelgewichten.
#
#   godot --headless --path . res://arena/arena.tscn -- --campagnetrain [--config <json>] [--out <map>]
#
# Config (arena/arena_configs/campagne_train.json):
#   {"minuten": 60, "orakel": "res://data/duel_orakel.json", "kandidaten": 8,
#    "seeds": 60, "controle_seeds": 200, "base_seed": 900000, "sigma": 0.35,
#    "spelers": 16, "adoptie": 0.53, "uit": "res://data/campagne_verstand.json"}
#
# Elke generatie: `kandidaten` varianten van de kampioen (gespiegeld: plus en
# min dezelfde ruis), elk `seeds` campagnes tegen de kampioen, en elke seed
# nog eens met de teams gewisseld. De kandidaat speelt alle stoelen van zijn
# team, de kampioen alle stoelen van het andere: dit leert hoe een TEAM moet
# handelen. De beste gaat door een controle op verse seeds; wint zijn team daar
# minstens `adoptie` van de campagnes, dan wordt hij kampioen en schrijft de
# trainer `uit`. Elke 5 generaties: de kampioen tegen die van 5 generaties terug
# (de check uit het masterplan: >55%) en tegen de handbots (verstand leeg).
#
# F6.0-P4 (30 september, docs/F6-punten-masterplan.md §8): "fitness":
# "punten" leert een bot zijn EIGEN punten najagen in plaats van de teamwinst.
# Gemengde stoelen: in elk team speelt de helft (om en om op stoelnummer) de
# kandidaat en de helft de kampioen, per seed nog eens andersom. Een campagne
# telt voor de kandidaat als zijn helft gemiddeld meer punten haalde (gelijk =
# half). De teampot valt zo weg (beide helften zitten in beide teams); wat telt
# is wie er binnen het team beter van wordt. Extra sleutels:
#   "tabel"     afwijking van puntentabel v1, bv {"kampioen": 20, ...}
#   "start"     verstand om mee te beginnen als `uit` nog niet bestaat
#               (res://data/campagne_verstand.json: het teamverstand)
#   "sleutels"  welke knoppen de trainer verschuift; standaard alle bij
#               "punten" en alle behalve w_sparen/w_rivaal bij "team"
#
# Alles speelt op het duel-orakel (een campagne kost dan zo'n 150
# milliseconden). De kampioen hoort daarna op ECHTE duels nagemeten te worden
# (campagne_arena.ps1 met een campagnes-config), anders leert hij de gaten in
# het orakel. Het karakter (personalities.gd) raakt de trainer nooit aan.

const _Orakel := preload("res://scripts/training/duel_orakel.gd")


static func train(config: Dictionary, out_map: String, git_sha: String) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var budget_ms: int = int(float(config.get("minuten", 60)) * 60000.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_map))
	var logf := FileAccess.open(out_map.path_join("train.log"), FileAccess.WRITE)
	var orakel_pad := String(config.get("orakel", _Orakel.STANDAARD))
	if _Orakel.laad(orakel_pad) == null:
		_schrijf(logf, "[TRAIN] geen orakel op %s: eerst de datarun en tools/campagne/maak_orakel.py" % orakel_pad)
		logf.close()
		return {"generaties": 0, "adopties": 0}
	var speel := {"spelers": int(config.get("spelers", 16)), "duel_modus": "orakel",
		"orakel": orakel_pad, "duel_log": false, "max_stappen": int(config.get("max_stappen", 400))}
	var uit_pad := String(config.get("uit", CampaignAgent.VERSTAND_PAD))
	var fitness := String(config.get("fitness", "team"))
	if fitness == "punten":
		speel["tabel"] = config.get("tabel", {})
	var kampioen: Dictionary = _start(config, uit_pad)
	var startverstand: Dictionary = kampioen.duplicate()
	if config.has("start") and not FileAccess.file_exists(uit_pad):
		# F6.0-P4: zonder adoptie blijft het startverstand de kampioen. Meteen in
		# `uit`, anders meet een meting daarna de handbots.
		_bewaar(uit_pad, kampioen, 0, 0.5, orakel_pad, git_sha, config)
	var sleutels: Array = config.get("sleutels", standaard_sleutels(fitness))
	var sigma: float = float(config.get("sigma", 0.35))
	var n_kand: int = maxi(2, int(config.get("kandidaten", 8)) / 2 * 2)
	var n_seeds: int = int(config.get("seeds", 60))
	var n_controle: int = int(config.get("controle_seeds", 200))
	var adoptie: float = float(config.get("adoptie", 0.53))
	var base_seed: int = int(config.get("base_seed", 900000))
	var rng := SeededRng.new(base_seed)
	var historie: Array = [kampioen.duplicate()]
	var adopties := 0
	var gen := 0
	_schrijf(logf, "[TRAIN] start: %s, orakel %s, %d kandidaten x %d seeds x 2, controle %d x 2, adoptie %.0f%%" % [
		git_sha, orakel_pad, n_kand, n_seeds, n_controle, adoptie * 100.0])
	_schrijf(logf, "[TRAIN] fitness %s%s, knoppen %s" % [fitness,
		(", tabel " + JSON.stringify(speel.tabel)) if fitness == "punten" else "", ", ".join(PackedStringArray(sleutels))])
	_schrijf(logf, "[TRAIN] kampioen bij de start: %s" % JSON.stringify(kampioen))
	while Time.get_ticks_msec() - t0 < budget_ms:
		gen += 1
		var g0 := Time.get_ticks_msec()
		var seeds: Array = []
		for i in n_seeds:
			seeds.append(base_seed + gen * 1000 + i)
		var kandidaten: Array = []
		for k in n_kand / 2:
			var ruis := {}
			for sleutel in sleutels:
				ruis[sleutel] = rng.randfn(0.0, 1.0)
			kandidaten.append(_verschuif(kampioen, ruis, sigma))
			kandidaten.append(_verschuif(kampioen, ruis, -sigma))
		var beste := -1
		var beste_kans := -1.0
		var beste_extra := ""
		var kansen: Array = []
		for k in kandidaten.size():
			var meting := meet(fitness, speel, kandidaten[k], kampioen, seeds)
			var kans: float = float(meting.kans)
			kansen.append(kans)
			if kans > beste_kans:
				beste_kans = kans
				beste = k
				beste_extra = String(meting.extra)
		var regel := "[TRAIN] gen %d: beste %.1f%%%s (%s), sigma %.2f" % [gen, beste_kans * 100.0, beste_extra,
			", ".join(PackedStringArray(kansen.map(func(x): return "%.0f" % (float(x) * 100.0)))), sigma]
		var geadopteerd := false
		if beste_kans > 0.5:
			var controle: Array = []
			for i in n_controle:
				controle.append(base_seed + 500000 + gen * 1000 + i)
			var meting2 := meet(fitness, speel, kandidaten[beste], kampioen, controle)
			var kans2: float = float(meting2.kans)
			regel += ", controle %.1f%%%s" % [kans2 * 100.0, String(meting2.extra)]
			# Bij punten ook gemiddeld meer: vaker winnen met kleine marges en
			# groot verliezen is geen vooruitgang.
			if kans2 >= adoptie and float(meting2.verschil) >= 0.0:
				kampioen = kandidaten[beste]
				adopties += 1
				geadopteerd = true
				_bewaar(uit_pad, kampioen, gen, kans2, orakel_pad, git_sha, config)
		sigma = clampf(sigma * (1.15 if geadopteerd else 0.9), 0.05, 1.0)
		historie.append(kampioen.duplicate())
		regel += (" -> ADOPTIE " + JSON.stringify(kampioen)) if geadopteerd else " -> blijft"
		regel += " (%.0f s)" % ((Time.get_ticks_msec() - g0) / 1000.0)
		_schrijf(logf, regel)
		if gen % 5 == 0:
			var ijk: Array = []
			for i in n_controle:
				ijk.append(base_seed + 800000 + i)
			if fitness == "punten":
				# Binnen het team: haalt hij meer punten dan die van 5 generaties
				# terug en dan het startverstand? En als heel team tegen een team
				# met het startverstand: kost zijn eigenbelang het team de oorlog?
				var p_vorige := meet(fitness, speel, kampioen, historie[maxi(0, historie.size() - 6)], ijk)
				var p_start := meet(fitness, speel, kampioen, startverstand, ijk)
				var als_team := speel_tegen(speel, kampioen, startverstand, ijk)
				_schrijf(logf, "[TRAIN] check gen %d: punten tegen die van 5 generaties terug %.1f%%%s, tegen het startverstand %.1f%%%s; als heel team tegen het startverstand %.1f%% teamwinst" % [
					gen, float(p_vorige.kans) * 100.0, String(p_vorige.extra), float(p_start.kans) * 100.0,
					String(p_start.extra), als_team * 100.0])
			else:
				var tegen_vorige := speel_tegen(speel, kampioen, historie[maxi(0, historie.size() - 6)], ijk)
				var tegen_hand := speel_tegen(speel, kampioen, {}, ijk)
				_schrijf(logf, "[TRAIN] check gen %d: kampioen tegen die van 5 generaties terug %.1f%% (doel >55%%), tegen de handbots %.1f%%" % [
					gen, tegen_vorige * 100.0, tegen_hand * 100.0])
	_schrijf(logf, "[TRAIN] klaar: %d generaties, %d adopties, kampioen %s" % [gen, adopties, JSON.stringify(kampioen)])
	logf.close()
	return {"generaties": gen, "adopties": adopties, "kampioen": kampioen,
		"duur": (Time.get_ticks_msec() - t0) / 1000.0}


## De knoppen die de trainer standaard verschuift: bij "team" niet de
## eigenbelang-knoppen (w_sparen, w_rivaal), die horen bij de punten.
static func standaard_sleutels(fitness: String) -> Array:
	var uit: Array = []
	for sleutel in CampaignAgent.VERSTAND:
		if fitness == "punten" or not CampaignAgent.VERSTAND_EIGENBELANG.has(sleutel):
			uit.append(sleutel)
	return uit


## Een meting van `a` tegen `b` in de gekozen fitness: {kans, verschil, extra},
## met verschil het gemiddelde puntenverschil per stoel (0 bij "team") en extra
## een stukje logregel.
static func meet(fitness: String, speel: Dictionary, a: Dictionary, b: Dictionary, seeds: Array) -> Dictionary:
	if fitness == "punten":
		var p := speel_punten(speel, a, b, seeds)
		return {"kans": float(p.kans), "verschil": float(p.verschil),
			"extra": " (%+.1f punten)" % float(p.verschil)}
	return {"kans": speel_tegen(speel, a, b, seeds), "verschil": 0.0, "extra": ""}


## F6.0-P4: eigen punten van verstand `a` naast verstand `b` in DEZELFDE
## teams. Per seed twee campagnes: eerst speelt `a` de even stoelen en `b` de
## oneven (in elk team vier en vier), dan andersom, want de stoelen verschillen
## in factie. Per campagne: 1 als de stoelen van `a` gemiddeld meer punten
## haalden, een half bij gelijk, anders 0. Geeft {kans, verschil, n}, met
## verschil = het gemiddelde puntenverschil per stoel.
static func speel_punten(speel: Dictionary, a: Dictionary, b: Dictionary, seeds: Array) -> Dictionary:
	var spelers: int = int(speel.get("spelers", 16))
	var score := 0.0
	var verschil := 0.0
	var n := 0
	for seed_val in seeds:
		for omgedraaid in [false, true]:
			var per_stoel := {}
			for sid in spelers:
				per_stoel[sid] = a if (sid % 2 == 0) != omgedraaid else b
			var uit: Dictionary = CampagneArena.speel_campagne(speel, int(seed_val),
				[{"naam": "gemengd"}, {"naam": "gemengd"}], per_stoel)
			var punten: Dictionary = uit.samenvatting.get("punten", {})
			if punten.is_empty():
				continue  # niet uitgespeeld
			var som_a := 0.0
			var som_b := 0.0
			for sid in spelers:
				if (sid % 2 == 0) != omgedraaid:
					som_a += float(punten.get(str(sid), 0))
				else:
					som_b += float(punten.get(str(sid), 0))
			var d: float = (som_a - som_b) / float(maxi(1, spelers / 2))
			verschil += d
			score += 1.0 if d > 0.0 else (0.5 if d == 0.0 else 0.0)
			n += 1
	return {"kans": score / float(maxi(1, n)), "verschil": verschil / float(maxi(1, n)), "n": n}


## Winkans van verstand `a` tegen verstand `b`: per seed twee campagnes (a als
## team 0 en als team 1). Niet uitgespeelde campagnes tellen niet mee.
static func speel_tegen(speel: Dictionary, a: Dictionary, b: Dictionary, seeds: Array) -> float:
	var winst := 0
	var n := 0
	for seed_val in seeds:
		for omgedraaid in [false, true]:
			var ta := {"naam": "a", "verstand": a}
			var tb := {"naam": "b", "verstand": b}
			var uit: Dictionary = CampagneArena.speel_campagne(speel, int(seed_val), [tb, ta] if omgedraaid else [ta, tb])
			var team: int = int(uit.samenvatting.winnend_team)
			if team < 0:
				continue
			n += 1
			if team == (1 if omgedraaid else 0):
				winst += 1
	return float(winst) / float(maxi(1, n))


## Startpunt: het bestaande verstand in `uit` (verder trainen), anders dat in
## "start" (F6.0-P4: de puntenbots beginnen bij het teamverstand), anders nul.
static func _start(config: Dictionary, uit_pad: String) -> Dictionary:
	var start := {}
	for sleutel in CampaignAgent.VERSTAND:
		start[sleutel] = 0.0
	if bool(config.get("vers", false)):
		return start
	var pad := uit_pad
	if config.has("start") and not FileAccess.file_exists(uit_pad):
		pad = String(config.start)
	var bestaand: Dictionary = CampaignAgent.laad_verstand(pad)
	for sleutel in bestaand:
		if start.has(sleutel):
			start[sleutel] = float(bestaand[sleutel])
	return start


## Kampioen + sigma x ruis, per knop geschaald op zijn bereik en erin geklemd.
static func _verschuif(basis: Dictionary, ruis: Dictionary, sigma: float) -> Dictionary:
	var uit := {}
	for sleutel in CampaignAgent.VERSTAND:
		var grens: Array = CampaignAgent.VERSTAND[sleutel]
		var breedte: float = float(grens[1]) - float(grens[0])
		var v: float = float(basis.get(sleutel, 0.0)) + sigma * breedte * 0.25 * float(ruis.get(sleutel, 0.0))
		uit[sleutel] = snappedf(clampf(v, float(grens[0]), float(grens[1])), 0.001)
	return uit


static func _bewaar(pad: String, verstand: Dictionary, gen: int, kans: float, orakel_pad: String,
		git_sha: String, config: Dictionary) -> void:
	var f := FileAccess.open(pad, FileAccess.WRITE)
	if f == null:
		push_error("CampagneTrainer: kan %s niet schrijven" % pad)
		return
	f.store_string(JSON.stringify({
		"versie": 1,
		"gewichten": verstand,
		"meta": {"generatie": gen, "controle_winkans": snappedf(kans, 0.001), "orakel": orakel_pad,
			"git_sha": git_sha, "ts": Time.get_datetime_string_from_system(), "config": config},
	}, "\t") + "\n")
	f.close()


static func _schrijf(logf: FileAccess, regel: String) -> void:
	print(regel)
	if logf != null:
		logf.store_line(regel)
		logf.flush()
