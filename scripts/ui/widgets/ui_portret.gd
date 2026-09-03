class_name UiPortret
extends Control

## Portret van een speler of factie: het embleem (gravure) in een lauwerkrans
## in teamkleur. Brief §2.3: avatar = embleem + spelerskleur + naam, geen
## uploads. Dood = gedesatureerd met het 'dead'-icoon erover.
##
##   var p := UiPortret.new(96)
##   p.zet(Constants.Doctrine.BEER, "blauw")      # krans: "rood", "blauw" of "" (zwart)
##   p.zet(Constants.Doctrine.BEER, "rood", true) # gevallen

var _krans: TextureRect
var _embleem: TextureRect
var _dood: TextureRect
var _grootte: float = 96.0


func _init(grootte: float = 96.0) -> void:
	_grootte = grootte
	custom_minimum_size = Vector2(grootte, grootte)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_krans = _rect()
	_krans.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_krans)
	# Het embleem zit in de opening van de krans: iets boven het midden, want
	# onderaan zit de strik.
	_embleem = _rect()
	_embleem.anchor_left = 0.2
	_embleem.anchor_right = 0.8
	_embleem.anchor_top = 0.08
	_embleem.anchor_bottom = 0.8
	add_child(_embleem)
	_dood = _rect()
	_dood.anchor_left = 0.55
	_dood.anchor_right = 1.0
	_dood.anchor_top = 0.55
	_dood.anchor_bottom = 1.0
	_dood.modulate = UiAssets.WARM_IVOOR
	_dood.visible = false
	add_child(_dood)


func _rect() -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## doctrine = Constants.Doctrine; team = "rood" / "blauw" / "" (zwarte krans).
func zet(doctrine: int, team: String = "", dood: bool = false) -> void:
	_embleem.texture = UiAssets.embleem(doctrine)
	var krans_naam := "krans"
	if team == "rood" or team == "blauw":
		krans_naam = "krans_" + team
	_krans.texture = UiAssets.kaart(krans_naam)
	var tint := Color(0.55, 0.55, 0.55, 0.85) if dood else Color.WHITE
	_embleem.modulate = tint
	_krans.modulate = tint
	_dood.texture = UiAssets.icoon("dead")
	_dood.visible = dood and _dood.texture != null


## Alleen het embleem, zonder krans (bv. in een tabelrij).
func zonder_krans() -> void:
	_krans.visible = false
	_embleem.anchor_left = 0.0
	_embleem.anchor_right = 1.0
	_embleem.anchor_top = 0.0
	_embleem.anchor_bottom = 1.0
