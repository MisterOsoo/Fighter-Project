
extends State
class_name IdleState


#region Input Settings

@export_group("Input")

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

	player.velocity.x = 0.0
	player.play_animation(player.idle_animation)


func Update(_delta: float) -> void:
	pass


func PhysicsUpdate(_delta: float) -> void:
	if not player.can_use_ground_states():
		return

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

	if Input.is_action_just_pressed(jump_input):
		transition_to("jump")
		return

	var direction: float = Input.get_axis(
		left_input,
		right_input
	)

	if not is_zero_approx(direction):
		transition_to("move")


func Exit() -> void:
	pass

#endregion
