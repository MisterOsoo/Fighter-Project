
extends State
class_name MoveState


#region Movement Settings

@export_group("Movement")

@export var acceleration: float = 1200.0

@export var left_input: StringName = &"ui_left"
@export var right_input: StringName = &"ui_right"
@export var jump_input: StringName = &"jump"

#endregion


#region Animation Settings

@export_group("Animations")

@export var walk_forward_animation: String = "walkForward"
@export var walk_backward_animation: String = "walkBackward"

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

	update_walk_animation()


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

	# Update animation based on movement direction.
	update_walk_animation()


func Exit() -> void:
	pass

#endregion


#region Walk Animation Handling

func update_walk_animation() -> void:
	if player == null:
		return

	var direction: float = Input.get_axis(
		left_input,
		right_input
	)

	if is_zero_approx(direction):
		return

	# Positive means moving toward the opponent.
	# Negative means moving away from the opponent.
	var relative_direction: float = (
		direction * player.facing_direction
	)

	if relative_direction > 0.0:
		player.play_animation(walk_forward_animation)
	else:
		player.play_animation(walk_backward_animation)

#endregion
