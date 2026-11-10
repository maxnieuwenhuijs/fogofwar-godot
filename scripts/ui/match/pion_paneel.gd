extends Control

## Het pionpaneel onderaan de Match HUD (ontwerp 10 november 2026, het
## "Player box": assets/ui/match_hud/box/Player_box.png, 1069 x 274).
## Toont de pion die je in je actiebeurt hebt geselecteerd: portret van zijn
## factie, type, rol (vaandeldrager of tamboer) en drie grote stat-chips:
## HP en stamina als "nu/vol" (HP 1/3, stamina 2/3) en attack zoals hij NU is
## (met het vaandel erbij). Dit lost op dat de blokjes onder een pion op een
## telefoon te klein zijn om te tellen. Het tweede blad uit het ontwerp
## (spent HP, spent stamina, aura bonus, met een pijl) is er bewust niet
## (Max, 10 november: "spent hoeft niet, laat gewoon zo zien: stamina 2/3,
## hp 1/3").
##
## Fog: van een gedekte pion van de ander (Krokodil) staan er vraagtekens,
## nooit nullen.
##
## Puur beeld uit de staat (`ververs`, elke frame vanuit match_hud.gd); het
## paneel vangt wel de tik op zijn eigen vlak, zodat je er niet doorheen een
## prop of een pion aanklikt.

const Pack := preload("res://scripts/ui/ui_pack.gd")
const Beweging := preload("res://scripts/ui/ui_beweging.gd")

const MAAT := Vector2(1069.0, 274.0)
const ONDER_MARGE := 14.0
const PORTRET := 226.0
const PORTRET_POS := Vector2(38.0, 24.0)
const CHIP := Vector2(136.0, 130.0)
const CHIP_X := [516.0, 678.0, 840.0]
const CHIP_Y := 92.0
const INKT := Color("#2A1D12")
const INKT_ZACHT := Color("#5A4632")
const IVOOR := Color("#F1E6CF")
## Per chip: [frame, kleur van icoon, kleur van het cijfer, kleur van het label].
const KLEUR_HP := Color("#8ED49A")
const KLEUR_STAMINA := Color("#A8D4F5")
const KLEUR_ATTACK_ICOON := Color("#E9C9B0")
const KLEUR_ATTACK_CIJFER := Color("#F3C56B")
const KLEUR_ATTACK_LABEL := Color("#F0914F")
const CHIPS := [
	["match_hud/box/Stat_Chip_Frame_1", "match_hud/icons/hp", "HUD_CHIP_HP", KLEUR_HP, KLEUR_HP, KLEUR_HP],
	["match_hud/box/Stat_Chip_Frame_2", "match_hud/icons/move", "HUD_CHIP_STAMINA", KLEUR_STAMINA, KLEUR_STAMINA, KLEUR_STAMINA],
	["match_hud/box/Stat_Chip_Frame_3", "match_hud/icons/attack", "HUD_CHIP_ATTACK", KLEUR_ATTACK_ICOON, KLEUR_ATTACK_CIJFER, KLEUR_ATTACK_LABEL],
]
## Lettergrootte van het getal: een los cijfer groot, "2/3" iets kleiner.
const CIJFER_GROOT := 42
const CIJFER_BREUK := 33
const ROL := {
	"flag": ["match_hud/box/Role_Badge_FlagBearer", "match_hud/icons/Flag_bearer", "HUD_ROLE_FLAG"],
	"drum": ["match_hud/box/Role_Badge_Drummer", "match_hud/icons/Drummer", "HUD_ROLE_DRUM"],
}
const TYPE_SLEUTEL := ["UNIT_INFANTRY", "UNIT_CAVALRY", "UNIT_ARTILLERY"]

var game = null
var _portret: Control = null
var _titel: Label = null
var _onder: Label = null
var _rol_plaat: TextureRect = null
var _rol_icoon: TextureRect = null
var _rol_tekst: Label = null
var _chips: Array = []      # per chip {frame, icoon, cijfer, label}
var _oud: Dictionary = {}
var _pion_id: int = -1


func _init() -> void:
	name = "PionPaneel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	visible = false


func bouw_in(hud: Control, spel) -> void:
	game = spel
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -MAAT.x * 0.5
	offset_right = MAAT.x * 0.5
	offset_top = -(MAAT.y + ONDER_MARGE)
	offset_bottom = -ONDER_MARGE
	hud.add_child(self)
	Pack.zet_plaat(self, "match_hud/box/Player_box", 0.0, 0.0, MAAT.x, MAAT.y)
	_portret = Pack.portret(-1, PORTRET)
	_portret.position = PORTRET_POS
	add_child(_portret)
	_titel = Pack.tekst("", 44, INKT, "kop")
	_titel.position = Vector2(306.0, 22.0)
	_titel.size = Vector2(330.0, 56.0)
	_titel.clip_text = true
	add_child(_titel)
	_onder = Pack.tekst("", 25, INKT_ZACHT, "tekst")
	_onder.position = Vector2(308.0, 70.0)
	_onder.size = Vector2(170.0, 34.0)
	_onder.clip_text = true
	add_child(_onder)
	var orn := Pack.zet_plaat(self, "match_hud/ornaments/Player_box_ornament", 640.0, 30.0, 116.0, 48.0)
	orn.modulate = Color(1, 1, 1, 0.85)
	_rol_plaat = Pack.zet_plaat(self, "match_hud/box/Role_Badge_FlagBearer", 318.0, 104.0, 124.0, 112.0)
	_rol_icoon = Pack.icoon("match_hud/icons/Flag_bearer", 54.0, Color("#F0D9F0"))
	_rol_icoon.position = Vector2(353.0, 122.0)
	add_child(_rol_icoon)
	_rol_tekst = Pack.tekst("", 22, INKT, "kop")
	_rol_tekst.position = Vector2(280.0, 216.0)
	_rol_tekst.size = Vector2(200.0, 32.0)
	_rol_tekst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_rol_tekst)
	for i in 3:
		var houder := Control.new()
		houder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		houder.position = Vector2(float(CHIP_X[i]), CHIP_Y)
		houder.size = CHIP
		houder.pivot_offset = CHIP * 0.5
		add_child(houder)
		var frame := Pack.zet_plaat(houder, "match_hud/box/Stat_Chip_Frame_1", 0.0, 0.0, CHIP.x, CHIP.y)
		var icoon := Pack.icoon("match_hud/icons/hp", 46.0)
		icoon.position = Vector2(10.0, 22.0)
		houder.add_child(icoon)
		var cijfer := Pack.tekst("", CIJFER_GROOT, IVOOR, "cijfers")
		cijfer.position = Vector2(56.0, 14.0)
		cijfer.size = Vector2(74.0, 60.0)
		cijfer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cijfer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cijfer.pivot_offset = Vector2(37.0, 30.0)
		houder.add_child(cijfer)
		var label := Pack.tekst("", 19, IVOOR, "kop")
		label.position = Vector2(4.0, 76.0)
		label.size = Vector2(CHIP.x - 8.0, 46.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_constant_override("line_spacing", -6)
		houder.add_child(label)
		_chips.append({"houder": houder, "frame": frame, "icoon": icoon, "cijfer": cijfer, "label": label})
	for i in _chips.size():
		var spec: Array = CHIPS[i]
		var c: Dictionary = _chips[i]
		(c.frame as TextureRect).texture = Pack.tex(String(spec[0]))
		(c.icoon as TextureRect).texture = Pack.tex(String(spec[1]))
		(c.icoon as TextureRect).modulate = spec[3]
		(c.cijfer as Label).add_theme_color_override("font_color", spec[4])
		(c.label as Label).add_theme_color_override("font_color", spec[5])
		(c.label as Label).text = tr(String(spec[2]))


## Welke pion staat er in het paneel: de geselecteerde in je eigen actiebeurt
## (ook tijdens een Wolf-stap). -1 = geen paneel.
func gekozen_pion() -> int:
	if game == null or game.session == null:
		return -1
	var st = game.session.state
	if st == null or st.phase != Phase.Type.ACTION:
		return -1
	var pid: int = int(game._selected_pawn_id)
	if pid < 0:
		return -1
	var p = st.pawns.get(pid)
	if p == null or p.is_eliminated:
		return -1
	return pid


func _zet(sleutel: String, waarde) -> bool:
	if _oud.has(sleutel) and typeof(_oud[sleutel]) == typeof(waarde) and _oud[sleutel] == waarde:
		return false
	_oud[sleutel] = waarde
	return true


## De drie getallen als tekst: HP "nu/vol", stamina "nu/vol" (nu = wat hij
## op dit moment kan uitgeven, dus met het punt van de trom erbij), attack
## zoals hij nu slaat (met het vaandel erbij). "?" voor een gedekte pion,
## "-" voor een standbeeld.
static func waarden(st, p, gedekt: bool) -> Array:
	if gedekt:
		return ["?", "?", "?"]
	if not p.is_active:
		return ["-", "-", "-"]
	return ["%d/%d" % [p.current_hp, p.max_hp],
		"%d/%d" % [Rules.stamina_beschikbaar(st, p), p.max_stamina],
		str(Rules.effectieve_attack(st, p))]


func ververs() -> void:
	var pid: int = gekozen_pion()
	if pid != _pion_id:
		var was: int = _pion_id
		_pion_id = pid
		visible = pid >= 0
		_oud.clear()
		if pid >= 0:
			if was < 0:
				Beweging.schuif_in(self, Vector2(0.0, 40.0))
	if pid < 0:
		return
	var st = game.session.state
	var p = st.pawns.get(pid)
	var eigen: bool = p.owner_id == game._human_id
	var gedekt: bool = (not eigen) and bool(game.session.pion_gedekt(pid))
	var factie: int = int(st.doctrine_of(p.owner_id))
	Pack.zet_portret(_portret, factie if UiAssets.EMBLEMEN.has(factie) else -1)
	if _zet("titel", tr(String(TYPE_SLEUTEL[clampi(int(p.unit_type), 0, 2)]))):
		_titel.text = _oud["titel"]
	var onder: String = tr("DOCTRINE_%d_NAME" % factie)
	if not p.is_active:
		onder = tr("HUD_PAWN_NO_CARD")
	if _zet("onder", onder):
		_onder.text = onder
	var rol: String = String(p.rol)
	if _zet("rol", rol):
		var heeft: bool = ROL.has(rol)
		_rol_plaat.visible = heeft
		_rol_icoon.visible = heeft
		_rol_tekst.visible = heeft
		if heeft:
			_rol_plaat.texture = Pack.tex(String(ROL[rol][0]))
			_rol_icoon.texture = Pack.tex(String(ROL[rol][1]))
			_rol_icoon.modulate = Color("#F0D9F0") if rol == "flag" else Color("#CFEBD8")
			_rol_tekst.text = tr(String(ROL[rol][2]))
	var w: Array = waarden(st, p, gedekt)
	for i in 3:
		if _zet("w%d" % i, w[i]):
			var l: Label = _chips[i].cijfer
			var leeg: bool = l.text == ""
			l.text = w[i]
			l.add_theme_font_size_override("font_size", CIJFER_BREUK if String(w[i]).length() > 2 else CIJFER_GROOT)
			if not leeg:
				Beweging.punch(l, 1.2, Vector2(0.5, 0.5))


func stand() -> Dictionary:
	return {
		"zichtbaar": visible,
		"pion": _pion_id,
		"titel": _titel.text if _titel != null else "",
		"onder": _onder.text if _onder != null else "",
		"rol": _rol_tekst.text if (_rol_tekst != null and _rol_tekst.visible) else "",
		"cijfers": _chips.map(func(c): return (c.cijfer as Label).text),
		"labels": _chips.map(func(c): return (c.label as Label).text),
	}
