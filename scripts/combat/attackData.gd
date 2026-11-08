
extends Resource
class_name AttackData


#region Attack Information

@export_group("Attack Information")

@export var attack_name: String = "New Attack"
@export var animation_name: StringName = &"attack"

#endregion


#region Attack Restrictions

@export_group("Attack Restrictions")

@export var ground_only: bool = true
@export var air_only: bool = false

#endregion


#region Combo Settings

@export_group("Combo Settings")

@export var next_light_attack: AttackData
@export var next_heavy_attack: AttackData

@export var cancel_start_frame: int = 0
@export var cancel_end_frame: int = 0

@export var require_hit_to_cancel: bool = false

#endregion


#region Jump Cancel Settings

@export_group("Jump Cancel Settings")

@export var jump_cancelable: bool = false

#endregion


#region Movement Settings

@export_group("Movement Settings")

@export var lock_horizontal_movement: bool = true

#endregion


#region Ground Bounce Settings

@export_group("Ground Bounce Settings")

@export var enable_ground_bounce: bool = false

@export_range(0.0, 1000.0, 10.0, "or_greater")
var bounce_speed: float = 230.0

@export_range(0.0, 5.0, 0.05, "or_greater")
var bounce_hitstun: float = 0.6

#endregion


#region Blockstun Settings

@export_group("Blockstun Settings")

@export_range(0.0, 5.0, 0.01, "or_greater")
var blockstun_duration: float = 0.2

#endregion


#region Special Meter Settings

@export_group("Special Meter")

@export_range(0.0, 1000.0, 1.0, "or_greater")
var meter_gain_on_hit: float = 5.0

#endregion
