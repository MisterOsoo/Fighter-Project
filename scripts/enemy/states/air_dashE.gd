
extends State
class_name EnemyAirDashState


#region Air Dash Types

enum AirDashType {
	FORWARD,
	BACKWARD
}

#endregion


#region References

@export_group("References")
@export var enemy: BaseEnemy

#endregion


#region Animations

@export_group("Animations")

@export var forward_air_dash_animation: StringName = &"airdashforward"
@export var backward_air_dash_animation: StringName = &"airdashback"

#endregion


#region Air Dash Settings

@export_group("Air Dash Settings")

@export var forward_air_dash_speed: float = 400.0
@export var backward_air_dash_speed: float = 400.0

@export_range(0.01, 2.0, 0.01)
var air_dash_duration: float = 0.18

@export_range(0, 5, 1)
var max_air_dashes: int = 1

@export var freeze_vertical_velocity: bool = true

#endregion


#region Internal Variables

var next_air_dash_type: AirDashType = AirDashType.FORWARD

var air_dash_velocity: float = 0.0
var air_dash_time_remaining: float = 0.0
var air_dashes_remaining: int = 1

#endregion


#region Initialization

func _ready() -> void:
	if enemy == null:
		enemy = get_parent().get_parent() as BaseEnemy

	air_dashes_remaining = max_air_dashes

#endregion


#region Processing

func _physics_process(_delta: float) -> void:
	if enemy == null:
		return

	# Air dash charges reset when the enemy lands.
	if enemy.is_on_floor():
		air_dashes_remaining = max_air_dashes

#endregion


#region Air Dash Preparation

func can_air_dash() -> bool:
	return (
		enemy != null
		and not enemy.is_on_floor()
		and not enemy.is_dead
		and not enemy.isStunned
		and not enemy.is_launched
		and not enemy.isAttacking
		and air_dashes_remaining > 0
	)


func prepare_air_dash(
	air_dash_type: AirDashType
) -> void:
	next_air_dash_type = air_dash_type

#endregion


#region State Entry

func Enter() -> void:
	if enemy == null:
		return

	air_dashes_remaining -= 1
	air_dash_time_remaining = air_dash_duration

	match next_air_dash_type:
		AirDashType.FORWARD:
			air_dash_velocity = (
				enemy.facing_direction * forward_air_dash_speed
			)

			enemy.play_animation(
				forward_air_dash_animation
			)

		AirDashType.BACKWARD:
			air_dash_velocity = (
				-enemy.facing_direction * backward_air_dash_speed
			)

			enemy.play_animation(
				backward_air_dash_animation
			)

	enemy.velocity.x = air_dash_velocity

	if freeze_vertical_velocity:
		enemy.velocity.y = 0.0

#endregion


#region State Update

func PhysicsUpdate(delta: float) -> void:
	if enemy == null:
		return

	if enemy.is_dead or enemy.isStunned or enemy.is_launched:
		return

	# Lock horizontal direction during air dash.
	enemy.velocity.x = air_dash_velocity

	if freeze_vertical_velocity:
		enemy.velocity.y = 0.0

	air_dash_time_remaining -= delta

	if air_dash_time_remaining <= 0.0:
		finish_air_dash()

#endregion


#region Air Dash Finish

func finish_air_dash() -> void:
	if enemy == null:
		return

	var recovery_velocity: float = air_dash_velocity

	# Air dash ends with downward movement.
	enemy.velocity.y = maxf(enemy.velocity.y, 0.0)

	# Tell JumpState to recover without jumping again.
	if enemy.fsm:
		for child in enemy.fsm.get_children():
			if child is EnemyJumpState:
				var jump_state: EnemyJumpState = child

				jump_state.prepare_air_dash_recovery(
					recovery_velocity
				)

				enemy.fsm.transition_to("jump")
				return

	# Fallback if JumpState is missing.
	enemy.velocity.x = recovery_velocity

#endregion


#region State Exit

func Exit() -> void:
	air_dash_velocity = 0.0
	air_dash_time_remaining = 0.0
	next_air_dash_type = AirDashType.FORWARD

#endregion
