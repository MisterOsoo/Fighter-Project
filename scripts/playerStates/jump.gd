
extends State
class_name JumpState


#region Input Settings

@export_group("Input")
@export var jump_input: StringName = &"jump"

#endregion


#region References

@onready var player: BasePlayer = (
	get_parent().get_parent() as BasePlayer
)

#endregion


#region State Functions

func Enter() -> void:
	if player.is_dead or player.isStunned:
		return

	# Only start a new jump when grounded.
	# Entering this state while airborne must not
	# reset vertical velocity.
	if player.is_on_floor():
		var direction: float = Input.get_axis(
			"ui_left",
			"ui_right"
		)

		player.start_jump(direction)


func Update(_delta: float) -> void:
	pass


func PhysicsUpdate(_delta: float) -> void:
	if player.is_dead or player.isStunned:
		return

	if player.isAttacking:
		return

	if player.block_component:
		if player.block_component.is_blocking:
			return

	if player.dash_component:
		if player.dash_component.is_dashing:
			return

	if player.air_dash_component:
		if player.air_dash_component.is_air_dashing:
			return

	# Preserve fixed horizontal momentum in the air.
	if not player.is_on_floor():
		player.velocity.x = player.jump_horizontal_velocity

		update_jump_animation()
		return

	# Landing: reset jump flags.
	player.is_jumping = false
	player.is_jump_transitioning = false
	player.jump_transition_finished = false

	# Return to a ground state.
	var direction: float = Input.get_axis(
		"ui_left",
		"ui_right"
	)

	if is_zero_approx(direction):
		transition_to("idle")
	else:
		transition_to("move")


func Exit() -> void:
	pass

#endregion


#region Animation Handling

func update_jump_animation() -> void:
	if player.anim == null:
		return

	if player.velocity.y < 0.0:
		if not player.is_jump_transitioning:
			if not player.jump_transition_finished:
				player.play_animation(
					player.jumpstart_animation
				)
		return

	if not player.is_jump_transitioning:
		if not player.jump_transition_finished:
			player.is_jump_transitioning = true
			player.play_animation(
				player.jumptransition_animation
			)
			return

	if player.is_jump_transitioning:
		return

	if player.jump_transition_finished:
		player.play_animation(
			player.fall_animation
		)

#endregion
