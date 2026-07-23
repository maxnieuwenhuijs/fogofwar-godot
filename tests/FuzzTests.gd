extends TestSuite

# F1.4 — het fuzz-vangnet in het klein: een schone mini-run (0 schendingen)
# en de zelftest: een gesaboteerde run MOET geflagd worden (test-de-tester).
# De volle nachtrun (10k) draait via `arena.tscn -- --fuzz`.


func _class_name() -> String:
	return "FuzzTests"


func test_fuzz_25_partijen_schoon() -> void:
	var uitkomst: Dictionary = ArenaFuzz.run(25, 640000, "res://results/fuzz_suite", false)
	assert_eq(uitkomst.games, 25)
	assert_eq(uitkomst.violations, 0, "fuzz hoort schoon te zijn: %s" % str(uitkomst.repro_paden))


func test_sabotage_wordt_gevangen() -> void:
	# Stiekeme HP-mutatie halverwege: minstens de fold-vergelijking moet vuren.
	var uitkomst: Dictionary = ArenaFuzz.run(3, 641000, "res://results/fuzz_suite", true)
	assert_true(uitkomst.violations > 0, "de ingebouwde sabotage MOET gevangen worden")
