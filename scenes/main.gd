extends Node

# ====== PRELOAD ======
var stump_scene  = preload("res://scenes/stump.tscn")
var rock_scene   = preload("res://scenes/rock.tscn")
var barrel_scene = preload("res://scenes/barrel.tscn")
var bird_scene   = preload("res://scenes/bird.tscn")
var coin_scene   = preload("res://scenes/Coin.tscn")
var obstacle_types := [stump_scene, rock_scene, barrel_scene]
var bird_heights: Array[int] = [200, 390]

# ====== GAME VARS ======
const DINO_START_POS := Vector2i(150, 485)
const CAM_START_POS  := Vector2i(576, 324)

var screen_size: Vector2i
var ground_height: int

var score: float
const SCORE_MODIFIER: int = 10
var high_score: int

var speed: float
const START_SPEED: float = 450.0
const MAX_SPEED: int = 900
const SPEED_MODIFIER: int = 1200

var difficulty: int
const MAX_DIFFICULTY: int = 2

var game_running: bool

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
var next_invincible_score: int = 500
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

# best (เฉพาะในเซสชัน)
var best_coins: int = 0
var best_combo: int = 0
var best_time: float = 0.0
var best_destroyed: int = 0

const PX_PER_METER: float = 10.0  # ปรับตามสเกลฉาก

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
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()

	# ให้ UI กดได้ตอน paused
	$GameOver.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	$GameOver.get_node("Button").process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	$GameOver.get_node("Button").pressed.connect(_on_restart_pressed)

	# ตั้ง Shader หมอก
	if fog_mat:
		fog_mat.set_shader_parameter("screen_size", Vector2(screen_size))
		fog_mat.set_shader_parameter("softness_px", FOG_SOFTNESS)
		fog_mat.set_shader_parameter("fog_color", Color(0,0,0, FOG_ALPHA_MAX))
		fog_mat.set_shader_parameter("radius_px", FOG_RADIUS_MAX)

	_setup_particles()
	_setup_combo_ui()
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
	next_invincible_score = 500
	_set_glow(false)

	# counters
	near_miss_count = 0
	combo_count = 0
	max_combo_run = 0
	run_start_time = _now_sec()
	_update_stats_hud()

	# obstacles
	for obs in obstacles: obs.queue_free()
	obstacles.clear()

	# reset nodes
	$Dino.position = DINO_START_POS
	$Dino.velocity = Vector2.ZERO
	$Camera2D.position = CAM_START_POS
	$Ground.position = Vector2i(0, 0)

	# Reset shake
	original_cam_pos = $Camera2D.position
	shake_strength = 0.0
	shake_duration = 0.0
	shake_timer = 0.0

	# HUD
	_hud.get_node("StartLabel").show()
	$GameOver.hide()

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

		# Particles & combo
		_update_dust_particles(delta)
		_update_combo_system(delta)

		# trigger invincible (+500 display score)
		if int(score / SCORE_MODIFIER) >= next_invincible_score:
			next_invincible_score += 500
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

		# ground loop
		if $Camera2D.position.x - $Ground.position.x > screen_size.x * 1.5:
			$Ground.position.x += screen_size.x

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


func _update_combo_system(_delta: float) -> void:
	_check_obstacle_dodge()
	if combo_count > 0 and (_now_sec() - last_dodge_time) > COMBO_RESET_TIME:
		if combo_count > max_combo_run: max_combo_run = combo_count
		combo_count = 0
		_update_combo_ui()


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
		var bird = bird_scene.instantiate()
		bird.set_meta("type", "bird")
		var bx: int = start_x
		if last_spawn_type == "obs":
			bx = max(bx, int(last_spawn_right) + MIN_GAP_BIRD_AFTER_OBS)
		var by: int = bird_heights[rng.randi_range(0, bird_heights.size() - 1)]
		add_obs(bird, bx, by)
		last_spawn_right = float(bx + 48)
		last_spawn_type  = "bird"
	else:
		var obs_type = obstacle_types[randi() % obstacle_types.size()]
		var obs = obs_type.instantiate()
		obs.set_meta("type", "ground")

		var spr = obs.get_node("Sprite2D")
		var tex_w: int = spr.texture.get_width()
		var tex_h: int = spr.texture.get_height()
		var scx: float = spr.scale.x
		var scy: float = spr.scale.y
		var half_w: int = int(round(tex_w * scx * 0.5))

		var obs_y: int = screen_size.y - ground_height - int(round(tex_h * scy / 2.0)) + 5
		var obs_x: int = start_x
		add_obs(obs, obs_x, obs_y)

		last_spawn_right = float(obs_x + half_w)
		last_spawn_type  = "obs"

	next_obs_spawn_x = int(last_spawn_right) + randi_range(OBS_GAP_MIN, OBS_GAP_MAX)


func add_obs(obs, x: int, y: int) -> void:
	obs.position = Vector2i(x, y)
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
		remove_obs(obs)
	else:
		shake_screen(15.0, 0.5)
		game_over()


# ---------------------------------------------------------
# SCORE / HUD
# ---------------------------------------------------------
func show_score() -> void:
	var display_score: int = int(score / SCORE_MODIFIER)
	if _lb_score: _lb_score.text = "SCORE: " + str(display_score)


func check_high_score() -> void:
	if score > high_score:
		high_score = int(score)
		if _lb_high: _lb_high.text = "HIGH SCORE: " + str(high_score / SCORE_MODIFIER)


func adjust_difficulty() -> void:
	difficulty = int(score / float(SPEED_MODIFIER))
	if difficulty > MAX_DIFFICULTY: difficulty = MAX_DIFFICULTY


func game_over() -> void:
	check_high_score()
	get_tree().paused = true
	game_running = false
	$GameOver.show()
	$GameOver.get_node("Button").grab_focus()


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

	# connect signal "collected" ถ้ามี
	if c.has_signal("collected"):
		c.collected.connect(_on_coin_collected)

	items.add_child(c)
	next_coin_x = x + rng.randf_range(COIN_GAP_MIN, COIN_GAP_MAX)


func _on_coin_collected(coin_pos: Vector2) -> void:
	_play_coin_particle(coin_pos)
	shake_screen(3.0, 0.15)


# ---------------------------------------------------------
# INVINCIBLE: HUD + GLOW + FOG
# ---------------------------------------------------------
func _start_invincible(sec: float) -> void:
	invincible   = true
	inv_end_time = _now_sec() + sec

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


func add_score_points(points: int, world_pos: Vector2 = Vector2.ZERO, use_multiplier: bool = true) -> void:
	var p := points
	if use_multiplier:
		p = int(round(points * _score_multiplier()))
	score += p * SCORE_MODIFIER
	show_score()
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
