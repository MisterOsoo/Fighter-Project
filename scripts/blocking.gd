
@tool
extends Area2D
class_name BlockComponent

signal block_started
signal block_ended
signal attack_blocked

enum ShapeType {
	RECTANGLE,
	CIRCLE,
	CAPSULE
}

#region Inspector

@export_group("Collision")
@export var shape_type: ShapeType = ShapeType.RECTANGLE

@export_tool_button("Add Collision Shape")
var add_shape_button = add_collision_shape

@export_group("Input")
@export var left_input: StringName = &"ui_left"
@export var right_input: StringName = &"ui_right"

@export_group("Animation")
@export var block_animation: String = "block"

#endregion


#region References

var player: CharacterBody2D
var anim: AnimatedSprite2D

#endregion


#region State

var is_blocking: bool = false

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


#region Blocking

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


func can_block() -> bool:
	if player == null:
		return false

	if player.get("is_dead") == true:
		return false

	if player.get("isStunned") == true:
		return false

	if player.get("isAttacking") == true:
		return false

	if not player.is_on_floor():
		return false

	return is_holding_back()


func try_block_hit(attacker: Node2D = null) -> bool:
	if not can_block():
		return false

	# If the attacking hitbox is known, it must overlap
	# the block area.
	if attacker != null:
		if attacker is Area2D:
			if not overlaps_area(attacker as Area2D):
				return false
		else:
			return false

	is_blocking = true

	if player:
		player.velocity.x = 0.0

	if anim and anim.sprite_frames:
		if anim.sprite_frames.has_animation(block_animation):
			anim.play(block_animation)

	block_started.emit()
	attack_blocked.emit()

	return true


func end_block() -> void:
	if not is_blocking:
		return

	is_blocking = false
	block_ended.emit()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or player == null:
		return

	if is_blocking:
		if not can_block():
			end_block()
		elif anim and anim.sprite_frames:
			if anim.sprite_frames.has_animation(block_animation):
				if anim.animation != block_animation:
					anim.play(block_animation)

#endregion
