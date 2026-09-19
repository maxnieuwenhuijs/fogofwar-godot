extends Node

const Bestandsindex := preload("res://scripts/core/bestandsindex.gd")

## Tijdelijke helper om screenshots / input-tests van game.tscn te maken via de CLI.
## Modi (na `--`): (geen)=waaier, `open`=open-stand, `click`=klik-test op de + knop.

func _ready() -> void:
	if "weightio" in OS.get_cmdline_user_args():
		# Per-factie-profiel: alleen de Muis-set wijkt af; de rest blijft default.
		var profile := AIController.default_profile()
		profile[int(Constants.Doctrine.MUIS)]["protect"] = 999.0
		AIController.save_profile(profile)
		var loaded := AIController.load_profile()
		print("[WEIGHTIO] muis.protect=%s (verwacht 999) · mens.protect=%s (verwacht 160) · facties=%d · keys=%d" % [
			str(loaded[int(Constants.Doctrine.MUIS)].get("protect", "?")),
			str(loaded[int(Constants.Doctrine.MENS)].get("protect", "?")),
			loaded.size(), loaded[int(Constants.Doctrine.MENS)].size()])
		get_tree().quit()
		return

	if "uicheck" in OS.get_cmdline_user_args():
		# UI-assetpack (3 september): het statusbord van wat er ligt. Per
		# spec-id het bestand, de zes emblemen, de kaartdelen, elke knop- en
		# paneelstijl met zijn 9-patch-marges, de fonts per rol (bedoeld of
		# terugval), en of het thema en de widgets bouwen. Exit 1 als een
		# bekend bestand ontbreekt of het thema niet bouwt.
		var fouten := 0
		print("[UICHECK] iconen (spec-id -> bestand):")
		for id in UiAssets.icoon_ids():
			var tex := UiAssets.icoon(String(id))
			var bron: String = UiAssets._eerste_aanwezige(UiAssets.ICONEN[id])
			if tex == null:
				fouten += 1
			print("  %-16s %s" % [id, bron if tex != null else "ONTBREEKT"])
		print("[UICHECK] nog niet geleverd (tekst-terugval): %s" % ", ".join(UiAssets.ontbrekende_iconen()))
		print("[UICHECK] emblemen:")
		for d in Constants.DOCTRINE_DATA.keys():
			var e := UiAssets.embleem(int(d))
			if e == null:
				fouten += 1
			print("  %-10s %s" % [Constants.doctrine_name(int(d)), e.resource_path.get_file() if e != null else "ONTBREEKT"])
		print("[UICHECK] kaartdelen:")
		for deel in UiAssets.KAART.keys():
			var k := UiAssets.kaart(String(deel))
			if k == null:
				fouten += 1
			print("  %-20s %s" % [deel, "%s (%dx%d)" % [k.resource_path.get_file(), int(k.get_width()), int(k.get_height())] if k != null else "ONTBREEKT"])
		print("[UICHECK] knoppen (variant: staten, 9-patch-marge x/y):")
		for variant in UiAssets.KNOPPEN.keys():
			var staten: Array = []
			for staat in UiAssets.KNOP_STATEN.keys():
				var sb := UiAssets.knop_stijl(String(variant), String(staat))
				if sb == null:
					fouten += 1
				staten.append("%s=%s" % [staat, "ok" if sb != null else "ONTBREEKT"])
			var spec: Array = UiAssets.KNOPPEN[variant]
			print("  %-12s %-52s marge %d/%d" % [variant, " ".join(staten), int(spec[1]), int(spec[2])])
		print("[UICHECK] panelen:")
		for naam in UiAssets.PANELEN.keys():
			var sb := UiAssets.paneel_stijl(String(naam))
			if sb == null:
				fouten += 1
			var spec: Array = UiAssets.PANELEN[naam]
			print("  %-12s %-30s marge %d/%d %s" % [naam, spec[0], int(spec[1]), int(spec[2]), "" if sb != null else "ONTBREEKT"])
		print("[UICHECK] fonts (rol: bestand, bedoeld door de ontwerper?):")
		for rol in ["tekst", "kop", "cijfers"]:
			var bron := UiAssets.font_bron(rol)
			print("  %-8s %-28s %s" % [rol, bron if bron != "" else "(Godot-standaard)",
				"bedoeld" if UiAssets.font_is_bedoeld(rol) else "TERUGVAL, drop %s in assets/ui/fonts" % UiAssets.FONTS_BEDOELD[rol]])
		var thema := UiAssets.thema()
		var thema_ok: bool = thema != null and thema.has_stylebox("normal", "Button") and thema.has_stylebox("panel", "PaneelPapier")
		if not thema_ok:
			fouten += 1
		print("[UICHECK] thema bouwt: %s (default_font=%s)" % ["ja" if thema_ok else "NEE",
			thema.default_font.resource_path.get_file() if thema != null and thema.default_font != null else "standaard"])
		var widget_ok := true
		var portret := UiPortret.new(64)
		portret.zet(Constants.Doctrine.BEER, "rood", true)
		portret.free()
		var kaart := UiFactieKaart.new(Constants.Doctrine.WOLF, CRules.actieve_tabel().doctrine_data(Constants.Doctrine.WOLF))
		widget_ok = kaart.get_child_count() >= 2
		kaart.free()
		if not widget_ok:
			fouten += 1
		print("[UICHECK] widgets bouwen: %s" % ("ja" if widget_ok else "NEE"))
		print("[UICHECK] %s: %d fouten" % ["PASS" if fouten == 0 else "FAIL", fouten])
		get_tree().quit(0 if fouten == 0 else 1)
		return

	if "arena" in OS.get_cmdline_user_args():
		# Meet-toernooi (géén training): speelt elke doctrine-matchup en print een
		# winrate-matrix "wie wint tegen wie" met het huidige opgeslagen profiel.
		# Gebruik: -- arena [potjes-per-matchup] [ai-level]  (default 20, medium)
		var aargs := OS.get_cmdline_user_args()
		var ai_idx := aargs.find("arena")
		var per: int = int(aargs[ai_idx + 1]) if aargs.size() > ai_idx + 1 else 20
		var lvl: String = String(aargs[ai_idx + 2]) if aargs.size() > ai_idx + 2 else "medium"
		_run_arena(per, lvl)
		get_tree().quit()
		return

	if "shot" in OS.get_cmdline_user_args():
		# F3.3 — scherm-fixture + PNG + node-asserts: het standaardgereedschap
		# voor UI-checks (headless: screenshot overslaan, asserts blijven).
		var shargs := OS.get_cmdline_user_args()
		var shi := shargs.find("shot")
		var scherm: String = String(shargs[shi + 1]) if shargs.size() > shi + 1 else "campaign_hub"
		var shot_seed: int = int(shargs[shi + 2]) if shargs.size() > shi + 2 else 42
		if not ["campaign_hub", "ledger", "bracket"].has(scherm):
			print("[SHOT] onbekend scherm: %s" % scherm)
			get_tree().quit(1)
			return
		var shot_fouten := 0
		if scherm == "campaign_hub":
			var sdriver := SoloDriver.new(shot_seed, 0)
			sdriver.duel_ai = "easy"
			var hub: Control = load("res://scripts/ui/campaign/campaign_hub.gd").new()
			hub.driver = sdriver
			hub.mens_id = 0
			add_child(hub)
			await get_tree().create_timer(1.2).timeout
			for node_naam in ["Header", "Saldi", "Tijdlijn", "FasePaneel", "GrootboekKnop",
					"TeamLinks", "TeamRechts"]:
				if hub.find_child(node_naam, true, false) == null:
					shot_fouten += 1
					print("[SHOT] node ontbreekt: %s" % node_naam)
			var kop: Label = hub.find_child("Header", true, false)
			# i18n-proof: check op het vertaalde fragment i.p.v. hardcoded "Ronde".
			if kop == null or not kop.text.contains(hub.tr("HUB_HEADER").split("%d")[0].strip_edges()):
				shot_fouten += 1
				print("[SHOT] header toont geen ronde/round")
			for kolom_naam in ["TeamLinks", "TeamRechts"]:
				var tk: VBoxContainer = hub.find_child(kolom_naam, true, false)
				if tk == null or tk.get_child_count() < 9:
					shot_fouten += 1
					print("[SHOT] %s mist teamrijen (titel + 8 leden)" % kolom_naam)
		elif scherm == "ledger":
			var ldriver := SoloDriver.new(shot_seed, 0)
			var lscherm: Control = load("res://scripts/ui/campaign/ledger_screen.gd").new()
			add_child(lscherm)
			lscherm.open(ldriver.c, 0)
			await get_tree().create_timer(0.5).timeout
			for node_naam in ["Grootboek", "GrootboekTabel", "GrootboekSluit"]:
				if lscherm.find_child(node_naam, true, false) == null:
					shot_fouten += 1
					print("[SHOT] node ontbreekt: %s" % node_naam)
			var tabel: VBoxContainer = lscherm.find_child("GrootboekTabel", true, false)
			if tabel == null or tabel.get_child_count() != 16:
				shot_fouten += 1
				print("[SHOT] grootboek-tabel mist rijen")
		elif scherm == "bracket":
			var bc := CState.new()
			var blijst: Array = []
			for i in 6:
				blijst.append({"naam": "Speler%d" % i, "doctrine": 0})
			bc.setup(blijst, CRules.new())
			bc.fase = CState.Fase.BURGEROORLOG
			bc.duels_deze_ronde = [{"p1": 0, "p2": 3, "klaar": false}]
			bc.bracket = [[1, 4]]
			# Op de veldtafel met een marge, zoals in de hub (anders Godot-grijs).
			var bvlak := ColorRect.new()
			bvlak.color = UiAssets.VELDTAFEL
			bvlak.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(bvlak)
			var bview: VBoxContainer = load("res://scripts/ui/campaign/bracket_view.gd").new()
			add_child(bview)
			bview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bview.offset_left = 24.0
			bview.offset_top = 24.0
			bview.offset_right = -24.0
			bview.vul(bc)
			await get_tree().create_timer(0.5).timeout
			if bview.get_child_count() < 4:
				shot_fouten += 1
				print("[SHOT] bracket toont te weinig regels")
			var vs_gezien := false
			for kind in bview.get_children():
				if kind is Label and (kind as Label).text.contains("vs"):
					vs_gezien = true
			if not vs_gezien:
				shot_fouten += 1
				print("[SHOT] bracket toont geen duel-paren")
		var tex := get_viewport().get_texture()
		if tex != null and tex.get_image() != null:
			tex.get_image().save_png("res://_shot_%s.png" % scherm)
			print("[SHOT] screenshot -> _shot_%s.png" % scherm)
		else:
			print("[SHOT] headless: geen viewport-texture, screenshot overgeslagen")
		print("[SHOT] %s: %d fouten" % [scherm, shot_fouten])
		get_tree().quit(0 if shot_fouten == 0 else 1)
		return
	if "solocheck" in OS.get_cmdline_user_args():
		# F3.2-CHECK: N volledige solo-campagnes headless (16 bots) -> kampioen,
		# geen deadlocks; plus een determinisme-paar op de eerste seed.
		var sargs := OS.get_cmdline_user_args()
		var si := sargs.find("solocheck")
		var n_runs: int = int(sargs[si + 1]) if sargs.size() > si + 1 else 5
		var t0 := Time.get_ticks_msec()
		var fouten := 0
		for i in n_runs:
			var seed_val: int = 42000 + i
			var driver := SoloDriver.new(seed_val)
			driver.duel_ai = "easy"  # snelle duels: de check meet flow/determinisme, niet AI-kwaliteit
			driver.duel_honger_vanaf = 4
			driver.duel_max_steps = 1500  # V0: de noodstop levert geen uitslag meer op
			var kampioen: int = driver.run_headless()
			var duur := (Time.get_ticks_msec() - t0) / 1000.0
			if kampioen == -1:
				fouten += 1
				print("[SOLO] seed %d: DEADLOCK (fase %d, ronde %d)" % [seed_val, driver.c.fase, driver.c.ronde])
			else:
				print("[SOLO] seed %d: kampioen %s (%d duels, %d rondes, feed %d) · %.1f s" % [
					seed_val, driver.c.spelers[kampioen].naam, driver.duels_gespeeld,
					driver.c.ronde, driver.feed.size(), duur])
		var d1 := SoloDriver.new(42000)
		d1.duel_ai = "easy"
		d1.duel_honger_vanaf = 4
		d1.duel_max_steps = 1500
		var d2 := SoloDriver.new(42000)
		d2.duel_ai = "easy"
		d2.duel_honger_vanaf = 4
		d2.duel_max_steps = 1500
		var k1: int = d1.run_headless()
		var k2: int = d2.run_headless()
		var determinist: bool = k1 == k2 and d1.clog.entries.size() == d2.clog.entries.size()
		print("[SOLO] determinisme: %s (kampioen %d==%d, log %d==%d)" % [
			"OK" if determinist else "FAIL", k1, k2, d1.clog.entries.size(), d2.clog.entries.size()])
		var totaal := (Time.get_ticks_msec() - t0) / 1000.0
		print("[SOLO] klaar: %d/%d runs OK in %.1f s" % [n_runs - fouten, n_runs, totaal])
		get_tree().quit(0 if fouten == 0 and determinist else 1)
		return
	if "duelstats" in OS.get_cmdline_user_args():
		# F3-tuning: methode-verdeling van campagne-duels per cycluslimiet.
		# Gebruik: -- duelstats [ai] [seeds] [spelers] — meet hoe vaak duels
		# echt beslist worden (haven/eliminatie) versus de tiebreak-vangnet.
		var dargs := OS.get_cmdline_user_args()
		var di := dargs.find("duelstats")
		var d_ai: String = String(dargs[di + 1]) if dargs.size() > di + 1 else "medium"
		var d_seeds: int = int(dargs[di + 2]) if dargs.size() > di + 2 else 2
		var d_spelers: int = int(dargs[di + 3]) if dargs.size() > di + 3 else 6
		for limiet in [6, 12, 24, 0]:
			var telling := {"tiebreak": 0, "haven": 0, "eliminatie": 0, "remise": 0}
			var rondes := 0
			var duels := 0
			var t0d := Time.get_ticks_msec()
			for s_i in d_seeds:
				var dd := SoloDriver.new(1000 + s_i, -1, d_spelers)
				dd.duel_ai = d_ai
				dd.duel_honger_vanaf = limiet
				dd.duel_max_steps = 4000 if limiet == 0 else 400 + limiet * 120
				dd.run_headless(1600)
				rondes += dd.c.ronde
				duels += dd.duels_gespeeld
				for e in dd.feed:
					if String(e.get("type", "")) == "report":
						if int(e.winnaar) == -1:
							telling.remise = int(telling.remise) + 1
						else:
							telling[String(e.methode)] = int(telling[String(e.methode)]) + 1
			print("[DUELSTATS] limiet=%s ai=%s: haven %d · eliminatie %d · tiebreak %d · remise %d — gem %.1f rondes, %.1f duels per campagne · %.1f s" % [
				"uit" if limiet == 0 else str(limiet), d_ai, int(telling.haven),
				int(telling.eliminatie), int(telling.tiebreak), int(telling.remise),
				float(rondes) / d_seeds, float(duels) / d_seeds,
				(Time.get_ticks_msec() - t0d) / 1000.0])
		get_tree().quit(0)
		return
	if "train" in OS.get_cmdline_user_args():
		# Headless auto-trainer (CMA-lite), géén dashboard nodig.
		# Gebruik: -- train [minuten] [populatie] [potjes-per-kandidaat] [factie]
		# Met factie (mens/muis/leeuw/beer/wolf/vos) traint dit proces alléén die
		# factie en schrijft naar een eigen override-bestand → meerdere processen
		# kunnen veilig naast elkaar draaien (64-cores-route, train_ai_parallel.bat).
		# Stoppen mag altijd (Ctrl+C): elke verbetering is al opgeslagen.
		var targs := OS.get_cmdline_user_args()
		var ti := targs.find("train")
		var minutes: float = float(targs[ti + 1]) if targs.size() > ti + 1 else 60.0
		var pop: int = int(targs[ti + 2]) if targs.size() > ti + 2 else 6
		var games: int = int(targs[ti + 3]) if targs.size() > ti + 3 else 6
		var faction: int = -1
		if targs.size() > ti + 4:
			var fnames := {"mens": Constants.Doctrine.MENS, "varken": Constants.Doctrine.MENS, "muis": Constants.Doctrine.MUIS,
				"leeuw": Constants.Doctrine.LEEUW, "beer": Constants.Doctrine.BEER,
				"wolf": Constants.Doctrine.WOLF, "vos": Constants.Doctrine.VOS, "krokodil": Constants.Doctrine.VOS}
			faction = fnames.get(String(targs[ti + 4]).to_lower(), -1)
		# F0.1: optionele run-seed als 5e argument; zonder seed varieert de run
		# (exploratie), mét seed is de hele trainingsrun reproduceerbaar.
		var train_seed: int = int(targs[ti + 5]) if targs.size() > ti + 5 else int(Time.get_ticks_msec())
		# F2.5: optioneel 6e argument = pad naar een rules-json (bv.
		# arena/arena_configs/rules_v42_campaign.json) — trainen onder v4.2.
		if targs.size() > ti + 6:
			_train_rules = RulesConfig.load_from_file(String(targs[ti + 6]))
			print("[TRAIN] Regels: %s (%s)" % [String(targs[ti + 6]), _train_rules.rules_version])
		_run_training(minutes, pop, games, faction, train_seed)
		get_tree().quit()
		return

	if "genrules" in OS.get_cmdline_user_args():
		# Schrijf RulesConfig.defaults() naar json (F0.2).
		# Gebruik: -- genrules [pad]  (default: res://arena/arena_configs/v41_default.json)
		var gargs := OS.get_cmdline_user_args()
		var gi := gargs.find("genrules")
		var gpath := String(gargs[gi + 1]) if gargs.size() > gi + 1 else "res://arena/arena_configs/v41_default.json"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(gpath.get_base_dir()))
		RulesConfig.defaults().save_to_file(gpath)
		print("[GENRULES] %s geschreven (%s)" % [gpath, RulesConfig.defaults().rules_version])
		get_tree().quit()
		return

	if "showweights" in OS.get_cmdline_user_args():
		# Print het actieve (gemergde) profiel zoals het spel het zou laden.
		var sw_profile := AIController.load_profile()
		if sw_profile.is_empty():
			print("[WEIGHTS] Geen opgeslagen profiel — het spel speelt met defaults.")
		else:
			for d in Constants.DOCTRINE_DATA.keys():
				var w: Dictionary = sw_profile[int(d)]
				var src := "override" if FileAccess.file_exists(AIController.override_path(int(d))) else "hoofdbestand"
				print("[WEIGHTS] %-6s (%s)  haven %.0f · ranged %.1f · protect %.0f · art_value %.1f · cav_value %.1f · art_center %.2f" % [
					Constants.doctrine_name(int(d)), src, float(w.haven), float(w.ranged),
					float(w.protect), float(w.art_value), float(w.cav_value), float(w.art_center)])
		get_tree().quit()
		return

	if "trainer" in OS.get_cmdline_user_args():
		var tr = load("res://scenes/training/Trainer.tscn").instantiate()
		add_child(tr)
		await get_tree().create_timer(0.3).timeout
		tr.set("_steps_per_frame", 8)  # laag voor de test (16+eval potjes is zwaar)
		await get_tree().create_timer(6.0).timeout
		print("[TRAINER] run klaar, generatie=%d — screenshot opslaan" % tr.get("_generation"))
		var tr_tex := get_viewport().get_texture()
		if tr_tex != null and tr_tex.get_image() != null:
			tr_tex.get_image().save_png("res://_shot_trainer.png")
			print("[TRAINER] screenshot opgeslagen")
		else:
			print("[TRAINER] headless: geen viewport-texture, screenshot overgeslagen")
		get_tree().quit()
		return

	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.8).timeout
	var args := OS.get_cmdline_user_args()
	var out := "res://_shot.png"

	if "click" in args:
		var hand: CardHand = game.get_node("UI/CardHand")
		var lines: Array[String] = []
		for idx in hand.get_card_views().size():
			var card: CardView = hand.get_card_views()[idx]
			var before: int = card.data.hp
			var plus: Button = card.get_node("%HpPlus")
			var center: Vector2 = plus.get_global_transform() * (plus.size * 0.5)
			_click_at(center)
			await get_tree().create_timer(0.2).timeout
			lines.append("kaart%d %d->%d @(%d,%d)" % [idx, before, card.data.hp, center.x, center.y])
		print("[CLICKTEST] " + ", ".join(lines))
		out = "res://_shot_click.png"
	elif "picktest" in args:
		var hand: CardHand = game.get_node("UI/CardHand")
		var steps := 0
		while GameSession.state.phase != Phase.Type.ACTION and steps < 300:
			steps += 1
			var st: GameState = GameSession.state
			if st.phase == Phase.Type.PRE_GAME:
				game._start_match(1)
			elif st.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(st.phase):
				game._continue_after_reveal()
			elif Phase.is_define(st.phase) and st.cards_defined[1].size() == 0:
				for c in hand.get_card_views():
					c.data.hp = 3
					c.data.stamina = 2
					c.data.attack = 2
					c._refresh()
				hand._on_confirm_pressed()
			elif Phase.is_linking(st.phase) and st.current_player == 1:
				for i in st.cards_revealed[1].size():
					if not st.cards_revealed[1][i].is_linked():
						game._on_link_card_picked(i)
						break
				for pawn in st.pawns.values():
					if pawn.owner_id == 1 and not pawn.is_eliminated and pawn.linked_card_id == -1 and game._pawn_has_room(pawn):
						game._on_link_pawn_clicked(pawn.id)
						break
			await get_tree().create_timer(0.02).timeout
		GameSession.state.current_player = 1
		await get_tree().physics_frame
		await get_tree().physics_frame
		var target = null
		for pawn in GameSession.state.pawns.values():
			if pawn.owner_id == 1 and pawn.is_active and not pawn.is_eliminated \
					and Rules.can_pawn_act(GameSession.state, pawn.id) and pawn.remaining_stamina >= 2:
				target = pawn
				break
		var ctrl_pv = game._pawn_views[target.id]
		var ctrl_screen = game._camera.unproject_position(ctrl_pv.global_position + Vector3(0, 0.6, 0))
		var ctrl_hit = game._raycast_pawn(ctrl_screen)
		game._select_pawn(target.id)
		var one_step = null
		for m in game._valid_moves:
			if abs(m.x - target.position.x) + abs(m.y - target.position.y) == 1:
				one_step = m
				break
		var tile_world = game._board.to_global(game.tile_position(one_step.x, one_step.y) + Vector3(0, 0.1, 0))
		var tile_pick = game._pick_move_tile(game._camera.unproject_position(tile_world))
		game._on_tile_clicked(one_step)
		await get_tree().create_timer(0.7).timeout
		GameSession.state.current_player = 1
		var moved_pv = game._pawn_views[target.id]
		var moved_screen = game._camera.unproject_position(moved_pv.global_position + Vector3(0, 0.6, 0))
		var moved_hit = game._raycast_pawn(moved_screen)
		print("[PICK] ctrl_pion=%d tile_pick=%s na_verplaatsen=%d | verwacht: pion=%d tile=%s" % [
			ctrl_hit, str(tile_pick), moved_hit, target.id, str(one_step)])
		get_tree().quit()
		return
	elif "movehl" in args:
		var hand: CardHand = game.get_node("UI/CardHand")
		var steps := 0
		while GameSession.state.phase != Phase.Type.ACTION and steps < 300:
			steps += 1
			var st: GameState = GameSession.state
			if st.phase == Phase.Type.PRE_GAME:
				game._start_match(1)
			elif st.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(st.phase):
				game._continue_after_reveal()
			elif Phase.is_define(st.phase) and st.cards_defined[1].size() == 0:
				for c in hand.get_card_views():
					c.data.hp = 2
					c.data.stamina = 4
					c.data.attack = 1
					c._refresh()
				hand._on_confirm_pressed()
			elif Phase.is_linking(st.phase) and st.current_player == 1:
				for i in st.cards_revealed[1].size():
					if not st.cards_revealed[1][i].is_linked():
						game._on_link_card_picked(i)
						break
				for pawn in st.pawns.values():
					if pawn.owner_id == 1 and not pawn.is_eliminated and pawn.linked_card_id == -1 and game._pawn_has_room(pawn):
						game._on_link_pawn_clicked(pawn.id)
						break
			await get_tree().create_timer(0.02).timeout
		GameSession.state.current_player = 1
		for pawn in GameSession.state.pawns.values():
			if pawn.owner_id == 1 and pawn.is_active and not pawn.is_eliminated \
					and Rules.can_pawn_act(GameSession.state, pawn.id) and pawn.remaining_stamina >= 3:
				game._select_pawn(pawn.id)
				break
		await get_tree().create_timer(0.3).timeout
		out = "res://_shot_movehl.png"
	elif "reselect" in args:
		var hand: CardHand = game.get_node("UI/CardHand")
		var steps := 0
		while GameSession.state.phase != Phase.Type.ACTION and steps < 300:
			steps += 1
			var st: GameState = GameSession.state
			if st.phase == Phase.Type.PRE_GAME:
				game._start_match(1)
			elif st.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(st.phase):
				game._continue_after_reveal()
			elif Phase.is_define(st.phase) and st.cards_defined[1].size() == 0:
				for c in hand.get_card_views():
					c.data.hp = 3
					c.data.stamina = 2
					c.data.attack = 2
					c._refresh()
				hand._on_confirm_pressed()
			elif Phase.is_linking(st.phase) and st.current_player == 1:
				for i in st.cards_revealed[1].size():
					if not st.cards_revealed[1][i].is_linked():
						game._on_link_card_picked(i)
						break
				for pawn in st.pawns.values():
					if pawn.owner_id == 1 and not pawn.is_eliminated and pawn.linked_card_id == -1 and game._pawn_has_room(pawn):
						game._on_link_pawn_clicked(pawn.id)
						break
			await get_tree().create_timer(0.02).timeout
		GameSession.state.current_player = 1
		var target = null
		for pawn in GameSession.state.pawns.values():
			if pawn.owner_id == 1 and pawn.is_active and not pawn.is_eliminated \
					and Rules.can_pawn_act(GameSession.state, pawn.id) and pawn.remaining_stamina >= 2:
				target = pawn
				break
		if target == null:
			print("[RESELECT] geen geschikte pion gevonden")
		else:
			game._select_pawn(target.id)
			var one_step = null
			for m in game._valid_moves:
				if abs(m.x - target.position.x) + abs(m.y - target.position.y) == 1:
					one_step = m
					break
			var before_stam: int = target.remaining_stamina
			if one_step != null:
				game._on_tile_clicked(one_step)
			var after_stam: int = target.remaining_stamina
			GameSession.state.current_player = 1
			# Vul de voorraad bij zodat herselectie (picking-test) altijd kan.
			target.remaining_stamina = target.max_stamina
			game._select_pawn(target.id)
			print("[RESELECT] stamina %d->%d, herselecteerd=%s, geldige_zetten=%d" % [
				before_stam, after_stam,
				str(game._selected_pawn_id == target.id), game._valid_moves.size()])
		get_tree().quit()
		return
	elif "tegenstander" in args:
		game._human_doctrine = Constants.Doctrine.MUIS
		game._show_opponent_menu()
		await get_tree().create_timer(0.4).timeout
		out = "res://_shot_tegenstander.png"
	elif "uitleg" in args:
		game._show_doctrine_menu()
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("res://_shot_doctrines.png")
		game._show_rules_overlay(func() -> void: pass)
		await get_tree().create_timer(0.4).timeout
		out = "res://_shot_uitleg.png"
	elif "zweefcheck" in args:
		# Diagnose (3 september): welke mesh-nodes liggen BUITEN het bord na de
		# opstelling (zwevende wapens/props)? Print naam, ouderketen en positie.
		# Gebruik: -- zweefcheck [factie] [cyclus] (beide kanten dezelfde factie).
		# 8 september (Max: "zwevende wapens bij blauw na ontkoppeling"): met een
		# cyclus-getal >= 2 speelt de check door tot die cyclus (mens via het
		# timeout-pad, bot zoals altijd), dus VOORBIJ de cyclus-reset waarin elke
		# pion ontkoppelt en van vecht-model terug naar basismodel wisselt, en
		# meet dan pas. Per pion ook team en koppeling, plus meshes die aan geen
		# pion hangen en toch in de lucht staan (geen debris).
		var zf := {"varken": Constants.Doctrine.MENS, "muis": Constants.Doctrine.MUIS, "leeuw": Constants.Doctrine.LEEUW,
			"beer": Constants.Doctrine.BEER, "wolf": Constants.Doctrine.WOLF, "krokodil": Constants.Doctrine.VOS}
		var zn_cyclus: int = 1
		for zn in zf:
			if zn in args:
				game._human_doctrine = zf[zn]
				game._ai_doctrine = zf[zn]
		for za in args:
			if String(za).is_valid_int() and int(za) >= 2:
				zn_cyclus = int(za)
		game._start_match(1)
		await get_tree().create_timer(0.3).timeout
		game._confirm_placement()
		await get_tree().create_timer(1.5).timeout
		if zn_cyclus >= 2:
			var z_t0 := Time.get_ticks_msec()
			var z_stil := Time.get_ticks_msec()
			while GameSession.state.cycle < zn_cyclus and GameSession.state.phase != Phase.Type.GAME_OVER \
					and Time.get_ticks_msec() - z_t0 < 10 * 60 * 1000:
				var zst: GameState = GameSession.state
				if Phase.is_reveal(zst.phase) and not zst.reveal_acks.get(1, false):
					game._continue_after_reveal()
					z_stil = Time.get_ticks_msec()
				elif game._timer_active:
					game._timer_left = 0.0
					z_stil = Time.get_ticks_msec()
				elif Time.get_ticks_msec() - z_stil > 3000 and zst.current_player == 1:
					if zst.phase == Phase.Type.ACTION or Phase.is_linking(zst.phase):
						game._on_phase_timeout()
						z_stil = Time.get_ticks_msec()
				await get_tree().create_timer(0.05).timeout
			var zw := 0
			while not game.is_rustig() and zw < 600:
				zw += 1
				await get_tree().create_timer(0.05).timeout
			await get_tree().create_timer(1.0).timeout
			print("[ZWEEF] gemeten in cyclus %d, fase %s" % [GameSession.state.cycle, Phase.to_string_phase(GameSession.state.phase)])
		var buiten := 0
		var totaal := 0
		var los_in_de_lucht := 0
		var view_van: Dictionary = {}
		for vpid in game._pawn_views:
			view_van[game._pawn_views[vpid]] = int(vpid)
		for mi in game._world.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if not m.is_visible_in_tree():
				continue
			totaal += 1
			var gp: Vector3 = m.global_position
			# Afstand tot de eigen pion (het kind van Pawns): een wapen hoort binnen
			# ~2 eenheden van zijn pion te blijven (een vaandel steekt 1,3 omhoog);
			# de bordgrenzen zijn lokaal en misleiden hier.
			var pion: Node3D = m
			while pion != null and pion.get_parent() != game._pawns_root:
				pion = pion.get_parent() as Node3D
			var centrum: Vector3 = m.global_transform * m.get_aabb().get_center()
			if pion == null:
				# Bordrand-decor (Board/Omgeving/Props: hekjes, boompjes) telt niet mee.
				var decor: bool = false
				var dn: Node = m
				while dn != null and dn != game._world:
					if dn.name == "Omgeving" or dn.name == "Board":
						decor = true
					dn = dn.get_parent()
				if centrum.y > 0.5 and not decor and not m.is_in_group("battlefield_debris"):
					los_in_de_lucht += 1
					print("[ZWEEF] LOS (geen pion): %s midden=(%.2f, %.2f, %.2f) keten=%s" % [
						m.name, centrum.x, centrum.y, centrum.z, _zweef_keten(m, game._world)])
				continue
			# Gibs en ander strooisel hangen als eigen container onder Pawns (bv
			# infantry_mix_gibs): geen pion, dus geen wapen dat zweeft. Sinds de
			# check voorbij cyclus 1 meet (er vallen doden) telt alleen een echte
			# PawnView mee.
			if not (pion is PawnView):
				continue
			var ver: bool = centrum.distance_to(pion.global_position) > 2.0
			if ver:
				buiten += 1
				var zpid: int = int(view_van.get(pion, -1))
				var zp: Pawn = GameSession.state.pawns.get(zpid, null)
				var team: String = "?"
				if pion is PawnView:
					team = "rood" if (pion as PawnView).team == Constants.Team.RED else "blauw"
				var koppeling: String = "?"
				if zp != null:
					koppeling = "gekoppeld" if zp.linked_card_id != -1 else "ontkoppeld"
					if zp.is_eliminated:
						koppeling = "dood"
				print("[ZWEEF] %s team=%s pion=%d (%s) node=(%.2f, %.2f, %.2f) meshmidden=(%.2f, %.2f, %.2f) keten=%s" % [
					m.name, team, zpid, koppeling, gp.x, gp.y, gp.z, centrum.x, centrum.y, centrum.z,
					_zweef_keten(m, game._world)])
		# Fijnmeting (8 september, Max: "zwevende wapens bij het blauwe basismodel"):
		# per pion de VERSTE mesh, zodat een wapen dat een halve tegel naast de
		# hand hangt ook opvalt; de acht verste pionnen met team, model en koppeling.
		var verste: Array = []
		for vpv in game._pawn_views.values():
			if not (vpv as Node3D).visible:
				continue
			var maxd: float = 0.0
			var maxnaam: String = ""
			for mi2 in (vpv as Node).find_children("*", "MeshInstance3D", true, false):
				var m2 := mi2 as MeshInstance3D
				if not m2.is_visible_in_tree():
					continue
				var c2: Vector3 = m2.global_transform * m2.get_aabb().get_center()
				var d2: float = c2.distance_to((vpv as Node3D).global_position)
				if d2 > maxd:
					maxd = d2
					maxnaam = m2.name
			var vpid: int = int(view_van.get(vpv, -1))
			var vp: Pawn = GameSession.state.pawns.get(vpid, null)
			var vteam: String = "rood" if (vpv as PawnView).team == Constants.Team.RED else "blauw"
			var vkop: String = "?" if vp == null else ("dood" if vp.is_eliminated else ("gekoppeld" if vp.linked_card_id != -1 else "ontkoppeld"))
			var wh: Dictionary = (vpv as PawnView).wapen_hand_afstand()
			verste.append({"d": maxd, "naam": maxnaam, "pid": vpid, "team": vteam, "kop": vkop,
				"model": String((vpv as PawnView)._model_path).get_file(), "rol": String((vpv as PawnView)._rol),
				"swaps": (vpv as PawnView).swaps, "hand": float(wh.afstand), "bron": String(wh.bron), "wapen": String(wh.wapen)})
		verste.sort_custom(func(a, b): return float(a.hand) > float(b.hand))
		var los_van_hand := 0
		for v in verste:
			if float(v.hand) > 0.25:
				los_van_hand += 1
		for i in verste.size():
			var v: Dictionary = verste[i]
			if i >= 12 and String(v.rol) == "" and float(v.hand) <= 0.25:
				continue
			print("[ZWEEF] wapen-hand %.2f (%s %s) swaps=%d pion=%d team=%s %s model=%s rol=%s" % [
				float(v.hand), String(v.bron), String(v.wapen), int(v.swaps), int(v.pid), String(v.team), String(v.kop), String(v.model), String(v.rol)])
		print("[ZWEEF] wapens verder dan 0.25 van de hand: %d" % los_van_hand)
		# Headless geeft soms wel een texture maar geen image: save_png op null
		# brak de run af VOOR quit() en liet het proces hangen (8 september).
		var z_tex := get_viewport().get_texture()
		if z_tex != null and z_tex.get_image() != null:
			game._overlay.hide()
			game._card_hand.visible = false
			await get_tree().create_timer(0.3).timeout
			var z_img: Image = z_tex.get_image()
			if z_img != null:
				z_img.save_png("res://_shot_zweefcheck.png")
				print("[ZWEEF] screenshot -> _shot_zweefcheck.png")
		var z_ok: bool = buiten == 0 and los_in_de_lucht == 0
		print("[ZWEEF] meshes zichtbaar=%d, meer dan 2 van hun pion: %d, los in de lucht: %d (%s)" % [
			totaal, buiten, los_in_de_lucht, "PASS" if z_ok else "FAIL"])
		get_tree().quit(0 if z_ok else 1)
		return
	elif "windcheck" in args:
		# Wind (8 september): een richting per potje, alle vlaggen wapperen die
		# kant op, ook die van de vijand. Controle: na de opstelling de wind op
		# een vaste richting zetten en per vlagdoek meten of zijn vrije zijde
		# (lokale +X van het doek, in wereldruimte) met de wind mee wijst; daarna
		# de wind een kwartslag draaien en opnieuw meten. Beide teams moeten een
		# vlag hebben (rood en blauw kijken tegengesteld, dus dit vangt precies de
		# fout dat het doek in pion-ruimte staat). Gebruik: -- windcheck [factie]
		var wf := {"varken": Constants.Doctrine.MENS, "muis": Constants.Doctrine.MUIS, "leeuw": Constants.Doctrine.LEEUW,
			"beer": Constants.Doctrine.BEER, "wolf": Constants.Doctrine.WOLF, "krokodil": Constants.Doctrine.VOS}
		game._human_doctrine = Constants.Doctrine.MUIS
		game._ai_doctrine = Constants.Doctrine.MUIS
		for wn in wf:
			if wn in args:
				game._human_doctrine = wf[wn]
				game._ai_doctrine = wf[wn]
		game._start_match(1)
		await get_tree().create_timer(0.3).timeout
		game._confirm_placement()
		await get_tree().create_timer(1.5).timeout
		var fouten := 0
		for hoek in [0.0, PI * 0.5, PI * 1.25]:
			var wind := Vector3(cos(hoek), 0.0, sin(hoek))
			PawnView.wind_richting = wind
			await get_tree().process_frame
			await get_tree().process_frame
			var per_team := {Constants.Team.RED: 0, Constants.Team.BLUE: 0}
			for pid in game._pawn_views:
				var pv: PawnView = game._pawn_views[pid]
				if not pv.visible or pv._vlagdoek == null or not is_instance_valid(pv._vlagdoek):
					continue
				var vrij: Vector3 = pv._vlagdoek.global_transform.basis.x
				vrij.y = 0.0
				var d: float = vrij.normalized().dot(wind) if vrij.length() > 0.001 else -1.0
				per_team[pv.team] = int(per_team[pv.team]) + 1
				var ok: bool = d > 0.95
				if not ok:
					fouten += 1
				print("[WIND] hoek=%3.0f team=%s pion=%d vrij=(%.2f, %.2f) dot=%.3f %s" % [
					rad_to_deg(hoek), "rood" if pv.team == Constants.Team.RED else "blauw", pid,
					vrij.normalized().x, vrij.normalized().z, d, "OK" if ok else "FOUT"])
			if int(per_team[Constants.Team.RED]) == 0 or int(per_team[Constants.Team.BLUE]) == 0:
				fouten += 1
				print("[WIND] hoek=%3.0f: geen vlag gevonden bij rood=%d blauw=%d (heeft deze factie een model met vlag-prop?)" % [
					rad_to_deg(hoek), int(per_team[Constants.Team.RED]), int(per_team[Constants.Team.BLUE])])
		print("[WIND] %s: %d fout(en) over drie windrichtingen" % ["PASS" if fouten == 0 else "FAIL", fouten])
		# Met venster: een plaatje van de laatste stand (225 graden) als bijvangst.
		var wind_tex := get_viewport().get_texture()
		if wind_tex != null and wind_tex.get_image() != null:
			game._overlay.hide()
			game._card_hand.visible = false
			await get_tree().create_timer(0.3).timeout
			var wind_img: Image = wind_tex.get_image()
			if wind_img != null:
				wind_img.save_png("res://_shot_windcheck.png")
				print("[WIND] screenshot -> _shot_windcheck.png")
		get_tree().quit(0 if fouten == 0 else 1)
		return
	elif "audiopaneel" in args:
		# Geluidsinstellingen (8 september): het paneel opbouwen, elke schuif
		# aanraken en bewijzen dat Audio.zet_volume meteen op de muzieklaag
		# landt. Schrijft naar een eigen cfg (settings_check.cfg), niet naar
		# die van de speler. Met venster ook _shot_audiopaneel.png.
		var ap_fouten := 0
		var ap_pad_oud: String = Audio.instellingen_pad
		var ap_oud: Dictionary = {}
		for s in Audio.VOLUME_SOORTEN:
			ap_oud[s] = Audio.volume(String(s))
		Audio.instellingen_pad = "user://settings_check.cfg"
		game._show_audio_panel()
		await get_tree().process_frame
		var sliders: Array = game._audio_panel.find_children("*", "HSlider", true, false)
		if sliders.size() != 4:
			ap_fouten += 1
			print("[AUDIO] FOUT: verwacht 4 schuiven, gevonden %d" % sliders.size())
		Audio.play_music("music_battle")
		for i in sliders.size():
			(sliders[i] as HSlider).value = 25.0 + 10.0 * i
		await get_tree().process_frame
		for i in mini(4, sliders.size()):
			var soort: String = String(Audio.VOLUME_SOORTEN[i])
			var gezet: float = Audio.volume(soort)
			var bedoeld: float = (25.0 + 10.0 * i) / 100.0
			if absf(gezet - bedoeld) > 0.001:
				ap_fouten += 1
			print("[AUDIO] %-9s schuif %.0f%% -> Audio.volume %.2f %s" % [soort, 25.0 + 10.0 * i, gezet, "OK" if absf(gezet - bedoeld) <= 0.001 else "FOUT"])
		var verwacht_db: float = Audio.master_db + float(Audio.MUSIC_DB.get(Audio._music_cat, -16.0)) \
			+ Audio.volume_naar_db(Audio.vol_alles * Audio.vol_muziek)
		var ok_laag: bool = absf(Audio._music_player.volume_db - verwacht_db) < 0.01
		if not ok_laag:
			ap_fouten += 1
		print("[AUDIO] muzieklaag %.2f dB, verwacht %.2f %s" % [Audio._music_player.volume_db, verwacht_db, "OK" if ok_laag else "FOUT"])
		var ap_cfg := ConfigFile.new()
		var ok_cfg: bool = ap_cfg.load("user://settings_check.cfg") == OK \
			and absf(float(ap_cfg.get_value("audio", "muziek", -1.0)) - 0.35) < 0.001
		if not ok_cfg:
			ap_fouten += 1
		print("[AUDIO] bewaard in settings_check.cfg: %s" % ("OK" if ok_cfg else "FOUT"))
		var ap_tex := get_viewport().get_texture()
		if ap_tex != null and ap_tex.get_image() != null:
			await get_tree().create_timer(0.3).timeout
			var ap_img: Image = ap_tex.get_image()
			if ap_img != null:
				ap_img.save_png("res://_shot_audiopaneel.png")
				print("[AUDIO] screenshot -> _shot_audiopaneel.png")
		Audio.stop_music()
		for s in ap_oud:
			Audio.zet_volume(String(s), float(ap_oud[s]), false)
		Audio.instellingen_pad = ap_pad_oud
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings_check.cfg"))
		print("[AUDIO] %s: %d fout(en)" % ["PASS" if ap_fouten == 0 else "FAIL", ap_fouten])
		get_tree().quit(0 if ap_fouten == 0 else 1)
		return
	elif "chargemeet" in args:
		# 16 september: hoe ver loopt het model bij de sprong-clip van de charge
		# visueel WEG van zijn node (root motion in de hips)? Muis-cavalerie,
		# play_charge, per 0,1 s de heup-positie relatief aan de PawnView.
		var cm_scene: PackedScene = load("res://scenes/game/pawn_view.tscn")
		var cm_pv: PawnView = cm_scene.instantiate()
		cm_pv.team = Constants.Team.RED
		cm_pv.pawn_id = 800
		add_child(cm_pv)
		cm_pv.set_unit_type(Constants.UnitType.CAVALRY)
		cm_pv.set_character(Constants.Doctrine.MUIS, Constants.UnitType.CAVALRY, null)
		cm_pv.face_dir(Vector2i(0, -1))
		await get_tree().process_frame
		await get_tree().process_frame
		var cm_skels: Array = cm_pv.find_children("*", "Skeleton3D", true, false)
		if cm_skels.is_empty():
			print("[CHARGEMEET] geen skelet (model %s)" % String(cm_pv._model_path))
			get_tree().quit(1)
			return
		var cm_skel: Skeleton3D = cm_skels[0]
		var cm_hips := cm_skel.find_bone("mixamorig_Hips")
		if cm_hips < 0:
			cm_hips = cm_skel.find_bone("mixamorig:Hips")
		var cm_rust: Vector3 = cm_pv.to_local(cm_skel.global_transform * cm_skel.get_bone_global_pose(cm_hips).origin)
		print("[CHARGEMEET] model %s, schaal %.3f, sprong_duur %.2f s, heup in rust %s" % [String(cm_pv._model_path).get_file(), cm_pv.scale.x, cm_pv.charge_duur(), str(cm_rust)])
		cm_pv.play_charge()
		var cm_t := 0.0
		var cm_lijn: Array = []
		var cm_max := 0.0
		while cm_t < cm_pv.charge_duur() + 0.2:
			await get_tree().process_frame
			cm_t += get_process_delta_time()
			var q: Vector3 = cm_pv.to_local(cm_skel.global_transform * cm_skel.get_bone_global_pose(cm_hips).origin) - cm_rust
			cm_max = maxf(cm_max, -q.z)
			if cm_lijn.size() < 60 and fmod(cm_t, 0.1) < get_process_delta_time():
				cm_lijn.append("%.1f:%.2f/%.2f" % [cm_t, -q.z, q.y])
		print("[CHARGEMEET] vooruit(-z)/omhoog per 0,1 s: " + " ".join(cm_lijn))
		print("[CHARGEMEET] max vooruit %.2f wereld-eenheden (vakken) MET compensatie (moet onder 0,2 blijven)" % cm_max)
		var cm_prof: Dictionary = cm_pv.charge_profiel()
		var cm_tl: Dictionary = cm_pv.charge_tijdlijn(4)
		print("[CHARGEMEET] profiel: %s; tijdlijn over 4 vakken: %s" % [str(cm_prof), str(cm_tl)])
		var cm_fouten := 0
		if cm_max > 0.2:
			print("[CHARGEMEET] FOUT: het model loopt tijdens de sprong %.2f vak van zijn node weg" % cm_max)
			cm_fouten += 1
		if cm_prof.is_empty() or float(cm_prof.get("vooruit", 0.0)) < 0.5:
			print("[CHARGEMEET] FOUT: geen bruikbaar root-motion-profiel")
			cm_fouten += 1
		if float(cm_tl.sprong_start) + 0.05 > float(cm_tl.rij_dur):
			print("[CHARGEMEET] FOUT: de sprong begint niet voor de aankomst")
			cm_fouten += 1
		print("[CHARGEMEET] %s: %d fout(en)" % ["PASS" if cm_fouten == 0 else "FAIL", cm_fouten])
		get_tree().quit(0 if cm_fouten == 0 else 1)
		return
	elif "idlecheck" in args:
		# 16 september (Max: "alle idles de standaard meest stilstaande idle en
		# maximaal af en toe doen 1 a 3 poppetjes een andere idle"). Twaalf
		# muizen; twintig seconden lang elk frame tellen hoeveel er NIET in de
		# stilste idle-variant staan: nooit meer dan de knop idle_afwijkers, en
		# minstens een keer wel iemand (anders doet niemand ooit iets).
		var ic_scene: PackedScene = load("res://scenes/game/pawn_view.tscn")
		var ic_pvs: Array = []
		for ic_i in 12:
			var ic_pv: PawnView = ic_scene.instantiate()
			ic_pv.team = Constants.Team.RED if ic_i % 2 == 0 else Constants.Team.BLUE
			ic_pv.pawn_id = 700 + ic_i
			ic_pv.position = Vector3(float(ic_i % 4) * 1.2, 0.0, float(ic_i / 4) * 1.2)
			add_child(ic_pv)
			ic_pv.set_unit_type(0)
			ic_pv.set_character(Constants.Doctrine.MUIS, 0, null)
			ic_pvs.append(ic_pv)
		await get_tree().process_frame
		await get_tree().process_frame
		var ic_idles: Array = (ic_pvs[0] as PawnView)._variants_of("idle")
		if ic_idles.size() < 2:
			print("[IDLE] model heeft maar %d idle-variant(en); check overgeslagen" % ic_idles.size())
			get_tree().quit(0)
			return
		var ic_stil: String = (ic_pvs[0] as PawnView)._stilste_idle_variant(ic_idles)
		var ic_max: int = int(PawnView.fx("idle_afwijkers", 2.0))
		var ic_piek := 0
		var ic_ooit := 0
		var ic_t := 0.0
		var ic_fouten := 0
		while ic_t < 20.0:
			await get_tree().process_frame
			ic_t += get_process_delta_time()
			var n := 0
			for pv in ic_pvs:
				var clip := String((pv as PawnView)._anim.current_animation) if (pv as PawnView)._anim != null else ""
				if ic_idles.has(clip) and clip != ic_stil:
					n += 1
			ic_piek = maxi(ic_piek, n)
			if n > 0:
				ic_ooit += 1
		print("[IDLE] stilste variant: %s van %d; piek tegelijk afwijkend %d (knop %d), frames met een afwijker %d" % [ic_stil.get_file(), ic_idles.size(), ic_piek, ic_max, ic_ooit])
		if ic_piek > ic_max:
			print("[IDLE] FOUT: %d pionnen tegelijk in een andere idle, knop staat op %d" % [ic_piek, ic_max])
			ic_fouten += 1
		if ic_ooit == 0:
			print("[IDLE] FOUT: in twintig seconden deed niemand ooit een andere idle")
			ic_fouten += 1
		print("[IDLE] %s: %d fout(en)" % ["PASS" if ic_fouten == 0 else "FAIL", ic_fouten])
		get_tree().quit(0 if ic_fouten == 0 else 1)
		return
	elif "richtingcheck" in args:
		# 18 september (Max: "voor infantry attack pig klopt de orientatie niet").
		# Per type en archetype een PawnView zoals de Model-tuner, en in de pose
		# die de speler ziet meten waar de VOETEN heen wijzen (voet -> teen, in
		# wereldruimte, na de auto-fit van 180 graden). De voorkant van een pion
		# is -Z: een model dat 90 of 180 graden anders staat valt hier meteen op.
		# Gebruik: -- richtingcheck [factie] (default varken).
		var rc_fac: int = Constants.Doctrine.MENS
		var rc_namen := {"varken": Constants.Doctrine.MENS, "muis": Constants.Doctrine.MUIS,
			"leeuw": Constants.Doctrine.LEEUW, "beer": Constants.Doctrine.BEER,
			"wolf": Constants.Doctrine.WOLF, "krokodil": Constants.Doctrine.VOS}
		for rc_n in rc_namen:
			if rc_n in args:
				rc_fac = rc_namen[rc_n]
		var rc_kaarten := {"base": null, "spd": [1, 3, 1], "hp": [3, 1, 1],
			"atk": [1, 1, 3], "mix": [2, 2, 1]}
		var rc_scene: PackedScene = load("res://scenes/game/pawn_view.tscn")
		var rc_fouten := 0
		var rc_totaal := 0
		for rc_tp in [0, 1]:
			for rc_arch in ["base", "spd", "hp", "atk", "mix"]:
				var rc_pv: PawnView = rc_scene.instantiate()
				rc_pv.team = Constants.Team.RED
				add_child(rc_pv)
				rc_pv.set_unit_type(rc_tp)
				var rc_st = rc_kaarten[rc_arch]
				var rc_card = null
				if rc_st != null:
					rc_card = Card.new(0, 0, 0, int(rc_st[0]), int(rc_st[1]), int(rc_st[2]))
				rc_pv.set_character(rc_fac, rc_tp, rc_card)
				await get_tree().process_frame
				await get_tree().process_frame
				if String(rc_pv._model_path) == "":
					rc_pv.queue_free()
					continue
				rc_totaal += 1
				if "rust" in args and rc_pv._anim != null:
					# Diagnose: dezelfde meting in de RUSTPOSE (animatie uit, botten terug).
					rc_pv._anim.stop()
					for rsk in rc_pv._piece.find_children("*", "Skeleton3D", true, false):
						(rsk as Skeleton3D).reset_bone_poses()
					await get_tree().process_frame
				if "boom" in args:
					# Diagnose: de node-boom van het stuk met transforms.
					for rn in rc_pv._piece.find_children("*", "", true, false):
						if rn is Node3D:
							var rt: Transform3D = (rn as Node3D).transform
							var re: Vector3 = rt.basis.get_euler()
							print("[RICHTING]    node %-40s (%s) pos=(%.2f, %.2f, %.2f) rot=(%.0f, %.0f, %.0f) schaal=%.2f" % [
								rn.name, rn.get_class(), rt.origin.x, rt.origin.y, rt.origin.z, rad_to_deg(re.x), rad_to_deg(re.y), rad_to_deg(re.z), rt.basis.get_scale().x])
				var rc_m: Dictionary = _rc_meet(rc_pv)
				var rc_soort: String = "infantry" if rc_tp == 0 else "cavalry"
				if rc_m.is_empty():
					print("[RICHTING] %s %-4s %s: geen voet/teen-botten gevonden" % [rc_soort, rc_arch, String(rc_pv._model_path).get_file()])
					rc_pv.queue_free()
					continue
				# Hoek van de voetrichting t.o.v. de voorkant (-Z), in graden: 0 = goed.
				var rc_hoek: float = rad_to_deg(Vector2(-rc_m.voet.z, rc_m.voet.x).angle_to(Vector2(1.0, 0.0)))
				var rc_ok: bool = absf(rc_hoek) <= 25.0
				if not rc_ok:
					rc_fouten += 1
				print("[RICHTING] %s %-4s %-22s voeten (%.2f, %.2f) = %+.0f graden van de voorkant; romp (%.2f, %.2f); op %.2f omhoog; rot.y stuk %.0f (%s)" % [
					rc_soort, rc_arch, String(rc_pv._model_path).get_file(), rc_m.voet.x, rc_m.voet.z, rc_hoek,
					rc_m.romp.x, rc_m.romp.z, rc_m.omhoog, rad_to_deg(rc_pv._piece.rotation.y) if rc_pv._piece != null else 0.0,
					"PASS" if rc_ok else "FAIL"])
				rc_pv.queue_free()
		print("[RICHTING] %s: %d modellen, %d met een verkeerde richting" % ["PASS" if rc_fouten == 0 else "FAIL", rc_totaal, rc_fouten])
		# Met venster: de vijf infanterie-archetypen op een rij op het bord, van
		# voren gezien zoals de speler ze ziet (_shot_richting.png).
		var rc_tex := get_viewport().get_texture()
		if rc_tex != null and rc_tex.get_image() != null:
			game._overlay.hide()
			var rc_rij: Array = []
			var rc_i := 0
			for rc_arch2 in ["base", "spd", "hp", "atk", "mix"]:
				var pv2: PawnView = rc_scene.instantiate()
				pv2.team = Constants.Team.RED
				game._board.add_child(pv2)
				pv2.set_unit_type(0)
				var st2 = rc_kaarten[rc_arch2]
				pv2.set_character(rc_fac, 0, null if st2 == null else Card.new(0, 0, 0, int(st2[0]), int(st2[1]), int(st2[2])))
				pv2.position = game.tile_position(3 + rc_i, 7) + Vector3(0.0, 0.05, 0.0)
				pv2.face_dir(Vector2i(0, -1))
				rc_rij.append(pv2)
				rc_i += 1
			await get_tree().create_timer(1.0).timeout
			var rc_img: Image = rc_tex.get_image()
			if rc_img != null:
				rc_img.save_png("res://_shot_richting.png")
				print("[RICHTING] screenshot -> _shot_richting.png (base, spd, hp, atk, mix op rij 7)")
		get_tree().quit(0 if rc_fouten == 0 else 1)
		return
	elif "wapenroute" in args:
		# Diagnose (7 september): welke wapen-route neemt het spel per model?
		#   INGEBAKKEN = het geskinde wapen uit de .blend blijft staan en beweegt
		#                met elke animatie mee. Geen afstelling, geen prop.
		#   PROP       = het ingebakken wapen wordt VERBORGEN en er hangt een
		#                statische glb in de hand, met model_tuning.json erop.
		# De prop-route is de terugval voor modellen zonder meebewegend wapen.
		# Belandt een model daar per ongeluk, dan krijgt het de pos/rot/scale uit
		# de tuning-sleutel, en een afstelling die bij een OUDER model hoorde zet
		# het wapen zichtbaar scheef. Gebruik: -- wapenroute [factie]
		#
		# Opgebouwd zoals de Model-tuner (set_unit_type + set_character), NIET via
		# een partij: in een partij verschijnen alleen archetypen waarvoor een
		# model bestaat, dus op een halfgevulde assets-map zie je niets.
		var wr_fac: int = Constants.Doctrine.MUIS
		var wr_namen := {"varken": Constants.Doctrine.MENS, "muis": Constants.Doctrine.MUIS,
			"leeuw": Constants.Doctrine.LEEUW, "beer": Constants.Doctrine.BEER,
			"wolf": Constants.Doctrine.WOLF, "krokodil": Constants.Doctrine.VOS}
		for wr_n in wr_namen:
			if wr_n in args:
				wr_fac = wr_namen[wr_n]
		var wr_kaarten := {"base": null, "spd": [1, 3, 1], "hp": [3, 1, 1],
			"atk": [1, 1, 3], "mix": [2, 2, 1]}
		var wr_scene: PackedScene = load("res://scenes/game/pawn_view.tscn")
		if wr_scene == null:
			print("[WAPEN] PawnView.tscn niet gevonden")
			get_tree().quit(1)
			return
		var wr_prop := 0
		var wr_totaal := 0
		for wr_tp in [0, 1]:  # 0 = infanterie, 1 = cavalerie
			for wr_arch in ["base", "spd", "hp", "atk", "mix"]:
				var wr_pv: PawnView = wr_scene.instantiate()
				wr_pv.team = Constants.Team.RED
				add_child(wr_pv)
				wr_pv.set_unit_type(wr_tp)
				var wr_st = wr_kaarten[wr_arch]
				var wr_card = null
				if wr_st != null:
					wr_card = Card.new(0, 0, 0, int(wr_st[0]), int(wr_st[1]), int(wr_st[2]))
				wr_pv.set_character(wr_fac, wr_tp, wr_card)
				await get_tree().process_frame
				await get_tree().process_frame
				var wr_soort: String = "infantry" if wr_tp == 0 else "cavalry"
				if String(wr_pv._model_path) == "":
					wr_pv.queue_free()
					continue
				wr_totaal += 1
				var wr_baked: Array = wr_pv._baked_wapens
				var wr_route: String = "INGEBAKKEN" if not wr_baked.is_empty() else "PROP"
				if wr_baked.is_empty():
					wr_prop += 1
				var wr_sleutel: String = String(wr_pv._weapon_tune_key)
				var wr_tune: Dictionary = PawnView.model_tuning().get(wr_sleutel, {})
				var wr_tekst: String = "geen afstelling"
				if not wr_tune.is_empty():
					wr_tekst = "pos=%s rot=%s scale=%s %s" % [str(wr_tune.get("pos", [])),
						str(wr_tune.get("rot", [])), str(wr_tune.get("scale", 1.0)),
						"(NIET gebruikt op deze route)" if not wr_baked.is_empty() else "(WORDT TOEGEPAST)"]
				# Draagt het wapen een eigen teamjas, en staat die er ook echt op?
				var wr_jas: String = "wapenjas: geen (houdt zijn glb-atlas)"
				var wr_pad: String = String(wr_pv._baked_prop_pad)
				var wr_tex: Texture2D = PawnView.weapon_team_texture(wr_pad, Constants.Team.RED)
				if wr_tex != null:
					var wr_op := 0
					var wr_tot := 0
					for wr_mi in wr_pv._baked_wapens:
						wr_tot += 1
						var wr_mat: Material = (wr_mi as MeshInstance3D).material_override
						if wr_mat is BaseMaterial3D and (wr_mat as BaseMaterial3D).albedo_texture == wr_tex:
							wr_op += 1
					wr_jas = "wapenjas: %s, staat op %d/%d wapen-mesh(es)" % [
						wr_pad.get_file().get_basename() + "_red.png", wr_op, wr_tot]
					if wr_op < wr_tot:
						wr_jas += " !! NIET TOEGEPAST"
				print("[WAPEN] %-9s %-5s %-11s sleutel=%-26s %s" % [wr_soort, wr_arch,
					wr_route, wr_sleutel, wr_tekst])
				print("[WAPEN]                            %s" % wr_jas)
				wr_pv.queue_free()
		print("[WAPEN] %d model(len) bekeken, %d op de prop-route" % [wr_totaal, wr_prop])
		get_tree().quit(0)
		return
	elif "debrischeck" in args:
		# Worden lijken en gibs na een tijdje donker (Max, 7 september)? En blijft
		# een LEVENDE pion met hetzelfde model onaangetast -- oftewel: is het
		# materiaal per instantie gedupliceerd en niet het gedeelde glb-materiaal?
		var db_scene: PackedScene = load("res://scenes/game/pawn_view.tscn")
		var db_fac: int = Constants.Doctrine.MUIS
		var db_namen := {"varken": Constants.Doctrine.MENS, "muis": Constants.Doctrine.MUIS,
			"leeuw": Constants.Doctrine.LEEUW, "beer": Constants.Doctrine.BEER,
			"wolf": Constants.Doctrine.WOLF, "krokodil": Constants.Doctrine.VOS}
		for db_n in db_namen:
			if db_n in args:
				db_fac = db_namen[db_n]
		var db_dood: PawnView = db_scene.instantiate()
		var db_levend: PawnView = db_scene.instantiate()
		for db_pv in [db_dood, db_levend]:
			add_child(db_pv)
			db_pv.set_unit_type(0)
			db_pv.set_character(db_fac, 0, null)
		await get_tree().process_frame
		await get_tree().process_frame
		if String(db_dood._model_path) == "":
			print("[DEBRIS] geen model geleverd voor deze factie; niets te meten")
			get_tree().quit(0)
			return
		var db_meet := func(pv: PawnView) -> Color:
			for mi in pv.find_children("*", "MeshInstance3D", true, false):
				var m: Material = (mi as MeshInstance3D).material_override
				if m == null:
					m = (mi as MeshInstance3D).get_active_material(0)
				if m is BaseMaterial3D:
					return (m as BaseMaterial3D).albedo_color
			return Color.WHITE
		# Sinds 16 september ook: wordt het lijk doorzichtig (albedo-alpha met
		# depth-prepass) en zakt het stuk een stukje in het bord, terwijl de
		# levende pion dicht blijft en op zijn plek staat?
		var db_transp := func(pv: PawnView) -> int:
			for mi in pv.find_children("*", "MeshInstance3D", true, false):
				var m: Material = (mi as MeshInstance3D).material_override
				if m == null:
					m = (mi as MeshInstance3D).get_active_material(0)
				if m is BaseMaterial3D:
					return (m as BaseMaterial3D).transparency
			return -1
		var db_voor: Color = db_meet.call(db_dood)
		var db_levend_voor: Color = db_meet.call(db_levend)
		var db_levend_transp_voor: int = db_transp.call(db_levend)
		var db_y_voor: float = (db_dood._piece as Node3D).position.y
		var db_levend_y_voor: float = (db_levend._piece as Node3D).position.y
		db_dood._become_debris()
		var db_na: float = PawnView.fx("debris_donker_na", 4.0)
		var db_duur: float = PawnView.fx("debris_donker_duur", 2.5)
		var db_kracht: float = PawnView.fx("debris_donker", 0.7)
		var db_doorzicht: float = PawnView.fx("debris_doorzicht", 0.55)
		var db_zak: float = PawnView.fx("debris_zak", 0.08)
		print("[DEBRIS] instelling: na %.1f s, verloop %.1f s, kracht %.2f, doorzicht %.2f, zak %.2f" % [db_na, db_duur, db_kracht, db_doorzicht, db_zak])
		await get_tree().create_timer(db_na + db_duur + 0.4).timeout
		var db_daarna: Color = db_meet.call(db_dood)
		var db_levend_na: Color = db_meet.call(db_levend)
		var db_fouten := 0
		var db_verwacht: float = 1.0 - clampf(db_kracht, 0.0, 1.0)
		print("[DEBRIS] lijk : albedo %.2f -> %.2f (verwacht ~%.2f)" % [db_voor.r, db_daarna.r, db_verwacht])
		if absf(db_daarna.r - db_verwacht) > 0.05:
			print("[DEBRIS] FOUT: het lijk is niet donker geworden")
			db_fouten += 1
		var db_alpha_verwacht: float = 1.0 - clampf(db_doorzicht, 0.0, 1.0)
		print("[DEBRIS] lijk : alpha %.2f -> %.2f (verwacht ~%.2f), transparency %d (verwacht %d = alpha met depth-prepass)" % [
			db_voor.a, db_daarna.a, db_alpha_verwacht, db_transp.call(db_dood), BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS])
		if db_doorzicht > 0.001 and absf(db_daarna.a - db_alpha_verwacht) > 0.05:
			print("[DEBRIS] FOUT: het lijk is niet doorzichtig geworden")
			db_fouten += 1
		if db_doorzicht > 0.001 and db_transp.call(db_dood) != BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
			print("[DEBRIS] FOUT: het materiaal van het lijk staat niet op alpha met depth-prepass")
			db_fouten += 1
		var db_y_na: float = (db_dood._piece as Node3D).position.y
		print("[DEBRIS] lijk : y %.3f -> %.3f (verwacht ~%.3f)" % [db_y_voor, db_y_na, db_y_voor - db_zak])
		if absf((db_y_voor - db_y_na) - db_zak) > 0.005:
			print("[DEBRIS] FOUT: het lijk is niet (of niet ver genoeg) in het bord gezakt")
			db_fouten += 1
		print("[DEBRIS] levend: albedo %.2f -> %.2f (moet gelijk blijven)" % [db_levend_voor.r, db_levend_na.r])
		if absf(db_levend_na.r - db_levend_voor.r) > 0.01:
			print("[DEBRIS] FOUT: een LEVENDE pion verkleurde mee -- gedeeld materiaal aangeraakt")
			db_fouten += 1
		if absf(db_levend_na.a - db_levend_voor.a) > 0.01 or db_transp.call(db_levend) != db_levend_transp_voor:
			print("[DEBRIS] FOUT: een LEVENDE pion werd doorzichtig -- gedeeld materiaal aangeraakt")
			db_fouten += 1
		if absf((db_levend._piece as Node3D).position.y - db_levend_y_voor) > 0.001:
			print("[DEBRIS] FOUT: een LEVENDE pion zakte mee")
			db_fouten += 1
		print("[DEBRIS] %s: %d fout(en)" % ["PASS" if db_fouten == 0 else "FAIL", db_fouten])
		get_tree().quit(1 if db_fouten > 0 else 0)
		return
	elif "placetest" in args:
		# Zelf opstellen: kanonnen + paarden plaatsen, infanterie vult aan.
		game._start_match(1)
		await get_tree().create_timer(0.2).timeout
		game._begin_manual_placement()
		await get_tree().create_timer(0.2).timeout
		# 3 kanonnen op de voorste rij: flanken + centrum.
		for x in [0, 10, 5]:
			game._on_placement_tile_clicked(Vector2i(x, 9))
		# Test ongedaan maken: laatste kanon weg en terug.
		game._undo_placement()
		game._on_placement_tile_clicked(Vector2i(5, 9))
		# Ghost-voorvertoning (paard) boven een vrij vak zetten voor de screenshot.
		var ghost_screen: Vector2 = game._camera.unproject_position(
			game._board.to_global(game.tile_position(3, 10) + Vector3(0, 0.1, 0)))
		game._update_placement_ghost(ghost_screen)
		await get_tree().create_timer(0.2).timeout
		get_viewport().get_texture().get_image().save_png("res://_shot_place_mid.png")
		# 6 paarden op de achterste rij.
		for x in [0, 1, 2, 8, 9, 10]:
			game._on_placement_tile_clicked(Vector2i(x, 10))
		await get_tree().create_timer(0.4).timeout
		var st: GameState = GameSession.state
		var counts := {0: 0, 1: 0, 2: 0}
		var art_ok := true
		for pawn in st.get_alive_pawns_for(1):
			counts[pawn.unit_type] += 1
			if pawn.unit_type == Constants.UnitType.ARTILLERY and not [Vector2i(0, 9), Vector2i(10, 9), Vector2i(5, 9)].has(pawn.position):
				art_ok = false
		print("[PLACE] fase=%s inf=%d cav=%d art=%d kanonnen_op_gekozen_vakken=%s" % [
			Phase.to_string_phase(st.phase), counts[0], counts[1], counts[2], str(art_ok)])
		get_viewport().get_texture().get_image().save_png("res://_shot_place_done.png")
		get_tree().quit()
		return
	elif "through" in args:
		# Doorklik-test: klik op het zet-vak vóór de geselecteerde pion — de pion
		# hangt daar door de camerahoek overheen; de klik moet er doorheen vallen.
		var hand: CardHand = game.get_node("UI/CardHand")
		var steps := 0
		while GameSession.state.phase != Phase.Type.ACTION and steps < 300:
			steps += 1
			var st: GameState = GameSession.state
			if st.phase == Phase.Type.PRE_GAME:
				game._start_match(1)
			elif st.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(st.phase):
				game._continue_after_reveal()
			elif Phase.is_define(st.phase) and st.cards_defined[1].size() == 0:
				for c in hand.get_card_views():
					c.data.hp = 3
					c.data.stamina = 2
					c.data.attack = 2
					c._refresh()
				hand._on_confirm_pressed()
			elif Phase.is_linking(st.phase) and st.current_player == 1:
				for i in st.cards_revealed[1].size():
					if not st.cards_revealed[1][i].is_linked():
						game._on_link_card_picked(i)
						break
				for pawn in st.pawns.values():
					if pawn.owner_id == 1 and not pawn.is_eliminated and pawn.linked_card_id == -1 and game._pawn_has_room(pawn):
						game._on_link_pawn_clicked(pawn.id)
						break
			await get_tree().create_timer(0.02).timeout
		GameSession.state.current_player = 1
		var subject = null
		var front := Vector2i.ZERO
		for pawn in GameSession.state.get_active_pawns_for(1):
			var f := Vector2i(pawn.position.x, pawn.position.y - 1)
			if pawn.remaining_stamina >= 1 and GameSession.state.is_tile_empty(f):
				subject = pawn
				front = f
				break
		game._select_pawn(subject.id)
		await get_tree().physics_frame
		var world: Vector3 = game._board.to_global(game.tile_position(front.x, front.y) + Vector3(0, 0.1, 0))
		var screen: Vector2 = game._camera.unproject_position(world)
		var covering: int = game._raycast_pawn(screen)
		_click_at(screen)
		await get_tree().create_timer(0.6).timeout
		print("[THROUGH] dekkende_pion=%d (geselecteerd=%d) → pion_op_doelvak=%s (verwacht true)" % [
			covering, subject.id, str(GameSession.state.pawns[subject.id].position == front)])
		get_tree().quit()
		return
	elif "tunercheck" in args:
		# Doet de Model-tuner het nog, en kan hij opslaan? (4 augustus, na de
		# map-hernaming en de nieuwe leeuw/varken-modellen.) Drie dingen:
		# 1. welk model vindt het spel per factie/type/archetype,
		# 2. bouwt de tuner-scene zonder fouten op,
		# 3. overleeft de afstelling een rondje opslaan-en-teruglezen, met
		#    dezelfde sleutels (<factie>/<bestandsnaam>, map-onafhankelijk).
		var arch_lijst: Array = ["base", "spd", "hp", "atk", "mix"]
		var gevonden := 0
		var ontbreekt: Array = []
		print("[TUNER] model per factie en archetype (- = valt terug op base):")
		for doc in Constants.DOCTRINE_DATA.keys():
			var fac: String = Constants.doctrine_folder(int(doc))
			var regel: String = "[TUNER]   %-9s %-11s" % [Constants.doctrine_name(int(doc)), fac]
			for arch in arch_lijst:
				var naam := "infantry_%s.glb" % arch
				var pad := Bestandsindex.vind("res://assets/models/" + fac, naam)
				if pad != "" and ResourceLoader.exists(pad):
					regel += " %s=ja  " % arch
					gevonden += 1
				else:
					regel += " %s=-   " % arch
					ontbreekt.append("%s/%s" % [fac, arch])
			print(regel)
		print("[TUNER] %d modellen gevonden, %d nog niet geleverd" % [gevonden, ontbreekt.size()])
		# Musketten en gibs erbij: die hangen aan hetzelfde model.
		var zonder_gibs: Array = []
		for doc2 in Constants.DOCTRINE_DATA.keys():
			var fac2: String = Constants.doctrine_folder(int(doc2))
			for arch2 in arch_lijst:
				var mp := Bestandsindex.vind("res://assets/models/" + fac2, "infantry_%s.glb" % arch2)
				if mp == "" or not ResourceLoader.exists(mp):
					continue
				var gp := Bestandsindex.vind("res://assets/models/" + fac2, "infantry_%s_gibs.glb" % arch2)
				if gp == "" or not ResourceLoader.exists(gp):
					zonder_gibs.append("%s/infantry_%s" % [fac2, arch2])
		if zonder_gibs.is_empty():
			print("[TUNER] gibs: compleet")
		else:
			print("[TUNER] ZONDER GIBS (die pion valt niet uiteen): %s" % ", ".join(zonder_gibs))
		# 2. Bouwt de tuner op?
		var tuner_fouten := 0
		var scene: PackedScene = load("res://scenes/tools/ModelTuner.tscn")
		if scene == null:
			print("[TUNER] FOUT: ModelTuner.tscn laadt niet")
			tuner_fouten += 1
		else:
			var t: Node = scene.instantiate()
			if t == null:
				print("[TUNER] FOUT: ModelTuner instantieert niet")
				tuner_fouten += 1
			else:
				add_child(t)
				await get_tree().process_frame
				await get_tree().process_frame
				print("[TUNER] scene opgebouwd: %d kind-nodes" % t.get_child_count())
				# UI-vorm: pakt het paneel genoeg scherm, en kan elke tab scrollen?
				var pnl: PanelContainer = null
				for kind in t.find_children("*", "PanelContainer", true, false):
					pnl = kind as PanelContainer
					break
				if pnl != null:
					# Het paneel hangt onderaan met een hoogte in pixels en is
					# sleepbaar (Max, 7 september). Een vast AANDEEL van het
					# scherm werkte niet: op zijn staande venster (1080x1920)
					# vrat 56% het hele model op.
					var hoog: float = -pnl.offset_top
					var schermh: float = float(t.get_viewport().get_visible_rect().size.y)
					print("[TUNER] paneel %.0f px hoog van %.0f (%.0f%%), sleepbaar" % [
						hoog, schermh, 100.0 * hoog / maxf(schermh, 1.0)])
					if hoog < 120.0 or hoog > schermh * 0.9:
						print("[TUNER] FOUT: paneelhoogte buiten het bruikbare bereik")
						tuner_fouten += 1
					var greep_gevonden := false
					for kind in pnl.find_children("*", "Panel", true, false):
						if (kind as Control).mouse_default_cursor_shape == Control.CURSOR_VSIZE:
							greep_gevonden = true
							break
					if not greep_gevonden:
						print("[TUNER] FOUT: geen sleepgreep om de paneelhoogte mee te zetten")
						tuner_fouten += 1
				var tabc: TabContainer = null
				for kind in t.find_children("*", "TabContainer", true, false):
					tabc = kind as TabContainer
					break
				if tabc != null:
					var scrollbaar := 0
					var namen: Array = []
					for kind in tabc.get_children():
						namen.append(String(kind.name))
						if kind is ScrollContainer:
							scrollbaar += 1
					print("[TUNER] tabs: %d, waarvan scrollbaar %d (%s)" % [
						tabc.get_child_count(), scrollbaar, ", ".join(namen)])
					if scrollbaar != tabc.get_child_count():
						print("[TUNER] FOUT: niet elke tab kan scrollen; inhoud kan wegvallen")
						tuner_fouten += 1
				# De drie knoppen van 7 september indrukken. Alleen opbouwen zegt
				# niets over wat er PAS bij het indrukken gebeurt.
				var knoppen: Dictionary = {}
				for kn in t.find_children("*", "Button", true, false):
					knoppen[String((kn as Button).text)] = kn
				var keuze: OptionButton = null
				for kn in t.find_children("*", "OptionButton", true, false):
					if (kn as OptionButton).get_item_count() == 3 and (kn as OptionButton).get_item_text(1) == "alles rood":
						keuze = kn as OptionButton
						break
				if keuze == null:
					print("[TUNER] FOUT: geen team-keuze (rood / blauw / rood vs blauw)")
					tuner_fouten += 1
				if not knoppen.has("alle modellen") or not knoppen.has("bord"):
					print("[TUNER] FOUT: knop 'alle modellen' of 'bord' ontbreekt")
					tuner_fouten += 1
				else:
					(knoppen["alle modellen"] as Button).button_pressed = true
					await get_tree().process_frame
					await get_tree().process_frame
					var pionnen: Array = t.find_children("*", "Node3D", true, false).filter(
						func(n): return n is PawnView)
					print("[TUNER] alle modellen: %d pionnen op het veld" % pionnen.size())
					if pionnen.size() != 90:
						print("[TUNER] FOUT: verwacht 90 (6 facties x 3 types x 5 archetypen)")
						tuner_fouten += 1
					# Team-keuze: alles rood moet ELKE pion rood maken.
					if keuze != null:
						keuze.select(1)
						keuze.item_selected.emit(1)
						await get_tree().process_frame
						await get_tree().process_frame
						var rood := 0
						var alle: Array = t.find_children("*", "Node3D", true, false).filter(
							func(n): return n is PawnView)
						for p in alle:
							if (p as PawnView).team == Constants.Team.RED:
								rood += 1
						print("[TUNER] alles rood: %d van de %d pionnen rood" % [rood, alle.size()])
						if alle.size() == 0 or rood != alle.size():
							print("[TUNER] FOUT: team-keuze werkt niet door op alle pionnen")
							tuner_fouten += 1
					(knoppen["bord"] as Button).button_pressed = true
					await get_tree().process_frame
					await get_tree().process_frame
					var borden: Array = t.find_children("Board", "Node3D", true, false)
					var camaan := 0
					for b in borden:
						for c in (b as Node3D).find_children("*", "Camera3D", true, false):
							if (c as Camera3D).current:
								camaan += 1
					print("[TUNER] bord-view: %d bord(en), %d actieve bord-camera(s)" % [borden.size(), camaan])
					if borden.size() != 1:
						print("[TUNER] FOUT: bord-view laadt Board.tscn niet")
						tuner_fouten += 1
					if camaan > 0:
						print("[TUNER] FOUT: de bord-camera neemt het beeld over van de tuner")
						tuner_fouten += 1
					# "bord + legers" (16 september): beide legers in de
					# spel-opstelling op het bord, met de bord-camera aan,
					# en de charge-knop moet erop spelen (ruiter rijdt weg).
					if not knoppen.has("bord + legers") or not knoppen.has("charge (dood)"):
						print("[TUNER] FOUT: knop 'bord + legers' of 'charge (dood)' ontbreekt")
						tuner_fouten += 1
					else:
						(knoppen["bord + legers"] as Button).button_pressed = true
						await get_tree().process_frame
						await get_tree().process_frame
						var leger: Array = t.find_children("*", "Node3D", true, false).filter(
							func(n): return n is PawnView)
						var st_proef := GameState.new()
						st_proef.rules = RulesConfig.load_from_file("res://arena/arena_configs/v42_default.json")
						var fac_proef := CRules.facties_uit_bestand()
						if not fac_proef.is_empty():
							st_proef.rules.doctrines = fac_proef
						st_proef.doctrines[Constants.PLAYER_1] = int(t._my_fac_btn.get_selected_id())
						st_proef.doctrines[Constants.PLAYER_2] = int(t._opp_fac_btn.get_selected_id())
						var verwacht_leger: int = st_proef.default_placement(Constants.PLAYER_1).size() \
							+ st_proef.default_placement(Constants.PLAYER_2).size()
						var camaan2 := 0
						for b in t.find_children("Board", "Node3D", true, false):
							for c in (b as Node3D).find_children("*", "Camera3D", true, false):
								if (c as Camera3D).current:
									camaan2 += 1
						var vlaggen := 0
						var op_bord := 0
						for p in leger:
							if String((p as PawnView).rol_echt) == "flag":
								vlaggen += 1
							var pp: Vector3 = (p as Node3D).position
							if absf(pp.x) <= 5.01 and absf(pp.z) <= 5.01:
								op_bord += 1
						print("[TUNER] bord + legers: %d pionnen (verwacht %d), %d op het bord, %d vaandels, bord-camera aan=%d" % [
							leger.size(), verwacht_leger, op_bord, vlaggen, camaan2])
						if leger.size() != verwacht_leger or op_bord != leger.size():
							print("[TUNER] FOUT: de spel-opstelling staat niet compleet op het bord")
							tuner_fouten += 1
						if vlaggen != 2:
							print("[TUNER] FOUT: elk leger hoort een vaandeldrager te hebben")
							tuner_fouten += 1
						if camaan2 != 1:
							print("[TUNER] FOUT: bord + legers hoort de bord-camera aan te zetten")
							tuner_fouten += 1
						# Charge op het bord: de ruiter van de rode factie moet
						# van zijn vak vertrekken en er staat een verse vijand.
						t._type_btn.select(Constants.UnitType.CAVALRY)
						t._fac_btn.select(t._my_fac_btn.selected)
						var ruiter_voor: PawnView = null
						for p in leger:
							if (p as PawnView).team == Constants.Team.RED and (p as PawnView)._unit_type == Constants.UnitType.CAVALRY:
								ruiter_voor = p
								break
						var ruiter_thuis: Vector3 = ruiter_voor.position if ruiter_voor != null else Vector3.ZERO
						(knoppen["charge (dood)"] as Button).pressed.emit()
						await get_tree().create_timer(0.6).timeout
						var na: Array = t.find_children("*", "Node3D", true, false).filter(
							func(n): return n is PawnView)
						var verplaatst: bool = ruiter_voor != null and is_instance_valid(ruiter_voor) \
							and ruiter_voor.position.distance_to(ruiter_thuis) > 1.5
						print("[TUNER] charge op het bord: ruiter %s, %d pionnen na de knop (%d + verdediger), info: %s" % [
							"rijdt" if verplaatst else "STAAT STIL", na.size(), leger.size(), t._info.text])
						if not verplaatst or na.size() != leger.size() + 1:
							print("[TUNER] FOUT: de charge-knop speelt niet op het bord")
							tuner_fouten += 1
				t.queue_free()
				await get_tree().process_frame
		# 3. Opslaan en teruglezen.
		var voor: Dictionary = PawnView.model_tuning()
		var proef := "user://tunercheck_proef.json"
		var fh := FileAccess.open(proef, FileAccess.WRITE)
		if fh == null:
			print("[TUNER] FOUT: kan de afstelling niet wegschrijven")
			tuner_fouten += 1
		else:
			fh.store_string(JSON.stringify(voor, "\t") + "\n")
			fh.close()
			var terug = JSON.parse_string(FileAccess.get_file_as_string(proef))
			if not (terug is Dictionary):
				print("[TUNER] FOUT: de weggeschreven afstelling is geen geldige JSON")
				tuner_fouten += 1
			elif JSON.stringify(terug, "\t") != JSON.stringify(voor, "\t"):
				print("[TUNER] FOUT: opslaan en teruglezen levert iets anders op")
				tuner_fouten += 1
			else:
				print("[TUNER] opslaan/teruglezen: %d sleutels, byte-identiek terug" % voor.size())
			DirAccess.remove_absolute(ProjectSettings.globalize_path(proef))
		# Sleutels moeten map-onafhankelijk zijn: <factie>/<bestandsnaam>.
		var rare: Array = []
		for k in voor.keys():
			var s := String(k)
			if s.count("/") != 1 or s.contains("infanterie") or s.contains("wapens"):
				rare.append(s)
		if rare.is_empty():
			print("[TUNER] sleutels: allemaal <factie>/<bestandsnaam>, geen mapnaam erin")
		else:
			print("[TUNER] FOUT: sleutels met een mapnaam erin: %s" % ", ".join(rare))
			tuner_fouten += 1
		print("[TUNER] klaar: %d fout(en)" % tuner_fouten)
		get_tree().quit(0 if tuner_fouten == 0 else 1)
		return
	elif "facties" in args:
		# Waar spelen we nu eigenlijk mee? (C17, 3 augustus.) Drukt per factie
		# de kale tabel uit constants.gd af naast de ACTIEVE waarden, dus met
		# het doctrines-blok uit CRules.REGELS_BESTAND eroverheen, plus de
		# startvoorraad die een campagne daarmee boekt. Zo zie je in een
		# oogopslag wat een voorstel van de factiezoeker verandert, zonder een
		# campagne te hoeven starten.
		var blok: Dictionary = CRules.facties_uit_bestand()
		print("[FACTIES] bestand: %s" % CRules.REGELS_BESTAND)
		if blok.is_empty():
			print("[FACTIES] geen doctrines-blok: iedereen speelt de kale tabel uit constants.gd")
		else:
			print("[FACTIES] blok actief voor %d facties: %s" % [blok.size(), str(blok.keys())])
		var cr := CRules.new()
		cr.doctrines = blok
		print("[FACTIES] naam       kaarten budget comp            perks (hp/art/cav)  start-reserve")
		for doc in Constants.DOCTRINE_DATA.keys():
			var kaal: Dictionary = Constants.doctrine_data(doc)
			var nu: Dictionary = cr.doctrine_data(doc)
			var comp: Array = nu.comp
			var res: int = int(floor(int(comp[0]) * cr.start_poolfactor)) \
				+ int((cr.budget_bonus.get(str(doc), {}) as Dictionary).get("pt", 0))
			var ster := "  " if JSON.stringify(kaal) == JSON.stringify(nu) else " *"
			print("[FACTIES]%s %-10s %5d %6d  %-14s %d / %d / %d          %d inf" % [
				ster, String(nu.name), int(nu.cards), int(nu.budget), str(comp),
				int(nu.get("hp_bonus", 0)), int(nu.get("art_range_bonus", 0)),
				int(nu.get("cav_speed_bonus", 0)), res])
		print("[FACTIES] (* = wijkt af van constants.gd; start-reserve = comp x %.2f + budget_bonus)"
			% cr.start_poolfactor)
		# Proef op de som: een echte campagne opstarten en kijken of haar
		# grootboek en haar duelregels dezelfde facties gebruiken. Dit is de
		# controle die tot 3 augustus ontbrak -- toen las de campagne de kale
		# tabel en speelde ze dus andere dieren dan de arena mat.
		var proef := SoloDriver.new(31415, -1, 6)
		var eerste: int = int(proef.c.spelers.keys()[0])
		# Kies een speler wiens factie ECHT is overschreven, bij voorkeur eentje
		# met een andere comp: dat is het enige dat je in het grootboek TERUG
		# ziet. Bij een lege lijst valt hij terug op de eerste speler.
		for eis in ["comp", ""]:
			var gevonden := false
			for sid in proef.c.spelers:
				var sleutel := str(int(proef.c.spelers[sid].doctrine))
				var ov = blok.get(sleutel, null)
				if ov is Dictionary and (eis == "" or (ov as Dictionary).has(eis)):
					eerste = int(sid)
					gevonden = true
					break
			if gevonden:
				break
		var doc0: int = int(proef.c.spelers[eerste].doctrine)
		# Tegenstander: de eerste speler uit het andere team die bestaat.
		var tegen: int = eerste
		for sid in proef.c.spelers:
			if int(proef.c.spelers[sid].team) != int(proef.c.spelers[eerste].team):
				tegen = int(sid)
				break
		var duel: RulesConfig = proef.duel_rules_voor(eerste, tegen)
		print("[FACTIES] proefcampagne: %s start met %d inf in het grootboek (verwacht %d)" % [
			String(cr.doctrine_data(doc0).name), int(proef.c.pool_van(eerste).inf),
			int(floor(int((cr.doctrine_data(doc0).comp as Array)[0]) * cr.start_poolfactor))
				+ int((cr.budget_bonus.get(str(doc0), {}) as Dictionary).get("pt", 0))])
		print("[FACTIES] duelregels dragen %d factie-overrides mee, opstelling %s" % [
			(duel.doctrines as Dictionary).size(), str(duel.campaign.comp_override["1"])])
		get_tree().quit()
		return
	elif "wapengeluidcheck" in args:
		# Welke zwaai en klap hoort elke pion? (17 september, Max: "slashing
		# sounds en zwaard-impactgeluiden per factie of type wapen"). Per
		# factie x type x archetype: het wapen uit PawnView.melee_wapen en de
		# categorie die Audio werkelijk speelt voor slash / melee_kill /
		# melee_survive. FAIL als er iets stil blijft of als de bajonet ergens
		# anders dan bij de infanterie terechtkomt.
		print("[WAPEN] factie | type | arch | wapen | slash | kill | survive")
		var fouten: Array = []
		var wapens: Dictionary = {}
		for doc in Constants.Doctrine.values():
			var fac: String = Constants.doctrine_folder(doc)
			for ut in [Constants.UnitType.INFANTRY, Constants.UnitType.CAVALRY]:
				for arch in ["base", "spd", "hp", "atk", "mix"]:
					var wapen: String = PawnView.melee_wapen(ut, arch, doc)
					wapens[wapen] = true
					var cats: Array = []
					for cat in ["slash", "melee_kill", "melee_survive"]:
						var eff: String = Audio.effectieve_melee_categorie(cat, wapen, doc)
						cats.append(eff)
						if eff == "":
							fouten.append("%s %s %s: %s stil" % [fac, Constants.unit_type_file(ut), arch, cat])
						elif not eff.contains("_" + wapen):
							fouten.append("%s %s %s: %s valt terug op %s" % [fac, Constants.unit_type_file(ut), arch, cat, eff])
					if (ut == Constants.UnitType.INFANTRY) != (wapen == "bajonet"):
						fouten.append("%s %s %s: bajonet hoort bij de infanterie, dit is %s" % [fac, Constants.unit_type_file(ut), arch, wapen])
					print("[WAPEN] %-9s | %-8s | %-4s | %-7s | %s | %s | %s" % [fac, Constants.unit_type_file(ut), arch, wapen, cats[0], cats[1], cats[2]])
		# per wapen minstens twee varianten per categorie (anders klinkt elke klap hetzelfde)
		for w in wapens:
			for cat in ["slash", "melee_kill", "melee_survive"]:
				var n: int = Audio.variant_aantal("%s_%s" % [cat, w])
				if n < 2:
					fouten.append("%s_%s: %d variant(en), minstens 2 gewenst" % [cat, w, n])
		# de vier families moeten allemaal voorkomen
		for w in ["sabel", "bijl", "lans", "bajonet"]:
			if not wapens.has(w):
				fouten.append("wapen %s komt bij geen enkel model voor" % w)
		# een factie-opname wint van de wapen-versie (de keten), zonder dat er
		# een hoeft te liggen: de keten zelf moet kloppen
		var keten: Array = Audio.melee_keten("melee_kill", "bijl", Constants.Doctrine.MENS)
		if keten != ["melee_kill_bijl_pig", "melee_kill_bijl", "melee_kill"]:
			fouten.append("keten klopt niet: %s" % [keten])
		print("[WAPEN] wapens: %s" % [", ".join(wapens.keys())])
		if fouten.is_empty():
			print("[WAPEN] PASS")
		else:
			for f in fouten:
				print("[WAPEN] FOUT: %s" % f)
			print("[WAPEN] FAIL (%d)" % fouten.size())
		get_tree().quit(0 if fouten.is_empty() else 1)
		return
	elif "geluidcheck" in args:
		# Doet elk wav-bestand ook echt mee? (Max, 30 juli: "importeer de nieuwe
		# sounds"). Per categorie: hoeveel varianten geladen zijn, de mix-stand
		# en de tuning uit sounds/sound_tuning.json. Regels met AAN=0 zijn
		# bestanden die het spel NIET kan spelen -- die moet je zien.
		# Sinds 18 september (een mengpaneel): mix-dB, tuner-dB en vertraging
		# zijn wat het spel ECHT gebruikt, geerfd van `bron` als de categorie
		# geen eigen regel heeft (Audio.mix_bron); "eigen" = zelfstandig.
		print("[SND] categorie | varianten | mix-dB | tuner-dB | vertraging | bron")
		var cats: Array = Audio.alle_categorieen()
		var stil: Array = []
		var los: Array = []
		for cat in cats:
			var n: int = Audio.variant_aantal(cat)
			if n == 0:
				stil.append(cat)
			var bron: String = Audio.mix_bron(String(cat))
			print("[SND] %-24s | %d | %+.1f | %+.1f | %+.2f | %s" % [cat, n,
				Audio.mix_db(cat), Audio.volume_correctie(cat), Audio.extra_vertraging(cat),
				"eigen" if bron == String(cat) else bron])
		# Stille opnames: een categorie die geladen is maar die geen enkel
		# script ooit afspeelt. Dat is de vraag die telt -- "staat het bestand
		# in een categorie" is altijd waar en zegt dus niets.
		for cat in cats:
			if not Audio.categorie_wordt_gespeeld(String(cat)):
				los.append(String(cat))
		los.sort()
		print("[SND] categorieen: %d, zonder geluid: %s" % [cats.size(),
			"geen" if stil.is_empty() else String(", ").join(stil)])
		print("[SND] categorieen die niemand afspeelt: %s" % [
			"geen" if los.is_empty() else String(", ").join(los)])
		print("[SND] klaar")
		get_tree().quit()
		return
	elif "cliplengtes" in args:
		# Overzicht van alle animatie-lengtes per model (Max, 28 juli): handig
		# om sterfgeluiden en effect-timings op te maken.
		print("[CLIPS] model | clip | seconden")
		var mdir := "res://assets/models/"
		var facties: Array = []
		var dd := DirAccess.open(mdir)
		if dd != null:
			dd.list_dir_begin()
			var naam := dd.get_next()
			while naam != "":
				if dd.current_is_dir() and not naam.begins_with(".") and naam != "board" and naam != "props":
					facties.append(naam)
				naam = dd.get_next()
		for fac in facties:
			var fd := DirAccess.open(mdir + fac)
			if fd == null:
				continue
			var bestanden: Array = []
			for f in Bestandsindex.alles(mdir + fac, ".glb"):
				if not String(f).contains("_gibs") and not String(f).contains("_musket"):
					bestanden.append(f)
			bestanden.sort()
			for b in bestanden:
				var scene = load(Bestandsindex.vind(mdir + fac, String(b)))
				if scene == null:
					continue
				var inst = scene.instantiate()
				var spelers: Array = inst.find_children("*", "AnimationPlayer", true, false)
				if spelers.is_empty():
					inst.queue_free()
					continue
				var ap: AnimationPlayer = spelers[0]
				var namen: Array = ap.get_animation_list()
				namen.sort()
				# Naast de ruwe naam ook de naam die het SPEL gebruikt: verse
				# exports heten "Death 1" en worden bij het laden die1. Zo zie
				# je in een oogopslag of elke actie een clip heeft.
				var tellers: Dictionary = {}
				for an in namen:
					var lengte: float = ap.get_animation(an).length
					var spel := String(an)
					if not PawnView._schone_clipnaam(spel):
						var doel := PawnView._clip_doelnaam(spel)
						if doel == "":
							spel = "(geen actie)"
						else:
							var nr: int = int(tellers.get(doel, 0)) + 1
							tellers[doel] = nr
							spel = "%s%d" % [doel, nr]
					print("[CLIPS] %s/%s | %s -> %s | %.2f" % [
						fac, String(b).get_basename(), an, spel, lengte])
				inst.queue_free()
		print("[CLIPS] klaar")
		get_tree().quit()
		return
	elif "shoottest" in args:
		# Verifieer het klik-pad voor schieten (artillerie + infanterie) in de driver.
		var hand: CardHand = game.get_node("UI/CardHand")
		var steps := 0
		while GameSession.state.phase != Phase.Type.ACTION and steps < 300:
			steps += 1
			var st: GameState = GameSession.state
			if st.phase == Phase.Type.PRE_GAME:
				game._start_match(1)
			elif st.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(st.phase):
				game._continue_after_reveal()
			elif Phase.is_define(st.phase) and st.cards_defined[1].size() == 0:
				for c in hand.get_card_views():
					c.data.hp = 3
					c.data.stamina = 2
					c.data.attack = 2
					c._refresh()
				hand._on_confirm_pressed()
			elif Phase.is_linking(st.phase) and st.current_player == 1:
				for i in st.cards_revealed[1].size():
					if not st.cards_revealed[1][i].is_linked():
						game._on_link_card_picked(i)
						break
				for pawn in st.pawns.values():
					if pawn.owner_id == 1 and not pawn.is_eliminated and pawn.linked_card_id == -1 and game._pawn_has_room(pawn):
						game._on_link_pawn_clicked(pawn.id)
						break
			await get_tree().create_timer(0.02).timeout
		var st2: GameState = GameSession.state
		st2.current_player = 1
		# Gecontroleerd scenario midden op het bord.
		var gun: Pawn = st2._spawn_pawn(1, Vector2i(5, 5), Constants.UnitType.ARTILLERY)
		var gcard := Card.new(st2.next_card_id(), 1, st2.round_number, 1, 4, 2)
		st2.all_cards[gcard.id] = gcard
		gun.link_card(gcard)
		var victim: Pawn = st2._spawn_pawn(2, Vector2i(5, 3))
		var inf: Pawn = st2._spawn_pawn(1, Vector2i(8, 5), Constants.UnitType.INFANTRY)
		var icard := Card.new(st2.next_card_id(), 1, st2.round_number, 3, 1, 3)
		st2.all_cards[icard.id] = icard
		inf.link_card(icard)
		var victim2: Pawn = st2._spawn_pawn(2, Vector2i(8, 3))
		game._build_pawn_views()
		game._refresh_all()
		# 1) Artillerie: dracht 4, doelwit op afstand 2 → oranje + klik = schot.
		game._select_pawn(gun.id)
		print("[SHOOT] artillerie: doelwitten=%s vuurlijn_vakken=%d (vaste dracht %d)" % [
			str(game._valid_shots), Rules.get_shot_range_tiles(st2, gun.id).size(), Constants.ARTILLERY_RANGE])
		await get_tree().create_timer(0.25).timeout
		get_viewport().get_texture().get_image().save_png("res://_shot_shoottest.png")
		game._on_pawn_clicked(victim.id)
		print("[SHOOT] artillerieschot raak=%s (verwacht true)" % str(victim.is_eliminated))
		# 2) Infanterie: schot op exact afstand 2.
		GameSession.state.current_player = 1
		game._select_pawn(inf.id)
		print("[SHOOT] infanterie: doelwitten=%s (aanval %d → schade %d)" % [
			str(game._valid_shots), inf.attack_value, Rules.shot_damage(GameSession.state, inf)])
		game._on_pawn_clicked(victim2.id)
		print("[SHOOT] infanterieschot raak=%s (verwacht true)" % str(victim2.is_eliminated))
		# Vang de treffer-feedback (flits + zwevend schade-label) op een screenshot.
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("res://_shot_hitfx.png")
		get_tree().quit()
		return
	elif "simcheck" in args:
		# F0.4a: draai alle vastgelegde golden sims (tests/golden_sims.json) en
		# vergelijk winnaar/cycli/acties. Exit 0 = alles identiek, 1 = afwijking.
		var gj = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden_sims.json"))
		# De ijk-sims draaien op de regels die we ECHT spelen (Max, 30 juli:
		# "4.2 zijn de regels nu toch"). Stond hier eerst null = kale 4.1-
		# defaults; die regelset speelt niemand meer, dus bewaakte de baseline
		# het verkeerde. Pad staat in golden_sims.json ("rules"), leeg = 4.1.
		var sim_rules_pad := String(gj.get("rules", ""))
		var sim_rules: RulesConfig = null
		if sim_rules_pad != "" and FileAccess.file_exists(sim_rules_pad):
			var rj = JSON.parse_string(FileAccess.get_file_as_string(sim_rules_pad))
			if rj is Dictionary:
				sim_rules = RulesConfig.from_dict(rj)
		var mismatches := 0
		for entry in gj.sims:
			var uitkomst: Dictionary = _run_sim(String(entry.p1), String(entry.p2),
				_sim_doctrine(String(entry.d1)), _sim_doctrine(String(entry.d2)), int(entry.seed),
				RulesConfig.from_dict(rj_kopie(sim_rules_pad)) if sim_rules != null else null)
			var ok: bool = uitkomst.winner == int(entry.winner) 				and uitkomst.cyclus == int(entry.cyclus) and uitkomst.acties == int(entry.acties)
			print("[SIMCHECK] %s-%s %s-%s seed=%d -> winner=%d cyclus=%d acties=%d %s" % [
				entry.p1, entry.p2, entry.d1, entry.d2, int(entry.seed),
				uitkomst.winner, uitkomst.cyclus, uitkomst.acties,
				"OK" if ok else "AFWIJKING (verwacht winner=%d cyclus=%d acties=%d)" % [
					int(entry.winner), int(entry.cyclus), int(entry.acties)]])
			if not ok:
				mismatches += 1
		print("[SIMCHECK] klaar: %d afwijking(en)" % mismatches)
		get_tree().quit(0 if mismatches == 0 else 1)
		return
	elif "record" in args:
		# F0.7: neem een partij op als event-log. Gebruik:
		#   -- record <uit.json> <p1> <p2> [d1] [d2] [seed]
		var ri := args.find("record")
		var rout: String = String(args[ri + 1]) if args.size() > ri + 1 else "user://replays/partij.json"
		var rn1: String = String(args[ri + 2]) if args.size() > ri + 2 else "easy"
		var rn2: String = String(args[ri + 3]) if args.size() > ri + 3 else "easy"
		var rd1: int = _sim_doctrine(String(args[ri + 4]) if args.size() > ri + 4 else "mens")
		var rd2: int = _sim_doctrine(String(args[ri + 5]) if args.size() > ri + 5 else "mens")
		var rseed: int = int(args[ri + 6]) if args.size() > ri + 6 else 0
		var ru: Dictionary = _run_sim(rn1, rn2, rd1, rd2, rseed, null, rout)
		print("[RECORD] %s -> winner=%d acties=%d entries=%d" % [rout, ru.winner, ru.acties, ru.get("entries", 0)])
		get_tree().quit()
		return
	elif "replay" in args:
		# F0.7: verifieer een opgenomen log — fold + per-actie-hash + eindstaat.
		var pi := args.find("replay")
		if args.size() <= pi + 1:
			print("[REPLAY] geef een bestandspad op")
			get_tree().quit(1)
			return
		var rpath := String(args[pi + 1])
		var uitkomst: Dictionary = MatchLog.verify_file(rpath)
		print("[REPLAY] %s -> %s" % [rpath, "OK (byte-identiek)" if uitkomst.ok else "FOUT: " + String(uitkomst.get("fout", "?"))])
		get_tree().quit(0 if uitkomst.ok else 1)
		return
	elif "makegoldens" in args:
		_make_goldens()
		get_tree().quit()
		return
	elif "sim" in args:
		# Puur engine + AI: speel een volledige partij AI vs AI en log het resultaat.
		# Gebruik: -- sim <p1> <p2> [d1] [d2] [seed] [--rules pad.json]
		#   p = easy/medium/hard (default medium); d = mens/muis/leeuw/beer/wolf/vos;
		#   seed (int, default 0) maakt de partij reproduceerbaar (F0.1).
		var n1: String = args[1] if args.size() > 1 else "medium"
		var n2: String = args[2] if args.size() > 2 else "medium"
		var d1: int = _sim_doctrine(args[3] if args.size() > 3 else "mens")
		var d2: int = _sim_doctrine(args[4] if args.size() > 4 else "mens")
		var sim_seed: int = int(args[5]) if args.size() > 5 else 0
		# Optioneel: --rules <pad.json> laadt een RulesConfig (F0.2).
		var sim_rules: RulesConfig = null
		var ridx: int = args.find("--rules")
		if ridx != -1 and args.size() > ridx + 1:
			sim_rules = RulesConfig.load_from_file(String(args[ridx + 1]))
			print("[SIM] rules_config: %s (%s)" % [args[ridx + 1], sim_rules.rules_version])
		var uitkomst: Dictionary = _run_sim(n1, n2, d1, d2, sim_seed, sim_rules)
		var s := GameSession.state
		print("[SIM %s(P1,%s) vs %s(P2,%s)] winner=%d cyclus=%d acties=%d p1_haven=%d p2_haven=%d p1_alive=%d p2_alive=%d guard=%d" % [
			n1, Constants.doctrine_name(d1), n2, Constants.doctrine_name(d2),
			s.winner, s.cycle, uitkomst.acties,
			Rules.count_pawns_in_haven(s, 1), Rules.count_pawns_in_haven(s, 2),
			s.get_alive_pawns_for(1).size(), s.get_alive_pawns_for(2).size(), uitkomst.guard])
		get_tree().quit()
		return
	elif "aithread" in args:
		var hand: CardHand = game.get_node("UI/CardHand")
		var steps := 0
		while GameSession.state.phase != Phase.Type.ACTION and steps < 300:
			steps += 1
			var st: GameState = GameSession.state
			if st.phase == Phase.Type.PRE_GAME:
				game._start_match(2)  # Hard
			elif st.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(st.phase):
				game._continue_after_reveal()
			elif Phase.is_define(st.phase) and st.cards_defined[1].size() == 0:
				for c in hand.get_card_views():
					c.data.hp = 3
					c.data.stamina = 2
					c.data.attack = 2
					c._refresh()
				hand._on_confirm_pressed()
			elif Phase.is_linking(st.phase) and st.current_player == 1:
				for i in st.cards_revealed[1].size():
					if not st.cards_revealed[1][i].is_linked():
						game._on_link_card_picked(i)
						break
				for pawn in st.pawns.values():
					if pawn.owner_id == 1 and not pawn.is_eliminated and pawn.linked_card_id == -1 and game._pawn_has_room(pawn):
						game._on_link_pawn_clicked(pawn.id)
						break
			await get_tree().create_timer(0.02).timeout
		GameSession.state.current_player = 2
		var t0 := Time.get_ticks_msec()
		var snap: GameState = GameSession.state.clone()
		var thread := Thread.new()
		thread.start(game._ai.choose_action.bind(snap))
		var frames := 0
		while thread.is_alive():
			frames += 1
			await get_tree().process_frame
		var action = thread.wait_to_finish()
		print("[AITHREAD] leeg=%s type=%s rekentijd=%dms frames_gerenderd_tijdens=%d" % [
			str(action.is_empty()), str(action.get("type", "-")), Time.get_ticks_msec() - t0, frames])
		get_tree().quit()
		return
	elif "benchultra" in args:
		var hand: CardHand = game.get_node("UI/CardHand")
		var steps := 0
		while GameSession.state.phase != Phase.Type.ACTION and steps < 300:
			steps += 1
			var st: GameState = GameSession.state
			if st.phase == Phase.Type.PRE_GAME:
				game._start_match(3)  # Ultra
			elif st.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(st.phase):
				game._continue_after_reveal()
			elif Phase.is_define(st.phase) and st.cards_defined[1].size() == 0:
				for c in hand.get_card_views():
					c.data.hp = 3
					c.data.stamina = 2
					c.data.attack = 2
					c._refresh()
				hand._on_confirm_pressed()
			elif Phase.is_linking(st.phase) and st.current_player == 1:
				for i in st.cards_revealed[1].size():
					if not st.cards_revealed[1][i].is_linked():
						game._on_link_card_picked(i)
						break
				for pawn in st.pawns.values():
					if pawn.owner_id == 1 and not pawn.is_eliminated and pawn.linked_card_id == -1 and game._pawn_has_room(pawn):
						game._on_link_pawn_clicked(pawn.id)
						break
			await get_tree().create_timer(0.02).timeout
		var total_u := 0
		var n_u := 3
		for k in n_u:
			var t0u := Time.get_ticks_msec()
			var act: Dictionary = game._ai.choose_action(GameSession.state)
			total_u += Time.get_ticks_msec() - t0u
			print("[BENCHULTRA] zet %d: %s in %d ms" % [k + 1, str(act.get("type", "-")), Time.get_ticks_msec() - t0u])
		print("[BENCHULTRA] gemiddeld choose_action = %d ms over %d calls (budget %d ms)" % [
			total_u / n_u, n_u, game._ai.time_budget_ms])
		get_tree().quit()
		return
	elif "benchhard" in args:
		var hand: CardHand = game.get_node("UI/CardHand")
		var steps := 0
		while GameSession.state.phase != Phase.Type.ACTION and steps < 300:
			steps += 1
			var st: GameState = GameSession.state
			if st.phase == Phase.Type.PRE_GAME:
				game._start_match(2)  # Hard
			elif st.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(st.phase):
				game._continue_after_reveal()
			elif Phase.is_define(st.phase) and st.cards_defined[1].size() == 0:
				for c in hand.get_card_views():
					c.data.hp = 3
					c.data.stamina = 2
					c.data.attack = 2
					c._refresh()
				hand._on_confirm_pressed()
			elif Phase.is_linking(st.phase) and st.current_player == 1:
				for i in st.cards_revealed[1].size():
					if not st.cards_revealed[1][i].is_linked():
						game._on_link_card_picked(i)
						break
				for pawn in st.pawns.values():
					if pawn.owner_id == 1 and not pawn.is_eliminated and pawn.linked_card_id == -1 and game._pawn_has_room(pawn):
						game._on_link_pawn_clicked(pawn.id)
						break
			await get_tree().create_timer(0.02).timeout
		var total := 0
		var n := 5
		for k in n:
			var t0 := Time.get_ticks_msec()
			game._ai.choose_action(GameSession.state)
			total += Time.get_ticks_msec() - t0
		print("[BENCHHARD] gemiddeld choose_action = %d ms over %d calls" % [total / n, n])
		get_tree().quit()
		return
	elif "carddist" in args:
		game._start_match(1)
		await get_tree().create_timer(0.2).timeout
		game._confirm_placement()
		await get_tree().create_timer(0.3).timeout
		var cv: CardView = game.get_node("UI/CardHand").get_card_views()[0]
		var log := []
		var snap := func() -> String:
			return "%d/%d/%d(som %d)" % [cv.data.hp, cv.data.stamina, cv.data.attack, cv.data.stat_sum()]
		log.append(snap.call())
		cv._on_hp_plus_pressed()
		log.append(snap.call())
		cv._on_hp_plus_pressed()
		log.append(snap.call())
		cv._on_hp_plus_pressed()  # geblokkeerd (max 5)
		log.append(snap.call())
		cv._on_hp_minus_pressed()
		log.append(snap.call())
		cv._on_atk_minus_pressed()
		log.append(snap.call())
		print("[DIST] " + " -> ".join(log))
		get_tree().quit()
		return
	elif "define" in args:
		# `-- define muis` toont de 4-kaarten-waaier van de Muis.
		if "muis" in args:
			game._human_doctrine = Constants.Doctrine.MUIS
			game._ai_doctrine = Constants.Doctrine.MENS
		game._start_match(1)
		await get_tree().create_timer(0.2).timeout
		game._confirm_placement()
		await get_tree().create_timer(0.6).timeout
		# v4.2: eerst het CP-bod; klik "geen CP" weg zodat de waaier zelf in
		# beeld komt (UI-assetpack, 3 september: de kaarten zijn nu het scherm).
		if Phase.is_define(GameSession.state.phase) and not game._card_hand.visible:
			# `cp`: een CP-punt inzetten, dan draagt kaart 1 het zegel (17 september).
			game._on_cp_choice(1 if "cp" in args else 0)
			await get_tree().create_timer(0.9).timeout
		print("[DEFINE] fase=%s waaier=%s kaarten=%d" % [Phase.to_string_phase(GameSession.state.phase),
			str(game._card_hand.visible), game._card_hand.get_card_views().size()])
		# Waaier (16 september): plekken, draai en volgorde; met `focus` een
		# muisbeweging over de tweede kaart, die dan naar voren en omhoog moet.
		var dh: CardHand = game._card_hand
		var dviews: Array = dh.get_card_views()
		for i in dviews.size():
			var cv: CardView = dviews[i]
			print("[DEFINE] kaart %d: midden=(%.0f, %.0f) draai=%.1f graden schaal=%.2f volgorde=%d" % [
				i, cv.position.x + UiAssets.KAART_MAAT.x * 0.5 * cv.scale.x, cv.position.y + UiAssets.KAART_MAAT.y * 0.5 * cv.scale.y,
				rad_to_deg(cv.rotation), cv.scale.x / CardHand.KAART_SCHAAL, cv.get_index()])
		# CP-zegel per kaart: met inzet dubbel en groter, leeg een vage afdruk.
		for i in dviews.size():
			var zcv: CardView = dviews[i]
			var zz: TextureRect = zcv.find_child("CpZegel", true, false)
			var zz2: TextureRect = zcv.find_child("CpZegel2", true, false)
			if zz != null and zz2 != null:
				var inzet: bool = zz2.visible
				var zok: bool = (inzet and zz.modulate.a >= 0.99 and zz.size.x > CardView.CP_MAAT.x * 0.45) \
					or (not inzet and zz.modulate.a <= 0.3 and zz.texture == UiAssets.kaart("cp_leeg"))
				print("[DEFINE] kaart %d zegel: %s, breed %.0f, alpha %.2f (%s)" % [
					i, "CP-inzet (dubbel)" if inzet else "leeg (vaag)", zz.size.x, zz.modulate.a, "PASS" if zok else "FAIL"])
		# Kolommen binnen het kaartframe (de lijst loopt tot x 47 en vanaf 599).
		if dviews.size() >= 1:
			var k_links := 9999.0
			var k_rechts := -9999.0
			for knaam in ["HpKolom", "StaKolom", "AtkKolom"]:
				var kn: Control = (dviews[0] as CardView).find_child(knaam, true, false)
				if kn != null:
					k_links = minf(k_links, kn.position.x)
					k_rechts = maxf(k_rechts, kn.position.x + kn.size.x * kn.scale.x)
			print("[DEFINE] kolommen van %.0f tot %.0f op de kaart, kader 47..599 (%s)" % [
				k_links, k_rechts, "PASS" if k_links >= 47.0 and k_rechts <= 599.0 else "FAIL"])
		if "klik" in args and dviews.size() >= 1:
			var kdoel: CardView = dviews[0]
			var ky_voor: float = kdoel.position.y
			var kpunt: Vector2 = kdoel.get_global_transform() * Vector2(UiAssets.KAART_MAAT.x * 0.5, UiAssets.KAART_MAAT.y * 0.3)
			await _sc_muis(kpunt, true)
			await _sc_muis(kpunt, false)
			await get_tree().create_timer(0.4).timeout
			var kboven: bool = kdoel.get_index() == dviews.size() - 1
			print("[DEFINE] klik op kaart 0: bovenop=%s omhoog=%.0f px schaal=%.2f (%s)" % [
				str(kboven), ky_voor - kdoel.position.y, kdoel.scale.x / CardHand.KAART_SCHAAL,
				"PASS" if kboven and kdoel.position.y < ky_voor - 60.0 else "FAIL"])
			# De min-knop (17 september): een echte klik erop haalt een punt van HP af
			# (het gaat naar de kleinste andere stat), daarna zet de plus het terug.
			var kmin: Button = kdoel.find_child("HpMinus", true, false)
			var kplus: Button = kdoel.find_child("HpPlus", true, false)
			if kmin != null and kplus != null:
				var hp_voor: int = kdoel.data.hp
				var kmin_punt: Vector2 = kmin.get_global_transform() * (kmin.size * 0.5)
				await _sc_muis(kmin_punt, true)
				await _sc_muis(kmin_punt, false)
				var hp_na_min: int = kdoel.data.hp
				var kplus_punt: Vector2 = kplus.get_global_transform() * (kplus.size * 0.5)
				await _sc_muis(kplus_punt, true)
				await _sc_muis(kplus_punt, false)
				# Volgorde in de kolom: plus boven het cijfer, min eronder, even groot.
				var kcijfer: Control = kdoel.find_child("HpValue", true, false)
				var volgorde_ok: bool = kcijfer != null and kplus.position.y + kplus.size.y <= kcijfer.position.y \
					and kcijfer.position.y + kcijfer.size.y <= kmin.position.y and kmin.size == kplus.size
				print("[DEFINE] min-knop: hp %d -> %d -> %d; plus op %.0f, cijfer %.0f..%.0f, min op %.0f, knoppen %.0f px (%s)" % [
					hp_voor, hp_na_min, kdoel.data.hp, kplus.position.y,
					kcijfer.position.y if kcijfer != null else -1.0, (kcijfer.position.y + kcijfer.size.y) if kcijfer != null else -1.0,
					kmin.position.y, kmin.size.x,
					"PASS" if hp_na_min == hp_voor - 1 and kdoel.data.hp == hp_voor and volgorde_ok else "FAIL"])
			else:
				print("[DEFINE] FOUT: geen min- of plus-knop gevonden op kaart 0")
		if "focus" in args and dviews.size() >= 2:
			var doel: CardView = dviews[1]
			var y_voor: float = doel.position.y
			var ev := InputEventMouseMotion.new()
			ev.position = doel.get_global_transform() * (UiAssets.KAART_MAAT * 0.5)
			ev.global_position = ev.position
			Input.parse_input_event(ev)
			await get_tree().create_timer(0.4).timeout
			var bovenop: bool = doel.get_index() == dviews.size() - 1
			print("[DEFINE] focus op kaart 1: bovenop=%s omhoog=%.0f px schaal=%.2f (%s)" % [
				str(bovenop), y_voor - doel.position.y, doel.scale.x / CardHand.KAART_SCHAAL,
				"PASS" if bovenop and doel.position.y < y_voor - 5.0 else "FAIL"])
		out = "res://_shot_define.png"
	elif "reveal" in args:
		var hand: CardHand = game.get_node("UI/CardHand")
		game._start_match(1)
		await get_tree().create_timer(0.2).timeout
		game._confirm_placement()
		await get_tree().create_timer(0.3).timeout
		for c in hand.get_card_views():
			c.data.hp = 3
			c.data.stamina = 2
			c.data.attack = 2
			c._refresh()
		hand._on_confirm_pressed()
		await get_tree().create_timer(0.5).timeout
		print("[REVEAL] fase=%s" % Phase.to_string_phase(GameSession.state.phase))
		out = "res://_shot_reveal.png"
	elif "link" in args:
		var lfn := {"muis": Constants.Doctrine.MUIS, "varken": Constants.Doctrine.MENS, "leeuw": Constants.Doctrine.LEEUW, "beer": Constants.Doctrine.BEER, "wolf": Constants.Doctrine.WOLF, "krokodil": Constants.Doctrine.VOS}
		for fn in lfn:
			if fn in args:
				game._human_doctrine = lfn[fn]
				game._ai_doctrine = lfn[fn]
		var hand: CardHand = game.get_node("UI/CardHand")
		var steps := 0
		while not (Phase.is_linking(GameSession.state.phase) and GameSession.state.current_player == 1) \
				and steps < 60:
			steps += 1
			var st: GameState = GameSession.state
			if st.phase == Phase.Type.PRE_GAME:
				game._start_match(1)
			elif st.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(st.phase):
				game._continue_after_reveal()
			elif Phase.is_define(st.phase) and st.cards_defined[1].size() == 0:
				var lbud: int = int(GameSession.state.doctrine_data_of(1).budget)
				for c in hand.get_card_views():
					c.data.hp = 1
					c.data.stamina = mini(lbud - 2, 3)
					c.data.attack = lbud - 1 - mini(lbud - 2, 3)
					c._refresh()
				hand._on_confirm_pressed()
			await get_tree().create_timer(0.04).timeout
		# Selecteer de eerste kaart zodat je selectie + pion-highlights ziet.
		game._on_link_card_picked(0)
		if "uncouple" in args:
			# Koppel een paar eigen pionnen (krijgen archetype-look), trigger dan
			# de ontkoppel-cascade en schiet tijdens de terug-poffen.
			var linked := 0
			for pid in game._pawn_views:
				var pw2 = GameSession.state.pawns.get(pid)
				if pw2 != null and pw2.owner_id == 1 and not pw2.is_eliminated and pw2.linked_card_id == -1:
					game._on_link_card_picked(0)
					game._on_link_pawn_clicked(pid)
					linked += 1
					if linked >= 6:
						break
			await get_tree().create_timer(0.6).timeout
			game._uncouple_cascade()
			await get_tree().create_timer(0.12).timeout
			print("[LINK] ontkoppel-cascade getriggerd")
			out = "res://_shot_link.png"
		if "puff" in args:
			# Koppel de kaart aan een eigen ongekoppelde pion en schiet tijdens
			# de rook-pof (model-wissel base -> archetype).
			var target_id := -1
			for pid in game._pawn_views:
				var pw = GameSession.state.pawns.get(pid)
				if pw != null and pw.owner_id == 1 and not pw.is_eliminated and pw.linked_card_id == -1:
					target_id = pid
					break
			if target_id >= 0:
				game._on_link_pawn_clicked(target_id)
			await get_tree().create_timer(0.13).timeout
		else:
			await get_tree().create_timer(0.4).timeout
		print("[LINK] fase=%s beurt=%d" % [Phase.to_string_phase(GameSession.state.phase), GameSession.state.current_player])
		out = "res://_shot_link.png"
	elif "lobbycheck" in args:
		# F4.3i — de lobby van game.gd tegen de ECHTE backend: A maakt via de
		# lobby-code een match, B (een tweede client) doet mee, A's wachtscherm
		# ziet dat en start de partij; beide kiezen blind, A stelt op.
		# Gebruik: -- lobbycheck [http://127.0.0.1:8787]   (server: npm run dev)
		var li := args.find("lobbycheck")
		var l_url: String = String(args[li + 1]) if args.size() > li + 1 else "http://127.0.0.1:8787"
		var l_ok: bool = await _lobbycheck(game, l_url)
		get_tree().quit(0 if l_ok else 1)
		return
	elif "nettest" in args:
		# F4.3h — twee gast-accounts tegen de ECHTE backend: login, versiecheck,
		# match maken en joinen, beide blinde factiekeuzes via RemoteSession +
		# HttpTransport (polling), tot beide clients in PLACEMENT staan.
		# Gebruik: -- nettest [http://127.0.0.1:8787]   (server: npm run dev)
		var ni := args.find("nettest")
		var n_url: String = String(args[ni + 1]) if args.size() > ni + 1 else "http://127.0.0.1:8787"
		var n_ok: bool = await _nettest(game, n_url)
		get_tree().quit(0 if n_ok else 1)
		return
	elif "online" in args and ("play" in args or "vosview" in args):
		# F4.3g — `-- play online [2]` / `-- vosview online [2]`: het spel via de
		# online-weg (RemoteSession op een loopback met een L1-bot), als seat 1 of
		# seat 2 (bord gedraaid). Speelt tot de actiefase; vosview eist bovendien
		# dat gedekte pionnen '?' tonen (bot = Krokodil).
		var o_seat: int = 2 if "2" in args else 1
		var vos: bool = "vosview" in args
		var o_lb := LoopbackTransport.new(game._potje_regels())
		o_lb.zet_bot(Constants.opponent(o_seat), AgentL1.new(), 4242, Constants.Doctrine.VOS if vos else -1)
		o_lb.start()
		var o_sessie := RemoteSession.new(o_lb.voor_seat(o_seat), o_seat)
		game._start_online(o_sessie)
		await get_tree().create_timer(0.3).timeout
		var o_stappen := 0
		while o_lb.state.phase != Phase.Type.ACTION and o_lb.state.phase != Phase.Type.GAME_OVER and o_stappen < 400:
			o_stappen += 1
			_online_drijf_mens(game, o_lb, o_seat)
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(0.5).timeout
		await get_tree().process_frame
		var o_fouten := 0
		var levend := 0
		for pawn in o_lb.state.pawns.values():
			if not pawn.is_eliminated:
				levend += 1
		if o_lb.state.phase != Phase.Type.ACTION:
			o_fouten += 1
			print("[ONLINE] FOUT: geen actiefase bereikt (%s)" % Phase.to_string_phase(o_lb.state.phase))
		if game._pawn_views.size() != levend:
			o_fouten += 1
			print("[ONLINE] FOUT: %d pionnen op het bord, %d in de partij" % [game._pawn_views.size(), levend])
		if game._human_id != o_seat or game._ai != null:
			o_fouten += 1
			print("[ONLINE] FOUT: mens is %d (verwacht %d), bot in game.gd: %s" % [game._human_id, o_seat, str(game._ai != null)])
		if vos:
			var gedekt := 0
			game._update_health_bars()
			for pawn in game.session.state.pawns.values():
				var entry = game._hp_bars.get(pawn.id, null)
				if entry == null or not entry.has("qlabel"):
					continue
				var hoort: bool = game.session.pion_gedekt(pawn.id)
				if hoort:
					gedekt += 1
					if not entry.qlabel.visible:
						o_fouten += 1
						print("[ONLINE] FOUT: gedekte pion %d toont geen '?'" % pawn.id)
				elif entry.qlabel.visible and pawn.owner_id == o_seat:
					o_fouten += 1
					print("[ONLINE] FOUT: eigen pion %d toont '?'" % pawn.id)
			if gedekt == 0:
				o_fouten += 1
				print("[ONLINE] FOUT: geen enkele gedekte pion om te controleren")
			print("[ONLINE] vosview: gedekte pionnen gecheckt=%d" % gedekt)
		print("[ONLINE] %s seat=%d fase=%s stappen=%d camera=%s" % ["PASS" if o_fouten == 0 else "FAIL", o_seat,
			Phase.to_string_phase(o_lb.state.phase), o_stappen, str(game._camera.global_position)])
		var otex := get_viewport().get_texture()
		if otex != null and otex.get_image() != null:
			otex.get_image().save_png("res://_shot_play_online.png")
		get_tree().quit(0 if o_fouten == 0 else 1)
		return
	elif "bewonercheck" in args:
		# 8 september: de poppetjes in assets/models/bewoners/ (Bewoner). Per
		# bewoner: laadt hij, welke factie, hoe hoog, welke clips zijn idle en
		# welke actie; dan een actie afspelen en kijken of hij daarna weer in
		# idle staat. `-- bewonercheck <naam>` voor een enkele. Exit 1 bij een
		# fout; een bewoner zonder actie-clip is een waarschuwing, geen fout.
		var bw_i := args.find("bewonercheck")
		var bw_wie: String = String(args[bw_i + 1]) if args.size() > bw_i + 1 else ""
		# derde argument: zoveel seconden eerst idle laten staan (de idle-clips
		# wisselen om en om; dat pad zit anders niet in de check)
		var bw_idle_s: float = float(args[bw_i + 2]) if args.size() > bw_i + 2 else 0.0
		var bw_namen: Array = [bw_wie] if bw_wie != "" else Bewoner.alle_namen()
		var bw_fouten := 0
		if bw_namen.is_empty():
			print("[BEWONER] geen bewoners in assets/models/bewoners/ (zet er een <naam>.glb of <naam>.json neer)")
		for bw_naam in bw_namen:
			var bw := Bewoner.new()
			add_child(bw)
			if not bw.laad(String(bw_naam)):
				print("[BEWONER] FOUT: %s laadt niet (geen glb gevonden?)" % bw_naam)
				bw_fouten += 1
				bw.queue_free()
				continue
			var bw_fac: String = Constants.doctrine_display_name(bw.factie) if bw.factie >= 0 else "iedereen"
			print("[BEWONER] %s: factie=%s hoogte=%.2f idle=%s acties=%s geluid=%s" % [
				bw_naam, bw_fac, bw.hoogte, str(bw.idles()), str(bw.acties()), str(bw.manifest.get("geluid", []))])
			if bw.idles().is_empty():
				print("[BEWONER] FOUT: %s heeft geen idle-clip" % bw_naam)
				bw_fouten += 1
			# eigen kopie van de clips? (een pion van hetzelfde model hernoemt
			# anders de gedeelde bibliotheek onder hem vandaan: segfault)
			var bw_model := String(bw.manifest.get("model", bw_naam))
			var bw_pad := Bestandsindex.vind(Bewoner.BEWONERS_DIR, bw_model + ".glb")
			if bw_pad == "":
				bw_pad = Bestandsindex.vind(Bewoner.MODELS_DIR, bw_model + ".glb")
			if bw_pad != "":
				var bw_raw: Node = (load(bw_pad) as PackedScene).instantiate()
				add_child(bw_raw)
				var bw_ap: AnimationPlayer = Bewoner._zoek_anim(bw_raw)
				if bw.deelt_clips_met(bw_ap):
					print("[BEWONER] FOUT: %s deelt zijn clips nog met andere instanties van %s" % [bw_naam, bw_model])
					bw_fouten += 1
				else:
					print("[BEWONER] %s: eigen kopie van de clips (los van %s)" % [bw_naam, bw_model])
				bw_raw.queue_free()
			if bw_idle_s > 0.0:
				await get_tree().create_timer(bw_idle_s).timeout
				if not bw.speelt_idle():
					print("[BEWONER] FOUT: %s staat na %.0f s idle niet meer in een idle-clip" % [bw_naam, bw_idle_s])
					bw_fouten += 1
				else:
					print("[BEWONER] %s: %.0f s idle gestaan, speelt %s" % [bw_naam, bw_idle_s, bw._anim.current_animation])
			if bw.acties().is_empty():
				print("[BEWONER] LET OP: %s heeft geen actie-clip, een klik geeft een huppeltje" % bw_naam)
			else:
				if not bw.doe_actie():
					print("[BEWONER] FOUT: %s speelt zijn actie niet" % bw_naam)
					bw_fouten += 1
				var bw_t := 0.0
				while bw.bezig and bw_t < 25.0:
					await get_tree().create_timer(0.1).timeout
					bw_t += 0.1
				if bw.bezig:
					print("[BEWONER] FOUT: %s komt na 25 s niet terug uit zijn actie" % bw_naam)
					bw_fouten += 1
				elif not bw.speelt_idle():
					print("[BEWONER] FOUT: %s staat na zijn actie niet in idle" % bw_naam)
					bw_fouten += 1
				else:
					print("[BEWONER] %s: actie gespeeld in %.1f s, weer idle" % [bw_naam, bw_t])
			bw.queue_free()
		print("[BEWONER] " + ("PASS" if bw_fouten == 0 else "FAIL (%d fouten)" % bw_fouten))
		get_tree().quit(0 if bw_fouten == 0 else 1)
		return
	elif "propshot" in args:
		# 14 september: een prop uit assets/models/props/ op de foto met het
		# licht van het spel, om een levering (Tripo of Blender) te beoordelen
		# zoals de speler hem ziet: `-- propshot axe [red|blue]`. Met venster
		# `_shot_prop_<naam>.png` (schuin van voren, de kant die naar de
		# speler wijst) en `_shot_prop_<naam>_achter.png`; headless meldt hij
		# alleen maat, meshes en driehoeken.
		await get_tree().create_timer(1.0).timeout
		var pj := args.find("propshot")
		var p_naam: String = String(args[pj + 1]) if pj + 1 < args.size() else "axe"
		var p_team := ""
		if pj + 2 < args.size() and String(args[pj + 2]) in ["red", "blue"]:
			p_team = String(args[pj + 2])
		var p_bestand := "prop_%s%s.glb" % [p_naam, ("_" + p_team) if p_team != "" else ""]
		var p_pad := Bestandsindex.vind(Omgeving.PROPS_DIR, p_bestand)
		if p_pad == "" or not ResourceLoader.exists(p_pad):
			print("[PROPSHOT] FOUT: %s niet gevonden onder %s" % [p_bestand, Omgeving.PROPS_DIR])
			get_tree().quit(1)
			return
		var p_scene: PackedScene = load(p_pad)
		var p_inst: Node3D = p_scene.instantiate() as Node3D
		if p_inst == null:
			print("[PROPSHOT] FOUT: %s laadt niet als Node3D" % p_bestand)
			get_tree().quit(1)
			return
		# hoog boven het bord, weg van het diorama, in het gewone licht
		var p_root := Node3D.new()
		p_root.position = Vector3(5.0, 12.0, 5.0)
		add_child(p_root)
		p_root.add_child(p_inst)
		await get_tree().process_frame
		await get_tree().process_frame
		var p_doos := AABB()
		var p_eerste := true
		var p_tris := 0
		var p_meshes := 0
		for mi in p_inst.find_children("*", "MeshInstance3D", true, false):
			var m: Mesh = (mi as MeshInstance3D).mesh
			if m == null:
				continue
			p_meshes += 1
			var lokaal: AABB = (mi as MeshInstance3D).get_aabb()
			var xf: Transform3D = p_root.global_transform.affine_inverse() * (mi as Node3D).global_transform
			var wereld: AABB = xf * lokaal
			p_doos = wereld if p_eerste else p_doos.merge(wereld)
			p_eerste = false
			for si in range(m.get_surface_count()):
				var arr: Array = m.surface_get_arrays(si)
				var idx = arr[Mesh.ARRAY_INDEX]
				if idx != null and idx.size() > 0:
					p_tris += idx.size() / 3
				elif arr[Mesh.ARRAY_VERTEX] != null:
					p_tris += arr[Mesh.ARRAY_VERTEX].size() / 3
		print("[PROPSHOT] %s: doos %.2f x %.2f x %.2f (b x h x d), %d mesh(es), %d driehoeken" % [
			p_bestand, p_doos.size.x, p_doos.size.y, p_doos.size.z, p_meshes, p_tris])
		var p_tex := get_viewport().get_texture()
		if p_tex != null and p_tex.get_image() != null and p_meshes > 0:
			game._overlay.hide()
			game._card_hand.visible = false
			var p_ui := game.get_node_or_null("UI")
			if p_ui != null:
				p_ui.visible = false
			var p_mid: Vector3 = p_root.position + p_doos.get_center()
			var p_afstand: float = maxf(p_doos.size.x, maxf(p_doos.size.y, p_doos.size.z)) * 1.9 + 0.2
			var p_cam := Camera3D.new()
			add_child(p_cam)
			p_cam.fov = 40.0
			p_cam.current = true
			for p_hoek in [["", Vector3(0.45, 0.35, 1.0)], ["_achter", Vector3(-0.7, 0.4, -0.75)]]:
				p_cam.position = p_mid + (p_hoek[1] as Vector3).normalized() * p_afstand
				p_cam.look_at(p_mid, Vector3.UP)
				await get_tree().create_timer(0.5).timeout
				var p_img: Image = p_tex.get_image()
				if p_img != null:
					var p_uit := "res://_shot_prop_%s%s.png" % [p_naam, p_hoek[0]]
					p_img.save_png(p_uit)
					print("[PROPSHOT] screenshot -> %s" % p_uit.trim_prefix("res://"))
		print("[PROPSHOT] %s" % ("PASS" if p_meshes > 0 else "FAIL"))
		get_tree().quit(0 if p_meshes > 0 else 1)
		return
	elif "dioramashots" in args:
		# 11 september: alle diorama's een voor een op de foto, in het menu
		# (`_shot_diorama_<nr>.png`), om ze naast elkaar te bekijken. Alleen
		# met venster zinvol; headless telt hij alleen de props.
		await get_tree().create_timer(1.0).timeout
		var ds: Node = game._omgeving
		if ds == null:
			print("[DIORAMA] FOUT: geen omgeving")
			get_tree().quit(1)
			return
		for di in range(1, Omgeving.aantal_dioramas() + 1):
			ds.zet_diorama(di)
			await get_tree().create_timer(1.2).timeout
			var dtex := get_viewport().get_texture()
			if dtex != null and dtex.get_image() != null:
				dtex.get_image().save_png("res://_shot_diorama_%d.png" % di)
			# kosten: driehoeken en meshes (= draw calls) van alles onder Props
			var d_tris := 0
			var d_meshes := 0
			for mi in (ds._props_root as Node).find_children("*", "MeshInstance3D", true, false):
				var m: Mesh = (mi as MeshInstance3D).mesh
				if m == null:
					continue
				d_meshes += 1
				for si in range(m.get_surface_count()):
					var arr: Array = m.surface_get_arrays(si)
					var idx = arr[Mesh.ARRAY_INDEX]
					if idx != null and idx.size() > 0:
						d_tris += idx.size() / 3
					elif arr[Mesh.ARRAY_VERTEX] != null:
						d_tris += arr[Mesh.ARRAY_VERTEX].size() / 3
			print("[DIORAMA] %d %s: %d props, %d meshes, %d driehoeken" % [di, ds.diorama_naam(), ds._props.size(), d_meshes, d_tris])
		print("[DIORAMA] klaar")
		get_tree().quit(0)
		return
	elif "spelcheck" in args:
		# 12 september: de vijf mini-games in het diorama (scripts/game/
		# spelletjes.gd). Per spel: het diorama met die prop, vinger erop, na
		# de hold-drempel richten, richting en kracht vastzetten, loslaten en
		# de uitkomst tellen; vissen tikt als de dobber duikt, de cadans tikt
		# acht keer op de maat. Script-fouten vangt de grep op SCRIPT ERROR.
		await get_tree().create_timer(1.2).timeout
		var sp: Node = game._omgeving
		var sp_cam: Camera3D = game._camera
		var sp_fouten := 0
		if sp == null:
			print("[SPEL] FOUT: geen omgeving")
			get_tree().quit(1)
			return
		# [soort, diorama, minimale score]
		# (16 september: hooguit twee spellen per diorama, de cadans staat sindsdien in Bosrand (7) en niet meer in Weidekamp)
		var sp_doelen: Array = [["kegelen", 1, 3], ["keilen", 1, 1], ["kanon", 4, 1], ["vissen", 6, 1], ["cadans", 7, 8]]
		for doel in sp_doelen:
			var soort := String(doel[0])
			sp.zet_diorama(int(doel[1]))
			await get_tree().process_frame
			var p: Dictionary = {}
			for q in sp._props:
				if String(q.get("spel", "")) == soort:
					p = q
					break
			if p.is_empty():
				print("[SPEL] FOUT: geen %s-prop in diorama %d" % [soort, int(doel[1])])
				sp_fouten += 1
				continue
			var n: Node3D = p.node
			var scherm: Vector2 = sp_cam.unproject_position(n.to_global(p.get("midden", Vector3(0.0, float(p.hoogte) * 0.5, 0.0))))
			if not sp.klik(scherm):
				print("[SPEL] FOUT: %s (%s) niet raak" % [soort, n.name])
				sp_fouten += 1
				continue
			await get_tree().create_timer(0.35).timeout   # voorbij de hold-drempel
			if soort == "cadans":
				if not p.has("spel_staat"):
					print("[SPEL] FOUT: de cadans is niet gestart na het vasthouden")
					sp_fouten += 1
					continue
				var getikt := 0
				var wacht := 0.0
				while p.has("spel_staat") and wacht < 14.0:
					var st: Dictionary = p.spel_staat
					if String(st.fase) == "spel" and not bool(st.getikt_volgende) and float(st.volgende) - sp._tijd < 0.04 and getikt < 8:
						sp.klik(scherm)
						getikt += 1
					await get_tree().process_frame
					wacht += get_process_delta_time()
				print("[SPEL] cadans: %d keer getikt, %d in de maat (tempo nu %.2f s)" % [getikt, int(p.get("spel_score", -1)), float(p.get("tempo", 0.0))])
				if int(p.get("spel_score", -1)) < int(doel[2]):
					print("[SPEL] FOUT: cadans %d in de maat, verwacht %d" % [int(p.get("spel_score", -1)), int(doel[2])])
					sp_fouten += 1
				continue
			if not sp._spel.richt_bezig():
				print("[SPEL] FOUT: %s richt niet na het vasthouden" % soort)
				sp_fouten += 1
				continue
			var kracht := 0.5
			if soort == "kegelen":
				kracht = 1.0
			elif soort == "kanon":
				var d2: Dictionary = p.get("doel", {})
				if d2.is_empty():
					print("[SPEL] FOUT: het kanon heeft geen kruitvaten als doel")
					sp_fouten += 1
					continue
				var afst: float = (d2.node as Node3D).position.distance_to(n.position)
				kracht = clampf((afst - 1.6) / 5.4, 0.0, 1.0)
			# drie tikken (16 september): tik 1 heeft het richten gestart; de
			# richting-fase moet zwaaien (behalve kanon en vissen, die beginnen
			# met de meter), tik 2 zet de richting vast en start de meter
			var sp_fase: String = sp._spel.richt_fase()
			var sp_verwacht: String = "kracht" if soort == "vissen" else "richting"
			if sp_fase != sp_verwacht:
				print("[SPEL] FOUT: %s begint in fase '%s', verwacht '%s'" % [soort, sp_fase, sp_verwacht])
				sp_fouten += 1
			if sp_fase == "richting":
				sp.klik(scherm)   # tik 2: richting vast
				await get_tree().process_frame
				if sp._spel.richt_fase() != "kracht":
					print("[SPEL] FOUT: %s: na tik 2 geen krachtmeter (fase '%s')" % [soort, sp._spel.richt_fase()])
					sp_fouten += 1
			sp._spel.zet_richt(0.0, kracht)
			if soort == "kegelen":
				# met venster: de pijl van het richten op de plaat
				await get_tree().process_frame
				var rt := get_viewport().get_texture()
				if rt != null and rt.get_image() != null:
					rt.get_image().save_png("res://_shot_spel_richt.png")
			sp.laat_los(scherm)
			# tik 3: kracht vast, werpen (een tik naast de prop telt ook)
			sp.klik(scherm + Vector2(400.0, 300.0))
			await get_tree().process_frame
			if sp._spel.richt_bezig():
				print("[SPEL] FOUT: %s: na tik 3 loopt het richten nog" % soort)
				sp_fouten += 1
			if soort == "vissen":
				# wachten tot de dobber duikt, dan tikken
				var w2 := 0.0
				while w2 < 9.0 and p.has("spel_staat") and String((p.spel_staat as Dictionary).get("fase", "")) != "dip":
					await get_tree().process_frame
					w2 += get_process_delta_time()
				if not p.has("spel_staat"):
					print("[SPEL] FOUT: de dobber is nooit uitgeworpen of al terug")
					sp_fouten += 1
					continue
				sp.klik(scherm)
			var w3 := 0.0
			while bool(p.bezig) and w3 < 12.0:
				await get_tree().process_frame
				w3 += get_process_delta_time()
			var score: int = int(p.get("spel_score", -1))
			print("[SPEL] %s: score %d (kracht %.2f, klaar na %.1f s)" % [soort, score, kracht, w3])
			if bool(p.bezig):
				print("[SPEL] FOUT: %s is na 12 s nog bezig" % soort)
				sp_fouten += 1
			if score < int(doel[2]):
				print("[SPEL] FOUT: %s score %d, verwacht minstens %d" % [soort, score, int(doel[2])])
				sp_fouten += 1
		print("[SPEL] " + ("PASS" if sp_fouten == 0 else "FAIL (%d fouten)" % sp_fouten))
		var sp_tex := get_viewport().get_texture()
		if sp_tex != null and sp_tex.get_image() != null:
			sp_tex.get_image().save_png("res://_shot_spel.png")
		get_tree().quit(0 if sp_fouten == 0 else 1)
		return
	elif "dragercheck" in args:
		# 12 september (Max: "soms spawnen er weer soldaten met een trom of een
		# vlag, dat kan niet, als ze dood zijn zijn ze dood"). Opstelling met
		# echte dragers (C15), dan sneuvelen alle dragers van speler 1 in de
		# staat en komt er een verse spawn bij: geen enkele pion zonder echte
		# rol mag daarna een vaandel of trom tonen, en de dragers van speler 2
		# houden de hunne.
		var dc_fouten := 0
		var dc_hand: CardHand = game.get_node("UI/CardHand")
		var dc_steps := 0
		while not Phase.is_define(GameSession.state.phase) and dc_steps < 40:
			dc_steps += 1
			var dst: GameState = GameSession.state
			if dst.phase == Phase.Type.PRE_GAME:
				game._start_match(1)
			elif dst.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(dst.phase):
				game._continue_after_reveal()
			await get_tree().create_timer(0.05).timeout
		var dc_state: GameState = GameSession.state
		if not dc_state.campaign_actief_rollen():
			print("[DRAGER] FOUT: dit potje draagt geen echte rollen (campagne-blok ontbreekt)")
			get_tree().quit(1)
			return
		var tel_rol := func(owner: int, levend: bool) -> int:
			var n := 0
			for p in GameSession.state.pawns.values():
				if p.owner_id == owner and String(p.rol) != "" and (not levend or not p.is_eliminated):
					n += 1
			return n
		var dc_voor: int = tel_rol.call(1, true)
		if dc_voor == 0:
			print("[DRAGER] FOUT: speler 1 heeft geen dragers na de opstelling")
			dc_fouten += 1
		# de weergave VOOR het sneuvelen: de echte dragers tonen hun prop
		game._refresh_all()
		var dc_toont := func(owner: int) -> Dictionary:
			var uit := {"echt": 0, "cosmetisch": 0}
			for pid in game._pawn_views:
				var pv: PawnView = game._pawn_views[pid]
				var p: Pawn = GameSession.state.pawns.get(pid)
				if p == null or p.owner_id != owner or p.is_eliminated:
					continue
				var toont: String = String(pv._rol)
				if toont != "flag" and toont != "drum":
					continue
				if String(p.rol) == toont:
					uit["echt"] += 1
				else:
					uit["cosmetisch"] += 1
			return uit
		var dc_t0: Dictionary = dc_toont.call(1)
		print("[DRAGER] voor: speler 1 toont %d echte dragers, %d cosmetische" % [dc_t0.echt, dc_t0.cosmetisch])
		if int(dc_t0.cosmetisch) > 0:
			print("[DRAGER] FOUT: cosmetische vaandels/trommels terwijl het potje echte rollen draagt")
			dc_fouten += 1
		# alle dragers van speler 1 sneuvelen (staat), en er komt een verse spawn
		for p in GameSession.state.pawns.values():
			if p.owner_id == 1 and String(p.rol) != "" and not p.is_eliminated:
				GameSession.state.board[p.position.y][p.position.x] = Constants.EMPTY_TILE
				p.is_eliminated = true
		var dc_vrij: Array = Validator.vrije_spawn_vakken(GameSession.state, 1)
		var dc_spawn: Pawn = null
		if not dc_vrij.is_empty():
			dc_spawn = GameSession.state._spawn_pawn(1, dc_vrij[0], Constants.UnitType.INFANTRY)
		game._refresh_all()
		await get_tree().process_frame
		game._refresh_all()
		var dc_t1: Dictionary = dc_toont.call(1)
		var dc_t2: Dictionary = dc_toont.call(2)
		print("[DRAGER] na: speler 1 toont %d echte, %d cosmetische; speler 2 %d echte, %d cosmetische; figurant_rollen=%d" % [
			dc_t1.echt, dc_t1.cosmetisch, dc_t2.echt, dc_t2.cosmetisch, game._figurant_rollen.size()])
		if int(dc_t1.cosmetisch) > 0 or int(dc_t1.echt) > 0:
			print("[DRAGER] FOUT: speler 1 toont nog een vaandel of trom terwijl al zijn dragers dood zijn")
			dc_fouten += 1
		if int(dc_t2.echt) != tel_rol.call(2, true):
			print("[DRAGER] FOUT: speler 2 toont %d dragers, in de staat staan er %d" % [dc_t2.echt, tel_rol.call(2, true)])
			dc_fouten += 1
		if dc_spawn != null and game._pawn_views.has(dc_spawn.id):
			var spv: PawnView = game._pawn_views[dc_spawn.id]
			if String(spv._rol) != "" or String(spv.rol_vast) != "":
				print("[DRAGER] FOUT: de verse spawn (pion %d) toont rol '%s'/'%s'" % [dc_spawn.id, spv._rol, spv.rol_vast])
				dc_fouten += 1
			else:
				print("[DRAGER] verse spawn (pion %d) is een gewone soldaat" % dc_spawn.id)
		elif dc_spawn == null:
			print("[DRAGER] geen vrij spawnvak, spawn-deel overgeslagen")
		print("[DRAGER] " + ("PASS" if dc_fouten == 0 else "FAIL (%d fouten)" % dc_fouten))
		get_tree().quit(0 if dc_fouten == 0 else 1)
		return
	elif "beurtlicht" in args:
		# 17 september (Max: "een highlight als het de laatste of bijna laatste
		# pawns zijn, dat je ziet welke je nog kan bewegen"). Speelt tot je eigen
		# actiebeurt en meet: de straal staat precies op de pionnen die nog
		# kunnen (Rules.can_pawn_act) zodra dat er hooguit `beurt_licht_vanaf`
		# zijn; met de drempel op 1 pas bij de laatste; met de sterkte op 0 nooit.
		# Met venster een screenshot met de stralen aan.
		var bl_fouten := 0
		var bl_hand: CardHand = game.get_node("UI/CardHand")
		var bl_steps := 0
		while not (GameSession.state.phase == Phase.Type.ACTION and GameSession.state.current_player == 1) and bl_steps < 400:
			bl_steps += 1
			var bst: GameState = GameSession.state
			if bst.phase == Phase.Type.PRE_GAME:
				game._start_match(1)
			elif bst.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(bst.phase):
				game._continue_after_reveal()
			elif Phase.is_define(bst.phase) and bst.cards_defined[1].size() == 0 and not bl_hand.visible:
				if game._overlay.visible:
					game._on_cp_choice(0)
			elif Phase.is_define(bst.phase) and bst.cards_defined[1].size() == 0:
				var bbud: int = int(bst.doctrine_data_of(1).budget)
				for c in bl_hand.get_card_views():
					c.data.hp = 1
					c.data.stamina = mini(bbud - 2, 3)
					c.data.attack = bbud - 1 - mini(bbud - 2, 3)
					c._refresh()
				bl_hand._on_confirm_pressed()
			elif Phase.is_linking(bst.phase) and bst.current_player == 1:
				game._on_phase_timeout()   # auto-koppelen
			await get_tree().create_timer(0.05).timeout
		var bl_st: GameState = GameSession.state
		if not (bl_st.phase == Phase.Type.ACTION and bl_st.current_player == 1):
			print("[LICHT] FOUT: eigen actiebeurt niet bereikt (fase %s, beurt %d)" % [Phase.to_string_phase(bl_st.phase), bl_st.current_player])
			get_tree().quit(1)
			return
		await get_tree().process_frame
		game._refresh_all()
		var bl_uit: Array = _bl_meet(game)
		print("[LICHT] start actiebeurt: %d pionnen kunnen nog, %d stralen aan, drempel %d" % [bl_uit[0], bl_uit[1], int(round(PawnView.fx("beurt_licht_vanaf", 3.0)))])
		if bl_uit[2] > 0:
			print("[LICHT] FOUT: %d pion(nen) met een straal die niet klopt" % bl_uit[2])
			bl_fouten += 1
		# Zetten doen (beurtelings: de bot speelt tussendoor zelf) tot er hooguit
		# `drempel` eigen pionnen over zijn die nog kunnen, in de eigen beurt.
		var bl_drempel: int = int(round(PawnView.fx("beurt_licht_vanaf", 3.0)))
		var bl_ok: bool = await _bl_speel_tot(game, bl_drempel, 60.0)
		if bl_ok:
			bl_uit = _bl_meet(game)
			print("[LICHT] onder de drempel: %d kunnen nog, %d stralen, %d fout (%s)" % [
				bl_uit[0], bl_uit[1], bl_uit[2], "PASS" if bl_uit[1] == bl_uit[0] and bl_uit[2] == 0 and bl_uit[0] > 0 else "FAIL"])
			if bl_uit[1] != bl_uit[0] or bl_uit[2] > 0 or bl_uit[0] == 0:
				print("[LICHT] FOUT: onder de drempel hoort precies elke pion die nog kan een straal te hebben")
				bl_fouten += 1
			var bl_tex := get_viewport().get_texture()
			if bl_tex != null and bl_tex.get_image() != null:
				game._overlay.hide()
				await get_tree().create_timer(0.6).timeout
				var bl_img: Image = bl_tex.get_image()
				if bl_img != null:
					bl_img.save_png("res://_shot_beurtlicht.png")
					print("[LICHT] screenshot -> _shot_beurtlicht.png")
		else:
			print("[LICHT] FOUT: kwam niet in een eigen beurt met hooguit %d pionnen die nog kunnen" % bl_drempel)
			bl_fouten += 1
		# Drempel 1: alleen de laatste pion krijgt de straal.
		PawnView.set_fx("beurt_licht_vanaf", 1.0)
		game._refresh_all()
		bl_uit = _bl_meet(game)
		var bl_verwacht: int = bl_uit[0] if bl_uit[0] <= 1 else 0
		print("[LICHT] drempel 1: %d kunnen nog, %d stralen (verwacht %d)" % [bl_uit[0], bl_uit[1], bl_verwacht])
		if bl_uit[1] != bl_verwacht:
			print("[LICHT] FOUT: met drempel 1 hoort alleen de laatste pion een straal te krijgen")
			bl_fouten += 1
		if await _bl_speel_tot(game, 1, 60.0):
			bl_uit = _bl_meet(game)
			print("[LICHT] de laatste: %d kan nog, %d straal, %d fout (%s)" % [
				bl_uit[0], bl_uit[1], bl_uit[2], "PASS" if bl_uit[1] == 1 and bl_uit[2] == 0 else "FAIL"])
			if bl_uit[1] != 1 or bl_uit[2] > 0:
				print("[LICHT] FOUT: de laatste pion die nog kan heeft geen straal (of een andere wel)")
				bl_fouten += 1
		else:
			print("[LICHT] (geen eigen beurt met precies een pion over; laatste-pion-meting overgeslagen)")
		# Sterkte 0: nooit een straal.
		PawnView.set_fx("beurt_licht", 0.0)
		PawnView.set_fx("beurt_licht_vanaf", 30.0)
		game._refresh_all()
		bl_uit = _bl_meet(game)
		print("[LICHT] sterkte 0: %d stralen (verwacht 0)" % bl_uit[1])
		if bl_uit[1] != 0:
			print("[LICHT] FOUT: met sterkte 0 hoort er geen straal te staan")
			bl_fouten += 1
		print("[LICHT] %s: %d fout(en)" % ["PASS" if bl_fouten == 0 else "FAIL", bl_fouten])
		get_tree().quit(0 if bl_fouten == 0 else 1)
		return
	elif "sleepcheck" in args:
		# 16 september (Max: "een drag-en-drop-link die highlight op welk
		# poppetje je hem dropt, met een gebogen pijl"): tot de koppel-fase zoals
		# koppelcheck, dan kaart 0 met echte muis-events van de hand naar een
		# eigen pion slepen: onderweg moet de pijl staan en boven de pion "raak"
		# zijn, na het loslaten moet de pion die kaart dragen. Daarna kaart 1 naar
		# een leeg vak: geen koppeling, kaart blijft gekozen. Met venster een
		# screenshot midden in de sleep.
		var sc_fouten := 0
		if "muis" in args:
			game._human_doctrine = Constants.Doctrine.MUIS  # vijf kaarten in de koppel-waaier
		var sc_hand: CardHand = game.get_node("UI/CardHand")
		var sc_steps := 0
		while not Phase.is_linking(GameSession.state.phase) and sc_steps < 80:
			sc_steps += 1
			var sst: GameState = GameSession.state
			if sst.phase == Phase.Type.PRE_GAME:
				game._start_match(1)
			elif sst.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(sst.phase):
				game._continue_after_reveal()
			elif Phase.is_define(sst.phase) and sst.cards_defined[1].size() == 0 and not sc_hand.visible:
				if game._overlay.visible:
					game._on_cp_choice(0)
			elif Phase.is_define(sst.phase) and sst.cards_defined[1].size() == 0:
				var sbud: int = int(sst.doctrine_data_of(1).budget)
				for c in sc_hand.get_card_views():
					c.data.hp = 1
					c.data.stamina = mini(sbud - 2, 3)
					c.data.attack = sbud - 1 - mini(sbud - 2, 3)
					c._refresh()
				sc_hand._on_confirm_pressed()
			await get_tree().create_timer(0.05).timeout
		if not Phase.is_linking(GameSession.state.phase):
			print("[SLEEP] FOUT: koppel-fase niet bereikt (fase %s)" % Phase.to_string_phase(GameSession.state.phase))
			get_tree().quit(1)
			return
		if not await _sc_wacht_op_beurt():
			print("[SLEEP] FOUT: de mens komt niet aan de beurt in de koppel-fase")
			get_tree().quit(1)
			return
		await get_tree().create_timer(0.3).timeout
		var sc_views: Array = sc_hand.get_card_views()
		var sc_pion: int = _kc_vrije_pion()
		var sc_start: Vector2 = (sc_views[0] as CardView).get_global_transform() * (UiAssets.KAART_MAAT * 0.5)
		var sc_doel: Vector2 = game._pion_schermpunt(sc_pion, 0.3)
		var sc_pijl: KoppelPijl = game._koppel_pijl
		await _sc_muis(sc_start, true)
		await _sc_beweeg(sc_start, sc_doel, 14)
		print("[SLEEP] onderweg: pijl zichtbaar=%s raak=%s (kaart 0 -> pion %d)" % [str(sc_pijl.visible), str(sc_pijl.is_raak()), sc_pion])
		if not sc_pijl.visible or not sc_pijl.is_raak():
			print("[SLEEP] FOUT: de pijl staat niet of is niet raak boven de pion")
			sc_fouten += 1
		if game._selected_link_card_id < 0:
			print("[SLEEP] FOUT: de sleep koos de kaart niet")
			sc_fouten += 1
		var sc_tex := get_viewport().get_texture()
		if sc_tex != null and sc_tex.get_image() != null:
			var sc_img: Image = sc_tex.get_image()
			if sc_img != null:
				sc_img.save_png("res://_shot_sleepcheck.png")
				print("[SLEEP] screenshot -> _shot_sleepcheck.png")
		var sc_kaart0: int = (GameSession.state.cards_revealed[1][0] as Card).id
		var sc_boog_van: Vector2 = sc_pijl._van
		var sc_boog_naar: Vector2 = sc_pijl._naar
		await _sc_muis(sc_doel, false)
		# Halverwege de vlucht: de spookkaart hangt met zijn anker OP de boog
		# van de pijl, de pijl begint bij dat anker, de echte kaart is weg.
		await get_tree().create_timer(0.12).timeout
		var sc_spook: Control = game.get_node("UI").find_child("Spookkaart", false, false)
		if sc_spook == null:
			print("[SLEEP] FOUT: geen spookkaart tijdens de vlucht")
			sc_fouten += 1
		else:
			var anker: Vector2 = sc_spook.position + sc_spook.pivot_offset
			var dichtst := 1.0e9
			for si in 201:
				dichtst = minf(dichtst, anker.distance_to(KoppelPijl.boogpunt(sc_boog_van, sc_boog_naar, float(si) / 200.0)))
			var bron_weg: bool = (sc_views[0] as CardView).modulate.a < 0.05
			print("[SLEEP] vlucht-detail: anker=(%.0f, %.0f) schaal=%.2f pijl_van=(%.0f, %.0f) boog_van=(%.0f, %.0f) boog_naar=(%.0f, %.0f)" % [
				anker.x, anker.y, sc_spook.scale.x, sc_pijl._van.x, sc_pijl._van.y, sc_boog_van.x, sc_boog_van.y, sc_boog_naar.x, sc_boog_naar.y])
			print("[SLEEP] vlucht: anker %.1f px van de boog, pijl zichtbaar=%s begint bij het anker=%s, kaart uit de hand=%s" % [
				dichtst, str(sc_pijl.visible), str(sc_pijl._van.distance_to(anker) < 1.5), str(bron_weg)])
			if dichtst > 4.0 or not sc_pijl.visible or sc_pijl._van.distance_to(anker) >= 1.5 or not bron_weg:
				print("[SLEEP] FOUT: de kaart volgt de pijl niet (of de pijl volgt de kaart niet)")
				sc_fouten += 1
			var sc_vtex := get_viewport().get_texture()
			if sc_vtex != null and sc_vtex.get_image() != null:
				var sc_vimg: Image = sc_vtex.get_image()
				if sc_vimg != null:
					sc_vimg.save_png("res://_shot_sleepvlucht.png")
					print("[SLEEP] screenshot -> _shot_sleepvlucht.png")
		await get_tree().create_timer(0.6).timeout
		if game.get_node("UI").find_child("Spookkaart", false, false) != null:
			print("[SLEEP] FOUT: de spookkaart is na de vlucht niet opgeruimd")
			sc_fouten += 1
		if is_instance_valid(sc_views[0]) and (sc_views[0] as CardView).modulate.a < 0.95:
			print("[SLEEP] FOUT: de kaart kwam na de vlucht niet terug in de hand")
			sc_fouten += 1
		var sc_gekoppeld: int = (GameSession.state.pawns[sc_pion] as Pawn).linked_card_id
		print("[SLEEP] losgelaten: pion %d draagt kaart %d (verwacht %d), pijl weg=%s" % [sc_pion, sc_gekoppeld, sc_kaart0, str(not sc_pijl.visible)])
		if sc_gekoppeld != sc_kaart0:
			print("[SLEEP] FOUT: de pion is niet aan kaart 0 gekoppeld")
			sc_fouten += 1
		if sc_pijl.visible:
			print("[SLEEP] FOUT: de pijl blijft staan na het loslaten")
			sc_fouten += 1
		# Tweede sleep: kaart 1 naar een leeg vak midden op het bord.
		if await _sc_wacht_op_beurt():
			await get_tree().create_timer(0.3).timeout
			var sc_kaart1: int = (GameSession.state.cards_revealed[1][1] as Card).id
			var sc_start1: Vector2 = (sc_views[1] as CardView).get_global_transform() * (UiAssets.KAART_MAAT * 0.5)
			var sc_leeg: Vector2 = game._camera.unproject_position(game._board.to_global(game.tile_position(5, 5) + Vector3(0.0, 0.3, 0.0)))
			await _sc_muis(sc_start1, true)
			await _sc_beweeg(sc_start1, sc_leeg, 14)
			print("[SLEEP] naar een leeg vak: pijl zichtbaar=%s raak=%s" % [str(sc_pijl.visible), str(sc_pijl.is_raak())])
			if not sc_pijl.visible or sc_pijl.is_raak():
				print("[SLEEP] FOUT: boven een leeg vak hoort de pijl te staan zonder raak")
				sc_fouten += 1
			await _sc_muis(sc_leeg, false)
			await get_tree().create_timer(0.3).timeout
			var sc_k1: Card = GameSession.state.cards_revealed[1][1]
			print("[SLEEP] losgelaten naast een pion: kaart 1 gekoppeld=%s gekozen=%s" % [str(sc_k1.is_linked()), str(game._selected_link_card_id == sc_kaart1)])
			if sc_k1.is_linked():
				print("[SLEEP] FOUT: loslaten naast een pion koppelde toch")
				sc_fouten += 1
			if game._selected_link_card_id != sc_kaart1:
				print("[SLEEP] FOUT: de kaart bleef niet gekozen na een mislukte sleep")
				sc_fouten += 1
		else:
			print("[SLEEP] FOUT: geen tweede beurt voor de mens")
			sc_fouten += 1
		print("[SLEEP] %s: %d fout(en)" % ["PASS" if sc_fouten == 0 else "FAIL", sc_fouten])
		get_tree().quit(0 if sc_fouten == 0 else 1)
		return
	elif "koppelcheck" in args:
		# 12 september (Max: "houd mijn kaart geselecteerd ook al is de AI eerst
		# aan de beurt, totdat ik gelinkt heb"). Speelt tot de koppel-fase, geeft
		# de beurt aan de bot door zelf een kaart te koppelen, kiest DAN de
		# volgende kaart terwijl de bot denkt, en bewijst: de keuze staat (een
		# pion-klik doet nog niets), overleeft de beurtwissel met de waaier erbij,
		# en gaat pas weg als de kaart aan een pion hangt.
		var kc_fouten := 0
		var kc_hand: CardHand = game.get_node("UI/CardHand")
		var kc_steps := 0
		while not Phase.is_linking(GameSession.state.phase) and kc_steps < 80:
			kc_steps += 1
			var kst: GameState = GameSession.state
			if kst.phase == Phase.Type.PRE_GAME:
				game._start_match(1)
			elif kst.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(kst.phase):
				game._continue_after_reveal()
			elif Phase.is_define(kst.phase) and kst.cards_defined[1].size() == 0:
				var kbud: int = int(kst.doctrine_data_of(1).budget)
				for c in kc_hand.get_card_views():
					c.data.hp = 1
					c.data.stamina = mini(kbud - 2, 3)
					c.data.attack = kbud - 1 - mini(kbud - 2, 3)
					c._refresh()
				kc_hand._on_confirm_pressed()
			await get_tree().create_timer(0.05).timeout
		if not Phase.is_linking(GameSession.state.phase):
			print("[KOPPEL] FOUT: koppel-fase niet bereikt (fase %s)" % Phase.to_string_phase(GameSession.state.phase))
			get_tree().quit(1)
			return
		await get_tree().process_frame
		# eigen beurt? koppel dan eerst een kaart, zodat de bot aan de beurt komt
		if GameSession.state.current_player == 1:
			game._on_link_card_picked(0)
			game._on_link_pawn_clicked(_kc_vrije_pion())
			await get_tree().process_frame
		var kst2: GameState = GameSession.state
		if not Phase.is_linking(kst2.phase) or kst2.current_player != 2:
			print("[KOPPEL] FOUT: de bot is niet aan de beurt na de eerste koppeling (fase %s, beurt %d)" % [Phase.to_string_phase(kst2.phase), kst2.current_player])
			get_tree().quit(1)
			return
		# de volgende vrije kaart kiezen TERWIJL de bot denkt
		var kc_kaarten: Array = kst2.cards_revealed[1]
		var keuze := -1
		for i in kc_kaarten.size():
			if not (kc_kaarten[i] as Card).is_linked():
				keuze = i
				break
		game._on_link_card_picked(keuze)
		var kaart_id: int = (kc_kaarten[keuze] as Card).id
		if game._selected_link_card_id != kaart_id:
			print("[KOPPEL] FOUT: kaart %d kiezen tijdens de beurt van de bot werd geweigerd" % keuze)
			kc_fouten += 1
		# een pion-klik in de beurt van de bot koppelt NIET en laat de keuze staan
		var kc_pion := _kc_vrije_pion()
		game._on_link_pawn_clicked(kc_pion)
		if (GameSession.state.pawns[kc_pion] as Pawn).linked_card_id != -1:
			print("[KOPPEL] FOUT: pion %d werd gekoppeld terwijl de bot aan de beurt was" % kc_pion)
			kc_fouten += 1
		if game._selected_link_card_id != kaart_id:
			print("[KOPPEL] FOUT: de keuze verdween door een pion-klik in de beurt van de bot")
			kc_fouten += 1
		# wachten tot de bot gekoppeld heeft en de beurt terug is
		var kc_wacht := 0.0
		while GameSession.state.current_player != 1 and Phase.is_linking(GameSession.state.phase) and kc_wacht < 5.0:
			await get_tree().create_timer(0.05).timeout
			kc_wacht += 0.05
		var kst3: GameState = GameSession.state
		if not Phase.is_linking(kst3.phase) or kst3.current_player != 1:
			print("[KOPPEL] FOUT: de beurt kwam niet terug (fase %s, beurt %d)" % [Phase.to_string_phase(kst3.phase), kst3.current_player])
			kc_fouten += 1
		if game._selected_link_card_id != kaart_id:
			print("[KOPPEL] FOUT: de keuze overleefde de beurtwissel niet (%d)" % game._selected_link_card_id)
			kc_fouten += 1
		if kc_hand._selected_index != keuze:
			print("[KOPPEL] FOUT: de waaier toont kaart %d als gekozen, verwacht %d" % [kc_hand._selected_index, keuze])
			kc_fouten += 1
		var kc_views: Array = kc_hand.get_card_views()
		if keuze < kc_views.size() and not (kc_views[keuze] as CardView)._selected:
			print("[KOPPEL] FOUT: de gekozen kaart licht niet op in de waaier")
			kc_fouten += 1
		# nu koppelen: de keuze gaat weg, de pion draagt de kaart
		kc_pion = _kc_vrije_pion()
		game._on_link_pawn_clicked(kc_pion)
		await get_tree().process_frame
		var kc_pk: Pawn = GameSession.state.pawns[kc_pion]
		if kc_pk.linked_card_id != kaart_id:
			print("[KOPPEL] FOUT: pion %d draagt kaart %d, verwacht %d" % [kc_pion, kc_pk.linked_card_id, kaart_id])
			kc_fouten += 1
		if game._selected_link_card_id != -1:
			print("[KOPPEL] FOUT: de keuze bleef staan na het koppelen")
			kc_fouten += 1
		print("[KOPPEL] kaart %d gekozen in de beurt van de bot, bleef staan over de beurtwissel, gekoppeld aan pion %d" % [keuze, kc_pion])
		print("[KOPPEL] " + ("PASS" if kc_fouten == 0 else "FAIL (%d fouten)" % kc_fouten))
		get_tree().quit(0 if kc_fouten == 0 else 1)
		return
	elif "omgevingcheck" in args:
		# 8 september: het diorama om het bord (scripts/game/omgeving.gd).
		# Bewijst dat de Omgeving er staat (grond, wolken, vignet, props), dat
		# elke prop een klik op zijn eigen schermpositie pakt (game.gd vraagt
		# Omgeving.klik VOOR de beurt-check, dus ook terwijl je wacht), dat een
		# klik op het bordmidden GEEN prop raakt, en dat de korte reacties na
		# een paar seconden weer vrij zijn. Met venster ook _shot_omgeving.png.
		await get_tree().create_timer(1.2).timeout
		var og_fouten := 0
		var og: Node = game._omgeving
		if og == null:
			print("[OMGEVING] FOUT: game._omgeving is null")
			og_fouten += 1
		else:
			var og_cam: Camera3D = game._camera
			var og_props: Array = og._props
			print("[OMGEVING] props=%d grond=%s wolken=%s vignet=%s camera=%s" % [
				og_props.size(), og._grond != null, og._wolken != null, og._vignet != null, og_cam.position])
			if og_props.size() < 8:
				print("[OMGEVING] FOUT: maar %d props (verwacht minstens 8)" % og_props.size())
				og_fouten += 1
			# `-- omgevingcheck [nr] blauw` (13 september): het kamp vooraan als het
			# BLAUWE team, zodat ook de rijke props (prop_<naam>_blue.glb) laden
			if "blauw" in args:
				og.zet_facties(og._factie_eigen, og._factie_ander, "blue")
				await get_tree().process_frame
				print("[OMGEVING] kamp vooraan = blauw (de rijke props)")
			# alle twaalf diorama's een keer opbouwen (elk minstens 8 props) en
			# eindigen op het diorama uit het argument (`-- omgevingcheck 5`), anders 1
			var og_i := args.find("omgevingcheck")
			var og_wil: int = 1
			if args.size() > og_i + 1 and String(args[og_i + 1]).is_valid_int():
				og_wil = int(args[og_i + 1])
			for di in range(1, Omgeving.aantal_dioramas() + 1):
				og.zet_diorama(di)
				await get_tree().process_frame
				var dingers: int = Omgeving.dinger_aantal(di)
				print("[OMGEVING] diorama %d %s: %d props, %d tik-dingen" % [di, og.diorama_naam(), og._props.size(), dingers])
				if og._props.size() < 8:
					print("[OMGEVING] FOUT: diorama %d heeft maar %d props" % [di, og._props.size()])
					og_fouten += 1
				if dingers < 3:
					print("[OMGEVING] FOUT: diorama %d heeft maar %d tik-dingen (minstens 3)" % [di, dingers])
					og_fouten += 1
				# welke props komen uit een GELEVERDE glb (12 september, de eerste
				# Tripo-tent): verwerk_prop.py leest deze regel terug als bewijs
				var og_glbs: Dictionary = {}
				for dp in og._props:
					if dp.has("glb"):
						var gk := "%s (%s)" % [String((dp.node as Node3D).name).rstrip("0123456789"), String(dp.glb)]
						og_glbs[gk] = int(og_glbs.get(gk, 0)) + 1
				if not og_glbs.is_empty():
					var og_delen: Array = []
					for gk in og_glbs:
						og_delen.append("%s x%d" % [gk, og_glbs[gk]])
					print("[OMGEVING] diorama %d geleverde glb-props: %s" % [di, ", ".join(og_delen)])
				# elke prop in dit diorama moet op zijn eigen klikpunt raak zijn
				var mis: Array = []
				for dp in og._props:
					var dn: Node3D = dp.node
					var dwp: Vector3 = dn.to_global(dp.get("midden", Vector3(0.0, float(dp.hoogte) * 0.5, 0.0)))
					if not og.klik(og_cam.unproject_position(dwp)):
						mis.append(dn.name)
					og.laat_los(og_cam.unproject_position(dwp))
				if not mis.is_empty():
					print("[OMGEVING] FOUT: diorama %d, niet raak: %s" % [di, ", ".join(mis)])
					og_fouten += 1
			og.zet_diorama(og_wil)
			await get_tree().create_timer(0.5).timeout
			og_props = og._props
			var og_namen: Array = []
			for p in og_props:
				var pn: Node3D = p.node
				var wp: Vector3 = pn.to_global(p.get("midden", Vector3(0.0, float(p.hoogte) * 0.5, 0.0)))
				var sp: Vector2 = og_cam.unproject_position(wp)
				var raak: bool = og.klik(sp)
				og.laat_los(sp)   # een tik is drukken en loslaten: de spel-props reageren pas dan
				og_namen.append("%s@(%d,%d)" % [pn.name, int(sp.x), int(sp.y)])
				if not raak:
					print("[OMGEVING] FOUT: klik op %s (scherm %s) raakt niets" % [pn.name, sp])
					og_fouten += 1
				elif og._spel.richt_bezig():
					# een werp-prop (16 september, drie tikken): tik 1 zet de pijl
					# neer, dat IS de reactie; afbreken voor de volgende prop
					og._spel.breek_af()
				elif not p.bezig:
					print("[OMGEVING] FOUT: %s pakt de klik maar reageert niet" % pn.name)
					og_fouten += 1
			print("[OMGEVING] geklikt: " + ", ".join(og_namen))
			var og_midden: Vector2 = og_cam.unproject_position(game._board.to_global(game.tile_position(5, 5)))
			if og.klik(og_midden):
				print("[OMGEVING] FOUT: een klik op het bordmidden raakt een prop")
				og_fouten += 1
			# bewoners volgen de facties: soldaat_mouse (assets/models/bewoners)
			# staat bij wie Muis speelt, vooraan bij jou, aan de overkant bij de
			# ander, en nergens zolang niemand Muis speelt.
			var bw_menu: int = og.bewoners().size()
			og.zet_facties(Constants.Doctrine.WOLF, Constants.Doctrine.MUIS)
			var bw_ander: Array = og.bewoners()
			og.zet_facties(Constants.Doctrine.MUIS, Constants.Doctrine.WOLF)
			var bw_eigen: Array = og.bewoners()
			print("[OMGEVING] bewoners: menu=%d, Wolf tegen Muis=%d (z %s), als Muis=%d (z %s)" % [
				bw_menu, bw_ander.size(), str(bw_ander.map(func(b): return snappedf(b.position.z, 0.1))),
				bw_eigen.size(), str(bw_eigen.map(func(b): return snappedf(b.position.z, 0.1)))])
			if Bewoner.alle_namen().has("soldaat_mouse"):
				if bw_eigen.size() < 1 or bw_ander.size() < 1:
					print("[OMGEVING] FOUT: soldaat_mouse verschijnt niet bij een Muis-speler")
					og_fouten += 1
				elif bw_eigen[0].position.z < 10.0 or bw_ander[0].position.z > 0.0:
					print("[OMGEVING] FOUT: bewoner staat aan de verkeerde kant (eigen z %.1f, ander z %.1f)" % [bw_eigen[0].position.z, bw_ander[0].position.z])
					og_fouten += 1
			for b in bw_eigen:
				var bp: Vector2 = og_cam.unproject_position((b as Node3D).global_position + Vector3(0.0, 0.3, 0.0))
				if not og.klik(bp):
					print("[OMGEVING] FOUT: klik op bewoner %s (scherm %s) raakt niets" % [b.naam, bp])
					og_fouten += 1
				elif not b.bezig and not b.acties().is_empty():
					print("[OMGEVING] FOUT: bewoner %s speelt geen actie na de klik" % b.naam)
					og_fouten += 1
			# de langste korte reactie is een bewoner-actie (~4,2 s) of de kogel
			# (3,75 s); alleen de kraai blijft langer weg (16-28 s)
			await get_tree().create_timer(5.5).timeout
			var og_bezig := 0
			for p in og._props:
				if p.bezig:
					og_bezig += 1
			print("[OMGEVING] na 5,5 s nog bezig: %d (alleen de kraai mag)" % og_bezig)
			if og_bezig > 1:
				og_fouten += 1
			# de variatie (11 september): elke reactie van elke prop een keer, kort
			# na elkaar. Overlappen mag; script-fouten niet (die vangt de grep).
			var og_reacties := 0
			for p in og._props:
				var lijst: Array = p.get("reacties", [])
				for ri in range(lijst.size()):
					og.speel_reactie(p, ri)
					og_reacties += 1
					await get_tree().create_timer(0.3).timeout
			print("[OMGEVING] %d reacties gespeeld op %d props" % [og_reacties, og._props.size()])
			await get_tree().create_timer(5.0).timeout
			# snel doorklikken (11 september): elke klik moet raak zijn en de
			# combo moet oplopen, ook terwijl de grote reactie nog loopt
			if og._props.size() > 0:
				var tp: Dictionary = og._props[0]
				var tn: Node3D = tp.node
				var tsp: Vector2 = og_cam.unproject_position(tn.global_position + Vector3(0.0, float(tp.hoogte) * 0.5, 0.0))
				var raak_n := 0
				for ti in 6:
					if og.klik(tsp):
						raak_n += 1
					await get_tree().create_timer(0.08).timeout
				print("[OMGEVING] snel klikken op %s: %d van 6 raak, combo %d" % [tn.name, raak_n, int(tp.combo)])
				if raak_n < 6 or int(tp.combo) < 4:
					print("[OMGEVING] FOUT: snel klikken werkt niet (raak %d, combo %d)" % [raak_n, int(tp.combo)])
					og_fouten += 1
		print("[OMGEVING] " + ("PASS" if og_fouten == 0 else "FAIL (%d fouten)" % og_fouten))
		var og_tex := get_viewport().get_texture()
		if og_tex != null and og_tex.get_image() != null:
			og_tex.get_image().save_png("res://_shot_omgeving.png")
			print("[OMGEVING] screenshot -> _shot_omgeving.png")
		get_tree().quit(0 if og_fouten == 0 else 1)
		return
	elif "vosview" in args:
		# F0.6-check: speel tot de actiefase tegen een Krokodil-AI en assert dat
		# de HP-blokjes van gedekte vijandelijke pionnen het "?"-sentinel tonen
		# (en eigen pionnen niet). Exit 0 = groen, 1 = lek/regressie.
		game._ai_doctrine = Constants.Doctrine.VOS
		var vhand: CardHand = game.get_node("UI/CardHand")
		var vsteps := 0
		while GameSession.state.phase != Phase.Type.ACTION \
				and GameSession.state.phase != Phase.Type.GAME_OVER and vsteps < 700:
			vsteps += 1
			var vst: GameState = GameSession.state
			if vst.phase == Phase.Type.PRE_GAME:
				game._start_match(1)
			elif vst.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(vst.phase):
				game._continue_after_reveal()
			elif Phase.is_define(vst.phase) and vst.cards_defined[1].size() == 0:
				var vbud: int = int(GameSession.state.doctrine_data_of(1).budget)
				for c in vhand.get_card_views():
					c.data.hp = 1
					c.data.stamina = mini(vbud - 2, 3)
					c.data.attack = vbud - 1 - mini(vbud - 2, 3)
					c._refresh()
				vhand._on_confirm_pressed()
			elif Phase.is_linking(vst.phase) and vst.current_player == 1:
				for i in vst.cards_revealed[1].size():
					if not vst.cards_revealed[1][i].is_linked():
						game._on_link_card_picked(i)
						break
				var vtarget = null
				for pawn in vst.pawns.values():
					if pawn.owner_id == 1 and not pawn.is_eliminated \
							and pawn.linked_card_id == -1 and game._pawn_has_room(pawn):
						vtarget = pawn
						break
				if vtarget != null:
					game._on_link_pawn_clicked(vtarget.id)
			await get_tree().create_timer(0.02).timeout
		var fouten := 0
		var gedekt_gecheckt := 0
		game._update_health_bars()
		for pawn in GameSession.state.pawns.values():
			var entry = game._hp_bars.get(pawn.id, null)
			if entry == null or not entry.has("qlabel"):
				continue
			# F4.3e: dezelfde kijkregel als de view (incl. C13: van dichtbij zie je hem).
			var hoort_gedekt: bool = View.pion_gedekt_voor(GameSession.state, pawn, 1)
			if hoort_gedekt:
				gedekt_gecheckt += 1
				if not entry.qlabel.visible or entry.qlabel.text != "?":
					fouten += 1
					print("[VOSVIEW] FOUT: gedekte pion %d toont geen '?'" % pawn.id)
			elif entry.qlabel.visible and pawn.owner_id == 1:
				fouten += 1
				print("[VOSVIEW] FOUT: eigen pion %d toont onterecht '?'" % pawn.id)
		print("[VOSVIEW] gedekte pionnen gecheckt=%d fouten=%d fase=%s" % [
			gedekt_gecheckt, fouten, Phase.to_string_phase(GameSession.state.phase)])
		var vosview_ok: bool = fouten == 0 and gedekt_gecheckt > 0
		print("[VOSVIEW] " + ("PASS" if vosview_ok else "FAIL"))
		var vtex := get_viewport().get_texture()
		if vtex != null and vtex.get_image() != null:
			vtex.get_image().save_png("res://_shot_vosview.png")
		get_tree().quit(0 if vosview_ok else 1)
		return
	elif "meleecheck" in args:
		# `-- meleecheck` — de bajonet-choreografie METEN in het echte spel
		# (Max, 30 juli: "laat het popje op de tegel staan, laat de tegenstander
		# doodgaan, dan pas oversteken"). We zetten twee pionnen naast elkaar,
		# laten de aanvaller toestoten en bemonsteren daarna elke 50 ms waar zijn
		# model STAAT. Goed = hij blijft op zijn eigen vak tot de dood-clip klaar
		# is, en steekt daarna over.
		# Muizen: die hebben alle karaktermodellen met clips, dus hier valt echt
		# iets te meten (de mens-factie speelt met geometrische stukken).
		game._human_doctrine = Constants.Doctrine.MUIS
		game._ai_doctrine = Constants.Doctrine.MUIS
		var mc_hand: CardHand = game.get_node("UI/CardHand")
		var mc_steps := 0
		while GameSession.state.phase != Phase.Type.ACTION \
				and GameSession.state.phase != Phase.Type.GAME_OVER and mc_steps < 700:
			mc_steps += 1
			var mst: GameState = GameSession.state
			if mst.phase == Phase.Type.PRE_GAME:
				game._start_match(1)
			elif mst.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(mst.phase):
				game._continue_after_reveal()
			elif Phase.is_define(mst.phase) and mst.cards_defined[1].size() == 0:
				var mbud: int = int(GameSession.state.doctrine_data_of(1).budget)
				for c2 in mc_hand.get_card_views():
					c2.data.hp = 1
					c2.data.stamina = mini(mbud - 2, 3)
					c2.data.attack = mbud - 1 - mini(mbud - 2, 3)
					c2._refresh()
				mc_hand._on_confirm_pressed()
			elif Phase.is_linking(mst.phase) and mst.current_player == 1:
				for i in mst.cards_revealed[1].size():
					if not mst.cards_revealed[1][i].is_linked():
						game._on_link_card_picked(i)
						break
				var mtarget = null
				for pawn in mst.pawns.values():
					if pawn.owner_id == 1 and not pawn.is_eliminated \
							and pawn.linked_card_id == -1 and game._pawn_has_room(pawn):
						mtarget = pawn
						break
				if mtarget != null:
					game._on_link_pawn_clicked(mtarget.id)
			await get_tree().create_timer(0.04).timeout
		var st3: GameState = GameSession.state
		# Twee scenario's (26 augustus, Max: "alle cav maken ook gebruik van
		# hun wapen"): de infanterie-bajonet EN de cavalerie-stoot met het
		# ingebakken melee-wapen. Zelfde meting, zelfde choreografie-regels;
		# de cavalerie-clips (Attack/Thrust/Pommel strike) heten na het laden
		# gewoon melee1..N, dus de clip-eis blijft identiek.
		var mc_alles_ok := true
		for mc_scenario in [[Constants.UnitType.INFANTRY, "infanterie"], [Constants.UnitType.CAVALRY, "cavalerie"]]:
			var mc_ok: bool = await _meleecheck_scenario(game, st3, int(mc_scenario[0]), String(mc_scenario[1]))
			mc_alles_ok = mc_alles_ok and mc_ok
		# Derde scenario (26 aug): de CHARGE -- aanrijden op de rush-clip,
		# sprong-stoot ("charge"-clip) bij aankomst.
		var mc_charge_ok: bool = await _meleecheck_charge(game, st3)
		mc_alles_ok = mc_alles_ok and mc_charge_ok
		print("[MELEE] " + ("PASS" if mc_alles_ok else "FAIL"))
		get_tree().quit(0 if mc_alles_ok else 1)
		return
	elif "resumecheck" in args:
		# F4.3g — de koude herstart op de ONLINE-weg (masterplan-M3 zonder
		# netwerk): game.gd speelt via een RemoteSession op een loopback met een
		# L1-bot; op elk nieuw moment start een verse game.tscn met een verse
		# RemoteSession op dezelfde loopback (alleen de view) en wordt het scherm
		# vergeleken. Gebruik: -- resumecheck [seed] [seat]
		var ri2 := args.find("resumecheck")
		var r_seed: int = int(args[ri2 + 1]) if args.size() > ri2 + 1 else 777
		var r_seat: int = int(args[ri2 + 2]) if args.size() > ri2 + 2 else 1
		seed(r_seed)
		var r_lb := LoopbackTransport.new(game._potje_regels())
		r_lb.zet_bot(Constants.opponent(r_seat), AgentL1.new(), r_seed)
		r_lb.start()
		game._start_online(RemoteSession.new(r_lb.voor_seat(r_seat), r_seat))
		await get_tree().create_timer(0.3).timeout
		var r_momenten := 0
		var r_verschillen := 0
		var r_canary := 0
		var r_sleutel := ""
		var r_acties := 0
		var r_t0 := Time.get_ticks_msec()
		var r_fasen: Dictionary = {}
		while r_lb.state.phase != Phase.Type.GAME_OVER and r_acties < 240 \
				and Time.get_ticks_msec() - r_t0 < 15 * 60 * 1000:
			var rw := 0
			while not game.is_rustig() and rw < 600:
				rw += 1
				await get_tree().create_timer(0.05).timeout
			await get_tree().create_timer(0.35).timeout
			await get_tree().process_frame
			await get_tree().process_frame
			var rs: GameState = r_lb.state
			var sleutel := "%s|%d|%d|%d|%d|%s|%s|%s|%s|%s" % [Phase.to_string_phase(rs.phase), rs.cycle,
				rs.round_number, rs.current_player, rs.pending_wolf_step_pawn,
				str(rs.doctrine_commits.has(r_seat)), str(rs.placements_done.get(r_seat, false)),
				str(rs.cards_defined.get(r_seat, []).size() > 0), str(rs.reveal_acks.get(r_seat, false)),
				str(rs.spawn_done.get(r_seat, false))]
			if sleutel != r_sleutel:
				r_sleutel = sleutel
				r_momenten += 1
				r_fasen[rs.phase] = true
				var ru: Dictionary = await _resume_vergelijk(game, r_lb, r_seat, r_momenten)
				r_verschillen += int(ru.verschillen)
				r_canary += int(ru.canary)
			if r_lb.state.phase == Phase.Type.GAME_OVER:
				break
			if _online_drijf_mens(game, r_lb, r_seat):
				r_acties += 1
			else:
				await get_tree().create_timer(0.1).timeout
		var rwe := 0
		while not game.is_rustig() and rwe < 600:
			rwe += 1
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(0.5).timeout
		await get_tree().process_frame
		await get_tree().process_frame
		var r_eind: Dictionary = await _resume_vergelijk(game, r_lb, r_seat, r_momenten + 1)
		r_verschillen += int(r_eind.verschillen)
		r_canary += int(r_eind.canary)
		r_fasen[r_lb.state.phase] = true
		var r_lijst: Array = []
		for f in r_fasen:
			r_lijst.append(Phase.to_string_phase(f))
		var r_ok: bool = r_verschillen == 0 and r_canary == 0 and r_momenten >= 8
		print("[RESUME] %s: seed=%d seat=%d momenten=%d verschillen=%d canary=%d acties=%d fasen=%s" % [
			"PASS" if r_ok else "FAIL", r_seed, r_seat, r_momenten + 1, r_verschillen, r_canary, r_acties, ", ".join(r_lijst)])
		get_tree().quit(0 if r_ok else 1)
		return
	elif "herstelcheck" in args:
		# F4.3e — render-vanaf-snapshot, offline bewezen (masterplan-M3 zonder
		# netwerk). De live scene speelt ZONDER bot (de online-situatie): de
		# mens via het timeout-pad, de tegenstander (een L1-agent) buiten
		# game.gd om via GameSession, zoals een server dat doet. Op elk nieuw
		# "moment" (fasewissel, beurtwissel, eigen commit, open wolf-stap)
		# start een VERSE game.tscn op alleen de fog-view van speler 1 (door
		# JSON-tekst) en wordt het scherm vergeleken met het live scherm.
		# Canary: geen hp-blokje met een getal voor een pion die in de view
		# '?' droeg. Gebruik: -- herstelcheck [seed] [factie-tegenstander]
		var hi := args.find("herstelcheck")
		var h_seed: int = int(args[hi + 1]) if args.size() > hi + 1 else 777
		var h_d2: int = _sim_doctrine(String(args[hi + 2])) if args.size() > hi + 2 else Constants.Doctrine.VOS
		seed(h_seed)
		game._human_doctrine = Constants.Doctrine.MUIS
		game._ai_doctrine = h_d2
		game._start_match(1)
		await get_tree().create_timer(0.2).timeout
		game._confirm_placement()  # beide opstellingen: de bot is er nog
		await get_tree().create_timer(0.3).timeout
		game._ai = null
		game._stop_phase_timer()  # de define-timer liep nog met bot; vanaf nu drijft het harnas
		game._update_hud()  # topbalk zonder de "nog 20s" van die timer
		var h_bot := AgentL1.new()
		h_bot.player_id = 2
		h_bot.rng = SeededRng.new(h_seed).fork("p2")
		var momenten := 0
		var verschillen := 0
		var canary := 0
		var laatste_sleutel := ""
		var h_acties := 0
		var h_t0 := Time.get_ticks_msec()
		var fasen_gezien: Dictionary = {}
		while GameSession.state.phase != Phase.Type.GAME_OVER and h_acties < 240 \
				and Time.get_ticks_msec() - h_t0 < 15 * 60 * 1000:
			var w := 0
			while not game.is_rustig() and w < 600:  # poef-reveal van spawns kan seconden duren
				w += 1
				await get_tree().create_timer(0.05).timeout
			await get_tree().create_timer(0.35).timeout
			await get_tree().process_frame
			await get_tree().process_frame
			var st: GameState = GameSession.state
			var sleutel := "%s|%d|%d|%d|%d|%s|%s|%s|%s" % [Phase.to_string_phase(st.phase), st.cycle,
				st.round_number, st.current_player, st.pending_wolf_step_pawn,
				str(st.placements_done.get(1, false)), str(st.cards_defined.get(1, []).size() > 0),
				str(st.reveal_acks.get(1, false)), str(st.spawn_done.get(1, false))]
			if sleutel != laatste_sleutel:
				laatste_sleutel = sleutel
				momenten += 1
				fasen_gezien[st.phase] = true
				var uitkomst: Dictionary = await _herstel_vergelijk(game, st, momenten)
				verschillen += int(uitkomst.verschillen)
				canary += int(uitkomst.canary)
			if GameSession.state.phase == Phase.Type.GAME_OVER:
				break
			if _herstel_zet(game, h_bot):
				h_acties += 1
			else:
				await get_tree().create_timer(0.1).timeout
		# Ook het einde zelf vergelijken (of de laatste stand bij afkappen),
		# pas als het scherm stilstaat (ronde-pauze, opruk, ragdoll).
		var we := 0
		while not game.is_rustig() and we < 600:
			we += 1
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(0.5).timeout
		await get_tree().process_frame
		await get_tree().process_frame
		var eind: Dictionary = await _herstel_vergelijk(game, GameSession.state, momenten + 1)
		verschillen += int(eind.verschillen)
		canary += int(eind.canary)
		fasen_gezien[GameSession.state.phase] = true
		var fasen_lijst: Array = []
		for f in fasen_gezien:
			fasen_lijst.append(Phase.to_string_phase(f))
		var hok: bool = verschillen == 0 and canary == 0 and momenten >= 8
		print("[HERSTEL] %s: seed=%d momenten=%d verschillen=%d canary=%d acties=%d fasen=%s" % [
			"PASS" if hok else "FAIL", h_seed, momenten + 1, verschillen, canary, h_acties, ", ".join(fasen_lijst)])
		get_tree().quit(0 if hok else 1)
		return
	elif "naadcheck" in args:
		# F4.3c — de bot-naad. Na de opstelling gaat de AI op null: vanaf dan
		# is game.gd een client zonder tegenstander in huis, precies de online-
		# situatie. De "tegenstander" dient buiten game.gd om in (zoals een
		# server dat doet), de mens speelt via het timeout-pad. Eisen: niets
		# crasht, game.gd dient NOOIT iets namens speler 2 in, elke commit-fase
		# wacht op de ander, en zonder klok start er geen lokale timer.
		game._human_doctrine = Constants.Doctrine.MUIS
		game._ai_doctrine = Constants.Doctrine.WOLF
		game._start_match(1)
		await get_tree().create_timer(0.2).timeout
		game._confirm_placement()  # beide opstellingen: de bot is er nog
		await get_tree().create_timer(0.3).timeout
		var nfouten := 0
		var teller := [0]
		GameSession.action_performed.connect(func(_a: Dictionary, _r: Dictionary) -> void: teller[0] += 1)
		game._ai = null  # vanaf hier: geen bot meer in game.gd
		var st: GameState = GameSession.state
		if not Phase.is_define(st.phase):
			nfouten += 1
			print("[NAAD] FOUT: na de opstelling geen define-fase maar %s" % Phase.to_string_phase(st.phase))
		# 1. De define-timer liep al (gestart met bot). Timeout-pad: de mens
		#    definieert automatisch, de tegenstander NIET (geen bot).
		game._timer_left = 0.0
		await get_tree().create_timer(0.4).timeout
		st = GameSession.state
		if st.cards_defined[1].size() == 0:
			nfouten += 1
			print("[NAAD] FOUT: de mens heeft niet gedefinieerd via het timeout-pad")
		if st.cards_defined[2].size() != 0:
			nfouten += 1
			print("[NAAD] FOUT: game.gd definieerde namens de tegenstander")
		if not Phase.is_define(st.phase):
			nfouten += 1
			print("[NAAD] FOUT: de define-fase wachtte niet op de tegenstander")
		# 2. Zonder klok en zonder bot start er geen lokale timer.
		game._start_phase_timer(5.0)
		if game._timer_active:
			nfouten += 1
			print("[NAAD] FOUT: lokale timer actief zonder klok en zonder bot")
		# 3. De tegenstander definieert (buiten game.gd om): reveal opent.
		var bud2: int = int(st.doctrine_data_of(2).budget)
		var kaarten2: Array = []
		for i in Validator.expected_define_count(st, 2):
			kaarten2.append({"hp": bud2 - 2, "stamina": 1, "attack": 1})
		if not GameSession.submit_define_cards(2, kaarten2):
			nfouten += 1
			print("[NAAD] FOUT: define van de tegenstander geweigerd")
		await get_tree().create_timer(0.3).timeout
		st = GameSession.state
		if not Phase.is_reveal(st.phase):
			nfouten += 1
			print("[NAAD] FOUT: geen reveal na beide defines maar %s" % Phase.to_string_phase(st.phase))
		# 4. De mens bevestigt de reveal: alleen de EIGEN ack, de fase wacht.
		game._continue_after_reveal()
		await get_tree().create_timer(0.2).timeout
		st = GameSession.state
		if not bool(st.reveal_acks.get(1, false)) or bool(st.reveal_acks.get(2, false)):
			nfouten += 1
			print("[NAAD] FOUT: reveal-ack niet alleen voor de mens (%s)" % str(st.reveal_acks))
		if not Phase.is_reveal(st.phase):
			nfouten += 1
			print("[NAAD] FOUT: de reveal wachtte niet op de ack van de tegenstander")
		GameSession.submit_ack_reveal(2)
		await get_tree().create_timer(0.3).timeout
		# 5. De drie setup-rondes uitspelen: de mens via het timeout-pad (zonder
		#    bot en zonder klok loopt er geen timer meer, dus _on_phase_timeout
		#    rechtstreeks), de tegenstander buiten game.gd om. Na elke zet van de
		#    mens moet de fase op de ander WACHTEN; game.gd mag nooit namens
		#    speler 2 definiëren, acken of koppelen.
		var rondjes := 0
		var links_p2 := 0
		while GameSession.state.phase != Phase.Type.ACTION and rondjes < 300:
			rondjes += 1
			st = GameSession.state
			if Phase.is_define(st.phase):
				if st.cards_defined[1].size() == 0:
					game._on_phase_timeout()
					await get_tree().create_timer(0.2).timeout
					if GameSession.state.cards_defined[2].size() != 0:
						nfouten += 1
						print("[NAAD] FOUT: game.gd definieerde namens de tegenstander (ronde %d)" % st.round_number)
				elif st.cards_defined[2].size() == 0:
					var b2: int = int(st.doctrine_data_of(2).budget)
					var k2: Array = []
					for i in Validator.expected_define_count(st, 2):
						k2.append({"hp": b2 - 2, "stamina": 1, "attack": 1})
					GameSession.submit_define_cards(2, k2)
			elif Phase.is_reveal(st.phase):
				if not bool(st.reveal_acks.get(1, false)):
					game._continue_after_reveal()
					await get_tree().create_timer(0.2).timeout
					if bool(GameSession.state.reveal_acks.get(2, false)):
						nfouten += 1
						print("[NAAD] FOUT: game.gd ackte namens de tegenstander (ronde %d)" % st.round_number)
				elif not bool(st.reveal_acks.get(2, false)):
					GameSession.submit_ack_reveal(2)
			elif Phase.is_linking(st.phase):
				if st.current_player == 1:
					game._on_phase_timeout()
				else:
					var gelinkt_voor: int = 0
					for c in st.cards_revealed[2]:
						if c.is_linked():
							gelinkt_voor += 1
					await get_tree().create_timer(1.0).timeout  # ruim boven de ai_link_denktijd
					st = GameSession.state
					if not Phase.is_linking(st.phase) or st.current_player != 2:
						continue
					var gelinkt_na: int = 0
					for c in st.cards_revealed[2]:
						if c.is_linked():
							gelinkt_na += 1
					if gelinkt_na != gelinkt_voor:
						nfouten += 1
						print("[NAAD] FOUT: game.gd koppelde namens de tegenstander (ronde %d)" % st.round_number)
					var kaart = null
					for c in st.cards_revealed[2]:
						if not c.is_linked():
							kaart = c
							break
					var pion = null
					for p in st.pawns.values():
						if p.owner_id == 2 and not p.is_eliminated and p.linked_card_id == -1:
							pion = p
							break
					if kaart != null and pion != null and GameSession.submit_link(2, kaart.id, pion.id):
						links_p2 += 1
			await get_tree().create_timer(0.1).timeout
		st = GameSession.state
		if st.phase != Phase.Type.ACTION:
			nfouten += 1
			print("[NAAD] FOUT: geen actiefase na de setup-rondes maar %s (rondjes %d)" % [Phase.to_string_phase(st.phase), rondjes])
		if links_p2 == 0:
			nfouten += 1
			print("[NAAD] FOUT: de tegenstander kwam nooit aan koppelen toe")
		# 6. Actiefase: is de tegenstander aan zet, dan doet game.gd NIETS.
		var voor_acties: int = teller[0]
		await get_tree().create_timer(1.2).timeout
		if GameSession.state.current_player == 2 and teller[0] != voor_acties:
			nfouten += 1
			print("[NAAD] FOUT: game.gd deed een actie namens de tegenstander")
		if GameSession.state.current_player == 2 and game._timer_active:
			nfouten += 1
			print("[NAAD] FOUT: timer actief in de beurt van de tegenstander")
		# 7. Einde via de "server": opgeven door de tegenstander, game_over-pad.
		GameSession.submit_resign(2)
		await get_tree().create_timer(0.3).timeout
		if GameSession.state.phase != Phase.Type.GAME_OVER or GameSession.state.winner != 1:
			nfouten += 1
			print("[NAAD] FOUT: geen game_over met winnaar 1 na de resign van de tegenstander")
		print("[NAAD] %s: %d fouten, %d acties, koppelrondjes %d" % ["PASS" if nfouten == 0 else "FAIL", nfouten, teller[0], rondjes])
		get_tree().quit(0 if nfouten == 0 else 1)
		return
	elif "uispel" in args:
		# F4.3a — nulmeting op game.gd-niveau: een volledige partij vs-AI waarin
		# de MENS uitsluitend via het bestaande timeout-pad speelt (auto-define,
		# aanvul-spawn, auto-link, greedy zet) en de AI zoals altijd. Dit dekt
		# de submit-VOLGORDE van game.gd (AI-opstelling voor de mens, AI-bet en
		# -define na de mens, AI-spawn voor de overlay), die simcheck, goldens
		# en `-- record` niet raken. Gebruik: -- uispel [seed]
		var ui := args.find("uispel")
		var ui_seed: int = int(args[ui + 1]) if args.size() > ui + 1 else 777
		seed(ui_seed)
		game._human_doctrine = Constants.Doctrine.MUIS
		game._ai_doctrine = Constants.Doctrine.WOLF
		var acties := [0]
		GameSession.action_performed.connect(func(_a: Dictionary, _r: Dictionary) -> void: acties[0] += 1)
		game._start_match(1)
		var t0 := Time.get_ticks_msec()
		var afgekapt := false
		var stil_sinds := Time.get_ticks_msec()
		while GameSession.state.phase != Phase.Type.GAME_OVER:
			if Time.get_ticks_msec() - t0 > 20 * 60 * 1000:
				afgekapt = true
				break
			var st: GameState = GameSession.state
			if st.phase == Phase.Type.PLACEMENT and not st.placements_done.get(1, false):
				game._confirm_placement()
				stil_sinds = Time.get_ticks_msec()
			elif Phase.is_reveal(st.phase) and not st.reveal_acks.get(1, false):
				game._continue_after_reveal()
				stil_sinds = Time.get_ticks_msec()
			elif game._timer_active:
				# De echte timeout-route: _process ziet 0 en vuurt _on_phase_timeout.
				game._timer_left = 0.0
				stil_sinds = Time.get_ticks_msec()
			elif Time.get_ticks_msec() - stil_sinds > 3000 and st.current_player == 1:
				if st.phase == Phase.Type.ACTION or Phase.is_linking(st.phase):
					# Vangnet: de mens is aan zet zonder lopende klok (bv. een
					# open wolf-stap). Zelfde pad als een timeout.
					game._on_phase_timeout()
					stil_sinds = Time.get_ticks_msec()
			await get_tree().create_timer(0.05).timeout
		var us: GameState = GameSession.state
		print("[UISPEL] seed=%d winner=%d acties=%d cyclus=%d afgekapt=%s duur=%ds zobrist=%s" % [
			ui_seed, us.winner, acties[0], us.cycle, str(afgekapt),
			int((Time.get_ticks_msec() - t0) / 1000), Zobrist.state_hash(us)])
		get_tree().quit(1 if afgekapt else 0)
		return
	elif "play" in args:
		# `-- play [factie]` — bv. `play muis` om karaktermodellen te bekijken.
		var fnames := {"mens": Constants.Doctrine.MENS, "varken": Constants.Doctrine.MENS, "muis": Constants.Doctrine.MUIS,
			"leeuw": Constants.Doctrine.LEEUW, "beer": Constants.Doctrine.BEER,
			"wolf": Constants.Doctrine.WOLF, "vos": Constants.Doctrine.VOS, "krokodil": Constants.Doctrine.VOS}
		for fname in fnames:
			if fname in args:
				game._human_doctrine = fnames[fname]
				game._ai_doctrine = fnames[fname]
		if "sfeer" in args:
			game._toggle_ambiance_panel()
		var hand: CardHand = game.get_node("UI/CardHand")
		var steps := 0
		# Muis heeft 4 kaarten per ronde (24 koppelingen) → ruimere stap-limiet.
		while GameSession.state.phase != Phase.Type.ACTION \
				and GameSession.state.phase != Phase.Type.GAME_OVER and steps < 700:
			steps += 1
			var st: GameState = GameSession.state
			if st.phase == Phase.Type.PRE_GAME:
				game._start_match(1)
			elif st.phase == Phase.Type.PLACEMENT:
				game._confirm_placement()
			elif Phase.is_reveal(st.phase):
				game._continue_after_reveal()
			elif Phase.is_define(st.phase) and st.cards_defined[1].size() == 0:
				# Stats passend binnen het doctrine-budget (Muis 5, Leeuw 9, rest 7).
				var bud: int = int(GameSession.state.doctrine_data_of(1).budget)
				for c in hand.get_card_views():
					c.data.hp = 1
					c.data.stamina = mini(bud - 2, 3)
					c.data.attack = bud - 1 - mini(bud - 2, 3)
					c._refresh()
				hand._on_confirm_pressed()
			elif Phase.is_linking(st.phase) and st.current_player == 1:
				for i in st.cards_revealed[1].size():
					if not st.cards_revealed[1][i].is_linked():
						game._on_link_card_picked(i)
						break
				var target = null
				for pawn in st.pawns.values():
					if pawn.owner_id == 1 and not pawn.is_eliminated \
							and pawn.linked_card_id == -1 and game._pawn_has_room(pawn):
						target = pawn
						break
				if target != null:
					game._on_link_pawn_clicked(target.id)
			await get_tree().create_timer(0.04).timeout
		if "sporen" in args:
			# Twee kruisende test-looppaden midden over het bord.
			game._spawn_footprints(game.tile_position(1, 5), game.tile_position(9, 5), 0.1)
			game._spawn_footprints(game.tile_position(5, 1), game.tile_position(5, 9), 0.1)
			game._spawn_wheel_tracks(game.tile_position(1, 7), game.tile_position(9, 7), Vector3(1, 0, 0), Vector3(0, 0, 1), 0.1)
			await get_tree().create_timer(0.5).timeout
		await get_tree().create_timer(0.4).timeout
		print("[PLAY] fase=%s cyclus=%d ronde=%d beurt=%d actief_p1=%d actief_p2=%d stappen=%d" % [
			Phase.to_string_phase(GameSession.state.phase),
			GameSession.state.cycle, GameSession.state.round_number,
			GameSession.state.current_player,
			GameSession.state.get_active_pawns_for(1).size(),
			GameSession.state.get_active_pawns_for(2).size(),
			steps,
		])
		out = "res://_shot_play.png"
	elif "align" in args:
		# `-- align` — uitlijn-diagnose: meet per pion het verschil tussen de
		# wereldpositie van de PawnView en het centrum van zijn tegel, en maak
		# een top-down screenshot (recht van boven = elke verschuiving is
		# ondubbelzinnig zichtbaar, zonder camera-perspectief-verwarring).
		game._human_doctrine = Constants.Doctrine.MUIS
		game._ai_doctrine = Constants.Doctrine.MUIS
		game._start_match(1)
		await get_tree().create_timer(0.3).timeout
		game._confirm_placement()
		await get_tree().create_timer(0.6).timeout
		var asum := Vector3.ZERO
		var aworst := 0.0
		var acount := 0
		for pid in game._pawn_views:
			var pv: PawnView = game._pawn_views[pid]
			var pawn = GameSession.state.pawns.get(pid)
			if pawn == null:
				continue
			var tile: Node3D = game._tiles.get(Vector2i(pawn.position.x, pawn.position.y))
			if tile == null:
				print("[ALIGN] pion %d: GEEN tegel voor (%d,%d)!" % [pid, pawn.position.x, pawn.position.y])
				continue
			var delta: Vector3 = pv.global_position - tile.global_position
			delta.y = 0.0
			asum += delta
			acount += 1
			aworst = maxf(aworst, delta.length())
			if acount <= 6:
				var px := 0.0
				var pz := 0.0
				if pv._piece != null:
					px = pv._piece.position.x
					pz = pv._piece.position.z
				print("[ALIGN] pion %d op (%d,%d): delta=(%+.3f, %+.3f) piece_offset=(%+.3f, %+.3f)" % [
					pid, pawn.position.x, pawn.position.y, delta.x, delta.z, px, pz])
		print("[ALIGN] gemiddelde delta=(%+.4f, %+.4f) over %d pionnen · max=%.4f" % [
			asum.x / maxf(float(acount), 1.0), asum.z / maxf(float(acount), 1.0), acount, aworst])
		# Visueel zwaartepunt (botten) t.o.v. de tegel, per team — het oog
		# beoordeelt op het LIJF, niet op de wiskundige pion-positie.
		for team_id in [1, 2]:
			var vsum := Vector3.ZERO
			var vn := 0
			for pid in game._pawn_views:
				var pawn = GameSession.state.pawns.get(pid)
				if pawn == null or pawn.owner_id != team_id:
					continue
				var pv: PawnView = game._pawn_views[pid]
				if pv._piece == null:
					continue
				var tile: Node3D = game._tiles.get(Vector2i(pawn.position.x, pawn.position.y))
				if tile == null:
					continue
				var mm: Dictionary = pv._measure_bones(pv._piece)
				if mm.is_empty():
					continue
				var wc: Vector3 = (pv._piece as Node3D).global_transform * Vector3(
					float(mm.center.x), 0.0, float(mm.center.z))
				var vd := wc - tile.global_position
				vsum += Vector3(vd.x, 0.0, vd.z)
				vn += 1
			if vn > 0:
				print("[ALIGN] team %d: visueel voeten-centrum t.o.v. tegel = (%+.3f, %+.3f)" % [
					team_id, vsum.x / float(vn), vsum.z / float(vn)])
		var acam: Camera3D = game._camera
		acam.projection = Camera3D.PROJECTION_ORTHOGONAL
		acam.size = 21.0
		acam.global_position = game._board.global_position + Vector3(5.0, 20.0, 5.0)
		acam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		await get_tree().create_timer(0.25).timeout
		out = "res://_shot_align.png"
	elif "open" in args:
		var hand: CardHand = game.get_node("UI/CardHand")
		game._start_match(1)
		await get_tree().create_timer(0.2).timeout
		game._confirm_placement()
		await get_tree().create_timer(0.3).timeout
		for c in hand.get_card_views():
			c.data.hp = 3
			c.data.stamina = 2
			c.data.attack = 2
			c._refresh()
		hand._on_confirm_pressed()
		await get_tree().create_timer(0.9).timeout
		out = "res://_shot_open.png"

	# Headless (--headless) is er geen rendering: get_texture() geeft null.
	# De [PLAY]-regel hierboven is dan het rooksignaal; screenshot is bijvangst.
	var vp_tex := get_viewport().get_texture()
	if vp_tex != null and vp_tex.get_image() != null:
		vp_tex.get_image().save_png(out)
	else:
		print("[PLAY] headless: geen viewport-texture, screenshot overgeslagen")
	get_tree().quit()


# =========================================================================
# Headless auto-trainer (CMA-lite per factie)
# =========================================================================

const TRAIN_AI := preload("res://scripts/ai/AIMedium.gd")

## F2.5 — optionele custom regels voor de hele trainingsrun (null = 4.1.x).
var _train_rules: RulesConfig = null

# Convergentiecheck (bouwplan §7.4, F1.6): elke CONV_INTERVAL factie-generaties
# speelt de huidige kampioen head-to-head tegen die van CONV_INTERVAL terug.
const CONV_INTERVAL := 5
const CONV_GAMES := 12

## Populatie-training: per generatie één factie. POP kandidaten (alle gewichten
## licht verstoord, log-normaal met stapgrootte sigma) spelen elk GAMES potjes;
## de top-helft wordt gerecombineerd (meetkundig gemiddelde) en geverifieerd
## tegen de kampioen. Sigma past zichzelf aan (groter bij succes, kleiner bij
## falen). Het profiel wordt bij elke adoptie opgeslagen.
## Adoptie-poort van de trainer (19 september, zie de toelichting bij de
## verificatie): verificatie per helft VERIFY_FACTOR x games potjes, eis
## +VERIFY_MARGE op het totaal (fitness 0-1 per potje, dus 1,0 = een winst
## netto), per helft hooguit VERIFY_HELFT_MIN achteruit. Stapgrootte sigma
## zakt niet onder SIGMA_VLOER en gaat na SIGMA_RESET_NA afwijzingen op rij
## terug naar 0,25.
const VERIFY_FACTOR := 2
const VERIFY_MARGE := 1.0
const VERIFY_HELFT_MIN := 0.5
const SIGMA_VLOER := 0.12
const SIGMA_RESET_NA := 5
const VERIFY_THREADS := 6      # verificatiepotjes tegelijk (meer = allocator-contention)


func _run_training(minutes: float, pop: int, games: int, faction: int = -1, train_seed: int = 0) -> void:
	# F0.1: alle trainings-loting via één seedbare stream (was: globale randi/randfn
	# op de hoofdthread; die thread-beperking vervalt hiermee).
	var train_rng := SeededRng.new(train_seed)
	var profile: Dictionary = AIController.load_profile()
	if profile.is_empty():
		profile = AIController.default_profile()
		print("[TRAIN] Geen opgeslagen profiel — start met defaults.")
	else:
		print("[TRAIN] Opgeslagen per-factie-profiel geladen — training gaat verder.")
	if faction >= 0:
		print("[TRAIN] Dit proces traint alléén de %s (override: %s)." % [
			Constants.doctrine_name(faction), AIController.override_path(faction)])
	var baseline: Dictionary = AIController.default_profile()
	# Schaal-anker: eerdere runs lieten de grootte-ordes exploderen (Beer haven=1.2M,
	# Leeuw hp=112k) — gedrag-neutraal (lineaire eval), maar mutaties worden zinloos
	# en floats lopen ooit vol. Terugpinnen op de baseline-schaal wijzigt géén beslissing.
	for dk in profile:
		if baseline.has(dk):
			profile[dk] = AIController.renormalize_weights(profile[dk], baseline[dk])
	var doctrines: Array = Constants.DOCTRINE_DATA.keys()
	# Tegenstander-pool tegen rondjes draaien (steen-papier-schaar in zelf-spel):
	# [0] = baseline (vast ijkpunt), daarna de recente kampioenen.
	var pool: Array = [_copy_profile(baseline), _copy_profile(profile)]
	var max_pool: int = 8
	var sigma: Dictionary = {}
	for d in doctrines:
		sigma[d] = 0.25
	# 19 september: na een reeks afwijzingen de stap weer opgooien, anders
	# krimpt hij naar de vloer en zijn alle kandidaten kopieen van de kampioen.
	var afwijzingen_op_rij: Dictionary = {}
	for d in doctrines:
		afwijzingen_op_rij[d] = 0
	var t0: int = Time.get_ticks_msec()
	var deadline: float = minutes * 60_000.0
	var gen: int = 0
	var adoptions: int = 0
	# Matchup-tally: hoe vaak wint DEZE (getrainde) factie tegen elke tegenstander.
	var matchup: Dictionary = {}
	# C15 (7 september): buit over de hele run, zodat het rapport laat zien of
	# de kandidaten echt op dragers jagen (pt = vaandel, cp = tamboer).
	var buit_run: Dictionary = {"pt": 0, "cp": 0, "verloren": 0, "potjes": 0}
	# Convergentie: per factie een venster kampioen-snapshots + generatie-teller.
	var conv_geschiedenis: Dictionary = {}
	var gen_factie: Dictionary = {}
	# Referentie-score van de HUIDIGE kampioen op de vaste verificatiereeks,
	# per factie gecacht (vervalt bij adoptie). Zie de relatieve gate hieronder.
	var verify_ref: Dictionary = {}
	print("[TRAIN] Budget %.1f min · populatie %d · %d potjes per kandidaat · %d facties · PARALLEL (%d threads)" % [
		minutes, pop, games, doctrines.size(), pop])
	print("[TRAIN] Eén generatie = %d potjes (kandidaten + dubbele verificatie); parallel op eigen threads..." % [
		pop * games + games * VERIFY_FACTOR * 2])
	while Time.get_ticks_msec() - t0 < deadline:
		gen += 1
		var d: int = faction if faction >= 0 else doctrines[(gen - 1) % doctrines.size()]
		var champ_w: Dictionary = profile[d]
		# 1) Kandidaten: alle gewichten licht verstoord (multiplicatief, dus het
		#    TEKEN blijft behouden — negatieve gewichten zoals flankvoorkeuren
		#    mogen niet naar +0.01 geklemd worden).
		var candidates: Array = []
		for _j in pop:
			var w: Dictionary = {}
			for k in champ_w:
				var scaled: float = float(champ_w[k]) * exp(train_rng.randfn(0.0, float(sigma[d])))
				if absf(scaled) < 0.01:
					scaled = 0.01 if scaled >= 0.0 else -0.01
				w[k] = scaled
			candidates.append({"w": w, "fit": 0.0})
		# 2) GEDEELD tegenstander-schema: elke kandidaat speelt exact dezelfde
		#    reeks (zelfde tegenstander, factie én kant per potje-index). Zo is
		#    het fitness-verschil tussen kandidaten puur de gewichten, niet de
		#    loting (gepaarde vergelijking → veel minder ruis per generatie).
		#    Tegenstander-facties gebalanceerd (geschud rondje) i.p.v. willekeurig.
		var doc_order: Array = doctrines.duplicate()
		train_rng.shuffle(doc_order)
		var schedule: Array = []
		for g in games:
			# Potje 0: vast ijkpunt (baseline); potje 1: de huidige kampioen;
			# de rest: een willekeurige oude kampioen uit de pool.
			var opp_profile: Dictionary
			if g == 0:
				opp_profile = baseline
			elif g == 1:
				opp_profile = profile
			else:
				opp_profile = pool[train_rng.randi_range(0, pool.size() - 1)]
			var opp_d: int = doc_order[g % doc_order.size()]
			schedule.append({"opp_w": opp_profile[opp_d], "opp_d": opp_d, "cand_is_p1": g % 2 == 0})
		# Fitness PARALLEL: één thread per kandidaat (pop threads tegelijk).
		# Meer threads (per potje) bleek AVERECHTS: te veel GDScript-threads
		# vechten om de allocator en maken het 4× trager. pop (6) is de sweet spot.
		var threads: Array = []
		for j in pop:
			var jobs: Array = []
			for g in games:
				jobs.append({
					"cand_w": candidates[j].w, "cand_d": d,
					"opp_w": schedule[g].opp_w, "opp_d": schedule[g].opp_d,
					"cand_is_p1": schedule[g].cand_is_p1,
				})
			var thread := Thread.new()
			thread.start(_eval_games_threaded.bind(jobs))
			threads.append(thread)
		var gen_buit: Dictionary = {"pt": 0, "cp": 0, "verloren": 0}
		for j in pop:
			var res: Dictionary = threads[j].wait_to_finish()
			candidates[j].fit = float(res.fit)
			for od in res.tally:
				if not matchup.has(od):
					matchup[od] = {"w": 0.0, "g": 0}
				matchup[od].w += res.tally[od].w
				matchup[od].g += res.tally[od].g
			for bk in ["pt", "cp", "verloren"]:
				gen_buit[bk] += int(res.buit[bk])
				buit_run[bk] += int(res.buit[bk])
			buit_run.potjes += games
			print("[TRAIN]   gen %d · %s · kandidaat %d/%d: %.1f/%d punten · buit %d pt + %d CP, %d dragers verloren · %.1f min" % [
				gen, Constants.doctrine_name(d), j + 1, pop, float(candidates[j].fit), games,
				int(res.buit.pt), int(res.buit.cp), int(res.buit.verloren),
				float(Time.get_ticks_msec() - t0) / 60_000.0])
		candidates.sort_custom(func(a, b): return a.fit > b.fit)
		# 3) Recombinatie: meetkundig gemiddelde van de top-helft, met behoud
		#    van het teken (alle kandidaten delen het teken van de kampioen).
		var mu: int = maxi(1, pop / 2)
		var mean: Dictionary = {}
		for k in champ_w:
			var sign_ref: float = -1.0 if float(champ_w[k]) < 0.0 else 1.0
			var log_sum: float = 0.0
			for j in mu:
				log_sum += log(maxf(0.01, absf(float(candidates[j].w[k]))))
			mean[k] = sign_ref * exp(log_sum / float(mu))
		# Her-normaliseren vóór verificatie: precies wat we zouden opslaan wordt
		# getest. Pint de schaal op de baseline; ratio's/tekens blijven exact.
		mean = AIController.renormalize_weights(mean, baseline[d])
		# 4) Verificatie-gate (parallel): 2×games potjes — de HELFT tegen de
		#    kampioen, de HELFT tegen de vaste baseline (anders kun je overfitten
		#    op je eigen stijl en absoluut zwakker worden zonder dat de gate het
		#    ziet). Tegenstander-facties round-robin i.p.v. loting.
		#    RELATIEVE gate (F1.6): de oude absolute eis (>= 8/12 = 67% winrate)
		#    was voor een zwakke factie onhaalbaar — Muis op ~20% kreeg 12
		#    generaties lang 0 adopties, ook met echt betere kandidaten. Nu
		#    speelt de HUIDIGE kampioen dezelfde (deterministische) reeks als
		#    referentie; adoptie eist totaal >= referentie + 2 en per helft geen
		#    achteruitgang groter dan 1. Meet "beter dan nu", niet "goed".
		# Twee rondes van `games` threads (12 tegelijk = allocator-contention).
		#    19 september (diagnose na vier runs met samen 1 adoptie op ~300
		#    generaties, waarvan 186 op 4.3.7): de fitness is sinds de
		#    campagne-fitness GENORMALISEERD naar 0-1 per potje, dus "+2" eiste
		#    twee verliespartijen die in havenwinsten omslaan op 12 vaste loten,
		#    zonder er een terug te geven. Gemeten: een kandidaat die tegen de
		#    baseline +0,6 en in totaal +0,4 beter was ging de prullenbak in.
		#    Nu: elke helft VERIFY_FACTOR x games potjes (24 in totaal), eis
		#    +VERIFY_MARGE (1,0: een extra winst netto) en per helft hooguit
		#    -VERIFY_HELFT_MIN (0,5) achteruit. De referentie speelt dezelfde
		#    (deterministische) reeks, dus dit blijft "beter dan nu".
		var n_half: int = games * VERIFY_FACTOR
		var n_verify: int = n_half * 2
		if not verify_ref.has(d):
			verify_ref[d] = {
				"champ": _verify_round(champ_w, d, profile, doctrines, n_half),
				"base": _verify_round(champ_w, d, baseline, doctrines, n_half),
			}
		var ref: Dictionary = verify_ref[d]
		var ref_tot: float = float(ref.champ) + float(ref.base)
		var verify_champ: float = _verify_round(mean, d, profile, doctrines, n_half)
		var verify_base: float = _verify_round(mean, d, baseline, doctrines, n_half)
		var verify: float = verify_champ + verify_base
		var adopted: bool = verify >= ref_tot + VERIFY_MARGE \
			and verify_champ >= float(ref.champ) - VERIFY_HELFT_MIN \
			and verify_base >= float(ref.base) - VERIFY_HELFT_MIN
		if adopted:
			profile[d] = mean
			adoptions += 1
			afwijzingen_op_rij[d] = 0
			verify_ref.erase(d)  # nieuwe kampioen → nieuwe referentie meten
			sigma[d] = minf(0.35, float(sigma[d]) * 1.15)
			if faction >= 0:
				# Parallel-modus: alleen het eigen factie-bestand schrijven,
				# zodat processen elkaars werk niet overschrijven.
				AIController.save_faction_override(faction, mean)
			else:
				AIController.save_profile(profile)
			# Nieuwe kampioen de pool in; baseline op [0] blijft altijd staan.
			pool.append(_copy_profile(profile))
			if pool.size() > max_pool:
				pool.remove_at(1)
		else:
			afwijzingen_op_rij[d] = int(afwijzingen_op_rij[d]) + 1
			if int(afwijzingen_op_rij[d]) >= SIGMA_RESET_NA:
				# Vast op een plateau: weer breed zoeken in plaats van
				# steeds kleinere kopieen van dezelfde kampioen.
				sigma[d] = 0.25
				afwijzingen_op_rij[d] = 0
			else:
				sigma[d] = maxf(SIGMA_VLOER, float(sigma[d]) * 0.85)
		var elapsed: float = float(Time.get_ticks_msec() - t0) / 60_000.0
		print("[TRAIN] gen %d · %s · beste kandidaat %.1f/%d · verificatie %.1f/%d vs referentie %.1f (kampioen %.1f/%.1f + baseline %.1f/%.1f) → %s · sigma %.2f · %.1f min" % [
			gen, Constants.doctrine_name(d), float(candidates[0].fit), games,
			verify, n_verify, ref_tot, verify_champ, float(ref.champ), verify_base, float(ref.base),
			"GEADOPTEERD 💾" if adopted else "verworpen", float(sigma[d]), elapsed])
		# C15: jagen de kandidaten op dragers? Per potje, over de hele generatie.
		var gen_potjes: float = maxf(1.0, float(pop * games))
		print("[TRAIN] gen %d · %s · buit per potje: %.2f pt + %.2f CP veroverd, %.2f eigen dragers verloren" % [
			gen, Constants.doctrine_name(d), float(gen_buit.pt) / gen_potjes,
			float(gen_buit.cp) / gen_potjes, float(gen_buit.verloren) / gen_potjes])
		# Convergentiecheck (bouwplan §7.4): elke CONV_INTERVAL factie-generaties
		# de huidige kampioen head-to-head (spiegel d-vs-d, VASTE seeds) tegen de
		# kampioen van CONV_INTERVAL generaties terug. ~50% = plateau. Alleen
		# rapportage — de mens beslist over stoppen/doortrainen.
		gen_factie[d] = int(gen_factie.get(d, 0)) + 1
		if not conv_geschiedenis.has(d):
			conv_geschiedenis[d] = []
		var hist: Array = conv_geschiedenis[d]
		hist.append((profile[d] as Dictionary).duplicate())
		if hist.size() > CONV_INTERVAL + 1:
			hist.pop_front()
		if int(gen_factie[d]) % CONV_INTERVAL == 0 and hist.size() > CONV_INTERVAL:
			var conv: float = _convergence_match(profile[d], hist[0], d, train_seed)
			var pct: float = 100.0 * conv / float(CONV_GAMES)
			print("[TRAIN] convergentiecheck %s: nu vs %d gen terug: %.0f%% (%.1f/%d, vaste seeds) — %s" % [
				Constants.doctrine_name(d), CONV_INTERVAL, pct, conv, CONV_GAMES,
				"nog vooruitgang" if pct >= 58.0 else "plateau"])
	print("[TRAIN] Klaar: %d generaties, %d adopties in %.1f min. Profiel: res://data/ai_weights.json" % [
		gen, adoptions, float(Time.get_ticks_msec() - t0) / 60_000.0])
	# Matchup-overzicht: hoe deed de getrainde factie het tegen elke tegenstander?
	# Printen én wegschrijven naar een per-factie bestand (parallel-veilig), zodat
	# je na een nachtrun kunt meten en bijstellen.
	var my_name: String = Constants.doctrine_name(faction) if faction >= 0 else "kampioen"
	var lines: Array = []
	lines.append("Fog of War — trainings-matchup voor %s" % my_name)
	lines.append("Generaties: %d · adopties: %d · minuten: %.1f" % [
		gen, adoptions, float(Time.get_ticks_msec() - t0) / 60_000.0])
	var run_potjes: float = maxf(1.0, float(buit_run.potjes))
	var buit_regel := "Buit op dragers (kandidaten, %d potjes): %.2f pt + %.2f CP per potje veroverd, %.2f eigen dragers per potje verloren" % [
		int(buit_run.potjes), float(buit_run.pt) / run_potjes, float(buit_run.cp) / run_potjes,
		float(buit_run.verloren) / run_potjes]
	lines.append(buit_regel)
	print("[TRAIN] " + buit_regel)
	lines.append("Winrate van %s tegen elke tegenstander-factie (alle trainingspotjes):" % my_name)
	print("[TRAIN] Winrate van %s tegen elke tegenstander-factie (over alle trainingspotjes):" % my_name)
	for od in Constants.DOCTRINE_DATA.keys():
		if matchup.has(od) and matchup[od].g > 0:
			var wr: float = 100.0 * float(matchup[od].w) / float(matchup[od].g)
			var line := "  vs %-7s %5.1f%%  (%d potjes)" % [Constants.doctrine_name(od), wr, int(matchup[od].g)]
			print("[TRAIN] " + line.strip_edges())
			lines.append(line)
	DirAccess.make_dir_recursive_absolute("res://data")
	var fname := "res://data/matchup_%s.txt" % (my_name.to_lower() if faction >= 0 else "champion")
	var f := FileAccess.open(fname, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines) + "\n")
	print("[TRAIN] Matchup-log opgeslagen → %s" % fname)


# =========================================================================
# Arena: "wie wint tegen wie" — winrate-matrix over alle doctrine-matchups
# =========================================================================

## Speelt elke (rij-doctrine vs kolom-doctrine) `per` keer met het huidige profiel,
## kant gewisseld voor eerlijkheid. Print een winrate-matrix + een ranglijst en
## schrijft alles naar data/arena_results.txt. Puur meten, geen training.
func _run_arena(per: int, level: String) -> void:
	var paths := {
		"easy": "res://scripts/ai/AIEasy.gd", "medium": "res://scripts/ai/AIMedium.gd",
		"hard": "res://scripts/ai/AIHard.gd", "ultra": "res://scripts/ai/AIUltra.gd",
	}
	var ai_script = load(paths.get(level, paths["medium"]))
	var profile: Dictionary = AIController.load_profile()
	if profile.is_empty():
		profile = AIController.default_profile()
		print("[ARENA] Geen opgeslagen profiel — meet met de defaults.")
	else:
		print("[ARENA] Meet met het opgeslagen per-factie-profiel.")
	var doctrines: Array = Constants.DOCTRINE_DATA.keys()
	var n := doctrines.size()
	# win[i][j] = aantal keer dat rij-doctrine i wint van kolom-doctrine j.
	var win: Array = []
	var played: Array = []
	for i in n:
		win.append([]); played.append([])
		for j in n:
			win[i].append(0); played[i].append(0)
	var wins_total := {}
	var games_total := {}
	for d in doctrines:
		wins_total[d] = 0; games_total[d] = 0
	var t0 := Time.get_ticks_msec()
	# Alle potjes als losse jobs, daarna PARALLEL over een threadpool (64-cores-route).
	var jobs: Array = []
	for i in n:
		for j in n:
			for g in per:
				jobs.append({
					"i": i, "j": j, "i_is_p1": g % 2 == 0,
					"wi": (profile[doctrines[i]] as Dictionary).duplicate(),
					"wj": (profile[doctrines[j]] as Dictionary).duplicate(),
					"di": int(doctrines[i]), "dj": int(doctrines[j]),
				})
	var workers: int = mini(16, jobs.size())
	print("[ARENA] %d doctrines · %d potjes/richting · %d potjes totaal · %s · %d threads ..." % [
		n, per, jobs.size(), level, workers])
	# Verdeel round-robin over de workers.
	var buckets: Array = []
	for w in workers:
		buckets.append([])
	for idx in jobs.size():
		buckets[idx % workers].append(jobs[idx])
	var threads: Array = []
	for w in workers:
		var th := Thread.new()
		th.start(_arena_games_threaded.bind(buckets[w], ai_script))
		threads.append(th)
	for th in threads:
		for r in th.wait_to_finish():
			var i: int = r.i
			var j: int = r.j
			played[i][j] += 1
			games_total[doctrines[i]] += 1
			games_total[doctrines[j]] += 1
			if r.pts >= 1.0:
				win[i][j] += 1
				wins_total[doctrines[i]] += 1
			elif r.pts <= 0.0:
				wins_total[doctrines[j]] += 1
	print("[ARENA]   alle potjes gespeeld (%.1f min)" % [float(Time.get_ticks_msec() - t0) / 60_000.0])

	# --- Matrix opbouwen (rij wint % tegen kolom) ---
	var lines: Array = []
	lines.append("Fog of War — arena winrate-matrix (%s, %d potjes/richting)" % [level, per])
	lines.append("Rij wint-%% tegen kolom. Spiegels (diagonaal) horen rond 50%%.")
	lines.append("")
	var header := "         "
	for j in n:
		header += "%-8s" % Constants.doctrine_name(doctrines[j]).substr(0, 7)
	lines.append(header)
	for i in n:
		var row := "%-9s" % Constants.doctrine_name(doctrines[i])
		for j in n:
			var pct := 0.0
			if played[i][j] > 0:
				pct = 100.0 * float(win[i][j]) / float(played[i][j])
			row += "%-8s" % ("%d%%" % int(round(pct)))
		lines.append(row)
	lines.append("")
	# --- Ranglijst (algehele winrate over alle matchups) ---
	var rank: Array = []
	for d in doctrines:
		var wr := 0.0
		if games_total[d] > 0:
			wr = 100.0 * float(wins_total[d]) / float(games_total[d])
		rank.append({"name": Constants.doctrine_name(d), "wr": wr, "n": games_total[d]})
	rank.sort_custom(func(a, b): return a.wr > b.wr)
	lines.append("Ranglijst (algehele winrate):")
	for r in rank:
		lines.append("  %-7s %5.1f%%  (%d potjes)" % [r.name, r.wr, r.n])

	var text := "\n".join(lines)
	print("\n" + text + "\n")
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open("res://data/arena_results.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
	print("[ARENA] Klaar in %.1f min → data/arena_results.txt" % [float(Time.get_ticks_msec() - t0) / 60_000.0])


## Eén verificatieronde: `games` potjes parallel (1 thread per potje) van de
## uitdager-gewichten tegen één tegenstander-profiel; tegenstander-facties
## round-robin, kant om en om. Retour: behaalde punten (win=1, gelijk=0.5).
func _verify_round(cand_w: Dictionary, cand_d: int, opp_profile: Dictionary,
		doctrines: Array, games: int) -> float:
	# Hooguit VERIFY_THREADS threads tegelijk: meer GDScript-threads vechten om
	# de allocator en maken het trager (gemeten 19 september: 12 tegelijk
	# verdubbelde de generatietijd, 14,6 -> 28,8 min). De potjes worden dus in
	# rondes gespeeld; de reeks (tegenstander-factie en kant per index) blijft
	# dezelfde, dus de referentie blijft geldig.
	var pts: float = 0.0
	var g0: int = 0
	while g0 < games:
		var threads: Array = []
		for g in range(g0, mini(games, g0 + VERIFY_THREADS)):
			var opp_d: int = doctrines[g % doctrines.size()]
			var vjobs: Array = [{
				"cand_w": cand_w, "cand_d": cand_d,
				"opp_w": opp_profile[opp_d], "opp_d": opp_d,
				"cand_is_p1": g % 2 == 0,
			}]
			var thread := Thread.new()
			thread.start(_eval_games_threaded.bind(vjobs))
			threads.append(thread)
		for t in threads:
			pts += float(t.wait_to_finish().fit)
		g0 += VERIFY_THREADS
	return pts


## Arena thread-werker: speelt een lijst potjes en geeft per potje {i, j, pts}
## terug (pts vanuit rij-doctrine i: 1 = win, 0.5 = gelijk, 0 = verlies).
func _arena_games_threaded(jobs: Array, ai_script) -> Array:
	var out: Array = []
	for job in jobs:
		var ai_i = ai_script.new()
		ai_i.weights = job.wi
		var ai_j = ai_script.new()
		ai_j.weights = job.wj
		var a1 = ai_i if job.i_is_p1 else ai_j
		var a2 = ai_j if job.i_is_p1 else ai_i
		var d1: int = job.di if job.i_is_p1 else job.dj
		var d2: int = job.dj if job.i_is_p1 else job.di
		var runner := MatchRunner.new(a1, a2, d1, d2, 0, _train_rules)
		# V0 (3 augustus): de noodstop levert geen uitslag meer op, dus hij moet
		# ruim boven de echte partijduur liggen. Gemeten met honger vanaf cyclus
		# 10 over 216 partijen: mediaan 608 stappen, p90 737, max 932.
		runner.max_steps = 1400
		while not runner.done:
			runner.step()
		var winner: int = runner.winner
		runner.dispose()
		var i_side: int = Constants.PLAYER_1 if job.i_is_p1 else Constants.PLAYER_2
		var pts: float = 0.5
		if winner == i_side:
			pts = 1.0
		elif winner != -1:
			pts = 0.0
		out.append({"i": job.i, "j": job.j, "pts": pts})
	return out


## Diepe kopie van een profiel (doctrine -> weights-dict).
func _copy_profile(profile: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for d in profile:
		out[d] = (profile[d] as Dictionary).duplicate()
	return out


## Thread-werker: speel een lijst potjes en geef {fit, tally}. tally telt per
## tegenstander-doctrine de gewonnen punten en potjes ("wie wint tegen wie").
## Alles wat de thread aanraakt is eigen state (elke match z'n eigen engine);
## de gedeelde gewichten-dicts worden alleen gelezen (en in _train_match gedupliceerd).
func _eval_games_threaded(jobs: Array) -> Dictionary:
	var fit: float = 0.0
	var tally: Dictionary = {}
	var buit: Dictionary = {"pt": 0, "cp": 0, "verloren": 0}
	for job in jobs:
		var uit: Dictionary = _train_match(job.cand_w, job.cand_d, job.opp_w, job.opp_d, job.cand_is_p1)
		var s: float = float(uit.score)
		fit += s
		for bk in ["pt", "cp", "verloren"]:
			buit[bk] += int(uit[bk])
		var od: int = int(job.opp_d)
		if not tally.has(od):
			tally[od] = {"w": 0.0, "g": 0}
		tally[od].w += s
		tally[od].g += 1
	return {"fit": fit, "tally": tally, "buit": buit}


## Speel één headless potje. Retour {score, pt, cp, verloren}: score 1.0 =
## kandidaat wint, 0.5 = gelijk, 0.0 = verlies (onder v4.2 de campagne-
## fitness uit CampagneFitness), pt/cp = wat de kandidaat op dragers
## veroverde, verloren = zijn eigen neergelegde dragers (C15, 7 september).
func _train_match(cand_w: Dictionary, cand_d: int, opp_w: Dictionary, opp_d: int, cand_is_p1: bool) -> Dictionary:
	var ca = TRAIN_AI.new()
	ca.weights = cand_w.duplicate()
	var oa = TRAIN_AI.new()
	oa.weights = opp_w.duplicate()
	var a1 = ca if cand_is_p1 else oa
	var a2 = oa if cand_is_p1 else ca
	var d1: int = cand_d if cand_is_p1 else opp_d
	var d2: int = opp_d if cand_is_p1 else cand_d
	var runner := MatchRunner.new(a1, a2, d1, d2, 0, _train_rules)
	# Patstellingen kosten anders tot 2500 stappen per potje; echte partijen zijn
	# rond ~350 klaar. De tiebreak (materiaal → haven) geeft hetzelfde leersignaal.
	runner.max_steps = 1400  # V0: gemeten max 932 stappen met honger vanaf 10
	while not runner.done:
		runner.step()
	var winner: int = runner.winner
	var cand_side: int = Constants.PLAYER_1 if cand_is_p1 else Constants.PLAYER_2
	var buit: Dictionary = runner.buit[cand_side]
	var score: float
	if _train_rules != null and _train_rules.campaign_actief():
		score = CampagneFitness.score(runner.state(), cand_side, winner, buit)
	else:
		score = 0.5 if winner == -1 else (1.0 if winner == cand_side else 0.0)
	runner.dispose()
	return {"score": score, "pt": int(buit.pt), "cp": int(buit.cp), "verloren": int(buit.verloren)}


## Convergentie-potjes: spiegel-partijen (beide kanten factie d) met VASTE
## seeds — zelfde run-seed geeft exact dezelfde meetreeks. Retour: punten
## voor de nieuwe kampioen (1 / 0.5 / 0 per potje), kanten wisselend.
func _convergence_match(nieuw_w: Dictionary, oud_w: Dictionary, d: int, run_seed: int) -> float:
	var threads: Array = []
	for g in CONV_GAMES:
		var thread := Thread.new()
		thread.start(_conv_game.bind(nieuw_w, oud_w, d, g % 2 == 0, 910000 + run_seed * 31 + g))
		threads.append(thread)
	var pts: float = 0.0
	for t in threads:
		pts += float(t.wait_to_finish())
	return pts


func _conv_game(nieuw_w: Dictionary, oud_w: Dictionary, d: int, nieuw_is_p1: bool, seed_val: int) -> float:
	var na = TRAIN_AI.new()
	na.weights = nieuw_w.duplicate()
	var oa = TRAIN_AI.new()
	oa.weights = oud_w.duplicate()
	var a1 = na if nieuw_is_p1 else oa
	var a2 = oa if nieuw_is_p1 else na
	var runner := MatchRunner.new(a1, a2, d, d, seed_val, _train_rules)
	runner.max_steps = 1400  # V0: gemeten max 932 stappen met honger vanaf 10
	while not runner.done:
		runner.step()
	var winner: int = runner.winner
	runner.dispose()
	if winner == -1:
		return 0.5
	var kant: int = Constants.PLAYER_1 if nieuw_is_p1 else Constants.PLAYER_2
	return 1.0 if winner == kant else 0.0


## Richtingcheck: voet -> teen (links en rechts gemiddeld), heup -> nek en de
## op-as, in wereldruimte, uit het skelet van het stuk. Leeg als er geen
## voet- en teenbotten zijn.
func _rc_meet(pv: PawnView) -> Dictionary:
	if pv._piece == null:
		return {}
	var skels: Array = pv._piece.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return {}
	var sk: Skeleton3D = skels[0]
	sk.force_update_all_bone_transforms()
	var pos: Dictionary = {}
	for i in sk.get_bone_count():
		var naam: String = sk.get_bone_name(i).to_lower()
		var wereld: Vector3 = (sk.global_transform * sk.get_bone_global_pose(i)).origin
		for deel in ["leftfoot", "lefttoebase", "rightfoot", "righttoebase", "hips", "neck", "head"]:
			if naam.ends_with(deel):   # mixamorig:LeftFoot, mixamorig_LeftFoot, LeftFoot
				pos[deel] = wereld
	var voet := Vector3.ZERO
	var n := 0
	for kant in ["left", "right"]:
		if pos.has(kant + "foot") and pos.has(kant + "toebase"):
			var d: Vector3 = pos[kant + "toebase"] - pos[kant + "foot"]
			d.y = 0.0
			if d.length() > 0.0001:
				voet += d.normalized()
				n += 1
	if n == 0:
		return {}
	voet = (voet / float(n)).normalized()
	var romp := Vector3.ZERO
	var omhoog := 0.0
	if pos.has("hips") and pos.has("neck"):
		var r: Vector3 = pos["neck"] - pos["hips"]
		omhoog = r.normalized().y
		r.y = 0.0
		romp = r.normalized() if r.length() > 0.0001 else Vector3.ZERO
	return {"voet": voet, "romp": romp, "omhoog": omhoog}


## Beurtlicht: zetten doen (de bot speelt zijn beurten zelf) tot de mens aan
## de beurt is met hooguit `doel` pionnen die nog kunnen; false als de
## actiefase eerder afloopt of de tijd op is.
func _bl_speel_tot(g, doel: int, budget_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	var zetten := 0
	while Time.get_ticks_msec() - t0 < budget_s * 1000.0:
		var st: GameState = GameSession.state
		if st.phase != Phase.Type.ACTION:
			return false
		if st.current_player == 1:
			g._refresh_all()
			if _bl_meet(g)[0] <= doel:
				return true
			zetten += 1
			if zetten > 80:
				return false
			g._auto_action_human()
		await get_tree().create_timer(0.1).timeout
	return false


## Beurtlicht: [pionnen van de mens die nog kunnen, stralen aan, stralen die niet kloppen].
func _bl_meet(g) -> Array:
	var st: GameState = GameSession.state
	var kunnen := 0
	var aan := 0
	var fout := 0
	var drempel: int = int(round(PawnView.fx("beurt_licht_vanaf", 3.0)))
	var eigen_kunnen: Array = []
	for pid in st.pawns:
		var p: Pawn = st.pawns[pid]
		if p.owner_id == 1 and not p.is_eliminated and p.is_active and Rules.can_pawn_act(st, int(pid)):
			eigen_kunnen.append(int(pid))
	kunnen = eigen_kunnen.size()
	var hoort: bool = PawnView.fx("beurt_licht", 1.0) > 0.0 and drempel > 0 and kunnen <= drempel \
			and st.phase == Phase.Type.ACTION and st.current_player == 1
	for pid in g._pawn_views:
		var pv: PawnView = g._pawn_views[pid]
		if pv._beurt_licht_aan:
			aan += 1
		var verwacht: bool = hoort and eigen_kunnen.has(int(pid))
		if pv._beurt_licht_aan != verwacht:
			fout += 1
	return [kunnen, aan, fout]


## Sleepcheck: een muisknop indrukken of loslaten op een schermpunt, als echt event.
func _sc_muis(pos: Vector2, ingedrukt: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = ingedrukt
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame


## Sleepcheck: de muis in stappen van a naar b bewegen (elke stap een frame).
func _sc_beweeg(van: Vector2, naar: Vector2, stappen: int) -> void:
	for i in range(1, stappen + 1):
		var ev := InputEventMouseMotion.new()
		ev.position = van.lerp(naar, float(i) / float(stappen))
		ev.global_position = ev.position
		ev.relative = (naar - van) / float(stappen)
		Input.parse_input_event(ev)
		await get_tree().process_frame
	await get_tree().process_frame


## Sleepcheck: wachten tot de mens aan de beurt is in de koppel-fase (de bot
## koppelt tussendoor); false als dat binnen 6 s niet gebeurt.
func _sc_wacht_op_beurt() -> bool:
	var wacht := 0.0
	while wacht < 6.0:
		var st: GameState = GameSession.state
		if Phase.is_linking(st.phase) and st.current_player == 1:
			return true
		if not Phase.is_linking(st.phase):
			return false
		await get_tree().create_timer(0.05).timeout
		wacht += 0.05
	return false


## Ouderketen van een node tot aan de wereld, voor de zweefcheck.
func _zweef_keten(n: Node, wereld: Node) -> String:
	var keten: Array = []
	var k: Node = n
	while k != null and k != wereld:
		keten.append(k.name + ("(" + k.get_class() + ")" if not (k is MeshInstance3D) else ""))
		k = k.get_parent()
	return " < ".join(keten)


func _click_at(pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	get_viewport().push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	get_viewport().push_input(up)


# =========================================================================
# Sim-helpers (F0.4a): één herbruikbare partij-runner voor sim en simcheck
# =========================================================================

func _sim_doctrine(naam: String) -> int:
	var doctrine_names := {
		"mens": Constants.Doctrine.MENS, "varken": Constants.Doctrine.MENS,
		"muis": Constants.Doctrine.MUIS,
		"leeuw": Constants.Doctrine.LEEUW,
		"beer": Constants.Doctrine.BEER,
		"wolf": Constants.Doctrine.WOLF,
		"vos": Constants.Doctrine.VOS, "krokodil": Constants.Doctrine.VOS,
	}
	return doctrine_names.get(String(naam).to_lower(), Constants.Doctrine.MENS)


## Volledige AI-vs-AI-partij op de GameSession-autoload; synchroon.
## Retourneert {winner, cyclus, acties, guard}.
## Verse RulesConfig per sim: de config wordt tijdens een partij aangeraakt
## (pools/cp), dus elke sim krijgt zijn eigen kopie uit hetzelfde bestand.
func rj_kopie(pad: String) -> Dictionary:
	if pad == "" or not FileAccess.file_exists(pad):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(pad))
	return d if d is Dictionary else {}


func _run_sim(n1: String, n2: String, d1: int, d2: int, sim_seed: int, sim_rules: RulesConfig, record_path: String = "") -> Dictionary:
	var paths := {
		"easy": "res://scripts/ai/AIEasy.gd",
		"medium": "res://scripts/ai/AIMedium.gd",
		"hard": "res://scripts/ai/AIHard.gd",
		"ultra": "res://scripts/ai/AIUltra.gd",
	}
	var a1 = load(paths.get(n1, paths["medium"])).new()
	a1.player_id = 1
	var a2 = load(paths.get(n2, paths["medium"])).new()
	a2.player_id = 2
	var sim_rng := SeededRng.new(sim_seed)
	a1.rng = sim_rng.fork("p1")
	a2.rng = sim_rng.fork("p2")
	GameSession.start_new_game(d1, d2, sim_rules)
	if record_path != "":
		GameSession.match_log = MatchLog.new()
		GameSession.match_log.setup(GameSession.state, {"p1": n1, "p2": n2,
			"d1": Constants.doctrine_name(d1), "d2": Constants.doctrine_name(d2), "seed": sim_seed})
	GameSession.submit_placement(1, a1.choose_placement(GameSession.state))
	GameSession.submit_placement(2, a2.choose_placement(GameSession.state))
	var acts := 0
	var guard := 0
	while GameSession.state.phase != Phase.Type.GAME_OVER and guard < 8000:
		guard += 1
		var st: GameState = GameSession.state
		var ph: int = st.phase
		var cur = a1 if st.current_player == 1 else a2
		if ph == Phase.Type.CYCLE_SPAWN:
			# Leerbaar (opdracht Max): spawn-beleid uit de gewichten.
			for pid in [1, 2]:
				if st.spawn_done.get(pid, false):
					continue
				var spawner = a1 if pid == 1 else a2
				GameSession.submit_spawn(pid, spawner.choose_spawn(st))
		elif Phase.is_define(ph):
			for pid in [1, 2]:
				if st.cards_defined[pid].size() > 0 or Validator.expected_define_count(st, pid) == 0:
					continue
				var bot = a1 if pid == 1 else a2
				# Leerbaar CP-beleid (cp_bet_r1..r3).
				var bet: int = bot.choose_cp_bet(st)
				if bet > 0:
					GameSession.submit_bet_cp(pid, bet)
				var cards: Array = bot.generate_cards(st)
				for i in mini(bet, cards.size()):
					cards[i].hp = int(cards[i].hp) + 1
				if not GameSession.submit_define_cards(pid, cards) and bet > 0:
					for i in mini(bet, cards.size()):
						cards[i].hp = int(cards[i].hp) - 1
					GameSession.submit_define_cards(pid, cards)
		elif Phase.is_reveal(ph):
			GameSession.acknowledge_reveal()
		elif Phase.is_linking(ph):
			var link = cur.choose_link(st)
			if link.has("card_id"):
				if not GameSession.submit_link(st.current_player, link.card_id, link.pawn_id):
					print("[SIM-LINKFAIL] beurt=%d kaart=%d pion=%d" % [st.current_player, link.card_id, link.pawn_id])
					break
			else:
				print("[SIM-LINKBREAK] beurt=%d ronde=%d" % [st.current_player, st.round_number])
				break
		elif ph == Phase.Type.ACTION:
			if st.pending_wolf_step_pawn != -1:
				var step: Dictionary = cur.choose_wolf_step(st)
				if step.has("target"):
					GameSession.submit_wolf_step(st.current_player, step.target)
				else:
					GameSession.skip_wolf_step(st.current_player)
				continue
			var act = cur.choose_action(st)
			if act.is_empty():
				print("[SIM-BREAK] fase=%s beurt=%d can_act=%s actief=%d" % [
					Phase.to_string_phase(st.phase), st.current_player,
					str(Rules.can_player_act(st, st.current_player)),
					st.get_active_pawns_for(st.current_player).size()])
				break
			acts += 1
			# F2.5/B3: onder campaign spreekt artillerie CANNON_ACT.
			var sim_camp: bool = st.rules.campaign_actief()
			match String(act.type):
				"move":
					var loper: Pawn = st.pawns.get(int(act.pawn_id), null)
					if sim_camp and loper != null and loper.unit_type == Constants.UnitType.ARTILLERY:
						GameSession.submit_cannon_roll(st.current_player, act.pawn_id, act.target)
					else:
						GameSession.submit_move(st.current_player, act.pawn_id, act.target)
				"attack":
					GameSession.submit_attack(st.current_player, act.attacker_id, act.defender_id)
				"shot":
					var schutter: Pawn = st.pawns.get(int(act.shooter_id), null)
					if sim_camp and schutter != null and schutter.unit_type == Constants.UnitType.ARTILLERY:
						GameSession.submit_cannon_shoot(st.current_player, act.shooter_id, act.target_id)
					else:
						GameSession.submit_shot(st.current_player, act.shooter_id, act.target_id)
				"charge":
					GameSession.submit_charge(st.current_player, act.pawn_id, act.move_target, act.defender_id)
	var uitkomst := {"winner": GameSession.state.winner, "cyclus": GameSession.state.cycle, "acties": acts, "guard": guard}
	if record_path != "" and GameSession.match_log != null:
		uitkomst["entries"] = GameSession.match_log.entries.size()
		GameSession.match_log.save(record_path, GameSession.state)
		GameSession.match_log = null
	return uitkomst

# =========================================================================
# Golden replays (F0.7): 6 sim-partijen + 6 handgeschreven randgevallen
# =========================================================================

func _make_goldens() -> void:
	var dir := "res://tests/golden_replays/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	# 1-6: per doctrine één volledige partij (easy vs easy, vaste seeds).
	var docs: Array = [["mens", 11], ["muis", 22], ["leeuw", 33], ["beer", 44], ["wolf", 55], ["vos", 66]]
	var tegen: Array = ["vos", "leeuw", "wolf", "muis", "beer", "mens"]
	for i in docs.size():
		var naam: String = docs[i][0]
		var pad: String = dir + "sim_%s.json" % naam
		var ru: Dictionary = _run_sim("easy", "easy", _sim_doctrine(naam), _sim_doctrine(String(tegen[i])), int(docs[i][1]), null, pad)
		print("[GOLDENS] %s: winner=%d acties=%d" % [pad, ru.winner, ru.acties])
	# 7-12: randgevallen op geconstrueerde staten.
	_golden_terugslag_doodt_aanvaller(dir)
	_golden_wolf_stap_in_haven_wint(dir)
	_golden_charge_kill_verplichte_verplaatsing(dir)
	_golden_vos_onthulling_bij_schade(dir)
	_golden_kaart_vervalt_zonder_pion(dir)
	_golden_honger(dir)
	_golden_spawn_geblokkeerd(dir)
	_golden_cp_inzet(dir)
	_golden_kanon_act(dir)
	print("[GOLDENS] klaar")


## Neem een handgeschreven actielijst op: [[action, player], ...].
func _golden_opnemen(pad: String, s: GameState, acties: Array) -> void:
	var log := MatchLog.new()
	log.setup(s)
	for a in acties:
		var res: Dictionary = Reducer.apply(s, a[0], a[1])
		if not res.ok:
			print("[GOLDENS] FOUT bij %s: %s" % [pad, res.error])
			return
		log.record(a[1], a[0], res.events, s)
	log.save(pad, s)
	print("[GOLDENS] %s: %d acties" % [pad, acties.size()])


func _golden_actieve_pion(s: GameState, owner: int, pos: Vector2i, unit_type: int, hp: int, spd: int, atk: int) -> Pawn:
	var pawn: Pawn = s._spawn_pawn(owner, pos, unit_type)
	var card := Card.new(s.next_card_id(), owner, s.round_number, hp, spd, atk)
	s.all_cards[card.id] = card
	pawn.link_card(card)
	return pawn


func _golden_terugslag_doodt_aanvaller(dir: String) -> void:
	# Aanvaller (1 HP) slaat een overlevende cavalerist: terugslag 2 → aanvaller dood.
	var s := GameState.new()
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var aanvaller := _golden_actieve_pion(s, 1, Vector2i(5, 5), Constants.UnitType.INFANTRY, 1, 2, 1)
	var cav := _golden_actieve_pion(s, 2, Vector2i(5, 4), Constants.UnitType.CAVALRY, 5, 2, 1)
	s._spawn_pawn(1, Vector2i(0, 10))  # reserve zodat de partij niet meteen eindigt
	_golden_opnemen(dir + "terugslag_doodt_aanvaller.json", s,
		[[Actions.make_melee(aanvaller.id, cav.id), 1]])


func _golden_wolf_stap_in_haven_wint(dir: String) -> void:
	# Wolf slaat, overleeft de terugslag en stapt gratis de haven in → winst.
	var s := GameState.new()
	s.doctrines[Constants.PLAYER_1] = Constants.Doctrine.WOLF
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	s._spawn_pawn(1, Vector2i(0, 0))  # al in de haven
	var wolf := _golden_actieve_pion(s, 1, Vector2i(4, 1), Constants.UnitType.INFANTRY, 3, 2, 1)
	var vijand := _golden_actieve_pion(s, 2, Vector2i(3, 1), Constants.UnitType.INFANTRY, 5, 2, 1)
	s._spawn_pawn(2, Vector2i(10, 10))
	_golden_opnemen(dir + "wolf_stap_in_haven_wint.json", s, [
		[Actions.make_melee(wolf.id, vijand.id), 1],
		[Actions.make_wolf_step(Vector2i(4, 0)), 1],
	])


func _golden_charge_kill_verplichte_verplaatsing(dir: String) -> void:
	# Charge: 2 stappen + kill → verplichte verplaatsing naar het vrijgekomen vak.
	var s := GameState.new()
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var cav := _golden_actieve_pion(s, 1, Vector2i(5, 7), Constants.UnitType.CAVALRY, 3, 3, 5)
	var doel := _golden_actieve_pion(s, 2, Vector2i(5, 4), Constants.UnitType.INFANTRY, 2, 2, 1)
	s._spawn_pawn(2, Vector2i(10, 10))
	_golden_opnemen(dir + "charge_kill_verplichte_verplaatsing.json", s,
		[[Actions.make_charge(cav.id, Vector2i(5, 5), doel.id), 1]])


func _golden_vos_onthulling_bij_schade(dir: String) -> void:
	# Gedekte Krokodil-pion wordt beschoten: onthulling vóór de schade.
	var s := GameState.new()
	s.doctrines[Constants.PLAYER_2] = Constants.Doctrine.VOS
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var schutter := _golden_actieve_pion(s, 1, Vector2i(5, 5), Constants.UnitType.INFANTRY, 3, 2, 2)
	var gedekt := _golden_actieve_pion(s, 2, Vector2i(5, 3), Constants.UnitType.INFANTRY, 5, 2, 1)
	gedekt.card_revealed = false
	s.cards_revealed[2] = [s.all_cards[gedekt.linked_card_id]]
	s._spawn_pawn(2, Vector2i(10, 10))
	_golden_opnemen(dir + "vos_onthulling_bij_schade.json", s,
		[[Actions.make_shoot(schutter.id, gedekt.id), 1]])


func _golden_kaart_vervalt_zonder_pion(dir: String) -> void:
	# Koppelfase: 2 kaarten, 1 vrije pion → de tweede kaart vervalt, de ronde
	# schuift door naar de volgende define.
	var s := GameState.new()
	s.phase = Phase.linking_for_round(1)
	s.current_player = 1
	s.initiative_player = 1
	var vrij: Pawn = s._spawn_pawn(1, Vector2i(5, 9))
	var c1 := Card.new(s.next_card_id(), 1, 1, 3, 2, 2)
	var c2 := Card.new(s.next_card_id(), 1, 1, 2, 2, 3)
	s.all_cards[c1.id] = c1
	s.all_cards[c2.id] = c2
	s.cards_revealed[1] = [c1, c2]
	s._spawn_pawn(2, Vector2i(5, 1))  # P2 heeft geen koppelwerk
	_golden_opnemen(dir + "kaart_vervalt_zonder_pion.json", s,
		[[Actions.make_link(c1.id, vrij.id), 1]])


func _golden_honger(dir: String) -> void:
	# V0: de uitputtingsklok. Dezelfde gespiegelde stand die vroeger een remise
	# gaf, eindigt nu beslissend: de honger eet om de beurt en er komt altijd
	# een winnaar uit. Deze golden bewaakt precies dat.
	var s := GameState.new()
	s.rules = RulesConfig.new()
	s.rules.honger_vanaf_cyclus = 1
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var mover := _golden_actieve_pion(s, 1, Vector2i(5, 8), Constants.UnitType.INFANTRY, 3, 1, 1)
	s._spawn_pawn(1, Vector2i(2, 10))   # achterhoede: die verhongert het eerst
	s._spawn_pawn(2, Vector2i(5, 3))
	s._spawn_pawn(2, Vector2i(8, 0))
	_golden_opnemen(dir + "honger.json", s,
		[[Actions.make_move(mover.id, Vector2i(5, 7)), 1]])


func _golden_spawn_geblokkeerd(dir: String) -> void:
	# v4.2 (F2.2): cycluseinde onder campaign → RESET (administratie) → blinde
	# CYCLE_SPAWN. P1 mikt met zijn tweede spawn op een bezet achterste-rij-vak:
	# bij de reveal wordt die ene spawn geweigerd en blijft de pion in de pool
	# (D6). Eindstaat: SETUP_1_DEFINE van cyclus 2 met 1 nieuwe P1-pion.
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {}})  # F2.1-defaults, versie 4.2.0
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var mover := _golden_actieve_pion(s, 1, Vector2i(5, 8), Constants.UnitType.INFANTRY, 3, 1, 1)
	s._spawn_pawn(1, Vector2i(5, 10))  # bezet het doelvak van de tweede spawn
	s._spawn_pawn(2, Vector2i(5, 1))
	s.init_pools()
	_golden_opnemen(dir + "spawn_geblokkeerd.json", s, [
		[Actions.make_move(mover.id, Vector2i(5, 7)), 1],
		[Actions.make_spawn([
			{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(4, 10)},
			{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(5, 10)},
		]), 1],
		[Actions.make_spawn([]), 2],
	])


func _golden_cp_inzet(dir: String) -> void:
	# v4.2 (F2.3): blinde CP-inzet -> kaart met budget+1 -> reveal met
	# cp_admin-ledger; het extra punt in Aanval wint het initiatief (D3).
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {}})
	s.phase = Phase.Type.SETUP_1_DEFINE
	s.current_player = 1
	s._spawn_pawn(1, Vector2i(5, 9))
	s._spawn_pawn(2, Vector2i(5, 1))
	s.init_pools()
	var b: int = int(s.doctrine_data_of(1).budget)
	_golden_opnemen(dir + "cp_inzet.json", s, [
		[Actions.make_bet_cp(1), 1],
		[Actions.make_define_cards([{"hp": b - 2, "stamina": 1, "attack": 2}]), 1],
		[Actions.make_define_cards([{"hp": b - 2, "stamina": 1, "attack": 1}]), 2],
	])


func _golden_kanon_act(dir: String) -> void:
	# v4.2 (F2.4): kanon rolt 1 vak en schiet dan een standbeeld kapot via
	# CANNON_ACT (P2 kan niets, dus P1 houdt de beurt). P2 verliest NIET:
	# bord + pool telt (F2.2). RETREAT bestaat niet (D9).
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {}})
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var kanon := _golden_actieve_pion(s, 1, Vector2i(5, 6), Constants.UnitType.ARTILLERY, 2, 3, 2)
	var doel: Pawn = s._spawn_pawn(2, Vector2i(5, 3))  # standbeeld in de vuurlijn
	s._spawn_pawn(2, Vector2i(10, 10))
	s._spawn_pawn(1, Vector2i(0, 10))
	s.init_pools()
	_golden_opnemen(dir + "kanon_act.json", s, [
		[Actions.make_cannon_roll(kanon.id, Vector2i(5, 5)), 1],
		[Actions.make_cannon_shoot(kanon.id, doel.id), 1],
	])


## Eén melee-scenario voor `-- meleecheck`: een aanvaller van het gegeven
## type stoot een aangrenzende infanterist met 1 HP neer. Meet of er een
## melee-clip speelt en of de opruk op het choreografie-moment begint (blijft
## hij op zijn vak staan tot stoot-frame + opruk-vertraging). Sinds
## 26 augustus draait dit ook voor CAVALERIE (Max: "alle cav maken ook
## gebruik van hun wapen"): het ingebakken wapen zwaait in die clips mee.
func _meleecheck_scenario(game, st3: GameState, unit_type: int, naam: String) -> bool:
	# Staat kan door het vorige scenario verschoven zijn (beurtwissel na de
	# kill): terugzetten. Dit is een KIJK-meting, geen regel-partij.
	st3.current_player = 1
	if st3.phase != Phase.Type.ACTION:
		st3.phase = Phase.Type.ACTION
	var aanvaller: Pawn = null
	var slachtoffer: Pawn = null
	for pawn in st3.pawns.values():
		if pawn.is_eliminated or not pawn.is_active:
			continue
		if pawn.owner_id == st3.current_player and aanvaller == null \
				and pawn.unit_type == unit_type:
			aanvaller = pawn
		elif pawn.owner_id != st3.current_player and slachtoffer == null \
				and pawn.unit_type == Constants.UnitType.INFANTRY:
			slachtoffer = pawn
	if aanvaller == null:
		# Niet actief gekoppeld geraakt in de opzet (de koppel-lus pakt de
		# eerste de beste pionnen): forceer er een. De validator eist alleen
		# actief + stamina, en dit meet de kijk-kant.
		for pawn in st3.pawns.values():
			if not pawn.is_eliminated and pawn.owner_id == st3.current_player \
					and pawn.unit_type == unit_type:
				aanvaller = pawn
				aanvaller.is_active = true
				break
	if slachtoffer == null:
		for pawn in st3.pawns.values():
			if not pawn.is_eliminated and pawn.owner_id != st3.current_player \
					and pawn.unit_type == Constants.UnitType.INFANTRY:
				slachtoffer = pawn
				slachtoffer.is_active = true
				break
	if aanvaller == null or slachtoffer == null:
		print("[MELEE][%s] geen bruikbaar paar gevonden" % naam)
		return false
	aanvaller.remaining_stamina = maxi(aanvaller.remaining_stamina, 2)
	var van := Vector2i(5, 5)
	var naar := Vector2i(5, 4)
	for bezet in st3.pawns.values():
		if bezet != aanvaller and bezet != slachtoffer and not bezet.is_eliminated \
				and (bezet.position == van or bezet.position == naar):
			st3.set_pawn_position(bezet, Vector2i(0, 0) if bezet.position != Vector2i(0, 0) else Vector2i(10, 9))
	st3.set_pawn_position(aanvaller, van)
	st3.set_pawn_position(slachtoffer, naar)
	slachtoffer.current_hp = 1
	game._refresh_all()
	await get_tree().create_timer(0.3).timeout
	# Zelfde rekensom als game.gd: de dood-clip speelt op death_speed, en de
	# opruk wacht op stoot-frame + opruk-vertraging (vast, 30 juli).
	var dood_dur := 0.0
	var def_view = game._pawn_views.get(slachtoffer.id)
	var atk_voor = game._pawn_views.get(aanvaller.id)
	if def_view != null:
		var dsp2: float = def_view.melee_fx("death_speed", "death_speed", 1.0)
		dood_dur = def_view.clip_duration("die") / maxf(dsp2, 0.01)
	var hit_del2: float = 0.55
	var opruk_v: float = 0.35
	if atk_voor != null:
		hit_del2 = atk_voor.melee_fx("hit_delay", "melee_hit_delay", 0.55)
		opruk_v = atk_voor.melee_fx("advance_delay", "melee_advance_delay", 0.35)
	var verwacht: float = hit_del2 + opruk_v
	var melee_gestart := ""
	var atk_view = game._pawn_views.get(aanvaller.id)
	var y_van: Vector3 = game.tile_position(van.x, van.y)
	var mc_gelukt: bool = GameSession.submit_attack(st3.current_player, aanvaller.id, slachtoffer.id)
	if not mc_gelukt:
		var mc_act := Actions.make_melee(aanvaller.id, slachtoffer.id)
		var mc_res: Dictionary = Validator.is_legal(st3, mc_act, st3.current_player)
		print("[MELEE][%s] stoot geweigerd: %s (fase=%s speler=%d stamina=%d actief=%s kaart=%d posities=%s/%s)" % [
			naam, JSON.stringify(mc_res), Phase.to_string_phase(st3.phase), st3.current_player,
			aanvaller.remaining_stamina, str(aanvaller.is_active), aanvaller.linked_card_id,
			str(aanvaller.position), str(slachtoffer.position)])
		return false
	if atk_view != null:
		melee_gestart = String(atk_view.huidige_clip())
	var t := 0.0
	var vertrek := -1.0
	while t < verwacht + 3.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
		if atk_view == null or not is_instance_valid(atk_view):
			break
		var afstand: float = Vector2(atk_view.position.x - y_van.x,
			atk_view.position.z - y_van.z).length()
		if afstand > 0.15 and vertrek < 0.0:
			vertrek = t
			break
	print("[MELEE][%s] stoot-clip=%s dood-clip=%.2fs verwacht vertrek %.2fs, echt %.2fs" % [
		naam, melee_gestart if melee_gestart != "" else "GEEN", dood_dur, verwacht, vertrek])
	var mc_ok: bool = melee_gestart.begins_with("melee") or melee_gestart.begins_with("bayonet")
	if not mc_ok:
		print("[MELEE][%s] FAIL: er speelde geen stoot-clip maar '%s'" % [naam, melee_gestart])
	if vertrek < 0.0:
		print("[MELEE][%s] FAIL: hij is helemaal niet overgestoken" % naam)
		mc_ok = false
	elif vertrek < verwacht * 0.85:
		print("[MELEE][%s] FAIL: te vroeg overgestoken (%.2fs tegen %.2fs verwacht)" % [naam, vertrek, verwacht])
		mc_ok = false
	elif vertrek > verwacht + 0.6:
		print("[MELEE][%s] FAIL: veel te laat overgestoken (%.2fs tegen %.2fs verwacht)" % [naam, vertrek, verwacht])
		mc_ok = false
	return mc_ok


## Charge-scenario voor `-- meleecheck` (26 aug, Max: "jump en dan melee, dat
## is voor de charge"): een cavalerist rijdt DRIE vakken aan en velt de
## aangrenzende infanterist. Eis: tijdens het aanrijden speelt een
## rush-clip, daarna de charge-sprongstoot (terugval walk/melee telt
## ook, voor facties zonder die clips -- maar de muis heeft ze). Sinds 16
## september begint de sprong twee vakken voor de aankomst (bij een rit van
## een vak dus meteen, vandaar drie vakken hier) en valt de klap pas tegen
## het einde van de sprong-clip: de sprong moet na 1,2 s dus nog lopen en
## het slachtoffer mag dan nog niet gevallen zijn.
func _meleecheck_charge(game, st3: GameState) -> bool:
	st3.current_player = 1
	if st3.phase != Phase.Type.ACTION:
		st3.phase = Phase.Type.ACTION
	var ruiter: Pawn = null
	var slachtoffer: Pawn = null
	for pawn in st3.pawns.values():
		if pawn.is_eliminated:
			continue
		if pawn.owner_id == st3.current_player and ruiter == null \
				and pawn.unit_type == Constants.UnitType.CAVALRY:
			ruiter = pawn
			ruiter.is_active = true
		elif pawn.owner_id != st3.current_player and slachtoffer == null \
				and pawn.unit_type == Constants.UnitType.INFANTRY:
			slachtoffer = pawn
			slachtoffer.is_active = true
	if ruiter == null or slachtoffer == null:
		print("[MELEE][charge] geen bruikbaar paar gevonden")
		return false
	ruiter.remaining_stamina = maxi(ruiter.remaining_stamina, 6)
	# een ongekoppelde ruiter slaat met 0 en sterft aan de terugslag; de check
	# gaat over de choreografie, dus geef hem een klap en wat leven
	ruiter.attack_value = maxi(ruiter.attack_value, 3)
	ruiter.max_hp = maxi(ruiter.max_hp, 4)
	ruiter.current_hp = maxi(ruiter.current_hp, 4)
	var start := Vector2i(5, 8)
	var tussen := Vector2i(5, 5)
	var doelvak := Vector2i(5, 4)
	var vrij: Array = [start, Vector2i(5, 7), Vector2i(5, 6), tussen, doelvak]
	for bezet in st3.pawns.values():
		if bezet != ruiter and bezet != slachtoffer and not bezet.is_eliminated \
				and bezet.position in vrij:
			st3.set_pawn_position(bezet, Vector2i(0, 0) if bezet.position != Vector2i(0, 0) else Vector2i(10, 9))
	st3.set_pawn_position(ruiter, start)
	st3.set_pawn_position(slachtoffer, doelvak)
	slachtoffer.current_hp = 1
	game._refresh_all()
	await get_tree().create_timer(0.3).timeout
	var rv = game._pawn_views.get(ruiter.id)
	var gelukt: bool = GameSession.submit_charge(st3.current_player, ruiter.id, tussen, slachtoffer.id)
	if not gelukt:
		var act := Actions.make_charge(ruiter.id, tussen, slachtoffer.id)
		var res: Dictionary = Validator.is_legal(st3, act, st3.current_player)
		print("[MELEE][charge] charge geweigerd: %s (stamina=%d posities=%s->%s doel=%s)" % [
			JSON.stringify(res), ruiter.remaining_stamina, str(start), str(tussen), str(doelvak)])
		return false
	# 16 september (Max: "de sprong moet echt eerder starten, het poppetje
	# vliegt er twee velden overheen"): de rit-tween is nu de vlucht en
	# eindigt op de landing van de sprong (root motion weggecompenseerd).
	# Meten: de sprong-clip begint op tl.sprong_start, de pion staat op
	# tl.rij_dur op het tussenvak, en het doel staat nog vlak voor tl.klap_del
	# en is weg kort erna (1 HP, dus de klap doodt hem).
	var rij_dist: int = absi(tussen.x - start.x) + absi(tussen.y - start.y)
	var tl: Dictionary = rv.charge_tijdlijn(rij_dist) if rv != null else {}
	var sprong_duur: float = rv.charge_duur() if rv != null else -1.0
	var gezien: Array = []
	var t := 0.0
	var t_sprong := -1.0
	var pos_bij_landing := Vector3.INF
	var doel_voor_klap := false
	var doel_na_klap := true
	var klap_del: float = float(tl.get("klap_del", 0.35))
	var rij_dur: float = float(tl.get("rij_dur", 0.0))
	var eind: float = maxf(klap_del + 0.6, 1.2)
	while t < eind:
		if rv != null and is_instance_valid(rv):
			var clip := String(rv.huidige_clip())
			if clip != "" and (gezien.is_empty() or gezien[gezien.size() - 1] != clip):
				gezien.append(clip)
			if t_sprong < 0.0 and clip.begins_with("charge"):
				t_sprong = t
			if pos_bij_landing == Vector3.INF and t >= rij_dur + 0.06:
				pos_bij_landing = (rv as Node3D).position
		if t >= klap_del - 0.15 and t < klap_del - 0.1:
			doel_voor_klap = game._pawn_views.has(slachtoffer.id)
		if t >= klap_del + 0.45 and t < klap_del + 0.5:
			doel_na_klap = game._pawn_views.has(slachtoffer.id)
		await get_tree().create_timer(0.03).timeout
		t += 0.03
	print("[MELEE][charge] staat na de actie: ruiter dood=%s (hp %d, atk %d) slachtoffer dood=%s (hp %d) ruiter op %s" % [
		ruiter.is_eliminated, ruiter.current_hp, ruiter.attack_value, slachtoffer.is_eliminated, slachtoffer.current_hp, str(ruiter.position)])
	# waar de rit eindigt volgens de staat (bij een kill schuift de ruiter
	# door naar het vak van het slachtoffer)
	var doel_tegel: Vector3 = game.tile_position(ruiter.position.x, ruiter.position.y)
	var afstand_landing: float = Vector2(pos_bij_landing.x - doel_tegel.x, pos_bij_landing.z - doel_tegel.z).length() if pos_bij_landing != Vector3.INF else 99.0
	print("[MELEE][charge] clip-verloop: %s (sprong-clip %.2f s; tijdlijn %s; sprong gezien op %.2f s; op %.2f s %.2f vak van zijn eindvak; doel voor de klap=%s, na de klap=%s)" % [
		", ".join(gezien), sprong_duur, str(tl), t_sprong, rij_dur + 0.06, afstand_landing, doel_voor_klap, doel_na_klap])
	var stootte := false
	for clip in gezien:
		var c := String(clip)
		if c.begins_with("charge") or c.begins_with("melee"):
			stootte = true
	var ok := stootte and afstand_landing < 0.25 and doel_voor_klap and not doel_na_klap
	if sprong_duur > 0.0:
		ok = ok and t_sprong >= 0.0 and absf(t_sprong - float(tl.get("sprong_start", 0.0))) < 0.15
	if not ok:
		print("[MELEE][charge] FAIL: stoot=%s sprong-op-tijd=%s landing-op-eindvak=%s doel-voor-klap=%s doel-weg-na-klap=%s" % [
			stootte, t_sprong >= 0.0 and absf(t_sprong - float(tl.get("sprong_start", 0.0))) < 0.15, afstand_landing < 0.25, doel_voor_klap, not doel_na_klap])
	return ok



## F4.3e -- sessie die alleen een (herbouwde) staat heeft: wat een client na
## een koude start in handen heeft. Geen submits (die gaan online naar de
## server), wel de haken die de renderer nodig heeft.
class SnapshotSession extends SessionInterface:
	var view: Dictionary = {}

	func _init(v: Dictionary) -> void:
		view = v
		state = ClientState.uit_view(v)

	func local_player_id() -> int:
		return int(view.get("viewer", Constants.PLAYER_1))

	func pion_gedekt(pawn_id: int) -> bool:
		return ClientState.pion_gedekt(view, pawn_id)

	func is_online() -> bool:
		return true


## F4.3e -- één moment vergelijken: het live scherm tegen een verse scene die
## alleen de fog-view van speler 1 kreeg (door JSON-tekst heen).
func _herstel_vergelijk(game: Node, st: GameState, moment: int) -> Dictionary:
	var live: Dictionary = game.render_digest()
	var view: Dictionary = JSON.parse_string(JSON.stringify(View.for_player(st, 1)))
	var snap := SnapshotSession.new(view)
	var vers: Node = load("res://scenes/game/game.tscn").instantiate()
	add_child(vers)
	await get_tree().process_frame
	vers._start_vanaf_sessie(snap)
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	var hersteld: Dictionary = vers.render_digest()
	var fouten: Array = _digest_verschillen(live, hersteld)
	var canary := 0
	for key in view.pawns:
		if (view.pawns[key] as Dictionary).get("current_hp", 0) is String:
			var p = (hersteld.pawns as Dictionary).get(String(key), null)
			if p != null and (not bool(p.vraagteken) or String(p.blokjes).contains("1")):
				canary += 1
	print("[HERSTEL] moment %2d %-16s %s%s" % [moment, String(live.fase),
		"OK" if fouten.is_empty() and canary == 0 else "VERSCHIL: " + ", ".join(fouten),
		"" if canary == 0 else " (canary: %d gedekte pionnen tonen stats)" % canary])
	vers.queue_free()
	await get_tree().process_frame
	return {"verschillen": fouten.size(), "canary": canary}


func _digest_verschillen(a: Dictionary, b: Dictionary) -> Array:
	var uit: Array = []
	for key in a:
		if key == "pawns":
			var pa: Dictionary = a.pawns
			var pb: Dictionary = b.pawns
			for pid in pa:
				if not pb.has(pid):
					uit.append("pion %s ontbreekt hersteld" % pid)
				elif JSON.stringify(pa[pid]) != JSON.stringify(pb[pid]):
					uit.append("pion %s: %s -> %s" % [pid, JSON.stringify(pa[pid]), JSON.stringify(pb[pid])])
			for pid in pb:
				if not pa.has(pid):
					uit.append("pion %s alleen hersteld" % pid)
		elif JSON.stringify(a[key]) != JSON.stringify(b.get(key, null)):
			uit.append("%s: %s -> %s" % [key, JSON.stringify(a[key]), JSON.stringify(b.get(key, null))])
		if uit.size() >= 6:
			break
	return uit


## F4.3e -- één zet in de herstelcheck: de mens via het timeout-pad zodra hij
## iets moet doen, anders de tegenstander (L1) buiten game.gd om.
func _herstel_zet(game: Node, bot: Agent) -> bool:
	var st: GameState = GameSession.state
	if Phase.is_define(st.phase):
		if st.cards_defined.get(1, []).size() == 0 and Validator.expected_define_count(st, 1) > 0:
			game._on_phase_timeout()
			return true
	elif Phase.is_reveal(st.phase):
		if not bool(st.reveal_acks.get(1, false)):
			game._continue_after_reveal()
			return true
	elif Phase.is_linking(st.phase) or st.phase == Phase.Type.ACTION:
		if st.current_player == 1:
			game._on_phase_timeout()
			return true
	elif st.phase == Phase.Type.CYCLE_SPAWN:
		if not bool(st.spawn_done.get(1, false)):
			game._on_phase_timeout()
			return true
	# De tegenstander, zoals een server hem zou aanleveren.
	var legal: Array = Validator.legal_actions(st, 2)
	if legal.is_empty():
		return false
	var actie: Dictionary = bot.decide(View.for_player(st, 2), legal, bot.rng)
	if actie.is_empty():
		actie = legal[0]
	return GameSession._apply_action(2, actie)


## F4.3g -- één stap van de mens op de online-weg, via dezelfde UI-paden als
## een echte speler (keuze-menu, opstel-knop, onthul-knop, timeout-pad). De
## bot in de loopback handelt zelf. Geeft true als er iets is ingediend.
func _online_drijf_mens(game: Node, lb: LoopbackTransport, seat: int) -> bool:
	var st: GameState = lb.state
	if st.phase == Phase.Type.PRE_GAME:
		if not st.doctrine_commits.has(seat):
			var keuze: int = Constants.DOCTRINE_DATA.keys().find(Constants.Doctrine.MUIS)
			game._on_doctrine_choice(maxi(keuze, 0))
			return true
	elif st.phase == Phase.Type.PLACEMENT:
		if not bool(st.placements_done.get(seat, false)):
			game._confirm_placement()
			return true
	elif Phase.is_define(st.phase):
		if st.cards_defined.get(seat, []).size() == 0 and Validator.expected_define_count(st, seat) > 0:
			game._on_phase_timeout()
			return true
	elif Phase.is_reveal(st.phase):
		if not bool(st.reveal_acks.get(seat, false)):
			game._continue_after_reveal()
			return true
	elif Phase.is_linking(st.phase) or st.phase == Phase.Type.ACTION:
		if st.current_player == seat:
			game._on_phase_timeout()
			return true
	elif st.phase == Phase.Type.CYCLE_SPAWN:
		if not bool(st.spawn_done.get(seat, false)):
			game._on_phase_timeout()
			return true
	return false


## F4.3g -- één moment op de online-weg vergelijken: het live scherm tegen
## een verse scene met een verse RemoteSession op dezelfde loopback (alleen
## de view, door JSON).
func _resume_vergelijk(game: Node, lb: LoopbackTransport, seat: int, moment: int) -> Dictionary:
	var live: Dictionary = game.render_digest()
	var vers: Node = load("res://scenes/game/game.tscn").instantiate()
	add_child(vers)
	await get_tree().process_frame
	vers._start_online(RemoteSession.new(lb.voor_seat(seat), seat))
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	var hersteld: Dictionary = vers.render_digest()
	var fouten: Array = _digest_verschillen(live, hersteld)
	var canary := 0
	var view: Dictionary = (vers.session as RemoteSession).view
	for key in view.get("pawns", {}):
		if (view.pawns[key] as Dictionary).get("current_hp", 0) is String:
			var p = (hersteld.pawns as Dictionary).get(String(key), null)
			if p != null and (not bool(p.vraagteken) or String(p.blokjes).contains("1")):
				canary += 1
	print("[RESUME] moment %2d %-16s %s%s" % [moment, String(live.fase),
		"OK" if fouten.is_empty() and canary == 0 else "VERSCHIL: " + ", ".join(fouten),
		"" if canary == 0 else " (canary: %d gedekte pionnen tonen stats)" % canary])
	vers.queue_free()
	await get_tree().process_frame
	return {"verschillen": fouten.size(), "canary": canary}


## F4.3h -- wachten op een callback-antwoord (max `sec` seconden).
func _wacht_op(bak: Array, sec: float = 10.0) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	while bak.is_empty() and Time.get_ticks_msec() - t0 < int(sec * 1000):
		await get_tree().process_frame
	return bak[0] if not bak.is_empty() else {"ok": false, "fout": "geen antwoord binnen %.0f s" % sec}


func _nettest(game: Node, url: String) -> bool:
	# Tellers in een Array: een lambda vangt losse variabelen op waarde.
	var teller: Array = [0, 0]  # [stappen, fouten]
	var meld := func(naam: String, ok: bool, extra: String = "") -> void:
		teller[0] += 1
		if not ok:
			teller[1] += 1
		print("[NETTEST] %2d %-34s %s %s" % [teller[0], naam, "PASS" if ok else "FAIL", extra])
	var idA := Identiteit.laad("nettest_A")
	var idB := Identiteit.laad("nettest_B")
	var tA := HttpTransport.new(self, url)
	var tB := HttpTransport.new(self, url)
	var bak: Array = []
	tA.login(idA.device_token, "NettestA", func(a): bak.append(a))
	var a: Dictionary = await _wacht_op(bak)
	meld.call("login A (gast, device-token)", bool(a.ok), String(a.get("fout", "")))
	if not bool(a.ok):
		return false
	bak.clear()
	tB.login(idB.device_token, "NettestB", func(b): bak.append(b))
	a = await _wacht_op(bak)
	meld.call("login B", bool(a.ok), String(a.get("fout", "")))
	bak.clear()
	tA.versiecheck(func(v): bak.append(v))
	a = await _wacht_op(bak)
	meld.call("versiecheck core-hash", bool(a.ok), "%s / %s" % [String(a.get("server", "")).substr(0, 12), String(a.get("client", "")).substr(0, 12)])
	if not bool(a.ok):
		return false
	bak.clear()
	var regels: RulesConfig = game._potje_regels()
	tA.maak_match(regels.rules_version, regels.to_dict(), func(m): bak.append(m))
	a = await _wacht_op(bak)
	meld.call("match maken (seat 1)", bool(a.ok) and int(a.get("seat", 0)) == 1, String(a.get("match_id", a.get("fout", ""))))
	if not bool(a.ok):
		return false
	var match_id: String = String(a.match_id)
	bak.clear()
	tB.join(match_id, func(j): bak.append(j))
	a = await _wacht_op(bak)
	meld.call("joinen (seat 2)", bool(a.ok) and int(a.get("seat", 0)) == 2, String(a.get("fout", "")))
	var sA := RemoteSession.new(tA, 1)
	var sB := RemoteSession.new(tB, 2)
	add_child(sA)
	add_child(sB)
	bak.clear()
	sA.start(func(ok): bak.append({"ok": ok}))
	a = await _wacht_op(bak)
	meld.call("sessie A verbonden (status + view)", bool(a.ok) and sA.state != null and sA.state.phase == Phase.Type.PRE_GAME,
		"seq=%d" % sA.seq)
	bak.clear()
	sB.start(func(ok): bak.append({"ok": ok}))
	a = await _wacht_op(bak)
	meld.call("sessie B verbonden", bool(a.ok) and sB.state != null, "naam van 1 volgens B: %s" % sB.naam_van(1))
	var foutenA: Array = []
	sA.error_occurred.connect(func(_p, m): foutenA.append(m))
	sA.submit_choose_doctrine(1, Constants.Doctrine.MUIS)
	# B ziet via polling dat A koos.
	var t0 := Time.get_ticks_msec()
	while not bool(sB.tegenstander_status().get("enemy_has_chosen", false)) and Time.get_ticks_msec() - t0 < 10000:
		await get_tree().create_timer(0.1).timeout
	meld.call("A koos; B ziet dat via polling", bool(sB.tegenstander_status().get("enemy_has_chosen", false)),
		"na %d ms, seqB=%d" % [Time.get_ticks_msec() - t0, sB.seq])
	sB.submit_choose_doctrine(2, Constants.Doctrine.WOLF)
	t0 = Time.get_ticks_msec()
	while (sA.state.phase != Phase.Type.PLACEMENT or sB.state.phase != Phase.Type.PLACEMENT) \
			and Time.get_ticks_msec() - t0 < 10000:
		await get_tree().create_timer(0.1).timeout
	meld.call("beide in PLACEMENT (reveal via de server)", sA.state.phase == Phase.Type.PLACEMENT and sB.state.phase == Phase.Type.PLACEMENT,
		"seqA=%d seqB=%d" % [sA.seq, sB.seq])
	meld.call("facties uit de staat", sA.state.doctrine_of(2) == Constants.Doctrine.WOLF and sB.state.doctrine_of(1) == Constants.Doctrine.MUIS)
	# Een opstelling van A; B ziet in PLACEMENT nog geen pionnen van A (fog).
	sA.submit_default_placement(1)
	t0 = Time.get_ticks_msec()
	while not bool(sB.state.placements_done.get(1, false)) and Time.get_ticks_msec() - t0 < 10000:
		await get_tree().create_timer(0.1).timeout
	var vreemd := 0
	for pawn in sB.state.pawns.values():
		if pawn.owner_id == 1:
			vreemd += 1
	meld.call("B ziet dat A opstelde, maar niet wat", bool(sB.state.placements_done.get(1, false)) and vreemd == 0,
		"vijandelijke pionnen zichtbaar: %d" % vreemd)
	meld.call("geen foutmeldingen bij A", foutenA.is_empty(), str(foutenA))
	bak.clear()
	tA.status(func(s): bak.append(s))
	a = await _wacht_op(bak)
	meld.call("GET /matches/:id", bool(a.ok) and String(a.get("status", "")) == "bezig" and int(a.get("seq", 0)) == 3,
		"status=%s seq=%s" % [String(a.get("status", "")), str(a.get("seq", "?"))])
	print("[NETTEST] %s: %d stappen, %d fouten, match %s" % ["PASS" if teller[1] == 0 else "FAIL", teller[0], teller[1], match_id])
	return teller[1] == 0


## F4.3i -- wachten tot een conditie waar is (max `sec` seconden).
func _wacht_tot(cond: Callable, sec: float = 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(sec * 1000):
		await get_tree().create_timer(0.1).timeout
	return cond.call()


func _lobbycheck(game: Node, url: String) -> bool:
	var teller: Array = [0, 0]
	var meld := func(naam: String, ok: bool, extra: String = "") -> void:
		teller[0] += 1
		if not ok:
			teller[1] += 1
		print("[LOBBY] %2d %-40s %s %s" % [teller[0], naam, "PASS" if ok else "FAIL", extra])
	# A = game.gd met een eigen identiteit; server via de bridge.
	OnlineBridge.identiteit = Identiteit.laad("lobby_A")
	OnlineBridge.identiteit.server_url = url
	var overlay = game._overlay
	game._show_online_lobby()
	var ok: bool = await _wacht_tot(func() -> bool: return overlay.visible and String(overlay._title.text) == game.tr("MENU_MULTI_ONLINE_TITLE"))
	meld.call("lobby: verbonden, keuzes in beeld", ok, String(overlay._title.text))
	if not ok:
		return false
	overlay._pick(0)  # Nieuwe match
	ok = await _wacht_tot(func() -> bool: return OnlineBridge.match_id != "" and overlay.visible and String(overlay._title.text) == game.tr("MENU_ONLINE_WAIT_TITLE"))
	meld.call("nieuwe match, wachtscherm met match-id", ok, OnlineBridge.match_id)
	if not ok:
		return false
	var match_id: String = OnlineBridge.match_id
	# B = een tweede client, direct op het transport.
	var idB := Identiteit.laad("lobby_B")
	var tB := HttpTransport.new(self, url)
	var bak: Array = []
	tB.login(idB.device_token, "LobbyB", func(a): bak.append(a))
	var a: Dictionary = await _wacht_op(bak)
	meld.call("B ingelogd", bool(a.ok), String(a.get("fout", "")))
	bak.clear()
	tB.join(match_id, func(j): bak.append(j))
	a = await _wacht_op(bak)
	meld.call("B doet mee (seat 2)", bool(a.ok) and int(a.get("seat", 0)) == 2, String(a.get("fout", "")))
	var sB := RemoteSession.new(tB, 2)
	add_child(sB)
	bak.clear()
	sB.start(func(k): bak.append({"ok": k}))
	a = await _wacht_op(bak)
	meld.call("sessie B verbonden", bool(a.ok))
	# A's wachtscherm pollt elke 2 s en start dan de partij: het keuze-menu.
	# Sinds de UI-assetpack (merge 5d4a18e) is dat het factie-keuzescherm
	# (game._factie_keuze), niet meer het overlay-menu.
	var keuzescherm = game._factie_keuze
	ok = await _wacht_tot(func() -> bool: return game.session != null and game.session.is_online() and keuzescherm.visible and String(keuzescherm._titel.text) == game.tr("MENU_DOCTRINE_TITLE"), 20.0)
	meld.call("A ziet dat B meedoet en krijgt het factie-menu", ok, "mens=%d" % game._human_id)
	if not ok:
		return false
	var keuze: int = Constants.DOCTRINE_DATA.keys().find(Constants.Doctrine.MUIS)
	game._on_doctrine_choice(maxi(keuze, 0))
	sB.submit_choose_doctrine(2, Constants.Doctrine.WOLF)
	ok = await _wacht_tot(func() -> bool: return game.session.state.phase == Phase.Type.PLACEMENT and sB.state.phase == Phase.Type.PLACEMENT)
	meld.call("beide keuzes binnen, beide in PLACEMENT", ok, "seqA=%d seqB=%d" % [game.session.seq, sB.seq])
	ok = await _wacht_tot(func() -> bool: return overlay.visible and String(overlay._title.text) == game.tr("PHASE_PLACEMENT"))
	meld.call("A krijgt de opstel-overlay", ok)
	game._confirm_placement()
	ok = await _wacht_tot(func() -> bool: return bool(sB.state.placements_done.get(1, false)))
	meld.call("B ziet dat A opstelde", ok)
	meld.call("hervat-id staat in identity.cfg", OnlineBridge.identiteit.laatste_match_id == match_id)
	print("[LOBBY] %s: %d stappen, %d fouten, match %s" % ["PASS" if teller[1] == 0 else "FAIL", teller[0], teller[1], match_id])
	return teller[1] == 0


## koppelcheck: een eigen (speler 1), levende, nog ongekoppelde pion, of -1.
func _kc_vrije_pion() -> int:
	for pid in GameSession.state.pawns:
		var p: Pawn = GameSession.state.pawns[pid]
		if p.owner_id == 1 and not p.is_eliminated and p.linked_card_id == -1:
			return int(pid)
	return -1
