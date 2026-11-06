
extends Node
class_name specialMeterComponent


#region Signals

signal resource_changed(current: float, maximum: float)
signal resource_depleted
signal resource_restored

#endregion


#region Resource Settings

@export_group("Resource Settings")

@export_range(1.0, 1000.0, 1.0)
var max_resource: float = 100.0

@export var start_full: bool = true

var current_resource: float = 0.0

#endregion


#region Regeneration Settings

@export_group("Regeneration")

@export var regeneration_enabled: bool = false

@export_range(0.0, 100.0, 0.5)
var regeneration_rate: float = 5.0

@export_range(0.0, 10.0, 0.1)
var regeneration_delay: float = 2.0

var regeneration_timer: float = 0.0

#endregion


#region Initialization

func _ready() -> void:
	if start_full:
		current_resource = max_resource
	else:
		current_resource = 0.0

	resource_changed.emit(current_resource, max_resource)

#endregion


#region Processing

func _process(delta: float) -> void:
	if not regeneration_enabled:
		return

	if regeneration_timer > 0.0:
		regeneration_timer = maxf(
			regeneration_timer - delta,
			0.0
		)
		return

	regenerate_resource(regeneration_rate * delta)

#endregion


#region Resource Consumption

func consume_resource(amount: float) -> bool:
	if amount <= 0.0:
		return true

	if current_resource < amount:
		return false

	var previous_resource: float = current_resource

	current_resource = maxf(
		current_resource - amount,
		0.0
	)

	regeneration_timer = regeneration_delay

	resource_changed.emit(current_resource, max_resource)

	if previous_resource > 0.0 and current_resource <= 0.0:
		resource_depleted.emit()

	return true


func can_afford(amount: float) -> bool:
	return current_resource >= amount

#endregion


#region Resource Regeneration

func regenerate_resource(amount: float) -> void:
	if amount <= 0.0:
		return

	if current_resource >= max_resource:
		return

	var previous_resource: float = current_resource

	current_resource = minf(
		current_resource + amount,
		max_resource
	)

	resource_changed.emit(current_resource, max_resource)

	if previous_resource <= 0.0 and current_resource > 0.0:
		resource_restored.emit()

#endregion


#region Resource Modification

func set_resource(amount: float) -> void:
	var previous_resource: float = current_resource

	current_resource = clampf(
		amount,
		0.0,
		max_resource
	)

	if is_equal_approx(previous_resource, current_resource):
		return

	resource_changed.emit(current_resource, max_resource)

	if previous_resource > 0.0 and current_resource <= 0.0:
		resource_depleted.emit()

	if previous_resource <= 0.0 and current_resource > 0.0:
		resource_restored.emit()


func refill_resource() -> void:
	set_resource(max_resource)


func empty_resource() -> void:
	set_resource(0.0)

#endregion


#region Resource Information

func get_resource_percentage() -> float:
	if max_resource <= 0.0:
		return 0.0

	return current_resource / max_resource


func is_resource_empty() -> bool:
	return current_resource <= 0.0


func is_resource_full() -> bool:
	return current_resource >= max_resource

#endregion
