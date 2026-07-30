class_name Bestandsindex
extends RefCounted

## Zoekt een bestand op NAAM onder een map, hoe diep het ook weggestopt zit
## (Max, 30 juli: "er moeten folder structuren in alle mappen voor
## vindbaarheid"). De code vraagt om "infantry_atk.glb" of "musket.wav" en niet
## om een pad, dus jij mag de mappen indelen zoals je wil -- per factie, per
## categorie, per prop -- zonder dat er iets stukloopt.
##
## Per map wordt de inhoud eenmalig ingelezen en bewaard. Zet je tijdens het
## spelen bestanden bij (dat doet niemand), dan is `vergeet()` de knop.

static var _cache: Dictionary = {}


## Bestandsnaam -> volledig pad, voor alles onder `map` (recursief).
## Twee bestanden met dezelfde naam: de minst diep weggestopte wint, zodat een
## bewuste kopie bovenin voorgaat op een oude in een submap.
static func index(map: String) -> Dictionary:
	var sleutel := map.trim_suffix("/")
	if _cache.has(sleutel):
		return _cache[sleutel]
	var uit: Dictionary = {}
	_loop(sleutel, uit, 0)
	_cache[sleutel] = uit
	return uit


static func _loop(map: String, uit: Dictionary, diepte: int) -> void:
	var d := DirAccess.open(map)
	if d == null:
		return
	d.list_dir_begin()
	var naam := d.get_next()
	while naam != "":
		var pad: String = map + "/" + naam
		if d.current_is_dir():
			if not naam.begins_with("."):
				_loop(pad, uit, diepte + 1)
		else:
			# Godot legt naast een geimporteerd bestand een .import; de echte
			# naam is die zonder dat achtervoegsel.
			var kaal: String = naam.trim_suffix(".import")
			if not uit.has(kaal) or int(uit[kaal]["diepte"]) > diepte:
				uit[kaal] = {"pad": map + "/" + kaal, "diepte": diepte}
		naam = d.get_next()
	d.list_dir_end()


## Volledig pad van dit bestand, of "" als het er niet is.
static func vind(map: String, bestandsnaam: String) -> String:
	var idx: Dictionary = index(map)
	if not idx.has(bestandsnaam):
		return ""
	return String(idx[bestandsnaam]["pad"])


## Alle bestanden onder `map` met deze extensie (bv ".glb"), op naam gesorteerd.
static func alles(map: String, extensie: String) -> Array:
	var uit: Array = []
	for naam in index(map).keys():
		if String(naam).ends_with(extensie):
			uit.append(String(naam))
	uit.sort()
	return uit


## Opnieuw inlezen (map leeg = alles).
static func vergeet(map: String = "") -> void:
	if map == "":
		_cache.clear()
	else:
		_cache.erase(map.trim_suffix("/"))
