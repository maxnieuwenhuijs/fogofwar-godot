class_name CoreHash
extends RefCounted

## F4.3h — de hash van alles wat de spelregels IS: core/ (recursief) plus de
## pure kern onder scripts/core. Client en worker vergelijken deze hash
## (bouwplan §11.5): verschillen ze, dan spelen ze een ander spel en weigert
## de client te verbinden. Verhuisd uit tools/server_worker.gd zodat de
## client dezelfde berekening draait; dit bestand zelf zit NIET in de lijst
## (en niet onder res://core), dus de hash is onveranderd.

const KERN: Array[String] = ["constants.gd", "GameState.gd", "Rules.gd", "Card.gd", "Pawn.gd", "Phase.gd"]


static func bereken() -> String:
	var paden: Array = []
	_verzamel_gd("res://core", paden)
	for naam in KERN:
		paden.append("res://scripts/core/" + naam)
	paden.sort()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for pad in paden:
		ctx.update((String(pad) + "\n").to_utf8_buffer())
		ctx.update(FileAccess.get_file_as_bytes(pad))
	return ctx.finish().hex_encode()


static func _verzamel_gd(map: String, uit: Array) -> void:
	var dir := DirAccess.open(map)
	if dir == null:
		return
	dir.list_dir_begin()
	var naam := dir.get_next()
	while naam != "":
		var pad := map + "/" + naam
		if dir.current_is_dir():
			if not naam.begins_with("."):
				_verzamel_gd(pad, uit)
		elif naam.ends_with(".gd"):
			uit.append(pad)
		naam = dir.get_next()
	dir.list_dir_end()
