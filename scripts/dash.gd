
extends Node
class_name DashComponent

signal dash_started
signal dash_finished


#region Dash Settings

@export_group("Dash Settings")
@export var dash_speed: float = 350.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.25

#endregion


#region Input Settings

@export_group("Input Settings")
@export var dash_input: StringName = &"dash"
@export var left_input: StringName = &"ui_left"
@export var right_input: StringName = &"ui_right"
@export var double_tap_window: float = 0.25

#endregion


#region Animation Settings

@export_group("Animation")
@export var forward_dash_animation: String = "dashforward"
@export var backward_dash_animation: String = "dashback"

#endregion


#region References

@onready var player: BasePlayer = get_parent() as BasePlayer

#endregion


#region Internal Variables

var is_dashing: bool = false
var dash_direction: int = 1

var dash_timer: float = 0.0
var cooldown_timer: float = 0.0

var last_tap_direction: int = 0
var tap_timer: float = 0.0

var requested_direction: int = 1

#endregion


#region Physics

func _physics_process(delta: float) -> void:
	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	tap_timer = maxf(tap_timer - delta, 0.0)

	if is_dashing:
		dash_timer -= delta

		if dash_timer <= 0.0:
			stop_dash()

		return

	if not can_dash():
		return

	var input_direction: int = get_input_direction()

	if InputMap.has_action(dash_input):
		if Input.is_action_just_pressed(dash_input):
			var direction: int = input_direction

			if direction == 0:
				direction = get_facing_direction()

			request_dash(direction)
			return

	check_double_tap()

#endregion


#region Input Handling

func get_input_direction() -> int:
	var axis: float = Input.get_axis(left_input, right_input)

	if axis > 0.0:
		return 1

	if axis < 0.0:
		return -1

	return 0


func get_facing_direction() -> int:
	if player:
		return 1 if player.facing_direction >= 0 else -1

	return 1


func check_double_tap() -> void:
	var direction: int = 0

	if Input.is_action_just_pressed(right_input):
		direction = 1

	elif Input.is_action_just_pressed(left_input):
		direction = -1

	if direction == 0:
		return

	if direction == last_tap_direction and tap_timer > 0.0:
		request_dash(direction)
		last_tap_direction = 0
		tap_timer = 0.0
	else:
		last_tap_direction = direction
		tap_timer = double_tap_window


func request_dash(direction: int) -> void:
	if not can_dash():
		return

	if player.fsm == null:
		return

	requested_direction = 1 if direction >= 0 else -1
	player.fsm.transition_to("dash")

#endregion


#region Dash Logic

func can_dash() -> bool:
	if player == null or not player.is_on_floor():
		return false

	if is_dashing or cooldown_timer > 0.0:
		return false

	if player.isAttacking or player.isStunned or player.is_dead:
		return false

	if player.block_component and player.block_component.is_blocking:
		return false

	if player.air_dash_component:
		if player.air_dash_component.is_air_dashing:
			return false

	return true


func start_dash(direction: int) -> void:
	if not can_dash():
		return

	is_dashing = true
	dash_direction = 1 if direction >= 0 else -1

	dash_timer = dash_duration
	cooldown_timer = dash_cooldown

	last_tap_direction = 0
	tap_timer = 0.0

	dash_started.emit()


func apply_dash_velocity() -> void:
	if player == null or not is_dashing:
		return

	player.velocity.x = dash_direction * dash_speed


func stop_dash() -> void:
	if not is_dashing:
		return

	is_dashing = false
	dash_timer = 0.0

	if player:
		player.velocity.x = 0.0

	dash_finished.emit()


func get_dash_animation() -> String:
	if dash_direction == get_facing_direction():
		return forward_dash_animation

	return backward_dash_animation

#endregion
