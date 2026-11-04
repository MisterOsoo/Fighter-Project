
extends CanvasLayer
class_name HealthBarController


#region Health Bar References

@export_group("Health Bars")

@export var player_health_bar: TextureProgressBar
@export var enemy_health_bar: TextureProgressBar

#endregion


#region Character References

var player: Node
var enemy: Node

var player_health: HealthComponent
var enemy_health: HealthComponent

#endregion


#region Initialization

func _ready() -> void:
	call_deferred("setup_health_bars")

#endregion


#region Setup

func setup_health_bars() -> void:
	find_characters()
	connect_health_components()
	initialize_health_bars()


func find_characters() -> void:
	player = get_tree().get_first_node_in_group("player")
	enemy = get_tree().get_first_node_in_group("enemy")


func connect_health_components() -> void:
	if player != null:
		player_health = find_health_component(player)

		if player_health != null:
			if not player_health.health_changed.is_connected(
				update_player_health
			):
				player_health.health_changed.connect(
					update_player_health
				)

	if enemy != null:
		enemy_health = find_health_component(enemy)

		if enemy_health != null:
			if not enemy_health.health_changed.is_connected(
				update_enemy_health
			):
				enemy_health.health_changed.connect(
					update_enemy_health
				)


func find_health_component(character: Node) -> HealthComponent:
	if character == null:
		return null

	# First check whether the character exposes
	# a HealthComponent reference.
	var component: HealthComponent = character.get_node_or_null(
		"HealthComponent"
	) as HealthComponent

	if component != null:
		return component

	# Fallback: search direct children.
	for child in character.get_children():
		if child is HealthComponent:
			return child as HealthComponent

	return null

#endregion


#region Health Bar Initialization

func initialize_health_bars() -> void:
	if player_health != null and player_health_bar != null:
		player_health_bar.min_value = 0
		player_health_bar.max_value = player_health.max_health
		player_health_bar.value = player_health.current_health

	if enemy_health != null and enemy_health_bar != null:
		enemy_health_bar.min_value = 0
		enemy_health_bar.max_value = enemy_health.max_health
		enemy_health_bar.value = enemy_health.current_health

#endregion


#region Player Health

func update_player_health(current_health: int) -> void:
	if player_health_bar == null:
		return

	player_health_bar.value = current_health

#endregion


#region Enemy Health

func update_enemy_health(current_health: int) -> void:
	if enemy_health_bar == null:
		return

	enemy_health_bar.value = current_health

#endregion
