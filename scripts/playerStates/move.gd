
extends State
class_name MoveState


#region Movement Settings

@export_group("Movement")

@export var acceleration: float = 1200.0

@export var left_input: StringName = &"ui_left"
@export var right_input: StringName = &"ui_right"
@export var jump_input: StringName = &"jump"

#endregion


#region References

@onready var player: BasePlayer = (
	get_parent().get_parent() as BasePlayer
)

@onready var attack_state: AttackState = (
	get_parent().get_node_or_null("attack") as AttackState
)

#endregion


#region State Functions

func Enter() -> void:
	if not player.can_use_ground_states():
		return

	player.play_animation(player.walk_animation)


func Update(_delta: float) -> void:
	pass


func PhysicsUpdate(delta: float) -> void:
	if not player.can_use_ground_states():
		return

	# Crouching immediately stops movement.
	if Input.is_action_pressed(player.crouch_input):
		player.velocity.x = 0.0
		player.jump_horizontal_velocity = 0.0

		transition_to("crouch")
		return

	# Normal attacks.
	if attack_state:
		if Input.is_action_just_pressed(
			attack_state.light_input
		):
			attack_state.request_attack(&"light")
			transition_to("attack")
			return

		if Input.is_action_just_pressed(
			attack_state.heavy_input
		):
			attack_state.request_attack(&"heavy")
			transition_to("attack")
			return

	# Jump.
	if Input.is_action_just_pressed(jump_input):
		transition_to("jump")
		return

	# Horizontal movement.
	var direction: float = Input.get_axis(
		left_input,
		right_input
	)

	if is_zero_approx(direction):
		transition_to("idle")
		return

	player.velocity.x = move_toward(
		player.velocity.x,
		direction * player.speed,
		acceleration * delta
	)


func Exit() -> void:
	pass

#endregion
