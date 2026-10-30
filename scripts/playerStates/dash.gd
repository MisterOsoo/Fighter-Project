
extends State
class_name DashState


#region References

@onready var player: BasePlayer = (
	get_parent().get_parent() as BasePlayer
)

@onready var dash_component: DashComponent = (
	player.dash_component
)

#endregion


#region State Functions

func Enter() -> void:
	if dash_component == null:
		return_to_movement()
		return

	dash_component.start_dash(
		dash_component.requested_direction
	)

	if not dash_component.is_dashing:
		return_to_movement()
		return

	player.play_animation(
		dash_component.get_dash_animation()
	)


func Update(_delta: float) -> void:
	pass


func PhysicsUpdate(_delta: float) -> void:
	if dash_component == null:
		return

	if player.is_dead or player.isStunned:
		return

	if not dash_component.is_dashing:
		return_to_movement()
		return

	# BasePlayer handles the actual velocity
	# and movement during the dash.
	player.play_animation(
		dash_component.get_dash_animation()
	)


func Exit() -> void:
	if dash_component and dash_component.is_dashing:
		dash_component.stop_dash()

#endregion


#region State Transitions

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
