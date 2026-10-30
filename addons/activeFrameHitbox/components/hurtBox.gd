
@tool
@icon("res://addons/activeFrameHitbox/icons/hurtbox.svg")
extends Area2D
class_name Hurtbox

signal damage_received(amount: int)
signal hitstun_received(duration: float)
signal knockback_received(impulse: Vector2, duration: float)

#region Collision Settings

enum ShapeType {
	RECTANGLE,
	CIRCLE,
	CAPSULE
}

@export var shape_type: ShapeType = ShapeType.RECTANGLE

@export_tool_button("Add Collision Shape")
var add_shape_button = add_collision_shape

#endregion


#region References

@export var character: CharacterBody2D
@export var health_component: HealthComponent

#endregion


#region Collision Shape

func add_collision_shape() -> void:
	if not Engine.is_editor_hint():
		return

	if get_node_or_null("HurtboxCollision"):
		push_warning("A collision shape already exists!")
		return

	var collision := CollisionShape2D.new()
	collision.name = "HurtboxCollision"
	collision.debug_color = Color(1.0, 0.41, 0.71, 0.3)

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


#region Hit Reception

func receive_hit(
	damage: int,
	knockback: float = 0.0,
	knockup: float = 0.0,
	attacker_position: Vector2 = Vector2.ZERO,
	knockback_duration: float = 0.18,
	hitstun_duration: float = 0.0,
	launch_gravity_multiplier: float = 0.4,
	launch_max_fall_speed: float = 250.0,
	attacking_hitbox: Area2D = null
) -> bool:

	if character == null:
		return false

	if character.get("is_dead") == true:
		return false

	# Check whether the attack was blocked.
	if attacking_hitbox:
		var block_component: Node = (
			character.get_node_or_null("BlockComponent")
		)

		if block_component:
			if block_component.has_method("try_block_hit"):
				if block_component.call(
					"try_block_hit",
					attacking_hitbox
				):
					return false

	# The attack successfully landed.
	damage_received.emit(damage)

	if health_component:
		health_component.take_damage(damage)

	var direction: float = (
		1.0 if character.global_position.x >= attacker_position.x
		else -1.0
	)

	var impulse := Vector2(
		direction * knockback,
		-knockup
	)

	if character.has_method("receive_combat_hit"):
		character.call(
			"receive_combat_hit",
			impulse,
			knockback_duration,
			hitstun_duration,
			launch_gravity_multiplier,
			launch_max_fall_speed
		)
	else:
		if knockback != 0.0 or knockup != 0.0:
			knockback_received.emit(
				impulse,
				knockback_duration
			)

		if hitstun_duration > 0.0:
			hitstun_received.emit(hitstun_duration)

	return true

#endregion
