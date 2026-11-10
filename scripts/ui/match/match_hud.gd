extends Control

## De Match HUD uit het ontwerp van 10 november 2026 (pdf "Fog of war UI Match
## Multiplayer Notification", pagina 1; assets in assets/ui/match_hud/).
## Vervangt de perkamenten balk van 3 september (hud_balk.gd, waarvan alleen
## de statische helpers nog gebruikt worden).
##
## Bovenaan, in de 1080 brede kolom van het ontwerp (gecentreerd als het
## venster breder is):
##   rij 1  jouw vaandel met portret | rondebalk (cyclus, wie is aan zet, klok) | vaandel van de ander
##   rij 2  voorraadbalk: per kant levend, versterkingspunten, CP | "?" | opgeven
##   rij 3  de aanwijsregel (het bestaande $UI/PromptLabel in een perkamenten strook)
## Onderaan het pionpaneel (pion_paneel.gd) voor de geselecteerde pion.
## De actiebalk uit het ontwerp (Move, Melee, Shot, Charge, Undo) is er
## bewust NIET (Max, 10 november: "die bar onder moet eruit"): het spel toont
## alle opties tegelijk en een tik op een doel voert uit; de ene contextknop
## (ongedaan, overslaan, deselecteer) blijft.
##
## JIJ staat links in je eigen kleur (rood = stoel 1, blauw = stoel 2, net
## als de pionnen), de ander rechts. Fog (D12): reserve en CP van de ander
## zijn "?".
##
## De HUD leest elke frame uit de staat (`_process` -> `_ververs`) en zet
## alleen wat veranderde: geen enkel pad in game.gd kan hem vergeten bij te
## werken. Hij verandert zelf niets aan het spel. De drie oude labels blijven
## directe kinderen van $UI (naam en type): TopLabel en CountLabel worden
## nog gevuld door game.gd (render_digest leest de topbalk-tekst) maar zijn
## onzichtbaar; PromptLabel is de aanwijsregel zelf.
##
##   _hud_balk = MATCH_HUD_SCRIPT.new()
##   _hud_balk.bouw_in($UI, _top_label, _prompt_label, _count_label, self)
##   _hud_balk.ververs(phase, prompt_gezet) / zet_beurt(speler) / zet_timer(sec)

const Pack := preload("res://scripts/ui/ui_pack.gd")
const Beweging := preload("res://scripts/ui/ui_beweging.gd")
const PION_PANEEL := preload("res://scripts/ui/match/pion_paneel.gd")

## Maten, 1080 breed. Sinds 10 november een derde LAGER dan het ontwerp
## (Max: "op alle schermen mag die top bar echt minder pixels innemen, die
## drie top bars mogen kleiner, ook bij het spel zelf"): de drie rijen samen
## 256 hoog in plaats van 390. De vaandels zijn op 60% (dezelfde verhouding),
## de rondebalk en de voorraadbalk zijn 9-patches (het beslag in de hoeken
## houdt zijn vorm) over de volle breedte.
const BREEDTE := 1080.0
const VAANDEL := Vector2(126.0, 120.0)
const RONDE := Rect2(126.0, 0.0, 828.0, 112.0)
const PORTRET := 72.0
const PORTRET_POS := Vector2(27.0, 6.0)
const VOORRAAD := Rect2(6.0, 118.0, 808.0, 74.0)
const KNOP_MAAT := Vector2(124.0, 74.0)
const KNOP_HELP_X := 820.0
const KNOP_OPGEVEN_X := 950.0
const AANWIJS_Y := 198.0
const AANWIJS_H := 54.0
const AANWIJS_MIN := 540.0
const AANWIJS_MAX := 1010.0
const TIMER_ROOD_VANAF := 5
## Hoogte van alles wat de HUD bovenaan inneemt (voor wie eronder wil staan).
const TOP_HOOGTE := 260.0

const INKT := Color("#2A1D12")
const INKT_ZACHT := Color("#5A4632")
const IVOOR := Color("#F1E6CF")
const TIMER_ROOD := Color("#A63A2B")

var game = null            # game.gd (ongetypeerd: alleen gelezen)
var paneel = null          # pion_paneel.gd
var _top: Label = null
var _prompt: Label = null
var _telling: RichTextLabel = null
var _kolom: Control = null         # de 1080 brede kolom bovenaan
var _vaandel: Array = [null, null]  # [links (jij), rechts (de ander)]
var _portret: Array = [null, null]
var _ronde_plaat: NinePatchRect = null
var _klein: Label = null
var _groot: Label = null
var _klok_icoon: TextureRect = null
var _klok: Label = null
var _balk: NinePatchRect = null
var _tel: Array = []               # 6 labels: [jij levend, punten, cp, ander levend, punten, cp]
var _tel_icoon: Array = []
var _aanwijs: NinePatchRect = null
var _knoppen: Control = null       # "?" en opgeven: boven de overlay
var _knop_help: Button = null
var _knop_opgeven: Button = null
var _oud: Dictionary = {}          # wat er nu staat (alleen wijzigingen worden gezet)
var _timer_sec: int = -1
var _beurt_speler: int = -1


func _init() -> void:
	name = "MatchHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Hangt de HUD onder `ui` achter de labels (index 0; game.gd zet daarna de
## hp-laag op 0, waardoor de HUD op 1 komt: boven de stat-blokjes, onder de
## labels, de kaarten en de overlay). De twee knoppen komen bovenaan in `ui`,
## boven de overlay en de uitleg, net als de oude knoppenkolom.
func bouw_in(ui: Node, top: Label, prompt: Label, telling: RichTextLabel, spel) -> void:
	game = spel
	_top = top
	_prompt = prompt
	_telling = telling
	ui.add_child(self)
	ui.move_child(self, 0)
	_bouw_kolom()
	_bouw_knoppen(ui)
	paneel = PION_PANEEL.new()
	paneel.bouw_in(self, spel)
	_stijl_labels()
	_stijl_contextknop()
	_ververs()


func _kolom_wortel(naam: String) -> Control:
	var k := Control.new()
	k.name = naam
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	k.anchor_left = 0.5
	k.anchor_right = 0.5
	k.offset_left = -BREEDTE * 0.5
	k.offset_right = BREEDTE * 0.5
	k.offset_top = 0.0
	k.offset_bottom = TOP_HOOGTE
	return k


## Een plaat als 9-patch (de hoeken houden hun vorm bij een andere maat).
func _negen(naam: String, r: Rect2, mx: int, my: int) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = Pack.tex(naam)
	n.patch_margin_left = mx
	n.patch_margin_right = mx
	n.patch_margin_top = my
	n.patch_margin_bottom = my
	n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.position = r.position
	n.size = r.size
	n.pivot_offset = r.size * 0.5
	_kolom.add_child(n)
	return n


## De voorraadbalk is in het plaatje blauw links en rood rechts.
func balk_gespiegeld() -> bool:
	return _balk != null and _balk.scale.x < 0.0


func _bouw_kolom() -> void:
	_kolom = _kolom_wortel("Boven")
	add_child(_kolom)
	# rij 1: de rondebalk eerst, de vaandels eroverheen (hun schaduw valt op de balk)
	_ronde_plaat = _negen("match_hud/box/Round_box", RONDE, 40, 36)
	_klein = Pack.tekst("", 22, INKT_ZACHT, "tekst")
	_klein.position = RONDE.position + Vector2(24.0, 12.0)
	_klein.size = Vector2(640.0, 30.0)
	_klein.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_klein.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_klein.clip_text = true
	_kolom.add_child(_klein)
	_groot = Pack.tekst("", 36, INKT, "kop")
	_groot.position = RONDE.position + Vector2(24.0, 40.0)
	_groot.size = Vector2(640.0, 52.0)
	_groot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_groot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_groot.clip_text = true
	_kolom.add_child(_groot)
	_klok_icoon = TextureRect.new()
	_klok_icoon.texture = HubAssets.tex("icons/Phase_icon")
	_klok_icoon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_klok_icoon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_klok_icoon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_klok_icoon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_klok_icoon.modulate = INKT
	_klok_icoon.position = RONDE.position + Vector2(712.0, 12.0)
	_klok_icoon.size = Vector2(38.0, 44.0)
	_kolom.add_child(_klok_icoon)
	_klok = Pack.tekst("", 28, INKT, "cijfers")
	_klok.position = RONDE.position + Vector2(668.0, 56.0)
	_klok.size = Vector2(128.0, 40.0)
	_klok.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_klok.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_kolom.add_child(_klok)
	for kant in 2:
		var x: float = 0.0 if kant == 0 else BREEDTE - VAANDEL.x
		var plaat := Pack.zet_plaat(_kolom, "match_hud/box/Player_box_2", x, 0.0, VAANDEL.x, VAANDEL.y)
		_vaandel[kant] = plaat
		var p := Pack.portret(-1, PORTRET)
		p.position = Vector2(x, 0.0) + PORTRET_POS
		_kolom.add_child(p)
		_portret[kant] = p
	# rij 2: de voorraadbalk met per helft drie tellers
	_balk = _negen("match_hud/box/Team_Resource_Bar", VOORRAAD, 44, 30)
	var helft: float = VOORRAAD.size.x * 0.5
	var iconen := [UiAssets.icoon("unit-infantry"), UiAssets.icoon("pool"), UiAssets.icoon("cp")]
	for kant in 2:
		for i in 3:
			var cx: float = VOORRAAD.position.x + kant * helft + 34.0 + i * 122.0
			var ic := TextureRect.new()
			ic.texture = iconen[i]
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ic.modulate = IVOOR
			ic.position = Vector2(cx, VOORRAAD.position.y + 19.0)
			ic.size = Vector2(36.0, 38.0)
			_kolom.add_child(ic)
			_tel_icoon.append(ic)
			var l := Pack.tekst("", 29, IVOOR, "cijfers")
			l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.85))
			l.add_theme_constant_override("outline_size", 5)
			l.position = Vector2(cx + 42.0, VOORRAAD.position.y + 14.0)
			l.size = Vector2(64.0, 46.0)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_kolom.add_child(l)
			_tel.append(l)
	# rij 3: de strook achter de aanwijsregel
	_aanwijs = NinePatchRect.new()
	_aanwijs.name = "Aanwijs"
	_aanwijs.texture = Pack.tex("match_hud/box/Info_box")
	_aanwijs.patch_margin_left = 26
	_aanwijs.patch_margin_right = 26
	_aanwijs.patch_margin_top = 20
	_aanwijs.patch_margin_bottom = 20
	_aanwijs.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_aanwijs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aanwijs.visible = false
	_kolom.add_child(_aanwijs)


func _kleine_knop(x: float) -> Button:
	var b := Button.new()
	Pack.knop(b, "match_hud/buttons/Small_button_2_default", "match_hud/buttons/Small_button_2_pressed",
		"", IVOOR, Vector2(34.0, 34.0))
	b.position = Vector2(x, VOORRAAD.position.y)
	b.size = KNOP_MAAT
	b.custom_minimum_size = KNOP_MAAT
	_knoppen.add_child(b)
	return b


func _bouw_knoppen(ui: Node) -> void:
	_knoppen = _kolom_wortel("HudKnoppen")
	ui.add_child(_knoppen)
	_knop_help = _kleine_knop(KNOP_HELP_X)
	_knop_help.name = "Help"
	_knop_help.text = "?"
	_knop_help.add_theme_font_size_override("font_size", 42)
	_knop_help.pressed.connect(func() -> void: game._on_help_pressed())
	_knop_opgeven = _kleine_knop(KNOP_OPGEVEN_X)
	_knop_opgeven.name = "Opgeven"
	_knop_opgeven.tooltip_text = tr("HUD_BTN_RESIGN")
	_knop_opgeven.icon = UiAssets.icoon("forfeit")
	_knop_opgeven.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_knop_opgeven.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_knop_opgeven.expand_icon = true
	_knop_opgeven.add_theme_constant_override("icon_max_width", 40)
	_knop_opgeven.pressed.connect(func() -> void: game._on_resign_pressed())
	# Het sfeer-paneel is gereedschap van de maker en staat niet in de HUD
	# (Max, 10 november: "ambiance vlaggetje mag er ook uit"): toets L opent het.
	Beweging.plof(_knop_help, 0.05, Beweging.POP_VAN, true, Vector2(0.5, 0.5), true)
	Beweging.plof(_knop_opgeven, 0.10)


## De drie oude labels: TopLabel en CountLabel onzichtbaar (hun tekst blijft
## kloppen), PromptLabel wordt de aanwijsregel in de strook.
func _stijl_labels() -> void:
	if _top != null:
		_top.visible = false
	if _telling != null:
		_telling.visible = false
	if _prompt != null:
		_prompt.theme_type_variation = "LabelInkt"
		_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_prompt.max_lines_visible = 2
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_prompt.add_theme_font_size_override("font_size", 22)
		var f := UiAssets.font("kop")
		if f != null:
			_prompt.add_theme_font_override("font", f)
		_prompt.remove_theme_color_override("font_color")
		_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE


## De ene contextknop van game.gd (ongedaan bij het opstellen, overslaan bij
## de Wolf-stap, deselecteer bij een gekozen pion) in de stijl van de HUD:
## de donkere plaat met het icoon van de ontwerper ervoor. Hij staat
## linksonder, en schuift boven het pionpaneel zodra dat er staat.
const CTX_MAAT := Vector2(250.0, 96.0)
const CTX_ICOON := {
	"ongedaan": "match_hud/icons/Undo",
	"overslaan": "match_hud/icons/Skip",
	"deselecteer": "match_hud/icons/Deselect",
}


func _stijl_contextknop() -> void:
	var b: Button = game._context_knop
	if b == null:
		return
	b.theme_type_variation = ""
	Pack.knop(b, "match_hud/buttons/Small_button_2_default", "match_hud/buttons/Small_button_2_pressed",
		"", IVOOR, Vector2(34.0, 34.0))
	for staat in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := b.get_theme_stylebox(staat) as StyleBoxTexture
		if sb != null:
			sb.content_margin_left = 22.0
			sb.content_margin_right = 20.0
			sb.content_margin_top = 10.0
			sb.content_margin_bottom = 12.0
	b.custom_minimum_size = CTX_MAAT
	b.add_theme_font_size_override("font_size", 24)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 46)
	b.add_theme_constant_override("h_separation", 12)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER


func _leg_contextknop() -> void:
	var b: Button = game._context_knop
	if b == null or not b.visible:
		return
	var soort := "deselecteer"
	if game._placement_mode:
		soort = "ongedaan"
	elif game._wolf_step_mode:
		soort = "overslaan"
	if _zet("ctx_soort", soort):
		b.icon = Pack.tex(String(CTX_ICOON[soort]))
	var omhoog: float = 0.0
	if paneel != null and paneel.visible:
		omhoog = paneel.MAAT.y + paneel.ONDER_MARGE - 6.0
	if _zet("ctx_omhoog", omhoog):
		b.offset_left = 20.0
		b.offset_right = 20.0 + CTX_MAAT.x
		b.offset_top = -(24.0 + CTX_MAAT.y) - omhoog
		b.offset_bottom = -24.0 - omhoog


# --- De oude aanroepen van game.gd -----------------------------------------------

## Bij elke _update_hud. De fase komt uit de staat; hier alleen: is er een
## prompt gezet, dan die weer inkt maken (game.gd zet er zelf een lichte
## kleur op, bedoeld voor de oude donkere balk).
func ververs(_phase: int, prompt_gezet: bool) -> void:
	if prompt_gezet and _prompt != null:
		_prompt.add_theme_color_override("font_color", INKT)
	_ververs()


## Aanwijsregel in de (donkere) teamkleur van wie aan zet is.
func zet_beurt(player_id: int) -> void:
	if _prompt != null:
		_prompt.add_theme_color_override("font_color", UiAssets.team_kleur(player_id))
		if player_id != _beurt_speler and _beurt_speler != -1:
			Beweging.wissel(_prompt, Vector2(0.5, 0.5))
			if _groot != null:
				Beweging.wissel(_groot, Vector2(0.5, 0.5))
		_beurt_speler = player_id


## Elke frame uit de timer-tak van game._process: een hartslag per seconde in
## de laatste seconden (de tekst en de kleur zet _ververs uit dezelfde timer).
func zet_timer(seconden_over: float) -> void:
	var sec := int(ceil(seconden_over))
	if sec != _timer_sec:
		_timer_sec = sec
		if sec > 0 and sec <= TIMER_ROOD_VANAF and _klok != null:
			Beweging.punch(_klok, 1.1, Vector2(0.5, 0.5))


# --- Uit de staat -------------------------------------------------------------------

func _process(_delta: float) -> void:
	_ververs()


func _zet(sleutel: String, waarde) -> bool:
	if _oud.has(sleutel) and typeof(_oud[sleutel]) == typeof(waarde) and _oud[sleutel] == waarde:
		return false
	_oud[sleutel] = waarde
	return true


static func klok_tekst(seconden: float) -> String:
	var s := maxi(0, int(ceil(seconden)))
	return "%02d:%02d" % [int(s / 60.0), s % 60]


## De grote regel van de rondebalk: wie is er aan zet, of (in de fasen waarin
## beide spelers tegelijk kiezen) welke fase het is.
func grote_regel(st, mens: int) -> String:
	var ph: int = st.phase
	if ph == Phase.Type.PRE_GAME:
		return tr("MENU_TITLE")
	if Phase.is_linking(ph) or ph == Phase.Type.ACTION:
		return tr("HUD_TURN_YOU") if st.current_player == mens else tr("HUD_TURN_OPPONENT")
	return game._phase_label(ph)


func kleine_regel(st) -> String:
	var ph: int = st.phase
	if ph == Phase.Type.PRE_GAME:
		return ""
	var basis: String = tr("HUD_CYCLE_ROUND") % [st.cycle, st.round_number]
	if Phase.is_linking(ph) or ph == Phase.Type.ACTION:
		return "%s · %s" % [basis, game._phase_label(ph)]
	return basis


func _ververs() -> void:
	if game == null or _kolom == null or game.session == null:
		return
	var st = game.session.state
	if st == null:
		return
	var mens: int = game._human_id
	var ander: int = Constants.PLAYER_2 if mens == Constants.PLAYER_1 else Constants.PLAYER_1
	var in_spel: bool = st.phase != Phase.Type.PRE_GAME
	# rij 1
	if _zet("groot", grote_regel(st, mens)):
		_groot.text = _oud["groot"]
	if _zet("klein", kleine_regel(st)):
		_klein.text = _oud["klein"]
	var klok_aan: bool = in_spel and bool(game._timer_active)
	var klok: String = klok_tekst(game._timer_left) if klok_aan else ""
	if _zet("klok", klok):
		_klok.text = klok
	if _zet("klok_aan", klok_aan):
		_klok_icoon.modulate = Color(INKT, 1.0 if klok_aan else 0.28)
	var rood: bool = klok_aan and int(ceil(game._timer_left)) <= TIMER_ROOD_VANAF
	if _zet("klok_rood", rood):
		_klok.add_theme_color_override("font_color", TIMER_ROOD if rood else INKT)
		_klok_icoon.modulate = Color(TIMER_ROOD if rood else INKT, 1.0 if klok_aan else 0.28)
	# de vaandels: jij links, de ander rechts, elk in de kleur van zijn stoel
	if _zet("mens", mens):
		(_vaandel[0] as TextureRect).texture = Pack.tex(_vaandel_naam(mens))
		(_vaandel[1] as TextureRect).texture = Pack.tex(_vaandel_naam(ander))
		_balk.scale.x = -1.0 if mens == Constants.PLAYER_1 else 1.0   # het plaatje is blauw links, rood rechts
	if _zet("in_spel", in_spel):
		for kant in 2:
			(_vaandel[kant] as Control).visible = in_spel
			(_portret[kant] as Control).visible = in_spel
		_balk.visible = in_spel
		# In het menu geen rondebalk: het menu draagt zelf de titel (die stond
		# er dubbel), en "?" hoort dan rechtsboven in de hoek.
		for n in [_ronde_plaat, _groot, _klein, _klok, _klok_icoon]:
			(n as Control).visible = in_spel
		if _knop_help != null:
			_knop_help.position = Vector2(KNOP_HELP_X, VOORRAAD.position.y) if in_spel \
				else Vector2(BREEDTE - KNOP_MAAT.x - 10.0, 10.0)
		for n in _tel + _tel_icoon:
			(n as Control).visible = in_spel
		if _knop_opgeven != null:
			_knop_opgeven.visible = in_spel
	if in_spel:
		Pack.zet_portret(_portret[0], _factie_van(st, mens))
		Pack.zet_portret(_portret[1], _factie_van(st, ander))
		# rij 2: levend, versterkingspunten, CP. Die van de ander zijn geheim (D12).
		var campagne: bool = st.rules != null and st.rules.campaign_actief()
		var eigen: Array = [str(st.get_alive_pawns_for(mens).size()),
			str(st.pool_total(mens)) if campagne else "-",
			str(int(st.cp.get(mens, 0))) if campagne else "-"]
		var vreemd: Array = [str(st.get_alive_pawns_for(ander).size()),
			"?" if campagne else "-", "?" if campagne else "-"]
		var alle: Array = eigen + vreemd
		for i in alle.size():
			if _zet("tel%d" % i, alle[i]):
				var oud_leeg: bool = (_tel[i] as Label).text == ""
				(_tel[i] as Label).text = alle[i]
				if not oud_leeg:
					Beweging.punch(_tel[i], 1.18, Vector2(0.0, 0.5))
	# de oefen-lobby vult het hele scherm: de twee knoppen van het bord horen
	# daar niet overheen te zweven
	var lobby_open: bool = game._lobby != null and game._lobby.visible
	if _zet("knoppen_zicht", not lobby_open):
		_knoppen.visible = not lobby_open
	_leg_aanwijs(in_spel)
	if paneel != null:
		paneel.ververs()
	_leg_contextknop()


func _vaandel_naam(speler: int) -> String:
	# Player_box_1 = blauw, Player_box_2 = rood
	return "match_hud/box/Player_box_2" if speler == Constants.PLAYER_1 else "match_hud/box/Player_box_1"


## De factie van een speler, of -1 zolang die niet bekend is (online kiest
## iedereen blind; tot de onthulling staat er een silhouet).
func _factie_van(st, speler: int) -> int:
	if st.phase == Phase.Type.PRE_GAME:
		return -1
	if st.has_method("doctrine_bekend") and not st.doctrine_bekend(speler):
		return -1
	var d: int = int(st.doctrine_of(speler))
	return d if UiAssets.EMBLEMEN.has(d) else -1


## De strook volgt de tekst van het PromptLabel: breed genoeg voor een regel,
## bij een lange zin twee regels. Leeg = geen strook.
func _leg_aanwijs(in_spel: bool) -> void:
	if _prompt == null:
		return
	var tekst: String = _prompt.text if in_spel else ""
	if not _zet("aanwijs", tekst):
		return
	_aanwijs.visible = tekst != ""
	_prompt.visible = tekst != ""
	if tekst == "":
		return
	var f: Font = _prompt.get_theme_font("font")
	var fs: int = _prompt.get_theme_font_size("font_size")
	var b: float = f.get_string_size(tekst, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 70.0
	var regels := 1
	if b > AANWIJS_MAX:
		regels = 2
		b = clampf(b * 0.56 + 40.0, AANWIJS_MIN, AANWIJS_MAX)
	b = clampf(b, AANWIJS_MIN, AANWIJS_MAX)
	var h: float = AANWIJS_H if regels == 1 else AANWIJS_H + 28.0
	_aanwijs.position = Vector2((BREEDTE - b) * 0.5, AANWIJS_Y)
	_aanwijs.size = Vector2(b, h)
	# Het label is een direct kind van de CanvasLayer: schermcoordinaten.
	var links: float = _kolom.global_position.x + _aanwijs.position.x
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 0.0
	_prompt.offset_left = links + 22.0
	_prompt.offset_right = links + b - 22.0
	_prompt.offset_top = AANWIJS_Y + 4.0
	_prompt.offset_bottom = AANWIJS_Y + h - 6.0


## Voor de checks: wat er nu op de HUD staat.
func stand() -> Dictionary:
	return {
		"groot": _groot.text if _groot != null else "",
		"klein": _klein.text if _klein != null else "",
		"klok": _klok.text if _klok != null else "",
		"tellers": _tel.map(func(l): return (l as Label).text),
		"aanwijs": _aanwijs.visible if _aanwijs != null else false,
		"aanwijs_rect": Rect2(_aanwijs.position, _aanwijs.size) if _aanwijs != null else Rect2(),
		"jij_links": String((_vaandel[0] as TextureRect).texture.resource_path).get_file() if _vaandel[0] != null and (_vaandel[0] as TextureRect).texture != null else "",
		"portretten": [int((_portret[0] as Control).get_meta("doctrine", -99)), int((_portret[1] as Control).get_meta("doctrine", -99))],
		"paneel": paneel.stand() if paneel != null else {},
	}
