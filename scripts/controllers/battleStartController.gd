
extends Node
class_name BattleStartController


#region Signals

signal battle_started
signal intro_finished

#endregion


#region References

@export_group("References")

@export var battle_ui: CanvasLayer

#endregion


#region Battle Start Settings

@export_group("Battle Start Settings")

@export var play_on_ready: bool = true

@export_range(0.0, 10.0, 0.1)
var delay_before_fight: float = 2.0

#endregion


#region Fight UI Settings

@export_group("Fight UI Settings")

@export var fight_text: String = "FIGHT!"

@export_range(0.1, 5.0, 0.1)
var fight_duration: float = 1.0

@export_range(0.05, 1.0, 0.05)
var flash_interval: float = 0.15

#endregion


#region Debug Settings

@export_group("Debug")

@export var debug_intro: bool = true

#endregion


#region Internal Variables

var player: CharacterBody2D
var enemy: BaseEnemy
var fight_label: Label

var intro_running: bool = false
var battle_active: bool = false

var locked_nodes: Dictionary = {}

#endregion


#region Initialization

func _ready() -> void:
	call_deferred("initialize_battle")


func initialize_battle() -> void:
	find_fighters()
	find_fight_label()

	if player == null or enemy == null:
		push_error(
			"BattleStartController: Player or Enemy not found."
		)
		return

	prepare_fight_ui()

	# Make sure both fighters face each other
	# before disabling their gameplay logic.
	update_initial_facing()

	lock_fighters()

	if debug_intro:
		print(
			"BattleStartController: Fighters facing each other and locked."
		)

	if play_on_ready:
		start_battle_intro()

#endregion


#region Fighter Detection

func find_fighters() -> void:
	player = null
	enemy = null

	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D:
			player = node as CharacterBody2D
			break

	for node in get_tree().get_nodes_in_group("enemy"):
		if node is BaseEnemy:
			enemy = node as BaseEnemy
			break

#endregion


#region Initial Facing

func update_initial_facing() -> void:
	if not is_instance_valid(player):
		return

	if not is_instance_valid(enemy):
		return

	# Determine which direction each fighter
	# should face based on their positions.
	var player_direction: int = 1

	if enemy.global_position.x < player.global_position.x:
		player_direction = -1

	var enemy_direction: int = -player_direction

	set_fighter_facing(
		player,
		player_direction
	)

	set_fighter_facing(
		enemy,
		enemy_direction
	)


func set_fighter_facing(
	fighter: CharacterBody2D,
	direction: int
) -> void:
	if not is_instance_valid(fighter):
		return

	# Update the fighter's facing variable.
	for property in fighter.get_property_list():
		if String(property.get("name", "")) == "facing_direction":
			fighter.set(
				"facing_direction",
				direction
			)
			break

	# Use the exported Visuals reference
	# when available.
	var visuals_node: Node2D = null
	var visuals_value: Variant = fighter.get("visuals")

	if visuals_value is Node2D:
		visuals_node = visuals_value as Node2D

	# Otherwise find the Visuals child.
	if visuals_node == null:
		visuals_node = fighter.find_child(
			"Visuals",
			true,
			false
		) as Node2D

	if visuals_node == null:
		return

	visuals_node.scale.x = (
		absf(visuals_node.scale.x) * direction
	)

#endregion


#region UI Detection

func find_fight_label() -> void:
	fight_label = null

	if is_instance_valid(battle_ui):
		fight_label = battle_ui.find_child(
			"FightLabel",
			true,
			false
		) as Label

		if fight_label != null:
			return

	var scene_root: Node = get_tree().current_scene

	if scene_root != null:
		fight_label = scene_root.find_child(
			"FightLabel",
			true,
			false
		) as Label

#endregion


#region Battle Intro

func start_battle_intro() -> void:
	if intro_running or battle_active:
		return

	if player == null or enemy == null:
		return

	intro_running = true

	if delay_before_fight > 0.0:
		await get_tree().create_timer(
			delay_before_fight
		).timeout

	if not is_inside_tree():
		return

	await flash_fight_text()

	if not is_inside_tree():
		return

	unlock_fighters()

	battle_active = true
	intro_running = false

	if debug_intro:
		print(
			"BattleStartController: FIGHT! Fighters unlocked."
		)

	battle_started.emit()
	intro_finished.emit()

#endregion


#region Fighter Locking

func lock_fighters() -> void:
	locked_nodes.clear()

	lock_fighter(player)
	lock_fighter(enemy)


func lock_fighter(fighter: CharacterBody2D) -> void:
	if not is_instance_valid(fighter):
		return

	fighter.velocity = Vector2.ZERO

	save_and_disable_processing(fighter)

	for child in fighter.get_children():
		lock_gameplay_node_recursive(child)

	var anim: AnimatedSprite2D = find_fighter_animation(fighter)

	if anim != null:
		if anim.sprite_frames != null:
			if anim.sprite_frames.has_animation("idle"):
				anim.play("idle")


func lock_gameplay_node_recursive(node: Node) -> void:
	if node is AnimatedSprite2D:
		return

	if node is Node2D and not node is CharacterBody2D:
		for child in node.get_children():
			lock_gameplay_node_recursive(child)
		return

	if node.get_script() != null:
		save_and_disable_processing(node)
		return

	for child in node.get_children():
		lock_gameplay_node_recursive(child)


func save_and_disable_processing(node: Node) -> void:
	if locked_nodes.has(node):
		return

	locked_nodes[node] = {
		"process": node.is_processing(),
		"physics": node.is_physics_processing(),
		"input": node.is_processing_input(),
		"unhandled_input": node.is_processing_unhandled_input(),
		"unhandled_key_input": node.is_processing_unhandled_key_input()
	}

	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)


func unlock_fighters() -> void:
	for node in locked_nodes.keys():
		if not is_instance_valid(node):
			continue

		var settings: Dictionary = locked_nodes[node]

		node.set_process(settings["process"])
		node.set_physics_process(settings["physics"])
		node.set_process_input(settings["input"])
		node.set_process_unhandled_input(
			settings["unhandled_input"]
		)
		node.set_process_unhandled_key_input(
			settings["unhandled_key_input"]
		)

	locked_nodes.clear()

#endregion


#region Animation Detection

func find_fighter_animation(
	fighter: CharacterBody2D
) -> AnimatedSprite2D:
	if fighter == null:
		return null

	var anim_value: Variant = fighter.get("anim")

	if anim_value is AnimatedSprite2D:
		return anim_value as AnimatedSprite2D

	for node in fighter.find_children(
		"*",
		"AnimatedSprite2D",
		true,
		false
	):
		if node is AnimatedSprite2D:
			return node as AnimatedSprite2D

	return null

#endregion


#region Fight UI Preparation

func prepare_fight_ui() -> void:
	if fight_label == null:
		push_warning(
			"BattleStartController: FightLabel not found."
		)
		return

	fight_label.text = fight_text
	fight_label.visible = false
	fight_label.modulate.a = 1.0

#endregion


#region Fight UI Flash Animation

func flash_fight_text() -> void:
	if fight_label == null:
		return

	fight_label.text = fight_text
	fight_label.modulate.a = 1.0

	var elapsed: float = 0.0
	var showing: bool = false

	while elapsed < fight_duration:
		showing = not showing
		fight_label.visible = showing

		var wait_time: float = minf(
			flash_interval,
			fight_duration - elapsed
		)

		await get_tree().create_timer(
			wait_time
		).timeout

		if not is_inside_tree():
			return

		elapsed += wait_time

	fight_label.visible = false

#endregion
