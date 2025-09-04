extends Control

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var instructions_button: Button = $VBoxContainer/InstructionsButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	print("MainMenu: Starting")
	
	# Connect only essential button signals
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if instructions_button:
		instructions_button.pressed.connect(_on_instructions_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	print("MainMenu: Ready completed")

func _on_play_pressed() -> void:
	print("Play button pressed")
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_instructions_pressed() -> void:
	print("Instructions button pressed")
	get_tree().change_scene_to_file("res://scenes/Instructions.tscn")

func _on_settings_pressed() -> void:
	print("Settings button pressed")
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_quit_pressed() -> void:
	print("Quit button pressed")
	get_tree().quit()
