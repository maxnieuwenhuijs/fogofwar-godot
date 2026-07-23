extends TestSuite

# F0.1 — determinisme-tests: SeededRng-gedrag + reproduceerbare partijen.
# De partij-tests draaien met een stap-limiet (tiebreak beslist) zodat de
# suite snel blijft; voor determinisme is de volledige uitkomst niet nodig.

const AIEasyScript := preload("res://scripts/ai/AIEasy.gd")


func _class_name() -> String:
	return "DeterminismTests"


func test_seeded_rng_same_seed_same_stream() -> void:
	var a := SeededRng.new(42)
	var b := SeededRng.new(42)
	for i in 25:
		assert_eq(a.randi_range(0, 1000), b.randi_range(0, 1000), "stream-afwijking op trek %d" % i)
	assert_true(absf(SeededRng.new(42).randf() - SeededRng.new(43).randf()) > 0.0000001,
		"verschillende seeds horen (vrijwel zeker) direct te divergeren")


func test_seeded_rng_fork_stable_and_independent() -> void:
	var f1 := SeededRng.new(7).fork("p1")
	var f2 := SeededRng.new(7).fork("p1")
	assert_eq(f1.randi_range(0, 999999), f2.randi_range(0, 999999), "fork met zelfde label = zelfde stream")
	var fa := SeededRng.new(7).fork("p1")
	var fb := SeededRng.new(7).fork("p2")
	var diverged := false
	for i in 8:
		if fa.randi_range(0, 999999) != fb.randi_range(0, 999999):
			diverged = true
			break
	assert_true(diverged, "forks met verschillende labels horen onafhankelijk te zijn")


func test_seeded_rng_shuffle_deterministic() -> void:
	var arr1 := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var arr2 := arr1.duplicate()
	SeededRng.new(99).shuffle(arr1)
	SeededRng.new(99).shuffle(arr2)
	assert_eq(arr1, arr2, "zelfde seed = zelfde permutatie")
	var sorted := arr1.duplicate()
	sorted.sort()
	assert_eq(sorted, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "shuffle verliest geen elementen")


func test_seeded_rng_pick() -> void:
	assert_eq(SeededRng.new(1).pick([]), null, "pick op lege array = null")
	assert_eq(SeededRng.new(1).pick([42]), 42, "pick op 1 element = dat element")


## 2× dezelfde sim met dezelfde seed → identieke winnaar/cycli/stappen (F0.1-CHECK).
func test_same_seed_same_match() -> void:
	var runs: Array = []
	for _r in 2:
		var runner := MatchRunner.new(AIEasyScript.new(), AIEasyScript.new(),
			Constants.Doctrine.MENS, Constants.Doctrine.MUIS, 424242)
		runner.max_steps = 260
		var steps := 0
		while not runner.done and steps < 400:
			runner.step()
			steps += 1
		runs.append("%d|%d|%d" % [runner.winner, runner.engine.state.cycle, steps])
		runner.dispose()
	assert_eq(runs[0], runs[1], "zelfde seed hoort een identiek verloop te geven")


## Verschillende seeds met AIEasy → verschillend verloop. Robuust tegen de
## kans dat twee specifieke seeds toevallig samenvallen: we eisen dat er over
## 4 seeds minstens 2 verschillende vingerafdrukken ontstaan (F0.1-CHECK).
func test_different_seeds_vary_course() -> void:
	var prints := {}
	for s in [1, 2, 3, 4]:
		var runner := MatchRunner.new(AIEasyScript.new(), AIEasyScript.new(),
			Constants.Doctrine.MENS, Constants.Doctrine.MENS, s)
		runner.max_steps = 200
		var steps := 0
		var first_moves := []
		while not runner.done and steps < 320:
			runner.step()
			steps += 1
			if steps <= 30:
				first_moves.append(str(runner.engine.state.current_player))
		prints["%d|%d|%d|%s" % [runner.winner, runner.engine.state.cycle, steps, "".join(first_moves)]] = true
		runner.dispose()
	assert_true(prints.size() >= 2,
		"4 verschillende seeds horen minstens 2 verschillende verlopen te geven (kreeg %d)" % prints.size())
