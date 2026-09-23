class_name BeslisLog
extends RefCounted

# L4 neuraal (22 september) -- de beslislogger: trainingsdata voor het netwerk.
#
# Per actiefase-beslissing schrijft een agent (AgentL2 of AgentL4 met
# `beslis_log` gezet) de kenmerkrij van ELKE kandidaat-na-staat plus de index
# van de gekozen zet; na de partij schrijft de arena de uitslag. Binair, want
# een partij heeft honderden beslissingen met elk tientallen tot honderden
# kandidaten van 65 floats: als json is dat gigabytes per nachtrun.
#
# Formaat (little-endian, alles in een bestand `beslissingen.bin`):
#   kop:      "FOWL" (4 bytes) | u16 formaat-versie (1) | u16 kenmerk-versie
#             | u16 aantal kenmerken
#   record:   u8 soort
#     soort 1 = beslissing: u32 partij | u8 speler | u8 doctrine
#               | u16 kandidaten | u16 gekozen | kandidaten x kenmerken f32
#     soort 2 = uitslag:    u32 partij | u8 winnaar (0 = geen, 1, 2)
#               | u8 doctrine p1 | u8 doctrine p2 | u16 cycli
#
# Lezer: tools/l4/train_net.py (`lees_beslislog`).

const MAGIC: String = "FOWL"
const FORMAAT_VERSIE: int = 1

var pad: String = ""
var beslissingen: int = 0
var uitslagen: int = 0
var kandidaten: int = 0
var _f: FileAccess = null


func _init(pad_: String) -> void:
	pad = pad_
	_f = FileAccess.open(pad_, FileAccess.WRITE)
	if _f == null:
		push_error("BeslisLog: kan %s niet openen" % pad_)
		return
	_f.big_endian = false
	_f.store_buffer(MAGIC.to_ascii_buffer())
	_f.store_16(FORMAAT_VERSIE)
	_f.store_16(Kenmerken.KENMERK_VERSIE)
	_f.store_16(Kenmerken.aantal())


func open() -> bool:
	return _f != null


func schrijf_beslissing(partij: int, speler: int, doctrine: int, rijen: Array, gekozen: int) -> void:
	if _f == null or rijen.is_empty():
		return
	_f.store_8(1)
	_f.store_32(partij)
	_f.store_8(speler)
	_f.store_8(doctrine)
	_f.store_16(rijen.size())
	_f.store_16(gekozen)
	for rij in rijen:
		_f.store_buffer((rij as PackedFloat32Array).to_byte_array())
	beslissingen += 1
	kandidaten += rijen.size()


func schrijf_uitslag(partij: int, winnaar: int, doctrine1: int, doctrine2: int, cycli: int) -> void:
	if _f == null:
		return
	_f.store_8(2)
	_f.store_32(partij)
	_f.store_8(maxi(0, winnaar))
	_f.store_8(doctrine1)
	_f.store_8(doctrine2)
	_f.store_16(cycli)
	uitslagen += 1


func sluit() -> void:
	if _f != null:
		_f.close()
		_f = null
