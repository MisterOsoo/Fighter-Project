
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


#region Movement Settings

@export_group("Movement Settings")

@export var lock_horizontal_movement: bool = true

#endregion
