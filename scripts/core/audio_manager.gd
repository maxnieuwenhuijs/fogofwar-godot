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
	"ui_click":    ["ui_click.wav", "ui_click2.wav", "ui_click3.wav"],
	"ui_back":     ["ui_back.wav", "ui_back2.wav"],
	"ui_hover":    ["ui_hover.wav"],
	"ui_error":    ["ui_error.wav"],
	"ui_open":     ["ui_open.wav"],
	"ui_toggle":   ["ui_toggle.wav"],
	"card_confirm": ["card_confirm.wav", "card_confirm2.wav"],
	"card_stat_up": ["card_stat_up.wav", "card_stat_up2.wav", "card_stat_up3.wav"],
	"card_stat_down": ["card_stat_down.wav", "card_stat_down2.wav", "card_stat_down3.wav"],
	"reveal":      ["reveal.wav", "reveal2.wav"],
	"initiative":  ["initiative.wav"],
	"phase_change": ["phase_change.wav", "phase_change2.wav"],
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
	"ui_click": -6.0,
	"ui_back": -6.0,
	"ui_hover": -12.0,
	"ui_error": -5.0,
	"ui_open": -7.0,
	"ui_toggle": -6.0,
	"card_confirm": -4.0,
	"card_stat_up": -7.0,
	"card_stat_down": -7.0,
	"reveal": -3.0,
	"initiative": -3.0,
	"phase_change": -5.0,
	"place_pawn": -5.0,
	"your_turn": -6.0,
	"cannon_select": -5.0,
	"inf_select": -5.0,
	"cannon_fuse": -4.0,
	"deselect": -7.0,
}

var _streams: Dictionary = {}       # categorie -> Array[AudioStream]
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var enabled: bool = true


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


func _play_now(category: String, variant: int = -1, pitch: float = 0.0) -> void:
	var variants: Array = _streams.get(category, [])
	if variants.is_empty():
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	var idx: int = (variant % variants.size()) if variant >= 0 else (randi() % variants.size())
	player.stream = variants[idx]
	player.volume_db = master_db + float(CATEGORY_DB.get(category, 0.0))
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
