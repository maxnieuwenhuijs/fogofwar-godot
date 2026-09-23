class_name HubAssets
extends RefCounted

## De elementen van het Campaign Hub-ontwerp (23 september 2026, pdf
## "Campaign_hub" + de map Campaign_HUB_UI van de ontwerper) staan onder
## res://assets/ui/campaign_hub/<map>/<bestand>.png, met de namen van de
## ontwerper. Dit is de enige plek die die paden kent; de hub vraagt om
## "icons/Time_icon" en krijgt een Texture2D, StyleBox of een kant-en-klaar
## portret terug.
##
## Maten: het ontwerp is een staand frame van 564 x 981 (de maat van BG.png).
## De hub rekent alles in die ontwerp-eenheden en vermenigvuldigt met een
## schaal S (schermbreedte / 564, op 1080 breed 1,915). De frame-delen
## (Title_frame, Status_bar, de kolommen) zijn op 1x geleverd, de knoppen en
## portretten op 2-5x: ze worden op hun ontwerpmaat getekend.

const MAP := "res://assets/ui/campaign_hub"
const ONTWERP := Vector2(564.0, 981.0)

## Tekstkleuren uit het ontwerp: inkt op perkament, ivoor op de kolommen.
const INKT := Color("#2A1D12")
const INKT_ZACHT := Color("#5A4632")
const IVOOR := Color("#F1E6CF")
## Teamkleuren van de feed-figuurtjes en getallen (blauw = jouw team).
const BLAUW := Color("#1F3563")
const ROOD := Color("#8E2A1E")
## De groene quick-chat-tag (geen asset: holder 4 getint).
const GROEN := Color("#3E5A22")

static var _cache: Dictionary = {}
static var _silhouet_mat: ShaderMaterial = null


## Een gravure (zwart op transparant) als effen silhouet in een kleur: de
## vlag linksboven toont zo de factie in ivoor op het blauwe doek.
static func silhouet(kleur: Color) -> ShaderMaterial:
	if _silhouet_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(1.0);\nvoid fragment() {\n\tCOLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);\n}\n"
		_silhouet_mat = ShaderMaterial.new()
		_silhouet_mat.shader = sh
	var m := _silhouet_mat.duplicate() as ShaderMaterial
	m.set_shader_parameter("tint", kleur)
	return m


## Texture op "<map>/<naam>" zonder .png; null met een waarschuwing als hij ontbreekt.
static func tex(naam: String) -> Texture2D:
	if _cache.has(naam):
		return _cache[naam]
	var pad := "%s/%s.png" % [MAP, naam]
	var t: Texture2D = null
	if ResourceLoader.exists(pad):
		t = load(pad) as Texture2D
	if t == null:
		push_warning("HubAssets: %s ontbreekt" % pad)
	_cache[naam] = t
	return t


## 9-patch uit een asset. Marges in texture-pixels; inhoud in scherm-pixels.
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


## Een heel plaatje op een vaste plek, uitgerekt tot de rechthoek (frame-delen).
static func plaat(naam: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(naam)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Icoon (houdt aspect). kleur modulate: de witte iconen worden zo inkt of ivoor.
static func icoon(naam: String, grootte: float, kleur: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex("icons/" + naam)
	r.custom_minimum_size = Vector2(grootte, grootte)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = kleur
	return r


## Statusbadge op een portret: welk icoon hoort bij welke stand.
const STATUS_ICOON := {
	"actief": "Active_icon",     # genomineerd / aan de beurt deze ronde
	"strijd": "Inbattle_icon",   # vecht nu een duel
	"rust": "Neutral_icon",      # doet deze ronde niets
	"dood": "Dead_icon",         # gevallen
}


## Het ronde portret uit het ontwerp: gekleurde schijf (teal = jouw team,
## zalm = vijand), de gravure van de factie erop, de gouden ring eromheen en
## rechtsonder een donkere badge met de status. Dood = grijs.
static func portret(doctrine: int, eigen: bool, dood: bool, grootte: float, status: String = "") -> Control:
	var houder := Control.new()
	houder.custom_minimum_size = Vector2(grootte, grootte)
	houder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var schijf := plaat("team_enemy_holder/Your_team_holder_BG" if eigen else "team_enemy_holder/Enemy_team_holder_BG")
	_zet_binnen(schijf, 0.06)
	houder.add_child(schijf)
	var gravure := TextureRect.new()
	gravure.texture = UiAssets.embleem(doctrine)
	gravure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gravure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gravure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gravure.modulate = Color(0.1, 0.08, 0.06, 0.92)
	_zet_binnen(gravure, 0.16)
	houder.add_child(gravure)
	var ring := plaat("team_enemy_holder/Team_holder")
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	houder.add_child(ring)
	if dood:
		schijf.modulate = Color(0.62, 0.62, 0.6)
		schijf.self_modulate = Color(0.75, 0.75, 0.75)
		ring.modulate = Color(0.7, 0.68, 0.64)
	if status != "" and STATUS_ICOON.has(status):
		var badge := Control.new()
		badge.name = "Status"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.anchor_left = 0.62
		badge.anchor_top = 0.62
		badge.anchor_right = 0.98
		badge.anchor_bottom = 0.98
		houder.add_child(badge)
		var bol := plaat("team_enemy_holder/Your_enemy_team_holder_status_BG")
		bol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		badge.add_child(bol)
		var ic := icoon(String(STATUS_ICOON[status]), 0)
		_zet_binnen(ic, 0.22)
		badge.add_child(ic)
		# Het grijze schijfje (rand) om de badge, zoals in het ontwerp.
		var rand := plaat("team_enemy_holder/Team_holder")
		rand.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rand.modulate = Color(0.85, 0.85, 0.85)
		badge.add_child(rand)
	return houder


## Leeg stemrondje (nog niet gestemd): de schijf zonder gravure, verbleekt.
static func leeg_rondje(grootte: float) -> Control:
	var houder := Control.new()
	houder.custom_minimum_size = Vector2(grootte, grootte)
	houder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var schijf := plaat("team_enemy_holder/Your_team_holder_BG")
	schijf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	schijf.modulate = Color(0.85, 0.78, 0.62, 0.55)
	houder.add_child(schijf)
	return houder


static func _zet_binnen(c: Control, marge: float) -> void:
	c.anchor_left = marge
	c.anchor_top = marge
	c.anchor_right = 1.0 - marge
	c.anchor_bottom = 1.0 - marge
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


## Label in het hub-font. grootte in scherm-pixels.
static func tekst(t: String, grootte: int, kleur: Color = INKT, kop: bool = false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", grootte)
	l.add_theme_color_override("font_color", kleur)
	var f := UiAssets.font("kop" if kop else "tekst")
	if f != null:
		l.add_theme_font_override("font", f)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Knopstijl uit een asset voor alle staten (normaal, hover, ingedrukt,
## uit). `ingedrukt` = een ander plaatje voor de ingedrukte staat ("" = zelfde,
## iets donkerder).
static func knop(b: Button, naam: String, marge: Vector2, inhoud: Vector4,
		tekstkleur: Color = INKT, ingedrukt: String = "") -> void:
	var normaal := patch(naam, marge, inhoud)
	var hover := normaal.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.08, 1.05, 0.98)
	var druk: StyleBoxTexture
	if ingedrukt != "":
		druk = patch(ingedrukt, marge, inhoud)
	else:
		druk = normaal.duplicate() as StyleBoxTexture
		druk.modulate_color = Color(0.82, 0.78, 0.72)
	var uit := normaal.duplicate() as StyleBoxTexture
	uit.modulate_color = Color(0.7, 0.68, 0.64, 0.75)
	b.add_theme_stylebox_override("normal", normaal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", druk)
	b.add_theme_stylebox_override("hover_pressed", druk)
	b.add_theme_stylebox_override("disabled", uit)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for staat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(staat, tekstkleur)
	b.add_theme_color_override("font_disabled_color", Color(tekstkleur, 0.45))
	for staat in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(staat, tekstkleur)
	var f := UiAssets.font("kop")
	if f != null:
		b.add_theme_font_override("font", f)
