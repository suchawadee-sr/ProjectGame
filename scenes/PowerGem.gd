extends Area2D

signal power_collected(pos: Vector2)

@export var speed_boost_multiplier: float = 2.0
@export var power_duration: float = 8.0
@export var score_value: int = 50

func _ready():
	body_entered.connect(_on_body_entered)
	
	# Add floating animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "position:y", position.y - 10, 1.0).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", position.y + 10, 1.0).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body):
	if body.name != "Dino": 
		return
		
	var main = get_tree().current_scene
	if main and main.has_method("add_score_points"):
		main.add_score_points(score_value, global_position)
	
	if main and main.has_method("activate_power_mode"):
		main.activate_power_mode(power_duration, speed_boost_multiplier)
	
	# Emit signal for effects
	power_collected.emit(global_position)
	queue_free()
