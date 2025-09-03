extends Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var explosion_types = {
	"small": "res://wills_pixel_explosions_sample/X_plosion/PNG/",
	"round": "res://wills_pixel_explosions_sample/round_explosion/PNG/",
	"vortex": "res://wills_pixel_explosions_sample/round_vortex/PNG/",
	"vertical": "res://wills_pixel_explosions_sample/vertical_explosion/PNG/"
}

func _ready() -> void:
	# Create AnimatedSprite2D if not exists
	if not animated_sprite:
		animated_sprite = AnimatedSprite2D.new()
		add_child(animated_sprite)

func play_explosion(type: String = "small", pos: Vector2 = Vector2.ZERO, scale_factor: float = 1.0) -> void:
	# Prevent multiple explosions
	if animated_sprite.is_playing():
		return
		
	position = pos
	scale = Vector2(scale_factor, scale_factor)
	
	# Create sprite frames for the explosion
	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("explode")
	sprite_frames.set_animation_loop("explode", false)  # Ensure no looping
	
	# Load frames based on type
	var frame_path = explosion_types.get(type, explosion_types["small"])
	
	# Load explosion frames (assuming 64 frames for X_plosion)
	var frame_count = 64 if type == "small" else 32
	for i in range(frame_count):
		var frame_file = frame_path + "frame%04d.png" % i
		if ResourceLoader.exists(frame_file):
			var texture = load(frame_file)
			sprite_frames.add_frame("explode", texture)
	
	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.play("explode")
	
	# Connect signal only if not already connected
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	queue_free()

# Static function to create explosion easily
static func create_explosion(parent: Node, type: String, pos: Vector2, scale_factor: float = 1.0) -> void:
	var explosion = preload("res://scenes/Explosion.tscn").instantiate()
	parent.add_child(explosion)
	explosion.play_explosion(type, pos, scale_factor)
