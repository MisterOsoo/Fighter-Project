
extends State
class_name DeathState


#region References

@export_group("References")
@export var player: BasePlayer

#endregion


#region Animation Settings

@export_group("Animation Settings")
@export var death_animation: String = "dead"

#endregion


#region Initialization

func _ready() -> void:
	if player == null:
		player = owner as BasePlayer

#endregion


#region State Functions

func Enter() -> void:
	if player == null:
		return

	player.is_dead = true
	player.isAttacking = false
	player.isStunned = false

	player.hitstun_timer = 0.0
	player.knockback_timer = 0.0
	player.knockback_total_duration = 0.0
	player.knockback_start_speed = 0.0

	player.velocity.x = 0.0

	player.is_jumping = false
	player.is_jump_transitioning = false
	player.jump_transition_finished = false
	player.jump_horizontal_velocity = 0.0

	player.ground_bounce_pending = false
	player.ground_bounce_active = false

	player.reset_launch_state()

	if player.dash_component:
		if player.dash_component.is_dashing:
			player.dash_component.stop_dash()

	if player.air_dash_component:
		if player.air_dash_component.is_air_dashing:
			player.air_dash_component.stop_air_dash()

	if player.block_component:
		if player.block_component.is_blocking:
			player.block_component.end_block(true)

	# Play the animation selected in this state's Inspector.
	player.play_animation(death_animation)


func Update(_delta: float) -> void:
	pass


func PhysicsUpdate(_delta: float) -> void:
	pass


func Exit() -> void:
	pass

#endregion


#region Transition Rules

func can_transition_to(_new_state: State) -> bool:
	return false

#endregion
