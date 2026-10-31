
extends State
class_name AttackState


#region Attack Settings

@export_group("Ground Attacks")
@export var light_attack: AttackData
@export var heavy_attack: AttackData

@export_group("Air Attacks")
@export var air_light_attack: AttackData
@export var air_heavy_attack: AttackData

#endregion


#region Input Settings

@export_group("Input")
@export var light_input: StringName = &"lightAtk"
@export var heavy_input: StringName = &"heavyAtk"
@export var jump_input: StringName = &"ui_accept"

#endregion


#region Combo Settings

@export_group("Combo")
@export_range(0, 20, 1)
var input_buffer_frames: int = 4

#endregion


#region Jump Cancel Settings

@export_group("Jump Cancel")
@export var hold_jump_buffer_until_cancel: bool = true

@export_range(0, 60, 1)
var jump_buffer_frames: int = 5

#endregion


#region Landing Cancel Settings

@export_group("Landing Cancel")
@export var enable_landing_cancel: bool = true

#endregion


#region References

@onready var player: BasePlayer = (
	get_parent().get_parent() as BasePlayer
)

#endregion


#region Internal Variables

var current_attack: AttackData
var requested_attack: AttackData

var hit_confirmed: bool = false

var buffered_input: StringName = &""
var buffer_frames_remaining: int = 0

var jump_buffered: bool = false
var jump_buffer_remaining: int = 0

var attack_finished: bool = false
var attack_started: bool = false

var attack_started_airborne: bool = false

#endregion


#region Initialization

func _ready() -> void:
	if player.anim:
		if not player.anim.animation_finished.is_connected(
			_on_animation_finished
		):
			player.anim.animation_finished.connect(
				_on_animation_finished
			)

#endregion


#region Attack Requests

func request_attack(attack_type: StringName) -> void:
	var airborne: bool = not player.is_on_floor()

	match attack_type:
		&"light":
			if airborne:
				requested_attack = air_light_attack
			else:
				requested_attack = light_attack

		&"heavy":
			if airborne:
				requested_attack = air_heavy_attack
			else:
				requested_attack = heavy_attack

		_:
			requested_attack = null

#endregion


#region State Functions

func Enter() -> void:
	if requested_attack == null:
		return_to_movement()
		return

	if player.is_dead or player.isStunned:
		requested_attack = null
		return_to_movement()
		return

	if not is_attack_allowed(requested_attack):
		requested_attack = null
		return_to_movement()
		return

	start_attack(requested_attack)
	requested_attack = null


func Update(_delta: float) -> void:
	pass


func PhysicsUpdate(_delta: float) -> void:
	if current_attack == null:
		return

	if player.is_dead or player.isStunned:
		return

	# Landing immediately cancels aerial attacks.
	if try_landing_cancel():
		return

	# Buffer jump input.
	if current_attack.jump_cancelable:
		if InputMap.has_action(jump_input):
			if Input.is_action_just_pressed(jump_input):
				jump_buffered = true
				jump_buffer_remaining = jump_buffer_frames + 1

	# Buffer attack inputs.
	if InputMap.has_action(light_input):
		if Input.is_action_just_pressed(light_input):
			buffer_input(&"light")

	if InputMap.has_action(heavy_input):
		if Input.is_action_just_pressed(heavy_input):
			buffer_input(&"heavy")

	# Jump cancel takes priority.
	if try_jump_cancel():
		return

	if try_combo_cancel():
		return

	# Update jump buffer.
	if jump_buffered and not hold_jump_buffer_until_cancel:
		jump_buffer_remaining -= 1

		if jump_buffer_remaining <= 0:
			jump_buffered = false
			jump_buffer_remaining = 0

	# Update attack buffer.
	if buffer_frames_remaining > 0:
		buffer_frames_remaining -= 1

		if buffer_frames_remaining <= 0:
			buffered_input = &""

	# Finish attack.
	if attack_finished:
		return_to_movement()


func Exit() -> void:
	current_attack = null
	requested_attack = null

	hit_confirmed = false

	buffered_input = &""
	buffer_frames_remaining = 0

	jump_buffered = false
	jump_buffer_remaining = 0

	attack_finished = false
	attack_started = false
	attack_started_airborne = false

	player.isAttacking = false

#endregion


#region Attack Handling

func start_attack(attack: AttackData) -> void:
	if attack == null:
		return

	current_attack = attack

	hit_confirmed = false

	buffered_input = &""
	buffer_frames_remaining = 0

	jump_buffered = false
	jump_buffer_remaining = 0

	attack_finished = false
	attack_started = true

	# Remember whether this attack began in the air.
	attack_started_airborne = (
		attack.air_only or not player.is_on_floor()
	)

	player.isAttacking = true

	if attack.lock_horizontal_movement:
		player.velocity.x = 0.0

	if player.anim == null:
		attack_finished = true
		return

	if player.anim.sprite_frames == null:
		attack_finished = true
		return

	if not player.anim.sprite_frames.has_animation(
		attack.animation_name
	):
		push_warning(
			"Missing attack animation: " +
			str(attack.animation_name)
		)
		attack_finished = true
		return

	player.anim.play(attack.animation_name)
	player.anim.set_frame_and_progress(0, 0.0)


func is_attack_allowed(attack: AttackData) -> bool:
	if attack == null:
		return false

	if attack.ground_only and not player.is_on_floor():
		return false

	if attack.air_only and player.is_on_floor():
		return false

	return true

#endregion


#region Landing Cancel

func try_landing_cancel() -> bool:
	if not enable_landing_cancel:
		return false

	if current_attack == null:
		return false

	# Ground attacks should never be landing-canceled.
	if not attack_started_airborne:
		return false

	# Wait until the character actually lands.
	if not player.is_on_floor():
		return false

	# Stop the aerial attack animation immediately.
	if player.anim:
		player.anim.stop()

	# Clear the attack before changing states.
	# This also prevents further combo cancels.
	attack_finished = true
	player.isAttacking = false

	return_to_movement()
	return true

#endregion


#region Hit Confirmation

func notify_hit_confirmed(
	attack_animation: StringName
) -> void:
	if current_attack == null:
		return

	if attack_animation != current_attack.animation_name:
		return

	hit_confirmed = true

	# Immediately check for a buffered jump.
	if jump_buffered:
		try_jump_cancel()

#endregion


#region Input Buffer

func buffer_input(attack_type: StringName) -> void:
	buffered_input = attack_type
	buffer_frames_remaining = input_buffer_frames + 1

#endregion


#region Jump Cancel

func try_jump_cancel() -> bool:
	if current_attack == null:
		return false

	if not current_attack.jump_cancelable:
		return false

	if not jump_buffered:
		return false

	if not player.is_on_floor():
		return false

	if not is_inside_cancel_window():
		return false

	if current_attack.require_hit_to_cancel:
		if not hit_confirmed:
			return false

	var direction: float = Input.get_axis(
		"ui_left",
		"ui_right"
	)

	jump_buffered = false
	jump_buffer_remaining = 0

	player.start_jump(direction)
	player.isAttacking = false

	transition_to("jump")
	return true

#endregion


#region Combo Cancel

func try_combo_cancel() -> bool:
	if current_attack == null:
		return false

	if buffered_input == &"":
		return false

	if buffer_frames_remaining <= 0:
		return false

	if not is_inside_cancel_window():
		return false

	if current_attack.require_hit_to_cancel:
		if not hit_confirmed:
			return false

	var next_attack: AttackData

	match buffered_input:
		&"light":
			next_attack = current_attack.next_light_attack

		&"heavy":
			next_attack = current_attack.next_heavy_attack

		_:
			return false

	if next_attack == null:
		return false

	if not is_attack_allowed(next_attack):
		return false

	start_attack(next_attack)
	return true

#endregion


#region Cancel Window

func is_inside_cancel_window() -> bool:
	if current_attack == null:
		return false

	if player.anim == null:
		return false

	if player.anim.animation != current_attack.animation_name:
		return false

	var current_frame: int = player.anim.frame

	if current_frame < current_attack.cancel_start_frame:
		return false

	if current_frame > current_attack.cancel_end_frame:
		return false

	return true

#endregion


#region Animation Signals

func _on_animation_finished() -> void:
	if current_attack == null:
		return

	if player.anim == null:
		return

	if player.anim.animation != current_attack.animation_name:
		return

	attack_finished = true

#endregion


#region Movement Transitions

func return_to_movement() -> void:
	if player.is_dead or player.isStunned:
		return

	if not player.is_on_floor():
		player.jump_horizontal_velocity = player.velocity.x
		transition_to("jump")
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


#region Hitbox Signals

func _on_light_1_hit_confirmed(
	attack_animation: StringName
) -> void:
	notify_hit_confirmed(attack_animation)


func _on_light_2_hit_confirmed(
	attack_animation: StringName
) -> void:
	notify_hit_confirmed(attack_animation)


func _on_light_3_hit_confirmed(
	attack_animation: StringName
) -> void:
	notify_hit_confirmed(attack_animation)


func _on_air_light_1_hit_confirmed(
	attack_animation: StringName
) -> void:
	notify_hit_confirmed(attack_animation)

#endregion
