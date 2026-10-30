
extends Node
class_name CameraBounds


#region Camera Settings

@export_group("Camera")
@export var camera: Camera2D

#endregion


#region Boundary Settings

@export_group("Boundaries")

@export var horizontal_margin: float = 24.0
@export var vertical_margin: float = 24.0

@export var limit_horizontal: bool = true
@export var limit_vertical: bool = false

#endregion


#region References

@onready var character: CharacterBody2D = get_parent() as CharacterBody2D

#endregion


#region Physics

func _physics_process(_delta: float) -> void:

	if character == null:
		return

	if camera == null:
		camera = get_viewport().get_camera_2d()

	if camera == null:
		return

	clamp_to_camera()

#endregion


#region Camera Boundaries

func clamp_to_camera() -> void:

	var viewport_size: Vector2 = camera.get_viewport_rect().size

	# Convert screen size into world-space size.
	var safe_zoom: Vector2 = Vector2(
		maxf(absf(camera.zoom.x), 0.001),
		maxf(absf(camera.zoom.y), 0.001)
	)

	var half_size: Vector2 = viewport_size / safe_zoom * 0.5

	var center: Vector2 = camera.get_screen_center_position()

	var min_position: Vector2 = center - half_size
	var max_position: Vector2 = center + half_size

	# Horizontal boundaries.
	if limit_horizontal:

		var min_x: float = min_position.x + horizontal_margin
		var max_x: float = max_position.x - horizontal_margin

		if min_x <= max_x:

			character.global_position.x = clampf(
				character.global_position.x,
				min_x,
				max_x
			)

			if character.global_position.x <= min_x and character.velocity.x < 0.0:
				character.velocity.x = 0.0

			if character.global_position.x >= max_x and character.velocity.x > 0.0:
				character.velocity.x = 0.0

	# Vertical boundaries.
	if limit_vertical:

		var min_y: float = min_position.y + vertical_margin
		var max_y: float = max_position.y - vertical_margin

		if min_y <= max_y:

			character.global_position.y = clampf(
				character.global_position.y,
				min_y,
				max_y
			)

			if character.global_position.y <= min_y and character.velocity.y < 0.0:
				character.velocity.y = 0.0

			if character.global_position.y >= max_y and character.velocity.y > 0.0:
				character.velocity.y = 0.0

#endregion
