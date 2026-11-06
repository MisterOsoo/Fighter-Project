
extends Resource
class_name SpecialAttackData


#region Special Information

@export_group("Special Information")

@export var special_name: String = "New Special"
@export var animation_name: StringName = &"special"

#endregion


#region EX Special Settings

@export_group("EX Special")

@export var ex_enabled: bool = false

@export_range(0.0, 1000.0, 1.0)
var ex_meter_cost: float = 25.0

@export var ex_animation_name: StringName = &""

@export_range(1.0, 5.0, 0.1)
var ex_damage_multiplier: float = 1.5

#endregion


#region EX Yellow Flash

@export_group("EX Yellow Flash")

@export var ex_yellow_flash: bool = true

@export var ex_flash_color: Color = Color(
	1.0, 0.9, 0.0, 1.0
)

@export_range(0.01, 1.0, 0.01)
var ex_flash_interval: float = 0.08

#endregion


#region EX Delayed Shadow

@export_group("EX Delayed Shadow")

@export var ex_afterimage_enabled: bool = true

@export_range(0.0, 1.0, 0.05)
var ex_afterimage_opacity: float = 0.5

@export var ex_afterimage_color: Color = Color(
	1.0, 0.85, 0.0, 1.0
)

@export_range(0.0, 100.0, 1.0)
var ex_afterimage_offset: float = 6.0

#endregion


#region Restrictions

enum UsageType {
	GROUND_ONLY,
	AIR_ONLY,
	GROUND_AND_AIR
}

@export_group("Restrictions")

@export var usage_type: UsageType = UsageType.GROUND_ONLY


func can_use(is_airborne: bool) -> bool:
	match usage_type:
		UsageType.GROUND_ONLY:
			return not is_airborne

		UsageType.AIR_ONLY:
			return is_airborne

		UsageType.GROUND_AND_AIR:
			return true

	return false

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


#region EX Movement Settings

@export_group("EX Movement")

@export var ex_movement_type: MovementType = MovementType.NONE

@export_range(0, 100, 1)
var ex_movement_start_frame: int = 0

@export var ex_movement_speed: float = 400.0

@export_range(0.0, 5.0, 0.01, "or_greater")
var ex_movement_duration: float = 0.2

@export var ex_movement_direction: Vector2 = Vector2.RIGHT

@export var ex_lock_horizontal_movement: bool = true

#endregion


#region EX Helpers

func get_animation(is_ex: bool) -> StringName:
	if is_ex and ex_enabled and ex_animation_name != &"":
		return ex_animation_name

	return animation_name


func get_damage_multiplier(is_ex: bool) -> float:
	if is_ex and ex_enabled:
		return ex_damage_multiplier

	return 1.0


func get_meter_cost(is_ex: bool) -> float:
	if is_ex and ex_enabled:
		return ex_meter_cost

	return 0.0

#endregion


#region Movement Helpers

func get_movement_type(is_ex: bool) -> MovementType:
	if is_ex and ex_enabled:
		return ex_movement_type

	return movement_type


func get_movement_start_frame(is_ex: bool) -> int:
	if is_ex and ex_enabled:
		return ex_movement_start_frame

	return movement_start_frame


func get_movement_speed(is_ex: bool) -> float:
	if is_ex and ex_enabled:
		return ex_movement_speed

	return movement_speed


func get_movement_duration(is_ex: bool) -> float:
	if is_ex and ex_enabled:
		return ex_movement_duration

	return movement_duration


func get_movement_direction(is_ex: bool) -> Vector2:
	if is_ex and ex_enabled:
		return ex_movement_direction

	return movement_direction


func get_lock_horizontal_movement(is_ex: bool) -> bool:
	if is_ex and ex_enabled:
		return ex_lock_horizontal_movement

	return lock_horizontal_movement

#endregion
