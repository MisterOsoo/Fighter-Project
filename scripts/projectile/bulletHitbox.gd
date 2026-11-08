
@tool
extends Area2D
class_name BulletHitbox


#region Signals

signal hit_confirmed(target: Hurtbox)
signal hit_blocked(target: Hurtbox)
signal projectile_clashed(other_hitbox: BulletHitbox)

#endregion


#region Collision Shape Settings

enum ShapeType {
	RECTANGLE,
	CIRCLE,
	CAPSULE
}

@export_group("Collision Shape")

@export var shape_type: ShapeType = ShapeType.RECTANGLE

@export_tool_button("Add Collision Shape")
var add_collision_shape_button: Callable = create_collision_shape

#endregion


#region Projectile Collision

@export_group("Projectile Collision")

@export var destroy_on_projectile_collision: bool = true

#endregion


#region Attack Properties

@export_group("Attack Properties")

@export var damage: int = 10
@export var knockback: float = 0.0
@export var knockup: float = 0.0

@export_range(0.0, 2.0, 0.01, "or_greater")
var knockback_duration: float = 0.18

@export_range(0.0, 5.0, 0.01, "or_greater")
var hitstun_duration: float = 0.4

#endregion


#region EX Damage

@export_group("EX Damage")

@export_range(0.0, 10.0, 0.1, "or_greater")
var damage_multiplier: float = 1.0


func set_damage_multiplier(multiplier: float) -> void:
	damage_multiplier = maxf(multiplier, 0.0)


func get_final_damage() -> int:
	return maxi(
		0,
		roundi(float(damage) * damage_multiplier)
	)

#endregion


#region Launch Properties

@export_group("Launch Properties")

@export var launch_gravity_multiplier: float = 0.4
@export var launch_max_fall_speed: float = 250.0

#endregion


#region Ground Slam

@export_group("Ground Slam")

@export var ground_slam: bool = false

@export_range(0.0, 2000.0, 10.0, "or_greater")
var ground_slam_speed: float = 500.0

#endregion


#region Ground Bounce

@export_group("Ground Bounce")

@export var enable_ground_bounce: bool = false
@export var bounce_speed: float = 230.0
@export var bounce_hitstun: float = 0.6

#endregion


#region Block Settings

@export_group("Blocking")

@export var can_be_blocked: bool = true

@export_range(0.0, 5.0, 0.01, "or_greater")
var blockstun_duration: float = 0.2

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


#region References

var character: Node2D

#endregion


#region Internal Variables

var hit_targets: Array[Hurtbox] = []
var has_clashed: bool = false

#endregion


#region Initialization

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	monitoring = true
	debug_collision_settings()

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

#endregion


#region Hit Detection

func _on_area_entered(area: Area2D) -> void:
	print(
	"[BulletHitbox] ",
	get_parent().name,
	" detected: ",
	area.name,
	" | Type: ",
	area.get_class()
)

	if area is BulletHitbox:
		print("PROJECTILE VS PROJECTILE DETECTED!")
		if has_clashed or is_queued_for_deletion():
			return

	if area is BulletHitbox:
		handle_projectile_collision(area as BulletHitbox)
		return

	if not area is Hurtbox:
		return

	var hurtbox: Hurtbox = area as Hurtbox

	if hurtbox in hit_targets:
		return

	var target_character: Node2D = hurtbox.character

	if not is_instance_valid(target_character):
		return

	# Prevent the projectile from hitting its shooter.
	if is_instance_valid(character):
		if target_character == character:
			return

	hit_targets.append(hurtbox)

	# Check blocking before applying damage.
	if can_be_blocked:
		var block_component: BlockComponent = (
			target_character.get("block_component")
			as BlockComponent
		)

		if block_component:
			if block_component.try_block_hit(self):
				hit_blocked.emit(hurtbox)
				return

	var final_damage: int = get_final_damage()

	# Apply damage and combat physics.
	var hit_landed: bool = hurtbox.receive_hit(
		final_damage,
		knockback,
		knockup,
		get_attack_origin(),
		knockback_duration,
		hitstun_duration,
		launch_gravity_multiplier,
		launch_max_fall_speed,
		self,
		ground_slam,
		ground_slam_speed,
		ground_slam and enable_ground_bounce,
		bounce_speed,
		bounce_hitstun
	)

	if not hit_landed:
		return

	# Spawn effects before the bullet is destroyed.
	spawn_impact_fx(hurtbox)
	trigger_hit_effects()

	hit_confirmed.emit(hurtbox)

#endregion


#region Projectile Collision

func handle_projectile_collision(
	other: BulletHitbox
) -> void:
	if not destroy_on_projectile_collision:
		return

	if not is_instance_valid(other):
		return

	if other == self:
		return

	if not other.destroy_on_projectile_collision:
		return

	if has_clashed or other.has_clashed:
		return

	if other.is_queued_for_deletion():
		return

	# Both projectiles must have valid shooters.
	if not is_instance_valid(character):
		return

	if not is_instance_valid(other.character):
		return

	# Never clash with projectiles from the same shooter.
	if character == other.character:
		return

	var my_team: int = get_projectile_team(character)
	var other_team: int = get_projectile_team(
		other.character
	)

	# Only player and enemy projectiles can clash.
	if my_team == 0 or other_team == 0:
		return

	if my_team == other_team:
		return

	# Mark both before emitting signals so
	# the clash cannot happen twice.
	has_clashed = true
	other.has_clashed = true

	projectile_clashed.emit(other)
	other.projectile_clashed.emit(self)


func get_projectile_team(
	shooter_node: Node2D
) -> int:
	if not is_instance_valid(shooter_node):
		return 0

	if shooter_node.is_in_group("player"):
		return 1

	if shooter_node.is_in_group("enemy"):
		return 2

	return 0

#endregion


#region Attack Origin

func get_attack_origin() -> Vector2:
	if is_instance_valid(character):
		return character.global_position

	return global_position

#endregion


#region Impact FX

func spawn_impact_fx(hurtbox: Hurtbox) -> void:
	if impact_fx_scene == null:
		return

	var effect: Node2D = (
		impact_fx_scene.instantiate() as Node2D
	)

	if effect == null:
		push_warning(
			"Impact FX scene root must inherit Node2D."
		)
		return

	var impact_position: Vector2 = (
		get_impact_position(hurtbox)
	)

	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		effect.queue_free()
		return

	scene_root.add_child(effect)

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
		get_node_or_null("bulletCollision")
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

	var hit_center: Vector2 = (
		hit_collision.global_position
	)

	var hurt_local_point: Vector2 = (
		hurt_collision.to_local(hit_center)
	)

	var shape_rect: Rect2 = (
		hurt_collision.shape.get_rect()
	)

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
		hurt_collision.to_global(
			closest_local_point
		)
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


#region Collision Shape Generation

func create_collision_shape() -> void:
	if not Engine.is_editor_hint():
		return

	call_deferred(
		"_create_collision_shape_deferred"
	)


func _create_collision_shape_deferred() -> void:
	if not is_inside_tree():
		return

	var collision: CollisionShape2D = (
		get_node_or_null("bulletCollision")
		as CollisionShape2D
	)

	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "bulletCollision"

		add_child(collision)

		var scene_root: Node = (
			get_tree().edited_scene_root
		)

		if scene_root:
			collision.owner = scene_root

	match shape_type:
		ShapeType.RECTANGLE:
			collision.shape = RectangleShape2D.new()

		ShapeType.CIRCLE:
			collision.shape = CircleShape2D.new()

		ShapeType.CAPSULE:
			collision.shape = CapsuleShape2D.new()

	collision.debug_color = Color(
		1.0,
		1.0,
		0.0,
		0.4
	)

	collision.disabled = false

#endregion


#region Reset

func reset_hit_targets() -> void:
	hit_targets.clear()

#endregion

func debug_collision_settings() -> void:
	print(
		"[", get_parent().name, "] ",
		"Layer: ", collision_layer,
		" | Mask: ", collision_mask,
		" | Monitoring: ", monitoring,
		" | Monitorable: ", monitorable
	)
