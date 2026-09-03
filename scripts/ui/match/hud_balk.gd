class_name HudBalk
extends PanelContainer

## De HUD-balk bovenaan het bord (pdf pagina 7: Frame_1, de brede balk).
## Ligt als perkament ACHTER de drie bestaande labels van game.tscn
## ($UI/TopLabel, $UI/PromptLabel, $UI/CountLabel). Die blijven directe
## kinderen van $UI met hun naam en type (capture.gd en de tools resolven ze
## zo); de balk maakt ze inkt-op-perkament en tekent links het fase-icoon.
## Het thema onder de CanvasLayer regelt UiThema (node_added), niet deze balk.
##
##   _hud_balk = HUD_BALK_SCRIPT.new()            # preload: parst zonder klassencache
##   _hud_balk.bouw_in($UI, _top_label, _prompt_label, _count_label)
##   _hud_balk.ververs(state.phase, prompt != "")  # bij elke _update_hud
##   _hud_balk.zet_beurt(player_id)                 # prompt in teamkleur
##   _hud_balk.zet_timer(_timer_left)               # laatste 5 s diep rood
##
## Geometrie (1080x1920-canvas): de balk loopt van BALK_LINKS tot BALK_RECHTS;
## de knoppenkolom rechtsboven (game.gd, _build_help_button) staat op KOLOM_X
## en valt er dus naast, niet overheen. Het sfeerpaneel (offset_top 140)
## bedekt de onderste rand van de sfeer-knop zodra het open staat; dat was
## al zo en de L-toets sluit het ook.

const BALK_LINKS := 10.0
const BALK_RECHTS := 960.0
const BALK_BOVEN := 4.0
const BALK_ONDER := 190.0
## De knoppenkolom rechts van de balk (breedte 88, x 976..1064).
const KOLOM_X := 976.0
const KOLOM_BREEDTE := 88.0
const ICOON_GROOTTE := 56.0
## Inhoudsmarge van de balk (kleiner dan de 9-patch-rand van Frame_1, want de
## labels staan er los overheen; alleen het fase-icoon leeft hierbinnen).
const MARGE_X := 30
const MARGE_Y := 16
## De timer-tekst kleurt diep rood in de laatste seconden.
const TIMER_ROOD_VANAF := 5
## Grootte van de iconen in de tel-regel (CountLabel, BBCode).
const TEL_ICOON := 30

var _top: Label = null
var _prompt: Label = null
var _telling: RichTextLabel = null
var _fase_icoon: TextureRect = null
var _fase_id: String = ""
var _timer_rood: bool = false


func _init() -> void:
	name = "HudBalk"
	theme_type_variation = "PaneelBalk"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = BALK_LINKS
	offset_top = BALK_BOVEN
	offset_right = BALK_RECHTS
	offset_bottom = BALK_ONDER
	var sb := UiAssets.paneel_stijl("balk")
	if sb != null:
		sb.content_margin_left = MARGE_X
		sb.content_margin_right = MARGE_X
		sb.content_margin_top = MARGE_Y
		sb.content_margin_bottom = MARGE_Y
		add_theme_stylebox_override("panel", sb)
	# Het fase-icoon: links in de balk, verticaal gecentreerd (de container
	# geeft het de volle hoogte, KEEP_ASPECT_CENTERED tekent het in het midden).
	_fase_icoon = UiAssets.icoon_rect("", ICOON_GROOTTE, UiAssets.INKT)
	_fase_icoon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_fase_icoon.size_flags_vertical = Control.SIZE_FILL
	add_child(_fase_icoon)


## Hangt de balk onder `ui` achter de labels (index 0; game.gd zet daarna de
## hp-laag op 0, waardoor de balk op 1 komt: boven de hp-blokjes, onder de
## labels) en zet de labels in inkt. Instantie-methode en geen static
## fabriek: een verwijzing naar de eigen class_name zou de klassencache
## (--import) vereisen, en die bouwt de hoofdsessie centraal.
func bouw_in(ui: Node, top: Label, prompt: Label, telling: RichTextLabel) -> void:
	_top = top
	_prompt = prompt
	_telling = telling
	ui.add_child(self)
	ui.move_child(self, 0)
	_stijl_labels()


## Tekst op perkament = inkt (regel uit het contract). De offsets en
## fontgroottes staan in game.tscn; hier alleen de varianten en het wrappen.
func _stijl_labels() -> void:
	if _top != null:
		_top.theme_type_variation = "LabelKopInkt"
		_top.remove_theme_color_override("font_color")
	if _prompt != null:
		_prompt.theme_type_variation = "LabelInkt"
		_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_prompt.max_lines_visible = 2
		_prompt.remove_theme_color_override("font_color")
	if _telling != null:
		_telling.theme_type_variation = "RichInkt"
		_telling.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_telling.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Bij elke _update_hud: fase-icoon bijwerken; is er een prompt gezet, dan
## die weer inkt maken (game.gd zet er zelf nog een lichte kleur op).
func ververs(phase: int, prompt_gezet: bool) -> void:
	var id := UiAssets.fase_icoon_id(phase)
	if id != _fase_id:
		_fase_id = id
		_fase_icoon.texture = UiAssets.icoon(id) if id != "" else null
		_fase_icoon.visible = _fase_icoon.texture != null
	if prompt_gezet and _prompt != null:
		_prompt.add_theme_color_override("font_color", UiAssets.INKT)
	_zet_timer_rood(false)


## Prompt in de (donkere) teamkleur van wie aan zet is.
func zet_beurt(player_id: int) -> void:
	if _prompt != null:
		_prompt.add_theme_color_override("font_color", UiAssets.team_kleur(player_id))


## Elke frame uit de timer-tak van _process: de laatste seconden diep rood.
func zet_timer(seconden_over: float) -> void:
	_zet_timer_rood(int(ceil(seconden_over)) <= TIMER_ROOD_VANAF)


func _zet_timer_rood(aan: bool) -> void:
	if aan == _timer_rood:
		return
	_timer_rood = aan
	if _top == null:
		return
	if aan:
		_top.add_theme_color_override("font_color", UiAssets.DIEP_ROOD)
	else:
		_top.remove_theme_color_override("font_color")


# --- Kleine knoppen -----------------------------------------------------------

## Een kleine knop (bv. 88x60) op een 9-patch die voor grotere vlakken is
## getekend: de hoekplaten (36-48 px) passen niet in de knopmaat en de
## inhoudsmarges rekken de knop op tot buiten beeld. Hier worden per staat de
## texture-marges op de halve knopmaat begrensd (of, als zelfs dat niet past,
## de hele texture geschaald), de inhoudsmarges klein gehouden en wordt de
## tekst geknipt in plaats van de knop opgerekt.
static func compacte_knop(knop: Button, variant: String, maat: Vector2,
		marge: Vector2i = Vector2i(6, 4)) -> void:
	knop.custom_minimum_size = maat
	knop.clip_text = true
	var max_x := int(maat.x * 0.5) - 1
	var max_y := int(maat.y * 0.5) - 1
	for paar in [["normal", "normaal"], ["hover", "normaal"], ["pressed", "ingedrukt"],
			["hover_pressed", "ingedrukt"], ["disabled", "geblokkeerd"]]:
		var sb := UiAssets.knop_stijl(variant, String(paar[1]))
		if sb == null:
			sb = UiAssets.knop_stijl(variant, "normaal")
		if sb == null:
			continue
		if sb.texture_margin_left + sb.texture_margin_right + 8.0 > maat.x 				or sb.texture_margin_top + sb.texture_margin_bottom + 8.0 > maat.y:
			# Past de 9-patch niet: de hele texture geschaald tekenen, anders
			# stoten de vier hoekplaten in het midden op elkaar (kruisnaad).
			sb.texture_margin_left = 0.0
			sb.texture_margin_right = 0.0
			sb.texture_margin_top = 0.0
			sb.texture_margin_bottom = 0.0
		else:
			sb.texture_margin_left = minf(sb.texture_margin_left, float(max_x))
			sb.texture_margin_right = minf(sb.texture_margin_right, float(max_x))
			sb.texture_margin_top = minf(sb.texture_margin_top, float(max_y))
			sb.texture_margin_bottom = minf(sb.texture_margin_bottom, float(max_y))
		sb.content_margin_left = marge.x
		sb.content_margin_right = marge.x
		sb.content_margin_top = marge.y
		sb.content_margin_bottom = marge.y
		knop.add_theme_stylebox_override(String(paar[0]), sb)


# --- BBCode voor de tel-regel -------------------------------------------------

## Icoon als [img]-tag in een kleur; "" als het icoon er niet is.
static func img_bbcode(icoon_id: String, kleur: Color, grootte: int = TEL_ICOON) -> String:
	var tex := UiAssets.icoon(icoon_id)
	if tex == null or tex.resource_path == "":
		return ""
	return "[img width=%d color=#%s]%s[/img]" % [grootte, kleur.to_html(false), tex.resource_path]


## "[inf] 22/22   [inf] 22/22" in de donkere teamkleuren (op perkament).
static func telling_bbcode(rood: int, rood_totaal: int, blauw: int, blauw_totaal: int) -> String:
	var delen: Array = []
	for paar in [[Constants.PLAYER_1, rood, rood_totaal], [Constants.PLAYER_2, blauw, blauw_totaal]]:
		var kleur := UiAssets.team_kleur(int(paar[0]))
		var icoon := img_bbcode("unit-infantry", kleur)
		if icoon == "":
			icoon = "●"
		delen.append("[color=#%s]%s %d/%d[/color]" % [kleur.to_html(false), icoon, int(paar[1]), int(paar[2])])
	return "    ".join(delen)


## Eigen reserve en CP-saldo met de pool- en cp-iconen (D12: alleen de eigen).
static func reserve_bbcode(pool: int, cp: int) -> String:
	var kleur := UiAssets.DONKER_LEER
	var pool_icoon := img_bbcode("pool", kleur)
	var cp_icoon := img_bbcode("cp", kleur)
	if pool_icoon == "" or cp_icoon == "":
		# Tekst-terugval; zonder gecompileerde vertaling is dit de sleutel zelf
		# (geen %-plekken), dan niet formatteren.
		var tekst := TranslationServer.translate("HUD_UI_RESERVE_TEKST")
		if tekst.find("%") != -1:
			tekst = tekst % [pool, cp]
		return "    [color=#%s]%s[/color]" % [kleur.to_html(false), tekst]
	return "    [color=#%s]%s %d   %s %d[/color]" % [kleur.to_html(false), pool_icoon, pool, cp_icoon, cp]


## Icoon-id per spawn-actie van game.gd (_show_spawn_overlay: int = koop dat
## type, "bevestig" = bevestigen, "reset" = opnieuw).
static func spawn_icoon(actie: Variant) -> String:
	if actie is int:
		return ["unit-infantry", "unit-cavalry", "unit-artillery"][clampi(int(actie), 0, 2)]
	if String(actie) == "bevestig":
		return "check"
	return ""
