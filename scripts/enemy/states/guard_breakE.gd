
extends State
class_name EnemyGuardBreakState


#region References

@export_group("References")
@export var enemy: BaseEnemy
@export var block_component: BlockComponent

#endregion


#region Guard Break Flash

@export_group("Guard Break Flash")

@export var enable_guard_break_flash: bool = true
@export var flash_color: Color = Color(1.0, 0.5, 0.0, 1.0)

@export_range(0.02, 1.0, 0.01)
var flash_interval: float = 0.1

#endregion


#region Internal Variables

var flash_timer: float = 0.0
var flash_active: bool = false
var original_modulate: Color = Color.WHITE

#endregion


#region Initialization

func _ready() -> void:
	if enemy == null:
		enemy = get_parent().get_parent() as BaseEnemy

	if enemy and block_component == null:
		block_component = enemy.block_component

	if block_component:
		if not block_component.guard_break_recovered.is_connected(
			_on_recovered
		):
			block_component.guard_break_recovered.connect(
				_on_recovered
			)

#endregion


#region State Functions

func Enter() -> void:
	if enemy == null or block_component == null:
		return

	enemy.isAttacking = false
	enemy.movement_direction = 0.0
	enemy.velocity.x = 0.0

	block_component.play_guard_break_animation()

	start_guard_break_flash()


func Update(delta: float) -> void:
	if enemy == null or enemy.is_dead:
		stop_guard_break_flash()
		return

	if block_component == null:
		stop_guard_break_flash()
		return

	if not block_component.is_guard_broken:
		stop_guard_break_flash()
		return

	update_guard_break_flash(delta)


func PhysicsUpdate(_delta: float) -> void:
	if enemy == null or enemy.is_dead or block_component == null:
		return

	enemy.velocity.x = 0.0

	if not block_component.is_guard_broken:
		finish_recovery()


func Exit() -> void:
	stop_guard_break_flash()

#endregion


#region Guard Break Flash

func start_guard_break_flash() -> void:
	if enemy == null or enemy.visuals == null:
		return

	original_modulate = enemy.visuals.modulate
	flash_timer = 0.0
	flash_active = false

	if not enable_guard_break_flash:
		return

	flash_active = true
	enemy.visuals.modulate = flash_color


func update_guard_break_flash(delta: float) -> void:
	if not enable_guard_break_flash:
		return

	if enemy == null or enemy.visuals == null:
		return

	flash_timer += delta

	if flash_timer < flash_interval:
		return

	flash_timer = 0.0
	flash_active = not flash_active

	if flash_active:
		enemy.visuals.modulate = flash_color
	else:
		enemy.visuals.modulate = original_modulate


func stop_guard_break_flash() -> void:
	flash_timer = 0.0
	flash_active = false

	if enemy and enemy.visuals:
		enemy.visuals.modulate = original_modulate

#endregion


#region Recovery

func _on_recovered() -> void:
	if fsm and fsm.current_state == self:
		finish_recovery()


func finish_recovery() -> void:
	if enemy == null or enemy.is_dead or block_component == null:
		return

	if block_component.is_guard_broken:
		return

	if fsm == null or fsm.current_state != self:
		return

	stop_guard_break_flash()

	if enemy.isStunned:
		fsm.transition_to("hurt", true)

	elif is_zero_approx(enemy.movement_direction):
		fsm.transition_to("idle", true)

	else:
		fsm.transition_to("move", true)

#endregion
