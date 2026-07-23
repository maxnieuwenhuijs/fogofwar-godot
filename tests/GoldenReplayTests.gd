extends TestSuite

# F0.7 — golden replays: elk bestand in tests/golden_replays/ wordt gefold
# vanaf zijn beginstaat; élke actie-hash en de volledige eindstaat moeten
# byte-identiek zijn. BREEKT ER ÉÉN: dat is een bewuste regelwijziging →
# rules_version-bump + entry in docs/spelregels-CHANGELOG.md + goldens
# opnieuw genereren met `capture.tscn -- makegoldens` (werkafspraak §0).


func _class_name() -> String:
	return "GoldenReplayTests"


func test_alle_goldens_byte_identiek() -> void:
	var dir_pad := "res://tests/golden_replays"
	var da := DirAccess.open(dir_pad)
	assert_true(da != null, "golden_replays-map bestaat")
	if da == null:
		return
	var bestanden: Array = []
	for f in da.get_files():
		if String(f).ends_with(".json"):
			bestanden.append(String(f))
	bestanden.sort()
	assert_true(bestanden.size() >= 12, "minstens 12 goldens verwacht (kreeg %d)" % bestanden.size())
	for f in bestanden:
		var uitkomst: Dictionary = MatchLog.verify_file(dir_pad + "/" + f)
		assert_true(uitkomst.ok, "golden %s: %s" % [f, String(uitkomst.get("fout", "OK"))])
