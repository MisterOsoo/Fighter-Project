
extends Node
class_name AIController


#region AI Settings

enum AIType { WILD, TRAINER }

@export_group("AI Settings")
@export var ai_type: AIType = AIType.WILD
@export var enemy: BaseEnemy

#endregion


#region AI Scripts

@export_group("AI Scripts")
@export var wild_ai_script: Script
@export var trainer_ai_script: Script

#endregion


#region Wild Movement Settings

@export_group("Wild Movement")
@export_range(0.0, 500.0, 1.0) var wild_preferred_distance: float = 100.0
@export_range(0.05, 5.0, 0.05) var wild_decision_interval: float = 0.5

#endregion


#region Wild Combat Settings

@export_group("Wild Combat")
@export_range(0.0, 500.0, 5.0) var wild_attack_range: float = 75.0
@export_range(0.0, 100.0, 1.0) var wild_attack_chance: float = 45.0
@export_range(0.0, 100.0, 1.0) var wild_heavy_chance: float = 20.0
@export_range(0.0, 100.0, 1.0) var wild_combo_chance: float = 25.0
@export_range(0.0, 10.0, 0.1) var wild_attack_cooldown: float = 1.5

#endregion


#region Wild Special Attacks

@export_group("Wild Special Attacks")
@export var wild_equipped_specials: Array[SpecialAttackData] = []
@export_range(0.0, 100.0, 1.0) var wild_special_chance: float = 15.0
@export_range(0.0, 1000.0, 5.0) var wild_special_range: float = 250.0
@export_range(0.0, 30.0, 0.1) var wild_special_cooldown: float = 5.0
@export_range(0.0, 100.0, 1.0) var wild_ex_special_chance: float = 10.0
@export var wild_debug_specials: bool = false

#endregion


#region Wild Attack Approach

@export_group("Wild Attack Approach")
@export_range(0.0, 500.0, 1.0) var wild_attack_approach_distance: float = 20.0
@export_range(0.1, 10.0, 0.1) var wild_approach_timeout: float = 2.0

#endregion


#region Wild Defense Settings

@export_group("Wild Defense")
@export_range(0.0, 100.0, 1.0) var wild_block_chance: float = 25.0
@export_range(0.0, 500.0, 1.0) var wild_block_detection_range: float = 100.0
@export_range(0.05, 2.0, 0.05) var wild_block_hold_duration: float = 0.45
@export_range(0.0, 100.0, 1.0) var wild_crouch_block_chance: float = 25.0
@export_range(0.0, 100.0, 1.0) var wild_counterattack_block_bonus: float = 15.0
@export_range(0.0, 1.0, 0.01) var wild_block_reaction_delay: float = 0.05
@export var wild_debug_defense: bool = false

#endregion


#region Wild Recovery Settings

@export_group("Wild Recovery")
@export_range(0.0, 5.0, 0.05) var wild_post_attack_pause_min: float = 0.7
@export_range(0.0, 5.0, 0.05) var wild_post_attack_pause_max: float = 1.3
@export var wild_stop_during_recovery: bool = true

#endregion


#region Wild Strategic Retreat

@export_group("Wild Strategic Retreat")
@export var wild_enable_strategic_retreat: bool = true
@export_range(0.0, 100.0, 1.0) var wild_whiff_retreat_chance: float = 20.0
@export_range(0.0, 100.0, 1.0) var wild_blocked_retreat_chance: float = 25.0
@export_range(0.0, 100.0, 1.0) var wild_hit_retreat_chance: float = 0.0
@export_range(0.0, 100.0, 1.0) var wild_back_dash_chance: float = 60.0
@export_range(0.0, 2.0, 0.01) var wild_retreat_delay: float = 0.25
@export_range(0.0, 10.0, 0.1) var wild_retreat_cooldown: float = 4.0
@export_range(0.0, 500.0, 1.0) var wild_minimum_retreat_space: float = 70.0
@export var wild_debug_retreat: bool = false

#endregion


#region Trainer Movement Settings

@export_group("Trainer Movement")
@export_range(0.0, 500.0, 1.0) var trainer_preferred_distance: float = 60.0
@export_range(0.05, 5.0, 0.05) var trainer_decision_interval: float = 0.15

#endregion


#region Trainer Combat Settings

@export_group("Trainer Combat")
@export_range(0.0, 500.0, 5.0) var trainer_attack_range: float = 85.0
@export_range(0.0, 100.0, 1.0) var trainer_attack_chance: float = 75.0
@export_range(0.0, 100.0, 1.0) var trainer_heavy_chance: float = 35.0
@export_range(0.0, 100.0, 1.0) var trainer_combo_chance: float = 65.0
@export_range(0.0, 10.0, 0.1) var trainer_attack_cooldown: float = 0.8

#endregion


#region Trainer Special Attacks

@export_group("Trainer Special Attacks")
@export var trainer_equipped_specials: Array[SpecialAttackData] = []
@export_range(0.0, 100.0, 1.0) var trainer_special_chance: float = 35.0
@export_range(0.0, 1000.0, 5.0) var trainer_special_range: float = 250.0
@export_range(0.0, 30.0, 0.1) var trainer_special_cooldown: float = 3.0
@export_range(0.0, 100.0, 1.0) var trainer_ex_special_chance: float = 30.0
@export var trainer_debug_specials: bool = false

#endregion


#region Trainer Attack Approach

@export_group("Trainer Attack Approach")
@export_range(0.0, 500.0, 1.0) var trainer_attack_approach_distance: float = 20.0
@export_range(0.1, 10.0, 0.1) var trainer_approach_timeout: float = 2.0

#endregion


#region Trainer Defense Settings

@export_group("Trainer Defense")
@export_range(0.0, 100.0, 1.0) var trainer_block_chance: float = 60.0
@export_range(0.0, 500.0, 1.0) var trainer_block_detection_range: float = 100.0
@export_range(0.05, 2.0, 0.05) var trainer_block_hold_duration: float = 0.45
@export_range(0.0, 100.0, 1.0) var trainer_crouch_block_chance: float = 25.0
@export_range(0.0, 100.0, 1.0) var trainer_counterattack_block_bonus: float = 25.0
@export_range(0.0, 1.0, 0.01) var trainer_block_reaction_delay: float = 0.05
@export var trainer_debug_defense: bool = false

#endregion


#region Trainer Recovery Settings

@export_group("Trainer Recovery")
@export_range(0.0, 5.0, 0.05) var trainer_post_attack_pause_min: float = 0.35
@export_range(0.0, 5.0, 0.05) var trainer_post_attack_pause_max: float = 0.75
@export var trainer_stop_during_recovery: bool = true

#endregion


#region Trainer Strategic Retreat

@export_group("Trainer Strategic Retreat")
@export var trainer_enable_strategic_retreat: bool = true
@export_range(0.0, 100.0, 1.0) var trainer_whiff_retreat_chance: float = 55.0
@export_range(0.0, 100.0, 1.0) var trainer_blocked_retreat_chance: float = 65.0
@export_range(0.0, 100.0, 1.0) var trainer_hit_retreat_chance: float = 20.0
@export_range(0.0, 100.0, 1.0) var trainer_back_dash_chance: float = 65.0
@export_range(0.0, 2.0, 0.01) var trainer_retreat_delay: float = 0.15
@export_range(0.0, 10.0, 0.1) var trainer_retreat_cooldown: float = 2.5
@export_range(0.0, 500.0, 1.0) var trainer_minimum_retreat_space: float = 70.0
@export var trainer_debug_retreat: bool = false

#endregion


#region Internal Variables

var active_ai: Node

#endregion


#region Initialization

func _ready() -> void:
	if enemy == null:
		enemy = get_parent() as BaseEnemy

	initialize_ai()

#endregion


#region AI Selection

func initialize_ai() -> void:
	if is_instance_valid(active_ai):
		remove_child(active_ai)
		active_ai.queue_free()
		active_ai = null

	var selected_script: Script

	match ai_type:
		AIType.WILD:
			selected_script = wild_ai_script

		AIType.TRAINER:
			selected_script = trainer_ai_script

	if selected_script == null:
		push_warning(
			"AIController: No AI script assigned for selected AI type."
		)
		return

	if not selected_script.can_instantiate():
		push_error(
			"AIController: Selected AI script cannot be instantiated."
		)
		return

	active_ai = Node.new()
	active_ai.set_script(selected_script)

	active_ai.name = (
		"WildAI"
		if ai_type == AIType.WILD
		else "TrainerAI"
	)

	active_ai.set("enemy", enemy)

	apply_combat_settings()

	add_child(active_ai)

#endregion


#region Combat Configuration

func apply_combat_settings() -> void:
	if active_ai == null:
		return

	var prefix: String = (
		"wild_"
		if ai_type == AIType.WILD
		else "trainer_"
	)

	var settings: Array[String] = [
		"preferred_distance",
		"decision_interval",
		"attack_range",
		"attack_chance",
		"heavy_chance",
		"combo_chance",
		"attack_cooldown",
		"equipped_specials",
		"special_chance",
		"special_range",
		"special_cooldown",
		"ex_special_chance",
		"debug_specials",
		"attack_approach_distance",
		"approach_timeout",
		"block_chance",
		"block_detection_range",
		"block_hold_duration",
		"crouch_block_chance",
		"counterattack_block_bonus",
		"block_reaction_delay",
		"debug_defense",
		"post_attack_pause_min",
		"post_attack_pause_max",
		"stop_during_recovery",
		"enable_strategic_retreat",
		"whiff_retreat_chance",
		"blocked_retreat_chance",
		"hit_retreat_chance",
		"back_dash_chance",
		"retreat_delay",
		"retreat_cooldown",
		"minimum_retreat_space",
		"debug_retreat"
	]

	var available_properties: Dictionary = {}

	for property in active_ai.get_property_list():
		available_properties[
			String(property.get("name", ""))
		] = true

	for setting in settings:
		if available_properties.has(setting):
			active_ai.set(
				setting,
				get(prefix + setting)
			)
		else:
			push_warning(
				"AIController: "
				+ active_ai.name
				+ " does not expose setting: "
				+ setting
			)

#endregion
