extends Node

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
		_run_training(minutes, pop, games, faction)
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
			str(game._valid_shots), inf.attack_value, Rules.shot_damage(inf)])
		game._on_pawn_clicked(victim2.id)
		print("[SHOOT] infanterieschot raak=%s (verwacht true)" % str(victim2.is_eliminated))
		# Vang de treffer-feedback (flits + zwevend schade-label) op een screenshot.
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("res://_shot_hitfx.png")
		get_tree().quit()
		return
	elif "sim" in args:
		# Puur engine + AI: speel een volledige partij AI vs AI en log het resultaat.
		# Gebruik: -- sim <p1> <p2> [d1] [d2]
		#   p = easy/medium/hard (default medium); d = mens/muis/leeuw/beer/wolf/vos.
		var paths := {
			"easy": "res://scripts/ai/AIEasy.gd",
			"medium": "res://scripts/ai/AIMedium.gd",
			"hard": "res://scripts/ai/AIHard.gd",
			"ultra": "res://scripts/ai/AIUltra.gd",
		}
		var doctrine_names := {
			"mens": Constants.Doctrine.MENS, "varken": Constants.Doctrine.MENS,
			"muis": Constants.Doctrine.MUIS,
			"leeuw": Constants.Doctrine.LEEUW,
			"beer": Constants.Doctrine.BEER,
			"wolf": Constants.Doctrine.WOLF,
			"vos": Constants.Doctrine.VOS, "krokodil": Constants.Doctrine.VOS,
		}
		var n1: String = args[1] if args.size() > 1 else "medium"
		var n2: String = args[2] if args.size() > 2 else "medium"
		var d1: int = doctrine_names.get(args[3] if args.size() > 3 else "mens", Constants.Doctrine.MENS)
		var d2: int = doctrine_names.get(args[4] if args.size() > 4 else "mens", Constants.Doctrine.MENS)
		var a1 = load(paths.get(n1, paths["medium"])).new()
		a1.player_id = 1
		var a2 = load(paths.get(n2, paths["medium"])).new()
		a2.player_id = 2
		GameSession.start_new_game(d1, d2)
		GameSession.submit_placement(1, a1.choose_placement(GameSession.state))
		GameSession.submit_placement(2, a2.choose_placement(GameSession.state))
		var acts := 0
		var guard := 0
		while GameSession.state.phase != Phase.Type.GAME_OVER and guard < 8000:
			guard += 1
			var st: GameState = GameSession.state
			var ph: int = st.phase
			var cur = a1 if st.current_player == 1 else a2
			if Phase.is_define(ph):
				if st.cards_defined[1].size() == 0:
					GameSession.submit_define_cards(1, a1.generate_cards(st))
				if st.cards_defined[2].size() == 0:
					GameSession.submit_define_cards(2, a2.generate_cards(st))
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
					for pawn in st.get_active_pawns_for(st.current_player):
						if Rules.can_pawn_act(st, pawn.id):
							print("  pion %d type=%d pos=%s stamina=%d/%d atk=%d melee=%d schoten=%d zetten=%d" % [
								pawn.id, pawn.unit_type, str(pawn.position),
								pawn.remaining_stamina, pawn.max_stamina, pawn.attack_value,
								Rules.get_valid_melee_targets(st, pawn.id).size(),
								Rules.get_valid_shot_targets(st, pawn.id).size(),
								Rules.get_valid_moves(st, pawn.id).size()])
					break
				acts += 1
				match String(act.type):
					"move":
						GameSession.submit_move(st.current_player, act.pawn_id, act.target)
					"attack":
						GameSession.submit_attack(st.current_player, act.attacker_id, act.defender_id)
					"shot":
						GameSession.submit_shot(st.current_player, act.shooter_id, act.target_id)
					"charge":
						GameSession.submit_charge(st.current_player, act.pawn_id, act.move_target, act.defender_id)
		var s := GameSession.state
		print("[SIM %s(P1,%s) vs %s(P2,%s)] winner=%d cyclus=%d acties=%d p1_haven=%d p2_haven=%d p1_alive=%d p2_alive=%d guard=%d" % [
			n1, Constants.doctrine_name(d1), n2, Constants.doctrine_name(d2),
			s.winner, s.cycle, acts,
			Rules.count_pawns_in_haven(s, 1), Rules.count_pawns_in_haven(s, 2),
			s.get_alive_pawns_for(1).size(), s.get_alive_pawns_for(2).size(), guard])
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

	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out)
	get_tree().quit()


# =========================================================================
# Headless auto-trainer (CMA-lite per factie)
# =========================================================================

const TRAIN_AI := preload("res://scripts/ai/AIMedium.gd")

## Populatie-training: per generatie één factie. POP kandidaten (alle gewichten
## licht verstoord, log-normaal met stapgrootte sigma) spelen elk GAMES potjes;
## de top-helft wordt gerecombineerd (meetkundig gemiddelde) en geverifieerd
## tegen de kampioen. Sigma past zichzelf aan (groter bij succes, kleiner bij
## falen). Het profiel wordt bij elke adoptie opgeslagen.
func _run_training(minutes: float, pop: int, games: int, faction: int = -1) -> void:
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
				var scaled: float = float(champ_w[k]) * exp(randfn(0.0, float(sigma[d])))
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
		doc_order.shuffle()
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
				opp_profile = pool[randi() % pool.size()]
			var opp_d: int = doc_order[g % doc_order.size()]
			schedule.append({"opp_w": opp_profile[opp_d], "opp_d": opp_d, "cand_is_p1": g % 2 == 0})
		# Fitness PARALLEL: één thread per kandidaat (pop threads tegelijk).
		# Meer threads (per potje) bleek AVERECHTS: te veel GDScript-threads
		# vechten om de allocator en maken het 4× trager. pop (6) is de sweet spot.
		# (Loting gebeurt op de hoofdthread — randi is niet thread-safe.)
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
		#    ziet). Tegenstander-facties round-robin i.p.v. loting. Adoptie eist
		#    marge op het totaal ÉN geen verlies tegen een van beide helften —
		#    de oude gate (4/6 tegen alleen de kampioen) liet ~34% pure ruis door,
		#    vandaar 90-127 'adopties' met gedrifte gewichten in de nachtrun.
		# Twee rondes van `games` threads (12 tegelijk = allocator-contention).
		var n_verify: int = games * 2
		var verify_champ: float = _verify_round(mean, d, profile, doctrines, games)
		var verify_base: float = _verify_round(mean, d, baseline, doctrines, games)
		var verify: float = verify_champ + verify_base
		var half: float = float(games) * 0.5
		var adopted: bool = verify >= float(n_verify) * 0.5 + 2.0 \
			and verify_champ >= half and verify_base >= half
		if adopted:
			profile[d] = mean
			adoptions += 1
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
		print("[TRAIN] gen %d · %s · beste kandidaat %.1f/%d · verificatie %.1f/%d (kampioen %.1f + baseline %.1f) → %s · sigma %.2f · %.1f min" % [
			gen, Constants.doctrine_name(d), float(candidates[0].fit), games,
			verify, n_verify, verify_champ, verify_base,
			"GEADOPTEERD 💾" if adopted else "verworpen", float(sigma[d]), elapsed])
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
		var runner := MatchRunner.new(a1, a2, d1, d2)
		runner.max_steps = 600  # snelle tiebreak bij patstelling (meten, geen training)
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
	var runner := MatchRunner.new(a1, a2, d1, d2)
	# Patstellingen kosten anders tot 2500 stappen per potje; echte partijen zijn
	# rond ~350 klaar. De tiebreak (materiaal → haven) geeft hetzelfde leersignaal.
	runner.max_steps = 900
	while not runner.done:
		runner.step()
	var winner: int = runner.winner
	runner.dispose()
	if winner == -1:
		return 0.5
	var cand_side: int = Constants.PLAYER_1 if cand_is_p1 else Constants.PLAYER_2
	return 1.0 if winner == cand_side else 0.0


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
