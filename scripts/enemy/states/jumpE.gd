
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


#region Animations

@export_group("Animations")

@export var jumpstart_animation: StringName = &"jumpstart"
@export var jumptransition_animation: StringName = &"jumptransition"
@export var fall_animation: StringName = &"fall"

#endregion


#region Jump Settings

@export_group("Jump Settings")

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


func prepare_air_dash_recovery(
	horizontal_velocity: float
) -> void:
	recovering_from_air_dash = true
	recovery_velocity = horizontal_velocity

#endregion


#region State Entry

func Enter() -> void:
	if enemy == null:
		return

	jump_started = true
	jump_transition_finished = false
	has_left_ground = false

	# Air dash recovery does not restart the jump.
	if recovering_from_air_dash:
		jump_horizontal_velocity = recovery_velocity

		enemy.velocity.x = jump_horizontal_velocity
		enemy.velocity.y = maxf(enemy.velocity.y, 0.0)

		has_left_ground = true
		jump_transition_finished = true

		enemy.play_animation(fall_animation)

		recovering_from_air_dash = false
		return

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

	if debug_jump:
		print("------------------------")
		print("Enemy: ", enemy.name)
		print("Jump type: ", JumpType.keys()[next_jump_type])
		print("BaseEnemy jump velocity: ", enemy.jump_velocity)
		print("Applied vertical velocity: ", enemy.velocity.y)
		print("Gravity: ", enemy.get_gravity())
		print("------------------------")

	enemy.play_animation(jumpstart_animation)

#endregion


#region State Update

func PhysicsUpdate(_delta: float) -> void:
	if enemy == null:
		return

	if enemy.is_dead or enemy.isStunned or enemy.is_launched:
		return

	if not jump_started:
		return

	# Preserve locked horizontal momentum.
	enemy.velocity.x = jump_horizontal_velocity

	# The enemy must leave the ground before
	# the jump can be considered complete.
	if not enemy.is_on_floor():
		has_left_ground = true

	if has_left_ground:
		if enemy.is_on_floor() and enemy.velocity.y >= 0.0:
			finish_jump()
			return

	if debug_jump:
		print(
			"Jump Y velocity: ",
			enemy.velocity.y,
			" | On floor: ",
			enemy.is_on_floor()
		)

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


#region Landing

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
