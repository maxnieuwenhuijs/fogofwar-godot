extends Node

## Autoload UiThema: legt het thema uit UiAssets over het hele spel, zodat
## elke Control in elke scene (bord, hub, grootboek, uitleg, tuner) de
## knoppen, panelen en letters van de assetpack krijgt zonder dat een scene
## er iets voor hoeft te doen. Nodes die een andere vorm willen zetten
## theme_type_variation (lijst in ui_assets.gd bij THEMA-VARIANTEN).
##
## Twee wegen, want een thema erft in Godot alleen door een keten van
## Control/Window-ouders (bevinding 3 september: het venster-thema kwam
## niet aan onder de CanvasLayer $UI van game.tscn en niet onder de kale
## Node van capture.tscn):
##   1. het root-venster krijgt het thema (dekt alles wat direct onder een
##      Control of Window hangt);
##   2. elke Control of Window die onder een niet-Control (CanvasLayer,
##      Node, Node3D) de boom in komt, krijgt het thema zelf. Zo'n node is
##      de wortel van een eigen erfketen; zijn kinderen erven het gewoon.
##
## Draait ook headless (tests, capture-modi): de textures laden gewoon, er
## wordt alleen niets getekend.


func _ready() -> void:
	var venster := get_window()
	if venster != null:
		venster.theme = UiAssets.thema()
	get_tree().node_added.connect(_bij_nieuwe_node)


## Is deze node de wortel van een thema-erfketen (ouder is geen Control/Window)?
static func is_thema_wortel(node: Node) -> bool:
	if not (node is Control or node is Window):
		return false
	var ouder := node.get_parent()
	return ouder != null and not (ouder is Control) and not (ouder is Window)


func _bij_nieuwe_node(node: Node) -> void:
	if not is_thema_wortel(node):
		return
	var thema := UiAssets.thema()
	if node is Control:
		if (node as Control).theme == null:
			(node as Control).theme = thema
	elif node is Window:
		if (node as Window).theme == null:
			(node as Window).theme = thema
