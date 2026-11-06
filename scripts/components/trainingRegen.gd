
extends Node
class_name TrainingRegenerationComponent


#region Group Settings

@export_group("Character Groups")

@export var player_group: StringName = &"player"
@export var enemy_group: StringName = &"enemy"

#endregion


#region Component Settings

@export_group("Component Settings")

@export var health_component_name: StringName = &"HealthComponent"
@export var special_meter_component_name: StringName = &"SpecialMeterComponent"

#endregion


#region Regeneration Settings

@export_group("Regeneration Settings")

@export var regeneration_enabled: bool = true

@export_range(0.0, 30.0, 0.1)
var regeneration_delay: float = 3.0

@export_range(0.0, 100.0, 0.5)
var health_regeneration_per_second: float = 10.0

@export_range(0.0, 100.0, 0.5)
var special_regeneration_per_second: float = 10.0

#endregion


#region Internal Variables

var fighters: Dictionary = {}

#endregion


#region Initialization

func _ready() -> void:
	_register_existing_fighters()

	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _register_existing_fighters() -> void:
	for character in get_tree().get_nodes_in_group(player_group):
		_register_fighter(character)

	for character in get_tree().get_nodes_in_group(enemy_group):
		_register_fighter(character)


func _on_node_added(node: Node) -> void:
	if node.is_in_group(player_group) or node.is_in_group(enemy_group):
		_register_fighter.call_deferred(node)


func _register_fighter(character: Node) -> void:
	if not is_instance_valid(character):
		return

	if not (
		character.is_in_group(player_group)
		or character.is_in_group(enemy_group)
	):
		return

	if fighters.has(character):
		return

	var health: HealthComponent = _find_health_component(character)

	var meter: specialMeterComponent = _find_meter_component(character)

	if health == null:
		push_warning(
			"TrainingRegeneration: No HealthComponent found on "
			+ character.name
		)
		return

	fighters[character] = {
		"health": health,
		"meter": meter,
		"timer": 0.0,
		"health_fraction": 0.0,
		"previous_health": health.current_health
	}

#endregion


#region Component Discovery

func _find_health_component(root: Node) -> HealthComponent:
	if root is HealthComponent:
		return root as HealthComponent

	for child in root.get_children():
		var found: HealthComponent = _find_health_component(child)

		if found:
			return found

	return null


func _find_meter_component(root: Node) -> specialMeterComponent:
	if root is specialMeterComponent:
		return root as specialMeterComponent

	for child in root.get_children():
		var found: specialMeterComponent = _find_meter_component(child)

		if found:
			return found

	return null

#endregion


#region Processing

func _process(delta: float) -> void:
	if not regeneration_enabled:
		return

	for character in fighters.keys():
		if not is_instance_valid(character):
			fighters.erase(character)
			continue

		_update_fighter(character, delta)


func _update_fighter(character: Node, delta: float) -> void:
	var data: Dictionary = fighters[character]

	var health: HealthComponent = data["health"]
	var meter: specialMeterComponent = data["meter"]

	if not is_instance_valid(health):
		fighters.erase(character)
		return

	var current_health: int = health.current_health
	var previous_health: int = int(data["previous_health"])

	var took_damage: bool = current_health < previous_health
	var attacking: bool = _is_character_attacking(character)

	if took_damage or attacking:
		data["timer"] = 0.0
		data["health_fraction"] = 0.0
	else:
		data["timer"] = float(data["timer"]) + delta

		if float(data["timer"]) >= regeneration_delay:
			_regenerate_health(data, delta)
			_regenerate_meter(meter, delta)

	data["previous_health"] = health.current_health

	fighters[character] = data

#endregion


#region Attack Detection

func _is_character_attacking(character: Node) -> bool:
	if character is BasePlayer:
		var player: BasePlayer = character as BasePlayer

		if player.isAttacking:
			return true

		if player.fsm and player.fsm.current_state:
			if player.fsm.current_state is AttackState:
				return true

			if player.fsm.current_state is SpecialAttackState:
				return true

	return false

#endregion


#region Health Regeneration

func _regenerate_health(data: Dictionary, delta: float) -> void:
	var health: HealthComponent = data["health"]

	if not is_instance_valid(health):
		return

	if health.current_health <= 0:
		return

	if health.current_health >= health.max_health:
		data["health_fraction"] = 0.0
		return

	data["health_fraction"] = (
		float(data["health_fraction"])
		+ health_regeneration_per_second * delta
	)

	var amount: int = int(data["health_fraction"])

	if amount <= 0:
		return

	data["health_fraction"] = (
		float(data["health_fraction"]) - float(amount)
	)

	health.current_health = mini(
		health.current_health + amount,
		health.max_health
	)

	health.health_changed.emit(health.current_health)

#endregion


#region Special Meter Regeneration

func _regenerate_meter(
	meter: specialMeterComponent,
	delta: float
) -> void:
	if not is_instance_valid(meter):
		return

	meter.regenerate_resource(
		special_regeneration_per_second * delta
	)

#endregion


#region Manual Activity Notifications

func notify_attack(character: Node) -> void:
	_reset_fighter_timer(character)


func notify_damage_received(character: Node) -> void:
	_reset_fighter_timer(character)


func _reset_fighter_timer(character: Node) -> void:
	if not fighters.has(character):
		return

	var data: Dictionary = fighters[character]

	data["timer"] = 0.0
	data["health_fraction"] = 0.0

	fighters[character] = data

#endregion
