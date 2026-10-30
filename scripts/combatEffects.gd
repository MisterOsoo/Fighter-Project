
extends Node

#region Hitstop Settings

var hitstop_timer: SceneTreeTimer
var hitstop_end_time_msec: int = 0

#endregion


#region Screen Shake Settings

var shake_camera: Camera2D
var shake_strength: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO

#endregion


#region Hitstop

func hitstop(duration: float) -> void:
	if duration <= 0.0:
		return

	var current_time: int = Time.get_ticks_msec()
	var requested_end: int = current_time + int(duration * 1000.0)

	# Allow a new hit to extend an existing hitstop.
	hitstop_end_time_msec = maxi(
		hitstop_end_time_msec,
		requested_end
	)

	if get_tree().paused:
		return

	get_tree().paused = true
	_run_hitstop()


func _run_hitstop() -> void:
	while Time.get_ticks_msec() < hitstop_end_time_msec:
		await get_tree().process_frame

	get_tree().paused = false

#endregion


#region Screen Shake

func screen_shake(
	strength: float,
	duration: float = 0.2
) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return

	var camera: Camera2D = get_viewport().get_camera_2d()

	if camera == null:
		return

	# Reset the previous camera shake if the camera changed.
	if shake_camera != camera:
		_reset_camera_offset()
		shake_camera = camera

	shake_strength = maxf(shake_strength, strength)
	shake_duration = duration
	shake_timer = duration


func _process(delta: float) -> void:
	if shake_camera == null:
		return

	if shake_timer <= 0.0:
		_reset_camera_offset()
		shake_camera = null
		return

	shake_timer -= delta

	# Remove the previous shake before applying the new one.
	shake_camera.offset -= shake_offset

	var intensity: float = clampf(
		shake_timer / maxf(shake_duration, 0.001),
		0.0,
		1.0
	)

	shake_offset = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	) * shake_strength * intensity

	shake_camera.offset += shake_offset


func _reset_camera_offset() -> void:
	if is_instance_valid(shake_camera):
		shake_camera.offset -= shake_offset

	shake_offset = Vector2.ZERO

#endregion
