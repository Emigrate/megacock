extends Node3D

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

func _ready() -> void:
	sprite.play("default")
	sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	queue_free()
