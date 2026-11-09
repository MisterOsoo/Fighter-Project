
extends State
class_name CrouchState


#region Animation Settings

@export_group("Animation Settings")
@export var crouch_animation: String = "crouch"

#endregion


#region Attack Settings

@export_group("Attack Settings")
@export var heavy_input: StringName = &"heavyAtk"

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

	# Crouching heavy attack.
	if InputMap.has_action(heavy_input):
		if Input.is_action_just_pressed(heavy_input):
			request_crouch_heavy()
			return

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


#region Crouch Attack

func request_crouch_heavy() -> void:
	if player == null or player.fsm == null:
		return

	var attack_state: AttackState = null

	for child in player.fsm.get_children():
		if child is AttackState:
			attack_state = child as AttackState
			break

	if attack_state == null:
		push_warning(
			"CrouchState: AttackState not found."
		)
		return

	if attack_state.crouch_heavy_attack == null:
		push_warning(
			"CrouchState: Crouch Heavy AttackData not assigned."
		)
		return

	attack_state.request_attack(&"crouch_heavy")
	transition_to("attack")

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

	for child in hurtbox.get_children():
		if child is CollisionShape2D:
			var collision: CollisionShape2D = (
				child as CollisionShape2D
			)

			collision.set_deferred(
				"disabled",
				not enabled
			)

	hurtbox.set_deferred("monitoring", enabled)
	hurtbox.set_deferred("monitorable", enabled)

#endregion
