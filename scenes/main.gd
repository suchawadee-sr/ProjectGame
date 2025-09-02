extends Node

# ---------- LEVEL MODE ----------
@export var level_mode: bool = true                 # ปิด = เล่นแบบ endless เดิม
@export var level_goal_score: int = 1000            # เป้าคะแนนบน HUD (หน่วยเดียวกับที่แสดง)
@export var next_level: PackedScene                  # ฉากถัดไป (ว่างได้)
@export var level_index: int = 1                    # เลขด่านของฉากนี้ (1,2,3,...)

# ---------- OBSTACLE PRELOADS ----------
var stump_scene  = preload("res://scenes/stump.tscn")
var rock_scene   = preload("res://scenes/rock.tscn")
var barrel_scene = preload("res://scenes/barrel.tscn")
var bird_scene   = preload("res://scenes/bird.tscn")

var obstacle_types := [stump_scene, rock_scene, barrel_scene]
var obstacles: Array = []             # ต้องมีค่าเริ่มต้น
var bird_heights := [200, 390]

# ---------- GAME CONSTS / VARS ----------
const DINO_START_POS := Vector2i(150, 485)
const CAM_START_POS  := Vector2i(576, 324)

var difficulty
const MAX_DIFFICULTY : int = 2

var score : int = 0
const SCORE_MODIFIER : int = 10        # HUD แสดง score / SCORE_MODIFIER
var high_score : int = 0

var speed : float = 0.0
const START_SPEED : float = 10.0
const MAX_SPEED   : int   = 25
const SPEED_MODIFIER : int = 5000

var screen_size : Vector2i
var ground_height : int
var game_running : bool = false
var last_obs

# ---------- READY ----------
func _ready():
	screen_size = get_window().size
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	$GameOver.get_node("Button").pressed.connect(new_game)
	new_game()

# ---------- RESET ----------
func new_game():
	# reset variables
	score = 0
	show_score()
	game_running = false
	get_tree().paused = false
	difficulty = 0

	# delete all obstacles
	for obs in obstacles:
		obs.queue_free()
	obstacles.clear()

	# reset nodes
	$Dino.position   = DINO_START_POS
	$Dino.velocity   = Vector2i(0, 0)
	$Camera2D.position = CAM_START_POS
	$Ground.position = Vector2i(0, 0)

	# reset UI
	$HUD.get_node("StartLabel").show()
	$GameOver.hide()

# ---------- LOOP ----------
func _process(delta):
	if game_running:
		# speed up & difficulty
		speed = START_SPEED + score / SPEED_MODIFIER
		if speed > MAX_SPEED:
			speed = MAX_SPEED
		adjust_difficulty()

		# spawn obstacles
		generate_obs()

		# move dino and camera
		$Dino.position.x     += speed
		$Camera2D.position.x += speed

		# score (ภายในยังเป็นหน่วยย่อย / HUD แสดงหาร SCORE_MODIFIER)
		score += speed
		show_score()

		# ---- ผ่านด่าน ----
		if level_mode and (score / SCORE_MODIFIER) >= level_goal_score:
			level_complete()
			return

		# move ground (loop)
		if $Camera2D.position.x - $Ground.position.x > screen_size.x * 1.5:
			$Ground.position.x += screen_size.x

		# cleanup
		for obs in obstacles:
			if obs.position.x < ($Camera2D.position.x - screen_size.x):
				remove_obs(obs)
	else:
		if Input.is_action_pressed("ui_accept"):
			game_running = true
			$HUD.get_node("StartLabel").hide()

# ---------- OBSTACLES ----------
func generate_obs():
	# ground obstacles
	if obstacles.is_empty() or last_obs.position.x < score + randi_range(300, 500):
		var obs_type = obstacle_types[randi() % obstacle_types.size()]
		var obs
		var max_obs = difficulty + 1
		for i in range(randi() % max_obs + 1):
			obs = obs_type.instantiate()
			var obs_height = obs.get_node("Sprite2D").texture.get_height()
			var obs_scale  = obs.get_node("Sprite2D").scale
			var obs_x : int = screen_size.x + score + 100 + (i * 100)
			var obs_y : int = screen_size.y - ground_height - int(obs_height * obs_scale.y / 2.0) + 5
			last_obs = obs
			add_obs(obs, obs_x, obs_y)

		# bird obstacles (ยากสุด)
		if difficulty == MAX_DIFFICULTY and (randi() % 2) == 0:
			obs = bird_scene.instantiate()
			var obs_x2 : int = screen_size.x + score + 100
			var obs_y2 : int = bird_heights[randi() % bird_heights.size()]
			add_obs(obs, obs_x2, obs_y2)

func add_obs(obs, x, y):
	obs.position = Vector2i(x, y)
	obs.body_entered.connect(hit_obs)   # root obstacle ควรเป็น Area2D
	add_child(obs)
	obstacles.append(obs)

func remove_obs(obs):
	obs.queue_free()
	obstacles.erase(obs)

# ---------- COLLISION / SCORE / DIFFICULTY ----------
func hit_obs(body):
	if body.name == "Dino":
		game_over()

func show_score():
	$HUD.get_node("ScoreLabel").text = "SCORE: " + str(score / SCORE_MODIFIER)

func check_high_score():
	if score > high_score:
		high_score = score
		$HUD.get_node("HighScoreLabel").text = "HIGH SCORE: " + str(high_score / SCORE_MODIFIER)

func adjust_difficulty():
	difficulty = score / SPEED_MODIFIER
	if difficulty > MAX_DIFFICULTY:
		difficulty = MAX_DIFFICULTY

# ---------- GAME OVER / LEVEL COMPLETE ----------
func game_over():
	check_high_score()
	get_tree().paused = true
	game_running = false
	$GameOver.show()

func level_complete():
	check_high_score()

	# อัปเดตสถิติและปลดล็อกด่าน
	var hud_score := score / SCORE_MODIFIER
	GameState.high_score = max(GameState.high_score, hud_score)
	GameState.unlock_next(level_index)

	game_running = false
	get_tree().paused = true
	if $GameOver.has_method("show_victory"):
		$GameOver.show_victory(score)

	await get_tree().process_frame
	get_tree().paused = false

	if next_level:
		get_tree().change_scene_to_packed(next_level)
	else:
		# ไม่มีฉากถัดไป → กลับเมนูหลัก
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
