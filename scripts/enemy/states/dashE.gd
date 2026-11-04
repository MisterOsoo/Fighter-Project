
extends State
class_name EnemyDashState


#region Dash Types

enum DashType {
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

@export var forward_dash_animation: StringName = &"dashforward"
@export var backward_dash_animation: StringName = &"dashback"

#endregion


#region Dash Settings

@export_group("Dash Settings")

@export var forward_dash_speed: float = 350.0
@export var backward_dash_speed: float = 350.0

@export_range(0.01, 2.0, 0.01)
var dash_duration: float = 0.15

@export_range(0.0, 5.0, 0.05)
var dash_cooldown: float = 0.25

#endregion


#region Internal Variables

var next_dash_type: DashType = DashType.FORWARD

var dash_velocity: float = 0.0
var dash_time_remaining: float = 0.0
var cooldown_remaining: float = 0.0

#endregion


#region Initialization

func _ready() -> void:
	if enemy == null:
		enemy = get_parent().get_parent() as BaseEnemy

#endregion


#region Processing

func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(
			cooldown_remaining - delta,
			0.0
		)

#endregion


#region Dash Preparation

func can_dash() -> bool:
	return (
		enemy != null
		and enemy.can_move()
		and cooldown_remaining <= 0.0
	)


func prepare_dash(dash_type: DashType) -> void:
	next_dash_type = dash_type

#endregion


#region State Entry

func Enter() -> void:
	if enemy == null:
		return

	dash_time_remaining = dash_duration
	cooldown_remaining = dash_cooldown

	match next_dash_type:
		DashType.FORWARD:
			dash_velocity = (
				enemy.facing_direction * forward_dash_speed
			)
			enemy.play_animation(forward_dash_animation)

		DashType.BACKWARD:
			dash_velocity = (
				-enemy.facing_direction * backward_dash_speed
			)
			enemy.play_animation(backward_dash_animation)

	enemy.velocity.x = dash_velocity

#endregion


#region State Update

func PhysicsUpdate(delta: float) -> void:
	if enemy == null:
		return

	if enemy.is_dead or enemy.isStunned or enemy.is_launched:
		return

	enemy.velocity.x = dash_velocity

	dash_time_remaining -= delta

	if dash_time_remaining <= 0.0:
		finish_dash()

#endregion


#region Dash Finish

func finish_dash() -> void:
	if enemy == null:
		return

	enemy.velocity.x = 0.0

	if is_zero_approx(enemy.movement_direction):
		transition_to("idle")
	else:
		transition_to("move")

#endregion


#region State Exit

func Exit() -> void:
	dash_velocity = 0.0
	dash_time_remaining = 0.0
	next_dash_type = DashType.FORWARD

#endregion
