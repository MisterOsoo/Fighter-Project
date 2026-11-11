extends State
class_name EnemyDeathState

#region References
@export_group("References")
@export var enemy: BaseEnemy
#endregion

#region Animation Settings
@export_group("Animation Settings")
@export var death_animation: StringName = &"dead"
#endregion

#region Initialization
func _ready() -> void:
	if enemy == null:
		enemy = get_parent().get_parent() as BaseEnemy
#endregion

#region State Functions
func Enter() -> void:
	if enemy == null:
		return

	# BaseEnemy waits for the final hit's knockback and landing
	# before entering this state. Do not cancel the launch here.
	enemy.is_dead = true
	enemy.isAttacking = false
	enemy.isStunned = false
	enemy.movement_direction = 0.0

	if enemy.block_component:
		enemy.block_component.clear_ai_block()
		enemy.block_component.end_block(true)

	if enemy.visuals:
		enemy.visuals.modulate = Color.WHITE

	enemy.death_animation = death_animation
	# BaseEnemy owns the animation-finished wait, blinking and queue_free.
	enemy.play_death_sequence()


func Update(_delta: float) -> void:
	pass


func PhysicsUpdate(_delta: float) -> void:
	pass


func Exit() -> void:
	pass
#endregion

#region Transition Rules
func can_transition_to(_new_state: State) -> bool:
	return false
#endregion
