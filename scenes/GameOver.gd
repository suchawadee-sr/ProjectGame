extends Control

@onready var score_value: Label = $MainContainer/StatsContainer/ScoreContainer/ScoreValue
@onready var coins_value: Label = $MainContainer/StatsContainer/CoinsContainer/CoinsValue
@onready var distance_value: Label = $MainContainer/StatsContainer/DistanceContainer/DistanceValue
@onready var time_value: Label = $MainContainer/StatsContainer/TimeContainer/TimeValue
@onready var best_score_value: Label = $MainContainer/StatsContainer/BestScoreContainer/BestScoreValue

@onready var restart_button: Button = $MainContainer/ButtonsContainer/RestartButton
@onready var main_menu_button: Button = $MainContainer/ButtonsContainer/MainMenuButton

var game_data = {}

func _ready() -> void:
	# Hide initially
	visible = false
	
	# Load best score from save file
	load_best_score()

func show_game_over(data: Dictionary) -> void:
	game_data = data
	
	# Update UI with game data
	score_value.text = str(data.get("score", 0))
	coins_value.text = str(data.get("coins", 0))
	distance_value.text = str(data.get("distance", 0)) + "m"
	
	# Format time as MM:SS
	var time_seconds = data.get("time", 0.0)
	var minutes = int(time_seconds) / 60
	var seconds = int(time_seconds) % 60
	time_value.text = "%02d:%02d" % [minutes, seconds]
	
	# Check and update best score
	var current_score = data.get("score", 0)
	var best_score = data.get("best_score", 0)
	
	if current_score > best_score:
		best_score = current_score
		save_best_score(best_score)
		# Show "NEW RECORD!" animation or effect
		show_new_record_effect()
	
	best_score_value.text = str(best_score)
	
	# Force UI to be visible and on top
	visible = true
	modulate = Color.WHITE
	
	# Simple show without animation for testing
	scale = Vector2.ONE
	modulate.a = 1.0

func animate_show() -> void:
	print("GameOver.gd: animate_show called")
	# Force to front and make sure it's visible
	move_to_front()
	z_index = 1000
	
	# Scale animation
	scale = Vector2(0.8, 0.8)
	modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	print("GameOver.gd: Animation started, visible=", visible, " z_index=", z_index)

func show_new_record_effect() -> void:
	# Create a "NEW RECORD!" label with animation
	var new_record_label = Label.new()
	new_record_label.text = "NEW RECORD!"
	new_record_label.add_theme_font_size_override("font_size", 32)
	new_record_label.add_theme_color_override("font_color", Color.YELLOW)
	new_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_record_label.position = Vector2(get_viewport().size.x / 2 - 100, 100)
	get_tree().current_scene.add_child(new_record_label)
	
	# Animate the new record label
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(new_record_label, "scale", Vector2(1.2, 1.2), 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(new_record_label, "modulate:a", 0.0, 1.0).set_delay(1.0)
	
	# Remove label after animation
	tween.tween_callback(new_record_label.queue_free).set_delay(2.0)

func load_best_score() -> int:
	var save_file = FileAccess.open("user://best_score.save", FileAccess.READ)
	if save_file:
		var best_score = save_file.get_32()
		save_file.close()
		return best_score
	return 0

func save_best_score(score: int) -> void:
	var save_file = FileAccess.open("user://best_score.save", FileAccess.WRITE)
	if save_file:
		save_file.store_32(score)
		save_file.close()

func _on_restart_button_pressed() -> void:
	# Unpause before restarting
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_button_pressed() -> void:
	# Unpause before going to main menu
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func hide_game_over() -> void:
	visible = false
