
@tool
extends StaticBody2D
class_name BaseNPC


#region Signals

signal npc_interacted(interactor: Node2D)

#endregion


#region NPC Settings

@export_group("NPC Settings")

@export var npc_name: String = "NPC"
@export var face_player_on_interact: bool = true

#endregion


#region References

@export_group("References")

@export var visuals: Node2D

@export var anim: AnimatedSprite2D:
	set(value):
		anim = value
		notify_property_list_changed()

@export var interactable: InteractableComponent

#endregion


#region Animation Settings

@export_group("Animation Settings")

@export_custom(PROPERTY_HINT_ENUM, "")
var idle_animation: String = "idle"

#endregion


#region Internal Variables

var facing_direction: int = 1

#endregion


#region Inspector Animation Dropdown

func _validate_property(property: Dictionary) -> void:
	if property.name == "idle_animation":
		if anim and anim.sprite_frames:
			var animations: PackedStringArray = (
				anim.sprite_frames.get_animation_names()
			)

			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(animations)

#endregion


#region Initialization

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if visuals == null:
		visuals = get_node_or_null("visuals") as Node2D

	if anim == null and visuals:
		anim = visuals.get_node_or_null(
			"AnimatedSprite2D"
		) as AnimatedSprite2D

	if interactable == null:
		interactable = get_node_or_null(
			"Interactable"
		) as InteractableComponent

	if visuals:
		facing_direction = (
			-1 if visuals.scale.x < 0.0 else 1
		)

	if interactable:
		if not interactable.interacted.is_connected(
			_on_interacted
		):
			interactable.interacted.connect(
				_on_interacted
			)

	# Automatically play idle when NPC spawns.
	play_animation(StringName(idle_animation))

#endregion


#region Interaction

func _on_interacted(interactor: Node2D) -> void:
	if face_player_on_interact:
		face_interactor(interactor)

	npc_interacted.emit(interactor)

	print(npc_name, " was interacted with.")


func face_interactor(interactor: Node2D) -> void:
	if visuals == null:
		return

	if not is_instance_valid(interactor):
		return

	var direction: float = (
		interactor.global_position.x - global_position.x
	)

	if absf(direction) < 0.01:
		return

	facing_direction = (
		1 if direction > 0.0 else -1
	)

	# Flip the entire visuals node.
	visuals.scale.x = (
		absf(visuals.scale.x) * facing_direction
	)

#endregion


#region Animation Controller

func play_animation(
	animation_name: StringName
) -> void:
	if anim == null:
		return

	if anim.sprite_frames == null:
		return

	if not anim.sprite_frames.has_animation(
		animation_name
	):
		push_warning(
			"BaseNPC: Animation not found: "
			+ str(animation_name)
		)
		return

	if (
		anim.animation != animation_name
		or not anim.is_playing()
	):
		anim.play(animation_name)

#endregion
