extends Area2D

signal collected(pos: Vector2)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body) -> void:
	if body.name == "Dino":
		collected.emit(global_position)
		queue_free()
