
extends State
class_name EnemySpecialAttackState


#region References

@export_group("References")
@export var enemy: BaseEnemy
@export var special_meter: specialMeterComponent

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
	if enemy == null:
		enemy = get_parent().get_parent() as BaseEnemy

	if enemy == null:
		push_error("EnemySpecialAttackState requires BaseEnemy.")
		return

	for child in enemy.get_children():
		if child is EXVisualEffects:
			ex_visual_effects = child as EXVisualEffects

		if child is specialMeterComponent:
			if special_meter == null:
				special_meter = child as specialMeterComponent

#endregion


#region Special Requests

func request_special(
	special: SpecialAttackData,
	is_ex: bool = false
) -> bool:
	if enemy == null or enemy.fsm == null:
		return false

	if special == null:
		return false

	if enemy.is_dead or enemy.isStunned:
		return false

	if enemy.isAttacking:
		return false

	if enemy.fsm.current_state == self:
		return false

	if enemy.block_component:
		if enemy.block_component.is_guard_broken:
			return false

		if enemy.block_component.blockstun_timer > 0.0:
			return false

		if enemy.block_component.is_blocking:
			return false

	if is_ex and not special.ex_enabled:
		return false

	if not special.can_use(not enemy.is_on_floor()):
		return false

	if is_ex:
		if special_meter == null:
			return false

		if special_meter.current_resource < special.ex_meter_cost:
			return false

	if enemy.anim == null:
		return false

	if enemy.anim.sprite_frames == null:
		return false

	var animation_name: StringName = special.get_animation(is_ex)

	if not enemy.anim.sprite_frames.has_animation(animation_name):
		return false

	pending_special = special
	pending_is_ex = is_ex

	enemy.fsm.transition_to("specialAttack")

	return enemy.fsm.current_state == self


#endregion


#region State Functions

func Enter() -> void:
	if enemy == null:
		return

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

	if enemy.is_dead or enemy.isStunned:
		cancel_special()
		return

	if current_is_ex and not current_special.ex_enabled:
		cancel_special()
		return

	if not current_special.can_use(not enemy.is_on_floor()):
		cancel_special()
		return

	active_animation = current_special.get_animation(current_is_ex)

	if enemy.anim == null or enemy.anim.sprite_frames == null:
		cancel_special()
		return

	if not enemy.anim.sprite_frames.has_animation(active_animation):
		push_warning(
			"Missing enemy special animation: %s" %
			active_animation
		)
		cancel_special()
		return

	if current_is_ex:
		if special_meter == null:
			cancel_special()
			return

		if not special_meter.consume_resource(
			current_special.ex_meter_cost
		):
			cancel_special()
			return

	enemy.isAttacking = true
	enemy.movement_direction = 0.0
	enemy.velocity.x = 0.0

	enemy.anim.play(active_animation)
	enemy.anim.set_frame_and_progress(0, 0.0)

	if current_is_ex and ex_visual_effects:
		ex_visual_effects.start_effects(current_special)


func Update(_delta: float) -> void:
	if current_special == null:
		return

	if enemy == null:
		return

	if enemy.is_dead or enemy.isStunned:
		return

	if enemy.anim == null:
		finish_special()
		return

	if enemy.anim.animation != active_animation:
		return

	if not enemy.anim.is_playing():
		finish_special()


func PhysicsUpdate(delta: float) -> void:
	if current_special == null:
		return

	if enemy == null:
		return

	if enemy.is_dead or enemy.isStunned:
		return

	if not movement_started:
		if enemy.anim:
			if enemy.anim.frame >= (
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
		enemy.velocity.x = 0.0


func Exit() -> void:
	if enemy:
		enemy.isAttacking = false

	reset_special()

	pending_special = null
	pending_is_ex = false

#endregion


#region Special Meter

func find_special_meter() -> specialMeterComponent:
	if enemy == null:
		return null

	for child in enemy.get_children():
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

	var facing: float = float(enemy.facing_direction)

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

			movement_velocity = direction.normalized() * speed


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
				enemy.velocity.x = 0.0

		SpecialAttackData.MovementType.FORWARD_DASH, \
		SpecialAttackData.MovementType.BACKWARD_DASH:
			enemy.velocity.x = movement_velocity.x

		SpecialAttackData.MovementType.VERTICAL_LAUNCH:
			enemy.velocity.y = movement_velocity.y
			movement_timer = 0.0

		SpecialAttackData.MovementType.DIRECTIONAL:
			enemy.velocity.x = movement_velocity.x
			enemy.velocity.y = movement_velocity.y

#endregion


#region Special Completion

func finish_special() -> void:
	if current_special == null:
		return

	enemy.isAttacking = false

	reset_special()
	return_to_movement()


func cancel_special() -> void:
	if enemy:
		enemy.isAttacking = false

	reset_special()
	return_to_movement()


func reset_special() -> void:
	if ex_visual_effects:
		ex_visual_effects.stop_effects()

	current_special = null
	current_is_ex = false

	movement_started = false
	movement_timer = 0.0
	movement_velocity = Vector2.ZERO
	active_animation = &""

#endregion


#region Movement Transitions

func return_to_movement() -> void:
	if enemy == null or enemy.fsm == null:
		return

	if enemy.is_dead or enemy.isStunned:
		return

	if not enemy.is_on_floor():
		var jump_state: EnemyJumpState = (
			enemy.fsm.states.get("jump") as EnemyJumpState
		)

		if jump_state:
			jump_state.prepare_air_dash_recovery(
				enemy.velocity.x
			)

			transition_to("jump")

		return

	if not is_zero_approx(enemy.movement_direction):
		transition_to("move")
	else:
		transition_to("idle")

#endregion
