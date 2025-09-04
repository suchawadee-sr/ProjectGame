extends Control

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var instructions_button: Button = $VBoxContainer/InstructionsButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

var button_hover_tweens: Dictionary = {}
var background_music: AudioStreamPlayer
var title_label: Label
var background: ColorRect
var background_tween: Tween

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
	_play_click_sound()
	# Add button press effect
	var button_tween = create_tween()
	button_tween.tween_property(instructions_button, "scale", Vector2(0.95, 0.95), 0.1)
	button_tween.tween_property(instructions_button, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Wait for animation then change scene
	await button_tween.finished
	get_tree().change_scene_to_file("res://scenes/Instructions.tscn")

func _on_settings_pressed() -> void:
	_play_click_sound()
	# Add button press effect
	var button_tween = create_tween()
	button_tween.tween_property(settings_button, "scale", Vector2(0.95, 0.95), 0.1)
	button_tween.tween_property(settings_button, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Wait for animation then change scene
	await button_tween.finished
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_quit_pressed() -> void:
	_play_click_sound()
	_stop_background_music()
	# Add button press effect
	var button_tween = create_tween()
	button_tween.tween_property(quit_button, "scale", Vector2(0.95, 0.95), 0.1)
	button_tween.tween_property(quit_button, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Wait for animation then quit
	await button_tween.finished
	get_tree().quit()

func _play_click_sound() -> void:
	# Simple click feedback without requiring audio file
	pass

func _stop_background_music() -> void:
	if background_music and background_music.playing:
		background_music.stop()
		print("MainMenu: Stopped background music")

func _update_title_color(angle: float) -> void:
	var r = sin(angle) * 0.5 + 0.5
	var g = sin(angle + 2.09) * 0.5 + 0.5
	var b = sin(angle + 4.19) * 0.5 + 0.5
	title_label.add_theme_color_override("font_color", Color(r, g, b))

func _animate_background() -> void:
	if background:
		# Gradient color animation
		background_tween = create_tween()
		background_tween.set_loops()
		background_tween.tween_property(background, "color", Color(0.15, 0.25, 0.35), 4.0)
		background_tween.tween_property(background, "color", Color(0.05, 0.15, 0.25), 4.0)

func _setup_particles() -> void:
	# Skip particles to avoid potential issues
	pass

func _create_menu_particle_material() -> ParticleProcessMaterial:
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, -1, 0)
	particle_material.spread = 30.0
	particle_material.initial_velocity_min = 20.0
	particle_material.initial_velocity_max = 50.0
	particle_material.gravity = Vector3(0, -20, 0)
	particle_material.scale_min = 0.2
	particle_material.scale_max = 0.8
	particle_material.color = Color(1.0, 0.8, 0.2, 0.6)
	return particle_material

func _create_floating_coin() -> Control:
	var coin = Control.new()
	coin.custom_minimum_size = Vector2(32, 32)
	if get_viewport():
		coin.position = Vector2(randf() * get_viewport().size.x, get_viewport().size.y + 50)
	else:
		coin.position = Vector2(randf() * 1024, 650)  # fallback values
	
	var coin_sprite = TextureRect.new()
	coin_sprite.texture = load("res://assets/img/GoldCoinSprite/Gold_1.png")
	coin_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	coin_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_sprite.anchors_preset = Control.PRESET_FULL_RECT
	coin.add_child(coin_sprite)
	
	return coin

func _create_floating_coins() -> void:
	# Skip floating coins to simplify startup
	pass

func _on_play_hover() -> void:
	if button_hover_tweens.has("play"):
		button_hover_tweens["play"].kill()
	button_hover_tweens["play"] = create_tween()
	button_hover_tweens["play"].parallel().tween_property(play_button, "scale", Vector2(1.1, 1.1), 0.2)
	button_hover_tweens["play"].parallel().tween_property(play_button, "rotation", deg_to_rad(2), 0.2)

func _on_play_unhover() -> void:
	if button_hover_tweens.has("play"):
		button_hover_tweens["play"].kill()
	button_hover_tweens["play"] = create_tween()
	button_hover_tweens["play"].parallel().tween_property(play_button, "scale", Vector2(1.0, 1.0), 0.2)
	button_hover_tweens["play"].parallel().tween_property(play_button, "rotation", 0.0, 0.2)

func _on_quit_hover() -> void:
	if button_hover_tweens.has("quit"):
		button_hover_tweens["quit"].kill()
	button_hover_tweens["quit"] = create_tween()
	button_hover_tweens["quit"].parallel().tween_property(quit_button, "scale", Vector2(1.05, 1.05), 0.2)
	button_hover_tweens["quit"].parallel().tween_property(quit_button, "modulate", Color.RED, 0.2)

func _on_instructions_hover() -> void:
	if button_hover_tweens.has("instructions"):
		button_hover_tweens["instructions"].kill()
	button_hover_tweens["instructions"] = create_tween()
	button_hover_tweens["instructions"].parallel().tween_property(instructions_button, "scale", Vector2(1.05, 1.05), 0.2)
	button_hover_tweens["instructions"].parallel().tween_property(instructions_button, "modulate", Color.CYAN, 0.2)

func _on_instructions_unhover() -> void:
	if button_hover_tweens.has("instructions"):
		button_hover_tweens["instructions"].kill()
	button_hover_tweens["instructions"] = create_tween()
	button_hover_tweens["instructions"].parallel().tween_property(instructions_button, "scale", Vector2(1.0, 1.0), 0.2)
	button_hover_tweens["instructions"].parallel().tween_property(instructions_button, "modulate", Color.WHITE, 0.2)

func _on_settings_hover() -> void:
	if button_hover_tweens.has("settings"):
		button_hover_tweens["settings"].kill()
	button_hover_tweens["settings"] = create_tween()
	button_hover_tweens["settings"].parallel().tween_property(settings_button, "scale", Vector2(1.05, 1.05), 0.2)
	button_hover_tweens["settings"].parallel().tween_property(settings_button, "modulate", Color.GREEN, 0.2)

func _on_settings_unhover() -> void:
	if button_hover_tweens.has("settings"):
		button_hover_tweens["settings"].kill()
	button_hover_tweens["settings"] = create_tween()
	button_hover_tweens["settings"].parallel().tween_property(settings_button, "scale", Vector2(1.0, 1.0), 0.2)
	button_hover_tweens["settings"].parallel().tween_property(settings_button, "modulate", Color.WHITE, 0.2)

func _on_quit_unhover() -> void:
	if button_hover_tweens.has("quit"):
		button_hover_tweens["quit"].kill()
	button_hover_tweens["quit"] = create_tween()
	button_hover_tweens["quit"].parallel().tween_property(quit_button, "scale", Vector2(1.0, 1.0), 0.2)
	button_hover_tweens["quit"].parallel().tween_property(quit_button, "modulate", Color.WHITE, 0.2)

func _input(event: InputEvent) -> void:
	# Allow Enter/Space to start game
	if event.is_action_pressed("ui_accept"):
		_on_play_pressed()
