
extends CanvasLayer


#region Input Settings

@export_group("Menu Inputs")

@export var up_input: StringName = &"ui_up"
@export var down_input: StringName = &"ui_down"
@export var left_input: StringName = &"ui_left"
@export var right_input: StringName = &"ui_right"
@export var accept_input: StringName = &"ui_accept"

#endregion


#region Color Settings

@export_group("Menu Colors")

@export var normal_color: Color = Color.WHITE
@export var selected_color: Color = Color.YELLOW

#endregion


#region Scene Settings

@export_group("Scene Transitions")

@export var battle_scene: PackedScene
@export var training_scene: PackedScene
@export var overworld_scene: PackedScene
@export var options_scene: PackedScene

#endregion


#region References

@onready var menu_container: VBoxContainer = get_node_or_null(
	"PanelContainer/VBoxContainer"
) as VBoxContainer

@onready var play_button: Button = get_node_or_null(
	"PanelContainer/VBoxContainer/Play"
) as Button

@onready var play_submenu: VBoxContainer = get_node_or_null(
	"PanelContainer/VBoxContainer/PlaySubmenu"
) as VBoxContainer

@onready var battle_button: Button = get_node_or_null(
	"PanelContainer/VBoxContainer/PlaySubmenu/Battle"
) as Button

@onready var training_button: Button = get_node_or_null(
	"PanelContainer/VBoxContainer/PlaySubmenu/Training"
) as Button

@onready var overworld_button: Button = get_node_or_null(
	"PanelContainer/VBoxContainer/PlaySubmenu/Overworld"
) as Button

@onready var options_button: Button = get_node_or_null(
	"PanelContainer/VBoxContainer/Options"
) as Button

@onready var quit_button: Button = get_node_or_null(
	"PanelContainer/VBoxContainer/Quit"
) as Button

#endregion


#region Menu State

var submenu_open: bool = false
var current_index: int = 0

var menu_buttons: Array[Button] = []

#endregion


#region Initialization

func _ready() -> void:
	check_references()

	if play_submenu:
		play_submenu.hide()

	for button in [
		play_button,
		battle_button,
		training_button,
		overworld_button,
		options_button,
		quit_button
	]:
		if button == null:
			continue

		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE

	update_menu_buttons()
	update_selection()


func check_references() -> void:
	if menu_container == null:
		push_error("MainMenu: VBoxContainer not found.")

	if play_button == null:
		push_error("MainMenu: Play button not found.")

	if play_submenu == null:
		push_error("MainMenu: PlaySubmenu not found.")

	if battle_button == null:
		push_error("MainMenu: Battle button not found.")

	if training_button == null:
		push_error("MainMenu: Training button not found.")

	if overworld_button == null:
		push_error("MainMenu: Overworld button not found.")

	if options_button == null:
		push_error("MainMenu: Options button not found.")

	if quit_button == null:
		push_error("MainMenu: Quit button not found.")

#endregion


#region Menu Navigation

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed(down_input):
		mark_input_handled()
		move_selection(1)

	elif event.is_action_pressed(up_input):
		mark_input_handled()
		move_selection(-1)

	elif event.is_action_pressed(accept_input):
		mark_input_handled()
		activate_selection()

	elif event.is_action_pressed(left_input):
		mark_input_handled()

		if submenu_open:
			close_submenu()

	elif event.is_action_pressed(right_input):
		mark_input_handled()

		if not submenu_open and get_selected_button() == play_button:
			open_submenu()


func mark_input_handled() -> void:
	if not is_inside_tree():
		return

	var viewport: Viewport = get_viewport()

	if viewport != null:
		viewport.set_input_as_handled()


func move_selection(direction: int) -> void:
	if menu_buttons.is_empty():
		return

	current_index = wrapi(
		current_index + direction,
		0,
		menu_buttons.size()
	)

	update_selection()

#endregion


#region Menu Selection

func update_menu_buttons() -> void:
	menu_buttons.clear()

	if play_button:
		menu_buttons.append(play_button)

	if submenu_open:
		if battle_button:
			menu_buttons.append(battle_button)

		if training_button:
			menu_buttons.append(training_button)

		if overworld_button:
			menu_buttons.append(overworld_button)

	if options_button:
		menu_buttons.append(options_button)

	if quit_button:
		menu_buttons.append(quit_button)

	if menu_buttons.is_empty():
		current_index = 0
	else:
		current_index = clampi(
			current_index,
			0,
			menu_buttons.size() - 1
		)


func update_selection() -> void:
	for button in [
		play_button,
		battle_button,
		training_button,
		overworld_button,
		options_button,
		quit_button
	]:
		if button:
			button.modulate = normal_color

	var selected_button: Button = get_selected_button()

	if selected_button:
		selected_button.modulate = selected_color


func get_selected_button() -> Button:
	if menu_buttons.is_empty():
		return null

	if current_index < 0 or current_index >= menu_buttons.size():
		return null

	return menu_buttons[current_index]


func activate_selection() -> void:
	var selected_button: Button = get_selected_button()

	if selected_button == null:
		return

	if selected_button == play_button:
		if submenu_open:
			close_submenu()
		else:
			open_submenu()

	elif selected_button == battle_button:
		start_battle()

	elif selected_button == training_button:
		start_training()

	elif selected_button == overworld_button:
		start_overworld()

	elif selected_button == options_button:
		open_options()

	elif selected_button == quit_button:
		quit_game()

#endregion


#region Submenu

func open_submenu() -> void:
	if play_submenu == null:
		push_error("MainMenu: Cannot open missing PlaySubmenu.")
		return

	submenu_open = true
	play_submenu.show()

	update_menu_buttons()

	if battle_button and menu_buttons.has(battle_button):
		current_index = menu_buttons.find(battle_button)
	elif training_button and menu_buttons.has(training_button):
		current_index = menu_buttons.find(training_button)
	elif overworld_button and menu_buttons.has(overworld_button):
		current_index = menu_buttons.find(overworld_button)
	else:
		current_index = 0

	update_selection()


func close_submenu() -> void:
	submenu_open = false

	if play_submenu:
		play_submenu.hide()

	update_menu_buttons()

	if play_button and menu_buttons.has(play_button):
		current_index = menu_buttons.find(play_button)
	else:
		current_index = 0

	update_selection()

#endregion


#region Menu Actions

func start_battle() -> void:
	if battle_scene == null:
		push_warning(
			"MainMenu: No Battle scene assigned in Inspector."
		)
		return

	get_tree().change_scene_to_packed(battle_scene)


func start_training() -> void:
	if training_scene == null:
		push_warning(
			"MainMenu: No Training scene assigned in Inspector."
		)
		return

	get_tree().change_scene_to_packed(training_scene)


func start_overworld() -> void:
	if overworld_scene == null:
		push_warning(
			"MainMenu: No Overworld scene assigned in Inspector."
		)
		return

	get_tree().change_scene_to_packed(overworld_scene)


func open_options() -> void:
	if options_scene == null:
		push_warning(
			"MainMenu: No Options scene assigned in Inspector."
		)
		return

	get_tree().change_scene_to_packed(options_scene)


func quit_game() -> void:
	get_tree().quit()

#endregion
