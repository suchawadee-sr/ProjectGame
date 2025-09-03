# Coin.gd  (ติดกับ Coin.tscn)
extends Area2D
@export var value: int = 10
func _ready():
	body_entered.connect(_on_enter)
func _on_enter(b):
	if b.name != "Dino": return
	var main := get_tree().current_scene
	if main and main.has_method("add_score_points"):
		main.add_score_points(value, global_position, true, true)  # use_multiplier=true, is_coin=true
	queue_free()
