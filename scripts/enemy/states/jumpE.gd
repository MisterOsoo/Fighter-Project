
extends State
class_name EnemyJumpState


#region Jump Types

enum JumpType {
	NEUTRAL,
	FORWARD,
	BACKWARD
}

#endregion


#region References

@export_group("References")
@export var enemy: BaseEnemy

#endregion


#region Animation Settings

@export_group("Animations")
@export var jumpstart_animation: StringName = &"jumpstart"
@export var jumptransition_animation: StringName = &"jumptransition"
@export var fall_animation: StringName = &"fall"

#endregion


#region Movement Settings

@export_group("Movement")
@export var forward_jump_speed: float = 100.0
@export var backward_jump_speed: float = 100.0

#endregion


#region Debug Settings

@export_group("Debug")
@export var debug_jump: bool = false

#endregion


#region Internal Variables

var next_jump_type: JumpType = JumpType.NEUTRAL
var jump_horizontal_velocity: float = 0.0
var jump_started: bool = false
var jump_transition_finished: bool = false
var has_left_ground: bool = false
var recovering_from_air_dash: bool = false
var recovery_velocity: float = 0.0

#endregion


#region Initialization

func _ready() -> void:
	if enemy == null:
		enemy = get_parent().get_parent() as BaseEnemy

#endregion


#region Jump Preparation

func prepare_jump(jump_type: JumpType) -> void:
	next_jump_type = jump_type
	recovering_from_air_dash = false


func prepare_air_dash_recovery(horizontal_velocity: float) -> void:
	recovering_from_air_dash = true
	recovery_velocity = horizontal_velocity

#endregion


#region State Entry

func Enter() -> void:
	if enemy == null:
		return

	# Air dash recovery is allowed while airborne.
	# It does not apply another jump impulse.
	if recovering_from_air_dash:
		jump_started = true
		jump_transition_finished = true
		has_left_ground = true

		jump_horizontal_velocity = recovery_velocity

		enemy.velocity.x = jump_horizontal_velocity
		enemy.velocity.y = maxf(enemy.velocity.y, 0.0)

		enemy.play_animation(fall_animation)

		recovering_from_air_dash = false
		return

	# Prevent a second jump while airborne.
	if not enemy.is_on_floor():
		if debug_jump:
			print(
				"EnemyJumpState: Jump rejected. Enemy is airborne."
			)

		jump_started = false
		next_jump_type = JumpType.NEUTRAL
		return

	# Prevent restarting an active jump.
	if jump_started:
		if debug_jump:
			print(
				"EnemyJumpState: Jump rejected. Already jumping."
			)
		return

	jump_started = true
	jump_transition_finished = false
	has_left_ground = false

	match next_jump_type:
		JumpType.NEUTRAL:
			jump_horizontal_velocity = 0.0

		JumpType.FORWARD:
			jump_horizontal_velocity = (
				enemy.facing_direction * forward_jump_speed
			)

		JumpType.BACKWARD:
			jump_horizontal_velocity = (
				-enemy.facing_direction * backward_jump_speed
			)

	enemy.velocity.x = jump_horizontal_velocity
	enemy.velocity.y = enemy.jump_velocity

	enemy.play_animation(jumpstart_animation)

	if debug_jump:
		print(
			"EnemyJumpState: Jump started. Type: ",
			JumpType.keys()[next_jump_type]
		)

#endregion


#region State Update

func PhysicsUpdate(_delta: float) -> void:
	if enemy == null:
		return

	if enemy.is_dead or enemy.isStunned or enemy.is_launched:
		return

	if not jump_started:
		return

	enemy.velocity.x = jump_horizontal_velocity

	if not enemy.is_on_floor():
		has_left_ground = true

	if (
		has_left_ground
		and enemy.is_on_floor()
		and enemy.velocity.y >= 0.0
	):
		finish_jump()
		return

	update_jump_animation()

#endregion


#region Animation Handling

func update_jump_animation() -> void:
	if enemy.anim == null:
		return

	var sprite: AnimatedSprite2D = enemy.anim

	if sprite.animation == jumpstart_animation:
		if sprite.is_playing():
			return

		enemy.play_animation(jumptransition_animation)
		return

	if sprite.animation == jumptransition_animation:
		if sprite.is_playing():
			return

		jump_transition_finished = true

	if jump_transition_finished:
		enemy.play_animation(fall_animation)

#endregion


#region Jump Completion

func finish_jump() -> void:
	if enemy == null:
		return

	enemy.velocity.x = 0.0

	jump_started = false
	has_left_ground = false

	if is_zero_approx(enemy.movement_direction):
		transition_to("idle")
	else:
		transition_to("move")

#endregion


#region State Exit

func Exit() -> void:
	jump_started = false
	jump_transition_finished = false
	has_left_ground = false

	jump_horizontal_velocity = 0.0
	recovery_velocity = 0.0
	recovering_from_air_dash = false

	next_jump_type = JumpType.NEUTRAL

#endregion
