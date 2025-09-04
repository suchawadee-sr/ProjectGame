extends Control

@onready var master_volume_slider: HSlider = $VBoxContainer/MasterVolumeSlider
@onready var music_volume_slider: HSlider = $VBoxContainer/MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = $VBoxContainer/SFXVolumeSlider
@onready var master_volume_value: Label = $VBoxContainer/MasterVolumeValue
@onready var music_volume_value: Label = $VBoxContainer/MusicVolumeValue
@onready var sfx_volume_value: Label = $VBoxContainer/SFXVolumeValue
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var title_label: Label = $VBoxContainer/Title

var title_tween: Tween
var click_sound: AudioStreamPlayer

func _ready() -> void:
	print("Settings: Scene loaded")
	
	# Setup click sound
	click_sound = AudioStreamPlayer.new()
	click_sound.stream = load("res://assets/sound/click.mp3")
	click_sound.volume_db = -10.0
	add_child(click_sound)
	
	# Connect signals
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Connect hover signals
	back_button.mouse_entered.connect(_on_back_hover)
	back_button.mouse_exited.connect(_on_back_unhover)
	
	# Load saved settings
	_load_settings()
	
	# Style the back button
	back_button.add_theme_font_size_override("font_size", 28)
	back_button.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	back_button.add_theme_color_override("font_hover_color", Color.RED)
	
	# Animate title
	_animate_title()

func _animate_title() -> void:
	title_tween = create_tween()
	title_tween.set_loops()
	title_tween.tween_property(title_label, "modulate", Color(1, 1, 0.3, 1), 2.0)
	title_tween.tween_property(title_label, "modulate", Color(1, 1, 0.8, 1), 2.0)

func _load_settings() -> void:
	# Load from config file or use defaults
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		master_volume_slider.value = config.get_value("audio", "master_volume", 50.0)
		music_volume_slider.value = config.get_value("audio", "music_volume", 70.0)
		sfx_volume_slider.value = config.get_value("audio", "sfx_volume", 80.0)
	else:
		# Use default values
		master_volume_slider.value = 50.0
		music_volume_slider.value = 70.0
		sfx_volume_slider.value = 80.0
	
	# Update labels
	_update_volume_labels()

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume_slider.value)
	config.set_value("audio", "music_volume", music_volume_slider.value)
	config.set_value("audio", "sfx_volume", sfx_volume_slider.value)
	config.save("user://settings.cfg")

func _update_volume_labels() -> void:
	master_volume_value.text = str(int(master_volume_slider.value)) + "%"
	music_volume_value.text = str(int(music_volume_slider.value)) + "%"
	sfx_volume_value.text = str(int(sfx_volume_slider.value)) + "%"

func _on_master_volume_changed(value: float) -> void:
	master_volume_value.text = str(int(value)) + "%"
	# Apply master volume to all audio buses
	var master_db = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_db)
	_save_settings()

func _on_music_volume_changed(value: float) -> void:
	music_volume_value.text = str(int(value)) + "%"
	# Apply music volume (assuming music bus exists)
	var music_db = linear_to_db(value / 100.0)
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, music_db)
	_save_settings()

func _on_sfx_volume_changed(value: float) -> void:
	sfx_volume_value.text = str(int(value)) + "%"
	# Apply SFX volume (assuming SFX bus exists)
	var sfx_db = linear_to_db(value / 100.0)
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, sfx_db)
	_save_settings()

func _on_back_pressed() -> void:
	_play_click_sound()
	# Add button press effect
	var button_tween = create_tween()
	button_tween.tween_property(back_button, "scale", Vector2(0.95, 0.95), 0.1)
	button_tween.tween_property(back_button, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Wait for animation then change scene
	await button_tween.finished
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_back_hover() -> void:
	var hover_tween = create_tween()
	hover_tween.parallel().tween_property(back_button, "scale", Vector2(1.05, 1.05), 0.2)
	hover_tween.parallel().tween_property(back_button, "modulate", Color.RED, 0.2)

func _on_back_unhover() -> void:
	var hover_tween = create_tween()
	hover_tween.parallel().tween_property(back_button, "scale", Vector2(1.0, 1.0), 0.2)
	hover_tween.parallel().tween_property(back_button, "modulate", Color.WHITE, 0.2)

func _play_click_sound() -> void:
	if click_sound and click_sound.stream:
		click_sound.play()

func _input(event: InputEvent) -> void:
	# Allow Escape to go back
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
