
extends State
class_name CrouchState


#region Animation Settings

@export_group("Animation Settings")
@export var crouch_animation: String = "crouch"

#endregion


#region Hurtbox Settings

@export_group("Hurtboxes")
@export var standing_hurtbox: Hurtbox
@export var crouching_hurtbox: Hurtbox

#endregion


#region References

@onready var player: BasePlayer = (
	get_parent().get_parent() as BasePlayer
)

#endregion


#region Initialization

func _ready() -> void:
	# Start with only the standing hurtbox active.
	set_crouching_hurtbox(false)

#endregion


#region State Functions

func Enter() -> void:
	if player.is_dead:
		return

	player.velocity.x = 0.0
	player.jump_horizontal_velocity = 0.0

	set_crouching_hurtbox(true)
	player.play_animation(crouch_animation)


func Update(_delta: float) -> void:
	pass


func PhysicsUpdate(_delta: float) -> void:
	if player.is_dead:
		return

	if player.isStunned or player.isAttacking:
		return

	if not player.is_on_floor():
		transition_to("jump")
		return

	player.velocity.x = 0.0
	player.jump_horizontal_velocity = 0.0

	if not Input.is_action_pressed(player.crouch_input):
		player.update_ground_state()


func Exit() -> void:
	var keep_crouching: bool = (
		player.block_component != null
		and player.block_component.is_blocking
		and player.block_component.is_crouch_blocking
	)

	if not keep_crouching:
		set_crouching_hurtbox(false)

#endregion


#region Hurtbox Management

func set_crouching_hurtbox(enabled: bool) -> void:
	set_hurtbox_active(standing_hurtbox, not enabled)
	set_hurtbox_active(crouching_hurtbox, enabled)


func set_hurtbox_active(
	hurtbox: Hurtbox,
	enabled: bool
) -> void:
	if hurtbox == null:
		return

	# Disable actual collision shapes.
	for child in hurtbox.get_children():
		if child is CollisionShape2D:
			var collision: CollisionShape2D = (
				child as CollisionShape2D
			)

			collision.set_deferred(
				"disabled",
				not enabled
			)

	# Also control Area2D detection.
	hurtbox.set_deferred("monitoring", enabled)
	hurtbox.set_deferred("monitorable", enabled)

#endregion
