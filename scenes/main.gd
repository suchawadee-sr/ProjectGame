extends Node

# ====== PRELOAD ======
var stump_scene  = preload("res://scenes/stump.tscn")
var rock_scene   = preload("res://scenes/rock.tscn")
var barrel_scene = preload("res://scenes/barrel.tscn")
var bird_scene   = preload("res://scenes/bird.tscn")
var coin_scene   = preload("res://scenes/Coin.tscn")
var explosion_scene = preload("res://scenes/Explosion.tscn")
var game_over_scene = preload("res://scenes/GameOver.tscn")

# ====== AUDIO ======
var background_music: AudioStreamPlayer
var coin_sound: AudioStreamPlayer
var explosion_sound: AudioStreamPlayer
var gameover_sound: AudioStreamPlayer
var jump_sound: AudioStreamPlayer
var transition_sound: AudioStreamPlayer
var immortal_sound: AudioStreamPlayer
var click_sound: AudioStreamPlayer

# Background transition system
@onready var bg2_scene = preload("res://scenes/bg2.tscn")
@onready var ground2_scene = preload("res://scenes/ground2.tscn")
@onready var bg3_scene = preload("res://scenes/bg3.tscn")
@onready var ground3_scene = preload("res://scenes/ground3.tscn")
@onready var bg4_scene = preload("res://scenes/bg4.tscn")
@onready var ground4_scene = preload("res://scenes/ground4.tscn")
# Stage-specific obstacle types
var stage1_obstacles := [preload("res://scenes/barrel2.tscn"), preload("res://scenes/shelf.tscn"), preload("res://scenes/table.tscn")]
var stage2_obstacles := [rock_scene, stump_scene, barrel_scene]
var stage3_obstacles := [preload("res://scenes/bush.tscn"), preload("res://scenes/flower.tscn"), preload("res://scenes/rock2.tscn")]
var stage4_obstacles := [preload("res://scenes/mons1.tscn"), preload("res://scenes/mons2.tscn"), preload("res://scenes/mons3.tscn")]

# Stage-specific flying objects
var stage1_flying := preload("res://scenes/bat.tscn")
var stage2_flying := preload("res://scenes/bird.tscn")
var stage3_flying := preload("res://scenes/fairy.tscn")
var stage4_flying := preload("res://scenes/vamp.tscn")

var bird_heights: Array[int] = [200, 390]
var current_bg_stage: int = 1
var bg_transition_distances: Array[int] = [1500, 3000, 4500]  # Distance in meters for stage 2, 3, 4
var bg_transitions_completed: Array[bool] = [false, false, false]  # For stages 2, 3, 4
var is_transitioning: bool = false

# ====== GAME VARS ======
const DINO_START_POS := Vector2i(150, 485)
const CAM_START_POS  := Vector2i(576, 324)

var screen_size: Vector2i
var ground_height: int

var score: float
const SCORE_MODIFIER: int = 10
var high_score: int

var speed: float
const START_SPEED: float = 600.0
const MAX_SPEED: int = 1200
const SPEED_MODIFIER: int = 800

var difficulty: int
const MAX_DIFFICULTY: int = 2

var game_running: bool

# ====== BACKGROUND SYSTEM ======
# Background transition variables moved to top section

# ====== ITEMS (เหรียญ) ======
@onready var items := $Items
var item_lanes_y: Array[float] = [485.0, 430.0, 390.0]
const COIN_GAP_MIN: float = 500.0
const COIN_GAP_MAX: float = 900.0
const COIN_SAFE_FROM_OBS: float = 200.0
var next_coin_x: float = 0.0

# ====== OBSTACLE SPACING ======
const OBS_GAP_MIN: int = 420
const OBS_GAP_MAX: int = 680
const MIN_GAP_ANY: int = 560
const MIN_GAP_BIRD_AFTER_OBS: int = 340
const MIN_FRONT_BUFFER: int = 720

var obstacles: Array = []
var next_obs_spawn_x: int = 0
var last_spawn_right: float = -1.0e9
var last_spawn_type: String = ""   # "obs" | "bird" | ""

# ====== INVINCIBLE ======
var invincible: bool = false
var inv_end_time: float = 0.0
var next_invincible_score: int = 1000
const INVINCIBLE_DURATION: float = 5.0
const HIT_REWARD_POINTS: int = 50
const HIT_COOLDOWN: float = 0.35
var _last_hit_time: float = -1000.0

# ====== HUD REFS ======
var inv_panel: Control
var inv_bar: ProgressBar
var inv_label: Label

@onready var _hud := $HUD
@onready var _lb_score: Label = _hud.get_node_or_null(^"ScoreLabel")
@onready var _lb_high:  Label = _hud.get_node_or_null(^"HighScoreLabel")

# Stats panel (ตามที่จัดในฉาก)
@onready var _stats_panel: Control            = _hud.get_node(^"StatsPanel")
@onready var _lb_perfect: Label               = _stats_panel.get_node(^"PerfectLabel")
@onready var _lb_combo: Label                 = _stats_panel.get_node(^"ComboLabel")
@onready var _lb_distance: Label              = _stats_panel.get_node(^"DistanceLabel")
@onready var _lb_multiplier: Label            = _stats_panel.get_node(^"MultiplierLabel")

# ====== RUN SUMMARY / COUNTERS ======
var coins_collected: int = 0
var near_miss_count: int = 0
var obstacles_destroyed: int = 0
var max_combo_run: int = 0
var run_start_time: float = 0.0
var distance_traveled: float = 0.0
var game_time: float = 0.0

# best (เฉพาะในเซสชัน)
var best_coins: int = 0
var best_combo: int = 0
var best_time: float = 0.0
var best_destroyed: int = 0

const PX_PER_METER: float = 10.0  # ปรับตามสเกลฉาก

# GameOver UI
var game_over_ui: Control

# ====== RNG ======
var rng := RandomNumberGenerator.new()

# ====== FOG-OF-WAR (VIGNETTE) ======
@onready var fog_rect: ColorRect     = $FogLayer/Vignette
@onready var fog_mat: ShaderMaterial = fog_rect.material as ShaderMaterial

const FOG_RADIUS_MAX: float = 420.0
const FOG_RADIUS_MIN: float = 160.0
const FOG_SOFTNESS:   float = 140.0
const FOG_ALPHA_MAX:  float = 0.90
const FOG_SCORE_FULL: int   = 3000

var _fog_prev_alpha: float = FOG_ALPHA_MAX
var _fog_hidden_by_inv: bool = false
var _fog_tween: Tween
var _fog_radius_tween: Tween

# ====== NEW FEATURES ======
# 1) Screen shake
var shake_strength: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var original_cam_pos: Vector2

# 2) Particles
var dust_particles: GPUParticles2D
var coin_particles: GPUParticles2D
var dust_timer: float = 0.0
const DUST_INTERVAL: float = 0.15

# 3) Combos
var combo_count: int = 0
var combo_label: Label
var combo_timer: float = 0.0
const COMBO_RESET_TIME: float = 2.0
var last_dodge_time: float = 0.0


# ====== PERFECT DODGE ======
const PERFECT_DODGE_X_WINDOW: float = 44.0
const PERFECT_DODGE_Y_TOL_GROUND: float = 16.0
const PERFECT_DODGE_Y_TOL_BIRD: float   = 18.0
const PERFECT_DODGE_POINTS: int = 10


# ---------------------------------------------------------
# LIFECYCLE
# ---------------------------------------------------------
func _ready() -> void:
	screen_size   = get_window().size
	var ground_node = get_node_or_null("Ground")
	if ground_node:
		var sprite = ground_node.get_node_or_null("Sprite2D")
		if sprite and sprite.texture:
			ground_height = sprite.texture.get_height()
		else:
			ground_height = 100  # fallback value

	# Load high score from save file
	high_score = load_best_score()

	# Setup GameOver UI with CanvasLayer
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(canvas_layer)
	
	game_over_ui = game_over_scene.instantiate()
	canvas_layer.add_child(game_over_ui)
	game_over_ui.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# ตั้ง Shader หมอก
	if fog_mat:
		fog_mat.set_shader_parameter("screen_size", Vector2(screen_size))
		fog_mat.set_shader_parameter("softness_px", FOG_SOFTNESS)
		fog_mat.set_shader_parameter("fog_color", Color(0,0,0, FOG_ALPHA_MAX))
		fog_mat.set_shader_parameter("radius_px", FOG_RADIUS_MAX)

	_setup_particles()
	_setup_combo_ui()
	_setup_background_music()
	new_game()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	new_game()


func new_game() -> void:
	rng.randomize()

	# stop fog tweens
	if _fog_tween and is_instance_valid(_fog_tween): _fog_tween.kill()
	if _fog_radius_tween and is_instance_valid(_fog_radius_tween): _fog_radius_tween.kill()

	# core
	score = 0.0
	show_score()
	game_running = false
	get_tree().paused = false
	difficulty = 0
	invincible = false
	next_invincible_score = 1000
	_set_glow(false)

	# counters
	near_miss_count = 0
	combo_count = 0
	max_combo_run = 0
	coins_collected = 0
	obstacles_destroyed = 0
	distance_traveled = 0.0
	game_time = 0.0
	run_start_time = _now_sec()
	
	# Reset background transition system
	current_bg_stage = 1
	bg_transitions_completed = [false, false, false]
	
	_update_stats_hud()

	# obstacles
	for obs in obstacles: obs.queue_free()
	obstacles.clear()

	# reset nodes
	$Dino.position = DINO_START_POS
	$Dino.velocity = Vector2.ZERO
	$Camera2D.position = CAM_START_POS
	
	# Reset ground position for any existing ground node
	var ground_node = get_node_or_null("Ground")
	if not ground_node:
		ground_node = get_node_or_null("Ground2")
	if not ground_node:
		ground_node = get_node_or_null("Ground3")
	if not ground_node:
		ground_node = get_node_or_null("Ground4")
	if ground_node:
		ground_node.position = Vector2i(0, 0)

	# Reset shake
	original_cam_pos = $Camera2D.position
	shake_strength = 0.0
	shake_duration = 0.0
	shake_timer = 0.0

	# HUD
	_hud.get_node("StartLabel").show()
	if game_over_ui:
		game_over_ui.hide_game_over()

	# HUD Invincible
	_ensure_inv_hud()
	inv_panel.hide()
	inv_bar.min_value = 0.0
	inv_bar.max_value = INVINCIBLE_DURATION
	inv_bar.value     = 0.0
	inv_label.text    = "0.0s"

	# coins
	for n in items.get_children(): n.queue_free()

	# spacing refs
	last_spawn_right = float($Camera2D.position.x) - 2000.0
	last_spawn_type  = ""
	next_obs_spawn_x = int($Camera2D.position.x) + screen_size.x + 100

	# coin first
	next_coin_x = float($Camera2D.position.x) + float(screen_size.x) * 0.75
	_spawn_next_coin()

	# reset fog (เผื่อรอบก่อนเป็นอมตะ)
	if fog_mat:
		_fog_hidden_by_inv = false
		fog_mat.set_shader_parameter("fog_color", Color(0,0,0, FOG_ALPHA_MAX))
		fog_mat.set_shader_parameter("radius_px", FOG_RADIUS_MAX)
		fog_mat.set_shader_parameter("center_px", _world_to_screen($Dino.global_position))

	# Background stage reset is handled in the counters section above

	dust_timer = 0.0


# ---------------------------------------------------------
# PER-FRAME
# ---------------------------------------------------------
func _process(delta: float) -> void:
	# Fog follow center and auto radius when not tweening
	if fog_mat and not _fog_hidden_by_inv:
		var c: Vector2 = _world_to_screen($Dino.global_position)
		fog_mat.set_shader_parameter("center_px", c)
		if _fog_radius_tween == null or not is_instance_valid(_fog_radius_tween) or not _fog_radius_tween.is_running():
			var display_score: int = int(score / SCORE_MODIFIER)
			var t: float = clamp(float(display_score) / float(FOG_SCORE_FULL), 0.0, 1.0)
			var radius: float = lerp(FOG_RADIUS_MAX, FOG_RADIUS_MIN, t)
			fog_mat.set_shader_parameter("radius_px", radius)

	_update_screen_shake(delta)

	if game_running:
		# speed & difficulty
		speed = START_SPEED + float(score) / float(SPEED_MODIFIER)
		if speed > MAX_SPEED: speed = MAX_SPEED
		adjust_difficulty()

		# obstacles
		generate_obs()

		# move
		$Dino.position.x     += speed * delta
		$Camera2D.position.x += speed * delta
		original_cam_pos.x   += speed * delta

		# scoring (ระยะทาง/เวลา)
		score += speed * delta
		show_score()

		# HUD stats refresh
		_update_stats_hud()

		# Background transition check
		_check_background_transition()

		# Update game statistics
		game_time = _now_sec() - run_start_time
		distance_traveled = $Camera2D.position.x / PX_PER_METER

		# Particles & combo
		_update_dust_particles(delta)
		_update_combo_system(delta)

		# trigger invincible (+1000 display score)
		if int(score / SCORE_MODIFIER) >= next_invincible_score:
			next_invincible_score += 1000
			_start_invincible(INVINCIBLE_DURATION)

		# invincible countdown
		if invincible:
			var remaining: float = clamp(inv_end_time - _now_sec(), 0.0, INVINCIBLE_DURATION)
			_update_inv_ui(remaining)
			if remaining <= 0.0:
				invincible = false
				_set_glow(false)
				_fog_restore_after_invincible()
				_update_inv_ui(0.0)

		# ground loop - check all possible ground nodes
		var ground_node = get_node_or_null("Ground")
		if not ground_node:
			ground_node = get_node_or_null("Ground2")
		if not ground_node:
			ground_node = get_node_or_null("Ground3")
		if not ground_node:
			ground_node = get_node_or_null("Ground4")
		if ground_node and $Camera2D.position.x - ground_node.position.x > screen_size.x * 1.5:
			ground_node.position.x += screen_size.x

		# cull old obstacles
		for obs in obstacles:
			if obs.position.x < ($Camera2D.position.x - screen_size.x):
				remove_obs(obs)

		# coin spawn 1-by-1
		if float($Camera2D.position.x) >= next_coin_x:
			_spawn_next_coin()

		# cull coins behind
		for n in items.get_children():
			if n.global_position.x < ($Camera2D.position.x - screen_size.x):
				n.queue_free()
	else:
		if Input.is_action_pressed("ui_accept"):
			game_running = true
			_hud.get_node("StartLabel").hide()
			# Delay background music to avoid audio chaos
			await get_tree().create_timer(0.3).timeout
			_play_background_music()
		# Test audio with T key
		if Input.is_action_just_pressed("ui_select"):  # T key
			print("Testing audio...")
			_test_audio_system()


# ---------------------------------------------------------
# NEW FEATURE 1: SCREEN SHAKE SYSTEM
# ---------------------------------------------------------
func _update_screen_shake(delta: float) -> void:
	if shake_duration <= 0.0:
		return

	shake_timer -= delta
	shake_duration -= delta

	if shake_duration <= 0.0:
		$Camera2D.position = original_cam_pos
		shake_strength = 0.0
		return

	var shake_offset := Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	)
	$Camera2D.position = original_cam_pos + shake_offset


func shake_screen(strength: float, duration: float) -> void:
	shake_strength = strength
	shake_duration = duration
	shake_timer = duration


# ---------------------------------------------------------
# NEW FEATURE 2: PARTICLE SYSTEM
# ---------------------------------------------------------
func _setup_particles() -> void:
	# Dust particles
	dust_particles = GPUParticles2D.new()
	dust_particles.name = "DustParticles"
	dust_particles.emitting = false
	dust_particles.amount = 50
	dust_particles.lifetime = 1.0
	dust_particles.process_material = _create_dust_material()
	add_child(dust_particles)

	# Coin collect particles
	coin_particles = GPUParticles2D.new()
	coin_particles.name = "CoinParticles"
	coin_particles.emitting = false
	coin_particles.amount = 20
	coin_particles.lifetime = 0.8
	coin_particles.process_material = _create_coin_material()
	add_child(coin_particles)


func _create_dust_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 60.0
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0
	material.gravity = Vector3(0, 98, 0)
	material.scale_min = 0.3
	material.scale_max = 0.7
	material.color = Color(0.8, 0.6, 0.4, 0.7)
	return material


func _create_coin_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 80.0
	material.initial_velocity_max = 150.0
	material.gravity = Vector3(0, 150, 0)
	material.scale_min = 0.5
	material.scale_max = 1.2
	material.color = Color(1.0, 0.8, 0.2, 0.9)
	return material


func _update_dust_particles(delta: float) -> void:
	dust_timer += delta
	if dust_timer >= DUST_INTERVAL:
		dust_timer = 0.0
		dust_particles.position = $Dino.position + Vector2(0, 20)
		dust_particles.restart()
		dust_particles.emitting = true
		await get_tree().create_timer(0.1)
		if dust_particles:
			dust_particles.emitting = false


func _play_coin_particle(coin_pos: Vector2) -> void:
	coin_particles.position = coin_pos
	coin_particles.restart()
	coin_particles.emitting = true
	await get_tree().create_timer(0.1)
	if coin_particles:
		coin_particles.emitting = false


# ---------------------------------------------------------
# NEW FEATURE 3: COMBO + PERFECT DODGE
# ---------------------------------------------------------
func _setup_combo_ui() -> void:
	combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.add_theme_font_size_override("font_size", 36)
	combo_label.add_theme_color_override("font_color", Color.YELLOW)
	combo_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	combo_label.add_theme_constant_override("shadow_offset_x", 2)
	combo_label.add_theme_constant_override("shadow_offset_y", 2)
	combo_label.position = Vector2(screen_size.x - 250, 100)
	combo_label.visible = false
	_hud.add_child(combo_label)


# ---------------------------------------------------------
# BACKGROUND MUSIC SYSTEM
# ---------------------------------------------------------
func _setup_background_music() -> void:
	# Setup background music
	background_music = AudioStreamPlayer.new()
	background_music.name = "BackgroundMusic"
	var bg_stream = load("res://assets/sound/background_sound.mp3")
	if bg_stream:
		background_music.stream = bg_stream
		background_music.volume_db = 0.0  # Full volume for testing
		background_music.autoplay = false
		add_child(background_music)
		print("Background music loaded successfully")
	else:
		print("Failed to load background music")
	
	# Setup coin pickup sound
	coin_sound = AudioStreamPlayer.new()
	coin_sound.name = "CoinSound"
	var coin_stream = load("res://assets/sound/pickupCoin.wav")
	if coin_stream:
		coin_sound.stream = coin_stream
		coin_sound.volume_db = 0.0  # Full volume for testing
		coin_sound.autoplay = false
		add_child(coin_sound)
		print("Coin sound loaded successfully")
	else:
		print("Failed to load coin sound")
	
	# Setup explosion sound
	explosion_sound = AudioStreamPlayer.new()
	explosion_sound.name = "ExplosionSound"
	var explosion_stream = load("res://assets/sound/explosion.wav")
	if explosion_stream:
		explosion_sound.stream = explosion_stream
		explosion_sound.volume_db = 0.0  # Full volume for testing
		explosion_sound.autoplay = false
		add_child(explosion_sound)
		print("Explosion sound loaded successfully")
	else:
		print("Failed to load explosion sound")
	
	# Setup game over sound
	gameover_sound = AudioStreamPlayer.new()
	gameover_sound.name = "GameOverSound"
	gameover_sound.process_mode = Node.PROCESS_MODE_ALWAYS  # Continue playing when paused
	var gameover_stream = load("res://assets/sound/gameover.mp3")
	if gameover_stream:
		gameover_sound.stream = gameover_stream
		gameover_sound.volume_db = 0.0  # Full volume for testing
		gameover_sound.autoplay = false
		add_child(gameover_sound)
		print("Game over sound loaded successfully")
	else:
		print("Failed to load game over sound")
	
	# Setup jump sound
	jump_sound = AudioStreamPlayer.new()
	jump_sound.name = "JumpSound"
	var jump_stream = load("res://assets/sound/jump.mp3")
	if jump_stream:
		jump_sound.stream = jump_stream
		jump_sound.volume_db = 0.0
		jump_sound.autoplay = false
		add_child(jump_sound)
		print("Jump sound loaded successfully")
	else:
		print("Failed to load jump sound")
	
	# Setup transition sound
	transition_sound = AudioStreamPlayer.new()
	transition_sound.name = "TransitionSound"
	var transition_stream = load("res://assets/sound/transition.mp3")
	if transition_stream:
		transition_sound.stream = transition_stream
		transition_sound.volume_db = 0.0  # Full volume for testing
		transition_sound.autoplay = false
		add_child(transition_sound)
		print("Transition sound loaded successfully")
	else:
		print("Failed to load transition sound")
	
	# Setup immortal sound
	immortal_sound = AudioStreamPlayer.new()
	immortal_sound.name = "ImmortalSound"
	immortal_sound.stream = load("res://assets/sound/immortal.mp3")
	immortal_sound.volume_db = 0.0
	add_child(immortal_sound)
	print("Immortal sound loaded: ", immortal_sound.stream != null)
	
	# Setup click sound
	click_sound = AudioStreamPlayer.new()
	click_sound.name = "ClickSound"
	click_sound.stream = load("res://assets/sound/click.mp3")
	click_sound.volume_db = -8.0  # Much quieter by default
	add_child(click_sound)
	print("Click sound loaded: ", click_sound.stream != null)


func _play_background_music() -> void:
	if background_music and not background_music.playing:
		background_music.volume_db = -20.0  # Start quieter
		background_music.play()
		print("Playing background music")
		# Fade in background music
		var tween = create_tween()
		tween.tween_property(background_music, "volume_db", -10.0, 1.0)
	else:
		print("Background music not available or already playing")


func _stop_background_music() -> void:
	if background_music and background_music.playing:
		background_music.stop()
		print("Stopped background music")


func _play_coin_sound() -> void:
	if coin_sound:
		coin_sound.play()
		print("Playing coin sound")
	else:
		print("Coin sound not available")


func _play_explosion_sound() -> void:
	if explosion_sound:
		explosion_sound.play()
		print("Playing explosion sound")
	else:
		print("Explosion sound not available")


func _play_gameover_sound() -> void:
	if gameover_sound:
		gameover_sound.play()
		print("Playing game over sound")
	else:
		print("Game over sound not available")


func _play_jump_sound() -> void:
	if jump_sound:
		jump_sound.play()
		print("Playing jump sound - Stream: ", jump_sound.stream)
		print("Jump sound volume: ", jump_sound.volume_db)
	else:
		print("Jump sound not available")


func _play_transition_sound() -> void:
	if transition_sound:
		transition_sound.play()
		print("Playing transition sound")
	else:
		print("Transition sound not available")


func _play_immortal_sound() -> void:
	if immortal_sound:
		immortal_sound.play()
		print("Playing immortal sound")
	else:
		print("Immortal sound not available")


func _play_click_sound() -> void:
	if click_sound:
		click_sound.volume_db = -5.0  # Quieter click sound
		click_sound.play()
		print("Playing click sound")
	else:
		print("Click sound not available")


func _test_audio_system() -> void:
	print("=== AUDIO SYSTEM TEST ===")
	print("Master volume: ", AudioServer.get_bus_volume_db(0))
	print("Audio driver: ", AudioServer.get_driver_name())
	print("Output device: ", AudioServer.get_output_device())
	
	# Test each sound
	if background_music:
		print("Background music stream: ", background_music.stream)
		print("Background music volume: ", background_music.volume_db)
		background_music.volume_db = 10.0  # Very loud
		background_music.play()
		print("Playing background music at max volume")
	
	if coin_sound:
		await get_tree().create_timer(1.0).timeout
		coin_sound.volume_db = 10.0
		coin_sound.play()
		print("Playing coin sound at max volume")
	
	if jump_sound:
		await get_tree().create_timer(1.0).timeout
		jump_sound.volume_db = 10.0
		jump_sound.play()
		print("Playing jump sound at max volume")
	
	if click_sound:
		await get_tree().create_timer(1.0).timeout
		click_sound.volume_db = 10.0
		click_sound.play()
		print("Playing click sound at max volume")


func _update_combo_system(_delta: float) -> void:
	_check_obstacle_dodge()
	if combo_count > 0 and (_now_sec() - last_dodge_time) > COMBO_RESET_TIME:
		if combo_count > max_combo_run: max_combo_run = combo_count
		combo_count = 0
		_update_combo_ui()
		_update_stats_hud()  # Update multiplier when combo resets


func _check_obstacle_dodge() -> void:
	var dino_pos = $Dino.global_position
	for obs in obstacles:
		if obs == null or obs.has_meta("dodged"):
			continue
		var obs_pos = obs.global_position
		if obs_pos.x < dino_pos.x and abs(obs_pos.x - dino_pos.x) <= 100.0:
			var perfect := _is_perfect_dodge(obs)
			obs.set_meta("dodged", true)
			_on_obstacle_dodged(perfect)


func _on_obstacle_dodged(perfect: bool=false) -> void:
	combo_count += 1
	last_dodge_time = _now_sec()
	var bonus_points = combo_count * 10
	add_score_points(bonus_points, $Dino.global_position + Vector2(0, -50))
	if perfect:
		near_miss_count += 1
		add_score_points(PERFECT_DODGE_POINTS, $Dino.global_position + Vector2(0, -70))
		shake_screen(6.0, 0.20)
	_update_combo_ui()
	_update_stats_hud()
	_show_combo_text()


func _update_combo_ui() -> void:
	if combo_count <= 0:
		combo_label.visible = false
		return
	combo_label.visible = true
	combo_label.text = "COMBO x" + str(combo_count)
	if combo_count >= 10:
		combo_label.add_theme_color_override("font_color", Color.MAGENTA)
	elif combo_count >= 5:
		combo_label.add_theme_color_override("font_color", Color.RED)
	else:
		combo_label.add_theme_color_override("font_color", Color.YELLOW)


func _show_combo_text() -> void:
	var combo_text := ""
	if combo_count >= 15:
		combo_text = "LEGENDARY!"
	elif combo_count >= 10:
		combo_text = "AMAZING!"
	elif combo_count >= 5:
		combo_text = "GREAT!"
	elif combo_count >= 3:
		combo_text = "NICE!"
	else:
		return
	_spawn_floating_text($Dino.global_position + Vector2(0, -80), combo_text)


# --- 1) ขนาดสไปรท์/แอนิเมชันของ node ใด ๆ (Godot 4) ---
func _sprite_dims_from(node: Node) -> Vector2:
	var spr: Sprite2D = node.get_node_or_null("Sprite2D") as Sprite2D
	if spr and spr.texture:
		return Vector2(
			spr.texture.get_width() * spr.scale.x,
			spr.texture.get_height() * spr.scale.y
		)

	var anim: AnimatedSprite2D = node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim:
		var sf: SpriteFrames = anim.sprite_frames
		if sf:
			var anim_name: StringName = anim.animation
			var names: PackedStringArray = sf.get_animation_names()
			if (anim_name == &"" or not names.has(String(anim_name))) and names.size() > 0:
				anim_name = StringName(names[0])  # ใช้อันแรกถ้าไม่ได้ตั้ง

			var count: int = sf.get_frame_count(anim_name)
			if count > 0:
				var idx: int = clampi(anim.frame, 0, count - 1)
				var tex: Texture2D = sf.get_frame_texture(anim_name, idx)
				if tex:
					return Vector2(tex.get_width() * anim.scale.x, tex.get_height() * anim.scale.y)

	return Vector2(48, 48)  # fallback


# --- 2) ขนาดของไดโนเอง (Godot 4) ---
func _dino_dims() -> Vector2:
	var anim: AnimatedSprite2D = $Dino.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim:
		var sf: SpriteFrames = anim.sprite_frames
		if sf:
			var anim_name: StringName = anim.animation
			var names: PackedStringArray = sf.get_animation_names()
			if (anim_name == &"" or not names.has(String(anim_name))) and names.size() > 0:
				anim_name = StringName(names[0])

			var count: int = sf.get_frame_count(anim_name)
			if count > 0:
				var idx: int = clampi(anim.frame, 0, count - 1)
				var tex: Texture2D = sf.get_frame_texture(anim_name, idx)
				if tex:
					return Vector2(tex.get_width() * anim.scale.x, tex.get_height() * anim.scale.y)

	var spr: Sprite2D = $Dino.get_node_or_null("Sprite2D") as Sprite2D
	if spr and spr.texture:
		return Vector2(
			spr.texture.get_width() * spr.scale.x,
			spr.texture.get_height() * spr.scale.y
		)

	return Vector2(48, 48)  # fallback

# --- 3) ตรวจ PERFECT DODGE (ใส่ชนิดให้ครบเพื่อโหมด strict) ---
func _is_perfect_dodge(obs: Node2D) -> bool:
	var dpos: Vector2 = $Dino.global_position
	var opos: Vector2 = obs.global_position

	if abs(opos.x - dpos.x) > PERFECT_DODGE_X_WINDOW:
		return false

	var od: Vector2 = _sprite_dims_from(obs)
	var dd: Vector2 = _dino_dims()

	var dino_top: float = dpos.y - dd.y * 0.5
	var dino_bottom: float = dpos.y + dd.y * 0.5
	var obs_top: float = opos.y - od.y * 0.5
	var obs_bottom: float = opos.y + od.y * 0.5

	var t: String = String(obs.get_meta("type"))
	if t == "bird":
		var gap: float = obs_bottom - dino_top
		return gap >= 0.0 and gap <= PERFECT_DODGE_Y_TOL_BIRD
	else:
		var gap2: float = dino_bottom - obs_top
		return gap2 >= 0.0 and gap2 <= PERFECT_DODGE_Y_TOL_GROUND


# ---------------------------------------------------------
# OBSTACLES (UPDATED WITH SHAKE)
# ---------------------------------------------------------
func generate_obs() -> void:
	var cam_x: int = int($Camera2D.position.x)
	var spawn_front: int = cam_x + screen_size.x + 100
	if spawn_front < next_obs_spawn_x: return

	var start_x: int = int(max(
		next_obs_spawn_x,
		int(last_spawn_right) + MIN_GAP_ANY,
		cam_x + MIN_FRONT_BUFFER
	))

	var spawn_bird_only: bool = randf() < 0.30

	if spawn_bird_only and difficulty >= 1:
		# Get stage-specific flying object
		var flying_scene = _get_current_flying_scene()
		var flying_obj = flying_scene.instantiate()
		flying_obj.set_meta("type", "bird")
		var bx: int = start_x
		if last_spawn_type == "obs":
			bx = max(bx, int(last_spawn_right) + MIN_GAP_BIRD_AFTER_OBS)
		var by: int = bird_heights[rng.randi_range(0, bird_heights.size() - 1)]
		add_obs(flying_obj, bx, by)
		last_spawn_right = float(bx + 48)
		last_spawn_type  = "bird"
	else:
		# Get stage-specific ground obstacles
		var current_obstacles = _get_current_obstacles()
		var obs_type = current_obstacles[randi() % current_obstacles.size()]
		var obs = obs_type.instantiate()
		obs.set_meta("type", "ground")

		var spr = obs.get_node("Sprite2D")
		var tex_w: int = spr.texture.get_width()
		var tex_h: int = spr.texture.get_height()
		var scx: float = spr.scale.x
		var scy: float = spr.scale.y
		var half_w: int = int(round(tex_w * scx * 0.5))

		var obs_y: int = 552 - int(round(tex_h * scy * 0.5))
		var obs_x: int = start_x
		add_obs(obs, obs_x, obs_y)

		last_spawn_right = float(obs_x + half_w)
		last_spawn_type  = "obs"

	next_obs_spawn_x = int(last_spawn_right) + randi_range(OBS_GAP_MIN, OBS_GAP_MAX)


# Get current stage obstacles
func _get_current_obstacles() -> Array:
	match current_bg_stage:
		1:
			return stage1_obstacles
		2:
			return stage2_obstacles
		3:
			return stage3_obstacles
		4:
			return stage4_obstacles
		_:
			return stage1_obstacles  # fallback


# Get current stage flying object
func _get_current_flying_scene() -> PackedScene:
	match current_bg_stage:
		1:
			return stage1_flying
		2:
			return stage2_flying
		3:
			return stage3_flying
		4:
			return stage4_flying
		_:
			return stage1_flying  # fallback


func add_obs(obs, x: int, y: int) -> void:
	obs.position = Vector2i(x, y)
	obs.z_index = 100  # ให้สิ่งกีดขวางอยู่ข้างหน้าสุด
	obs.body_entered.connect(hit_obs.bind(obs))
	add_child(obs)
	obstacles.append(obs)


func remove_obs(obs) -> void:
	if obs == null: return
	obs.queue_free()
	obstacles.erase(obs)


func hit_obs(body, obs):
	if body.name != "Dino": return
	if invincible:
		var now: float = _now_sec()
		if now - _last_hit_time < HIT_COOLDOWN: return
		_last_hit_time = now
		add_score_points(HIT_REWARD_POINTS, obs.global_position)
		shake_screen(8.0, 0.3)
		_play_explosion_sound()
		_create_explosion("small", obs.global_position, 1.5)
		obstacles_destroyed += 1
		remove_obs(obs)
	else:
		_play_explosion_sound()
		shake_screen(15.0, 0.5)
		game_over()


# ---------------------------------------------------------
# SCORE / HUD
# ---------------------------------------------------------
func show_score() -> void:
	var display_score: int = int(score / SCORE_MODIFIER)
	if _lb_score: _lb_score.text = "SCORE: " + str(display_score)
	if _lb_high: _lb_high.text = "HIGH SCORE: " + str(high_score / SCORE_MODIFIER)


func check_high_score() -> void:
	if score > high_score:
		high_score = int(score)
		save_best_score(high_score)
		if _lb_high: _lb_high.text = "HIGH SCORE: " + str(high_score / SCORE_MODIFIER)


func adjust_difficulty() -> void:
	difficulty = int(score / float(SPEED_MODIFIER))
	if difficulty > MAX_DIFFICULTY: difficulty = MAX_DIFFICULTY


func game_over() -> void:
	check_high_score()
	_stop_background_music()
	_play_gameover_sound()
	game_running = false
	
	# Wait for game over sound to play before pausing
	await get_tree().create_timer(0.5).timeout
	get_tree().paused = true
	if game_over_ui:
		# Prepare game data for GameOver UI
		var game_data = {
			"score": int(score / SCORE_MODIFIER),
			"coins": coins_collected,
			"distance": int(distance_traveled),
			"time": game_time,
			"best_score": int(high_score / SCORE_MODIFIER)
		}
		
		# Show GameOver UI with data
		game_over_ui.show_game_over(game_data)
		var button = game_over_ui.get_node_or_null("RestartButton")
		if not button:
			button = game_over_ui.get_node_or_null("Button")
		if button:
			button.grab_focus()


# ---------------------------------------------------------
# COINS (UPDATED WITH PARTICLES)
# ---------------------------------------------------------
func _last_obs_x() -> float:
	if obstacles.is_empty(): return -1.0e12
	var mx: float = -1.0e12
	for o in obstacles:
		if float(o.position.x) > mx:
			mx = float(o.position.x)
	return mx


func _spawn_next_coin() -> void:
	var cam_x: float = float($Camera2D.position.x)
	var front_buffer: float = float(screen_size.x) * 0.60
	var safe_from_obs: float = _last_obs_x() + COIN_SAFE_FROM_OBS
	var x: float = max(next_coin_x, cam_x + front_buffer, safe_from_obs)

	var lane_idx: int = rng.randi_range(0, item_lanes_y.size() - 1)
	var y: float = float(item_lanes_y[lane_idx])

	var c = coin_scene.instantiate()
	c.global_position = Vector2(x, y)
	c.z_index = 100  # ให้เหรียญอยู่ข้างหน้าสุด

	# connect signal "collected" ถ้ามี
	if c.has_signal("collected"):
		c.collected.connect(_on_coin_collected)

	items.add_child(c)
	next_coin_x = x + rng.randf_range(COIN_GAP_MIN, COIN_GAP_MAX)


func _on_coin_collected(coin_pos: Vector2) -> void:
	_play_coin_particle(coin_pos)
	_play_coin_sound()
	shake_screen(3.0, 0.15)


# ---------------------------------------------------------
# INVINCIBLE: HUD + GLOW + FOG
# ---------------------------------------------------------
func _start_invincible(sec: float) -> void:
	invincible   = true
	inv_end_time = _now_sec() + sec

	_play_immortal_sound()
	_set_glow(true)
	_fog_hide_for_invincible()

	_ensure_inv_hud()
	inv_panel.show()
	inv_bar.max_value = sec
	inv_bar.value     = sec
	inv_label.text    = "%0.1fs" % sec


func _update_inv_ui(remaining: float) -> void:
	_ensure_inv_hud()
	remaining = clamp(remaining, 0.0, INVINCIBLE_DURATION)
	if remaining > 0.0:
		if not inv_panel.visible: inv_panel.show()
		inv_bar.max_value = INVINCIBLE_DURATION
		inv_bar.value     = remaining
		inv_label.text    = "%0.1fs" % remaining
		inv_label.modulate = Color(1, 0.4, 0.4) if remaining <= 1.0 else Color(1, 1, 1)
	else:
		inv_panel.hide()


func _ensure_inv_hud() -> void:
	if inv_panel != null and inv_bar != null and inv_label != null:
		return
	var hud := _hud
	var panel := hud.get_node_or_null("InvPanel") as Control
	if panel == null:
		panel = Control.new()
		panel.name = "InvPanel"
		panel.visible = false
		panel.position = Vector2(20, 20)
		panel.size = Vector2(260, 26)
		hud.add_child(panel)

		var bar := ProgressBar.new()
		bar.name = "InvBar"
		bar.min_value = 0.0
		bar.max_value = INVINCIBLE_DURATION
		bar.value = 0.0
		bar.position = Vector2(0, 3)
		bar.size = Vector2(200, 20)
		panel.add_child(bar)

		var label := Label.new()
		label.name = "InvLabel"
		label.text = "0.0s"
		label.position = Vector2(208, 3)
		panel.add_child(label)

	inv_panel = panel
	inv_bar   = panel.get_node("InvBar") as ProgressBar
	inv_label = panel.get_node("InvLabel") as Label


# ----- Outline Glow Effect -----
func _ensure_glow_overlay() -> void:
	var spr := $Dino.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if spr.material != null and spr.material.get("shader") != null:
		return

	var shader_code := """
shader_type canvas_item;
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;
void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
	vec4 sprite_color = texture(TEXTURE, UV);
	float outline = 0.0;
	for(float x = -1.0; x <= 1.0; x += 1.0) {
		for(float y = -1.0; y <= 1.0; y += 1.0) {
			if(x == 0.0 && y == 0.0) continue;
			vec2 offset = vec2(x, y) * size;
			outline += texture(TEXTURE, UV + offset).a;
		}
	}
	outline = min(outline, 1.0);
	if(sprite_color.a == 0.0 && outline > 0.0) {
		COLOR = outline_color * glow_intensity;
	} else {
		COLOR = sprite_color;
	}
}
"""
	var shader := Shader.new()
	shader.code = shader_code
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("outline_width", 0.0)
	material.set_shader_parameter("outline_color", Color(1.0, 1.0, 0.0, 0.8))
	material.set_shader_parameter("glow_intensity", 0.0)
	spr.material = material


func _set_glow(on: bool) -> void:
	var spr := $Dino.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_ensure_glow_overlay()
	var material := spr.material as ShaderMaterial
	if material == null: return

	if on:
		var tween := create_tween()
		tween.set_loops()
		tween.parallel().tween_method(
			func(val): material.set_shader_parameter("outline_width", val),
			0.0, 3.0, 0.5
		)
		tween.parallel().tween_method(
			func(val): material.set_shader_parameter("glow_intensity", val),
			0.0, 1.5, 0.5
		)
		tween.parallel().tween_method(
			func(val): material.set_shader_parameter("outline_width", val),
			3.0, 1.5, 0.5
		)
		tween.parallel().tween_method(
			func(val): material.set_shader_parameter("glow_intensity", val),
			1.5, 0.8, 0.5
		)
	else:
		var tweens = get_tree().get_processed_tweens()
		for t in tweens:
			if t.is_valid():
				t.kill()
		material.set_shader_parameter("outline_width", 0.0)
		material.set_shader_parameter("glow_intensity", 0.0)


# ----- Time helper -----
func _now_sec() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


# ----- Score helpers -----
func _score_multiplier() -> float:
	if combo_count >= 15: return 1.5
	if combo_count >= 10: return 1.25
	if combo_count >= 5:  return 1.1
	return 1.0


func add_score_points(points: int, world_pos: Vector2 = Vector2.ZERO, use_multiplier: bool = true, is_coin: bool = false) -> void:
	var p := points
	if use_multiplier:
		p = int(round(points * _score_multiplier()))
	score += p * SCORE_MODIFIER
	show_score()
	
	# Count coins collected
	if is_coin:
		coins_collected += 1
	
	if world_pos != Vector2.ZERO:
		_spawn_floating_text(world_pos, "+" + str(p))


func _update_stats_hud() -> void:
	if _lb_perfect:   _lb_perfect.text   = "PERFECT: " + str(near_miss_count)
	if _lb_combo:     _lb_combo.text     = "COMBO: x" + str(max(combo_count, 0))
	var meters := int(max(0.0, ($Dino.position.x - float(DINO_START_POS.x)) / PX_PER_METER))
	if _lb_distance:  _lb_distance.text  = "DISTANCE: %dm" % meters
	if _lb_multiplier:_lb_multiplier.text = "MULTIPLIER: x%.1f" % _score_multiplier()


# ----- Floating world text -----
func _world_to_screen(p: Vector2) -> Vector2:
	return p - $Camera2D.position + Vector2(float(screen_size.x), float(screen_size.y)) * 0.5


func _spawn_floating_text(world_pos: Vector2, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.modulate.a = 1.0
	_hud.add_child(lbl)
	lbl.position = _world_to_screen(world_pos)

	var tween := create_tween()
	tween.parallel().tween_property(lbl, "position:y", lbl.position.y - 40.0, 0.8)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.tween_callback(lbl.queue_free)


# ----- Fog helpers -----
func _fog_set_alpha(a: float) -> void:
	if fog_mat == null: return
	var col: Color = fog_mat.get_shader_parameter("fog_color")
	col.a = a
	fog_mat.set_shader_parameter("fog_color", col)


func _fog_hide_for_invincible() -> void:
	if fog_mat == null or _fog_hidden_by_inv: return
	_fog_prev_alpha = (fog_mat.get_shader_parameter("fog_color") as Color).a
	_fog_hidden_by_inv = true

	if _fog_tween and is_instance_valid(_fog_tween): _fog_tween.kill()
	if _fog_radius_tween and is_instance_valid(_fog_radius_tween): _fog_radius_tween.kill()

	_fog_tween = create_tween()
	_fog_tween.parallel().tween_method(_fog_set_alpha, _fog_prev_alpha, 0.0, 0.8)

	_fog_radius_tween = create_tween()
	var current_radius = fog_mat.get_shader_parameter("radius_px") as float
	_fog_radius_tween.tween_method(
		func(r): fog_mat.set_shader_parameter("radius_px", r),
		current_radius,
		screen_size.x * 1.5,
		1.0
	)


func _fog_restore_after_invincible() -> void:
	if fog_mat == null or not _fog_hidden_by_inv: return
	_fog_hidden_by_inv = false

	if _fog_tween and is_instance_valid(_fog_tween): _fog_tween.kill()
	if _fog_radius_tween and is_instance_valid(_fog_radius_tween): _fog_radius_tween.kill()

	_fog_tween = create_tween()
	_fog_tween.tween_method(_fog_set_alpha, 0.0, FOG_ALPHA_MAX, 0.8)

	_fog_radius_tween = create_tween()
	var current_radius = fog_mat.get_shader_parameter("radius_px") as float
	var display_score: int = int(score / SCORE_MODIFIER)
	var t: float = clamp(float(display_score) / float(FOG_SCORE_FULL), 0.0, 1.0)
	var target_radius: float = lerp(FOG_RADIUS_MAX, FOG_RADIUS_MIN, t)

	_fog_radius_tween.tween_method(
		func(r): fog_mat.set_shader_parameter("radius_px", r),
		current_radius,
		target_radius,
		1.0
	)


# ----- Background Transition System -----
func _check_background_transition() -> void:
	if is_transitioning:
		return
		
	var current_distance: int = int(distance_traveled)
	
	for i in range(bg_transition_distances.size()):
		var target_stage = i + 2
		var required_distance = bg_transition_distances[i]
		
		if current_distance >= required_distance and current_bg_stage == target_stage - 1 and not bg_transitions_completed[i]:
			is_transitioning = true
			match target_stage:
				2:
					_transition_to_stage(2, "STAGE 2!")
				3:
					_transition_to_stage(3, "STAGE 3!")
				4:
					_transition_to_stage(4, "STAGE 4!")
			
			bg_transitions_completed[i] = true
			current_bg_stage = target_stage
			print("Background transitioned to stage ", target_stage, " at distance: ", current_distance, "m")
			break

func _transition_to_stage(stage: int, stage_text: String) -> void:
	print("=== STAGE TRANSITION DEBUG ===")
	print("Transitioning to stage: ", stage)
	print("Current dino position: ", $Dino.global_position)
	
	# Play transition sound
	_play_transition_sound()
	
	# Show stage text immediately without fade
	_show_stage_text(stage_text)
	
	print("Before removing current bg/ground:")
	print("- Current ground nodes in scene:")
	for child in get_children():
		if "Ground" in child.name:
			if child.has_method("get_position"):
				print("  - ", child.name, " at position: ", child.get_position())
			else:
				print("  - ", child.name, " (no position property)")
	
	# Remove current background and ground
	_remove_current_bg_ground()
	
	print("After removing current bg/ground")
	
	# Add new background and ground based on stage
	var new_bg: Node
	var new_ground: Node
	var bg_name: String
	var ground_name: String
	
	match stage:
		2:
			new_bg = bg2_scene.instantiate()
			new_ground = ground2_scene.instantiate()
			bg_name = "Bg2"
			ground_name = "Ground2"
		3:
			new_bg = bg3_scene.instantiate()
			new_ground = ground3_scene.instantiate()
			bg_name = "Bg3"
			ground_name = "Ground3"
		4:
			new_bg = bg4_scene.instantiate()
			new_ground = ground4_scene.instantiate()
			bg_name = "Bg4"
			ground_name = "Ground4"
	
	# Add them at the correct positions in scene tree
	add_child(new_bg)
	move_child(new_bg, 0)  	# Position new nodes at camera position
	
	# Only set position if it's not a ParallaxBackground
	if new_bg.get_class() != "ParallaxBackground":
		new_bg.position.x = $Camera2D.position.x - screen_size.x / 2
	new_ground.position.x = $Camera2D.position.x - screen_size.x / 2
	
	print("Adding new bg/ground:")
	print("- New bg type: ", new_bg.get_class())
	print("- New ground type: ", new_ground.get_class())
	
	# Add to scene
	add_child(new_ground)
	new_bg.name = bg_name
	new_ground.name = ground_name
	
	print("After adding new bg/ground:")
	print("- ", bg_name, " added (type: ", new_bg.get_class(), ")")
	print("- ", ground_name, " added (type: ", new_ground.get_class(), ")")
	print("- Dino position after transition: ", $Dino.global_position)
	
	# Check ground collision shape
	var collision_shape = new_ground.get_node("CollisionShape2D")
	if collision_shape:
		print("- Ground collision position: ", collision_shape.position)
		print("- Ground collision shape size: ", collision_shape.shape.size)
	
	# Add screen shake for transition effect
	shake_screen(8.0, 0.5)
	
	print("=== END STAGE TRANSITION DEBUG ===")
	
	# Unlock transitions
	is_transitioning = false

func _show_stage_text(stage_text: String) -> void:
	# Create a label to show stage transition text
	var stage_label = Label.new()
	stage_label.text = stage_text
	stage_label.add_theme_font_size_override("font_size", 48)
	stage_label.add_theme_color_override("font_color", Color.WHITE)
	stage_label.position = Vector2(screen_size.x / 2 - 100, screen_size.y / 2)
	stage_label.z_index = 1000
	
	# Add to HUD
	_hud.add_child(stage_label)
	
	# Animate the text
	var tween = create_tween()
	tween.parallel().tween_property(stage_label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(stage_label.queue_free)

func _remove_current_bg_ground() -> void:
	# Remove any existing background and ground nodes immediately
	var nodes_to_remove = []
	for child in get_children():
		if child.name.begins_with("Bg") or child.name.begins_with("Ground"):
			print("- Removing node: ", child.name, " (type: ", child.get_class(), ")")
			nodes_to_remove.append(child)
	
	for node in nodes_to_remove:
		remove_child(node)
		node.queue_free()

# Removed fade effects to prevent black screen

func _create_other_transition_effects(stage_text: String) -> void:
	# Screen shake for dramatic effect
	shake_screen(12.0, 1.2)
	
	# Show transition text
	_spawn_floating_text($Dino.global_position + Vector2(0, -100), stage_text)
	
	# Add some sparkle particles for extra effect
	_create_transition_particles()

func _create_transition_particles() -> void:
	# Create sparkle effect during transition
	var sparkle_particles = GPUParticles2D.new()
	sparkle_particles.name = "TransitionSparkles"
	sparkle_particles.emitting = true
	sparkle_particles.amount = 100
	sparkle_particles.lifetime = 2.0
	sparkle_particles.position = $Dino.global_position
	sparkle_particles.process_material = _create_sparkle_material()
	add_child(sparkle_particles)
	
	# Auto-remove after effect
	await get_tree().create_timer(2.5).timeout
	if sparkle_particles and is_instance_valid(sparkle_particles):
		sparkle_particles.queue_free()

func _create_sparkle_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 360.0
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 150.0
	material.gravity = Vector3(0, -50, 0)
	material.scale_min = 0.2
	material.scale_max = 0.8
	material.color = Color(1.0, 1.0, 0.2, 0.8)
	return material


# ----- Best Score Management -----
func load_best_score() -> int:
	var save_file = FileAccess.open("user://best_score.save", FileAccess.READ)
	if save_file:
		var best_score = save_file.get_32()
		save_file.close()
		return best_score
	return 0

func save_best_score(new_high_score: int) -> void:
	var save_file = FileAccess.open("user://best_score.save", FileAccess.WRITE)
	if save_file:
		save_file.store_32(new_high_score)
		save_file.close()
		print("High score saved: ", new_high_score)

# ----- Explosion Effects -----
func _create_explosion(type: String, pos: Vector2, scale_factor: float = 1.0) -> void:
	var explosion = explosion_scene.instantiate()
	add_child(explosion)
	explosion.play_explosion(type, pos, scale_factor)
