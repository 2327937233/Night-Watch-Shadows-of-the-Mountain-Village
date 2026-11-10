extends Node

var sprite: AnimatedSprite3D
var surface: ShaderMaterial

func _ready() -> void:
	sprite = get_parent() as AnimatedSprite3D
	if sprite == null:
		return
	surface = ShaderMaterial.new()
	surface.shader = preload("res://shaders/character_edge_blend.gdshader")
	sprite.material_override = surface
	sprite.frame_changed.connect(_sync_frame)
	sprite.animation_changed.connect(_sync_frame)
	_sync_frame()

func _sync_frame() -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(sprite.animation):
		var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if texture != null:
			surface.set_shader_parameter("frame_texture", texture)

func _process(_delta: float) -> void:
	# Rooms retain their individual cold/warm character grading.
	surface.set_shader_parameter("character_tint", sprite.modulate)
