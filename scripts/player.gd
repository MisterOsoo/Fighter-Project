
extends CharacterBody2D
class_name BasePlayer


#region Player Settings

@export_group("References")
@export var anim: AnimatedSprite2D
@export var visuals: Node2D
@export var fsm: FiniteStateMachine

@export_group("Movement")
@export var speed: float = 100.0
@export var jump_velocity: float = -400.0

@export_group("Input")
@export var crouch_input: StringName = &"ui_down"

@export_group("Components")
@export var dash_component: DashComponent
@export var air_dash_component: AirDashComponent
@export var block_component: BlockComponent
@export var health_component: HealthComponent

var opponent: CharacterBody2D
var facing_direction: int = 1

#endregion


#region Equipped Special Attacks

@export_group("Equipped Special Attacks")
@export var equipped_specials: Array[SpecialAttackData] = []


func get_equipped_specials() -> Array[SpecialAttackData]:
	var result: Array[SpecialAttackData] = []

	for special in equipped_specials:
		if special == null:
			continue

		result.append(special)

		if result.size() >= 4:
			break

	return result

#endregion


#region Animation Settings

@export_group("Animations")
@export var idle_animation: String = "idle"
@export var walk_animation: String = "walk"
@export var jumpstart_animation: String = "jumpstart"
@export var jumptransition_animation: String = "jumptransition"
@export var fall_animation: String = "fall"
@export var attack_animation: String = "attack"
@export var hurt_animation: String = "hurt"
@export var death_animation: String = "dead"

#endregion


#region Combat State

var isAttacking: bool = false
var isStunned: bool = false
var is_dead: bool = false

var hitstun_timer: float = 0.0

var knockback_timer: float = 0.0
var knockback_total_duration: float = 0.0
var knockback_start_speed: float = 0.0

var is_launched: bool = false
var is_ground_slammed: bool = false

var launch_gravity_multiplier: float = 1.0
var launch_max_fall_speed: float = 250.0

#endregion


#region Ground Bounce State

var ground_bounce_pending: bool = false
var ground_bounce_active: bool = false

var ground_bounce_speed: float = 230.0
var ground_bounce_hitstun: float = 0.6

#endregion


#region Jump State

var is_jumping: bool = false
var is_jump_transitioning: bool = false
var jump_transition_finished: bool = false
var jump_horizontal_velocity: float = 0.0

#endregion


#region Initialization

func _ready() -> void:
	if anim:
		if not anim.animation_finished.is_connected(
			_on_animated_sprite_2d_animation_finished
		):
			anim.animation_finished.connect(
				_on_animated_sprite_2d_animation_finished
			)

	if fsm == null:
		fsm = get_node_or_null(
			"FiniteStateMachine"
		) as FiniteStateMachine

	if dash_component == null:
		dash_component = get_node_or_null(
			"DashComponent"
		) as DashComponent

	if air_dash_component == null:
		air_dash_component = get_node_or_null(
			"AirDashComponent"
		) as AirDashComponent

	if block_component == null:
		block_component = get_node_or_null(
			"BlockComponent"
		) as BlockComponent

	if health_component == null:
		health_component = get_node_or_null(
			"HealthComponent"
		) as HealthComponent

	if health_component:
		if not health_component.defeated.is_connected(
			_on_health_defeated
		):
			health_component.defeated.connect(
				_on_health_defeated
			)

	update_facing()

#endregion


#region Facing

func update_facing() -> void:
	var candidate: Node = (
		get_tree().get_first_node_in_group("enemy")
	)

	opponent = candidate as CharacterBody2D

	if not is_on_floor() or not is_instance_valid(opponent):
		return

	var difference: float = (
		opponent.global_position.x - global_position.x
	)

	if absf(difference) < 0.01:
		return

	facing_direction = 1 if difference > 0.0 else -1

	if visuals:
		visuals.scale.x = (
			absf(visuals.scale.x) * facing_direction
		)

#endregion


#region FSM Helpers

func is_crouching() -> bool:
	if fsm == null:
		return false

	if fsm.current_state is CrouchState:
		return true

	if block_component:
		if block_component.is_blocking:
			return block_component.is_crouch_blocking

	return false


func can_use_ground_states() -> bool:
	if is_dead or isStunned or isAttacking:
		return false

	if knockback_timer > 0.0:
		return false

	if not is_on_floor():
		return false

	if dash_component and dash_component.is_dashing:
		return false

	if air_dash_component and air_dash_component.is_air_dashing:
		return false

	if block_component and block_component.is_blocking:
		return false

	return true


func update_ground_state() -> void:
	if fsm == null or not can_use_ground_states():
		return

	# Crouching takes priority over horizontal movement.
	if Input.is_action_pressed(crouch_input):
		velocity.x = 0.0
		jump_horizontal_velocity = 0.0

		fsm.transition_to("crouch")
		return

	var direction: float = Input.get_axis(
		"ui_left",
		"ui_right"
	)

	if is_zero_approx(direction):
		fsm.transition_to("idle")
	else:
		fsm.transition_to("move")

#endregion


#region Hit Reception

func receive_combat_hit(
	impulse: Vector2,
	new_knockback_duration: float,
	new_hitstun_duration: float,
	gravity_multiplier: float,
	max_fall_speed: float,
	ground_slam: bool = false,
	ground_bounce: bool = false,
	bounce_speed: float = 230.0,
	bounce_hitstun: float = 0.6
) -> void:
	if is_dead:
		return

	# A successful hit interrupts blocking.
	if block_component:
		block_component.end_block(true)

	# Interrupt active dashes.
	if dash_component and dash_component.is_dashing:
		dash_component.stop_dash()

	if air_dash_component and air_dash_component.is_air_dashing:
		air_dash_component.stop_air_dash()

	# Apply hitstun.
	hitstun_timer = maxf(new_hitstun_duration, 0.0)
	isStunned = hitstun_timer > 0.0

	# Apply horizontal knockback.
	knockback_total_duration = maxf(
		new_knockback_duration,
		0.0
	)

	knockback_timer = knockback_total_duration
	knockback_start_speed = impulse.x

	# Reset previous launch settings.
	reset_launch_state()

	ground_bounce_pending = false
	ground_bounce_active = false

	# Standard upward launch.
	if impulse.y < 0.0:
		velocity.y = impulse.y
		is_launched = true

		launch_gravity_multiplier = maxf(
			gravity_multiplier,
			0.0
		)

		launch_max_fall_speed = maxf(
			max_fall_speed,
			0.0
		)

	# Ground Slam.
	elif ground_slam and impulse.y > 0.0 and not is_on_floor():
		velocity.y = impulse.y

		is_launched = true
		is_ground_slammed = true

		launch_gravity_multiplier = 1.0
		launch_max_fall_speed = INF

		# Ground Bounce is configured by AttackData.
		ground_bounce_pending = ground_bounce
		ground_bounce_speed = maxf(bounce_speed, 0.0)
		ground_bounce_hitstun = maxf(bounce_hitstun, 0.0)

	if is_launched:
		is_jumping = false
		is_jump_transitioning = false
		jump_transition_finished = false
		jump_horizontal_velocity = 0.0

	if knockback_timer > 0.0:
		velocity.x = knockback_start_speed
	else:
		velocity.x = 0.0

	isAttacking = false

	if isStunned or knockback_timer > 0.0 or is_launched:
		if fsm:
			if fsm.current_state is HurtState:
				var hurt_state: HurtState = (
					fsm.current_state as HurtState
				)

				hurt_state.receive_additional_hit()
			else:
				fsm.transition_to("hurt", true)

#endregion


#region Movement

func _physics_process(delta: float) -> void:
	if is_dead:
		apply_gravity(delta)
		move_and_slide()
		return

	# Resolve landing from a previous physics frame.
	if is_launched and is_on_floor() and velocity.y >= 0.0:
		if ground_bounce_pending:
			trigger_ground_bounce()
		else:
			reset_launch_state()

	var ground_dashing: bool = (
		dash_component != null
		and dash_component.is_dashing
	)

	var air_dashing: bool = (
		air_dash_component != null
		and air_dash_component.is_air_dashing
	)

	if not air_dashing:
		apply_gravity(delta)

	# Update hitstun.
	if isStunned:
		hitstun_timer = maxf(
			hitstun_timer - delta,
			0.0
		)

		if hitstun_timer <= 0.0:
			isStunned = false

	# Update horizontal knockback.
	if knockback_timer > 0.0:
		knockback_timer = maxf(
			knockback_timer - delta,
			0.0
		)

		var remaining_ratio: float = 0.0

		if knockback_total_duration > 0.0:
			remaining_ratio = (
				knockback_timer / knockback_total_duration
			)

		velocity.x = (
			knockback_start_speed * remaining_ratio
		)

		if knockback_timer <= 0.0:
			velocity.x = 0.0

	# Ground Bounce removes all horizontal momentum.
	if ground_bounce_active:
		velocity.x = 0.0
		knockback_timer = 0.0
		knockback_total_duration = 0.0
		knockback_start_speed = 0.0
		jump_horizontal_velocity = 0.0

	# BlockState is entered only by BlockComponent
	# when an attack successfully connects.
	if block_component and block_component.is_blocking:
		velocity.x = 0.0

		if fsm and not (fsm.current_state is BlockState):
			fsm.transition_to("block")

		move_and_slide()
		update_facing()
		return

	# Stunned characters cannot control movement.
	if isStunned or knockback_timer > 0.0:
		move_and_slide()
		update_facing()
		return

	# Ground dash.
	if ground_dashing:
		dash_component.apply_dash_velocity()

		play_animation(
			dash_component.get_dash_animation()
		)

		move_and_slide()
		update_facing()
		return

	# Air dash.
	if air_dashing:
		air_dash_component.apply_air_dash_velocity()

		play_animation(
			air_dash_component.get_dash_animation()
		)

		move_and_slide()
		update_facing()
		return

	# Special attacks control their own movement.
	if fsm and fsm.current_state is SpecialAttackState:
		move_and_slide()
		update_facing()
		return

	# Normal attacks preserve their existing movement rules.
	if isAttacking:
		var lock_horizontal: bool = true

		if fsm and fsm.current_state is AttackState:
			var attack_state: AttackState = (
				fsm.current_state as AttackState
			)

			if attack_state.current_attack:
				lock_horizontal = (
					attack_state.current_attack.lock_horizontal_movement
				)

		if lock_horizontal:
			velocity.x = 0.0
		elif not is_on_floor():
			velocity.x = jump_horizontal_velocity

		move_and_slide()
		update_facing()
		return

	# Crouching prevents horizontal movement,
	# including when left or right is held.
	if fsm and fsm.current_state is CrouchState:
		velocity.x = 0.0
		jump_horizontal_velocity = 0.0

		move_and_slide()
		update_facing()
		return

	# Normal movement is controlled by the FSM.
	move_and_slide()
	update_facing()

	# Release the vertical-only bounce lock on landing.
	if ground_bounce_active and is_on_floor():
		ground_bounce_active = false

	# Transition to jump when leaving the floor.
	if not is_on_floor() and fsm:
		if fsm.current_state:
			var state_name: String = (
				fsm.current_state.name.to_lower()
			)

			if state_name not in [
				"jump",
				"hurt",
				"airdash",
				"attack",
				"specialattack",
				"block",
				"crouch",
				"death"
			]:
				jump_horizontal_velocity = velocity.x
				fsm.transition_to("jump")

#endregion


#region Ground Bounce

func trigger_ground_bounce() -> void:
	ground_bounce_pending = false
	ground_bounce_active = true

	# Remove all horizontal momentum.
	velocity.x = 0.0

	knockback_timer = 0.0
	knockback_total_duration = 0.0
	knockback_start_speed = 0.0

	jump_horizontal_velocity = 0.0

	# Bounce vertically upward.
	velocity.y = -ground_bounce_speed

	is_launched = true
	is_ground_slammed = false

	launch_gravity_multiplier = 1.0
	launch_max_fall_speed = 250.0

	# Extend hitstun so the bounce can be comboed.
	hitstun_timer = maxf(
		hitstun_timer,
		ground_bounce_hitstun
	)

	isStunned = hitstun_timer > 0.0

	if fsm and not (fsm.current_state is HurtState):
		fsm.transition_to("hurt", true)

#endregion


#region Launch Reset

func reset_launch_state() -> void:
	is_launched = false
	is_ground_slammed = false

	launch_gravity_multiplier = 1.0
	launch_max_fall_speed = 250.0

#endregion


#region Jump

func start_jump(direction: float) -> void:
	velocity.y = jump_velocity

	jump_horizontal_velocity = direction * speed
	velocity.x = jump_horizontal_velocity

	is_jumping = true
	is_jump_transitioning = false
	jump_transition_finished = false

	play_animation(jumpstart_animation)

#endregion


#region Gravity

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var gravity_scale: float = 1.0

		if is_launched:
			gravity_scale = launch_gravity_multiplier

		velocity += get_gravity() * gravity_scale * delta

		if is_launched:
			velocity.y = minf(
				velocity.y,
				launch_max_fall_speed
			)

#endregion


#region Animation Handling

func play_animation(animation_name: String) -> void:
	if anim == null or anim.sprite_frames == null:
		return

	if not anim.sprite_frames.has_animation(animation_name):
		return

	if anim.animation != animation_name or not anim.is_playing():
		anim.play(animation_name)


func _on_animated_sprite_2d_animation_finished() -> void:
	if anim == null:
		return

	if anim.animation == jumptransition_animation:
		is_jump_transitioning = false
		jump_transition_finished = true

#endregion


#region Death Handling

func _on_health_defeated() -> void:
	die()


func die() -> void:
	if is_dead:
		return

	# Mark defeated immediately to prevent further hits.
	is_dead = true

	# Interrupt existing actions before entering DeathState.
	if dash_component and dash_component.is_dashing:
		dash_component.stop_dash()

	if air_dash_component and air_dash_component.is_air_dashing:
		air_dash_component.stop_air_dash()

	if block_component and block_component.is_blocking:
		block_component.end_block(true)

	isAttacking = false
	isStunned = false

	hitstun_timer = 0.0
	knockback_timer = 0.0
	knockback_total_duration = 0.0
	knockback_start_speed = 0.0

	velocity.x = 0.0

	if fsm:
		fsm.transition_to("death", true)
	else:
		play_animation(death_animation)

#endregion
