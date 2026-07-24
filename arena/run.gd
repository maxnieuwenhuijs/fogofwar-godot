extends Node

# F1.2 — de standalone arena-runner:
#
#   godot --headless --path . res://arena/arena.tscn -- --config <json> [--out <map>] [--seed-offset N]
#
# Config (arena/arena_configs/*.json):
#   {
#     "matchups": "all" | [["muis", "wolf"], ...],   # "all" = alle 36 gerichte paren
#     "games_per_matchup": 5,
#     "agents": {"p1": "l1", "p2": "l1"},            # l0 | l1 | l2 | l3 | l3u
#     "base_seed": 1000,
#     "rules": "res://arena/arena_configs/v41_default.json",  # optioneel
#     "max_steps": 1500,
#     "track_repetitions": true,
#     "full_state": {"p1": false, "p2": false}       # B8-ablatie
#   }
#
# Uitvoer: <out>/games.jsonl — regel 1 = run-metadata (git-sha, config, ts),
# daarna één regel per partij (ZONDER wallclock: zelfde config+seed ⇒
# byte-identieke game-regels, B10/reproduceerbaarheid). Console: winrate-matrix.

const DOCTRINE_NAMEN := {
	"mens": Constants.Doctrine.MENS, "varken": Constants.Doctrine.MENS,
	"muis": Constants.Doctrine.MUIS, "leeuw": Constants.Doctrine.LEEUW,
	"beer": Constants.Doctrine.BEER, "wolf": Constants.Doctrine.WOLF,
	"vos": Constants.Doctrine.VOS, "krokodil": Constants.Doctrine.VOS,
}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--bench"):
		_bench(args)
		return
	if args.has("--fuzz") or args.has("--fuzz-selftest"):
		_fuzz(args)
		return
	var config_pad := _arg(args, "--config", "res://arena/arena_configs/quick_l1.json")
	var out_map := _arg(args, "--out", "res://results/run")
	var seed_offset := int(_arg(args, "--seed-offset", "0"))
	var config = JSON.parse_string(FileAccess.get_file_as_string(config_pad))
	if config == null:
		push_error("Arena: config onleesbaar: %s" % config_pad)
		get_tree().quit(1)
		return
	var uitkomst: Dictionary = run_arena(config, out_map, seed_offset)
	print("[ARENA] klaar: %d partijen -> %s (%.1f s, %.2f match/s)" % [
		uitkomst.games, uitkomst.pad, uitkomst.duur, uitkomst.per_sec])
	_print_matrix(uitkomst.matrix)
	get_tree().quit(0)


func run_arena(config: Dictionary, out_map: String, seed_offset: int) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var rules: RulesConfig = null
	if config.has("rules"):
		rules = RulesConfig.load_from_file(String(config.rules))
	var max_steps := int(config.get("max_steps", 1500))
	var per := int(config.get("games_per_matchup", 5))
	var base_seed := int(config.get("base_seed", 1000))
	var track_reps := bool(config.get("track_repetitions", true))
	var matchups: Array = _bepaal_matchups(config.get("matchups", "all"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_map))
	var pad := out_map.path_join("games.jsonl")
	var f := FileAccess.open(pad, FileAccess.WRITE)
	f.store_line(JSON.stringify({
		"run_meta": true,
		"git_sha": _git_sha(),
		"ts": Time.get_datetime_string_from_system(),
		"config": config,
		"seed_offset": seed_offset,
		"rules_version": (rules.rules_version if rules != null else RulesConfig.defaults().rules_version),
	}))
	var matrix: Dictionary = {}
	var games := 0
	var index := 0
	for matchup in matchups:
		var d1: int = matchup[0]
		var d2: int = matchup[1]
		for g in per:
			var seed_val: int = base_seed + seed_offset + index
			index += 1
			var a1: Agent = _maak_agent(String(config.get("agents", {}).get("p1", "l1")))
			var a2: Agent = _maak_agent(String(config.get("agents", {}).get("p2", "l1")))
			a1.full_state = bool(config.get("full_state", {}).get("p1", false))
			a2.full_state = bool(config.get("full_state", {}).get("p2", false))
			for a in [a1, a2]:
				if a is AgentL2:
					a.tie_break_loting = bool(config.get("tie_break_loting", false))
			var runner := AgentRunner.new(a1, a2, d1, d2, seed_val, rules)
			runner.max_steps = max_steps
			var metrics := ArenaMetrics.new()
			metrics.track_repetitions = track_reps
			runner.metrics = metrics
			runner.run()
			var regel: Dictionary = metrics.finalize(runner, d1, d2, seed_val, {
				"p1": String(config.get("agents", {}).get("p1", "l1")),
				"p2": String(config.get("agents", {}).get("p2", "l1")),
				"full_state_1": a1.full_state,
				"full_state_2": a2.full_state,
			})
			f.store_line(JSON.stringify(regel))
			games += 1
			var sleutel := "%s>%s" % [Constants.doctrine_name(d1), Constants.doctrine_name(d2)]
			if not matrix.has(sleutel):
				matrix[sleutel] = {"w1": 0, "w2": 0, "remise": 0}
			if runner.winner == 1:
				matrix[sleutel].w1 += 1
			elif runner.winner == 2:
				matrix[sleutel].w2 += 1
			else:
				matrix[sleutel].remise += 1
	f.close()
	var duur := (Time.get_ticks_msec() - t0) / 1000.0
	return {"games": games, "pad": pad, "duur": duur,
		"per_sec": (games / duur) if duur > 0 else 0.0, "matrix": matrix}


## F1.4 — fuzz-vangnet: `-- --fuzz [games] [seed]` (nachtrun) of
## `-- --fuzz-selftest` (sabotage-run: de checks MOETEN de ingebouwde
## mutatie vangen — test-de-tester). Repro's bij schendingen in results/fuzz/.
func _fuzz(args: PackedStringArray) -> void:
	var selftest := args.has("--fuzz-selftest")
	var vlag := "--fuzz-selftest" if selftest else "--fuzz"
	var i := args.find(vlag)
	var games := 3 if selftest else 500
	if args.size() > i + 1 and not String(args[i + 1]).begins_with("--"):
		games = int(args[i + 1])
	var seed_val := 640000
	if args.size() > i + 2 and not String(args[i + 2]).begins_with("--"):
		seed_val = int(args[i + 2])
	var t0 := Time.get_ticks_msec()
	var uitkomst: Dictionary = ArenaFuzz.run(games, seed_val, "res://results/fuzz", selftest)
	var duur := (Time.get_ticks_msec() - t0) / 1000.0
	if selftest:
		var gevangen: bool = uitkomst.violations > 0
		print("[FUZZ-SELFTEST] sabotage %s door de checks (%d/%d partijen geflagd) — %s" % [
			"GEVANGEN" if gevangen else "NIET GEVANGEN", uitkomst.violations, games,
			"PASS" if gevangen else "FAIL: het vangnet is stuk"])
		get_tree().quit(0 if gevangen else 1)
		return
	print("[FUZZ] %d partijen in %.1f s (%.2f/s): %d schendingen%s" % [
		games, duur, games / duur, uitkomst.violations,
		"" if uitkomst.violations == 0 else " — repro's: " + str(uitkomst.repro_paden)])
	get_tree().quit(0 if uitkomst.violations == 0 else 1)


## F1.3 — doorvoermeting op 1 core: `-- --bench [l0|l1|l2] [games]`.
## Zonder metrics (pure engine+agent-snelheid), gemengde doctrine-paren.
func _bench(args: PackedStringArray) -> void:
	var i := args.find("--bench")
	var label := String(args[i + 1]) if args.size() > i + 1 and not String(args[i + 1]).begins_with("--") else "l1"
	var games := int(args[i + 2]) if args.size() > i + 2 else 30
	var docs: Array = Constants.DOCTRINE_DATA.keys()
	var t0 := Time.get_ticks_msec()
	var totaal_steps := 0
	for g in games:
		var runner := AgentRunner.new(_maak_agent(label), _maak_agent(label),
			docs[g % docs.size()], docs[(g + 3) % docs.size()], 33000 + g)
		runner.max_steps = 1500
		runner.run()
		totaal_steps += runner.steps
	var duur := (Time.get_ticks_msec() - t0) / 1000.0
	print("[BENCH] %s-vs-%s: %d partijen in %.1f s -> %.2f match/s/core (%.0f beslissingen/s)" % [
		label, label, games, duur, games / duur, totaal_steps / duur])
	get_tree().quit(0)


func _bepaal_matchups(spec) -> Array:
	var out: Array = []
	if spec is String and String(spec) == "all":
		var docs: Array = Constants.DOCTRINE_DATA.keys()
		for d1 in docs:
			for d2 in docs:
				out.append([int(d1), int(d2)])
		return out
	for paar in spec:
		out.append([_doctrine(String(paar[0])), _doctrine(String(paar[1]))])
	return out


func _doctrine(naam: String) -> int:
	return DOCTRINE_NAMEN.get(naam.to_lower(), Constants.Doctrine.MENS)


func _maak_agent(label: String) -> Agent:
	match label.to_lower():
		"l0":
			return AgentL0.new()
		"l1":
			return AgentL1.new()
		"l2":
			return AgentL2.new()
		"l3":
			return AgentL3.new()
		"l3u":
			return AgentL3.new(true)
	push_warning("Arena: onbekend agent-label '%s', val terug op l1" % label)
	return AgentL1.new()


func _git_sha() -> String:
	var uit: Array = []
	var code := OS.execute("git", ["rev-parse", "--short", "HEAD"], uit)
	if code == 0 and uit.size() > 0:
		return String(uit[0]).strip_edges()
	return "onbekend"


func _arg(args: PackedStringArray, naam: String, standaard: String) -> String:
	var i := args.find(naam)
	if i != -1 and args.size() > i + 1:
		return String(args[i + 1])
	return standaard


func _print_matrix(matrix: Dictionary) -> void:
	print("[ARENA] winrates per gerichte matchup (P1-kant wint / P2-kant wint / remise):")
	var sleutels: Array = matrix.keys()
	sleutels.sort()
	for s in sleutels:
		var m: Dictionary = matrix[s]
		print("  %-16s %d / %d / %d" % [s, m.w1, m.w2, m.remise])
