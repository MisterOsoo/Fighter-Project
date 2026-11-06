
extends CharacterBody2D
class_name TrainingDummy


#region Collision Settings

@export_group("Collision")

@export_range(1.0, 100.0, 1.0)
var body_collision_priority: float = 10.0

@export var prevent_body_pushing: bool = true

#endregion


#region Facing Settings

@export_group("Facing")

var opponent: CharacterBody2D
@export var visuals: Node2D

var facing_direction: int = -1

#endregion


#region Animation Settings

@export_group("Animations")

@export var anim: AnimatedSprite2D

@export var idle_animation: String = "idle"
@export var hit_animation: String = "hit"
@export var death_animation: String = "dead"

#endregion


#region Death Settings

@export_group("Death Settings")

@export var health_component: HealthComponent

@export var blink_duration: float = 1.0
@export var blink_interval: float = 0.1

var is_dead: bool = false
var is_blinking: bool = false

#endregion


#region Training Respawn Settings

@export_group("Training Respawn")

@export var training_respawn_enabled: bool = true

@export_range(0.0, 30.0, 0.1)
var respawn_delay: float = 2.0

@export_range(0.0, 2000.0, 10.0)
var respawn_height: float = 500.0

@export_range(0.0, 2000.0, 10.0)
var respawn_distance: float = 150.0

enum RespawnSide {
	OPPOSITE,
	LEFT,
	RIGHT
}

@export var respawn_side: RespawnSide = RespawnSide.OPPOSITE

@export_range(0.0, 10.0, 0.1)
var respawn_blink_duration: float = 1.0

@export_range(0.01, 1.0, 0.01)
var respawn_blink_interval: float = 0.1

#endregion


#region Camera Respawn Settings

@export_group("Camera Respawn")

@export var camera_controller: GroupCameraController

@export var camera_enemy_group: StringName = &"enemy"

#endregion


#region Combat State

var isStunned: bool = false
var hitstun_timer: float = 0.0

var knockback_timer: float = 0.0
var knockback_duration: float = 0.0
var knockback_velocity: float = 0.0

var is_launched: bool = false
var is_ground_slammed: bool = false

var launch_gravity_multiplier: float = 1.0
var launch_max_fall_speed: float = 250.0

var ground_bounce_pending: bool = false
var ground_bounce_active: bool = false
var ground_bounce_speed: float = 230.0
var ground_bounce_hitstun: float = 0.6

#endregion


#region Respawn State

var spawn_position: Vector2

var original_collision_layer: int
var original_collision_mask: int

var hurtbox: Area2D
var original_hurtbox_layer: int
var original_hurtbox_mask: int
var original_hurtbox_monitoring: bool
var original_hurtbox_monitorable: bool

var is_respawning: bool = false
var was_in_enemy_group: bool = false

var respawn_side_direction: float = 1.0

#endregion


#region Initialization

func _ready() -> void:
	collision_priority = body_collision_priority

	spawn_position = global_position

	original_collision_layer = collision_layer
	original_collision_mask = collision_mask

	if visuals == null:
		visuals = get_node_or_null("Visuals") as Node2D

	if anim == null and visuals:
		anim = visuals.get_node_or_null(
			"AnimatedSprite2D"
		) as AnimatedSprite2D

	if health_component == null:
		health_component = get_node_or_null(
			"HealthComponent"
		) as HealthComponent

	hurtbox = get_node_or_null("Hurtbox") as Area2D

	if hurtbox:
		original_hurtbox_layer = hurtbox.collision_layer
		original_hurtbox_mask = hurtbox.collision_mask
		original_hurtbox_monitoring = hurtbox.monitoring
		original_hurtbox_monitorable = hurtbox.monitorable

	if health_component:
		if not health_component.defeated.is_connected(
			_on_defeated
		):
			health_component.defeated.connect(
				_on_defeated
			)

	if anim:
		if not anim.animation_finished.is_connected(
			_on_animation_finished
		):
			anim.animation_finished.connect(
				_on_animation_finished
			)

		play_idle_animation()

	update_facing()

#endregion


#region Facing

func update_facing() -> void:
	var candidate: Node = get_tree().get_first_node_in_group(
		"player"
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


#region Physics

func _physics_process(delta: float) -> void:
	if is_respawning:
		return

	if not is_dead:
		update_hitstun(delta)

	update_knockback(delta)
	apply_gravity(delta)

	move_and_slide()

	if is_on_floor() and is_launched:
		if ground_bounce_pending and not is_dead:
			trigger_ground_bounce()
		else:
			reset_launch_state()

	if ground_bounce_active:
		velocity.x = 0.0
		knockback_velocity = 0.0
		knockback_timer = 0.0

		if is_on_floor() and not ground_bounce_pending:
			ground_bounce_active = false

	if not is_dead:
		update_facing()

#endregion


#region Animation Handling

func play_idle_animation() -> void:
	if is_dead or isStunned:
		return

	if anim == null or anim.sprite_frames == null:
		return

	if anim.sprite_frames.has_animation(idle_animation):
		anim.play(idle_animation)


func _on_animation_finished() -> void:
	if anim == null or is_dead:
		return

	if anim.animation == hit_animation:
		if not isStunned:
			play_idle_animation()

#endregion


#region Hitstun

func update_hitstun(delta: float) -> void:
	var was_stunned: bool = isStunned

	if hitstun_timer > 0.0:
		hitstun_timer = maxf(
			hitstun_timer - delta,
			0.0
		)

	isStunned = hitstun_timer > 0.0

	if was_stunned and not isStunned:
		if not is_dead:
			play_idle_animation()

#endregion


#region Knockback

func update_knockback(delta: float) -> void:
	if ground_bounce_active:
		velocity.x = 0.0
		return

	if knockback_timer > 0.0:
		var weight: float = (
			knockback_timer / maxf(knockback_duration, 0.001)
		)

		velocity.x = knockback_velocity * weight

		knockback_timer = maxf(
			knockback_timer - delta,
			0.0
		)
	else:
		velocity.x = 0.0

#endregion


#region Gravity

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var gravity: Vector2 = get_gravity()

		if is_launched:
			gravity *= launch_gravity_multiplier

		velocity += gravity * delta

		if is_launched:
			velocity.y = minf(
				velocity.y,
				launch_max_fall_speed
			)

	elif velocity.y > 0.0:
		velocity.y = 0.0

#endregion


#region Receive Combat Hit

func receive_combat_hit(
	impulse: Vector2,
	new_knockback_duration: float,
	new_hitstun_duration: float,
	new_launch_gravity_multiplier: float = 1.0,
	new_launch_max_fall_speed: float = 250.0,
	ground_slam: bool = false,
	ground_bounce: bool = false,
	bounce_speed: float = 230.0,
	bounce_hitstun: float = 0.6
) -> void:
	if is_dead or is_respawning:
		return

	knockback_velocity = impulse.x
	knockback_duration = maxf(
		new_knockback_duration,
		0.0
	)
	knockback_timer = knockback_duration

	if knockback_duration <= 0.0:
		velocity.x = 0.0

	reset_launch_state()

	ground_bounce_active = false
	ground_bounce_pending = false

	if impulse.y < 0.0:
		velocity.y = impulse.y
		is_launched = true

		launch_gravity_multiplier = maxf(
			new_launch_gravity_multiplier,
			0.0
		)

		launch_max_fall_speed = maxf(
			new_launch_max_fall_speed,
			0.0
		)

	elif ground_slam and impulse.y > 0.0 and not is_on_floor():
		velocity.y = impulse.y
		is_launched = true
		is_ground_slammed = true

		launch_gravity_multiplier = 1.0
		launch_max_fall_speed = INF

		ground_bounce_pending = ground_bounce
		ground_bounce_speed = maxf(bounce_speed, 0.0)
		ground_bounce_hitstun = maxf(bounce_hitstun, 0.0)

	hitstun_timer = maxf(new_hitstun_duration, 0.0)
	isStunned = hitstun_timer > 0.0

	play_hit_animation()

#endregion


#region Ground Bounce

func trigger_ground_bounce() -> void:
	ground_bounce_pending = false
	ground_bounce_active = true

	velocity.x = 0.0
	knockback_velocity = 0.0
	knockback_timer = 0.0
	knockback_duration = 0.0

	velocity.y = -ground_bounce_speed

	is_launched = true
	is_ground_slammed = false

	launch_gravity_multiplier = 1.0
	launch_max_fall_speed = 250.0

	hitstun_timer = maxf(
		hitstun_timer,
		ground_bounce_hitstun
	)

	isStunned = hitstun_timer > 0.0

	play_hit_animation()


func reset_launch_state() -> void:
	is_launched = false
	is_ground_slammed = false
	launch_gravity_multiplier = 1.0
	launch_max_fall_speed = 250.0

#endregion


#region Hit Animation

func play_hit_animation() -> void:
	if is_dead or anim == null:
		return

	if anim.sprite_frames == null:
		return

	if anim.sprite_frames.has_animation(hit_animation):
		anim.play(hit_animation)

#endregion


#region Death Handling

func _on_defeated() -> void:
	if is_dead:
		return

	is_dead = true
	isStunned = false
	hitstun_timer = 0.0

	knockback_timer = 0.0
	knockback_velocity = 0.0
	velocity.x = 0.0

	ground_bounce_pending = false
	ground_bounce_active = false

	if hurtbox:
		hurtbox.set_deferred("monitorable", false)
		hurtbox.set_deferred("monitoring", false)

	play_death_sequence()

#endregion


#region Death Animation

func play_death_sequence() -> void:
	if anim == null or anim.sprite_frames == null:
		start_blinking()
		return

	if not anim.sprite_frames.has_animation(death_animation):
		start_blinking()
		return

	anim.play(death_animation)
	await anim.animation_finished

	if not is_inside_tree():
		return

	start_blinking()

#endregion


#region Death Blinking

func start_blinking() -> void:
	if is_blinking:
		return

	is_blinking = true

	if visuals == null:
		finish_death_sequence()
		return

	var elapsed: float = 0.0
	var interval: float = maxf(blink_interval, 0.01)

	while elapsed < blink_duration:
		visuals.visible = not visuals.visible

		await get_tree().create_timer(
			interval
		).timeout

		if not is_inside_tree():
			return

		elapsed += interval

	visuals.visible = true
	is_blinking = false

	finish_death_sequence()

#endregion


#region Camera Respawn Handling

func disconnect_from_camera() -> void:
	was_in_enemy_group = is_in_group(camera_enemy_group)

	if was_in_enemy_group:
		remove_from_group(camera_enemy_group)

	if is_instance_valid(camera_controller):
		camera_controller.queue_target_refresh()


func reconnect_to_camera() -> void:
	if was_in_enemy_group:
		add_to_group(camera_enemy_group)

	if is_instance_valid(camera_controller):
		camera_controller.queue_target_refresh()

	was_in_enemy_group = false

#endregion


#region Respawn Position

func get_respawn_position() -> Vector2:
	var candidate: Node = get_tree().get_first_node_in_group(
		"player"
	)

	opponent = candidate as CharacterBody2D

	if not is_instance_valid(opponent):
		return spawn_position

	var direction: float = 1.0

	match respawn_side:
		RespawnSide.LEFT:
			direction = -1.0

		RespawnSide.RIGHT:
			direction = 1.0

		RespawnSide.OPPOSITE:
			direction = respawn_side_direction

	return Vector2(
		opponent.global_position.x + direction * respawn_distance,
		spawn_position.y
	)

#endregion


#region Respawn Handling

func finish_death_sequence() -> void:
	if not training_respawn_enabled:
		queue_free()
		return

	start_respawn()


func start_respawn() -> void:
	if is_respawning:
		return

	is_respawning = true

	# Remember which side of the player the dummy was on.
	var candidate: Node = get_tree().get_first_node_in_group(
		"player"
	)

	opponent = candidate as CharacterBody2D

	if is_instance_valid(opponent):
		respawn_side_direction = signf(
			global_position.x - opponent.global_position.x
		)

		if is_zero_approx(respawn_side_direction):
			respawn_side_direction = 1.0

	# Disconnect from the camera before moving.
	disconnect_from_camera()

	# Hide the dummy.
	if visuals:
		visuals.hide()

	# Disable physical collision.
	collision_layer = 0
	collision_mask = 0

	if hurtbox:
		hurtbox.set_deferred("collision_layer", 0)
		hurtbox.set_deferred("collision_mask", 0)
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)

	velocity = Vector2.ZERO

	# Move the dummy above the arena while invisible.
	global_position.y -= respawn_height

	# Restore health.
	if health_component:
		health_component.current_health = health_component.max_health
		health_component.health_changed.emit(
			health_component.current_health
		)

	# Wait before respawning.
	await get_tree().create_timer(
		respawn_delay
	).timeout

	if not is_inside_tree():
		return

	complete_respawn()


func complete_respawn() -> void:
	# Respawn relative to the player's current position.
	global_position = get_respawn_position()

	velocity = Vector2.ZERO

	# Reset combat state.
	is_dead = false
	isStunned = false
	hitstun_timer = 0.0

	knockback_timer = 0.0
	knockback_duration = 0.0
	knockback_velocity = 0.0

	ground_bounce_pending = false
	ground_bounce_active = false

	reset_launch_state()

	if anim and anim.sprite_frames:
		if anim.sprite_frames.has_animation(idle_animation):
			anim.play(idle_animation)

	# Blink back into the arena.
	blink_respawn()

#endregion


#region Respawn Blinking

func blink_respawn() -> void:
	if visuals == null:
		reconnect_to_camera()
		finish_respawn()
		return

	visuals.hide()

	# Reconnect after the dummy reaches its new position.
	reconnect_to_camera()

	var elapsed: float = 0.0
	var interval: float = maxf(
		respawn_blink_interval,
		0.01
	)

	while elapsed < respawn_blink_duration:
		visuals.visible = not visuals.visible

		await get_tree().create_timer(
			interval
		).timeout

		if not is_inside_tree():
			return

		elapsed += interval

	visuals.show()

	finish_respawn()


func finish_respawn() -> void:
	# Restore body collision.
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask

	# Restore hurtbox collision.
	if hurtbox:
		hurtbox.set_deferred(
			"collision_layer",
			original_hurtbox_layer
		)
		hurtbox.set_deferred(
			"collision_mask",
			original_hurtbox_mask
		)
		hurtbox.set_deferred(
			"monitoring",
			original_hurtbox_monitoring
		)
		hurtbox.set_deferred(
			"monitorable",
			original_hurtbox_monitorable
		)

	is_respawning = false

	update_facing()

#endregion
