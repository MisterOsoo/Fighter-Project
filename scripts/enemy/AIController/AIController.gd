
extends Node
class_name AIController


#region AI Settings

enum AIType {
	WILD,
	TRAINER
}

@export_group("AI Settings")

@export var ai_type: AIType = AIType.WILD

@export var enemy: BaseEnemy

#endregion


#region AI Scripts

@export_group("AI Scripts")

@export var wild_ai_script: Script = preload(
	"res://scripts/enemy/AIController/wildAI.gd"
)

@export var trainer_ai_script: Script = preload(
	"res://scripts/enemy/AIController/trainerAI.gd"
)

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
		active_ai.queue_free()
		active_ai = null

	var selected_script: Script

	match ai_type:
		AIType.WILD:
			selected_script = wild_ai_script

		AIType.TRAINER:
			selected_script = trainer_ai_script

	if selected_script == null:
		push_warning("AIController: No AI script assigned.")
		return

	active_ai = Node.new()
	active_ai.set_script(selected_script)

	active_ai.name = (
		"WildAI"
		if ai_type == AIType.WILD
		else "TrainerAI"
	)

	active_ai.set("enemy", enemy)

	add_child(active_ai)

#endregion
