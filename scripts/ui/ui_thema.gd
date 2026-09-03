extends Node

## Autoload UiThema: legt het thema uit UiAssets over het root-venster, zodat
## elke Control in elke scene (bord, hub, grootboek, uitleg, tuner) de
## knoppen, panelen en letters van de assetpack krijgt zonder dat een scene
## er iets voor hoeft te doen. Nodes die een andere vorm willen zetten
## theme_type_variation (lijst in ui_assets.gd bij THEMA-VARIANTEN).
##
## Draait ook headless (tests, capture-modi): de textures laden gewoon, er
## wordt alleen niets getekend.


func _ready() -> void:
	var venster := get_window()
	if venster != null:
		venster.theme = UiAssets.thema()
