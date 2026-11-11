
extends Area2D
class_name InteractableComponent


#region Signals

signal interacted(interactor: Node2D)
signal interaction_enabled_changed(enabled: bool)

#endregion


#region Interaction Settings

@export_group("Interaction Settings")

@export var interaction_name: String = "Interact"

@export var interaction_enabled: bool = true:
	set(value):
		interaction_enabled = value

		if is_inside_tree():
			interaction_enabled_changed.emit(value)

@export var one_time_interaction: bool = false

#endregion


#region Internal Variables

var has_been_interacted: bool = false

#endregion


#region Initialization

func _ready() -> void:
	print("INTERACTABLE READY: ", get_path())
	monitorable = true

#endregion


#region Interaction

func can_interact() -> bool:
	if not interaction_enabled:
		return false

	if one_time_interaction and has_been_interacted:
		return false

	return true


func interact(interactor: Node2D) -> bool:
	if not can_interact():
		return false

	has_been_interacted = true

	interacted.emit(interactor)

	print(
		"Interacted with: ",
		interaction_name
	)

	return true

#endregion


#region Utility

func reset_interaction() -> void:
	has_been_interacted = false


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled

#endregion
