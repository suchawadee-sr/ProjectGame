extends Control

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var instructions_button: Button = $VBoxContainer/InstructionsButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var title_label: Label = $VBoxContainer/Title
@onready var background: ColorRect = $Background

var title_tween: Tween
var background_tween: Tween
var particles: GPUParticles2D
var floating_coins: Array[Control] = []
var button_hover_tweens: Dictionary = {}
var click_sound: AudioStreamPlayer
var background_music: AudioStreamPlayer

func _ready() -> void:
	print("MainMenu: Starting _ready()")
	
	# Setup click sound (optional)
	click_sound = AudioStreamPlayer.new()
	var click_stream = load("res://assets/sound/click.mp3")
	if click_stream:
		click_sound.stream = click_stream
		click_sound.volume_db = -10.0
		add_child(click_sound)
		print("MainMenu: Click sound loaded")
	else:
		add_child(click_sound)
		print("MainMenu: Click sound not found, using silent mode")
	
	# Setup background music (optional) 
	background_music = AudioStreamPlayer.new()
	var music_stream = load("res://assets/sound/background_menu_gameover.mp3")
	if music_stream:
		background_music.stream = music_stream
		background_music.volume_db = -15.0
		background_music.autoplay = true
		add_child(background_music)
		print("MainMenu: Background music loaded")
	else:
		add_child(background_music)
		print("MainMenu: Background music not found, using silent mode")
	
	# Connect button signals
	play_button.pressed.connect(_on_play_pressed)
	instructions_button.pressed.connect(_on_instructions_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Connect hover signals
	play_button.mouse_entered.connect(_on_play_hover)
	play_button.mouse_exited.connect(_on_play_unhover)
	instructions_button.mouse_entered.connect(_on_instructions_hover)
	instructions_button.mouse_exited.connect(_on_instructions_unhover)
	settings_button.mouse_entered.connect(_on_settings_hover)
	settings_button.mouse_exited.connect(_on_settings_unhover)
	quit_button.mouse_entered.connect(_on_quit_hover)
	quit_button.mouse_exited.connect(_on_quit_unhover)
	
	# Set up animations
	print("MainMenu: Setting up animations")
	_animate_title()
	_animate_background()
	_setup_particles()
	_create_floating_coins()
	
	print("MainMenu: _ready() completed successfully")
	
	# Style the buttons
	_style_buttons()
	
	# Focus on play button
	play_button.grab_focus()

func _animate_title() -> void:
	if title_label:
		title_label.add_theme_font_size_override("font_size", 48)
		title_label.add_theme_color_override("font_color", Color.YELLOW)
		title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		title_label.add_theme_constant_override("shadow_offset_x", 3)
		title_label.add_theme_constant_override("shadow_offset_y", 3)
		
		# Rainbow color cycling animation
		title_tween = create_tween()
		title_tween.set_loops()
		title_tween.tween_method(_update_title_color, 0.0, 6.28, 3.0)
		
		# Floating animation
		var float_tween = create_tween()
		float_tween.set_loops()
		float_tween.tween_property(title_label, "position:y", title_label.position.y - 10, 2.0)
		float_tween.tween_property(title_label, "position:y", title_label.position.y + 10, 2.0)

func _style_buttons() -> void:
	# Play button styling
	play_button.add_theme_font_size_override("font_size", 32)
	play_button.add_theme_color_override("font_color", Color.WHITE)
	play_button.add_theme_color_override("font_hover_color", Color.YELLOW)
	
	# Instructions button styling
	instructions_button.add_theme_font_size_override("font_size", 28)
	instructions_button.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	instructions_button.add_theme_color_override("font_hover_color", Color.CYAN)
	
	# Settings button styling
	settings_button.add_theme_font_size_override("font_size", 28)
	settings_button.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	settings_button.add_theme_color_override("font_hover_color", Color.GREEN)
	
	# Quit button styling  
	quit_button.add_theme_font_size_override("font_size", 24)
	quit_button.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	quit_button.add_theme_color_override("font_hover_color", Color.RED)

func _on_play_pressed() -> void:
	_play_click_sound()
	_stop_background_music()
	# Add button press effect
	var button_tween = create_tween()
	button_tween.tween_property(play_button, "scale", Vector2(0.95, 0.95), 0.1)
	button_tween.tween_property(play_button, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Wait for animation then change scene
	await button_tween.finished
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
	if click_sound and click_sound.stream:
		click_sound.play()

func _stop_background_music() -> void:
	if background_music and background_music.playing:
		background_music.stop()
		print("MainMenu: Stopped background music")

func _update_title_color(angle: float) -> void:
	if title_label:
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
	if get_viewport():
		particles = GPUParticles2D.new()
		particles.name = "MenuParticles"
		particles.position = Vector2(get_viewport().size.x / 2, get_viewport().size.y)
		particles.emitting = true
		particles.amount = 30
		particles.lifetime = 8.0
		particles.process_material = _create_menu_particle_material()
		add_child(particles)

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
	var coin_texture = load("res://assets/img/GoldCoinSprite/Gold_1.png")
	if coin_texture:
		coin_sprite.texture = coin_texture
		coin_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		coin_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin_sprite.anchors_preset = Control.PRESET_FULL_RECT
		coin.add_child(coin_sprite)
	
	return coin

func _create_floating_coins() -> void:
	for i in range(5):
		var coin = _create_floating_coin()
		add_child(coin)
		floating_coins.append(coin)
		
		# Animate each coin
		var coin_tween = create_tween()
		coin_tween.set_loops()
		coin_tween.tween_property(coin, "rotation", PI * 2, 2.0 + randf())
		
		var float_tween = create_tween()
		float_tween.set_loops()
		float_tween.tween_property(coin, "position:y", coin.position.y - 100, 3.0 + randf())
		float_tween.tween_property(coin, "position:y", coin.position.y, 3.0 + randf())

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
