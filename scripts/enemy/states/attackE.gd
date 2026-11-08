
extends State
class_name EnemyAttackState


#region Attack Settings

@export_group("Ground Attacks")
@export var light_attack: AttackData
@export var heavy_attack: AttackData

@export_group("Air Attacks")
@export var air_light_attack: AttackData
@export var air_heavy_attack: AttackData

#endregion


#region Combo Settings

@export_group("Combo")

@export_range(0, 20, 1)
var input_buffer_frames: int = 4

#endregion


#region References

@onready var enemy: BaseEnemy = (
	get_parent().get_parent() as BaseEnemy
)

#endregion


#region Internal Variables

var current_attack: AttackData
var requested_attack: AttackData

var hit_confirmed: bool = false

var buffered_input: StringName = &""
var buffer_frames_remaining: int = 0

var attack_finished: bool = false

#endregion


#region Initialization

func _ready() -> void:
	if enemy == null:
		push_error("EnemyAttackState requires BaseEnemy.")
		return

	if enemy.anim:
		if not enemy.anim.animation_finished.is_connected(
			_on_animation_finished
		):
			enemy.anim.animation_finished.connect(
				_on_animation_finished
			)

	connect_hitbox_signals()

#endregion


#region Hitbox Connections

func connect_hitbox_signals() -> void:
	if enemy == null:
		return

	for node in enemy.find_children(
		"*",
		"activeFrameHitbox",
		true,
		false
	):
		var hitbox: activeFrameHitbox = (
			node as activeFrameHitbox
		)

		if hitbox == null:
			continue

		if not hitbox.hit_confirmed.is_connected(
			notify_hit_confirmed
		):
			hitbox.hit_confirmed.connect(
				notify_hit_confirmed
			)

#endregion


#region Attack Requests

func request_attack(attack_type: StringName) -> bool:
	if enemy == null:
		return false

	if enemy.is_dead or enemy.isStunned:
		return false

	if enemy.isAttacking:
		return false

	if enemy.fsm == null:
		return false

	if enemy.fsm.current_state == self:
		return false

	var airborne: bool = not enemy.is_on_floor()

	match attack_type:
		&"light":
			requested_attack = (
				air_light_attack if airborne else light_attack
			)

		&"heavy":
			requested_attack = (
				air_heavy_attack if airborne else heavy_attack
			)

		_:
			requested_attack = null

	if not is_attack_allowed(requested_attack):
		requested_attack = null
		return false

	enemy.fsm.transition_to("attack")

	# Return whether the FSM actually accepted the request.
	return enemy.fsm.current_state == self


func request_combo(attack_type: StringName) -> bool:
	if enemy == null or enemy.fsm == null:
		return false

	if enemy.fsm.current_state != self:
		return false

	if current_attack == null:
		return false

	if attack_type != &"light" and attack_type != &"heavy":
		return false

	buffered_input = attack_type
	buffer_frames_remaining = input_buffer_frames + 1

	return true

#endregion


#region State Functions

func Enter() -> void:
	if enemy == null:
		return

	if requested_attack == null:
		return_to_movement()
		return

	if enemy.is_dead or enemy.isStunned:
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
	if enemy == null:
		return

	if current_attack == null:
		return

	if enemy.is_dead or enemy.isStunned:
		return

	if try_combo_cancel():
		return

	if buffer_frames_remaining > 0:
		buffer_frames_remaining -= 1

		if buffer_frames_remaining <= 0:
			buffered_input = &""

	if attack_finished:
		return_to_movement()


func Exit() -> void:
	clear_hitbox_bounce_settings()

	current_attack = null
	requested_attack = null

	hit_confirmed = false

	buffered_input = &""
	buffer_frames_remaining = 0

	attack_finished = false

	if enemy:
		enemy.isAttacking = false

#endregion


#region Attack Handling

func start_attack(attack: AttackData) -> void:
	if attack == null:
		return

	current_attack = attack
	hit_confirmed = false

	buffered_input = &""
	buffer_frames_remaining = 0

	attack_finished = false

	enemy.isAttacking = true
	enemy.stop_movement()

	apply_hitbox_bounce_settings(attack)

	if attack.lock_horizontal_movement:
		enemy.velocity.x = 0.0

	if enemy.anim == null:
		attack_finished = true
		return

	if enemy.anim.sprite_frames == null:
		attack_finished = true
		return

	if not enemy.anim.sprite_frames.has_animation(
		attack.animation_name
	):
		push_warning(
			"Missing enemy attack animation: "
			+ str(attack.animation_name)
		)
		attack_finished = true
		return

	enemy.anim.play(attack.animation_name)
	enemy.anim.set_frame_and_progress(0, 0.0)


func is_attack_allowed(attack: AttackData) -> bool:
	if attack == null:
		return false

	if enemy == null:
		return false

	if attack.ground_only and not enemy.is_on_floor():
		return false

	if attack.air_only and enemy.is_on_floor():
		return false

	return true

#endregion


#region Hitbox Bounce Settings

func apply_hitbox_bounce_settings(attack: AttackData) -> void:
	for node in enemy.find_children(
		"*",
		"activeFrameHitbox",
		true,
		false
	):
		var hitbox: activeFrameHitbox = (
			node as activeFrameHitbox
		)

		if hitbox == null:
			continue

		if hitbox.attack_animation == str(
			attack.animation_name
		):
			hitbox.enable_ground_bounce = (
				attack.enable_ground_bounce
			)
			hitbox.bounce_speed = attack.bounce_speed
			hitbox.bounce_hitstun = attack.bounce_hitstun
		else:
			hitbox.enable_ground_bounce = false


func clear_hitbox_bounce_settings() -> void:
	if enemy == null:
		return

	for node in enemy.find_children(
		"*",
		"activeFrameHitbox",
		true,
		false
	):
		var hitbox: activeFrameHitbox = (
			node as activeFrameHitbox
		)

		if hitbox:
			hitbox.enable_ground_bounce = false

#endregion


#region Hit Confirmation

func notify_hit_confirmed(
	attack_animation: StringName
) -> void:
	if current_attack == null:
		return

	if enemy == null or enemy.anim == null:
		return

	if enemy.fsm == null:
		return

	if enemy.fsm.current_state != self:
		return

	if enemy.anim.animation != current_attack.animation_name:
		return

	if attack_animation != current_attack.animation_name:
		return

	hit_confirmed = true

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

	if not is_attack_allowed(next_attack):
		return false

	start_attack(next_attack)
	return true

#endregion


#region Cancel Window

func is_inside_cancel_window() -> bool:
	if current_attack == null:
		return false

	if enemy.anim == null:
		return false

	if enemy.anim.animation != current_attack.animation_name:
		return false

	var current_frame: int = enemy.anim.frame

	return (
		current_frame >= current_attack.cancel_start_frame
		and current_frame <= current_attack.cancel_end_frame
	)

#endregion


#region Animation Signals

func _on_animation_finished() -> void:
	if current_attack == null:
		return

	if enemy == null or enemy.anim == null:
		return

	if enemy.anim.animation != current_attack.animation_name:
		return

	attack_finished = true

#endregion


#region Movement Transitions

func return_to_movement() -> void:
	if enemy == null:
		return

	if enemy.is_dead or enemy.isStunned:
		return

	if enemy.fsm == null:
		return

	if not enemy.is_on_floor():
		if enemy.fsm.states.has("jump"):
			transition_to("jump")
		return

	if absf(enemy.movement_direction) > 0.01:
		transition_to("move")
	else:
		transition_to("idle")

#endregion
