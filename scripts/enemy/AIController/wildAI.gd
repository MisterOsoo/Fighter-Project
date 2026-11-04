
extends Node
class_name WildAI


#region References

@export_group("References")

@export var enemy: BaseEnemy
@export var retreat_component: LowHealthRetreat

#endregion


#region Movement Settings

@export_group("Movement")

@export var preferred_distance: float = 100.0

@export_range(0.05, 5.0, 0.05)
var decision_interval: float = 0.5

#endregion


#region Internal Variables

var decision_timer: float = 0.0

#endregion


#region Initialization

func _ready() -> void:
	if enemy == null:
		var parent: Node = get_parent()

		if parent is BaseEnemy:
			enemy = parent as BaseEnemy
		elif parent != null:
			enemy = parent.get_parent() as BaseEnemy

	if retreat_component == null and enemy != null:
		retreat_component = enemy.get_node_or_null(
			"LowHealthRetreat"
		) as LowHealthRetreat

#endregion


#region Processing

func _physics_process(delta: float) -> void:
	if enemy == null:
		return

	if enemy.is_dead:
		enemy.stop_movement()
		return

	# Defensive Mode overrides normal approach AI.
	if retreat_component != null:
		if retreat_component.should_override_movement():
			enemy.stop_movement()
			return

	if enemy.isStunned or enemy.isAttacking:
		return

	if not enemy.can_move():
		return

	decision_timer -= delta

	if decision_timer > 0.0:
		return

	decision_timer = decision_interval

	update_movement()

#endregion


#region Movement Decision

func update_movement() -> void:
	if not is_instance_valid(enemy.opponent):
		enemy.stop_movement()
		return

	var difference: float = (
		enemy.opponent.global_position.x
		- enemy.global_position.x
	)

	if absf(difference) <= preferred_distance:
		enemy.stop_movement()
		return

	enemy.set_movement_direction(
		signf(difference)
	)

#endregion
