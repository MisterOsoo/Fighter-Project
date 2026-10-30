
extends State
class_name HurtState


#region Flash Settings

@export_group("Hit Flash")

@export var enable_hit_flash: bool = true
@export var flash_color: Color = Color(1.0, 0.5, 0.5, 1.0)
@export var flash_duration: float = 0.08

#endregion


#region References

@onready var player: BasePlayer = (
	get_parent().get_parent() as BasePlayer
)

#endregion


#region Internal Variables

var flash_timer: float = 0.0
var original_modulate: Color = Color.WHITE

#endregion


#region Initialization

func _ready() -> void:
	if player.visuals:
		original_modulate = player.visuals.modulate

	if player.anim:
		if not player.anim.animation_finished.is_connected(
			_on_animation_finished
		):
			player.anim.animation_finished.connect(
				_on_animation_finished
			)

#endregion


#region State Functions

func Enter() -> void:
	if player.is_dead:
		return

	player.isAttacking = false

	play_hurt_animation()
	start_hit_flash()


func Update(delta: float) -> void:
	update_hit_flash(delta)


func PhysicsUpdate(_delta: float) -> void:
	if player.is_dead:
		return

	if player.isStunned or player.knockback_timer > 0.0:
		return

	if player.is_on_floor():
		return_to_ground()
	else:
		return_to_air()


func Exit() -> void:
	flash_timer = 0.0
	reset_flash()

#endregion


#region Hurt Animation

func play_hurt_animation() -> void:
	if player.anim == null:
		return

	if player.anim.sprite_frames == null:
		return

	if not player.anim.sprite_frames.has_animation(
		player.hurt_animation
	):
		return

	player.anim.play(player.hurt_animation)
	player.anim.set_frame_and_progress(0, 0.0)


func hold_last_hurt_frame() -> void:
	if player.anim == null:
		return

	var frames: SpriteFrames = player.anim.sprite_frames

	if frames == null:
		return

	if not frames.has_animation(player.hurt_animation):
		return

	var frame_count: int = frames.get_frame_count(
		player.hurt_animation
	)

	if frame_count <= 0:
		return

	player.anim.stop()
	player.anim.set_frame_and_progress(
		frame_count - 1,
		0.0
	)

#endregion


#region Hit Flash

func start_hit_flash() -> void:
	if not enable_hit_flash:
		return

	if player.visuals == null:
		return

	flash_timer = flash_duration
	player.visuals.modulate = flash_color


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
	if player.visuals:
		player.visuals.modulate = original_modulate

#endregion


#region Repeated Hits

func receive_additional_hit() -> void:
	if player.is_dead:
		return

	# Only restart the flash.
	# Do not replay or change the hurt animation.
	start_hit_flash()

#endregion


#region Animation Signals

func _on_animation_finished() -> void:
	if fsm.current_state != self:
		return

	if player.anim == null:
		return

	if player.anim.animation == player.hurt_animation:
		hold_last_hurt_frame()

#endregion


#region Recovery Transitions

func return_to_ground() -> void:
	var direction: float = Input.get_axis(
		"ui_left",
		"ui_right"
	)

	if is_zero_approx(direction):
		transition_to("idle")
	else:
		transition_to("move")


func return_to_air() -> void:
	player.jump_horizontal_velocity = player.velocity.x

	player.is_jumping = false
	player.is_jump_transitioning = false
	player.jump_transition_finished = true

	transition_to("jump")

#endregion
