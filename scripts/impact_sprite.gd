
extends AnimatedSprite2D

@export var impact_animation: StringName = &"impact"

func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	play(impact_animation)


func _on_animation_finished() -> void:
	queue_free()
