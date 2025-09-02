extends Node

const SAVE_PATH := "user://save.cfg"

var high_score: int = 0
var unlocked_levels: int = 1  # เริ่มปลดล็อกจากด่าน 1

func _ready() -> void:
	load()  # โหลดทันทีเมื่อเกมเริ่ม (หลังเพิ่มเป็น Autoload)

func save():
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "high_score", high_score)
	cfg.set_value("progress", "unlocked_levels", unlocked_levels)
	cfg.save(SAVE_PATH)

func load():
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err == OK:
		high_score = int(cfg.get_value("progress", "high_score", 0))
		unlocked_levels = int(cfg.get_value("progress", "unlocked_levels", 1))

func unlock_next(current_index: int):
	# current_index คือเลขด่านปัจจุบัน (1,2,3,…)
	if unlocked_levels < current_index + 1:
		unlocked_levels = current_index + 1
		save()
