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
			var bview: VBoxContainer = load("res://scripts/ui/campaign/bracket_view.gd").new()
			add_child(bview)
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
		get_viewport().get_texture().get_image().save_png("res://_shot_trainer.png")
		print("[TRAINER] screenshot opgeslagen")
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
			var plus: Button = card.get_node("Margin/VBox/StatRows/HpRow/HpPlus")
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
	elif "geluidcheck" in args:
		# Doet elk wav-bestand ook echt mee? (Max, 30 juli: "importeer de nieuwe
		# sounds"). Per categorie: hoeveel varianten geladen zijn, de mix-stand
		# en de tuning uit sounds/sound_tuning.json. Regels met AAN=0 zijn
		# bestanden die het spel NIET kan spelen -- die moet je zien.
		print("[SND] categorie | varianten | mix-dB | tuner-dB | vertraging")
		var cats: Array = Audio.alle_categorieen()
		var stil: Array = []
		var los: Array = []
		for cat in cats:
			var n: int = Audio.variant_aantal(cat)
			if n == 0:
				stil.append(cat)
			print("[SND] %-24s | %d | %+.1f | %+.1f | %+.2f" % [cat, n,
				float(Audio.CATEGORY_DB.get(cat, 0.0)),
				Audio.volume_correctie(cat), Audio.extra_vertraging(cat)])
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
			var hoort_gedekt: bool = pawn.owner_id == 2 and pawn.is_active and not pawn.card_revealed
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
	var t0: int = Time.get_ticks_msec()
	var deadline: float = minutes * 60_000.0
	var gen: int = 0
	var adoptions: int = 0
	# Matchup-tally: hoe vaak wint DEZE (getrainde) factie tegen elke tegenstander.
	var matchup: Dictionary = {}
	# Convergentie: per factie een venster kampioen-snapshots + generatie-teller.
	var conv_geschiedenis: Dictionary = {}
	var gen_factie: Dictionary = {}
	# Referentie-score van de HUIDIGE kampioen op de vaste verificatiereeks,
	# per factie gecacht (vervalt bij adoptie). Zie de relatieve gate hieronder.
	var verify_ref: Dictionary = {}
	print("[TRAIN] Budget %.1f min · populatie %d · %d potjes per kandidaat · %d facties · PARALLEL (%d threads)" % [
		minutes, pop, games, doctrines.size(), pop])
	print("[TRAIN] Eén generatie = %d potjes (kandidaten + dubbele verificatie); parallel op eigen threads..." % [
		pop * games + games * 2])
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
		for j in pop:
			var res: Dictionary = threads[j].wait_to_finish()
			candidates[j].fit = float(res.fit)
			for od in res.tally:
				if not matchup.has(od):
					matchup[od] = {"w": 0.0, "g": 0}
				matchup[od].w += res.tally[od].w
				matchup[od].g += res.tally[od].g
			print("[TRAIN]   gen %d · %s · kandidaat %d/%d: %.1f/%d punten · %.1f min" % [
				gen, Constants.doctrine_name(d), j + 1, pop, float(candidates[j].fit), games,
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
		var n_verify: int = games * 2
		if not verify_ref.has(d):
			verify_ref[d] = {
				"champ": _verify_round(champ_w, d, profile, doctrines, games),
				"base": _verify_round(champ_w, d, baseline, doctrines, games),
			}
		var ref: Dictionary = verify_ref[d]
		var ref_tot: float = float(ref.champ) + float(ref.base)
		var verify_champ: float = _verify_round(mean, d, profile, doctrines, games)
		var verify_base: float = _verify_round(mean, d, baseline, doctrines, games)
		var verify: float = verify_champ + verify_base
		var adopted: bool = verify >= ref_tot + 2.0 \
			and verify_champ >= float(ref.champ) - 1.0 \
			and verify_base >= float(ref.base) - 1.0
		if adopted:
			profile[d] = mean
			adoptions += 1
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
			sigma[d] = maxf(0.06, float(sigma[d]) * 0.85)
		var elapsed: float = float(Time.get_ticks_msec() - t0) / 60_000.0
		print("[TRAIN] gen %d · %s · beste kandidaat %.1f/%d · verificatie %.1f/%d vs referentie %.1f (kampioen %.1f/%.1f + baseline %.1f/%.1f) → %s · sigma %.2f · %.1f min" % [
			gen, Constants.doctrine_name(d), float(candidates[0].fit), games,
			verify, n_verify, ref_tot, verify_champ, float(ref.champ), verify_base, float(ref.base),
			"GEADOPTEERD 💾" if adopted else "verworpen", float(sigma[d]), elapsed])
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
	var threads: Array = []
	for g in games:
		var opp_d: int = doctrines[g % doctrines.size()]
		var vjobs: Array = [{
			"cand_w": cand_w, "cand_d": cand_d,
			"opp_w": opp_profile[opp_d], "opp_d": opp_d,
			"cand_is_p1": g % 2 == 0,
		}]
		var thread := Thread.new()
		thread.start(_eval_games_threaded.bind(vjobs))
		threads.append(thread)
	var pts: float = 0.0
	for t in threads:
		pts += float(t.wait_to_finish().fit)
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
	for job in jobs:
		var s: float = _train_match(job.cand_w, job.cand_d, job.opp_w, job.opp_d, job.cand_is_p1)
		fit += s
		var od: int = int(job.opp_d)
		if not tally.has(od):
			tally[od] = {"w": 0.0, "g": 0}
		tally[od].w += s
		tally[od].g += 1
	return {"fit": fit, "tally": tally}


## Speel één headless potje; retour: 1.0 = kandidaat wint, 0.5 = gelijk, 0.0 = verlies.
func _train_match(cand_w: Dictionary, cand_d: int, opp_w: Dictionary, opp_d: int, cand_is_p1: bool) -> float:
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
	var score: float
	if _train_rules != null and _train_rules.campaign_actief():
		score = _campagne_score(runner.state(), cand_side, winner)
	else:
		score = 0.5 if winner == -1 else (1.0 if winner == cand_side else 0.0)
	runner.dispose()
	return score


## Campagne-fitness (26 juli, Max: "lange termijn denken"): onder v4.2-regels
## traint de bot op het campagne-puntensysteem in plaats van kale winst.
## Haven (3) > eliminatie (2) > tiebreak (1) > verlies (0), plus een kleine
## spaarbonus: restleger en gespaarde CP gaan in de campagne mee naar het
## volgende duel — óók voor de verliezer (die houdt zijn rest). Zo leert de
## bot winnen ZONDER zichzelf leeg te vechten. Genormaliseerd naar [0, 1];
## de relatieve adoptie-gate vergelijkt kandidaat en referentie op dezelfde
## schaal, dus de gate-marge blijft geldig.
func _campagne_score(s: GameState, kant: int, winner: int) -> float:
	var punten: float = 0.0
	if winner == -1:
		punten = 1.0  # remise: beide het tiebreak-punt
	elif winner == kant:
		if Rules.count_pawns_in_haven(s, winner) >= s.rules.pawns_in_haven_to_win:
			punten = 3.0
		else:
			var verliezer: int = Constants.opponent(winner)
			if s.count_alive_pawns_for(verliezer) + s.pool_total(verliezer) == 0:
				punten = 2.0
			else:
				punten = 1.0
	var comp: Array = s.doctrine_data_of(kant).comp
	var factor: float = float(s.rules.campaign.get("poolfactor", 1.5))
	var start_totaal: int = 0
	var rest: int = 0
	if s.punten_model():
		# C11: alles in puntenwaarde (soldaat 1 / ruiter 2 / kanon 3) zodat
		# een gespaard kanon ook echt 3x een soldaat waard is.
		for t in 3:
			start_totaal += int(comp[t]) * s.spawn_kosten(t) 				+ int(floor(int(comp[t]) * factor)) * s.spawn_kosten(t)
		for pawn in s.pawns.values():
			if not pawn.is_eliminated and pawn.owner_id == kant:
				rest += s.spawn_kosten(pawn.unit_type)
		rest += s.pool_total(kant)
	else:
		for t in 3:
			start_totaal += int(comp[t]) + int(floor(int(comp[t]) * factor))
		rest = s.count_alive_pawns_for(kant) + s.pool_total(kant)
	var rest_fractie: float = clampf(float(rest) / maxf(1.0, float(start_totaal)), 0.0, 1.0)
	var cp_start: float = maxf(1.0, float(s.rules.campaign.get("cp_start", 10)))
	var cp_fractie: float = clampf(float(s.cp.get(kant, 0)) / cp_start, 0.0, 1.0)
	return (punten / 3.0 + 0.15 * rest_fractie + 0.05 * cp_fractie) / 1.2


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
## is voor de charge"): een cavalerist rijdt een vak aan en velt de
## aangrenzende infanterist. Eis: tijdens het aanrijden speelt een
## rush-clip, bij aankomst de charge-sprongstoot (terugval walk/melee telt
## ook, voor facties zonder die clips -- maar de muis heeft ze).
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
	ruiter.remaining_stamina = maxi(ruiter.remaining_stamina, 3)
	var start := Vector2i(5, 6)
	var tussen := Vector2i(5, 5)
	var doelvak := Vector2i(5, 4)
	for bezet in st3.pawns.values():
		if bezet != ruiter and bezet != slachtoffer and not bezet.is_eliminated \
				and (bezet.position == start or bezet.position == tussen or bezet.position == doelvak):
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
	# Clip-verloop bemonsteren: eerst hoort er een rush/walk te spelen,
	# daarna de charge/melee-stoot.
	var gezien: Array = []
	var t := 0.0
	while t < 1.2:
		if rv != null and is_instance_valid(rv):
			var clip := String(rv.huidige_clip())
			if clip != "" and (gezien.is_empty() or gezien[gezien.size() - 1] != clip):
				gezien.append(clip)
		await get_tree().create_timer(0.03).timeout
		t += 0.03
	print("[MELEE][charge] clip-verloop: %s" % ", ".join(gezien))
	var reed := false
	var stootte := false
	var stoot_na_rit := false
	for clip in gezien:
		var c := String(clip)
		if c.begins_with("rush") or c.begins_with("walk"):
			reed = true
		elif c.begins_with("charge") or c.begins_with("melee"):
			stootte = true
			if reed:
				stoot_na_rit = true
	var ok := reed and stootte and stoot_na_rit
	if not ok:
		print("[MELEE][charge] FAIL: aanrijden=%s stoot=%s volgorde-goed=%s" % [reed, stootte, stoot_na_rit])
	return ok

