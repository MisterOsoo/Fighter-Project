
extends State
class_name BlockState


#region Animation Settings

@export_group("Block Animations")

@export var standing_block_animation: String = "block"
@export var crouching_block_animation: String = "crouchblock"

#endregion


#region References

@onready var player: BasePlayer = (
	get_parent().get_parent() as BasePlayer
)

@onready var block_component: BlockComponent = (
	player.block_component
)

#endregion


#region State Functions

func Enter() -> void:
	if block_component == null:
		return_to_movement()
		return

	if not block_component.is_blocking:
		return_to_movement()
		return

	player.velocity.x = 0.0
	player.jump_horizontal_velocity = 0.0

	update_block_hurtbox()
	play_block_animation()


func Update(_delta: float) -> void:
	pass


func PhysicsUpdate(_delta: float) -> void:
	if block_component == null:
		return_to_movement()
		return

	if player.is_dead or player.isStunned:
		block_component.end_block(true)
		return

	player.velocity.x = 0.0
	player.jump_horizontal_velocity = 0.0

	update_block_hurtbox()
	play_block_animation()

	if block_component.blockstun_timer > 0.0:
		return

	block_component.end_block()
	return_to_movement()


func Exit() -> void:
	if block_component:
		block_component.end_block(true)

	if not Input.is_action_pressed(player.crouch_input):
		set_crouch_hurtbox(false)

#endregion


#region Animation Handling

func play_block_animation() -> void:
	if player.anim == null:
		return

	var animation_name: String = standing_block_animation

	if block_component.is_crouch_blocking:
		animation_name = crouching_block_animation

	player.play_animation(animation_name)

#endregion


#region Hurtbox Management

func update_block_hurtbox() -> void:
	if block_component == null:
		return

	set_crouch_hurtbox(
		block_component.is_crouch_blocking
	)


func set_crouch_hurtbox(enabled: bool) -> void:
	var crouch_state: CrouchState = (
		fsm.states.get("crouch") as CrouchState
	)

	if crouch_state:
		crouch_state.set_crouching_hurtbox(enabled)

#endregion


#region Movement Transitions

func return_to_movement() -> void:
	if player.is_dead or player.isStunned:
		return

	if not player.is_on_floor():
		transition_to("jump")
		return

	if Input.is_action_pressed(player.crouch_input):
		transition_to("crouch")
		return

	var direction: float = Input.get_axis(
		"ui_left",
		"ui_right"
	)

	if is_zero_approx(direction):
		transition_to("idle")
	else:
		transition_to("move")

#endregion
