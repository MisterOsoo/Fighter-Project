
@tool
@icon("res://addons/activeFrameHitbox/icons/hurtbox.svg")
extends Area2D
class_name Hurtbox


#region Signals

signal damage_received(amount: int)
signal hitstun_received(duration: float)
signal knockback_received(impulse: Vector2, duration: float)

#endregion


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
	attacking_hitbox: Area2D = null,
	ground_slam: bool = false,
	ground_slam_speed: float = 500.0,
	ground_bounce: bool = false,
	bounce_speed: float = 230.0,
	bounce_hitstun: float = 0.6
) -> bool:

	if not is_instance_valid(character):
		return false

	if character.get("is_dead") == true:
		return false

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

	damage_received.emit(damage)

	if health_component:
		health_component.take_damage(damage)

	if not is_instance_valid(character):
		return true

	if character.get("is_dead") == true:
		return true

	var direction: float = (
		1.0 if character.global_position.x >= attacker_position.x
		else -1.0
	)

	var impulse: Vector2 = Vector2(
		direction * knockback,
		-knockup
	)

	var apply_ground_slam: bool = (
		ground_slam and not character.is_on_floor()
	)

	if apply_ground_slam:
		impulse.y = maxf(ground_slam_speed, 0.0)

	if character.has_method("receive_combat_hit"):
		character.call(
			"receive_combat_hit",
			impulse,
			knockback_duration,
			hitstun_duration,
			launch_gravity_multiplier,
			launch_max_fall_speed,
			apply_ground_slam,
			apply_ground_slam and ground_bounce,
			bounce_speed,
			bounce_hitstun
		)
	else:
		if (
			knockback != 0.0
			or knockup != 0.0
			or apply_ground_slam
		):
			knockback_received.emit(
				impulse,
				knockback_duration
			)

		if hitstun_duration > 0.0:
			hitstun_received.emit(hitstun_duration)

	return true

#endregion
