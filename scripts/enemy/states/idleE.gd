
extends State
class_name EnemyIdleState


#region References

@export_group("References")

@export var enemy: BaseEnemy

#endregion


#region Animation Settings

@export_group("Animations")

@export var idle_animation: StringName = &"idle"

#endregion


#region Initialization

func _ready() -> void:
	if enemy == null:
		enemy = get_parent().get_parent() as BaseEnemy

#endregion


#region State Entry

func Enter() -> void:
	if enemy == null:
		return

	enemy.play_animation(idle_animation)

#endregion


#region State Update

func PhysicsUpdate(_delta: float) -> void:
	if enemy == null:
		return

	if enemy.is_dead or enemy.isStunned:
		return

	if not enemy.is_on_floor():
		return

	if not is_zero_approx(enemy.movement_direction):
		transition_to("move")

#endregion


#region State Exit

func Exit() -> void:
	pass

#endregion
