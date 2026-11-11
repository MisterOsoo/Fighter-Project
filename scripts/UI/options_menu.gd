
extends Control
class_name OptionsMenu


#region Signals

signal menu_closed()

#endregion


#region Actions

@export_group("Actions")

@export var displayed_actions: Array[StringName] = [
	&"ui_left",
	&"ui_right",
	&"ui_up",
	&"ui_down",
	&"jump",
	&"lightAtk",
	&"heavyAtk",
	&"dash",
	&"interact"
]

@export var action_display_names: Array[String] = [
	"Move Left",
	"Move Right",
	"Move Up",
	"Move Down",
	"Jump",
	"Light Attack",
	"Heavy Attack",
	"Dash",
	"Interact"
]

@export var interact_input: StringName = &"interact"

#endregion


#region Button Settings

@export_group("Button Settings")

@export_range(50.0, 400.0, 5.0)
var keyboard_button_width: float = 110.0

@export_range(50.0, 400.0, 5.0)
var controller_button_width: float = 110.0

@export_range(50.0, 400.0, 5.0)
var action_label_width: float = 140.0

@export_range(20.0, 100.0, 1.0)
var button_height: float = 36.0

@export_range(0.0, 50.0, 1.0)
var row_spacing: float = 8.0

#endregion


#region Scroll Settings

@export_group("Scroll Settings")

@export_range(100.0, 1000.0, 10.0)
var scroll_area_width: float = 400.0

@export_range(50.0, 1000.0, 10.0)
var scroll_area_height: float = 250.0

@export_range(50.0, 1000.0, 10.0)
var right_stick_scroll_speed: float = 250.0

@export_range(0.0, 1.0, 0.05)
var right_stick_deadzone: float = 0.2

#endregion


#region References

@export_group("References")

@export var binding_scroll: ScrollContainer
@export var binding_rows: VBoxContainer
@export var reset_button: Button
@export var back_button: Button

#endregion


#region Scene Settings

@export_group("Scene Settings")

@export_file("*.tscn")
var back_scene_path: String = "res://scenes/main_menu.tscn"

#endregion


#region Save Settings

@export_group("Save Settings")

@export var save_path: String = "user://input_bindings.cfg"

#endregion


#region Internal Variables

enum DeviceType {
	KEYBOARD,
	CONTROLLER
}

var waiting_for_input: bool = false
var selected_action: StringName = &""
var selected_device: DeviceType = DeviceType.KEYBOARD

var default_bindings: Dictionary = {}
var binding_buttons: Dictionary = {}

var focusable_buttons: Array[Button] = []

var right_stick_value: float = 0.0
var right_stick_scroll_remainder: float = 0.0

#endregion


#region Initialization

func _ready() -> void:
	capture_default_bindings()
	load_bindings()

	setup_scroll_container()
	setup_menu_buttons()
	create_binding_rows()

	call_deferred("focus_first_button")

#endregion


#region Scroll Container Setup

func setup_scroll_container() -> void:
	if binding_scroll == null:
		push_warning(
			"OptionsMenu: BindingScroll is not assigned."
		)
		return

	binding_scroll.custom_minimum_size = Vector2(
		scroll_area_width,
		scroll_area_height
	)

	binding_scroll.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER
	)

	binding_scroll.size_flags_vertical = (
		Control.SIZE_SHRINK_BEGIN
	)

	binding_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)

	binding_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)

	binding_scroll.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	binding_scroll.follow_focus = true

	if binding_rows:
		binding_rows.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

#endregion


#region Menu Buttons

func setup_menu_buttons() -> void:
	if reset_button:
		reset_button.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		reset_button.focus_mode = Control.FOCUS_ALL

		if not reset_button.pressed.is_connected(
			reset_to_defaults
		):
			reset_button.pressed.connect(
				reset_to_defaults
			)

	if back_button:
		back_button.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		back_button.focus_mode = Control.FOCUS_ALL

		if not back_button.pressed.is_connected(
			close_menu
		):
			back_button.pressed.connect(
				close_menu
			)

#endregion


#region Default Bindings

func capture_default_bindings() -> void:
	for action in displayed_actions:
		if not InputMap.has_action(action):
			push_warning(
				"Input action not found: " + str(action)
			)
			continue

		var events: Array[InputEvent] = []

		for event in InputMap.action_get_events(action):
			events.append(event.duplicate())

		default_bindings[action] = events

#endregion


#region Generate UI

func create_binding_rows() -> void:
	if binding_rows == null:
		return

	for child in binding_rows.get_children():
		binding_rows.remove_child(child)
		child.queue_free()

	binding_buttons.clear()
	focusable_buttons.clear()

	binding_rows.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)

	binding_rows.add_theme_constant_override(
		"separation",
		int(row_spacing)
	)

	for i in range(displayed_actions.size()):
		var action: StringName = displayed_actions[i]

		if not InputMap.has_action(action):
			continue

		var row := HBoxContainer.new()

		row.alignment = (
			BoxContainer.ALIGNMENT_CENTER
		)

		row.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)

		row.add_theme_constant_override(
			"separation",
			12
		)

		binding_rows.add_child(row)

		var action_label := Label.new()

		action_label.text = get_action_display_name(
			action,
			i
		)

		action_label.custom_minimum_size = Vector2(
			action_label_width,
			button_height
		)

		action_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)

		action_label.vertical_alignment = (
			VERTICAL_ALIGNMENT_CENTER
		)

		action_label.clip_text = true

		row.add_child(action_label)

		var keyboard_button := Button.new()

		setup_binding_button(
			keyboard_button,
			keyboard_button_width
		)

		row.add_child(keyboard_button)

		var controller_button := Button.new()

		setup_binding_button(
			controller_button,
			controller_button_width
		)

		row.add_child(controller_button)

		keyboard_button.pressed.connect(
			start_rebinding.bind(
				action,
				DeviceType.KEYBOARD
			)
		)

		controller_button.pressed.connect(
			start_rebinding.bind(
				action,
				DeviceType.CONTROLLER
			)
		)

		binding_buttons[action] = {
			"keyboard": keyboard_button,
			"controller": controller_button
		}

		focusable_buttons.append(keyboard_button)
		focusable_buttons.append(controller_button)

	setup_focus_navigation()
	update_binding_buttons()


func setup_binding_button(
	button: Button,
	button_width: float
) -> void:
	button.custom_minimum_size = Vector2(
		button_width,
		button_height
	)

	button.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER
	)

	button.alignment = HORIZONTAL_ALIGNMENT_CENTER

	button.clip_text = true

	button.text_overrun_behavior = (
		TextServer.OVERRUN_TRIM_ELLIPSIS
	)

	button.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	button.focus_mode = Control.FOCUS_ALL

	button.focus_entered.connect(
		_on_button_focused.bind(button)
	)


func get_action_display_name(
	action: StringName,
	index: int
) -> String:
	if index < action_display_names.size():
		var custom_name: String = (
			action_display_names[index].strip_edges()
		)

		if not custom_name.is_empty():
			return custom_name

	return str(action).replace("_", " ").capitalize()

#endregion


#region Focus Navigation

func setup_focus_navigation() -> void:
	var row_count: int = int(
		focusable_buttons.size() / 2
	)

	if row_count == 0:
		return

	for i in range(row_count):
		var keyboard_button: Button = (
			focusable_buttons[i * 2]
		)

		var controller_button: Button = (
			focusable_buttons[i * 2 + 1]
		)

		keyboard_button.focus_neighbor_right = (
			keyboard_button.get_path_to(
				controller_button
			)
		)

		controller_button.focus_neighbor_left = (
			controller_button.get_path_to(
				keyboard_button
			)
		)

		if i > 0:
			var previous_keyboard: Button = (
				focusable_buttons[(i - 1) * 2]
			)

			var previous_controller: Button = (
				focusable_buttons[(i - 1) * 2 + 1]
			)

			keyboard_button.focus_neighbor_top = (
				keyboard_button.get_path_to(
					previous_keyboard
				)
			)

			controller_button.focus_neighbor_top = (
				controller_button.get_path_to(
					previous_controller
				)
			)

		if i < row_count - 1:
			var next_keyboard: Button = (
				focusable_buttons[(i + 1) * 2]
			)

			var next_controller: Button = (
				focusable_buttons[(i + 1) * 2 + 1]
			)

			keyboard_button.focus_neighbor_bottom = (
				keyboard_button.get_path_to(
					next_keyboard
				)
			)

			controller_button.focus_neighbor_bottom = (
				controller_button.get_path_to(
					next_controller
				)
			)

	var last_keyboard: Button = (
		focusable_buttons[focusable_buttons.size() - 2]
	)

	var last_controller: Button = (
		focusable_buttons[focusable_buttons.size() - 1]
	)

	if reset_button:
		last_keyboard.focus_neighbor_bottom = (
			last_keyboard.get_path_to(reset_button)
		)

		last_controller.focus_neighbor_bottom = (
			last_controller.get_path_to(reset_button)
		)

		reset_button.focus_neighbor_top = (
			reset_button.get_path_to(last_keyboard)
		)

	if reset_button and back_button:
		reset_button.focus_neighbor_bottom = (
			reset_button.get_path_to(back_button)
		)

		back_button.focus_neighbor_top = (
			back_button.get_path_to(reset_button)
		)

	if reset_button:
		reset_button.focus_neighbor_left = NodePath("")
		reset_button.focus_neighbor_right = NodePath("")

	if back_button:
		back_button.focus_neighbor_left = NodePath("")
		back_button.focus_neighbor_right = NodePath("")
		back_button.focus_neighbor_bottom = NodePath("")


func focus_first_button() -> void:
	if focusable_buttons.is_empty():
		return

	focusable_buttons[0].grab_focus()


func _on_button_focused(button: Button) -> void:
	if binding_scroll == null:
		return

	if not binding_scroll.is_ancestor_of(button):
		return

	binding_scroll.ensure_control_visible(button)

#endregion


#region Right Stick Scrolling

func _process(delta: float) -> void:
	if waiting_for_input:
		return

	if binding_scroll == null:
		return

	if absf(right_stick_value) < right_stick_deadzone:
		return

	var scroll_amount: float = (
		right_stick_value
		* right_stick_scroll_speed
		* delta
	)

	var scrollbar: VScrollBar = (
		binding_scroll.get_v_scroll_bar()
	)

	var maximum_scroll: float = maxf(
		scrollbar.max_value - scrollbar.page,
		0.0
	)

	right_stick_scroll_remainder += scroll_amount

	var whole_pixels: int = int(
		right_stick_scroll_remainder
	)

	if whole_pixels == 0:
		return

	right_stick_scroll_remainder -= whole_pixels

	binding_scroll.scroll_vertical = int(
		clampf(
			float(binding_scroll.scroll_vertical + whole_pixels),
			0.0,
			maximum_scroll
		)
	)

#endregion


#region Input Handling

func _input(event: InputEvent) -> void:
	if waiting_for_input:
		handle_rebinding_input(event)
		return

	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_RIGHT_Y:
			right_stick_value = event.axis_value

	if event.is_action_pressed(interact_input):
		if event is InputEventKey and event.echo:
			return

		mark_input_handled()
		activate_focused_button()


func mark_input_handled() -> void:
	if not is_inside_tree():
		return

	var viewport: Viewport = get_viewport()

	if viewport != null:
		viewport.set_input_as_handled()


func activate_focused_button() -> void:
	if not is_inside_tree():
		return

	var viewport: Viewport = get_viewport()

	if viewport == null:
		return

	var focused_control: Control = (
		viewport.gui_get_focus_owner()
	)

	if not focused_control is Button:
		return

	var focused_button: Button = focused_control as Button

	if focused_button.disabled:
		return

	focused_button.pressed.emit()

#endregion


#region Rebinding

func start_rebinding(
	action: StringName,
	device: DeviceType
) -> void:
	selected_action = action
	selected_device = device
	waiting_for_input = true

	right_stick_value = 0.0
	right_stick_scroll_remainder = 0.0

	update_binding_buttons()


func handle_rebinding_input(
	event: InputEvent
) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				mark_input_handled()
				cancel_rebinding()
				return

	if selected_device == DeviceType.KEYBOARD:
		if event is InputEventKey:
			if event.pressed and not event.echo:
				mark_input_handled()
				apply_new_binding(event)
				return

	elif selected_device == DeviceType.CONTROLLER:
		if event is InputEventJoypadButton:
			if event.pressed:
				mark_input_handled()
				apply_new_binding(event)
				return

		elif event is InputEventJoypadMotion:
			if absf(event.axis_value) >= 0.75:
				mark_input_handled()
				apply_new_binding(event)
				return

#endregion


#region Apply Rebinding

func apply_new_binding(event: InputEvent) -> void:
	if not InputMap.has_action(selected_action):
		cancel_rebinding()
		return

	var new_event: InputEvent = event.duplicate()

	if new_event is InputEventKey:
		var key_event: InputEventKey = (
			new_event as InputEventKey
		)

		if key_event.physical_keycode == KEY_NONE:
			key_event.physical_keycode = (
				key_event.keycode
			)

		key_event.keycode = KEY_NONE
		key_event.unicode = 0
		key_event.pressed = false

	elif new_event is InputEventJoypadButton:
		new_event.device = -1
		(new_event as InputEventJoypadButton).pressed = false

	elif new_event is InputEventJoypadMotion:
		new_event.device = -1

	remove_device_bindings(
		selected_action,
		selected_device
	)

	InputMap.action_add_event(
		selected_action,
		new_event
	)

	waiting_for_input = false
	selected_action = &""

	save_bindings()
	update_binding_buttons()


func remove_device_bindings(
	action: StringName,
	device: DeviceType
) -> void:
	for event in InputMap.action_get_events(action):
		if device == DeviceType.KEYBOARD:
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		else:
			if (
				event is InputEventJoypadButton
				or event is InputEventJoypadMotion
			):
				InputMap.action_erase_event(action, event)


func cancel_rebinding() -> void:
	waiting_for_input = false
	selected_action = &""
	update_binding_buttons()

#endregion


#region Button Labels

func update_binding_buttons() -> void:
	for action in binding_buttons:
		var buttons: Dictionary = binding_buttons[action]

		var keyboard_button: Button = buttons["keyboard"]
		var controller_button: Button = buttons["controller"]

		keyboard_button.text = get_binding_text(
			action,
			DeviceType.KEYBOARD
		)

		controller_button.text = get_binding_text(
			action,
			DeviceType.CONTROLLER
		)

		if waiting_for_input and selected_action == action:
			if selected_device == DeviceType.KEYBOARD:
				keyboard_button.text = "Press a key..."
			else:
				controller_button.text = "Press a button..."


func get_binding_text(
	action: StringName,
	device: DeviceType
) -> String:
	for event in InputMap.action_get_events(action):
		if device == DeviceType.KEYBOARD:
			if event is InputEventKey:
				return event.as_text()
		else:
			if (
				event is InputEventJoypadButton
				or event is InputEventJoypadMotion
			):
				return event.as_text()

	return "Unbound"

#endregion


#region Save Bindings

func save_bindings() -> void:
	var config := ConfigFile.new()

	for action in displayed_actions:
		if not InputMap.has_action(action):
			continue

		var saved_events: Array[Dictionary] = []

		for event in InputMap.action_get_events(action):
			var data: Dictionary = {}

			if event is InputEventKey:
				var key_event: InputEventKey = event

				data = {
					"type": "key",
					"keycode": key_event.keycode,
					"physical_keycode": key_event.physical_keycode,
					"shift": key_event.shift_pressed,
					"ctrl": key_event.ctrl_pressed,
					"alt": key_event.alt_pressed,
					"meta": key_event.meta_pressed
				}

			elif event is InputEventJoypadButton:
				data = {
					"type": "button",
					"button_index": event.button_index
				}

			elif event is InputEventJoypadMotion:
				data = {
					"type": "axis",
					"axis": event.axis,
					"axis_value": event.axis_value
				}

			if not data.is_empty():
				saved_events.append(data)

		config.set_value(
			"bindings",
			str(action),
			saved_events
		)

	var error: Error = config.save(save_path)

	if error != OK:
		push_error("Failed to save input bindings.")

#endregion


#region Load Bindings

func load_bindings() -> void:
	var config := ConfigFile.new()

	if config.load(save_path) != OK:
		return

	for action in displayed_actions:
		if not InputMap.has_action(action):
			continue

		if not config.has_section_key(
			"bindings",
			str(action)
		):
			continue

		var saved_events: Array = config.get_value(
			"bindings",
			str(action),
			[]
		)

		var restored_events: Array[InputEvent] = []

		for data in saved_events:
			if not data is Dictionary:
				continue

			var event: InputEvent = null

			match data.get("type", ""):
				"key":
					var key_event := InputEventKey.new()

					key_event.keycode = data.get(
						"keycode",
						0
					)

					key_event.physical_keycode = data.get(
						"physical_keycode",
						0
					)

					key_event.shift_pressed = data.get(
						"shift",
						false
					)

					key_event.ctrl_pressed = data.get(
						"ctrl",
						false
					)

					key_event.alt_pressed = data.get(
						"alt",
						false
					)

					key_event.meta_pressed = data.get(
						"meta",
						false
					)

					event = key_event

				"button":
					var button_event := (
						InputEventJoypadButton.new()
					)

					button_event.button_index = data.get(
						"button_index",
						0
					)

					button_event.device = -1
					event = button_event

				"axis":
					var axis_event := (
						InputEventJoypadMotion.new()
					)

					axis_event.axis = data.get(
						"axis",
						0
					)

					axis_event.axis_value = data.get(
						"axis_value",
						1.0
					)

					axis_event.device = -1
					event = axis_event

			if event != null:
				restored_events.append(event)

		InputMap.action_erase_events(action)

		for event in restored_events:
			InputMap.action_add_event(action, event)

#endregion


#region Reset Defaults

func reset_to_defaults() -> void:
	cancel_rebinding()

	for action in default_bindings:
		InputMap.action_erase_events(action)

		for event in default_bindings[action]:
			InputMap.action_add_event(
				action,
				event.duplicate()
			)

	save_bindings()
	update_binding_buttons()

#endregion


#region Menu Controls

func close_menu() -> void:
	if waiting_for_input:
		cancel_rebinding()
		return

	right_stick_value = 0.0
	right_stick_scroll_remainder = 0.0

	if back_scene_path.is_empty():
		push_warning(
			"OptionsMenu: No Back Scene Path assigned!"
		)
		return

	if not ResourceLoader.exists(back_scene_path):
		push_error(
			"OptionsMenu: Scene does not exist: "
			+ back_scene_path
		)
		return

	menu_closed.emit()

	var error: Error = get_tree().change_scene_to_file(
		back_scene_path
	)

	if error != OK:
		push_error(
			"OptionsMenu: Failed to load: "
			+ back_scene_path
		)

#endregion
