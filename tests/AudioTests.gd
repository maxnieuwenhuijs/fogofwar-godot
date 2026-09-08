extends TestSuite

# Geluidsinstellingen (8 september 2026): vier volumes in de Audio-autoload,
# meteen toegepast op de lopende lagen en bewaard in settings.cfg. De tests
# schrijven naar een eigen cfg-bestand en zetten alles daarna terug, zodat de
# instellingen van de speler niet veranderen.


func _class_name() -> String:
	return "AudioTests"


const TEST_CFG := "user://settings_audiotest.cfg"


func _bewaar_stand() -> Dictionary:
	var stand: Dictionary = {"pad": Audio.instellingen_pad, "cat": Audio._music_cat, "vol": {}}
	for s in Audio.VOLUME_SOORTEN:
		stand.vol[s] = Audio.volume(String(s))
	Audio.instellingen_pad = TEST_CFG
	return stand


func _zet_terug(stand: Dictionary) -> void:
	for s in stand.vol:
		Audio.zet_volume(String(s), float(stand.vol[s]), false)
	Audio._music_cat = String(stand.cat)
	Audio.instellingen_pad = String(stand.pad)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))


func test_volume_naar_db() -> void:
	assert_eq(Audio.volume_naar_db(1.0), 0.0, "vol = 0 dB")
	assert_true(absf(Audio.volume_naar_db(0.5) + 6.02) < 0.05, "half = ongeveer -6 dB")
	assert_eq(Audio.volume_naar_db(0.0), -80.0, "nul = stil, geen -inf")
	assert_eq(Audio.volume_naar_db(2.0), 0.0, "boven 1 wordt afgekapt")


func test_zet_volume_landt_meteen_op_de_muzieklaag() -> void:
	var stand := _bewaar_stand()
	Audio._music_cat = "music_battle"
	Audio.zet_volume("alles", 1.0, false)
	Audio.zet_volume("muziek", 0.25, false)
	var verwacht: float = Audio.master_db + float(Audio.MUSIC_DB.get("music_battle", -16.0)) + Audio.volume_naar_db(0.25)
	assert_true(absf(Audio._music_player.volume_db - verwacht) < 0.01,
		"muzieklaag krijgt het nieuwe volume meteen (%.2f, verwacht %.2f)" % [Audio._music_player.volume_db, verwacht])
	# `alles` schaalt eroverheen.
	Audio.zet_volume("alles", 0.5, false)
	verwacht = Audio.master_db + float(Audio.MUSIC_DB.get("music_battle", -16.0)) + Audio.volume_naar_db(0.5 * 0.25)
	assert_true(absf(Audio._music_player.volume_db - verwacht) < 0.01, "alles x muziek")
	# Omgeving raakt de muzieklaag niet, wel de ambience-laag.
	var muziek_voor: float = Audio._music_player.volume_db
	Audio.zet_volume("omgeving", 0.1, false)
	assert_true(absf(Audio._music_player.volume_db - muziek_voor) < 0.001, "omgeving laat de muziek met rust")
	var amb_verwacht: float = Audio.master_db + float(Audio.MUSIC_DB.get(Audio._ambient_cat, -16.0)) + Audio.volume_naar_db(0.5 * 0.1)
	assert_true(absf(Audio._ambient_player.volume_db - amb_verwacht) < 0.01, "ambience-laag volgt omgeving")
	# Onbekende soort doet niets en crasht niet.
	Audio.zet_volume("kanon", 0.1, false)
	assert_eq(Audio.volume("kanon"), 1.0, "onbekende soort = 1.0")
	_zet_terug(stand)


func test_volumes_worden_bewaard_en_teruggelezen() -> void:
	var stand := _bewaar_stand()
	Audio.zet_volume("muziek", 0.4)
	Audio.zet_volume("effecten", 0.7)
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(TEST_CFG), OK, "cfg geschreven")
	assert_true(absf(float(cfg.get_value("audio", "muziek", -1.0)) - 0.4) < 1e-6, "muziek bewaard")
	assert_true(absf(float(cfg.get_value("audio", "effecten", -1.0)) - 0.7) < 1e-6, "effecten bewaard")
	# Andere secties blijven staan (de taal woont in hetzelfde bestand).
	cfg.set_value("i18n", "locale", "nl")
	cfg.set_value("audio", "muziek", 0.15)
	cfg.save(TEST_CFG)
	Audio._laad_volumes()
	assert_true(absf(Audio.volume("muziek") - 0.15) < 1e-6, "teruggelezen bij het laden")
	Audio.zet_volume("alles", 0.9)
	var cfg2 := ConfigFile.new()
	assert_eq(cfg2.load(TEST_CFG), OK)
	assert_eq(String(cfg2.get_value("i18n", "locale", "")), "nl", "de taal overleeft een volume-opslag")
	# Buiten bereik wordt geklemd.
	Audio.zet_volume("effecten", 7.0, false)
	assert_eq(Audio.volume("effecten"), 1.0, "geklemd op 1")
	_zet_terug(stand)
