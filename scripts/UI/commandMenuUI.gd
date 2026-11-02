
extends CanvasLayer
class_name CommandMenuUI


#region Signals

signal special_attacks_pressed
signal switch_monster_pressed
signal cancel_pressed
signal special_selected(special: SpecialAttackData)

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


#region Submenu

var special_container: VBoxContainer
var available_specials: Array[SpecialAttackData] = []
var showing_specials: bool = false

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

	special_container = VBoxContainer.new()
	special_container.name = "SpecialContainer"
	special_container.process_mode = Node.PROCESS_MODE_ALWAYS

	menu_container.add_child(special_container)
	menu_container.move_child(
		special_container,
		menu_container.get_child_count() - 2
	)

	title_label.text = "Command Menu"
	special_attacks_button.text = "Special Attacks"
	switch_monster_button.text = "Switch Monster"
	cancel_button.text = "Cancel"

	hide_menu()

#endregion


#region Menu Visibility

func show_menu() -> void:
	if panel == null:
		panel = get_node_or_null("PanelContainer")

	if panel == null:
		return

	show_main_menu()
	panel.show()

	if special_attacks_button:
		special_attacks_button.grab_focus()


func hide_menu() -> void:
	if panel == null:
		panel = get_node_or_null("PanelContainer")

	if panel:
		panel.hide()

	showing_specials = false

#endregion


#region Main Menu

func show_main_menu() -> void:
	showing_specials = false

	title_label.text = "Command Menu"

	special_attacks_button.show()
	switch_monster_button.show()

	if special_container:
		special_container.hide()

	cancel_button.text = "Cancel"

#endregion


#region Special Menu

func show_special_menu(
	specials: Array[SpecialAttackData]
) -> void:
	available_specials = specials
	showing_specials = true

	title_label.text = "Special Attacks"

	special_attacks_button.hide()
	switch_monster_button.hide()

	cancel_button.text = "Back"

	for child in special_container.get_children():
		child.queue_free()
		special_container.remove_child(child)

	special_container.show()

	var first_button: Button = null

	for special in available_specials:
		if special == null:
			continue

		var button := Button.new()
		button.text = special.special_name
		button.focus_mode = Control.FOCUS_ALL

		special_container.add_child(button)

		button.pressed.connect(
			_on_special_selected.bind(special)
		)

		if first_button == null:
			first_button = button

	if first_button:
		first_button.grab_focus()

#endregion


#region Countdown Display

func update_timer(
	time_remaining: float,
	total_duration: float
) -> void:
	if timer_label == null:
		timer_label = get_node_or_null(
			"PanelContainer/VBoxContainer/timerLabel"
		)

	if progress_bar == null:
		progress_bar = get_node_or_null(
			"PanelContainer/VBoxContainer/ProgressBar"
		)

	if timer_label:
		timer_label.text = "%.1f" % time_remaining

	if progress_bar:
		progress_bar.max_value = total_duration
		progress_bar.value = time_remaining

#endregion


#region Button Signals

func _on_special_attacks_pressed() -> void:
	special_attacks_pressed.emit()


func _on_switch_monster_pressed() -> void:
	switch_monster_pressed.emit()


func _on_cancel_pressed() -> void:
	if showing_specials:
		show_main_menu()
		special_attacks_button.grab_focus()
	else:
		cancel_pressed.emit()


func _on_special_selected(
	special: SpecialAttackData
) -> void:
	special_selected.emit(special)

#endregion
