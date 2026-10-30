
extends Node
class_name FiniteStateMachine


#region State Settings

@export var initial_state: State
@export var debug_states: bool = true

var states: Dictionary = {}
var current_state: State

#endregion


#region Initialization

func _ready() -> void:

	for child in get_children():

		if child is State:

			var state: State = child

			states[state.name.to_lower()] = state

			state.fsm = self

			if not state.state_transition.is_connected(
				change_state
			):
				state.state_transition.connect(
					change_state
				)

	if initial_state == null:
		push_warning("FSM has no initial state assigned.")
		return

	if not states.values().has(initial_state):
		push_error("Initial state must be a child of the FSM.")
		return

	current_state = initial_state
	current_state.Enter()

	print_current_state()

#endregion


#region State Transitions

func change_state(
	source_state: State,
	new_state_name: String
) -> void:

	if source_state != current_state:
		return

	transition_to(new_state_name)


func transition_to(
	new_state_name: String,
	force: bool = false
) -> void:

	var new_state: State = states.get(
		new_state_name.to_lower()
	)

	if new_state == null:
		push_warning(
			"State not found: " + new_state_name
		)
		return

	if new_state == current_state:
		return

	if current_state:
		if not force:
			if not current_state.can_transition_to(new_state):
				return

		current_state.Exit()

	current_state = new_state
	current_state.Enter()

	print_current_state()

#endregion


#region Debug

func print_current_state() -> void:

	if not debug_states:
		return

	if current_state == null:
		return

	print("Current State: ", current_state.name)

#endregion


#region Updates

func _process(delta: float) -> void:

	if current_state:
		current_state.Update(delta)


func _physics_process(delta: float) -> void:

	if current_state:
		current_state.PhysicsUpdate(delta)

#endregion
