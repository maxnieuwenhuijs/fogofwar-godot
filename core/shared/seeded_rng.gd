class_name SeededRng
extends RefCounted

# Seedbare RNG (F0.1): alle spel-relevante loting loopt hierdoor, zodat
# partijen reproduceerbaar zijn (replays F0.7, arena-metingen F1, fuzz F1.4).
# Presentatie (audio/VFX) blijft bewust op de globale RNG.
#
# Gebruik: var rng := SeededRng.new(42); rng.randi_range(0, 2); rng.pick(arr)
# Sub-streams: rng.fork("p1") geeft een onafhankelijke, herleidbare stream —
# zo beïnvloedt een extra loting bij speler 1 nooit de stream van speler 2.

var seed_value: int = 0
var _rng := RandomNumberGenerator.new()


func _init(seed_val: int = 0) -> void:
	seed_value = seed_val
	_rng.seed = seed_val


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


## Normaalverdeling (voor CMA-lite-mutaties in de trainer).
func randfn(mean: float = 0.0, deviation: float = 1.0) -> float:
	return _rng.randfn(mean, deviation)


## Willekeurig element; null bij een lege array.
func pick(arr: Array):
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]


## In-place Fisher-Yates met déze stream (Array.shuffle() zou de globale RNG pakken).
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Onafhankelijke sub-stream, deterministisch afgeleid van (seed, label).
func fork(label: String) -> SeededRng:
	return SeededRng.new(hash("%d/%s" % [seed_value, label]))
