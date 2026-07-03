extends Node

## Simpele SFX-speler (autoload "Audio"). Per categorie een lijst varianten;
## play() kiest willekeurig een variant → natuurlijke afwisseling. Een pool van
## AudioStreamPlayers laat geluiden overlappen (schot + inslag + terugslag).

const SFX_DIR := "res://sounds/"
const POOL_SIZE := 10

## Categorie → bestandsnamen (zónder pad). Random keuze per afspeelverzoek.
const BANK := {
	"cannon_fire": ["cannon_heavy.wav", "cannon_heavy2.wav", "cannon_heavy3.wav"],
	"cannon_air":  ["cannon_bal_flies.wav", "cannon_ball_flies2.wav", "cannon_ball_flies3.wav"],
	"cannon_hit":  ["cannon_ball_hit.wav"],
	"musket_fire": ["musket.wav", "musket_heavy_2.wav", "musket_heavy_3.wav"],
	"musket_echo": ["musket_echo.wav", "musket_echo2.wav", "musket_echo3.wav",
					"musket_echo4.wav", "musket_echo5.wav", "musket_echo6.wav"],
	"musket_hit":  ["default_musket_hit.wav"],
	"musket_cock": ["cockhammer.wav"],
	"melee_kill":  ["mellee_hit.wav", "mellee_hit2.wav", "mellee_hit4.wav"],
	"melee_survive": ["mellee_hit_no_kill.wav"],
	"step":        ["step1.wav", "step2.wav", "step3.wav", "step4.wav"],
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


## Voetstappen over een beweging: één stap per gelopen vakje, gelijkmatig over
## `duration` verdeeld. Sample cyclt 1→2→3→4→1…, beginnend op een willekeurige
## index (nieuwe reeks); de pitch tikt per ronde-van-4 omhoog, dus de 5e stap
## (= sample 1 opnieuw) klinkt nét anders dan de 1e.
func play_footsteps(step_count: int, duration: float) -> void:
	if not enabled or step_count <= 0:
		return
	var start := randi() % 4
	var base_pitch := randf_range(0.92, 1.06)
	for i in step_count:
		var sample_idx := (start + i) % 4
		var round := i / 4  # integer: elke 4 stappen een pitch-trapje hoger
		var pitch := base_pitch + float(round) * 0.06
		var t := duration * float(i + 1) / float(step_count)  # geluid bij het neerkomen
		play("step", t, sample_idx, pitch)


func set_enabled(on: bool) -> void:
	enabled = on
