extends Node

## Simpele SFX-speler (autoload "Audio"). Per categorie een lijst varianten;
## play() kiest willekeurig een variant → natuurlijke afwisseling. Een pool van
## AudioStreamPlayers laat geluiden overlappen (schot + inslag + terugslag).

const SFX_DIR := "res://sounds/"
const POOL_SIZE := 10

## Categorie → bestandsnamen (zónder pad). Random keuze per afspeelverzoek.
const BANK := {
	"cannon_fire": ["cannon_heavy.wav", "cannon_heavy2.wav", "cannon_heavy3.wav"],
	"cannon_air":  ["cannon_bal_flies.wav", "cannon_ball_flies3.wav",
					"cannon_bal_flies4.wav", "cannon_bal_flies5.wav"],
	"cannon_hit":  ["cannon_ball_hit.wav"],
	"musket_fire": ["musket.wav", "musket_heavy_2.wav", "musket_heavy_3.wav"],
	"musket_echo": ["musket_echo.wav", "musket_echo2.wav", "musket_echo3.wav",
					"musket_echo4.wav", "musket_echo5.wav", "musket_echo6.wav"],
	"musket_hit":  ["default_musket_hit.wav"],
	# Factie-sterfgeluiden (SOUND-WISHLIST 7b) en val-geluiden (7bis).
	# Kanontreffer: eigen, zwaardere kreet die VLAK VOOR de inslag inzet.
	"inf_kanon_die_mouse": ["mouse_hit_canon_1.wav", "mouse_hit_canon_2.wav"],
	"inf_die_mouse": ["mouse_shot_die_1.wav", "mouse_shot_die_2.wav", "mouse_shot_die_3.wav"],
	"val_musket":    ["musket_hits_floor.wav", "musket_hit_floor_2.wav"],
	"val_hoed":      ["hat_hit_floor_2.wav"],
	"body_fall":     ["body_hit_floor_1.wav", "body_hit_floor_2.wav", "body_hit_floor_3.wav"],
	"musket_cock": ["cockhammer.wav"],
	"melee_kill":  ["mellee_hit.wav", "mellee_hit2.wav", "mellee_hit4.wav"],
	"melee_survive": ["mellee_hit_no_kill.wav"],
	"step":        ["step1.wav", "step2.wav", "step3.wav", "step4.wav"],
	"horse_move":  ["horse_move.wav", "horse_move2.wav"],
	"cannon_move": ["cannon_move.wav", "cannon_move2.wav", "cannon_move3.wav", "cannon_move4.wav"],
	"horse_select": ["horse_select.wav", "horse_select2.wav", "horse_select3.wav"],
	"horse_die":   ["horse_die.wav", "horse_die2.wav"],
	"inf_die":     ["inf_die.wav", "inf_die2.wav", "inf_die3.wav", "inf_die4.wav"],
	"cannon_die":  ["cannon_destroyed.wav"],
	"retaliation_horse": ["retaliation_with_horse.wav"],
	"blood_splash": ["small_blood_splash.wav", "small_blood_splash2.wav", "small_blood_splash3.wav"],
	"charge_yell": ["charge_yell.wav"],
	"pawn_block":  ["pawn_block.wav", "pawn_block2.wav"],
	"haven_score": ["haven_score.wav", "haven_score2.wav"],
	"win_fanfare": ["win_fanfare.wav"],
	"lose_sting":  ["lose_sting.wav"],
	"timer_tick":  ["timer_tick.wav"],
	"timer_warning": ["timer_warning.wav"],
	"ui_click":    ["ui_click.wav", "ui_click2.wav", "ui_click3.wav"],
	"ui_back":     ["ui_back.wav", "ui_back2.wav"],
	"ui_hover":    ["ui_hover.wav"],
	"ui_error":    ["ui_error.wav"],
	"ui_open":     ["ui_open.wav", "ui_open2.wav"],
	"ui_toggle":   ["ui_toggle.wav"],
	"card_confirm": ["card_confirm.wav", "card_confirm2.wav"],
	"card_deal":   ["card_deal2.wav", "card_deal3.wav"],
	"card_select": ["card_select.wav", "card_select2.wav", "card_select3.wav"],
	"card_stat_up": ["card_stat_up.wav", "card_stat_up2.wav", "card_stat_up3.wav"],
	"card_stat_down": ["card_stat_down.wav", "card_stat_down2.wav", "card_stat_down3.wav"],
	"link_snap":   ["link_snap.wav", "link_snap2.wav", "links_snap3.wav"],
	"reveal":      ["reveal.wav", "reveal2.wav"],
	"initiative":  ["initiative.wav"],
	"phase_change": ["phase_change.wav", "phase_change2.wav"],
	"cycle_start": ["cycle_start.wav"],
	"retaliation": ["retaliation.wav"],
	"place_pawn":  ["place_pawn.wav", "place_pawn2.wav", "place_pawn3.wav", "place_pawn4.wav"],
	"your_turn":   ["your_turn.wav"],
	"cannon_select": ["cannon_select.wav", "cannon_select2.wav", "cannon_select3.wav"],
	"inf_select":  ["inf_select.wav", "inf_select2.wav", "inf_select3.wav"],
	"cannon_fuse": ["canvas_cannon_fuse.wav", "canvas_cannon_fuse2.wav"],
	"deselect":    ["deselect.wav"],
}

## Globale demping + per-categorie bijstelling (mp3's zijn ongelijk genormaliseerd).
@export var master_db: float = -4.0
const CATEGORY_DB := {
	"cannon_fire": 0.0,
	"cannon_air": -6.0,
	"cannon_hit": -2.0,
	"musket_fire": -3.0,
	"musket_echo": -8.0,
	"musket_hit": -4.0,
	"musket_cock": -5.0,
	"melee_kill": -1.0,
	"melee_survive": -3.0,
	"step": -7.0,
	"horse_move": -6.0,
	"cannon_move": -6.0,
	"horse_select": -5.0,
	"horse_die": -2.0,
	"inf_die": -2.0,
	"cannon_die": -2.0,
	"retaliation_horse": -3.0,
	"blood_splash": -6.0,
	"charge_yell": -3.0,
	"pawn_block": -4.0,
	"haven_score": -2.0,
	"win_fanfare": -2.0,
	"lose_sting": -2.0,
	"timer_tick": -10.0,
	"timer_warning": -6.0,
	"ui_click": -6.0,
	"ui_back": -6.0,
	"ui_hover": -12.0,
	"ui_error": -5.0,
	"ui_open": -7.0,
	"ui_toggle": -6.0,
	"card_confirm": -4.0,
	"card_deal": -6.0,
	"card_select": -6.0,
	"card_stat_up": -7.0,
	"card_stat_down": -7.0,
	"link_snap": -4.0,
	"reveal": -3.0,
	"initiative": -3.0,
	"phase_change": -5.0,
	"cycle_start": -3.0,
	"retaliation": -3.0,
	"place_pawn": -5.0,
	"your_turn": -6.0,
	"cannon_select": -5.0,
	"inf_select": -5.0,
	"cannon_fuse": -4.0,
	"deselect": -7.0,
}

## Muziek/ambience: lange loops in res://music/ (QOA-gecomprimeerde WAV).
## Geen naadloze loop nodig: bij `finished` start een willekeurige volgende
## variant → natuurlijke afwisseling (bv. veld → veld met regen).
const MUSIC_DIR := "res://music/"
const MUSIC_BANK := {
	"music_battle": ["music_battle.wav", "music_battle2.wav"],
	"ambient_field": ["ambient_field.wav", "ambient_field2.wav", "ambient_field_rain.wav"],
}
const MUSIC_DB := {
	"music_battle": -16.0,
	"ambient_field": -20.0,
}

var _streams: Dictionary = {}       # categorie -> Array[AudioStream]
var _music_streams: Dictionary = {} # lazy-cache: categorie -> Array[AudioStream]
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var enabled: bool = true

var _music_player: AudioStreamPlayer    # muzieklaag (in-game bed)
var _ambient_player: AudioStreamPlayer  # ambience-laag (wind/veld)
var _music_cat: String = ""
var _ambient_cat: String = ""


func _ready() -> void:
	for category in BANK:
		var loaded: Array = []
		for filename in BANK[category]:
			var stream := load(SFX_DIR + filename)
			if stream != null:
				loaded.append(stream)
			else:
				push_warning("Audio: kon %s niet laden" % filename)
		_streams[category] = loaded
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.finished.connect(func() -> void: _loop_layer(_music_player, _music_cat))
	add_child(_music_player)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Master"
	_ambient_player.finished.connect(func() -> void: _loop_layer(_ambient_player, _ambient_cat))
	add_child(_ambient_player)


## Speel een geluid uit een categorie.
## variant < 0 = willekeurige variant; anders die exacte index (cyclisch).
## pitch <= 0 = subtiele random pitch; anders die exacte pitch_scale.
func play(category: String, delay: float = 0.0, variant: int = -1, pitch: float = 0.0) -> void:
	if not enabled:
		return
	if delay > 0.0:
		# Autoload zit in de tree, dus deze timer loopt ook los van de scene.
		get_tree().create_timer(delay).timeout.connect(_play_now.bind(category, variant, pitch))
	else:
		_play_now(category, variant, pitch)


## Factie-variant met terugval (SOUND-WISHLIST 7b, besluit Max 28 juli):
## probeert "<categorie>_<factie>" (bv. inf_die_mouse) en valt anders terug op
## de algemene categorie. Zo kun je per factie geluiden toevoegen zonder dat
## het spel stuk gaat zolang ze ontbreken.
## Hoeveel varianten heeft een categorie? (0 = niets geladen -- de tuner
## toont dat, zodat je meteen ziet of een bestand is aangekomen.)
func variant_aantal(category: String) -> int:
	return (_streams.get(category, []) as Array).size()


## Langste variant in seconden (voor de tuner: past het bij de animatie?).
func langste_duur(category: String) -> float:
	var langste := 0.0
	for s in _streams.get(category, []):
		langste = maxf(langste, (s as AudioStream).get_length())
	return langste


## Zoekvolgorde van fijn naar grof (besluit Max, 28 juli):
##   <cat>_<factie>_<archetype>   bv. inf_die_mouse_hp   -- dit ene model
##   <cat>_<factie>               bv. inf_die_mouse      -- hele factie
##   <cat>_mouse[_<archetype>]    leen van de muis (zoals de modellen)
##   <cat>                        algemeen
## Zo kun je zo grof of zo fijn opnemen als je wilt: één geluid voor alles,
## of een eigen kreet voor de dikke hp-muis.
func categorie_keten(category: String, doctrine: int, archetype: String = "") -> Array:
	var fac := Constants.doctrine_folder(doctrine)
	var keten: Array = []
	if archetype != "":
		keten.append("%s_%s_%s" % [category, fac, archetype])
	keten.append("%s_%s" % [category, fac])
	if fac != "mouse":
		if archetype != "":
			keten.append("%s_mouse_%s" % [category, archetype])
		keten.append("%s_mouse" % category)
	keten.append(category)
	return keten


## Welke categorie klinkt er werkelijk? ("" = niets) -- de tuner gebruikt dit
## zodat je daar exact hoort wat het spel speelt.
func effectieve_categorie(category: String, doctrine: int, terugval: String = "",
		archetype: String = "") -> String:
	for kandidaat in categorie_keten(category, doctrine, archetype):
		if not (_streams.get(kandidaat, []) as Array).is_empty():
			return kandidaat
	if terugval != "":
		return effectieve_categorie(terugval, doctrine, "", archetype)
	return ""


func play_factie(category: String, doctrine: int, delay: float = 0.0, pitch: float = 0.0,
		terugval: String = "", archetype: String = "") -> void:
	var cat := effectieve_categorie(category, doctrine, terugval, archetype)
	if cat != "":
		play(cat, delay, -1, pitch)


## GELUID-AFSTELLING (sounds/sound_tuning.json, besluit Max 28 juli): per
## categorie een volume-correctie in dB en een extra vertraging in seconden.
## Zo stem je de bons van een vallend lijf of musket precies af op de animatie
## zonder de code aan te raken -- de Model-tuner (tab Geluid) schrijft hierin.
const GELUID_TUNING_PAD := "res://sounds/sound_tuning.json"
var _snd_tuning: Dictionary = {}
var _snd_geladen: bool = false


func _laad_snd_tuning() -> void:
	if _snd_geladen:
		return
	_snd_geladen = true
	if not FileAccess.file_exists(GELUID_TUNING_PAD):
		return
	var f := FileAccess.open(GELUID_TUNING_PAD, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_snd_tuning = d


func volume_correctie(category: String) -> float:
	_laad_snd_tuning()
	return float((_snd_tuning.get(category, {}) as Dictionary).get("db", 0.0))


func extra_vertraging(category: String) -> float:
	_laad_snd_tuning()
	return float((_snd_tuning.get(category, {}) as Dictionary).get("vertraging", 0.0))


func zet_geluid_tuning(category: String, db: float, vertraging: float) -> void:
	_laad_snd_tuning()
	_snd_tuning[category] = {"db": db, "vertraging": vertraging}
	bewaar_geluid_tuning()


func bewaar_geluid_tuning() -> void:
	var f := FileAccess.open(GELUID_TUNING_PAD, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_snd_tuning, "\t"))


## Speel met de afgestelde vertraging erbij (voor bonzen die op een animatie
## moeten vallen). basis = het moment dat de code zelf berekent.
func play_getuned(category: String, basis: float = 0.0, pitch: float = 0.0) -> void:
	# Negatieve correctie vervroegt; onder nul kan een geluid niet, dus dan
	# klinkt hij meteen. Zo kun je een bons die te laat valt naar voren halen.
	play(category, maxf(0.0, basis + extra_vertraging(category)), -1, pitch)


## Wat de tuner nodig heeft om te laten zien wat er echt gebeurt: de basis
## die de code zelf berekent (bv. de val-tijd van het musket).
func basis_vertraging(category: String) -> float:
	match category:
		"body_fall":
			return 0.9          # standaard dood-poel-moment; per clip instelbaar
		"val_hoed":
			return 0.75         # hoedje tolt langer na
	if category.begins_with("val_"):
		return 0.44             # boog van een weggeslingerd voorwerp
	return 0.0


func _play_now(category: String, variant: int = -1, pitch: float = 0.0) -> void:
	var variants: Array = _streams.get(category, [])
	if variants.is_empty() and category.begins_with("val_"):
		variants = _streams.get("val_prop", [])   # generiek kletter-geluid
	if variants.is_empty():
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	var idx: int = (variant % variants.size()) if variant >= 0 else (randi() % variants.size())
	player.stream = variants[idx]
	player.volume_db = master_db + float(CATEGORY_DB.get(category, 0.0)) + volume_correctie(category)
	player.pitch_scale = pitch if pitch > 0.0 else randf_range(0.96, 1.04)
	player.play()


## Beweeggeluid over een verplaatsing: één klap per gelopen vakje, gelijkmatig
## over `duration` verdeeld. Sample cyclt door de varianten van `category`,
## beginnend op een willekeurige index (nieuwe reeks); de pitch tikt per volledige
## ronde omhoog, dus de eerste herhaling van een sample klinkt nét anders.
## category: "step" (infanterie), "horse_move" (cavalerie), "cannon_move" (artillerie).
func play_footsteps(step_count: int, duration: float, category: String = "step") -> void:
	if not enabled or step_count <= 0:
		return
	var count: int = _streams.get(category, []).size()
	if count == 0:
		return
	var start := randi() % count
	var base_pitch := randf_range(0.92, 1.06)
	for i in step_count:
		var sample_idx := (start + i) % count
		var round := i / count  # elke volle ronde een pitch-trapje hoger
		var pitch := base_pitch + float(round) * 0.06
		var t := duration * float(i + 1) / float(step_count)  # geluid bij het neerkomen
		play(category, t, sample_idx, pitch)


func set_enabled(on: bool) -> void:
	enabled = on
	# Mute pauzeert ook de muziek-/ambience-lagen (positie blijft staan).
	if _music_player != null:
		_music_player.stream_paused = not on
	if _ambient_player != null:
		_ambient_player.stream_paused = not on


# --- Muziek & ambience (lange loops) -----------------------------------------

## Start de muzieklaag met een categorie uit MUSIC_BANK (lazy geladen).
## Herstart niet als die categorie al speelt.
func play_music(category: String) -> void:
	if _music_cat == category and _music_player.playing:
		return
	_music_cat = category
	_start_layer(_music_player, category)


## Start de ambience-laag (zelfde gedrag als play_music, eigen speler).
func play_ambient(category: String) -> void:
	if _ambient_cat == category and _ambient_player.playing:
		return
	_ambient_cat = category
	_start_layer(_ambient_player, category)


func stop_music() -> void:
	_music_cat = ""
	_music_player.stop()


func stop_ambient() -> void:
	_ambient_cat = ""
	_ambient_player.stop()


func _start_layer(player: AudioStreamPlayer, category: String) -> void:
	var variants: Array = _music_variants(category)
	if variants.is_empty():
		return
	player.stream = variants[randi() % variants.size()]
	player.volume_db = master_db + float(MUSIC_DB.get(category, -16.0))
	player.stream_paused = not enabled
	player.play()


## Track afgelopen → willekeurige volgende variant van dezelfde categorie.
func _loop_layer(player: AudioStreamPlayer, category: String) -> void:
	if category != "":
		_start_layer(player, category)


func _music_variants(category: String) -> Array:
	if not _music_streams.has(category):
		var loaded: Array = []
		for filename in MUSIC_BANK.get(category, []):
			var stream := load(MUSIC_DIR + filename)
			if stream != null:
				loaded.append(stream)
			else:
				push_warning("Audio: kon %s niet laden" % filename)
		_music_streams[category] = loaded
	return _music_streams[category]
