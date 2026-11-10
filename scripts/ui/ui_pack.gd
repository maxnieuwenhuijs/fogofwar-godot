extends RefCounted

## De levering van milestone 3 + 4 (10 november 2026: pdf "Fog of war UI Match
## Multiplayer Notification" + UI_Assets_Milestone_3.zip): Match HUD, lobby,
## ghost mode, meldingen en het entry screen. De plaatjes staan onder
## res://assets/ui/<map>/<submap>/<bestand>.png (tools/verwerk_ui_m3.py zet
## ze daar) en worden hier op PAD gevraagd, niet op naam zoals de eerste
## pack: de namen botsen onderling (drie keer Player_box_1) en met de oude
## iconen (hp.png, attack.png, move.png).
##
##   const Pack := preload("res://scripts/ui/ui_pack.gd")
##   Pack.tex("match_hud/icons/Charge")          -> Texture2D
##   Pack.plaat("match_hud/box/Round_box")       -> TextureRect, uitgerekt
##   Pack.icoon("match_hud/icons/hp", 48, kleur) -> TextureRect, houdt aspect
##   Pack.patch("match_hud/box/Info_box", Vector2(24, 20)) -> StyleBoxTexture
##
## Zonder class_name: via preload, dan werkt het ook headless voordat de
## editor de klassencache heeft bijgewerkt.

const MAP := "res://assets/ui"

## Wat een scherm minstens nodig heeft, per map (voor `-- uicheck` en de
## tests): ontbreekt hier iets, dan is de levering niet goed aangekomen.
const VERWACHT := {
	"match_hud": [
		"box/Round_box", "box/Player_box", "box/Player_box_1", "box/Player_box_2",
		"box/Player_holder", "box/Player_holder_BG", "box/Team_Resource_Bar", "box/Info_box",
		"box/Stat_Chip_Frame_1", "box/Stat_Chip_Frame_2", "box/Stat_Chip_Frame_3",
		"box/Role_Badge_FlagBearer", "box/Role_Badge_Drummer",
		"buttons/Small_button_2_default", "buttons/Small_button_2_pressed",
		"buttons/Action_Button_default", "buttons/Action_Button_pressed",
		"buttons/Arrow_button_1", "buttons/Arrow_button_2",
		"ornaments/Player_box_ornament",
		"icons/hp", "icons/move", "icons/attack", "icons/Spent_hp", "icons/Spent_stamina",
		"icons/Aura_bonus", "icons/Flag_bearer", "icons/Drummer",
		"icons/Undo", "icons/Skip", "icons/Deselect", "icons/Cancel_order",
		"icons/Meelee", "icons/Charge", "icons/Shot_target", "icons/Deploiment",
		"icons/Line_of_fire", "icons/Move_order", "icons/Wolf_step",
		"icons/Planning", "icons/Queued_order", "icons/Executing", "icons/Lapsed_order",
		"icons/Cancelled", "icons/Replaced",
		"icons/target_markers/Selected_unit", "icons/target_markers/Selectable_target",
		"icons/target_markers/Enemy_target", "icons/target_markers/Focus_marker",
		"icons/hidden_states/Hidden_unit", "icons/hidden_states/Unknow_target",
		"icons/hidden_states/Unrevealed",
		"icons/interaction_states/Selected", "icons/interaction_states/Linkable",
		"icons/interaction_states/Drop_target", "icons/interaction_states/Hit",
		"icons/interaction_states/Last_pawns", "icons/interaction_states/Cant_Act",
	],
	"lobby": [
		"bg/BG", "box/Multiplayer_lobby_holder", "box/Lobby_Info_Bar", "box/Lobby_Status_Bar",
		"box/Team_Box_1", "box/Team_Box_2", "box/Players_frame_BG", "box/State_holder",
		"box/Player_box_1", "box/Player_box_2",
		"box/Lobby_Player_Slot_player_BG1", "box/Lobby_Player_Slot_player_BG2",
		"box/Lobby_Player_Slot_player_BG3",
		"buttons/Lobby_Player_Slot_1_default", "buttons/Lobby_Player_Slot_1_pressed",
		"buttons/Lobby_Player_Slot_2_default", "buttons/Lobby_Player_Slot_2_pressed",
		"buttons/Leave_button_default", "buttons/Leave_button_pressed",
		"buttons/Ready_box_default", "buttons/Ready_box_pressed", "buttons/Not_ready_box",
		"buttons/Start_now_Active", "buttons/Start_now_Pressed", "buttons/Start_now_blocked",
		"buttons/Option_button_default", "buttons/Option_button_pressed",
		"buttons/quick_chat_button_default", "buttons/quick_chat_button_pressed",
		"buttons/Ready_Status_Icon_checked", "buttons/Ready_Status_Icon_off",
		"icons/Bot", "icons/Chat_icon", "icons/Code", "icons/Copy", "icons/Globe", "icons/Leave",
		"icons/Not_ready", "icons/Players", "icons/QUick_chat", "icons/Ready", "icons/Time_icon",
		"ornaments/Divider", "ornaments/Lobby_Player_Slot_number_holder",
	],
	"ghost": [
		"box/Ghost_mode_holder", "box/Dead_flag", "box/Blocked_box", "box/Button_blocked",
		"box/Chat_box_blocked", "box/Ghost_Stake_box", "icons/Cup",
	],
	"notificatie": [
		"box/Banner_1", "box/Banner_2", "box/Banner_3",
		"box/Push_notification_1", "box/Push_notification_2", "box/Push_notification_3",
		"button/Banner_button_default", "button/Banner_button_pressed",
		"icons/Inbattle_icon", "icons/Council_open", "icons/Battle_report",
	],
	"entry": [
		"box/Lobby_Panel_", "box/Lobby_join_code_box", "box/Lobby_join_ornament",
		"box/Lobby_quick_play_ornament", "box/Lobby_quick_with_friends_ornament",
		"buttons/Lobby_button_default", "buttons/Lobby_button_pressed",
		"buttons/button_7", "buttons/button_7_pressed",
	],
}

static var _cache: Dictionary = {}


static func pad(naam: String) -> String:
	return "%s/%s.png" % [MAP, naam]


static func bestaat(naam: String) -> bool:
	return ResourceLoader.exists(pad(naam))


## Texture op "<map>/<submap>/<naam>" zonder .png; null met een eenmalige
## waarschuwing als hij ontbreekt.
static func tex(naam: String) -> Texture2D:
	if _cache.has(naam):
		return _cache[naam]
	var t: Texture2D = null
	if bestaat(naam):
		t = load(pad(naam)) as Texture2D
	if t == null:
		push_warning("UiPack: %s ontbreekt" % pad(naam))
	_cache[naam] = t
	return t


## Wat er van VERWACHT ontbreekt ("<map>/<naam>"); leeg = de levering is compleet.
static func ontbrekend() -> Array:
	var uit: Array = []
	for map in VERWACHT:
		for naam in VERWACHT[map]:
			if not bestaat("%s/%s" % [map, naam]):
				uit.append("%s/%s" % [map, naam])
	uit.sort()
	return uit


static func aantal_verwacht() -> int:
	var n := 0
	for map in VERWACHT:
		n += (VERWACHT[map] as Array).size()
	return n


## 9-patch uit een asset. Marges in texture-pixels; inhoud (links, boven,
## rechts, onder) in scherm-pixels.
static func patch(naam: String, marge: Vector2, inhoud: Vector4 = Vector4.ZERO) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(naam)
	sb.texture_margin_left = marge.x
	sb.texture_margin_right = marge.x
	sb.texture_margin_top = marge.y
	sb.texture_margin_bottom = marge.y
	sb.content_margin_left = inhoud.x
	sb.content_margin_top = inhoud.y
	sb.content_margin_right = inhoud.z
	sb.content_margin_bottom = inhoud.w
	return sb


## Een heel plaatje op een vaste plek, uitgerekt tot de rechthoek.
static func plaat(naam: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(naam)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Een plaatje op (x, y) met maat (b, h), als kind van `ouder`.
static func zet_plaat(ouder: Control, naam: String, x: float, y: float, b: float, h: float) -> TextureRect:
	var r := plaat(naam)
	r.position = Vector2(x, y)
	r.size = Vector2(b, h)
	ouder.add_child(r)
	return r


## Icoon (houdt aspect). De witte iconen kleur je met `kleur` (modulate); de
## gekleurde (markeringen, staten) laat je wit.
static func icoon(naam: String, grootte: float, kleur: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(naam)
	# eerst de expand-stand: anders is de minimummaat die van het plaatje
	# (500 px) en wordt de maat hieronder daarop afgekapt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(grootte, grootte)
	r.size = Vector2(grootte, grootte)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = kleur
	return r


## Label in het UI-font. rol = "tekst", "kop" of "cijfers" (UiAssets.font).
static func tekst(t: String, grootte: int, kleur: Color, rol: String = "tekst") -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", grootte)
	l.add_theme_color_override("font_color", kleur)
	var f := UiAssets.font(rol)
	if f != null:
		l.add_theme_font_override("font", f)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Knop op een heel plaatje (geen 9-patch: de knop houdt de maat van het
## plaatje aan). `ingedrukt` en `uit` zijn andere plaatjes ("" = hetzelfde,
## donkerder of fletser).
static func knop(b: Button, naam: String, ingedrukt: String = "", uit: String = "",
		tekstkleur: Color = Color("#F1E6CF"), marge: Vector2 = Vector2.ZERO) -> void:
	var normaal := patch(naam, marge)
	var hover := normaal.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.1, 1.07, 1.0)
	var druk: StyleBoxTexture
	if ingedrukt != "":
		druk = patch(ingedrukt, marge)
	else:
		druk = normaal.duplicate() as StyleBoxTexture
		druk.modulate_color = Color(0.8, 0.77, 0.72)
	var blok: StyleBoxTexture
	if uit != "":
		blok = patch(uit, marge)
	else:
		blok = normaal.duplicate() as StyleBoxTexture
		blok.modulate_color = Color(0.7, 0.68, 0.64, 0.7)
	b.add_theme_stylebox_override("normal", normaal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", druk)
	b.add_theme_stylebox_override("hover_pressed", druk)
	b.add_theme_stylebox_override("disabled", blok)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for staat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(staat, tekstkleur)
	b.add_theme_color_override("font_disabled_color", Color(tekstkleur, 0.45))
	for staat in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(staat, tekstkleur)
	b.add_theme_color_override("icon_disabled_color", Color(tekstkleur, 0.45))
	var f := UiAssets.font("kop")
	if f != null:
		b.add_theme_font_override("font", f)
	b.focus_mode = Control.FOCUS_NONE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Het ronde portret van de levering: schijf, gravure van de factie, gouden
## ring. `schijf` = het plaatje achter de gravure (grijs in de HUD, teal of
## zalm in de lobby); doctrine < 0 = onbekend (de silhouet-schijf, geen
## gravure).
static func portret(doctrine: int, grootte: float, schijf: String = "match_hud/box/Player_holder_BG") -> Control:
	var houder := Control.new()
	houder.custom_minimum_size = Vector2(grootte, grootte)
	houder.size = Vector2(grootte, grootte)
	houder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := plaat("lobby/box/Lobby_Player_Slot_player_BG3" if doctrine < 0 else schijf)
	bg.name = "Schijf"
	_zet_binnen(bg, 0.05)
	houder.add_child(bg)
	var gravure := TextureRect.new()
	gravure.name = "Gravure"
	gravure.texture = UiAssets.embleem(doctrine) if doctrine >= 0 else null
	gravure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gravure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gravure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	gravure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gravure.modulate = Color(0.1, 0.08, 0.06, 0.94)
	_zet_binnen(gravure, 0.15)
	houder.add_child(gravure)
	var ring := plaat("match_hud/box/Player_holder")
	ring.name = "Ring"
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	houder.add_child(ring)
	houder.set_meta("doctrine", doctrine)
	return houder


## Een bestaand portret een andere factie geven (doctrine < 0 = onbekend).
static func zet_portret(houder: Control, doctrine: int, schijf: String = "match_hud/box/Player_holder_BG") -> void:
	if houder == null or int(houder.get_meta("doctrine", -99)) == doctrine:
		return
	houder.set_meta("doctrine", doctrine)
	var bg := houder.get_node_or_null("Schijf") as TextureRect
	var gravure := houder.get_node_or_null("Gravure") as TextureRect
	if bg != null:
		bg.texture = tex("lobby/box/Lobby_Player_Slot_player_BG3" if doctrine < 0 else schijf)
	if gravure != null:
		gravure.texture = UiAssets.embleem(doctrine) if doctrine >= 0 else null


static func _zet_binnen(c: Control, marge: float) -> void:
	c.anchor_left = marge
	c.anchor_top = marge
	c.anchor_right = 1.0 - marge
	c.anchor_bottom = 1.0 - marge
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


static func vergeet() -> void:
	_cache.clear()
