
extends CanvasLayer
class_name CommandMenuUI


#region Signals

signal special_attacks_pressed
signal ex_special_attacks_pressed
signal switch_monster_pressed
signal cancel_pressed
signal special_selected(
	special: SpecialAttackData,
	is_ex: bool
)

#endregion


#region References

@onready var panel: PanelContainer = $PanelContainer

@onready var menu_container: VBoxContainer = (
	$PanelContainer/VBoxContainer
)

@onready var title_label: Label = (
	$PanelContainer/VBoxContainer/titleLabel
)

@onready var timer_label: Label = (
	$PanelContainer/VBoxContainer/timerLabel
)

@onready var special_attacks_button: Button = (
	$PanelContainer/VBoxContainer/specialButton
)

@onready var switch_monster_button: Button = (
	$PanelContainer/VBoxContainer/teamButton
)

@onready var cancel_button: Button = (
	$PanelContainer/VBoxContainer/cancelButton
)

@onready var progress_bar: ProgressBar = (
	$PanelContainer/VBoxContainer/ProgressBar
)

#endregion


#region EX Button

var ex_special_attacks_button: Button

#endregion


#region Submenu

var special_container: VBoxContainer

var available_specials: Array[SpecialAttackData] = []

var showing_specials: bool = false
var showing_ex_specials: bool = false

#endregion


#region Initialization

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	special_attacks_button.pressed.connect(
		_on_special_attacks_pressed
	)

	switch_monster_button.pressed.connect(
		_on_switch_monster_pressed
	)

	cancel_button.pressed.connect(
		_on_cancel_pressed
	)

	create_ex_button()
	create_special_container()

	title_label.text = "Command Menu"
	special_attacks_button.text = "Special Attacks"
	switch_monster_button.text = "Switch Monster"
	cancel_button.text = "Cancel"

	# Intercept ui_accept before focused buttons
	# can process it.
	get_viewport().gui_focus_changed.connect(
		_on_gui_focus_changed
	)

	hide_menu()

#endregion


#region Input Filtering

func _on_gui_focus_changed(
	control: Control
) -> void:
	if control == null:
		return

	if not panel.visible:
		return

	if not panel.is_ancestor_of(control):
		return

	if control is Button:
		var button: Button = control as Button

		if not button.gui_input.is_connected(
			_on_button_gui_input
		):
			button.gui_input.connect(
				_on_button_gui_input
			)


func _on_button_gui_input(
	event: InputEvent
) -> void:
	if not panel.visible:
		return

	if event.is_action("ui_accept"):
		get_viewport().set_input_as_handled()

#endregion


#region Dynamic UI

func create_ex_button() -> void:
	ex_special_attacks_button = Button.new()
	ex_special_attacks_button.name = "exSpecialButton"
	ex_special_attacks_button.text = "EX Special Attacks"
	ex_special_attacks_button.focus_mode = Control.FOCUS_ALL
	ex_special_attacks_button.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	menu_container.add_child(ex_special_attacks_button)

	var special_index: int = (
		special_attacks_button.get_index()
	)

	menu_container.move_child(
		ex_special_attacks_button,
		special_index + 1
	)

	ex_special_attacks_button.pressed.connect(
		_on_ex_special_attacks_pressed
	)


func create_special_container() -> void:
	special_container = VBoxContainer.new()
	special_container.name = "SpecialContainer"
	special_container.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	menu_container.add_child(special_container)

	menu_container.move_child(
		special_container,
		cancel_button.get_index()
	)

#endregion


#region Menu Visibility

func show_menu() -> void:
	if panel == null:
		return

	show_main_menu()
	panel.show()

	special_attacks_button.grab_focus()


func hide_menu() -> void:
	if panel:
		panel.hide()

	showing_specials = false
	showing_ex_specials = false

#endregion


#region Main Menu

func show_main_menu() -> void:
	showing_specials = false
	showing_ex_specials = false

	title_label.text = "Command Menu"

	special_attacks_button.show()
	ex_special_attacks_button.show()
	switch_monster_button.show()

	if special_container:
		special_container.hide()

	cancel_button.text = "Cancel"

#endregion


#region Special Menu

func show_special_menu(
	specials: Array[SpecialAttackData],
	is_ex: bool = false,
	available_meter: float = 0.0
) -> void:
	available_specials = specials

	showing_specials = true
	showing_ex_specials = is_ex

	if is_ex:
		title_label.text = "EX Special Attacks"
	else:
		title_label.text = "Special Attacks"

	special_attacks_button.hide()
	ex_special_attacks_button.hide()
	switch_monster_button.hide()

	cancel_button.text = "Back"

	for child in special_container.get_children():
		special_container.remove_child(child)
		child.queue_free()

	special_container.show()

	var first_button: Button = null

	for special in available_specials:
		if special == null:
			continue

		var button := Button.new()
		button.focus_mode = Control.FOCUS_ALL
		button.process_mode = Node.PROCESS_MODE_ALWAYS

		if is_ex:
			button.text = "EX %s - %.0f Meter" % [
				special.special_name,
				special.ex_meter_cost
			]

			button.disabled = (
				available_meter < special.ex_meter_cost
			)
		else:
			button.text = special.special_name

		special_container.add_child(button)

		button.pressed.connect(
			_on_special_selected.bind(special, is_ex)
		)

		if first_button == null and not button.disabled:
			first_button = button

	if first_button:
		first_button.grab_focus()
	else:
		cancel_button.grab_focus()

#endregion


#region Countdown Display

func update_timer(
	time_remaining: float,
	total_duration: float
) -> void:
	if timer_label:
		timer_label.text = "%.1f" % time_remaining

	if progress_bar:
		progress_bar.max_value = total_duration
		progress_bar.value = time_remaining

#endregion


#region Button Signals

func _on_special_attacks_pressed() -> void:
	special_attacks_pressed.emit()


func _on_ex_special_attacks_pressed() -> void:
	ex_special_attacks_pressed.emit()


func _on_switch_monster_pressed() -> void:
	switch_monster_pressed.emit()


func _on_cancel_pressed() -> void:
	if showing_specials:
		show_main_menu()
		special_attacks_button.grab_focus()
	else:
		cancel_pressed.emit()


func _on_special_selected(
	special: SpecialAttackData,
	is_ex: bool
) -> void:
	special_selected.emit(special, is_ex)

#endregion
