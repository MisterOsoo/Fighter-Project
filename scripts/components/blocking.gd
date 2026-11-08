@tool
extends Area2D
class_name BlockComponent

#region Signals
signal block_started
signal block_ended
signal attack_blocked
signal guard_broken
signal guard_break_recovered
#endregion

#region Collision Settings
enum ShapeType { RECTANGLE, CIRCLE, CAPSULE }
@export_group("Collision")
@export var shape_type: ShapeType = ShapeType.RECTANGLE
@export_tool_button("Add Collision Shape")
var add_shape_button = add_collision_shape
#endregion

#region Input Settings
@export_group("Input")
@export var use_player_input: bool = true
@export var left_input: StringName = &"ui_left"
@export var right_input: StringName = &"ui_right"
@export var down_input: StringName = &"ui_down"
#endregion

#region Animation Settings
@export_group("Animation")
@export var block_animation: String = "block"
@export var crouch_block_animation: String = "crouchblock"
@export var guard_break_animation: String = "guardbreak"
#endregion

#region Blockstun Settings
@export_group("Blockstun")
@export_range(0.0, 5.0, 0.01, "or_greater")
var blockstun_duration: float = 0.2
#endregion

#region Guard Meter Settings
@export_group("Guard Meter")
@export var special_meter: specialMeterComponent
@export_range(0.0, 1000.0, 1.0)
var default_block_meter_damage: float = 10.0
#endregion

#region Guard Break Settings
@export_group("Guard Break")
@export_range(0.0, 10.0, 0.1)
var guard_break_stun_duration: float = 1.5
@export_range(0.0, 100.0, 1.0)
var guard_break_recovery_percent: float = 50.0
#endregion

#region Block Flash Settings
@export_group("Block Flash")
@export var enable_block_flash: bool = true
@export var block_flash_color: Color = Color(0.2, 0.55, 1.0, 1.0)
@export_range(0.01, 1.0, 0.01, "or_greater")
var block_flash_duration: float = 0.12
#endregion

#region References
var player: CharacterBody2D
var anim: AnimatedSprite2D
#endregion

#region State
var is_blocking: bool = false
var is_crouch_blocking: bool = false
var blockstun_timer: float = 0.0
var is_guard_broken: bool = false
var guard_break_timer: float = 0.0
var ai_wants_to_block: bool = false
var ai_wants_to_crouch_block: bool = false
var block_flash_timer: float = 0.0
var block_flash_original_modulate: Color = Color.WHITE
var block_flash_active: bool = false
#endregion

#region Initialization
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	player = get_parent() as CharacterBody2D
	if player:
		anim = player.get("anim") as AnimatedSprite2D
		if special_meter == null:
			for child in player.get_children():
				if child is specialMeterComponent:
					special_meter = child as specialMeterComponent
					break
	monitoring = true
	monitorable = false
#endregion

#region Collision Shape
func add_collision_shape() -> void:
	if not Engine.is_editor_hint():
		return
	if get_node_or_null("BlockCollision"):
		push_warning("BlockCollision already exists!")
		return
	var collision := CollisionShape2D.new()
	collision.name = "BlockCollision"
	collision.debug_color = Color(0.2, 0.6, 1.0, 0.3)
	match shape_type:
		ShapeType.RECTANGLE: collision.shape = RectangleShape2D.new()
		ShapeType.CIRCLE: collision.shape = CircleShape2D.new()
		ShapeType.CAPSULE: collision.shape = CapsuleShape2D.new()
	add_child(collision)
	collision.owner = owner
#endregion

#region Directional Blocking
func is_holding_back() -> bool:
	if player == null:
		return false
	if not use_player_input:
		return ai_wants_to_block
	var opponent: CharacterBody2D = player.get("opponent") as CharacterBody2D
	if not is_instance_valid(opponent):
		return false
	var difference: float = opponent.global_position.x - player.global_position.x
	if absf(difference) < 0.01:
		return false
	if difference > 0.0:
		return Input.is_action_pressed(left_input)
	return Input.is_action_pressed(right_input)

func is_holding_down() -> bool:
	if not use_player_input:
		return ai_wants_to_crouch_block
	return Input.is_action_pressed(down_input)

func is_attack_from_front(attacker: Node2D) -> bool:
	if player == null or attacker == null:
		return false
	var attacker_position: Vector2 = attacker.global_position
	var attacking_character: Node2D = attacker.get("character") as Node2D
	if is_instance_valid(attacking_character):
		attacker_position = attacking_character.global_position
	var difference: float = attacker_position.x - player.global_position.x
	var facing: int = int(player.get("facing_direction"))
	return difference * float(facing) >= 0.0
#endregion

#region AI Blocking
func request_ai_block(enabled: bool, crouching: bool = false) -> void:
	ai_wants_to_block = enabled
	ai_wants_to_crouch_block = enabled and crouching

func clear_ai_block() -> void:
	ai_wants_to_block = false
	ai_wants_to_crouch_block = false
#endregion

#region Block Eligibility
func can_block() -> bool:
	if player == null or is_guard_broken:
		return false
	if player.get("is_dead") == true:
		return false
	if not player.is_on_floor():
		return false
	# A block already in progress can absorb additional hits during blockstun.
	if is_blocking and blockstun_timer > 0.0:
		return true
	if player.get("isStunned") == true or player.get("isAttacking") == true:
		return false
	return is_holding_back()
#endregion

#region Attack Blockstun Lookup
func get_attack_blockstun(attacker: Node2D) -> float:
	var duration: float = blockstun_duration
	if attacker == null:
		return duration
	if attacker is activeFrameHitbox:
		var hitbox: activeFrameHitbox = attacker as activeFrameHitbox
		duration = maxf(hitbox.blockstun_duration, 0.0)
	var attacking_character: Node = attacker.get("character") as Node
	if not is_instance_valid(attacking_character):
		return duration
	var attacking_fsm: FiniteStateMachine = attacking_character.get("fsm") as FiniteStateMachine
	if attacking_fsm == null:
		return duration
	# Both player and enemy attack states expose current_attack.
	var current_state: State = attacking_fsm.current_state
	if current_state == null:
		return duration
	if not (current_state is AttackState or current_state is EnemyAttackState):
		return duration
	var attack_data: AttackData = current_state.get("current_attack") as AttackData
	if attack_data == null:
		return duration
	if attacker is activeFrameHitbox:
		var active_hitbox: activeFrameHitbox = attacker as activeFrameHitbox
		if StringName(active_hitbox.attack_animation) != attack_data.animation_name:
			return duration
	return maxf(attack_data.blockstun_duration, 0.0)
#endregion

#region Guard Meter
func get_block_meter_damage(_attacker: Node2D) -> float:
	return maxf(default_block_meter_damage, 0.0)

func consume_block_meter(amount: float) -> void:
	if not is_instance_valid(special_meter):
		return
	var remaining: float = special_meter.current_resource
	var cost: float = minf(maxf(amount, 0.0), remaining)
	if cost > 0.0:
		special_meter.consume_resource(cost)
#endregion

#region Hit Blocking
func try_block_hit(attacker: Node2D = null) -> bool:
	if not can_block() or attacker == null:
		return false
	if not is_attack_from_front(attacker):
		return false
	if not attacker is Area2D:
		return false
	if not overlaps_area(attacker as Area2D):
		return false
	# Zero meter BEFORE this hit causes guard break.
	if is_instance_valid(special_meter) and special_meter.current_resource <= 0.0:
		trigger_guard_break()
		return true
	var new_blockstun: float = get_attack_blockstun(attacker)
	if not is_blocking:
		is_crouch_blocking = is_holding_down()
		is_blocking = true
		block_started.emit()
	blockstun_timer = new_blockstun
	if player:
		player.velocity.x = 0.0
	consume_block_meter(get_block_meter_damage(attacker))
	attack_blocked.emit()
	trigger_block_flash()
	var player_fsm: FiniteStateMachine = player.get("fsm") as FiniteStateMachine
	if player_fsm and not (player_fsm.current_state is BlockState or player_fsm.current_state is EnemyBlockState):
		if player_fsm.states.has("block"):
			player_fsm.transition_to("block", true)
	return true
#endregion

#region Guard Break
func trigger_guard_break() -> void:
	if is_guard_broken:
		return
	end_block(true)
	clear_ai_block()
	is_guard_broken = true
	guard_break_timer = maxf(guard_break_stun_duration, 0.0)
	if player:
		player.velocity.x = 0.0
	# GuardBreakState receives this signal and owns the animation.
	guard_broken.emit()
	if player is BaseEnemy:
		var enemy_fsm: FiniteStateMachine = player.get("fsm") as FiniteStateMachine
		if enemy_fsm and enemy_fsm.states.has("guardbreak"):
			enemy_fsm.transition_to("guardbreak", true)
	if guard_break_timer <= 0.0:
		recover_from_guard_break()

# Pass false when an incoming hit must transition directly into HurtState.
func recover_from_guard_break(emit_recovery_signal: bool = true) -> void:
	if not is_guard_broken:
		return
	guard_break_timer = 0.0
	is_guard_broken = false
	if is_instance_valid(special_meter):
		var restored_amount: float = special_meter.max_resource * guard_break_recovery_percent / 100.0
		special_meter.set_resource(restored_amount)
	if emit_recovery_signal:
		guard_break_recovered.emit()
#endregion

#region Block Ending
func end_block(force: bool = false) -> void:
	if not is_blocking:
		return
	if blockstun_timer > 0.0 and not force:
		return
	is_blocking = false
	is_crouch_blocking = false
	blockstun_timer = 0.0
	block_ended.emit()
#endregion

#region Animation Handling
func play_block_animation() -> void:
	if anim == null or anim.sprite_frames == null:
		return
	var animation_name: String = crouch_block_animation if is_crouch_blocking else block_animation
	if not anim.sprite_frames.has_animation(animation_name):
		return
	if anim.animation != animation_name or not anim.is_playing():
		anim.play(animation_name)

func play_guard_break_animation() -> void:
	if anim == null or anim.sprite_frames == null:
		return
	if not anim.sprite_frames.has_animation(guard_break_animation):
		return
	anim.play(guard_break_animation)
#endregion

#region Block Flash
func trigger_block_flash() -> void:
	if not enable_block_flash or not is_instance_valid(anim):
		return
	if not block_flash_active:
		block_flash_original_modulate = anim.modulate
	block_flash_active = true
	block_flash_timer = maxf(block_flash_duration, 0.01)
	anim.modulate = block_flash_original_modulate * block_flash_color

func update_block_flash(delta: float) -> void:
	if not block_flash_active:
		return
	if not is_instance_valid(anim):
		block_flash_active = false
		block_flash_timer = 0.0
		return
	block_flash_timer = maxf(block_flash_timer - delta, 0.0)
	if block_flash_timer <= 0.0:
		anim.modulate = block_flash_original_modulate
		block_flash_active = false

func _exit_tree() -> void:
	if block_flash_active and is_instance_valid(anim):
		anim.modulate = block_flash_original_modulate
	block_flash_active = false
#endregion

#region Physics
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	update_block_flash(delta)
	if is_guard_broken:
		guard_break_timer = maxf(guard_break_timer - delta, 0.0)
		player.velocity.x = 0.0
		if guard_break_timer <= 0.0:
			recover_from_guard_break()
		return
	if blockstun_timer > 0.0:
		blockstun_timer = maxf(blockstun_timer - delta, 0.0)
#endregion
