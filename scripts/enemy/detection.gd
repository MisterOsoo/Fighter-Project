
extends Area2D
class_name ProjectileDetection


#region References

@export_group("References")

@export var enemy: BaseEnemy
@export var ai_controller: AIController

#endregion


#region Detection Settings

@export_group("Detection Settings")

@export var jump_on_projectile: bool = true

enum DodgeDirection {
	NEUTRAL,
	FORWARD,
	BACKWARD
}

@export var dodge_direction: DodgeDirection = DodgeDirection.FORWARD

#endregion


#region Wild AI Settings

@export_group("Wild AI")

@export_range(0.0, 1.0, 0.05)
var wild_reaction_chance: float = 0.35

@export_range(0.0, 5.0, 0.1)
var wild_reaction_cooldown: float = 2.0

#endregion


#region Trainer AI Settings

@export_group("Trainer AI")

@export_range(0.0, 1.0, 0.05)
var trainer_reaction_chance: float = 0.85

@export_range(0.0, 5.0, 0.1)
var trainer_reaction_cooldown: float = 0.5

#endregion


#region Internal Variables

var cooldown_remaining: float = 0.0

#endregion


#region Initialization

func _ready() -> void:
	if enemy == null:
		enemy = get_parent() as BaseEnemy

	if ai_controller == null and enemy:
		ai_controller = enemy.get_node_or_null(
			"AIController"
		) as AIController

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

#endregion


#region Processing

func _physics_process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(
			cooldown_remaining - delta,
			0.0
		)

#endregion


#region AI Settings

func get_reaction_chance() -> float:
	if ai_controller == null:
		return wild_reaction_chance

	match ai_controller.ai_type:
		AIController.AIType.TRAINER:
			return trainer_reaction_chance

		AIController.AIType.WILD:
			return wild_reaction_chance

	return wild_reaction_chance


func get_reaction_cooldown() -> float:
	if ai_controller == null:
		return wild_reaction_cooldown

	match ai_controller.ai_type:
		AIController.AIType.TRAINER:
			return trainer_reaction_cooldown

		AIController.AIType.WILD:
			return wild_reaction_cooldown

	return wild_reaction_cooldown

#endregion


#region Projectile Detection

func _on_area_entered(area: Area2D) -> void:
	if not jump_on_projectile:
		return

	if not area is BulletHitbox:
		return

	if enemy == null:
		return

	if enemy.is_dead or enemy.isStunned:
		return

	if not enemy.is_on_floor():
		return

	if cooldown_remaining > 0.0:
		return

	var bullet: BulletHitbox = area as BulletHitbox

	var distance_x: float = (
		bullet.global_position.x
		- enemy.global_position.x
	)

	# Only react to projectiles in front of the enemy.
	if distance_x * enemy.facing_direction <= 0.0:
		return

	var reaction_chance: float = get_reaction_chance()

	if randf() > reaction_chance:
		return

	perform_dodge()

	cooldown_remaining = get_reaction_cooldown()

#endregion


#region Dodge Behavior

func perform_dodge() -> void:
	if enemy == null:
		return

	match dodge_direction:
		DodgeDirection.NEUTRAL:
			enemy.jump(
				EnemyJumpState.JumpType.NEUTRAL
			)

		DodgeDirection.FORWARD:
			enemy.jump(
				EnemyJumpState.JumpType.FORWARD
			)

		DodgeDirection.BACKWARD:
			enemy.jump(
				EnemyJumpState.JumpType.BACKWARD
			)

#endregion
