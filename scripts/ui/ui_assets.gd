class_name UiAssets
extends RefCounted

## De UI-assetpack in het spel (3 september 2026: `UI_assets_pack` plus de
## "Fog of war UI direction"-pdf van de ontwerper). Dit is de ENIGE plek die
## weet hoe de bestanden heten. Schermen vragen om een concept ("stat-hp",
## "het embleem van de Beer", "knop groot, ingedrukt") en krijgen een
## Texture2D of een StyleBox terug.
##
## Bestanden worden op NAAM gezocht onder res://assets/ui (Bestandsindex),
## dus de mappen daar mag je herindelen. De namen van de ontwerper blijven
## staan, inclusief zijn typo's: `button_2_bloccked` en `Croccodile` worden
## herkend, zodat een nieuwe drop van het pack gewoon werkt.
##
## Het thema (thema()) legt de autoload UiThema over het root-venster: elke
## Button, PanelContainer en Label in het spel ziet er daarmee vanzelf uit
## als het pack. Andere vormen kies je per node met theme_type_variation;
## de lijst staat onderaan bij THEMA-VARIANTEN.

const MAP := "res://assets/ui"

# --- Palet (pdf pagina 8: Colors/Font) ---------------------------------------
const PERKAMENT_LICHT := Color("#E6D7B8")
const PERKAMENT_WARM := Color("#C9AD7B")
const OUD_BRUIN := Color("#8E6840")
const DONKER_LEER := Color("#4A2F21")
const INKT := Color("#1E1712")
const WARM_IVOOR := Color("#F3EBDD")
const MESSING := Color("#B38A47")
const OUD_MESSING := Color("#7A5A33")
const WAS_ROOD := Color("#7E2C24")
const DIEP_ROOD := Color("#A63A2B")
const SELECTIE_GOUD := Color("#D9B84A")
## De "veldtafel": het donkere hout waar de perkamenten panelen op liggen
## (achtergrond van menu's, hub en grootboek). Niet in het pack, wel in de
## pdf-achtergrond gesampled.
const VELDTAFEL := Color("#231912")
const VELDTAFEL_LICHT := Color("#33251B")

## Teamkleuren (rood = speler 1, blauw = speler 2, zelfde regel als de
## teamringen op het bord). De donkere varianten zijn uit de linten en
## zegels van het pack gesampled, de lichte zijn voor tekst op de veldtafel.
const TEAM_ROOD := Color("#7E2C24")
const TEAM_BLAUW := Color("#2B3A78")
const TEAM_ROOD_LICHT := Color("#E0705F")
const TEAM_BLAUW_LICHT := Color("#8A9FE8")

# --- Iconen: id uit docs/design/UI-SPEC-EN.md ("Icon list") -> bestand ---------
## Een waarde mag een Array zijn: dan wint het eerste bestand dat bestaat.
const ICONEN := {
	# A. kaartstats
	"stat-hp": "hp.png",
	"stat-speed": "speed.png",
	"stat-attack": "attack.png",
	# B. voorraad en status
	"pool": "reinforcement_pool.png",
	"cp": "command_points.png",
	"score": "campaign_points.png",
	"alive": "alive.png",
	"dead": "dead.png",
	"initiative": "initiative.png",
	"hidden": "hidden.png",
	# C. acties
	"act-melee": "melee.png",
	"act-shot": "shot.png",
	"act-move": "move.png",
	"act-charge": "charge.png",
	"act-wolfstep": "wolf_step.png",
	"act-roll": "cannon_roll.png",
	"act-fire": "cannon_fire.png",
	"act-retreat": "cannon_retreat.png",
	# D. eenheden en spawn
	"unit-infantry": "infantry.png",
	"unit-cavalry": "cavalry.png",
	"unit-artillery": "artillery.png",
	"spawn": "spawn.png",
	# E. fasen
	"phase-setup": "setup.png",
	"phase-define": "define.png",
	"phase-reveal": "reveal.png",
	"phase-link": "link.png",
	# F. uitslagen
	"win-harbor": ["Victory.png", "victory.png"],
	"draw": "draw.png",
	"forfeit": "forfeit.png",
	# extra in het pack (niet in de speclijst)
	"check": ["Check_icon.png", "check_icon.png"],
}

## Spec-id's die de ontwerper nog NIET geleverd heeft (campagne/sociaal en
## tijd). icoon() geeft daar null voor; schermen vallen dan terug op tekst.
const NOG_NIET_GELEVERD := ["vote", "nomination", "donation", "testament",
	"report", "chat", "clock", "pin"]

## Fase-icoon per engine-fase (E in de spec; actie hergebruikt melee, spawn
## hergebruikt spawn).
static func fase_icoon_id(phase: int) -> String:
	if phase == Phase.Type.PLACEMENT or phase == Phase.Type.PRE_GAME:
		return "phase-setup"
	if Phase.is_define(phase):
		return "phase-define"
	if Phase.is_reveal(phase):
		return "phase-reveal"
	if Phase.is_linking(phase):
		return "phase-link"
	if phase == Phase.Type.ACTION:
		return "act-melee"
	if phase == Phase.Type.CYCLE_SPAWN:
		return "spawn"
	if phase == Phase.Type.GAME_OVER:
		return "win-harbor"
	return ""

# --- Emblemen (pdf pagina 5) -------------------------------------------------
const EMBLEMEN := {
	Constants.Doctrine.MENS: ["Pig.png", "pig.png"],
	Constants.Doctrine.MUIS: ["Mouse.png", "mouse.png"],
	Constants.Doctrine.LEEUW: ["Lion.png", "lion.png"],
	Constants.Doctrine.BEER: ["Bear.png", "bear.png"],
	Constants.Doctrine.WOLF: ["Wolf.png", "wolf.png"],
	Constants.Doctrine.VOS: ["Crocodile.png", "Croccodile.png", "crocodile.png"],
}

# --- Kaartonderdelen (pdf pagina 2 en 3) --------------------------------------
const KAART := {
	"frame": "Card_clear_frame.png",
	"rug_1": "Back_1.png",
	"rug_2": "Back_2.png",
	"lint_rood": "Red_ornament.png",
	"lint_blauw": "Blue_ornament.png",
	"gekoppeld_rood": "Card_status_linked_red.png",
	"gekoppeld_blauw": "Card_status_linked_blue.png",
	"onthuld_rood": "Card_status_revealed_red.png",
	"onthuld_blauw": "Card_status_revealed_blue.png",
	"selecteerbaar_rood": "Card_status_selectable_red.png",
	"selecteerbaar_blauw": "Card_status_selectable_blue.png",
	"cp_rood": "CP_red.png",
	"cp_blauw": "CP_blue.png",
	"cp_leeg": "CP_blocked.png",
	"krans": "Card_faction_holder.png",
	"krans_rood": "Card_faction_holder_red.png",
	"krans_blauw": "Card_faction_holder_blue.png",
	"naamplaat": "Card_top.png",
	"sierlijn": "Card_ornament_1.png",
	"specs": "Card_specs_holder.png",
	"specs_sierlijn": "Card_specs_holder_ornament.png",
	"specs_naam": "Card_specs_name_holder.png",
	"plus": "Card_editable_button_plus_standard.png",
	"plus_ingedrukt": "Card_editable_button_plus_pressed.png",
	"min": "Card_editable_button_minus_standard.png",
	"min_ingedrukt": "Card_editable_button_minus_pressed.png",
	"paneel_balk": "Frame_1.png",
	"paneel_veldtafel": "Frame_2.png",
	"paneel_papier": "Frame_3.png",
	"perkament": "Texture_1.png",
}

## Vaste maten van het kaartontwerp (pdf pagina 3, in pixels van het
## 645x989-frame). card_view.tscn bouwt hierop; de hand schaalt de hele kaart.
const KAART_MAAT := Vector2(645, 989)
const KAART_LINT_X := 78.0          # het losse lint (72 breed) staat hier
const KAART_GEKOPPELD_X := 21.0     # het lint-met-zegel (187 breed): strook op dezelfde plek
const KAART_NAAMPLAAT_Y := 22.0
const KAART_KRANS_Y := 98.0
const KAART_KRANS_SCHAAL := 0.94
const KAART_SIERLIJN_Y := 440.0
const KAART_TITEL_Y := 366.0
const KAART_SPECS_Y := 492.0
const KAART_SPECS_X := [54.0, 238.0, 422.0]
const KAART_CP_MIDDEN := Vector2(322.0, 871.0)
const KAART_CP_SCHAAL := 0.43
const KAART_ONTHULD_POS := Vector2(415.0, 830.0)
const KAART_ONTHULD_SCHAAL := 0.85
const KAART_ONTHULD_HOEK_GRADEN := -12.0

# --- Knoppen (pdf pagina 6): variant -> [basisnaam, marge_x, marge_y] --------
## De marges zijn de 9-patch-randen in texture-pixels (hoekplaat + lijst).
## "rond" heeft geen 9-patch: die knop moet vierkant blijven.
const KNOPPEN := {
	"klein": ["button_3", 36, 30],
	"klein_breed": ["button_4", 36, 30],
	"groot": ["button_1", 50, 48],
	"breed": ["button_2", 50, 48],
	"rood": ["button_5", 48, 46],
	"rond": ["button_6", 0, 0],
	"vierkant": ["button_7", 42, 42],
}
const KNOP_STATEN := {"normaal": "", "ingedrukt": "_pressed", "geblokkeerd": "_blocked"}
## Knoppen met een donkere vulling krijgen ivoren tekst; de rest inkt.
const KNOPPEN_DONKER := ["rood", "rond", "vierkant"]

# --- Panelen (pdf pagina 7): naam -> [bestand, marge_x, marge_y] --------------
const PANELEN := {
	"balk": ["Frame_1.png", 56, 52],
	"veldtafel": ["Frame_2.png", 54, 54],
	"papier": ["Frame_3.png", 54, 54],
	"naamplaat": ["Card_top.png", 40, 20],
	"specs": ["Card_specs_holder.png", 16, 16],
	"specs_naam": ["Card_specs_name_holder.png", 10, 6],
	"perkament": ["Texture_1.png", 40, 40],
}

# --- Fonts (pdf pagina 8): Roboto Slab SemiBold voor tekst, Rye voor cijfers --
## Per rol de kandidaten in volgorde van voorkeur; het eerste bestand dat
## onder assets/ui staat wint. Ontbreekt alles: null (Godot-standaardfont).
## Rye en RobotoSlab-SemiBold zitten NIET in het pack; drop ze in
## assets/ui/fonts/ (Google Fonts) en het thema pakt ze vanzelf op.
const FONTS := {
	"tekst": ["RobotoSlab-SemiBold.ttf", "RobotoSlab_SemiBold.ttf", "RobotoSlab[wght].ttf",
		"RobotoSlab_Regular.ttf", "RobotoSlab-Regular.ttf", "RobotoSlab_Bold.ttf"],
	"kop": ["RobotoSlab-SemiBold.ttf", "RobotoSlab_SemiBold.ttf", "RobotoSlab[wght].ttf",
		"RobotoSlab_Bold.ttf", "RobotoSlab-Bold.ttf", "RobotoSlab_Regular.ttf"],
	"cijfers": ["Rye-Regular.ttf", "Rye_Regular.ttf", "RobotoSlab_Bold.ttf", "RobotoSlab-Bold.ttf",
		"RobotoSlab-SemiBold.ttf", "RobotoSlab[wght].ttf", "RobotoSlab_Regular.ttf"],
}
## Het bestand dat de ontwerper bedoelt; alles daarna is terugval.
const FONTS_BEDOELD := {"tekst": "RobotoSlab-SemiBold.ttf", "kop": "RobotoSlab-SemiBold.ttf",
	"cijfers": "Rye-Regular.ttf"}

static var _texturen: Dictionary = {}
static var _fonts: Dictionary = {}
static var _gemeld: Dictionary = {}
static var _thema: Theme = null


# --- Zoeken ---------------------------------------------------------------------

## Eerste naam uit de lijst die onder assets/ui bestaat; "" als geen.
static func _eerste_aanwezige(namen) -> String:
	if namen is String:
		namen = [namen]
	for naam in namen:
		if Bestandsindex.vind(MAP, String(naam)) != "":
			return String(naam)
	return ""


## Texture op bestandsnaam (of lijst van alternatieven); null + eenmalige
## waarschuwing als het bestand er niet is.
static func textuur(naam) -> Texture2D:
	var gekozen := _eerste_aanwezige(naam)
	var sleutel: String = gekozen if gekozen != "" else str(naam)
	if _texturen.has(sleutel):
		return _texturen[sleutel]
	var tex: Texture2D = null
	if gekozen != "":
		var res = load(Bestandsindex.vind(MAP, gekozen))
		if res is Texture2D:
			tex = res
	if tex == null and not _gemeld.has(sleutel):
		_gemeld[sleutel] = true
		push_warning("UiAssets: '%s' niet gevonden onder %s" % [sleutel, MAP])
	_texturen[sleutel] = tex
	return tex


## Icoon op spec-id ("stat-hp", "act-melee", ...). Null voor id's die nog
## niet geleverd zijn (NOG_NIET_GELEVERD) of onbekend zijn.
static func icoon(id: String) -> Texture2D:
	if not ICONEN.has(id):
		return null
	return textuur(ICONEN[id])


static func icoon_ids() -> Array:
	var uit: Array = ICONEN.keys()
	uit.sort()
	return uit


## Welke spec-id's ontbreken er nu echt (bestand niet aanwezig).
static func ontbrekende_iconen() -> Array:
	var uit: Array = []
	for id in NOG_NIET_GELEVERD:
		if not ICONEN.has(id) or _eerste_aanwezige(ICONEN[id]) == "":
			uit.append(id)
	for id in ICONEN:
		if _eerste_aanwezige(ICONEN[id]) == "" and not uit.has(id):
			uit.append(id)
	uit.sort()
	return uit


static func embleem(doctrine: int) -> Texture2D:
	return textuur(EMBLEMEN.get(doctrine, EMBLEMEN[Constants.Doctrine.MENS]))


static func kaart(deel: String) -> Texture2D:
	if not KAART.has(deel):
		push_warning("UiAssets.kaart: onbekend deel '%s'" % deel)
		return null
	return textuur(KAART[deel])


## Teamkleur van een seat (rood = speler 1, blauw = speler 2).
static func team_kleur(speler_id: int, licht: bool = false) -> Color:
	if speler_id == Constants.PLAYER_1:
		return TEAM_ROOD_LICHT if licht else TEAM_ROOD
	return TEAM_BLAUW_LICHT if licht else TEAM_BLAUW


## "rood"/"blauw": het achtervoegsel van de kaartdelen en kransen per seat.
static func team_naam(speler_id: int) -> String:
	return "rood" if speler_id == Constants.PLAYER_1 else "blauw"


# --- Fonts ------------------------------------------------------------------------

## Bestandsnaam die voor deze rol gebruikt wordt ("" = geen font gevonden).
static func font_bron(rol: String) -> String:
	return _eerste_aanwezige(FONTS.get(rol, []))


## Is het door de ontwerper bedoelde font aanwezig (niet een terugval)?
static func font_is_bedoeld(rol: String) -> bool:
	return font_bron(rol) == String(FONTS_BEDOELD.get(rol, ""))


## Font voor een rol: "tekst", "kop" of "cijfers". Null = Godot-standaard.
static func font(rol: String) -> Font:
	if _fonts.has(rol):
		return _fonts[rol]
	var f: Font = null
	var naam := font_bron(rol)
	if naam != "":
		var res = load(Bestandsindex.vind(MAP, naam))
		if res is Font:
			f = res
			if naam.contains("[wght]"):
				# Variabel font: kies het SemiBold-gewicht.
				var v := FontVariation.new()
				v.base_font = res
				var ts := TextServerManager.get_primary_interface()
				v.variation_opentype = {ts.name_to_tag("wght"): 600}
				f = v
	_fonts[rol] = f
	return f


# --- Stijlen --------------------------------------------------------------------

## 9-patch-stylebox: marges in texture-pixels, inhoudsmarges apart (-1 = zelfde).
static func _negen_patch(tex: Texture2D, mx: int, my: int, cx: int = -1, cy: int = -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = mx
	sb.texture_margin_right = mx
	sb.texture_margin_top = my
	sb.texture_margin_bottom = my
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.draw_center = true
	if cx >= 0:
		sb.content_margin_left = cx
		sb.content_margin_right = cx
	if cy >= 0:
		sb.content_margin_top = cy
		sb.content_margin_bottom = cy
	return sb


## Knopstijl: variant uit KNOPPEN, staat "normaal"/"ingedrukt"/"geblokkeerd".
## De inhoudsmarges liggen iets binnen de hoekplaten zodat tekst niet
## onnodig ver van de lijst staat. Null als het bestand ontbreekt.
static func knop_stijl(variant: String, staat: String = "normaal") -> StyleBoxTexture:
	var spec: Array = KNOPPEN.get(variant, KNOPPEN["klein"])
	var achtervoegsel: String = KNOP_STATEN.get(staat, "")
	var namen: Array = [String(spec[0]) + achtervoegsel + ".png"]
	if achtervoegsel == "_blocked":
		namen.append(String(spec[0]) + "_bloccked.png")  # typo in het pack
	var tex := textuur(namen)
	if tex == null:
		return null
	var mx: int = int(spec[1])
	var my: int = int(spec[2])
	if mx == 0:
		return _negen_patch(tex, 0, 0, 12, 12)
	return _negen_patch(tex, mx, my, maxi(8, mx - 6), maxi(6, my - 8))


## Paneelstijl uit PANELEN ("balk", "veldtafel", "papier", "naamplaat", ...).
static func paneel_stijl(naam: String) -> StyleBoxTexture:
	var spec: Array = PANELEN.get(naam, PANELEN["papier"])
	var tex := textuur(spec[0])
	if tex == null:
		return null
	var mx: int = int(spec[1])
	var my: int = int(spec[2])
	return _negen_patch(tex, mx, my, mx + 6, my + 4)


## Vlakke stijl in het palet (voor kaartjes, balken en achtergronden).
static func vlak_stijl(kleur: Color, rand_kleur: Color = Color(0, 0, 0, 0), rand: int = 0,
		radius: int = 6, marge: Vector2 = Vector2(12, 8)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = kleur
	if rand > 0:
		sb.border_color = rand_kleur
		sb.set_border_width_all(rand)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = marge.x
	sb.content_margin_right = marge.x
	sb.content_margin_top = marge.y
	sb.content_margin_bottom = marge.y
	return sb


## Kaartje in teamkleur: perkament met een dikke linkerrand (rood/blauw).
static func kaartje_stijl(speler_id: int = 0) -> StyleBoxFlat:
	var sb := vlak_stijl(PERKAMENT_LICHT, OUD_MESSING, 2, 6, Vector2(14, 10))
	if speler_id == Constants.PLAYER_1 or speler_id == Constants.PLAYER_2:
		sb.border_color = team_kleur(speler_id)
		sb.border_width_left = 8
	return sb


## Getint icoon als TextureRect (wit icoon x kleur), vierkant, houdt aspect.
static func icoon_rect(id: String, grootte: float, kleur: Color = WARM_IVOOR) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = icoon(id)
	rect.custom_minimum_size = Vector2(grootte, grootte)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = kleur
	rect.visible = rect.texture != null
	return rect


## Embleem als TextureRect (inkt-gravure, houdt aspect).
static func embleem_rect(doctrine: int, grootte: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = embleem(doctrine)
	rect.custom_minimum_size = Vector2(grootte, grootte)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


# --- Thema --------------------------------------------------------------------------

## THEMA-VARIANTEN (theme_type_variation op een node):
##   Button:         (standaard = klein perkament, button_3)
##     KnopGroot     button_1, het grote perkament (menu's)
##     KnopBreed     button_2, breed perkament (hoofdknoppen)
##     KnopKleinBreed button_4
##     KnopRood      button_5, rood (gevaar: opgeven, aanvallen)
##     KnopRond      button_6, ronde icoonknop (VIERKANT houden)
##     KnopVierkant  button_7, vierkante icoonknop
##     KnopPlus / KnopMin   de kleine +/- knopjes van de kaart
##   PanelContainer: (standaard = vlak perkament-kaartje)
##     PaneelBalk / PaneelVeldtafel / PaneelPapier   de drie lijsten (Frame_1/2/3)
##     PaneelNaamplaat / PaneelSpecs / PaneelSpecsNaam   kaartonderdelen
##     PaneelPerkament   Texture_1 (achtergrond van een heel scherm)
##     PaneelDonker      vlak, de veldtafel
##     PaneelKaartjeRood / PaneelKaartjeBlauw   feed-kaartje met teamrand
##   Label:          (standaard = ivoor, voor op de veldtafel en het bord)
##     LabelInkt / LabelInktZacht   op perkament
##     LabelKop / LabelKopInkt      kopfont
##     LabelCijfer / LabelCijferIvoor   Rye (of terugval) voor getallen
##   RichTextLabel:  RichInkt
static func thema() -> Theme:
	if _thema == null:
		_thema = _bouw_thema()
	return _thema


static func _zet_knop(t: Theme, type: String, variant: String, basis: String = "") -> void:
	if basis != "":
		t.set_type_variation(type, basis)
	var normaal := knop_stijl(variant, "normaal")
	if normaal == null:
		return
	var hover := knop_stijl(variant, "normaal")
	hover.modulate_color = Color(1.08, 1.06, 1.0)
	var ingedrukt := knop_stijl(variant, "ingedrukt")
	var geblokkeerd := knop_stijl(variant, "geblokkeerd")
	t.set_stylebox("normal", type, normaal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, ingedrukt if ingedrukt != null else normaal)
	t.set_stylebox("hover_pressed", type, ingedrukt if ingedrukt != null else normaal)
	t.set_stylebox("disabled", type, geblokkeerd if geblokkeerd != null else normaal)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	var tekst: Color = WARM_IVOOR if KNOPPEN_DONKER.has(variant) else INKT
	var gedimd := Color(tekst, 0.45)
	t.set_color("font_color", type, tekst)
	t.set_color("font_hover_color", type, tekst)
	t.set_color("font_pressed_color", type, tekst)
	t.set_color("font_hover_pressed_color", type, tekst)
	t.set_color("font_focus_color", type, tekst)
	t.set_color("font_disabled_color", type, gedimd)
	t.set_color("icon_normal_color", type, tekst)
	t.set_color("icon_hover_color", type, tekst)
	t.set_color("icon_pressed_color", type, tekst)
	t.set_color("icon_hover_pressed_color", type, tekst)
	t.set_color("icon_focus_color", type, tekst)
	t.set_color("icon_disabled_color", type, gedimd)


## De +/- knopjes van de kaart: hele texture als stylebox, geen tekst.
static func _zet_kaartknop(t: Theme, type: String, deel: String) -> void:
	t.set_type_variation(type, "Button")
	var normaal := kaart(deel)
	var ingedrukt := kaart(deel + "_ingedrukt")
	if normaal == null:
		return
	var sb_n := _negen_patch(normaal, 0, 0, 4, 4)
	var sb_h := _negen_patch(normaal, 0, 0, 4, 4)
	sb_h.modulate_color = Color(1.08, 1.06, 1.0)
	var sb_p := _negen_patch(ingedrukt if ingedrukt != null else normaal, 0, 0, 4, 4)
	var sb_d := _negen_patch(normaal, 0, 0, 4, 4)
	sb_d.modulate_color = Color(1, 1, 1, 0.4)
	t.set_stylebox("normal", type, sb_n)
	t.set_stylebox("hover", type, sb_h)
	t.set_stylebox("pressed", type, sb_p)
	t.set_stylebox("hover_pressed", type, sb_p)
	t.set_stylebox("disabled", type, sb_d)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())


static func _zet_paneel(t: Theme, type: String, sb: StyleBox, basis: String = "PanelContainer") -> void:
	if sb == null:
		return
	if type != basis:
		t.set_type_variation(type, basis)
	t.set_stylebox("panel", type, sb)


static func _zet_label(t: Theme, type: String, kleur: Color, font_rol: String = "",
		grootte: int = 0, basis: String = "Label") -> void:
	if type != basis:
		t.set_type_variation(type, basis)
	t.set_color("font_color", type, kleur)
	if font_rol != "":
		var f := font(font_rol)
		if f != null:
			t.set_font("font", type, f)
	if grootte > 0:
		t.set_font_size("font_size", type, grootte)


static func _bouw_thema() -> Theme:
	var t := Theme.new()
	var f_tekst := font("tekst")
	if f_tekst != null:
		t.default_font = f_tekst
	t.default_font_size = 20
	# Knoppen
	_zet_knop(t, "Button", "klein")
	_zet_knop(t, "KnopGroot", "groot", "Button")
	_zet_knop(t, "KnopBreed", "breed", "Button")
	_zet_knop(t, "KnopKleinBreed", "klein_breed", "Button")
	_zet_knop(t, "KnopRood", "rood", "Button")
	_zet_knop(t, "KnopRond", "rond", "Button")
	_zet_knop(t, "KnopVierkant", "vierkant", "Button")
	_zet_kaartknop(t, "KnopPlus", "plus")
	_zet_kaartknop(t, "KnopMin", "min")
	_zet_knop(t, "OptionButton", "klein")
	_zet_knop(t, "MenuButton", "klein")
	# Vinkjes: de lakzegels
	for type in ["CheckBox", "CheckButton"]:
		var aan := textuur("button_check_on.png")
		var uit := textuur("button_check_off.png")
		if aan != null and uit != null:
			t.set_icon("checked", type, aan)
			t.set_icon("unchecked", type, uit)
			t.set_icon("checked_disabled", type, aan)
			t.set_icon("unchecked_disabled", type, uit)
		t.set_color("font_color", type, WARM_IVOOR)
		t.set_color("font_hover_color", type, WARM_IVOOR)
		t.set_color("font_pressed_color", type, WARM_IVOOR)
	# Panelen
	_zet_paneel(t, "PanelContainer", kaartje_stijl())
	_zet_paneel(t, "Panel", kaartje_stijl(), "Panel")
	_zet_paneel(t, "PaneelBalk", paneel_stijl("balk"))
	_zet_paneel(t, "PaneelVeldtafel", paneel_stijl("veldtafel"))
	_zet_paneel(t, "PaneelPapier", paneel_stijl("papier"))
	_zet_paneel(t, "PaneelNaamplaat", paneel_stijl("naamplaat"))
	_zet_paneel(t, "PaneelSpecs", paneel_stijl("specs"))
	_zet_paneel(t, "PaneelSpecsNaam", paneel_stijl("specs_naam"))
	_zet_paneel(t, "PaneelPerkament", paneel_stijl("perkament"))
	_zet_paneel(t, "PaneelDonker", vlak_stijl(VELDTAFEL, Color(0, 0, 0, 0), 0, 0, Vector2(0, 0)))
	_zet_paneel(t, "PaneelKaartjeRood", kaartje_stijl(Constants.PLAYER_1))
	_zet_paneel(t, "PaneelKaartjeBlauw", kaartje_stijl(Constants.PLAYER_2))
	# Labels
	_zet_label(t, "Label", WARM_IVOOR)
	_zet_label(t, "LabelInkt", INKT)
	_zet_label(t, "LabelInktZacht", OUD_BRUIN)
	_zet_label(t, "LabelKop", WARM_IVOOR, "kop", 30)
	_zet_label(t, "LabelKopInkt", INKT, "kop", 30)
	_zet_label(t, "LabelCijfer", INKT, "cijfers", 44)
	_zet_label(t, "LabelCijferIvoor", WARM_IVOOR, "cijfers", 44)
	t.set_color("default_color", "RichTextLabel", WARM_IVOOR)
	t.set_type_variation("RichInkt", "RichTextLabel")
	t.set_color("default_color", "RichInkt", INKT)
	var f_kop := font("kop")
	if f_kop != null:
		t.set_font("bold_font", "RichTextLabel", f_kop)
		t.set_font("bold_font", "RichInkt", f_kop)
	# Dialogen (opgeven-bevestiging, rapport-detail): een donker vlak met een
	# messing rand, want de tekst-Labels in een Window blijven ivoor (op het
	# perkament van Frame_2 was dat onleesbaar; bevinding 3 september).
	var dialoog := vlak_stijl(VELDTAFEL_LICHT, MESSING, 3, 8, Vector2(28, 20))
	if dialoog != null:
		t.set_stylebox("panel", "AcceptDialog", dialoog)
		t.set_stylebox("panel", "ConfirmationDialog", dialoog)
	t.set_color("title_color", "Window", WARM_IVOOR)
	# Voortgang: messing op donker leer.
	t.set_stylebox("background", "ProgressBar", vlak_stijl(DONKER_LEER, OUD_MESSING, 1, 4, Vector2(2, 2)))
	t.set_stylebox("fill", "ProgressBar", vlak_stijl(MESSING, Color(0, 0, 0, 0), 0, 4, Vector2(2, 2)))
	t.set_color("font_color", "ProgressBar", WARM_IVOOR)
	# Tooltips
	t.set_stylebox("panel", "TooltipPanel", vlak_stijl(PERKAMENT_LICHT, OUD_MESSING, 2, 4, Vector2(10, 6)))
	t.set_color("font_color", "TooltipLabel", INKT)
	return t


## Caches leegmaken (tests, of na een nieuwe drop van het pack).
static func vergeet() -> void:
	_texturen.clear()
	_fonts.clear()
	_gemeld.clear()
	_thema = null
	Bestandsindex.vergeet(MAP)
