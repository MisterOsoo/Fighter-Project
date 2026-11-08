
extends State
class_name GuardBreakState


#region Animation Settings

@export_group("Guard Break Animation")
@export var guard_break_animation: String = "guardbreak"

#endregion


#region Guard Break Flash

@export_group("Guard Break Flash")

@export var enable_guard_break_flash: bool = true
@export var flash_color: Color = Color(1.0, 0.5, 0.0, 1.0)

@export_range(0.02, 1.0, 0.01)
var flash_interval: float = 0.1

#endregion


#region References

@onready var player: BasePlayer = (
	get_parent().get_parent() as BasePlayer
)

@onready var block_component: BlockComponent = (
	player.block_component if player != null else null
)

#endregion


#region Internal State

var is_recovering: bool = false

var flash_timer: float = 0.0
var flash_active: bool = false
var original_modulate: Color = Color.WHITE

#endregion


#region Initialization

func _ready() -> void:
	if player == null:
		push_error("GuardBreakState: BasePlayer was not found.")
		return

	if block_component == null:
		block_component = player.get_node_or_null(
			"BlockComponent"
		) as BlockComponent

	if block_component == null:
		push_error("GuardBreakState: BlockComponent is not assigned.")
		return

	if not block_component.guard_broken.is_connected(
		_on_guard_broken
	):
		block_component.guard_broken.connect(
			_on_guard_broken
		)

	if not block_component.guard_break_recovered.is_connected(
		_on_guard_break_recovered
	):
		block_component.guard_break_recovered.connect(
			_on_guard_break_recovered
		)

#endregion


#region State Functions

func Enter() -> void:
	if player == null or player.is_dead:
		return

	is_recovering = false

	player.isAttacking = false
	player.isStunned = true

	player.velocity.x = 0.0
	player.jump_horizontal_velocity = 0.0

	player.knockback_timer = 0.0
	player.knockback_total_duration = 0.0
	player.knockback_start_speed = 0.0

	player.hitstun_timer = 0.0

	if player.dash_component:
		if player.dash_component.is_dashing:
			player.dash_component.stop_dash()

	if player.air_dash_component:
		if player.air_dash_component.is_air_dashing:
			player.air_dash_component.stop_air_dash()

	play_guard_break_animation()
	start_guard_break_flash()


func Update(delta: float) -> void:
	if fsm == null or fsm.current_state != self:
		return

	if player == null or player.is_dead:
		stop_guard_break_flash()
		return

	if block_component == null:
		stop_guard_break_flash()
		return

	if block_component.is_guard_broken:
		if player.anim != null:
			if player.anim.animation != guard_break_animation:
				play_guard_break_animation()

		update_guard_break_flash(delta)

	else:
		stop_guard_break_flash()


func PhysicsUpdate(_delta: float) -> void:
	if player == null or player.is_dead or block_component == null:
		return

	player.velocity.x = 0.0
	player.jump_horizontal_velocity = 0.0

	if block_component.is_guard_broken:
		player.isStunned = true
		return

	complete_recovery()


func Exit() -> void:
	stop_guard_break_flash()

	if player == null or player.is_dead:
		return

	if block_component != null and block_component.is_guard_broken:
		return

	# Preserve hitstun when an incoming hit interrupts Guard Break.
	if player.hitstun_timer <= 0.0:
		player.isStunned = false

#endregion


#region Guard Break Flash

func start_guard_break_flash() -> void:
	if player == null or player.visuals == null:
		return

	original_modulate = player.visuals.modulate

	flash_timer = 0.0
	flash_active = false

	if not enable_guard_break_flash:
		return

	flash_active = true
	player.visuals.modulate = flash_color


func update_guard_break_flash(delta: float) -> void:
	if not enable_guard_break_flash:
		return

	if player == null or player.visuals == null:
		return

	flash_timer += delta

	if flash_timer < flash_interval:
		return

	flash_timer = 0.0
	flash_active = not flash_active

	if flash_active:
		player.visuals.modulate = flash_color
	else:
		player.visuals.modulate = original_modulate


func stop_guard_break_flash() -> void:
	flash_timer = 0.0
	flash_active = false

	if player and player.visuals:
		player.visuals.modulate = original_modulate

#endregion


#region Guard Break Signals

func _on_guard_broken() -> void:
	if player == null or player.is_dead or fsm == null:
		return

	if fsm.current_state != self:
		fsm.transition_to("guardBreak", true)
	else:
		play_guard_break_animation()
		start_guard_break_flash()


func _on_guard_break_recovered() -> void:
	if player == null or player.is_dead or fsm == null:
		return

	if fsm.current_state == self:
		complete_recovery()

#endregion


#region Guard Break Animation

func play_guard_break_animation() -> void:
	if player == null or player.anim == null:
		return

	if player.anim.sprite_frames == null:
		return

	if not player.anim.sprite_frames.has_animation(
		guard_break_animation
	):
		push_warning(
			"GuardBreakState: Missing animation: " +
			guard_break_animation
		)
		return

	player.anim.play(guard_break_animation)

#endregion


#region Recovery

func complete_recovery() -> void:
	if is_recovering:
		return

	if player == null or player.is_dead or fsm == null:
		return

	if block_component != null and block_component.is_guard_broken:
		return

	if fsm.current_state != self:
		return

	is_recovering = true

	stop_guard_break_flash()

	player.isStunned = false
	player.hitstun_timer = 0.0

	if not player.is_on_floor():
		fsm.transition_to("jump")

	elif Input.is_action_pressed(player.crouch_input):
		fsm.transition_to("crouch")

	else:
		var direction: float = Input.get_axis(
			"ui_left",
			"ui_right"
		)

		fsm.transition_to(
			"idle" if is_zero_approx(direction) else "move"
		)

#endregion


#region Transition Rules

func can_transition_to(new_state: State) -> bool:
	if block_component != null and block_component.is_guard_broken:
		return new_state.name.to_lower() == "death"

	return true

#endregion
