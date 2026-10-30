
extends Node
class_name State


#region Signals

signal state_transition(
	source_state: State,
	new_state_name: String
)

#endregion


#region References

var fsm: Node

#endregion


#region State Functions

func Enter() -> void:
	pass


func Update(_delta: float) -> void:
	pass


func PhysicsUpdate(_delta: float) -> void:
	pass


func Exit() -> void:
	pass

#endregion


#region Transition Rules

func can_transition_to(_new_state: State) -> bool:
	return true


func transition_to(new_state_name: String) -> void:
	state_transition.emit(self, new_state_name)

#endregion
