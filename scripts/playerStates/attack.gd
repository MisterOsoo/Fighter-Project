
extends State
class_name AttackState


#region Attack Settings

@export_group("Attacks")

@export var light_attack: AttackData
@export var heavy_attack: AttackData

#endregion


#region Input Settings

@export_group("Input")

@export var light_input: StringName = &"lightAtk"
@export var heavy_input: StringName = &"heavyAtk"

#endregion


#region Combo Settings

@export_group("Combo")

@export_range(0, 20, 1)
var input_buffer_frames: int = 4

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

var attack_finished: bool = false
var attack_started: bool = false

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
	if attack_type == &"light":
		requested_attack = light_attack

	elif attack_type == &"heavy":
		requested_attack = heavy_attack

	else:
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

	if Input.is_action_just_pressed(light_input):
		buffer_input(&"light")

	elif Input.is_action_just_pressed(heavy_input):
		buffer_input(&"heavy")

	# Evaluate the buffered input before expiring it.
	if try_combo_cancel():
		return

	if buffer_frames_remaining > 0:
		buffer_frames_remaining -= 1

		if buffer_frames_remaining <= 0:
			buffered_input = &""

	if attack_finished:
		return_to_movement()


func Exit() -> void:
	current_attack = null
	requested_attack = null

	hit_confirmed = false
	buffered_input = &""
	buffer_frames_remaining = 0

	attack_finished = false
	attack_started = false

	player.isAttacking = false

#endregion


#region Attack Execution

func start_attack(attack: AttackData) -> void:
	if attack == null:
		return

	current_attack = attack

	hit_confirmed = false
	buffered_input = &""
	buffer_frames_remaining = 0

	attack_finished = false
	attack_started = true

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

	# Always restart the animation, including
	# when an attack is reused.
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


#region Hit Confirmation

func notify_hit_confirmed(
	attack_animation: StringName
) -> void:
	if current_attack == null:
		return

	if attack_animation != current_attack.animation_name:
		return

	hit_confirmed = true

#endregion


#region Combo Handling

func buffer_input(attack_type: StringName) -> void:
	buffered_input = attack_type
	buffer_frames_remaining = input_buffer_frames + 1


func try_combo_cancel() -> bool:
	if current_attack == null:
		return false

	if buffered_input == &"":
		return false

	if buffer_frames_remaining <= 0:
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


#region Animation Handling

func _on_animation_finished() -> void:
	if current_attack == null:
		return

	if player.anim == null:
		return

	if player.anim.animation != current_attack.animation_name:
		return

	attack_finished = true

#endregion


#region State Transitions

func return_to_movement() -> void:
	if player.is_dead or player.isStunned:
		return

	if not player.is_on_floor():
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


func _on_light_1_hit_confirmed(attack_animation: StringName) -> void:
	notify_hit_confirmed(attack_animation)


func _on_light_2_hit_confirmed(attack_animation: StringName) -> void:
	notify_hit_confirmed(attack_animation)


func _on_light_3_hit_confirmed(attack_animation: StringName) -> void:
	notify_hit_confirmed(attack_animation)
