
extends State
class_name EnemyBlockState


#region References

@export_group("References")
@export var enemy: BaseEnemy
@export var block_component: BlockComponent

#endregion


#region Initialization

func _ready() -> void:
	if enemy == null:
		enemy = get_parent().get_parent() as BaseEnemy

	if enemy and block_component == null:
		block_component = enemy.block_component

#endregion


#region State Functions

func Enter() -> void:
	if enemy == null or block_component == null:
		return

	# Ground blocking only.
	# If another script forces this state in midair,
	# return to airborne movement without starting a block.
	if not enemy.is_on_floor():
		recover_airborne()
		return

	if enemy.is_dead or enemy.isStunned:
		return

	if block_component.is_guard_broken:
		return

	enemy.movement_direction = 0.0
	enemy.velocity.x = 0.0

	if not block_component.is_blocking:
		block_component.is_blocking = true
		block_component.is_crouch_blocking = (
			block_component.is_holding_down()
		)
		block_component.block_started.emit()

	block_component.play_block_animation()


func PhysicsUpdate(_delta: float) -> void:
	if enemy == null or block_component == null:
		return

	if enemy.is_dead or block_component.is_guard_broken:
		return

	if enemy.isStunned:
		return

	# Prevent BlockState from remaining active
	# after the enemy leaves the ground.
	if not enemy.is_on_floor():
		recover_airborne()
		return

	enemy.velocity.x = 0.0

	# Preserve existing blockstun behavior.
	if block_component.blockstun_timer > 0.0:
		block_component.play_block_animation()
		return

	# Continue blocking while AI or directional
	# input requests it.
	if block_component.is_holding_back():
		block_component.is_crouch_blocking = (
			block_component.is_holding_down()
		)

		block_component.play_block_animation()
		return

	# Blocking finished normally.
	block_component.end_block(true)

	if not is_zero_approx(enemy.movement_direction):
		transition_to("move")
	else:
		transition_to("idle")


func Exit() -> void:
	if block_component == null:
		return

	# Preserve guard-break and blockstun handling.
	if block_component.is_guard_broken:
		return

	if block_component.blockstun_timer <= 0.0:
		block_component.end_block(true)

#endregion


#region Airborne Recovery

func recover_airborne() -> void:
	if enemy == null or enemy.fsm == null:
		return

	if block_component != null:
		# End ordinary blocking without cancelling
		# an existing blockstun timer.
		if block_component.blockstun_timer <= 0.0:
			block_component.end_block(true)

	var jump_state: EnemyJumpState = (
		enemy.fsm.states.get("jump") as EnemyJumpState
	)

	if jump_state == null:
		return

	# Recover into falling, not a new jump.
	# Preserve horizontal momentum.
	jump_state.prepare_air_dash_recovery(
		enemy.velocity.x
	)

	transition_to("jump")

#endregion
