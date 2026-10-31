
extends State
class_name JumpState


#region Input Settings

@export_group("Input")

@export var jump_input: StringName = &"jump"
@export var light_input: StringName = &"lightAtk"
@export var heavy_input: StringName = &"heavyAtk"

#endregion


#region References

@export_group("References")

@export var attack_state: AttackState

@onready var player: BasePlayer = (
	get_parent().get_parent() as BasePlayer
)

#endregion


#region State Functions

func Enter() -> void:
	if player.is_dead or player.isStunned:
		return

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

	# Check aerial attacks.
	if not player.is_on_floor():
		if try_air_attack():
			return

		player.velocity.x = player.jump_horizontal_velocity
		update_jump_animation()
		return

	# Landing.
	player.is_jumping = false
	player.is_jump_transitioning = false
	player.jump_transition_finished = false

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


#region Air Attack Handling

func try_air_attack() -> bool:
	if attack_state == null:
		print("JumpState: AttackState reference is missing.")
		return false

	if InputMap.has_action(light_input):
		if Input.is_action_just_pressed(light_input):
			print("JumpState: Air light input detected.")

			if attack_state.air_light_attack == null:
				print("JumpState: Air Light Attack resource is missing.")
				return false

			attack_state.request_attack(&"light")
			transition_to("attack")

			print("JumpState: Requested transition to AttackState.")
			return true

	if InputMap.has_action(heavy_input):
		if Input.is_action_just_pressed(heavy_input):
			print("JumpState: Air heavy input detected.")

			if attack_state.air_heavy_attack == null:
				print("JumpState: Air Heavy Attack resource is missing.")
				return false

			attack_state.request_attack(&"heavy")
			transition_to("attack")

			print("JumpState: Requested transition to AttackState.")
			return true

	return false

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
