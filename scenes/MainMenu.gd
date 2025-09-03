extends Control

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var title_label: Label = $VBoxContainer/Title
@onready var background: ColorRect = $Background

var title_tween: Tween
var background_tween: Tween
var particles: GPUParticles2D
var floating_coins: Array[Control] = []
var button_hover_tweens: Dictionary = {}

func _ready() -> void:
	# Connect button signals
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Connect hover signals
	play_button.mouse_entered.connect(_on_play_hover)
	play_button.mouse_exited.connect(_on_play_unhover)
	quit_button.mouse_entered.connect(_on_quit_hover)
	quit_button.mouse_exited.connect(_on_quit_unhover)
	
	# Set up animations
	_animate_title()
	_animate_background()
	_setup_particles()
	_create_floating_coins()
	
	# Style the buttons
	_style_buttons()
	
	# Focus on play button
	play_button.grab_focus()

func _animate_title() -> void:
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
	
	# Quit button styling  
	quit_button.add_theme_font_size_override("font_size", 24)
	quit_button.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	quit_button.add_theme_color_override("font_hover_color", Color.RED)

func _on_play_pressed() -> void:
	# Add button press effect
	var button_tween = create_tween()
	button_tween.tween_property(play_button, "scale", Vector2(0.95, 0.95), 0.1)
	button_tween.tween_property(play_button, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Wait for animation then change scene
	await button_tween.finished
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_pressed() -> void:
	# Add button press effect
	var button_tween = create_tween()
	button_tween.tween_property(quit_button, "scale", Vector2(0.95, 0.95), 0.1)
	button_tween.tween_property(quit_button, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Wait for animation then quit
	await button_tween.finished
	get_tree().quit()

func _update_title_color(angle: float) -> void:
	var r = sin(angle) * 0.5 + 0.5
	var g = sin(angle + 2.09) * 0.5 + 0.5
	var b = sin(angle + 4.19) * 0.5 + 0.5
	title_label.add_theme_color_override("font_color", Color(r, g, b))

func _animate_background() -> void:
	# Gradient color animation
	background_tween = create_tween()
	background_tween.set_loops()
	background_tween.tween_property(background, "color", Color(0.15, 0.25, 0.35), 4.0)
	background_tween.tween_property(background, "color", Color(0.05, 0.15, 0.25), 4.0)

func _setup_particles() -> void:
	particles = GPUParticles2D.new()
	particles.name = "MenuParticles"
	particles.position = Vector2(get_viewport().size.x / 2, get_viewport().size.y)
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 8.0
	particles.process_material = _create_menu_particle_material()
	add_child(particles)

func _create_menu_particle_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 30.0
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 50.0
	material.gravity = Vector3(0, -20, 0)
	material.scale_min = 0.2
	material.scale_max = 0.8
	material.color = Color(1.0, 0.8, 0.2, 0.6)
	return material

func _create_floating_coins() -> void:
	for i in range(5):
		var coin = Label.new()
		coin.text = "◉"
		coin.add_theme_font_size_override("font_size", 24)
		coin.add_theme_color_override("font_color", Color.GOLD)
		coin.position = Vector2(
			randf_range(50, get_viewport().size.x - 50),
			randf_range(50, get_viewport().size.y - 50)
		)
		add_child(coin)
		floating_coins.append(coin)
		
		# Animate each coin
		var coin_tween = create_tween()
		coin_tween.set_loops()
		coin_tween.tween_property(coin, "rotation", PI * 2, 2.0 + randf())
		
		var float_tween = create_tween()
		float_tween.set_loops()
		float_tween.tween_property(coin, "position:y", coin.position.y - 20, 1.5 + randf())
		float_tween.tween_property(coin, "position:y", coin.position.y + 20, 1.5 + randf())

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
