
@tool
extends Area2D
class_name BlockComponent


#region Signals

signal block_started
signal block_ended
signal attack_blocked

#endregion


#region Collision Settings

enum ShapeType {
	RECTANGLE,
	CIRCLE,
	CAPSULE
}

@export_group("Collision")
@export var shape_type: ShapeType = ShapeType.RECTANGLE

@export_tool_button("Add Collision Shape")
var add_shape_button = add_collision_shape

#endregion


#region Input Settings

@export_group("Input")
@export var left_input: StringName = &"ui_left"
@export var right_input: StringName = &"ui_right"

#endregion


#region Animation Settings

@export_group("Animation")
@export var block_animation: String = "block"

#endregion


#region Blockstun Settings

@export_group("Blockstun")

@export_range(0.0, 5.0, 0.01, "or_greater")
var blockstun_duration: float = 0.2

#endregion


#region References

var player: CharacterBody2D
var anim: AnimatedSprite2D

#endregion


#region State

var is_blocking: bool = false
var blockstun_timer: float = 0.0

#endregion


#region Initialization

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	player = get_parent() as CharacterBody2D

	if player:
		anim = player.get("anim") as AnimatedSprite2D

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
		ShapeType.RECTANGLE:
			collision.shape = RectangleShape2D.new()

		ShapeType.CIRCLE:
			collision.shape = CircleShape2D.new()

		ShapeType.CAPSULE:
			collision.shape = CapsuleShape2D.new()

	add_child(collision)
	collision.owner = owner

#endregion


#region Directional Blocking

func is_holding_back() -> bool:
	if player == null:
		return false

	var opponent: CharacterBody2D = (
		player.get("opponent") as CharacterBody2D
	)

	if not is_instance_valid(opponent):
		return false

	var difference: float = (
		opponent.global_position.x - player.global_position.x
	)

	if absf(difference) < 0.01:
		return false

	if difference > 0.0:
		return Input.is_action_pressed(left_input)

	return Input.is_action_pressed(right_input)


func is_attack_from_front(attacker: Node2D) -> bool:
	if player == null or attacker == null:
		return false

	var attacker_position: Vector2 = attacker.global_position

	var attacking_character: Node2D = (
		attacker.get("character") as Node2D
	)

	if is_instance_valid(attacking_character):
		attacker_position = attacking_character.global_position

	var difference: float = (
		attacker_position.x - player.global_position.x
	)

	var facing: int = int(player.get("facing_direction"))

	return difference * float(facing) >= 0.0

#endregion


#region Block Eligibility

func can_block() -> bool:
	if player == null:
		return false

	if player.get("is_dead") == true:
		return false

	if player.get("isStunned") == true:
		return false

	if not player.is_on_floor():
		return false

	# Keep blocking during active blockstun,
	# even if the player releases back.
	if is_blocking and blockstun_timer > 0.0:
		return true

	if player.get("isAttacking") == true:
		return false

	return is_holding_back()

#endregion


#region Attack Blockstun Lookup

func get_attack_blockstun(attacker: Node2D) -> float:
	var duration: float = blockstun_duration

	if attacker == null:
		return duration

	# First preference: blockstun on the hitbox.
	if attacker is activeFrameHitbox:
		var hitbox: activeFrameHitbox = (
			attacker as activeFrameHitbox
		)

		duration = maxf(hitbox.blockstun_duration, 0.0)

	# Second preference: matching AttackData.
	var attacking_character: Node = (
		attacker.get("character") as Node
	)

	if not is_instance_valid(attacking_character):
		return duration

	var attacking_fsm: FiniteStateMachine = (
		attacking_character.get("fsm") as FiniteStateMachine
	)

	if attacking_fsm == null:
		return duration

	var attack_state: AttackState = (
		attacking_fsm.current_state as AttackState
	)

	if attack_state == null:
		return duration

	var attack_data: AttackData = attack_state.current_attack

	if attack_data == null:
		return duration

	# Only use AttackData if it matches the hitbox.
	if attacker is activeFrameHitbox:
		var active_hitbox: activeFrameHitbox = (
			attacker as activeFrameHitbox
		)

		if StringName(active_hitbox.attack_animation) != (
			attack_data.animation_name
		):
			return duration

	return maxf(attack_data.blockstun_duration, 0.0)

#endregion


#region Hit Blocking

func try_block_hit(attacker: Node2D = null) -> bool:
	if not can_block():
		return false

	if attacker == null:
		return false

	if not is_attack_from_front(attacker):
		return false

	if not attacker is Area2D:
		return false

	if not overlaps_area(attacker as Area2D):
		return false

	var new_blockstun: float = get_attack_blockstun(attacker)

	if not is_blocking:
		is_blocking = true
		block_started.emit()

	# Refresh blockstun for every blocked attack.
	blockstun_timer = new_blockstun

	player.velocity.x = 0.0

	play_block_animation()
	attack_blocked.emit()

	var player_fsm: FiniteStateMachine = (
		player.get("fsm") as FiniteStateMachine
	)

	if player_fsm:
		if not (player_fsm.current_state is BlockState):
			player_fsm.transition_to("block")

	return true

#endregion


#region Block Ending

func end_block(force: bool = false) -> void:
	if not is_blocking:
		return

	if blockstun_timer > 0.0 and not force:
		return

	is_blocking = false
	blockstun_timer = 0.0

	block_ended.emit()

#endregion


#region Animation Handling

func play_block_animation() -> void:
	if anim == null or anim.sprite_frames == null:
		return

	if not anim.sprite_frames.has_animation(block_animation):
		return

	if anim.animation != block_animation or not anim.is_playing():
		anim.play(block_animation)

#endregion


#region Physics

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or player == null:
		return

	if blockstun_timer > 0.0:
		blockstun_timer = maxf(
			blockstun_timer - delta,
			0.0
		)

#endregion
