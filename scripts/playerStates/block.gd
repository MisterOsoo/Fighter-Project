
extends State
class_name BlockState


#region References

@onready var player: BasePlayer = (
	get_parent().get_parent() as BasePlayer
)

@onready var block_component: BlockComponent = (
	player.block_component
)

#endregion


#region State Functions

func Enter() -> void:
	if block_component == null:
		return_to_movement()
		return

	if not block_component.is_blocking:
		return_to_movement()
		return

	player.velocity.x = 0.0
	block_component.play_block_animation()


func Update(_delta: float) -> void:
	pass


func PhysicsUpdate(_delta: float) -> void:
	if block_component == null:
		return_to_movement()
		return

	if player.is_dead or player.isStunned:
		block_component.end_block(true)
		return

	# Lock movement throughout blockstun.
	player.velocity.x = 0.0
	player.jump_horizontal_velocity = 0.0

	block_component.play_block_animation()

	# Remain in BlockState until the timer expires.
	if block_component.blockstun_timer > 0.0:
		return

	# Blockstun finished.
	block_component.end_block()
	return_to_movement()


func Exit() -> void:
	if block_component:
		block_component.end_block(true)

#endregion


#region Movement Transitions

func return_to_movement() -> void:
	if player.is_dead or player.isStunned:
		return

	if not player.is_on_floor():
		transition_to("jump")
		return

	var direction: float = Input.get_axis(
		"ui_left",
		"ui_right"
	)

	if is_zero_approx(direction):
		transition_to("idle")
	else:
		transition_to("move")

#endregion
