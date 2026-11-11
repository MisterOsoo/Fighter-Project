
@tool
extends Area2D
class_name PlayerInteractComponent


#region Signals

signal interaction_started(interactable: InteractableComponent)
signal interaction_available(interactable: InteractableComponent)
signal interaction_unavailable()

#endregion


#region Interaction Settings

@export_group("Interaction Settings")

@export var interact_input: StringName = &"interact"
@export var interaction_enabled: bool = true

#endregion


#region References

@export_group("References")

@export var player: CharacterBody2D

#endregion


#region Button Icon Settings

@export_group("Button Icon Settings")

@export var button_icon: Node2D:
	set(value):
		button_icon = value
		notify_property_list_changed()

@export_custom(PROPERTY_HINT_ENUM, "")
var button_animation: String = "bottom"

@export var button_position_offset: Vector2 = Vector2.ZERO

#endregion


#region Internal Variables

var nearby_interactables: Array[InteractableComponent] = []
var current_interactable: InteractableComponent = null

var button_anim: AnimatedSprite2D = null

#endregion


#region Inspector Animation Dropdown

func _validate_property(property: Dictionary) -> void:
	if property.name != "button_animation":
		return

	var sprite: AnimatedSprite2D = find_button_animation_sprite()

	if sprite == null or sprite.sprite_frames == null:
		return

	var animations: PackedStringArray = (
		sprite.sprite_frames.get_animation_names()
	)

	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(animations)


func find_button_animation_sprite() -> AnimatedSprite2D:
	if button_icon == null:
		return null

	if button_icon is AnimatedSprite2D:
		return button_icon as AnimatedSprite2D

	return find_animated_sprite_recursive(button_icon)


func find_animated_sprite_recursive(
	root: Node
) -> AnimatedSprite2D:
	for child in root.get_children():
		if child is AnimatedSprite2D:
			return child as AnimatedSprite2D

		var result: AnimatedSprite2D = (
			find_animated_sprite_recursive(child)
		)

		if result != null:
			return result

	return null

#endregion


#region Initialization

func _ready() -> void:
	print("PLAYER INTERACT COMPONENT IS RUNNING")
	if Engine.is_editor_hint():
		return

	if player == null:
		var parent_node: Node = get_parent()

		while parent_node != null:
			if parent_node is CharacterBody2D:
				player = parent_node as CharacterBody2D
				break

			parent_node = parent_node.get_parent()

	button_anim = find_button_animation_sprite()

	monitoring = true

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)

	hide_button_icon()

	for area in get_overlapping_areas():
		_on_area_entered(area)

	update_current_interactable()

#endregion


#region Physics

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Keep the icon positioned between the player
	# and the currently selected interactable.
	if current_interactable != null:
		if is_instance_valid(current_interactable):
			update_button_position()

#endregion


#region Input

func _unhandled_input(event: InputEvent) -> void:
	if not interaction_enabled:
		return

	if event.is_action_pressed(interact_input) and not event.is_echo():
		attempt_interaction()

#endregion


#region Interaction

func attempt_interaction() -> void:
	if not interaction_enabled:
		return

	update_current_interactable()

	if current_interactable == null:
		return

	if not current_interactable.can_interact():
		return

	if current_interactable.interact(player):
		interaction_started.emit(current_interactable)

		update_current_interactable()


func update_current_interactable() -> void:
	var previous_interactable: InteractableComponent = current_interactable

	current_interactable = get_closest_interactable()

	if previous_interactable != current_interactable:
		if current_interactable != null:
			interaction_available.emit(current_interactable)
		else:
			interaction_unavailable.emit()

	update_button_icon()

#endregion


#region Closest Interactable

func get_closest_interactable() -> InteractableComponent:
	if not interaction_enabled:
		return null

	var closest: InteractableComponent = null
	var closest_distance: float = INF

	for interactable in nearby_interactables:
		if not is_instance_valid(interactable):
			continue

		if not interactable.can_interact():
			continue

		var distance: float = global_position.distance_squared_to(
			interactable.global_position
		)

		if distance < closest_distance:
			closest_distance = distance
			closest = interactable

	return closest

#endregion


#region Area Detection

func _on_area_entered(area: Area2D) -> void:
	print("Player interaction area detected: ", area.name)
	
	if not area is InteractableComponent:
		return

	var interactable: InteractableComponent = (
		area as InteractableComponent
	)

	if interactable in nearby_interactables:
		return

	nearby_interactables.append(interactable)
	update_current_interactable()


func _on_area_exited(area: Area2D) -> void:
	if not area is InteractableComponent:
		return

	var interactable: InteractableComponent = (
		area as InteractableComponent
	)

	nearby_interactables.erase(interactable)
	update_current_interactable()

#endregion


#region Button Icon Position

func update_button_position() -> void:
	if button_icon == null:
		return

	if player == null:
		return

	if not is_instance_valid(current_interactable):
		return

	var player_position: Vector2 = player.global_position
	var interactable_position: Vector2 = (
		current_interactable.global_position
	)

	# Find the midpoint between player and interactable.
	var midpoint: Vector2 = (
		player_position + interactable_position
	) * 0.5

	# Apply the Inspector offset in world coordinates.
	button_icon.global_position = (
		midpoint + button_position_offset
	)

#endregion


#region Button Icon Visibility

func update_button_icon() -> void:
	if button_icon == null:
		return

	if not interaction_enabled or current_interactable == null:
		hide_button_icon()
		return

	show_button_icon()


func show_button_icon() -> void:
	if button_icon == null:
		return

	# Position the icon BEFORE making it visible.
	update_button_position()

	button_icon.visible = true

	if button_anim == null:
		button_anim = find_button_animation_sprite()

	if button_anim == null or button_anim.sprite_frames == null:
		return

	var animation_name: StringName = StringName(
		button_animation
	)

	if not button_anim.sprite_frames.has_animation(
		animation_name
	):
		return

	if (
		button_anim.animation != animation_name
		or not button_anim.is_playing()
	):
		button_anim.play(animation_name)


func hide_button_icon() -> void:
	if button_icon:
		button_icon.visible = false

	if button_anim:
		button_anim.stop()

#endregion


#region Utility

func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled

	if not interaction_enabled:
		current_interactable = null
		interaction_unavailable.emit()

	update_current_interactable()

#endregion
