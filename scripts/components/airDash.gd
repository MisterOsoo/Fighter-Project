
extends Node
class_name AirDashComponent

signal air_dash_started
signal air_dash_finished


#region Air Dash Settings

@export_group("Air Dash Settings")
@export var air_dash_speed: float = 400.0
@export var air_dash_duration: float = 0.18
@export var max_air_dashes: int = 1
@export var freeze_vertical_velocity: bool = true

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
@export var forward_air_dash_animation: String = "airdashforward"
@export var backward_air_dash_animation: String = "airdashback"

#endregion


#region References

@onready var player: BasePlayer = get_parent() as BasePlayer

#endregion


#region Internal Variables

var is_air_dashing: bool = false
var air_dash_direction: int = 1
var air_dashes_remaining: int = 0

var dash_timer: float = 0.0

var last_tap_direction: int = 0
var tap_timer: float = 0.0

var requested_direction: int = 1

#endregion


#region Initialization

func _ready() -> void:
	air_dashes_remaining = max_air_dashes

#endregion


#region Physics

func _physics_process(delta: float) -> void:
	if player == null:
		return

	tap_timer = maxf(tap_timer - delta, 0.0)

	if player.is_on_floor() and not is_air_dashing:
		air_dashes_remaining = max_air_dashes
		last_tap_direction = 0
		tap_timer = 0.0

	if is_air_dashing:
		dash_timer -= delta

		if dash_timer <= 0.0:
			stop_air_dash()

		return

	if not can_air_dash():
		return

	var input_direction: int = get_input_direction()

	if InputMap.has_action(dash_input):
		if Input.is_action_just_pressed(dash_input):
			var direction: int = input_direction

			if direction == 0:
				direction = get_facing_direction()

			request_air_dash(direction)
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
		request_air_dash(direction)
		last_tap_direction = 0
		tap_timer = 0.0
	else:
		last_tap_direction = direction
		tap_timer = double_tap_window


func request_air_dash(direction: int) -> void:
	if not can_air_dash():
		return

	if player.fsm == null:
		return

	requested_direction = 1 if direction >= 0 else -1
	player.fsm.transition_to("airdash")

#endregion


#region Air Dash Logic

func can_air_dash() -> bool:
	if player == null or player.is_on_floor():
		return false

	if is_air_dashing or air_dashes_remaining <= 0:
		return false

	if player.isAttacking or player.isStunned or player.is_dead:
		return false

	if player.block_component and player.block_component.is_blocking:
		return false

	if player.dash_component:
		if player.dash_component.is_dashing:
			return false

	return true


func start_air_dash(direction: int) -> void:
	if not can_air_dash():
		return

	is_air_dashing = true
	air_dash_direction = 1 if direction >= 0 else -1
	air_dashes_remaining -= 1
	dash_timer = air_dash_duration

	last_tap_direction = 0
	tap_timer = 0.0

	if player.velocity.y < 0.0:
		player.velocity.y = 0.0

	air_dash_started.emit()


func apply_air_dash_velocity() -> void:
	if player == null or not is_air_dashing:
		return

	player.velocity.x = air_dash_direction * air_dash_speed

	if freeze_vertical_velocity:
		player.velocity.y = 0.0


func stop_air_dash() -> void:
	if not is_air_dashing:
		return

	is_air_dashing = false
	dash_timer = 0.0

	if player:
		var remaining_velocity: float = (
			air_dash_direction * player.speed
		)

		player.velocity.x = remaining_velocity
		player.jump_horizontal_velocity = remaining_velocity
		player.velocity.y = 0.0

	air_dash_finished.emit()


func get_dash_animation() -> String:
	if air_dash_direction == get_facing_direction():
		return forward_air_dash_animation

	return backward_air_dash_animation

#endregion
