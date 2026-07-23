class_name AgentL3
extends AgentL2

# L3 — de Hard/Ultra-search bovenop de L2-eval, op dezelfde view-reconstructie
# (puntschatting voor gedekte stats, B11; determinized sampling N=16 is de
# geplande upgrade zodra de arena aantoont dat de puntschatting L3 merkbaar
# zwakker maakt — bouwplan-besluit B11/F8).

const HardScript := preload("res://scripts/ai/AIHard.gd")
const UltraScript := preload("res://scripts/ai/AIUltra.gd")

var _ultra: bool = false


func _init(ultra: bool = false) -> void:
	_ultra = ultra


func _get_ai(view: Dictionary):
	if _ai == null:
		_ai = UltraScript.new() if _ultra else HardScript.new()
	return super._get_ai(view)
