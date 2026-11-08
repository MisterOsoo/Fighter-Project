
extends Node
class_name LowHealthRetreat


#region References

@export_group("References")

@export var enemy: BaseEnemy
@export var ai_controller: AIController
@export var health_component: HealthComponent
@export var camera_bounds: CameraBounds

#endregion


#region Defensive Mode Settings

@export_group("Defensive Mode")

@export_range(0.0, 1.0, 0.05)
var health_threshold: float = 0.30

@export var defensive_mode_enabled: bool = true

#endregion


#region Distance Settings

@export_group("Defensive Distances")

@export_range(0.0, 1000.0, 5.0)
var retreat_trigger_distance: float = 180.0

@export_range(0.0, 1000.0, 5.0)
var target_retreat_distance: float = 250.0

@export_range(0.0, 1000.0, 5.0)
var comfortable_distance: float = 300.0

#endregion


#region Retreat Timing

@export_group("Retreat Timing")

@export_range(0.1, 10.0, 0.1)
var decision_interval: float = 1.0

@export_range(0.0, 10.0, 0.1)
var retreat_cooldown: float = 1.0

#endregion


#region Wild AI Settings

@export_group("Wild AI")

@export_range(0.0, 1.0, 0.05)
var wild_retreat_chance: float = 0.35

#endregion


#region Trainer AI Settings

@export_group("Trainer AI")

@export_range(0.0, 1.0, 0.05)
var trainer_retreat_chance: float = 0.80

#endregion


#region Retreat Actions

@export_group("Retreat Actions")

@export var allow_backward_dash: bool = true
@export var allow_backward_jump: bool = true

@export_range(0.0, 1.0, 0.05)
var backward_dash_weight: float = 0.50

#endregion


#region Ranged Special Settings

@export_group("Ranged Special Attacks")

@export var enable_ranged_specials: bool = true

# Only specials placed in this array are used
# by the low-health retreat behavior.
@export var ranged_specials: Array[SpecialAttackData] = []

@export_range(0.0, 1000.0, 5.0)
var minimum_special_distance: float = 100.0

@export_range(0.0, 1500.0, 5.0)
var maximum_special_distance: float = 500.0

@export_range(0.1, 10.0, 0.1)
var special_decision_interval: float = 0.75

@export_range(0.0, 20.0, 0.1)
var special_cooldown: float = 3.0

@export var allow_ex_specials: bool = true

@export_range(0.0, 1.0, 0.05)
var ex_special_chance: float = 0.20

@export var debug_specials: bool = false

#endregion


#region Ranged Special AI Chances

@export_group("Ranged Special AI Chances")

@export_range(0.0, 1.0, 0.05)
var wild_ranged_special_chance: float = 0.35

@export_range(0.0, 1.0, 0.05)
var trainer_ranged_special_chance: float = 0.75

#endregion


#region Camera Safety

@export_group("Camera Safety")

@export var check_camera_boundaries: bool = true

@export_range(0.0, 200.0, 1.0)
var boundary_safety_margin: float = 32.0

#endregion


#region Internal Variables

var decision_timer: float = 0.0
var cooldown_remaining: float = 0.0

var special_decision_timer: float = 0.0
var special_cooldown_remaining: float = 0.0

var retreat_active: bool = false

var special_state: EnemySpecialAttackState

#endregion


#region Initialization

func _ready() -> void:
	if enemy == null:
		enemy = get_parent() as BaseEnemy

	if enemy == null:
		push_warning(
			"LowHealthRetreat: BaseEnemy reference missing."
		)
		return

	if ai_controller == null:
		ai_controller = enemy.get_node_or_null(
			"AIController"
		) as AIController

	if health_component == null:
		health_component = enemy.health_component

	if health_component == null:
		health_component = enemy.get_node_or_null(
			"HealthComponent"
		) as HealthComponent

	if camera_bounds == null:
		camera_bounds = enemy.get_node_or_null(
			"CameraBounds"
		) as CameraBounds

	find_special_state()

#endregion


#region Processing

func _physics_process(delta: float) -> void:
	if enemy == null:
		return

	if enemy.is_dead:
		retreat_active = false
		return

	decision_timer = maxf(
		decision_timer - delta,
		0.0
	)

	cooldown_remaining = maxf(
		cooldown_remaining - delta,
		0.0
	)

	special_decision_timer = maxf(
		special_decision_timer - delta,
		0.0
	)

	special_cooldown_remaining = maxf(
		special_cooldown_remaining - delta,
		0.0
	)

	if not is_defensive_mode_active():
		retreat_active = false
		return

	if not is_instance_valid(enemy.opponent):
		retreat_active = false
		return

	# Do not interrupt an ongoing special,
	# attack, dash, jump, or hurt state.
	if enemy.isAttacking or enemy.isStunned:
		return

	if not enemy.can_move():
		return

	# Defensive AI never intentionally
	# approaches the player.
	enemy.stop_movement()

	var distance: float = get_player_distance()

	# Prioritize escaping when the player
	# is too close.
	if distance < retreat_trigger_distance:
		process_retreat()
		return

	retreat_active = false

	# Once enough distance has been created,
	# attempt a ranged special attack.
	process_ranged_special(distance)

#endregion


#region Defensive Mode

func is_defensive_mode_active() -> bool:
	if not defensive_mode_enabled:
		return false

	if enemy == null or health_component == null:
		return false

	if enemy.is_dead:
		return false

	if health_component.max_health <= 0:
		return false

	var health_percentage: float = (
		float(health_component.current_health)
		/ float(health_component.max_health)
	)

	return health_percentage <= health_threshold


func should_override_movement() -> bool:
	return is_defensive_mode_active()

#endregion


#region Distance Checking

func get_player_distance() -> float:
	if enemy == null:
		return INF

	if not is_instance_valid(enemy.opponent):
		return INF

	return absf(
		enemy.opponent.global_position.x
		- enemy.global_position.x
	)

#endregion


#region AI Type Settings

func get_retreat_chance() -> float:
	if ai_controller == null:
		return wild_retreat_chance

	match ai_controller.ai_type:
		AIController.AIType.TRAINER:
			return trainer_retreat_chance

		AIController.AIType.WILD:
			return wild_retreat_chance

	return wild_retreat_chance


func get_ranged_special_chance() -> float:
	if ai_controller == null:
		return wild_ranged_special_chance

	match ai_controller.ai_type:
		AIController.AIType.TRAINER:
			return trainer_ranged_special_chance

		AIController.AIType.WILD:
			return wild_ranged_special_chance

	return wild_ranged_special_chance

#endregion


#region Retreat Processing

func process_retreat() -> void:
	if decision_timer > 0.0:
		return

	if cooldown_remaining > 0.0:
		return

	if not can_retreat_from_camera():
		retreat_active = false
		return

	decision_timer = decision_interval

	if randf() > get_retreat_chance():
		return

	attempt_retreat()

#endregion


#region Ranged Special Processing

func process_ranged_special(distance: float) -> void:
	if not enable_ranged_specials:
		return

	if ranged_specials.is_empty():
		return

	if distance < minimum_special_distance:
		return

	if distance > maximum_special_distance:
		return

	if special_decision_timer > 0.0:
		return

	if special_cooldown_remaining > 0.0:
		return

	if enemy.is_dead or enemy.isStunned:
		return

	if enemy.isAttacking:
		return

	if not enemy.is_on_floor():
		return

	if enemy.block_component:
		if enemy.block_component.is_blocking:
			return

		if enemy.block_component.is_guard_broken:
			return

	if special_state == null:
		find_special_state()

	if special_state == null:
		return

	special_decision_timer = special_decision_interval

	if randf() > get_ranged_special_chance():
		return

	attempt_ranged_special()

#endregion


#region Ranged Special Selection

func attempt_ranged_special() -> void:
	if special_state == null:
		return

	var available_specials: Array[SpecialAttackData] = []

	# Only select specials that are valid
	# for the enemy's current situation.
	for special in ranged_specials:
		if special == null:
			continue

		if not special.can_use(
			not enemy.is_on_floor()
		):
			continue

		available_specials.append(special)

	if available_specials.is_empty():
		return

	# Randomly select one available special.
	var selected_special: SpecialAttackData = (
		available_specials.pick_random()
	)

	var use_ex: bool = false

	if allow_ex_specials:
		if selected_special.ex_enabled:
			use_ex = randf() < ex_special_chance

	# The special state validates meter,
	# animations, and combat restrictions.
	var success: bool = special_state.request_special(
		selected_special,
		use_ex
	)

	# If EX fails, try the normal version.
	if not success and use_ex:
		use_ex = false

		success = special_state.request_special(
			selected_special,
			false
		)

	if success:
		special_cooldown_remaining = special_cooldown
		retreat_active = false

		if debug_specials:
			print(
				"LowHealthRetreat: ",
				enemy.name,
				" used ranged special: ",
				selected_special.resource_name,
				" EX: ",
				use_ex
			)

#endregion


#region Camera Boundary Checking

func can_retreat_from_camera() -> bool:
	if not check_camera_boundaries:
		return true

	if camera_bounds == null:
		return true

	if not camera_bounds.limit_horizontal:
		return true

	var camera: Camera2D = camera_bounds.camera

	if camera == null:
		camera = get_viewport().get_camera_2d()

	if camera == null:
		return true

	var viewport_size: Vector2 = (
		camera.get_viewport_rect().size
	)

	var safe_zoom_x: float = maxf(
		absf(camera.zoom.x),
		0.001
	)

	var half_width: float = (
		viewport_size.x / safe_zoom_x
	) * 0.5

	var center_x: float = (
		camera.get_screen_center_position().x
	)

	var min_x: float = (
		center_x
		- half_width
		+ camera_bounds.horizontal_margin
		+ boundary_safety_margin
	)

	var max_x: float = (
		center_x
		+ half_width
		- camera_bounds.horizontal_margin
		- boundary_safety_margin
	)

	var retreat_direction: float = (
		-float(enemy.facing_direction)
	)

	if retreat_direction < 0.0:
		return enemy.global_position.x > min_x

	if retreat_direction > 0.0:
		return enemy.global_position.x < max_x

	return false

#endregion


#region Retreat Decision

func attempt_retreat() -> void:
	if enemy == null:
		return

	if not can_retreat_from_camera():
		return

	var dash_state: EnemyDashState = get_dash_state()
	var jump_state: EnemyJumpState = get_jump_state()

	var can_dash_back: bool = (
		allow_backward_dash
		and dash_state != null
	)

	if can_dash_back:
		can_dash_back = dash_state.can_dash()

	var can_jump_back: bool = (
		allow_backward_jump
		and jump_state != null
	)

	if not can_dash_back and not can_jump_back:
		return

	var use_dash: bool = false

	if can_dash_back and can_jump_back:
		use_dash = randf() < backward_dash_weight

	elif can_dash_back:
		use_dash = true

	if use_dash:
		enemy.dash(
			EnemyDashState.DashType.BACKWARD
		)
	else:
		enemy.jump(
			EnemyJumpState.JumpType.BACKWARD
		)

	retreat_active = true
	cooldown_remaining = retreat_cooldown

#endregion


#region State References

func find_special_state() -> void:
	special_state = null

	if enemy == null or enemy.fsm == null:
		return

	for child in enemy.fsm.get_children():
		if child is EnemySpecialAttackState:
			special_state = child as EnemySpecialAttackState
			return


func get_dash_state() -> EnemyDashState:
	if enemy == null or enemy.fsm == null:
		return null

	for child in enemy.fsm.get_children():
		if child is EnemyDashState:
			return child as EnemyDashState

	return null


func get_jump_state() -> EnemyJumpState:
	if enemy == null or enemy.fsm == null:
		return null

	for child in enemy.fsm.get_children():
		if child is EnemyJumpState:
			return child as EnemyJumpState

	return null

#endregion
