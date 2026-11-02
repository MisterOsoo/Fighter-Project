
extends Resource
class_name SpecialAttackData


#region Special Information

@export_group("Special Information")

@export var special_name: String = "New Special"
@export var animation_name: StringName = &"special"

#endregion


#region Restrictions

@export_group("Restrictions")

@export var ground_only: bool = true
@export var air_only: bool = false

#endregion


#region Movement Settings

enum MovementType {
	NONE,
	FORWARD_DASH,
	BACKWARD_DASH,
	VERTICAL_LAUNCH,
	DIRECTIONAL
}

@export_group("Movement")

@export var movement_type: MovementType = MovementType.NONE

@export_range(0, 100, 1)
var movement_start_frame: int = 0

@export var movement_speed: float = 400.0

@export_range(0.0, 5.0, 0.01, "or_greater")
var movement_duration: float = 0.2

@export var movement_direction: Vector2 = Vector2.RIGHT

@export var lock_horizontal_movement: bool = true

#endregion
