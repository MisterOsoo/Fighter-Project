
extends State
class_name SpecialAttackState


#region References

@onready var player: BasePlayer = (
	get_parent().get_parent() as BasePlayer
)

#endregion


#region Special State

var pending_special: SpecialAttackData
var current_special: SpecialAttackData

#endregion


#region Movement State

var movement_started: bool = false
var movement_timer: float = 0.0
var movement_velocity: Vector2 = Vector2.ZERO

#endregion


#region Special Selection

func prepare_special(special: SpecialAttackData) -> void:
	pending_special = special

#endregion


#region State Functions

func Enter() -> void:
	if pending_special == null:
		return_to_movement()
		return

	current_special = pending_special
	pending_special = null

	movement_started = false
	movement_timer = 0.0
	movement_velocity = Vector2.ZERO

	player.isAttacking = true
	player.velocity.x = 0.0

	if player.anim == null:
		finish_special()
		return

	if player.anim.sprite_frames == null:
		finish_special()
		return

	if not player.anim.sprite_frames.has_animation(
		current_special.animation_name
	):
		push_warning(
			"Missing special animation: %s" %
			current_special.animation_name
		)
		finish_special()
		return

	player.anim.play(current_special.animation_name)
	player.anim.set_frame_and_progress(0, 0.0)


func Update(_delta: float) -> void:
	if current_special == null:
		return

	if player.is_dead or player.isStunned:
		return

	if player.anim == null:
		finish_special()
		return

	if player.anim.animation != current_special.animation_name:
		return

	if not player.anim.is_playing():
		finish_special()


func PhysicsUpdate(delta: float) -> void:
	if current_special == null:
		return

	if player.is_dead or player.isStunned:
		return

	if not movement_started:
		if player.anim:
			if player.anim.frame >= (
				current_special.movement_start_frame
			):
				start_special_movement()

	if movement_started and movement_timer > 0.0:
		apply_special_movement()

		movement_timer = maxf(
			movement_timer - delta,
			0.0
		)

	elif current_special.lock_horizontal_movement:
		player.velocity.x = 0.0

#endregion


#region Movement Handling

func start_special_movement() -> void:
	if current_special == null:
		return

	movement_started = true
	movement_timer = current_special.movement_duration

	var speed: float = current_special.movement_speed
	var facing: float = float(player.facing_direction)

	match current_special.movement_type:
		SpecialAttackData.MovementType.NONE:
			movement_velocity = Vector2.ZERO

		SpecialAttackData.MovementType.FORWARD_DASH:
			movement_velocity = Vector2(
				speed * facing,
				0.0
			)

		SpecialAttackData.MovementType.BACKWARD_DASH:
			movement_velocity = Vector2(
				-speed * facing,
				0.0
			)

		SpecialAttackData.MovementType.VERTICAL_LAUNCH:
			movement_velocity = Vector2(
				0.0,
				-speed
			)

		SpecialAttackData.MovementType.DIRECTIONAL:
			var direction: Vector2 = (
				current_special.movement_direction
			)

			direction.x *= facing

			movement_velocity = (
				direction.normalized() * speed
			)


func apply_special_movement() -> void:
	if current_special == null:
		return

	match current_special.movement_type:
		SpecialAttackData.MovementType.NONE:
			if current_special.lock_horizontal_movement:
				player.velocity.x = 0.0

		SpecialAttackData.MovementType.FORWARD_DASH, \
		SpecialAttackData.MovementType.BACKWARD_DASH:
			player.velocity.x = movement_velocity.x

		SpecialAttackData.MovementType.VERTICAL_LAUNCH:
			# Apply the upward impulse once.
			player.velocity.y = movement_velocity.y
			movement_timer = 0.0

		SpecialAttackData.MovementType.DIRECTIONAL:
			player.velocity.x = movement_velocity.x
			player.velocity.y = movement_velocity.y

#endregion


#region Special Completion

func finish_special() -> void:
	if current_special == null:
		return

	player.isAttacking = false
	current_special = null

	movement_started = false
	movement_timer = 0.0
	movement_velocity = Vector2.ZERO

	return_to_movement()


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


func Exit() -> void:
	player.isAttacking = false

	current_special = null
	pending_special = null

	movement_started = false
	movement_timer = 0.0
	movement_velocity = Vector2.ZERO

#endregion
