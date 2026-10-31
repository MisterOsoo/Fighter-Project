
@tool
@icon("res://addons/activeFrameHitbox/icons/hitbox.svg")
extends Area2D
class_name activeFrameHitbox


#region Signals

signal hit_confirmed(attack_animation: StringName)

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


#region Hitbox Settings

@export var character: CharacterBody2D

@export var animated_sprite: AnimatedSprite2D:
	set(value):
		animated_sprite = value
		notify_property_list_changed()

@export_custom(PROPERTY_HINT_ENUM, "")
var attack_animation: String = "attack"

@export var active_frames: Array[int] = [0]

@export_group("Attack Properties")
@export var damage: int = 0
@export var knockback: float = 0.0
@export var knockup: float = 0.0

@export_range(0.0, 2.0, 0.01, "or_greater")
var knockback_duration: float = 0.18

@export_range(0.0, 5.0, 0.01, "or_greater")
var hitstun_duration: float = 0.4

@export_group("Launch Properties")
@export var launch_gravity_multiplier: float = 0.4
@export var launch_max_fall_speed: float = 250.0

@export_group("Ground Slam")
@export var ground_slam: bool = false

@export_range(0.0, 2000.0, 10.0, "or_greater")
var ground_slam_speed: float = 500.0

#endregion


#region Hit Effects

@export_group("Hit Effects")

@export var enable_hitstop: bool = true

@export_range(0.0, 1.0, 0.01, "or_greater")
var hitstop_duration: float = 0.08

@export var enable_screen_shake: bool = true

@export_range(0.0, 50.0, 0.5, "or_greater")
var screen_shake_strength: float = 5.0

@export_range(0.0, 2.0, 0.01, "or_greater")
var screen_shake_duration: float = 0.2

#endregion


#region Impact FX

@export_group("Impact FX")

@export var impact_fx_scene: PackedScene
@export var impact_fx_offset: Vector2 = Vector2.ZERO

@export_range(0.0, 10.0, 0.1, "or_greater")
var impact_fx_lifetime: float = 0.5

#endregion


#region Internal State

@onready var collision: CollisionShape2D = (
	get_node_or_null("HitboxCollision")
)

var hit_targets: Array[Hurtbox] = []
var attack_started: bool = false

#endregion


#region Collision Shape

func add_collision_shape() -> void:
	if not Engine.is_editor_hint():
		return

	if get_node_or_null("HitboxCollision"):
		push_warning("A collision shape already exists!")
		return

	var new_collision := CollisionShape2D.new()
	new_collision.name = "HitboxCollision"
	new_collision.debug_color = Color(1.0, 1.0, 0.0, 0.3)

	match shape_type:
		ShapeType.RECTANGLE:
			new_collision.shape = RectangleShape2D.new()

		ShapeType.CIRCLE:
			new_collision.shape = CircleShape2D.new()

		ShapeType.CAPSULE:
			new_collision.shape = CapsuleShape2D.new()

	add_child(new_collision)
	new_collision.owner = owner

#endregion


#region Animation Dropdown

func _validate_property(property: Dictionary) -> void:
	if property.name == "attack_animation":
		if animated_sprite and animated_sprite.sprite_frames:
			var animations: PackedStringArray = (
				animated_sprite.sprite_frames.get_animation_names()
			)

			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(animations)

#endregion


#region Initialization

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if collision == null:
		push_warning("Hitbox needs a CollisionShape2D!")
		return

	collision.set_deferred("disabled", true)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if animated_sprite:
		if not animated_sprite.frame_changed.is_connected(
			_update_hitbox
		):
			animated_sprite.frame_changed.connect(
				_update_hitbox
			)

		if not animated_sprite.animation_changed.is_connected(
			_update_hitbox
		):
			animated_sprite.animation_changed.connect(
				_update_hitbox
			)

		if not animated_sprite.animation_finished.is_connected(
			_on_animation_finished
		):
			animated_sprite.animation_finished.connect(
				_on_animation_finished
			)

		_update_hitbox()

#endregion


#region Hitbox Logic

func _update_hitbox() -> void:
	if not animated_sprite or not collision:
		return

	var is_attack_playing: bool = (
		animated_sprite.animation == attack_animation
		and animated_sprite.is_playing()
	)

	if is_attack_playing and not attack_started:
		hit_targets.clear()
		attack_started = true

	if not is_attack_playing:
		attack_started = false

	var is_active: bool = (
		is_attack_playing
		and animated_sprite.frame in active_frames
	)

	collision.set_deferred("disabled", not is_active)


func _on_animation_finished() -> void:
	if animated_sprite.animation == attack_animation:
		attack_started = false

		if collision:
			collision.set_deferred("disabled", true)


func _on_area_entered(area: Area2D) -> void:
	print("Hitbox detected area: ", area.name)

	if not area is Hurtbox:
		return

	var hurtbox: Hurtbox = area as Hurtbox

	if character == null or hurtbox.character == null:
		return

	if hurtbox.character == character:
		return

	if hurtbox in hit_targets:
		return

	hit_targets.append(hurtbox)

	var hit_landed: bool = hurtbox.receive_hit(
		damage,
		knockback,
		knockup,
		character.global_position,
		knockback_duration,
		hitstun_duration,
		launch_gravity_multiplier,
		launch_max_fall_speed,
		self,
		ground_slam,
		ground_slam_speed
	)

	if not hit_landed:
		return

	hit_confirmed.emit(StringName(attack_animation))

	spawn_impact_fx(hurtbox)
	trigger_hit_effects()

#endregion


#region Impact FX

func spawn_impact_fx(hurtbox: Hurtbox) -> void:
	if impact_fx_scene == null:
		return

	var effect: Node2D = impact_fx_scene.instantiate() as Node2D

	if effect == null:
		push_warning("Impact FX scene root must inherit Node2D.")
		return

	var impact_position: Vector2 = get_impact_position(hurtbox)

	get_tree().current_scene.add_child(effect)

	effect.global_position = (
		impact_position + impact_fx_offset
	)

	if impact_fx_lifetime > 0.0:
		get_tree().create_timer(
			impact_fx_lifetime
		).timeout.connect(
			effect.queue_free
		)

#endregion


#region Impact Position

func get_impact_position(hurtbox: Hurtbox) -> Vector2:
	var hit_collision: CollisionShape2D = (
		get_node_or_null("HitboxCollision")
	)

	var hurt_collision: CollisionShape2D = (
		hurtbox.get_node_or_null("HurtboxCollision")
	)

	if hit_collision == null or hurt_collision == null:
		return (
			global_position + hurtbox.global_position
		) * 0.5

	if hit_collision.shape == null or hurt_collision.shape == null:
		return (
			global_position + hurtbox.global_position
		) * 0.5

	var hit_center: Vector2 = hit_collision.global_position

	var hurt_local_point: Vector2 = (
		hurt_collision.to_local(hit_center)
	)

	var shape_rect: Rect2 = hurt_collision.shape.get_rect()

	var closest_local_point: Vector2 = Vector2(
		clampf(
			hurt_local_point.x,
			shape_rect.position.x,
			shape_rect.end.x
		),
		clampf(
			hurt_local_point.y,
			shape_rect.position.y,
			shape_rect.end.y
		)
	)

	var closest_world_point: Vector2 = (
		hurt_collision.to_global(closest_local_point)
	)

	return (
		hit_center + closest_world_point
	) * 0.5

#endregion


#region Hit Effects

func trigger_hit_effects() -> void:
	var effects: Node = get_node_or_null(
		"/root/CombatEffects"
	)

	if effects == null:
		return

	if enable_screen_shake:
		effects.call(
			"screen_shake",
			screen_shake_strength,
			screen_shake_duration
		)

	if enable_hitstop:
		effects.call(
			"hitstop",
			hitstop_duration
		)

#endregion
