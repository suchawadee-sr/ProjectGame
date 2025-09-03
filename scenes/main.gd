extends Node

# ====== Preload ======
var stump_scene  = preload("res://scenes/stump.tscn")
var rock_scene   = preload("res://scenes/rock.tscn")
var barrel_scene = preload("res://scenes/barrel.tscn")
var bird_scene   = preload("res://scenes/bird.tscn")
var coin_scene   = preload("res://scenes/Coin.tscn")

# ====== Stage assets ======
const BG1_PATH     := "res://scenes/bg.tscn"
const GROUND1_PATH := "res://scenes/ground.tscn"
const BG2_PATH     := "res://scenes/bg2.tscn"
const GROUND2_PATH := "res://scenes/ground2.tscn"
const BG1_CANDIDATES      := ["res://scenes/bg.tscn", "res://bg.tscn"]
const GROUND1_CANDIDATES  := ["res://scenes/ground.tscn", "res://ground.tscn"]
const BG2_CANDIDATES      := ["res://scenes/bg2.tscn", "res://bg2.tscn"]
const GROUND2_CANDIDATES  := ["res://scenes/ground2.tscn", "res://ground2.tscn"]

# กลุ่มสิ่งกีดขวาง/ความสูงนก แยกตามสเตจ
var obst_stage1: Array = [stump_scene, rock_scene, barrel_scene]
var obst_stage2: Array = [barrel_scene, rock_scene, stump_scene]
var bird_y_stage1: Array[int] = [200, 390]
var bird_y_stage2: Array[int] = [240, 400]

# ตัวแปรที่ generator ใช้งาน (ต้องมีแน่นอน)
var obstacle_types: Array = obst_stage1.duplicate()
var bird_heights: Array[int] = bird_y_stage1.duplicate()

# ====== Game vars ======
const DINO_START_POS := Vector2i(150, 485)
const CAM_START_POS  := Vector2i(576, 324)

var screen_size: Vector2i
var ground_height: int
var floor_y_local: float = 0.0   # baseline Y ของพื้น (จาก Marker "Floor")

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

# ----- Draw order (สูง = อยู่บน) -----
const Z_BG := -50
const Z_GROUND := -10
const Z_OBS := 10
const Z_ITEMS := 12
const Z_DINO := 20

# ====== Items (เหรียญ) ======
@onready var items := $Items
var item_lanes_y: Array[float] = [485.0, 430.0, 390.0]
const COIN_GAP_MIN: float = 500.0
const COIN_GAP_MAX: float = 900.0
const COIN_SAFE_FROM_OBS: float = 200.0
var next_coin_x: float = 0.0

# ====== Obstacles spacing ======
const OBS_GAP_MIN: int = 420
const OBS_GAP_MAX: int = 680
const MIN_GAP_ANY: int = 560
const MIN_GAP_BIRD_AFTER_OBS: int = 340
const MIN_FRONT_BUFFER: int = 720

var obstacles: Array = []
var next_obs_spawn_x: int = 0
var last_spawn_right: float = -1.0e9
var last_spawn_type: String = ""   # "obs" | "bird" | ""

# ====== Invincible mode ======
var invincible: bool = false
var inv_end_time: float = 0.0
var next_invincible_score: int = 500
const INVINCIBLE_DURATION: float = 5.0
const HIT_REWARD_POINTS: int = 50
const HIT_COOLDOWN: float = 0.35
var _last_hit_time: float = -1000.0

# ====== HUD refs ======
var inv_panel: Control
var inv_bar: ProgressBar
var inv_label: Label

# ====== RNG ======
var rng := RandomNumberGenerator.new()

# ====== Stage switch (HUD score) ======
const STAGE2_HUD_THRESHOLD: int = 500
var stage2_switched: bool = false

# ---------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------
func _ready() -> void:
	screen_size = get_window().size
	if $Ground.has_node("Sprite2D"):
		ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	$GameOver.get_node("Button").pressed.connect(new_game)
	new_game()

func new_game() -> void:
	rng.randomize()

	# core
	score = 0.0
	show_score()
	game_running = false
	get_tree().paused = false
	difficulty = 0
	invincible = false
	next_invincible_score = 500
	stage2_switched = false
	_set_glow(false)

	# clear obstacles
	for obs in obstacles: obs.queue_free()
	obstacles.clear()

	# reset nodes
	$Dino.position = DINO_START_POS
	$Dino.velocity = Vector2i(0, 0)
	$Camera2D.position = CAM_START_POS
	$Ground.position = Vector2i(0, 0)

	# กลับฉากแรกเสมอ
	_apply_stage1()

	# HUD
	$HUD.get_node("StartLabel").show()
	$GameOver.hide()

	# ensure Inv HUD
	_ensure_inv_hud()
	inv_panel.hide()
	inv_bar.min_value = 0.0
	inv_bar.max_value = INVINCIBLE_DURATION
	inv_bar.value     = 0.0
	inv_label.text    = "0.0s"

	# clear coins
	for n in items.get_children(): n.queue_free()

	# spacing refs
	last_spawn_right = float($Camera2D.position.x) - 2000.0
	last_spawn_type  = ""
	next_obs_spawn_x = int($Camera2D.position.x) + screen_size.x + 100

	# coin first
	next_coin_x = float($Camera2D.position.x) + float(screen_size.x) * 0.75
	_spawn_next_coin()

# ---------------------------------------------------------
# Per-frame
# ---------------------------------------------------------
func _process(delta: float) -> void:
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

		# score by distance
		score += speed * delta
		show_score()

		# stage switch when HUD score reached
		var hud_score := int(score / SCORE_MODIFIER)
		if (not stage2_switched) and hud_score >= STAGE2_HUD_THRESHOLD:
			stage2_switched = true
			_apply_stage2()

		# unlock invincible every +500 display points
		if hud_score >= next_invincible_score:
			next_invincible_score += 500
			_start_invincible(INVINCIBLE_DURATION)

		# invincible countdown
		if invincible:
			var remaining: float = clamp(inv_end_time - _now_sec(), 0.0, INVINCIBLE_DURATION)
			_update_inv_ui(remaining)
			if remaining <= 0.0:
				invincible = false
				_set_glow(false)
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
			$HUD.get_node("StartLabel").hide()

# ---------------------------------------------------------
# Obstacles (hard spacing)
# ---------------------------------------------------------
func generate_obs() -> void:
	var cam_x: int = int($Camera2D.position.x)
	var spawn_front: int = cam_x + screen_size.x + 100
	if spawn_front < next_obs_spawn_x:
		return

	var start_x: int = int(max(
		next_obs_spawn_x,
		int(last_spawn_right) + MIN_GAP_ANY,
		cam_x + MIN_FRONT_BUFFER
	))

	var spawn_bird_only: bool = randf() < 0.30

	if spawn_bird_only and difficulty >= 1:
		var bird = bird_scene.instantiate()
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

		var spr = obs.get_node("Sprite2D")
		var tex_w: int = spr.texture.get_width()
		var tex_h: int = spr.texture.get_height()
		var scx: float = spr.scale.x
		var scy: float = spr.scale.y
		var half_w: int = int(round(tex_w * scx * 0.5))

		# ตำแหน่ง Y จาก baseline ของพื้น (Marker "Floor")
		var obs_y: float = floor_y_local - (tex_h * scy * 0.5) + 5.0
		var obs_x: float = float(start_x)
		add_obs(obs, int(roundi(obs_x)), int(roundi(obs_y)))

		last_spawn_right = float(obs_x + half_w)
		last_spawn_type  = "obs"

	next_obs_spawn_x = int(last_spawn_right) + randi_range(OBS_GAP_MIN, OBS_GAP_MAX)

func add_obs(obs, x: int, y: int) -> void:
	obs.position = Vector2(x, y)
	if obs is CanvasItem:
		(obs as CanvasItem).z_index = Z_OBS
	obs.body_entered.connect(hit_obs.bind(obs))
	add_child(obs)
	obstacles.append(obs)

func remove_obs(obs) -> void:
	if obs == null: return
	obs.queue_free()
	obstacles.erase(obs)

func hit_obs(body, obs):
	if body.name != "Dino":
		return
	if invincible:
		var now: float = _now_sec()
		if now - _last_hit_time < HIT_COOLDOWN:
			return
		_last_hit_time = now
		add_score_points(HIT_REWARD_POINTS, obs.global_position)
		remove_obs(obs)
	else:
		game_over()

# ---------------------------------------------------------
# Score / HUD text
# ---------------------------------------------------------
func show_score() -> void:
	var display_score: int = int(score / SCORE_MODIFIER)
	$HUD.get_node("ScoreLabel").text = "SCORE: " + str(display_score)

func check_high_score() -> void:
	if score > high_score:
		high_score = score
		$HUD.get_node("HighScoreLabel").text = "HIGH SCORE: " + str(high_score / SCORE_MODIFIER)

func adjust_difficulty() -> void:
	difficulty = score / SPEED_MODIFIER
	if difficulty > MAX_DIFFICULTY:
		difficulty = MAX_DIFFICULTY

func game_over() -> void:
	check_high_score()
	get_tree().paused = true
	game_running = false
	$GameOver.show()

# ---------------------------------------------------------
# Coins (one by one)
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
	items.add_child(c)

	next_coin_x = x + rng.randf_range(COIN_GAP_MIN, COIN_GAP_MAX)

# ---------------------------------------------------------
# Invincible: HUD + Glow + Utils
# ---------------------------------------------------------
func _start_invincible(sec: float) -> void:
	invincible   = true
	inv_end_time = _now_sec() + sec
	_set_glow(true)
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
	else:
		inv_panel.hide()

func _ensure_inv_hud() -> void:
	if inv_panel != null and inv_bar != null and inv_label != null: return
	var hud := $HUD
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

func _ensure_glow_material() -> void:
	var spr := $Dino.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if spr.material is ShaderMaterial: return
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform bool enabled = false;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.3, 1.0);
uniform float thickness = 2.0;
uniform float speed = 6.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (!enabled) {
		COLOR = tex;
	} else {
		vec2 ts = vec2(textureSize(TEXTURE, 0));
		float r = thickness / max(1.0, min(ts.x, ts.y));
		float a = 0.0;
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				vec2 off = vec2(float(x), float(y)) * r;
				a = max(a, texture(TEXTURE, UV + off).a);
			}
		}
		if (tex.a < 0.1 && a > 0.0) {
			float t = 0.5 + 0.5 * sin(TIME * speed);
			COLOR = vec4(glow_color.rgb, t * glow_color.a);
		} else {
			COLOR = tex;
		}
	}
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	spr.material = mat

func _set_glow(on: bool) -> void:
	_ensure_glow_material()
	var spr := $Dino.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var mat := spr.material as ShaderMaterial
	mat.set_shader_parameter("enabled", on)

func _now_sec() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

# ---------------------------------------------------------
# Points + floating text (optional)
# ---------------------------------------------------------
func add_score_points(points: int, world_pos: Vector2 = Vector2.ZERO) -> void:
	score += points * SCORE_MODIFIER
	show_score()
	if world_pos != Vector2.ZERO:
		_spawn_floating_text(world_pos, "+" + str(points))

func _world_to_screen(p: Vector2) -> Vector2:
	return p - $Camera2D.position + Vector2(float(screen_size.x), float(screen_size.y)) * 0.5

func _spawn_floating_text(world_pos: Vector2, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.modulate.a = 1.0
	$HUD.add_child(lbl)
	lbl.position = _world_to_screen(world_pos)
	var tween := create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 40.0, 0.5)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)

# ---------------------------------------------------------
# Stage switch helpers
# ---------------------------------------------------------
func _swap_node(old_node: Node, new_scene_path: String) -> bool:
	if not is_instance_valid(old_node): return false
	if not ResourceLoader.exists(new_scene_path):
		push_warning("Swap fail: no scene at %s" % new_scene_path)
		return false

	var packed := load(new_scene_path) as PackedScene
	if packed == null:
		push_warning("Swap fail: load error %s" % new_scene_path)
		return false

	var parent := old_node.get_parent()
	var idx := old_node.get_index()
	var old_name := old_node.name

	var new_node := packed.instantiate()
	new_node.name = old_name
	if old_node is Node2D and new_node is Node2D:
		(new_node as Node2D).position = (old_node as Node2D).position

	# สลับแบบปลอดภัย
	old_node.name = old_name + "_old"
	parent.add_child(new_node)
	parent.move_child(new_node, idx)
	old_node.queue_free()

	print("[Swap] %s -> %s" % [old_name, new_scene_path])
	return true

func _swap_to_first_existing(node: Node, candidates: Array) -> bool:
	for p in candidates:
		if ResourceLoader.exists(p):
			return _swap_node(node, p)
	push_warning("No candidate exists for %s" % [candidates])
	return false


func _apply_stage1() -> void:
	_swap_to_first_existing($Bg, BG1_CANDIDATES)
	_swap_to_first_existing($Ground, GROUND1_CANDIDATES)
	obstacle_types = obst_stage1.duplicate()
	bird_heights   = bird_y_stage1.duplicate()
	_refresh_ground_metrics()
	_apply_draw_order()
	_force_bg_behind()
	for o in obstacles: o.queue_free()
	obstacles.clear()
	last_spawn_right = float($Camera2D.position.x)
	last_spawn_type  = ""
	next_obs_spawn_x = int($Camera2D.position.x) + screen_size.x + 100
	print("[Stage] 1 applied")

func _apply_stage2() -> void:
	_swap_to_first_existing($Bg, BG2_CANDIDATES)
	_swap_to_first_existing($Ground, GROUND2_CANDIDATES)
	obstacle_types = obst_stage2.duplicate()
	bird_heights   = bird_y_stage2.duplicate()
	_refresh_ground_metrics()
	_apply_draw_order()
	_force_bg_behind()
	for o in obstacles: o.queue_free()
	obstacles.clear()
	last_spawn_right = float($Camera2D.position.x)
	last_spawn_type  = ""
	next_obs_spawn_x = int($Camera2D.position.x) + 200
	if $HUD.has_node("StageLabel"):
		var L := $HUD.get_node("StageLabel") as Label
		L.text = "STAGE 2"
		L.show()
	print("[Stage] 2 applied")


# ---------------------------------------------------------
# Draw order / Ground metrics
# ---------------------------------------------------------
func _apply_draw_order() -> void:
	if $Bg is CanvasItem:        ($Bg as CanvasItem).z_index = Z_BG
	elif $Bg is CanvasLayer:     ($Bg as CanvasLayer).layer = -10
	if $Ground is CanvasItem:    ($Ground as CanvasItem).z_index = Z_GROUND
	if $Dino is CanvasItem:      ($Dino as CanvasItem).z_index = Z_DINO
	if items is CanvasItem:      (items as CanvasItem).z_index = Z_ITEMS

func _force_bg_behind() -> void:
	if $Bg is CanvasLayer:
		($Bg as CanvasLayer).layer = -10
	else:
		_set_ci_recursive($Bg, Z_BG)

func _set_ci_recursive(n: Node, z_val: int) -> void:
	if n is CanvasItem:
		var ci := n as CanvasItem
		ci.z_index = z_val
		ci.z_as_relative = true
	for c in n.get_children():
		_set_ci_recursive(c, z_val)

# หา Y ของขอบบนจาก CollisionShape2D (ถ้าเจอ)
func _floor_y_from_collision() -> float:
	var cs := $Ground.find_child("CollisionShape2D", true, false) as CollisionShape2D
	if cs == null or cs.shape == null:
		return NAN

	var top_y := INF
	var shp := cs.shape

	if shp is RectangleShape2D:
		var s := (shp as RectangleShape2D).size
		top_y = cs.to_global(Vector2(0, -s.y * 0.5)).y

	elif shp is SegmentShape2D:
		var seg := shp as SegmentShape2D
		top_y = min(cs.to_global(seg.a).y, cs.to_global(seg.b).y)

	elif shp is CapsuleShape2D:
		var cap := shp as CapsuleShape2D
		var top_local := Vector2(0, -(cap.height * 0.5 + cap.radius))
		top_y = cs.to_global(top_local).y

	elif shp is CircleShape2D:
		var cir := shp as CircleShape2D
		top_y = cs.to_global(Vector2(0, -cir.radius)).y

	elif shp is ConvexPolygonShape2D:
		for p in (shp as ConvexPolygonShape2D).points:
			top_y = min(top_y, cs.to_global(p).y)

	elif shp is ConcavePolygonShape2D:
		var segs := (shp as ConcavePolygonShape2D).segments
		for i in range(0, segs.size(), 2):
			top_y = min(top_y, cs.to_global(segs[i]).y, cs.to_global(segs[i + 1]).y)

	if top_y == INF:
		return NAN
	return top_y


# อัปเดตค่าพื้น: ใช้ Marker "Floor" → ถ้าไม่มี ใช้ CollisionShape2D → ถ้าไม่มีอีก ค่อยเดาจาก Sprite
func _refresh_ground_metrics() -> void:
	var spr := $Ground.get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		ground_height = spr.texture.get_height()

	# 1) ใช้ Marker2D "Floor" ถ้ามี
	var m := $Ground.get_node_or_null("Floor") as Node2D
	if m:
		floor_y_local = m.global_position.y
		return

	# 2) ไม่มี Marker → ใช้ CollisionShape2D
	var y_from_col := _floor_y_from_collision()
	if not is_nan(y_from_col):
		floor_y_local = y_from_col
		return

	# 3) Fallback เดาจาก Sprite
	if spr:
		var tex_h := float(spr.texture.get_height())
		var scy   := float(spr.scale.y)
		var sprite_top := spr.global_position.y - (tex_h * scy * 0.5)
		floor_y_local = sprite_top + 8.0
		push_warning("No Floor marker/CollisionShape2D; approximate floor y=%.1f" % floor_y_local)
	else:
		floor_y_local = float(screen_size.y - ground_height)
		push_warning("Ground has no Sprite2D; rough floor y=%.1f" % floor_y_local)




#extends Node
#
## ====== Preload ======
#var stump_scene  = preload("res://scenes/stump.tscn")
#var rock_scene   = preload("res://scenes/rock.tscn")
#var barrel_scene = preload("res://scenes/barrel.tscn")
#var bird_scene   = preload("res://scenes/bird.tscn")
#var coin_scene   = preload("res://scenes/Coin.tscn")
#
#var obstacle_types := [stump_scene, rock_scene, barrel_scene]
#var bird_heights: Array[int] = [200, 390]
#
## ====== Game vars ======
#const DINO_START_POS := Vector2i(150, 485)
#const CAM_START_POS  := Vector2i(576, 324)
#
#var screen_size: Vector2i
#var ground_height: int
#
#var score: float
#const SCORE_MODIFIER: int = 10
#var high_score: int
#
#var speed: float
#const START_SPEED: float = 450.0
#const MAX_SPEED: int = 900
#const SPEED_MODIFIER: int = 1200
#
#var difficulty: int
#const MAX_DIFFICULTY: int = 2
#
#var game_running: bool
#
## ====== Items (เหรียญ) ======
#@onready var items := $Items                         # Node2D
#var item_lanes_y: Array[float] = [485.0, 430.0, 390.0]
#const COIN_GAP_MIN: float = 500.0
#const COIN_GAP_MAX: float = 900.0
#const COIN_SAFE_FROM_OBS: float = 200.0
#var next_coin_x: float = 0.0
#
## ====== Obstacles spacing ======
#const OBS_GAP_MIN: int = 420
#const OBS_GAP_MAX: int = 680
#const MIN_GAP_ANY: int = 560
#const MIN_GAP_BIRD_AFTER_OBS: int = 340
#const MIN_FRONT_BUFFER: int = 720
#
#var obstacles: Array = []
#var next_obs_spawn_x: int = 0
#var last_spawn_right: float = -1.0e9
#var last_spawn_type: String = ""   # "obs" | "bird" | ""
#
## ====== Invincible mode ======
#var invincible: bool = false
#var inv_end_time: float = 0.0
#var next_invincible_score: int = 500
#const INVINCIBLE_DURATION: float = 5.0
#const HIT_REWARD_POINTS: int = 50
#const HIT_COOLDOWN: float = 0.35
#var _last_hit_time: float = -1000.0
#
## ====== HUD refs (ปล่อยว่างไว้ แล้วไปตั้งค่าใน _ensure_inv_hud) ======
#var inv_panel: Control
#var inv_bar: ProgressBar
#var inv_label: Label
#
## ====== RNG ======
#var rng := RandomNumberGenerator.new()
#
## ---------------------------------------------------------
## Lifecycle
## ---------------------------------------------------------
#func _ready() -> void:
	#screen_size   = get_window().size
	#ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	#$GameOver.get_node("Button").pressed.connect(new_game)
	#new_game()
#
#func new_game() -> void:
	#rng.randomize()
#
	## core
	#score = 0.0
	#show_score()
	#game_running = false
	#get_tree().paused = false
	#difficulty = 0
	#invincible = false
	#next_invincible_score = 500
	#_set_glow(false)
#
	## clear obstacles
	#for obs in obstacles:
		#obs.queue_free()
	#obstacles.clear()
#
	## reset nodes
	#$Dino.position = DINO_START_POS
	#$Dino.velocity = Vector2i(0, 0)
	#$Camera2D.position = CAM_START_POS
	#$Ground.position = Vector2i(0, 0)
#
	## HUD
	#$HUD.get_node("StartLabel").show()
	#$GameOver.hide()
#
	## สร้าง/ผูก InvPanel, InvBar, InvLabel (ถ้าไม่มีจะสร้างให้)
	#_ensure_inv_hud()
	#inv_panel.hide()
	#inv_bar.min_value = 0.0
	#inv_bar.max_value = INVINCIBLE_DURATION
	#inv_bar.value     = 0.0
	#inv_label.text    = "0.0s"
#
	## clear coins
	#for n in items.get_children():
		#n.queue_free()
#
	## spacing refs
	#last_spawn_right = float($Camera2D.position.x) - 2000.0
	#last_spawn_type  = ""
	#next_obs_spawn_x = int($Camera2D.position.x) + screen_size.x + 100
#
	## coin first
	#next_coin_x = float($Camera2D.position.x) + float(screen_size.x) * 0.75
	#_spawn_next_coin()
#
## ---------------------------------------------------------
## Per-frame
## ---------------------------------------------------------
#func _process(delta: float) -> void:
	#if game_running:
		## speed & difficulty
		#speed = START_SPEED + float(score) / float(SPEED_MODIFIER)
		#if speed > MAX_SPEED:
			#speed = MAX_SPEED
		#adjust_difficulty()
#
		## obstacles
		#generate_obs()
#
		## move
		#$Dino.position.x     += speed * delta
		#$Camera2D.position.x += speed * delta
#
		## score by distance
		#score += speed * delta
		#show_score()
#
		## unlock invincible every +500 display points
		#if int(score / SCORE_MODIFIER) >= next_invincible_score:
			#next_invincible_score += 500
			#_start_invincible(INVINCIBLE_DURATION)
#
		## countdown + HUD
		#if invincible:
			#var remaining: float = clamp(inv_end_time - _now_sec(), 0.0, INVINCIBLE_DURATION)
			#_update_inv_ui(remaining)
			#if remaining <= 0.0:
				#invincible = false
				#_set_glow(false)
				#_update_inv_ui(0.0)
#
		## ground loop
		#if $Camera2D.position.x - $Ground.position.x > screen_size.x * 1.5:
			#$Ground.position.x += screen_size.x
#
		## cull old obstacles
		#for obs in obstacles:
			#if obs.position.x < ($Camera2D.position.x - screen_size.x):
				#remove_obs(obs)
#
		## coin spawn 1-by-1
		#if float($Camera2D.position.x) >= next_coin_x:
			#_spawn_next_coin()
#
		## cull coins behind
		#for n in items.get_children():
			#if n.global_position.x < ($Camera2D.position.x - screen_size.x):
				#n.queue_free()
	#else:
		#if Input.is_action_pressed("ui_accept"):
			#game_running = true
			#$HUD.get_node("StartLabel").hide()
#
## ---------------------------------------------------------
## Obstacles (hard spacing)
## ---------------------------------------------------------
#func generate_obs() -> void:
	#var cam_x: int = int($Camera2D.position.x)
	#var spawn_front: int = cam_x + screen_size.x + 100
	#if spawn_front < next_obs_spawn_x:
		#return
#
	#var start_x: int = int(max(
		#next_obs_spawn_x,
		#int(last_spawn_right) + MIN_GAP_ANY,
		#cam_x + MIN_FRONT_BUFFER
	#))
#
	#var spawn_bird_only: bool = randf() < 0.30
#
	#if spawn_bird_only and difficulty >= 1:
		#var bird = bird_scene.instantiate()
		#var bx: int = start_x
		#if last_spawn_type == "obs":
			#bx = max(bx, int(last_spawn_right) + MIN_GAP_BIRD_AFTER_OBS)
		#var by: int = bird_heights[rng.randi_range(0, bird_heights.size() - 1)]
		#add_obs(bird, bx, by)
#
		#last_spawn_right = float(bx + 48)
		#last_spawn_type  = "bird"
	#else:
		#var obs_type = obstacle_types[randi() % obstacle_types.size()]
		#var obs = obs_type.instantiate()
#
		#var spr = obs.get_node("Sprite2D")
		#var tex_w: int = spr.texture.get_width()
		#var tex_h: int = spr.texture.get_height()
		#var scx: float = spr.scale.x
		#var scy: float = spr.scale.y
		#var half_w: int = int(round(tex_w * scx * 0.5))
#
		#var obs_y: int = screen_size.y - ground_height - int(round(tex_h * scy / 2.0)) + 5
		#var obs_x: int = start_x
		#add_obs(obs, obs_x, obs_y)
#
		#last_spawn_right = float(obs_x + half_w)
		#last_spawn_type  = "obs"
#
	#next_obs_spawn_x = int(last_spawn_right) + randi_range(OBS_GAP_MIN, OBS_GAP_MAX)
#
#func add_obs(obs, x: int, y: int) -> void:
	#obs.position = Vector2i(x, y)
	#obs.body_entered.connect(hit_obs.bind(obs))  # bind obs ref
	#add_child(obs)
	#obstacles.append(obs)
#
#func remove_obs(obs) -> void:
	#if obs == null: return
	#obs.queue_free()
	#obstacles.erase(obs)
#
#func hit_obs(body, obs):
	#if body.name != "Dino":
		#return
	#if invincible:
		#var now: float = _now_sec()
		#if now - _last_hit_time < HIT_COOLDOWN:
			#return
		#_last_hit_time = now
		#add_score_points(HIT_REWARD_POINTS, obs.global_position)
		#remove_obs(obs)
	#else:
		#game_over()
#
## ---------------------------------------------------------
## Score / HUD text
## ---------------------------------------------------------
#func show_score() -> void:
	#var display_score: int = int(score / SCORE_MODIFIER)
	#$HUD.get_node("ScoreLabel").text = "SCORE: " + str(display_score)
#
#func check_high_score() -> void:
	#if score > high_score:
		#high_score = score
		#$HUD.get_node("HighScoreLabel").text = "HIGH SCORE: " + str(high_score / SCORE_MODIFIER)
#
#func adjust_difficulty() -> void:
	#difficulty = score / SPEED_MODIFIER
	#if difficulty > MAX_DIFFICULTY:
		#difficulty = MAX_DIFFICULTY
#
#func game_over() -> void:
	#check_high_score()
	#get_tree().paused = true
	#game_running = false
	#$GameOver.show()
#
## ---------------------------------------------------------
## Coins (one by one)
## ---------------------------------------------------------
#func _last_obs_x() -> float:
	#if obstacles.is_empty():
		#return -1.0e12
	#var mx: float = -1.0e12
	#for o in obstacles:
		#if float(o.position.x) > mx:
			#mx = float(o.position.x)
	#return mx
#
#func _spawn_next_coin() -> void:
	#var cam_x: float = float($Camera2D.position.x)
	#var front_buffer: float = float(screen_size.x) * 0.60
	#var safe_from_obs: float = _last_obs_x() + COIN_SAFE_FROM_OBS
	#var x: float = max(next_coin_x, cam_x + front_buffer, safe_from_obs)
#
	#var lane_idx: int = rng.randi_range(0, item_lanes_y.size() - 1)
	#var y: float = float(item_lanes_y[lane_idx])
#
	#var c = coin_scene.instantiate()
	#c.global_position = Vector2(x, y)
	#items.add_child(c)
#
	#next_coin_x = x + rng.randf_range(COIN_GAP_MIN, COIN_GAP_MAX)
#
## ---------------------------------------------------------
## Invincible: HUD + Glow + Utils
## ---------------------------------------------------------
#func _start_invincible(sec: float) -> void:
	#invincible   = true
	#inv_end_time = _now_sec() + sec
	#_set_glow(true)
	## show HUD immediately
	#_ensure_inv_hud()
	#inv_panel.show()
	#inv_bar.max_value = sec
	#inv_bar.value     = sec
	#inv_label.text    = "%0.1fs" % sec
#
#func _update_inv_ui(remaining: float) -> void:
	#_ensure_inv_hud()
	#remaining = clamp(remaining, 0.0, INVINCIBLE_DURATION)
	#if remaining > 0.0:
		#if not inv_panel.visible:
			#inv_panel.show()
		#inv_bar.max_value = INVINCIBLE_DURATION
		#inv_bar.value     = remaining
		#inv_label.text    = "%0.1fs" % remaining
	#else:
		#inv_panel.hide()
#
#func _ensure_inv_hud() -> void:
	#if inv_panel != null and inv_bar != null and inv_label != null:
		#return
	#var hud := $HUD
	#var panel := hud.get_node_or_null("InvPanel") as Control
	#if panel == null:
		#panel = Control.new()
		#panel.name = "InvPanel"
		#panel.visible = false
		#panel.position = Vector2(20, 20)
		#panel.size = Vector2(260, 26)
		#hud.add_child(panel)
#
		#var bar := ProgressBar.new()
		#bar.name = "InvBar"
		#bar.min_value = 0.0
		#bar.max_value = INVINCIBLE_DURATION
		#bar.value = 0.0
		#bar.position = Vector2(0, 3)
		#bar.size = Vector2(200, 20)
		#panel.add_child(bar)
#
		#var label := Label.new()
		#label.name = "InvLabel"
		#label.text = "0.0s"
		#label.position = Vector2(208, 3)
		#panel.add_child(label)
#
	#inv_panel = panel
	#inv_bar   = panel.get_node("InvBar") as ProgressBar
	#inv_label = panel.get_node("InvLabel") as Label
#
#func _ensure_glow_material() -> void:
	#var spr := $Dino.get_node("AnimatedSprite2D") as AnimatedSprite2D
	#if spr.material is ShaderMaterial:
		#return
	#var sh := Shader.new()
	#sh.code = """
#shader_type canvas_item;
#
#uniform bool enabled = false;
#uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.3, 1.0);
#uniform float thickness = 2.0; // px
#uniform float speed = 6.0;
#
#void fragment() {
	#vec4 tex = texture(TEXTURE, UV);
	#if (!enabled) {
		#COLOR = tex;
	#} else {
		#vec2 ts = vec2(textureSize(TEXTURE, 0));
		#float r = thickness / max(1.0, min(ts.x, ts.y));
		#float a = 0.0;
		#for (int x = -1; x <= 1; x++) {
			#for (int y = -1; y <= 1; y++) {
				#vec2 off = vec2(float(x), float(y)) * r;
				#a = max(a, texture(TEXTURE, UV + off).a);
			#}
		#}
		#if (tex.a < 0.1 && a > 0.0) {
			#float t = 0.5 + 0.5 * sin(TIME * speed);
			#COLOR = vec4(glow_color.rgb, t * glow_color.a);
		#} else {
			#COLOR = tex;
		#}
	#}
#}
#"""
	#var mat := ShaderMaterial.new()
	#mat.shader = sh
	#spr.material = mat
#
#func _set_glow(on: bool) -> void:
	#_ensure_glow_material()
	#var spr := $Dino.get_node("AnimatedSprite2D") as AnimatedSprite2D
	#var mat := spr.material as ShaderMaterial
	#mat.set_shader_parameter("enabled", on)
#
#func _now_sec() -> float:
	#return float(Time.get_ticks_msec()) / 1000.0
#
## ---------------------------------------------------------
## Points + floating text (optional)
## ---------------------------------------------------------
#func add_score_points(points: int, world_pos: Vector2 = Vector2.ZERO) -> void:
	#score += points * SCORE_MODIFIER
	#show_score()
	#if world_pos != Vector2.ZERO:
		#_spawn_floating_text(world_pos, "+" + str(points))
#
#func _world_to_screen(p: Vector2) -> Vector2:
	#return p - $Camera2D.position + Vector2(float(screen_size.x), float(screen_size.y)) * 0.5
#
#func _spawn_floating_text(world_pos: Vector2, text: String) -> void:
	#var lbl := Label.new()
	#lbl.text = text
	#lbl.add_theme_font_size_override("font_size", 24)
	#lbl.modulate.a = 1.0
	#$HUD.add_child(lbl)
	#lbl.position = _world_to_screen(world_pos)
	#var tween := create_tween()
	#tween.tween_property(lbl, "position:y", lbl.position.y - 40.0, 0.5)
	#tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	#tween.tween_callback(lbl.queue_free)
