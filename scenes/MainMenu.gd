extends Control

@export var level_scenes: Array[PackedScene] = []   # [Level1, Level2, ...]
@export var level_names: Array[String] = []         # ["Forest","Desert",...]

func _ready() -> void:
	%BackBtn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	_build_level_buttons()

func _build_level_buttons():
	var grid := %Grid  # GridContainer
	for c in grid.get_children():
		c.queue_free()

	for i in level_scenes.size():
		var btn := Button.new()
		btn.text = (i < level_names.size()) ? level_names[i] : "Level %d" % (i+1)

		var level_index := i + 1
		var locked := level_index > GameState.unlocked_levels
		btn.disabled = locked
		if locked:
			btn.text += "  🔒"

		btn.pressed.connect(_start_level.bind(i))
		grid.add_child(btn)

func _start_level(idx: int):
	if idx >= 0 and idx < level_scenes.size():
		get_tree().change_scene_to_packed(level_scenes[idx])
