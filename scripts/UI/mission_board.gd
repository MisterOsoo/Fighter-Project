
extends Control
class_name MissionBoard


#region Signals

signal board_closed()

#endregion


#region Input Settings

@export_group("Inputs")

@export var up_input: StringName = &"ui_up"
@export var down_input: StringName = &"ui_down"
@export var interact_input: StringName = &"interact"
@export var back_input: StringName = &"ui_cancel"

#endregion


#region Scene Settings

@export_group("Scene Settings")

@export var progression_tree_scene: PackedScene

#endregion


#region References

@export_group("References")

@export var mission_list: VBoxContainer
@export var description_label: Label
@export var back_button: Button

#endregion


#region Menu Settings

@export_group("Menu Settings")

@export var selected_color: Color = Color.YELLOW
@export var normal_color: Color = Color.WHITE
@export var locked_color: Color = Color.DIM_GRAY

#endregion


#region Internal Variables

var mission_buttons: Array[Button] = []
var mission_types: Array[int] = []

var current_index: int = 0
var menu_open: bool = false

#endregion


#region Initialization

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	hide()

	if back_button:
		back_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back_button.focus_mode = Control.FOCUS_NONE

		if not back_button.pressed.is_connected(close_board):
			back_button.pressed.connect(close_board)

	create_mission_buttons()

#endregion


#region Open / Close

func open_board() -> void:
	create_mission_buttons()

	menu_open = true
	show()

	current_index = 0
	update_selection()

	get_tree().paused = true


func close_board() -> void:
	menu_open = false
	hide()

	get_tree().paused = false

	board_closed.emit()

#endregion


#region Mission Buttons

func create_mission_buttons() -> void:
	if mission_list == null:
		return

	for child in mission_list.get_children():
		mission_list.remove_child(child)
		child.queue_free()

	mission_buttons.clear()
	mission_types.clear()

	for biome in [
		MissionManager.Biome.RANGER_TEST,
		MissionManager.Biome.FOREST,
		MissionManager.Biome.SEA,
		MissionManager.Biome.VOLCANO,
		MissionManager.Biome.DESERT,
		MissionManager.Biome.SWAMP,
		MissionManager.Biome.FINAL_MISSION
	]:
		var button := Button.new()

		button.text = MissionManager.get_biome_name(biome)

		button.custom_minimum_size.y = 36.0
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER

		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE

		if not MissionManager.is_biome_unlocked(biome):
			button.text += "  [LOCKED]"

		mission_list.add_child(button)

		mission_buttons.append(button)
		mission_types.append(biome)

	update_selection()

#endregion


#region Input

func _input(event: InputEvent) -> void:
	if not menu_open:
		return

	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed(down_input):
		mark_input_handled()
		move_selection(1)

	elif event.is_action_pressed(up_input):
		mark_input_handled()
		move_selection(-1)

	elif event.is_action_pressed(interact_input):
		mark_input_handled()
		confirm_selection()

	elif event.is_action_pressed(back_input):
		mark_input_handled()
		close_board()


func mark_input_handled() -> void:
	if not is_inside_tree():
		return

	var viewport := get_viewport()

	if viewport:
		viewport.set_input_as_handled()

#endregion


#region Navigation

func move_selection(direction: int) -> void:
	if mission_buttons.is_empty():
		return

	current_index = wrapi(
		current_index + direction,
		0,
		mission_buttons.size() + 1
	)

	update_selection()


func update_selection() -> void:
	for i in range(mission_buttons.size()):
		var button: Button = mission_buttons[i]
		var biome: int = mission_types[i]

		if not MissionManager.is_biome_unlocked(biome):
			button.modulate = locked_color
		else:
			button.modulate = normal_color

		if i == current_index:
			button.modulate = selected_color

	if back_button:
		back_button.modulate = (
			selected_color
			if current_index == mission_buttons.size()
			else normal_color
		)

	if description_label:
		if current_index == mission_buttons.size():
			description_label.text = "Return to the overworld."
		elif current_index < mission_types.size():
			var biome: int = mission_types[current_index]

			if MissionManager.is_biome_unlocked(biome):
				description_label.text = (
					"Start " +
					MissionManager.get_biome_name(biome) +
					" mission?"
				)
			else:
				description_label.text = "Mission locked."

#endregion


#region Mission Selection

func confirm_selection() -> void:
	if current_index == mission_buttons.size():
		close_board()
		return

	if current_index >= mission_types.size():
		return

	var biome: int = mission_types[current_index]

	if not MissionManager.is_biome_unlocked(biome):
		return

	MissionManager.select_biome(biome)

	if progression_tree_scene == null:
		push_warning(
			"MissionBoard: No progression tree scene assigned!"
		)
		return

	menu_open = false
	get_tree().paused = false

	get_tree().change_scene_to_packed(
		progression_tree_scene
	)

#endregion
