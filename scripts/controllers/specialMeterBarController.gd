
extends CanvasLayer
class_name SpecialMeterBarController


#region Meter References

@onready var player_meter_bar: TextureProgressBar = $"../playerMeter"
@onready var enemy_meter_bar: TextureProgressBar = $"../enemyMeter"

#endregion


#region Character References

var player: Node
var enemy: Node

var player_meter: specialMeterComponent
var enemy_meter: specialMeterComponent

#endregion


#region Initialization

func _ready() -> void:
	call_deferred("setup_meters")

#endregion


#region Setup

func setup_meters() -> void:
	find_characters()
	connect_meters()
	initialize_meters()


func find_characters() -> void:
	player = get_tree().get_first_node_in_group("player")
	enemy = get_tree().get_first_node_in_group("enemy")


func find_meter_component(character: Node) -> specialMeterComponent:
	if character == null:
		return null

	# Search for the component by node name.
	var component: specialMeterComponent = character.get_node_or_null(
		"specialMeterComponent"
	) as specialMeterComponent

	if component != null:
		return component

	# Search children by script class.
	for child in character.get_children():
		if child is specialMeterComponent:
			return child as specialMeterComponent

	return null

#endregion


#region Connect Meters

func connect_meters() -> void:
	if player != null:
		player_meter = find_meter_component(player)

		if player_meter != null:
			if not player_meter.resource_changed.is_connected(
				update_player_meter
			):
				player_meter.resource_changed.connect(
					update_player_meter
				)

	if enemy != null:
		enemy_meter = find_meter_component(enemy)

		if enemy_meter != null:
			if not enemy_meter.resource_changed.is_connected(
				update_enemy_meter
			):
				enemy_meter.resource_changed.connect(
					update_enemy_meter
				)

#endregion


#region Initialize Meters

func initialize_meters() -> void:
	if player_meter != null:
		player_meter_bar.min_value = 0
		player_meter_bar.max_value = player_meter.max_resource
		player_meter_bar.value = player_meter.current_resource

	if enemy_meter != null:
		enemy_meter_bar.min_value = 0
		enemy_meter_bar.max_value = enemy_meter.max_resource
		enemy_meter_bar.value = enemy_meter.current_resource

#endregion


#region Player Meter

func update_player_meter(
	current_resource: float,
	maximum_resource: float
) -> void:
	player_meter_bar.max_value = maximum_resource
	player_meter_bar.value = current_resource

#endregion


#region Enemy Meter

func update_enemy_meter(
	current_resource: float,
	maximum_resource: float
) -> void:
	enemy_meter_bar.max_value = maximum_resource
	enemy_meter_bar.value = current_resource

#endregion
