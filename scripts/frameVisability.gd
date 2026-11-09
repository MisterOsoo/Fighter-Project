
extends Sprite2D
class_name FrameVisibility


#region Animation Settings

@export_group("Animation Settings")

@export var animated_sprite: AnimatedSprite2D
@export var target_animation: StringName = &"attack"

#endregion


#region Visibility Settings

@export_group("Visibility Frames")

@export_range(0, 100, 1)
var start_frame: int = 0

@export_range(0, 100, 1)
var end_frame: int = 1

#endregion


#region Initialization

func _ready() -> void:
	visible = false

	if animated_sprite == null:
		push_warning(
			"FrameVisibility: No AnimatedSprite2D assigned!"
		)
		return

	if not animated_sprite.frame_changed.is_connected(
		update_visibility
	):
		animated_sprite.frame_changed.connect(
			update_visibility
		)

	if not animated_sprite.animation_changed.is_connected(
		update_visibility
	):
		animated_sprite.animation_changed.connect(
			update_visibility
		)

	update_visibility()

#endregion


#region Visibility

func update_visibility() -> void:
	if animated_sprite == null:
		visible = false
		return

	if animated_sprite.animation != target_animation:
		visible = false
		return

	if not animated_sprite.is_playing():
		visible = false
		return

	var current_frame: int = animated_sprite.frame

	visible = (
		current_frame >= start_frame
		and current_frame <= end_frame
	)

#endregion
