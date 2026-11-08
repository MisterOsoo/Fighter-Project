
extends State
class_name EnemyHurtState


#region Animation Settings

@export_group("Hurt Animation")
@export var hurt_animation: StringName = &"hit"

#endregion


#region Flash Settings

@export_group("Hit Flash")

@export var enable_hit_flash: bool = true
@export var flash_color: Color = Color(1.0, 0.5, 0.5, 1.0)
@export_range(0.0, 1.0, 0.01)
var flash_duration: float = 0.08

#endregion


#region References

@export_group("References")
@export var enemy: BaseEnemy

#endregion


#region Debug

@export_group("Debug")
@export var debug_recovery: bool = false

#endregion


#region Internal Variables

var flash_timer: float = 0.0
var original_modulate: Color = Color.WHITE
var hurt_animation_finished: bool = false

#endregion


#region Initialization

func _ready() -> void:
	if enemy == null:
		enemy = get_parent().get_parent() as BaseEnemy

	if enemy == null:
		return

	if enemy.visuals:
		original_modulate = enemy.visuals.modulate

	if enemy.anim:
		if not enemy.anim.animation_finished.is_connected(
			_on_animation_finished
		):
			enemy.anim.animation_finished.connect(
				_on_animation_finished
			)

#endregion


#region State Functions

func Enter() -> void:
	if enemy == null or enemy.is_dead:
		return

	enemy.isAttacking = false
	hurt_animation_finished = false

	play_hurt_animation()
	start_hit_flash()


func Update(delta: float) -> void:
	update_hit_flash(delta)


func PhysicsUpdate(_delta: float) -> void:
	if enemy == null or enemy.is_dead:
		return

	if hurt_animation_finished:
		hold_last_hurt_frame()

	# Do not recover until all hit reactions finish.
	if (
		enemy.isStunned
		or enemy.knockback_timer > 0.0
		or enemy.is_launched
		or enemy.ground_bounce_active
	):
		return

	# Grounded recovery.
	if enemy.is_on_floor():
		recover_on_ground()
		return

	# Airborne recovery.
	# This must NOT start a new jump.
	recover_in_air()


func Exit() -> void:
	flash_timer = 0.0
	hurt_animation_finished = false
	reset_flash()

#endregion


#region Recovery

func recover_on_ground() -> void:
	if enemy == null:
		return

	if debug_recovery:
		print(
			"EnemyHurtState: Ground recovery."
		)

	if is_zero_approx(enemy.movement_direction):
		transition_to("idle")
	else:
		transition_to("move")


func recover_in_air() -> void:
	if enemy == null or enemy.fsm == null:
		return

	var jump_state: EnemyJumpState = (
		enemy.fsm.states.get("jump") as EnemyJumpState
	)

	if jump_state == null:
		if debug_recovery:
			push_warning(
				"EnemyHurtState: JumpState not found."
			)
		return

	# Preserve the enemy's remaining horizontal momentum.
	# Do not apply another upward jump impulse.
	var recovery_horizontal_velocity: float = enemy.velocity.x

	# Tell JumpState that this is airborne recovery,
	# not a new jump.
	jump_state.prepare_air_dash_recovery(
		recovery_horizontal_velocity
	)

	if debug_recovery:
		print(
			"EnemyHurtState: Air recovery.",
			" Horizontal velocity: ",
			recovery_horizontal_velocity,
			" Vertical velocity: ",
			enemy.velocity.y
		)

	transition_to("jump")

#endregion


#region Hurt Animation

func play_hurt_animation() -> void:
	if (
		enemy == null
		or enemy.anim == null
		or enemy.anim.sprite_frames == null
	):
		return

	if not enemy.anim.sprite_frames.has_animation(
		hurt_animation
	):
		return

	enemy.anim.play(hurt_animation)
	enemy.anim.set_frame_and_progress(0, 0.0)


func hold_last_hurt_frame() -> void:
	if (
		enemy == null
		or enemy.anim == null
		or enemy.anim.sprite_frames == null
	):
		return

	var frames: SpriteFrames = enemy.anim.sprite_frames

	if not frames.has_animation(hurt_animation):
		return

	var frame_count: int = frames.get_frame_count(
		hurt_animation
	)

	if frame_count <= 0:
		return

	if enemy.anim.animation != hurt_animation:
		enemy.anim.animation = hurt_animation

	enemy.anim.stop()

	enemy.anim.set_frame_and_progress(
		frame_count - 1,
		0.0
	)

#endregion


#region Hit Flash

func start_hit_flash() -> void:
	if (
		not enable_hit_flash
		or enemy == null
		or enemy.visuals == null
	):
		return

	flash_timer = maxf(flash_duration, 0.0)

	enemy.visuals.modulate = (
		original_modulate * flash_color
	)


func update_hit_flash(delta: float) -> void:
	if flash_timer <= 0.0:
		return

	flash_timer = maxf(
		flash_timer - delta,
		0.0
	)

	if flash_timer <= 0.0:
		reset_flash()


func reset_flash() -> void:
	if enemy != null and enemy.visuals != null:
		enemy.visuals.modulate = original_modulate

#endregion


#region Repeated Hits

func receive_additional_hit() -> void:
	if enemy == null or enemy.is_dead:
		return

	start_hit_flash()

#endregion


#region Animation Signals

func _on_animation_finished() -> void:
	if fsm == null or fsm.current_state != self:
		return

	if enemy == null or enemy.anim == null:
		return

	if enemy.anim.animation != hurt_animation:
		return

	hurt_animation_finished = true
	hold_last_hurt_frame()

#endregion
