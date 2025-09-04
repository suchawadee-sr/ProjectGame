extends Control

@onready var score_value: Label = $MainContainer/StatsContainer/ScoreContainer/ScoreValue
@onready var coins_value: Label = $MainContainer/StatsContainer/CoinsContainer/CoinsValue
@onready var distance_value: Label = $MainContainer/StatsContainer/DistanceContainer/DistanceValue
@onready var time_value: Label = $MainContainer/StatsContainer/TimeContainer/TimeValue
@onready var best_score_value: Label = $MainContainer/StatsContainer/BestScoreContainer/BestScoreValue

@onready var restart_button: Button = $MainContainer/ButtonsContainer/RestartButton
@onready var main_menu_button: Button = $MainContainer/ButtonsContainer/MainMenuButton

var game_data = {}
var click_sound: AudioStreamPlayer
var background_music: AudioStreamPlayer

func _ready() -> void:
	# Hide initially
	visible = false
	
	# Setup click sound
	click_sound = AudioStreamPlayer.new()
	click_sound.stream = load("res://assets/sound/click.mp3")
	click_sound.volume_db = 0.0  # Increase volume
	click_sound.process_mode = Node.PROCESS_MODE_ALWAYS  # Allow sound to play when paused
	add_child(click_sound)
	print("GameOver: Click sound setup complete - Volume: ", click_sound.volume_db)
	
	# Setup background music
	background_music = AudioStreamPlayer.new()
	background_music.stream = load("res://assets/sound/background_menu_gameover.mp3")
	background_music.volume_db = -10.0  # Quieter background music
	background_music.process_mode = Node.PROCESS_MODE_ALWAYS  # Allow music to play when paused
	add_child(background_music)
	print("GameOver: Background music setup complete")
	
	# Connect button signals manually to ensure they work
	restart_button.pressed.connect(_on_restart_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	
	# Load best score from save file
	load_best_score()

func show_game_over(data: Dictionary) -> void:
	game_data = data
	
	# Start background music
	_play_background_music()
	
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
	_play_click_sound()
	_stop_background_music()
	# Longer delay to ensure click sound finishes playing
	await get_tree().create_timer(0.5).timeout
	# Unpause before restarting
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_button_pressed() -> void:
	print("GameOver: Main menu button pressed!")
	_play_click_sound()
	_stop_background_music()
	
	# Unpause immediately to ensure scene change works
	get_tree().paused = false
	
	# Add delay to let click sound play
	await get_tree().create_timer(0.3).timeout
	_change_to_main_menu()

func _change_to_main_menu() -> void:
	print("GameOver: Attempting to change scene to MainMenu_Fixed.tscn")
	var result = get_tree().change_scene_to_file("res://scenes/MainMenu_Fixed.tscn")
	if result != OK:
		print("GameOver: Failed to change scene! Error code: ", result)
	else:
		print("GameOver: Scene change initiated successfully")

func _play_click_sound() -> void:
	if click_sound:
		print("GameOver: Attempting to play click sound...")
		click_sound.play()
		print("GameOver: Click sound played - Volume: ", click_sound.volume_db)
		print("GameOver: Sound playing: ", click_sound.playing)
	else:
		print("GameOver: Click sound not available")

func _play_background_music() -> void:
	if background_music and not background_music.playing:
		background_music.play()
		print("GameOver: Playing background music")

func _stop_background_music() -> void:
	if background_music and background_music.playing:
		background_music.stop()
		print("GameOver: Stopped background music")

func hide_game_over() -> void:
	_stop_background_music()
	visible = false
