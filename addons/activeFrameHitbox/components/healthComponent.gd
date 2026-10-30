@icon ("res://addons/activeFrameHitbox/icons/health.svg")
extends Node
class_name HealthComponent

signal health_changed(current_health: int)
signal defeated

@export var max_health: int = 100

var current_health: int


func _ready() -> void:
	current_health = max_health


func take_damage(amount: int) -> void:
	current_health = max(current_health - amount, 0)

	health_changed.emit(current_health)

	print("Damage taken: ", amount)
	print("Health remaining: ", current_health)

	if current_health == 0:
		defeated.emit()
