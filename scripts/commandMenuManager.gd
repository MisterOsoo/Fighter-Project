
extends Node
class_name CommandMenuManager


#region Signals

signal menu_opened
signal menu_closed
signal special_attacks_selected
signal switch_monster_selected
signal special_executed(special: SpecialAttackData)

#endregion


#region Inspector Settings

@export_group("Command Menu")

@export var menu_input: StringName = &"specialMenu"

@export_range(1.0, 30.0, 0.5)
var menu_duration: float = 5.0

#endregion


#region References

@export_group("References")

@export var menu_ui: CommandMenuUI

var player: BasePlayer

#endregion


#region State

var is_menu_open: bool = false
var time_remaining: float = 0.0

#endregion


#region Initialization

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	find_active_player()

	if menu_ui:
		menu_ui.hide_menu()

		if not menu_ui.special_attacks_pressed.is_connected(
			_on_special_attacks_pressed
		):
			menu_ui.special_attacks_pressed.connect(
				_on_special_attacks_pressed
			)

		if not menu_ui.switch_monster_pressed.is_connected(
			_on_switch_monster_pressed
		):
			menu_ui.switch_monster_pressed.connect(
				_on_switch_monster_pressed
			)

		if not menu_ui.cancel_pressed.is_connected(
			close_menu
		):
			menu_ui.cancel_pressed.connect(close_menu)

		if not menu_ui.special_selected.is_connected(
			_on_special_selected
		):
			menu_ui.special_selected.connect(
				_on_special_selected
			)

#endregion


#region Active Player

func find_active_player() -> void:
	var candidate: Node = get_tree().get_first_node_in_group(
		"player"
	)

	player = candidate as BasePlayer


func set_active_player(
	new_player: BasePlayer
) -> void:
	if is_menu_open:
		close_menu()

	player = new_player


func get_active_player() -> BasePlayer:
	if not is_instance_valid(player):
		find_active_player()

	return player

#endregion


#region Input

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(menu_input):
		return

	if event.is_echo():
		return

	if is_menu_open:
		confirm_selection()
	else:
		try_open_menu()

	get_viewport().set_input_as_handled()


func confirm_selection() -> void:
	if menu_ui == null:
		return

	var focused_control: Control = (
		get_viewport().gui_get_focus_owner()
	)

	if focused_control is Button:
		var focused_button: Button = focused_control as Button

		if focused_button.is_visible_in_tree():
			if not focused_button.disabled:
				focused_button.pressed.emit()

#endregion


#region Menu Eligibility

func can_open_menu() -> bool:
	var active_player: BasePlayer = get_active_player()

	if active_player == null:
		return false

	if active_player.is_dead or active_player.isStunned:
		return false

	if active_player.block_component:
		if active_player.block_component.is_blocking:
			return false

	if active_player.fsm == null:
		return false

	if active_player.fsm.current_state is SpecialAttackState:
		return false

	if active_player.isAttacking:
		return can_cancel_attack_into_menu()

	return true


func can_cancel_attack_into_menu() -> bool:
	var active_player: BasePlayer = get_active_player()

	if active_player == null or active_player.fsm == null:
		return false

	var attack_state: AttackState = (
		active_player.fsm.current_state as AttackState
	)

	if attack_state == null:
		return false

	if attack_state.current_attack == null:
		return false

	if not attack_state.is_inside_cancel_window():
		return false

	if attack_state.current_attack.require_hit_to_cancel:
		if not attack_state.hit_confirmed:
			return false

	return true

#endregion


#region Menu Control

func try_open_menu() -> void:
	if is_menu_open:
		return

	if not can_open_menu():
		return

	open_menu()


func open_menu() -> void:
	if is_menu_open:
		return

	is_menu_open = true
	time_remaining = menu_duration

	if menu_ui:
		menu_ui.show_menu()
		menu_ui.update_timer(
			time_remaining,
			menu_duration
		)

	get_tree().paused = true
	menu_opened.emit()


func close_menu() -> void:
	if not is_menu_open:
		return

	is_menu_open = false
	get_tree().paused = false

	if menu_ui:
		menu_ui.hide_menu()

	menu_closed.emit()

#endregion


#region Countdown

func _process(delta: float) -> void:
	if not is_menu_open:
		return

	time_remaining = maxf(
		time_remaining - delta,
		0.0
	)

	if menu_ui:
		menu_ui.update_timer(
			time_remaining,
			menu_duration
		)

	if time_remaining <= 0.0:
		close_menu()

#endregion


#region Special Attacks

func get_equipped_specials() -> Array[SpecialAttackData]:
	var result: Array[SpecialAttackData] = []

	var active_player: BasePlayer = get_active_player()

	if active_player == null:
		return result

	return active_player.get_equipped_specials()


func get_available_specials() -> Array[SpecialAttackData]:
	var result: Array[SpecialAttackData] = []

	var active_player: BasePlayer = get_active_player()

	if active_player == null:
		return result

	var is_airborne: bool = not active_player.is_on_floor()

	for special in get_equipped_specials():
		if special == null:
			continue

		if not special.can_use(is_airborne):
			continue

		result.append(special)

	return result


func _on_special_attacks_pressed() -> void:
	special_attacks_selected.emit()

	if menu_ui:
		menu_ui.show_special_menu(
			get_available_specials()
		)


func _on_special_selected(
	special: SpecialAttackData
) -> void:
	if not is_menu_open or special == null:
		return

	if not get_available_specials().has(special):
		return

	var active_player: BasePlayer = get_active_player()

	if active_player == null or active_player.fsm == null:
		return

	var special_state: SpecialAttackState = null

	for child in active_player.fsm.get_children():
		if child is SpecialAttackState:
			special_state = child as SpecialAttackState
			break

	if special_state == null:
		push_warning(
			"SpecialAttackState not found in player FSM."
		)
		return

	special_state.prepare_special(special)

	close_menu()

	active_player.fsm.transition_to(
		"specialattack",
		true
	)

	special_executed.emit(special)

#endregion


#region Monster Switching

func _on_switch_monster_pressed() -> void:
	switch_monster_selected.emit()
	close_menu()

#endregion
