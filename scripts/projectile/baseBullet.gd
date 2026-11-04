
extends Node2D
class_name BaseBullet


#region Bullet Settings

enum DirectionMode {
	SHOOTER_FACING,
	MANUAL
}

@export_group("Bullet Settings")

@export var direction_mode: DirectionMode = (
	DirectionMode.SHOOTER_FACING
)

@export var speed: float = 400.0
@export var direction: Vector2 = Vector2.RIGHT

#endregion


#region Animation Settings

@export_group("Animation Settings")

@export var bullet_animation: StringName = &"default"
@export var autoplay_animation: bool = true

#endregion


#region References

@export_group("References")

@export var hitbox: BulletHitbox
@export var anim: AnimatedSprite2D

#endregion


#region Internal Variables

var shooter: Node2D
var initialized_direction: bool = false

#endregion


#region Initialization

func _ready() -> void:
	if hitbox:
		hitbox.character = shooter

		if not hitbox.hit_confirmed.is_connected(
			_on_hitbox_hit_confirmed
		):
			hitbox.hit_confirmed.connect(
				_on_hitbox_hit_confirmed
			)

		if not hitbox.hit_blocked.is_connected(
			_on_hitbox_hit_blocked
		):
			hitbox.hit_blocked.connect(
				_on_hitbox_hit_blocked
			)

	update_direction()

	if autoplay_animation:
		play_bullet_animation()

#endregion


#region Shooter

func set_shooter(new_shooter: Node2D) -> void:
	shooter = new_shooter

	if hitbox:
		hitbox.character = shooter

	if is_node_ready():
		update_direction()

#endregion


#region Direction

func update_direction() -> void:
	match direction_mode:
		DirectionMode.SHOOTER_FACING:
			set_shooter_direction()

		DirectionMode.MANUAL:
			set_manual_direction()

	initialized_direction = true


func set_shooter_direction() -> void:
	if not is_instance_valid(shooter):
		push_warning(
			"BaseBullet needs a shooter for facing direction."
		)
		set_manual_direction()
		return

	var facing_value: Variant = shooter.get(
		"facing_direction"
	)

	if facing_value is int:
		var facing: int = int(facing_value)

		if facing != 0:
			direction = Vector2(
				float(signi(facing)),
				0.0
			)
			return

	var visuals: Node2D = shooter.get_node_or_null(
		"Visuals"
	) as Node2D

	if visuals:
		direction = (
			Vector2.LEFT
			if visuals.scale.x < 0.0
			else Vector2.RIGHT
		)
		return

	set_manual_direction()


func set_manual_direction() -> void:
	if direction == Vector2.ZERO:
		push_warning(
			"BaseBullet direction cannot be Vector2.ZERO!"
		)
		direction = Vector2.RIGHT

	direction = direction.normalized()

#endregion


#region Animation Handling

func play_bullet_animation() -> void:
	if anim == null:
		push_warning("BaseBullet has no AnimatedSprite2D assigned!")
		return

	if anim.sprite_frames == null:
		push_warning("BaseBullet AnimatedSprite2D has no SpriteFrames!")
		return

	if not anim.sprite_frames.has_animation(bullet_animation):
		push_warning(
			"BaseBullet animation not found: %s"
			% bullet_animation
		)
		return

	anim.play(bullet_animation)

#endregion


#region Movement

func _physics_process(delta: float) -> void:
	if not initialized_direction:
		return

	global_position += direction * speed * delta

#endregion


#region Hit Detection

func _on_hitbox_hit_confirmed(
	_target: Hurtbox
) -> void:
	destroy_bullet()


func _on_hitbox_hit_blocked(
	_target: Hurtbox
) -> void:
	destroy_bullet()

#endregion


#region Destruction

func destroy_bullet() -> void:
	if is_queued_for_deletion():
		return

	queue_free()

#endregion
