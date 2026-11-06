
extends State
class_name SpecialAttackState


#region References

@onready var player: BasePlayer = (
	get_parent().get_parent() as BasePlayer
)

var ex_visual_effects: EXVisualEffects

#endregion


#region Special State

var pending_special: SpecialAttackData
var current_special: SpecialAttackData

var pending_is_ex: bool = false
var current_is_ex: bool = false

var active_animation: StringName = &""

#endregion


#region Movement State

var movement_started: bool = false
var movement_timer: float = 0.0
var movement_velocity: Vector2 = Vector2.ZERO

#endregion


#region Initialization

func _ready() -> void:
	if player:
		for child in player.get_children():
			if child is EXVisualEffects:
				ex_visual_effects = child as EXVisualEffects
				break

#endregion


#region Special Selection

func prepare_special(
	special: SpecialAttackData,
	is_ex: bool = false
) -> void:
	pending_special = special
	pending_is_ex = is_ex

#endregion


#region State Functions

func Enter() -> void:
	if pending_special == null:
		return_to_movement()
		return

	current_special = pending_special
	current_is_ex = pending_is_ex

	pending_special = null
	pending_is_ex = false

	movement_started = false
	movement_timer = 0.0
	movement_velocity = Vector2.ZERO

	if current_is_ex and not current_special.ex_enabled:
		cancel_special()
		return

	if not current_special.can_use(
		not player.is_on_floor()
	):
		cancel_special()
		return

	active_animation = current_special.get_animation(
		current_is_ex
	)

	if player.anim == null:
		cancel_special()
		return

	if player.anim.sprite_frames == null:
		cancel_special()
		return

	if not player.anim.sprite_frames.has_animation(
		active_animation
	):
		push_warning(
			"Missing special animation: %s" %
			active_animation
		)
		cancel_special()
		return

	if current_is_ex:
		var meter: specialMeterComponent = find_special_meter()

		if meter == null:
			cancel_special()
			return

		if not meter.consume_resource(
			current_special.ex_meter_cost
		):
			cancel_special()
			return

	player.isAttacking = true
	player.velocity.x = 0.0

	player.anim.play(active_animation)
	player.anim.set_frame_and_progress(0, 0.0)

	# Activate visual effects for EX specials only.
	if current_is_ex and ex_visual_effects:
		ex_visual_effects.start_effects(current_special)


func Update(_delta: float) -> void:
	if current_special == null:
		return

	if player.is_dead or player.isStunned:
		return

	if player.anim == null:
		finish_special()
		return

	if player.anim.animation != active_animation:
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
				current_special.get_movement_start_frame(
					current_is_ex
				)
			):
				start_special_movement()

	if movement_started and movement_timer > 0.0:
		apply_special_movement()

		movement_timer = maxf(
			movement_timer - delta,
			0.0
		)

	elif current_special.get_lock_horizontal_movement(
		current_is_ex
	):
		player.velocity.x = 0.0

#endregion


#region Special Meter

func find_special_meter() -> specialMeterComponent:
	if player == null:
		return null

	for child in player.get_children():
		if child is specialMeterComponent:
			return child as specialMeterComponent

	return null

#endregion


#region Movement Handling

func start_special_movement() -> void:
	if current_special == null:
		return

	movement_started = true

	movement_timer = current_special.get_movement_duration(
		current_is_ex
	)

	var speed: float = current_special.get_movement_speed(
		current_is_ex
	)

	var facing: float = float(player.facing_direction)

	var movement_type: SpecialAttackData.MovementType = (
		current_special.get_movement_type(current_is_ex)
	)

	match movement_type:
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
				current_special.get_movement_direction(
					current_is_ex
				)
			)

			direction.x *= facing

			movement_velocity = (
				direction.normalized() * speed
			)


func apply_special_movement() -> void:
	if current_special == null:
		return

	var movement_type: SpecialAttackData.MovementType = (
		current_special.get_movement_type(current_is_ex)
	)

	match movement_type:
		SpecialAttackData.MovementType.NONE:
			if current_special.get_lock_horizontal_movement(
				current_is_ex
			):
				player.velocity.x = 0.0

		SpecialAttackData.MovementType.FORWARD_DASH, \
		SpecialAttackData.MovementType.BACKWARD_DASH:
			player.velocity.x = movement_velocity.x

		SpecialAttackData.MovementType.VERTICAL_LAUNCH:
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
	reset_special()
	return_to_movement()


func cancel_special() -> void:
	player.isAttacking = false
	reset_special()
	return_to_movement()


func reset_special() -> void:
	# Stop EX visual effects.
	if ex_visual_effects:
		ex_visual_effects.stop_effects()

	current_special = null
	current_is_ex = false

	movement_started = false
	movement_timer = 0.0
	movement_velocity = Vector2.ZERO
	active_animation = &""


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

	reset_special()

	pending_special = null
	pending_is_ex = false

#endregion
