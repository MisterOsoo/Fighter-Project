
extends State
class_name AirDashState


#region References

@onready var player: BasePlayer = (
	get_parent().get_parent() as BasePlayer
)

@onready var air_dash_component: AirDashComponent = (
	player.air_dash_component
)

#endregion


#region State Functions

func Enter() -> void:
	if air_dash_component == null:
		transition_to("jump")
		return

	air_dash_component.start_air_dash(
		air_dash_component.requested_direction
	)

	if not air_dash_component.is_air_dashing:
		transition_to("jump")
		return

	player.play_animation(
		air_dash_component.get_dash_animation()
	)


func Update(_delta: float) -> void:
	pass


func PhysicsUpdate(_delta: float) -> void:
	if air_dash_component == null:
		return

	if player.is_dead or player.isStunned:
		return

	if not air_dash_component.is_air_dashing:
		return_to_airborne_state()
		return

	# BasePlayer handles air dash movement.
	player.play_animation(
		air_dash_component.get_dash_animation()
	)


func Exit() -> void:
	if air_dash_component:
		if air_dash_component.is_air_dashing:
			air_dash_component.stop_air_dash()

#endregion


#region State Transitions

func return_to_airborne_state() -> void:
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
