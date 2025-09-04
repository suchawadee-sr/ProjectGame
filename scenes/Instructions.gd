extends Control

@onready var back_button: Button = $BackButton

var click_sound: AudioStreamPlayer
var background_music: AudioStreamPlayer

func _ready() -> void:
	# Setup click sound
	click_sound = AudioStreamPlayer.new()
	click_sound.stream = load("res://assets/sound/click.mp3")
	click_sound.volume_db = -8.0
	add_child(click_sound)
	
	# Setup background music
	background_music = AudioStreamPlayer.new()
	background_music.stream = load("res://assets/sound/background_menu_gameover.mp3")
	background_music.volume_db = -15.0
	background_music.autoplay = true
	add_child(background_music)
	
	# Connect button signal
	back_button.pressed.connect(_on_back_button_pressed)
	
	# Focus on back button
	back_button.grab_focus()

func _on_back_button_pressed() -> void:
	_play_click_sound()
	_stop_background_music()
	# Add button press effect
	var button_tween = create_tween()
	button_tween.tween_property(back_button, "scale", Vector2(0.95, 0.95), 0.1)
	button_tween.tween_property(back_button, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Wait for animation then go back to main menu
	await button_tween.finished
	get_tree().change_scene_to_file("res://scenes/MainMenu_Fixed.tscn")

func _play_click_sound() -> void:
	if click_sound:
		click_sound.play()

func _stop_background_music() -> void:
	if background_music and background_music.playing:
		background_music.stop()

func _input(event: InputEvent) -> void:
	# Allow Escape to go back
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
