class_name NeuraalNet
extends RefCounted

# L4 neuraal (22 september) -- een klein MLP in pure GDScript.
#
# Leest het json dat tools/l4/train_net.py schrijft en rekent het voorwaarts
# uit, deterministisch en zonder afhankelijkheden: het netwerk moet in de
# arena, in het spel en straks op een telefoon draaien. Formaat:
#
#   {
#     "versie": 1,
#     "kenmerk_versie": 1,            # Kenmerken.KENMERK_VERSIE bij het trainen
#     "kenmerken": 65,                # invoerbreedte
#     "mu": [...], "sigma": [...],    # invoer-normalisatie (x - mu) / sigma
#     "lagen": [{"w": [[...]], "b": [...]}, ...],  # w is [invoer][uitvoer]
#     "proef": {"invoer": [...], "uitvoer": 0.123}  # pariteitscheck
#   }
#
# Alle verborgen lagen: ReLU. De laatste laag is lineair en heeft breedte 1:
# de waarde van een na-staat voor de speler die hem bekijkt (hoger = beter).
# `proef` is een vector met de uitkomst zoals Python hem rekende; `proef_ok`
# bewijst dat GDScript hetzelfde getal maakt (tot 1e-4).

const STANDAARD_PAD: String = "res://data/ai_net.json"

var pad: String = ""
var kenmerk_versie: int = -1
var kenmerken: int = 0
var mu: PackedFloat32Array = PackedFloat32Array()
var sigma: PackedFloat32Array = PackedFloat32Array()
var lagen: Array = []  # [{w: Array[PackedFloat32Array] per invoer, b: PackedFloat32Array, uit: int}]
var proef_invoer: PackedFloat32Array = PackedFloat32Array()
var proef_uitvoer: float = 0.0
var heeft_proef: bool = false
var meta: Dictionary = {}

static var _cache: Dictionary = {}


## Geladen netwerk uit de cache (een keer van schijf per proces); null als het
## bestand ontbreekt of niet leest.
static func laad(pad_: String = STANDAARD_PAD) -> NeuraalNet:
	if _cache.has(pad_):
		return _cache[pad_]
	var net := NeuraalNet.new()
	if not net._lees(pad_):
		_cache[pad_] = null
		return null
	_cache[pad_] = net
	return net


static func wis_cache() -> void:
	_cache.clear()


func _lees(pad_: String) -> bool:
	if not FileAccess.file_exists(pad_):
		return false
	var f := FileAccess.open(pad_, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		push_error("NeuraalNet: %s is geen json-object" % pad_)
		return false
	pad = pad_
	kenmerk_versie = int(data.get("kenmerk_versie", -1))
	kenmerken = int(data.get("kenmerken", 0))
	mu = PackedFloat32Array(data.get("mu", []))
	sigma = PackedFloat32Array(data.get("sigma", []))
	if mu.size() != kenmerken or sigma.size() != kenmerken:
		push_error("NeuraalNet: mu/sigma passen niet op %d kenmerken" % kenmerken)
		return false
	lagen.clear()
	var breedte: int = kenmerken
	for laag in data.get("lagen", []):
		var w_in: Array = laag.get("w", [])
		var b: PackedFloat32Array = PackedFloat32Array(laag.get("b", []))
		if w_in.size() != breedte:
			push_error("NeuraalNet: laag verwacht %d invoer, kreeg %d rijen" % [breedte, w_in.size()])
			return false
		var uit: int = b.size()
		var w: Array = []
		for rij in w_in:
			var r := PackedFloat32Array(rij)
			if r.size() != uit:
				push_error("NeuraalNet: rij van %d past niet op %d uitvoer" % [r.size(), uit])
				return false
			w.append(r)
		lagen.append({"w": w, "b": b, "uit": uit})
		breedte = uit
	if lagen.is_empty() or breedte != 1:
		push_error("NeuraalNet: laatste laag moet breedte 1 hebben (nu %d)" % breedte)
		return false
	var proef = data.get("proef", null)
	if proef is Dictionary:
		proef_invoer = PackedFloat32Array(proef.get("invoer", []))
		proef_uitvoer = float(proef.get("uitvoer", 0.0))
		heeft_proef = proef_invoer.size() == kenmerken
	meta = data.get("meta", {})
	return true


## Waarde van een kenmerkrij. Rekent in doubles (GDScript float); de
## gewichten zelf zijn float32, net als in de trainer.
func waarde(x: PackedFloat32Array) -> float:
	assert(x.size() == kenmerken, "NeuraalNet: %d kenmerken, netwerk wil %d" % [x.size(), kenmerken])
	var h: PackedFloat64Array = PackedFloat64Array()
	h.resize(kenmerken)
	for i in kenmerken:
		h[i] = (float(x[i]) - float(mu[i])) / float(sigma[i])
	var laatste: int = lagen.size() - 1
	for li in lagen.size():
		var laag: Dictionary = lagen[li]
		var w: Array = laag.w
		var b: PackedFloat32Array = laag.b
		var uit: int = laag.uit
		var z: PackedFloat64Array = PackedFloat64Array()
		z.resize(uit)
		for j in uit:
			z[j] = float(b[j])
		for i in h.size():
			var hi: float = h[i]
			if hi == 0.0:
				continue
			var rij: PackedFloat32Array = w[i]
			for j in uit:
				z[j] += hi * float(rij[j])
		if li != laatste:
			for j in uit:
				if z[j] < 0.0:
					z[j] = 0.0
		h = z
	return h[0]


## Rekent GDScript hetzelfde als Python? (pariteit van de voorwaartse pas)
func proef_ok(tolerantie: float = 1e-4) -> bool:
	if not heeft_proef:
		return false
	return absf(waarde(proef_invoer) - proef_uitvoer) <= tolerantie


func beschrijving() -> String:
	var vorm: Array = [str(kenmerken)]
	for laag in lagen:
		vorm.append(str(int(laag.uit)))
	return "%s (kenmerk-versie %d, lagen %s%s)" % [pad, kenmerk_versie, "-".join(vorm),
		"" if meta.is_empty() else ", " + str(meta.get("bron", ""))]
