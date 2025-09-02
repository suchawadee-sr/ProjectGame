extends Area2D

@export var fly_speed: float = 120.0    # ความเร็วบินไปทางซ้าย (px/sec)
@export var bob_amplitude: float = 16.0 # ระยะส่ายขึ้นลง (px)
@export var bob_period: float = 1.0     # รอบการส่าย (วินาที)

var _y0: float
var _t: float = 0.0

func _ready():
	_y0 = position.y
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play()

func _process(delta):
	_t += delta
	# บินซ้ายด้วยความเร็วคงที่ (เพิ่มจากเอฟเฟกต์กล้อง)
	position.x -= fly_speed * delta
	# โบกขึ้นลงเล็กน้อย
	position.y = _y0 + sin(_t * TAU / bob_period) * bob_amplitude
