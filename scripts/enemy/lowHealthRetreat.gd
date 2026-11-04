
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


#region Camera Safety

@export_group("Camera Safety")

@export var check_camera_boundaries: bool = true

@export_range(0.0, 200.0, 1.0)
var boundary_safety_margin: float = 32.0

#endregion


#region Internal Variables

var decision_timer: float = 0.0
var cooldown_remaining: float = 0.0

var retreat_active: bool = false

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

#endregion


#region Processing

func _physics_process(delta: float) -> void:
	if enemy == null:
		return

	if enemy.is_dead:
		retreat_active = false
		return

	if decision_timer > 0.0:
		decision_timer = maxf(
			decision_timer - delta,
			0.0
		)

	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(
			cooldown_remaining - delta,
			0.0
		)

	if not is_defensive_mode_active():
		retreat_active = false
		return

	if not is_instance_valid(enemy.opponent):
		retreat_active = false
		return

	# Defensive AI never intentionally approaches
	# the player while low on health.
	enemy.stop_movement()

	var distance: float = get_player_distance()

	# The player is far enough away.
	# Hold position and wait.
	if distance >= retreat_trigger_distance:
		retreat_active = false
		return

	# The enemy is too close to the player.
	# Only attempt retreat from a valid ground state.
	if not enemy.can_move():
		return

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
	# Normal AI approach behavior is disabled
	# for the entire duration of Defensive Mode.
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

	# Backward means moving away from the opponent.
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
