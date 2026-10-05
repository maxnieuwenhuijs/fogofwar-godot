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
	assert_true(absf(Audio.niveau_db(Audio._music_player) - verwacht) < 0.01,
		"muzieklaag krijgt het nieuwe volume meteen (%.2f, verwacht %.2f)" % [Audio.niveau_db(Audio._music_player), verwacht])
	# `alles` schaalt eroverheen.
	Audio.zet_volume("alles", 0.5, false)
	verwacht = Audio.master_db + float(Audio.MUSIC_DB.get("music_battle", -16.0)) + Audio.volume_naar_db(0.5 * 0.25)
	assert_true(absf(Audio.niveau_db(Audio._music_player) - verwacht) < 0.01, "alles x muziek")
	# Omgeving raakt de muzieklaag niet, wel de ambience-laag.
	var muziek_voor: float = Audio.niveau_db(Audio._music_player)
	Audio.zet_volume("omgeving", 0.1, false)
	assert_true(absf(Audio.niveau_db(Audio._music_player) - muziek_voor) < 0.001, "omgeving laat de muziek met rust")
	var amb_verwacht: float = Audio.master_db + float(Audio.MUSIC_DB.get(Audio._ambient_cat, -16.0)) + Audio.volume_naar_db(0.5 * 0.1)
	assert_true(absf(Audio.niveau_db(Audio._ambient_player) - amb_verwacht) < 0.01, "ambience-laag volgt omgeving")
	# Onbekende soort doet niets en crasht niet.
	Audio.zet_volume("kanon", 0.1, false)
	assert_eq(Audio.volume("kanon"), 1.0, "onbekende soort = 1.0")
	_zet_terug(stand)


## 5 oktober (Max: "dB per sound effect luistert niet naar de algemene game
## sound settings"): de volumes zijn faders op eigen bussen. Een effect dat al
## klinkt schaalt dus mee, de dB per categorie blijft in volume_db, en M zet de
## Master-bus stil. Vaste variant en toon: geen globale RNG.
func test_bussen_effect_volgt_al_spelend_en_m_dempt_master() -> void:
	var stand := _bewaar_stand()
	var oud_aan: bool = Audio.enabled
	for naam in [Audio.BUS_EFFECTEN, Audio.BUS_MUZIEK, Audio.BUS_OMGEVING]:
		assert_true(AudioServer.get_bus_index(naam) > 0, "bus %s bestaat onder Master" % naam)
		assert_eq(String(AudioServer.get_bus_send(AudioServer.get_bus_index(naam))), "Master", "%s stuurt naar Master" % naam)
	assert_eq(String(Audio._pool[0].bus), Audio.BUS_EFFECTEN, "effecten op SFX")
	assert_eq(String(Audio._music_player.bus), Audio.BUS_MUZIEK, "muziek op Music")
	assert_eq(String(Audio._ambient_player.bus), Audio.BUS_OMGEVING, "omgeving op Ambient")
	assert_true(AudioServer.get_bus_effect_count(0) >= 1 and AudioServer.get_bus_effect(0, 0) is AudioEffectHardLimiter,
		"begrenzer op Master")
	Audio.set_enabled(true)
	Audio.zet_volume("alles", 1.0, false)
	Audio.zet_volume("effecten", 1.0, false)
	if Audio.variant_aantal("inf_select") > 0:
		var voor: int = Audio._next
		Audio.play("inf_select", 0.0, 0, 1.0)
		assert_true(Audio._next != voor, "er is echt een speler gebruikt")
		var p: AudioStreamPlayer = Audio._pool[(Audio._next - 1 + Audio._pool.size()) % Audio._pool.size()]
		assert_true(absf(p.volume_db - (Audio.master_db + Audio.mix_niveau("inf_select"))) < 0.01,
			"volume_db = master + dB per categorie, zonder schuif")
		var basis: float = p.volume_db
		Audio.zet_volume("effecten", 0.5, false)
		assert_true(absf(Audio.niveau_db(p) - (basis + Audio.volume_naar_db(0.5))) < 0.01,
			"een effect dat al klinkt volgt de schuif effecten (%.2f)" % Audio.niveau_db(p))
		Audio.zet_volume("alles", 0.5, false)
		assert_true(absf(Audio.niveau_db(p) - (basis + Audio.volume_naar_db(0.25))) < 0.01, "alles x effecten")
		p.stop()
	Audio.set_enabled(false)
	assert_true(AudioServer.is_bus_mute(0), "M zet de Master-bus stil")
	Audio.set_enabled(true)
	assert_false(AudioServer.is_bus_mute(0), "M terug: Master weer aan")
	Audio.set_enabled(oud_aan)
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
